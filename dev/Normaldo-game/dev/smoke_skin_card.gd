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

	# ── ЯЗЫК ПРИБИТ К РУССКОМУ ───────────────────────────────────────────────
	# Тест считает на экране РУССКИЕ слова — «РЕЗИСТ», «АКТИВНАЯ». А подписи
	# способностей собираются склейкой из уже переведённых кусков, и на
	# английской машине в них лежит английский: проверки падают не потому, что
	# карточка сломалась, а потому, что она заговорила на другом языке.
	#
	# Ставится ЛОКАЛЬ ПРОЦЕССА, а не выбор игрока: `Loc.set_language` пишет в
	# сохранение, а оно на диске и переживает прогон — тест бы навязал русский
	# всем следующим сюитам и самому разработчику.
	TranslationServer.set_locale("ru")
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
	print("── Подпись и жир ──")
	await _test_lore_and_fat(hud, save, reg)
	print("── Статистика скина ──")
	await _test_stats(hud, save, reg)
	print("── Состояния кнопки ──")
	await _test_action(hud, save, reg)
	print("── Все скины ──")
	await _test_all_skins(hud, save, reg)
	print("── Кружок тот же, что в забеге ──")
	_test_badge_matches_run()
	print("── Награда стоит посередине карточки ──")
	await _test_reward_centred(hud, save, reg)

	print("")
	if _fails == 0:
		print("ВСЁ ЗЕЛЁНОЕ")
	else:
		print("ПРОВАЛОВ: ", _fails)
	quit(1 if _fails > 0 else 0)

# ── КРУЖОК СПОСОБНОСТИ — ОДИН И ТОТ ЖЕ В ДВУХ МЕСТАХ ───────────────────────
# В забеге он висит в углу экрана, на карточке скина — в списке способностей, и
# игрок обязан узнать в нём тот же значок. Узнаёт он его по СИЛУЭТУ: предмет
# нарисован крупнее диска и вылезает за кольцо.
#
# Пропорция у обоих должна быть одна. Здесь она разъехалась ровно так: боевой
# кружок рисовал иконку на 116 % диска, карточка — на 64 %, вписывая её внутрь
# кольца, и один и тот же резист выглядел двумя разными значками.
#
# Проверяется, что карточка БЕРЁТ число у боевого кружка, а не держит своё.
func _test_badge_matches_run() -> void:
	var badges := FileAccess.get_file_as_string("res://scripts/skill_badges.gd")
	var hud    := FileAccess.get_file_as_string("res://scripts/hud.gd")
	_check(badges.contains("const ICON_OVER"),
		"боевой кружок объявил пропорцию иконки")
	_check(hud.contains("_SKILL_BADGES_SCRIPT.ICON_OVER"),
		"а карточка берёт её оттуда же, а не пишет своим числом")
	# И сам он ею же и рисует: объявленная, но неиспользованная константа — это
	# два числа вместо одного, только с видом порядка.
	_check(badges.contains("D * ICON_OVER"),
		"и рисует ею же")
	# То же и со свечением под тёмной иконкой: таблица кругов одна на оба места.
	_check(badges.contains("const ICON_GLOW_RINGS"),
		"свечение объявлено там же")
	_check(hud.contains("_SKILL_BADGES_SCRIPT.ICON_GLOW_RINGS"),
		"и карточка светит той же таблицей")

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

# Есть ли где-нибудь в поддереве узел, показывающий именно эту картинку.
# Рисуют её по-разному — TextureRect в одних местах, Sprite2D в других, — и
# искать по типу узла значит промахнуться на первой же перестановке вёрстки.
func _has_texture(node: Node, want: Texture2D) -> bool:
	if want == null:
		return false
	if node is TextureRect and (node as TextureRect).texture == want:
		return true
	if node is Sprite2D and (node as Sprite2D).texture == want:
		return true
	for c in node.get_children():
		if _has_texture(c, want):
			return true
	return false

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

# Центральную колонку заполняют подпись героя и лестница состояний жира. Без
# них там пустовала половина панели, а о самих состояниях говорил только
# перетаскиваемый кусок пиццы, о котором игрок не догадывался.
func _test_lore_and_fat(hud: Node, save: Node, reg: Node) -> void:
	# Подпись обязана быть у КАЖДОГО скина: пустая строка оставит дыру в колонке.
	var missing : Array = []
	var too_long : Array = []
	for sd in reg.SKINS:
		var id := String(sd["id"])
		var text := String(reg.lore_for(id))
		if text.strip_edges() == "":
			missing.append(id)
		elif text.length() > 90:
			too_long.append("%s (%d)" % [id, text.length()])
	_check(missing.is_empty(), "подпись есть у всех скинов, нет у: %s" % [missing])
	_check(too_long.is_empty(), "подписи влезают в колонку, длинные: %s" % [too_long])

	# На 1-м уровне открыты три состояния, четвёртое — с замком и уровнем.
	_reset(save, ["classic", "pirate"], "pirate", 1)
	var ov : Control = await _open(hud, reg, "pirate")
	var t : Array = _texts(ov, [])
	_check(_count(t, String(reg.lore_for("pirate"))) == 1, "подпись героя на карточке")
	_check(_count(t, "СОСТОЯНИЯ ЖИРА") == 1, "лестница состояний жира на карточке")
	var unlock_lvl : int = hud.call("_fat_unlock_level", 3, "pirate")
	_check(_count(t, "ур.%d" % unlock_lvl) > 0,
		"у закрытого состояния подписан уровень открытия (ур.%d)" % unlock_lvl)
	await _close(ov)

	# На уровне, где открыто всё, замков быть не должно.
	_reset(save, ["classic", "pirate"], "pirate", 5)
	var ov2 : Control = await _open(hud, reg, "pirate")
	var t2 : Array = _texts(ov2, [])
	var locks := 0
	for fi in 4:
		var lv : int = hud.call("_fat_unlock_level", fi, "pirate")
		if lv > 1:
			locks += _count(t2, "ур.%d" % lv)
	_check(locks == 0 or _count(t2, "ур.5") > 0,
		"на прокачанном скине состояния жира открыты")
	await _close(ov2)

# Личная статистика скина. Счётчики лежат в той же записи, что и опыт, и главный
# риск тут не в отображении, а в том, что сохранение затрёт их: _flush_active
# раньше подменял запись целиком.
func _test_stats(hud: Node, save: Node, reg: Node) -> void:
	_reset(save, ["classic", "tyson"], "tyson", 3)
	_check(int(save.get_skin_runs_for("tyson")) == 0 and int(save.get_skin_best_for("tyson")) == 0,
		"у нового скина счётчики на нуле")

	save.note_run_finished(120)
	save.note_run_finished(340)
	_check(int(save.get_skin_runs_for("tyson")) == 2, "забеги считаются: %d" % save.get_skin_runs_for("tyson"))
	_check(int(save.get_skin_best_for("tyson")) == 340, "рекорд взят лучший: %d" % save.get_skin_best_for("tyson"))

	save.note_run_finished(90)
	_check(int(save.get_skin_best_for("tyson")) == 340, "слабый забег рекорд не сбивает")
	_check(int(save.get_skin_runs_for("tyson")) == 3, "но в счётчик забегов попадает")

	# Забег засчитывается только АКТИВНОМУ скину.
	_check(int(save.get_skin_runs_for("classic")) == 0, "чужому скину забег не приписан")

	# Сохранение и смена скина не должны стирать счётчики: они лежат в одной
	# записи с опытом, и полная перезапись записи их убивала.
	save.set_active_skin("classic")
	save.set_active_skin("tyson")
	_check(int(save.get_skin_runs_for("tyson")) == 3 and int(save.get_skin_best_for("tyson")) == 340,
		"счётчики пережили смену скина: %d / %d"
		% [save.get_skin_runs_for("tyson"), save.get_skin_best_for("tyson")])

	# На карточке строка есть и показывает те же числа.
	var ov : Control = await _open(hud, reg, "tyson")
	var t : Array = _texts(ov, [])
	_check(_count(t, "Забегов: 3") == 1, "на карточке показано число забегов")
	_check(_count(t, "Рекорд: 340") == 1, "и рекорд")
	await _close(ov)

	# У скина без забегов — отдельная формулировка, а не два нуля.
	_reset(save, ["classic", "pirate"], "pirate", 1)
	var ov2 : Control = await _open(hud, reg, "pirate")
	var t2 : Array = _texts(ov2, [])
	_check(_count(t2, "Ещё ни одного забега") == 1, "скин без забегов подписан словами")
	_check(_count(t2, "Рекорд: 0") == 0, "и нулей не показывает")
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
	# Без денег кнопка показывает ЦЕНУ, а не «НЕТ ДЕНЕГ»: игрок и так видит
	# баланс, а вот сколько ещё копить — только здесь.
	var t3 : Array = _texts(ov3, [])
	_check(_count(t3, "НЕТ ДЕНЕГ") == 0, "слов «нет денег» больше нет")
	var price3 : int = int((reg.get_skin("joker") as Dictionary).get("price", 0))
	_check(_count(t3, str(price3)) >= 1, "а написана цена %d: %s" % [price3, t3])

	# ── ВЕНЕЦ ПОКАЗАН СВОЕЙ КАРТИНКОЙ ────────────────────────────────────────
	# У венца 10-го уровня три места показа: кружок в забеге, строка лестницы на
	# карточке и окно «уровень взят». В забеге он рисовался картинкой, а в
	# карточке — общей звёздочкой «★», и паучью реакцию, которую игрок узнаёт по
	# руке, на экране скина нельзя было отличить от остановки времени.
	#
	# Проверяем не «есть ли звёздочка», а лежит ли на карточке ИМЕННО ТА
	# картинка, которую отдаёт `SkinProgression.perk_icon`: если кто-то заведёт
	# венцу свой `preload` рядом, тест этого не заметит, а вот подмену источника
	# — заметит.
	var ov4 : Control = await _open(hud, reg, "spider_man")
	var prog : Node = get_root().get_node_or_null("SkinProgression")
	var want_tex : Texture2D = prog.call("perk_icon", "spider_reflex")
	_check(want_tex != null, "у паучьей реакции заведена картинка")
	_check(_has_texture(ov4, want_tex),
		"и она стоит на карточке скина, а не звёздочка")
	await _close(ov4)
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

# ── НАГРАДА НЕ ЛЕЖИТ НА ГРАНИЦЕ КАРТОЧКИ ──────────────────────────────────────
# Блок награды — это ИКОНКА ПЛЮС ЧИСЛО ПОД НЕЙ, и он выше самой иконки.
# Центрировали по одной иконке: блок уезжал на треть карточки вниз и ложился на
# нижнюю рамку, оставляя сверху пустоту. На глаз это заметно только рядом с
# соседней карточкой, где награда — картинка без подписи.
#
# Меряются НАСТОЯЩИЕ узлы: сколько пустоты осталось сверху и сколько снизу.
func _test_reward_centred(hud: Node, save: Node, reg: Node) -> void:
	save.skin_progress = {}
	var ov : Control = await _open(hud, reg, "viking")
	if ov == null:
		_check(false, "карточка не открылась")
		return
	var cards := _money_cards(ov, [])
	_check(not cards.is_empty(), "денежных карточек найдено: %d" % cards.size())
	var bad : Array = []
	for c in cards:
		var card : Control = (c as Array)[0]
		var top  : float   = (c as Array)[1]
		var bot  : float   = (c as Array)[2]
		var over := top
		var under := card.size.y - bot
		# Полпикселя разницы даёт нечётная высота — это не перекос.
		if absf(over - under) > 2.0:
			bad.append("%s: сверху %.0f, снизу %.0f" % [card.name, over, under])
	_check(bad.is_empty(), "сверху и снизу поровну: %s" % [bad])
	_close(ov)

# Карточки, где награда — деньги: у них внутри иконка-TextureRect и подпись
# «xN». Возвращается [карточка, верх блока, низ блока] в координатах карточки.
func _money_cards(n: Node, out: Array) -> Array:
	if n is Control:
		var icons : Array = []
		var nums  : Array = []
		for ch in n.get_children():
			if ch is TextureRect:
				icons.append(ch)
			elif ch is Label and String((ch as Label).text).begins_with("x"):
				nums.append(ch)
		if not icons.is_empty() and not nums.is_empty():
			var top := INF
			var bot := -INF
			for i in icons:
				top = minf(top, (i as Control).position.y)
				bot = maxf(bot, (i as Control).position.y + (i as Control).size.y)
			for l in nums:
				top = minf(top, (l as Control).position.y)
				bot = maxf(bot, (l as Control).position.y + (l as Control).size.y)
			out.append([n as Control, top, bot])
	for ch in n.get_children():
		_money_cards(ch, out)
	return out
