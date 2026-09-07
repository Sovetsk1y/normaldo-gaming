extends SceneTree

# Headless-проверка редкого ивента «стена пиццы».
#   godot --headless --path . --script res://dev/smoke_pizza_wall.gd
#
# Ивент из оригинала: во все пять линий уходит колонна ЗАМЕДЛЯЮЩИХ предметов
# текущего уровня, а следом вдвое быстрее идёт сплошная стена пиццы и нагоняет
# её на экране.
#
# Ломается он тремя способами, и все три тихие:
#   1. Стена перестаёт быть быстрее колонны — тогда это просто две колонны
#      подряд, и никакой погони на экране нет.
#   2. Стена выходит без форы и нагоняет колонну за краем экрана — игрок видит
#      либо только замедляющие, либо только пиццу, но не встречу.
#   3. Ивент перестаёт быть редким — кулдаун снимают, и «раз в две минуты»
#      превращается в «каждый восьмой сет-пис».
#
# См. scripts/spawner.gd (_setpiece_pizza_wall), /Концепция/Паттерны препятствий.md

var _fails  : int = 0
var _checks : int = 0
const EXPECTED_CHECKS : int = 24

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
	var sp : Node = game.get_node_or_null("Spawner")
	var n  : Node = game.get_node_or_null("Normaldo")
	sp.call("clear_items")
	sp.set_process(false)
	n.set("_dev_immortal", true)
	await process_frame

	var vp : Vector2 = get_root().get_visible_rect().size
	var lanes : Array = []
	for i in 5:
		lanes.append(vp.y * (float(i) + 0.5) / 5.0)

	# ── РЕДКОСТЬ ────────────────────────────────────────────────────────────
	# Главное свойство ивента — что он редкий. Сет-писы из пула выпадают
	# равновероятно, поэтому «редкость» здесь живёт отдельным кулдауном, и
	# проверять её надо ВЫБОРОМ, а не наличием константы: константу легко
	# объявить и не подключить.
	print("── Редкость ──")
	var pool : Array = sp.CAMPAIGN_DIRECTOR[3]["sp"]
	_check(pool.has("pizza_wall"), "ивент есть в пуле поздних фаз")
	_check(sp.HARDCORE_SET_PIECES.has("pizza_wall"), "и в хвосте тоже")

	var cd : float = float(sp.SP_RARE_COOLDOWN["pizza_wall"])
	sp.set("_elapsed", cd * 0.5)
	sp.set("_sp_last_at", {})
	var early := 0
	for i in 400:
		sp.set("_last_sp_id", "")
		if String(sp.call("_pick_set_piece", pool)) == "pizza_wall":
			early += 1
	_check(early == 0,
		"до первого кулдауна (%.0f c) не выпадает ни разу за 400 выборов: %d" % [cd, early])

	sp.set("_elapsed", cd * 2.0)
	sp.set("_sp_last_at", {})
	var late := 0
	for i in 400:
		sp.set("_last_sp_id", "")
		if String(sp.call("_pick_set_piece", pool)) == "pizza_wall":
			late += 1
	_check(late > 0, "после кулдауна выпадает: %d раз за 400 выборов" % late)

	# И ПОСЛЕ показа снова уходит в кулдаун — иначе «редкий» означало бы только
	# «не в первую минуту», а дальше он лез бы наравне со всеми.
	sp.set("_sp_last_at", {"pizza_wall": cd * 2.0})
	var again := 0
	for i in 400:
		sp.set("_last_sp_id", "")
		if String(sp.call("_pick_set_piece", pool)) == "pizza_wall":
			again += 1
	_check(again == 0, "и сразу после показа снова недоступен: %d" % again)

	# ── ДЕВ-КНОПКА ──────────────────────────────────────────────────────────
	# У редкого ивента она не роскошь: до 75-й секунды он не выпадает по
	# определению, и «посмотреть глазами» без кнопки означает доиграть до поздней
	# фазы и надеяться. Проверяется и то, что кнопка ПОДПИСАНА: ряд состоит из
	# одинаковых тёмных квадратов с иконками 36×36, и пицца на кнопке «стена»
	# ничем не отличается от пиццы на кнопке «дать пиццы».
	print("── Дев-кнопка ──")
	var hud : Node = game.get_node_or_null("HUD")
	hud.call("_build_dev_pizza_wall_btn")
	await process_frame
	var caps : Array = []
	_labels(hud, caps)
	_check(caps.has("СТЕНА"), "кнопка подписана и её видно в ряду")
	_check(sp.has_method("dev_send_pizza_wall"), "и зовёт тот же сет-пис")

	# ── ЗАМЕДЛЯЮЩИЕ БЕРУТСЯ ИЗ РАСКЛАДКИ УРОВНЯ ─────────────────────────────
	# Не из отдельного списка: второй список разъезжается с первым в первую же
	# правку раскладки. Поэтому сверяется НАБОР против таблицы уровня.
	print("── Замедляющие текущего уровня ──")
	sp.set("_hardcore", false)
	sp.set("level", 0)
	var k0 : Array = sp.call("_level_slowing_kinds")
	_check(k0 == ["banana"], "канализация — банан: %s" % [k0])
	sp.set("level", 1)
	var k1 : Array = sp.call("_level_slowing_kinds")
	_check(k1.has("beer") and k1.has("banana"), "река — пиво и банан: %s" % [k1])
	sp.set("level", 4)
	var k4 : Array = sp.call("_level_slowing_kinds")
	_check(k4.has("cocktail"), "клуб — коктейль: %s" % [k4])
	# Двор — единственный уровень БЕЗ замедляющих в таблице. Пустой набор здесь
	# означал бы колонну из ничего, то есть стену пиццы без платы за неё.
	sp.set("level", 3)
	var k3 : Array = sp.call("_level_slowing_kinds")
	_check(not k3.is_empty(), "на уровне без замедляющих набор не пустой: %s" % [k3])

	# ── КОЛОННА ─────────────────────────────────────────────────────────────
	print("── Колонна замедляющих ──")
	sp.set("level", 0)
	# Разморозка ПОСЛЕ зачистки, а не до: `clear_items()` сам ставит `_frozen`
	# (забег остановлен, пока поток не запустили заново).
	sp.call("clear_items")
	sp.set("_frozen", false)
	await process_frame
	var speed : float = 250.0
	sp.call("_setpiece_pizza_wall", speed, lanes, vp.x)
	await process_frame

	var slow : Array = _group(sp, "slowing")
	_check(slow.size() == 5, "замедляющие ушли во все пять линий: %d" % slow.size())
	var lanes_hit : Array = []
	for s in slow:
		for i in lanes.size():
			if absf((s as Node2D).position.y - float(lanes[i])) < 4.0 and not lanes_hit.has(i):
				lanes_hit.append(i)
	_check(lanes_hit.size() == 5, "и каждая линия занята ровно один раз: %s" % [lanes_hit])
	_check(_pizzas(sp).is_empty(), "а пиццы пока нет — колонна идёт первой")

	var slow_speed : float = float(slow[0].get("speed"))
	_check(absf(slow_speed - speed) < 1.0,
		"колонна летит со скоростью потока: %.0f против %.0f" % [slow_speed, speed])

	# ── СТЕНА ───────────────────────────────────────────────────────────────
	# Ждём форы плюс запас на один такт: фора считается от ширины экрана и
	# скорости, а не константой, поэтому и здесь она считается тем же способом.
	print("── Стена пиццы ──")
	var lead : float = float(sp.call("_pizza_wall_lead", speed, vp.x))
	var waited : float = await _await_pizza(sp, lead * 2.0 + 1.0)
	var pz : Array = _pizzas(sp)
	_check(pz.size() >= 5, "стена пошла: пицц %d" % pz.size())
	if pz.is_empty():
		_finish()
		return
	# Фора ОТРАБОТАЛА: стена вышла не сразу вслед за колонной. Без неё она
	# нагоняла бы её ещё за краем экрана, и никакой погони игрок бы не увидел.
	_check(waited > lead * 0.7,
		"и не сразу, а с форой: ждали %.2f c при расчётной %.2f" % [waited, lead])

	var pz_speed : float = float(pz[0].get("speed"))
	_check(absf(pz_speed - speed * float(sp.PIZZA_WALL_SPEED_MULT)) < 1.0,
		"и летит ВДВОЕ быстрее колонны: %.0f против %.0f" % [pz_speed, slow_speed])

	# Встреча обязана случиться В КАДРЕ. Сближаются они со скоростью разницы, то
	# есть за `x_slow - x_pizza` пикселей делённые на `speed` секунд; за это же
	# время колонна проедет столько же — и обязана остаться правее левого края.
	var x_slow  : float = _min_x(slow)
	var x_pizza : float = _max_x(pz)
	var t_meet  : float = maxf(0.0, x_pizza - x_slow) / maxf(1.0, pz_speed - slow_speed)
	var x_at_meet : float = x_slow - slow_speed * t_meet
	_check(x_at_meet > 0.0 and x_at_meet < vp.x,
		"стена нагоняет колонну В КАДРЕ: встреча на x=%.0f через %.2f c"
			% [x_at_meet, t_meet])
	# И не «где-нибудь в кадре», а там, где обещано константой: точка встречи —
	# это и есть содержание ивента, и уехавшая к самому краю читалась бы уже как
	# две отдельные волны.
	var want : float = float(sp.PIZZA_WALL_MEET_X) * vp.x
	_check(absf(x_at_meet - want) < vp.x * 0.12,
		"и ровно там, где обещано: %.0f против %.0f" % [x_at_meet, want])

	# Пицца — еда, а не угроза: стена задумана призом за то, что игрок прошёл
	# колонну не замедлившись. Ударяющая стена в пять линий была бы приговором.
	var food_ok := true
	for p in pz:
		if int(p.get("damage")) != 0 or not bool(p.get("is_eatable")):
			food_ok = false
	_check(food_ok, "вся стена съедобна и не бьёт")

	await _wait(0.9)
	var wide : Array = []
	for p in _pizzas(sp):
		for i in lanes.size():
			if absf((p as Node2D).position.y - float(lanes[i])) < 4.0 and not wide.has(i):
				wide.append(i)
	_check(wide.size() == 5, "стена сплошная — все пять линий: %s" % [wide])

	# ── ЗАМОРОЗКА ───────────────────────────────────────────────────────────
	# Сет-пис ждёт таймерами, а забег в это время может встать (босс, мини-игра).
	# Стена, которая продолжает сыпаться в замороженный поток, — это предметы,
	# летящие поверх остановленной игры.
	print("── Заморозка ──")
	# Сперва дать ДОБЕЖАТЬ предыдущему сет-пису. Он висит на таймерах и выходит
	# сам, упёршись в заморозку, — а `clear_items()` её как раз и ставит. Снять
	# заморозку раньше значило бы разбудить старую стену, и её пицца сошла бы за
	# новую: именно так эта проверка и падала, показывая «в замороженном потоке
	# вышло 4 пиццы», которых никто не спавнил.
	sp.call("clear_items")
	await _wait(float(sp.PIZZA_WALL_COLS_MAX) * 0.2 + 0.4)
	sp.call("clear_items")
	sp.set("_frozen", false)
	await process_frame
	_check(_pizzas(sp).is_empty(), "поток чист перед проверкой заморозки")
	sp.call("_setpiece_pizza_wall", speed, lanes, vp.x)
	await process_frame
	sp.set("_frozen", true)
	await _wait(lead + 0.6)
	_check(_pizzas(sp).is_empty(),
		"в замороженном потоке стена не выходит: пицц %d" % _pizzas(sp).size())

	_finish()

func _labels(node: Node, out: Array) -> void:
	if node is Label and String((node as Label).text) != "":
		out.append(String((node as Label).text))
	for c in node.get_children():
		_labels(c, out)

func _group(sp: Node, g: String) -> Array:
	var out : Array = []
	for c in sp.get_children():
		if c is Node2D and (c as Node).is_in_group(g):
			out.append(c)
	return out

func _pizzas(sp: Node) -> Array:
	var out : Array = []
	var tex : Texture2D = load("res://assets/items/pizza.png")
	for c in sp.get_children():
		var s := c.get_node_or_null("Sprite2D") as Sprite2D
		if s != null and s.texture == tex:
			out.append(c)
	return out

func _min_x(nodes: Array) -> float:
	var v : float = 1e9
	for nd in nodes:
		v = minf(v, (nd as Node2D).position.x)
	return v

func _max_x(nodes: Array) -> float:
	var v : float = -1e9
	for nd in nodes:
		v = maxf(v, (nd as Node2D).position.x)
	return v

# Ждём НАСТОЯЩИЕ секунды, а не кадры. Сет-пис отмеряет форy и такты через
# `SceneTree.create_timer`, то есть по реальному времени, а в headless кадры
# идут не по 1/60: отсчёт кадрами разошёлся бы с таймерами сет-писа, и тест
# мерил бы «до», думая, что мерит «после».
func _wait(sec: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		await process_frame

# Дождаться первой пиццы, но не дольше `limit`. Возвращает, сколько ждали.
func _await_pizza(sp: Node, limit: float) -> float:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(limit * 1000.0):
		if not _pizzas(sp).is_empty():
			break
		await process_frame
	return float(Time.get_ticks_msec() - t0) / 1000.0

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
