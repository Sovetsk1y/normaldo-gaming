extends SceneTree

# Headless-проверка экрана скинов (сетка магазина).
#   godot --headless --path . --script res://dev/smoke_skins_screen.gd
#
# Экран собирается кодом, и ломается он молча: карточки наезжают друг на друга,
# сетка перестаёт влезать на экран, кнопка покупки списывает деньги дважды.
# Ровно это здесь и проверяется.

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

	print("── Сетка ──")
	await _test_grid(hud, save)
	print("── Состояния карточки ──")
	await _test_states(hud, save)
	print("── Покупка ──")
	await _test_buy(hud, save)
	print("── Надеть ──")
	await _test_equip(hud, save)
	print("── Нет денег ──")
	await _test_broke(hud, save)
	print("── Карточный вид ──")
	await _test_cards(hud, save)

	print("")
	if _fails == 0:
		print("ВСЁ ЗЕЛЁНОЕ")
	else:
		print("ПРОВАЛОВ: ", _fails)
	quit(1 if _fails > 0 else 0)

# ── Карточный вид ────────────────────────────────────────────────────────────
# Сетка отвечает на «что у меня есть», карточки — на «каков он». Ради второго
# всё и делалось: до этого посмотреть скин на четвёртом жире можно было только
# докормив его в забеге, то есть покупка делалась вслепую по одной картинке из
# четырёх. Поэтому проверяется не «карточки нарисовались», а СВАЙП ЖИРА.
func _test_cards(hud: Node, save: Node) -> void:
	_setup_save(save, 12400)
	var overlay : Control = await _open(hud, true)
	_check(overlay != null, "карточный вид открылся")
	if overlay == null:
		return

	var cards : Array = []
	_collect_cards(overlay, cards)
	_check(cards.size() >= 10, "карточек на всю коллекцию: %d" % cards.size())

	# Лента ГОРИЗОНТАЛЬНАЯ: карточки стоят в ряд, а не столбцом.
	if cards.size() >= 2:
		var a : Control = cards[0]
		var b : Control = cards[1]
		_check(absf(a.position.y - b.position.y) < 2.0 and b.position.x > a.position.x,
			"и стоят в ряд: (%.0f, %.0f) и (%.0f, %.0f)"
				% [a.position.x, a.position.y, b.position.x, b.position.y])

	# Свайп по портрету листает ЖИР. Событие подаётся настоящее — то же, что
	# придёт от пальца.
	var card : Control = _card_named(overlay, "Card_viking")
	_check(card != null, "карточка викинга на месте")
	if card != null:
		var holder : Control = card.get_node_or_null("Portrait")
		var swipe  : Control = card.get_node_or_null("FatSwipe")
		_check(holder != null and swipe != null, "у неё есть портрет и зона свайпа")
		if holder != null and swipe != null:
			var rect : TextureRect = hud.call("_head_icon_rect", holder)
			var fat0 : int = int(rect.get_meta("head_fat", -1))
			_swipe(swipe, -40.0)
			await process_frame
			var fat1 : int = int(rect.get_meta("head_fat", -1))
			_check(fat1 == fat0 + 1, "свайп влево листает вперёд: %d → %d" % [fat0, fat1])
			_swipe(swipe, 40.0)
			await process_frame
			_check(int(rect.get_meta("head_fat", -1)) == fat0,
				"свайп вправо возвращает: %d" % int(rect.get_meta("head_fat", -1)))

			# И меняется именно КАРТИНКА, а не только число.
			_swipe(swipe, -40.0)
			await process_frame
			_check(rect.texture != hud.call("_avatar_texture", "viking", fat0),
				"и портрет действительно другой")

			# Под портретом — ТОТ ЖЕ индикатор, что в забеге, и лампы в нём
			# КОПЯТСЯ. Стояли тут четыре одинаковых квадратика, и горел ровно
			# один: витрина сообщала, что состояния сменяют друг друга, — тогда
			# как третье не отменяет первых двух, оно на них стоит.
			var gauge : Control = _fat_gauge(card)
			_check(gauge != null, "под портретом индикатор жира из забега")
			if gauge != null:
				# Пульс черепа — предупреждение «следующий удар убивает». В
				# витрине убивать нечему, и мигающий красным череп читался бы
				# как поломка экрана.
				_check(not bool(gauge.get("warn_on_empty")),
					"и череп в витрине не пульсирует тревогой")
				# Отматываем в начало и проходим все четыре состояния подряд.
				for _r in 4:
					_swipe(swipe, 40.0)
					await process_frame
				var seen : Array = []
				var cum_ok := true
				for f in 4:
					var got : int = _lit(gauge)
					seen.append(got)
					if got != f + 1:
						cum_ok = false
					_swipe(swipe, -40.0)
					await process_frame
				_check(cum_ok, "лампы копятся слева направо: %s при ожидаемом [1, 2, 3, 4]"
					% [seen])

		# Закрытые уровнем состояния — под замком, а не пустой ячейкой: пустая
		# читается как «я ещё не дорос», замок — как «сюда не пускают», и это
		# разные сообщения. Проверяется по ВСЕЙ ленте: у прокачанного викинга
		# открыто всё, и одна его карточка пропустила бы замки совсем.
		var sp : Node = get_root().get_node_or_null("SkinProgression")
		var lock_ok := true
		var with_locks := 0
		for c in cards:
			var g : Control = _fat_gauge(c)
			if g == null:
				continue
			var sid : String = String(c.name).trim_prefix("Card_")
			var owned : bool = bool(save.call("owns_skin", sid))
			var mx : int = int(sp.call("max_fat_state", sid,
				save.call("get_skin_level_for", sid) if owned else 1))
			if _locked(g) != 3 - mx:
				lock_ok = false
			if _locked(g) > 0:
				with_locks += 1
		_check(lock_ok and with_locks > 0,
			"закрытые состояния под замком, замки есть на %d карточках" % with_locks)

		# ПОРТРЕТ ДЕРЖИТ РИСУНОК В КОРОБКЕ. Нормировка идёт по «голове», а голова
		# в замерах — это самое крупное связное пятно спрайта, и честной головой
		# оно оказывается не у всех: у Гарри руки и рубашка нарисованы отдельно и
		# мерится ровно голова, а у Волшебника шляпа слита с телом и мерится вся
		# фигура. Гарри от этого вылезал за коробку на треть, и рядом с соседями,
		# которые в неё помещались, читался как вдвое более крупный.
		#
		# Проверяется поэтому не «голова такого-то размера» (по кривой метрике
		# это ничего не значит), а РИСУНОК: он у всех внутри коробки и у всех
		# занимает её сопоставимо.
		var out_of_box : Array = []
		var fill_min : float = 9.0
		var fill_max : float = 0.0
		for c in cards:
			var hd : Control = c.get_node_or_null("Portrait")
			if hd == null:
				continue
			var rr : TextureRect = hud.call("_head_icon_rect", hd)
			if rr == null or rr.texture == null:
				continue
			var used : Rect2i = ItemSizing.content_rect(rr.texture)
			var k : float = rr.size.x / float(rr.texture.get_width())
			var tl : Vector2 = rr.position + Vector2(used.position) * k
			var wh : Vector2 = Vector2(used.size) * k
			if tl.x < -1.0 or tl.y < -1.0 \
					or tl.x + wh.x > hd.size.x + 1.0 or tl.y + wh.y > hd.size.y + 1.0:
				out_of_box.append(String(c.name))
			var fill : float = maxf(wh.x, wh.y) / hd.size.x
			fill_min = minf(fill_min, fill)
			fill_max = maxf(fill_max, fill)
		_check(out_of_box.is_empty(),
			"рисунок ни у кого не вылезает за портрет: %s" % [out_of_box])
		_check(fill_min > 0.55 and fill_max <= 1.0,
			"и занимает коробку сопоставимо: от %.2f до %.2f" % [fill_min, fill_max])

	await _close(overlay)

# Индикатор 💀 F A T карточки. Ищется по классу, а не по имени узла: имя можно
# переставить, а класс — это ровно тот же прибор, что стоит в забеге.
func _fat_gauge(card: Node) -> Control:
	for c in card.get_children():
		if c is FatGauge:
			return c
	return null

func _lit(gauge: Control) -> int:
	var n := 0
	for l in gauge.get_children():
		if bool(l.get("lit")):
			n += 1
	return n

func _locked(gauge: Control) -> int:
	var n := 0
	for l in gauge.get_children():
		if bool(l.get("locked")):
			n += 1
	return n

func _collect_cards(root: Node, out: Array) -> void:
	if root is Control and String(root.name).begins_with("Card_"):
		out.append(root)
	for c in root.get_children():
		_collect_cards(c, out)

func _card_named(root: Node, nm: String) -> Control:
	var stack : Array = [root]
	while not stack.is_empty():
		var n : Node = stack.pop_back()
		if n is Control and String(n.name) == nm:
			return n
		for c in n.get_children():
			stack.append(c)
	return null

# Настоящая последовательность событий пальца: касание, протяжка, отпускание.
func _swipe(ctrl: Control, dx: float) -> void:
	var down := InputEventScreenTouch.new()
	down.pressed = true
	ctrl.gui_input.emit(down)
	var mv := InputEventScreenDrag.new()
	mv.relative = Vector2(dx, 0.0)
	ctrl.gui_input.emit(mv)
	var up := InputEventScreenTouch.new()
	up.pressed = false
	ctrl.gui_input.emit(up)

# ── Хелперы ───────────────────────────────────────────────────────────────────

func _setup_save(save: Node, dollars: int) -> void:
	save.dollars     = dollars
	save.tokens      = 50
	save.owned_skins = ["classic", "viking", "tyson"]
	save.active_skin = "viking"
	save.skin_level  = 3

# Вид задаётся ЯВНО на каждое открытие. По умолчанию экран открывается
# карточками, и проверки сетки, написанные до этого, молча искали бы ячейки в
# ленте карточек и находили ноль — «сетка сломалась», хотя сломался тест.
func _open(hud: Node, cards: bool = false) -> Control:
	hud.set("_skins_card_view", cards)
	var before : Array = hud.get_children()
	hud.call("_show_shop", 0, true, true)   # from_slots=true — без анимации въезда
	for _i in 8:
		await process_frame
	for c in hud.get_children():
		if c is Control and not before.has(c):
			return c
	return null

# Экран может освободиться сам — после покупки он пересобирается. Поэтому
# закрытие принимает что угодно и молча пропускает уже мёртвый узел.
func _close(overlay: Variant) -> void:
	if overlay != null and is_instance_valid(overlay):
		(overlay as Node).free()
	await process_frame

func _texts(node: Node, out: Array) -> Array:
	if node is Label:
		out.append(String((node as Label).text))
	for c in node.get_children():
		_texts(c, out)
	return out

# Карточка скина — Control, в поддереве которого лежит подпись с его именем.
func _cell_for(overlay: Node, name_ru: String) -> Control:
	var stack : Array = [overlay]
	while not stack.is_empty():
		var n : Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
			if c is Control and _texts(c, []).has(name_ru) and c.size.x > 80.0 and c.size.x < 300.0:
				return c
	return null

# Кнопка действия карточки: она смещена вниз, а зона открытия подробностей
# начинается от нуля. Так и различаем, не завязываясь на порядок детей.
func _action_button(cell: Control) -> Button:
	var best : Button = null
	for c in cell.get_children():
		if c is Button and (c as Button).position.y > 1.0:
			best = c
	return best

func _cells(overlay: Node) -> Array:
	var out : Array = []
	for sd in SkinRegistryList():
		var cell := _cell_for(overlay, String(sd.get("name_ru", sd["id"])))
		if cell != null:
			out.append(cell)
	return out

func SkinRegistryList() -> Array:
	var reg : Node = get_root().get_node_or_null("SkinRegistry")
	var out : Array = []
	for sd in reg.SKINS:
		if String(sd["id"]) == "new_year":
			continue
		out.append(sd)
	return out

# ── Тесты ─────────────────────────────────────────────────────────────────────

# Ради этой раскладки экран и переделывался: вся коллекция обязана помещаться
# на экран без прокрутки, а карточки — не наезжать друг на друга.
func _test_grid(hud: Node, save: Node) -> void:
	_setup_save(save, 12400)
	var overlay : Control = await _open(hud)
	_check(overlay != null, "экран магазина собрался")
	if overlay == null:
		return

	var want : int = SkinRegistryList().size()
	var cells : Array = _cells(overlay)
	_check(cells.size() == want, "на экране все %d скинов, найдено %d" % [want, cells.size()])

	var vp : Vector2 = get_root().get_visible_rect().size
	var boxes : Array = []
	for c in cells:
		boxes.append(Rect2((c as Control).global_position, (c as Control).size))

	var inside := true
	for b in boxes:
		var r : Rect2 = b
		if r.position.x < -0.5 or r.position.y < -0.5 or r.end.x > vp.x + 0.5 or r.end.y > vp.y + 0.5:
			inside = false
	_check(inside, "все карточки целиком на экране %dx%d" % [int(vp.x), int(vp.y)])

	var overlap := false
	for i in boxes.size():
		for j in range(i + 1, boxes.size()):
			if (boxes[i] as Rect2).intersects(boxes[j] as Rect2):
				overlap = true
	_check(not overlap, "карточки не наезжают друг на друга")
	await _close(overlay)

# Каждое состояние обязано быть названо СЛОВОМ: по одному цвету рамки игрок не
# отличит купленный скин от того, на который не хватает денег.
func _test_states(hud: Node, save: Node) -> void:
	_setup_save(save, 5200)   # хватит на «редкий» за 5000, но не на эпический
	var overlay : Control = await _open(hud)
	var t : Array = _texts(overlay, [])
	_check(t.has("АКТИВЕН"), "активный скин подписан словом")
	_check(t.has("НАДЕТЬ"),  "купленный скин подписан словом")
	_check(t.has("НЕТ ДЕНЕГ"), "недоступный скин подписан словом")
	var has_price := false
	for line in t:
		if String(line) == "5000":
			has_price = true
	_check(has_price, "у доступного к покупке видна цена")

	# Редкость тоже словом, а не только цветом ленты.
	_check(t.has("Обычный") or t.has("Редкий") or t.has("Эпический"),
		"редкость подписана словом")
	await _close(overlay)

# Покупка списывает ровно один раз и переводит карточку в «НАДЕТЬ».
func _test_buy(hud: Node, save: Node) -> void:
	_setup_save(save, 12400)
	var overlay : Control = await _open(hud)
	var reg : Node = get_root().get_node_or_null("SkinRegistry")
	var target := "batman"
	var data : Dictionary = reg.get_skin(target)
	var price : int = int(data.get("price", 0))
	var d0 : int = int(save.get("dollars"))

	var cell := _cell_for(overlay, String(data["name_ru"]))
	_check(cell != null, "карточка «%s» на экране" % data["name_ru"])
	if cell == null:
		await _close(overlay)
		return
	var btn := _action_button(cell)
	_check(btn != null, "у карточки есть кнопка покупки")
	if btn == null:
		await _close(overlay)
		return
	btn.emit_signal("pressed")
	for _i in 10:
		await process_frame

	_check(bool(save.call("owns_skin", target)), "скин куплен")
	_check(int(save.get("dollars")) == d0 - price,
		"списано ровно %d $: было %d, стало %d" % [price, d0, int(save.get("dollars"))])

	# Экран пересобрался — на новой карточке уже «НАДЕТЬ», а не цена.
	var fresh : Control = null
	for c in hud.get_children():
		if c is Control and c != overlay:
			fresh = c
	if fresh != null:
		var cell2 := _cell_for(fresh, String(data["name_ru"]))
		_check(cell2 != null and _texts(cell2, []).has("НАДЕТЬ"),
			"после покупки карточка предлагает надеть")
		await _close(fresh)
	await _close(overlay)
	for c in hud.get_children():
		if c is Control and c.name.begins_with("@Control"):
			c.free()
	await process_frame

func _test_equip(hud: Node, save: Node) -> void:
	_setup_save(save, 12400)
	var overlay : Control = await _open(hud)
	var reg : Node = get_root().get_node_or_null("SkinRegistry")
	var data : Dictionary = reg.get_skin("tyson")
	var cell := _cell_for(overlay, String(data["name_ru"]))
	var btn := _action_button(cell) if cell != null else null
	_check(btn != null, "у купленного скина есть кнопка «НАДЕТЬ»")
	if btn != null:
		btn.emit_signal("pressed")
		for _i in 10:
			await process_frame
	_check(String(save.get("active_skin")) == "tyson",
		"активный скин сменился: %s" % save.get("active_skin"))
	for c in hud.get_children():
		if c is Control:
			c.free()
	await process_frame

# На недоступной карточке кнопки быть не должно вовсе — иначе тап «покупает»
# впустую и игрок думает, что игра сломана.
func _test_broke(hud: Node, save: Node) -> void:
	_setup_save(save, 100)
	var overlay : Control = await _open(hud)
	var reg : Node = get_root().get_node_or_null("SkinRegistry")
	var data : Dictionary = reg.get_skin("joker")
	var cell := _cell_for(overlay, String(data["name_ru"]))
	_check(cell != null, "карточка недоступного скина на экране")
	if cell != null:
		_check(_action_button(cell) == null, "на недоступной карточке нет кнопки покупки")
		_check(_texts(cell, []).has("НЕТ ДЕНЕГ"), "и написано, почему")
	var d0 : int = int(save.get("dollars"))
	for _i in 5:
		await process_frame
	_check(int(save.get("dollars")) == d0, "деньги не тронуты")
	await _close(overlay)
