extends SceneTree

# Кадры ДВУХ ПОРЧ ФОНА — настоящий рендер.
#   xvfb-run -a godot --path . --script res://dev/shot_trip.gd -- <папка> [эффект] [уровень]
#
# Эффект: none | mirror | invert | both. По умолчанию снимаются все четыре.
#
# Снимать обязательно. Оба эффекта живут в ШЕЙДЕРЕ (shaders/bg_trip.gdshader), а
# headless-тест шейдеров не выполняет вовсе: он проверит, что слой поднялся и
# что параметр выставлен, — и промолчит, если на экране при этом ничего не
# происходит или, наоборот, чернота. Единственный способ убедиться — посмотреть.
#
# Поток заморожен, как и в `shot_bg`: кадр про фон, а с живым потоком Нормальдо
# умирает раньше, чем уедет арка меню.

const SECS : float = 26.0   # чтобы арка меню ушла и встала плитка уровня

func _initialize() -> void:
	await _bail_out()
	var argv := OS.get_cmdline_user_args()
	var out  : String = argv[0] if argv.size() > 0 else "user://shots"
	var only : String = argv[1] if argv.size() > 1 else ""
	var lvl  : int    = clampi(int(argv[2]) if argv.size() > 2 else 1, 1, 3)
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
	while t < SECS:
		get_root().get_tree().paused = false
		sp.set("_frozen", true)
		sp.call("clear_items")
		await process_frame
		t += 1.0 / 60.0

	var modes : Array = [
		{ "id": "none",   "inv": false, "mir": false },
		{ "id": "mirror", "inv": false, "mir": true  },
		{ "id": "invert", "inv": true,  "mir": false },
		{ "id": "both",   "inv": true,  "mir": true  },
	]
	for m in modes:
		if only != "" and String(m["id"]) != only:
			continue
		bg.call("set_inverted", bool(m["inv"]))
		bg.call("set_mirrored", bool(m["mir"]))
		# Копия кадра снимается при отрисовке, поэтому одного кадра мало:
		# первый уходит на то, чтобы слой вообще поднялся.
		for _i in 4:
			await process_frame
		await RenderingServer.frame_post_draw
		var path : String = "%s/trip_%d_%s.png" % [out, lvl, String(m["id"])]
		get_root().get_texture().get_image().save_png(path)
		print("saved ", String(m["id"]))
	quit(0)

func _bail_out() -> void:
	for _i in 4000:
		await process_frame
