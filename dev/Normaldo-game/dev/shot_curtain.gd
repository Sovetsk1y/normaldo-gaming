extends SceneTree

# Кадр ЗАНАВЕСА между эпизодами: «НЕМНОГО ПОЗДНЕЕ…», сюжетная строка и деньги.
#   xvfb-run -a godot --path . --rendering-driver opengl3 --script res://dev/shot_curtain.gd -- <папка> [эпизод]
#
# Именно этот переход видит игрок, начиная эпизод 2…5. Карточка уровня
# (`shot_levelcard.gd`) — другой переход, он бывает только в бесконечном.

func _initialize() -> void:
	var argv := OS.get_cmdline_user_args()
	var out : String = argv[0] if argv.size() > 0 else "user://shots"
	var ep  : int    = int(argv[1]) if argv.size() > 1 else 3
	DirAccess.make_dir_recursive_absolute(out)
	var game : Node = load("res://scenes/game.tscn").instantiate()
	get_root().add_child(game)
	await process_frame
	await process_frame
	var hud : Node = game.get_node_or_null("HUD")
	var sp  : Node = game.get_node_or_null("Spawner")
	sp.set("campaign_mode", true)
	sp.call("set_start_level", ep - 1)
	var story : String = String(sp.call("level_story"))
	print("эпизод %d → «%s»" % [ep, story])
	LevelTransition.play(hud, "НЕМНОГО ПОЗДНЕЕ…", func() -> void: pass, story)
	# Ждём, пока шторка закроется и текст проявится.
	for _i in 70:
		await process_frame
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png("%s/curtain.png" % out)
	print("saved")
	quit(0)
