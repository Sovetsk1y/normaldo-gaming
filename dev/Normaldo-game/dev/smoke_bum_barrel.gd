extends SceneTree

# Headless-проверка бомжа с бочкой.
#   godot --headless --path . --script res://dev/smoke_bum_barrel.gd
#
# Смысл этого вида в ПОДГОТОВКЕ: угроза появляется не сразу, игрок успевает
# прочитать «сейчас оттуда вылетит». Если собака вылетает мгновенно или не
# вылетает вовсе — вид ничем не отличается от обычного предмета.
#
# См. /Концепция/Паттерны препятствий.md

var _fails  : int = 0
var _checks : int = 0
const EXPECTED_CHECKS : int = 6

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
	await process_frame

	print("── Приезд, бочка, собака ──")
	var vp : Vector2 = get_root().get_visible_rect().size
	(n as Node2D).position = Vector2(220.0, vp.y * 0.5)
	# Пять линий, как в настоящем забеге: сет-пис выбирает лейн случайно, и
	# массив из одного элемента ему не подходит.
	var lanes : Array = []
	for i in 5:
		lanes.append(vp.y * (float(i) + 0.5) / 5.0)
	(n as Node2D).position = Vector2(220.0, lanes[2])
	sp.call("_setpiece_bum_barrel", 250.0, lanes, vp.x)
	await process_frame

	var node : Node2D = _find_barrel(sp)
	_check(node != null, "бомж с бочкой появился")
	if node == null:
		_finish()
		return
	_check(node.position.x > vp.x, "стартует ИЗ-ЗА правого края: x=%.0f" % node.position.x)

	# Собаки в первые полсекунды быть не должно — идёт подготовка.
	await _wait(0.45)
	_check(_dogs(sp) == 0, "пока подъезжает — собаки нет")

	var x_mid : float = node.position.x if is_instance_valid(node) else -1.0
	_check(x_mid < vp.x, "успел затормозить в кадре: x=%.0f" % x_mid)

	# А через полторы секунды — вылетела и целится в линию Нормальдо.
	await _wait(1.4)
	var dogs : Array = _dog_nodes(sp)
	_check(dogs.size() >= 1, "собака вылетела: %d" % dogs.size())
	if not dogs.is_empty():
		var d : Node2D = dogs[0]
		_check(absf(d.position.y - (n as Node2D).position.y) < 30.0,
			"и летит по линии Нормальдо: %.0f против %.0f"
				% [d.position.y, (n as Node2D).position.y])
	_finish()

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

func _wait(sec: float) -> void:
	var t := 0.0
	while t < sec:
		await process_frame
		t += 1.0 / 60.0

func _find_barrel(sp: Node) -> Node2D:
	for c in sp.get_children():
		if c.get_script() != null and String(c.get_script().resource_path).ends_with("bum_barrel.gd"):
			return c
	return null

func _dogs(sp: Node) -> int:
	return _dog_nodes(sp).size()

func _dog_nodes(sp: Node) -> Array:
	var out : Array = []
	for c in sp.get_children():
		if c.scene_file_path != "" and c.scene_file_path.ends_with("dog.tscn"):
			out.append(c)
	return out
