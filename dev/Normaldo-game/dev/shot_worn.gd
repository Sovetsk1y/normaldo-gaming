extends SceneTree

# Кадр НАДЕВАЕМЫХ вещей — шляпа мага и маска Кейси на живом Нормальдо.
#   xvfb-run -a godot --path . --script res://dev/shot_worn.gd -- <папка> <скин> <вещь>
#
# вещь: hat | mask. Скин — id из SkinRegistry, по умолчанию classic.
#
# Проверяется глазами ровно одно: ПОСАДКА. Шляпа и маска — дети спрайта
# Нормальдо и позиционируются в долях его кадра, поэтому одна цифра садится
# сразу на все скины — и промахивается тоже сразу на всех.
#
# Снимается ЖИВОЙ забег, а не сборка головы в сетку: пробовали сетку из
# дубликатов спрайта, и она врала — у дубликата свои масштаб и поворот, а кадр
# Нормальдо это не голова, а фигура целиком, поэтому доля ширины читалась не та.

func _initialize() -> void:
	_bail_out()
	var argv := OS.get_cmdline_user_args()
	var out  : String = argv[0] if argv.size() > 0 else "user://shots"
	var skin : String = argv[1] if argv.size() > 1 else "classic"
	var worn : String = argv[2] if argv.size() > 2 else "hat"
	DirAccess.make_dir_recursive_absolute(out)

	var game : Node = load("res://scenes/game.tscn").instantiate()
	get_root().add_child(game)
	await process_frame

	# Скин ставим ПОСЛЕ первого кадра: у автолоада SaveData свой `_ready` с
	# `_load()`, и он затирает всё, что записали до него. Ставили раньше — и
	# каждый кадр выходил на том скине, что лежал в сейве, каким бы аргументом
	# скрипт ни звали.
	var save : Node = get_root().get_node_or_null("SaveData")
	save.set("active_skin", skin)
	var owned : Array = save.get("owned_skins")
	if not owned.has(skin):
		owned.append(skin)
		save.set("owned_skins", owned)
	var hud      : Node   = game.get_node_or_null("HUD")
	var normaldo : Node2D = game.get_node_or_null("Normaldo")
	var spawner  : Node   = game.get_node_or_null("Spawner")

	hud.call("_start_game")
	for _i in 10:
		await process_frame
	# Меню сносим руками. `_start_game` убирает его сам, но только досмотрев
	# интро с пультом и прыжком с дивана, а нам этого ждать незачем: логотип
	# NORMALDO висит ровно там, где голова со шляпой, и кадр выходит нечитаемым.
	var menu = hud.get("_menu_overlay")
	if menu != null and is_instance_valid(menu):
		menu.queue_free()
		hud.set("_menu_overlay", null)
	await process_frame
	normaldo.set("fat_state", 1)
	normaldo.call("_apply_skin_to_sprite")
	# Поток не нужен: разглядываем посадку, а летящая бочка поперёк головы этому
	# только мешает.
	if spawner:
		spawner.call("clear_items")
		spawner.set_process(false)
	await _wait(1.2)

	if worn == "mask":
		normaldo.call("_spawn_scars_mask")
	else:
		normaldo.call("_wear_hat", 999.0)
	await _wait(0.6)

	# Диагностика в лог: без неё непонятно, что именно попало в кадр.
	print("меню на экране: ", is_instance_valid(hud.get("_menu_overlay")))
	print("скин: ", save.get("active_skin"))
	var spr : Sprite2D = normaldo.get("_sprite")
	print("кадр Нормальдо: ", spr.texture.get_size(), " масштаб ", spr.scale)
	for c in spr.get_children():
		if c is Sprite2D:
			print("  надето: ", (c as Sprite2D).texture.resource_path.get_file(),
				" в ", (c as Sprite2D).position, " масштаб ", (c as Sprite2D).scale,
				" глобально ", (c as Sprite2D).global_position)
	print("голова глобально: ", spr.global_position)
	# Непрозрачная рамка кадра в ЭКРАННЫХ координатах: 1000×1000 у спрайта — это
	# в основном пустота, и «доля кадра» ничего не говорит о том, где на самом
	# деле макушка.
	var img : Image = spr.texture.get_image()
	var used : Rect2i = img.get_used_rect()
	var sz : Vector2 = spr.texture.get_size()
	var top_y : float = spr.global_position.y + (float(used.position.y) - sz.y * 0.5) * spr.scale.y
	var bot_y : float = spr.global_position.y + (float(used.end.y) - sz.y * 0.5) * spr.scale.y
	print("рисунок в кадре: ", used, " на экране по Y: %.0f…%.0f" % [top_y, bot_y])

	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png("%s/worn_%s_%s.png" % [out, skin, worn])
	print("saved worn_%s_%s" % [skin, worn])
	quit(0)

func _wait(sec: float) -> void:
	var t := 0.0
	while t < sec:
		get_root().get_tree().paused = false
		await process_frame
		t += 1.0 / 60.0

func _bail_out() -> void:
	for _i in 1800:
		await process_frame
	quit(1)
