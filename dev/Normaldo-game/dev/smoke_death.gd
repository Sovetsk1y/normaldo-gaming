extends SceneTree

# Headless-проверка экрана смерти.
#   godot --headless --path . --script res://dev/smoke_death.gd
#
# Здесь игрок решает «ещё раз или хватит», и решает по цифрам с этого экрана.
# Врущая строка рекорда или отрицательный остаток опыта — не косметика: они
# ломают ровно то, ради чего экран существует.
#
# См. /Концепция/Экран смерти.md

var _fails : int = 0

func _check(ok: bool, what: String) -> void:
	if ok:
		print("  ok   ", what)
	else:
		_fails += 1
		print("  FAIL ", what)

func _initialize() -> void:
	var game : Node = load("res://scenes/game.tscn").instantiate()
	get_root().add_child(game)
	await process_frame
	await process_frame
	var hud  : Node = game.get_node_or_null("HUD")
	var save : Node = get_root().get_node_or_null("SaveData")
	if hud == null or save == null:
		print("  FAIL сцена не собралась")
		quit(1)
		return

	print("── Сборка и раскладка ──")
	await _test_layout(hud, save)
	print("── Итоги забега ──")
	await _test_stats(hud, save)
	print("── Строка рекорда ──")
	await _test_record(hud, save)
	print("── Полоса опыта ──")
	await _test_xp(hud, save)
	print("── Задания и баланс ──")
	await _test_quests(hud, save)
	print("── Награда за уровень ──")
	await _test_reward(hud, save)

	print("")
	if _fails == 0:
		print("ВСЁ ЗЕЛЁНОЕ")
	else:
		print("ПРОВАЛОВ: ", _fails)
	quit(1 if _fails > 0 else 0)

# ── Хелперы ───────────────────────────────────────────────────────────────────

# Экран смерти кладёт узлы прямо в HUD, поэтому запоминаем, что там было ДО, и
# смотрим только на новое.
var _before_ids : Dictionary = {}

func _open(hud: Node, save: Node, pizzas: int, dollars: int, secs: float,
		best_before: int, xp_before: int, level_before: int,
		rewards: Array = []) -> Array:
	_before_ids.clear()
	for c in hud.get_children():
		_before_ids[c.get_instance_id()] = true
	save.dollars = 12400
	save.skin_xp    = xp_before
	save.skin_level = level_before
	hud.set("_dollars_this_run", dollars)
	hud.set("_elapsed_time", secs)
	hud.set("_go_best_before", best_before)
	hud.call("_show_game_over", pizzas, rewards, xp_before, level_before)
	for _i in 6:
		await process_frame
	var fresh : Array = []
	for c in hud.get_children():
		if not _before_ids.has(c.get_instance_id()):
			fresh.append(c)
	return fresh

func _shut(hud: Node, fresh: Array) -> void:
	get_root().get_tree().paused = false
	for n in fresh:
		if is_instance_valid(n):
			n.free()
	hud.set("_go_overlay", null)
	await process_frame

func _texts(nodes: Array) -> Array:
	var out : Array = []
	for n in nodes:
		_collect(n, out)
	return out

func _collect(node: Node, out: Array) -> void:
	if node is Label:
		out.append(String((node as Label).text))
	for c in node.get_children():
		_collect(c, out)

# Точное совпадение подписи. Подстрокой считать нельзя: названия заданий
# пересекаются между собой и с другими подписями экрана, и тест начинает падать
# от того, какие задания сегодня выпали.
func _count_exact(arr: Array, needle: String) -> int:
	var n := 0
	for t in arr:
		if String(t) == needle:
			n += 1
	return n

func _count(arr: Array, needle: String) -> int:
	var n := 0
	for t in arr:
		if String(t).find(needle) >= 0:
			n += 1
	return n

func _btn_by_label(nodes: Array, text: String) -> Button:
	var labels : Array = []
	for n in nodes:
		_collect_labels(n, labels)
	var target := Rect2()
	for l in labels:
		if String((l as Label).text) == text:
			target = Rect2((l as Label).global_position, (l as Label).size)
	if target.size == Vector2.ZERO:
		return null
	for n in nodes:
		if n is Button:
			var r := Rect2((n as Button).global_position, (n as Button).size)
			if r.intersects(target) and absf(r.size.x - target.size.x) < 4.0:
				return n
	return null

func _collect_labels(node: Node, out: Array) -> void:
	if node is Label:
		out.append(node)
	for c in node.get_children():
		_collect_labels(c, out)

# ── Тесты ─────────────────────────────────────────────────────────────────────

func _test_layout(hud: Node, save: Node) -> void:
	var fresh : Array = await _open(hud, save, 411, 86, 134.0, 480, 3200, 4)
	_check(get_root().get_tree().paused, "экран смерти остановил дерево")

	var vp : Vector2 = get_root().get_visible_rect().size
	var lay : Dictionary = hud.get("_go_layout")
	var l : Rect2 = lay["left"]
	var r : Rect2 = lay["right"]
	_check(l.position.x >= 0.0 and r.end.x <= vp.x and r.end.y <= vp.y,
		"колонки внутри экрана: %.0f … %.0f" % [l.position.x, r.end.x])
	_check(l.end.x <= r.position.x,
		"колонки не наезжают: %.0f ≤ %.0f" % [l.end.x, r.position.x])

	# «ЕЩЁ РАЗ» — то, чего мы хотим от игрока; выход не должен выглядеть равным.
	var again : Button = _btn_by_label(fresh, "ЕЩЁ РАЗ")
	var quit_b : Button = _btn_by_label(fresh, "ВЫХОД")
	_check(again != null and quit_b != null, "обе кнопки нашлись")
	if again != null and quit_b != null:
		_check(again.size.x > quit_b.size.x * 1.5,
			"«ЕЩЁ РАЗ» заметно шире выхода: %.0f и %.0f" % [again.size.x, quit_b.size.x])
	await _shut(hud, fresh)

func _test_stats(hud: Node, save: Node) -> void:
	var fresh : Array = await _open(hud, save, 411, 86, 134.0, 480, 3200, 4)
	var txt : Array = _texts(fresh)
	_check(_count(txt, "411") >= 1, "пиццы забега показаны: %s" % [txt])
	_check(_count(txt, "+ 86") == 1, "доллары забега показаны")
	_check(_count(txt, "2:14") == 1, "время забега показано")
	_check(_count(txt, "МОЙ БАЛАНС") == 1, "баланс на месте")
	await _shut(hud, fresh)

# Главный крючок экрана: три случая, и ни в одном строка не должна врать.
func _test_record(hud: Node, save: Node) -> void:
	var fresh : Array = await _open(hud, save, 411, 0, 60.0, 480, 3200, 4)
	_check(_count(_texts(fresh), "ДО РЕКОРДА НЕ ХВАТИЛО 69") == 1,
		"не добрал: сказано, сколько не хватило: %s" % [_texts(fresh)])
	await _shut(hud, fresh)

	fresh = await _open(hud, save, 520, 0, 60.0, 480, 3200, 4)
	_check(_count(_texts(fresh), "НОВЫЙ РЕКОРД") == 1,
		"побил: сказано про новый рекорд")
	await _shut(hud, fresh)

	fresh = await _open(hud, save, 120, 0, 60.0, 0, 3200, 4)
	var t : Array = _texts(fresh)
	_check(_count(t, "ПЕРВЫЙ ЗАБЕГ") == 1, "первый забег назван первым")
	_check(_count(t, "НОВЫЙ РЕКОРД") == 0,
		"и не выдаётся за новый рекорд: %s" % [t])
	await _shut(hud, fresh)

func _test_xp(hud: Node, save: Node) -> void:
	# Рассинхрон уровня и опыта (дев-сброс, правка сейва) не должен печатать
	# отрицательный остаток — раньше на экране висело «-6789 / 8400 XP».
	var bad : Array = []
	for pair in [[3200, 4], [0, 1], [0, 10], [999999, 10], [50, 3]]:
		var fresh : Array = await _open(hud, save, 100, 0, 30.0, 0,
			int(pair[0]), int(pair[1]))
		for t in _texts(fresh):
			if String(t).find("XP") >= 0 and String(t).begins_with("-"):
				bad.append("xp=%s lv=%s → %s" % [pair[0], pair[1], t])
		await _shut(hud, fresh)
	_check(bad.is_empty(), "остаток опыта никогда не отрицательный: %s" % [bad])

	var fresh2 : Array = await _open(hud, save, 100, 0, 30.0, 0, 3200, 4)
	_check(_count(_texts(fresh2), "XP") >= 1, "остаток опыта показан числом")
	_check(_count(_texts(fresh2), "ур.4") == 1 and _count(_texts(fresh2), "ур.5") == 1,
		"метки уровней у полосы на месте")
	await _shut(hud, fresh2)

func _test_quests(hud: Node, save: Node) -> void:
	var qm : Node = get_root().get_node_or_null("QuestManager")
	var fresh : Array = await _open(hud, save, 411, 86, 134.0, 480, 3200, 4)
	var txt : Array = _texts(fresh)
	var missing : Array = []
	for slot in qm.daily_quests.size():
		if bool(qm.call("is_slot_on_cooldown", slot)):
			continue
		var def : Dictionary = qm.call("_daily_def", slot)
		if _count_exact(txt, String(def.get("title", ""))) != 1:
			missing.append(def.get("title", ""))
	_check(missing.is_empty(), "задания дня перечислены: нет %s" % [missing])
	_check(_count(txt, "ЗАДАНИЯ ДНЯ") == 1, "заголовок блока заданий на месте")
	await _shut(hud, fresh)

func _test_reward(hud: Node, save: Node) -> void:
	var fresh : Array = await _open(hud, save, 411, 86, 134.0, 480, 3200, 4,
		[{"level": 5, "dollars": 500, "tokens": 1}])
	var txt : Array = _texts(fresh)
	_check(_count(txt, "УРОВЕНЬ 5") == 1, "новый уровень назван: %s" % [txt])
	_check(_count(txt, "+500 $") == 1 and _count(txt, "+1 жетон") == 1,
		"награда за уровень показана")
	await _shut(hud, fresh)

	# Без наград строка не выдумывается.
	var fresh2 : Array = await _open(hud, save, 411, 86, 134.0, 480, 3200, 4)
	_check(_count(_texts(fresh2), "УРОВЕНЬ") == 0,
		"без повышения про уровень молчим: %s" % [_texts(fresh2)])
	await _shut(hud, fresh2)
