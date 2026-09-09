extends SceneTree

# Кадр КРОКОДИЛА В ПОТОКЕ: тормозит, ведёт стволом, стреляет.
#   xvfb-run -a godot --path . --resolution 960x430 --script res://dev/shot_croc_item.gd -- <папка>
#
# Снимается МОМЕНТ ПРИЦЕЛА — то, ради чего сет-пис и нужен: ствол наведён на
# голову, выстрела ещё нет. Кадр после выстрела показал бы пулю, но не то, что
# перед ней было честное окно на уворот.

func _initialize() -> void:
	var argv := OS.get_cmdline_user_args()
	var out : String = argv[0] if argv.size() > 0 else "user://shots"
	DirAccess.make_dir_recursive_absolute(out)
	var game : Node = load("res://scenes/game.tscn").instantiate()
	get_root().add_child(game)
	await process_frame
	var hud : Node = game.get_node_or_null("HUD")
	var sp  : Node = game.get_node_or_null("Spawner")
	var nrm : Node2D = game.get_node_or_null("Normaldo")
	hud.call("_start_game")
	# ЖДЁМ ПО РЕАЛЬНОМУ ВРЕМЕНИ, а не по кадрам. Интро — Нормальдо на диване,
	# бросок пульта, прыжок — идёт по таймерам `SceneTree.create_timer`, то есть
	# по секундам; сорок кадров headless-рендера пролетают за доли секунды, и
	# снимок выходил на ГЛАВНОМ МЕНЮ, поверх которого стоял крокодил.
	var boot := Time.get_ticks_msec()
	while Time.get_ticks_msec() - boot < 5000:
		get_root().get_tree().paused = false
		await process_frame
	nrm.call("enable_input")
	nrm.call("set_dev_immortal", true)
	sp.set("_frozen", true)
	sp.call("clear_items")
	sp.set_process(true)
	await process_frame

	var vp : Vector2 = get_root().get_visible_rect().size
	# Голову ставим НИЖЕ крокодила: так виден доворот ствола, а на одной линии
	# он выглядел бы просто «смотрит влево».
	nrm.position = Vector2(vp.x * 0.22, vp.y * 0.78)
	sp.call("_spawn_level_hazard", "croc", vp.y * 0.34, vp.x, 250.0)
	await process_frame
	var croc : Node2D = null
	for c in sp.get_children():
		if c.is_in_group("croc"):
			croc = c
	if croc == null:
		print("крокодил не вылетел")
		quit(1)
		return

	# Ждём, пока доедет и начнёт вести стволом.
	var t := 0.0
	while t < 6.0 and is_instance_valid(croc):
		await process_frame
		t += 1.0 / 60.0
		if int(croc.get("_state")) == 1 and bool(croc.get("_tracking")) and t > 1.2:
			break
	print("снят на t=%.2f, ведёт=%s" % [t, croc.get("_tracking")])
	await RenderingServer.frame_post_draw
	var img := get_root().get_texture().get_image()
	img.save_png(out + "/croc_item.png")
	# И КРУПНО. В полном кадре крокодил в потоке размером с ладонь и теряется
	# среди граффити — а проверять надо ДОВОРОТ СТВОЛА, то есть несколько
	# пикселей. Вырезаем его окрестность и растим без сглаживания.
	var at : Vector2 = croc.position
	var r  : int = 130
	var rect := Rect2i(int(at.x) - r, int(at.y) - r, r * 2, r * 2)
	rect = rect.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	var crop := img.get_region(rect)
	crop.resize(crop.get_width() * 3, crop.get_height() * 3, Image.INTERPOLATE_NEAREST)
	crop.save_png(out + "/croc_item_zoom.png")
	print("saved, крокодил на ", at, " голова на ", nrm.position)
	quit(0)
