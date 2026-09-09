extends SceneTree

# Headless-проверка боя с КАПИТАНОМ ПОЛИЦИИ.
#   godot --headless --path . --script res://dev/smoke_police.gd
#
# Бой длинный (около минуты) и состоит из четырёх актов, каждый — своя корутина.
# Ломается такое ТИХО: акт, упавший на первом же `await`, не печатает ничего —
# бой просто идёт дальше без него, и заметить это можно только глазами и только
# если знать, чего ждать.
#
# Поэтому тест не смотрит на картинку, а СЛЕДИТ ЗА АРЕНОЙ: кто на ней побывал за
# время боя. Не побывал никто из акта — акт не отработал.

const POLICE := preload("res://scripts/police_boss.gd")
const SWAT   := preload("res://scripts/police_swat.gd")
const DOG    := preload("res://scripts/police_dog.gd")
const HELI   := preload("res://scripts/police_heli.gd")
const SHOT   := preload("res://scripts/skill_projectile.gd")

# Ширина языка пламени на экране: 71 пиксель рисунка в масштабе 0.83. По ней и
# меряется, сплошная ли горящая полоса.
const FIRE_W : float = 59.0

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
	print("── Разведка боем ──")
	await _test_fight()
	print("── Отряд: три вида, и щит не ломается ──")
	await _test_squad_kinds()
	print("── Собака возвращается к хозяину ──")
	await _test_dog_returns()
	print("── Собака: не крутится, разгоняется, ест снаряды ──")
	await _test_dog_rules()
	print("── Турель: под кабиной и наводится ──")
	await _test_gun_under_belly()
	print("── Сватовец смотрит туда, куда стреляет ──")
	await _test_swat_mirror()
	_finish()

# ── ЗЕРКАЛО ПО ЦЕЛИ ────────────────────────────────────────────────────────
# Боец нарисован смотрящим влево. Пока зеркала не было, Нормальдо мог зайти
# справа, ствол разворачивался ему вслед, а голова продолжала смотреть в другую
# сторону — человек, стреляющий у себя из-за спины.
#
# Проверяются ОБА направления: без второго можно было бы «починить» зеркало,
# просто отразив бойца навсегда.
func _test_swat_mirror() -> void:
	var game : Node = load("res://scenes/game.tscn").instantiate()
	get_root().add_child(game)
	await process_frame

	var mark := Node2D.new()
	game.add_child(mark)

	var s := Area2D.new()
	s.set_script(SWAT)
	s.set("kind", "rifle")
	s.set("target", mark)
	s.position = Vector2(480.0, 215.0)
	game.add_child(s)
	await process_frame
	# Живой, а не падающий: зеркало считается в ходовом состоянии.
	s.call("enter_from_edge")

	var head : Sprite2D = null
	for c in s.get_children():
		if c is Sprite2D and (c as Sprite2D).texture == SWAT.SWAT_TEX:
			head = c
	if head == null:
		_check(false, "у сватовца нашлась голова")
		game.queue_free()
		return

	mark.position = Vector2(100.0, 215.0)      # цель СЛЕВА
	await process_frame
	await process_frame
	_check(not head.flip_h, "цель слева — смотрит влево, как нарисован")

	mark.position = Vector2(900.0, 215.0)      # цель СПРАВА
	await process_frame
	await process_frame
	_check(head.flip_h, "цель справа — отзеркалился")

	# И ЩИТОНОСЕЦ НЕ ЗЕРКАЛИТСЯ НИКОГДА. Он не целится, он идёт, и щит у него
	# всегда спереди по ходу; развернувшийся щитоносец подставил бы спину, и
	# правило «его не обойти в лоб» сломалось бы само собой.
	var sh := Area2D.new()
	sh.set_script(SWAT)
	sh.set("kind", "shield")
	sh.set("target", mark)
	sh.position = Vector2(480.0, 215.0)
	game.add_child(sh)
	await process_frame
	sh.call("enter_from_edge")
	for _i in 4:
		await process_frame
	_check(not bool(sh.get("_facing_right")), "а щитоносец не разворачивается никогда")

	game.queue_free()
	await process_frame

# ── ВЕСЬ БОЙ ОТ ВХОДА ДО ФИНАЛА ────────────────────────────────────────────
func _test_fight() -> void:
	var game : Node = load("res://scenes/game.tscn").instantiate()
	get_root().add_child(game)
	await process_frame
	var hud : Node = game.get_node_or_null("HUD")
	var nrm : Node = game.get_node_or_null("Normaldo")
	hud.call("_start_game")
	for _i in 20:
		get_root().get_tree().paused = false
		await process_frame
	nrm.call("enable_input")
	# БЕССМЕРТИЕ ОБЯЗАТЕЛЬНО. Бой идёт минуту, и по нему летают пули, гранаты и
	# собака: смертный подопытный умрёт на первом акте, и тест будет проверять
	# экран смерти.
	nrm.call("set_dev_immortal", true)
	hud.call("summon_police", true)
	await process_frame

	var boss : Node = null
	for c in game.get_children():
		if c.get_script() == POLICE:
			boss = c
	_check(boss != null, "капитан поднялся")
	if boss == null:
		game.queue_free()
		return

	# Кто побывал на арене за бой.
	var seen : Dictionary = {}
	# ── КАК ГУСТО ВСТАЁТ ОГОНЬ ──────────────────────────────────────────────
	# Берём полосу В МОМЕНТ, КОГДА ОНА ТОЛЬКО ЧТО ВСТАЛА ЦЕЛИКОМ, и больше не
	# трогаем. Сначала здесь бралась просто «полоса, где огней больше всего», и
	# проверка оказалась плавающей: если два захода приходятся на ОДНУ полосу,
	# в выборку попадает момент, когда первый огонь уже догорает, а второй ещё
	# кладётся, — и дыра там честная, но говорит она не про плотность, а про
	# догорание. Тест то проходил (38 огней, просвет 49), то падал (36 и 99).
	#
	# Правило, которое мы проверяем, звучит как «полоса ВСТАЁТ сплошной», поэтому
	# и мерить надо ровно вставшую.
	var best_lane : Array = []
	var lane_ready : bool = false
	# Сколько огней кладёт один заход: тот же расчёт, что и у босса. Считаем, а не
	# пишем числом, чтобы проверка пережила правку шага и ширины экрана.
	var full_lane : int = int(ceil(absf((get_root().get_visible_rect().size.x
		- POLICE.FIRE_X_FROM) - POLICE.FIRE_X_TO) / POLICE.FIRE_STEP_PX)) + 1
	# Где отделялся от вертолёта каждый сватовец — по одному числу на бойца.
	var drop_x : Dictionary = {}
	# И сколько их стояло на арене разом за всё время боя.
	var max_swat : int = 0
	# Столько же про собак и про горящие полосы.
	var max_dogs  : int = 0
	var max_lanes : int = 0
	var t := 0.0
	while t < 95.0 and is_instance_valid(boss):
		get_root().get_tree().paused = false
		await process_frame
		t += 1.0 / 60.0
		var lanes : Dictionary = {}
		var swat_now : int = 0
		var dogs_now : int = 0
		for c in game.get_children():
			if not is_instance_valid(c):
				continue
			if c.is_in_group("police_dog"):
				seen["собака"] = true
				dogs_now += 1
			elif c.is_in_group("swat"):
				seen["сват"] = true
				swat_now += 1
				# ГДЕ ИМЕННО он появился. Запоминаем по первому кадру жизни: дальше
				# боец идёт влево сам, и через секунду он будет где угодно.
				var sid : int = c.get_instance_id()
				if not drop_x.has(sid):
					drop_x[sid] = (c as Node2D).position.x
			elif c.is_in_group("fire"):
				seen["огонь"] = true
				var key : int = int(round((c as Node2D).position.y))
				if not lanes.has(key):
					lanes[key] = []
				(lanes[key] as Array).append((c as Node2D).position.x)
			elif c is Line2D:
				seen["трос"] = true
			elif c.get_script() != null and \
					String(c.get_script().resource_path).ends_with("police_heli.gd"):
				seen["вертолёт"] = true
		max_swat  = maxi(max_swat, swat_now)
		max_dogs  = maxi(max_dogs, dogs_now)
		# Полос СЧИТАЕМ ПО РАЗНЫМ y: огни одной полосы стоят на одной высоте, и
		# считать их поштучно значило бы считать не полосы, а пламя.
		max_lanes = maxi(max_lanes, lanes.size())
		if not lane_ready:
			for key in lanes:
				# Считаем РАЗНЫЕ места, а не огни: два захода по одной полосе кладут
				# огонь в те же самые точки, и по числу огней полоса выглядела бы
				# вдвое плотнее, чем она есть.
				var seen_x : Dictionary = {}
				for x in (lanes[key] as Array):
					seen_x[int(round(float(x)))] = true
				if seen_x.size() >= full_lane:
					best_lane = seen_x.keys()
					lane_ready = true
					break

	_check(not is_instance_valid(boss), "и бой дошёл до конца за %.0f c" % t)
	# Минута — не «сколько получилось»: столько же длится бой с крокодилом, и
	# босс, который кончается вдвое быстрее остальных, читается как недоделанный.
	_check(t > 30.0, "бой не оборвался на середине: %.0f c" % t)
	for who in ["собака", "сват", "вертолёт", "огонь", "трос"]:
		_check(seen.has(who), "на арене побывал: %s" % who)

	# ── ГОРЯЩАЯ ПОЛОСА ОБЯЗАНА БЫТЬ СПЛОШНОЙ ────────────────────────────────
	# Иначе она ничего не отбирает: между редкими кострами свободно проходит и
	# Нормальдо, и сватовец, и обещание «полоса выключена на десять секунд»
	# оказывается враньём. Меряем самый широкий просвет между соседями.
	best_lane.sort()
	var gap : float = 0.0
	for i in range(1, best_lane.size()):
		gap = maxf(gap, float(best_lane[i]) - float(best_lane[i - 1]))
	_check(lane_ready and gap <= FIRE_W,
		"горящая полоса встала сплошной: %d мест из %d, самый широкий просвет %.0f px при ширине пламени %.0f"
			% [best_lane.size(), full_lane, gap, FIRE_W])

	# ── ОТРЯД ВЫСАЖИВАЕТСЯ В ДАЛЬНЕЙ ТРЕТИ ──────────────────────────────────
	# Прыжки шли по секундомеру, и третий боец отделялся на x=392 — за серединой
	# экрана, почти у Нормальдо под носом: реакции на него не оставалось никакой.
	#
	# Проверяется САМЫЙ БЛИЖНИЙ прыжок из всех за бой, а не средний и не первый:
	# средний спрячет одного заехавшего, а первый по устройству всегда у самого
	# края и потому не значит ничего.
	var vpx : float = get_root().get_visible_rect().size.x
	var nearest : float = vpx * 2.0
	for sid in drop_x:
		nearest = minf(nearest, float(drop_x[sid]))
	_check(not drop_x.is_empty() and nearest >= vpx * 2.0 / 3.0,
		"весь отряд высадился в дальней трети: ближайший прыжок x=%.0f при границе %.0f"
			% [nearest, vpx * 2.0 / 3.0])

	# ── ОТРЯД НА АРЕНЕ ОДИН ЗА РАЗ ──────────────────────────────────────────
	# Капитан сыпал новую тройку после КАЖДОГО захода штурмовки, а боец живёт до
	# ухода за край семнадцать секунд: к третьему заходу на экране стояла шеренга
	# из десятка при двух горящих полосах, и пройти это было нельзя — не потому
	# что сложно, а потому что некуда деться.
	#
	# Меряется ПИК за весь бой, а не число вызовов: важно, сколько их стояло
	# ОДНОВРЕМЕННО, а вызвать капитан может сколько угодно раз, если каждый раз
	# предыдущие успели кончиться.
	_check(max_swat <= POLICE.SQUAD_SIZE,
		"на арене разом не больше одной группы: пик %d при группе в %d"
			% [max_swat, POLICE.SQUAD_SIZE])

	# ── БОЛЬШЕ ДВУХ ГОРЯЩИХ ПОЛОС НЕ БЫВАЕТ ─────────────────────────────────
	# Полоса горит десять секунд, заходов три — и они складывались: к третьему
	# на поле оставалось две свободные линии из пяти, и это при живом отряде.
	_check(max_lanes <= POLICE.MAX_BURNING,
		"горящих полос разом не больше %d: пик %d" % [POLICE.MAX_BURNING, max_lanes])

	# ── ВОЛНЫ СОБАК РАСТУТ ДО ТРЁХ ──────────────────────────────────────────
	# Ровно до трёх, и это надо проверять с ОБЕИХ сторон. Меньше — значит волны
	# не выросли (например, акт кончается по таймеру и третью волну обрывает);
	# больше — значит волны наложились друг на друга, а каждая обязана дождаться
	# своих собак.
	_check(max_dogs == POLICE.DOG_WAVES,
		"самая большая стая — ровно %d собаки: пик %d" % [POLICE.DOG_WAVES, max_dogs])

	# И НИЧЕГО НЕ ОСТАЛОСЬ. Сватовец, переживший бой, стрелял бы по уже
	# победившему игроку; огонь — жёг бы полосу до конца забега.
	var left : Array = []
	for c in game.get_children():
		if not is_instance_valid(c):
			continue
		for g in ["swat", "police_dog", "fire"]:
			if c.is_in_group(g):
				left.append(g)
	_check(left.is_empty(), "и арена убрана за собой: %s" % [left])

	game.queue_free()
	await process_frame

# ── ТРИ ВИДА СВАТ ──────────────────────────────────────────────────────────
# Щитоносца НЕЛЬЗЯ сломать, и это половина его смысла: вопрос от него — «куда ты
# денешься», а не «чем его убрать». Он единственный, кого нет в группе ломаемых,
# и потерять эту строку легко.
func _test_squad_kinds() -> void:
	var game : Node = load("res://scenes/game.tscn").instantiate()
	get_root().add_child(game)
	await process_frame

	var made : Dictionary = {}
	for kind in ["shield", "rifle", "grenade"]:
		var s := Area2D.new()
		s.set_script(SWAT)
		s.set("kind", kind)
		game.add_child(s)
		await process_frame
		made[kind] = s

	_check(bool(made["shield"].is_in_group("obstacle")), "щитоносец — угроза")

	# ЛОМАЕМ ТАК ЖЕ, КАК ЭТО ДЕЛАЕТ СПЕЛЛ: через `on_hit`. Первым заходом здесь
	# проверялась ГРУППА «ломаемых» — и проверка была зелёной при полностью
	# сломанном щите: ломает предметы `normaldo._kill_item`, а он спрашивает не
	# группу, а метод. Группа висела украшением.
	for kind in ["shield", "rifle", "grenade"]:
		(made[kind] as Node).call("on_hit")
	# Даём твину смерти доиграть: гибель — это падение с прокруткой, а не
	# мгновенное `queue_free`.
	var t := 0.0
	while t < 1.2:
		get_root().get_tree().paused = false
		await process_frame
		t += 1.0 / 60.0

	_check(is_instance_valid(made["shield"]) \
			and not bool((made["shield"] as Node).get("_dead")),
		"но спелл его не берёт — щит держит")
	_check(not is_instance_valid(made["rifle"]) \
			or bool((made["rifle"] as Node).get("_dead")),
		"стрелка — берёт")
	_check(not is_instance_valid(made["grenade"]) \
			or bool((made["grenade"] as Node).get("_dead")),
		"гранатомётчика — тоже")

	game.queue_free()
	await process_frame

# ── СОБАКА ВСЕГДА ВОЗВРАЩАЕТСЯ ─────────────────────────────────────────────
# Босс ждёт её ПО СИГНАЛУ, а не по таймеру. Значит собака, не пославшая сигнал,
# вешает весь бой намертво: акт не кончится никогда, и игрок останется с одной
# собакой до конца забега.
#
# Проверяется худший случай: цели нет вовсе (игрок умер и убран). Собака обязана
# отбегать своё и уйти к хозяину, а не летать вечно.
func _test_dog_returns() -> void:
	var game : Node = load("res://scenes/game.tscn").instantiate()
	get_root().add_child(game)
	await process_frame
	var owner := Node2D.new()
	owner.position = Vector2(900.0, 200.0)
	game.add_child(owner)

	var dog := Area2D.new()
	dog.set_script(DOG)
	dog.set("owner_node", owner)
	dog.set("target", null)
	dog.position = Vector2(880.0, 200.0)
	game.add_child(dog)
	await process_frame

	var home := [false]
	(dog.get("came_home") as Signal).connect(func() -> void: home[0] = true)

	var t := 0.0
	while t < 30.0 and is_instance_valid(dog):
		get_root().get_tree().paused = false
		await process_frame
		t += 1.0 / 60.0
	_check(home[0], "собака без цели всё равно вернулась за %.1f c" % t)
	_check(not is_instance_valid(dog), "и убралась с арены")

	game.queue_free()
	await process_frame

# ── ТРИ ПРАВИЛА СОБАКИ ─────────────────────────────────────────────────────
# Все три ЛОМАЮТСЯ ТИХО. Крутящийся спрайт — это одна строка, которую легко
# вернуть «чтобы живее»; разгон — поле, которое кто-нибудь заменит константой
# при первой же правке скорости; перехват снарядов вообще невидим, пока не
# выстрелишь в неё именно тем скином, у которого снаряд летит медленно.
func _test_dog_rules() -> void:
	var game : Node = load("res://scenes/game.tscn").instantiate()
	get_root().add_child(game)
	await process_frame

	var dog := Area2D.new()
	dog.set_script(DOG)
	dog.set("target", null)
	dog.position = Vector2(480.0, 210.0)
	game.add_child(dog)
	await process_frame

	var v0 : float = float((dog.get("_vel") as Vector2).length())
	var t := 0.0
	while t < 2.0 and is_instance_valid(dog):
		get_root().get_tree().paused = false
		await process_frame
		t += 1.0 / 60.0
	if not is_instance_valid(dog):
		_check(false, "собака дожила до замера разгона")
		_check(false, "собака дожила до замера разгона")
		game.queue_free()
		await process_frame
		return

	var spr := (dog as Node).get_child(0) as Sprite2D
	_check(is_instance_valid(spr) and absf(spr.rotation) < 0.001,
		"собака не крутится: поворот %.3f" % [spr.rotation if is_instance_valid(spr) else -1.0])

	var v1 : float = float((dog.get("_vel") as Vector2).length())
	# Не «стало больше нуля», а стало больше ИМЕННО НА СТОЛЬКО, сколько обещает
	# ускорение: скорость, подросшая на пару пикселей от округлений, прошла бы
	# проверку «v1 > v0» и не была бы разгоном.
	_check(v1 > v0 + 100.0, "и разгоняется: %.0f → %.0f px/c за %.1f c" % [v0, v1, t])

	# СНАРЯД ЛЮБОГО СКИНА. Берём тот самый узел, который спавнит `normaldo`, —
	# он один на все скины, и проверять каждый скин отдельно значило бы проверять
	# одно и то же двенадцать раз.
	var shot := Area2D.new()
	shot.set_script(SHOT)
	game.add_child(shot)
	shot.set("radius", 26.0)
	shot.set("velocity", Vector2.ZERO)
	shot.set("life", 5.0)
	shot.call("setup", null)
	(shot as Node2D).global_position = (dog as Node2D).global_position
	for _i in 4:
		get_root().get_tree().paused = false
		await process_frame
	_check(not is_instance_valid(shot), "снаряд гаснет у неё в зубах")

	# И САМА ОНА СПЕЛЛОМ НЕ БЬЁТСЯ. Иначе получилось бы, что один и тот же
	# батаранг то гаснет в зубах, то убивает — смотря кто успел первым.
	(dog as Node).call("on_hit")
	for _i in 4:
		get_root().get_tree().paused = false
		await process_frame
	_check(is_instance_valid(dog) and not bool(dog.get("_done")),
		"а спелл её не берёт")

	game.queue_free()
	await process_frame

# ── ТУРЕЛЬ ПОД БРЮХОМ, А НЕ НА КРЫШЕ ───────────────────────────────────────
# Пулемёт нарисован в углу своего кадра, и посаженный «по центру кадра» он
# уезжает вверх — на глаз это читается как «вертолёт везёт пулемёт на крыше».
# Проверка меряет РИСУНКИ, а не позиции узлов: именно рисунок и разъезжается.
func _test_gun_under_belly() -> void:
	var game : Node = load("res://scenes/game.tscn").instantiate()
	get_root().add_child(game)
	await process_frame

	var heli := Node2D.new()
	heli.set_script(HELI)
	heli.position = Vector2(600.0, 120.0)
	game.add_child(heli)
	heli.call("set_gun_visible", true)
	await process_frame

	var body : Sprite2D = null
	var gun  : Sprite2D = null
	for c in heli.get_children():
		if not (c is Sprite2D):
			continue
		var s := c as Sprite2D
		if s.texture == HELI.GUN1_TEX or s.texture == HELI.GUN2_TEX:
			gun = s
		elif s.texture == HELI.BODY_TEX or s.texture == HELI.DOOR_TEX:
			body = s
	if body == null or gun == null:
		_check(false, "у вертолёта нашлись корпус и турель")
		game.queue_free()
		await process_frame
		return

	var rb := _drawn_rect(body)
	var rg := _drawn_rect(gun)
	# Весь ствол — ниже середины корпуса. Кабина нарисована в нижней половине,
	# так что «ниже середины» и значит «под кабиной».
	_check(rg.position.y >= rb.get_center().y,
		"верх турели ниже середины корпуса: %.0f против %.0f"
			% [rg.position.y, rb.get_center().y])
	# И дуло — ещё ниже её крепления: очередь уходит вниз, к полосе.
	var mz : Vector2 = heli.call("muzzle")
	_check(mz.y > gun.global_position.y,
		"дуло смотрит вниз от крепления: %.0f против %.0f"
			% [mz.y, gun.global_position.y])

	# ── СТВОЛ И ОЧЕРЕДЬ — ОДНА ПРЯМАЯ ────────────────────────────────────────
	# Очередь рисуется ОТ ДУЛА В ТОЧКУ, и пока турель не поворачивалась, линия
	# уезжала вдоль полосы, а ствол оставался смотреть в одну сторону: на экране
	# это выглядело как жёлтая палка, приставленная к пулемёту сбоку.
	#
	# Проверяются ДВЕ РАЗНЫЕ точки. С одной совпасть можно случайно — например,
	# если наводка не работает вовсе, а точка выбрана там, куда ствол и так
	# смотрел.
	# ── И СТРЕЛЯЕТ ТОЛЬКО ПО ТОМУ, ЧТО НИЖЕ ЕЁ ───────────────────────────────
	# Турель висит ПОД вертолётом, и её ось приходится ниже двух верхних полос.
	# Пока ствол не поворачивался, это было незаметно — он смотрел в одну сторону
	# при любой полосе. Стоило навести его честно, и по верхним полосам он начал
	# бы бить снизу вверх, из-под собственного вертолёта.
	#
	# Проверка идёт ПО СПИСКУ ПОЛОС, который босс реально штурмует: список — часть
	# правила, а не пожелание, и вернуть в него верхнюю полосу можно только вместе
	# с переносом вертолёта.
	heli.position = Vector2(600.0, POLICE.HELI_HOVER_Y)
	await process_frame
	var vp : Vector2 = get_root().get_visible_rect().size
	var bad : Array = []
	for i in POLICE.STRAFE_LANES:
		var ly : float = vp.y / float(POLICE.LANES) * (float(i) + 0.5)
		if ly <= gun.global_position.y:
			bad.append(i)
	_check(bad.is_empty(),
		"все штурмуемые полосы ниже турели (ось %.0f): лишние %s"
			% [gun.global_position.y, bad])

	for at in [Vector2(900.0, 200.0), Vector2(80.0, 380.0)]:
		heli.call("aim_at", at)
		await process_frame
		var m : Vector2 = heli.call("muzzle")
		var to_muzzle : Vector2 = m - gun.global_position
		var to_target : Vector2 = at - gun.global_position
		var da : float = absf(wrapf(to_muzzle.angle() - to_target.angle(), -PI, PI))
		_check(da < 0.02,
			"навёлся в (%.0f, %.0f) — ствол и очередь на одной прямой: расхождение %.3f рад"
				% [at.x, at.y, da])

	game.queue_free()
	await process_frame

# Прямоугольник РИСУНКА спрайта в координатах его родителя. Sprite2D рисует кадр
# центром в своей точке, поэтому от позиции надо отнять полкадра, прибавить
# offset (которым и двигает `anchor_sprite`) и место рисунка внутри кадра — и всё
# это в масштабе спрайта.
func _drawn_rect(s: Sprite2D) -> Rect2:
	var sz := s.texture.get_size()
	var r  := ItemSizing.content_rect(s.texture)
	var tl : Vector2 = s.position \
		+ (Vector2(r.position) - sz * 0.5 + s.offset) * s.scale
	return Rect2(tl, Vector2(r.size) * s.scale)

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
