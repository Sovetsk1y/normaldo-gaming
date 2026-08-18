extends SceneTree

# Снимок экрана заданий.
#   xvfb-run -a godot --path . --script res://dev/shot_quests.gd -- <папка> [имя]
#
# Работает только с настоящим рендером (x11/opengl3).

func _initialize() -> void:
	var argv := OS.get_cmdline_user_args()
	var out  : String = argv[0] if argv.size() > 0 else "user://shots"
	var name : String = argv[1] if argv.size() > 1 else "quests"
	DirAccess.make_dir_recursive_absolute(out)

	var game : Node = load("res://scenes/game.tscn").instantiate()
	get_root().add_child(game)
	await process_frame
	await process_frame
	var hud : Node = game.get_node_or_null("HUD")

	# Сейв под съёмку: деньги на счету и задания в разном состоянии, чтобы в
	# кадр попали и невыполненное, и готовое к получению.
	var save : Node = get_root().get_node_or_null("SaveData")
	save.dollars = 1024
	save.tokens  = 83
	var qm : Node = get_root().get_node_or_null("QuestManager")
	if qm != null:
		qm.reroll_daily_quests()
		var st : Array = qm.get("daily_slots")
		if st.size() >= 2:
			st[0]["progress"] = 999999   # первое выполнено — видно кнопку «ЗАБРАТЬ»
			st[1]["progress"] = 0
		qm.emit_signal("quests_updated")

	var screen : Node = load("res://scripts/quests_screen.gd").new()
	screen.call("setup", hud)
	hud.add_child(screen)
	var t := 0.0
	while t < 1.2:
		await process_frame
		t += get_root().get_process_delta_time()
	await RenderingServer.frame_post_draw
	var img := get_root().get_texture().get_image()
	img.save_png("%s/%s.png" % [out, name])
	print("saved ", name)
	quit(0)
