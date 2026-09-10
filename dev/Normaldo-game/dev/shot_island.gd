extends SceneTree

# Снимок интерфейса С ОСТРОВКОМ — тем самым вырезом на айфонах.
#   xvfb-run -a godot --path . --script res://dev/shot_island.gd -- left|right
#
# Островок подменяется дев-чипом «ОСТРОВ» из левого столбца: настоящий есть
# только на устройстве, а разметку правят здесь.

func _initialize() -> void:
	var out := "/tmp/claude-0/shots"
	DirAccess.make_dir_recursive_absolute(out)
	var side : String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "left"
	var game : Node = load("res://scenes/game.tscn").instantiate()
	get_root().add_child(game)
	await process_frame
	await process_frame
	var hud : Node = game.get_node_or_null("HUD")
	var sp  : Node = game.get_node_or_null("Spawner")
	hud.call("_start_game")
	while hud.get("_mini_menu_btn") == null:
		await process_frame
	var steps : int = 1 if side == "left" else 2
	for i in steps:
		hud.call("_cycle_safe_sim")
	var t := 0.0
	while t < 2.5:
		await process_frame
		t += 1.0 / 60.0
	var sa : Node = get_root().get_node("/root/SafeArea")
	print("XX safe=", sa.call("rect"), " insets=", sa.call("insets"))
	print("XX hud scale=", hud.scale, " offset=", hud.offset)
	get_root().get_texture().get_image().save_png(out + "/safe_" + side + ".png")
	quit()
