extends SceneTree

# Headless-проверка экрана достижений.
#   godot --headless --path . --script res://dev/smoke_awards.gd
#
# Экран собран на моках, но ТАБЛИЦА настоящая, и ломается она тихо. Три вида
# поломок, ни один из которых на глаз не виден:
#
#   1. Таблица разошлась со спекой. Список сгенерирован из
#      Концепция/Достижения.md; правка руками в scripts/achievements.gd
#      переживёт ровно до следующей пересборки, а до тех пор экран будет
#      показывать не то, что согласовано.
#   2. Числа не сходятся с потолком Apple. Больше 100 достижений или больше
#      1000 очков — и часть списка просто не заведётся в App Store Connect,
#      причём узнаем мы об этом на выкатке, а не здесь.
#   3. Достижение потерялось между категориями. Категорий двенадцать, экран
#      показывает по одной, и выпавшее из всех двенадцати не увидит никто.
#
# См. /Концепция/Достижения.md

const ACH := preload("res://scripts/achievements.gd")
const MOCK := preload("res://scripts/achievements_mock.gd")

var _fails  : int = 0
var _checks : int = 0
const EXPECTED_CHECKS : int = 22

func _check(ok: bool, what: String) -> void:
	_checks += 1
	if ok:
		print("  ok   ", what)
	else:
		_fails += 1
		print("  FAIL ", what)

func _initialize() -> void:
	print("── Таблица ──")
	_test_table()
	print("── Потолок Apple ──")
	_test_apple()
	print("── Моки ──")
	_test_mock()
	print("── Экран ──")
	await _test_screen()
	_finish()

# ── Таблица ──────────────────────────────────────────────────────────────────

func _test_table() -> void:
	var all : Array = ACH.ALL
	_check(all.size() == 78, "достижений 78: %d" % all.size())

	# Уникальность id — главное свойство всего списка. id уходит в Game Center
	# и там неизменен навсегда; два достижения с одним id — это одно
	# достижение, и второе просто не заведётся.
	var seen : Dictionary = {}
	var dup : Array = []
	for a in all:
		var i : String = String(a["id"])
		if seen.has(i):
			dup.append(i)
		seen[i] = true
	_check(dup.is_empty(), "id уникальны: %s" % [dup])

	# Каждое достижение лежит в ОДНОЙ из объявленных категорий, и сумма по
	# категориям равна всему списку. Достижение с категорией, которой нет во
	# вкладках, не показывается вообще — и молча.
	var keys : Dictionary = {}
	for c in ACH.CATEGORIES:
		keys[String(c["key"])] = true
	var stray : Array = []
	for a in all:
		if not keys.has(String(a["cat"])):
			stray.append(String(a["id"]))
	_check(stray.is_empty(), "категория каждого объявлена во вкладках: %s" % [stray])

	var sum_cats := 0
	for c in ACH.CATEGORIES:
		sum_cats += ACH.in_category(String(c["key"])).size()
	_check(sum_cats == all.size(),
		"по категориям разложены все: %d из %d" % [sum_cats, all.size()])

	# Пустая категория — это пустая вкладка на экране: игрок нажимает и видит
	# белое поле, не понимая, сломано это или так задумано.
	var empty : Array = []
	for c in ACH.CATEGORIES:
		if ACH.in_category(String(c["key"])).is_empty():
			empty.append(String(c["key"]))
	_check(empty.is_empty(), "пустых категорий нет: %s" % [empty])

	# Порог, вес, заголовок и счётчик — обязательные поля. Порог 0 сделал бы
	# достижение выданным всем сразу, пустой заголовок — безымянной строкой.
	var bad : Array = []
	for a in all:
		if int(a["goal"]) < 1 or int(a["tier"]) < 1 or int(a["tier"]) > 4 \
				or String(a["title"]).is_empty() or String(a["stat"]).is_empty():
			bad.append(String(a["id"]))
	_check(bad.is_empty(), "у всех есть порог, вес, имя и счётчик: %s" % [bad])

	# Волна только первая или вторая: третьей в спеке нет, и «волна 0» на экране
	# нарисовала бы метку «2-я волна» там, где её быть не должно.
	var waves : Array = []
	for a in all:
		if int(a["wave"]) != 1 and int(a["wave"]) != 2:
			waves.append(String(a["id"]))
	_check(waves.is_empty(), "волна у всех первая или вторая: %s" % [waves])

	# ЛЕСТНИЦЫ. Пороги внутри лестницы обязаны РАСТИ: ступень легче предыдущей —
	# это перепутанные местами строки, в списке на 78 строк глазами такое не
	# ловится, а на экране выглядит как сломанная полоска.
	#
	# Сравнивать пороги можно только В ПРЕДЕЛАХ ОДНОГО СЧЁТЧИКА, и это не
	# послабление проверки, а устройство двух лестниц из семнадцати. «Кампания»
	# идёт эпизод 1 → 2 → 3 по счётчику `episodes_done`, а её вершина «пройди
	# всю кампанию» стоит на отдельном `campaign_done` с порогом 1. «Уровни
	# скинов» так же переламываются с `skin_lvl_max` на `skins_at_10`: сначала
	# докуда дошёл один скин, потом сколько скинов дошло до десятого. Числа 1 и
	# 3 на этих переломах меньше предыдущих, и это верно — они про другое.
	#
	# Ровно эту разницу проверка сначала и не знала: она сравнивала пороги через
	# перелом и падала на верных данных.
	var by_chain : Dictionary = {}
	var by_leg : Dictionary = {}
	for a in all:
		var ch : String = String(a.get("chain", ""))
		if ch.is_empty():
			continue
		by_chain[ch] = true
		var leg : String = ch + "|" + String(a["stat"])
		if not by_leg.has(leg):
			by_leg[leg] = []
		(by_leg[leg] as Array).append(a)
	_check(by_chain.size() >= 15, "лестниц не меньше пятнадцати: %d" % by_chain.size())

	var broken : Array = []
	for leg in by_leg:
		var steps : Array = by_leg[leg]
		steps.sort_custom(func(x, y): return String(x["step"]) < String(y["step"]))
		var prev : int = -1
		for s in steps:
			if int(s["goal"]) < prev:
				broken.append("%s: %d после %d" % [leg, int(s["goal"]), prev])
			prev = int(s["goal"])
	_check(broken.is_empty(), "пороги внутри лестниц растут: %s" % [broken])

	# Взятая ступень обязана тянуть за собой все предыдущие СВОЕГО счётчика.
	# Именно на этом и погорел первый мок: «пройди всю кампанию» стояло взятым
	# при непройденном третьем эпизоде. Экран с такой раскладкой обсуждать
	# нельзя — непонятно, кривой список или кривые числа.
	var gaps : Array = []
	for leg in by_leg:
		var steps : Array = by_leg[leg]
		steps.sort_custom(func(x, y): return int(x["goal"]) < int(y["goal"]))
		var seen_undone := false
		for s in steps:
			if MOCK.is_done(s):
				if seen_undone:
					gaps.append("%s: %s взято через дыру" % [leg, String(s["id"])])
			else:
				seen_undone = true
	_check(gaps.is_empty(), "взятые ступени идут подряд с начала: %s" % [gaps])

# ── Потолок Apple ────────────────────────────────────────────────────────────

func _test_apple() -> void:
	var n : int = ACH.ALL.size()
	_check(n <= 100, "достижений не больше ста: %d" % n)
	var pts : int = ACH.total_points()
	_check(pts <= 1000, "очков не больше тысячи: %d" % pts)
	var over : Array = []
	for a in ACH.ALL:
		if ACH.points(a) > 100:
			over.append(String(a["id"]))
	_check(over.is_empty(), "ни одно не дороже ста очков: %s" % [over])

# ── Моки ─────────────────────────────────────────────────────────────────────

func _test_mock() -> void:
	# Прогресс обязан быть ПОВТОРЯЕМЫМ: экран показывают и снимают кадрами, и
	# список, меняющийся при каждом открытии, обсуждать нельзя.
	var a : Dictionary = ACH.ALL[7]
	var same := true
	for _i in 5:
		if MOCK.counter(a) != MOCK.counter(a) or MOCK.is_done(a) != MOCK.is_done(a):
			same = false
	_check(same, "мок повторяем: одно и то же достижение даёт одно и то же")

	# Взятое обязано иметь счётчик не меньше порога, невзятое — меньше.
	# Иначе на экране «получено» с полоской в треть, и наоборот.
	var bad : Array = []
	for x in ACH.ALL:
		var done : bool = MOCK.is_done(x)
		var c : int = MOCK.counter(x)
		if done and c < int(x["goal"]):
			bad.append("%s: взято при %d из %d" % [String(x["id"]), c, int(x["goal"])])
		elif not done and c >= int(x["goal"]):
			bad.append("%s: не взято при %d из %d" % [String(x["id"]), c, int(x["goal"])])
	_check(bad.is_empty(), "счётчик не спорит с признаком «взято»: %s" % [bad])

	# Сводка обязана сходиться с построчным подсчётом: расхождение шапки со
	# списком — первое, что видно на таком экране.
	var s : Dictionary = MOCK.summary()
	var done_rows := 0
	for x in ACH.ALL:
		if MOCK.is_done(x):
			done_rows += 1
	_check(int(s["done"]) == done_rows,
		"шапка сходится со списком: %d и %d" % [int(s["done"]), done_rows])
	_check(int(s["points_all"]) == ACH.total_points(),
		"и очки в шапке — те же: %d" % int(s["points_all"]))

# ── Экран ────────────────────────────────────────────────────────────────────

func _test_screen() -> void:
	var game : Node = load("res://scenes/game.tscn").instantiate()
	get_root().add_child(game)
	await process_frame
	var hud : Node = game.get_node_or_null("HUD")
	_check(hud != null and hud.has_method("_show_awards"), "интерфейс умеет открыть экран")
	if hud == null:
		game.queue_free()
		return

	hud.call("_show_awards", 0)
	for _i in 40:
		get_root().get_tree().paused = false
		await process_frame

	var screen : Node = null
	for c in hud.get_children():
		if c is AwardsScreen:
			screen = c
	_check(screen != null, "экран открылся")
	if screen == null:
		game.queue_free()
		return

	# Строк на странице ровно столько, сколько достижений в категории. Ошибка
	# тут тихая в обе стороны: недостача — молча пропавшее достижение, избыток —
	# строки прошлой категории, оставшиеся после переключения.
	var body : Node = screen.get("_page_body")
	var n0 : int = ACH.in_category("start").size()
	_check(body != null and body.get_child_count() > 0, "страница собралась")

	# Переключение категории обязано ЗАМЕНИТЬ страницу, а не дописать к ней.
	# Проверяется высотой содержимого: у категорий разное число достижений.
	var h0 : float = (body as Control).custom_minimum_size.y
	screen.call("_on_category", 6)   # СКИНЫ — двенадцать, больше всех
	await process_frame
	var h1 : float = (body as Control).custom_minimum_size.y
	_check(h1 > h0, "переключение категории перестроило страницу: %.0f → %.0f" % [h0, h1])
	var n6 : int = ACH.in_category("skins").size()
	_check(is_equal_approx(h1 / maxf(1.0, h0), float(n6) / float(n0)),
		"и высота выросла ровно по числу строк: %d против %d" % [n6, n0])

	game.queue_free()
	await process_frame

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
