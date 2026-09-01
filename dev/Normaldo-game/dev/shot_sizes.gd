extends SceneTree

# Кадр «размеры предметов»: мешок с баксами, вор, кобра и бомж с бочкой стоят на
# соседних линиях рядом с рядовым бомжом и бананом — чтобы размер каждого
# читался НА ФОНЕ соседей, а не сам по себе.
#   xvfb-run -a godot --path . --display-driver x11 --rendering-driver opengl3 \
#     --resolution 960x430 --script res://dev/shot_sizes.gd -- <папка>

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
	(n as Node2D).position = Vector2(120.0, vp.y * 0.5)
	n.set("_dev_immortal", true)

	var lanes : Array = []
	for i in 5:
		lanes.append(vp.y * (float(i) + 0.5) / 5.0)

	# Эталоны — банан и рядовой бомж: по ним и видно, кто «побольше».
	_put(sp, load("res://scenes/homeless.tscn"), Vector2(vp.x * 0.62, lanes[0]))
	_put(sp, load("res://scenes/snake.tscn"),      Vector2(vp.x * 0.62, lanes[1]))
	_put(sp, load("res://scenes/money_bag.tscn"),  Vector2(vp.x * 0.62, lanes[2]))

	var thief := Area2D.new()
	thief.set_script(load("res://scripts/thief.gd"))
	thief.set("speed", 0.0)
	thief.position = Vector2(vp.x * 0.62, lanes[3])
	sp.add_child(thief)

	var bb := Node2D.new()
	bb.set_script(load("res://scripts/bum_barrel.gd"))
	bb.call("setup", n, lanes[4], 0.0)
	sp.add_child(bb)
	await process_frame
	(bb as Node2D).position = Vector2(vp.x * 0.72, lanes[4])

	for _i in 30:
		get_root().get_tree().paused = false
		await process_frame

	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png("%s/sizes.png" % out)
	print("saved sizes")
	quit(0)

func _put(sp: Node, scene: PackedScene, at: Vector2) -> void:
	var it : Node2D = scene.instantiate()
	it.set("speed", 0.0)
	it.position = at
	sp.add_child(it)

func _bail_out() -> void:
	for _i in 4000:
		await process_frame
	push_error("shot_sizes: не дошёл до съёмки")
	quit(1)
