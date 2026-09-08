extends SceneTree

# Headless-проверка правок забега, каждая из которых ломалась МОЛЧА.
#   godot --headless --path . --script res://dev/smoke_run_fixes.gd
#
# Общее у них одно: ни одна не роняет игру и ни одна не видна в логе. Их находят
# глазами, случайно, через недели после того, как они появились, — значит место
# им в тесте, а не в списке «посмотреть при случае».
#
#   1. ПОДПИСЬ С ПЕРЕНОСОМ раздувалась до пол-экрана и уносила текст мимо своей
#      панели. Так пропала реплика босса: облачко рисуется, текста в нём нет.
#   2. НИНДЗЯ НЕ ВОЗВРАЩАЛ УПРАВЛЕНИЕ после реплики — весь бой Нормальдо стоял.
#   3. `enable_input()` ЗВАЛИ КАК «вернуть управление», а она начинает забег:
#      каждый бой стирал накопленный бонусный опыт и бонус мага.
#   4. ЧАСЫ ЗАМЕДЛЕНИЯ висели по центру головы и закрывали её целиком.
#   5. ВЗГЛЯД ЗАЛИПАЛ ВЛЕВО: увёл голову влево — и она едет затылком к потоку,
#      пока следующий свайп случайно не окажется вправо.

const UI_KIT      := preload("res://scripts/ui_kit.gd")
const BOSS_SPEECH := preload("res://scripts/boss_speech.gd")

var _fails  : int = 0
var _checks : int = 0
const EXPECTED_CHECKS : int = 18

func _check(ok: bool, what: String) -> void:
	_checks += 1
	if ok:
		print("  ok   ", what)
	else:
		_fails += 1
		print("  FAIL ", what)

func _initialize() -> void:
	var game : Node = load("res://scenes/game.tscn").instantiate()
	get_root().add_child(game)
	await process_frame
	var n  : Node2D = game.get_node_or_null("Normaldo")
	var sp : Node   = game.get_node_or_null("Spawner")
	sp.call("clear_items")
	sp.set_process(false)
	n.set("_dev_immortal", true)
	await process_frame

	# ── Подпись с переносом ─────────────────────────────────────────────────
	# У Label с `autowrap_mode` минимальная высота считается ОТ ШИРИНЫ. В момент
	# add_child() ширина нулевая, перенос выходит по одному символу на строку —
	# у пятнадцати букв это 492 px минимальной высоты вместо 84. Дальше size
	# зажимается этим минимумом, и с выравниванием по центру текст уезжает
	# далеко вниз.
	print("── Подпись с переносом ──")
	var host := Control.new()
	host.size = Vector2(330.0, 84.0)
	get_root().add_child(host)
	var l := Label.new()
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.text          = "ПРОВЕРКА ПЕРЕНОСА"
	UI_KIT.place(host, l, Vector2(10.0, 0.0), Vector2(310.0, 84.0))
	await process_frame
	_check(absf(l.size.y - 84.0) < 1.0,
		"место под подпись не раздувается: %.0f при заказанных 84" % l.size.y)
	host.queue_free()

	# И то же самое НА ЖИВОМ ОБЛАЧКЕ БОССА: проверка выше про механику, эта —
	# про то, что реплику видно. Текст обязан лежать В ГРАНИЦАХ облачка.
	BOSS_SPEECH.show(game, game, "ТЫ ЖИРНЫЙ И МЕДЛЕННЫЙ.\nЯ БЫСТРЫЙ.", 220.0,
		Color(0.10, 0.06, 0.14), Color(0.92, 0.26, 0.30), Color(0.98, 0.96, 1.00),
		4.0, 0.32)
	await process_frame
	await process_frame
	var box : Control = _speech_box(game)
	_check(box != null, "облачко реплики на месте")
	var msg : Label = _label_of(box) if box != null else null
	_check(msg != null and not msg.text.strip_edges().is_empty(),
		"и текст в нём есть: «%s»" % [msg.text if msg != null else "нет"])
	_check(msg != null and msg.size.y <= box.size.y + 1.0,
		"и он ВНУТРИ облачка, а не под ним: %.0f при высоте облачка %.0f"
			% [msg.size.y if msg != null else -1.0, box.size.y if box != null else -1.0])

	# ── Управление возвращают, а не начинают забег заново ────────────────────
	print("── Возврат управления ──")
	_check(n.has_method("resume_input"), "у Нормальдо есть отдельный возврат")
	n.call("enable_input")
	n.set("_skill_bonus_xp", 777)
	n.set("_wizard_bonus_active", true)
	n.call("disable_input")
	n.call("resume_input")
	_check(bool(n.call("is_input_enabled")), "он включает управление")
	# ВОТ РАДИ ЧЕГО ОН И ЗАВЕДЁН. `enable_input()` — это старт забега: она
	# обнуляет накопленное. Боссы звали её после своей реплики, то есть каждый
	# бой молча съедал игроку заработанный бонусный опыт.
	_check(int(n.get("_skill_bonus_xp")) == 777,
		"и НЕ стирает накопленный бонусный опыт: %d" % int(n.get("_skill_bonus_xp")))
	_check(bool(n.get("_wizard_bonus_active")), "и не снимает бонус мага")
	n.call("enable_input")
	_check(int(n.get("_skill_bonus_xp")) == 0,
		"а старт забега — стирает, как и должен: %d" % int(n.get("_skill_bonus_xp")))

	# Ни один босс не зовёт старт забега вместо возврата: это та же ошибка,
	# и повторить её проще всего копипастой из соседнего босса.
	var offenders : Array = []
	for f in ["scripts/ninja_foot.gd", "scripts/club_boss.gd",
			"scripts/leatherhead.gd", "scripts/bum_king.gd"]:
		if _mentions(f, "enable_input") and not _mentions(f, "resume_input"):
			offenders.append(f)
		elif _calls_start(f):
			offenders.append(f)
	_check(offenders.is_empty(), "и боссы зовут именно его: %s" % [offenders])

	# ── Часы замедления ─────────────────────────────────────────────────────
	# Значок вдвое шире головы, и надетый по центру он закрывал лицо целиком —
	# полторы секунды игрок смотрит на циферблат вместо Нормальдо.
	print("── Часы замедления ──")
	var vp : Vector2 = get_root().get_visible_rect().size
	n.position = vp * 0.5
	n.call("_mark_world_slow", 4.0)
	await process_frame
	var fx : Dictionary = n.get("_status_fx")
	var clock = fx.get("hourglass")
	_check(clock != null and is_instance_valid(clock), "часы появились")
	if clock != null and is_instance_valid(clock):
		var dy : float = float((clock as Node).get_meta("dy", 0.0))
		_check(dy < -20.0, "и стоят НАД головой: сдвиг %.0f px" % dy)
		_check((clock as Node2D).global_position.y < n.global_position.y - 20.0,
			"а не на ней: часы на y=%.0f, голова на y=%.0f"
				% [(clock as Node2D).global_position.y, n.global_position.y])

	# ── Палец на экране разворачивает вперёд ────────────────────────────────
	print("── Взгляд по касанию ──")
	n.call("enable_input")
	n.call("_set_facing", true)
	_check(bool(n.get("_facing_left")), "голова смотрит влево")
	var t := InputEventScreenTouch.new()
	t.pressed  = true
	t.index    = 0
	t.position = vp * 0.5
	n.call("_input", t)
	# ПОКА ПАЛЕЦ НА ЭКРАНЕ, взгляд слушается движения: игрок ведёт голову и
	# видит, куда она летит. Разворачивать её тут значило бы спорить с рукой.
	_check(bool(n.get("_facing_left")),
		"пока палец на экране — взгляд слушается движения")
	var up := InputEventScreenTouch.new()
	up.pressed  = false
	up.index    = 0
	up.position = vp * 0.5
	n.call("_input", up)
	_check(not bool(n.get("_facing_left")),
		"убрали палец — голова возвращается вперёд, к потоку")

	# ── И ТО ЖЕ САМОЕ ВЖИВУЮ, на настоящем бою ──────────────────────────────
	# Сверка по исходникам выше ловит копипасту, но не ловит пропуск: у Ноги
	# Ниндзя вызова не было ВООБЩЕ, и никакая проверка «зовёт ли он правильную
	# функцию» этого не увидела бы. Поэтому здесь поднимается настоящий бой и
	# ждётся, что управление сначала отберут, а потом вернут. Интро идёт около
	# восьми секунд — это цена того, чтобы проверять то, что случилось, а не то,
	# что написано.
	print("── Ниндзя: бой целиком ──")
	var hud : Node = game.get_node_or_null("HUD")
	n.call("enable_input")
	hud.call("_summon_boss", "ninja")
	var was_off := false
	var back_at := -1.0
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 25000:
		if not bool(n.call("is_input_enabled")):
			was_off = true
		elif was_off:
			back_at = float(Time.get_ticks_msec() - t0) / 1000.0
			break
		await process_frame
	_check(was_off, "реплика забирает управление")
	_check(back_at > 0.0,
		"и после титра оно возвращается: через %.1f c" % back_at)

	_finish()

func _speech_box(root: Node) -> Control:
	for c in root.get_children():
		if c is CanvasLayer and (c as CanvasLayer).layer == BOSS_SPEECH.LAYER:
			for k in c.get_children():
				if k is Control:
					return k
	return null

func _label_of(box: Control) -> Label:
	if box == null:
		return null
	for c in box.get_children():
		if c is Label:
			return c
	return null

# Читаем ИСХОДНИК, а не поведение: вызов стоит внутри длинной корутины интро,
# и доигрывать её целиком ради одной строки — это минуты на каждый прогон.
# Комментарии пропускаем: в них эти слова стоят по делу.
func _mentions(path: String, what: String) -> bool:
	var f := FileAccess.open("res://" + path.trim_prefix("res://"), FileAccess.READ)
	if f == null:
		return false
	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line.begins_with("#"):
			continue
		if line.contains(what):
			return true
	return false

func _calls_start(path: String) -> bool:
	var f := FileAccess.open("res://" + path.trim_prefix("res://"), FileAccess.READ)
	if f == null:
		return false
	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line.begins_with("#"):
			continue
		if line.contains("enable_input") and not line.contains("resume_input") \
				and not line.contains("disable_input") \
				and not line.contains("is_input_enabled"):
			return true
	return false

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
