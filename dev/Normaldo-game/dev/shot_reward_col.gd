extends SceneTree

# Правая колонка карточки скина — награды за уровни.
#   xvfb-run -a godot --path . --resolution 960x430 --script res://dev/shot_reward_col.gd -- <папка> <имя> <скин> <прокрутка px>
#
# Отдельный снимок, потому что две вещи мешают увидеть карточку наград на общем
# кадре: облачко тура ложится ровно на колонку, а денежные награды лежат ниже
# видимой части списка и без прокрутки в кадр не попадают.

func _initialize() -> void:
	var argv := OS.get_cmdline_user_args()
	var out   : String = argv[0]
	var name  : String = argv[1]
	var skin  : String = argv[2] if argv.size() > 2 else "viking"
	var scroll: float  = float(argv[3]) if argv.size() > 3 else 0.0
	DirAccess.make_dir_recursive_absolute(out)
	# Состояние ставится ДО сборки сцены: меню решает, показывать ли облачко
	# тура, у себя в `_ready`, и флаг, выставленный после, оно уже не увидит —
	# первый снимок вышел ровно с облачком поперёк колонки.
	await process_frame
	var save := get_root().get_node("SaveData")
	save.set("tutorial_done", true)
	save.set("dollars", 99000)
	save.set("tokens", 83)
	var seen : Dictionary = {}
	for k in ["start", "quests", "skins", "slots", "leaders", "book", "awards"]:
		seen[k] = true
	save.set("menu_tips_seen", seen)
	TranslationServer.set_locale("ru")
	var game : Node = load("res://scenes/game.tscn").instantiate()
	get_root().add_child(game)
	await process_frame
	await process_frame
	var hud : Node = game.get_node("HUD")
	var reg : Node = get_root().get_node("SkinRegistry")
	hud.call("_show_skin_detail", reg.get_skin(skin), true, null, true)
	for _i in 90:
		await process_frame
	if scroll > 0.0:
		for sc in _scrolls(get_root()):
			(sc as ScrollContainer).scroll_vertical = int(scroll)
		for _i in 10:
			await process_frame
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png("%s/%s.png" % [out, name])
	print("saved ", name)
	quit(0)

func _scrolls(n: Node) -> Array:
	var out : Array = []
	if n is ScrollContainer:
		out.append(n)
	for c in n.get_children():
		out.append_array(_scrolls(c))
	return out
