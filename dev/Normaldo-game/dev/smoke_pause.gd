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
	print("── Отсчёт возврата ──")
	await _test_countdown(hud)
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
	print("── Усадка переживает уход с экрана ──")
	await _test_press_anim()
	print("── Пульсация ждёт входа в дерево ──")
	await _test_pulse()
	print("── Пауза поверх интерфейса мини-игры ──")
	await _test_pause_above_minigame(hud, game)

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

# «ПРОДОЛЖИТЬ» не возвращает в игру мгновенно: экран паузы уходит сразу, а игра
# ждёт отсчёта 3-2-1. Проверяем ровно этот разрыв — экрана уже нет, паузы ещё
# нет, — потому что сломать его можно молча: достаточно вернуть в pause_screen
# вызов _close_pause_menu, и отсчёт исчезнет, а тест раскладки не заметит.
#
# Время меряется таймером ДЕРЕВА, а не кадрами: кадры в headless идут медленнее
# реального времени, и «полсекунды на цифру» в кадрах не считаются.
func _test_countdown(hud: Node) -> void:
	var scr : Node = await _open(hud)
	scr.call("_on_resume")
	await process_frame
	_check(not is_instance_valid(scr), "экран паузы ушёл сразу")
	_check(bool(hud.call("resume_counting")), "отсчёт пошёл")
	_check(get_root().get_tree().paused, "игра во время отсчёта СТОИТ")

	# Затемнение среднее: сквозь него видно забег. Полное здесь бессмысленно —
	# осматриваться было бы негде.
	var dim : ColorRect = _first_rect(hud.get("_resume_layer"))
	_check(dim != null and dim.color.a > 0.2 and dim.color.a < 0.7,
		"затемнение среднее: a=%.2f" % [dim.color.a if dim != null else -1.0])

	var digits : Array = []
	var t0 : float = Time.get_ticks_msec() / 1000.0
	while bool(hud.call("resume_counting")) and Time.get_ticks_msec() / 1000.0 - t0 < 6.0:
		var lay : Node = hud.get("_resume_layer")
		if is_instance_valid(lay):
			for l in _texts(lay, []):
				if not digits.has(String(l)) and String(l) != "":
					digits.append(String(l))
		await process_frame
	var dt : float = Time.get_ticks_msec() / 1000.0 - t0
	_check(digits == ["3", "2", "1"], "цифры шли 3, 2, 1: %s" % [digits])
	var want : float = float(hud.get("RESUME_DIGIT_T")) * 3.0
	_check(absf(dt - want) < 0.35, "отсчёт занял %.2f с при ожидаемых %.2f" % [dt, want])
	_check(not get_root().get_tree().paused, "после отсчёта игра пошла")
	_check(not bool(hud.call("resume_counting")), "слой отсчёта убран")

	# Свернули окно на середине отсчёта — это снова пауза, а не «доиграл и пустил».
	scr = await _open(hud)
	scr.call("_on_resume")
	await process_frame
	hud.call("_open_pause_menu")
	await process_frame
	_check(not bool(hud.call("resume_counting")), "открытие паузы гасит отсчёт")
	_check(get_root().get_tree().paused, "и оставляет игру на паузе")
	await _shut(hud)

func _first_rect(node: Node) -> ColorRect:
	if node == null:
		return null
	for c in node.get_children():
		if c is ColorRect:
			return c
	return null

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
		if _count_exact(txt, String(def.get("title", ""))) != 1:
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

# Кнопка живёт дольше своего экрана. Сигналы у Godot идут в порядке
# `pressed` → `button_up`, а следом вьюпорт шлёт `mouse_exited`, когда вынимает
# кнопку из дерева — то есть усадка доигрывает УЖЕ ПОСЛЕ того, как обработчик
# увёл игрока с экрана. Выход из забега при этом зовёт reload_current_scene(),
# который вынимает сцену из дерева сразу, а удаляет через кадр: в этом окне узел
# ещё is_instance_valid(), но create_tween() возвращает null, и кнопка выхода
# валилась «Cannot call method 'set_pause_mode' on a null value».
func _test_press_anim() -> void:
	var host := Control.new()
	get_root().add_child(host)
	var visual := Control.new()
	visual.size = Vector2(40, 20)
	host.add_child(visual)
	await process_frame

	UiKit.press_anim(visual, true)
	for _i in 12:
		await process_frame
	_check(visual.scale.x < 0.95, "в дереве усадка анимируется: ×%.2f" % visual.scale.x)

	# Тот самый кадр: узел отцеплен, но ещё жив.
	host.remove_child(visual)
	_check(is_instance_valid(visual) and not visual.is_inside_tree(),
		"узел вне дерева, но валиден — is_instance_valid() тут не защита")
	UiKit.press_anim(visual, false)
	_check(is_equal_approx(visual.scale.x, 1.0),
		"вне дерева масштаб возвращается напрямую: ×%.2f" % visual.scale.x)

	visual.free()
	host.free()
	await process_frame


# Второй кирпич того же семейства. Экраны собирают карточки ОТЦЕПЛЕННЫМИ и
# добавляют в дерево потом; `create_tween()` на отцепленном узле в Godot 4.2
# возвращает null, и пульсация молча не заводится — экран выглядит собранным,
# просто ничего не двигается. Проверяем контракт, а не версию движка: пока узел
# вне дерева, пульсации нет; попал в дерево — пошла.
func _test_pulse() -> void:
	var host := Control.new()
	var node := Control.new()
	node.modulate = Color(1, 1, 1)
	UiKit.pulse(node, "modulate", Color(1.4, 1.4, 1.4), Color(1, 1, 1), 0.2)
	for _i in 12:
		await process_frame
	_check(is_equal_approx(node.modulate.r, 1.0),
		"вне дерева пульсация не запускается: %.3f" % node.modulate.r)

	get_root().add_child(host)
	host.add_child(node)
	var seen : Array = []
	for _i in 30:
		await process_frame
		seen.append(node.modulate.r)
	_check(seen.max() - seen.min() > 0.01,
		"попал в дерево — пульсация пошла: размах %.3f" % (seen.max() - seen.min()))
	host.free()
	await process_frame


# «ТАПАЙ» из мини-игры просвечивал сквозь меню паузы. Причина не в z_index:
# мини-игры рисуют интерфейс в СВОЁМ CanvasLayer (layer = 50), а z_index
# упорядочивает только внутри одного слоя. Пауза обязана лежать слоем выше —
# иначе поверх её кнопок мигает подсказка остановленной игры.
func _test_pause_above_minigame(hud: Node, game: Node) -> void:
	var boss : Node = game.get_node_or_null("FatBoss")
	var scr : Node = await _open(hud)
	var lay : CanvasLayer = (scr as Node).get_parent() as CanvasLayer
	_check(lay != null, "экран паузы лежит в собственном CanvasLayer")
	if lay == null:
		await _shut(hud)
		return

	# Слой мини-игры создаётся вместе с ней — берём из неё же, чтобы проверка не
	# разошлась с кодом, если слой там поменяют.
	boss.call("dev_begin_play", 1.0)
	for _i in 6:
		await process_frame
	var mg : CanvasLayer = boss.get("_ui")
	_check(mg != null, "интерфейс мини-игры нашёлся")
	if mg != null:
		_check(lay.layer > mg.layer,
			"пауза выше мини-игры: %d против %d" % [lay.layer, mg.layer])
	boss.call("_end_minigame")
	for _i in 10:
		await process_frame

	# И настройки — выше паузы, они открываются с неё.
	scr.call("_on_settings")
	for _i in 6:
		await process_frame
	var st : Node = hud.get("_settings_screen")
	if is_instance_valid(st):
		var slay : CanvasLayer = (st as Node).get_parent() as CanvasLayer
		_check(slay != null and slay.layer > lay.layer,
			"настройки выше паузы: %d против %d"
				% [slay.layer if slay != null else -1, lay.layer])
		st.call("_on_close")
		for _i in 40:
			await process_frame
	await _shut(hud)
