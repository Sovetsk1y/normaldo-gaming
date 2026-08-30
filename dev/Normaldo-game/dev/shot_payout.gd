extends SceneTree

# Снимки окна итогов мини-игры — чтобы смотреть его, не собирая билд.
#   xvfb-run -a godot --path . --script res://dev/shot_payout.gd -- <папка>
#
# Работает ТОЛЬКО с настоящим рендером (x11/opengl3): в --headless нет
# рендер-устройства и viewport отдаёт пустую картинку.

const PAYOUT := preload("res://scripts/minigame_payout.gd")

# Секунда прогона → имя кадра. Точки выбраны по тактам сцены: барабаны крутятся,
# встали, «×N» вылетел, числа выросли, добыча улетает.
const SHOTS : Array = [
	[1.30, "1_spin"],
	[2.60, "2_landed"],
	[3.10, "3_mult"],
	[3.80, "4_grown"],
	[4.25, "5_flyout"],
	[4.90, "6_slake"],
]

func _initialize() -> void:
	var out : String = "user://shots"
	var argv := OS.get_cmdline_user_args()
	if argv.size() > 0:
		out = argv[0]
	DirAccess.make_dir_recursive_absolute(out)

	var game : Node = load("res://scenes/game.tscn").instantiate()
	get_root().add_child(game)
	await process_frame
	await process_frame

	var w : Node = PAYOUT.new()
	w.call("setup", 12, 7, 4, Vector2(120.0, 14.0), Vector2(180.0, 14.0))
	game.add_child(w)

	var t := 0.0
	var next := 0
	while next < SHOTS.size():
		await process_frame
		t += get_root().get_process_delta_time()
		if t >= float(SHOTS[next][0]):
			await RenderingServer.frame_post_draw
			var img := get_root().get_texture().get_image()
			var path : String = "%s/payout_%s.png" % [out, SHOTS[next][1]]
			img.save_png(path)
			print("saved ", path)
			next += 1
	quit(0)
