extends SceneTree

# Кадры КОЛОДЫ ДЖОКЕРА — по одному на каждую фазу спелла.
#   xvfb-run -a godot --path . --resolution 960x430 --script res://dev/shot_cards.gd -- <папка>
#
# Кадры берутся ПО СОСТОЯНИЮ САМИХ КАРТ, а не по секундомеру: сколько карта
# летит до первой стены, зависит от того, где стоял Джокер, и снимок «через
# столько-то секунд» показывал бы каждый раз разное.
#
# Три фазы, и все три надо видеть отдельно:
#   cross  — только что брошены, крест ещё читается;
#   bounce — половина отскоков позади, карты разошлись по полю;
#   return — идут домой.

const WAIT_MAX : float = 20.0

var _out : String = "user://shots"

func _initialize() -> void:
	var argv := OS.get_cmdline_user_args()
	_out = argv[0] if argv.size() > 0 else "user://shots"
	DirAccess.make_dir_recursive_absolute(_out)

	var game : Node = load("res://scenes/game.tscn").instantiate()
	get_root().add_child(game)
	await process_frame
	var hud      : Node   = game.get_node_or_null("HUD")
	var normaldo : Node2D = game.get_node_or_null("Normaldo")
	var spawner  : Node   = game.get_node_or_null("Spawner")
	var save     : Node   = get_root().get_node_or_null("SaveData")

	# Меню — CanvasLayer поверх мира: снятый через него кадр показывает логотип,
	# а не поле.
	var boot := 0
	while boot < 900 and hud.get("_menu_overlay") == null:
		get_root().get_tree().paused = false
		await process_frame
		boot += 1
	hud.call("_start_game")
	boot = 0
	while boot < 2400 and hud.get("_menu_overlay") != null:
		get_root().get_tree().paused = false
		await process_frame
		boot += 1
	for _i in 30:
		get_root().get_tree().paused = false
		await process_frame

	save.active_skin = "joker"
	normaldo.call("reload_skin")
	normaldo.call("enable_input")
	normaldo.call("set_dev_immortal", true)
	# ПО ЦЕНТРУ: крест от головы у края экрана наполовину уходит за рамку, и по
	# такому кадру не видно, что лучей четыре.
	var vp : Vector2 = get_root().get_visible_rect().size
	normaldo.position = vp * 0.5
	# Поток не трогаем: карты обязаны быть видны НА ПОЛЕ, среди предметов, —
	# иначе непонятно, что именно они сбивают.
	await process_frame

	normaldo.call("_cast_card_deck", Vector2.RIGHT)
	await _shot(game, "cross", "крест из четырёх карт",
		func() -> bool: return _cards(game).size() == 4)
	# Половина отскоков позади.
	await _shot(game, "bounce", "карты после отскоков",
		func() -> bool: return _min_walls_used(game) >= 2)
	await _shot(game, "return", "возвращаются к Джокеру",
		func() -> bool: return _any_returning(game))
	print("saved")
	quit(0)

func _shot(game: Node, name: String, what: String, cond: Callable) -> void:
	var t := 0.0
	while t < WAIT_MAX and not bool(cond.call()):
		get_root().get_tree().paused = false
		await process_frame
		t += 1.0 / 60.0
	if t >= WAIT_MAX:
		print("НЕ ДОЖДАЛСЯ: %s" % what)
		return
	await RenderingServer.frame_post_draw
	var img := get_root().get_texture().get_image()
	img.save_png("%s/cards_%s.png" % [_out, name])
	print("снят %s" % what)

func _cards(game: Node) -> Array:
	var out : Array = []
	for c in game.get_children():
		if not is_instance_valid(c):
			continue
		var s = c.get_script()
		if s != null and String(s.resource_path).ends_with("skill_projectile.gd"):
			out.append(c)
	return out

# Сколько отскоков УЖЕ израсходовала самая «отбившаяся» карта.
func _min_walls_used(game: Node) -> int:
	var best := 0
	for c in _cards(game):
		var total : int = int(c.get("wall_bounces"))
		var left  : int = int(c.get("_walls_left"))
		best = maxi(best, total - left)
	return best

func _any_returning(game: Node) -> bool:
	for c in _cards(game):
		if bool(c.get("_returning")):
			return true
	return false
