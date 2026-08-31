extends SceneTree

# Кадр дымовой завесы жёлтого ниндзя.
#   xvfb-run -a godot --path . --display-driver x11 --rendering-driver opengl3 \
#     --resolution 960x430 --script res://dev/shot_smoke.gd -- <папка>
#
# Снимается ПО СОБЫТИЮ: ждём, пока облако сядет на предмет. Фиксированная
# задержка ловила бы то шашку в полёте, то уже растаявший дым.

const NINJA := preload("res://scripts/ninja_item.gd")

func _initialize() -> void:
	_bail_out()
	var argv := OS.get_cmdline_user_args()
	var out : String = argv[0] if argv.size() > 0 else "user://shots"
	DirAccess.make_dir_recursive_absolute(out)

	var game : Node = load("res://scenes/game.tscn").instantiate()
	get_root().add_child(game)
	await process_frame
	var hud : Node = game.get_node_or_null("HUD")
	var n   : Node = game.get_node_or_null("Normaldo")
	var sp  : Node = game.get_node_or_null("Spawner")
	# Сначала дожидаемся, что меню СОБРАЛОСЬ. `_start_game`, позванный раньше, не
	# находит оверлея, ветку его ухода пропускает — и главный экран остаётся
	# висеть поверх забега до конца съёмки.
	var boot := 0
	while boot < 900 and hud.get("_menu_overlay") == null:
		get_root().get_tree().paused = false
		await process_frame
		boot += 1
	hud.call("_start_game")
	# Ждём СОБЫТИЯ — что меню действительно ушло. Отсчитывать кадры нельзя: интро
	# идёт по реальному времени, и на медленной машине снимок ловит главный экран.
	# Паузу снимаем КАЖДЫЙ кадр: меню ставит дерево на паузу отложенным вызовом, а
	# уход меню сделан тюином — под паузой он не идёт, и ожидание висит вечно.
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
	(n as Node2D).position = Vector2(210.0, vp.y * 0.5)
	n.set("_dev_immortal", true)
	for _i in 10:
		await process_frame

	# Мишени: без них кидать не во что.
	for i in 4:
		var it : Node2D = sp.call("build_random_item", 60.0)
		if it == null:
			continue
		it.position = Vector2(vp.x * (0.34 + 0.13 * float(i)),
			vp.y * (0.22 + 0.19 * float(i)))
		sp.add_child(it)

	var ninja := Area2D.new()
	ninja.set_script(NINJA)
	ninja.set("speed", 250.0)
	ninja.set("kind", "smoke")
	ninja.position = Vector2(vp.x + 40.0, vp.y * 0.5)
	sp.add_child(ninja)

	var t := 0.0
	while t < 12.0:
		get_root().get_tree().paused = false
		await process_frame
		t += 1.0 / 60.0
		if get_root().get_tree().get_nodes_in_group("smoke").size() >= 2:
			break
	for _i in 24:
		get_root().get_tree().paused = false
		await process_frame

	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png("%s/smoke.png" % out)
	print("saved smoke")
	quit(0)

func _bail_out() -> void:
	for _i in 4000:
		await process_frame
	push_error("shot_smoke: не дошёл до съёмки")
	quit(1)
