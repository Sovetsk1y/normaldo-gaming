extends SceneTree

# Кадр РЕПЛИКИ БОССА: облачко и текст в нём.
#   xvfb-run -a godot --path . --rendering-driver opengl3 --script res://dev/shot_speech.gd -- <папка>

const BOSS_SPEECH := preload("res://scripts/boss_speech.gd")

func _initialize() -> void:
	var argv := OS.get_cmdline_user_args()
	var out : String = argv[0] if argv.size() > 0 else "user://shots"
	DirAccess.make_dir_recursive_absolute(out)
	var game : Node = load("res://scenes/game.tscn").instantiate()
	get_root().add_child(game)
	await process_frame
	await process_frame
	BOSS_SPEECH.show(game, game, "ТЫ ЖИРНЫЙ И МЕДЛЕННЫЙ.\nЯ БЫСТРЫЙ.", 220.0,
		Color(0.10, 0.06, 0.14), Color(0.92, 0.26, 0.30), Color(0.98, 0.96, 1.00),
		6.0, 0.32)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 900:
		await process_frame
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png("%s/speech.png" % out)
	print("saved")
	quit(0)
