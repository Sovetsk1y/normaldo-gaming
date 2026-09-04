extends SceneTree

# Кадры знаков валют из мешка — по одному на каждый из четырёх.
#   xvfb-run -a godot --path . --script res://dev/shot_money_bag.gd -- <папка>
#
# Мешок выстреливает доллары ЗА правый край, поэтому снимать надо не выстрел, а
# момент, когда знак уже заехал в кадр: до этого на экране пусто, после —
# россыпь. Знак подтягивается вручную, а поток заморожен, чтобы в кадр не лезли
# бочки. Знак задаётся напрямую (`_shoot_glyph`), а не жеребьёвкой внутри
# `burst`: проверять надо каждый из четырёх, а не тот, который выпал.

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
	(n as Node2D).position = Vector2(120.0, vp.y * 0.5)
	n.set("_dev_immortal", true)
	sp.set_process(false)

	for glyph in ["dollar", "ruble", "yen", "euro"]:
		await _shoot(sp, vp, glyph, out)
	quit(0)

func _shoot(sp: Node, vp: Vector2, glyph: String, out: String) -> void:
	sp.call("clear_items")
	await process_frame
	sp.call("dev_spawn_money_bag")
	await process_frame
	var bag : Node2D = null
	for c in sp.get_children():
		if c.is_in_group("money_bag"):
			bag = c
	if bag == null:
		print("мешок не появился")
		return
	bag.position = Vector2(vp.x * 0.6, vp.y * 0.5)
	bag.call("_shoot_glyph", glyph, 0)

	# Ждём приземления всех долларов: знак должен стоять целиком.
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 6000:
		get_root().get_tree().paused = false
		await process_frame
		var landed := 0
		var total  := 0
		for c in sp.get_children():
			if c.is_in_group("dollar"):
				total += 1
				if (c as Node).is_processing():
					landed += 1
		if total > 0 and landed == total:
			break
	# Подтягиваем знак в кадр целиком, вместо того чтобы ждать, пока доедет.
	var min_x := INF
	for c in sp.get_children():
		if c.is_in_group("dollar"):
			min_x = minf(min_x, (c as Node2D).position.x)
	var shift : float = min_x - vp.x * 0.42
	for c in sp.get_children():
		if c.is_in_group("dollar"):
			(c as Node2D).position.x -= shift
	if is_instance_valid(bag):
		bag.free()
	for _i in 6:
		get_root().get_tree().paused = false
		await process_frame
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png("%s/money_bag_%s.png" % [out, glyph])
	print("saved money_bag_", glyph)
