extends SceneTree

# Кадр раздела ПРЕДМЕТЫ в лаборатории.
#   xvfb-run -a godot --path . --script res://dev/shot_itemlab.gd -- <папка> [номер предмета]
#
# Тест меряет, что правка доходит до забега. Глазами тут смотрят другое:
# СХОДЯТСЯ ЛИ ТРИ РАМКИ — коробка лейна, габариты рисунка и круг хитбокса. Если
# круг заметно больше рисунка, предмет бьёт воздухом вокруг себя; если рисунок
# вылез из коробки, он ест соседние линии. Оба случая видно только глазами.

func _initialize() -> void:
	for _i in 4000:
		await process_frame
	var argv := OS.get_cmdline_user_args()
	var out : String = argv[0] if argv.size() > 0 else "user://shots"
	var idx : int    = int(argv[1]) if argv.size() > 1 else 0
	DirAccess.make_dir_recursive_absolute(out)

	var game : Node = load("res://scenes/game.tscn").instantiate()
	get_root().add_child(game)
	await process_frame
	var hud : Node = game.get_node_or_null("HUD")

	hud.call("_show_skin_lab")
	await process_frame
	var lab : Node = null
	for c in hud.get_children():
		if c.get_script() != null \
				and String(c.get_script().resource_path).ends_with("skin_lab.gd"):
			lab = c
	if lab == null:
		print("лаборатория не открылась")
		quit(1)
		return

	lab.call("_cycle_mode")          # скины → предметы
	lab.set("_item", idx)
	lab.call("_refresh")
	for _i in 20:
		get_root().get_tree().paused = false
		await process_frame

	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png("%s/itemlab_%d.png" % [out, idx])
	print("saved itemlab_", idx)
	quit(0)
