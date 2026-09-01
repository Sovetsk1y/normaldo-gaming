extends SceneTree

# Headless-проверка КАМПАНИИ ИЗ ПЯТИ УРОВНЕЙ.
#   godot --headless --path . --script res://dev/smoke_levels.gd
#
# Кампания — это цепочка, и ломается она в стыках. Отдельно взятый уровень
# работает, отдельно взятый босс работает, а забег всё равно кончается на
# первом же переходе: слово не сбросилось, фаза не поднялась, фон не сменился,
# следующий босс не тот. Каждый такой стык тут и проверяется.
#
# Второе — НАБОРЫ ПРЕДМЕТОВ. Локация локацией её и делает: канализация — это
# банан под ногами и полицейская машина, стройка — конусы и знаки. Перепутать их
# местами нельзя, а на глаз это ловится только после долгой игры.
#
# См. /Концепция/Кампания — пять уровней.md

const SP := preload("res://scripts/spawner.gd")

var _fails  : int = 0
var _checks : int = 0
const EXPECTED_CHECKS : int = 29

func _check(ok: bool, what: String) -> void:
	_checks += 1
	if ok:
		print("  ok   ", what)
	else:
		_fails += 1
		print("  FAIL ", what)

func _initialize() -> void:
	print("── Таблица уровней ──")
	_test_table()
	print("── Наборы предметов по уровням ──")
	await _test_pools()
	print("── Слово кончает уровень ──")
	await _test_letters_end_level()
	print("── Переход на следующий уровень ──")
	await _test_advance()
	print("── Фон: своя полоса на уровень ──")
	await _test_background()
	_finish()

# ── Таблица ──────────────────────────────────────────────────────────────────

func _test_table() -> void:
	var lv : Array = SP.CAMPAIGN_LEVELS
	_check(lv.size() == 5, "уровней пять: %d" % lv.size())
	# Боссы стоят там же, где в старом проекте.
	_check(String(lv[0]["boss"]) == "ninja", "в конце первого — Нога Ниндзя")
	_check(String(lv[1]["boss"]) == "croc", "в конце второго — Крокодил")
	_check(String(lv[2]["boss"]) == "" and String(lv[3]["boss"]) == "",
		"третий и четвёртый без боссов")
	_check(String(lv[4]["boss"]) == "club", "в конце пятого — Хозяин клуба")

	# Стартовая планка сложности РАСТЁТ от уровня к уровню: пятый не должен
	# начинаться так же вяло, как первый.
	var rises := true
	for i in range(1, lv.size()):
		if int(lv[i]["phase"]) <= int(lv[i - 1]["phase"]):
			rises = false
	_check(rises, "фаза старта растёт от уровня к уровню")
	# А уровни укорачиваются: к финалу темп плотнее.
	var shortens := true
	for i in range(1, lv.size()):
		if float(lv[i]["letter"]) > float(lv[i - 1]["letter"]):
			shortens = false
	_check(shortens, "период между буквами укорачивается")

# ── Наборы предметов ─────────────────────────────────────────────────────────
# Веса перенесены из `_itemsByLevel` старого проекта. Проверяется не «набор
# непустой», а ПРИНАДЛЕЖНОСТЬ: то, что должно быть только на своём уровне,
# на чужом не встречается.

func _test_pools() -> void:
	var e : Dictionary = await _boot()
	var sp : Node = e["sp"]
	sp.set("campaign_mode", true)
	var seen : Array = []
	for lvl in 5:
		sp.set("level", lvl)
		var kinds : Dictionary = {}
		for _i in 4000:
			kinds[String(sp.call("_pick_level_hazard"))] = true
		seen.append(kinds)

	# Полицейская машина — примета ПЕРВОГО уровня и больше ничья.
	var car_only_first : bool = seen[0].has("police_car")
	for i in range(1, 5):
		if seen[i].has("police_car"):
			car_only_first = false
	_check(car_only_first, "полицейская машина — только на первом уровне")
	# Конусы начинаются со второго, перчатка — с четвёртого.
	_check(not seen[0].has("cone") and seen[1].has("cone"),
		"конусы приходят со второго уровня")
	_check(not seen[0].has("glove") and not seen[1].has("glove")
			and not seen[2].has("glove") and seen[3].has("glove"),
		"боксёрская перчатка — с четвёртого")
	_check(not seen[0].has("roadsign") and not seen[1].has("roadsign")
			and seen[2].has("roadsign"),
		"дорожный знак — с третьего")
	# Банан есть везде: это общая примета улицы, а не одной локации.
	var banana_all := true
	for i in 5:
		if not seen[i].has("banana"):
			banana_all = false
	_check(banana_all, "банановая кожура есть на всех уровнях")
	# И база тоже: камень, змея, ниндзя не привязаны к месту.
	var base_all := true
	for i in 5:
		for k in ["stone", "snake", "ninja"]:
			if not seen[i].has(k):
				base_all = false
	_check(base_all, "камень, змея и ниндзя есть везде")
	e["game"].queue_free()
	await process_frame

# ── Слово кончает уровень ────────────────────────────────────────────────────

func _test_letters_end_level() -> void:
	var e : Dictionary = await _boot()
	var sp : Node = e["sp"]
	sp.set("campaign_mode", true)
	sp.set_process(true)
	var got : Array = []
	sp.connect("level_cleared", func(boss: String, nxt: int) -> void:
		got.append([boss, nxt]))

	# Доводим слово до последней буквы напрямую: гонять восемь периодов по
	# четырнадцать секунд значило бы мерить секундомер, а не переход.
	sp.set("_letter_idx", SP.LETTER_WORD.length() - 1)
	sp.call("_run_letter")
	await _tick(8.0)
	_check(got.size() == 1, "последняя буква кончает уровень: %d" % got.size())
	if not got.is_empty():
		_check(String(got[0][0]) == "ninja" and int(got[0][1]) == 1,
			"и говорит, кого звать и куда дальше: %s" % [got[0]])
	else:
		_check(false, "—")
	_check(not sp.is_processing(), "поток на время босса остановлен")
	e["game"].queue_free()
	await process_frame

# ── Переход ──────────────────────────────────────────────────────────────────

func _test_advance() -> void:
	var e : Dictionary = await _boot()
	var sp : Node = e["sp"]
	sp.set("campaign_mode", true)
	sp.set("_letter_idx", 8)
	sp.set("level", 0)
	sp.call("advance_level")
	await process_frame
	_check(int(sp.get("level")) == 1, "уровень стал вторым")
	_check(int(sp.call("letters_done")) == 0, "слово начинается ЗАНОВО")
	_check(int(sp.get("_phase")) == int(SP.CAMPAIGN_LEVELS[1]["phase"]),
		"фаза встала на планку уровня: %d" % int(sp.get("_phase")))
	_check(sp.is_processing(), "поток снова идёт")
	_check(String(sp.call("level_name")) == String(SP.CAMPAIGN_LEVELS[1]["name"]),
		"и название сменилось: %s" % sp.call("level_name"))

	# Пятый уровень — последний: дальше идти некуда.
	sp.set("level", 4)
	sp.set("_letter_idx", SP.LETTER_WORD.length() - 1)
	var got : Array = []
	sp.connect("level_cleared", func(boss: String, nxt: int) -> void:
		got.append([boss, nxt]))
	sp.call("_run_letter")
	await _tick(8.0)
	_check(not got.is_empty() and int(got[0][1]) == 0,
		"после пятого следующего нет: %s" % [got])
	e["game"].queue_free()
	await process_frame

# ── Фон ──────────────────────────────────────────────────────────────────────

func _test_background() -> void:
	var e : Dictionary = await _boot()
	var bg : Node = e["game"].get_node_or_null("Background")
	_check(bg != null and bg.has_method("set_level"), "фон умеет менять уровень")
	if bg == null:
		_check(false, "—")
		_check(false, "—")
		_check(false, "—")
		e["game"].queue_free()
		await process_frame
		return
	# У каждого уровня СВОЯ полоса, и куски у них разные. Одна и та же полоса на
	# двух уровнях означала бы, что смена локации не читается вовсе.
	var texs : Array = []
	for lvl in range(1, 6):
		bg.call("set_level", lvl)
		await process_frame
		var t : Texture2D = (bg.get_node("BgA") as Sprite2D).texture
		_check(t != null, "уровень %d: полоса загрузилась" % lvl)
		texs.append(t.resource_path if t != null else "")
	var distinct : Dictionary = {}
	for t in texs:
		distinct[t] = true
	_check(distinct.size() == 5, "и у всех пяти она своя: %d разных" % distinct.size())
	e["game"].queue_free()
	await process_frame

# ── Хелперы ──────────────────────────────────────────────────────────────────

func _boot() -> Dictionary:
	var game : Node = load("res://scenes/game.tscn").instantiate()
	get_root().add_child(game)
	await process_frame
	var sp : Node = game.get_node_or_null("Spawner")
	sp.call("clear_items")
	sp.set_process(false)
	get_root().get_tree().paused = false
	await process_frame
	return { "game": game, "sp": sp }

func _tick(sec: float) -> void:
	var t := 0.0
	while t < sec:
		get_root().get_tree().paused = false
		await process_frame
		t += 1.0 / 60.0

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
