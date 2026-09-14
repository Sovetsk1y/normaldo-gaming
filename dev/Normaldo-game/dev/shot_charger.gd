extends SceneTree

# Кадры УДАРА ПО ЛИНИИ и ВСТУПИТЕЛЬНОЙ ПОЛОСЫ ПИЦЦЫ.
#   xvfb-run -a godot --path . --resolution 960x430 --script res://dev/shot_charger.gd -- <папка>
#
# Снимается то, что числами не проверишь: читается ли собака как собака (а не
# как перчатка, которую перекрасили), видно ли под ней красную полосу телеграфа
# и ложится ли полоса пиццы волной, а не лесенкой.
#
# Кадры берутся ПО СОСТОЯНИЮ, а не по секундомеру: зарядка длится доли секунды,
# и попасть в неё по таймеру — лотерея, в которой пустой кадр выглядит точно так
# же, как кадр «всё сломалось».
const GLOVE := preload("res://scripts/boxing_glove.gd")

var _out : String = "user://shots"

func _initialize() -> void:
	var argv := OS.get_cmdline_user_args()
	_out = argv[0] if argv.size() > 0 else "user://shots"
	DirAccess.make_dir_recursive_absolute(_out)

	var game : Node = load("res://scenes/game.tscn").instantiate()
	get_root().add_child(game)
	await process_frame
	var hud : Node = game.get_node_or_null("HUD")
	var sp  : Node = game.get_node_or_null("Spawner")

	# Меню разбираем до конца — иначе кадр покажет логотип, а не поле.
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
	for _i in 20:
		get_root().get_tree().paused = false
		await process_frame

	# ── Обе породы, рядом, на зарядке ──────────────────────────────────────
	# Директора глушим: его поток закрыл бы половину кадра случайными
	# предметами, и сравнить породы было бы не по чему.
	sp.set_process(false)
	sp.call("clear_items")
	await process_frame
	var lanes : Array = sp.call("_lane_centers")
	for pair in [[GLOVE.Breed.GLOVE, 1], [GLOVE.Breed.DOG, 3]]:
		var n : Node = load("res://scenes/boxing_glove.tscn").instantiate()
		n.breed = pair[0]
		n.charge_duration = 4.0   # держим зарядку, чтобы успеть снять телеграф
		n.position = Vector2(1040.0, float(lanes[pair[1]]))
		sp.add_child(n)
	# ТЕЛЕГРАФ РАСТЁТ ВМЕСТЕ С ЗАРЯДКОЙ, от нулевой высоты. Снятый в тот кадр,
	# когда обе только вошли в зарядку, он ещё нулевой — кадр вышел бы без
	# единой красной полосы, то есть ровно с тем видом, который означает «не
	# работает».
	await _wait_until(func() -> bool:
		var grown := 0
		for c in sp.get_children():
			if c.get_script() == GLOVE and int(c.get("_phase")) == 1 \
					and float(c.get("_phase_timer")) > 1.6:
				grown += 1
		return grown >= 2, 8.0)
	await _shot("charger_pair")

	# ── Полоса пиццы ───────────────────────────────────────────────────────
	# `clear_items()` САМ ставит `_frozen`, и вступление после него выходило
	# пустым: функция проверяет флаг первой строкой и молча возвращается.
	sp.call("clear_items")
	sp.set("_frozen", false)
	await process_frame
	# Ждём, пока на поле наберётся несколько колонок: по одной волну не видно.
	sp.call("_campaign_intro_pizza", 250.0, lanes, 960.0)
	await _wait_until(func() -> bool: return sp.get_child_count() >= 18, 8.0)
	await _shot("intro_band")

	print("saved")
	quit(0)

func _wait_until(cond: Callable, limit: float) -> void:
	var t := 0.0
	while t < limit and not bool(cond.call()):
		get_root().get_tree().paused = false
		await process_frame
		t += 1.0 / 60.0
	if t >= limit:
		print("НЕ ДОЖДАЛСЯ состояния")

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png("%s/%s.png" % [_out, name])
	print("снят %s" % name)
