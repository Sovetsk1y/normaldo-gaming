extends SceneTree

# Кадры тачки копов: как идёт и что остаётся после аварии.
#   xvfb-run -a godot --path . --script res://dev/shot_police_car.gd -- <папка>
#
# Два кадра. Первый — машина на подходе: видно, что она занимает две линии из
# пяти и что рядом остаётся щель. Второй — сразу после аварии: два копа на
# соседних линиях.

func _initialize() -> void:
	var argv := OS.get_cmdline_user_args()
	var out : String = argv[0] if argv.size() > 0 else "user://shots"
	DirAccess.make_dir_recursive_absolute(out)
	var game : Node = load("res://scenes/game.tscn").instantiate()
	get_root().add_child(game)
	await process_frame
	var hud : Node = game.get_node_or_null("HUD")
	var n   : Node = game.get_node_or_null("Normaldo")
	var sp  : Node = game.get_node_or_null("Spawner")
	var boot := 0
	while boot < 900 and hud.get("_menu_overlay") == null:
		get_root().get_tree().paused = false
		await process_frame
		boot += 1
	hud.call("_start_game")
	boot = 0
	while boot < 1800 and hud.get("_menu_overlay") != null:
		get_root().get_tree().paused = false
		await process_frame
		boot += 1
	for _i in 70:
		get_root().get_tree().paused = false
		await process_frame
	var vp : Vector2 = get_root().get_visible_rect().size
	(n as Node2D).position = Vector2(110.0, vp.y * 0.5)
	n.set("_dev_immortal", true)
	sp.call("clear_items")
	sp.set_process(false)
	await process_frame

	sp.call("_spawn_police_car", 0.0, vp.x, 250.0)
	await process_frame
	var car : Node2D = null
	for c in sp.get_children():
		if c.is_in_group("police_car"):
			car = c
	if car == null:
		print("машина не появилась")
		quit(1)
		return
	car.position.x = vp.x * 0.62
	for _i in 4:
		get_root().get_tree().paused = false
		await process_frame
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png("%s/police_car.png" % out)
	print("saved police_car")

	# Авария: ждём копов на своих линиях.
	car.call("_crash")
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 900:
		get_root().get_tree().paused = false
		await process_frame
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png("%s/police_car_crash.png" % out)
	print("saved police_car_crash")
	quit(0)
