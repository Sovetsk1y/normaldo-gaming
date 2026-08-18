extends SceneTree

# Headless-проверка карточки скина (экран подробностей).
#   godot --headless --path . --script res://dev/smoke_skin_card.gd
#
# Карточка собирается кодом для 13 скинов в трёх состояниях, и ломается молча:
# колонки наезжают, способности дублируются, закрытый резист выглядит открытым.

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
	var reg  : Node = get_root().get_node_or_null("SkinRegistry")
	if hud == null or save == null:
		print("  FAIL сцена не собралась")
		quit(1)
		return

	print("── Раскладка ──")
	await _test_layout(hud, save, reg)
	print("── Способности ──")
	await _test_abilities(hud, save, reg)
	print("── Прокачка ──")
	await _test_progress(hud, save, reg)
	print("── Состояния кнопки ──")
	await _test_action(hud, save, reg)
	print("── Все скины ──")
	await _test_all_skins(hud, save, reg)

	print("")
	if _fails == 0:
		print("ВСЁ ЗЕЛЁНОЕ")
	else:
		print("ПРОВАЛОВ: ", _fails)
	quit(1 if _fails > 0 else 0)

# ── Хелперы ───────────────────────────────────────────────────────────────────

# Прогресс скинов лежит на диске и переживает прогоны — обнуляем, иначе скин,
# прокачанный прошлым тестом, притворится купленным и десятого уровня.
func _reset(save: Node, owned: Array, active: String, level: int) -> void:
	save.dollars       = 20000
	save.tokens        = 50
	save.skin_progress = {}
	save.owned_skins   = owned
	save.active_skin   = active
	save.skin_level    = level
	save.skin_xp       = 0

func _open(hud: Node, reg: Node, skin_id: String) -> Control:
	var before : Array = hud.get_children()
	hud.call("_show_skin_detail", reg.get_skin(skin_id), true, null, true)
	for _i in 8:
		await process_frame
	for c in hud.get_children():
		if c is Control and not before.has(c):
			return c
	return null

func _close(overlay: Variant) -> void:
	if overlay != null and is_instance_valid(overlay):
		(overlay as Node).free()
	await process_frame

func _texts(node: Node, out: Array) -> Array:
	if node is Label:
		out.append(String((node as Label).text))
	elif node is RichTextLabel:
		out.append(String((node as RichTextLabel).text))
	for c in node.get_children():
		_texts(c, out)
	return out

# Левая колонка — прокрутка, стоящая у левого края тела карточки.
func _left_column(ov: Node, lx: float) -> Node:
	var stack : Array = [ov]
	while not stack.is_empty():
		var n : Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
			if c is ScrollContainer and absf((c as Control).global_position.x - lx) < 24.0:
				return c
	return ov

func _count(list: Array, needle: String) -> int:
	var n := 0
	for t in list:
		if String(t).contains(needle):
			n += 1
	return n

# ── Тесты ─────────────────────────────────────────────────────────────────────

# Три колонки обязаны стоять рядом, не наезжая друг на друга, и помещаться на
# экран целиком — раньше левая обрезала текст по нижней границе панели.
func _test_layout(hud: Node, save: Node, reg: Node) -> void:
	_reset(save, ["classic", "harry_potter"], "harry_potter", 4)
	var ov : Control = await _open(hud, reg, "harry_potter")
	_check(ov != null, "карточка собралась")
	if ov == null:
		return
	var vp : Vector2 = get_root().get_visible_rect().size
	var lay : Dictionary = hud.call("_skin_card_layout", vp)
	var w : float = lay["col_w"]
	var cols : Array = [
		Rect2(float(lay["lx"]), float(lay["body_y"]), w, float(lay["body_h"])),
		Rect2(float(lay["cx"]), float(lay["body_y"]), w, float(lay["body_h"])),
		Rect2(float(lay["rx"]), float(lay["body_y"]), w, float(lay["body_h"])),
	]
	var overlap := false
	for i in 3:
		for j in range(i + 1, 3):
			if (cols[i] as Rect2).intersects(cols[j] as Rect2):
				overlap = true
	_check(not overlap, "колонки не наезжают друг на друга")
	var inside := true
	for c in cols:
		var r : Rect2 = c
		if r.position.x < -0.5 or r.position.y < -0.5 or r.end.x > vp.x + 0.5 or r.end.y > vp.y + 0.5:
			inside = false
	_check(inside, "все три колонки в пределах экрана %dx%d" % [int(vp.x), int(vp.y)])
	_check(float(lay["lx"]) > 4.0 and float(lay["rx"]) + w < vp.x - 4.0,
		"есть поля от краёв экрана")
	await _close(ov)

# Способности показываются РОВНО ОДИН РАЗ. Раньше их рисовали дважды: списком
# слева и рядом кружков по центру, и дубль занимал половину центральной колонки.
func _test_abilities(hud: Node, save: Node, reg: Node) -> void:
	_reset(save, ["classic", "joker"], "joker", 1)
	var ov : Control = await _open(hud, reg, "joker")
	var t : Array = _texts(ov, [])
	_check(_count(t, "СПОСОБНОСТИ") == 1,
		"заголовок «СПОСОБНОСТИ» на экране один: %d" % _count(t, "СПОСОБНОСТИ"))

	# Считаем ТОЛЬКО в левой колонке: справа карточки наград тоже кричат «НОВЫЙ
	# РЕЗИСТ!», и по всему экрану счёт всегда завышен.
	var vp : Vector2 = get_root().get_visible_rect().size
	var lay : Dictionary = hud.call("_skin_card_layout", vp)
	var left : Array = _texts(_left_column(ov, float(lay["lx"])), [])
	var want : int = (hud.call("_ability_items", "joker") as Array).size()
	var got  : int = _count(left, "РЕЗИСТ") + _count(left, "АКТИВНАЯ") + _count(left, "ПАССИВНАЯ")
	_check(got == want, "перечислено %d способностей из %d" % [got, want])

	# У закрытого резиста обязан стоять уровень открытия, а не только замок.
	_check(_count(t, "Откроется на") > 0, "у закрытых резистов написан уровень открытия")
	await _close(ov)

	# Прокачанный скин: часть резистов открыта, и у них виден откат.
	_reset(save, ["classic", "joker"], "joker", 6)
	var ov2 : Control = await _open(hud, reg, "joker")
	var t2 : Array = _texts(ov2, [])
	_check(_count(t2, "Откат") > 0, "у открытых резистов показан откат")
	_check(_count(t2, "Откроется на") > 0, "у ещё закрытых — уровень открытия")
	await _close(ov2)

# Полоса опыта обязана говорить остаток ЧИСЛОМ: без числа она отвечает «скоро».
func _test_progress(hud: Node, save: Node, reg: Node) -> void:
	_reset(save, ["classic", "tyson"], "tyson", 3)
	var ov : Control = await _open(hud, reg, "tyson")
	var t : Array = _texts(ov, [])
	_check(_count(t, "ещё") > 0 and _count(t, "пицц") > 0,
		"показан остаток до следующего уровня числом")
	_check(_count(t, "ур.3") > 0 and _count(t, "ур.4") > 0,
		"подписаны текущий и следующий уровни")
	await _close(ov)

	# У не купленного скина полосы опыта нет — качать нечего.
	_reset(save, ["classic"], "classic", 1)
	var ov2 : Control = await _open(hud, reg, "tyson")
	var t2 : Array = _texts(ov2, [])
	_check(_count(t2, "ещё") == 0, "у не купленного скина полосы опыта нет")
	await _close(ov2)

func _test_action(hud: Node, save: Node, reg: Node) -> void:
	_reset(save, ["classic", "viking"], "viking", 2)
	var ov : Control = await _open(hud, reg, "viking")
	_check(_count(_texts(ov, []), "АКТИВЕН") == 1, "у активного скина кнопка «АКТИВЕН»")
	await _close(ov)

	_reset(save, ["classic", "viking"], "classic", 1)
	var ov2 : Control = await _open(hud, reg, "viking")
	_check(_count(_texts(ov2, []), "НАДЕТЬ") == 1, "у купленного — «НАДЕТЬ»")
	await _close(ov2)

	_reset(save, ["classic"], "classic", 1)
	save.dollars = 10
	var ov3 : Control = await _open(hud, reg, "joker")
	_check(_count(_texts(ov3, []), "НЕТ ДЕНЕГ") == 1, "без денег — «НЕТ ДЕНЕГ»")
	await _close(ov3)

# Карточка обязана собираться для КАЖДОГО скина: у них разные наборы
# способностей, и падает обычно ровно тот, о котором забыли.
func _test_all_skins(hud: Node, save: Node, reg: Node) -> void:
	var bad : Array = []
	for sd in reg.SKINS:
		var id := String(sd["id"])
		_reset(save, ["classic", id], id, 5)
		var ov : Control = await _open(hud, reg, id)
		if ov == null or _texts(ov, []).is_empty():
			bad.append(id)
		await _close(ov)
	_check(bad.is_empty(), "карточка собралась у всех %d скинов, упали: %s" % [reg.SKINS.size(), bad])
