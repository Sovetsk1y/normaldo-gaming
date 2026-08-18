extends SceneTree

# Снимки окон настроек.
#   xvfb-run -a godot --path . --script res://dev/shot_settings.gd -- <папка> [что]
#
# что: settings | sound | notif | profile | account | restore | rename
# Работает только с настоящим рендером (x11/opengl3).

func _initialize() -> void:
	_bail_out()
	var argv := OS.get_cmdline_user_args()
	var out  : String = argv[0] if argv.size() > 0 else "user://shots"
	var what : String = argv[1] if argv.size() > 1 else "settings"
	DirAccess.make_dir_recursive_absolute(out)

	var game : Node = load("res://scenes/game.tscn").instantiate()
	get_root().add_child(game)
	await process_frame
	await process_frame
	var hud : Node = game.get_node_or_null("HUD")

	var save : Node = get_root().get_node_or_null("SaveData")
	save.dollars       = 12400
	save.tokens        = 83
	save.display_name  = "НОРМАЛЬДО-3D53"
	if String(save.recovery_code) == "":
		save.recovery_code = "NRM-4K2P-8QX7"

	for _i in 30:
		await process_frame

	match what:
		"restore", "rename":
			# Диалог обязан открываться ПОВЕРХ настроек и возвращать в них —
			# ради этого весь флоу и переделывался, значит и снимаем его так.
			hud.call("_show_settings_modal")
			for _i in 40:
				await process_frame
			var s0 : Node = hud.get("_settings_screen")
			if s0 != null:
				s0.call("_on_select", "profile" if what == "rename" else "account")
			for _i in 10:
				await process_frame
			hud.call("_show_rename_modal" if what == "rename" else "_show_restore_modal")
		_:
			hud.call("_show_settings_modal")
			for _i in 40:
				await process_frame
			# Раздел выбирается тем же путём, что пальцем: через обработчик
			# нажатия по строке корешка.
			var scr : Node = hud.get("_settings_screen")
			if scr != null and what != "settings":
				scr.call("_on_select", what)
	for _i in 60:
		await process_frame

	await RenderingServer.frame_post_draw
	var img := get_root().get_texture().get_image()
	img.save_png("%s/%s.png" % [out, what])
	print("saved ", what)
	quit(0)

func _bail_out() -> void:
	for _i in 1500:
		await process_frame
	push_error("shot_settings: не дошёл до съёмки, выходим по таймауту")
	quit(1)
