extends SceneTree

# Кадры отряда СВАТ и того, что у них в руках.
#   xvfb-run -a godot --path . --resolution 960x430 --script res://dev/shot_swat.gd -- <папка>
#
# Три вида разом на трёх полосах, а следом — гранатомётчик ПОСЛЕ броска: он
# обязан идти дальше с пустыми руками, и увидеть это в бою можно только поймав
# нужную секунду.

const SWAT := preload("res://scripts/police_swat.gd")

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

	var made : Array = []
	var y : float = 86.0
	for kind in ["shield", "rifle", "grenade"]:
		var s := Area2D.new()
		s.set_script(SWAT)
		s.set("kind", kind)
		s.set("target", nrm)
		s.set("walk_speed", 0.0)
		s.position = Vector2(640.0, y)
		game.add_child(s)
		s.call("enter_from_edge")
		made.append(s)
		y += 129.0
	await _tick(0.4)
	_save(out, "swat_kinds")

	# Гранатомётчик кинул — и дальше идёт пустой.
	await _tick(2.0)
	_save(out, "swat_spent")
	print("XX вид гранатомётчика после броска: ", made[2].get("kind"))
	quit()

func _save(out: String, name: String) -> void:
	get_root().get_texture().get_image().save_png("%s/%s.png" % [out, name])
	print("XX ", name)

func _tick(sec: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		get_root().get_tree().paused = false
		await process_frame
