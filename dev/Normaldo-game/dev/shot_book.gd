extends SceneTree

# Снимок экрана «Книга учителя».
#   xvfb-run -a godot --path . --script res://dev/shot_book.gd -- <папка> [имя] [done]
#
# done — сколько сюжетных заданий считать выполненными; из них последнее ещё не
# забрано, чтобы в кадр попала кнопка получения награды.
# Работает только с настоящим рендером (x11/opengl3).

func _initialize() -> void:
	_bail_out()
	var argv := OS.get_cmdline_user_args()
	var out  : String = argv[0] if argv.size() > 0 else "user://shots"
	var name : String = argv[1] if argv.size() > 1 else "book"
	var done : int    = int(argv[2]) if argv.size() > 2 else 3
	DirAccess.make_dir_recursive_absolute(out)

	var game : Node = load("res://scenes/game.tscn").instantiate()
	get_root().add_child(game)
	await process_frame
	await process_frame
	var hud : Node = game.get_node_or_null("HUD")

	var save : Node = get_root().get_node_or_null("SaveData")
	save.dollars = 12400
	save.tokens  = 83

	var qm : Node = get_root().get_node_or_null("QuestManager")
	if qm != null:
		var completed : Array = []
		var claimed   : Array = []
		for i in qm.STORY_QUESTS.size():
			completed.append(i < done)
			claimed.append(i < done - 1)   # последнее выполненное ждёт награды
		qm.set("story_completed", completed)
		qm.set("story_claimed", claimed)
		qm.emit_signal("quests_updated")

	var screen : Node = load("res://scripts/achievements_screen.gd").new()
	screen.call("setup", hud)
	hud.add_child(screen)
	for _i in 30:
		await process_frame
	# Четвёртый аргумент — номер главы, которую открыть (1-based). Без него
	# экран сам выбирает главу с готовой наградой.
	if argv.size() > 3:
		# Вкладка каталога снимается по имени раздела; число — номер главы.
		var a3 := String(argv[3])
		if a3 in ["items", "enemies", "bosses"]:
			# В кадре должны быть ОБА состояния: пара встреченных записей и
			# запертые. Снимок с одними «???» ничего не показывает про каталог.
			var cat : Node = get_root().get_node_or_null("/root/Bestiary")
			var rows : Array = cat.call("entries_of", a3)
			for i in mini(3, rows.size()):
				cat.call("mark", String((rows[i] as Dictionary)["id"]))
			screen.call("_on_tab", a3)
		else:
			screen.call("_on_select_chapter", int(a3) - 1)
	for _i in 60:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := get_root().get_texture().get_image()
	img.save_png("%s/%s.png" % [out, name])
	print("saved ", name)
	quit(0)

func _bail_out() -> void:
	for _i in 1200:
		await process_frame
	push_error("shot_book: не дошёл до съёмки, выходим по таймауту")
	quit(1)
