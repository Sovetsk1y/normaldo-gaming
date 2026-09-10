extends SceneTree

# Снимки обучения.
#   xvfb-run -a godot --path . --script res://dev/shot_tutorial.gd -- <папка>

func _initialize() -> void:
	var argv := OS.get_cmdline_user_args()
	var out : String = argv[0] if argv.size() > 0 else "/tmp/claude-0/shots"
	DirAccess.make_dir_recursive_absolute(out)
	await process_frame
	get_root().get_node("SaveData").set("tutorial_done", false)
	var game : Node = load("res://scenes/game.tscn").instantiate()
	get_root().add_child(game)
	await process_frame
	get_root().get_tree().paused = false
	var hud : Node = game.get_node_or_null("HUD")
	var nd  : Node2D = game.get_node_or_null("Normaldo")
	hud.set("_play_from_menu", true)
	hud.call("_start_game")
	var t0 := Time.get_ticks_msec()
	while game.get_node_or_null("Tutorial") == null and Time.get_ticks_msec() - t0 < 8000:
		await process_frame
	await _wait(4.6)
	get_root().get_texture().get_image().save_png(out + "/tut_move.png")
	print("XX такт 1 снят")

	# Повели пальцем — обучение переходит к пицце.
	nd.position.y += 120.0
	await _wait(2.6)
	get_root().get_texture().get_image().save_png(out + "/tut_eat.png")
	print("XX такт 2 снят")
	quit()

func _wait(sec: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		get_root().get_tree().paused = false
		await process_frame
