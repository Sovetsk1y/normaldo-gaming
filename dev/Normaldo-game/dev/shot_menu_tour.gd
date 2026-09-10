extends SceneTree

# Снимки обучения по главному меню.
#   xvfb-run -a godot --path . --script res://dev/shot_menu_tour.gd -- <папка>

func _initialize() -> void:
	var argv := OS.get_cmdline_user_args()
	var out : String = argv[0] if argv.size() > 0 else "/tmp/claude-0/shots"
	DirAccess.make_dir_recursive_absolute(out)
	await process_frame
	var save := get_root().get_node("SaveData")
	save.set("tutorial_done", true)
	save.set("menu_tips_seen", {})
	save.set("skin_progress", {"classic": {"runs": 3}})
	var game : Node = load("res://scenes/game.tscn").instantiate()
	get_root().add_child(game)
	await process_frame
	get_root().get_tree().paused = false
	var hud : Node = game.get_node_or_null("HUD")
	var t0 := Time.get_ticks_msec()
	while hud.get_node_or_null("MenuTour") == null and Time.get_ticks_msec() - t0 < 9000:
		get_root().get_tree().paused = false
		await process_frame
	var tour : Node = hud.get_node_or_null("MenuTour")
	print("XX тур: ", tour)
	for i in 3:
		await _wait(1.0)
		get_root().get_texture().get_image().save_png("%s/tour_%d.png" % [out, i + 1])
		print("XX остановка ", i + 1, " снята")
		if is_instance_valid(tour):
			tour.call("_show", i + 1)
	quit()

func _wait(sec: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		get_root().get_tree().paused = false
		await process_frame
