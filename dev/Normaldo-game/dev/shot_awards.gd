extends SceneTree

# Кадры экрана достижений — настоящий рендер.
#   xvfb-run -a godot --path . --script res://dev/shot_awards.gd -- <папка> [категория]
#
# Категория — номер вкладки в корешке, 0…11 (см. Achievements.CATEGORIES).
# Без номера снимается «menu» — главный экран с кнопкой достижений: проверять
# надо и то, куда игрок нажимает, а не только то, куда он попадает.
#
# Прогресс на экране фальшивый и ДЕТЕРМИНИРОВАННЫЙ (achievements_mock.gd),
# поэтому кадры воспроизводимы и их можно сравнивать между собой.

func _initialize() -> void:
	await _bail_out()
	var argv := OS.get_cmdline_user_args()
	var out  : String = argv[0] if argv.size() > 0 else "user://shots"
	var mode : String = argv[1] if argv.size() > 1 else "menu"
	DirAccess.make_dir_recursive_absolute(out)

	var game : Node = load("res://scenes/game.tscn").instantiate()
	get_root().add_child(game)
	await process_frame
	var hud  : Node = game.get_node_or_null("HUD")
	var save : Node = get_root().get_node_or_null("SaveData")
	save.dollars = 12400
	save.tokens  = 37

	if mode != "menu":
		hud.call("_show_awards", int(mode))
		# Заезд экрана — 0.45 с; снимать раньше значит поймать его на полпути.
		await _wait(0.9)
	else:
		await _wait(0.6)

	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png("%s/awards_%s.png" % [out, mode])
	print("saved ", mode)
	quit(0)

func _wait(sec: float) -> void:
	var t := 0.0
	while t < sec:
		get_root().get_tree().paused = false
		await process_frame
		t += 1.0 / 60.0

func _bail_out() -> void:
	for _i in 4000:
		await process_frame
