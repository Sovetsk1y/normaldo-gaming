extends SceneTree

# Снимки экрана паузы и отсчёта возврата.
#   xvfb-run -a godot --path . --script res://dev/shot_pause.gd -- <папка> [имя] [режим]
#
# режим: menu — сам экран паузы; count — отсчёт 3-2-1 после «ПРОДОЛЖИТЬ»
# (снимается на цифре 2, чтобы в кадре были и цифра, и забег под затемнением).
#
# Работает только с настоящим рендером (x11/opengl3).

func _initialize() -> void:
	_bail_out()
	var argv := OS.get_cmdline_user_args()
	var out  : String = argv[0] if argv.size() > 0 else "user://shots"
	var name : String = argv[1] if argv.size() > 1 else "pause"
	var mode : String = argv[2] if argv.size() > 2 else "menu"
	DirAccess.make_dir_recursive_absolute(out)

	var game : Node = load("res://scenes/game.tscn").instantiate()
	get_root().add_child(game)
	await process_frame
	await process_frame
	var hud      : Node = game.get_node_or_null("HUD")
	var normaldo : Node = game.get_node_or_null("Normaldo")
	var spawner  : Node = game.get_node_or_null("Spawner")
	var bg       : Node = game.get_node_or_null("Background")
	# Пауза снимается ИЗ ЗАБЕГА: только тогда под затемнением видно то, ради чего
	# отсчёт и заведён — лейны, летящие предметы и сам Нормальдо.
	hud.call("_start_game")
	for _i in 10:
		await process_frame
	if spawner:
		spawner.campaign_mode = true
		spawner.set_process(true)
	if bg:
		bg.start_scrolling()
	normaldo.set("_total_pizza_count", 137)
	normaldo.set("_pizza_count", 46)
	hud.set("_dollars_this_run", 24)
	hud.set("_elapsed_time", 134.0)
	for _i in 150:
		await process_frame

	hud.call("_open_pause_menu")
	for _i in 40:
		await process_frame

	if mode == "count":
		var scr : Node = hud.get("_pause_overlay")
		scr.call("_on_resume")
		# Ждём середину отсчёта по ЧАСАМ, а не по кадрам: дерево на паузе, и
		# кадры здесь идут не в том темпе, что твин отсчёта.
		var t0 : float = Time.get_ticks_msec() / 1000.0
		while Time.get_ticks_msec() / 1000.0 - t0 < float(hud.get("RESUME_DIGIT_T")) * 1.5:
			await process_frame

	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png("%s/%s.png" % [out, name])
	print("saved ", name)
	quit(0)

func _bail_out() -> void:
	for _i in 1200:
		await process_frame
	push_error("shot_pause: не дошёл до съёмки, выходим по таймауту")
	quit(1)
