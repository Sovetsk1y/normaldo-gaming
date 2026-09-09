extends SceneTree

# Кадры боя с КАПИТАНОМ ПОЛИЦИИ — по одному на каждый акт.
#   xvfb-run -a godot --path . --resolution 960x430 --script res://dev/shot_police.gd -- <папка>
#
# Снимки берутся ПО РЕАЛЬНОМУ ВРЕМЕНИ от начала боя: акты идут по таймерам, и
# отсчитывать их кадрами нельзя — в headless-рендере кадры пролетают за доли
# секунды, и все четыре снимка вышли бы из первой секунды.
const SHOTS : Array = [
	[ 7.0, "dog",    "собака"],
	[13.0, "squad",  "отряд"],
	[24.0, "strafe", "штурмовка"],
	[55.0, "rope",   "трос"],
	[57.6, "finale", "пицца на голову"],
]

func _initialize() -> void:
	var argv := OS.get_cmdline_user_args()
	var out : String = argv[0] if argv.size() > 0 else "user://shots"
	DirAccess.make_dir_recursive_absolute(out)
	var game : Node = load("res://scenes/game.tscn").instantiate()
	get_root().add_child(game)
	await process_frame
	var hud : Node = game.get_node_or_null("HUD")
	var nrm : Node2D = game.get_node_or_null("Normaldo")
	hud.call("_start_game")
	var boot := Time.get_ticks_msec()
	while Time.get_ticks_msec() - boot < 5000:
		get_root().get_tree().paused = false
		await process_frame
	nrm.call("enable_input")
	nrm.call("set_dev_immortal", true)
	# Голову ставим В СЕРЕДИНУ ЛЕВОЙ ПОЛОВИНЫ: туда идут сватовцы и туда летит
	# собака, и с края кадр читался бы как «никого нет».
	var vp : Vector2 = get_root().get_visible_rect().size
	nrm.position = Vector2(vp.x * 0.26, vp.y * 0.5)
	hud.call("summon_police", true)

	var t0 := Time.get_ticks_msec()
	for s in SHOTS:
		var at : float = float(s[0])
		while float(Time.get_ticks_msec() - t0) / 1000.0 < at:
			get_root().get_tree().paused = false
			await process_frame
		await RenderingServer.frame_post_draw
		var img := get_root().get_texture().get_image()
		img.save_png("%s/police_%s.png" % [out, String(s[1])])
		# И КРУПНО правый край: капитан там ростом с ладонь, а проверять надо
		# фуражку, рацию и пиццу на макушке — несколько десятков пикселей.
		var vpz : Vector2i = img.get_size()
		var rect := Rect2i(vpz.x - 320, 0, 320, min(vpz.y, 320))
		var crop := img.get_region(rect)
		crop.resize(crop.get_width() * 2, crop.get_height() * 2, Image.INTERPOLATE_NEAREST)
		crop.save_png("%s/police_%s_zoom.png" % [out, String(s[1])])
		print("снят %s на %.0f c" % [String(s[2]), at])
	print("saved")
	quit(0)
