extends SceneTree

# Кадры босса «Старый пират»: арена с толпой и момент размена.
#   xvfb-run -a godot --path . --rendering-driver opengl3 --script res://dev/shot_bum_king.gd -- <папка>
#
# Тест меряет правила размена, а глазами тут проверяют другое: ЧИТАЕТСЯ ли арена
# как замкнутая. Овал из двадцати шести бомжей может оказаться редким частоколом,
# сквозь который видно фон, — и тогда «уходить некуда» перестаёт быть очевидным,
# сколько бы оно ни было правдой в коде.

const BUM_KING := preload("res://scripts/bum_king.gd")

func _initialize() -> void:
	var argv := OS.get_cmdline_user_args()
	var out : String = argv[0] if argv.size() > 0 else "user://shots"
	DirAccess.make_dir_recursive_absolute(out)
	var game : Node = load("res://scenes/game.tscn").instantiate()
	get_root().add_child(game)
	await process_frame
	await process_frame
	var hud : Node   = game.get_node_or_null("HUD")
	var sp  : Node   = game.get_node_or_null("Spawner")
	var n   : Node2D = game.get_node_or_null("Normaldo")

	# Меню — CanvasLayer поверх мира, и снятый через него кадр показал бы логотип
	# вместо арены. Разбираем его так же, как в остальных съёмках.
	var boot := 0
	while boot < 900 and hud.get("_menu_overlay") == null:
		get_root().get_tree().paused = false
		await process_frame
		boot += 1
	hud.call("_start_game")
	boot = 0
	while boot < 2400 and hud.get("_menu_overlay") != null:
		get_root().get_tree().paused = false
		await process_frame
		boot += 1
	for _i in 30:
		get_root().get_tree().paused = false
		await process_frame

	sp.call("clear_items")
	sp.set_process(false)
	n.set("_dev_immortal", true)
	await process_frame

	var boss : Node2D = Node2D.new()
	boss.set_script(BUM_KING)
	boss.call("setup", n, sp, game, true)
	game.add_child(boss)

	# Первый кадр — арена на волне серого: толпа, полосы, противник.
	await _await_wave(boss, "grey", 12.0)
	await _run(0.9)
	await _save(out, "bum_king_arena")

	# Второй — размен: оба кулака в воздухе, вот-вот блок.
	boss.set("foe_hp", 9)
	boss.set("_p_cd", 0.0)
	boss.call("punch")
	boss.call("foe_punch")
	await _run(0.12)
	await _save(out, "bum_king_clash")

	# Третий — сам босс на арене. Обнулять ХП надо ПОКА НЕ ДОЙДЁМ: волн до него
	# две, и одного обнуления хватает ровно на одну — второй рядовой выходит с
	# полным ХП и стоит до конца ожидания. Ровно так этот кадр и снялся в первый
	# раз: вместо короля на нём позировал рыжий бомж.
	await _skip_to_king(boss, 14.0)
	# Третий — ЗОВ: пират ещё стоит в кольце, толпа кричит «ПИРАТА В БОЙ!». Волна
	# «king» начинается именно с него, а не с появления бойца.
	await _run(0.5)
	await _save(out, "bum_king_call")

	# Четвёртый — он сам на арене. Ждать надо ВЫХОДА, а не времени: между началом
	# волны и его появлением стоит зов толпы, и кадр по таймеру ловил бы пустую
	# арену с облачками.
	await _await_king_out(boss, 8.0)
	await _run(1.2)
	await _save(out, "bum_king_boss")
	quit(0)

func _await_king_out(boss: Node, limit: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(limit * 1000.0):
		if not is_instance_valid(boss):
			return
		var foe = boss.get("_foe_sprite")
		if is_instance_valid(foe) and foe.texture == boss.F_IDLE:
			return
		get_root().get_tree().paused = false
		await process_frame

func _skip_to_king(boss: Node, limit: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(limit * 1000.0):
		if not is_instance_valid(boss) or String(boss.get("current_wave")) == "king":
			return
		boss.set("foe_hp", 0)
		get_root().get_tree().paused = false
		await process_frame

func _await_wave(boss: Node, want: String, limit: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(limit * 1000.0):
		if not is_instance_valid(boss) or String(boss.get("current_wave")) == want:
			return
		get_root().get_tree().paused = false
		await process_frame

func _run(sec: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		get_root().get_tree().paused = false
		await process_frame

func _save(out: String, name: String) -> void:
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png("%s/%s.png" % [out, name])
	print("saved ", name)
