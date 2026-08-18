extends SceneTree

# Headless-проверка экрана заданий.
#   godot --headless --path . --script res://dev/smoke_quests.gd
#
# Экран собирается кодом целиком, поэтому ломается он молча: раскладка уезжает,
# карточка вылезает за экран, кнопка начисляет награду дважды — и всё это видно
# только глазами. Здесь проверяется то, что глазами как раз не видно.

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
	if hud == null or qm == null:
		print("  FAIL сцена не собралась")
		quit(1)
		return

	print("── Прогресс заданий ──")
	_test_progress(qm)
	print("── Раскладка ──")
	await _test_layout(hud, qm)
	print("── Состояния карточки ──")
	await _test_states(hud, qm)
	print("── Получение награды ──")
	await _test_claim(hud, qm, save)
	print("── Бонус за вход ──")
	await _test_bonus(hud, qm, save)
	print("── Закрытие ──")
	await _test_close(hud)

	print("")
	if _fails == 0:
		print("ВСЁ ЗЕЛЁНОЕ")
	else:
		print("ПРОВАЛОВ: ", _fails)
	quit(1 if _fails > 0 else 0)

# ── Хелперы ───────────────────────────────────────────────────────────────────

func _open(hud: Node) -> Node:
	var scr : Node = load("res://scripts/quests_screen.gd").new()
	scr.call("setup", hud)
	hud.add_child(scr)
	for _i in 4:
		await process_frame
	return scr

func _close(scr: Node) -> void:
	if is_instance_valid(scr):
		scr.free()
	await process_frame

# Все подписи в поддереве — по ним проверяется, что состояние названо СЛОВОМ, а
# не передано одним лишь цветом.
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

func _rects(node: Node, out: Array) -> Array:
	if node is Control and (node is Panel or node is ColorRect):
		var c := node as Control
		out.append(Rect2(c.global_position, c.size))
	for ch in node.get_children():
		_rects(ch, out)
	return out

func _set_state(qm: Node, states: Array) -> void:
	qm.reroll_daily_quests()
	var q : Array = qm.get("daily_quests")
	for i in mini(states.size(), q.size()):
		match String(states[i]):
			"ready":
				q[i]["completed"] = true
				q[i]["claimed"]   = false
			"claimed":
				q[i]["completed"] = true
				q[i]["claimed"]   = true
				q[i]["claimed_at"] = int(Time.get_unix_time_from_system())
			_:
				q[i]["completed"] = false
				q[i]["claimed"]   = false

# ── Тесты ─────────────────────────────────────────────────────────────────────

# Числовой прогресс появился ради полосы на карточке. Разбор условия там свой,
# и достаточно одной опечатки в ключе, чтобы полоса у целой пачки заданий
# навсегда застряла на нуле. Прогоняем ВСЕ задания из всех трёх пулов.
func _test_progress(qm: Node) -> void:
	var bad : Array = []
	var q : Array = qm.get("daily_quests")
	for pool_name in ["DAILY_EASY", "DAILY_MEDIUM", "DAILY_HARD"]:
		var pool : Array = qm.get(pool_name)
		for idx in pool.size():
			q[0]["tier"]      = "easy" if pool_name == "DAILY_EASY" else ("medium" if pool_name == "DAILY_MEDIUM" else "hard")
			q[0]["idx"]       = idx
			q[0]["completed"] = false
			var pr : Vector2i = qm.daily_progress(0)
			if pr.y <= 0 or pr.x < 0 or pr.x > pr.y:
				bad.append("%s[%d] → %s" % [pool_name, idx, pr])
			if String(qm.daily_progress_text(0)) == "":
				bad.append("%s[%d] без текста" % [pool_name, idx])
	_check(bad.is_empty(), "прогресс считается у всех заданий всех пулов, сломано: %s" % [bad])

	# Выполненное показываем полным даже там, где промежуточного счётчика нет.
	q[0]["completed"] = true
	var full : Vector2i = qm.daily_progress(0)
	_check(full.x == full.y, "выполненное задание — полоса заполнена: %s" % [full])

# Ради этой раскладки экран и переделывался: три карточки в ряд обязаны влезать
# целиком. Если однажды они снова начнут вылезать за экран или наезжать друг на
# друга, это должно падать тестом, а не обнаруживаться на телефоне.
func _test_layout(hud: Node, qm: Node) -> void:
	_set_state(qm, ["ready", "idle", "idle"])
	var scr : Node = await _open(hud)
	var vp : Vector2 = get_root().get_visible_rect().size

	var cards : Array = scr.get("_cards")
	_check(cards.size() == 3, "на экране три карточки: %d" % cards.size())

	var lay : Dictionary = scr.get("_layout")
	var size : Vector2 = lay["card_size"]
	var boxes : Array = []
	for i in 3:
		boxes.append(Rect2(scr.call("_card_pos", i), size))

	var inside := true
	for b in boxes:
		var r : Rect2 = b
		if r.position.x < 0.0 or r.position.y < 0.0 \
				or r.end.x > vp.x + 0.5 or r.end.y > vp.y + 0.5:
			inside = false
	_check(inside, "все карточки целиком на экране %dx%d" % [int(vp.x), int(vp.y)])

	var overlap := false
	for i in 3:
		for j in range(i + 1, 3):
			if (boxes[i] as Rect2).intersects(boxes[j] as Rect2):
				overlap = true
	_check(not overlap, "карточки не наезжают друг на друга")

	var banner := Rect2(lay["banner_pos"], lay["banner_size"])
	var banner_clean := true
	for b in boxes:
		if banner.intersects(b as Rect2):
			banner_clean = false
	_check(banner_clean, "баннер бонуса не наезжает на карточки")

	# Чип «до сброса» — левее строки ресурсов, иначе налезает на счётчики.
	var reset_lbl : Label = scr.get("_reset_lbl")
	_check(is_instance_valid(reset_lbl) and reset_lbl.text.contains("ДО СБРОСА"),
		"в шапке показано время до сброса: «%s»" % (reset_lbl.text if is_instance_valid(reset_lbl) else "нет"))
	await _close(scr)

# Состояние карточки не должно передаваться одним лишь цветом: в каждой обязано
# найтись слово, называющее состояние, и номер сложности в медальоне.
func _test_states(hud: Node, qm: Node) -> void:
	_set_state(qm, ["ready", "claimed", "idle"])
	var scr : Node = await _open(hud)
	var cards : Array = scr.get("_cards")

	var want : Array = ["ЗАБРАТЬ", "ЗАБРАНО", "ИДЁТ"]
	var got  : Array = []
	for i in 3:
		var t : Array = _texts(cards[i], [])
		var found := ""
		for w in want:
			for line in t:
				if String(line).contains(String(w)):
					found = String(w)
					break
			if found != "":
				break
		got.append(found)
	_check(not got.has(""), "у каждой карточки состояние названо словом: %s" % [got])

	# Номер сложности 1/2/3 — вторая, не цветовая кодировка уровня.
	var nums := true
	for i in 3:
		var t : Array = _texts(cards[i], [])
		if not (t.has("1") or t.has("2") or t.has("3")):
			nums = false
	_check(nums, "в каждой карточке есть номер сложности")

	# Забранная карточка показывает таймер до нового задания.
	var cd : Array = scr.get("_cd_timer_lbls")
	_check(is_instance_valid(cd[1]) and String(cd[1].text).length() == 8,
		"у забранного слота тикает таймер: «%s»" % (cd[1].text if is_instance_valid(cd[1]) else "нет"))
	await _close(scr)

# Кнопка обязана начислить ровно один раз. Тап проходит через настоящий Button,
# а не через прямой вызов обработчика: иначе тест разойдётся с игрой при первой
# же правке проводки сигналов.
func _test_claim(hud: Node, qm: Node, save: Node) -> void:
	_set_state(qm, ["ready", "idle", "idle"])
	qm.set("daily_bonus_avail", false)   # баннер проверяем отдельно
	var scr : Node = await _open(hud)
	var cards : Array = scr.get("_cards")
	var def : Dictionary = qm._daily_def(0)
	var reward_d : int = int(def.get("reward_d", 0))
	var reward_t : int = int(def.get("reward_t", 0))
	var d0 : int = int(save.get("dollars"))
	var t0 : int = int(save.get("tokens"))

	var btns : Array = _buttons(cards[0], [])
	_check(btns.size() == 1, "у готовой карточки ровно одна кнопка: %d" % btns.size())
	if btns.is_empty():
		await _close(scr)
		return
	(btns[0] as Button).emit_signal("pressed")
	# Начисление идёт после перелёта иконок — ждём с запасом.
	for _i in 90:
		await process_frame

	var q : Array = qm.get("daily_quests")
	_check(bool(q[0]["claimed"]), "слот помечен забранным")
	_check(qm.is_slot_on_cooldown(0), "слот ушёл на откат")
	_check(int(save.get("dollars")) == d0 + reward_d and int(save.get("tokens")) == t0 + reward_t,
		"награда начислена ровно один раз: +%d $ +%d жетон" % [reward_d, reward_t])

	# Повторное нажатие по уже отработавшей кнопке ничего не добавляет.
	if is_instance_valid(btns[0]):
		(btns[0] as Button).emit_signal("pressed")
		for _i in 60:
			await process_frame
	_check(int(save.get("dollars")) == d0 + reward_d and int(save.get("tokens")) == t0 + reward_t,
		"повторный тап не начисляет второй раз")
	await _close(scr)

func _test_bonus(hud: Node, qm: Node, save: Node) -> void:
	_set_state(qm, ["idle", "idle", "idle"])
	qm.set("daily_bonus_avail", true)
	var scr : Node = await _open(hud)
	var d0 : int = int(save.get("dollars"))
	var btns : Array = _buttons(scr.get("_bonus_root"), [])
	_check(btns.size() == 1, "у баннера бонуса одна кнопка: %d" % btns.size())
	if not btns.is_empty():
		(btns[0] as Button).emit_signal("pressed")
		for _i in 90:
			await process_frame
	_check(int(save.get("dollars")) == d0 + int(qm.ENTRY_BONUS),
		"бонус за вход начислен: +%d $" % int(qm.ENTRY_BONUS))
	_check(not bool(qm.get("daily_bonus_avail")), "бонус помечен забранным")
	await _close(scr)

# Экран закрывается по кнопке «назад» и освобождается сам. Если он останется в
# дереве, следующее открытие даст два экрана друг поверх друга.
func _test_close(hud: Node) -> void:
	var scr : Node = await _open(hud)
	scr.call("_on_close")
	for _i in 60:
		await process_frame
	_check(not is_instance_valid(scr), "экран освободился после закрытия")
