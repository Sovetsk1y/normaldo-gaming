extends SceneTree

# Снимок интерфейса ВО ВРЕМЯ забега.
#   xvfb-run -a godot --path . --script res://dev/shot_run.gd -- <папка> [имя] [скин] [жир] [cd]
#
# скин — id скина (по умолчанию joker: у него больше всего кружков);
# жир   — 0..3;
# cd    — «cd» ставит часть способностей на откат, чтобы в кадр попали
#         и готовые кружки, и остывающие.
# Работает только с настоящим рендером (x11/opengl3).

func _initialize() -> void:
	_bail_out()
	var argv := OS.get_cmdline_user_args()
	var out  : String = argv[0] if argv.size() > 0 else "user://shots"
	var name : String = argv[1] if argv.size() > 1 else "run"
	var skin : String = argv[2] if argv.size() > 2 else "joker"
	var fat  : int    = int(argv[3]) if argv.size() > 3 else 1
	var cd   : bool   = argv.size() > 4 and argv[4] == "cd"
	DirAccess.make_dir_recursive_absolute(out)

	var game : Node = load("res://scenes/game.tscn").instantiate()
	get_root().add_child(game)
	await process_frame
	await process_frame

	var hud      : Node = game.get_node_or_null("HUD")
	var normaldo : Node = game.get_node_or_null("Normaldo")
	var spawner  : Node = game.get_node_or_null("Spawner")
	var bg       : Node = game.get_node_or_null("Background")
	var save     : Node = get_root().get_node_or_null("SaveData")

	save.dollars      = 12400
	save.tokens       = 83
	save.owned_skins  = ["classic", "viking", "tyson", "harry_potter", "joker", "batman"]
	save.active_skin  = skin
	save.skin_level   = 10          # чтобы были открыты все способности
	# Режим «fatlock» — первый уровень скина: верхние состояния жира ещё закрыты,
	# и в индикаторе должны стоять замки.
	if argv.size() > 5 and String(argv[5]) == "fatlock":
		save.skin_level = 1
	normaldo.call("reload_skin")
	normaldo.call("_build_skin_runtime")

	hud.call("_start_game")
	for _i in 10:
		await process_frame
	normaldo.set("fat_state", fat)
	normaldo.call("_apply_skin_to_sprite")
	if spawner:
		spawner.campaign_mode = true
		spawner.set_process(true)
	if bg:
		bg.start_scrolling()

	# Немного добычи в счётчики, иначе в кадре везде нули.
	normaldo.set("_pizza_count", 46)
	normaldo.set("_total_pizza_count", 137)
	normaldo.emit_signal("stats_changed", fat, 46, 137)

	for _i in 150:
		await process_frame

	# Режим «marks»: ставим на экран ровно те предметы, к которым у скина есть
	# резист, — иначе в кадр попадает случайная волна бананов, и метку показать
	# не на чем.
	if name.begins_with("marks") or (argv.size() > 5 and argv[5] == "marks"):
		spawner.call("clear_items")
		var vpw : float = get_root().get_visible_rect().size.x
		var rows : Array = [
			[0.30, spawner.TRASH_TEX, 0.30],
			[0.55, spawner.STONE_TEX, 0.30],
			[0.80, spawner.TRASH_TEX, 0.30],
		]
		for ri in rows.size():
			var row : Array = rows[ri]
			for k in 3:
				var it : Node = spawner.call("_spawn_item",
					get_root().get_visible_rect().size.y * float(row[0]),
					vpw - 180.0 * float(k) - 40.0, row[1], float(row[2]), 0.0, 1)
				it.position.x = vpw - 210.0 * float(k) - 150.0
		for _i in 4:
			await process_frame

	if cd:
		# Часть кружков — на откате: в кадр должны попасть оба состояния.
		var layer : Node = hud.get("_skill_badges_layer")
		var n := 0
		for b in layer.get_children():
			var key : String = String(b.get("key"))
			if key == "":
				continue
			if n % 2 == 0:
				normaldo.call("start_skill_cd", key, 8.0)
			n += 1
		for _i in 30:
			await process_frame

	# Мини-игра с мутагеном: ставим фазу Б напрямую и фиксируем уровень жира
	# прямо перед съёмкой — иначе он утечёт за кадры ожидания.
	# Бомж с бочкой: сет-пис ставится в линию Нормальдо, чтобы в кадре были и
	# он, и цель. Задержка выбирается режимом: 0.35 — приезд, 1.3 — собака.
	if argv.size() > 5 and String(argv[5]).begins_with("barrel"):
		spawner.set_process(false)
		spawner.call("clear_items")
		for _i in 6:
			await process_frame
		var vpb : Vector2 = get_root().get_visible_rect().size
		var lanes : Array = []
		for i in 5:
			lanes.append(vpb.y * (float(i) + 0.5) / 5.0)
		(normaldo as Node2D).position = Vector2(200.0, lanes[2])
		spawner.call("_setpiece_bum_barrel", 250.0, [lanes[2], lanes[2], lanes[2],
			lanes[2], lanes[2]], vpb.x)
		# Такты хореографии. Бомж теперь СНАЧАЛА влетает как обычный предмет и
		# только потом отыгрывает атаку, поэтому до собаки около двух секунд.
		var waits : Dictionary = {
			"barrel_come": 0.40,   # летит как обычный предмет
			"barrel_put":  1.45,   # затормозил, ставит бочку стоймя
			"barrel_turn": 1.88,   # заваливается набок крышкой влево
			"barrel_lid":  2.15,   # крышка отошла
			"barrel_dog":  2.35,   # откинута, собака вылетела
		}
		var wait_t : float = float(waits.get(String(argv[5]), 2.35))
		var tb := 0.0
		while tb < wait_t:
			await process_frame
			tb += 1.0 / 60.0

	# Буква NORMALDO: ставим её вручную и ждём, пока доедет до центра экрана.
	if argv.size() > 5 and String(argv[5]).begins_with("letter"):
		spawner.set_process(false)
		spawner.call("clear_items")
		for _i in 6:
			await process_frame
		spawner.set("campaign_mode", true)
		spawner.set("_frozen", false)
		spawner.call("_run_letter")
		var tl := 0.0
		while tl < 3.1:
			get_root().get_tree().paused = false
			await process_frame
			tl += 1.0 / 60.0

	# Ниндзя трёх видов: ставим одного нужного вида и ждём его атаки.
	if argv.size() > 5 and String(argv[5]).begins_with("ninja_"):
		spawner.set_process(false)
		spawner.call("clear_items")
		for _i in 6:
			await process_frame
		var vpn : Vector2 = get_root().get_visible_rect().size
		(normaldo as Node2D).position = Vector2(200.0, vpn.y * 0.5)
		var nk := String(argv[5]).substr(6)
		var nn := Area2D.new()
		nn.set_script(load("res://scripts/ninja_item.gd"))
		nn.set("speed", 250.0)
		nn.set("kind", nk)
		nn.position = Vector2(vpn.x + 40.0, vpn.y * 0.5)
		spawner.add_child(nn)
		var waits_n : Dictionary = {
			"ninja_shuriken": 1.35,
			"ninja_predator": 1.20,   # середина рывка
			"ninja_smoke":    2.30,   # дым уже стоит
		}
		var tn := 0.0
		var wn : float = float(waits_n.get(String(argv[5]), 1.5))
		while tn < wn:
			get_root().get_tree().paused = false
			await process_frame
			tn += 1.0 / 60.0

	if argv.size() > 5 and String(argv[5]).begins_with("boss"):
		var boss : Node = game.get_node_or_null("FatBoss")
		var bar : float = 1.0
		if String(argv[5]) == "boss_mid": bar = 0.5
		if String(argv[5]) == "boss_low": bar = 0.08
		if String(argv[5]) == "boss_pop": bar = 0.55
		boss.call("dev_begin_play", bar)
		for _i in 8:
			await process_frame
		boss.set("_bar", bar)
		boss.call("_update_bar_hud")
		normaldo.call("set_fat_boss_factor", boss.call("fat_factor_for", bar))
		# «pop» — кадр сразу после серии тапов: видно, насколько тап вспухает.
		if String(argv[5]) == "boss_pop":
			for _t in 4:
				boss.call("_on_tap")
				await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var bimg := get_root().get_texture().get_image()
		bimg.save_png("%s/%s.png" % [out, name])
		print("saved ", name)
		quit(0)
		return

	# Экран смерти собирается своим настоящим строителем: аргументы — это то,
	# что ему передаёт `_on_normaldo_died`.
	if argv.size() > 5 and String(argv[5]).begins_with("death"):
		save.dollars = 12400
		hud.set("_dollars_this_run", 86)
		hud.set("_elapsed_time", 134.0)
		save.skin_xp    = 3400
		save.skin_level = 4
		var rewards : Array = []
		if String(argv[5]) == "death_levelup":
			rewards = [{"level": 5, "dollars": 500, "tokens": 1}]
		# Рекорд ДО забега: экран сравнивает результат именно с ним.
		hud.set("_go_best_before", 340 if String(argv[5]) == "death_record" else 480)
		save.skin_progress[String(save.active_skin)] = {
			"xp": 3400, "level": 4, "mastery": 0, "runs": 37, "best": 480}
		paused = true
		hud.call("_show_game_over", 411, rewards, 3200, 4)
		for _i in 90:
			await process_frame
		await RenderingServer.frame_post_draw
		var dimg := get_root().get_texture().get_image()
		dimg.save_png("%s/%s.png" % [out, name])
		print("saved ", name)
		quit(0)
		return

	# Пауза снимается тем же путём, что открывает игрок.
	if argv.size() > 5 and String(argv[5]).begins_with("pause"):
		hud.call("_open_pause_menu")
		for _i in 30:
			await process_frame
		var pscr : Node = hud.get("_pause_overlay")
		if String(argv[5]) == "pause_exit":
			pscr.call("_on_quit")
			for _i in 30:
				await process_frame
		elif String(argv[5]) == "pause_settings":
			pscr.call("_on_settings")
			for _i in 60:
				await process_frame

	await RenderingServer.frame_post_draw
	var img := get_root().get_texture().get_image()
	img.save_png("%s/%s.png" % [out, name])
	print("saved ", name)
	quit(0)

func _bail_out() -> void:
	for _i in 2000:
		await process_frame
	push_error("shot_run: не дошёл до съёмки, выходим по таймауту")
	quit(1)
