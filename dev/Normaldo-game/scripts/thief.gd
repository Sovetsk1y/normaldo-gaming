extends Area2D

# Вор — летит по своей линии; ~0.5 c «наводится» на ближайшую цель ВПЕРЕДИ по ходу
# движения (ресурс ИЛИ Нормальдо; сзади — никогда), затем меняет спрайт на thief2 и
# делает рывок. По ресурсу ДОВОДИТСЯ (летит прямо в него, даже если тот едет) →
# уничтожает падением. По Нормальдо — прыгает в ЗАФИКСИРОВАННУЮ точку, не следует.
# Всегда ПОВЁРНУТ туда, КУДА летит (flip_h; спрайт по умолчанию смотрит ВЛЕВО).
# Полностью улетел за экран — умирает. Сам — препятствие (урон 1).

const TEX1 := preload("res://assets/items/thief1.png")
const TEX2 := preload("res://assets/items/thief2.png")
const LAUGH_SFX := preload("res://assets/audio/thief_laugh.mp3")   # ищет/наводится на цель
const JUMP_SFX  := preload("res://assets/audio/thief_jump.mp3")    # рывок к цели

@export var speed : float = 250.0
var damage : int = 1

# Вор — ЧЕЛОВЕК, и рядом с бомжом (61 px рисунка) он должен читаться человеком,
# а не банкой колы. Прежний размер брался по КАДРУ (74 от 441), а кадры у него
# с большими полями: рисунка выходило 52×62 — ровно банан.
#
# Меряется по РИСУНКУ и по ДЛИННОЙ стороне, но масштаб считается ОДИН — по
# первому кадру — и ставится обоим. Нормировать каждый кадр отдельно нельзя:
# во втором он в рывке, руки-ноги врозь (435 px против 312), и вор ужимался бы
# ровно в момент прыжка, то есть тогда, когда на него и смотрят.
const THIEF_PX : float = 82.0

const FIRST_DELAY : float = 0.3     # прежде чем начать первое наведение
const TURN_TIME   : float = 0.5     # время наведения на цель
const JUMP_MULT   : float = 2.2     # скорость рывка × speed (не слишком быстро)
const RELAND_WAIT : float = 0.15    # после приземления — быстро ищет следующую
const SEEK_RADIUS : float = 340.0
const OFFSCREEN_M : float = 60.0    # запас, после которого «полностью за экраном»

var _spr        : Sprite2D
var _state      : String = "fly"    # fly | turn | jump
var _target     : Node2D = null
var _is_loot    : bool = false
var _jump_point : Vector2 = Vector2.ZERO
var _seek_t     : float = FIRST_DELAY
var _turn_t     : float = 0.0
var _normaldo   : Node2D = null
var _entered    : bool = false      # уже показался на экране (спавнится справа за краем)

func _ready() -> void:
	collision_layer = 2
	collision_mask  = 0
	add_to_group("obstacle")
	# Своя группа нужна, чтобы вора можно было УЗНАТЬ. Без неё его тег пустой:
	# иммунитет к вору (6-й уровень Бэтмена и Джокера) не срабатывал, и Дракула
	# не отжирал бандита, хотя бандит тоже человек.
	add_to_group("thief")
	_spr = Sprite2D.new()
	_spr.texture        = TEX1
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_spr.scale = Vector2.ONE * ItemSizing.content_scale(TEX1, THIEF_PX)
	add_child(_spr)
	var cs := CollisionShape2D.new()
	var c  := CircleShape2D.new()
	# Зона удара — по рисунку, а не по прежнему числу: вор бьёт на 1, и биться
	# он обязан там, где нарисован.
	c.radius = THIEF_PX * 0.40
	cs.shape = c
	add_child(cs)
	_normaldo = _find_normaldo()

func _find_normaldo() -> Node2D:
	var n := get_parent()
	while n != null:
		var nm = n.get_node_or_null("Normaldo")
		if nm != null:
			return nm
		n = n.get_parent()
	return null

# Спрайт по умолчанию смотрит ВЛЕВО; поворачиваем его В СТОРОНУ ЦЕЛИ (наведение/
# рывок), а в полёте — влево (по ходу движения).
func _aim_rot() -> float:
	if _state == "turn" or _state == "jump":
		var dir : Vector2 = _jump_point - global_position
		if dir.length() > 1.0:
			return wrapf(dir.angle() - PI, -PI, PI)
	return 0.0

func _offscreen() -> bool:
	var vp := get_viewport_rect().size
	return position.x < -OFFSCREEN_M or position.x > vp.x + OFFSCREEN_M \
		or position.y < -OFFSCREEN_M or position.y > vp.y + OFFSCREEN_M

func _process(delta: float) -> void:
	# Умираем за экраном ТОЛЬКО после того, как показались (спавнимся справа за краем).
	if not _entered:
		if position.x <= get_viewport_rect().size.x:
			_entered = true
	elif _offscreen():
		queue_free()
		return
	match _state:
		"fly":
			position.x -= speed * delta
			_seek_t -= delta
			if _seek_t <= 0.0:
				_begin_turn()
		"turn":
			position.x -= speed * delta   # летит, пока наводится
			_turn_t -= delta
			if _turn_t <= 0.0:
				_begin_jump()
		"jump":
			if _is_loot and is_instance_valid(_target):
				_jump_point = _target.global_position   # доводимся к ресурсу
			var to : Vector2 = _jump_point - global_position
			var step : float = speed * JUMP_MULT * delta
			if to.length() <= step or to.length() <= 16.0:
				global_position = _jump_point
				_arrive()
			else:
				global_position += to.normalized() * step
	# Плавно поворачиваемся В СТОРОНУ ЦЕЛИ (в полёте — влево).
	_spr.rotation = lerp_angle(_spr.rotation, _aim_rot(), clampf(delta * 9.0, 0.0, 1.0))

func _begin_turn() -> void:
	var t := _nearest_target_ahead()
	if t == null:
		_seek_t = 0.35            # впереди пусто — летим дальше, ищем чуть позже
		return
	_target     = t
	_is_loot    = t != _normaldo
	_jump_point = t.global_position
	_state  = "turn"
	_turn_t = TURN_TIME
	_play_sfx(LAUGH_SFX)      # злобный смех, пока наводится на цель

func _begin_jump() -> void:
	if is_instance_valid(_target):
		_jump_point = _target.global_position   # свежая точка на момент прыжка
	_spr.texture = TEX2
	_state = "jump"
	_play_sfx(JUMP_SFX)      # звук рывка

# Fire-and-forget SFX: временный плеер у родителя, сам чистится (звук не обрывается,
# если вор освободится по пути).
func _play_sfx(stream: AudioStream) -> void:
	if stream == null or not is_instance_valid(get_parent()):
		return
	var a := AudioStreamPlayer.new()
	a.stream    = stream
	a.volume_db = -4.0
	get_parent().add_child(a)
	a.play()
	a.finished.connect(a.queue_free)

func _arrive() -> void:
	if _is_loot and is_instance_valid(_target):
		if _target.has_method("knock_down"):
			_target.knock_down()
		elif _target.has_method("on_hit"):
			_target.on_hit()
		else:
			_target.queue_free()
	_reset_to_fly()

func _reset_to_fly() -> void:
	_target = null
	_spr.texture = TEX1
	_state  = "fly"
	_seek_t = RELAND_WAIT

# Ближайшая цель ВПЕРЕДИ (левее вора): ресурсы (пицца/доллар) или Нормальдо.
func _nearest_target_ahead() -> Node2D:
	var best : Node2D = null
	var bd := SEEK_RADIUS
	var cands : Array = []
	for grp in ["pizza", "dollar"]:
		for n in get_tree().get_nodes_in_group(grp):
			cands.append(n)
	if is_instance_valid(_normaldo):
		cands.append(_normaldo)
	for n in cands:
		if n == self or not (n is Node2D) or not is_instance_valid(n):
			continue
		var np : Vector2 = (n as Node2D).global_position
		if np.x >= global_position.x:
			continue                       # только строго ВПЕРЕДИ; сзади — нет
		var d : float = global_position.distance_to(np)
		if d < bd:
			bd = d
			best = n
	return best
