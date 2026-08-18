extends SceneTree

# Снимок экрана автоматов.
#   xvfb-run -a godot --path . --script res://dev/shot_slots.gd -- <папка> [имя] [режим]
#
# режим:
#   spin — снять экран во время вращения барабанов
#   win  — снять окно выигрыша
#   poor — снять состояние «нет жетонов»
# Работает только с настоящим рендером (x11/opengl3).

func _initialize() -> void:
	_bail_out()
	var argv := OS.get_cmdline_user_args()
	var out  : String = argv[0] if argv.size() > 0 else "user://shots"
	var name : String = argv[1] if argv.size() > 1 else "slots"
	var mode : String = argv[2] if argv.size() > 2 else ""
	DirAccess.make_dir_recursive_absolute(out)

	var game : Node = load("res://scenes/game.tscn").instantiate()
	get_root().add_child(game)
	await process_frame
	await process_frame
	var hud : Node = game.get_node_or_null("HUD")

	var save : Node = get_root().get_node_or_null("SaveData")
	save.dollars = 12400
	save.tokens  = 0 if mode == "poor" else 83
	# Сброс прогресса скинов: сейв лежит на диске и переживает прогоны, а
	# smoke_skins.gd прокачивает каждый скин до 10-го уровня.
	save.skin_progress = {}
	save.owned_skins   = ["classic", "viking", "tyson", "harry_potter"]
	save.active_skin   = "harry_potter"
	save.skin_level    = 4
	save.skin_xp       = 3400   # середина 4-го уровня

	var screen : Node = load("res://scripts/slots_screen.gd").new()
	screen.call("setup", hud)
	hud.add_child(screen)
	for _i in 40:
		await process_frame

	match mode:
		"spin":
			screen.call("_on_spin_pressed")
			for _i in 20:
				await process_frame
		"win":
			screen.call("_show_win_popup", {"sym": "dollar", "count": 3})
			for _i in 45:
				await process_frame
		"poor":
			screen.call("_on_spin_pressed")
			for _i in 30:
				await process_frame
		"history":
			# Три спина подряд, окно выигрыша закрываем сразу — в кадр должна
			# попасть заполненная лента последних спинов.
			for _s in 3:
				screen.call("_on_spin_pressed")
				for _i in 400:
					if not bool(screen.get("_spinning")):
						break
					await process_frame
				var pop = screen.get("_win_popup")
				if pop != null and is_instance_valid(pop):
					pop.queue_free()
					screen.set("_win_popup", null)
				await process_frame
			for _i in 20:
				await process_frame
		_:
			for _i in 50:
				await process_frame

	await RenderingServer.frame_post_draw
	var img := get_root().get_texture().get_image()
	img.save_png("%s/%s.png" % [out, name])
	print("saved ", name)
	quit(0)

func _bail_out() -> void:
	for _i in 1500:
		await process_frame
	push_error("shot_slots: не дошёл до съёмки, выходим по таймауту")
	quit(1)
