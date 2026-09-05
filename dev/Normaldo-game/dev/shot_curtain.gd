extends SceneTree

# Кадры ЗАНАВЕСА «НЕМНОГО ПОЗДНЕЕ…».
#   xvfb-run -a godot --path . --script res://dev/shot_curtain.gd -- <папка>
#
# Снимаются три момента: шторка на середине хода, экран закрыт с надписью, и
# шторка на середине обратного хода. Глазами проверяется ровно одно: читается ли
# зубец шторки на телефоне и не съедает ли надпись собственный занавес.
#
# Занавес строится кодом (см. level_transition.gd), поэтому и снимается он сам
# по себе, без забега: воспроизводить весь путь «меню → интро → второй эпизод»
# ради трёх кадров дороже, чем показать сам занавес.

func _initialize() -> void:
	_bail_out()
	var argv := OS.get_cmdline_user_args()
	var out  : String = argv[0] if argv.size() > 0 else "user://shots"
	DirAccess.make_dir_recursive_absolute(out)

	var game : Node = load("res://scenes/game.tscn").instantiate()
	get_root().add_child(game)
	await process_frame
	var hud : Node = game.get_node_or_null("HUD")

	# Фон второго уровня под занавесом — чтобы было видно, что он и правда
	# сменился, а не остался квартирой.
	var bg : Node = game.get_node_or_null("Background")
	if bg and bg.has_method("set_level"):
		bg.call("set_level", 2)
	await _wait(0.4)

	var t = load("res://scripts/level_transition.gd").new()
	hud.add_child(t)
	t.call("_run", "НЕМНОГО ПОЗДНЕЕ…", Callable())

	await _shoot(out, "1_cover", 0.30)     # шторка закрывается
	await _shoot(out, "2_hold",  0.70)     # закрыто, надпись
	await _shoot(out, "3_open",  1.90)     # открывается обратно
	print("saved curtain")
	quit(0)

var _t : float = 0.0

func _shoot(out: String, name: String, at: float) -> void:
	await _wait(maxf(0.0, at - _t))
	_t = at
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png("%s/curtain_%s.png" % [out, name])
	print("saved curtain_%s (t=%.2f)" % [name, at])

func _wait(sec: float) -> void:
	var t0 : int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		get_root().get_tree().paused = false
		await process_frame

func _bail_out() -> void:
	for _i in 2400:
		await process_frame
	quit(1)
