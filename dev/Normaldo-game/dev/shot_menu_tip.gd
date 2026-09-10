extends SceneTree

# Снимок разовой подсказки по поводу.
#   xvfb-run -a godot --path . --script res://dev/shot_menu_tip.gd -- <папка>

func _initialize() -> void:
	var argv := OS.get_cmdline_user_args()
	var out : String = argv[0] if argv.size() > 0 else "/tmp/claude-0/shots"
	DirAccess.make_dir_recursive_absolute(out)
	await process_frame
	var save := get_root().get_node("SaveData")
	save.set("tutorial_done", true)
	save.set("skin_progress", {"classic": {"runs": 5}})
	save.set("menu_tips_seen", {"tour": true})
	save.set("tokens", 4)
	var game : Node = load("res://scenes/game.tscn").instantiate()
	get_root().add_child(game)
	await process_frame
	get_root().get_tree().paused = false
	var hud : Node = game.get_node_or_null("HUD")
	var t0 := Time.get_ticks_msec()
	while hud.get_node_or_null("MenuTour") == null and Time.get_ticks_msec() - t0 < 9000:
		get_root().get_tree().paused = false
		await process_frame
	var tip : Node = hud.get_node_or_null("MenuTour")
	print("XX подсказка: ", tip.get("_key") if tip != null else "нет")
	var t1 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t1 < 1200:
		get_root().get_tree().paused = false
		await process_frame
	get_root().get_texture().get_image().save_png(out + "/menu_tip.png")
	quit()
