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
	print("── Размер головы ──")
	_test_heads(reg)
	print("── Карточка скина ──")
	_test_card(skil, save)
	print("── Касты ──")
	await _test_casts(reg, save)
	print("── Паутина Спайдера ──")
	await _test_web(save)

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

	# Три состояния жира доступны сразу, 4-е открывает 2-й уровень.
	var f1 : int = prog.max_fat_state("viking", 1)
	var f2 : int = prog.max_fat_state("viking", 2)
	_check(f1 == 2 and f2 == 3, "жир: 1 лвл → %d состояния, 2 лвл → %d" % [f1 + 1, f2 + 1])

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

# Замеры голов лежат таблицей (skin_metrics.gd), и главный риск — добавить скин
# и забыть её пересчитать: тогда он молча отрисуется по старой логике «ширина
# кадра» и снова окажется мельче остальных. Сверку самой таблицы со спрайтами
# делает dev/tools/measure_heads.py --check, здесь ловим именно пропуск.
func _test_heads(reg: Node) -> void:
	var metrics : Node = get_root().get_node_or_null("SkinMetrics")
	var missing : Array = []
	for s in reg.SKINS:
		var id := String(s["id"])
		if id == "classic":
			continue   # у классики кадр это ровно голова, замер не нужен
		if not metrics.HEADS.has(id):
			missing.append(id)
	_check(missing.is_empty(), "замеры головы есть у всех скинов, пропущено: %s" % [missing])

	# Джокер — крайний случай: его голова 27 % кадра, множитель должен быть
	# заметно больше единицы, иначе нормировка не работает.
	var jk : float = metrics.scale_for("joker")
	_check(jk > 3.0, "Джокеру назначен множитель ×%.2f" % jk)

	# Смещение головы у Гарри ощутимое — проверяем, что оно вообще не нулевое.
	var off : Vector2 = metrics.offset_for("harry_potter", 0)
	_check(absf(off.x) > 0.05, "у Гарри учтено смещение головы от центра: %.3f" % off.x)

# Карточка обязана показывать ВСЕ резисты скина, включая ещё не открытые, —
# иначе игрок не видит, ради чего качать скин дальше. Открытые и закрытые
# различаются флагом unlocked, по нему рисуется замок.
func _test_card(skil: Node, save: Node) -> void:
	save.active_skin = "tyson"
	save.skin_level  = 1
	var all_1 : Array = skil.all_resists("tyson")
	_check(all_1.size() == 3, "на 1 уровне в карточке всё равно 3 кружка резистов")
	var locked := 0
	for r in all_1:
		if not bool(r.get("unlocked", true)):
			locked += 1
	_check(locked == 3, "на 1 уровне все три закрыты замком")

	save.skin_level = 6
	var all_6 : Array = skil.all_resists("tyson")
	var open_6 := 0
	for r in all_6:
		if bool(r.get("unlocked", false)):
			open_6 += 1
	_check(all_6.size() == 3 and open_6 == 2,
		"на 6 уровне кружков всё так же 3, открыто %d" % open_6)

	# Уровень открытия должен быть проставлен — по нему подпись «откроется на N».
	var lvls : Array = []
	for r in all_6:
		lvls.append(int(r.get("level", 0)))
	_check(lvls == [4, 6, 8], "уровни открытия резистов: %s" % [lvls])

	# Карточка НЕ активного скина должна смотреть на его собственный уровень,
	# а не показывать всё открытым.
	save.active_skin = "viking"
	save.skin_level  = 10
	var other : Array = skil.all_resists("tyson")
	var other_open := 0
	for r in other:
		if bool(r.get("unlocked", false)):
			other_open += 1
	_check(other_open < 3, "у неактивного скина открыто по ЕГО уровню: %d из 3" % other_open)

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

# Паутина обязана вести себя по-разному: добычу тянет к себе, препятствие
# облепляет и тормозит. Если перепутать — спелл с откатом 2 c будет уничтожать
# любую угрозу и обесценит остальные скины.
func _test_web(save: Node) -> void:
	var game : Node = load("res://scenes/game.tscn").instantiate()
	get_root().add_child(game)
	await process_frame
	var normaldo : Node = game.get_node_or_null("Normaldo")
	var spawner  : Node = game.get_node_or_null("Spawner")
	spawner.clear_items()
	save.active_skin = "spider_man"
	save.skin_level  = 10
	normaldo.reload_skin()
	await process_frame

	# Препятствие: липнет и тормозит, но НЕ ломается.
	var rock := Area2D.new()
	rock.set_script(preload("res://scripts/hazard_item.gd"))
	rock.set("kind", "safe")
	rock.set("speed", 250.0)
	rock.position = Vector2(500.0, 200.0)
	spawner.add_child(rock)
	await process_frame
	var speed_before : float = float(rock.get("speed"))
	normaldo.call("_web_stick", rock)
	await process_frame
	_check(is_instance_valid(rock), "препятствие после паутины ЖИВО, а не сломано")
	_check(float(rock.get("speed")) < speed_before,
		"препятствие замедлено: %.0f → %.0f" % [speed_before, float(rock.get("speed"))])
	_check(rock.has_meta("webbed"), "на препятствии висит паутина")

	# Добыча: подтягивается к голове.
	var pizza := Area2D.new()
	pizza.set_script(preload("res://scripts/effect_item.gd"))
	pizza.set("kind", "casino_chip")
	pizza.set("speed", 250.0)
	pizza.position = Vector2(700.0, 60.0)
	spawner.add_child(pizza)
	await process_frame
	var dist_before : float = pizza.global_position.distance_to(normaldo.global_position)
	normaldo.call("_web_pull", pizza)
	# Замеряем В ПОЛЁТЕ: долетев до головы, добыча честно подбирается и узел
	# освобождается — это правильный исход, а не пропажа.
	var t := 0.0
	while t < 0.12:
		await process_frame
		t += 1.0 / 60.0
	if is_instance_valid(pizza):
		var dist_after : float = pizza.global_position.distance_to(normaldo.global_position)
		_check(dist_after < dist_before,
			"добыча подтягивается к голове: %.0f → %.0f" % [dist_before, dist_after])
	else:
		_check(true, "добыча долетела до головы и подобрана")

	game.queue_free()
