extends SceneTree

# Headless-проверка босса «Хозяин клуба».
#   godot --headless --path . --script res://dev/smoke_club_boss.gd
#
# Битва держится на том же правиле, что и все остальные: СНАЧАЛА ТЕЛЕГРАФ,
# ПОТОМ УДАР. У этого босса телеграфа два уровня — сначала видно, как он ЗВОНИТ,
# и только потом загорается ЛИНИЯ, по которой побегут вызванные. Проверять надо
# именно порядок, а не «охранник появился»: босс, который бьёт без
# предупреждения, формально работает и при этом нечестен — ровно этим он и болел
# в старом проекте.
#
# Второе — что битва ДОХОДИТ ДО КОНЦА. Три акта, сшитые await'ами, ломаются
# тихо: одна корутина не дождалась, и босс навсегда завис в акте, а забег не
# продолжится никогда.
#
# Третье — что в каждом акте СВОЙ вопрос. Акт, повторяющий предыдущий чуть
# быстрее, — это не нарастание, а то, от чего этот бой и переписывали.
#
# См. /Концепция/Босс — Хозяин клуба.md

const CLUB := preload("res://scripts/club_boss.gd")

var _fails  : int = 0
var _checks : int = 0
const EXPECTED_CHECKS : int = 42

func _check(ok: bool, what: String) -> void:
	_checks += 1
	if ok:
		print("  ok   ", what)
	else:
		_fails += 1
		print("  FAIL ", what)

func _initialize() -> void:
	print("── Кадры и кнопка ──")
	await _test_assets()
	print("── Акт 1: охрана ──")
	await _test_security()
	print("── Акт 2: полиция ──")
	await _test_police()
	print("── Акт 3: танцпол ──")
	await _test_floor()
	print("── Акт 3: рывок бьёт в точку ──")
	await _test_dash_is_fixed()
	print("── Кулаки бьют по-настоящему ──")
	await _test_fist_hurts()
	print("── Финал: его увозят ──")
	await _test_finale()
	print("── Смерть игрока обрывает битву ──")
	await _test_death_stops()
	print("── Битва доходит до конца ──")
	await _test_full()
	_finish()

# ── Хелперы ──────────────────────────────────────────────────────────────────

func _boot(immortal: bool = true) -> Dictionary:
	var game : Node = load("res://scenes/game.tscn").instantiate()
	get_root().add_child(game)
	await process_frame
	var n  : Node = game.get_node_or_null("Normaldo")
	var sp : Node = game.get_node_or_null("Spawner")
	sp.call("clear_items")
	sp.set_process(false)
	get_root().get_tree().paused = false
	var vp : Vector2 = get_root().get_visible_rect().size
	(n as Node2D).position = Vector2(200.0, vp.y * 0.5)
	# Нормальдо бессмертен НАМЕРЕННО: тест меряет хореографию битвы, а не
	# выживание. Смертный умирает на первой же волне, экран смерти ставит дерево
	# на паузу — и битва замирает на середине, а тест показывает «босс завис»,
	# хотя завис он не сам.
	n.set("_dev_immortal", immortal)
	await process_frame
	return { "game": game, "n": n, "sp": sp, "vp": vp }

# Босс поднимается БЕЗ интро: интро — это титр, реплика и разъезд, и гонять их в
# каждом тесте значит мерить титры, а не битву.
func _boss(e: Dictionary) -> Node2D:
	var b := Node2D.new()
	b.set_script(CLUB)
	b.call("setup", e["n"], e["sp"], e["game"], true)
	b.set("autostart", false)
	e["game"].add_child(b)
	return b

func _tick(sec: float) -> void:
	var t := 0.0
	while t < sec:
		get_root().get_tree().paused = false
		await process_frame
		t += 1.0 / 60.0

func _count(group: String) -> int:
	return get_root().get_tree().get_nodes_in_group(group).size()

# Полосы вызова — ColorRect'ы в группе club_fx, лежащие прямо в корне сцены.
# Ищутся по форме, а не по имени: лента всегда во всю ширину экрана и заметно
# ниже её по высоте.
func _lane_strips(game: Node) -> Array:
	var out : Array = []
	var vp : Vector2 = get_root().get_visible_rect().size
	for c in game.get_children():
		if c is ColorRect and c.is_in_group("club_fx") \
				and absf((c as ColorRect).size.x - vp.x) < 2.0:
			out.append(c)
	return out

# ── Кадры ────────────────────────────────────────────────────────────────────

func _test_assets() -> void:
	var sz : Vector2 = CLUB.F_IDLE[0].get_size()
	var same := true
	for arr in [CLUB.F_IDLE, CLUB.F_TALK, CLUB.F_RAGE]:
		for t in arr:
			if t.get_size() != sz:
				same = false
	_check(same, "все позы босса в одной рамке %dx%d" % [sz.x, sz.y])
	_check(CLUB.F_TALK.size() == 4 and CLUB.F_RAGE.size() == 4,
		"разговор и ярость по четыре кадра")
	# Кадры разговора и ярости — РАЗНЫЕ листы. Если их случайно нарежут из
	# одного, злой звонок перестанет отличаться от обычного, а на этом держится
	# весь второй акт.
	_check(CLUB.F_TALK[0] != CLUB.F_RAGE[0], "злой звонок нарисован отдельно")

	# МЕСТО В КАМПАНИИ. Босс перестал быть «битвой, до которой можно дойти только
	# дев-кнопкой»: он стоит в конце последнего уровня, как и стоял в старом
	# проекте. Проверяется именно это — кнопка теперь обычный дев-инструмент под
	# общим рубильником, и её наличие ничего про бой не говорит.
	var lv : Array = load("res://scripts/spawner.gd").CAMPAIGN_LEVELS
	_check(String(lv[lv.size() - 1]["boss"]) == "club",
		"хозяин клуба стоит в конце последнего уровня")
	_check(lv.size() == 3, "а уровней в кампании три: %d" % lv.size())

# Зона босса включена ПРЯМО СЕЙЧАС: она существует весь такт погони, но
# `monitorable` у неё поднимается только на рывке.
func _fist_live(b: Node) -> bool:
	var f : Area2D = _fist_of(b)
	return f != null and f.monitorable

# Ударная зона самого босса, если она сейчас есть.
func _fist_of(b: Node) -> Area2D:
	for c in b.get_children():
		if c is Area2D and c.is_in_group("obstacle"):
			return c
	return null

func _labels(node: Node, out: Array) -> void:
	if node is Label and String((node as Label).text) != "":
		out.append(String((node as Label).text))
	for c in node.get_children():
		_labels(c, out)

# ── Акт 1: ОХРАНА ────────────────────────────────────────────────────────────
# Вопрос акта — «выбери линию», и держится он на том, что линию показали
# ЗАРАНЕЕ. Проверяется именно порядок: сначала лента, потом охранник.
func _test_security() -> void:
	var e : Dictionary = await _boot()
	var b : Node2D = _boss(e)
	await process_frame
	b.call("_act_security")

	# Полоса появляется РАНЬШЕ первого вызванного.
	var strip_at : float = -1.0
	var minion_at : float = -1.0
	var t := 0.0
	while t < 6.0 and (strip_at < 0.0 or minion_at < 0.0):
		await _tick(1.0 / 60.0)
		t += 1.0 / 60.0
		if strip_at < 0.0 and not _lane_strips(e["game"]).is_empty():
			strip_at = t
		if minion_at < 0.0 and _count("club_minion") > 0:
			minion_at = t
	_check(strip_at >= 0.0 and minion_at >= 0.0,
		"полоса вызова и охрана появились: %.2f и %.2f с" % [strip_at, minion_at])
	_check(strip_at < minion_at,
		"СНАЧАЛА полоса, ПОТОМ охрана: %.2f против %.2f" % [strip_at, minion_at])
	_check(minion_at - strip_at > 0.3,
		"и между ними есть время уйти: %.2f с" % (minion_at - strip_at))

	# Вызванные идут по СВОИМ линиям и не сворачивают: на этом держится смысл
	# полосы. Наводящийся охранник отменил бы её.
	var m : Node2D = get_root().get_tree().get_nodes_in_group("club_minion")[0]
	var y0 : float = m.position.y
	var x0 : float = m.position.x
	await _tick(0.4)
	if is_instance_valid(m):
		_check(absf(m.position.y - y0) < 8.0,
			"охранник держит линию: %.0f → %.0f" % [y0, m.position.y])
		_check(m.position.x < x0 - 40.0,
			"и идёт справа налево: %.0f → %.0f" % [x0, m.position.x])
	else:
		_check(false, "охранник дожил до замера")
		_check(false, "—")

	# Волны РАЗГОНЯЮТСЯ: паузы между ними падают. Одинаковый ритм — это не
	# сложность и не лёгкость, это скука, и именно им болел старый список.
	var waits : Array = CLUB.SEC_WAITS
	var ramp := true
	for i in range(1, waits.size()):
		if float(waits[i]) >= float(waits[i - 1]):
			ramp = false
	_check(ramp, "паузы между волнами укорачиваются: %s" % [waits])
	# И линий занимают всё больше — но никогда не все пять.
	var lanes : Array = CLUB.SEC_WAVES
	var grows : bool = int(lanes[lanes.size() - 1]) > int(lanes[0])
	var leaves_gap := true
	for v in lanes:
		if int(v) >= CLUB.LANES:
			leaves_gap = false
	_check(grows and leaves_gap,
		"линий занимают всё больше, но всегда меньше пяти: %s" % [lanes])
	# А вот УДАРНОЙ ЗОНЫ у самого босса на этом такте быть не должно: он звонит,
	# а не дерётся, и стоит у правого края. Постоянный хитбокс там был бы просто
	# стеной, в которую нельзя войти.
	_check(_fist_of(b) == null, "сам он на этом такте не бьёт — зоны у него нет")

	b.call("_abort")
	e["game"].queue_free()
	await process_frame

# ── Акт 2: ПОЛИЦИЯ ───────────────────────────────────────────────────────────
# Вопрос акта — «выбери сторону», и он честен только если приходят С ДВУХ
# сторон. В старом проекте все вызванные появлялись справа, и полиция
# отличалась от охраны только скоростью, то есть ничем.
func _test_police() -> void:
	var e : Dictionary = await _boot()
	var b : Node2D = _boss(e)
	await process_frame
	b.call("_act_police")

	var seen_left  := false
	var seen_right := false
	var swapped    := false
	var lanes_hit : Dictionary = {}
	var t := 0.0
	while t < 14.0:
		await _tick(1.0 / 60.0)
		t += 1.0 / 60.0
		for m in get_root().get_tree().get_nodes_in_group("club_minion"):
			if not is_instance_valid(m):
				continue
			var lane_now : int = int(m.get_meta("lane", -1))
			if int(m.get_meta("lane_seen", -2)) == -2:
				m.set_meta("lane_seen", lane_now)
			elif int(m.get_meta("lane_seen")) != lane_now:
				swapped = true
				m.set_meta("lane_seen", lane_now)
			if m.get_meta("side", "") == "":
				# Сторона определяется по направлению: у пришедшего слева оно в +X.
				var d : Vector2 = m.get("_dir")
				m.set_meta("side", "L" if d.x > 0.0 else "R")
				if d.x > 0.0: seen_left = true
				else:         seen_right = true
			lanes_hit[int(round(m.position.y / (e["vp"].y / 5.0) - 0.5))] = true
	_check(seen_left and seen_right,
		"полиция приезжает с ОБЕИХ сторон: слева=%s, справа=%s" % [seen_left, seen_right])
	_check(lanes_hit.size() >= 4,
		"залп накрывает почти все линии: %d из 5" % lanes_hit.size())
	_check(CLUB.POL_SPEED > CLUB.SEC_SPEED,
		"и она быстрее охраны: %.0f против %.0f" % [CLUB.POL_SPEED, CLUB.SEC_SPEED])
	# Залпов должно быть много: акт из трёх залпов кончался раньше, чем игрок
	# успевал понять правило мигалки.
	_check(CLUB.POL_VOLLEYS >= 6, "залпов шесть: %d" % CLUB.POL_VOLLEYS)
	# ПОДМЕНА ДЫРЫ: кто-то из копов уже в полёте сходит со своей линии и
	# закрывает свободную. Ловится по смене `lane` — по одной высоте линии это
	# было бы не отличить от покачивания на ходу.
	_check(swapped, "и кто-то из копов на лету закрыл свободную линию собой")

	b.call("_abort")
	e["game"].queue_free()
	await process_frame

# ── Акт 3: ТАНЦПОЛ ───────────────────────────────────────────────────────────
# Вопрос акта — «он идёт сам». Стена девочек оставляет ровно ОДНУ дыру, и дыра
# ползёт; поверх этого хозяин надевает кастеты и гонится.
func _test_floor() -> void:
	var e : Dictionary = await _boot()
	var b : Node2D = _boss(e)
	await process_frame
	# Игрок стоит в углу — так видно, что босс действительно ИДЁТ к нему.
	(e["n"] as Node2D).position = Vector2(120.0, e["vp"].y * 0.15)
	b.call("_act_floor")

	# Стена СПЛОШНАЯ: дыры в ней нет. Дыра была нужна, пока стена убивала;
	# теперь она не убивает, и проход в ней не нужен.
	var wall : int = 0
	var t := 0.0
	while t < 6.0 and wall == 0:
		await _tick(1.0 / 60.0)
		t += 1.0 / 60.0
		if _count("club_minion") > 0:
			await _tick(0.15)
			wall = _count("club_minion")
	_check(wall == CLUB.LANES,
		"стена девочек сплошная: %d из %d линий" % [wall, CLUB.LANES])

	# И она НЕ БЬЁТ, а ЗАМЕДЛЯЕТ. Об девочку не умирают — об неё вязнут, и
	# именно этим третий акт отличается по типу опасности от первых двух.
	var all_slow := true
	var any_hits := false
	for m in get_root().get_tree().get_nodes_in_group("club_minion"):
		if not m.is_in_group("slowing"):
			all_slow = false
		if m.is_in_group("obstacle"):
			any_hits = true
	_check(all_slow and not any_hits,
		"и не бьёт, а замедляет: %.1f с вязкости" % CLUB.GIRL_SLOW_T)

	# ── Подход → заряд → рывок ──────────────────────────────────────────────
	var chased := false
	t = 0.0
	while t < 9.0 and not chased:
		await _tick(1.0 / 60.0)
		t += 1.0 / 60.0
		chased = bool(b.get("_tracking"))
	_check(chased, "хозяин надевает кастеты и идёт сам")
	if not chased:
		b.call("_abort")
		e["game"].queue_free()
		await process_frame
		for _i in 7:
			_check(false, "—")
		return

	var knuck : Node = null
	for c in b.get_children():
		if c is Node2D and c.get_child_count() == 2 and c.get_child(0) is Sprite2D:
			knuck = c
	_check(knuck != null, "и кастеты на нём — два кулака")

	# Фазы идут по порядку. Проверяется именно ПОРЯДОК: рывок без заряда — это
	# удар без телеграфа, а он тут запрещён так же, как у всех остальных боссов.
	var seen : Array = []
	var mark_at_charge := false
	var fist_on_approach := false
	t = 0.0
	while t < 14.0 and not seen.has("recover"):
		await _tick(1.0 / 60.0)
		t += 1.0 / 60.0
		if not is_instance_valid(b):
			break
		var ph : String = String(b.get("_chase"))
		if ph != "" and (seen.is_empty() or seen[seen.size() - 1] != ph):
			seen.append(ph)
		if ph == "charge" and _count("club_mark") > 0:
			mark_at_charge = true
		if ph in ["approach", "recover"] and _fist_live(b):
			fist_on_approach = true
	_check(seen.has("charge") and seen.has("dash")
			and seen.find("charge") < seen.find("dash"),
		"СНАЧАЛА заряд, ПОТОМ рывок: %s" % [seen])
	_check(mark_at_charge, "и на полу метка — куда прилетит")
	_check(not fist_on_approach, "а бьёт он ТОЛЬКО в рывке, не на подходе")

	b.call("_abort")
	e["game"].queue_free()
	await process_frame

# ── Рывок бьёт В ТОЧКУ, а не в игрока ────────────────────────────────────────
# Точка запоминается в начале заряда. Рывок, доводящийся до головы, отменил бы и
# заряд, и уворот: уходить было бы некуда, и такт свёлся бы к «не подпускай его».
func _test_dash_is_fixed() -> void:
	var e : Dictionary = await _boot()
	var b : Node2D = _boss(e)
	await process_frame
	(e["n"] as Node2D).position = Vector2(e["vp"].x * 0.35, e["vp"].y * 0.5)
	b.position = Vector2(e["vp"].x * 0.35 + CLUB.CHARGE_D + 140.0, e["vp"].y * 0.5)
	b.call("_start_track")

	var t := 0.0
	while t < 8.0 and String(b.get("_chase")) != "charge":
		await _tick(1.0 / 60.0)
		t += 1.0 / 60.0
	_check(String(b.get("_chase")) == "charge", "подошёл и начал заряд")
	var target : Vector2 = b.get("_dash_to")

	# УХОДИМ во время заряда — ровно то, ради чего заряд и нужен.
	(e["n"] as Node2D).position = Vector2(e["vp"].x * 0.35, e["vp"].y * 0.88)
	t = 0.0
	while t < 8.0 and String(b.get("_chase")) != "recover":
		await _tick(1.0 / 60.0)
		t += 1.0 / 60.0
	_check(String(b.get("_chase")) == "recover", "рывок отработал и кончился")
	_check(b.position.distance_to(target) < 70.0,
		"и пришёл в ЗАПОМНЕННУЮ точку: %.0f px от неё" % b.position.distance_to(target))
	_check(b.position.distance_to((e["n"] as Node2D).position) > 120.0,
		"а не за игроком: %.0f px до него"
			% b.position.distance_to((e["n"] as Node2D).position))

	b.call("_abort")
	e["game"].queue_free()
	await process_frame

# ── Кулаки ─# ── Кулаки ───────────────────────────────────────────────────────────────────
# «Зона есть» и «зона бьёт» — разные утверждения, и второе важнее. Проверяется
# оно на СМЕРТНОМ Нормальдо: его ставят вплотную к боссу на такте погони и
# смотрят, дошёл ли урон до игрока. До этой правки босс проходил сквозь голову
# насквозь, и весь последний акт был пустым.
func _test_fist_hurts() -> void:
	var e : Dictionary = await _boot(false)
	var b : Node2D = _boss(e)
	await process_frame
	(e["n"] as Node2D).position = Vector2(e["vp"].x * 0.4, e["vp"].y * 0.5)
	b.position = Vector2(e["vp"].x * 0.4 + CLUB.CHARGE_D + 90.0, e["vp"].y * 0.5)
	b.call("_start_track")
	await _tick(0.3)
	_check(_fist_of(b) != null, "на такте погони у босса есть зона")
	# Игрок НЕ УХОДИТ — рывок обязан его достать. Ждём столько, сколько нужно
	# на подход, заряд и сам рывок.
	var t := 0.0
	while t < 8.0 and not bool(e["n"].get("_dead")):
		await _tick(1.0 / 60.0)
		t += 1.0 / 60.0
	_check(bool(e["n"].get("_dead")),
		"и рывок ДОХОДИТ до стоящего на месте: удар засчитан")
	if is_instance_valid(b):
		b.call("_abort")
	e["game"].queue_free()
	await process_frame

# ── Финал ────────────────────────────────────────────────────────────────────
# Конец рассказан ДВИЖЕНИЕМ: к боссу подходят девочки, подъезжает полицейская
# машина, все садятся, машина уезжает. Раньше тут была толпа, слетающаяся к
# нему со всех сторон, и на экране это читалось как «все спрятались за него», а
# не как конец.
func _test_finale() -> void:
	var e : Dictionary = await _boot()
	var b : Node2D = _boss(e)
	await process_frame
	b.call("_finale")

	var car : Sprite2D = null
	var t := 0.0
	while t < 6.0 and car == null:
		await _tick(1.0 / 60.0)
		t += 1.0 / 60.0
		car = _car(e["game"])
	_check(car != null, "полицейская машина подъехала")
	if car == null:
		e["game"].queue_free()
		await process_frame
		_check(false, "—")
		_check(false, "—")
		return

	# Она ОСТАНАВЛИВАЕТСЯ в кадре, а не проезжает мимо: садиться надо во
	# что-то стоящее. Ищем кадр, где машина внутри экрана и УЖЕ НЕ ЕДЕТ.
	var x_stop : float = -1.0
	var x_prev : float = car.position.x
	t = 0.0
	while t < 3.0 and x_stop < 0.0:
		await _tick(1.0 / 60.0)
		t += 1.0 / 60.0
		if not is_instance_valid(car):
			break
		var x : float = car.position.x
		if x > 0.0 and x < e["vp"].x and absf(x - x_prev) < 1.0:
			x_stop = x
		x_prev = x
	_check(x_stop > 0.0, "и встала в кадре: x=%.0f" % x_stop)

	# Дальше уезжает ЗА ЛЕВЫЙ край и увозит его: босс к этому моменту погас.
	t = 0.0
	while t < 6.0 and is_instance_valid(b) and float(b.modulate.a) > 0.05:
		await _tick(1.0 / 60.0)
		t += 1.0 / 60.0
	_check(not is_instance_valid(b) or float(b.modulate.a) <= 0.05,
		"хозяина увезли — с экрана он ушёл вместе с машиной")
	if is_instance_valid(b):
		b.call("_abort")
	e["game"].queue_free()
	await process_frame

func _car(game: Node) -> Sprite2D:
	for c in game.get_children():
		if c is Sprite2D and (c as Sprite2D).texture == CLUB.T_POLICE_CAR:
			return c
	return null

# ── Смерть игрока ────────────────────────────────────────────────────────────
# Такты сшиты через `get_tree().create_timer()`, а тот тикает и на паузе: без
# явного обрыва босс спокойно доигрывает акт поверх экрана смерти.
func _test_death_stops() -> void:
	var e : Dictionary = await _boot(false)
	var b : Node2D = _boss(e)
	await process_frame
	b.call("_act_security")
	await _tick(2.0)
	_check(_count("club_minion") > 0, "охрана на экране")
	e["n"].call("_die")
	await _tick(0.6)
	_check(not is_instance_valid(b) or bool(b.get("_stopped")),
		"смерть игрока обрывает битву")
	await _tick(0.5)
	_check(_count("club_minion") == 0, "и убирает вызванных с экрана")
	_check(_count("club_fx") == 0, "и все декорации: мигалку, полосы, стробоскоп")
	e["game"].queue_free()
	await process_frame

# ── Битва целиком ────────────────────────────────────────────────────────────
func _test_full() -> void:
	var e : Dictionary = await _boot()
	var b : Node2D = _boss(e)
	await process_frame
	b.call("_run_boss")
	var seen : Array = []
	var t := 0.0
	while t < 120.0 and is_instance_valid(b):
		await _tick(0.1)
		t += 0.1
		if not is_instance_valid(b):
			break
		var act : String = String(b.get("current_act"))
		if act != "" and (seen.is_empty() or seen[seen.size() - 1] != act):
			seen.append(act)
	_check(not is_instance_valid(b), "битва закончилась и босс убрался: %.0f с" % t)
	_check(seen.has("security") and seen.has("police") and seen.has("floor")
			and seen.has("finale"),
		"и прошла все акты по порядку: %s" % [seen])
	_check(_count("club_minion") == 0 and _count("club_fx") == 0,
		"после битвы на экране ничего от неё не осталось")
	# Забег возвращается в рабочее состояние: заморозку снял бы только конец
	# кампании, а при дев-вызове его нет.
	_check(e["sp"].is_processing(), "поток предметов пошёл дальше")
	e["game"].queue_free()
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
