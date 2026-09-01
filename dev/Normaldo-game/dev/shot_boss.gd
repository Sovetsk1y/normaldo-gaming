extends SceneTree

# Снимки ЖИРОБОССА по всем скинам и состояниям жира.
#   xvfb-run -a godot --path . --script res://dev/shot_boss.gd -- <папка> [coll]
#
# Второй аргумент «coll» включает отрисовку коллизий: так видно, совпадает ли
# круг столкновения с нарисованной головой. Без этого «предмет ломается перед
# лицом» проверить нечем.
#
# Работает только с настоящим рендером (x11/opengl3): в --headless нет
# рендер-устройства и viewport отдаёт пустую картинку.

const SKINS : Array = [
	"classic", "viking", "tyson", "batman", "halloween", "kuss", "new_year",
	"dracula", "glasses", "wizard", "harry_potter", "pirate", "spider_man", "joker",
]

func _initialize() -> void:
	var argv := OS.get_cmdline_user_args()
	var out : String = argv[0] if argv.size() > 0 else "user://shots"
	var show_coll : bool = argv.size() > 1 and argv[1] == "coll"
	DirAccess.make_dir_recursive_absolute(out)

	# Флаг обязан стоять ДО инстанса сцены: CollisionShape2D решает, рисовать ли
	# себя, при входе в дерево.
	debug_collisions_hint = show_coll
	var game : Node = load("res://scenes/game.tscn").instantiate()
	get_root().add_child(game)
	await process_frame
	await process_frame

	var normaldo : Node = game.get_node_or_null("Normaldo")
	var spawner  : Node = game.get_node_or_null("Spawner")
	var boss     : Node = game.get_node_or_null("FatBoss")
	var save     : Node = get_root().get_node_or_null("SaveData")
	if normaldo == null or boss == null:
		print("сцена не собралась")
		quit(1)
		return

	spawner.clear_items()

	# Режим «tap»: один кадр с подсказкой мини-игры — картинка TAP! и пальцы по
	# бокам. Пальцы снимаются в НИЖНЕЙ точке (кадр «прижат»), иначе в кадре стоят
	# две поднятые руки и проверить нечего.
	if argv.size() > 1 and argv[1] == "tap":
		save.active_skin = "classic"
		save.skin_level  = 10
		normaldo.reload_skin()
		await process_frame
		game.get_node("HUD").call("_start_game")
		for _i in 20:
			await process_frame
		boss.call("dev_begin_play", 1.0)
		for _i in 40:
			await process_frame
		boss.call("_show_prompt")
		var t0 : float = Time.get_ticks_msec() / 1000.0
		var want : float = float(boss.get("FINGER_DOWN_T")) \
			+ float(boss.get("FINGER_HOLD_T")) * 0.5
		while Time.get_ticks_msec() / 1000.0 - t0 < want:
			await process_frame
		await RenderingServer.frame_post_draw
		get_root().get_texture().get_image().save_png("%s/boss_tap.png" % out)
		print("готово")
		quit(0)
		return

	for sid in SKINS:
		for fat in 4:
			save.active_skin = sid
			save.skin_level  = 10          # чтобы были доступны все состояния жира
			normaldo.reload_skin()
			await process_frame
			normaldo.set("fat_state", fat)
			normaldo.call("_apply_skin_to_sprite")
			# Ставим босса напрямую, без погони за мутагеном: нас интересует
			# ровно кадр френзи.
			normaldo.call("begin_fat_boss")
			boss.call("dev_pose_boss")
			await process_frame
			var ov : Node2D = _draw_hitbox(game, normaldo) if show_coll else null
			await process_frame
			await RenderingServer.frame_post_draw
			var img := get_root().get_texture().get_image()
			img.save_png("%s/boss_%s_%d.png" % [out, sid, fat])
			if ov != null:
				ov.queue_free()
			normaldo.call("end_fat_boss")
			await process_frame
	print("готово")
	quit(0)

# Круг хитбокса рисуется ПОВЕРХ головы: собственная отрисовка CollisionShape2D
# лежит под спрайтом (z_index 1) и гигантской головой закрывается полностью.
func _draw_hitbox(game: Node, normaldo: Node) -> Node2D:
	var cs := normaldo.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if cs == null or not (cs.shape is CircleShape2D):
		return null
	var r : float = (cs.shape as CircleShape2D).radius * float(normaldo.get("scale").x)
	var ov := Node2D.new()
	ov.z_index  = 200
	ov.position = normaldo.get("position")
	ov.set_script(GDScript.new())
	game.add_child(ov)
	var line := Line2D.new()
	line.width       = 3.0
	line.default_color = Color(1.0, 0.25, 0.25, 0.9)
	var pts := PackedVector2Array()
	for i in 65:
		var a := TAU * float(i) / 64.0
		pts.append(Vector2(cos(a), sin(a)) * r)
	line.points = pts
	ov.add_child(line)
	return ov
