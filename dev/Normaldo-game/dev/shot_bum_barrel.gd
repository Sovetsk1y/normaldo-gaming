extends SceneTree

# Раскадровка бомжа с бочкой — четыре такта из спеки.
#   xvfb-run -a godot --path . --display-driver x11 --rendering-driver opengl3 \
#     --resolution 960x430 --script res://dev/shot_bum_barrel.gd -- <папка>
#
# Такты снимаются ПО СОБЫТИЮ: падение бочки длится 0.22 с, открытая она стоит
# 0.2 с до выстрела — ловить это фиксированной задержкой значит гадать.

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
	for _i in 60:
		get_root().get_tree().paused = false
		await process_frame
	sp.call("clear_items")
	sp.set_process(false)
	var vp : Vector2 = get_root().get_visible_rect().size
	(n as Node2D).position = Vector2(200.0, vp.y * 0.5)
	n.set("_dev_immortal", true)

	var lanes : Array = []
	for i in 5:
		lanes.append(vp.y * (float(i) + 0.5) / 5.0)
	sp.call("_setpiece_bum_barrel", 250.0, lanes, vp.x)
	await process_frame
	var node : Node2D = null
	for c in sp.get_children():
		if c.get_script() != null and String(c.get_script().resource_path).ends_with("bum_barrel.gd"):
			node = c
	if node == null:
		push_error("shot_bum_barrel: сет-пис не поднялся")
		quit(1)
		return
	var bar : Sprite2D = node.get("_barrel")

	# 1. Летит как обычный предмет.
	await _until(func() -> bool: return node.position.x < vp.x - 40.0, 4.0)
	await _shot(out, "bb_1_enter")
	# 2. Затормозил.
	await _until(func() -> bool: return String(node.get("_phase")) != "enter", 4.0)
	await _wait(0.5)
	await _shot(out, "bb_2_stop")
	# 3. Бочка открылась.
	await _until(func() -> bool:
		return is_instance_valid(bar) \
			and bar.texture == load("res://assets/items/barrel_open2.png"), 4.0)
	await _shot(out, "bb_3_open")
	# 4. Собака пошла по своей линии.
	await _until(func() -> bool:
		for c in sp.get_children():
			if c.scene_file_path.ends_with("dog.tscn"):
				return c.position.x < vp.x * 0.62
		return false, 4.0)
	await _shot(out, "bb_4_dog")
	print("saved")
	quit(0)

func _shot(out: String, name: String) -> void:
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png("%s/%s.png" % [out, name])

func _wait(sec: float) -> void:
	var t := 0.0
	while t < sec:
		get_root().get_tree().paused = false
		await process_frame
		t += 1.0 / 60.0

func _until(cond: Callable, limit: float) -> void:
	var t := 0.0
	while t < limit:
		get_root().get_tree().paused = false
		await process_frame
		t += 1.0 / 60.0
		if cond.call():
			return

func _bail_out() -> void:
	for _i in 6000:
		await process_frame
	push_error("shot_bum_barrel: не дошёл до съёмки")
	quit(1)
