extends SceneTree

# Кадр гриба в забеге — настоящий рендер.
#   xvfb-run -a godot --path . --script res://dev/shot_mushroom.gd -- <папка> [эффект]
#
# Эффект: off (гриб просто летит) | on (гриб съеден, порча включена).
# Без аргумента снимаются оба.
#
# Смотреть надо оба кадра. Первый — про РИСУНОК: как гриб читается в потоке,
# не теряется ли среди предметов, виден ли срез свечения по краю кадра. Второй —
# про ЭФФЕКТ: он живёт в шейдере, а headless шейдеров не выполняет, и молчание
# теста ничего не говорит о том, что на экране.

const SECS : float = 26.0   # чтобы арка меню ушла и встала плитка уровня

func _initialize() -> void:
	await _bail_out()
	var argv := OS.get_cmdline_user_args()
	var out  : String = argv[0] if argv.size() > 0 else "user://shots"
	var only : String = argv[1] if argv.size() > 1 else ""
	DirAccess.make_dir_recursive_absolute(out)

	var game : Node = load("res://scenes/game.tscn").instantiate()
	get_root().add_child(game)
	await process_frame
	var hud : Node = game.get_node_or_null("HUD")
	var sp  : Node = game.get_node_or_null("Spawner")
	var nrm : Node = game.get_node_or_null("Normaldo")

	hud.call("_start_game")
	var t := 0.0
	while t < SECS:
		get_root().get_tree().paused = false
		sp.set("_frozen", true)
		sp.call("clear_items")
		await process_frame
		t += 1.0 / 60.0

	for mode in ["off", "on"]:
		if only != "" and mode != only:
			continue
		if mode == "on":
			nrm.call("apply_shroom", 8.0)
		# Гриб ставим ВРУЧНУЮ и рядом с героем: в потоке он редкий, ждать его
		# выпадения в кадросъёмке — это ждать минутами.
		var m := Area2D.new()
		m.set_script(load("res://scripts/mushroom_item.gd"))
		m.set("speed", 0.0)
		sp.add_child(m)
		m.position = Vector2(get_root().get_visible_rect().size.x * 0.55, 220.0)
		for _i in 8:
			get_root().get_tree().paused = false
			await process_frame
		await RenderingServer.frame_post_draw
		get_root().get_texture().get_image().save_png("%s/mushroom_%s.png" % [out, mode])
		print("saved ", mode)
	quit(0)

func _bail_out() -> void:
	for _i in 4000:
		await process_frame
