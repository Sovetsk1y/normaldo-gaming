extends SceneTree

# Headless-проверка скинов: лестница уровней, резисты и касты всех спеллов.
#   godot --headless --path . --script res://dev/smoke_skins.gd

var _fails : int = 0

func _check(ok: bool, what: String) -> void:
	if ok:
		print("  ok   ", what)
	else:
		_fails += 1
		print("  FAIL ", what)

func _initialize() -> void:
	var save : Node = get_root().get_node_or_null("SaveData")
	var prog : Node = get_root().get_node_or_null("SkinProgression")
	var skil : Node = get_root().get_node_or_null("SkinSkills")
	var reg  : Node = get_root().get_node_or_null("SkinRegistry")

	print("── Лестница уровней ──")
	_test_ladder(prog, reg)
	print("── Резисты по уровням ──")
	_test_resists(prog, skil, save)
	print("── Касты ──")
	await _test_casts(reg, save)

	print("")
	if _fails == 0:
		print("ВСЁ ЗЕЛЁНОЕ")
	else:
		print("ПРОВАЛОВ: ", _fails)
	quit(1 if _fails > 0 else 0)

func _test_ladder(prog: Node, reg: Node) -> void:
	var ids : Array = []
	for s in reg.SKINS:
		ids.append(String(s["id"]))

	var no_first := true
	var full := true
	for id in ids:
		# Главное требование: на 1-м уровне награды нет — скин уже куплен.
		if not prog.reward_for(id, 1).is_empty():
			no_first = false
			print("      у «%s» есть награда на 1 уровне" % id)
		for lv in range(2, 11):
			if prog.reward_for(id, lv).is_empty():
				full = false
				print("      у «%s» пусто на уровне %d" % [id, lv])
	_check(no_first, "ни у одного скина нет награды за 1 уровень")
	_check(full, "уровни 2–10 заполнены у всех %d скинов" % ids.size())

	# 4-е состояние жира открывает 2-й уровень, а не 5-й как раньше.
	var f1 : int = prog.max_fat_state("viking", 1)
	var f2 : int = prog.max_fat_state("viking", 2)
	_check(f1 == 1 and f2 == 3, "жир: 1 лвл → %d, 2 лвл → %d" % [f1, f2])

	# Венец 10-го уровня есть у каждого скина из ТЗ.
	var crowned := 0
	for id in ids:
		if not prog.reward_for(id, 10).is_empty():
			crowned += 1
	_check(crowned == ids.size(), "у всех скинов есть награда 10 уровня")

func _test_resists(prog: Node, skil: Node, save: Node) -> void:
	# Резисты копятся по уровням: до 4-го ни одного, после 8-го — три.
	var at3 : int = prog.immunities("tyson", 3).size()
	var at4 : int = prog.immunities("tyson", 4).size()
	var at8 : int = prog.immunities("tyson", 8).size()
	_check(at3 == 0 and at4 == 1 and at8 == 3,
		"Тайсон: 3 лвл → %d, 4 лвл → %d, 8 лвл → %d резистов" % [at3, at4, at8])

	# У резиста есть откат — это по-прежнему резист, а не вечный иммунитет.
	var rows : Array = skil.resists_at("tyson", 8)
	var has_cd := rows.size() == 3
	for r in rows:
		if float(r.get("cd", 0.0)) <= 0.0:
			has_cd = false
	_check(has_cd, "у всех резистов Тайсона задан откат")

	# Эпические и легендарные перезаряжаются быстрее обычных.
	var cd_common : float = skil.resist_cd("tyson")
	var cd_epic   : float = skil.resist_cd("wizard")
	_check(cd_epic < cd_common, "откат: обычный %.0f c > эпический %.0f c" % [cd_common, cd_epic])

	# get_resists для АКТИВНОГО скина обязан смотреть на его реальный уровень.
	save.active_skin = "tyson"
	save.skin_level  = 3
	_check(skil.get_resists("tyson").is_empty(), "на 3 уровне активный скин без резистов")
	save.skin_level = 10
	_check(skil.get_resists("tyson").size() == 3, "на 10 уровне активный скин с тремя резистами")

func _test_casts(reg: Node, save: Node) -> void:
	var game : Node = load("res://scenes/game.tscn").instantiate()
	get_root().add_child(game)
	await process_frame
	var normaldo : Node = game.get_node_or_null("Normaldo")
	var spawner  : Node = game.get_node_or_null("Spawner")
	if normaldo == null:
		_check(false, "сцена не собралась")
		return
	normaldo.enable_input()
	normaldo.set_dev_immortal(true)
	spawner.clear_items()

	# Каждый скин: переключаемся, кастуем, ждём. Падение любого спелла всплывёт
	# как SCRIPT ERROR в stderr прогона.
	for s in reg.SKINS:
		var id := String(s["id"])
		save.active_skin = id
		save.skin_level  = 10
		normaldo.reload_skin()
		await process_frame
		normaldo.call("_build_skin_runtime")
		for i in 3:
			normaldo.call("_try_fire_ability", normaldo.position + Vector2(120.0, 0.0))
			await process_frame
		var t := 0.0
		while t < 0.5:
			await process_frame
			t += 1.0 / 60.0
		_check(is_instance_valid(normaldo) and not bool(normaldo.get("_dead")),
			"«%s» отработал каст" % id)

	# Поза каста подгрузилась у скинов, чьи архивы приехали.
	var posed : Array = []
	var with_art := ["batman", "harry_potter", "halloween", "spider_man", "wizard",
		"joker", "tyson", "viking"]
	for id in with_art:
		save.active_skin = id
		normaldo.reload_skin()
		await process_frame
		var arr : Array = normaldo.get("_skin_spell_tex")
		var n := 0
		for tex in arr:
			if tex != null:
				n += 1
		if n == 4:
			posed.append(id)
	_check(posed.size() == with_art.size(),
		"позы каста на всех 4 состояниях жира у %d/%d скинов: %s"
		% [posed.size(), with_art.size(), posed])

	game.queue_free()
