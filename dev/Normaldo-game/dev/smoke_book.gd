extends SceneTree

# Headless-проверка экрана «Книга учителя».
#   godot --headless --path . --script res://dev/smoke_book.gd
#
# Экран собирается кодом целиком, поэтому ломается молча: страница разворота
# уезжает за край, глава теряет задание, забранное перестаёт отличаться от
# готового. Здесь проверяется ровно то, что глазами на одном кадре не увидеть.
#
# См. /Концепция/Экран книги учителя.md

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
	var qm   : Node = get_root().get_node_or_null("QuestManager")
	if hud == null or qm == null or save == null:
		print("  FAIL сцена не собралась")
		quit(1)
		return

	print("── Раскладка разворота ──")
	await _test_layout(hud, qm)
	print("── Главы ──")
	await _test_chapters(hud, qm)
	print("── Состояния заданий ──")
	await _test_states(hud, qm)
	print("── Общий прогресс ──")
	await _test_overall(hud, qm)
	print("── Бесконечный режим ──")
	await _test_endless(hud, qm)
	print("── Переход по уведомлению ──")
	await _test_focus(hud, qm)
	print("── Получение награды ──")
	await _test_claim(hud, qm, save)
	print("── Каталог: вкладки ──")
	await _test_catalog(hud)
	print("── Закрытие ──")
	await _test_close(hud, qm)

	print("")
	if _fails == 0:
		print("ВСЁ ЗЕЛЁНОЕ")
	else:
		print("ПРОВАЛОВ: ", _fails)
	quit(1 if _fails > 0 else 0)

# ── Каталог: ПРЕДМЕТЫ · ВРАГИ · БОССЫ ────────────────────────────────────────
# Каталог показывает ТОЛЬКО встреченное, и ломается это молча: достаточно
# перепутать «есть в списке» с «встречено», и книга разом выдаст весь бестиарий
# и всех боссов игроку, который прошёл полуровня.
func _test_catalog(hud: Node) -> void:
	var cat : Node = get_root().get_node_or_null("/root/Bestiary")
	var save : Node = get_root().get_node_or_null("SaveData")
	_check(cat != null, "каталог поднялся автолоадом")
	if cat == null:
		return

	# Чистый сейв: не встречено ничего.
	save.set("seen_entries", {})
	var scr : Node = await _open(hud)
	scr.call("_on_tab", cat.S_ENEMY)
	await process_frame
	_check(String(scr.get("_tab")) == cat.S_ENEMY, "вкладка ВРАГИ открылась")

	var rows : Array = scr.call("_cat_entries")
	_check(rows.size() > 8, "в разделе есть записи: %d" % rows.size())
	var texts : Array = _texts(scr.get("_spine_body"), [])
	var named := 0
	for t in texts:
		if String(t) != "???":
			named += 1
	_check(named == 0, "на чистом сейве все записи заперты: названий %d" % named)

	# Страница запертой записи не рассказывает, что это.
	var page : Array = _texts(scr.get("_page_body"), [])
	var leaks : Array = []
	for e in rows:
		for t in page:
			if String(t) == String((e as Dictionary)["text"]):
				leaks.append((e as Dictionary)["id"])
	_check(leaks.is_empty(), "и описание не показано: %s" % [leaks])

	# Встретили — запись открылась.
	var first : Dictionary = rows[0]
	cat.call("mark", String(first["id"]))
	scr.call("_rebuild_content")
	await process_frame
	_check(_texts(scr.get("_spine_body"), []).has(String(first["title"])),
		"встреченная запись названа: %s" % first["title"])
	_check(_texts(scr.get("_page_body"), []).has(String(first["text"])),
		"и у неё есть описание")

	# Вкладок четыре, и переключаются они.
	scr.call("_on_tab", cat.S_BOSS)
	await process_frame
	_check(String(scr.get("_tab")) == cat.S_BOSS, "вкладка БОССЫ открылась")
	_check((scr.call("_cat_entries") as Array).size() >= 3,
		"боссов в каталоге: %d" % (scr.call("_cat_entries") as Array).size())
	scr.call("_on_tab", "")
	await process_frame
	_check(String(scr.get("_tab")) == "", "и обратно к главам")
	_check(scr.get("_sel_chapter") >= 0, "глава при этом выбрана")
	await _close(scr)

# ── Хелперы ───────────────────────────────────────────────────────────────────

# Сюжет вручную: сколько заданий выполнено и сколько из них забрано.
func _set_story(qm: Node, completed: int, claimed: int) -> void:
	var c : Array = []
	var k : Array = []
	for i in qm.STORY_QUESTS.size():
		c.append(i < completed)
		k.append(i < claimed)
	qm.set("story_completed", c)
	qm.set("story_claimed", k)

func _open(hud: Node, focus: int = -1) -> Node:
	var scr : Node = load("res://scripts/achievements_screen.gd").new()
	scr.call("setup", hud, focus)
	hud.add_child(scr)
	for _i in 4:
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

func _buttons(node: Node, out: Array) -> Array:
	if node is Button:
		out.append(node)
	for c in node.get_children():
		_buttons(c, out)
	return out

func _count(arr: Array, needle: String) -> int:
	var n := 0
	for t in arr:
		if String(t).find(needle) >= 0:
			n += 1
	return n

# ── Тесты ─────────────────────────────────────────────────────────────────────

# Ради этой раскладки экран и переделывался: корешок и страница обязаны влезать
# целиком и не наезжать друг на друга.
func _test_layout(hud: Node, qm: Node) -> void:
	_set_story(qm, 3, 2)
	var scr : Node = await _open(hud)
	var vp : Vector2 = get_root().get_visible_rect().size
	var lay : Dictionary = scr.get("_lay")
	var spine : Rect2 = lay["spine"]
	var page  : Rect2 = lay["page"]

	_check(spine.position.x >= 0.0 and spine.end.y <= vp.y,
		"корешок внутри экрана: %s" % [spine])
	_check(page.end.x <= vp.x and page.end.y <= vp.y,
		"страница внутри экрана: %s" % [page])
	_check(spine.end.x <= page.position.x,
		"страницы разворота не наезжают: %.0f ≤ %.0f" % [spine.end.x, page.position.x])
	_check(spine.position.y > 60.0,
		"разворот ниже шапки с ресурсами: y=%.0f" % spine.position.y)

	# Задания главы делят страницу и не вылезают за её нижний край.
	var body : Control = scr.get("_page_body")
	var q_list : Rect2 = lay["q_list"]
	_check(body.custom_minimum_size.y <= q_list.size.y + 1.0,
		"задания главы помещаются без скролла: %.0f ≤ %.0f"
			% [body.custom_minimum_size.y, q_list.size.y])
	var spine_body : Control = scr.get("_spine_body")
	_check(spine_body.custom_minimum_size.y <= float(lay["ch_list"].size.y) + 1.0,
		"главы помещаются без скролла: %.0f ≤ %.0f"
			% [spine_body.custom_minimum_size.y, lay["ch_list"].size.y])
	await _close(scr)

	# Худший случай по высоте: открыт бесконечный режим, видны ВСЕ шесть глав, а
	# в самой длинной главе четыре задания. Если что-то и вылезет — то здесь.
	_set_story(qm, qm.STORY_QUESTS.size(), 3)
	var scr2 : Node = await _open(hud)
	var lay2 : Dictionary = scr2.get("_lay")
	_check((scr2.call("_visible_chapters") as Array).size() == qm.CHAPTERS.size(),
		"в худшем случае видны все главы")
	_check(float(scr2.get("_spine_body").custom_minimum_size.y) <= float(lay2["ch_list"].size.y) + 1.0,
		"шесть глав помещаются в корешок: %.0f ≤ %.0f"
			% [scr2.get("_spine_body").custom_minimum_size.y, lay2["ch_list"].size.y])
	var longest := 0
	for ci in (scr2.call("_visible_chapters") as Array):
		longest = maxi(longest, (scr2.call("_visible_quests", int(ci)) as Array).size())
	var fits := true
	for ci in (scr2.call("_visible_chapters") as Array):
		scr2.call("_on_select_chapter", int(ci))
		await process_frame
		if float(scr2.get("_page_body").custom_minimum_size.y) > float(lay2["q_list"].size.y) + 1.0:
			fits = false
	_check(fits, "задания любой главы (максимум %d) помещаются на страницу" % longest)
	await _close(scr2)

# Главы должны быть перечислены все и ровно по разу, а счётчик — совпадать с
# данными менеджера, а не считаться отдельно и разъезжаться.
func _test_chapters(hud: Node, qm: Node) -> void:
	_set_story(qm, 5, 4)
	var scr : Node = await _open(hud)
	var vis : Array = scr.call("_visible_chapters")
	var spine_txt : Array = _texts(scr.get("_spine_body"), [])

	# Все задания разложены по главам ровно один раз.
	var seen : Dictionary = {}
	var dup := false
	for ci in qm.CHAPTERS.size():
		for qi in (qm.CHAPTERS[ci] as Dictionary)["quests"]:
			if seen.has(int(qi)):
				dup = true
			seen[int(qi)] = ci
	_check(not dup and seen.size() == qm.STORY_QUESTS.size(),
		"каждое задание лежит ровно в одной главе: %d из %d"
			% [seen.size(), qm.STORY_QUESTS.size()])

	var nums_ok := true
	for ci in vis:
		if _count(spine_txt, str(int(ci) + 1)) < 1:
			nums_ok = false
	_check(nums_ok, "номер каждой видимой главы есть в корешке: %s" % [vis])

	var counts_ok := true
	for ci in vis:
		var done : int = scr.call("_chapter_done", int(ci))
		var tot  : int = (scr.call("_visible_quests", int(ci)) as Array).size()
		if _count(spine_txt, "%d/%d" % [done, tot]) < 1:
			counts_ok = false
	_check(counts_ok, "счётчик главы совпадает с данными: %s" % [spine_txt])

	# Переключение главы перерисовывает правую страницу.
	var first : int = int(scr.get("_sel_chapter"))
	var other : int = -1
	for ci in vis:
		if int(ci) != first:
			other = int(ci)
			break
	var before : Array = _texts(scr.get("_page_body"), [])
	scr.call("_on_select_chapter", other)
	await process_frame
	var after : Array = _texts(scr.get("_page_body"), [])
	_check(int(scr.get("_sel_chapter")) == other and before != after,
		"выбор главы перерисовывает страницу: %d → %d" % [first, other])

	# Заголовок страницы — название выбранной главы.
	var head_txt : Array = _texts(scr.get("_page_head"), [])
	var want : String = ((qm.CHAPTERS[other] as Dictionary)["title"] as String).to_upper()
	_check(_count(head_txt, want) == 1, "в шапке страницы название главы: %s" % [head_txt])
	await _close(scr)

# Состояние строки обязано быть названо словом и показано значком, а не одним
# лишь цветом: приглушение — не состояние.
func _test_states(hud: Node, qm: Node) -> void:
	# Глава 1 — три задания: забрано / готово / не выполнено.
	_set_story(qm, 2, 1)
	var scr : Node = await _open(hud)
	scr.call("_on_select_chapter", 0)
	await process_frame
	var txt : Array = _texts(scr.get("_page_body"), [])

	_check(_count(txt, "ЗАБРАНО") == 1, "забранное подписано словом: %s" % [txt])
	_check(_count(txt, "В ПРОЦЕССЕ") == 1, "невыполненное подписано словом: %s" % [txt])
	_check(_count(txt, "ЗАБРАТЬ") == 1, "готовое — кнопка «ЗАБРАТЬ»: %s" % [txt])
	_check(_count(txt, "✓") == 1, "у забранного стоит галочка")

	# Названия и описания всех заданий главы на месте.
	var qs : Array = scr.call("_visible_quests", 0)
	var all_ok := true
	for qi in qs:
		var d : Dictionary = qm.STORY_QUESTS[int(qi)]
		if _count(txt, String(d["title"])) != 1 or _count(txt, String(d["desc"])) != 1:
			all_ok = false
	_check(all_ok, "каждое задание главы названо ровно один раз")

	# Кнопка ровно одна — у готового задания; забранное и невыполненное нажать
	# нельзя, иначе награду можно забрать дважды.
	var btns : Array = _buttons(scr.get("_page_body"), [])
	_check(btns.size() == 1, "кнопка только у готового задания: %d" % btns.size())
	await _close(scr)

	# Всё забрано — ни одной кнопки на странице.
	_set_story(qm, qm.STORY_QUESTS.size(), qm.STORY_QUESTS.size())
	var scr2 : Node = await _open(hud)
	scr2.call("_on_select_chapter", 0)
	await process_frame
	_check(_buttons(scr2.get("_page_body"), []).is_empty(),
		"в пройденной главе нет кнопок получения")
	await _close(scr2)

# Общий прогресс книги — то, ради чего экран открывают повторно.
func _test_overall(hud: Node, qm: Node) -> void:
	_set_story(qm, 6, 4)
	var scr : Node = await _open(hud)
	var pr : Vector2i = scr.call("_overall_progress")
	var txt : Array = _texts(scr.get("_overall_root"), [])
	_check(pr.x == 4, "общий прогресс = числу забранных: %d" % pr.x)
	# В знаменателе именно ВИДИМЫЕ задания: главы про закрытый бесконечный режим
	# скрыты, и считать их в общем прогрессе — обещать книгу, которой не видно.
	var visible_total := 0
	for ci in (scr.call("_visible_chapters") as Array):
		visible_total += (scr.call("_visible_quests", int(ci)) as Array).size()
	_check(pr.y == visible_total and visible_total < qm.STORY_QUESTS.size(),
		"в знаменателе все видимые задания: %d из %d" % [pr.y, qm.STORY_QUESTS.size()])
	_check(_count(txt, "ПРОЙДЕНО %d / %d" % [pr.x, pr.y]) == 1,
		"общий прогресс написан числом: %s" % [txt])

	# Глава с готовой наградой находится сама — экран открывается на ней.
	_check(bool(scr.call("_chapter_has_ready", int(scr.get("_sel_chapter")))),
		"экран открылся на главе с готовой наградой")
	await _close(scr)

# Главы про бесконечный режим до его открытия не показываются: иначе экран
# рассказывает про режим, о котором игрок ещё не знает.
func _test_endless(hud: Node, qm: Node) -> void:
	_set_story(qm, 3, 3)   # босс не побеждён → режим закрыт
	_check(not bool(qm.is_endless_unlocked()), "бесконечный режим закрыт")
	var scr : Node = await _open(hud)
	var vis : Array = scr.call("_visible_chapters")
	var hidden := true
	for ci in vis:
		for qi in (scr.call("_visible_quests", int(ci)) as Array):
			if bool(scr.call("_is_endless_quest", int(qi))):
				hidden = false
	_check(hidden, "заданий закрытого режима на экране нет: главы %s" % [vis])
	await _close(scr)

	_set_story(qm, qm.STORY_QUESTS.size(), 0)
	_check(bool(qm.is_endless_unlocked()), "после победы над боссом режим открыт")
	var scr2 : Node = await _open(hud)
	var vis2 : Array = scr2.call("_visible_chapters")
	_check(vis2.size() == qm.CHAPTERS.size(),
		"с открытым режимом видны все главы: %d" % vis2.size())
	# Награда-режим показана словами, а не суммой.
	var ci_endless : int = scr2.call("_chapter_of", 6)
	scr2.call("_on_select_chapter", ci_endless)
	await process_frame
	_check(_count(_texts(scr2.get("_page_body"), []), "БЕСКОНЕЧНЫЙ") == 1,
		"награда-режим подписана словами")
	await _close(scr2)

# Переход с плашки «награда готова» обязан привести в нужную главу.
func _test_focus(hud: Node, qm: Node) -> void:
	_set_story(qm, qm.STORY_QUESTS.size(), 0)
	var target : int = 9   # глава 3
	var scr : Node = await _open(hud, target)
	var want : int = scr.call("_chapter_of", target)
	_check(int(scr.get("_sel_chapter")) == want,
		"открылась глава задания: %d (ждали %d)" % [scr.get("_sel_chapter"), want])
	_check(want >= 0 and (scr.call("_visible_quests", want) as Array).has(target),
		"задание действительно лежит в этой главе")
	await _close(scr)

# Награду нельзя забрать дважды, и она приходит на счёт.
func _test_claim(hud: Node, qm: Node, save: Node) -> void:
	_set_story(qm, 2, 1)         # задание 1 «Первый укус» готово, +400 $
	save.dollars = 0
	var scr : Node = await _open(hud)
	scr.call("_on_select_chapter", 0)
	await process_frame
	var btns : Array = _buttons(scr.get("_page_body"), [])
	if btns.size() != 1:
		_check(false, "не нашли кнопку получения")
		await _close(scr)
		return
	(btns[0] as Button).emit_signal("pressed")
	(btns[0] as Button).emit_signal("pressed")   # второе нажатие обязано пройти вхолостую
	for _i in 70:
		await process_frame
	_check(bool(qm.story_claimed[1]), "награда забрана")
	_check(int(save.dollars) == 400, "начислено ровно один раз: %d" % save.dollars)

	# Экран пересобрался по сигналу: кнопки больше нет, слово сменилось.
	var txt : Array = _texts(scr.get("_page_body"), [])
	_check(_count(txt, "ЗАБРАТЬ") == 0 and _count(txt, "ЗАБРАНО") == 2,
		"строка перешла в «ЗАБРАНО»: %s" % [txt])
	await _close(scr)

func _test_close(hud: Node, qm: Node) -> void:
	_set_story(qm, 1, 0)
	var scr : Node = await _open(hud)
	scr.call("_on_close")
	for _i in 40:
		await process_frame
	_check(not is_instance_valid(scr), "экран закрылся и освободился")
