extends SceneTree

# Островок, чёлка и полоска «домой».
#   godot --headless --path . --script res://dev/smoke_safe_area.gd
#
# ── ЧТО ЗДЕСЬ ПРОВЕРЯЕТСЯ ──────────────────────────────────────────────────
# Обещание сменилось, и вместе с ним сменился тест.
#
# БЫЛО: слой интерфейса ужимался в безопасный прямоугольник целиком, и проверка
# сверяла масштаб. Стоило это семи процентов размера НА КАЖДОМ ЭКРАНЕ, включая
# те, где островку закрывать нечего, — и кнопка паузы отъезжала от угла, хотя
# железо к ней и близко не подходит.
#
# СТАЛО: слои не двигаются вовсе, а разметка обходит САМО ПЯТНО там, где
# содержимое до него дотягивается. Проверять теперь надо не масштаб (его нет), а
# то, ради чего всё затевалось: НЕ ЛЕЖИТ ЛИ ЧТО-НИБУДЬ ПОД ЖЕЛЕЗОМ.
#
# Поэтому экраны открываются по-настоящему, островок подменяется на левый и на
# правый, и по дереву собирается всё, что попало под пятно. Список пустой —
# значит обещание держится.
#
# ── ДВЕ ЛОВУШКИ ЗАМЕРА ────────────────────────────────────────────────────
# У подписи КОРОБКА ШИРЕ БУКВ: по коробке «под островком» оказывались надписи,
# чьи буквы до него не доходят. Меряются буквы.
#
# Содержимое ПРОКРУТКИ обрезается её границами: глобальный прямоугольник
# карточки торчит наружу, а на экране её там нет. Такие узлы пропускаются — за
# них отвечает сама прокрутка, а её границы проверяются наравне со всеми.

const CANVAS : Vector2 = Vector2(960.0, 430.0)
const SIM_L  : Vector4 = Vector4(66.0, 0.0,  0.0, 18.0)
const SIM_R  : Vector4 = Vector4( 0.0, 0.0, 66.0, 18.0)

# Экраны, которые обязаны обойти островок. Список именно перечислительный: новый
# экран сюда вписывается руками, то есть решение «а этот проверяем» будет
# принято, а не забыто.
const SCREENS : Array = [
	"меню", "сетка", "карточки", "задания", "лидеры",
	"достижения", "настройки", "слоты", "забег", "пауза", "смерть",
]

# Во весь экран остаются НАРОЧНО: фон обязан доходить до краёв, иначе по бокам
# появятся пустые поля, а затемнение с каймой по краю — это не затемнение.
# Узнаются по размеру: ровно холст.
func _is_backdrop(r: Rect2) -> bool:
	return r.size.x >= CANVAS.x - 1.0 and r.size.y >= CANVAS.y - 1.0

var _fails  : int = 0
var _checks : int = 0
const EXPECTED_CHECKS : int = 9

func _check(ok: bool, what: String) -> void:
	_checks += 1
	if ok:
		print("  ok   ", what)
	else:
		_fails += 1
		print("  FAIL ", what)

func _initialize() -> void:
	print("── Пятно железа ──")
	_test_island_geometry()
	print("── Слои не двигаются ──")
	await _test_layers_untouched()
	print("── Под островком пусто ──")
	await _test_screens()
	print("── Поворот телефона ──")
	await _test_rotation()

	print("")
	if _checks < EXPECTED_CHECKS:
		_fails += 1
		print("ПРОВЕРОК ВСЕГО %d, А ЖДАЛИ %d — какая-то оборвалась"
			% [_checks, EXPECTED_CHECKS])
	if _fails == 0:
		print("ВСЁ ЗЕЛЁНОЕ (проверок: %d)" % _checks)
	else:
		print("ПРОВАЛОВ: ", _fails)
	quit(1 if _fails > 0 else 0)

# ── Само пятно ────────────────────────────────────────────────────────────
func _test_island_geometry() -> void:
	var sa := get_root().get_node_or_null("SafeArea")
	if sa == null:
		_check(false, "автолоад SafeArea не поднялся")
		return
	# Без выреза разметку не трогаем ВООБЩЕ: на настольной машине и на телефоне
	# без островка игра обязана остаться такой, какой её нарисовали.
	sa.call("simulate", Vector4.ZERO)
	var none : Rect2 = sa.call("island")
	_check(none.size.x <= 0.0, "без выреза пятна нет: %s" % none)
	_check(float(sa.call("content_left", 22.0)) == 22.0
			and float(sa.call("content_right", 900.0)) == 900.0,
		"и поля разметки не меняются")

	sa.call("simulate", SIM_L)
	var l : Rect2 = sa.call("island")
	# Пятно стоит ПОСЕРЕДИНЕ края, а не вдоль всего: именно поэтому чип паузы в
	# верхнем углу трогать не нужно, и именно это отличает новую модель от
	# старой, где отступ съедал весь край.
	_check(l.position.x == 0.0 and l.position.y > 1.0
			and l.end.y < CANVAS.y - 1.0,
		"островок слева — пятно посередине края: %s" % l)
	sa.call("simulate", SIM_R)
	var r : Rect2 = sa.call("island")
	_check(r.end.x >= CANVAS.x - 0.5 and r.position.x > CANVAS.x * 0.5,
		"островок справа — пятно у правого края: %s" % r)
	sa.call("simulate", Vector4.ZERO)

# ── Слои остаются как есть ────────────────────────────────────────────────
# Ужимать слой перестали, и это проверяется отдельно: масштаб, поставленный
# «на всякий случай» в одном месте, вернул бы всю прежнюю беду разом и молча.
func _test_layers_untouched() -> void:
	var game : Node = load("res://scenes/game.tscn").instantiate()
	get_root().add_child(game)
	for _i in 6:
		await process_frame
	var sa := get_root().get_node_or_null("SafeArea")
	sa.call("simulate", SIM_L)
	for _i in 4:
		await process_frame
	var moved : Array = []
	_scan_layers(get_root(), moved)
	_check(moved.is_empty(), "ни один слой интерфейса не ужат и не сдвинут: %s"
		% [moved])
	sa.call("simulate", Vector4.ZERO)
	game.queue_free()
	await process_frame

func _scan_layers(n: Node, out: Array) -> void:
	if n is CanvasLayer:
		var cl := n as CanvasLayer
		if not cl.scale.is_equal_approx(Vector2.ONE) \
				or not cl.offset.is_equal_approx(Vector2.ZERO):
			out.append("%s масштаб %s сдвиг %s" % [cl.name, cl.scale, cl.offset])
	for c in n.get_children():
		_scan_layers(c, out)

# ── ПОВОРОТ ────────────────────────────────────────────────────────────────
# Островок переезжает с левого края на правый, и разметка, посчитанная при
# сборке, остаётся от прежнего края. Экран обязан пересобраться САМ, не дожидаясь
# переоткрытия: игрок перевернул телефон и смотрит на тот же экран.
#
# Проверяется не «пришёл ли сигнал», а результат: под пятном снова пусто. Экран
# при этом НЕ ОТКРЫВАЕТСЯ ЗАНОВО — открывается один раз, поворот делается уже
# поверх открытого.
func _test_rotation() -> void:
	var sa := get_root().get_node_or_null("SafeArea")
	var bad : Array = []
	for screen in ["карточки", "лидеры", "настройки", "задания", "слоты",
			"достижения", "пауза"]:
		bad.append_array(await _rotate_one(screen))
	_check(bad.is_empty(), "после поворота под островком пусто: %s"
		% [bad.slice(0, 8)])
	# И обратно: поворот из правого в левый обязан работать так же.
	var back : Array = await _rotate_one("карточки", SIM_R, SIM_L)
	_check(back.is_empty(), "и в обратную сторону: %s" % [back])

func _rotate_one(screen: String, first: Vector4 = SIM_L,
		then: Vector4 = SIM_R) -> Array:
	var sa := get_root().get_node_or_null("SafeArea")
	var game := await _open(screen, first)
	sa.call("simulate", then)
	# Пересборка идёт в обработчике сигнала и занимает кадр-другой.
	for _i in 30:
		get_root().get_tree().paused = false
		await process_frame
	var isl : Rect2 = sa.call("island")
	var hits : Array = []
	_scan(get_root(), isl, screen + " после поворота", hits)
	game.queue_free()
	await process_frame
	sa.call("simulate", Vector4.ZERO)
	return hits

# ── Экраны ────────────────────────────────────────────────────────────────
func _test_screens() -> void:
	for side in ["left", "right"]:
		var bad : Array = []
		for screen in SCREENS:
			bad.append_array(await _one_screen(screen, side))
		_check(bad.is_empty(), "островок %s — под ним пусто: %s"
			% [side, bad.slice(0, 8)])

# Экран поднимается в СВОЁЙ сцене и сносится следом. Открывать их один за другим
# в одном дереве нельзя: они не закрывают друг друга, и список выходит
# накопительным — под островком «оказывается» то, что лежит на экране, открытом
# три шага назад. Ровно так этот тест и врал в первой версии.
func _one_screen(screen: String, side: String) -> Array:
	var sa := get_root().get_node_or_null("SafeArea")
	var game := await _open(screen, SIM_L if side == "left" else SIM_R)
	var isl : Rect2 = sa.call("island")
	var hits : Array = []
	_scan(get_root(), isl, screen, hits)
	game.queue_free()
	await process_frame
	sa.call("simulate", Vector4.ZERO)
	return hits

# Поднять сцену и открыть нужный экран. Каждый раз СВОЯ сцена: экраны не
# закрывают друг друга, и в общем дереве список выходил накопительным — под
# островком «оказывалось» то, что лежит на экране, открытом три шага назад.
func _open(screen: String, sim: Vector4) -> Node:
	var save := get_root().get_node_or_null("SaveData")
	save.set("tutorial_done", true)
	save.set("dollars", 99000)
	save.set("tokens", 83)
	save.set("episodes_done", 5)
	var seen : Dictionary = {}
	for k in ["tour", "start", "quests", "skins", "slots", "leaders", "book", "awards"]:
		seen[k] = true
	save.set("menu_tips_seen", seen)
	var sa := get_root().get_node_or_null("SafeArea")
	sa.call("simulate", sim)

	var game : Node = load("res://scenes/game.tscn").instantiate()
	get_root().add_child(game)
	for _i in 6:
		await process_frame
	var hud : Node = game.get_node_or_null("HUD")
	match screen:
		"сетка":      hud.set("_skins_card_view", false); hud.call("_show_shop")
		"карточки":   hud.set("_skins_card_view", true);  hud.call("_show_shop")
		"задания":    hud.call("_show_quests")
		"лидеры":     hud.call("_show_leaderboard")
		"достижения": hud.call("_show_achievements")
		"настройки":  hud.call("_show_settings_modal", "sound")
		"слоты":      hud.call("_show_slots")
		"забег":      hud.call("_start_game")
		"пауза":
			hud.call("_start_game")
			for _i in 60:
				await process_frame
			hud.call("_open_pause_menu")
		"смерть":
			hud.set("_dollars_this_run", 640)
			hud.set("_elapsed_time", 96.0)
			hud.call("_show_game_over", 420, [], 40, 1)
	for _i in 50:
		get_root().get_tree().paused = false
		await process_frame
	return game

func _scan(n: Node, isl: Rect2, screen: String, out: Array) -> void:
	if n is Control:
		var c := n as Control
		if c.is_visible_in_tree() and c.size.x > 2.0 and c.size.y > 2.0 \
				and c.get_child_count() == 0 and not _clipped(c) and not _is_dev(c):
			var r := _drawn_rect(c)
			if isl.intersects(r) and not _is_backdrop(r):
				var what := c.get_class()
				var t = c.get("text")
				if t is String and String(t) != "":
					what += " «%s»" % String(t).substr(0, 20)
				out.append("%s: %s %.0f..%.0f" % [screen, what, r.position.x, r.end.x])
	for ch in n.get_children():
		_scan(ch, isl, screen, out)

func _drawn_rect(c: Control) -> Rect2:
	var r := Rect2(c.global_position, c.size)
	if c is Label:
		var l := c as Label
		var w : float = minf(r.size.x, l.get_combined_minimum_size().x)
		var x := r.position.x
		match l.horizontal_alignment:
			HORIZONTAL_ALIGNMENT_CENTER: x += (r.size.x - w) * 0.5
			HORIZONTAL_ALIGNMENT_RIGHT:  x += r.size.x - w
		return Rect2(Vector2(x, r.position.y), Vector2(w, r.size.y))
	return r

func _clipped(c: Control) -> bool:
	var n := c.get_parent()
	while n != null:
		if n is ScrollContainer:
			return true
		n = n.get_parent()
	return false

# ── ДЕВ-ЧИПЫ НЕ В СЧЁТ ────────────────────────────────────────────────────
# Они стоят в тех же углах, что и настоящий интерфейс, и под островок попадают
# честно — но в релизе их нет вовсе (`DevFlags.ENABLED`). Двигать ради них
# разметку значит подгонять игру под инструмент. Метку ставит `hud._dev_chip`.
func _is_dev(c: Control) -> bool:
	var n : Node = c
	while n != null:
		if n.is_in_group("dev_ui"):
			return true
		n = n.get_parent()
	return false
