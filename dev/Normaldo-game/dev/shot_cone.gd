extends SceneTree
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
	sp.call("clear_items"); sp.set_process(false)
	var vp : Vector2 = get_root().get_visible_rect().size
	(n as Node2D).position = Vector2(90.0, vp.y * 0.5)
	n.set("_dev_immortal", true)
	sp.call("_spawn_cone", vp.x, 0.0)
	for _i in 30:
		get_root().get_tree().paused = false
		await process_frame
	for c in sp.get_children():
		if c.is_in_group("cone"):
			(c as Node2D).position.x = vp.x * 0.55
	for _i in 20:
		get_root().get_tree().paused = false
		await process_frame
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png("%s/cone.png" % out)
	print("saved cone")
	quit(0)
