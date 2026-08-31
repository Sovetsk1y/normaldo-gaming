extends SceneTree

# Кадр выкриков: рисованный стикер над головой.
#   xvfb-run -a godot --path . --display-driver x11 --rendering-driver opengl3 \
#     --resolution 960x430 --script res://dev/shot_shouts.gd -- <папка> <resist|hit>
#
# Снимается на пике: стикер вырастает за 0.14 с и держится 0.35 — ловить его
# фиксированной задержкой «на глазок» значит снимать то пустой экран, то хвост
# затухания.

const PH := preload("res://scripts/phrases.gd")

func _initialize() -> void:
	_bail_out()
	var argv := OS.get_cmdline_user_args()
	var out  : String = argv[0] if argv.size() > 0 else "user://shots"
	var mode : String = argv[1] if argv.size() > 1 else "resist"
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
	(n as Node2D).position = Vector2(300.0, vp.y * 0.55)
	for _i in 10:
		get_root().get_tree().paused = false
		await process_frame

	# Три штуки в ряд: набор проверяется целиком, а не по одной картинке — вся
	# суть замера в том, что они ОДНОГО размера.
	var pool : Array = PH.RESIST if mode == "resist" else PH.HIT
	for i in 3:
		n.call("_pop_sticker", pool[i % pool.size()])
		for _j in 3:
			get_root().get_tree().paused = false
			await process_frame
		(n as Node2D).position.x += 150.0
	for _i in 8:
		get_root().get_tree().paused = false
		await process_frame

	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png("%s/shouts_%s.png" % [out, mode])
	print("saved ", mode)
	quit(0)

func _bail_out() -> void:
	for _i in 4000:
		await process_frame
	push_error("shot_shouts: не дошёл до съёмки")
	quit(1)
