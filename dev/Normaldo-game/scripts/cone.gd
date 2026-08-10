extends Area2D

# Дорожный конус — высокое препятствие в 3 ряда (лейна) с числом 5–10 на нём.
# Каждый ТАП по конусу убавляет число; на нуле конус сжимается на один ряд, число
# обновляется. Сжав до размера обычного предмета (1 ряд) — число больше не
# показывается, остаётся обычным препятствием.

const TEX      := preload("res://assets/items/cone.png")
const UI_FONT  := preload("res://assets/fonts/RussoOne-Regular.ttf")

@export var speed : float = 250.0
var damage : int = 1

var _rows : int = 3           # высота в лейнах: 3 → 2 → 1
var _num  : int = 0
var _spr  : Sprite2D
var _lbl  : Label
var _cs   : CollisionShape2D

func _ready() -> void:
	collision_layer = 2
	collision_mask  = 0
	add_to_group("obstacle")
	add_to_group("cone")            # чтобы Нормальдо игнорил тапы по конусу (не дабл-тап)
	input_pickable  = true          # ловим тапы по конусу (input_event)

	_spr = Sprite2D.new()
	_spr.texture        = TEX
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_spr)

	_cs = CollisionShape2D.new()
	_cs.shape = RectangleShape2D.new()
	add_child(_cs)

	_lbl = Label.new()
	_lbl.add_theme_font_override("font", UI_FONT)
	_lbl.add_theme_font_size_override("font_size", 26)
	_lbl.add_theme_color_override("font_color", Color(1, 1, 1))
	_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_lbl.add_theme_constant_override("outline_size", 4)
	_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_lbl.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	add_child(_lbl)

	_num = randi_range(5, 10)
	_resize()
	input_event.connect(_on_input)

func _lane_h() -> float:
	return get_viewport_rect().size.y / 5.0

func _resize() -> void:
	var h  := _rows * _lane_h() * 0.94
	var ts := TEX.get_size()
	var sc := h / ts.y
	_spr.scale = Vector2(sc, sc)
	var w := ts.x * sc
	(_cs.shape as RectangleShape2D).size = Vector2(w * 0.70, h * 0.86)
	# Число по центру конуса (только пока рядов > 1).
	_lbl.size     = Vector2(80.0, 40.0)
	_lbl.position = Vector2(-40.0, -20.0)
	_lbl.visible  = _rows > 1
	_lbl.text     = str(_num)

func _on_input(_vp: Node, ev: InputEvent, _shape_idx: int) -> void:
	if _rows <= 1:
		return
	var pressed := (ev is InputEventScreenTouch and (ev as InputEventScreenTouch).pressed) \
		or (ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed \
			and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT)
	if pressed:
		_tap()

func _tap() -> void:
	_num -= 1
	if _num > 0:
		_lbl.text = str(_num)
		_pulse()
		return
	# Число дошло до 0 → сжать на ряд.
	_rows -= 1
	if _rows > 1:
		_num = randi_range(5, 10)
	_resize()
	_pulse()

func _pulse() -> void:
	# Sprite2D масштабируется вокруг центра (centered=true) — pivot_offset не нужен.
	var base := _spr.scale
	var tw := _spr.create_tween()
	tw.tween_property(_spr, "scale", base * 1.10, 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_spr, "scale", base, 0.14).set_trans(Tween.TRANS_SINE)

# Попадает ли точка (мир ≈ экран) в тело конуса — для Нормальдо, чтобы он не
# считал тап по конусу за движение/дабл-тап.
func contains_point(p: Vector2) -> bool:
	if _cs == null or _cs.shape == null:
		return false
	var half : Vector2 = (_cs.shape as RectangleShape2D).size * 0.5 + Vector2(12.0, 12.0)
	var local : Vector2 = p - global_position
	return absf(local.x) <= half.x and absf(local.y) <= half.y

func _process(delta: float) -> void:
	position.x -= speed * delta
	if position.x < -260.0:
		queue_free()
