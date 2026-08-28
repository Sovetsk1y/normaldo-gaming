extends Node2D

# ── Бомж с бочкой ─────────────────────────────────────────────────────────────
# Отдельный вид бомжа: ВЛЕТАЕТ как обычный предмет, а показавшись целиком —
# тормозит, ставит бочку, бочка открывается, и оттуда в Нормальдо выпрыгивает
# собака. Собака идёт по его линии и уходит за левый край: увернуться надо от
# неё, а не от бомжа.
#
# Почему это НЕ обычный предмет, а маленькая сцена-хореограф. Обычные предметы
# едут с постоянной скоростью и ничего не решают; здесь же есть такты —
# приезд, установка, поворот, открытие, выстрел, — и каждый следующий зависит
# от предыдущего. Разложить это по независимым спавнам нельзя: бочка обязана
# открыться ТАМ, где её поставили, а собака вылететь ОТТУДА, где открылась
# бочка.
#
# Собака целится в линию Нормальдо на момент открытия бочки, а не постоянно:
# самонаводящаяся собака не оставила бы игроку хода.

# Кадры бочки идут по ПОРЯДКУ ПОКАЗА, а не по именам файлов. Художник назвал
# `open1`/`open2` ЗАКРЫТУЮ и с ОТОШЕДШЕЙ КРЫШКОЙ, а лежачая-открытая лежит в
# `trash_bin.png` — она же обычный предмет-мусорка. Прежний порядок был взят по
# именам, и бочка «открывалась» задом наперёд.
const BARREL_STAND : Texture2D = preload("res://assets/items/barrel_open1.png")  # закрыта
const BARREL_LID   : Texture2D = preload("res://assets/items/barrel_open2.png")  # крышка отошла
const BARREL_OPEN  : Texture2D = preload("res://assets/items/trash_bin.png")     # лежит открытой
const BUM_TEX : Array = [
	preload("res://assets/items/homeless1.png"),   # рыжий
	preload("res://assets/items/homeless2.png"),   # седой
]
const DOG_SCENE := preload("res://scenes/dog.tscn")

# Размеры. Это СЕТ-ПИС, а не предмет потока: бомж тут крупнее рядового бомжа из
# волны (66 px) и крупнее головы Нормальдо — иначе сцена читается как ещё один
# пролетающий мусор. Бочка не мельче собаки, которая из неё выпрыгивает: мелкая
# бочка превращает выстрел в фокус с появлением из ниоткуда.
const BUM_PX    : float = 120.0
# Ширина ТЕЛА бочки на экране. У стоячих кадров это ширина рисунка, у лежачего
# открытого — его длина: нормируй все три по одной стороне, и тело бочки на
# смене кадра меняло бы размер.
const BARREL_W      : float = 104.0
const BARREL_OPEN_W : float = 126.0

const ENTER_MARGIN : float = 24.0   # запас, после которого бомж «целиком в кадре»
const BRAKE_DIST   : float = 96.0   # тормозной путь: видно, что он ОСТАНАВЛИВАЕТСЯ
const BRAKE_T      : float = 0.45
const PUT_T        : float = 0.30   # бочка опускается на землю
const STAND_T      : float = 0.16   # стоит вертикально, прежде чем завалиться
const TURN_T       : float = 0.26   # заваливается набок крышкой ВЛЕВО
const LID_T        : float = 0.14   # крышка отходит
const OPEN_T       : float = 0.10   # откинута — и сразу собака
const DOG_SPEED    : float = 430.0  # заметно быстрее потока: это выстрел
const LEAVE_T      : float = 1.10

@export var speed  : float = 250.0
@export var lane_y : float = 0.0

var _target : Node2D = null        # Нормальдо: у него спрашиваем линию
var _bum    : Sprite2D = null
var _barrel : Sprite2D = null
var _phase  : String = "enter"     # enter | act | leave
var _sway_t : float = 0.0
var _done   : bool = false

func setup(normaldo: Node2D, y: float, item_speed: float) -> void:
	_target = normaldo
	lane_y  = y
	speed   = item_speed

func _ready() -> void:
	var vp := get_viewport_rect().size
	position = Vector2(vp.x + 120.0, lane_y)

	_bum = Sprite2D.new()
	_bum.texture = BUM_TEX[randi() % BUM_TEX.size()]
	ItemSizing.fit_sprite_content(_bum, BUM_PX)
	ItemSizing.anchor_sprite(_bum, 0.5, 0.5)
	add_child(_bum)

	_barrel = Sprite2D.new()
	_set_barrel_frame(BARREL_STAND)
	# Несёт перед собой, не наезжая на голову: бочка целиком СЛЕВА от бомжа.
	_barrel.position = Vector2(-_bum_half() - BARREL_W - 4.0, 6.0)
	add_child(_barrel)

# Бочка кадрируется по ВИДИМОЙ части и опирается на НИЖНИЙ ЛЕВЫЙ УГОЛ рисунка.
# Угол выбран не случайно: кадры нарисованы в разных рамках, и без общей опоры
# бочка на каждой смене кадра подпрыгивала бы, — а ещё это центр вращения, и
# вокруг него бочка заваливается набок, как настоящая.
func _set_barrel_frame(tex: Texture2D) -> void:
	_barrel.texture = tex
	if tex == BARREL_OPEN:
		# Лежачий кадр нормируется по ДЛИНЕ и опирается на правый нижний угол:
		# завалившаяся бочка лежит СЛЕВА от точки опоры, и открытая обязана
		# лечь туда же.
		ItemSizing.fit_sprite_content(_barrel, BARREL_OPEN_W, ItemSizing.AXIS_W)
		ItemSizing.anchor_sprite(_barrel, 1.0, 1.0)
	else:
		ItemSizing.fit_sprite_content(_barrel, BARREL_W, ItemSizing.AXIS_W)
		ItemSizing.anchor_sprite(_barrel, 0.0, 1.0)

# Пока не показался целиком — это обычный предмет потока: та же скорость, то же
# покачивание, что у бомжей из волны. Игрок узнаёт знакомую угрозу, и тем
# сильнее читается момент, когда она вдруг ТОРМОЗИТ.
func _process(delta: float) -> void:
	if _phase == "enter":
		position.x -= speed * delta
		_sway_t += delta * 6.0
		_bum.rotation = sin(_sway_t) * 0.05
		if _right_edge() < get_viewport_rect().size.x - ENTER_MARGIN:
			_phase = "act"
			_run()
	elif _phase == "leave":
		# Брошенная бочка дальше едет с потоком, как обычный предмет.
		position.x -= speed * delta
		if position.x < -260.0:
			queue_free()

# Половина ширины РИСУНКА бомжа. По рамке кадра считать нельзя: кадры
# кадрируются по видимой части, и рамка заметно шире нарисованного.
func _bum_half() -> float:
	return float(ItemSizing.content_rect(_bum.texture).size.x) * absf(_bum.scale.x) * 0.5

func _right_edge() -> float:
	return position.x + _bum_half()

func _run() -> void:
	# 1. Торможение — по нему и читается, что этот бомж не «летит мимо», а
	#    пришёл по делу.
	var tw := create_tween()
	tw.tween_property(self, "position:x", position.x - BRAKE_DIST, BRAKE_T)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_bum, "rotation", 0.0, BRAKE_T * 0.6)
	await tw.finished
	if not is_inside_tree():
		return

	# 2. Ставит бочку на землю СТОЯЧЕЙ. Дальше она живёт сама.
	var tw2 := create_tween()
	tw2.tween_property(_barrel, "position", Vector2(_barrel.position.x - 6.0, 38.0), PUT_T)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw2.finished
	if not is_inside_tree():
		return
	await get_tree().create_timer(STAND_T).timeout
	if not is_inside_tree():
		return

	# 3. Заваливается набок КРЫШКОЙ ВЛЕВО — это движение, а не подмена кадра:
	#    поворот читается только когда его видно.
	var tw3 := create_tween()
	tw3.tween_property(_barrel, "rotation", -PI * 0.5, TURN_T)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw3.finished
	if not is_inside_tree():
		return

	# 4. Крышка отходит — и откидывается. Собака выпрыгивает ровно на откинутой.
	_set_barrel_frame(BARREL_LID)
	await get_tree().create_timer(LID_T).timeout
	if not is_inside_tree():
		return
	_barrel.rotation = 0.0          # лежачий кадр УЖЕ нарисован лежащим
	_set_barrel_frame(BARREL_OPEN)
	await get_tree().create_timer(OPEN_T).timeout
	if not is_inside_tree():
		return
	_launch_dog()

	# 4. Бомж уходит за левый край, бочку бросает. Уходит ОН, а не вся сцена:
	#    иначе он утаскивал бы с собой и брошенную бочку.
	_phase = "leave"
	var tw4 := create_tween()
	tw4.tween_property(_bum, "position:x", -get_viewport_rect().size.x - 200.0, LEAVE_T)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

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
	# Линия берётся у Нормальдо ОДИН раз, в момент открытия бочки: собака летит
	# по прямой, и увернуться от неё можно. Наводящаяся хода не оставила бы.
	var y : float = lane_y
	if is_instance_valid(_target):
		y = (_target as Node2D).global_position.y
	# Вылетает ИЗ ГОРЛА бочки, а не из центра сцены: бочку успели поставить и
	# сдвинуть, и точка появления обязана ехать за ней.
	dog.position = Vector2(_barrel.global_position.x - BARREL_OPEN_W * 0.5, y)
	host.add_child(dog)
