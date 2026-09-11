extends SceneTree

# Кружки активных способностей — все в один кадр и крупно.
#   xvfb-run -a godot --path . --resolution 960x430 --script res://dev/shot_ability_badges.gd -- <папка> [имя]
#
# Судить о значке по общему снимку карточки нельзя: кружок там 52 px, лежит в
# прокручиваемой колонке и у каждого скина на своей высоте. Здесь он рисуется
# ровно тем же `_ability_badge`, но крупно и рядом с соседями — видно и то, что
# картинка читается, и то, что соседние друг на друга не похожи.

func _initialize() -> void:
	var argv := OS.get_cmdline_user_args()
	var out  : String = argv[0]
	var name : String = argv[1] if argv.size() > 1 else "ability_badges"
	DirAccess.make_dir_recursive_absolute(out)
	await process_frame
	var game : Node = load("res://scenes/game.tscn").instantiate()
	get_root().add_child(game)
	await process_frame
	await process_frame
	var hud : Node = game.get_node("HUD")
	var skills := get_root().get_node("SkinSkills")
	var reg := get_root().get_node("SkinRegistry")

	var layer := CanvasLayer.new()
	layer.layer = 200
	get_root().add_child(layer)
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.07, 1.0)
	bg.size  = get_root().get_visible_rect().size
	layer.add_child(bg)

	var sz   := 96.0
	var step := 118.0
	var x    := 14.0
	var y    := 120.0
	for s in reg.SKINS:
		var sid : String = String((s as Dictionary)["id"])
		var ab : Dictionary = skills.get_ability(sid)
		if ab.is_empty() or String(ab.get("icon", "")) == "":
			continue
		var holder := Control.new()
		holder.position = Vector2(x, y); holder.size = Vector2(sz, sz)
		bg.add_child(holder)
		hud.call("_ability_badge", holder, 0.0, 0.0, sz,
			Color(0.35, 1.00, 0.45), load(String(ab["icon"])), Color(1, 1, 1), "",
			false, float(ab.get("icon_k", 1.0)),
			ab.get("icon_glow", Color(0, 0, 0, 0)))
		var lbl := Label.new()
		lbl.text = sid
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.size = Vector2(sz, 16.0); lbl.position = Vector2(x, y + sz + 4.0)
		bg.add_child(lbl)
		x += step
		if x + sz > bg.size.x:
			x = 14.0
			y += sz + 46.0
	for _i in 10:
		await process_frame
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png("%s/%s.png" % [out, name])
	print("saved ", name)
	quit(0)
