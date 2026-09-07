extends SceneTree

# Обесцвечивание мира на замедлении времени.
#   godot --headless --path . --script res://dev/smoke_gray.gd
#
# Проверять тут надо не «красиво ли», а ДВА невидимых свойства.
#
# 1. Слой накрывает МИР, но не интерфейс. HUD — это CanvasLayer, а слои рисуются
#    поверх обычного холста при любом z_index; значит серый прямоугольник обязан
#    жить под корнем сцены, а не в HUD, иначе он либо накроет приборы, либо
#    окажется под предметами.
# 2. Эффект включается и снимается САМ, из общей воронки `apply_slow_mo`.
#    Замедление приходит с двух сторон — песочные часы и венец мага, — и если
#    вешать его на источники по отдельности, третий источник забудут.
#
# См. /Концепция/Эффекты и бонусы.md

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
	var game : Node = load("res://scenes/game.tscn").instantiate()
	get_root().add_child(game)
	await process_frame
	await process_frame

	var spawner : Node = game.get_node_or_null("Spawner")
	if spawner == null:
		print("  FAIL сцена не собралась")
		quit(1)
		return

	print("── Чёрно-белый мир ──")
	# До замедления слоя нет вовсе: копия кадра каждый кадр стоит денег, и
	# держать её «на всякий случай» не за что.
	_check(game.get_node_or_null("WorldGray") == null, "без замедления слоя нет")

	spawner.call("apply_slow_mo", 0.4, 0.6)
	for _i in 10:
		await process_frame
	var gray : Node = game.get_node_or_null("WorldGray")
	_check(gray != null, "замедление подняло слой")
	if gray == null:
		_done()
		return
	_check(bool(gray.call("is_gray")), "и мир обесцвечен")

	# Слой стоит ПОД КОРНЕМ сцены, а не в HUD: иначе он накрыл бы приборы.
	_check(gray.get_parent() == game, "слой живёт в сцене, а не в интерфейсе")
	var hud : Node = game.get_node_or_null("HUD")
	_check(hud != null and not _is_under(gray, hud), "и не внутри HUD")

	# Выше любого игрового z_index — иначе предметы рисовались бы поверх серого
	# и остались бы цветными.
	var rect : Node = gray.get_node_or_null("Gray")
	_check(rect != null and int(rect.get("z_index")) >= 1000,
		"прямоугольник выше всего игрового по z")

	# И снимается сам, когда замедление кончилось.
	for _i in 90:
		await process_frame
	_check(not bool(gray.call("is_gray")), "по окончании цвет вернулся")
	_done()

func _is_under(node: Node, root: Node) -> bool:
	var p : Node = node
	while p != null:
		if p == root:
			return true
		p = p.get_parent()
	return false

func _done() -> void:
	if _fails == 0:
		print("ВСЁ ЗЕЛЁНОЕ (проверок: %d)" % _checks)
	else:
		print("ПРОВАЛОВ: %d" % _fails)
	quit(0)
