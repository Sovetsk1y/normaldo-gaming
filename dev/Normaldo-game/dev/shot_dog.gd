extends SceneTree

# Кадры собаки капитана — все четыре состояния подряд.
#   xvfb-run -a godot --path . --resolution 960x430 --script res://dev/shot_dog.gd -- <папка>
#
# Снимать её в общем бою бесполезно: пауза на цепи длится сорок сотых, а пасть
# раскрывается на подлёте к игроку — попасть в оба момента секундомером нельзя.
# Поэтому собака поднимается ЗДЕСЬ и в известных положениях: на цепи у хозяина,
# в броске далеко от игрока и в броске вплотную к нему.

const DOG := preload("res://scripts/police_dog.gd")

func _initialize() -> void:
	var argv := OS.get_cmdline_user_args()
	var out : String = argv[0] if argv.size() > 0 else "user://shots"
	DirAccess.make_dir_recursive_absolute(out)
	var game : Node = load("res://scenes/game.tscn").instantiate()
	get_root().add_child(game)
	await process_frame
	get_root().get_tree().paused = false
	var hud : Node = game.get_node_or_null("HUD")
	# Меню — CanvasLayer ПОВЕРХ мира: снятый через него кадр показывает логотип и
	# кнопки, а не арену. Ждём, пока оно соберётся, и ждём, пока разберётся.
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
	var nrm : Node2D = game.get_node_or_null("Normaldo") as Node2D

	# ── На цепи у хозяина ──
	# Ждём САМУ СОБАКУ, а не секунды: перед первым актом капитан въезжает и
	# говорит, и сколько это займёт — не наше дело.
	hud.call("summon_police", true)
	var t0 := Time.get_ticks_msec()
	while get_root().get_tree().get_nodes_in_group("police_dog").is_empty() \
			and Time.get_ticks_msec() - t0 < 45000:
		get_root().get_tree().paused = false
		await process_frame
	await _tick(0.10)
	_save(out, "dog_leashed")
	await _tick(0.28)
	_save(out, "dog_strain")

	# ── Отдельная собака: далеко от игрока и вплотную ──
	var far := Area2D.new()
	far.set_script(DOG)
	far.set("target", nrm)
	far.set("owner_node", nrm)
	far.position = Vector2(620.0, 215.0)
	game.add_child(far)
	await _tick(1.0)
	far.set("_vel", Vector2.ZERO)
	far.position = Vector2(620.0, 215.0)
	await _tick(0.1)
	_save(out, "dog_far")
	print("XX кадр вдали: ", _frame_of(far), " на расстоянии ",
		far.global_position.distance_to(nrm.global_position))

	far.position = nrm.position + Vector2(60.0, 0.0)
	await _tick(0.1)
	_save(out, "dog_near")
	print("XX кадр вплотную: ", _frame_of(far), " на расстоянии ",
		far.global_position.distance_to(nrm.global_position))
	quit()

# Как называется кадр, который сейчас на собаке, — по имени файла.
func _frame_of(dog: Node) -> String:
	for c in dog.get_children():
		if c is Sprite2D and (c as Sprite2D).texture != null:
			return String((c as Sprite2D).texture.resource_path).get_file()
	return "?"

func _save(out: String, name: String) -> void:
	get_root().get_texture().get_image().save_png("%s/%s.png" % [out, name])
	print("XX ", name)

func _tick(sec: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		get_root().get_tree().paused = false
		await process_frame
