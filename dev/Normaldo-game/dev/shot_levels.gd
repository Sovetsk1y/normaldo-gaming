extends SceneTree

# Кадры трёх уровней кампании — настоящий рендер.
#   xvfb-run -a godot --path . --script res://dev/shot_levels.gd -- <папка> <такт>
#
# такт: 1..3 — забег на соответствующем уровне; card — карточка перехода.

func _initialize() -> void:
	_bail_out()
	var argv := OS.get_cmdline_user_args()
	var out  : String = argv[0] if argv.size() > 0 else "user://shots"
	var mode : String = argv[1] if argv.size() > 1 else "1"
	DirAccess.make_dir_recursive_absolute(out)

	var game : Node = load("res://scenes/game.tscn").instantiate()
	get_root().add_child(game)
	await process_frame
	await process_frame
	var hud  : Node = game.get_node_or_null("HUD")
	var sp   : Node = game.get_node_or_null("Spawner")
	var bg   : Node = game.get_node_or_null("Background")
	var save : Node = get_root().get_node_or_null("SaveData")
	save.dollars = 12400
	save.active_skin = "classic"

	hud.call("_start_game")
	for _i in 190:
		await process_frame

	if mode == "card":
		hud.call("_show_level_card", 2)
		await _wait(0.9)
	else:
		var lvl : int = clampi(int(mode), 1, 3)
		sp.set("level", lvl - 1)
		sp.call("clear_items")
		bg.call("set_level", lvl)
		# Даём потоку набросать предметов ИМЕННО ЭТОГО уровня: кадр должен
		# показывать не только стену, но и то, чем локация встречает.
		sp.set("_frozen", false)
		sp.set("_pattern_running", false)
		sp.set_process(true)
		await _wait(4.0)

	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png("%s/level_%s.png" % [out, mode])
	print("saved ", mode)
	quit(0)

func _wait(sec: float) -> void:
	var t := 0.0
	while t < sec:
		get_root().get_tree().paused = false
		await process_frame
		t += 1.0 / 60.0

func _bail_out() -> void:
	for _i in 4000:
		await process_frame
