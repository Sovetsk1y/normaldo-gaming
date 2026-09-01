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
const EXPECTED_CHECKS : int = 28

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

	# Кнопка вызова. Босс в кампанию не встроен, и без кнопки посмотреть на него
	# нельзя ничем — как и крокодила. Кнопки строятся на СТАРТЕ ЗАБЕГА, поэтому
	# забег тут поднимается по-настоящему, а не только сцена.
	var e : Dictionary = await _boot()
	var hud : Node = e["game"].get_node_or_null("HUD")
	hud.call("_start_game")
	await _tick(2.0)
	var caps : Array = []
	_labels(hud, caps)
	_check(caps.has("КЛУБ"), "кнопка КЛУБ есть в забеге: %s" % [caps])
	_check(hud.get("_croc_btn") != null,
		"и кнопка крокодила рядом с ней осталась")
	e["game"].queue_free()
	await process_frame

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
	var lanes_hit : Dictionary = {}
	var t := 0.0
	while t < 9.0:
		await _tick(1.0 / 60.0)
		t += 1.0 / 60.0
		for m in get_root().get_tree().get_nodes_in_group("club_minion"):
			if not is_instance_valid(m):
				continue
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
	_check(CLUB.POL_SPEED > CLUB.SEC_SPEED * 1.3,
		"и она заметно быстрее охраны: %.0f против %.0f" % [CLUB.POL_SPEED, CLUB.SEC_SPEED])

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
	# Игрок стоит в углу — так видно, что босс действительно ЕДЕТ к нему.
	(e["n"] as Node2D).position = Vector2(120.0, e["vp"].y * 0.15)
	b.call("_act_floor")

	# Первая стена: пять линий минус одна.
	var wall : int = 0
	var t := 0.0
	while t < 5.0 and wall == 0:
		await _tick(1.0 / 60.0)
		t += 1.0 / 60.0
		var cnt : int = _count("club_minion")
		if cnt > 0:
			await _tick(0.1)
			wall = _count("club_minion")
	_check(wall == CLUB.LANES - 1,
		"стена девочек оставляет ровно одну дыру: %d из %d" % [wall, CLUB.LANES])

	# Кастеты и погоня.
	var chased := false
	var x_before : float = b.position.x
	t = 0.0
	while t < 8.0 and not chased:
		await _tick(1.0 / 60.0)
		t += 1.0 / 60.0
		if bool(b.get("_tracking")):
			chased = true
	_check(chased, "хозяин надевает кастеты и начинает гнаться")
	if chased:
		var knuck : Node = null
		for c in b.get_children():
			if c is Node2D and c.get_child_count() == 2 and c.get_child(0) is Sprite2D:
				knuck = c
		_check(knuck != null, "и кастеты на нём — два кулака")
		var y_before : float = b.position.y
		await _tick(1.2)
		_check(b.position.y < y_before - 20.0 or b.position.x < x_before - 20.0,
			"и он действительно едет к игроку: (%.0f, %.0f) → (%.0f, %.0f)"
				% [x_before, y_before, b.position.x, b.position.y])
		# Но не мгновенно: уйти от него должно быть можно.
		_check(CLUB.TRACK_SPEED < 200.0,
			"но медленнее рывка игрока: %.0f" % CLUB.TRACK_SPEED)

	b.call("_abort")
	e["game"].queue_free()
	await process_frame

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
