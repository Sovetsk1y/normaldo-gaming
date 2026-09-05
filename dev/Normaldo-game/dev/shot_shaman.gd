extends SceneTree

# Кадр ШАМАНА С ПРИЗВАННЫМИ ЗМЕЯМИ.
#   xvfb-run -a godot --path . --script res://dev/shot_shaman.gd -- <папка> [сек]
#
# Глазами проверяется одно: читается ли это как ЗОНА, а не как три случайно
# оказавшихся рядом предмета. Радиус орбиты равен высоте линии, и промахнуться
# тут легко в обе стороны: маленький — змеи слипаются с шаманом в одно пятно,
# большой — расходятся так, что связь между ними не видна и обойти можно
# посередине.
#
# Второй аргумент — через сколько секунд после призыва снимать кадр: змеи
# кружат, и в разных фазах картинка разная (одна над, одна под — или обе сбоку).

func _initialize() -> void:
	_bail_out()
	var argv := OS.get_cmdline_user_args()
	var out  : String = argv[0] if argv.size() > 0 else "user://shots"
	var at   : float  = float(argv[1]) if argv.size() > 1 else 0.0
	DirAccess.make_dir_recursive_absolute(out)

	var game : Node = load("res://scenes/game.tscn").instantiate()
	get_root().add_child(game)
	await process_frame

	var hud     : Node = game.get_node_or_null("HUD")
	var spawner : Node = game.get_node_or_null("Spawner")
	hud.call("_start_game")
	for _i in 10:
		await process_frame
	var menu = hud.get("_menu_overlay")
	if menu != null and is_instance_valid(menu):
		menu.queue_free()
		hud.set("_menu_overlay", null)
	await _wait(0.8)

	# Поток глушим: смотрим одного шамана, а не то, что рядом с ним пролетало.
	spawner.call("clear_items")
	spawner.set("_frozen", true)
	var vp := get_root().get_visible_rect().size
	var sh : Node2D = spawner.call("_hazard_node", "shaman", 0.0)
	sh.position = Vector2(vp.x * 0.62, vp.y * 0.5)
	spawner.add_child(sh)

	await _wait(float(sh.SHAMAN_CALL_AT) + 0.5 + at)

	var snakes : Array = get_root().get_tree().get_nodes_in_group("snake")
	print("змей рядом: ", snakes.size())
	for s in snakes:
		print("  змея в ", (s as Node2D).position,
			" на удалении %.0f" % (s as Node2D).position.distance_to(sh.position))
	print("высота линии: %.0f" % (vp.y / 5.0))

	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png("%s/shaman_%.1f.png" % [out, at])
	print("saved shaman_%.1f" % at)
	quit(0)

func _wait(sec: float) -> void:
	var t0 : int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		get_root().get_tree().paused = false
		await process_frame

func _bail_out() -> void:
	for _i in 2400:
		await process_frame
	quit(1)
