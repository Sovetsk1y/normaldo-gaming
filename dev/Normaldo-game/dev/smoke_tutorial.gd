extends SceneTree

# Headless smoke-тест обучения.
#   godot --headless --script dev/smoke_tutorial.gd
#
# Проверяются ОБЕЩАНИЯ, а не строки: такт кончается действием игрока, а не
# временем; в обучении нельзя умереть, но жир теряется; поток всё это время
# молчит и возвращается целым; пропуск отпускает забег так же чисто, как
# нормальный конец; и второй раз обучение не заводится.
#
# Игрок здесь ненастоящий: тесту незачем возить палец, ему надо убедиться, что
# такт сдвигается ровно от того, о чём просили.

# ЗАГРУЖАЕТСЯ ЛЕНИВО, А НЕ `preload`-ом. Скрипт обучения ссылается на автолоады
# (`SaveData`, `SafeArea`), а те появляются ПОЗЖЕ, чем разбирается сам тест:
# `preload` компилировал бы его в момент, когда их ещё нет, ронял компиляцию и
# оставлял в кеше сломанный ресурс — первая же игра заводилась бы без обучения,
# а следующие с ним. Ровно так этот тест и падал: «на первом забеге обучение
# завелось» — FAIL, а все остальные проверки зелёные.
var _tut_script : GDScript = null

func _tut() -> GDScript:
	if _tut_script == null:
		_tut_script = load("res://scripts/tutorial.gd") as GDScript
	return _tut_script

func _beats() -> Array:
	return _tut().get_script_constant_map().get("BEATS", [])

# Есть ли ГДЕ-НИБУДЬ ВНУТРИ такая надпись. Облачко собирается из вложенных
# узлов, и спрашивать про подпись у самого облачка бесполезно.
func _has_text(n: Node, s: String) -> bool:
	if n == null:
		return false
	for c in n.get_children():
		# У большинства узлов свойства `text` нет вовсе, и `get` вернёт null —
		# приводить его к строке нельзя, это уже не проверка, а ошибка в обходе.
		var t = c.get("text")
		if t is String and t == s:
			return true
		if _has_text(c, s):
			return true
	return false

# Все ожидания в тесте ставятся С ЗАПАСОМ ОТ ОБРАТНОГО: проверка обязана падать,
# когда такт НЕ сдвинулся сам, а не когда он просто не успел. Сроки самих тактов
# тест не переписывает — он берёт их из BEATS и следит, чтобы они не разрослись.
const EXPECTED_CHECKS : int = 50

# Картинку грузить `preload`-ом можно: она ни на какие автолоады не смотрит.
const MENU_LOGO_TEX := preload("res://assets/ui/menu/logo.png")

var _fails  : int = 0
var _checks : int = 0

func _check(ok: bool, what: String) -> void:
	_checks += 1
	if ok:
		print("  ok   ", what)
	else:
		_fails += 1
		print("  FAIL ", what)

func _initialize() -> void:
	print("── Обучение заводится на первом забеге ──")
	await _test_starts_once()
	print("── Такт ждёт действия, а не таймера ──")
	await _test_beat_waits_for_action()
	print("── Поток молчит, пока идёт обучение ──")
	await _test_stream_silent()
	print("── Умереть нельзя, а вес теряется ──")
	await _test_no_death_but_fat_costs()
	print("── Пропуск отпускает забег целым ──")
	await _test_skip_releases()
	print("── Тур по меню: один раз и после забега ──")
	await _test_menu_tour()
	print("── Подсказки по поводу ──")
	await _test_menu_tips()
	print("── Подсветка панели гасит экран ──")
	await _test_fat_panel_dim()
	print("── Ничего выше третьей полосы ──")
	await _test_lane_floor()
	print("── Заставка запуска ──")
	await _test_splash()
	print("── Ведущая подсказка не смахивается ──")
	await _test_leading_tip()
	print("── Сценарий не врёт про себя ──")
	_test_script_sane()

	print("")
	if _checks < EXPECTED_CHECKS:
		_fails += 1
		print("ПРОВЕРОК ВСЕГО %d, А ЖДАЛИ %d — какая-то оборвалась"
			% [_checks, EXPECTED_CHECKS])
	if _fails == 0:
		print("ВСЁ ЗЕЛЁНОЕ (проверок: %d)" % _checks)
	else:
		print("ПРОВАЛОВ: ", _fails)
	quit(1 if _fails > 0 else 0)

# ── Общее ───────────────────────────────────────────────────────────────────

func _save() -> Node:
	return get_root().get_node_or_null("SaveData")

func _fresh_game(tutorial: bool) -> Array:
	# Кадр ПЕРЕД тем, как ставить флаг. Автолоад `SaveData` к этому моменту уже
	# в дереве, но его `_ready` — а с ним и чтение сейва с диска — случается на
	# первом холостом кадре. Поставленный раньше флаг тот перезаписывал бы
	# сохранённым, и первая же игра заводилась бы без обучения, а следующие с
	# ним: ровно так этот тест и падал одной-единственной проверкой.
	await process_frame
	_save().set("tutorial_done", not tutorial)
	var game : Node = load("res://scenes/game.tscn").instantiate()
	get_root().add_child(game)
	await process_frame
	get_root().get_tree().paused = false
	var hud : Node = game.get_node_or_null("HUD")
	hud.set("_play_from_menu", true)
	hud.call("_start_game")
	# Обучение заводится в конце `_start_game`, а тот идёт через интро.
	var t0 := Time.get_ticks_msec()
	while game.get_node_or_null("Tutorial") == null \
			and Time.get_ticks_msec() - t0 < 8000:
		await process_frame
	return [game, hud, game.get_node_or_null("Tutorial")]

func _tick(sec: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		get_root().get_tree().paused = false
		await process_frame

func _test_starts_once() -> void:
	var r : Array = await _fresh_game(true)
	_check(r[2] != null, "на первом забеге обучение завелось")
	(r[0] as Node).queue_free()
	await process_frame

	# Флаг проставлен — второй раз не заводится. Это и есть «один раз в жизни».
	var r2 : Array = await _fresh_game(false)
	_check(r2[2] == null, "а с проставленным флагом — нет")
	(r2[0] as Node).queue_free()
	await process_frame

# ГЛАВНОЕ ОБЕЩАНИЕ. Такт «веди пальцем» не должен кончаться сам: пока голову не
# увели, обучение стоит на нём. Проверяем обе стороны — что стоит, пока не
# ведут, и что трогается, как только повели.
func _test_beat_waits_for_action() -> void:
	var r : Array = await _fresh_game(true)
	var game : Node   = r[0]
	var tut  : Node   = r[2]
	var nd   : Node2D = game.get_node_or_null("Normaldo")
	if tut == null:
		_check(false, "обучение не завелось — такт проверить нечем")
		game.queue_free()
		await process_frame
		return

	# Первое слово появляется не мгновенно: обучение пропускает вперёд карточку
	# эпизода и баннер задания (см. `Tutorial.INTRO_WAIT`). Ждём его, а не
	# считаем секунды от старта, — иначе тест меряет длину заставки.
	var shown := await _wait_beat(tut, "move", 10.0)
	_check(shown, "первый такт — «веди пальцем»: %s" % [_beat_of(tut)])

	await _tick(3.0)
	_check(String(_beat_of(tut)) == "move",
		"и через три секунды без движения он всё тот же: %s" % [_beat_of(tut)])

	# Повели пальцем — на полторы полосы, больше порога в 60 px.
	nd.position.y = nd.position.y + 130.0
	var moved := await _wait_beat_change(tut, "move", 6.0)
	_check(moved, "увёл голову — такт сменился на «%s»" % [_beat_of(tut)])

	game.queue_free()
	await process_frame

# Пока идёт обучение, обычный поток обязан молчать: такт про мусор перестаёт
# быть тактом, если рядом летит ещё пять предметов.
func _test_stream_silent() -> void:
	var r : Array = await _fresh_game(true)
	var game : Node = r[0]
	var sp   : Node = game.get_node_or_null("Spawner")
	if r[2] == null:
		_check(false, "обучение не завелось — тишину проверить нечем")
		game.queue_free()
		await process_frame
		return
	await _tick(2.5)
	_check(not bool(sp.get("_frozen")) == false, "спавнер заморожен обучением")
	_check(not sp.is_processing(), "и не тикает — поток сам ничего не выдаёт")
	game.queue_free()
	await process_frame

# Удар обязан что-то стоить, иначе такт про мусор ничему не учит. Но смерти в
# обучении быть не должно.
func _test_no_death_but_fat_costs() -> void:
	var r : Array = await _fresh_game(true)
	var game : Node   = r[0]
	var nd   : Node2D = game.get_node_or_null("Normaldo")
	if r[2] == null:
		_check(false, "обучение не завелось — удар проверить нечем")
		game.queue_free()
		await process_frame
		return
	await _tick(1.0)
	_check(bool(nd.get("_dev_immortal")), "в обучении Нормальдо не убивается")

	# Толстый теряет состояние от удара — как в обычной игре.
	nd.set("fat_state", 2)
	nd.call("_take_hit", 1)
	await _tick(0.4)
	_check(int(nd.get("fat_state")) < 2,
		"но вес от удара теряет: %d" % [int(nd.get("fat_state"))])

	# А в скинни тот же удар не убивает.
	nd.set("fat_state", 0)
	nd.call("_take_hit", 1)
	await _tick(0.6)
	_check(not bool(nd.get("_dead")), "и в скинни удар не кончает забег")
	game.queue_free()
	await process_frame

# Пропуск — не «спрятать надписи», а вернуть забег: снять заморозку потока и
# неуязвимость. Незакрытая пауза означала бы поток, замороженный навсегда.
func _test_skip_releases() -> void:
	var r : Array = await _fresh_game(true)
	var game : Node   = r[0]
	var sp   : Node   = game.get_node_or_null("Spawner")
	var nd   : Node2D = game.get_node_or_null("Normaldo")
	var tut  : Node   = r[2]
	if tut == null:
		_check(false, "обучение не завелось — пропуск проверить нечем")
		game.queue_free()
		await process_frame
		return
	await _tick(1.0)
	tut.call("_skip")
	await _tick(0.6)
	_check(sp.is_processing(), "после пропуска поток снова идёт")
	_check(not bool(nd.get("_dev_immortal")), "и неуязвимость снята")
	_check(is_equal_approx(float(sp.get("world_speed_mult")), 1.0),
		"и время вернулось к обычному: ×%.2f" % [float(sp.get("world_speed_mult"))])
	_check(bool(_save().get("tutorial_done")),
		"а пропуск запомнен — переспрашивать не будем")
	game.queue_free()
	await process_frame

# ── ТУР ПО МЕНЮ ─────────────────────────────────────────────────────────────
# Три остановки, один раз в жизни, и только после того, как первый забег сыгран.
# Тур, вылезающий до первого забега, объясняет кнопки тому, кто ещё не знает,
# зачем они; тур, вылезающий каждый раз, — это модальное окно на входе в игру.
func _test_menu_tour() -> void:
	# Обучение пройдено, тур ещё не показан — самое начало второго захода.
	await process_frame
	_save().set("tutorial_done", true)
	_save().set("menu_tips_seen", {})
	_save().set("skin_progress", {"classic": {"runs": 3}})
	var game : Node = load("res://scenes/game.tscn").instantiate()
	get_root().add_child(game)
	await process_frame
	var hud : Node = game.get_node_or_null("HUD")
	var tour := await _wait_node(hud, "MenuTour", 9.0)
	_check(tour != null, "после первого забега тур завёлся")
	if tour != null:
		# Подсветка обязана попадать В КНОПКУ, а не в память о её месте:
		# раскладка меню считается от размера экрана.
		var vp : Vector2 = get_root().get_visible_rect().size
		var stops : Array = tour.get("_stops")
		var bad : Array = []
		for st in stops:
			var r : Rect2 = (st as Dictionary).get("rect", Rect2())
			if r.size.x <= 4.0 or r.size.y <= 4.0 \
					or not Rect2(Vector2.ZERO, vp).encloses(r):
				bad.append(r)
		_check(stops.size() == 3, "остановок ровно три: %d" % stops.size())
		_check(bad.is_empty(), "и каждая метит в живую кнопку на экране: %s" % [bad])
		# Прощёлкиваем до конца.
		for i in stops.size() + 1:
			if is_instance_valid(tour):
				tour.call("_show", i + 1)
			await process_frame
		_check(bool((_save().get("menu_tips_seen") as Dictionary).get("tour", false)),
			"пройденный тур запомнен")
	game.queue_free()
	await process_frame

	# И второй раз не заводится. Поводы для остальных кнопок при этом гасим:
	# проверяем здесь именно тур, а не то, что меню вообще молчит.
	_save().set("menu_tips_seen",
		{"tour": true, "slots": true, "leaders": true, "book": true, "awards": true})
	var game2 : Node = load("res://scenes/game.tscn").instantiate()
	get_root().add_child(game2)
	await process_frame
	var hud2 : Node = game2.get_node_or_null("HUD")
	var again := await _wait_node(hud2, "MenuTour", 3.0)
	_check(again == null, "а во второй раз меню молчит")
	game2.queue_free()
	await process_frame

# ── ПОДСКАЗКИ ПО ПОВОДУ ─────────────────────────────────────────────────────
# Проверяется не «всплыло окно», а само правило: подсказка появляется, КОГДА
# случился её повод, метит в свою кнопку, показывается по одной за заход и
# больше не возвращается.
func _test_menu_tips() -> void:
	await process_frame
	_save().set("tutorial_done", true)
	_save().set("skin_progress", {"classic": {"runs": 3}})
	# Книга и достижения гасятся сразу: их повод («открылась история», «есть
	# первое достижение») на прожитом сейве уже наступил, и проверять на них
	# «повода нет» нечестно. Остаются жетоны и таблица — их можно занулить.
	_save().set("menu_tips_seen", {"tour": true, "book": true, "awards": true})
	_save().set("tokens", 0)
	_save().set("mode_best", {})
	var quiet : Array = await _menu_with_tip(3.0)
	_check(quiet[1] == null, "без повода меню молчит")
	(quiet[0] as Node).queue_free()
	await process_frame

	# Упал жетон — вот и повод.
	_save().set("tokens", 3)
	var got : Array = await _menu_with_tip(8.0)
	var tip : Node = got[1]
	_check(tip != null, "упал жетон — подсказка про слоты пришла")
	if tip != null:
		_check(String(tip.get("_key")) == "slots",
			"и это именно она: «%s»" % [tip.get("_key")])
		var stops : Array = tip.get("_stops")
		_check(stops.size() == 1, "остановка ровно одна: %d" % stops.size())
		# ПО ОДНОЙ ЗА ЗАХОД: повод у «лидеров» тоже есть, но лезть вдвоём нельзя.
		tip.call("_show", 1)
		await process_frame
	(got[0] as Node).queue_free()
	await process_frame

	# Показанная — больше не возвращается, зато приходит следующая по поводу.
	_save().set("mode_best", {"ep1": 42})
	var next : Array = await _menu_with_tip(8.0)
	_check(next[1] != null and String((next[1] as Node).get("_key")) == "leaders",
		"следующий заход — следующая по поводу: «%s»"
		% [(next[1] as Node).get("_key") if next[1] != null else "молчит"])
	(next[0] as Node).queue_free()
	await process_frame

func _menu_with_tip(limit: float) -> Array:
	var game : Node = load("res://scenes/game.tscn").instantiate()
	get_root().add_child(game)
	await process_frame
	var hud : Node = game.get_node_or_null("HUD")
	return [game, await _wait_node(hud, "MenuTour", limit)]

func _wait_node(host: Node, name: String, limit: float) -> Node:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(limit * 1000.0):
		get_root().get_tree().paused = false
		await process_frame
		if not is_instance_valid(host):
			return null
		var n := host.get_node_or_null(name)
		if n != null:
			return n
	return null

# ── НИЧЕГО ВЫШЕ ТРЕТЬЕЙ ПОЛОСЫ ─────────────────────────────────────────────
# Облачко подсказки закрывает собой две верхние линии. Предмет, выданный туда,
# игрок не видит — а обучение, показывающее невидимое, учит ровно одному: что
# смотреть некуда.
#
# Проверяется САМ СПАВН, а не константа: попросили нулевую полосу — предмет
# обязан приехать не выше третьей.
func _test_lane_floor() -> void:
	var r : Array = await _fresh_game(true)
	var game : Node = r[0]
	var tut  : Node = r[2]
	var sp   : Node = game.get_node_or_null("Spawner")
	if tut == null:
		_check(false, "обучение не завелось — полосы проверить нечем")
		game.queue_free()
		await process_frame
		return
	var lanes : Array = sp.call("_lane_centers")
	var floor_y : float = float(lanes[2]) - 4.0
	var high : Array = []
	for lane in [0, 1, 2, 3, 4]:
		var it = tut.call("_send", "pizza", lane)
		if it == null:
			high.append("полоса %d: ничего не выдано" % lane)
			continue
		if (it as Node2D).position.y < floor_y:
			high.append("полоса %d → y=%.0f" % [lane, (it as Node2D).position.y])
	_check(high.is_empty(), "что ни попроси, приезжает не выше третьей: %s" % [high])
	game.queue_free()
	await process_frame

# ── ЗАСТАВКА ───────────────────────────────────────────────────────────────
# Две вещи, и обе про то, чтобы она никому не мешала: на сцене, поднятой руками
# (а так её поднимают все тесты и все снимки), заставка не заводится вовсе, а
# заведённая — уходит сама и не оставляет на экране ничего.
func _test_splash() -> void:
	var splash : GDScript = load("res://scripts/splash.gd") as GDScript
	var game : Node = load("res://scenes/game.tscn").instantiate()
	get_root().add_child(game)
	await process_frame
	var hud : Node = game.get_node_or_null("HUD")
	splash.set("_played", false)
	_check(not bool(splash.call("should_play", hud)),
		"на поднятой руками сцене заставка не заводится")

	# А заведённая — доигрывает и убирает себя.
	var sp = splash.call("play", hud)
	_check(sp != null and is_instance_valid(sp), "запущенная вручную — появилась")
	# ЛОГОТИП ОБЯЗАН ПРИЕХАТЬ НА МЕСТО МЕНЮШНОГО. Не приедет — на глазах у
	# игрока надпись прыгнет: копия заставки исчезнет в одном месте, настоящая
	# окажется в другом. Ловим последнее её положение перед тем, как заставка
	# себя уберёт.
	var last_logo := Vector2.INF
	var logo_node : Control = null
	# ДВУХ НАДПИСЕЙ НА ЭКРАНЕ НЕ БЫВАЕТ. Пока копия заставки едет из центра, своя
	# надпись меню обязана быть спрятана: сквозь гаснущее чёрное видны обе, и
	# главная встречает игрока двоящимся логотипом.
	var doubled : bool = false
	var t0 := Time.get_ticks_msec()
	while is_instance_valid(sp) and Time.get_ticks_msec() - t0 < 9000:
		get_root().get_tree().paused = false
		var lg = sp.get("_logo")
		if lg != null and is_instance_valid(lg):
			logo_node = lg as Control
			last_logo = logo_node.position
			var own = hud.get("_menu_logo")
			if own != null and is_instance_valid(own) and own != lg \
					and (own as CanvasItem).visible:
				doubled = true
		await process_frame
	_check(not doubled, "пока заставка ведёт надпись, второй на экране нет")
	_check(not is_instance_valid(sp),
		"и ушла сама за %.1f c" % [(Time.get_ticks_msec() - t0) / 1000.0])
	var home : Vector2 = (hud.call("menu_logo_rect") as Rect2).position
	_check(last_logo != Vector2.INF and last_logo.distance_to(home) < 4.0,
		"а логотип приехал на место меню'шного: %s против %s" % [last_logo, home])

	# НАДПИСЬ НЕ ПОДМЕНИЛАСЬ, А ОСТАЛАСЬ. Меню обязано забрать узел заставки
	# себе: две одинаковые надписи на одном месте совпадают только на слово, а
	# на телефоне с островком у слоёв разные системы координат — и подмена видна
	# прыжком ровно на величину отступа.
	_check(logo_node != null and is_instance_valid(logo_node)
			and hud.get("_menu_logo") == logo_node,
		"меню забрало надпись заставки себе, а не завело вторую")
	var logos : int = 0
	var ov = hud.get("_menu_overlay")
	if ov != null and is_instance_valid(ov):
		for c in (ov as Node).get_children():
			if c is TextureRect and (c as TextureRect).texture == MENU_LOGO_TEX:
				logos += 1
	_check(logos == 1, "и на главной ровно одна надпись, а не две (их %d)" % logos)
	game.queue_free()
	await process_frame

# ── ВЕДУЩАЯ ПОДСКАЗКА НЕ СМАХИВАЕТСЯ ───────────────────────────────────────
# «ДАВАЙ СРАЗУ К ДЕЛУ!» закрывается ТОЛЬКО тапом по зоне запуска, и тот же тап
# начинает забег. Её задача не сообщить, а довести до первой игры: закрываемая
# тапом куда попало, она смахивается вслепую, и игрок остаётся ровно в том
# меню, из которого его уводили.
func _test_leading_tip() -> void:
	await process_frame
	var game : Node = load("res://scenes/game.tscn").instantiate()
	get_root().add_child(game)
	await process_frame
	get_root().get_tree().paused = false
	var hud : Node = game.get_node_or_null("HUD")
	var t0 := Time.get_ticks_msec()
	while (hud.call("menu_play_rect") as Rect2).size.x <= 1.0 \
			and Time.get_ticks_msec() - t0 < 9000:
		get_root().get_tree().paused = false
		await process_frame

	var fired : Array = [false]
	var tour = MenuTour.play(hud, [{
		"rect": hud.call("menu_play_rect"), "big": "ДАВАЙ", "small": "сюда",
	}], "start_test", func() -> void: fired[0] = true)
	await process_frame
	_check(tour != null and is_instance_valid(tour), "ведущая подсказка появилась")

	# СМАХНУТЬ НЕЧЕМ. У обычного тура поверх экрана лежит кнопка во весь
	# viewport — тап куда угодно листает дальше. У ведущей такой быть не должно:
	# единственная кнопка обязана совпадать с подсвеченной зоной, а всё
	# остальное — глухо есть ввод.
	var zone : Rect2 = hud.call("menu_play_rect")
	var vp : Vector2 = get_root().get_visible_rect().size
	var hit : Button = null
	var wide : int = 0
	for c in (tour.get("_body") as Node).get_children():
		if not (c is Button):
			continue
		var b := c as Button
		if b.size.x >= vp.x - 1.0 and b.size.y >= vp.y - 1.0:
			wide += 1
		elif b.position.distance_to(zone.position) < 2.0:
			hit = b
	_check(wide == 0, "кнопки во весь экран у неё нет — смахнуть нечем")
	_check(hit != null, "а кнопка стоит ровно на подсвеченной зоне")
	# И НЕ ОБЕЩАЕТ ТОГО, ЧЕГО НЕ УМЕЕТ. «ПОНЯТНО» под текстом читается как «ткни
	# сюда, и я закроюсь», а закрыться она может ровно одним способом.
	_check(not _has_text(tour.get("_body") as Node, "ПОНЯТНО"),
		"«ПОНЯТНО» на ней не написано — закрывать её нечем, кроме зоны")
	if hit != null:
		hit.pressed.emit()
		await process_frame
		_check(not is_instance_valid(tour), "тап по зоне её закрыл")
		_check(fired[0], "и тем же тапом позвал начать забег")
	game.queue_free()
	await process_frame

# ── Сам сценарий ────────────────────────────────────────────────────────────
# Такт без слов — это пауза посреди игры, у которой игрок не понимает причины.
# Такт без срока страховки — возможность зависнуть навсегда.
# ── ПОДСВЕТКА ПАНЕЛИ ГАСИТ ЭКРАН ───────────────────────────────────────────
# Рамка вокруг полосы веса рисуется поверх ЖИВОГО забега: фон едет, мимо летит
# пицца, и взгляд к маленькой рамке в углу не идёт.
#
# Но забег в эти секунды продолжается, и потому затемнение обязано быть
# СКВОЗНЫМ ДЛЯ ВВОДА и лежать ПОД подсказкой. Съевшее тап затемнение роняет
# игрока на мусор ровно за то, что он послушался и стал читать; легшее поверх
# гасит как раз то, ради чего его включили.
func _test_fat_panel_dim() -> void:
	var r : Array = await _fresh_game(true)
	var game : Node = r[0]
	var tut  : Node = r[2]
	if tut == null:
		_check(false, "обучение не завелось — затемнение проверить нечем")
		game.queue_free()
		await process_frame
		return
	tut.call("_ring_fat_panel")
	await process_frame
	var ring = tut.get("_ring")
	var dim  = tut.get("_dim")
	_check(ring != null and is_instance_valid(ring), "панель веса обведена")
	_check(dim != null and is_instance_valid(dim), "и экран при этом затемнён")
	if dim != null and is_instance_valid(dim):
		var vp : Vector2 = get_root().get_visible_rect().size
		var d := dim as Control
		_check(d.size.x >= vp.x - 1.0 and d.size.y >= vp.y - 1.0,
			"на весь экран: %s против %s" % [d.size, vp])
		_check(d.mouse_filter == Control.MOUSE_FILTER_IGNORE,
			"ввода не ест — забег в эти секунды идёт как шёл")
		_check(d.get_index() == 0, "и лежит под подсказкой, а не поверх неё")
	game.queue_free()
	await process_frame

func _test_script_sane() -> void:
	var beats : Array = _beats()
	_check(beats.size() >= 5, "тактов в сценарии: %d" % beats.size())
	var mute : Array = []
	var endless : Array = []
	var ids : Dictionary = {}
	for b in beats:
		var d : Dictionary = b
		ids[String(d.get("id", ""))] = true
		if String(d.get("big", "")).strip_edges() == "":
			mute.append(d.get("id", "?"))
		if float(d.get("limit", 0.0)) <= 0.0:
			endless.append(d.get("id", "?"))
	_check(mute.is_empty(), "у каждого есть слова: %s" % [mute])
	_check(endless.is_empty(), "и срок страховки: %s" % [endless])
	# ── И СРОК ЭТОТ КОРОТКИЙ ─────────────────────────────────────────────────
	# Срок — потолок ЗАВИСАНИЯ: всё это время на экране висит одна и та же
	# надпись и не происходит ничего. Часы заводятся уже ПОСЛЕ подачи (см. BEATS),
	# то есть считают ровно то время, когда выдавать больше нечего.
	#
	# На такте про вес тут стояло 22 секунды, и с этим пришли словами «слишком
	# долго висим в таком состоянии». Двадцать две секунды неподвижной подсказки
	# читаются не как «подожди», а как «игра сломалась».
	var slow : Array = []
	for b in beats:
		var d : Dictionary = b
		if float(d.get("limit", 0.0)) > 20.0:
			slow.append([d.get("id", "?"), d.get("limit", 0.0)])
	_check(slow.is_empty(), "и ни один не даёт себе висеть дольше 20 с: %s" % [slow])
	_check(ids.size() == beats.size(), "и такты не повторяются: %d имён на %d"
		% [ids.size(), beats.size()])
	# Управление — раньше всего. Такт про еду, поставленный перед тактом про
	# палец, учит есть того, кто ещё не умеет двигаться.
	_check(String((beats[0] as Dictionary).get("id", "")) == "move",
		"а первым идёт управление: «%s»" % [(beats[0] as Dictionary).get("id", "")])
	# И ПОСЛЕДНИМ — ПРОЩАНИЕ. Обучение, обрывающееся на середине задания,
	# оставляет игрока ждать следующей подсказки вместо того, чтобы играть.
	var last : Dictionary = beats[beats.size() - 1]
	_check(String(last.get("id", "")) == "done",
		"а последним — прощание: «%s»" % [last.get("id", "")])

# ── Мелочи ──────────────────────────────────────────────────────────────────

# Какой такт идёт сейчас — по надписи на экране. Спрашивать поле нельзя: его
# нет, и заводить его ради теста значило бы проверять не то, что видит игрок.
func _beat_of(tut: Node) -> String:
	var cap = tut.get("_caption")
	if cap == null or not is_instance_valid(cap):
		return ""
	for c in (cap as Node).get_children():
		if c is Label:
			var txt := String((c as Label).text)
			for b in _beats():
				if String((b as Dictionary).get("big", "")) == txt:
					return String((b as Dictionary).get("id", ""))
	return "?"

# Дождаться, пока пойдёт нужный такт.
func _wait_beat(tut: Node, want: String, limit: float) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(limit * 1000.0):
		get_root().get_tree().paused = false
		await process_frame
		if not is_instance_valid(tut):
			return false
		if _beat_of(tut) == want:
			return true
	return false

func _wait_beat_change(tut: Node, from: String, limit: float) -> bool:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(limit * 1000.0):
		get_root().get_tree().paused = false
		await process_frame
		if not is_instance_valid(tut):
			return true
		var now := _beat_of(tut)
		if now != from and now != "":
			return true
	return false
