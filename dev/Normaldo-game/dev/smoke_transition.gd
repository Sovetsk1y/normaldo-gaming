extends SceneTree

# Headless-проверка переходов между эпизодами.
#   godot --headless --path . --script res://dev/smoke_transition.gd
#
# Переходов ДВА, и включён один (`LevelTransition.STYLE`):
#   curtain — ЭТОТ: зубчатая шторка с ЧЁРНОЙ подложкой, под ней дождь из купюр;
#   money   — облако денег во весь экран, без шторки вовсе.
#
# Проверяется в первую очередь ВКЛЮЧЁННЫЙ. Тест, который целиком гоняет
# выключенную ветку, зелен ровно настолько, насколько это никому не нужно:
# сломать можно то, что видит игрок, а смотрит тест в другую сторону. Отложенный
# стиль проверяется тем, что он жив и собирается, — не больше.
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
#   3. НАДПИСЬ ВИСИТ ДОСТАТОЧНО, ЧТОБЫ ЕЁ ПРОЧИТАЛИ. На занавесе две строки, на
#      карточке уровня три, и полторы секунды на них — это «успел заметить, что
#      что-то написано». Число тут не украшение, и уехать вниз оно может от
#      любой правки таймингов.
#
# И четвёртая, общая обоим: отложенный стиль обязан ОСТАВАТЬСЯ рабочим.

const TRANSITION := preload("res://scripts/level_transition.gd")

var _fails  : int = 0
var _checks : int = 0
const EXPECTED_CHECKS : int = 23

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

	print("── Включён занавес с чёрной подложкой ──")
	_check(TRANSITION.STYLE == "curtain",
		"включён занавес, а не облако: %s" % TRANSITION.STYLE)
	# ЧЁРНАЯ, А НЕ ПРОСТО ТЁМНАЯ. У облака подложка была зелёная, «цвета денег»,
	# и вернуться к ней незаметно можно одной правкой цвета.
	var cc : Color = TRANSITION.COL_CURTAIN
	_check(cc.r < 0.12 and cc.g < 0.12 and cc.b < 0.12
			and absf(cc.r - cc.g) < 0.05 and absf(cc.g - cc.b) < 0.05,
		"подложка занавеса чёрная и без оттенка: %s" % [cc])

	print("── Надпись висит достаточно, чтобы её прочитать ──")
	# Две строки на занавесе и три на карточке уровня. Порог 3 c — это не «как
	# сейчас», а сколько нужно на чтение: ниже него надпись успевают заметить, но
	# не прочесть.
	_check(float(TRANSITION.HOLD_T) >= 3.0,
		"занавес держит надпись %.1f c" % float(TRANSITION.HOLD_T))
	var hud_src : String = FileAccess.get_file_as_string("res://scripts/hud.gd")
	var card_t : float = _const_of(hud_src, "LEVEL_CARD_T")
	# И КАРТОЧКА УРОВНЯ ЗАКРЫВАЕТ ЭКРАН НАСМЕРТЬ. Стояло 0.85, и это была не
	# мягкость, а дырка: карточка обещает закрыть подмену полосы фона, а на
	# пятнадцать процентов подмена сквозь неё была видна. Глазами такое почти не
	# ловится, поэтому ловим числом.
	_check(hud_src.contains("tween_property(dim, \"color:a\", 1.0"),
		"карточка уровня доводит подложку до непрозрачной")
	_check(card_t >= 3.0, "карточка уровня держит свою %.1f c" % card_t)
	# И ОДИНАКОВО. Игрок видит их как одно место игры; разная задержка читается
	# как «тут почему-то торопят».
	_check(absf(card_t - float(TRANSITION.HOLD_T)) < 1.0,
		"и оба держат примерно поровну: %.1f и %.1f"
			% [float(TRANSITION.HOLD_T), card_t])
	# Отложенный стиль НЕ УДАЛЁН: вернуться к нему — одна константа, но только
	# если функция ещё жива.
	print("── Отложенный стиль жив ──")
	var t0 : Node = TRANSITION.new()
	get_root().add_child(t0)
	_check(t0.has_method("_run_curtain"), "занавес на месте")
	_check(t0.has_method("_run_money"), "и отложенное облако тоже")
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

	# ── ЗАНАВЕС: смена эпизода отдаётся ЗАКРЫТОМУ экрану ────────────────────
	# Это ВКЛЮЧЁННЫЙ путь, и здесь проверка стоит на том же, на чём у облака:
	# `on_covered` обязан прийти, когда шторка сомкнулась полностью. У занавеса
	# «полностью» — это не положение узла, а `factor` шейдера: при единице
	# треугольники сошлись и экрана под ними не видно.
	print("── Занавес: on_covered ──")
	var tc : Node = TRANSITION.new()
	get_root().add_child(tc)
	var c_done  := [false]
	var c_factor := [-1.0]
	tc.call("_run_curtain", "НЕМНОГО ПОЗДНЕЕ…", func() -> void:
		c_done[0] = true
		var r : ColorRect = tc.get("_rect")
		if is_instance_valid(r) and r.material != null:
			c_factor[0] = float((r.material as ShaderMaterial)
				.get_shader_parameter("factor")),
		"Найди дорогу к клубу")
	var c_wait := await _await_flag(c_done, 6.0)
	_check(c_done[0], "занавес отдал смену эпизода через %.1f c" % c_wait)
	_check(c_factor[0] > 0.99,
		"и ровно когда шторка сомкнулась: factor=%.3f" % c_factor[0])

	# ПОДЛОЖКА ЗАНАВЕСА — та самая чёрная, и берёт её шейдер из COL_CURTAIN.
	# Проверяется не константа (её сверили выше), а то, что она ДОЕХАЛА до
	# материала: разъехаться эти двое могут молча.
	var crect : ColorRect = tc.get("_rect")
	var base : Color = Color(1, 0, 1)
	if is_instance_valid(crect) and crect.material != null:
		base = (crect.material as ShaderMaterial).get_shader_parameter("base_color")
	_check(base.is_equal_approx(TRANSITION.COL_CURTAIN),
		"и шейдер красит её тем же чёрным: %s" % [base])

	# Деньги летят ПОД закрытым занавесом, а не поверх живого забега.
	var cbills := 0
	for ch in tc.get_children():
		if ch is Sprite2D:
			cbills += 1
	_check(cbills > 100, "и под ней летят деньги: %d купюр" % cbills)
	tc.queue_free()
	await process_frame

	# ── Смена эпизода отдаётся ЗАКРЫТОМУ экрану (отложенное облако) ─────────
	print("── Облако: on_covered ──")
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

# Достать число из константы по исходнику. Числа таймингов живут в hud.gd, а
# preload'ить его в тесте-SceneTree нельзя: он ссылается на автолоады, которых в
# этот момент ещё нет, и тест не падает, а тихо разваливается.
func _const_of(src: String, name: String) -> float:
	for line in src.split("\n"):
		var t := String(line).strip_edges()
		if t.begins_with("const " + name):
			return float(t.get_slice("=", 1).strip_edges())
	return -1.0

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
