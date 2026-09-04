extends SceneTree

# Headless-проверка интерфейса ВО ВРЕМЯ забега.
#   godot --headless --path . --script res://dev/smoke_run_hud.gd
#
# Резисты, кружки способностей, полоса жира и лампы 💀 F A T — всё, что игрок
# читает, пока летит.
#
# Колец резиста на предметах больше нет (их убрали: см. «Интерфейс забега»), но
# сами резисты остались, и главная тихая поломка тоже: опечатка в теге молча
# выключает резист навсегда — `_area_tag` просто никогда не вернёт такую строку.
# Это и проверяется первым разделом.
#
# См. /Концепция/Интерфейс забега.md

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
	var hud      : Node = game.get_node_or_null("HUD")
	var normaldo : Node = game.get_node_or_null("Normaldo")
	var spawner  : Node = game.get_node_or_null("Spawner")
	var save     : Node = get_root().get_node_or_null("SaveData")
	if hud == null or normaldo == null or spawner == null:
		print("  FAIL сцена не собралась")
		quit(1)
		return

	print("── Теги резистов ──")
	await _test_state(game, normaldo, save, spawner)
	print("── Ряд кружков ──")
	await _test_badges(hud, normaldo, save)
	print("── Полоса жира ──")
	await _test_fat_bar(hud, normaldo, save)
	print("── Лампы 💀 F A T ──")
	await _test_fat_gauge(hud, normaldo, save)

	print("")
	if _fails == 0:
		print("ВСЁ ЗЕЛЁНОЕ")
	else:
		print("ПРОВАЛОВ: ", _fails)
	quit(1 if _fails > 0 else 0)

# ── Лампы жира ───────────────────────────────────────────────────────────────
# На этом месте стояли ДВЕ КОПИИ СКИНА — текущее состояние и следующее. Скин и
# так на экране, крупный и в центре; индикатор должен отвечать не «как я
# выгляжу», а «сколько у меня осталось запаса». Теперь это череп и F A T.
func _test_fat_gauge(hud: Node, normaldo: Node, save: Node) -> void:
	var g : Control = hud.get("_fat_gauge")
	_check(g != null, "индикатор собрался")
	if g == null:
		return
	_check(g.get_child_count() == 4, "ламп ровно четыре: %d" % g.get_child_count())

	# Ни одной картинки скина в индикаторе: ради этого всё и затевалось.
	var pics : int = 0
	for c in g.get_children():
		if c is TextureRect and (c as TextureRect).texture != null:
			pics += 1
	_check(pics == 0, "и ни одной картинки скина в нём: %d" % pics)

	save.skin_level = 10
	for fat in 4:
		g.call("set_state", fat, 3, false)
		await process_frame
		var lit : int = 0
		var wrong : int = 0
		for i in g.get_child_count():
			var l : Control = g.get_child(i)
			if bool(l.get("lit")):
				lit += 1
			if bool(l.get("lit")) != (i <= fat):
				wrong += 1
		_check(wrong == 0 and lit == fat + 1,
			"жир %d: горит %d ламп, лишних нет" % [fat + 1, lit])

	# Череп в одиночестве — предупреждение: следующий удар убивает. Он пульсирует
	# ровно на нижнем состоянии и молчит, как только загорелась первая буква.
	g.call("set_state", 0, 3, false)
	await process_frame
	var tw = g.get("_pulse_tw")
	_check(tw != null and tw.is_valid(), "жир 1: череп тревожно пульсирует")
	g.call("set_state", 1, 3, false)
	await process_frame
	var tw2 = g.get("_pulse_tw")
	_check(tw2 == null or not tw2.is_valid(), "жир 2: пульс погашен")

	# Закрытое лестницей состояние — под замком. Пустая ячейка читалась бы как
	# «сюда я ещё не дорос», а замок — как «сюда не пускают».
	g.call("set_state", 1, 2, false)
	await process_frame
	var locked : Array = []
	for i in g.get_child_count():
		if bool(g.get_child(i).get("locked")):
			locked.append(i)
	_check(locked == [3], "закрытое состояние под замком: %s" % str(locked))

	# Сбили жир — лампа гаснет. Проверяется именно ГАШЕНИЕ, а не анимация
	# падения: падение косметика, а погасшая лампа — это состояние.
	g.call("set_state", 3, 3, false)
	await process_frame
	g.call("set_state", 1, 3, true)
	var t := 0.0
	while t < 0.8:
		await process_frame
		t += 1.0 / 60.0
	var still_lit : Array = []
	for i in g.get_child_count():
		if bool(g.get_child(i).get("lit")):
			still_lit.append(i)
	_check(still_lit == [0, 1], "после удара горят только череп и F: %s" % str(still_lit))

# ── Хелперы ───────────────────────────────────────────────────────────────────

func _use_skin(normaldo: Node, save: Node, sid: String) -> void:
	save.active_skin = sid
	save.skin_level  = 10          # чтобы открылась вся лестница резистов
	normaldo.call("reload_skin")
	normaldo.call("_build_skin_runtime")

# Предмет с нужным тегом, поставленный вручную: ждать нужной волны от спавнера
# — значит получить нестабильный тест.
func _put_item(spawner: Node, tex: Texture2D, y: float, x: float) -> Node:
	var it : Node = spawner.call("_spawn_item", y, x, tex, 0.30, 0.0, 1)
	it.position.x = x
	return it

# ── Тесты ─────────────────────────────────────────────────────────────────────

# Резист держится на ОДНОЙ строке — теге предмета, — и опечатка в ней ничего не
# ломает громко: `_area_tag` просто никогда не вернёт такую строку, резист молча
# не срабатывает, и заметить это можно только подставившись под нужный предмет.
# Поэтому теги сверяются у ВСЕХ скинов разом.
func _test_state(game: Node, normaldo: Node, save: Node, spawner: Node) -> void:
	spawner.call("clear_items")
	var trash : Node = _put_item(spawner, spawner.TRASH_TEX, 200.0, 600.0)
	var stone : Node = _put_item(spawner, spawner.STONE_TEX, 260.0, 700.0)
	await process_frame

	# Предмет опознаётся тем же тегом, которым записан резист скина.
	_use_skin(normaldo, save, "viking")   # резисты: cone / stone / trash / safe
	var cds : Dictionary = normaldo.get("_resist_cd_for")
	_check(String(normaldo.call("_area_tag", trash)) == "trash" and cds.has("trash"),
		"бочка опознана тегом резиста викинга")
	_check(String(normaldo.call("_area_tag", stone)) == "stone" and cds.has("stone"),
		"камень тоже")

	# У чужого скина тех же тегов в резистах нет.
	_use_skin(normaldo, save, "joker")    # bum / thief / cop / black_ace
	cds = normaldo.get("_resist_cd_for")
	_check(not cds.has("trash") and not cds.has("stone"),
		"у джокера этих резистов нет")

	# Опечатка в теге резиста молча выключает его навсегда: `_area_tag` просто
	# никогда не вернёт такую строку, резист не сработает, а метки не будет.
	# Поэтому сверяем теги ВСЕХ скинов со словарём, который умеет разбирать
	# `normaldo._area_tag` (список ниже повторяет его).
	var known : Array = [
		"fire", "glove", "snake", "bum", "dog", "thief", "compass", "cone",
		"handcuffs", "black_ace", "loser_ticket", "ninja", "safe", "cocktail",
		"cop", "poison", "bird", "helm", "shaman", "slowing",
		"banana", "beer", "trash", "stone",
	]
	var bad : Array = []
	var reg : Node = get_root().get_node_or_null("SkinRegistry")
	for sk in reg.SKINS:
		var sid : String = String((sk as Dictionary).get("id", ""))
		if sid == "":
			continue
		_use_skin(normaldo, save, sid)
		for tag in (normaldo.get("_resist_cd_for") as Dictionary).keys():
			if not known.has(String(tag)):
				bad.append("%s → %s" % [sid, tag])
	_check(bad.is_empty(), "теги резистов разбираются у всех скинов: %s" % [bad])

func _test_badges(hud: Node, normaldo: Node, save: Node) -> void:
	# spider_man — скин с ПОСТОЯННО включённой пассивкой: именно её статичный ★
	# и был лишним кружком в ряду.
	_use_skin(normaldo, save, "spider_man")
	hud.call("_build_skill_badges", normaldo)
	await process_frame
	var layer : Node = hud.get("_skill_badges_layer")
	var keys : Array = []
	var static_visible : Array = []
	for b in layer.get_children():
		var k := String(b.get("key"))
		keys.append(k)
		if not bool(b.get("dynamic")):
			static_visible.append(k)
	var has_passive := false
	for k in keys:
		if String(k).begins_with("passive:"):
			has_passive = true
	_check(not has_passive,
		"постоянной пассивки в ряду нет: %s" % [keys])

	# Постоянно висят только те кружки, состояние которых МЕНЯЕТСЯ: резисты и
	# активка. Всё остальное появляется на время действия.
	for k in static_visible:
		_check(k.begins_with("resist:") or k == "active",
			"постоянный кружок оправдан: %s" % k)

	# А динамические кружки эффектов на месте: они и есть то, что сообщает.
	for want in ["compass", "item:magic_hat", "item:cola"]:
		_check(keys.has(want), "динамический кружок «%s» на месте" % want)

	# Кружок вырос: 34 px в углу экрана и были причиной жалобы.
	var small : Array = []
	for b in layer.get_children():
		if float((b as Control).size.x) < 40.0:
			small.append("%s=%.0f" % [b.get("key"), (b as Control).size.x])
	_check(small.is_empty(), "кружки не мельче 40 px: %s" % [small])

func _test_fat_bar(hud: Node, normaldo: Node, save: Node) -> void:
	_use_skin(normaldo, save, "viking")
	var names : Array = hud.get("_FAT_NAMES")
	var thr   : Array = hud.get("FAT_THRESHOLDS")
	var bad   : Array = []
	for st in 4:
		var count : int = 0 if st == 0 else int(thr[st - 1])
		hud.call("_on_stats_changed", st, count + 5, 137)
		await process_frame
		var nm : String = String((hud.get("_fat_name_lbl") as Label).text)
		var lf : String = String((hud.get("_fat_left_lbl") as Label).text)
		if nm != String(names[st]):
			bad.append("состояние %d: «%s» вместо «%s»" % [st, nm, names[st]])
		if lf == "":
			bad.append("состояние %d: остаток пустой" % st)
	_check(bad.is_empty(), "состояние словом и остаток числом на всех жирах: %s" % [bad])

	# На максимальном состоянии остатка нет — там обязано быть слово.
	hud.call("_on_stats_changed", 3, 999, 999)
	await process_frame
	_check(String((hud.get("_fat_left_lbl") as Label).text) == "МАКСИМУМ",
		"на максимуме написано «МАКСИМУМ»: %s" % (hud.get("_fat_left_lbl") as Label).text)
