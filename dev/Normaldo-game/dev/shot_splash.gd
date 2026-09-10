extends SceneTree

# Снимки заставки запуска.
#   xvfb-run -a godot --path . --script res://dev/shot_splash.gd -- <папка>
#
# Заставка сама по себе на поднятой руками сцене не заводится (см.
# `Splash.should_play`), поэтому здесь она запускается явно — снимать надо её,
# а не проверку, при каких обстоятельствах она бывает.

func _initialize() -> void:
	var argv := OS.get_cmdline_user_args()
	var out : String = argv[0] if argv.size() > 0 else "/tmp/claude-0/shots"
	DirAccess.make_dir_recursive_absolute(out)
	await process_frame
	var save := get_root().get_node("SaveData")
	save.set("tutorial_done", false)
	save.set("menu_tips_seen", {})
	var game : Node = load("res://scenes/game.tscn").instantiate()
	get_root().add_child(game)
	await process_frame
	get_root().get_tree().paused = false
	var hud : Node = game.get_node_or_null("HUD")
	# Ждём, пока меню соберётся: заставка рисует логотип на его месте.
	var t0 := Time.get_ticks_msec()
	while hud.call("menu_logo_rect").size.x <= 1.0 and Time.get_ticks_msec() - t0 < 9000:
		get_root().get_tree().paused = false
		await process_frame
	var SPLASH := load("res://scripts/splash.gd")
	SPLASH.set("_played", false)
	var sp = SPLASH.call("play", hud)
	sp.connect("finished", func() -> void: hud.call("_after_splash"))
	# Время считается ОТ ЗАПУСКА ЗАСТАВКИ, а не от старта скрипта: меню перед
	# этим собирается сколько-то, и кадры уехали бы на эту разницу.
	var start := Time.get_ticks_msec()
	for shot in [[0.4, "splash_rain"], [1.1, "splash_logo"], [2.5, "splash_drain"],
			[3.1, "splash_fade"], [4.0, "splash_tip"]]:
		await _wait_until(float(shot[0]), start)
		get_root().get_texture().get_image().save_png("%s/%s.png" % [out, shot[1]])
		print("XX ", shot[1])
	quit()

func _wait_until(sec: float, start: int) -> void:
	while Time.get_ticks_msec() - start < int(sec * 1000.0):
		get_root().get_tree().paused = false
		await process_frame
