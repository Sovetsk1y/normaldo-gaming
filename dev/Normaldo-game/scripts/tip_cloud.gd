class_name TipCloud
extends RefCounted

# ── ВИД ПОДСКАЗКИ: ОБЛАЧКО ИЗ ДОЛЛАРОВ И РАМКА ──────────────────────────────
# Общий вид ВСЕХ подсказок игры: обучение в забеге, тур по меню, разовые
# подсказки по поводу. Раньше у каждой была своя тёмная плашка — прямоугольник
# из ниоткуда, каких в игре больше нигде нет.
#
# Тут же живёт и вторая половина этого языка — РАМКА вокруг того, о чём речь.
# Держать её отдельно значило бы иметь два места, где решается, как выглядит
# подсказка, и разойтись при первой же правке.
#
# Форма взята у перехода между эпизодами (`level_transition._build_cloud`): там
# экран закрывает масса долларов, и на ней написана сюжетная строка. Это уже
# язык игры — деньги как поверхность, на которой она с тобой разговаривает.
# Здесь та же масса, только размером с реплику.
#
# ── ПОЧЕМУ КУПЮРЫ ПО СЕТКЕ, А НЕ ВРАССЫПНУЮ ─────────────────────────────────
# То же, что и у перехода: случайная россыпь оставляет дыры, сквозь которые
# видно забег, и облачко перестаёт быть поверхностью. Сетка кроет по
# построению, случайность добавляется сдвигом внутри клетки.
#
# ── И ПОЧЕМУ ПОД НИМИ ЗАЛИВКА ПОЛОСАМИ ──────────────────────────────────────
# У знака доллара внутри дырки, и сквозь самую плотную кучу просвечивает фон.
# Заливка тёмно-зелёная — цвета тени между бумажками; чёрная вернула бы ту же
# прямоугольную плашку, от которой уходим. А полосами она набрана потому, что
# нужна ЭЛЛИПСОМ: прямоугольник вылезал бы углами из-под рваного края облака.

const DOLLAR_TEX := preload("res://assets/items/dollar.png")
const UI_FONT    := preload("res://assets/fonts/RussoOne-Regular.ttf")

# Купюра тут мельче, чем в переходе (112 px) — облачко размером с реплику, — но
# НЕ НАМНОГО. При 34 px знак доллара переставал читаться, и облачко выходило
# просто зелёным пятном: узнаётся оно именно по деньгам, а не по цвету.
const BILL_PX  : float = 48.0
const STEP_K   : float = 0.46      # шаг сетки в долях купюры — перекрытие ×2.5
const JITTER_K : float = 0.34      # разброс внутри клетки, доля шага
# Насколько сетка выходит за эллипс. Запас и делает край рваным.
const OVER     : float = 1.24

const BACK_COL  : Color = Color(0.04, 0.10, 0.06)
const BACK_ROWS : int   = 15       # из скольких полос набран эллипс заливки
const BACK_K    : float = 0.94     # заливка чуть уже облака — край остаётся рваным

const BIG_COL   : Color = Color(1.00, 1.00, 1.00)
const SMALL_COL : Color = Color(0.86, 0.92, 0.84)
const HINT_COL  : Color = Color(1.00, 0.85, 0.35)

# Готовое облачко с текстом. Возвращается Control, у которого НАЧАЛО КООРДИНАТ В
# ЦЕНТРЕ: подсказку ставят «вот сюда», а не «вот таким углом».
static func build(big: String, small: String, w: float, h: float,
		hint: String = "") -> Control:
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_fill(root, w, h)
	_bills(root, w, h)

	# Строки раскладываются ПО ЧИСЛУ САМИХ СТРОК, а не по долям высоты. Доли
	# высоты выглядели разумно ровно до третьей строки: подсказка «ДАЛЬШЕ ›»
	# налезла на пояснение, потому что каждая считала своё место сама.
	var lines : Array = [[big, 20, BIG_COL, 26.0]]
	if small != "":
		lines.append([small, 12, SMALL_COL, 18.0])
	if hint != "":
		lines.append([hint, 11, HINT_COL, 16.0])
	var total : float = 0.0
	for l in lines:
		total += float((l as Array)[3])
	var y : float = -total * 0.5
	for l in lines:
		var arr : Array = l
		var lbl := _label(String(arr[0]), int(arr[1]), arr[2] as Color)
		lbl.size     = Vector2(w, float(arr[3]))
		lbl.position = Vector2(-w * 0.5, y)
		root.add_child(lbl)
		y += float(arr[3])
	return root

# Сколько облачко занимает НА САМОМ ДЕЛЕ. Сетка купюр выходит за заданный размер
# (OVER), да и сама купюра торчит за свою клетку, — и подсказка, поставленная по
# номинальной высоте, свисала за нижний край экрана.
static func outer(w: float, h: float) -> Vector2:
	return Vector2(w * OVER + BILL_PX * 0.6, h * OVER + BILL_PX * 0.6)

# Заливка эллипсом, набранная горизонтальными полосами.
static func _fill(root: Control, w: float, h: float) -> void:
	var rx : float = w * 0.5 * BACK_K
	var ry : float = h * 0.5 * BACK_K
	var row_h : float = (ry * 2.0) / float(BACK_ROWS)
	for i in BACK_ROWS:
		var cy : float = -ry + row_h * (float(i) + 0.5)
		var k : float = 1.0 - (cy / ry) * (cy / ry)
		if k <= 0.0:
			continue
		var half : float = rx * sqrt(k)
		var r := ColorRect.new()
		r.color        = BACK_COL
		r.size         = Vector2(half * 2.0, row_h + 1.0)
		r.position     = Vector2(-half, cy - row_h * 0.5)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(r)

# Купюры по сетке, но только те, что попали в эллипс. Иначе облачко выходит
# прямоугольным — то есть той же плашкой, только зелёной.
static func _bills(root: Control, w: float, h: float) -> void:
	var ts : Vector2 = DOLLAR_TEX.get_size()
	var step : float = BILL_PX * STEP_K
	var rx : float = w * 0.5 * OVER
	var ry : float = h * 0.5 * OVER
	var jit : float = step * JITTER_K
	var cols : int = int(ceil(rx * 2.0 / step)) + 1
	var rows : int = int(ceil(ry * 2.0 / step)) + 1
	for cy in rows:
		for cx in cols:
			var p := Vector2(
				-rx + float(cx) * step + randf_range(-jit, jit),
				-ry + float(cy) * step + randf_range(-jit, jit))
			if (p.x / rx) * (p.x / rx) + (p.y / ry) * (p.y / ry) > 1.0:
				continue
			var b := Sprite2D.new()
			b.texture        = DOLLAR_TEX
			b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			var px : float = BILL_PX * randf_range(0.82, 1.18)
			b.scale    = Vector2.ONE * (px / maxf(ts.x, ts.y))
			b.rotation = randf_range(-PI, PI)
			b.position = p
			root.add_child(b)

# ── РАМКА ВОКРУГ ТОГО, О ЧЁМ РЕЧЬ ───────────────────────────────────────────
# Именно рамка, а не заливка: предмет или кнопку надо ПОКАЗАТЬ, а закрашенные
# поверх они перестают быть узнаваемыми. Пульсирует, чтобы её нашли глазами не
# приглядываясь.
const RING_COL : Color = Color(1.00, 0.85, 0.35, 0.95)
const RING_PAD : float = 8.0
const RING_W   : float = 3.0

static func ring(parent: Node, box: Rect2) -> Control:
	var b := box.grow(RING_PAD)
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(root)
	for side in [
		Rect2(b.position.x, b.position.y, b.size.x, RING_W),
		Rect2(b.position.x, b.end.y - RING_W, b.size.x, RING_W),
		Rect2(b.position.x, b.position.y, RING_W, b.size.y),
		Rect2(b.end.x - RING_W, b.position.y, RING_W, b.size.y),
	]:
		var r : Rect2 = side
		var c := ColorRect.new()
		c.color        = RING_COL
		c.position     = r.position
		c.size         = r.size
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(c)
	var tw := root.create_tween().set_loops()
	tw.tween_property(root, "modulate:a", 0.45, 0.55).set_trans(Tween.TRANS_SINE)
	tw.tween_property(root, "modulate:a", 1.00, 0.55).set_trans(Tween.TRANS_SINE)
	return root

static func _label(text: String, size_px: int, col: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", UI_FONT)
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", col)
	# Обводка ОТ КЕГЛЯ, как на переходе: фон под буквами пёстрый, и постоянные
	# 6 px при мелком кегле смыкаются поверх штрихов, превращая слово в пятно.
	l.add_theme_color_override("font_outline_color", Color(0.02, 0.05, 0.03))
	l.add_theme_constant_override("outline_size", int(round(float(size_px) * 0.32)))
	l.text                 = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	return l
