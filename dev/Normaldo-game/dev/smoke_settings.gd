extends SceneTree

# Headless-проверка экрана настроек.
#   godot --headless --path . --script res://dev/smoke_settings.gd
#
# Настройки пишут в SaveData: сломанный переключатель тут не «косметика», а
# выключенный звук, который не выключается, и уведомления, которые продолжают
# приходить. Здесь проверяется, что нажатие доходит до данных и обратно.
#
# См. /Концепция/Экран настроек.md

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

	print("── Раскладка ──")
	await _test_layout(hud, save)
	print("── Разделы ──")
	await _test_sections(hud, save)
	print("── Звук ──")
	await _test_sound(hud, save)
	print("── Уведомления ──")
	await _test_notif(hud, save)
	print("── Профиль и аккаунт ──")
	await _test_profile_account(hud, save)
	print("── Открытие и закрытие ──")
	await _test_open_close(hud)

	print("")
	if _fails == 0:
		print("ВСЁ ЗЕЛЁНОЕ")
	else:
		print("ПРОВАЛОВ: ", _fails)
	quit(1 if _fails > 0 else 0)

# ── Хелперы ───────────────────────────────────────────────────────────────────

func _open(hud: Node, section: String = "sound") -> Node:
	var scr : Node = load("res://scripts/settings_screen.gd").new()
	scr.call("setup", hud, section)
	hud.add_child(scr)
	for _i in 6:
		await process_frame
	return scr

func _close(scr: Node) -> void:
	if is_instance_valid(scr):
		scr.free()
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

func _sliders(node: Node, out: Array) -> Array:
	if node is HSlider:
		out.append(node)
	for c in node.get_children():
		_sliders(c, out)
	return out

# ── Тесты ─────────────────────────────────────────────────────────────────────

func _test_layout(hud: Node, save: Node) -> void:
	var scr : Node = await _open(hud)
	var vp : Vector2 = get_root().get_visible_rect().size
	var lay : Dictionary = scr.get("_lay")
	var spine : Rect2 = lay["spine"]
	var page  : Rect2 = lay["page"]
	_check(spine.position.x >= 0.0 and page.end.x <= vp.x and page.end.y <= vp.y,
		"колонки внутри экрана: %.0f … %.0f" % [spine.position.x, page.end.x])
	_check(spine.end.x <= page.position.x,
		"колонки не наезжают: %.0f ≤ %.0f" % [spine.end.x, page.position.x])
	_check(spine.position.y > 60.0, "разворот ниже шапки: y=%.0f" % spine.position.y)

	# Список разделов помещается в корешок целиком.
	var need : float = float(scr.get("SECTIONS").size()) * (float(scr.get("SEC_ROW_H"))
		+ float(scr.get("SEC_ROW_GAP"))) - float(scr.get("SEC_ROW_GAP"))
	_check(need <= float(lay["sec_list"].size.y) + 1.0,
		"разделы помещаются в корешок: %.0f ≤ %.0f" % [need, lay["sec_list"].size.y])
	await _close(scr)

func _test_sections(hud: Node, save: Node) -> void:
	var scr : Node = await _open(hud)
	# Каждый раздел обязан собрать своё содержимое — и не чужое.
	var marks : Dictionary = {
		"sound":   "Громкость звуков",
		"notif":   "Все уведомления",
		"profile": "ИМЯ В ТАБЛИЦЕ ЛИДЕРОВ",
		"account": "КОД ВОССТАНОВЛЕНИЯ",
	}
	var bad : Array = []
	for s in scr.get("SECTIONS"):
		var key : String = String((s as Dictionary)["key"])
		scr.call("_on_select", key)
		await process_frame
		var txt : Array = _texts(scr.get("_page_body"), [])
		if _count(txt, String(marks[key])) != 1:
			bad.append("%s: не нашли «%s»" % [key, marks[key]])
		# Заголовок страницы совпадает с выбранным разделом.
		var head : Array = _texts(scr.get("_page_head"), [])
		if _count(head, String((s as Dictionary)["title"])) != 1:
			bad.append("%s: заголовок страницы не тот: %s" % [key, head])
		# Чужого содержимого на странице быть не должно.
		for other in marks.keys():
			if String(other) != key and _count(txt, String(marks[other])) > 0:
				bad.append("%s: на странице чужое «%s»" % [key, marks[other]])
	_check(bad.is_empty(), "каждый раздел строит своё содержимое: %s" % [bad])

	# Версия — в корешке, а не в содержимом: место в списке настроек дороже.
	var spine_txt : Array = _texts(scr.get("_slide_root"), [])
	var has_ver := false
	for t in spine_txt:
		if String(t).begins_with("v"):
			has_ver = true
	_check(has_ver, "версия сборки на экране есть")
	await _close(scr)

func _test_sound(hud: Node, save: Node) -> void:
	save.set_sfx_volume(1.0)
	save.set_music_volume(1.0)
	var scr : Node = await _open(hud, "sound")
	var sliders : Array = _sliders(scr.get("_page_body"), [])
	_check(sliders.size() == 2, "два ползунка громкости: %d" % sliders.size())
	if sliders.size() < 2:
		await _close(scr)
		return

	# Ползунок обязан дойти до SaveData, а число на полосе — до игрока.
	(sliders[0] as HSlider).value = 0.4
	await process_frame
	_check(absf(float(save.sfx_volume) - 0.4) < 0.01,
		"звуки записались в сейв: %.2f" % save.sfx_volume)
	_check(_count(_texts(scr.get("_page_body"), []), "40 %") == 1,
		"и показаны числом: %s" % [_texts(scr.get("_page_body"), [])])

	(sliders[1] as HSlider).value = 0.0
	await process_frame
	_check(absf(float(save.music_volume)) < 0.01,
		"музыка выключается в ноль: %.2f" % save.music_volume)
	await _close(scr)
	save.set_sfx_volume(1.0)
	save.set_music_volume(1.0)

func _test_notif(hud: Node, save: Node) -> void:
	save.notif_enabled = true
	for k in save.notif_categories.keys():
		save.notif_categories[k] = true
	var scr : Node = await _open(hud, "notif")
	var txt : Array = _texts(scr.get("_page_body"), [])
	_check(_count(txt, "Все уведомления") == 1, "есть общий выключатель")
	_check(_count(txt, "ТИХИЕ ЧАСЫ") == 1, "тихие часы на той же странице, не за скроллом раздела")
	# Состояние подписано словом, а не только цветом.
	_check(_count(txt, "ВКЛ") >= (scr.get("CAT_ROWS") as Array).size() + 1,
		"каждый переключатель подписан словом: %d" % _count(txt, "ВКЛ"))

	# Категория переключается и переживает пересборку страницы.
	hud.call("_toggle_notif_category", "A")
	scr.call("_build_page")
	await process_frame
	_check(not bool(save.notif_categories.get("A", true)),
		"категория выключилась в сейве")
	_check(_count(_texts(scr.get("_page_body"), []), "ВЫКЛ") == 1,
		"и подписана «ВЫКЛ» ровно одна строка")

	# Общий выключатель выключен — категории гаснут и не нажимаются: щёлкать по
	# ним бессмысленно, а притворяться рабочими значит врать.
	var live_btns : int = _buttons(scr.get("_page_body"), []).size()
	hud.call("_toggle_notif_category", "_master")
	scr.call("_build_page")
	await process_frame
	var dead_btns : int = _buttons(scr.get("_page_body"), []).size()
	_check(not bool(save.notif_enabled), "общий выключатель выключился")
	_check(dead_btns < live_btns,
		"категории перестали нажиматься: было %d кнопок, стало %d" % [live_btns, dead_btns])

	# Тихие часы шагают по кругу.
	save.notif_quiet_start = 23
	scr.call("_build_page")
	await process_frame
	var steppers : Array = []
	for b in _buttons(scr.get("_page_body"), []):
		steppers.append(b)
	_check(steppers.size() >= 5, "шаговые кнопки тихих часов на месте: %d" % steppers.size())
	await _close(scr)
	save.notif_enabled = true
	for k in save.notif_categories.keys():
		save.notif_categories[k] = true

func _test_profile_account(hud: Node, save: Node) -> void:
	save.display_name  = "ТЕСТ-ИМЯ"
	save.recovery_code = "NORM-1111-2222-3333"
	var scr : Node = await _open(hud, "profile")
	var txt : Array = _texts(scr.get("_page_body"), [])
	_check(_count(txt, "ТЕСТ-ИМЯ") == 1, "имя показано в профиле: %s" % [txt])
	_check(_count(txt, "ИЗМЕНИТЬ ИМЯ") == 1, "кнопка смены имени на месте")

	# Имя поменялось снаружи (диалог сохранил) — страница обязана обновиться.
	save.display_name = "ДРУГОЕ-ИМЯ"
	save.data_changed.emit()
	await process_frame
	_check(_count(_texts(scr.get("_page_body"), []), "ДРУГОЕ-ИМЯ") == 1,
		"после сохранения имени страница обновилась")

	scr.call("_on_select", "account")
	await process_frame
	var atxt : Array = _texts(scr.get("_page_body"), [])
	# Код показан ЦЕЛИКОМ: пояснение просит переписать его, а звёздочки не
	# перепишешь.
	_check(_count(atxt, String(save.recovery_code)) == 1,
		"код восстановления показан целиком: %s" % [atxt])
	_check(_count(atxt, "*") == 0, "и не замаскирован звёздочками")
	_check(_count(atxt, "ВОССТАНОВИТЬ АККАУНТ") == 1, "кнопка восстановления на месте")
	await _close(scr)

func _test_open_close(hud: Node) -> void:
	# Экран открывается через тот же вход, что и у игрока, и не двоится.
	hud.call("_show_settings_modal")
	for _i in 6:
		await process_frame
	var scr : Node = hud.get("_settings_screen")
	_check(is_instance_valid(scr), "экран открылся из HUD")
	hud.call("_show_settings_modal")
	await process_frame
	_check(hud.get("_settings_screen") == scr, "повторное открытие не создаёт второй экран")

	scr.call("_on_close")
	for _i in 40:
		await process_frame
	_check(not is_instance_valid(scr), "экран закрылся и освободился")
