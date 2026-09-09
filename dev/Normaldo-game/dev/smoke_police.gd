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
const EXPECTED_CHECKS : int = 22

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
	print("── Турель висит под кабиной ──")
	await _test_gun_under_belly()
	_finish()

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
	# И как густо стоял огонь: полосу берём в тот момент, когда она догорела до
	# конца, то есть когда огней на ней больше всего.
	var best_lane : Array = []
	var t := 0.0
	while t < 95.0 and is_instance_valid(boss):
		get_root().get_tree().paused = false
		await process_frame
		t += 1.0 / 60.0
		var lanes : Dictionary = {}
		for c in game.get_children():
			if not is_instance_valid(c):
				continue
			if c.is_in_group("police_dog"):
				seen["собака"] = true
			elif c.is_in_group("swat"):
				seen["сват"] = true
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
		for key in lanes:
			if (lanes[key] as Array).size() > best_lane.size():
				best_lane = (lanes[key] as Array).duplicate()

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
	_check(best_lane.size() >= 2 and gap <= FIRE_W,
		"горящая полоса сплошная: %d огня, самый широкий просвет %.0f px при ширине пламени %.0f"
			% [best_lane.size(), gap, FIRE_W])

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
