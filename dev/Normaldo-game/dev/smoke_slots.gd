extends SceneTree

# Headless-проверка экрана автоматов.
#   godot --headless --path . --script res://dev/smoke_slots.gd
#
# Экран собирается кодом, а платит валютой — ломается молча и дорого: барабан
# встаёт на соседний символ, приз начисляется дважды, спин крутится без жетона.
# Здесь проверяется ровно это.
#
# См. /Концепция/Экран автоматов.md

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
	print("── Таблица призов ──")
	await _test_paytable(hud, save)
	print("── Кнопка спина ──")
	await _test_spin_button(hud, save)
	print("── Спин ──")
	await _test_spin(hud, save)
	print("── Начисление приза ──")
	await _test_payout(hud, save)
	print("── Закрытие с открытым окном ──")
	await _test_close_with_popup(hud, save)

	print("")
	if _fails == 0:
		print("ВСЁ ЗЕЛЁНОЕ")
	else:
		print("ПРОВАЛОВ: ", _fails)
	quit(1 if _fails > 0 else 0)

# ── Хелперы ───────────────────────────────────────────────────────────────────

func _open(hud: Node, save: Node, tokens: int = 10) -> Node:
	save.tokens  = tokens
	save.dollars = 0
	var scr : Node = load("res://scripts/slots_screen.gd").new()
	scr.call("setup", hud)
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

# Барабаны крутятся на таймерах — ждём кадрами, пока экран не скажет «встало».
func _await_spin(scr: Node, frames: int = 4000) -> bool:
	for _i in frames:
		if not bool(scr.get("_spinning")):
			return true
		await process_frame
	return false

# ── Тесты ─────────────────────────────────────────────────────────────────────

func _test_layout(hud: Node, save: Node) -> void:
	var scr : Node = await _open(hud, save)
	var vp : Vector2 = get_root().get_visible_rect().size
	var lay : Dictionary = scr.get("_lay")
	var skin : Rect2 = lay["skin"]
	var mach : Rect2 = lay["mach"]
	var pay  : Rect2 = lay["pay"]

	_check(skin.position.x >= 0.0 and pay.end.x <= vp.x and mach.end.y <= vp.y,
		"колонки внутри экрана: %.0f … %.0f" % [skin.position.x, pay.end.x])
	_check(skin.end.x <= mach.position.x and mach.end.x <= pay.position.x,
		"колонки не наезжают: %.0f ≤ %.0f, %.0f ≤ %.0f"
			% [skin.end.x, mach.position.x, mach.end.x, pay.position.x])
	_check(skin.position.y > 60.0, "колонки ниже шапки: y=%.0f" % skin.position.y)

	# Автоматы — картинка, и окно барабана обязано лечь ровно на тёмный экран
	# кабинета: разъедется — символы поедут по корпусу.
	var reel_w : float = float(scr.get("_reel_w"))
	var sym_h  : float = float(scr.get("_sym_h"))
	var mach_w : float = (mach.size.x - 16.0) / 3.0
	var rel    : Rect2 = scr.get("MACH_SCREEN_REL")
	_check(absf(reel_w - rel.size.x * mach_w) < 0.5,
		"окно барабана шириной с экран кабинета: %.1f ≈ %.1f" % [reel_w, rel.size.x * mach_w])
	_check(absf(sym_h - rel.size.y * mach_w * (454.0 / 241.0)) < 0.5,
		"и высотой с него же: %.1f" % sym_h)
	_check(mach_w * 3.0 <= mach.size.x,
		"три кабинета помещаются в колонку: %.0f ≤ %.0f" % [mach_w * 3.0, mach.size.x])
	# Регрессия по размеру: до переделки барабан был 80×70, меньше делать нельзя.
	_check(reel_w >= 74.0 and sym_h >= 70.0,
		"барабан не мельче прежнего: %.0f×%.0f" % [reel_w, sym_h])

	# Кабинет обрезан снизу, но экран и маркиза обязаны остаться в кадре.
	var cut : float = float(scr.get("MACH_CUT"))
	_check(cut > rel.position.y + rel.size.y,
		"обрезка кабинета не задевает экран: %.2f > %.2f" % [cut, rel.position.y + rel.size.y])

	# На входе не должно выглядеть, будто только что выпал выигрыш.
	var faces : Array = []
	for i in 3:
		faces.append(String(scr.call("visible_face", i)))
	_check(faces[0] != faces[1] or faces[1] != faces[2],
		"стартовые символы разные: %s" % [faces])
	await _close(scr)

func _test_paytable(hud: Node, save: Node) -> void:
	var scr : Node = await _open(hud, save)
	var txt : Array = _texts(scr.get("_slide_root"), [])

	# Каждый приз из таблицы назван ровно один раз.
	var missing : Array = []
	var dupes   : Array = []
	var prizes : Dictionary = scr.get("PRIZES")
	for sym in prizes.keys():
		for p in (prizes[sym] as Array):
			var n := _count(txt, String(p["label"]))
			if n == 0:
				missing.append(p["label"])
			elif n > 1:
				dupes.append("%s ×%d" % [p["label"], n])
	_check(missing.is_empty(), "все призы перечислены, нет: %s" % [missing])
	_check(dupes.is_empty(), "ни один приз не задвоен: %s" % [dupes])

	# Группы подписаны — раньше о том, что значки это число совпавших барабанов,
	# нигде не говорилось.
	for cap in ["ДЖЕКПОТ", "ТРИ В РЯД", "ДВА В РЯД", "ОДИН"]:
		_check(_count(txt, cap) >= 1, "в таблице есть группа «%s»" % cap)

	# Таблица помещается целиком: ничего важного за краем панели.
	var pay : Rect2 = (scr.get("_lay") as Dictionary)["pay"]
	var overflow : Array = []
	_collect_overflow(scr.get("_slide_root"), pay, overflow)
	_check(overflow.is_empty(), "таблица не вылезает за панель: %s" % [overflow])
	await _close(scr)

# Подписи правой колонки не должны выходить за нижний край её панели. Считаем в
# координатах `_slide_root`, а не в глобальных: на въезде он ещё едет снизу, и
# global_position врёт на высоту экрана.
func _collect_overflow(node: Node, pay: Rect2, out: Array) -> void:
	for ch in node.get_children():
		if ch is Label:
			var c := ch as Label
			var r := Rect2(c.position, c.size)
			if r.position.x >= pay.position.x and r.position.y >= pay.position.y \
					and r.end.y > pay.end.y + 1.0:
				out.append("%s y=%.1f h=%.1f" % [c.text, r.position.y, c.size.y])

func _test_spin_button(hud: Node, save: Node) -> void:
	var scr : Node = await _open(hud, save, 3)
	var lbl : Label = scr.get("_spin_lbl")
	_check(String(lbl.text).find("КРУТИТЬ") >= 0,
		"с жетонами на кнопке «КРУТИТЬ»: %s" % lbl.text)

	# Состояние словом, а не одной яркостью.
	save.tokens = 0
	save.data_changed.emit()
	await process_frame
	_check(String(lbl.text) == "НЕТ ЖЕТОНОВ",
		"без жетонов на кнопке «НЕТ ЖЕТОНОВ»: %s" % lbl.text)

	# И без жетонов спин не крутится и ничего не списывает.
	scr.call("_on_spin_pressed")
	for _i in 10:
		await process_frame
	_check(not bool(scr.get("_spinning")) and int(save.tokens) == 0,
		"без жетонов спина нет, жетонов: %d" % save.tokens)
	await _close(scr)

func _test_spin(hud: Node, save: Node) -> void:
	var scr : Node = await _open(hud, save, 5)
	scr.call("_on_spin_pressed")
	_check(int(save.tokens) == 4, "спин стоит ровно один жетон: %d" % save.tokens)
	_check(bool(scr.get("_spinning")), "барабаны закрутились")

	var done : bool = await _await_spin(scr)
	_check(done, "барабаны остановились")
	if not done:
		await _close(scr)
		return

	# Главное: в окне видно ИМЕННО выпавшую комбинацию. Между намерением
	# `_reel_target` и тем, что реально в окне, и живёт ошибка на один символ.
	var res : Dictionary = scr.get("_last_result")
	var sym : String = String(res.get("sym", ""))
	var want : int = int(res.get("count", 0))
	var got := 0
	var faces : Array = []
	for i in 3:
		var f : String = String(scr.call("visible_face", i))
		faces.append(f)
		if f == sym:
			got += 1
	_check(got == want, "в окнах ровно выпавшая комбинация: %s ждали %d×%s, видно %s"
		% [faces, want, sym, got])

	# Строка результата и лента — то, что остаётся после закрытия окна выигрыша.
	var line : String = String((scr.get("_result_lbl") as Label).text)
	var prize : Dictionary = scr.call("_get_prize", res)
	_check(line.find(String(prize.label)) >= 0,
		"строка результата назвала приз: «%s»" % line)
	_check((scr.get("_history") as Array).size() == 1,
		"спин попал в ленту последних")
	await _close(scr)

	# Лента не растёт бесконечно.
	var scr2 : Node = await _open(hud, save, 9)
	for _s in 5:
		scr2.call("_on_spin_pressed")
		if not await _await_spin(scr2):
			break
		# Окно выигрыша перехватывает следующий спин — закрываем его сразу.
		var pop = scr2.get("_win_popup")
		if pop != null and is_instance_valid(pop):
			pop.queue_free()
			scr2.set("_win_popup", null)
		await process_frame
	var hist : Array = scr2.get("_history")
	_check(hist.size() <= int(scr2.get("HISTORY_MAX")),
		"лента не длиннее %d: %d" % [scr2.get("HISTORY_MAX"), hist.size()])
	await _close(scr2)

# Приз обязан начислиться ровно один раз — это живые деньги игрока.
func _test_payout(hud: Node, save: Node) -> void:
	var scr : Node = await _open(hud, save, 3)
	save.dollars = 0
	var res := {"sym": "dollar", "count": 3}
	scr.set("_last_result", res)
	scr.call("_show_win_popup", res)
	await process_frame
	scr.call("_apply_win", res)
	for _i in 120:
		await process_frame
	_check(int(save.dollars) == 1000, "приз начислен: %d" % save.dollars)

	# Повторный вызов не должен доплатить ещё раз при закрытии экрана.
	scr.set("_win_popup", null)
	scr.call("_on_close")
	for _i in 60:
		await process_frame
	_check(int(save.dollars) == 1000, "закрытие не доплатило второй раз: %d" % save.dollars)
	if is_instance_valid(scr):
		scr.free()
	await process_frame

# Окно выигрыша открыто, игрок жмёт «назад» — приз всё равно обязан прийти.
func _test_close_with_popup(hud: Node, save: Node) -> void:
	var scr : Node = await _open(hud, save, 3)
	save.tokens  = 3
	save.dollars = 0
	var res := {"sym": "dollar", "count": 3}
	scr.set("_last_result", res)
	scr.set("_win_applied", false)
	scr.call("_show_win_popup", res)
	await process_frame
	scr.call("_on_close")
	for _i in 60:
		await process_frame
	_check(int(save.dollars) == 1000,
		"приз пришёл при закрытии с открытым окном: %d" % save.dollars)
	if is_instance_valid(scr):
		scr.free()
	await process_frame
