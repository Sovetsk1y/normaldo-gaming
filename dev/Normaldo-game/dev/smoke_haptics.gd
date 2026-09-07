extends SceneTree

# Headless-проверка вибрации.
#   godot --headless --path . --script res://dev/smoke_haptics.gd
#
# На десктопе `Input.vibrate_handheld()` — пустышка, и «загудел ли телефон»
# проверить нечем. Поэтому проверяется то, что действительно ломается:
#
#   1. ВЫКЛЮЧАТЕЛЬ ЗНАЕТ ПРО ВСЕ ВЫЗОВЫ. Прямой `Input.vibrate_handheld()` в
#      обход `Haptics` — это место, где телефон дёрнется у игрока, который
#      вибрацию выключил. Тест ищет такие места ПО ИСХОДНИКАМ: иначе они
#      находятся только жалобой.
#   2. Настройка живёт между запусками и вправду глушит гудок.
#   3. Тряска экрана и вибрация — одно событие: у трёх боссов тело тряски было
#      скопировано побайтово, и разъехаться им теперь негде.
#
# См. scripts/haptics.gd, scripts/screen_shake.gd

const HAPTICS      := preload("res://scripts/haptics.gd")
const SCREEN_SHAKE := preload("res://scripts/screen_shake.gd")

var _fails  : int = 0
var _checks : int = 0
const EXPECTED_CHECKS : int = 13

func _check(ok: bool, what: String) -> void:
	_checks += 1
	if ok:
		print("  ok   ", what)
	else:
		_fails += 1
		print("  FAIL ", what)

func _initialize() -> void:
	await process_frame

	# ── Единственный вход ───────────────────────────────────────────────────
	print("── Прямых вызовов в обход выключателя нет ──")
	var strays : Array = _grep_stray_vibrate("res://scripts")
	_check(strays.is_empty(),
		"Input.vibrate_handheld зовётся только из haptics.gd: %s" % [strays])

	# ── Словарь силы ────────────────────────────────────────────────────────
	# Ступени обязаны РАЗЛИЧАТЬСЯ пальцем. Числа, съехавшиеся в кучу, дают
	# «настроенный» словарь, в котором на деле одна ступень.
	print("── Словарь силы ──")
	# Порог 1.5 — не «примерно», а граница различимости: разницу в длительности
	# гудка пальцем ловят примерно от полутора раз, ближе — ощущается как одно и
	# то же. Меньший порог пропустил бы словарь, в котором ступеней на бумаге
	# четыре, а на телефоне две.
	const RATIO_MIN : float = 1.5
	var steps : Array = [HAPTICS.TAP, HAPTICS.HIT, HAPTICS.HEAVY, HAPTICS.BOSS]
	var worst : float = 1e9
	for i in steps.size() - 1:
		worst = minf(worst, float(steps[i + 1]) / float(steps[i]))
	_check(worst >= RATIO_MIN,
		"ступени различимы пальцем: %s, худшая разница ×%.2f" % [steps, worst])

	# ── Выключатель ─────────────────────────────────────────────────────────
	print("── Выключатель ──")
	var sd : Node = get_root().get_node_or_null("SaveData")
	_check(sd != null, "SaveData на месте")
	if sd == null:
		_finish()
		return
	var was : bool = bool(sd.get("vibration_on"))
	_check(sd.has_method("set_vibration"), "у настройки есть свой сеттер")

	sd.call("set_vibration", true)
	HAPTICS.reset_probe()
	HAPTICS.buzz(HAPTICS.HIT)
	_check(HAPTICS.count == 1 and HAPTICS.last_ms == HAPTICS.HIT,
		"включена — гудит: %d раз, %d мс" % [HAPTICS.count, HAPTICS.last_ms])

	sd.call("set_vibration", false)
	HAPTICS.reset_probe()
	HAPTICS.buzz(HAPTICS.BOSS)
	_check(HAPTICS.count == 0 and HAPTICS.suppressed == 1,
		"выключена — молчит: гудков %d, подавлено %d"
			% [HAPTICS.count, HAPTICS.suppressed])

	# Настройка ПЕРЕЖИВАЕТ перезапуск. Выключатель, который сбрасывается на
	# следующем запуске, — это не выключатель, а пауза.
	sd.call("_save")
	sd.call("_load")
	_check(not bool(sd.get("vibration_on")), "и сохраняется между запусками")
	sd.call("set_vibration", was)

	# Нулевая и отрицательная длительность — не гудок. Это не педантизм: сила
	# считается из амплитуды тряски, а амплитуда приходит числом извне.
	HAPTICS.reset_probe()
	sd.call("set_vibration", true)
	HAPTICS.buzz(0)
	HAPTICS.buzz(-5)
	_check(HAPTICS.count == 0, "нулевая длительность гудком не считается")

	# ── Тряска и вибрация — одно событие ────────────────────────────────────
	print("── Тряска ──")
	_check(SCREEN_SHAKE.strength(16.0) == HAPTICS.HEAVY,
		"сильная тряска → тяжёлая отдача")
	_check(SCREEN_SHAKE.strength(7.0) == HAPTICS.HIT,
		"средняя → удар")
	_check(SCREEN_SHAKE.strength(4.0) == HAPTICS.TAP,
		"мелкая → лёгкая")

	var root := Node2D.new()
	get_root().add_child(root)
	await process_frame
	HAPTICS.reset_probe()
	SCREEN_SHAKE.play(root, 14.0, 8)
	_check(HAPTICS.count == 1 and HAPTICS.last_ms == HAPTICS.HEAVY,
		"и сама тряска отдаёт: %d мс" % HAPTICS.last_ms)

	# Три босса больше НЕ ДЕРЖАТ своего тела тряски: оно у них совпадало
	# побайтово, и вернуть копию — самый естественный способ потерять отдачу на
	# одном из боёв.
	var own : Array = []
	for f in ["leatherhead.gd", "club_boss.gd", "ninja_foot.gd"]:
		var src := FileAccess.get_file_as_string("res://scripts/" + f)
		if "create_tween()" in src and "func _screen_shake" in src \
				and not ("SCREEN_SHAKE.play" in src):
			own.append(f)
	_check(own.is_empty(), "боссы трясут экран общим кирпичом: %s" % [own])

	sd.call("set_vibration", was)
	_finish()

# Ищем `Input.vibrate_handheld` во всех скриптах, кроме самого haptics.gd.
func _grep_stray_vibrate(dir: String) -> Array:
	var out : Array = []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	d.list_dir_begin()
	var name := d.get_next()
	while name != "":
		var path := dir + "/" + name
		if d.current_is_dir():
			if not name.begins_with("."):
				out.append_array(_grep_stray_vibrate(path))
		elif name.ends_with(".gd") and name != "haptics.gd":
			# Смотрим КОД, а не комментарии: про этот запрет как раз и написано
			# словами в паре мест, и слепой поиск по файлу находил объяснение
			# правила и объявлял его нарушением.
			for line in FileAccess.get_file_as_string(path).split("\n"):
				var code : String = line.strip_edges()
				if code.begins_with("#"):
					continue
				if "Input.vibrate_handheld" in code:
					out.append(name)
					break
		name = d.get_next()
	d.list_dir_end()
	return out

func _finish() -> void:
	print("")
	if _checks < EXPECTED_CHECKS:
		print("ПРОВАЛ: проверок %d из %d — тест не отработал" % [_checks, EXPECTED_CHECKS])
		quit(1)
		return
	if _fails == 0:
		print("ВСЁ ЗЕЛЁНОЕ (проверок: %d)" % _checks)
	else:
		print("ПРОВАЛОВ: ", _fails)
	quit(1 if _fails > 0 else 0)
