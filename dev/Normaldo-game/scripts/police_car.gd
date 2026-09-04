extends Area2D

# ── Тачка копов ───────────────────────────────────────────────────────────────
# Перевёрнутая полицейская машина, которая идёт ПО ДВУМ ЛЕЙНАМ и быстрее потока.
# Не предмет, а событие: врезается — разрушает — разрушается сама, и из неё
# вываливаются два копа на соседние линии.
#
# Раньше она была рядовой картинкой в потоке: летела как камень, только длиннее.
# Машина, ведущая себя как камень, — это не машина, а обои; всё, что от неё
# оставалось, — «объезжай сверху или снизу», ровно как от шезлонга.
#
# Такт целиком:
#
#   1. ВЛЕТАЕТ справа, вдвое быстрее потока, перекрывая две линии из пяти.
#      Скорость здесь — половина предупреждения: по ней сразу видно, что это не
#      предмет, и что уворачиваться надо СЕЙЧАС.
#   2. ПАШЕТ. Всё, что попадается ей в эти две линии, сносится — пицца, бочка,
#      деньги, всё. Отсюда и смысл её появления: две линии на несколько секунд
#      перестают быть местом, куда можно идти за добычей.
#   3. РАЗБИВАЕТСЯ, дойдя до игрока. Не «улетает за край»: набежавшая машина
#      обязана чем-то кончиться, иначе весь такт — это просто быстрая стена.
#   4. ИЗ НЕЁ ВЫВАЛИВАЮТСЯ ДВА КОПА — на линии выше и ниже той пары, которую она
#      занимала. Именно на СОСЕДНИЕ: игрок только что ушёл с её пути, то есть
#      стоит ровно там, и авария не заканчивается облегчением, а сдаёт ход
#      дальше.
#
# См. /Концепция/Уровни/Раскладка по уровням.md

const CAR_TEX  := preload("res://assets/items/police_car.png")
const COP_HAZARD := preload("res://scripts/hazard_item.gd")
const CRASH_SFX  := preload("res://assets/audio/hit.mp3")

# Размер — ТОТ ЖЕ, что у машины на финале хозяина клуба (`club_boss.CAR_PX`):
# 300 px по длинной стороне, то есть 300×140 на экране. Так это одна и та же
# машина в глазах игрока, а не две разного роста.
#
# Мерили её сначала по ВЫСОТЕ — «две линии из пяти», 160 px, — и получалось 343
# в длину: заметно крупнее той, что приезжает за боссом. Двух линий она при этом
# всё равно достаёт: хитбокс в 109 px при лейне 86 перекрывает обе, между
# центрами которых она идёт.
const CAR_PX : float = 300.0
const SPEED_MULT  : float = 1.75
# Где она разбивается — доля ширины экрана. Нормальдо стоит примерно на 0.23,
# поэтому 0.30: авария происходит У НЕГО ПЕРЕД НОСОМ, а не за спиной, где её
# уже не видно.
const CRASH_X_FRAC : float = 0.30
# Сколько разбитая машина кувыркается, прежде чем растаять.
const CRASH_T      : float = 0.55
# Урона два, как у сейфа: это самое тяжёлое, что есть в потоке, и переживать
# столкновение с машиной так же дёшево, как с бананом, она не должна.
@export var damage : int   = 2

@export var speed  : float = 250.0
# Верхняя из двух перекрытых линий. Копы вываливаются на lane-1 и lane+2.
@export var lane   : int   = 0
@export var lanes_total : int = 5

var _sprite  : Sprite2D = null
var _crashed : bool     = false

func _ready() -> void:
	speed *= SPEED_MULT
	add_to_group("obstacle")
	add_to_group("police_car")
	collision_layer = 2
	# Машина — единственный предмет, который САМА ищет столкновения: остальные
	# лежат на слое 2 и никого не слушают, ловит их Нормальдо. Ей же надо
	# сносить всё на своём пути, поэтому маска тоже 2.
	collision_mask  = 2
	monitoring      = true
	area_entered.connect(_on_area)

	_sprite = Sprite2D.new()
	_sprite.texture = CAR_TEX
	# Лист нарисован вверх колёсами (мигалка внизу, крыша сверху) — отражаем:
	# машина перевёрнутая, но не вверх ногами.
	_sprite.flip_v  = true
	ItemSizing.fit_sprite_content(_sprite, CAR_PX)
	add_child(_sprite)

	var rect := RectangleShape2D.new()
	var body : Vector2 = Vector2(ItemSizing.content_rect(CAR_TEX).size) * _sprite.scale
	# Хитбокс уже корпуса, но ненамного: у машины сходят на нет только мигалка
	# сверху и колёса снизу, всё остальное — железо. 0.62 давало полтора лейна
	# при рисунке в два, и машина проезжала СКВОЗЬ игрока, стоящего у её края.
	rect.size  = Vector2(body.x * 0.86, body.y * 0.78)
	var cs := CollisionShape2D.new()
	cs.shape   = rect
	add_child(cs)

func _process(delta: float) -> void:
	if _crashed:
		return
	position.x -= speed * delta
	if position.x <= get_viewport_rect().size.x * CRASH_X_FRAC:
		_crash()
		return
	if position.x < -400.0:
		queue_free()

# ── Пашет ─────────────────────────────────────────────────────────────────────

func _on_area(a: Area2D) -> void:
	if _crashed or not is_instance_valid(a):
		return
	# Своих не трогаем: копы вываливаются из неё же и в первый кадр стоят прямо
	# в её хитбоксе.
	if a.is_in_group("police_car") or a.is_in_group("cop"):
		return
	if a.has_method("knock_down"):
		a.call("knock_down")
	else:
		a.queue_free()

# ── Разбивается ───────────────────────────────────────────────────────────────

func _crash() -> void:
	if _crashed:
		return
	_crashed = true
	# Хитбокс снимаем ПЕРВЫМ: разбитая машина ещё полсекунды крутится на экране,
	# и убивать ею в это время — значит бить тем, что уже кончилось.
	collision_layer = 0
	collision_mask  = 0
	monitoring      = false
	_play(CRASH_SFX)
	_debris()
	_drop_cops()

	# Кувырок и затухание — ОДНОЙ последовательностью, а не set_parallel + chain:
	# на общем «параллельном» тюине шаги схлопывались, и машина исчезала в тот же
	# кадр, в который разбилась. Кувырка не было видно вообще.
	var tw := create_tween()
	tw.tween_property(_sprite, "rotation", _sprite.rotation + 0.9, CRASH_T)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(self, "position:x", position.x - 90.0, CRASH_T)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(self, "position:y", position.y + 40.0, CRASH_T)
	tw.tween_property(_sprite, "modulate:a", 0.0, 0.3)
	tw.tween_callback(queue_free)

# Два копа — на линию ВЫШЕ верхней занятой и на линию НИЖЕ нижней. Если машина
# шла по краю и соседа с одной стороны нет, оба уходят в ту сторону, где место
# есть: «выпал один» читалось бы как сбой, а не как решение.
func _drop_cops() -> void:
	var vp := get_viewport_rect().size
	var lane_h : float = vp.y / float(maxi(1, lanes_total))
	var above : int = lane - 1
	var below : int = lane + 2
	var targets : Array = []
	if above >= 0:
		targets.append(above)
	if below <= lanes_total - 1:
		targets.append(below)
	while targets.size() < 2:
		# Край экрана: добираем изнутри пары, которую машина занимала, — там
		# только что стало пусто, и коп встаёт ровно на освободившееся место.
		var inner : int = lane if not targets.has(lane) else lane + 1
		targets.append(clampi(inner, 0, lanes_total - 1))

	var parent := get_parent()
	if parent == null:
		return
	for i in targets.size():
		var cop := Area2D.new()
		cop.set_script(COP_HAZARD)
		cop.set("kind", "cop")
		cop.set("speed", speed / SPEED_MULT)   # дальше он едет с потоком, а не с машиной
		cop.position = position
		parent.add_child(cop)
		# Вылетают ДУГОЙ из машины на свои линии: коп, мгновенно оказавшийся на
		# соседней линии, читается как заспавненный, а не как выпавший.
		#
		# Пока летит — не едет сам и не ловится: иначе он одновременно и
		# вылетает по тюину, и уезжает влево своим ходом, и дуга превращается в
		# рывок наискось. Ловиться в этот момент он тоже не должен — игрок ещё
		# не видел, куда он сядет.
		cop.set_process(false)
		cop.collision_layer = 0
		var to := Vector2(position.x + 40.0 - 30.0 * float(i),
			lane_h * (float(targets[i]) + 0.5))
		var tw := cop.create_tween()
		tw.tween_property(cop, "position", to, 0.35)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_callback(func() -> void:
			if not is_instance_valid(cop):
				return
			cop.collision_layer = 2
			cop.set_process(true))

func _debris() -> void:
	var p := CPUParticles2D.new()
	p.one_shot             = true
	p.emitting             = true
	p.amount               = 28
	p.lifetime             = 0.7
	p.explosiveness        = 0.95
	p.direction            = Vector2(-1, -0.4)
	p.spread               = 70.0
	p.gravity              = Vector2(0, 420)
	p.initial_velocity_min = 120.0
	p.initial_velocity_max = 330.0
	p.scale_amount_min     = 3.0
	p.scale_amount_max     = 8.0
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.95, 0.75, 1.0))
	g.add_point(0.4, Color(0.75, 0.75, 0.80, 0.85))
	g.set_color(1, Color(0.30, 0.30, 0.34, 0.0))
	p.color_ramp = g
	add_child(p)
	p.finished.connect(p.queue_free)

func _play(stream: AudioStream) -> void:
	var parent := get_parent()
	if parent == null:
		return
	var a := AudioStreamPlayer.new()
	a.stream = stream
	parent.add_child(a)
	a.play()
	a.finished.connect(a.queue_free)
