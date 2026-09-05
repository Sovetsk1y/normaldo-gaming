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
	var mock : Node = get_root().get_node_or_null("LeaderboardModes")
	if hud == null or qm == null or mock == null:
		print("  FAIL сцена не собралась")
		quit(1)
		return

	print("── Замки на вкладках ──")
	await _test_locks(hud)
	_unlock()
	print("── Подиум и список ──")
	await _test_podium(hud, mock)
	print("── Своя позиция ──")
	await _test_my_strip(hud, mock)
	print("── Вкладки ──")
	await _test_tabs(hud)
	print("── Прыжок к своей строке ──")
	await _test_jump_to_me(hud, mock)
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

# Что открыто, решает ПРОГРЕСС ЭПИЗОДОВ, а не галочка сюжетного задания: три
# пройденных эпизода открывают и третью вкладку, и бесконечный режим.
func _episodes_done(n: int) -> void:
	var save : Node = get_root().get_node_or_null("SaveData")
	if save != null:
		save.set("episodes_done", n)

func _unlock() -> void:
	_episodes_done(3)

func _lock() -> void:
	_episodes_done(0)

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

# Данные подаёт ТЕСТ, а не игра. Своих строк у экрана больше нет и не должно
# быть — выдуманная таблица, неотличимая от настоящей, это ровно то, что мы
# отсюда и убрали. Но проверять подиум, список и прокрутку на чём-то надо,
# поэтому кладём ровно то, что положил бы ответ сервера.
func _feed(scr: Node, metric: int, rank: int, tag: String = "И") -> void:
	var rows : Array = []
	for r in range(1, 61):
		rows.append({
			"rank": r,
			"name": "%s%d" % [tag, r],
			"score": 900 - r * 7,
			"user_id": "u%d" % r,
			"is_player": r == rank,
			"avatar_skin": "classic",
			"avatar_fat": 0,
		})
	(scr.get("_server_rows") as Dictionary)[metric]  = rows
	(scr.get("_server_total") as Dictionary)[metric] = 137
	scr.call("_rebuild_list")

func _texts(node: Node, out: Array) -> Array:
	if node is Label:
		out.append(String((node as Label).text))
	for c in node.get_children():
		_texts(c, out)
	return out

# ── Тесты ─────────────────────────────────────────────────────────────────────

# Вкладка открыта ровно тогда, когда открыт её режим: смотреть чужие рекорды
# там, куда ещё нельзя попасть, — значит видеть спойлер и не мочь на него
# ответить. Раньше на этом стояла модалка на весь экран, и закрыт был лидерборд
# ЦЕЛИКОМ, включая эпизод 1, который открыт всегда.
func _test_locks(hud: Node) -> void:
	_lock()
	var scr : Node = await _open(hud)
	var open_at_zero : Array = []
	for m in 4:
		if bool(scr.call("_is_mode_unlocked", m)):
			open_at_zero.append(m)
	_check(open_at_zero == [0], "без пройденных эпизодов открыт только первый: %s" % [open_at_zero])

	# Нажатие по закрытой вкладке не переключает, а объясняет.
	scr.call("_on_tab", 2)
	await process_frame
	_check(int(scr.get("_active_metric")) == 0, "закрытая вкладка не открывается по нажатию")
	_check(is_instance_valid(scr.get("_toast_node")), "и вместо неё показана подсказка")
	await _close(scr)

	_episodes_done(1)
	var scr2 : Node = await _open(hud)
	var open_at_one : Array = []
	for m in 4:
		if bool(scr2.call("_is_mode_unlocked", m)):
			open_at_one.append(m)
	_check(open_at_one == [0, 1], "пройденный эпизод открывает следующую вкладку: %s" % [open_at_one])
	await _close(scr2)

	_unlock()
	var scr3 : Node = await _open(hud)
	var open_all : Array = []
	for m in 4:
		if bool(scr3.call("_is_mode_unlocked", m)):
			open_all.append(m)
	_check(open_all == [0, 1, 2, 3], "пройденная кампания открывает всё, включая бесконечный: %s"
		% [open_all])
	await _close(scr3)

# Первая тройка живёт на подиуме и НЕ дублируется в списке — иначе она занимает
# место дважды на экране, где каждая строка на счету.
func _test_podium(hud: Node, mock: Node) -> void:
	var scr : Node = await _open(hud, 0)
	_feed(scr, 0, 12)
	await process_frame
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

	# Имена на подиуме — те же, что у первых трёх строк поданных данных.
	var names_ok := t.has("И1") and t.has("И2") and t.has("И3")
	_check(names_ok, "на подиуме те же игроки, что и в данных: %s" % [t])
	await _close(scr)

# Своя позиция видна всегда и обязана совпадать с данными. Отдельно ловим старую
# ошибку: в демо-режиме экран писал «101 место», хотя мок говорит 47-е.
func _test_my_strip(hud: Node, mock: Node) -> void:
	for metric in [0, 3]:
		var scr : Node = await _open(hud, metric)
		var want : int = 12 + metric
		_feed(scr, metric, want)
		await process_frame
		var lbl : Label = scr.get("_my_strip_lbl")
		_check(is_instance_valid(lbl) and lbl.text.begins_with("%d место" % want),
			"метрика %d: показано место %d, как в данных: «%s»"
				% [metric, want, lbl.text if is_instance_valid(lbl) else "нет"])
		await _close(scr)

	# Таблицы нет — и строка об этом ГОВОРИТ, а не показывает выдуманное место.
	var empty : Node = await _open(hud, 0)
	var elbl : Label = empty.get("_my_strip_lbl")
	_check(is_instance_valid(elbl) and not ("место из" in elbl.text),
		"без данных места не выдумывается: «%s»" % [elbl.text if is_instance_valid(elbl) else "нет"])
	await _close(empty)

func _test_tabs(hud: Node) -> void:
	var scr : Node = await _open(hud, 0)
	# Вкладок ровно четыре — три эпизода и бесконечный. «Горы пицц» среди них
	# нет: она мерила усидчивость, а не игру.
	var caps : Array = []
	for l in (scr.get("_tab_lbl") as Array):
		caps.append(String((l as Label).text))
	_check(caps == ["ЭПИЗОД 1", "ЭПИЗОД 2", "ЭПИЗОД 3", "БЕСКОНЕЧНЫЙ"],
		"на полосе четыре вкладки по режимам: %s" % [caps])

	_feed(scr, 0, 12, "А")
	await process_frame
	var first : Array = (scr.get("_podium_ranks") as Array).duplicate()
	var names_before : Array = _texts(scr.get("_podium_root"), [])
	scr.call("_on_tab", 3)
	for _i in 20:
		await process_frame
	_feed(scr, 3, 20, "Б")
	await process_frame
	_check(int(scr.get("_active_metric")) == 3, "вкладка переключилась на бесконечный")
	var names_after : Array = _texts(scr.get("_podium_root"), [])
	_check(names_before != names_after, "подиум перестроился под другой режим")
	_check((scr.get("_podium_ranks") as Array) == first,
		"на другой вкладке подиум это снова места 1–3")
	await _close(scr)

# «ПОКАЗАТЬ В СПИСКЕ» ставит свою строку в СЕРЕДИНУ ОКНА СПИСКА.
#
# Раньше номер строки считался из места: `rank - 1`. Первая тройка уходит на
# подиум, и список начинается с ЧЕТВЁРТОГО места — значит строка стоит на три
# ниже, чем думала формула, и прокрутка промахивалась на 90 px: своя строка
# оказывалась у верхнего края окна, то есть примерно посреди экрана. Мерить это
# глазами нельзя — промах выглядит как «ну, куда-то проскроллило».
func _test_jump_to_me(hud: Node, mock: Node) -> void:
	var scr : Node = await _open(hud, 0)
	var rank : int = 27
	_feed(scr, 0, rank)
	await process_frame
	await scr.call("_on_my_position")
	for _i in 10:
		await process_frame
	var rows_y : Dictionary = scr.get("_list_row_y")
	_check(rows_y.has(rank), "своя строка нашлась в списке: место %d" % rank)
	if not rows_y.has(rank):
		_check(false, "—")
		await _close(scr)
		return
	var scroll : ScrollContainer = scr.get("_scroll")
	# Куда строка встала ВНУТРИ ОКНА: её вертикаль минус прокрутка.
	var in_view : float = float(rows_y[rank]) - float(scroll.scroll_vertical)
	var want    : float = (scroll.size.y - 30.0) * 0.5
	_check(absf(in_view - want) <= 2.0,
		"и встала в середину окна: %.0f при середине %.0f (окно %.0f)"
			% [in_view, want, scroll.size.y])
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
