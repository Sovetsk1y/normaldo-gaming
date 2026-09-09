extends SceneTree

# Снимок расфокуса от пива: кадр до и кадр во время, плюс ЦЕНА кадра.
#   xvfb-run -a godot --path . --resolution 960x430 --script res://dev/shot_beer.gd -- <папка>
#
# Только с настоящим рендером: в --headless нет рендер-устройства, и шейдер,
# читающий копию кадра, проверить нечем — картинка вернётся пустой.
#
# ПРО ЦИФРЫ FPS. Здесь их даёт llvmpipe — отрисовка на процессоре, — и они
# ЗАВЫШАЮТ цену заливки в разы против настоящего телефона. Как абсолютная
# величина они бессмысленны; годятся ровно на одно — сравнить «до» и «во время»
# в одном прогоне и увидеть, что слой не съедает кадр целиком.

func _initialize() -> void:
	var argv := OS.get_cmdline_user_args()
	var out : String = argv[0] if argv.size() > 0 else "user://shots"
	DirAccess.make_dir_recursive_absolute(out)

	var game : Node = load("res://scenes/game.tscn").instantiate()
	get_root().add_child(game)
	await process_frame
	var hud : Node = game.get_node_or_null("HUD")
	var nrm : Node = game.get_node_or_null("Normaldo")
	hud.call("_start_game")

	# Даём забегу набрать предметов: размывать пустой фон бессмысленно.
	for _i in 180:
		get_root().get_tree().paused = false
		await process_frame

	var fps_sharp := await _measure()
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png(out + "/beer_0_resko.png")
	print("снимок резко, кадров/с %.0f" % fps_sharp)

	nrm.call("apply_slow", 8.0, "beer")
	for _i in 30:
		await process_frame
	var fps_blur := await _measure()
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png(out + "/beer_1_mutno.png")
	print("снимок мутно, кадров/с %.0f" % fps_blur)
	print("цена расфокуса: ×%.2f по времени кадра" % (fps_sharp / maxf(fps_blur, 1.0)))
	quit(0)

# Среднее по 60 кадрам: мгновенный Engine.get_frames_per_second скачет вдвое от
# кадра к кадру, и по одному замеру нельзя сказать вообще ничего.
func _measure() -> float:
	var t0 := Time.get_ticks_usec()
	for _i in 60:
		await process_frame
	var dt : float = float(Time.get_ticks_usec() - t0) / 1_000_000.0
	return 60.0 / maxf(dt, 0.0001)
