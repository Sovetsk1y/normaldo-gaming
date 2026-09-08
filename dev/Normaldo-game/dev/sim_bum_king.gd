extends SceneTree

# Прикидка сложности короля: не проверка, а замер. Тест ловит, что решения у
# босса ЕСТЬ; здесь смотрят, чего они стоят за столом.
#
# Бот играет как играет человек, который ещё не понял бой: стоит на месте и бьёт,
# как только перезарядится. Против прежнего короля такая игра выигрывала всегда —
# он приходил по прямой, вставал в заряд и получал по кулаку каждые 0.85 с.
#
#   godot --headless --path . --script res://dev/sim_bum_king.gd -- <сколько боёв>

const BUM_KING := preload("res://scripts/bum_king.gd")

func _initialize() -> void:
	var argv := OS.get_cmdline_user_args()
	var runs : int = int(argv[0]) if argv.size() > 0 else 12
	for bot in ["spam", "smart", "press"]:
		var wins := 0
		var hp_left := 0
		var king_left := 0
		for i in runs:
			var r : Array = await _one_fight(bot)
			if bool(r[0]):
				wins += 1
			hp_left   += int(r[1])
			king_left += int(r[2])
		print("[%s] боёв: %d, игрок выиграл: %d (%.0f%%)"
			% [bot, runs, wins, 100.0 * float(wins) / float(runs)])
		print("[%s] в среднем осталось: у игрока %.1f из 3, у короля %.1f из 5"
			% [bot, float(hp_left) / float(runs), float(king_left) / float(runs)])
	quit(0)

var _seen : Dictionary = {}
var _rec_d : float = 1e9

func _one_fight(bot: String = "spam") -> Array:
	var game : Node = load("res://scenes/game.tscn").instantiate()
	get_root().add_child(game)
	await process_frame
	var sp : Node   = game.get_node_or_null("Spawner")
	var n  : Node2D = game.get_node_or_null("Normaldo")
	sp.call("clear_items")
	sp.set_process(false)
	await process_frame

	var boss : Node2D = Node2D.new()
	boss.set_script(BUM_KING)
	boss.call("setup", n, sp, game, true)
	game.add_child(boss)
	# СНАЧАЛА ОСТАНОВИТЬ ЕГО СОБСТВЕННЫЙ БОЙ. Узел, добавленный в дерево, сам
	# запускает всю последовательность — интро, волну серого, волну рыжего, — и
	# «поставим current_wave = king» её не отменяет: волна тут же вернёт своё
	# значение обратно, а на арене будет драться рядовой. Первый замер именно так
	# и мерил: 2430 кадров из 2700 король простоял в чужом состоянии.
	var t_boot := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t_boot < 20000 \
			and String(boss.get("current_wave")) != "grey":
		await process_frame
	boss.set("_running", false)      # волны выходят на первом же шаге
	await process_frame
	await process_frame
	boss.call("_clear_foe")

	# Теперь чистый бой с королём: рядовые — обучение, мерить на них нечего.
	boss.set("_running", true)
	boss.set("current_wave", "king")
	boss.set("king_hp", boss.KING_HP)
	boss.set("hero_hp", boss.HERO_HP)
	boss.set("_foe_attacks", true)
	boss.call("_spawn_foe", boss.F_IDLE, boss.BOSS_PX, Color.WHITE)
	boss.set("_foe_state", "stalk")
	n.position = boss.call("_arena_center")

	var t0 := Time.get_ticks_msec()
	# ШАГ БОТА — ПО НАСТОЯЩЕМУ ВРЕМЕНИ. В headless кадры идут во много раз чаще
	# реального времени, и бот, двигавшийся на фиксированные 0.016 с за кадр,
	# летал по арене со скоростью в десятки раз выше человеческой. Замер при этом
	# выглядел правдоподобно — просто мерил не то.
	var t_prev := Time.get_ticks_usec()
	while Time.get_ticks_msec() - t0 < 45000:
		var dt : float = float(Time.get_ticks_usec() - t_prev) / 1000000.0
		t_prev = Time.get_ticks_usec()
		if not is_instance_valid(boss):
			break
		if int(boss.get("king_hp")) <= 0 or int(boss.get("hero_hp")) <= 0:
			break
		var foe : Vector2 = boss.get("_foe_pos")
		var st  : String  = String(boss.get("_foe_state"))
		if bot == "spam":
			# Стоит и бьёт по готовности — так играет тот, кто ещё не понял бой.
			if float(boss.get("_p_cd")) <= 0.0:
				boss.call("punch")
		else:
			# Играет по правилам боя: уходит с линии заряда, наказывает отдышку,
			# в остальное время держится подальше.
			var to : Vector2 = foe - n.position
			var dir : Vector2 = to.normalized() if to.length() > 1.0 else Vector2.RIGHT
			if st == "charge" or st == "dash":
				# Уход с линии — свайпом, а свайп у головы быстрый: за треть
				# секунды она проходит полэкрана. Медленный «уход» мерил бы не
				# бой, а то, как игрок не успевает.
				n.position = boss.call("_clamp_to_arena",
					n.position - dir.orthogonal() * 620.0 * dt, 26.0)
			elif st == "recover":
				n.position = boss.call("_clamp_to_arena",
					n.position + dir * 460.0 * dt, 26.0)
				if float(boss.get("_p_cd")) <= 0.0 and boss.call("_hero_can_reach"):
					boss.call("punch")
			elif bot == "press":
				# ДАВИТ: не ждёт его броска, а идёт следом и бьёт, как только
				# достаёт, — принимая, что часть замахов он прочитает. Так играет
				# тот, кто разобрался: наказания одной отдышки на десять реек не
				# хватает.
				n.position = boss.call("_clamp_to_arena",
					n.position + dir * 300.0 * dt, 26.0)
				if float(boss.get("_p_cd")) <= 0.0 and boss.call("_hero_can_reach"):
					boss.call("punch")
			# «smart» в остальное время стоит: он живёт с одной отдышки.
		if bot == "zzz":
			var k : String = st
			_seen[k] = int(_seen.get(k, 0)) + 1
			if k == "recover":
				_rec_d = minf(_rec_d, n.position.distance_to(foe))
		await process_frame

	var won  : bool = int(boss.get("king_hp")) <= 0
	var hp   : int  = int(boss.get("hero_hp"))
	var khp  : int  = int(boss.get("king_hp"))
	if bot == "zzz":
		print("    состояния ", _seen, " ближайшее в отдышке %.0f px, руки хватает на %.0f"
			% [_rec_d, float(boss.SWING_REACH) + float(boss.FIST_R) + float(boss.call("_foe_r"))])
		_seen = {} ; _rec_d = 1e9
	print("    замахов %d, попал %d, блоков/парирований %d, получил %d"
		% [int(boss.get("punches")), int(boss.get("hits_dealt")),
			int(boss.get("blocks")), int(boss.get("hits_taken"))])
	game.queue_free()
	await process_frame
	return [won, hp, khp]

func _wait(sec: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		await process_frame
