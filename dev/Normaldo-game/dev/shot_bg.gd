extends SceneTree

# Кадр фона уровня — настоящий рендер, без предметов.
#   xvfb-run -a godot --path . --script res://dev/shot_bg.gd -- <папка> <уровень> [сек]
#
# Уровень 1 — плитка с процедурным декором, 2 и 3 — нарисованные полосы.
# Смотреть надо оба: плитку сравнивают с оригиналом (лампы, трубы, крысы, город в
# проёмах), полосу — с плёнкой затемнения, которой на плитке нет.
#
# ── Почему поток заморожен и почему каждый кадр ──────────────────────────────
# Кадр про фон, а не про забег: с живым потоком Нормальдо умирает секунде на
# двадцать пятой, то есть РАНЬШЕ, чем уедет арка меню (два куска по 771 px при
# 68 px/с — это двадцать три секунды), и в кадр попадает экран смерти.
#
# Замораживать надо каждый кадр, а не один раз: `hud._start_game` снимает
# заморозку сам, когда кончается интро, и однократная заморозка до этого момента
# просто затирается — проверено кадром, где Нормальдо всё равно погиб.
#
# По умолчанию 45 секунд: к этому времени арка уехала, плитка успела
# перебросить себя (11.3 с на кусок) и лампы выпали хотя бы дважды.

func _initialize() -> void:
	await _bail_out()
	var argv := OS.get_cmdline_user_args()
	var out  : String = argv[0] if argv.size() > 0 else "user://shots"
	var lvl  : int    = clampi(int(argv[1]) if argv.size() > 1 else 1, 1, 3)
	var secs : float  = float(argv[2]) if argv.size() > 2 else 45.0
	DirAccess.make_dir_recursive_absolute(out)

	var game : Node = load("res://scenes/game.tscn").instantiate()
	get_root().add_child(game)
	await process_frame
	var hud : Node = game.get_node_or_null("HUD")
	var sp  : Node = game.get_node_or_null("Spawner")
	var bg  : Node = game.get_node_or_null("Background")

	hud.call("_start_game")
	if lvl > 1:
		sp.set("level", lvl - 1)
		bg.call("set_level", lvl)

	var t := 0.0
	while t < secs:
		get_root().get_tree().paused = false
		sp.set("_frozen", true)
		sp.call("clear_items")
		await process_frame
		t += 1.0 / 60.0

	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png("%s/bg_%d.png" % [out, lvl])
	print("saved уровень ", lvl)
	quit(0)

func _bail_out() -> void:
	for _i in 4000:
		await process_frame
