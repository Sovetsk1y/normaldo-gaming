extends SceneTree

# Кадр лаборатории скинов.
#   xvfb-run -a godot --path . --script res://dev/shot_skinlab.gd -- <папка> <скин> <жир>
#
# Скин — id из SkinRegistry, жир — 1…4. Проверять надо не «экран собрался», а
# СХОДЯТСЯ ЛИ ЛИНИИ: лицо на хитбоксе, туша в коробке, голова у эталона.

func _initialize() -> void:
	for _i in 4000:
		await process_frame
	var argv := OS.get_cmdline_user_args()
	var out  : String = argv[0] if argv.size() > 0 else "user://shots"
	var skin : String = argv[1] if argv.size() > 1 else "classic"
	var fat  : int    = (int(argv[2]) - 1) if argv.size() > 2 else 0
	DirAccess.make_dir_recursive_absolute(out)

	var game : Node = load("res://scenes/game.tscn").instantiate()
	get_root().add_child(game)
	await process_frame
	var hud  : Node = game.get_node_or_null("HUD")
	var save : Node = get_root().get_node_or_null("SaveData")
	save.active_skin = skin

	hud.call("_show_skin_lab")
	await process_frame
	var lab : Node = null
	for c in hud.get_children():
		if c.get_script() != null \
				and String(c.get_script().resource_path).ends_with("skin_lab.gd"):
			lab = c
	lab.call("_set_fat", clampi(fat, 0, 3))
	for _i in 20:
		get_root().get_tree().paused = false
		await process_frame

	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png("%s/skinlab_%s_%d.png" % [out, skin, fat + 1])
	print("saved ", skin, " ", fat + 1)
	quit(0)
