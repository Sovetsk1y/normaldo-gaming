extends SceneTree

# Кадр сейфа рядом с камнем и бочкой.
#   xvfb-run -a godot --path . --script res://dev/shot_safe.gd -- <папка>
#
# Сейф долго показывался КОПИЕЙ КАМНЯ, и это было не видно: страница
# собиралась, предмет летел, всё «работало». Кадр нужен ровно для сравнения —
# сейф, камень и бочка в одном ряду, чтобы разница в рисунке и в размере
# читалась сразу.

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

	var lanes : Array = sp.call("_lane_centers")
	var mode : String = argv[1] if argv.size() > 1 else "row"
	if mode == "crack":
		# Вскрытие: сейф на голове, раскрытый, и из него сыплются доллары.
		# Голову отодвигаем от края: у левого борта сейф налезает на интерфейс, и
		# кадр показывает не механику, а неудачно выбранную точку съёмки.
		(n as Node2D).position = Vector2(vp.x * 0.28, vp.y * 0.56)
		sp.call("_spawn_safe", vp.y * 0.5, vp.x, 0.0)
		await process_frame
		var safe : Node2D = null
		for c in sp.get_children():
			if c.is_in_group("safe"):
				safe = c
		if safe == null:
			print("сейф не появился")
			quit(1)
			return
		safe.call("crack_open", n)
		# Ждём, пока высыплется половина пачки: в кадре нужен и раскрытый сейф на
		# голове, и деньги в воздухе.
		var t0 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < 900:
			get_root().get_tree().paused = false
			await process_frame
		await RenderingServer.frame_post_draw
		get_root().get_texture().get_image().save_png("%s/safe_crack.png" % out)
		print("saved safe_crack")
		quit(0)
		return

	sp.call("_spawn_level_hazard", "safe",  float(lanes[1]), vp.x, 0.0)
	sp.call("_spawn_level_hazard", "stone", float(lanes[2]), vp.x, 0.0)
	sp.call("_spawn_level_hazard", "trash", float(lanes[3]), vp.x, 0.0)
	await process_frame
	# Ставим всех троих в кадр в ряд: спавнятся они за правым краем.
	var i := 0
	for c in sp.get_children():
		if c is Node2D and not (c is AudioStreamPlayer):
			(c as Node2D).position.x = vp.x * (0.34 + 0.18 * float(i))
			i += 1
	for _i in 6:
		get_root().get_tree().paused = false
		await process_frame
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png("%s/safe.png" % out)
	print("saved safe")
	quit(0)
