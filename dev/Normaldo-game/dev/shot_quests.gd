extends SceneTree

# Снимок экрана заданий.
#   xvfb-run -a godot --path . --script res://dev/shot_quests.gd -- <папка> [имя]
#
# Работает только с настоящим рендером (x11/opengl3).

# Страховка: если что-то в теле упадёт, SceneTree останется крутиться вечно и
# прогон повиснет до таймаута. Аварийный выход по кадрам ставим ПЕРВЫМ делом.
func _initialize() -> void:
	_bail_out()
	var argv := OS.get_cmdline_user_args()
	var out  : String = argv[0] if argv.size() > 0 else "user://shots"
	var name : String = argv[1] if argv.size() > 1 else "quests"
	DirAccess.make_dir_recursive_absolute(out)

	var game : Node = load("res://scenes/game.tscn").instantiate()
	get_root().add_child(game)
	await process_frame
	await process_frame
	var hud : Node = game.get_node_or_null("HUD")

	# Сейв под съёмку: деньги на счету и задания в разном состоянии, чтобы в
	# кадр попали и невыполненное, и готовое к получению.
	var save : Node = get_root().get_node_or_null("SaveData")
	save.dollars = 1024
	save.tokens  = 83
	# Состояние под съёмку задаётся третьим аргументом: mixed (по умолчанию) —
	# готовое + два в процессе; claimed — забранное и слот на откате.
	var mode : String = argv[2] if argv.size() > 2 else "mixed"
	var qm : Node = get_root().get_node_or_null("QuestManager")
	if qm != null:
		qm.reroll_daily_quests()
		var st : Array = qm.get("daily_quests")
		if st.size() >= 3:
			match mode:
				"claimed":
					st[0]["completed"] = true
					st[0]["claimed"]   = true
					st[0]["claimed_at"] = int(Time.get_unix_time_from_system())
					st[1]["completed"] = true
					st[1]["claimed"]   = false
				_:
					st[0]["completed"] = true
					st[0]["claimed"]   = false
		qm.emit_signal("quests_updated")

	var screen : Node = load("res://scripts/quests_screen.gd").new()
	screen.call("setup", hud)
	hud.add_child(screen)
	# Считаем КАДРЫ, а не секунды: get_process_delta_time под xvfb может вернуть
	# ноль, и цикл по времени тогда не кончается никогда.
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
	push_error("shot_quests: не дошёл до съёмки, выходим по таймауту")
	quit(1)
