extends SceneTree

# Headless-проверка экрана лидеров.
#   godot --headless --path . --script res://dev/smoke_leaders.gd
#
# Экран собирается кодом, данные приходят то с сервера, то из мока, и почти всё
# ломается молча: подиум показывает не тех, список дублирует первую тройку, своя
# позиция врёт. Здесь проверяется ровно это.

const SPAWNER_SCRIPT := preload("res://scripts/spawner.gd")

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

# «Всё открыто» — это ВСЯ кампания, а не три эпизода. Длина берётся у таблицы:
# с разбивкой на шесть тройка перестала открывать бесконечный, и три проверки
# упали не на ошибке экрана, а на числе в этом помощнике.
func _unlock() -> void:
	# Длину кампании берём у ТАБЛИЦЫ УРОВНЕЙ, а не у QuestManager: скрипт
	# SceneTree компилируется раньше, чем автозагрузки попадают в область
	# видимости, и по имени менеджер отсюда не достать.
	_episodes_done(SPAWNER_SCRIPT.CAMPAIGN_LEVELS.size())

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
#
# ЛЕСТНИЦА ПРОВЕРЯЕТСЯ ЦЕЛИКОМ, а не в трёх точках. Раньше тут стояло три
# отдельных замера и в каждом `for m in 4` — то есть режимы 0…3. Эпизоды 4 и 5
# получили в enum номера 4 и 5 (ENDLESS вклинился между третьим и четвёртым), и
# обе новые вкладки просто не попадали в проверку. А в игре они при этом
# открывались на эпизод позже, чем надо: замок считался по номеру в enum, а не
# по номеру эпизода. Тест молчал, потому что смотрел не туда.
func _test_locks(hud: Node) -> void:
	var eps : Array = LeaderboardModes.EPISODE_MODE
	# Ожидание СТРОИТСЯ: эпизод N открыт при `episodes_done >= N−1`, бесконечный
	# — после всей кампании. Ни одного номера руками.
	for done in range(0, eps.size() + 1):
		_episodes_done(done)
		var scr : Node = await _open(hud)
		var want : Array = []
		for i in eps.size():
			if done >= i:
				want.append(int(eps[i]))
		if done >= SPAWNER_SCRIPT.CAMPAIGN_LEVELS.size():
			want.append(int(LeaderboardModes.Mode.ENDLESS))
		want.sort()
		var got : Array = []
		for m in LeaderboardModes.MODES:
			if bool(scr.call("_is_mode_unlocked", m)):
				got.append(int(m))
		got.sort()
		_check(got == want, "пройдено %d: открыты %s (ждали %s)" % [done, got, want])
		await _close(scr)

	# Нажатие по закрытой вкладке не переключает, а объясняет.
	_lock()
	var scr0 : Node = await _open(hud, LeaderboardModes.Mode.EP1)
	scr0.call("_on_tab", LeaderboardModes.Mode.EP3)
	await process_frame
	_check(int(scr0.get("_active_metric")) == LeaderboardModes.Mode.EP1,
		"закрытая вкладка не открывается по нажатию")
	_check(is_instance_valid(scr0.get("_toast_node")), "и вместо неё показана подсказка")
	# Подсказка называет ПРЕДЫДУЩИЙ эпизод, а не свой: «сначала пройди эпизод 2»
	# для третьей вкладки. С прежней формулой по номеру enum четвёртая вкладка
	# советовала бы пройти четвёртый эпизод, чтобы открыть четвёртый.
	_check(String(scr0.call("_mode_lock_hint", LeaderboardModes.Mode.EP4)).ends_with("3"),
		"подсказка зовёт на предыдущий эпизод: %s"
		% scr0.call("_mode_lock_hint", LeaderboardModes.Mode.EP4))
	await _close(scr0)

	# ВКЛАДКА ПО УМОЛЧАНИЮ — бесконечный, но он открыт только после всей
	# кампании. Пока она не пройдена, экран обязан открыться на самой дальней
	# доступной вкладке, а не на закрытой: иначе игрок с ходу упирается в
	# таблицу режима, в который ему ещё нельзя.
	for done in range(0, eps.size() + 1):
		_episodes_done(done)
		var scr : Node = await _open(hud, LeaderboardModes.DEFAULT_MODE)
		var at : int = int(scr.get("_active_metric"))
		_check(bool(scr.call("_is_mode_unlocked", at)),
			# Подпись берём КОНСТАНТОЙ, а не `mode_label()`: этот файл —
			# SceneTree-скрипт, он компилируется до того, как автозагрузки
			# войдут в область видимости, и вызов метода у них тут не
			# скомпилируется вовсе (константы и enum — резолвятся статически).
			"пройдено %d: экран открылся на доступной вкладке (%s)"
			% [done, LeaderboardModes.MODE_LABELS[at]])
		if done >= SPAWNER_SCRIPT.CAMPAIGN_LEVELS.size():
			_check(at == LeaderboardModes.DEFAULT_MODE,
				"а пройдя кампанию — сразу на бесконечном")
		await _close(scr)
	_unlock()

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
	# Вкладки — БЕСКОНЕЧНЫЙ ПЕРВЫМ, за ним эпизоды по порядку. Порядок здесь
	# содержательный: бесконечный — главная таблица (недельный сброс, места,
	# призы), эпизоды рядом и без призов. «Горы пицц» среди вкладок нет: она
	# мерила усидчивость, а не игру.
	#
	# Ожидание строится ИЗ СЛОВАРЯ РЕЖИМОВ, а не из списка руками: подписи и
	# порядок уже менялись, и вторая копия расходится с первой молча.
	var caps : Array = []
	for l in (scr.get("_tab_lbl") as Array):
		caps.append(String((l as Label).text))
	# Словарь режимов — автозагрузка, и по имени отсюда её не достать (скрипт
	# SceneTree компилируется раньше). Берём из дерева.
	var lm : Node = get_root().get_node_or_null("LeaderboardModes")
	var want : Array = []
	for m in (lm.get("MODES") as Array):
		want.append(String(lm.call("mode_label", int(m))))
	_check(caps == want, "вкладки по режимам, бесконечный первым: %s" % [caps])
	_check(caps[0] == "БЕСКОНЕЧНЫЙ", "и он же открыт по умолчанию")

	# ЗНАЧОК ЕСТЬ У КАЖДОГО РЕЖИМА. Раньше на вкладке рисовался замок, и рисовался
	# он только у закрытых — то есть отсутствие картинки ничего не значило.
	# Теперь значок несёт опознание режима, и режим без значка — это вкладка,
	# которую не отличить от соседней. Заведут шестой эпизод и забудут испечь
	# иконку — тест скажет; глазами это ловится только на самой дальней вкладке.
	var icons : Array = scr.get("_tab_icons") as Array
	_check(icons.size() == (lm.get("MODES") as Array).size(),
		"значок у каждой вкладки: %d из %d" % [icons.size(), (lm.get("MODES") as Array).size()])
	var no_tex : Array = []
	for ic in icons:
		if (ic as TextureRect).texture == null:
			no_tex.append(ic)
	_check(no_tex.is_empty(), "и у каждого значка есть картинка")
	# Закрытая вкладка отличается ПРИГЛУШЁННЫМ значком — это и есть бывший замок.
	var lock_dim : bool = true
	for i in (lm.get("MODES") as Array).size():
		var m : int = int((lm.get("MODES") as Array)[i])
		var lit : bool = (icons[i] as TextureRect).modulate.a >= 0.99
		if lit != bool(scr.call("_is_mode_unlocked", m)):
			lock_dim = false
	_check(lock_dim, "значок закрытой вкладки приглушён, открытой — в полный цвет")

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
