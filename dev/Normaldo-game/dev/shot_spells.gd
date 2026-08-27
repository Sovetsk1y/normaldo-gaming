extends SceneTree

# Кадры новых спеллов — настоящий рендер, не замер.
#   xvfb-run -a godot --path . --display-driver x11 --rendering-driver opengl3 \
#     --resolution 960x430 --script res://dev/shot_spells.gd -- <папка> <режим>
#
# режим: dollar | pirate3 | pirate4 | dracula | glasses1 | glasses2

func _initialize() -> void:
	_bail_out()
	var argv := OS.get_cmdline_user_args()
	var out  : String = argv[0] if argv.size() > 0 else "user://shots"
	var mode : String = argv[1] if argv.size() > 1 else "dollar"
	DirAccess.make_dir_recursive_absolute(out)

	var game : Node = load("res://scenes/game.tscn").instantiate()
	get_root().add_child(game)
	await process_frame
	await process_frame
	var hud      : Node = game.get_node_or_null("HUD")
	var normaldo : Node = game.get_node_or_null("Normaldo")
	var spawner  : Node = game.get_node_or_null("Spawner")
	var save     : Node = get_root().get_node_or_null("SaveData")

	var skin  := "classic"
	var fat   := 1
	var delay := 0.20
	match mode:
		"pirate3":  skin = "pirate";  fat = 2
		"pirate4":  skin = "pirate";  fat = 3
		"dracula":  skin = "dracula"; fat = 3; delay = 0.35
		"glasses1": skin = "glasses"; fat = 2; delay = 0.12
		"glasses2": skin = "glasses"; fat = 2; delay = 0.45

	save.dollars     = 12400
	save.owned_skins = ["classic", "pirate", "dracula", "glasses"]
	save.active_skin = skin
	save.skin_level  = 10
	normaldo.call("reload_skin")
	normaldo.call("_build_skin_runtime")

	hud.call("_start_game")
	for _i in 12:
		await process_frame
	normaldo.set("fat_state", fat)
	normaldo.call("_apply_skin_to_sprite")
	if spawner:
		spawner.set_process(false)
	spawner.call("clear_items")
	for _i in 10:
		await process_frame

	# Мишень для «Размена»: без неё нечего превращать.
	if mode == "dollar":
		var rock := Area2D.new()
		rock.set_script(preload("res://scripts/hazard_item.gd"))
		rock.set("kind", "safe")
		rock.set("speed", 0.0)
		rock.position = (normaldo as Node2D).position + Vector2(150.0, 0.0)
		spawner.add_child(rock)
		await process_frame

	normaldo.call("_try_fire_ability", (normaldo as Node2D).position + Vector2(400.0, 0.0))
	var t := 0.0
	while t < delay:
		await process_frame
		t += 1.0 / 60.0

	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png("%s/%s.png" % [out, mode])
	print("saved ", mode)
	quit(0)

func _bail_out() -> void:
	for _i in 2000:
		await process_frame
	push_error("shot_spells: не дошёл до съёмки")
	quit(1)
