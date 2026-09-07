extends Area2D

# Дорожный конус — препятствие ВЫСОТОЙ В 1, 2 ИЛИ 3 РЯДА (лейна). Разный размер
# и есть вся его механика: трёхрядный перекрывает больше половины экрана и
# заставляет искать проход, однорядный — обычная помеха в потоке.
#
# ── ТАПОВ БОЛЬШЕ НЕТ ─────────────────────────────────────────────────────────
# Раньше на конусе стояло число, каждый тап убавлял его, на нуле конус сжимался
# на ряд — и так до однорядного. Механика убрана целиком вместе с числом и
# подсказкой «тапай».
#
# Причина в том, ЧТО эта механика просила от игрока. Забег — про уклонение
# головой: палец ведёт Нормальдо, и всё внимание на траектории. Конус требовал
# бросить ведение и застучать пальцем по другой точке экрана, то есть перебивал
# основное управление ради частного случая — и делал это в единственном месте
# игры, так что приём не успевал стать привычкой. Уклоняться от высокого конуса
# интереснее, чем разбирать его тапами.
#
# Размер выбирается при спавне (`set_rows`), по умолчанию три ряда.
const TEX      := preload("res://assets/items/cone.png")

@export var speed : float = 250.0
var damage : int = 1

var _rows : int = 3           # высота в лейнах: 1, 2 или 3
var _spr  : Sprite2D
var _cs   : CollisionShape2D

var _falling   : bool    = false
var _fall_vel  : Vector2 = Vector2.ZERO
var _fall_spin : float   = 0.0

# Сколько рядов бывает у конуса. Спавнер выбирает из этого диапазона.
const ROWS_MIN : int = 1
const ROWS_MAX : int = 3

# Высота в рядах. Ставится ДО входа в дерево или сразу после — `_resize()`
# переживает оба порядка.
func set_rows(rows: int) -> void:
	_rows = clampi(rows, ROWS_MIN, ROWS_MAX)
	if is_instance_valid(_spr):
		_resize()

func rows() -> int:
	return _rows

func _ready() -> void:
	collision_layer = 2
	collision_mask  = 0
	add_to_group("obstacle")
	# Группа «cone» осталась: по ней Нормальдо узнаёт конус, а спавнер и
	# лаборатория — считают их в потоке.
	add_to_group("cone")
	# ЯВНО ГАСИМ ЛОВЛЮ ТАПОВ. У Area2D она включена по умолчанию, и просто убрать
	# `input_event` мало: конус продолжал бы принимать касания и молча съедать
	# их — то есть высокий конус стал бы мёртвой зоной, где дабл-тап спелла не
	# срабатывает без всякой причины.
	input_pickable  = false

	_spr = Sprite2D.new()
	_spr.texture        = TEX
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_spr)

	_cs = CollisionShape2D.new()
	_cs.shape = RectangleShape2D.new()
	add_child(_cs)

	_resize()

func _lane_h() -> float:
	return get_viewport_rect().size.y / 5.0

func _resize() -> void:
	var h  := _rows * _lane_h() * 0.94
	var ts := TEX.get_size()
	var sc := h / ts.y
	_spr.scale = Vector2(sc, sc)
	var w := ts.x * sc
	(_cs.shape as RectangleShape2D).size = Vector2(w * 0.70, h * 0.86)

# Сбитый конус ПАДАЕТ, как любой другой предмет. Раньше у него не было
# `knock_down`, и `_kill_item` сносил его через `queue_free()`: трёхрядная
# махина, которую игрок только что снёс головой, просто исчезала из кадра — и
# это читалось не как «сбил», а как «пропал кадр».
func knock_down() -> void:
	if _falling:
		return
	_falling   = true
	collision_layer = 0
	_fall_vel  = KnockFall.launch_velocity(speed)
	_fall_spin = KnockFall.launch_spin()

# Попадает ли точка (мир ≈ экран) в тело конуса — для Нормальдо, чтобы он не
# считал тап по конусу за движение/дабл-тап.
func contains_point(p: Vector2) -> bool:
	if _cs == null or _cs.shape == null:
		return false
	var half : Vector2 = (_cs.shape as RectangleShape2D).size * 0.5 + Vector2(12.0, 12.0)
	var local : Vector2 = p - global_position
	return absf(local.x) <= half.x and absf(local.y) <= half.y

func _process(delta: float) -> void:
	if _falling:
		_fall_vel = KnockFall.step(self, _spr, _fall_vel, _fall_spin, delta)
		if KnockFall.is_gone(self):
			queue_free()
		return
	ItemFlow.advance(self, speed, delta)
	if ItemFlow.gone(self, 260.0):
		queue_free()
