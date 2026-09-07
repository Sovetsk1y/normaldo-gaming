extends SceneTree

# Кадры МЕШКА ДЕНЕГ: нетронутый и раздутый тапами.
#   xvfb-run -a godot --path . --rendering-driver opengl3 --script res://dev/shot_money_bag.gd -- <папка>
#
# Смотреть глазами тут надо две вещи: читается ли число на боку (оно и есть
# будущая выплата) и не наезжает ли подсказка «ТАП!» на сам мешок, когда тот
# раздут до потолка. Обе меряются пикселями, а не логикой, и тестом не ловятся.
#
# Раньше здесь снимались знаки валют — механика с ними убрана (см. money_bag.gd).

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

	# Меню разбираем по-настоящему: мешок живёт в мире, а главный экран — это
	# CanvasLayer поверх мира, и снятый через него кадр показывает граффити
	# вместо подсказки «ТАП!» над мешком.
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
	sp.set_process(false)
	var vp : Vector2 = get_root().get_visible_rect().size

	for shot in [{"name": "bag_small", "taps": 0}, {"name": "bag_big", "taps": 14}]:
		sp.call("clear_items")
		await process_frame
		sp.call("dev_spawn_money_bag")
		await process_frame
		var bag : Node2D = null
		for c in sp.get_children():
			if c.is_in_group("money_bag"):
				bag = c
		if bag == null:
			continue
		for _i in int(shot["taps"]):
			bag.call("tap")
		# Ставим в центр: мешок спавнится за правым краем и в кадр не попадает.
		bag.set_process(false)
		bag.position = Vector2(vp.x * 0.5, vp.y * 0.5)
		for _i in 20:
			get_root().get_tree().paused = false
			await process_frame
		await RenderingServer.frame_post_draw
		get_root().get_texture().get_image().save_png("%s/%s.png" % [out, shot["name"]])
		print("saved ", shot["name"], " (тапов ", shot["taps"], ", выплата ",
			int(bag.call("payout")), ")")
	quit(0)
