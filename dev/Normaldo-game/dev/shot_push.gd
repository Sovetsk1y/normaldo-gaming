extends SceneTree

# Кадр ТЕЛЕФОНА С ПУШЕМ.
#   xvfb-run -a godot --path . --resolution 960x430 --script res://dev/shot_push.gd -- <папка>
#
# Снимается то, что числами не проверишь: не закрывает ли баннер поток, читается
# ли текст, и выглядит ли рука с телефоном так, будто он его достал, а не будто
# рядом с ним что-то появилось.
const PUSH := preload("res://scripts/phone_push.gd")

func _initialize() -> void:
	var argv := OS.get_cmdline_user_args()
	var out : String = argv[0] if argv.size() > 0 else "user://shots"
	DirAccess.make_dir_recursive_absolute(out)
	var game : Node = load("res://scenes/game.tscn").instantiate()
	get_root().add_child(game)
	await process_frame
	var hud : Node = game.get_node_or_null("HUD")
	var nrm : Node2D = game.get_node_or_null("Normaldo") as Node2D

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
	for _i in 40:
		get_root().get_tree().paused = false
		await process_frame

	nrm.position = Vector2(260.0, 215.0)
	# ── СВОЙ ПУШ ЗДЕСЬ НЕ НУЖЕН ────────────────────────────────────────────
	# Первый заход спавнил свой поверх того, который HUD показывает на старте
	# уровня сам. Два баннера встают в одну точку, и на снятом кадре строки
	# накладывались друг на друга — это читалось как поломка вёрстки, хотя
	# сломан был сам снимок.
	var t := 0.0
	while t < 8.0 and _find_push(game) == null:
		get_root().get_tree().paused = false
		await process_frame
		t += 1.0 / 60.0
	if _find_push(game) == null:
		print("НЕ ДОЖДАЛСЯ пуша")
	# Ждём, пока и рука выедет, и баннер доедет до места: снятый раньше кадр
	# показал бы не то, что увидит игрок, а середину въезда.
	for _i in 55:
		get_root().get_tree().paused = false
		await process_frame
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png(out + "/push_run.png")
	print("снят push_run")
	quit(0)

func _find_push(game: Node) -> Node:
	for c in game.get_children():
		if c.get_script() == PUSH:
			return c
	return null
