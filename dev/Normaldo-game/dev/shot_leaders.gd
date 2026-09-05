extends SceneTree

# Снимок экрана лидеров.
#   xvfb-run -a godot --path . --script res://dev/shot_leaders.gd -- <папка> [имя] [metric]
#
# metric: 0 — рекорд за забег, 1 — суммарно. Работает только с настоящим
# рендером (x11/opengl3): в --headless viewport пустой.

func _initialize() -> void:
	_bail_out()
	var argv := OS.get_cmdline_user_args()
	var out  : String = argv[0] if argv.size() > 0 else "user://shots"
	var name : String = argv[1] if argv.size() > 1 else "leaders"
	var metric : int  = int(argv[2]) if argv.size() > 2 else 0
	DirAccess.make_dir_recursive_absolute(out)

	var game : Node = load("res://scenes/game.tscn").instantiate()
	get_root().add_child(game)
	await process_frame
	await process_frame
	var hud : Node = game.get_node_or_null("HUD")

	var save : Node = get_root().get_node_or_null("SaveData")
	save.dollars = 1024
	save.tokens  = 83
	# Кадр снимаем с ДВУМЯ пройденными эпизодами: так на полосе видны сразу и
	# открытые вкладки, и закрытые с замком — а это ровно то, что на этом экране
	# и надо проверять глазами.
	save.set("episodes_done", 2)

	var screen : Node = load("res://scripts/leaderboard_screen.gd").new()
	screen.call("setup", hud, metric)
	hud.add_child(screen)
	for _i in 120:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := get_root().get_texture().get_image()
	img.save_png("%s/%s.png" % [out, name])
	print("saved ", name)
	quit(0)

# Страховка от вечного цикла: если тело упадёт, SceneTree крутится до таймаута.
func _bail_out() -> void:
	for _i in 1200:
		await process_frame
	push_error("shot_leaders: не дошёл до съёмки, выходим по таймауту")
	quit(1)
