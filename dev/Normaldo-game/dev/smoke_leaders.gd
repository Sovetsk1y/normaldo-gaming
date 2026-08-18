extends SceneTree

# Headless-проверка экрана лидеров.
#   godot --headless --path . --script res://dev/smoke_leaders.gd
#
# Экран собирается кодом, данные приходят то с сервера, то из мока, и почти всё
# ломается молча: подиум показывает не тех, список дублирует первую тройку, своя
# позиция врёт. Здесь проверяется ровно это.

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
	var qm   : Node = get_root().get_node_or_null("QuestManager")
	var mock : Node = get_root().get_node_or_null("LeaderboardMock")
	if hud == null or qm == null or mock == null:
		print("  FAIL сцена не собралась")
		quit(1)
		return

	print("── Замок бесконечного режима ──")
	await _test_lock(hud, qm)
	_unlock(qm)
	print("── Подиум и список ──")
	await _test_podium(hud, mock)
	print("── Своя позиция ──")
	await _test_my_strip(hud, mock)
	print("── Вкладки ──")
	await _test_tabs(hud)
	print("── Раскладка ──")
	await _test_layout(hud)
	print("── Закрытие ──")
	await _test_close(hud)

	print("")
	if _fails == 0:
		print("ВСЁ ЗЕЛЁНОЕ")
	else:
		print("ПРОВАЛОВ: ", _fails)
	quit(1 if _fails > 0 else 0)

# ── Хелперы ───────────────────────────────────────────────────────────────────

func _unlock(qm: Node) -> void:
	var done : Array = qm.get("story_completed")
	var idx  : int   = int(qm.ENDLESS_UNLOCK_QUEST_IDX)
	while done.size() <= idx:
		done.append(false)
	done[idx] = true

func _lock(qm: Node) -> void:
	var done : Array = qm.get("story_completed")
	var idx  : int   = int(qm.ENDLESS_UNLOCK_QUEST_IDX)
	if done.size() > idx:
		done[idx] = false

func _open(hud: Node, metric: int = 0) -> Node:
	var scr : Node = load("res://scripts/leaderboard_screen.gd").new()
	scr.call("setup", hud, metric)
	hud.add_child(scr)
	for _i in 30:
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

# ── Тесты ─────────────────────────────────────────────────────────────────────

# Таблица открывается только после бесконечного режима. Если замок однажды
# отвалится, игрок увидит чужие рекорды до того, как ему дадут в них попасть.
func _test_lock(hud: Node, qm: Node) -> void:
	_lock(qm)
	var scr : Node = await _open(hud)
	_check(is_instance_valid(scr.get("_lock_overlay")), "на закрытой таблице лежит замок")
	await _close(scr)

	_unlock(qm)
	var scr2 : Node = await _open(hud)
	_check(not is_instance_valid(scr2.get("_lock_overlay")),
		"после открытия бесконечного режима замка нет")
	await _close(scr2)

# Первая тройка живёт на подиуме и НЕ дублируется в списке — иначе она занимает
# место дважды на экране, где каждая строка на счету.
func _test_podium(hud: Node, mock: Node) -> void:
	var scr : Node = await _open(hud, 0)
	var podium : Array = scr.get("_podium_ranks")
	var list   : Array = scr.get("_list_ranks")
	_check(podium == [1, 2, 3], "на подиуме ровно первая тройка: %s" % [podium])

	var dup := false
	for r in list:
		if int(r) <= 3:
			dup = true
	_check(not dup, "в списке нет мест из тройки")
	_check(list.size() > 0 and int(list[0]) == 4, "список начинается с 4-го места: %s" % [list[0] if list.size() > 0 else -1])

	# Место названо ЦИФРОЙ, а не только цветом рамки медальона.
	var t : Array = _texts(scr.get("_podium_root"), [])
	_check(t.has("1") and t.has("2") and t.has("3"),
		"на карточках подиума стоят номера мест")

	# Имена на подиуме — те же, что у первых трёх строк источника данных.
	var top : Array = mock.get_top_n(0, 3)
	var names_ok := true
	for r in top:
		if not t.has(String(r.get("name", ""))):
			names_ok = false
	_check(names_ok, "на подиуме те же игроки, что и в данных")
	await _close(scr)

# Своя позиция видна всегда и обязана совпадать с данными. Отдельно ловим старую
# ошибку: в демо-режиме экран писал «101 место», хотя мок говорит 47-е.
func _test_my_strip(hud: Node, mock: Node) -> void:
	for metric in [0, 1]:
		var scr : Node = await _open(hud, metric)
		var lbl : Label = scr.get("_my_strip_lbl")
		_check(is_instance_valid(lbl) and lbl.text != "",
			"метрика %d: своя строка на экране: «%s»" % [metric, lbl.text if is_instance_valid(lbl) else "нет"])
		var want : int = int(mock.get_player_rank(metric))
		_check(is_instance_valid(lbl) and lbl.text.begins_with("%d место" % want),
			"метрика %d: показано место %d, как в данных" % [metric, want])
		await _close(scr)

func _test_tabs(hud: Node) -> void:
	var scr : Node = await _open(hud, 0)
	var first : Array = (scr.get("_podium_ranks") as Array).duplicate()
	var names_before : Array = _texts(scr.get("_podium_root"), [])
	scr.call("_on_tab_total")
	for _i in 20:
		await process_frame
	_check(int(scr.get("_active_metric")) == 1, "вкладка переключилась на «гора пицц»")
	var names_after : Array = _texts(scr.get("_podium_root"), [])
	_check(names_before != names_after, "подиум перестроился под другую метрику")
	_check((scr.get("_podium_ranks") as Array) == first,
		"на другой вкладке подиум это снова места 1–3")
	await _close(scr)

# Подиум, список и своя строка не должны наезжать друг на друга и обязаны
# помещаться на экран — раскладка считается одной функцией, и проверять её
# глазами на каждом разрешении невозможно.
func _test_layout(hud: Node) -> void:
	var scr : Node = await _open(hud, 0)
	var vp : Vector2 = get_root().get_visible_rect().size
	var lay : Dictionary = scr.call("_layout", vp)

	var podium := Rect2(0.0, float(lay["podium_y"]), vp.x, float(lay["podium_h"]))
	var list   := Rect2(float(lay["margin"]), float(lay["list_y"]),
		vp.x - float(lay["margin"]) * 2.0, float(lay["list_h"]))
	var strip  := Rect2(float(lay["margin"]), float(lay["strip_y"]),
		vp.x - float(lay["margin"]) * 2.0, float(lay["strip_h"]))

	_check(not podium.intersects(list), "подиум не наезжает на список")
	_check(not list.intersects(strip), "список не наезжает на свою строку")
	_check(list.size.y > 60.0, "списку осталось %.0f px высоты" % list.size.y)
	_check(strip.end.y <= vp.y + 0.5 and podium.position.y >= 0.0,
		"всё помещается по высоте экрана %d" % int(vp.y))

	var scroll : ScrollContainer = scr.get("_scroll")
	_check(is_instance_valid(scroll) and is_equal_approx(scroll.size.y, list.size.y),
		"область прокрутки совпадает с панелью списка")
	await _close(scr)

func _test_close(hud: Node) -> void:
	var scr : Node = await _open(hud)
	scr.call("_on_close")
	for _i in 60:
		await process_frame
	_check(not is_instance_valid(scr), "экран освободился после закрытия")
