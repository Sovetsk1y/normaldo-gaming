class_name FatGauge
extends Control

# ── Индикатор жира: череп и F A T ────────────────────────────────────────────
# Раньше на этом месте стояли ДВА СКИНА — текущее состояние жира и следующее.
# Проблема была не в красоте: голова скина и так на экране, крупная и в центре,
# а в углу висели её же две копии. Индикатор отвечал на вопрос «как я выгляжу»,
# который игрок и без него видит, и молчал про тот единственный, который в
# забеге важен: сколько у меня осталось запаса.
#
# Теперь это четыре лампы: 💀 F A T. Лампа i горит, когда жир дошёл до i.
#
#   жир 1 — горит только ЧЕРЕП: следующий удар убивает;
#   жир 2 — плюс F;  жир 3 — плюс A;  жир 4 — плюс T.
#
# Череп не украшение, а предупреждение, поэтому в одиночестве он ПУЛЬСИРУЕТ
# красным: «запаса нет». Стоит загореться первой букве — пульс гаснет, череп
# становится обычной костью в ряду.
#
# Состояние, которое ещё не открыто уровнем скина, показывается ЗАМКОМ. Замок
# честнее пустой ячейки: пустая читается как «сюда я ещё не дорос», а замок —
# как «сюда не пускают», и это разные сообщения.
#
# Череп, буквы и замок нарисованы кодом, а не картинками: это три фигуры из
# прямоугольников, и заводить под них ассеты значило бы завести ещё и их
# импорт, размеры и путаницу «почему замок в жире не такой, как в магазине».
#
# См. /Концепция/Интерфейс забега.md → «Полоса жира»

const LAMPS  : int   = 4
const GAP    : float = 4.0

const COL_LIT      : Color = Color(1.00, 0.62, 0.12)   # горит: тот же оранжевый, что у полосы
const COL_LIT_MAX  : Color = Color(1.00, 0.86, 0.22)   # последняя лампа — золотом
const COL_DIM      : Color = Color(0.30, 0.30, 0.34)   # не горит
const COL_BONE     : Color = Color(0.92, 0.92, 0.86)   # череп
const COL_DANGER   : Color = Color(1.00, 0.22, 0.18)   # череп в одиночестве
const COL_CELL     : Color = Color(0.10, 0.10, 0.13, 0.85)
const COL_LOCK     : Color = Color(0.55, 0.55, 0.62)

const POP_T   : float = 0.26   # лампа загорелась
const DROP_T  : float = 0.34   # лампу сбили
const PULSE_T : float = 0.55   # полупериод тревожного пульса черепа

var _cell   : float = 24.0
var _lamps  : Array = []       # Array[Lamp]
var _fat    : int = 0
var _max    : int = 3
var _ready_done : bool = false

# ── Лампа ────────────────────────────────────────────────────────────────────
# Отдельным узлом, а не куском общего _draw: каждой нужна СВОЯ анимация —
# масштаб, цвет, падение вниз. Тюины умеют дёргать свойства узла и не умеют
# элементы массива внутри чужого _draw.
class Lamp extends Control:
	var kind   : int   = 0        # 0 — череп, иначе индекс буквы
	var letter : String = ""
	var lit    : bool  = false
	var locked : bool  = false
	var glow   : float = 0.0      # 0..1, подсветка в момент срабатывания

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, FatGauge.COL_CELL, true)
		var body : Color = FatGauge.COL_DIM
		if lit:
			body = FatGauge.COL_BONE if kind == 0 else FatGauge.COL_LIT
		if glow > 0.0:
			body = body.lerp(Color(1, 1, 1), glow)
		if locked:
			_draw_lock()
			return
		if kind == 0:
			_draw_skull(body)
		else:
			_draw_letter(body)
		# Рамка: у горящей лампы своим цветом, у погасшей — чуть темнее фона.
		var edge : Color = body if lit else Color(0.18, 0.18, 0.22)
		draw_rect(r, edge, false, 1.0)

	# Череп из прямоугольников: свод, две глазницы, нос и зубы. Кругов
	# намеренно нет — вся игра нарисована пикселями, и гладкий овал в углу
	# читался бы как чужой элемент.
	func _draw_skull(col: Color) -> void:
		var w := size.x
		var h := size.y
		var u := w / 12.0                       # «пиксель» черепа
		var dome := Rect2(u * 2.0, u * 2.0, u * 8.0, u * 6.0)
		draw_rect(dome, col, true)
		var eye_w := u * 2.0
		draw_rect(Rect2(u * 3.0, u * 4.0, eye_w, u * 2.0), FatGauge.COL_CELL, true)
		draw_rect(Rect2(u * 7.0, u * 4.0, eye_w, u * 2.0), FatGauge.COL_CELL, true)
		draw_rect(Rect2(u * 5.5, u * 6.0, u, u), FatGauge.COL_CELL, true)   # нос
		# Челюсть с промежутками — по ним череп и опознаётся с двадцати пикселей.
		draw_rect(Rect2(u * 3.5, h - u * 3.5, u * 5.0, u * 2.0), col, true)
		draw_rect(Rect2(u * 5.0, h - u * 3.5, u * 0.7, u * 2.0), FatGauge.COL_CELL, true)
		draw_rect(Rect2(u * 6.5, h - u * 3.5, u * 0.7, u * 2.0), FatGauge.COL_CELL, true)

	func _draw_letter(col: Color) -> void:
		var f : Font = ThemeDB.fallback_font
		var fs : int = int(size.y * 0.62)
		var s := f.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		draw_string(f, Vector2((size.x - s.x) * 0.5, (size.y + s.y * 0.62) * 0.5),
			letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)

	func _draw_lock() -> void:
		var w := size.x
		var h := size.y
		var bw := w * 0.46
		var bh := h * 0.34
		var bx := (w - bw) * 0.5
		var by := h * 0.52
		# Дужка — три прямоугольника: две стойки и перемычка.
		var sw := w * 0.09
		draw_rect(Rect2(bx + sw, by - h * 0.24, sw, h * 0.24), FatGauge.COL_LOCK, true)
		draw_rect(Rect2(bx + bw - sw * 2.0, by - h * 0.24, sw, h * 0.24), FatGauge.COL_LOCK, true)
		draw_rect(Rect2(bx + sw, by - h * 0.28, bw - sw * 2.0, sw), FatGauge.COL_LOCK, true)
		draw_rect(Rect2(bx, by, bw, bh), FatGauge.COL_LOCK, true)

# ── Сборка ───────────────────────────────────────────────────────────────────

func setup(cell: float) -> void:
	_cell = cell
	custom_minimum_size = Vector2(LAMPS * cell + (LAMPS - 1) * GAP, cell)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in LAMPS:
		var l := Lamp.new()
		l.kind         = i
		l.letter       = ["", "F", "A", "T"][i]
		l.size         = Vector2(cell, cell)
		l.position     = Vector2(i * (cell + GAP), 0.0)
		l.pivot_offset = Vector2(cell, cell) * 0.5
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(l)
		_lamps.append(l)
	_ready_done = true
	_paint()

func gauge_size() -> Vector2:
	return Vector2(LAMPS * _cell + (LAMPS - 1) * GAP, _cell)

# Состояние снаружи: сколько жира и до какого он вообще открыт уровнем скина.
# `animate` выключается на первой отрисовке и на смене скина — там показывать
# «загорелось» нечего, состояние просто такое.
func set_state(fat: int, max_fat: int, animate: bool = true) -> void:
	if not _ready_done:
		return
	var prev := _fat
	_fat = clampi(fat, 0, LAMPS - 1)
	_max = clampi(max_fat, 0, LAMPS - 1)
	_paint()
	if not animate or prev == _fat:
		return
	if _fat > prev:
		for i in range(prev + 1, _fat + 1):
			_pop(i)
	else:
		# Сбили: гаснут ВСЕ лампы выше нового уровня, и каждая падает вниз.
		for i in range(_fat + 1, prev + 1):
			_drop(i)
		_shake()

func _paint() -> void:
	for i in _lamps.size():
		var l : Lamp = _lamps[i]
		l.lit    = i <= _fat
		l.locked = i > _max
		l.queue_redraw()
	_danger_pulse(_fat == 0)

# Загорелась: короткий выброс масштаба и белая вспышка. Вспышка нужна, чтобы
# лампа сообщала «ЭТО ТОЛЬКО ЧТО СЛУЧИЛОСЬ», а не просто оказалась зажжённой.
func _pop(i: int) -> void:
	if i < 0 or i >= _lamps.size():
		return
	var l : Lamp = _lamps[i]
	l.scale = Vector2.ONE * 1.7
	l.glow  = 1.0
	l.queue_redraw()
	var tw := l.create_tween()
	if tw == null:
		l.scale = Vector2.ONE
		l.glow  = 0.0
		return
	tw.tween_property(l, "scale", Vector2.ONE, POP_T)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_method(func(v: float) -> void:
		if is_instance_valid(l):
			l.glow = v
			l.queue_redraw(), 1.0, 0.0, POP_T)

# Сбили: лампа краснеет, распухает и ПАДАЕТ вниз, гаснув по дороге, — после чего
# возвращается на место уже погасшей. Падение и есть «скинулось»: простое
# гашение цвета читалось бы как «моргнуло», а не как потеря.
func _drop(i: int) -> void:
	if i < 0 or i >= _lamps.size():
		return
	var l : Lamp = _lamps[i]
	var home := l.position
	l.lit = true                       # падает ещё горящей
	l.queue_redraw()
	l.modulate = COL_DANGER
	var tw := l.create_tween()
	if tw == null:
		l.position = home
		l.modulate = Color.WHITE
		l.lit = false
		l.queue_redraw()
		return
	tw.set_parallel(true)
	tw.tween_property(l, "position", home + Vector2(0.0, _cell * 1.6), DROP_T)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(l, "scale", Vector2.ONE * 1.35, DROP_T * 0.35)
	tw.tween_property(l, "modulate:a", 0.0, DROP_T)
	tw.chain().tween_callback(func() -> void:
		if not is_instance_valid(l):
			return
		l.position = home
		l.scale    = Vector2.ONE
		l.lit      = false
		l.queue_redraw())
	tw.chain().tween_property(l, "modulate", Color.WHITE, 0.12)

func _shake() -> void:
	var tw := create_tween()
	if tw == null:
		return
	for i in 3:
		tw.tween_property(self, "position:x", position.x + (3.0 if i % 2 == 0 else -3.0), 0.04)
	tw.tween_property(self, "position:x", position.x, 0.05)

# Череп в одиночестве — не украшение, а предупреждение: следующий удар убивает.
# Пульс включается только на самом нижнем состоянии и снимается, как только
# загорелась первая буква.
var _pulse_tw : Tween = null

func _danger_pulse(on: bool) -> void:
	if _lamps.is_empty():
		return
	var skull : Lamp = _lamps[0]
	if _pulse_tw != null and _pulse_tw.is_valid():
		_pulse_tw.kill()
	_pulse_tw = null
	skull.modulate = Color.WHITE
	if not on or not is_inside_tree():
		return
	_pulse_tw = skull.create_tween()
	if _pulse_tw == null:
		return
	_pulse_tw.set_loops()
	_pulse_tw.tween_property(skull, "modulate", COL_DANGER, PULSE_T)\
		.set_trans(Tween.TRANS_SINE)
	_pulse_tw.tween_property(skull, "modulate", Color.WHITE, PULSE_T)\
		.set_trans(Tween.TRANS_SINE)

# Пульс живёт тюином, а тюин у узла вне дерева не создаётся: индикатор строится
# до добавления в HUD, и первый _paint попадает ровно в это окно.
func _notification(what: int) -> void:
	if what == NOTIFICATION_ENTER_TREE and _ready_done:
		_danger_pulse(_fat == 0)
