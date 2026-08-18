extends SceneTree

# Снимок экрана скинов.
#   xvfb-run -a godot --path . --script res://dev/shot_skins.gd -- <папка> [имя] [detail]
#
# detail=<skin_id> снимает карточку скина, без него — сетку.
# Работает только с настоящим рендером (x11/opengl3).

func _initialize() -> void:
	_bail_out()
	var argv := OS.get_cmdline_user_args()
	var out  : String = argv[0] if argv.size() > 0 else "user://shots"
	var name : String = argv[1] if argv.size() > 1 else "skins"
	var detail : String = argv[2] if argv.size() > 2 else ""
	DirAccess.make_dir_recursive_absolute(out)

	var game : Node = load("res://scenes/game.tscn").instantiate()
	get_root().add_child(game)
	await process_frame
	await process_frame
	var hud : Node = game.get_node_or_null("HUD")

	# poor — вариант съёмки с пустым кошельком: в кадр попадает состояние
	# «нет денег», которого при полном кошельке не увидеть.
	var poor : bool = argv.size() > 3 and argv[3] == "poor"
	var save : Node = get_root().get_node_or_null("SaveData")
	save.dollars = 300 if poor else 12400
	save.tokens  = 83
	# Часть скинов куплена, часть нет — в кадр должны попасть оба состояния.
	# Прогресс скинов сбрасываем: сейв лежит на диске и переживает прогоны, а
	# smoke_skins.gd прокачивает КАЖДЫЙ скин до 10-го уровня. Без сброса в кадр
	# попадает «десятый уровень» у скина, который даже не куплен.
	save.skin_progress = {}
	# Немного истории у активного скина, чтобы в кадр попала строка статистики.
	save.skin_progress["harry_potter"] = {"xp": 1, "level": 4, "mastery": 0, "runs": 37, "best": 412}
	save.skin_progress["pirate"]       = {"xp": 0, "level": 1, "mastery": 0, "runs": 0,  "best": 0}
	save.owned_skins = ["classic", "viking", "tyson", "harry_potter"]
	save.active_skin = "harry_potter"
	save.skin_level  = 4

	if detail != "":
		var reg : Node = get_root().get_node_or_null("SkinRegistry")
		hud.call("_show_skin_detail", reg.get_skin(detail), true, null, true)
	else:
		hud.call("_show_shop")
	for _i in 90:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := get_root().get_texture().get_image()
	img.save_png("%s/%s.png" % [out, name])
	print("saved ", name)
	quit(0)

func _bail_out() -> void:
	for _i in 1200:
		await process_frame
	push_error("shot_skins: не дошёл до съёмки, выходим по таймауту")
	quit(1)
