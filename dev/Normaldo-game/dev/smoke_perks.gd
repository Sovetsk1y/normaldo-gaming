extends SceneTree

# Headless-проверка ВЕНЦОВ 10-го УРОВНЯ и призыва шамана.
#   godot --headless --path . --script res://dev/smoke_perks.gd
#
# Все три вещи ломаются молча и одинаково: способность объявлена в таблице, а в
# бою её нет. Ровно так «Остановка времени» и «Паучья реакция» и прожили —
# записанные в лестницу скинов и не написанные в коде. На глаз это не ловится:
# перк с периодом 30 секунд не проверить забегом, а не сработавшую реакцию
# игрок принимает за обычный удар.
#
# Поэтому проверяются не картинки, а СЛЕДСТВИЯ: замедлился ли мир, отняли ли
# жир, появились ли змеи и держатся ли они возле шамана.

var _fails  : int = 0
var _checks : int = 0
const EXPECTED_CHECKS : int = 20

func _check(ok: bool, what: String) -> void:
	_checks += 1
	if ok:
		print("  ok   ", what)
	else:
		_fails += 1
		print("  FAIL ", what)

var _game : Node   = null
var _n    : Node2D = null
var _sp   : Node   = null
var _save : Node   = null

func _initialize() -> void:
	_game = load("res://scenes/game.tscn").instantiate()
	get_root().add_child(_game)
	await process_frame
	await process_frame
	_n    = _game.get_node_or_null("Normaldo")
	_sp   = _game.get_node_or_null("Spawner")
	_save = get_root().get_node_or_null("SaveData")
	if _n == null or _sp == null or _save == null:
		print("  FAIL сцена не собралась")
		quit(1)
		return

	print("── Перки объявлены и включаются ──")
	_test_declared()
	print("── Остановка времени мага ──")
	await _test_time_slow()
	print("── Паучья реакция ──")
	await _test_reflex()
	print("── Шаман зовёт змей ──")
	await _test_shaman()
	_finish()

# Перк живёт в лестнице скинов, и включаться он обязан ИМЕННО на 10-м уровне
# своего скина: перк, включённый всем, — это не венец, а общее правило.
func _test_declared() -> void:
	_use("wizard", 10)
	_check(bool(_n.get("_perk_time_slow")), "у мага 10-го уровня остановка времени есть")
	_check(not bool(_n.get("_perk_reflex")), "а паучьей реакции у него нет")
	_use("wizard", 9)
	_check(not bool(_n.get("_perk_time_slow")), "на 9-м уровне её ещё нет")
	_use("spider_man", 10)
	_check(bool(_n.get("_perk_reflex")), "у Спайди 10-го уровня реакция есть")
	_check(not bool(_n.get("_perk_time_slow")), "а остановки времени нет")

func _test_time_slow() -> void:
	_use("wizard", 10)
	_sp.set("_frozen", false)
	_sp.set("world_speed_mult", 1.0)
	_check(is_equal_approx(float(_sp.get("world_speed_mult")), 1.0),
		"до срабатывания мир идёт своим ходом")
	_n.call("_fire_time_slow")
	await _wait_frames(3)
	_check(float(_sp.get("world_speed_mult")) < 1.0,
		"мир замедлился: %.2f" % float(_sp.get("world_speed_mult")))
	_check(not _n.call("is_skill_ready", "perk:time_slow"),
		"и перк ушёл на откат — иначе он сработал бы каждый кадр")
	# Ждём РЕАЛЬНОЕ время: замедление снимается таймером, а не счётчиком кадров.
	await _wait_real(_n.TIME_SLOW_LEN + 1.2)
	_check(is_equal_approx(float(_sp.get("world_speed_mult")), 1.0),
		"через свои секунды мир вернулся: %.2f" % float(_sp.get("world_speed_mult")))

	# На боссе поток принадлежит бою — туда перк не лезет.
	_sp.set("_frozen", true)
	_sp.set("world_speed_mult", 1.0)
	_n.call("_fire_time_slow")
	await _wait_frames(3)
	_check(is_equal_approx(float(_sp.get("world_speed_mult")), 1.0),
		"на остановленном потоке (босс, мини-игра) перк молчит")
	_sp.set("_frozen", false)

func _test_reflex() -> void:
	_use("spider_man", 10)
	_n.set("fat_state", 2)
	_n.call("_apply_skin_to_sprite")
	_n.set("_invincible", false)
	# Заряд считаем готовым: после _use он уже на откате (так и задумано —
	# реакция копится с начала забега), поэтому для проверки сбрасываем откат.
	(_n.get("_skill_cd") as Dictionary).erase("perk:spider_reflex")

	var fat_before : int = int(_n.get("fat_state"))
	# Предмет ставим ПОДАЛЬШЕ от головы и бьём им вручную. Положенный на голову,
	# он вдобавок к нашему вызову даёт настоящее столкновение от движка — то
	# есть два удара вместо одного, и тест ловит не реакцию, а свою же вторую
	# коллизию.
	var rock := _rock(Vector2(_n.position.x + 420.0, _n.position.y - 140.0))
	await process_frame
	_n.call("_handle_obstacle", rock)
	await _wait_frames(2)
	_check(int(_n.get("fat_state")) == fat_before,
		"первый удар ушёл в пустоту: жир %d → %d" % [fat_before, int(_n.get("fat_state"))])
	_check(_knocked(rock), "и предмет при этом сбит, а не пролетел сквозь")
	_check(not _n.call("is_skill_ready", "perk:spider_reflex"),
		"заряд потрачен")

	# Второй удар подряд обязан пройти: заряд ОДИН, а не неуязвимость.
	var rock2 := _rock(Vector2(_n.position.x + 420.0, _n.position.y + 140.0))
	await process_frame
	_n.call("_handle_obstacle", rock2)
	await _wait_frames(2)
	_check(int(_n.get("fat_state")) < fat_before,
		"а второй прошёл — это заряд, а не щит: жир %d" % int(_n.get("fat_state")))

	# Чужому скину реакция не достаётся.
	_use("viking", 10)
	_check(not bool(_n.get("_perk_reflex")), "у чужого скина реакции нет")

# Шаман обязан привести с собой ровно двух змей, и они обязаны ДЕРЖАТЬСЯ возле
# него, а не улететь своим курсом.
func _test_shaman() -> void:
	_sp.call("clear_items")
	_sp.set("_frozen", true)     # поток не нужен, проверяем одного шамана
	await process_frame
	var sh : Node2D = _sp.call("_hazard_node", "shaman", 120.0)
	sh.position = Vector2(get_root().get_visible_rect().size.x * 0.6,
		get_root().get_visible_rect().size.y * 0.5)
	_sp.add_child(sh)
	var snakes_before : int = _count("snake")
	# Призыв ждёт SHAMAN_CALL_AT РЕАЛЬНЫХ секунд после появления.
	await _wait_real(float(sh.SHAMAN_CALL_AT) + 0.6)
	var got : int = _count("snake") - snakes_before
	_check(got == 2, "шаман призвал двух змей: %d" % got)

	var near := true
	var lane : float = get_root().get_visible_rect().size.y / 5.0
	for s in get_root().get_tree().get_nodes_in_group("snake"):
		if (s as Node2D).position.distance_to(sh.position) > lane * 1.6:
			near = false
	_check(near, "и обе держатся возле него, а не улетели своим курсом")

	# Кружат: за полсекунды позиции обязаны смениться, оставшись рядом.
	var was : Array = []
	for s in get_root().get_tree().get_nodes_in_group("snake"):
		was.append((s as Node2D).position)
	await _wait_real(0.6)
	var moved := false
	for i in get_root().get_tree().get_nodes_in_group("snake").size():
		var s : Node2D = get_root().get_tree().get_nodes_in_group("snake")[i]
		if i < was.size() and s.position.distance_to(was[i]) > 8.0:
			moved = true
	_check(moved, "и кружат, а не висят приклеенными")

	# Хозяина не стало — змея доживает сама, а не исчезает и не зависает.
	var snake : Node2D = get_root().get_tree().get_nodes_in_group("snake")[0]
	sh.queue_free()
	await _wait_real(0.4)
	_check(is_instance_valid(snake),
		"со смертью шамана змея не растворяется")
	var x0 : float = snake.position.x
	await _wait_real(0.4)
	_check(snake.position.x < x0, "а летит дальше сама: %.0f → %.0f" % [x0, snake.position.x])

# ── Мелочи ───────────────────────────────────────────────────────────────────

func _use(skin: String, level: int) -> void:
	_save.set("active_skin", skin)
	_save.set("skin_level", level)
	_n.call("_build_skin_runtime")

func _rock(pos: Vector2) -> Area2D:
	var r := Area2D.new()
	r.set_script(load("res://scripts/hazard_item.gd"))
	r.set("kind", "helm")
	r.set("speed", 0.0)
	r.position = pos
	_sp.add_child(r)
	return r

# Сбитое не исчезает, а падает (см. knock_fall.gd) — спрашиваем то, что и
# означает «сбит».
func _knocked(n) -> bool:
	if not is_instance_valid(n):
		return true
	return bool(n.get("_falling"))

func _count(group: String) -> int:
	return get_root().get_tree().get_nodes_in_group(group).size()

func _wait_frames(k: int) -> void:
	for _i in k:
		get_root().get_tree().paused = false
		await process_frame

func _wait_real(sec: float) -> void:
	var t0 : int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		get_root().get_tree().paused = false
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
