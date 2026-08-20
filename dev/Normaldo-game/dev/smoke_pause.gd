extends SceneTree

# Headless-проверка экрана паузы.
#   godot --headless --path . --script res://dev/smoke_pause.gd
#
# Пауза останавливает дерево — и сама обязана в этот момент работать. Классика
# ошибок здесь: кнопки, которые замерли вместе с игрой, и пауза, которая не
# снимается. Плюс цифры забега: если они врут, игрок принимает решение
# «идти дальше или хватит» по неверным данным.
#
# См. /Концепция/Экран паузы.md

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
	var hud      : Node = game.get_node_or_null("HUD")
	var normaldo : Node = game.get_node_or_null("Normaldo")
	var save     : Node = get_root().get_node_or_null("SaveData")
	if hud == null or normaldo == null:
		print("  FAIL сцена не собралась")
		quit(1)
		return

	print("── Открытие и снятие ──")
	await _test_open_close(hud)
	print("── Раскладка ──")
	await _test_layout(hud)
	print("── Цифры забега ──")
	await _test_run_stats(hud, normaldo, save)
	print("── Задания дня ──")
	await _test_quests(hud)
	print("── Выход ──")
	await _test_quit(hud)
	print("── Настройки с паузы ──")
	await _test_settings(hud)

	print("")
	if _fails == 0:
		print("ВСЁ ЗЕЛЁНОЕ")
	else:
		print("ПРОВАЛОВ: ", _fails)
	quit(1 if _fails > 0 else 0)

# ── Хелперы ───────────────────────────────────────────────────────────────────

func _open(hud: Node) -> Node:
	hud.call("_open_pause_menu")
	for _i in 4:
		await process_frame
	return hud.get("_pause_overlay")

func _shut(hud: Node) -> void:
	hud.call("_close_pause_menu")
	for _i in 4:
		await process_frame

func _texts(node: Node, out: Array) -> Array:
	if node is Label:
		out.append(String((node as Label).text))
	for c in node.get_children():
		_texts(c, out)
	return out

func _count(arr: Array, needle: String) -> int:
	var n := 0
	for t in arr:
		if String(t).find(needle) >= 0:
			n += 1
	return n

func _buttons(node: Node, out: Array) -> Array:
	if node is Button:
		out.append(node)
	for c in node.get_children():
		_buttons(c, out)
	return out

func _btn_by_label(scr: Node, text: String) -> Button:
	# Кнопка невидима и лежит рядом с подписью — ищем по совпадению рамки.
	var labels : Array = []
	_collect_labels(scr, labels)
	var target : Rect2 = Rect2()
	for l in labels:
		if String((l as Label).text) == text:
			target = Rect2((l as Label).global_position, (l as Label).size)
	if target.size == Vector2.ZERO:
		return null
	for b in _buttons(scr, []):
		var r := Rect2((b as Button).global_position, (b as Button).size)
		if r.intersects(target) and absf(r.size.x - target.size.x) < 6.0:
			return b
	return null

func _collect_labels(node: Node, out: Array) -> void:
	if node is Label:
		out.append(node)
	for c in node.get_children():
		_collect_labels(c, out)

# ── Тесты ─────────────────────────────────────────────────────────────────────

func _test_open_close(hud: Node) -> void:
	_check(not get_root().get_tree().paused, "до паузы дерево не остановлено")
	var scr : Node = await _open(hud)
	_check(is_instance_valid(scr), "экран паузы создался")
	_check(get_root().get_tree().paused, "пауза остановила дерево")
	# Экран обязан работать при остановленном дереве — иначе его кнопки замрут.
	_check(int((scr as Node).process_mode) == Node.PROCESS_MODE_ALWAYS,
		"экран паузы живёт при остановленном дереве")

	# Повторное нажатие паузы не плодит второй экран.
	hud.call("_open_pause_menu")
	await process_frame
	_check(hud.get("_pause_overlay") == scr, "второй экран не создаётся")

	await _shut(hud)
	_check(not get_root().get_tree().paused, "закрытие сняло паузу")
	_check(not is_instance_valid(scr), "экран освободился")

func _test_layout(hud: Node) -> void:
	var scr : Node = await _open(hud)
	var vp : Vector2 = get_root().get_visible_rect().size
	var lay : Dictionary = scr.get("_lay")
	var l : Rect2 = lay["left"]
	var r : Rect2 = lay["right"]
	_check(l.position.x >= 0.0 and r.end.x <= vp.x and r.end.y <= vp.y,
		"колонки внутри экрана: %.0f … %.0f" % [l.position.x, r.end.x])
	_check(l.end.x <= r.position.x,
		"колонки не наезжают: %.0f ≤ %.0f" % [l.end.x, r.position.x])

	# Продолжить — единственное залитое и самое крупное действие: выход не
	# должен выглядеть равным ему.
	var go   : Button = _btn_by_label(scr, "ПРОДОЛЖИТЬ")
	var quit_b : Button = _btn_by_label(scr, "ВЫХОД")
	_check(go != null and quit_b != null, "обе кнопки нашлись")
	if go != null and quit_b != null:
		_check(go.size.x > quit_b.size.x * 1.5,
			"«ПРОДОЛЖИТЬ» заметно шире выхода: %.0f и %.0f" % [go.size.x, quit_b.size.x])
	await _shut(hud)

func _test_run_stats(hud: Node, normaldo: Node, save: Node) -> void:
	# Забег с конкретными цифрами: пауза обязана показать ИХ, а не нули.
	normaldo.set("_total_pizza_count", 137)
	normaldo.set("_pizza_count", 46)
	normaldo.set("fat_state", 1)
	hud.set("_dollars_this_run", 24)
	hud.set("_elapsed_time", 134.0)
	save.active_skin = "classic"
	var scr : Node = await _open(hud)
	var txt : Array = _texts(scr, [])
	_check(_count(txt, "137") >= 1, "пиццы забега показаны: %s" % [txt])
	_check(_count(txt, "24") >= 1, "доллары забега показаны")
	_check(_count(txt, "2:14") == 1, "время забега показано")
	# Жир — словом И числом, как в самом забеге.
	var names : Array = hud.get("_FAT_NAMES")
	_check(_count(txt, String(names[1])) == 1,
		"состояние жира названо словом «%s»" % names[1])
	# Остаток до следующего жира — числом, ровно тот же расчёт, что в HUD забега.
	var thr : Array = hud.get("FAT_THRESHOLDS")
	var want : String = "%d / %d" % [46 - int(thr[0]), int(thr[1]) - int(thr[0])]
	_check(_count(txt, want) == 1, "остаток до следующего жира числом «%s»: %s" % [want, txt])
	await _shut(hud)

func _test_quests(hud: Node) -> void:
	var qm : Node = get_root().get_node_or_null("QuestManager")
	var scr : Node = await _open(hud)
	var txt : Array = _texts(scr, [])
	var missing : Array = []
	for slot in qm.daily_quests.size():
		var def : Dictionary = qm.call("_daily_def", slot)
		if bool(qm.call("is_slot_on_cooldown", slot)):
			continue
		if _count(txt, String(def.get("title", ""))) != 1:
			missing.append(def.get("title", ""))
	_check(missing.is_empty(), "все задания дня перечислены: нет %s" % [missing])
	_check(_count(txt, "ЗАДАНИЯ ДНЯ") == 1, "заголовок блока заданий на месте")
	await _shut(hud)

func _test_quit(hud: Node) -> void:
	var scr : Node = await _open(hud)
	# «ВЫХОД» обязан спрашивать подтверждение: он стирает весь забег.
	var before : int = _buttons(scr, []).size()
	scr.call("_on_quit")
	await process_frame
	var txt : Array = _texts(scr, [])
	_check(_count(txt, "ВЫЙТИ ИЗ ЗАБЕГА?") == 1, "выход спрашивает подтверждение")
	_check(_count(txt, "ОСТАТЬСЯ") == 1 and _count(txt, "ВЫЙТИ") >= 1,
		"в диалоге есть оба ответа")
	_check(get_root().get_tree().paused, "во время подтверждения игра всё ещё на паузе")

	# Отмена возвращает на паузу, а не в меню и не в игру.
	var layer : Node = null
	for c in scr.get_children():
		if c is Control and (c as Control).z_index == 5:
			layer = c
	_check(layer != null, "слой подтверждения найден")
	if layer != null:
		layer.queue_free()
		for _i in 4:
			await process_frame
	_check(is_instance_valid(scr) and get_root().get_tree().paused,
		"после отмены остались на паузе")
	_check(_buttons(scr, []).size() == before, "кнопки паузы вернулись")
	await _shut(hud)

func _test_settings(hud: Node) -> void:
	var scr : Node = await _open(hud)
	scr.call("_on_settings")
	for _i in 6:
		await process_frame
	var st : Node = hud.get("_settings_screen")
	_check(is_instance_valid(st), "настройки открылись с паузы")
	_check(get_root().get_tree().paused, "игра осталась на паузе")
	if is_instance_valid(st):
		# Настройки обязаны работать при остановленном дереве и лежать ПОВЕРХ паузы.
		_check(int((st as Node).process_mode) == Node.PROCESS_MODE_ALWAYS,
			"экран настроек живёт при остановленном дереве")
		_check(int((st as Node2D).z_index) > int((scr as Control).z_index),
			"настройки лежат поверх паузы: %d > %d"
				% [(st as Node2D).z_index, (scr as Control).z_index])
		st.call("_on_close")
		for _i in 40:
			await process_frame
	_check(get_root().get_tree().paused and is_instance_valid(scr),
		"закрыли настройки — вернулись на паузу")
	await _shut(hud)
