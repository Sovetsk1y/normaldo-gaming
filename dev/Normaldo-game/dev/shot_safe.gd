extends SceneTree

# Кадр сейфа рядом с камнем и бочкой.
#   xvfb-run -a godot --path . --script res://dev/shot_safe.gd -- <папка>
#
# Сейф долго показывался КОПИЕЙ КАМНЯ, и это было не видно: страница
# собиралась, предмет летел, всё «работало». Кадр нужен ровно для сравнения —
# сейф, камень и бочка в одном ряду, чтобы разница в рисунке и в размере
# читалась сразу.

func _initialize() -> void:
	var argv := OS.get_cmdline_user_args()
	var out : String = argv[0] if argv.size() > 0 else "user://shots"
	DirAccess.make_dir_recursive_absolute(out)
	var game : Node = load("res://scenes/game.tscn").instantiate()
	get_root().add_child(game)
	await process_frame
	var hud : Node = game.get_node_or_null("HUD")
	var n   : Node = game.get_node_or_null("Normaldo")
	var sp  : Node = game.get_node_or_null("Spawner")
	var boot := 0
	while boot < 900 and hud.get("_menu_overlay") == null:
		get_root().get_tree().paused = false
		await process_frame
		boot += 1
	hud.call("_start_game")
	boot = 0
	while boot < 1800 and hud.get("_menu_overlay") != null:
		get_root().get_tree().paused = false
		await process_frame
		boot += 1
	for _i in 70:
		get_root().get_tree().paused = false
		await process_frame
	var vp : Vector2 = get_root().get_visible_rect().size
	(n as Node2D).position = Vector2(110.0, vp.y * 0.5)
	n.set("_dev_immortal", true)
	sp.call("clear_items")
	sp.set_process(false)
	await process_frame

	var lanes : Array = sp.call("_lane_centers")
	sp.call("_spawn_level_hazard", "safe",  float(lanes[1]), vp.x, 0.0)
	sp.call("_spawn_level_hazard", "stone", float(lanes[2]), vp.x, 0.0)
	sp.call("_spawn_level_hazard", "trash", float(lanes[3]), vp.x, 0.0)
	await process_frame
	# Ставим всех троих в кадр в ряд: спавнятся они за правым краем.
	var i := 0
	for c in sp.get_children():
		if c is Node2D and not (c is AudioStreamPlayer):
			(c as Node2D).position.x = vp.x * (0.34 + 0.18 * float(i))
			i += 1
	for _i in 6:
		get_root().get_tree().paused = false
		await process_frame
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png("%s/safe.png" % out)
	print("saved safe")
	quit(0)
