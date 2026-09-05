extends SceneTree

# Headless-проверка КАМПАНИИ ИЗ ТРЁХ УРОВНЕЙ.
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
# См. /Концепция/Уровни/Кампания — три уровня.md

const SP := preload("res://scripts/spawner.gd")

# Уровней три. Полос фона по-прежнему пять — полосы 2 и 3 склеены в уровень 2,
# 4 и 5 в уровень 3, — но КАМПАНИЯ считается уровнями, а не полосами.
const LEVELS : int = 3

var _fails  : int = 0
var _checks : int = 0
const EXPECTED_CHECKS : int = 32

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
	print("── Эпизод против бесконечного ──")
	await _test_chain()
	_finish()

# ── Таблица ──────────────────────────────────────────────────────────────────

func _test_table() -> void:
	var lv : Array = SP.CAMPAIGN_LEVELS
	_check(lv.size() == LEVELS, "уровней три: %d" % lv.size())
	# Боссы стоят там же, где в старом проекте.
	_check(String(lv[0]["boss"]) == "ninja", "в конце первого — Нога Ниндзя")
	_check(String(lv[1]["boss"]) == "croc", "в конце второго — Крокодил")
	_check(String(lv[2]["boss"]) == "club", "в конце третьего — Хозяин клуба")
	# Уровень — это ЭПИЗОД, и кончается он боем: пустых финалов больше нет.
	# Раньше уровни 3 и 4 доигрывались просто буквой, потому что боссов было три
	# на пять уровней; теперь уровней ровно столько же, сколько боёв.
	var all_bossed := true
	for d in lv:
		if String(d["boss"]).is_empty():
			all_bossed = false
	_check(all_bossed, "каждый эпизод кончается боссом")

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
# У КАЖДОГО УРОВНЯ СВОЙ НАБОР — из этого локация и состоит. Проверяется не
# «набор непустой», а ПРИНАДЛЕЖНОСТЬ в обе стороны: заявленный предмет на своём
# уровне встречается, а на чужом — нет.
#
# Раскладка ниже — копия той, что в `spawner.HAZ_LEVEL`, и это не дублирование
# ради дублирования: таблица в спавнере — веса, а здесь — ЗАМЫСЕЛ. Поменяв вес,
# легко случайно уронить предмет с уровня или подсыпать его на чужой; тест
# ловит ровно это.
#
# См. /Концепция/Уровни/Раскладка по уровням.md
const LAYOUT : Dictionary = {
	# предмет → на каких уровнях (0-based) он ДОЛЖЕН встречаться
	"banana":     [0, 1],
	"trash":      [0, 2],
	"stone":      [0, 1],
	"homeless":   [0, 2],
	"cone":       [0, 1, 2],
	"roadsign":   [0],
	"snake":      [0],
	"poison":     [0],
	"helm":       [1],
	"bottle":     [1],
	"bird":       [1],
	"umbrella":   [1],
	"campfire":   [1],
	"lounger":    [1],
	"compass":    [1],
	"beer":       [1],
	"shaman":     [1],
	"police_car": [2],
	"tire":       [2],
	"molotov":    [2],
	"dog":        [2],
	"thief":      [2],
	"safe":       [2],
	"cop":        [2],
	"handcuffs":  [2],
	"girl":       [2],
	"cocktail":   [2],
	"black_ace":  [2],
	"loser_ticket": [2],
}
# Единственное, что летит ВЕЗДЕ: это не предмет места, а ритм-событие.
const EVERYWHERE : Array = ["glove"]

func _test_pools() -> void:
	var e : Dictionary = await _boot()
	var sp : Node = e["sp"]
	sp.set("campaign_mode", true)
	var seen : Array = []
	for lvl in LEVELS:
		sp.set("level", lvl)
		var kinds : Dictionary = {}
		for _i in 6000:
			kinds[String(sp.call("_pick_level_hazard"))] = true
		seen.append(kinds)

	var missing : Array = []
	var stray   : Array = []
	for item in LAYOUT:
		var want : Array = LAYOUT[item]
		for lvl in LEVELS:
			var here : bool = (seen[lvl] as Dictionary).has(item)
			if want.has(lvl) and not here:
				missing.append("%s нет на %d" % [item, lvl + 1])
			elif not want.has(lvl) and here:
				stray.append("%s залетел на %d" % [item, lvl + 1])
	_check(missing.is_empty(), "каждый предмет есть на своих уровнях: %s" % [missing])
	_check(stray.is_empty(), "и не залетает на чужие: %s" % [stray])

	var all_ok := true
	for k in EVERYWHERE:
		for lvl in LEVELS:
			if not (seen[lvl] as Dictionary).has(k):
				all_ok = false
	_check(all_ok, "боксёрская перчатка летит на всех уровнях")

	# НИНДЗЯ — только со второго. На первом игрок его ещё не встречал: там он
	# ждёт боссом в конце, и предмет, который объясняет себя этим боем, до боя
	# читается как непонятная фигура, зачем-то замирающая посреди экрана.
	var ninja_ok : bool = not (seen[0] as Dictionary).has("ninja")
	for lvl in range(1, LEVELS):
		if not (seen[lvl] as Dictionary).has("ninja"):
			ninja_ok = false
	_check(ninja_ok, "ниндзя приходит в поток со второго уровня")

	# И наборы РАЗНЫЕ: два уровня, совпавшие по составу, — это один уровень с
	# двумя задниками.
	var same : Array = []
	for a in range(LEVELS):
		for b in range(a + 1, LEVELS):
			var ka : Array = (seen[a] as Dictionary).keys()
			ka.sort()
			var kb : Array = (seen[b] as Dictionary).keys()
			kb.sort()
			if ka == kb:
				same.append("%d и %d" % [a + 1, b + 1])
	_check(same.is_empty(), "наборы уровней не повторяются: %s" % [same])
	e["game"].queue_free()
	await process_frame

# ── Слово кончает уровень ────────────────────────────────────────────────────

func _test_letters_end_level() -> void:
	var e : Dictionary = await _boot()
	var sp : Node = e["sp"]
	sp.set("campaign_mode", true)
	# Цепочка целиком — это БЕСКОНЕЧНЫЙ режим: переходы между уровнями бывают
	# только в нём (эпизод — один уровень, и после него забег кончается).
	sp.set("endless_chain", true)
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
	sp.set("endless_chain", true)
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

	# Третий уровень — последний: дальше идти некуда.
	sp.set("level", LEVELS - 1)
	sp.set("_letter_idx", SP.LETTER_WORD.length() - 1)
	var got : Array = []
	sp.connect("level_cleared", func(boss: String, nxt: int) -> void:
		got.append([boss, nxt]))
	sp.call("_run_letter")
	await _tick(8.0)
	_check(not got.is_empty() and int(got[0][1]) == 0,
		"а после третьего круг заходит на первый: %s" % [got])
	e["game"].queue_free()
	await process_frame

# ── Фон ──────────────────────────────────────────────────────────────────────

func _test_background() -> void:
	var e : Dictionary = await _boot()
	var bg : Node = e["game"].get_node_or_null("Background")
	_check(bg != null and bg.has_method("set_level"), "фон умеет менять уровень")
	if bg == null:
		for _i in LEVELS + 1:
			_check(false, "—")
		e["game"].queue_free()
		await process_frame
		return
	# У каждого уровня СВОЯ лента, и начинается она со своего куска. Один и тот же
	# кусок на двух уровнях означал бы, что смена локации не читается вовсе.
	var texs : Array = []
	for lvl in range(1, LEVELS + 1):
		bg.call("set_level", lvl)
		await process_frame
		var t : Texture2D = (bg.get_node("BgA") as Sprite2D).texture
		_check(t != null, "уровень %d: полоса загрузилась" % lvl)
		texs.append(t.resource_path if t != null else "")
	var distinct : Dictionary = {}
	for t in texs:
		distinct[t] = true
	_check(distinct.size() == LEVELS, "и у всех трёх она своя: %d разных" % distinct.size())
	e["game"].queue_free()
	await process_frame

# ── Эпизод против бесконечного ───────────────────────────────────────────────
# Одна и та же машинерия уровней, разница ровно в одном: кончается ли цепочка
# после последнего уровня или заходит на новый круг. Ошибка тут тихая в обе
# стороны — эпизод, не желающий кончаться, читается как зависший забег, а
# бесконечный, кончившийся на третьем боссе, — как «игра сломалась на победе».
func _test_chain() -> void:
	var e : Dictionary = await _boot()
	var sp : Node = e["sp"]
	sp.set("campaign_mode", true)

	# ЭПИЗОД. Ставим второй и доводим слово до конца: следующего уровня быть не
	# должно ни на первом эпизоде, ни на последнем.
	sp.set("endless_chain", false)
	for ep in LEVELS:
		sp.call("set_start_level", ep)
		sp.set("_letter_idx", SP.LETTER_WORD.length() - 1)
		var got : Array = []
		var h := func(boss: String, nxt: int) -> void: got.append([boss, nxt])
		sp.connect("level_cleared", h)
		sp.set_process(true)
		sp.call("_run_letter")
		await _tick(8.0)
		sp.disconnect("level_cleared", h)
		_check(got.size() == 1 and int(got[0][1]) == -1,
			"эпизод %d кончается сам: %s" % [ep + 1, got])

	# БЕСКОНЕЧНЫЙ. С последнего уровня цепочка заходит на первый, а не обрывается.
	sp.set("endless_chain", true)
	sp.call("set_start_level", LEVELS - 1)
	sp.set("_letter_idx", SP.LETTER_WORD.length() - 1)
	var loop : Array = []
	sp.connect("level_cleared", func(boss: String, nxt: int) -> void: loop.append(nxt))
	sp.set_process(true)
	sp.call("_run_letter")
	await _tick(8.0)
	_check(loop.size() == 1 and int(loop[0]) == 0,
		"в бесконечном после последнего уровня круг заходит на первый: %s" % [loop])

	# И СЛОЖНОСТЬ НЕ ОТКАТЫВАЕТСЯ. Второй круг обязан начинаться не легче того
	# места, где кончился первый: иначе «бесконечный» это «повторяющийся».
	sp.set("_phase", SP.CAMPAIGN_PHASES.size() - 1)
	sp.set("_phase_floor", SP.CAMPAIGN_PHASES.size() - 1)
	sp.call("advance_level")
	await process_frame
	_check(int(sp.get("level")) == 0, "уровень стал первым: %d" % int(sp.get("level")))
	_check(int(sp.get("_phase")) == SP.CAMPAIGN_PHASES.size() - 1,
		"а фаза осталась на достигнутой планке: %d" % int(sp.get("_phase")))
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
