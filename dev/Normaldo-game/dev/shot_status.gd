extends SceneTree

# Кадр СТАТУС-ЭФФЕКТОВ на живом Нормальдо.
#   xvfb-run -a godot --path . --script res://dev/shot_status.gd -- <папка> <эффект>
#
# эффект: sphere | slow | invert | hourglass | armor | heal | stun | shock |
#         rage | blessed
#
# Глазами проверяется ровно одно: РАЗМЕР И ЧИТАЕМОСТЬ значка на голове. Он
# считается от непрозрачной рамки рисунка (см. `_art_px` в normaldo.gd), и
# промахнуться тут легко в обе стороны: колечко на макушке не видно в потоке,
# а значок во весь экран закрывает саму игру.
#
# Снимается ЖИВОЙ забег, а не сетка эффектов на пустом фоне: значок обязан
# читаться поверх летящих предметов, а не на чёрном.

func _initialize() -> void:
	_bail_out()
	var argv := OS.get_cmdline_user_args()
	var out  : String = argv[0] if argv.size() > 0 else "user://shots"
	var fx   : String = argv[1] if argv.size() > 1 else "slow"
	DirAccess.make_dir_recursive_absolute(out)

	var game : Node = load("res://scenes/game.tscn").instantiate()
	get_root().add_child(game)
	await process_frame

	var hud      : Node   = game.get_node_or_null("HUD")
	var normaldo : Node2D = game.get_node_or_null("Normaldo")
	hud.call("_start_game")
	for _i in 10:
		await process_frame
	# Меню сносим руками — оно висит ровно там, где голова (см. shot_worn.gd).
	var menu = hud.get("_menu_overlay")
	if menu != null and is_instance_valid(menu):
		menu.queue_free()
		hud.set("_menu_overlay", null)
	await process_frame
	normaldo.set("fat_state", 2)
	normaldo.call("_apply_skin_to_sprite")
	await _wait(1.0)

	# Постоянные значки включаем через САМО состояние, а не через `_status_on`:
	# кадр должен показывать то, что увидит игрок, а не то, что мы попросили
	# нарисовать.
	match fx:
		"slow":      normaldo.call("apply_slow", 30.0)
		"invert":    normaldo.call("apply_invert", 30.0)
		"hourglass": normaldo.call("_mark_world_slow", 30.0)
		"armor":     normaldo.call("apply_casey_mask", 30.0)
		"sphere":
			# Сфера резиста считается шейдером, а не проигрывается кадрами, —
			# и снимается она через тот же вход, что зовёт сам резист.
			normaldo.call("_sphere_flash", 2.3)
		_:
			# Мгновенные — через тот же вход, что и в игре: он не просто вешает
			# картинку, а надувает её и гасит, и кадр обязан показывать это, а не
			# статичный значок.
			normaldo.call("_status_flash", fx, 2.0, 0.0)
	await _wait(0.34)

	var d : Dictionary = normaldo.get("_status_fx")
	print("значков на голове: ", d.keys())
	print("размер рисунка головы: %.0f px" % float(normaldo.call("_art_px")))

	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png("%s/status_%s.png" % [out, fx])
	print("saved status_%s" % fx)
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
