extends Area2D

# Дорожный конус — высокое препятствие в 3 ряда (лейна) с числом на нём.
# Каждый ТАП по конусу убавляет число; на нуле конус сжимается на один ряд, число
# обновляется. Сжав до размера обычного предмета (1 ряд) — число больше не
# показывается, остаётся обычным препятствием.

const TEX      := preload("res://assets/items/cone.png")
const UI_FONT  := preload("res://assets/fonts/RussoOne-Regular.ttf")
# Подсказка «тапай» — ОБЩИЙ КИРПИЧ с мини-играми (`tap_prompt.gd`): картинка
# TAP! и два тапающих пальца по бокам. Раньше конус рисовал свою — голую
# картинку TAP! в 58 px без пальцев, — и просьба читалась слабее, чем в тех же
# мини-играх: «по этому надо тапать» это один приём игры, и показывать его двумя
# разными способами значит учить дважды.
const TAP_PROMPT := preload("res://scripts/tap_prompt.gd")
# Ширина надписи на экране. Конус в три лейна — это 258 px высоты, и подсказка
# в 58 px на нём терялась; 108 читается с телефона, не закрывая сам конус.
const TAP_W    : float = 108.0

@export var speed : float = 250.0
var damage : int = 1

var _rows : int = 3           # высота в лейнах: 3 → 2 → 1
var _num  : int = 0
var _spr  : Sprite2D
var _lbl  : Label
var _prompt : Node2D = null
var _cs   : CollisionShape2D

var _falling   : bool    = false
var _fall_vel  : Vector2 = Vector2.ZERO
var _fall_spin : float   = 0.0

# ── Сколько тапов стоит ряд ──────────────────────────────────────────────────
# Большой конус — 5…10 тапов, и с каждым сжатием их становится МЕНЬШЕ, а не
# заново случайно. Иначе выходила бессмыслица: сбил трёхрядный за пять тапов, он
# сжался — и двухрядный запросил десять. Меньший конус не может быть крепче
# большего, из которого он получился.
const NUM_FIRST_MIN : int = 5
const NUM_FIRST_MAX : int = 10
const NUM_MIN       : int = 2

# Сколько тапов стоил конус ДО сжатия — от него и считается следующий ряд.
var _num_before_shrink : int = NUM_FIRST_MAX

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

	# Подсказка — НАД числом. Число одно ничего не просит: оно читается как
	# «сколько во мне жизней», а не как «бей по мне пальцем». Пальцы над ним и
	# есть та просьба, а цифра под ней — счётчик, сколько ещё раз.
	_prompt = Node2D.new()
	_prompt.set_script(TAP_PROMPT)
	add_child(_prompt)
	_prompt.call("setup", TAP_W)

	_num = randi_range(NUM_FIRST_MIN, NUM_FIRST_MAX)
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
	# Число по центру конуса (только пока рядов > 1), картинка TAP! — над ним,
	# в четверти высоты конуса: выше она налезала бы на верхушку, ниже — на цифру.
	_lbl.size     = Vector2(80.0, 40.0)
	_lbl.position = Vector2(-40.0, -20.0)
	_lbl.visible  = _rows > 1
	_lbl.text     = str(_num)
	if is_instance_valid(_prompt):
		_prompt.visible  = _rows > 1
		# Над цифрой и с запасом на собственную высоту подсказки: пальцы у неё
		# торчат выше картинки, и без этого запаса верхний палец залезал бы на
		# верхушку конуса.
		_prompt.position = Vector2(0.0, -h * 0.26 - float(_prompt.call("half_height")) * 0.4)

func _on_input(_vp: Node, ev: InputEvent, _shape_idx: int) -> void:
	if _rows <= 1:
		return
	var pressed := (ev is InputEventScreenTouch and (ev as InputEventScreenTouch).pressed) \
		or (ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed \
			and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT)
	if pressed:
		_tap()

func _tap() -> void:
	if _num > 0:
		_num_before_shrink = _num
	_num -= 1
	if _num > 0:
		_lbl.text = str(_num)
		_pulse()
		return
	# Число дошло до 0 → сжать на ряд. Новое число — СТРОГО МЕНЬШЕ прежнего.
	_rows -= 1
	if _rows > 1:
		_num = randi_range(NUM_MIN, maxi(NUM_MIN, _num_before_shrink - 1))
	_resize()
	_pulse()

func _pulse() -> void:
	# Sprite2D масштабируется вокруг центра (centered=true) — pivot_offset не нужен.
	var base := _spr.scale
	var tw := _spr.create_tween()
	tw.tween_property(_spr, "scale", base * 1.10, 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_spr, "scale", base, 0.14).set_trans(Tween.TRANS_SINE)

# Сбитый конус ПАДАЕТ, как любой другой предмет. Раньше у него не было
# `knock_down`, и `_kill_item` сносил его через `queue_free()`: трёхрядная
# махина, которую игрок только что снёс головой, просто исчезала из кадра — и
# это читалось не как «сбил», а как «пропал кадр».
func knock_down() -> void:
	if _falling:
		return
	_falling   = true
	collision_layer = 0
	input_pickable  = false     # падающий конус тапать уже незачем
	_fall_vel  = KnockFall.launch_velocity(speed)
	_fall_spin = KnockFall.launch_spin()
	if is_instance_valid(_lbl):
		_lbl.visible = false
	if is_instance_valid(_prompt):
		_prompt.call("dismiss", 0.12)

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
	position.x -= speed * delta
	if position.x < -260.0:
		queue_free()
		return
	# Своего пульса у конуса больше нет: подсказка мигает и тапает пальцами сама
	# (`tap_prompt.gd`), и вторая анимация поверх неё читалась бы как дрожь.
