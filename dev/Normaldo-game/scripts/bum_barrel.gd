extends Node2D

# ── Бомж с бочкой ─────────────────────────────────────────────────────────────
# Отдельный вид бомжа: ВЛЕТАЕТ как обычный предмет, а показавшись целиком —
# тормозит, роняет бочку, бочку открывает сорванной крышкой, и оттуда вылетает
# собака. Собака идёт по ЕГО линии и уходит за левый край: увернуться надо от
# неё, а не от бомжа — бомж и бочка не бьют вовсе.
#
# Почему это НЕ обычный предмет, а маленькая сцена-хореограф. Обычные предметы
# едут с постоянной скоростью и ничего не решают; здесь же есть такты —
# приезд, торможение, падение бочки, открытие, выстрел, — и каждый следующий
# зависит от предыдущего. Разложить это по независимым спавнам нельзя: бочка обязана
# открыться ТАМ, где её поставили, а собака вылететь ОТТУДА, где открылась
# бочка.
#
# Собака летит ПО СВОЕЙ ЛИНИИ — той, на которой встал бомж, — а не в Нормальдо.
# Это и делает такт честным: линия занята с того момента, как бомж на ней
# затормозил, игрок видит её всю подготовку и успевает с неё уйти. Собака,
# наведённая на голову в момент открытия, отнимала бы у этой подготовки смысл:
# сходить с линии было бы незачем, всё равно прилетит куда встал.

# У бочки РОВНО ДВА кадра, и это весь её словарь: закрыта и открыта.
#
# Прежняя версия добавляла третьим кадром `trash_bin.png` — «лежачую открытую», —
# и заваливала бочку набок, чтобы к ней прийти. Кадр был взят зря: это обычный
# предмет-мусорка из потока, и нарисован он С КРАСНОЙ ОБВОДКОЙ, то есть с той
# самой меткой «этот бьёт». В сет-писе она врала — поставленная бочка не бьёт,
# бьёт собака, — а заодно тянула за собой лишний такт с переворотом.
const BARREL_CLOSED : Texture2D = preload("res://assets/items/barrel_open1.png") # крышка на месте
const BARREL_OPEN   : Texture2D = preload("res://assets/items/barrel_open2.png") # крышку сорвало
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
# Ширина ТЕЛА бочки на экране. Оба кадра нормируются по ней и по одной стороне:
# у открытого сорванная крышка торчит вверх, и нормируй его по высоте — тело
# бочки на смене кадра ужалось бы вдвое.
const BARREL_W : float = 104.0

const ENTER_MARGIN : float = 24.0   # запас, после которого бомж «целиком в кадре»
const BRAKE_DIST   : float = 96.0   # тормозной путь: видно, что он ОСТАНАВЛИВАЕТСЯ
const BRAKE_T      : float = 0.45
const HOLD_T       : float = 0.18   # держит бочку перед собой, прежде чем уронить
const DROP_T       : float = 0.22   # ПАДАЕТ: быстро и с разгоном
const LAND_T       : float = 0.12   # приземлилась — короткий отскок
const OPEN_T       : float = 0.20   # крышку сорвало — и сразу собака
# Собака ВСЕГДА быстрее потока: это выстрел, а не ещё один предмет. К концу
# кампании поток разгоняется, и фиксированные 430 перестали бы читаться как
# рывок — поэтому множитель, а число только нижняя граница.
const DOG_SPEED_K   : float = 1.7
const DOG_SPEED_MIN : float = 430.0
const LEAVE_T       : float = 1.10

@export var speed  : float = 250.0
@export var lane_y : float = 0.0

var _bum    : Sprite2D = null
var _barrel : Sprite2D = null
var _phase  : String = "enter"     # enter | act | leave
var _sway_t : float = 0.0
var _done   : bool = false

# `normaldo` больше не нужен — собака летит по своей линии, а не в голову, — но
# аргумент остаётся: сет-пис зовут из спавнера тем же вызовом, что и остальные.
func setup(_normaldo: Node2D, y: float, item_speed: float) -> void:
	lane_y = y
	speed  = item_speed

func _ready() -> void:
	var vp := get_viewport_rect().size
	position = Vector2(vp.x + 120.0, lane_y)

	_bum = Sprite2D.new()
	_bum.texture = BUM_TEX[randi() % BUM_TEX.size()]
	ItemSizing.fit_sprite_content(_bum, BUM_PX)
	ItemSizing.anchor_sprite(_bum, 0.5, 0.5)
	add_child(_bum)

	_barrel = Sprite2D.new()
	_set_barrel_frame(BARREL_CLOSED)
	# Несёт перед собой, не наезжая на голову: бочка целиком СЛЕВА от бомжа.
	_barrel.position = Vector2(-_bum_half() - BARREL_W - 4.0, 6.0)
	add_child(_barrel)

# Бочка кадрируется по ВИДИМОЙ части, нормируется по ШИРИНЕ тела и опирается на
# НИЖНИЙ ЛЕВЫЙ УГОЛ рисунка.
#
# Опора выбрана не случайно. Кадры нарисованы в разных рамках (у открытого сверху
# ещё и сорванная крышка), и без общей опоры бочка на смене кадра подпрыгивала
# бы. А дно — то, чем она стоит на земле: с опорой на дно смена кадра выглядит
# как «крышку сорвало», а не как «бочку подменили».
func _set_barrel_frame(tex: Texture2D) -> void:
	_barrel.texture = tex
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
	#    пришёл по делу. С этого момента линия за ним держится пустой
	#    (см. spawner._setpiece_bum_barrel), и уйти с неё можно спокойно.
	var tw := create_tween()
	tw.tween_property(self, "position:x", position.x - BRAKE_DIST, BRAKE_T)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_bum, "rotation", 0.0, BRAKE_T * 0.6)
	await tw.finished
	if not is_inside_tree():
		return
	await get_tree().create_timer(HOLD_T).timeout
	if not is_inside_tree():
		return

	# 2. БОЧКА ПАДАЕТ. Именно падает, а не опускается: ускорение вниз и короткий
	#    отскок при ударе о землю. Плавная установка читалась бы как «поставил»,
	#    а нужно «уронил» — оттого крышку и срывает.
	var floor_y : float = _barrel.position.y + 44.0
	var tw2 := create_tween()
	tw2.tween_property(_barrel, "position:y", floor_y, DROP_T)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# Приземление: бочка приседает и распрямляется. Опора у неё на дне, поэтому
	# сжимается она ВВЕРХ, как настоящая.
	var base_sc : Vector2 = _barrel.scale
	tw2.tween_property(_barrel, "scale", Vector2(base_sc.x * 1.10, base_sc.y * 0.86), LAND_T * 0.4)
	tw2.tween_property(_barrel, "scale", base_sc, LAND_T * 0.6)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tw2.finished
	if not is_inside_tree():
		return

	# 3. ОТКРЫВАЕТСЯ — второй и последний кадр бочки.
	_set_barrel_frame(BARREL_OPEN)
	await get_tree().create_timer(OPEN_T).timeout
	if not is_inside_tree():
		return

	# 4. И оттуда вылетает собака.
	_launch_dog()

	# Бомж уходит за левый край, бочку бросает. Уходит ОН, а не вся сцена:
	# иначе он утаскивал бы с собой только что брошенную бочку.
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
		dog.speed = maxf(DOG_SPEED_MIN, speed * DOG_SPEED_K)
	# По СВОЕЙ линии — той, что бомж занял и держал всю подготовку. Наводить её
	# на голову значило бы обесценить эту подготовку: сходить с линии было бы
	# незачем, всё равно прилетит куда встал.
	dog.position = Vector2(_barrel.global_position.x, lane_y)
	host.add_child(dog)
