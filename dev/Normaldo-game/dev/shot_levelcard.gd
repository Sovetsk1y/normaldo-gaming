extends SceneTree

# Кадр карточки перехода между эпизодами: доллары через экран + сюжетная строка.
#   xvfb-run -a godot --path . --rendering-driver opengl3 --script res://dev/shot_levelcard.gd -- <папка>
#
# Только с настоящим рендером: карточка — это летящие спрайты поверх забега.

func _initialize() -> void:
	var argv := OS.get_cmdline_user_args()
	var out : String = argv[0] if argv.size() > 0 else "user://shots"
	DirAccess.make_dir_recursive_absolute(out)
	var game : Node = load("res://scenes/game.tscn").instantiate()
	get_root().add_child(game)
	await process_frame
	await process_frame
	var hud : Node = game.get_node_or_null("HUD")
	var sp  : Node = game.get_node_or_null("Spawner")
	var nrm : Node = game.get_node_or_null("Normaldo")
	nrm.call("enable_input")
	sp.set("campaign_mode", true)
	hud.call("_show_level_card", 1)
	# Ждём, пока затемнение доедет и подпись проявится.
	for _i in 90:
		await process_frame
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png("%s/levelcard.png" % out)
	print("saved")
	quit(0)
