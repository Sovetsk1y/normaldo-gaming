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

const DIM : Color = Color(0.0, 0.0, 0.0, 0.72)

# Облачко подсказки — того же размера, что и в забеге, чтобы тур не выглядел
# другой игрой.
const TIP_W : float = 360.0
const TIP_H : float = 108.0

signal finished

var _stops : Array = []
var _idx   : int   = 0
var _key   : String = "tour"
var _on_hole : Callable = Callable()
var _body  : Control = null

# `stops` — список словарей { rect: Rect2, big: String, small: String }.
# Прямоугольники, а не сами кнопки: тур живёт своим слоем и переживает
# перестройку меню, а ссылка на чужой Control — нет.
# `key` — под каким именем запомнить показанное в `SaveData.menu_tips_seen`.
# Тот же узел работает и разовой подсказкой по поводу: одна остановка вместо
# трёх, свой ключ. Заводить ради неё второй вид всплывашки значило бы иметь два
# места, где решается, как подсказка выглядит.
# `on_hole` — что сделать, когда игрок ткнул В САМУ подсвеченную кнопку. Если он
# задан, тур закрывается ТОЛЬКО этим тапом: мимо кнопки экран не реагирует.
#
# Нужно ровно первой подсказке — «ДАВАЙ СРАЗУ К ДЕЛУ!». Её задача не сообщить, а
# ДОВЕСТИ до первого забега, и закрываемая тапом куда попало она эту задачу не
# решает: игрок смахивает её вслепую и остаётся в меню, из которого его как раз
# и уводили.
static func play(host: Node, stops: Array, key: String = "tour",
		on_hole: Callable = Callable()) -> MenuTour:
	if host == null or stops.is_empty():
		return null
	var t := MenuTour.new()
	t.name    = "MenuTour"
	t._stops  = stops
	t._key    = key
	t._on_hole = on_hole
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

	TipCloud.ring(_body, hole)
	_caption(stop, hole, vp)

	if _on_hole.is_valid():
		# ЗАКРЫВАЕТ ТОЛЬКО ТАП ПО КНОПКЕ. Экран вокруг ест ввод и не реагирует:
		# такая подсказка не сообщает, а ведёт, и смахнуть её мимо цели нельзя.
		var eat := Control.new()
		eat.size         = vp
		eat.mouse_filter = Control.MOUSE_FILTER_STOP
		_body.add_child(eat)
		var hit := Button.new()
		hit.flat       = true
		hit.focus_mode = Control.FOCUS_NONE
		hit.position   = hole.position
		hit.size       = hole.size
		hit.pressed.connect(func() -> void:
			var cb := _on_hole
			_done()
			if cb.is_valid():
				cb.call())
		_body.add_child(hit)
	else:
		# Тап куда угодно — дальше. Отдельной кнопки «ДАЛЬШЕ» нет намеренно:
		# искать её глазами в затемнённом экране дольше, чем ткнуть в него.
		var tap := Button.new()
		tap.flat       = true
		tap.focus_mode = Control.FOCUS_NONE
		tap.size       = vp
		tap.pressed.connect(func() -> void: _show(_idx + 1))
		_body.add_child(tap)

	_body.modulate = Color(1, 1, 1, 0.0)
	var tw := _body.create_tween()
	tw.tween_property(_body, "modulate:a", 1.0, 0.18)

# Подпись встаёт ПОД кнопкой, а если та у нижнего края — над ней. Иначе текст
# уезжает за экран ровно у тех кнопок, что стоят внизу.
func _caption(stop: Dictionary, hole: Rect2, vp: Vector2) -> void:
	var below : bool = hole.end.y + TipCloud.outer(TIP_W, TIP_H).y < vp.y
	var y : float = (hole.end.y + 8.0) if below else (hole.position.y - TIP_H - 8.0)
	var last : bool = _idx >= _stops.size() - 1
	var hint : String = "ПОНЯТНО" if last else "ДАЛЬШЕ ›"
	if _on_hole.is_valid():
		# «ПОНЯТНО» на ведущей подсказке обещает, что её можно просто закрыть, —
		# а закрыть её можно ровно одним способом, тапом по кнопке.
		hint = "▼ ТАП ▼"
	var cloud := TipCloud.build(String(stop.get("big", "")),
		String(stop.get("small", "")), TIP_W, TIP_H, hint)
	var out := TipCloud.outer(TIP_W, TIP_H)
	cloud.position = Vector2(
		clampf(hole.get_center().x, out.x * 0.5, vp.x - out.x * 0.5),
		clampf(y + TIP_H * 0.5, out.y * 0.5, vp.y - out.y * 0.5))
	_body.add_child(cloud)

func _done() -> void:
	SaveData.menu_tips_seen[_key] = true
	SaveData._save()
	finished.emit()
	queue_free()
