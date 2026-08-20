extends SceneTree

# Снимок интерфейса ВО ВРЕМЯ забега.
#   xvfb-run -a godot --path . --script res://dev/shot_run.gd -- <папка> [имя] [скин] [жир] [cd]
#
# скин — id скина (по умолчанию joker: у него больше всего кружков);
# жир   — 0..3;
# cd    — «cd» ставит часть способностей на откат, чтобы в кадр попали
#         и готовые кружки, и остывающие.
# Работает только с настоящим рендером (x11/opengl3).

func _initialize() -> void:
	_bail_out()
	var argv := OS.get_cmdline_user_args()
	var out  : String = argv[0] if argv.size() > 0 else "user://shots"
	var name : String = argv[1] if argv.size() > 1 else "run"
	var skin : String = argv[2] if argv.size() > 2 else "joker"
	var fat  : int    = int(argv[3]) if argv.size() > 3 else 1
	var cd   : bool   = argv.size() > 4 and argv[4] == "cd"
	DirAccess.make_dir_recursive_absolute(out)

	var game : Node = load("res://scenes/game.tscn").instantiate()
	get_root().add_child(game)
	await process_frame
	await process_frame

	var hud      : Node = game.get_node_or_null("HUD")
	var normaldo : Node = game.get_node_or_null("Normaldo")
	var spawner  : Node = game.get_node_or_null("Spawner")
	var bg       : Node = game.get_node_or_null("Background")
	var save     : Node = get_root().get_node_or_null("SaveData")

	save.dollars      = 12400
	save.tokens       = 83
	save.owned_skins  = ["classic", "viking", "tyson", "harry_potter", "joker", "batman"]
	save.active_skin  = skin
	save.skin_level   = 10          # чтобы были открыты все способности
	normaldo.call("reload_skin")
	normaldo.call("_build_skin_runtime")

	hud.call("_start_game")
	for _i in 10:
		await process_frame
	normaldo.set("fat_state", fat)
	normaldo.call("_apply_skin_to_sprite")
	if spawner:
		spawner.campaign_mode = true
		spawner.set_process(true)
	if bg:
		bg.start_scrolling()

	# Немного добычи в счётчики, иначе в кадре везде нули.
	normaldo.set("_pizza_count", 46)
	normaldo.set("_total_pizza_count", 137)
	normaldo.emit_signal("stats_changed", fat, 46, 137)

	for _i in 150:
		await process_frame

	# Режим «marks»: ставим на экран ровно те предметы, к которым у скина есть
	# резист, — иначе в кадр попадает случайная волна бананов, и метку показать
	# не на чем.
	if name.begins_with("marks") or (argv.size() > 5 and argv[5] == "marks"):
		spawner.call("clear_items")
		var vpw : float = get_root().get_visible_rect().size.x
		var rows : Array = [
			[0.30, spawner.TRASH_TEX, 0.30],
			[0.55, spawner.STONE_TEX, 0.30],
			[0.80, spawner.TRASH_TEX, 0.30],
		]
		for ri in rows.size():
			var row : Array = rows[ri]
			for k in 3:
				var it : Node = spawner.call("_spawn_item",
					get_root().get_visible_rect().size.y * float(row[0]),
					vpw - 180.0 * float(k) - 40.0, row[1], float(row[2]), 0.0, 1)
				it.position.x = vpw - 210.0 * float(k) - 150.0
		for _i in 4:
			await process_frame

	if cd:
		# Часть кружков — на откате: в кадр должны попасть оба состояния.
		var layer : Node = hud.get("_skill_badges_layer")
		var n := 0
		for b in layer.get_children():
			var key : String = String(b.get("key"))
			if key == "":
				continue
			if n % 2 == 0:
				normaldo.call("start_skill_cd", key, 8.0)
			n += 1
		for _i in 30:
			await process_frame

	# Пауза снимается тем же путём, что открывает игрок.
	if argv.size() > 5 and String(argv[5]).begins_with("pause"):
		hud.call("_open_pause_menu")
		for _i in 30:
			await process_frame
		var pscr : Node = hud.get("_pause_overlay")
		if String(argv[5]) == "pause_exit":
			pscr.call("_on_quit")
			for _i in 30:
				await process_frame
		elif String(argv[5]) == "pause_settings":
			pscr.call("_on_settings")
			for _i in 60:
				await process_frame

	await RenderingServer.frame_post_draw
	var img := get_root().get_texture().get_image()
	img.save_png("%s/%s.png" % [out, name])
	print("saved ", name)
	quit(0)

func _bail_out() -> void:
	for _i in 2000:
		await process_frame
	push_error("shot_run: не дошёл до съёмки, выходим по таймауту")
	quit(1)
