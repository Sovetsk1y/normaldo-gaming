extends SceneTree

# Кадр замедления времени: мир обесцвечен, приборы цветные.
#   xvfb-run -a godot --path . --rendering-driver opengl3 --script res://dev/shot_gray.gd -- <папка>
#
# Только с настоящим рендером: в --headless viewport пустой, а весь эффект —
# экранный шейдер поверх уже нарисованного кадра.

func _initialize() -> void:
	var argv := OS.get_cmdline_user_args()
	var out : String = argv[0] if argv.size() > 0 else "user://shots"
	DirAccess.make_dir_recursive_absolute(out)

	var game : Node = load("res://scenes/game.tscn").instantiate()
	get_root().add_child(game)
	await process_frame
	await process_frame
	var nrm : Node = game.get_node_or_null("Normaldo")
	var sp  : Node = game.get_node_or_null("Spawner")
	var bg  : Node = game.get_node_or_null("Background")
	nrm.call("enable_input")
	nrm.call("set_dev_immortal", true)
	sp.set("campaign_mode", true)
	sp.set_process(true)
	if bg:
		bg.call("start_scrolling")
	# Даём потоку наполнить экран, иначе серым будет нечего красить.
	for _i in 200:
		await process_frame
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png("%s/before.png" % out)

	sp.call("apply_slow_mo", 0.35, 6.0)
	for _i in 40:
		await process_frame
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png("%s/gray.png" % out)
	print("saved")
	quit(0)
