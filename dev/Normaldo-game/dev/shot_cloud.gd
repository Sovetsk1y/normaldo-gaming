extends SceneTree

# Кадр ДЕНЕЖНОГО ОБЛАКА первого эпизода.
#   xvfb-run -a godot --path . --rendering-driver opengl3 --script res://dev/shot_cloud.gd -- <папка>
#
# Облако влетает справа, тормозит и висит с сюжетной строкой. Снимаем в момент
# стоянки — влёт и вылет на статичном кадре всё равно не видно.
#
# Меню приходится РАЗБИРАТЬ по-настоящему, а не пропускать: облако живёт в мире,
# а главный экран — это CanvasLayer поверх мира, и снятый через него кадр
# показывает граффити NORMALDO вместо надписи на облаке.

const CLOUD := preload("res://scripts/money_cloud.gd")

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

	# Ждём, что меню собралось, запускаем забег и ждём, что меню ушло. Паузу
	# снимаем каждый кадр: меню ставит дерево на паузу, а его уход сделан тюином.
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

	var story : String = String(sp.call("level_story"))
	print("строка: «%s»" % story)
	CLOUD.spawn(game, story)
	# Ждём конца влёта (1.05 c) с запасом — снимаем на стоянке.
	for _i in 100:
		get_root().get_tree().paused = false
		await process_frame
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png("%s/cloud.png" % out)
	print("saved")
	quit(0)
