extends SceneTree

# Headless-проверка бомжа с бочкой.
#   godot --headless --path . --script res://dev/smoke_bum_barrel.gd
#
# Смысл этого вида в ПОДГОТОВКЕ: сначала он неотличим от обычного предмета
# потока, потом вдруг тормозит, и только потом появляется угроза. Игрок успевает
# прочитать «сейчас оттуда вылетит». Если собака вылетает мгновенно или не
# вылетает вовсе — вид ничем не отличается от обычного предмета.
#
# См. /Концепция/Паттерны препятствий.md

var _fails  : int = 0
var _checks : int = 0
const EXPECTED_CHECKS : int = 14

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

	var bum : Sprite2D = node.get("_bum")
	var bar : Sprite2D = node.get("_barrel")
	_check(bum != null and bar != null, "в сцене есть и бомж, и бочка")
	if bum == null or bar == null:
		_finish()
		return

	# Размеры. Отзыв был буквально «бомж маленький, бочка ещё меньше»: обе
	# картинки нормировались ПО КАДРУ, а у бочки рисунок занимает половину кадра.
	# Меряем нарисованное, а не рамку.
	var bum_px : float = _drawn_h(bum)
	var bar_px : float = _drawn_h(bar)
	_check(bum_px > 100.0, "бомж крупный: %.0f px (рядовой в волне — 66)" % bum_px)
	_check(bar_px > 90.0, "бочка не мельче собаки: %.0f px (собака — 96)" % bar_px)

	# Сначала — обычный предмет потока: летит с той же скоростью, ничего не
	# отыгрывает. Именно на фоне этого читается последующее торможение.
	var x0 : float = node.position.x
	await _wait(0.25)
	var x1 : float = node.position.x
	var v  : float = (x0 - x1) / 0.25
	_check(String(node.get("_phase")) == "enter", "пока не показался целиком — просто летит")
	_check(absf(v - 250.0) < 45.0, "и летит со скоростью потока: %.0f против 250" % v)
	_check(bar.texture == load("res://assets/items/barrel_open1.png"),
		"бочку несёт СТОЯЧЕЙ, крышка закрыта")

	# Собаки в первые полторы секунды быть не должно — идёт подготовка.
	await _wait(1.0)
	_check(_dogs(sp) == 0, "пока подъезжает и ставит — собаки нет")
	var x_mid : float = node.position.x if is_instance_valid(node) else -1.0
	_check(x_mid < vp.x, "успел затормозить в кадре: x=%.0f" % x_mid)

	# А дальше — открытая бочка и собака из неё.
	await _wait(1.6)
	_check(bar.texture == load("res://assets/items/trash_bin.png"),
		"к выстрелу бочка ОТКРЫТА (последний кадр, а не первый)")
	var dogs : Array = _dog_nodes(sp)
	_check(dogs.size() >= 1, "собака вылетела: %d" % dogs.size())
	if not dogs.is_empty():
		var d : Node2D = dogs[0]
		_check(absf(d.position.y - (n as Node2D).position.y) < 30.0,
			"и летит по линии Нормальдо: %.0f против %.0f"
				% [d.position.y, (n as Node2D).position.y])

	# Бочку он БРОСАЕТ. Раньше уезжала вся сцена целиком, и бомж утаскивал
	# только что поставленную бочку за собой.
	await _wait(0.6)
	if is_instance_valid(node):
		_check(bum.global_position.x < bar.global_position.x,
			"ушёл, бочку бросил: бомж %.0f, бочка %.0f"
				% [bum.global_position.x, bar.global_position.x])
	_finish()

# Высота НАРИСОВАННОГО на экране, а не рамки кадра.
func _drawn_h(spr: Sprite2D) -> float:
	var r : Rect2i = ItemSizing.content_rect(spr.texture)
	return float(r.size.y) * absf(spr.scale.y)

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
