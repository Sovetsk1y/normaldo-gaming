extends SceneTree

# Кадры битвы с крокодилом — настоящий рендер, не замер.
#   xvfb-run -a godot --path . --display-driver x11 --rendering-driver opengl3 \
#     --resolution 960x430 --script res://dev/shot_croc.gd -- <папка> <такт>
#
# такт: intro | banner | hunt | tail | buck | rage | jaw | finale
#
# Такты снимаются ПО СОБЫТИЮ, а не по секундомеру: нить прицела висит 0.45 с,
# вспышка картечи — 0.1 с, и ловить их фиксированной задержкой значит гадать.

const CROC := preload("res://scripts/leatherhead.gd")

func _initialize() -> void:
	_bail_out()
	var argv := OS.get_cmdline_user_args()
	var out  : String = argv[0] if argv.size() > 0 else "user://shots"
	var mode : String = argv[1] if argv.size() > 1 else "hunt"
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

	var c := Node2D.new()
	c.set_script(CROC)
	c.call("setup", n, sp, game, true)
	c.set("autostart", mode in ["intro", "banner"])
	game.add_child(c)
	await process_frame
	# Такты, которые вызываются поштучно, сами босса на место не ставят: это
	# делает акт целиком, а мы дёргаем его середину.
	if mode in ["buck", "rage"]:
		(c as Node2D).position = Vector2(vp.x - CROC.W_FIGHT * 0.62, vp.y * 0.5)
		c.call("_set_pose", CROC.F_SHOT_DOWN[0], CROC.W_FIGHT)
	elif mode in ["hunt", "tail", "jaw", "finale"]:
		c.call("_set_pose", CROC.F_GUN, CROC.W_FIGHT)

	match mode:
		"intro":
			await _wait(1.4)
		"banner":
			await _wait(5.2)
		"hunt":
			c.call("_act_hunt")
			await _until(func() -> bool: return _find_named(game, "AimLaser") != null, 8.0)
			await _wait(0.2)
		"tail":
			c.call("_act_tail")
			await _until(func() -> bool:
				var t : Array = get_root().get_tree().get_nodes_in_group("croc_tail")
				return not t.is_empty() and (t[0] as Node2D).position.x > vp.x * 0.30 \
					and (t[0] as Node2D).position.x < vp.x * 0.70, 10.0)
		"buck":
			c.call("_buckshot", 3, CROC.BUCK_SPREAD)
			await _until(func() -> bool:
				return get_root().get_tree().get_nodes_in_group("bullet").size() >= 3, 4.0)
			await _wait(0.22)
		"rage":
			c.call("_rage_volley")
			await _until(func() -> bool:
				return get_root().get_tree().get_nodes_in_group("bullet").size() >= 5, 4.0)
			await _wait(0.02)
		"jaw":
			c.call("_jaw_lunge")
			await _wait(1.6)
		"finale":
			c.call("_finale")
			await _wait(1.1)

	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png("%s/%s.png" % [out, mode])
	print("saved ", mode)
	quit(0)

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

func _find_named(root: Node, nm: String) -> Node:
	if String(root.name).begins_with(nm):
		return root
	for c in root.get_children():
		var f := _find_named(c, nm)
		if f != null:
			return f
	return null

func _bail_out() -> void:
	for _i in 4000:
		await process_frame
	push_error("shot_croc: не дошёл до съёмки")
	quit(1)
