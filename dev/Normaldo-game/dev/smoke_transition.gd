extends SceneTree

# Headless-проверка переходов между эпизодами.
#   godot --headless --path . --script res://dev/smoke_transition.gd
#
# Переходов ДВА, и включён один (`LevelTransition.STYLE`):
#   money   — облако денег во весь экран, без шторки вовсе;
#   curtain — прежняя зубчатая шторка, под ней дождь из купюр.
#
# У перехода одна обязанность, и она не про красоту: ПОД НИМ МЕНЯЮТ ЭПИЗОД.
# Значит проверять надо две вещи, и обе ломаются молча:
#
#   1. `on_covered` зовётся РОВНО ТОГДА, когда экран уже закрыт. Позови раньше —
#      и игрок увидит, как под переходом меняется фон; не позови вовсе — эпизод
#      не сменится, а переход отработает как ни в чём не бывало.
#   2. ЭКРАН ЗАКРЫТ ПО-НАСТОЯЩЕМУ. У знака доллара внутри дырки, и случайная
#      россыпь оставляет просветы — мигающие окошки в живой забег ровно в тот
#      момент, когда за ними подменяют фон. Здесь это меряется покрытием сетки,
#      а не на глаз.
#
# И третья, общая обоим: оба стиля обязаны ОСТАВАТЬСЯ рабочими. Старый не
# удалён намеренно — он гарантирует закрытие сплошной заливкой, и вернуться к
# нему это одна константа.

const TRANSITION := preload("res://scripts/level_transition.gd")

var _fails  : int = 0
var _checks : int = 0
const EXPECTED_CHECKS : int = 14

func _check(ok: bool, what: String) -> void:
	_checks += 1
	if ok:
		print("  ok   ", what)
	else:
		_fails += 1
		print("  FAIL ", what)

func _initialize() -> void:
	var game : Node = load("res://scenes/game.tscn").instantiate()
	get_root().add_child(game)
	await process_frame
	var vp : Vector2 = get_root().get_visible_rect().size

	print("── Оба стиля на месте ──")
	_check(TRANSITION.STYLE in ["money", "curtain"],
		"включён известный стиль: %s" % TRANSITION.STYLE)
	# Старый НЕ УДАЛЁН: он рабочий и гарантирует закрытие сплошной заливкой.
	# Вернуться к нему — одна константа, но только если функция ещё жива.
	var t0 : Node = TRANSITION.new()
	get_root().add_child(t0)
	_check(t0.has_method("_run_curtain"), "прежняя шторка никуда не делась")
	_check(t0.has_method("_run_money"), "и новое облако есть")
	t0.queue_free()

	# ── Облако кроет экран ──────────────────────────────────────────────────
	# Купюры стоят по СЕТКЕ, и кроет она по построению. Проверяется само
	# построение: шаг меньше купюры, разброс внутри клетки меньше половины шага.
	# Случайная россыпь при том же числе купюр оставляла бы около пяти процентов
	# экрана пустыми — и это не абстракция, а окошки в живой забег.
	print("── Облако кроет экран ──")
	var t : Node = TRANSITION.new()
	get_root().add_child(t)
	await process_frame
	var step : float = float(t.CLOUD_BILL_PX) * float(t.CLOUD_STEP_K)
	_check(step < float(t.CLOUD_BILL_PX),
		"шаг сетки меньше купюры: %.0f против %.0f" % [step, float(t.CLOUD_BILL_PX)])
	_check(float(t.CLOUD_JITTER_K) < 0.5,
		"разброс внутри клетки меньше половины шага: %.2f" % float(t.CLOUD_JITTER_K))

	var cloud : Node2D = t.call("_build_cloud", vp)
	get_root().add_child(cloud)
	await process_frame
	var bills : Array = cloud.get_children()
	_check(bills.size() >= 200, "купюр сотни: %d" % bills.size())

	# И ОБЛАКО ШИРЕ ЭКРАНА с обеих сторон: край, совпавший с краем экрана,
	# показался бы ровной линией, по которой видно, что это прямоугольник.
	var minx : float =  1e9
	var maxx : float = -1e9
	var miny : float =  1e9
	var maxy : float = -1e9
	for b in bills:
		var p : Vector2 = (b as Node2D).position
		minx = minf(minx, p.x); maxx = maxf(maxx, p.x)
		miny = minf(miny, p.y); maxy = maxf(maxy, p.y)
	_check(maxx - minx > vp.x * 1.3,
		"облако шире экрана: %.0f при экране %.0f" % [maxx - minx, vp.x])
	_check(maxy - miny > vp.y * 1.2,
		"и выше экрана: %.0f при экране %.0f" % [maxy - miny, vp.y])

	# ПЛОТНОСТЬ МЕРЯЕТСЯ ПЕРЕКРЫТИЕМ ПО ПЛОЩАДИ, а не «в каждой клетке есть
	# купюра». Первая версия считала именно клетки — и была неправа: разброс
	# уводит центр купюры в соседнюю клетку, своя числится пустой, хотя телом
	# купюра (112 px против клетки в 52) кроет её с запасом. Тест показывал 87 из
	# 112 там, где дыр не было.
	#
	# И главное: СПЛОШНОСТЬ ГАРАНТИРУЕТ НЕ КУЧА, А ПОДЛОЖКА — у знака доллара
	# внутри дырки, и никакая плотность не закроет их полностью. Куча отвечает за
	# вид, подложка за то, что подмену эпизода не видно. Поэтому здесь проверяется
	# ровно то, за что куча и отвечает: что её хватает, чтобы подложка не читалась
	# как пустое поле между редкими бумажками.
	var seen : float = 0.0
	var glyph : Rect2i = ItemSizing.content_rect(load("res://assets/items/dollar.png"))
	var fill : float = 0.45   # доля рамки, занятая самим знаком
	for b in bills:
		var p : Vector2 = (b as Node2D).position + vp * 0.5
		if p.x < -step or p.y < -step or p.x > vp.x + step or p.y > vp.y + step:
			continue
		var sc : float = (b as Node2D).scale.x
		seen += float(glyph.size.x) * float(glyph.size.y) * sc * sc * fill
	var overdraw : float = seen / (vp.x * vp.y)
	_check(overdraw >= 2.0,
		"купюры перекрывают экран с запасом: ×%.1f" % overdraw)
	cloud.queue_free()

	# ── Смена эпизода отдаётся ЗАКРЫТОМУ экрану ─────────────────────────────
	print("── on_covered ──")
	var covered := [false]
	var when_x  := [0.0]
	t.call("_run_money", "НЕМНОГО ПОЗДНЕЕ…", func() -> void:
		covered[0] = true
		# Где было облако в этот момент: если оно ещё не доехало, экран открыт.
		var c : Node2D = _cloud_of(t)
		when_x[0] = c.position.x if is_instance_valid(c) else -9999.0,
		"Найди дорогу к клубу")

	var waited := await _await_flag(covered, 6.0)
	_check(covered[0], "переход отдал смену эпизода через %.1f c" % waited)
	_check(absf(when_x[0] - vp.x * 0.5) < 6.0,
		"и ровно тогда, когда облако встало по центру: x=%.0f при центре %.0f"
			% [when_x[0], vp.x * 0.5])

	# Подложка цвета денег, а не чёрная: у знака доллара внутри дырки, и чёрная
	# вернула бы ровно тот чёрный экран, ради ухода от которого всё и делалось.
	var back : ColorRect = _back_of(t)
	_check(back != null and back.color.g > back.color.r + 0.02,
		"подложка зеленее, чем краснее: %s" % [back.color if back != null else "нет"])
	_check(back != null and back.color.a > 0.9,
		"и на закрытом экране она непрозрачна: %.2f"
			% (back.color.a if back != null else -1.0))

	# ── Текст уезжает ВМЕСТЕ с деньгами ─────────────────────────────────────
	# Растаявший на месте текст читался бы как «надпись погасили», а он часть
	# облака и обязан уйти с ним.
	print("── Текст едет с облаком ──")
	var cl : Node2D = _cloud_of(t)
	var labels : Array = []
	if is_instance_valid(cl):
		for c in cl.get_children():
			if c is Label:
				labels.append(c)
	_check(labels.size() >= 2, "надписи лежат В ОБЛАКЕ: %d" % labels.size())

	_finish()

func _cloud_of(t: Node) -> Node2D:
	for c in t.get_children():
		if c is Node2D and not (c is Control) and c.get_child_count() > 50:
			return c
	return null

func _back_of(t: Node) -> ColorRect:
	for c in t.get_children():
		if c is ColorRect:
			return c
	return null

func _await_flag(flag: Array, limit: float) -> float:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(limit * 1000.0):
		if bool(flag[0]):
			break
		await process_frame
	return float(Time.get_ticks_msec() - t0) / 1000.0

func _finish() -> void:
	print("")
	if _checks < EXPECTED_CHECKS:
		print("ПРОВАЛ: проверок %d из %d — тест не отработал" % [_checks, EXPECTED_CHECKS])
		quit(1)
		return
	if _fails == 0:
		print("ВСЁ ЗЕЛЁНОЕ (проверок: %d)" % _checks)
	else:
		print("ПРОВАЛОВ: ", _fails)
	quit(1 if _fails > 0 else 0)
