extends SceneTree

# Кадр слова WIN, которое выкладывается долларами после победы над боссом.
#   xvfb-run -a godot --path . --script res://dev/shot_win.gd -- <папка>
#
# Слово стартует ЗА правым краем и проезжает экран за пять секунд, поэтому
# снимать надо не момент выкладки, а момент, когда оно уже в кадре: слово
# подтягивается вручную.

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

	sp.call("lay_word", "WIN", false, 330.0)
	await process_frame
	# Подтягиваем слово в кадр: ждать пять секунд пролёта незачем, а в кадр оно
	# целиком всё равно не влезает — снимаем начало.
	var min_x := INF
	for c in sp.get_children():
		if c.is_in_group("dollar"):
			min_x = minf(min_x, (c as Node2D).position.x)
	var shift : float = min_x - vp.x * 0.16
	for c in sp.get_children():
		if c.is_in_group("dollar"):
			(c as Node2D).position.x -= shift
	for _i in 4:
		get_root().get_tree().paused = false
		await process_frame
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png("%s/win_word.png" % out)
	print("saved win_word")
	quit(0)
