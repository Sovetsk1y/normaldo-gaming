extends SceneTree

# Кадры СТЕНЫ ПИЦЦЫ: момент выхода стены и момент, когда она нагоняет колонну.
#   xvfb-run -a godot --path . --rendering-driver opengl3 --script res://dev/shot_pizza_wall.gd -- <папка>
#
# Тест меряет геометрию: скорости, точку встречи, линии. Глазами тут проверяют
# другое — ЧИТАЕТСЯ ли погоня как погоня. Стена в пять линий на 85 px шага может
# оказаться визуально разреженной (тогда это не стена, а поток пиццы), а колонна
# из бананов на фоне плитки канализации — незаметной, и тогда игрок увидит не
# «плата, потом приз», а «просто много всего полетело».

func _initialize() -> void:
	var argv := OS.get_cmdline_user_args()
	var out : String = argv[0] if argv.size() > 0 else "user://shots"
	DirAccess.make_dir_recursive_absolute(out)
	var game : Node = load("res://scenes/game.tscn").instantiate()
	get_root().add_child(game)
	await process_frame
	await process_frame
	var hud : Node = game.get_node_or_null("HUD")
	var sp  : Node = game.get_node_or_null("Spawner")
	var nrm : Node = game.get_node_or_null("Normaldo")

	# Меню — CanvasLayer поверх мира, и снятый через него кадр показал бы логотип
	# вместо забега. Разбираем его по-настоящему, как в остальных съёмках.
	var boot := 0
	while boot < 900 and hud.get("_menu_overlay") == null:
		get_root().get_tree().paused = false
		await process_frame
		boot += 1
	hud.call("_start_game")
	boot = 0
	while boot < 2400 and hud.get("_menu_overlay") != null:
		get_root().get_tree().paused = false
		await process_frame
		boot += 1
	for _i in 30:
		get_root().get_tree().paused = false
		await process_frame

	nrm.call("enable_input")
	sp.call("clear_items")
	sp.set("_frozen", false)
	sp.set_process(false)   # поток не подсыпает своего: снимаем ТОЛЬКО ивент
	await process_frame

	var vp : Vector2 = get_root().get_visible_rect().size
	var lanes : Array = []
	for i in 5:
		lanes.append(vp.y * (float(i) + 0.5) / 5.0)
	var speed : float = 250.0
	sp.call("_setpiece_pizza_wall", speed, lanes, vp.x)

	# Первый кадр — на выходе стены: колонна уже в кадре, пицца только выезжает.
	var lead : float = float(sp.PIZZA_WALL_LEAD)
	await _run(lead + 0.35)
	await _save(out, "pizza_wall_start")

	# Второй — на встрече: стена вплотную к колонне, примерно на трети экрана.
	var meet : float = lead / (float(sp.call("_pizza_wall_mult", speed, vp.x)) - 1.0)
	await _run(meet - 0.35)
	await _save(out, "pizza_wall_meet")
	quit(0)

func _run(sec: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		get_root().get_tree().paused = false
		await process_frame

func _save(out: String, name: String) -> void:
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png("%s/%s.png" % [out, name])
	print("saved ", name)
