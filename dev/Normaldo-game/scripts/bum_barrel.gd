extends Node2D

# ── Бомж с бочкой ─────────────────────────────────────────────────────────────
# Отдельный вид бомжа: ВЛЕТАЕТ как обычный предмет, а показавшись целиком —
# тормозит, толкает бочку, та падает набок и открывается, и оттуда вылетает
# собака. Собака идёт по ЕГО линии и уходит за левый край.
#
# БЬЮТ ВСЕ ТРОЕ. Бомж и бочка — такие же препятствия, как любой предмет потока, и
# хитбоксы у них живут отдельными Area2D, которые каждый кадр едут за своими
# спрайтами. Иначе вышло бы то, что и вышло: игрок пролетает сквозь бомжа и бочку
# насквозь без урона, а сет-пис из угрозы превращается в декорацию, которую
# достаточно переждать.
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
const HITBOX_SCRIPT := preload("res://scripts/setpiece_hitbox.gd")

# Размеры. Бомж тут РОВНО ТАКОЙ ЖЕ, как рядовой бомж из потока (61 px), и это
# принципиально: от обычного предмета он отличается не размером, а тем, что умеет
# отыграть сцену и кинуть пса. Раздутый вдвое, он читался как босс — а он не босс.
const BUM_PX : float = 61.0
# Высота ТЕЛА бочки на экране — не ниже бомжа.
const BARREL_BODY_H : float = 66.0

# Бочка — размером с ОБЫЧНУЮ БОЧКУ ИЗ ПОТОКА: та рисуется мусоркой на 0.22 от
# кадра и выходит около 63 пикселей в высоту, то есть с самого бомжа. Меряется
# поэтому ВЫСОТА ТЕЛА, а не длинная сторона: по длинной стороне у закрытого кадра
# считалась бы высота (107 против 89 ширины), и бочка выходила бы заметно ниже
# заявленного.
#
# Масштаб считается по ЗАКРЫТОМУ кадру и потом ставится обоим напрямую.
#
# Почему не «нормировать каждый кадр по рисунку», как остальные предметы: у
# открытого кадра сорванная крышка тянет контент вверх — 165 пикселей против
# 107, — и нормировка по нему ужала бы тело бочки прямо на смене кадра. Оба кадра
# нарисованы в общей рамке 200×200 в одном масштабе (замер: тело в обоих 89–90 px
# шириной), поэтому ОДИН масштаб на двоих держит тело одинаковым, а сорванная
# крышка встаёт над ним ровно там, где нарисована.

const ENTER_MARGIN : float = 24.0   # запас, после которого бомж «целиком в кадре»
const BRAKE_DIST   : float = 96.0   # тормозной путь: видно, что он ОСТАНАВЛИВАЕТСЯ
const BRAKE_T      : float = 0.45
const HOLD_T       : float = 0.18   # держит бочку перед собой, прежде чем уронить
const PUSH_DX      : float = 16.0   # тычок вперёд: он ТОЛКАЕТ бочку, а не ждёт
const PUSH_T       : float = 0.24
const DROP_T       : float = 0.26   # ПАДАЕТ и заваливается НА БОК — одним движением
const LAND_T       : float = 0.12   # приземлилась — короткий отскок
const DROP_DY      : float = 34.0   # на сколько проседает, пока падает
const OPEN_T       : float = 0.20   # крышку сорвало — и сразу собака
# Собака ВСЕГДА быстрее потока: это выстрел, а не ещё один предмет. К концу
# кампании поток разгоняется, и фиксированные 430 перестали бы читаться как
# рывок — поэтому множитель, а число только нижняя граница.
const DOG_SPEED_K   : float = 1.7
const DOG_SPEED_MIN : float = 430.0

@export var speed  : float = 250.0
@export var lane_y : float = 0.0

var _bum    : Sprite2D = null
var _barrel : Sprite2D = null
var _phase  : String = "enter"     # enter | act | leave
var _bum_box    : Area2D = null
var _barrel_box : Area2D = null
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
	# Опора у неё на нижнем левом углу рисунка, поэтому тело уходит от точки
	# ВПРАВО — отступ считается от ширины тела, а не от рамки.
	_barrel.position = Vector2(-_bum_half() - _barrel_body().x - 2.0, 14.0)
	add_child(_barrel)

	# Хитбоксы. Отдельными узлами, а не на спрайтах: спрайты масштабируются и
	# вращаются, и форма удара ездила бы вместе с рисунком — у бочки, которая
	# заваливается на бок, буквально переворачивалась бы.
	var bum_r : Vector2 = _drawn_size(_bum)
	_bum_box    = _make_box(bum_r * 0.72)
	_barrel_box = _make_box(_barrel_body() * 0.80)
	_sync_boxes()

# Кадр бочки: размер по РАМКЕ, опора — нижний левый угол ЗАКРЫТОГО кадра.
#
# Опора одна на оба кадра и берётся именно у закрытого. Кадры зарегистрированы в
# общей рамке, но рисунок открытого спускается ниже на 14 пикселей, и опора «у
# каждого своя» дёргала бы тело бочки на смене кадра.
#
# Нижний левый угол выбран не случайно дважды: это дно, которым бочка стоит на
# земле, и это же центр вращения — вокруг него она заваливается набок, как
# настоящая, а не проворачивается вокруг своей середины.
func _set_barrel_frame(tex: Texture2D) -> void:
	_barrel.texture = tex
	_barrel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Масштаб — ОДИН на оба кадра и посчитан по закрытому: см. шапку.
	_barrel.scale = Vector2.ONE * ItemSizing.content_scale(
		BARREL_CLOSED, BARREL_BODY_H, ItemSizing.AXIS_H)
	var r := ItemSizing.content_rect(BARREL_CLOSED)
	_barrel.offset = tex.get_size() * 0.5 \
		- Vector2(float(r.position.x), float(r.position.y + r.size.y))

# Размер ТЕЛА бочки на экране — рисунка закрытого кадра, без сорванной крышки.
func _barrel_body() -> Vector2:
	var r := ItemSizing.content_rect(BARREL_CLOSED)
	return Vector2(float(r.size.x), float(r.size.y)) * absf(_barrel.scale.x)

# Пока не показался целиком — это обычный предмет потока: та же скорость, то же
# покачивание, что у бомжей из волны. Игрок узнаёт знакомую угрозу, и тем
# сильнее читается момент, когда она вдруг ТОРМОЗИТ.
func _process(delta: float) -> void:
	_sync_boxes()
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

# Экранный размер нарисованного у спрайта.
func _drawn_size(spr: Sprite2D) -> Vector2:
	var r := ItemSizing.content_rect(spr.texture)
	return Vector2(float(r.size.x), float(r.size.y)) * absf(spr.scale.x)

# Ударяющая зона: обычное препятствие, такое же, как предметы потока.
func _make_box(sz: Vector2) -> Area2D:
	var a := Area2D.new()
	a.set_script(HITBOX_SCRIPT)
	a.collision_layer = 2
	a.collision_mask  = 0
	a.add_to_group("obstacle")
	# Сломали любую из зон — сцена кончилась. Спелл, попавший в бомжа, обязан
	# что-то сделать, а сломать одну зону из двух и оставить сцену доигрывать
	# читалось бы как «спелл не сработал».
	a.connect("broken", _on_box_broken)
	var cs   := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = sz
	cs.shape  = rect
	a.add_child(cs)
	add_child(a)
	return a

func _on_box_broken() -> void:
	queue_free()

# Хитбоксы едут за своими спрайтами КАЖДЫЙ кадр: бомж качается и делает тычок,
# бочка падает и заваливается набок — зона удара обязана ехать с рисунком, иначе
# бьёт пустое место, а нарисованное не бьёт.
func _sync_boxes() -> void:
	if is_instance_valid(_bum_box) and is_instance_valid(_bum):
		_bum_box.position = _bum.position
	if is_instance_valid(_barrel_box) and is_instance_valid(_barrel):
		# Спрайт бочки опирается на нижний левый угол рисунка, поэтому центр тела
		# лежит от точки опоры вправо-вверх — и поворачивается вместе с ней.
		var b : Vector2 = _barrel_body()
		_barrel_box.position = _barrel.position \
			+ Vector2(b.x * 0.5, -b.y * 0.5).rotated(_barrel.rotation)
		_barrel_box.rotation = _barrel.rotation

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

	# 2. ТЫЧОК. Бомж коротко подаётся вперёд — и от этого бочка валится. Без него
	#    она заваливалась сама собой, и связи «уронил её ОН» на экране не было:
	#    бомж просто стоял рядом с падающей бочкой.
	var home_x : float = _bum.position.x
	var push := create_tween()
	push.tween_property(_bum, "position:x", home_x - PUSH_DX, PUSH_T * 0.40)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	push.tween_property(_bum, "position:x", home_x, PUSH_T * 0.60)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# Ждём МОМЕНТА КАСАНИЯ, а не всего тычка: бочка обязана пойти вниз тогда,
	# когда он в неё упёрся, — дальше он уже отходит назад.
	await get_tree().create_timer(PUSH_T * 0.40).timeout
	if not is_inside_tree():
		return

	# 3. БОЧКА ПАДАЕТ НА БОК. Одним движением: проседает вниз и заваливается на
	#    −90° вокруг своего нижнего угла. Просто опуститься ей мало — упавшая
	#    стоймя бочка читается как «поставил», а нужно «уронил»; и только лёжа у
	#    неё горло смотрит ВЛЕВО, туда, куда полетит собака.
	var tw2 := create_tween()
	tw2.set_parallel(true)
	tw2.tween_property(_barrel, "position:y", _barrel.position.y + DROP_DY, DROP_T)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw2.tween_property(_barrel, "rotation", -PI * 0.5, DROP_T)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw2.finished
	if not is_inside_tree():
		return
	# Удар о землю: короткий отскок по вертикали.
	var tw3 := create_tween()
	tw3.tween_property(_barrel, "position:y", _barrel.position.y - 5.0, LAND_T * 0.4)
	tw3.tween_property(_barrel, "position:y", _barrel.position.y, LAND_T * 0.6)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tw3.finished
	if not is_inside_tree():
		return

	# 4. ОТКРЫВАЕТСЯ — второй и последний кадр бочки. Лежит она уже на боку,
	#    поэтому сорванная крышка отлетает ВЛЕВО, а не вверх.
	_set_barrel_frame(BARREL_OPEN)
	await get_tree().create_timer(OPEN_T).timeout
	if not is_inside_tree():
		return

	# 5. И оттуда вылетает собака.
	_launch_dog()

	# Дальше он просто ЕДЕТ С ПОТОКОМ — вместе с брошенной бочкой, с той же
	# скоростью, что и любой предмет. Раньше он отдельно улетал за левый край
	# рывком, и это врало: сет-пис отличается от обычного предмета не тем, что
	# уносится прочь, а только тем, что по дороге умеет отыграть сцену.
	_phase = "leave"

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
	#
	# Вылетает из ГОРЛА: бочка лежит на боку, горло смотрит влево, и это её
	# нижний угол минус длина тела.
	dog.position = Vector2(_barrel.global_position.x - _barrel_body().y, lane_y)
	host.add_child(dog)
