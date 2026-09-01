extends SceneTree

# Кадры битвы с хозяином клуба — настоящий рендер, не замер.
#   xvfb-run -a godot --path . --script res://dev/shot_club.gd -- <папка> <такт>
#
# такт: intro | banner | call | tele | security | siren | police | girls |
#       track | charge | dash | swap | finale | leave
#
# Такты снимаются ПО СОБЫТИЮ, а не по секундомеру: полоса вызова висит 0.55 с,
# вспышка мигалки — 0.18 с, и ловить их фиксированной задержкой значит гадать.

const CLUB := preload("res://scripts/club_boss.gd")

func _initialize() -> void:
	_bail_out()
	var argv := OS.get_cmdline_user_args()
	var out  : String = argv[0] if argv.size() > 0 else "user://shots"
	var mode : String = argv[1] if argv.size() > 1 else "security"
	DirAccess.make_dir_recursive_absolute(out)

	var game : Node = load("res://scenes/game.tscn").instantiate()
	get_root().add_child(game)
	await process_frame
	await process_frame
	var hud  : Node = game.get_node_or_null("HUD")
	var n    : Node = game.get_node_or_null("Normaldo")
	var sp   : Node = game.get_node_or_null("Spawner")
	var save : Node = get_root().get_node_or_null("SaveData")
	save.dollars = 12400
	save.active_skin = "classic"

	hud.call("_start_game")
	for _i in 190:
		await process_frame
	sp.call("clear_items")
	sp.set_process(false)
	var vp : Vector2 = get_root().get_visible_rect().size
	(n as Node2D).position = Vector2(210.0, vp.y * 0.5)
	n.set("_dev_immortal", true)
	for _i in 10:
		await process_frame

	var b := Node2D.new()
	b.set_script(CLUB)
	b.call("setup", n, sp, game, true)
	b.set("autostart", mode in ["intro", "banner"])
	game.add_child(b)
	await process_frame
	# Такты, которые дёргают поштучно, сами босса на место не ставят: это делает
	# акт целиком, а мы вызываем его середину.
	if not (mode in ["intro", "banner"]):
		(b as Node2D).position = Vector2(vp.x - CLUB.W_FIGHT * 0.55, vp.y * 0.5)
		b.call("_build_bars")

	match mode:
		"intro":
			await _wait(1.3)
		"banner":
			await _wait(5.0)
		"call":
			# Звонок: телефон в руке и кольца вызова.
			b.call("_make_call", CLUB.SFX_SECURITY, CLUB.COL_SEC)
			await _wait(0.34)
		"tele":
			# Полосы вызова легли, охраны ещё нет — момент, ради которого акт и
			# читается.
			b.call("_act_security")
			await _until(func() -> bool:
				return _strips(game, vp) >= 2 \
					and get_root().get_tree().get_nodes_in_group("club_minion").is_empty(), 8.0)
		"security":
			b.call("_act_security")
			await _until(func() -> bool:
				for m in get_root().get_tree().get_nodes_in_group("club_minion"):
					if (m as Node2D).position.x < vp.x * 0.8:
						return true
				return false, 10.0)
		"siren":
			b.call("_act_police")
			await _until(func() -> bool: return _strips(game, vp) >= 1, 8.0)
			await _wait(0.1)
		"police":
			b.call("_act_police")
			await _until(func() -> bool:
				return get_root().get_tree().get_nodes_in_group("club_minion").size() >= 4, 10.0)
			await _wait(0.35)
		"girls":
			b.call("_act_floor")
			await _until(func() -> bool:
				return get_root().get_tree().get_nodes_in_group("club_minion").size() >= 4, 12.0)
			await _wait(0.5)
		"track":
			b.call("_act_floor")
			await _until(func() -> bool: return bool(b.get("_tracking")), 14.0)
			await _wait(1.4)
		"charge":
			# Заряд: он встал, ударил кастетами оземь, на полу метка.
			b.call("_act_floor")
			await _until(func() -> bool:
				return String(b.get("_chase")) == "charge", 24.0)
			await _wait(0.22)
		"dash":
			b.call("_act_floor")
			await _until(func() -> bool:
				return String(b.get("_chase")) == "dash", 24.0)
			await _wait(0.05)
		"swap":
			# Момент подмены дыры во втором акте: коп уже сошёл со своей линии и
			# закрывает свободную.
			b.call("_act_police")
			await _until(func() -> bool:
				for m in get_root().get_tree().get_nodes_in_group("club_minion"):
					var lane : int = int(m.get_meta("lane", -1))
					if int(m.get_meta("lane0", -9)) == -9:
						m.set_meta("lane0", lane)
					elif int(m.get_meta("lane0")) != lane:
						return true
				return false, 30.0)
			await _wait(0.10)
		"finale":
			# Момент, ради которого финал и переделан: машина уже встала, все
			# садятся.
			b.call("_finale")
			await _until(func() -> bool:
				for c in game.get_children():
					if c is Sprite2D and (c as Sprite2D).texture == CLUB.T_POLICE_CAR \
							and (c as Sprite2D).position.x < vp.x:
						return true
				return false, 8.0)
			await _wait(0.9)
		"leave":
			b.call("_finale")
			await _until(func() -> bool:
				return float(b.modulate.a) < 0.5 if is_instance_valid(b) else true, 10.0)
			await _wait(0.25)

	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png("%s/club_%s.png" % [out, mode])
	print("saved ", mode)
	quit(0)

# Сколько полос вызова лежит на экране прямо сейчас.
func _strips(game: Node, vp: Vector2) -> int:
	var n := 0
	for c in game.get_children():
		if c is ColorRect and c.is_in_group("club_fx") \
				and absf((c as ColorRect).size.x - vp.x) < 2.0 \
				and (c as ColorRect).color.a > 0.05:
			n += 1
	return n

func _wait(sec: float) -> void:
	var t := 0.0
	while t < sec:
		get_root().get_tree().paused = false
		await process_frame
		t += 1.0 / 60.0

func _until(cond: Callable, limit: float) -> void:
	var t := 0.0
	while t < limit:
		get_root().get_tree().paused = false
		await process_frame
		t += 1.0 / 60.0
		if cond.call():
			return

func _bail_out() -> void:
	for _i in 4000:
		await process_frame
