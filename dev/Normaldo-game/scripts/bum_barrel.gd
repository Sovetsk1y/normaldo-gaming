extends Node2D

# ── Бомж с бочкой ─────────────────────────────────────────────────────────────
# Отдельный вид бомжа: вылетает из-за правого края, ТОРМОЗИТ, ставит бочку,
# бочка открывается — и оттуда в Нормальдо летит собака. Собака идёт по его
# линии и уходит за левый край: увернуться надо от неё, а не от бомжа.
#
# Почему это НЕ обычный предмет, а маленькая сцена-хореограф. Обычные предметы
# едут с постоянной скоростью и ничего не решают; здесь же есть три такта —
# приезд, установка, выстрел, — и каждый следующий зависит от предыдущего.
# Разложить это по трём независимым спавнам нельзя: бочка обязана открыться
# ТАМ, где её поставили, а собака вылететь ОТТУДА, где открылась бочка.
#
# Собака целится в линию Нормальдо на момент открытия бочки, а не постоянно:
# самонаводящаяся собака не оставила бы игроку хода.

const BARREL_TEX      : Texture2D = preload("res://assets/items/trash_bin.png")
const BARREL_OPEN_TEX : Array = [
	preload("res://assets/items/barrel_open1.png"),
	preload("res://assets/items/barrel_open2.png"),
]
const BUM_TEX : Array = [
	preload("res://assets/items/homeless1.png"),
	preload("res://assets/items/homeless2.png"),
]
const DOG_SCENE := preload("res://scenes/dog.tscn")

const STOP_X_FRAC  : float = 0.72   # где бомж тормозит
const BRAKE_T      : float = 0.55
const PUT_T        : float = 0.28   # бочка опускается на землю
const OPEN_DELAY   : float = 0.25
const DOG_SPEED    : float = 430.0  # заметно быстрее потока: это выстрел
const LEAVE_T      : float = 1.10

@export var speed  : float = 250.0
@export var lane_y : float = 0.0

var _target : Node2D = null        # Нормальдо: у него спрашиваем линию
var _bum    : Sprite2D = null
var _barrel : Sprite2D = null
var _done   : bool = false

func setup(normaldo: Node2D, y: float, item_speed: float) -> void:
	_target = normaldo
	lane_y  = y
	speed   = item_speed

func _ready() -> void:
	var vp := get_viewport_rect().size
	position = Vector2(vp.x + 90.0, lane_y)

	_bum = Sprite2D.new()
	_bum.texture        = BUM_TEX[randi() % BUM_TEX.size()]
	_bum.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Размеры — через ItemSizing, как у обычных предметов: свои множители
	# разъезжаются с потоком, стоит поменять BASE_PX.
	ItemSizing.fit_sprite(_bum, ItemSizing.BASE_PX * 1.25)
	add_child(_bum)

	_barrel = Sprite2D.new()
	_barrel.texture        = BARREL_TEX
	_barrel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ItemSizing.fit_sprite(_barrel, ItemSizing.BASE_PX * 1.15)
	_barrel.position       = Vector2(-46.0, 4.0)   # в руках, впереди себя
	add_child(_barrel)

	_run()

func _run() -> void:
	var vp := get_viewport_rect().size
	# 1. Приезд с торможением — по нему и читается, что этот бомж не «летит
	#    мимо», а пришёл по делу.
	var tw := create_tween()
	tw.tween_property(self, "position:x", vp.x * STOP_X_FRAC, BRAKE_T)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tw.finished
	if not is_inside_tree():
		return

	# 2. Ставит бочку: она опускается и ОТЦЕПЛЯЕТСЯ от бомжа — дальше живёт сама.
	var tw2 := create_tween()
	tw2.tween_property(_barrel, "position", Vector2(-52.0, 26.0), PUT_T)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw2.finished
	if not is_inside_tree():
		return
	await get_tree().create_timer(OPEN_DELAY).timeout
	if not is_inside_tree():
		return

	# 3. Бочка открывается и стреляет собакой.
	_barrel.texture = BARREL_OPEN_TEX[0]
	ItemSizing.fit_sprite(_barrel, ItemSizing.BASE_PX * 1.15)
	await get_tree().create_timer(0.10).timeout
	if not is_inside_tree():
		return
	_barrel.texture = BARREL_OPEN_TEX[1]
	ItemSizing.fit_sprite(_barrel, ItemSizing.BASE_PX * 1.15)
	_launch_dog()

	# 4. Бомж уходит за левый край, бочку бросает.
	var tw3 := create_tween()
	tw3.tween_property(self, "position:x", -140.0, LEAVE_T)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tw3.finished
	if is_inside_tree():
		queue_free()

func _launch_dog() -> void:
	if _done:
		return
	_done = true
	var host := get_parent()
	if host == null:
		return
	var dog := DOG_SCENE.instantiate()
	if dog.get("speed") != null:
		dog.speed = DOG_SPEED
	# Линия берётся у Нормальдо ОДИН раз, в момент выстрела: собака летит по
	# прямой, и увернуться от неё можно. Наводящаяся собака хода не оставила бы.
	var y : float = lane_y
	if is_instance_valid(_target):
		y = (_target as Node2D).global_position.y
	dog.position = Vector2(global_position.x - 18.0, y)
	host.add_child(dog)
