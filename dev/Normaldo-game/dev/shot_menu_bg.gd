extends SceneTree

# Кадры главного экрана и фона забега.
#   xvfb-run -a godot --path . --display-driver x11 --rendering-driver opengl3 \
#     --resolution 960x430 --script res://dev/shot_menu_bg.gd -- <папка> <menu|wall>
#
# menu — главный экран с иконками;
# wall — забег, когда в кадре уже нарисованная полоса, а не арка меню.
#
# Полоса въезжает в кадр через полтора экрана прокрутки, то есть секунд через
# пятнадцать. Ждать их ради снимка незачем: для такта `wall` арка убирается, а
# куски полосы ставятся на место руками — снимается ровно то, что снимается.

func _initialize() -> void:
	_bail_out()
	var argv := OS.get_cmdline_user_args()
	var out  : String = argv[0] if argv.size() > 0 else "user://shots"
	var mode : String = argv[1] if argv.size() > 1 else "menu"
	DirAccess.make_dir_recursive_absolute(out)

	var game : Node = load("res://scenes/game.tscn").instantiate()
	get_root().add_child(game)
	await process_frame
	var hud : Node = game.get_node_or_null("HUD")
	var bg  : Node = game.get_node_or_null("Background")
	var save : Node = get_root().get_node_or_null("SaveData")
	save.dollars = 12400

	var boot := 0
	while boot < 900 and hud.get("_menu_overlay") == null:
		get_root().get_tree().paused = false
		await process_frame
		boot += 1
	for _i in 40:
		get_root().get_tree().paused = false
		await process_frame

	if mode == "wall":
		var n  : Node = game.get_node_or_null("Normaldo")
		var sp : Node = game.get_node_or_null("Spawner")
		hud.call("_start_game")
		boot = 0
		while boot < 1800 and hud.get("_menu_overlay") != null:
			get_root().get_tree().paused = false
			await process_frame
			boot += 1
		for _i in 60:
			get_root().get_tree().paused = false
			await process_frame
		sp.call("clear_items")
		sp.set_process(false)
		var vp : Vector2 = get_root().get_visible_rect().size
		(n as Node2D).position = Vector2(240.0, vp.y * 0.55)
		# Ставим полосу в кадр вручную — см. шапку.
		for name in ["BgIntro", "BgA", "BgB", "BgC"]:
			var s : Node = bg.get_node_or_null(name)
			if s == null:
				continue
			if name == "BgIntro":
				(s as Sprite2D).visible = false
		var tiles : Array = []
		for c in bg.get_children():
			if c is Sprite2D and c.name != "BgIntro":
				tiles.append(c)
		for i in tiles.size():
			if (tiles[i] as Sprite2D).texture == null:
				continue
			(tiles[i] as Sprite2D).visible = (tiles[i] as Sprite2D).name != "BgIntro"
		var idx := 0
		for c in bg.get_children():
			if c is Sprite2D and String(c.name).begins_with("Bg") and c.name != "BgIntro":
				if String(c.name) == "BgA" or String(c.name) == "BgB" or String(c.name) == "BgC":
					(c as Sprite2D).position.x = 645.0 * float(idx)
					idx += 1
				else:
					(c as Sprite2D).visible = false
		for _i in 20:
			get_root().get_tree().paused = false
			await process_frame

	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png("%s/bg_%s.png" % [out, mode])
	print("saved ", mode)
	quit(0)

func _bail_out() -> void:
	for _i in 4000:
		await process_frame
	push_error("shot_menu_bg: не дошёл до съёмки")
	quit(1)
