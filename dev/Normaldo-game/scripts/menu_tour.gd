extends CanvasLayer
class_name MenuTour

# ── ОБУЧЕНИЕ ПО ГЛАВНОМУ МЕНЮ ────────────────────────────────────────────────
# См. /Концепция/Обучение — первый забег и меню.md
#
# Показывается ОДИН РАЗ, когда игрок вернулся в меню после первого забега.
#
# ── ПОЧЕМУ ТРИ ОСТАНОВКИ, А НЕ СЕМЬ ─────────────────────────────────────────
# Тур по всем кнопкам подряд — то самое, что прощёлкивают не читая: игроку
# показывают то, чем он не собирается пользоваться прямо сейчас, и он листает,
# чтобы наконец начать играть.
#
# Поэтому здесь только то, что нужно на второй минуте жизни: откуда начинается
# забег, где лежит награда за только что сыгранное и куда девать собранные
# доллары. Остальные кнопки объясняют себя бейджами — красный кружок на
# «ЗАДАНИЯХ» говорит «сюда стоит зайти» лучше любой всплывашки.
#
# ── ЗАТЕМНЕНИЕ БЕЗ ШЕЙДЕРА ──────────────────────────────────────────────────
# Дырка в затемнении собрана из ЧЕТЫРЁХ прямоугольников вокруг неё, а не
# вырезана шейдером. Игра идёт в режиме совместимости GL, шейдерная маска на
# части устройств — это лишний риск ради эффекта, который тут виден полсекунды.

const UI_FONT := preload("res://assets/fonts/RussoOne-Regular.ttf")

const DIM       : Color = Color(0.0, 0.0, 0.0, 0.72)
const RING      : Color = Color(1.00, 0.85, 0.35, 0.95)
const RING_PAD  : float = 8.0     # насколько рамка шире самой кнопки
const RING_W    : float = 3.0

signal finished

var _stops : Array = []
var _idx   : int   = 0
var _body  : Control = null

# `stops` — список словарей { rect: Rect2, big: String, small: String }.
# Прямоугольники, а не сами кнопки: тур живёт своим слоем и переживает
# перестройку меню, а ссылка на чужой Control — нет.
static func play(host: Node, stops: Array) -> MenuTour:
	if host == null or stops.is_empty():
		return null
	var t := MenuTour.new()
	t.name   = "MenuTour"
	t._stops = stops
	host.add_child(t)
	return t

func _ready() -> void:
	SafeArea.apply(self)
	layer        = 130
	process_mode = Node.PROCESS_MODE_ALWAYS
	_show(0)

func _show(idx: int) -> void:
	_idx = idx
	if _idx >= _stops.size():
		_done()
		return
	if is_instance_valid(_body):
		_body.queue_free()
	var vp := get_viewport().get_visible_rect().size
	var stop : Dictionary = _stops[_idx]
	var hole : Rect2 = stop.get("rect", Rect2()) as Rect2

	_body = Control.new()
	_body.size         = vp
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_body)

	# Четыре полосы вокруг дырки. Пустые (нулевой ширины) не добавляем — кнопка
	# у самого края экрана дала бы вырожденный прямоугольник.
	for band in [
		Rect2(0.0, 0.0, vp.x, hole.position.y),
		Rect2(0.0, hole.end.y, vp.x, vp.y - hole.end.y),
		Rect2(0.0, hole.position.y, hole.position.x, hole.size.y),
		Rect2(hole.end.x, hole.position.y, vp.x - hole.end.x, hole.size.y),
	]:
		var r : Rect2 = band
		if r.size.x <= 0.0 or r.size.y <= 0.0:
			continue
		var c := ColorRect.new()
		c.color        = DIM
		c.position     = r.position
		c.size         = r.size
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_body.add_child(c)

	_ring(hole)
	_caption(stop, hole, vp)

	# Тап куда угодно — дальше. Отдельной кнопки «ДАЛЬШЕ» нет намеренно: искать
	# её глазами в затемнённом экране дольше, чем ткнуть в него.
	var tap := Button.new()
	tap.flat       = true
	tap.focus_mode = Control.FOCUS_NONE
	tap.size       = vp
	tap.pressed.connect(func() -> void: _show(_idx + 1))
	_body.add_child(tap)

	_body.modulate = Color(1, 1, 1, 0.0)
	var tw := _body.create_tween()
	tw.tween_property(_body, "modulate:a", 1.0, 0.18)

# Рамка вокруг кнопки — четыре полоски, пульсируют. Именно рамка, а не заливка:
# кнопку надо ПОКАЗАТЬ, а закрашенная поверх она перестаёт быть узнаваемой.
func _ring(hole: Rect2) -> void:
	var box := hole.grow(RING_PAD)
	var ring := Control.new()
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.add_child(ring)
	for side in [
		Rect2(box.position.x, box.position.y, box.size.x, RING_W),
		Rect2(box.position.x, box.end.y - RING_W, box.size.x, RING_W),
		Rect2(box.position.x, box.position.y, RING_W, box.size.y),
		Rect2(box.end.x - RING_W, box.position.y, RING_W, box.size.y),
	]:
		var r : Rect2 = side
		var c := ColorRect.new()
		c.color        = RING
		c.position     = r.position
		c.size         = r.size
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ring.add_child(c)
	var tw := ring.create_tween().set_loops()
	tw.tween_property(ring, "modulate:a", 0.45, 0.55).set_trans(Tween.TRANS_SINE)
	tw.tween_property(ring, "modulate:a", 1.00, 0.55).set_trans(Tween.TRANS_SINE)

# Подпись встаёт ПОД кнопкой, а если та у нижнего края — над ней. Иначе текст
# уезжает за экран ровно у тех кнопок, что стоят внизу.
func _caption(stop: Dictionary, hole: Rect2, vp: Vector2) -> void:
	var below : bool = hole.end.y + 78.0 < vp.y
	var y : float = (hole.end.y + 16.0) if below else (hole.position.y - 74.0)
	var root := Control.new()
	root.position     = Vector2(clampf(hole.get_center().x, 170.0, vp.x - 170.0), y)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.add_child(root)

	# Плашка обязательна: подсветка снимает затемнение вокруг кнопки, и подпись
	# у большой кнопки ложится на неприглушённое меню — на логотип, на надпись
	# «нажмите, чтобы начать». Обводки букв на такой мешанине не хватает.
	var plate := ColorRect.new()
	plate.color        = Color(0.04, 0.04, 0.07, 0.80)
	plate.size         = Vector2(360.0, 70.0)
	plate.position     = Vector2(-180.0, -4.0)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(plate)

	var big := _label(String(stop.get("big", "")), 20)
	big.position = Vector2(-260.0, 0.0)
	root.add_child(big)

	var small := _label(String(stop.get("small", "")), 12)
	small.modulate = Color(0.82, 0.82, 0.88)
	small.position = Vector2(-260.0, 26.0)
	root.add_child(small)

	var last : bool = _idx >= _stops.size() - 1
	var more := _label("ПОНЯТНО" if last else "ДАЛЬШЕ ›", 11)
	more.modulate = Color(1.00, 0.85, 0.35)
	more.position = Vector2(-260.0, 48.0)
	root.add_child(more)

func _label(text: String, size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", UI_FONT)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(1, 1, 1))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", 6)
	l.text                 = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size                 = Vector2(520.0, 24.0)
	l.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	return l

func _done() -> void:
	SaveData.menu_tips_seen["tour"] = true
	SaveData._save()
	finished.emit()
	queue_free()
