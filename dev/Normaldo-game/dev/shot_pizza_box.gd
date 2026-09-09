extends SceneTree

# Кадр КЛЮЧЕЙ мини-игр: мутаген и коробка пиццы рядом, в одном кадре.
#   xvfb-run -a godot --path . --resolution 960x430 --script res://dev/shot_pizza_box.gd -- <папка>
#
# Рядом — намеренно. Эффект у них ОБЩИЙ (scripts/minigame_glow.gd), и разойтись
# он может только цветом; увидеть это можно ТОЛЬКО в одном кадре — по отдельности
# оба выглядят правильно.
#
# ── ПОЧЕМУ КЛЮЧИ ЗАПУСКАЮТСЯ СВОИМИ ХОЗЯЕВАМИ ───────────────────────────────
# Первым заходом оба клались руками в свой CanvasLayer поверх меню. Мутаген в
# такой сборке УБИРАЛ СЕБЯ САМ, и кадр выходил с одной коробкой — а выглядело
# это как «у мутагена пропало свечение».
#
# Поэтому каждый ключ шлёт тот, кто его шлёт в игре: FatBoss мутаген, PizzaParty
# коробку. Заодно это и проверка: если хозяин разучится их отправлять, кадр
# выйдет пустым, и это видно сразу.

func _initialize() -> void:
	var argv := OS.get_cmdline_user_args()
	var out : String = argv[0] if argv.size() > 0 else "user://shots"
	DirAccess.make_dir_recursive_absolute(out)
	var game : Node = load("res://scenes/game.tscn").instantiate()
	get_root().add_child(game)
	await process_frame
	var hud   : Node = game.get_node_or_null("HUD")
	var sp    : Node = game.get_node_or_null("Spawner")
	var nrm   : Node2D = game.get_node_or_null("Normaldo")
	var boss  : Node = game.get_node_or_null("FatBoss")
	var party : Node = game.get_node_or_null("PizzaParty")
	hud.call("_start_game")
	for _i in 40:
		get_root().get_tree().paused = false
		await process_frame
	nrm.call("enable_input")
	# Поток гасим: ключи должны быть видны, а не тонуть в пицце.
	sp.set("_frozen", true)
	sp.call("clear_items")
	await process_frame

	boss.call("_send_mutagen")
	party.call("_send_box")
	await process_frame

	var vp : Vector2 = get_root().get_visible_rect().size
	var mut : Node2D = boss.get("_mutagen")
	var box : Node2D = party.get("_box")
	# Останавливаем и разводим по кадру. Скорость гасим ПОСЛЕ отправки: хозяин
	# ставит её сам, из текущей фазы забега.
	for pair in [[mut, 0.32], [box, 0.68]]:
		var n = pair[0]
		if n == null or not is_instance_valid(n):
			print("  ключ не долетел: ", pair[1])
			continue
		n.set("speed", 0.0)
		n.position = Vector2(vp.x * float(pair[1]), vp.y * 0.5)

	# Голову убираем с глаз: она в кадре не нужна, а реакция на близость от неё
	# зависит — ставим её РОВНО посередине между ключами, чтобы обоим досталось
	# поровну.
	nrm.position = Vector2(vp.x * 0.5, vp.y * 0.5)

	for _i in 40:
		await process_frame
	for pair in [["мутаген", mut], ["коробка", box]]:
		var n = pair[1]
		if n == null or not is_instance_valid(n):
			print("  %s: УБРАЛСЯ САМ" % pair[0])
			continue
		print("  %s: поз=%s" % [pair[0], (n as Node2D).position])
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png(out + "/keys.png")
	print("saved")
	quit(0)
