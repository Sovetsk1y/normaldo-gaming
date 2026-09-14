extends SceneTree

# Экраны С ОСТРОВКОМ — по одному кадру на экран.
#   xvfb-run -a godot --path . --resolution 960x430 --script res://dev/shot_island_screens.gd -- <папка> <экран> [left|right]
#
# Экран: run | skins | grid | quests | leaders | awards | settings | pause

func _initialize() -> void:
	var argv := OS.get_cmdline_user_args()
	var out    : String = argv[0]
	var screen : String = argv[1] if argv.size() > 1 else "run"
	var side   : String = argv[2] if argv.size() > 2 else "left"
	DirAccess.make_dir_recursive_absolute(out)
	await process_frame
	var save := get_root().get_node("SaveData")
	save.set("tutorial_done", true)
	save.set("dollars", 99000)
	save.set("tokens", 83)
	save.set("episodes_done", 5)
	var seen : Dictionary = {}
	# «tour» — САМ ТУР, а не отдельная подсказка: без него облако «ОТСЮДА ЗАБЕГ»
	# ложится поперёк экрана и закрывает то, ради чего снимок и делается.
	for k in ["tour", "start", "quests", "skins", "slots", "leaders", "book", "awards"]:
		seen[k] = true
	save.set("menu_tips_seen", seen)
	TranslationServer.set_locale("ru")
	var game : Node = load("res://scenes/game.tscn").instantiate()
	get_root().add_child(game)
	await process_frame
	await process_frame
	var hud : Node = game.get_node("HUD")
	while hud.get("_mini_menu_btn") == null and hud.get("_menu_overlay") == null:
		await process_frame
	for i in (1 if side == "left" else 2):
		hud.call("_cycle_safe_sim")
	match screen:
		"run":      hud.call("_start_game")
		"skins":    hud.set("_skins_card_view", true);  hud.call("_show_shop")
		"grid":     hud.set("_skins_card_view", false); hud.call("_show_shop")
		"quests":   hud.call("_show_quests")
		"leaders":  hud.call("_show_leaderboard")
		"awards":   hud.call("_show_achievements")
		"settings": hud.call("_show_settings_modal", "sound")
		"pause":    hud.call("_start_game"); await _tick(1.0); hud.call("_open_pause_menu")
	await _tick(float(argv[3]) if argv.size() > 3 else 2.0)
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png("%s/isl_%s_%s.png" % [out, screen, side])
	print("saved ", screen, " ", side)
	quit()

func _tick(sec: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		get_root().get_tree().paused = false
		await process_frame
