extends SceneTree

# Headless-проверка экрана достижений.
#   godot --headless --path . --script res://dev/smoke_awards.gd
#
# ТАБЛИЦА и СЧЁТЧИКИ ломаются тихо. Виды поломок, ни один из которых на глаз не
# виден:
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
#   4. ОСИРОТЕВШИЙ СЧЁТЧИК. У достижения написан `stat`, а хука, который его
#      считает, нет — достижение нельзя получить никогда, и снаружи это выглядит
#      просто как «не выпадает». Проверяется по исходникам: имя счётчика обязано
#      где-то встречаться литералом.
#   5. ЛИШНИЙ ХУК. Менеджер считает счётчик, на котором не висит ни одного
#      достижения, — работа вхолостую, и обычно это опечатка в имени.
#
# См. /Концепция/Достижения.md

const ACH := preload("res://scripts/achievements.gd")

# `achievement_manager.gd` НЕ ПРЕЛОУДИТСЯ: скрипт SceneTree компилируется до
# того, как автозагрузки попадают в область видимости, а менеджер обращается к
# SaveData и QuestManager. Берём его из дерева готовым узлом.
const MANAGER_SRC : String = "res://scripts/achievement_manager.gd"

var _fails  : int = 0
var _checks : int = 0
const EXPECTED_CHECKS : int = 45

func _check(ok: bool, what: String) -> void:
	_checks += 1
	if ok:
		print("  ok   ", what)
	else:
		_fails += 1
		print("  FAIL ", what)

func _initialize() -> void:
	# ЖДЁМ КАДР. Скрипт SceneTree стартует РАНЬШЕ, чем автозагрузки проходят
	# `_ready`: без этого менеджер отвечает на вызовы, но с пустым индексом —
	# и тест «ничего не открылось» проходит по неверной причине.
	await process_frame
	print("── Таблица ──")
	_test_table()
	print("── Потолок Apple ──")
	_test_apple()
	print("── Счётчики ──")
	_test_stats()
	print("── Менеджер ──")
	_test_manager()
	print("── Зеркало ──")
	_test_backend()
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

	# Пороги внутри одного счётчика обязаны РАЗЛИЧАТЬСЯ. Две ступени с одним
	# порогом открываются одновременно, то есть лестницы в этом месте нет — есть
	# два одинаковых достижения, и одно из них лишнее.
	var same : Array = []
	for leg in by_leg:
		var goals : Dictionary = {}
		for s in by_leg[leg]:
			var g : int = int(s["goal"])
			if goals.has(g):
				same.append("%s: %d дважды" % [leg, g])
			goals[g] = true
	_check(same.is_empty(), "порог внутри лестницы не повторяется: %s" % [same])

# ── Потолок Apple ────────────────────────────────────────────────────────────

func _test_apple() -> void:
	var n : int = ACH.ALL.size()
	_check(n <= 100, "достижений не больше ста: %d" % n)
	# Очки считаются по ВСЕМУ списку, включая зарезервированное. Бюджет за ним
	# держится: снимешь его двадцать очков — потратишь на что-то другое, а потом
	# при заведении окажешься за тысячей.
	var pts : int = ACH.total_points()
	_check(pts <= 1000, "очков не больше тысячи: %d" % pts)
	var over : Array = []
	for a in ACH.ALL:
		if ACH.points(a) > 100:
			over.append(String(a["id"]))
	_check(over.is_empty(), "ни одно не дороже ста очков: %s" % [over])

	# ЗАРЕЗЕРВИРОВАННОЕ не уходит в App Store Connect. Проверка нужна потому, что
	# ошибка здесь необратима: в Game Center достижение у игрока не отзывается,
	# и заведённое по недосмотру останется у всех навсегда. Одна забытая строка в
	# скрипте выгрузки — и вернуть уже нечего.
	var reg : Array = ACH.registerable()
	var leaked : Array = []
	for a in reg:
		if bool(a.get("reserved", false)):
			leaked.append(String(a["id"]))
	_check(leaked.is_empty(), "зарезервированное не попадает в выгрузку: %s" % [leaked])
	_check(reg.size() < ACH.ALL.size(),
		"и выгрузка короче списка: %d из %d" % [reg.size(), ACH.ALL.size()])

	# Зарезервированное не может стоять в ПЕРВОЙ волне: волна — это «когда
	# делаем», резерв — «пока не делаем вовсе», и одновременно они не бывают.
	var both : Array = []
	for a in ACH.ALL:
		if bool(a.get("reserved", false)) and int(a["wave"]) == 1:
			both.append(String(a["id"]))
	_check(both.is_empty(), "резерв не заявлен первой волной: %s" % [both])

# ── Счётчики ─────────────────────────────────────────────────────────────────
# Связь «таблица ↔ хуки» в обе стороны. Оба перекоса тихие: достижение с
# несчитаемым счётчиком просто никогда не выпадает, а счётчик без достижения
# считается впустую.

# Счётчики с двоеточием собираются СКЛЕЙКОЙ: `bump("item:" + tag)`. Литералом
# такое имя в коде не встречается никогда, и искать его целиком бессмысленно —
# ищем ХВОСТ, то есть само имя предмета, босса или мини-игры.
const JOINED_PREFIXES : Array = ["item:", "spell_hits:", "death_by:",
	"boss_nodmg:", "minigame:"]

func _sources() -> String:
	var out := ""
	var d := DirAccess.open("res://scripts")
	if d == null:
		return out
	for f in d.get_files():
		if not f.ends_with(".gd"):
			continue
		var fa := FileAccess.open("res://scripts/" + f, FileAccess.READ)
		if fa != null:
			out += fa.get_as_text()
	return out

func _test_stats() -> void:
	var src := _sources()
	_check(src.length() > 10000, "исходники прочитаны: %d символов" % src.length())

	# 1. Каждый счётчик кто-то считает.
	var orphans : Array = []
	for a in ACH.ALL:
		var st : String = String(a["stat"])
		var needle := st
		for pref in JOINED_PREFIXES:
			if st.begins_with(pref):
				needle = st.substr(pref.length())
				break
		if not src.contains('"' + needle + '"'):
			orphans.append("%s (%s)" % [String(a["id"]), st])
	_check(orphans.is_empty(), "у каждого счётчика есть кто-то считающий: %s" % [orphans])

	# 2. Каждый `bump`/`set_max`/`mark` попадает хоть в одно достижение.
	#    Разбираем ТОЛЬКО менеджер и только вызовы с литералом: склеенные имена
	#    проверены выше с другой стороны.
	var fa := FileAccess.open(MANAGER_SRC, FileAccess.READ)
	_check(fa != null, "менеджер читается с диска")
	if fa == null:
		return
	var known : Dictionary = {}
	for a in ACH.ALL:
		known[String(a["stat"])] = true
	var stray : Array = []
	var seen_calls := 0
	for line in fa.get_as_text().split("\n"):
		var t : String = line.strip_edges()
		if t.begins_with("#"):
			continue
		for fn in ["bump(\"", "set_max(\"", "mark(\""]:
			var at : int = t.find(fn)
			if at < 0:
				continue
			var from : int = at + fn.length()
			var to : int = t.find("\"", from)
			if to < 0:
				continue
			var name : String = t.substr(from, to - from)
			# Хвост склейки (`bump("item:" + tag)`) счётчиком не является:
			# целиком имя собирается в рантайме, и проверено оно с другой
			# стороны — по хвосту в исходниках.
			if name.ends_with(":"):
				continue
			seen_calls += 1
			if not known.has(name):
				stray.append(name)
	_check(seen_calls >= 30, "вызовов счётчиков в менеджере: %d" % seen_calls)
	_check(stray.is_empty(), "каждый счётчик менеджера кому-то нужен: %s" % [stray])

# ── Менеджер ─────────────────────────────────────────────────────────────────

func _test_manager() -> void:
	var am : Node = get_root().get_node_or_null("AchievementManager")
	_check(am != null, "менеджер поднят автозагрузкой")
	if am == null:
		return
	am.call("dev_reset")

	# ДАРОМ НЕ ВЫДАНО НИЧЕГО. Проверять «после сброса пусто» нельзя: `dev_reset`
	# заново раздаёт задним числом, и на машине разработчика сейв не пустой —
	# первый вариант этой проверки на том и упал, причём на верных данных.
	# Настоящее свойство другое: у каждого выданного счётчик добит до порога.
	var free_ones : Array = []
	for a in ACH.ALL:
		if bool(am.call("is_done", a)) and int(am.call("value", String(a["stat"]))) < int(a["goal"]):
			free_ones.append(String(a["id"]))
	_check(free_ones.is_empty(), "даром не выдано ничего: %s" % [free_ones])

	# ЛЕСТНИЦА. Ставим счётчик на порог средней ступени — обязаны открыться она
	# и все, что ниже, и ни одной выше. Ровно это и есть смысл лестницы, и
	# ровно на этом падал первый мок.
	am.call("set_max", "pizzas_total", 10000)
	_check(bool(am.call("is_done", ACH.by_id("pizza_1k"))), "1 000 пицц взято")
	_check(bool(am.call("is_done", ACH.by_id("pizza_10k"))), "10 000 пицц взято")
	_check(not bool(am.call("is_done", ACH.by_id("pizza_50k"))), "50 000 — ещё нет")

	# Счётчик ТОЛЬКО РАСТЁТ. Отката в Game Center не бывает: меньший процент он
	# игнорирует, и игра, откатившая счётчик, разошлась бы с ним навсегда.
	am.call("set_max", "pizzas_total", 5)
	_check(int(am.call("value", "pizzas_total")) == 10000,
		"счётчик не откатывается: %d" % int(am.call("value", "pizzas_total")))
	_check(bool(am.call("is_done", ACH.by_id("pizza_10k"))), "и взятое не отбирается")

	# Полоска и счётчик не спорят с признаком «взято».
	var bad : Array = []
	for a in ACH.ALL:
		var done : bool  = am.call("is_done", a)
		var c    : int   = am.call("counter", a)
		var pr   : float = am.call("progress", a)
		if done and (c < int(a["goal"]) or pr < 1.0):
			bad.append("%s: взято при %d из %d" % [String(a["id"]), c, int(a["goal"])])
		elif not done and (c >= int(a["goal"]) or pr >= 1.0):
			bad.append("%s: не взято при %d из %d" % [String(a["id"]), c, int(a["goal"])])
	_check(bad.is_empty(), "счётчик не спорит с признаком «взято»: %s" % [bad])

	# Шапка сходится со списком: расхождение — первое, что видно на экране.
	var sm : Dictionary = am.call("summary")
	var rows := 0
	var pts  := 0
	for a in ACH.ALL:
		if bool(am.call("is_done", a)):
			rows += 1
			pts  += ACH.points(a)
	_check(int(sm["done"]) == rows, "шапка сходится со списком: %d и %d" % [int(sm["done"]), rows])
	_check(int(sm["points"]) == pts, "очки в шапке — те же: %d и %d" % [int(sm["points"]), pts])
	_check(int(sm["points_all"]) == ACH.total_points(), "и потолок очков — из таблицы")

	# РАЗДАЧА ЗАДНИМ ЧИСЛОМ. Игрок с 40 000 пицц обязан получить бронзу и
	# серебро сразу, а золото — нет. Проверяется на живом сейве, потому что
	# именно так это и случится: не «первым запуском по флажку», а пересчётом.
	# SaveData — тоже автозагрузка, и по имени она здесь не видна (см. выше).
	var sd : Node = get_root().get_node_or_null("SaveData")
	if sd == null:
		return
	var was : int = int(sd.get("total_pizzas"))
	sd.set("total_pizzas", 40000)
	am.call("dev_reset")
	_check(bool(am.call("is_done", ACH.by_id("pizza_1k")))
		and bool(am.call("is_done", ACH.by_id("pizza_10k")))
		and not bool(am.call("is_done", ACH.by_id("pizza_50k"))),
		"задним числом выдано ровно заслуженное")
	# И БЕЗ ПЛАШЕК. Десяток достижений разом при первом запуске после обновления
	# — это не праздник, а очередь плашек, которую игрок пережидает. Само по себе
	# оно и так молчит (раздача идёт раньше, чем интерфейс подпишется на сигнал),
	# но это совпадение порядка загрузки, а не решение.
	_check((am.call("pending") as Array).is_empty(),
		"задним числом — молча, без очереди плашек")

	sd.set("total_pizzas", was)
	am.call("dev_reset")

# ── Зеркало платформы ────────────────────────────────────────────────────────
# Главное свойство зеркала: БЕЗ НЕГО ВСЁ РАБОТАЕТ. Здесь его заведомо нет — не
# iOS, — и проверяем мы именно это: игра не должна ни падать, ни менять
# поведение оттого, что Game Center недоступен. «Работает только у
# залогиненных» — поломка, которую на своём устройстве не увидишь.

func _test_backend() -> void:
	var am : Node = get_root().get_node_or_null("AchievementManager")
	if am == null:
		return
	var be = am.get("backend")
	_check(be != null, "зеркало заведено")
	if be == null:
		return
	_check(not bool(be.call("available")), "на не-iOS зеркала нет — и это не ошибка")

	# Идентификатор собирается из ОДНОЙ константы и совпадает с тем, что заводит
	# dev/tools/push_achievements.py. Разойтись им нельзя: сменённый id — это
	# новое достижение, а старое остаётся у игроков висеть навсегда.
	_check(String(be.call("vendor_id", "pizza_1k")) == "com.normaldo.mobapp.ach.pizza_1k",
		"идентификатор для Apple: %s" % String(be.call("vendor_id", "pizza_1k")))

	# Копит и отдаёт молча. Отправка без плагина обязана быть пустой операцией,
	# а не ошибкой на каждый забег.
	#
	# Очередь чистим: предыдущий блок теста двигал счётчики, а зеркало на них и
	# подписано — в ней уже лежат настоящие проценты.
	be.call("flush")
	be.call("submit", "pizza_1k", 42.0)
	be.call("submit", "pizza_1k", 10.0)
	var q : Dictionary = be.get("_queue")
	_check(q.size() == 1 and is_equal_approx(float(q["pizza_1k"]), 42.0),
		"в очереди больший процент, меньший отброшен: %s" % [q])
	be.call("flush")
	_check((be.get("_queue") as Dictionary).is_empty(), "после отправки очередь пуста")

	# ЗАРЕЗЕРВИРОВАННОЕ В ЗЕРКАЛО НЕ УХОДИТ: в App Store Connect его нет, и
	# отправлять процент по несуществующему идентификатору некуда.
	am.call("_mirror", ACH.by_id("campaign"))
	_check((be.get("_queue") as Dictionary).is_empty(),
		"зарезервированное в зеркало не попадает")

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
