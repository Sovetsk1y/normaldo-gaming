extends SceneTree

# Кадры новых спеллов — настоящий рендер, не замер.
#   xvfb-run -a godot --path . --display-driver x11 --rendering-driver opengl3 \
#     --resolution 960x430 --script res://dev/shot_spells.gd -- <папка> <режим>
#
# режим: dollar | cash | hand | pirate3 | pirate4 | dracula | wings | wings_flap |
#        glasses1 | glasses2 | kuss | fist_viking | fist_tyson | power

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
		"cash":       skin = "classic"; fat = 1; delay = 0.30
		"wings":      skin = "dracula"; fat = 3; delay = 0.02
		"wings_flap": skin = "dracula"; fat = 3; delay = 0.34
		"kuss":        skin = "kuss";    fat = 3; delay = 0.15
		"hand":        skin = "classic"; fat = 1; delay = 0.10
		"fist_viking": skin = "viking";  fat = 2; delay = 0.13
		"fist_tyson":  skin = "tyson";   fat = 2; delay = 0.13
		"power":       skin = "viking";  fat = 2; delay = 0.40

	save.dollars     = 12400
	save.owned_skins = ["classic", "pirate", "dracula", "glasses", "kuss", "viking", "tyson"]
	save.active_skin = skin
	save.skin_level  = 10
	normaldo.call("reload_skin")
	normaldo.call("_build_skin_runtime")

	hud.call("_start_game")
	# Интро («АНН» + бросок на диван) идёт около двух секунд и своим титром
	# закрывает лицо. Снимать спелл поверх него — снимать не спелл.
	for _i in 190:
		await process_frame
	normaldo.set("fat_state", fat)
	normaldo.call("_apply_skin_to_sprite")
	if spawner:
		spawner.set_process(false)
	spawner.call("clear_items")
	for _i in 10:
		await process_frame

	# Мишень. Для «POWER!» она ставится ВНЕ хитбокса головы (radius ~32), но в
	# пределах замаха викинга (92): ближе — и предмет съедает сам Нормальдо,
	# кулак бьёт уже по пустому месту.
	if mode in ["dollar", "cash", "power"]:
		var rock := Area2D.new()
		rock.set_script(preload("res://scripts/hazard_item.gd"))
		rock.set("kind", "safe")
		rock.set("speed", 0.0)
		rock.position = (normaldo as Node2D).position \
			+ Vector2(72.0 if mode == "power" else 150.0, 0.0)
		spawner.add_child(rock)
		await process_frame

	if not mode.begins_with("wings"):
		normaldo.call("_try_fire_ability", (normaldo as Node2D).position + Vector2(400.0, 0.0))
	# «POWER!» живёт треть секунды, и ловить его фиксированной задержкой —
	# гадание: попадание случается когда случается. Ждём появления самого
	# спрайта, а не отсчитываем время.
	if mode == "power":
		var pw : Texture2D = load("res://assets/skills/power.png")
		for _i in 120:
			await process_frame
			if _find_tex(normaldo.get_parent(), pw) != null:
				break
	else:
		var t := 0.0
		while t < delay:
			await process_frame
			t += 1.0 / 60.0

	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png("%s/%s.png" % [out, mode])
	print("saved ", mode)
	quit(0)

func _find_tex(root: Node, tex: Texture2D) -> Sprite2D:
	if root is Sprite2D and (root as Sprite2D).texture == tex:
		return root
	for c in root.get_children():
		var f := _find_tex(c, tex)
		if f != null:
			return f
	return null

func _bail_out() -> void:
	for _i in 2000:
		await process_frame
	push_error("shot_spells: не дошёл до съёмки")
	quit(1)
