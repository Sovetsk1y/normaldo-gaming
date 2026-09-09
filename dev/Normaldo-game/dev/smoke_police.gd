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

var _fails  : int = 0
var _checks : int = 0
const EXPECTED_CHECKS : int = 15

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
	var t := 0.0
	while t < 95.0 and is_instance_valid(boss):
		get_root().get_tree().paused = false
		await process_frame
		t += 1.0 / 60.0
		for c in game.get_children():
			if not is_instance_valid(c):
				continue
			if c.is_in_group("police_dog"):
				seen["собака"] = true
			elif c.is_in_group("swat"):
				seen["сват"] = true
			elif c.is_in_group("fire"):
				seen["огонь"] = true
			elif c is Line2D:
				seen["трос"] = true
			elif c.get_script() != null and \
					String(c.get_script().resource_path).ends_with("police_heli.gd"):
				seen["вертолёт"] = true

	_check(not is_instance_valid(boss), "и бой дошёл до конца за %.0f c" % t)
	# Минута — не «сколько получилось»: столько же длится бой с крокодилом, и
	# босс, который кончается вдвое быстрее остальных, читается как недоделанный.
	_check(t > 30.0, "бой не оборвался на середине: %.0f c" % t)
	for who in ["собака", "сват", "вертолёт", "огонь", "трос"]:
		_check(seen.has(who), "на арене побывал: %s" % who)

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
