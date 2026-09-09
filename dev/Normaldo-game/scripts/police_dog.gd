extends Area2D

# ── Собака капитана ──────────────────────────────────────────────────────────
# Часть боя с [[Босс — Капитан полиции]]. Капитан спускает её с поводка, она
# ЛЕТИТ В НОРМАЛЬДО — и дальше одно из двух:
#
#   а) промахнулась и ушла в стену — ОТСКАКИВАЕТ и идёт снова, уже под другим
#      углом. Так до восьми раз;
#   б) восьмой отскок она ВСЕГДА направляет к хозяину и возвращается к нему.
#
# ── ЗАЧЕМ ОТСКОКИ ──────────────────────────────────────────────────────────
# Атака, которая летит в тебя один раз, читается по прямой: сошёл с линии —
# всё. Отскакивающая заставляет читать ГЕОМЕТРИЮ КОМНАТЫ: она вернётся, и
# откуда — зависит от того, в какую стену её отправил твой уход. Это тот же
# вопрос, что у батаранга, но заданный противником, а не игроком.
#
# ── ПОЧЕМУ ВОСЬМОЙ ОТСКОК — К ХОЗЯИНУ ──────────────────────────────────────
# Атака обязана КОНЧАТЬСЯ, и кончаться понятно. Собака, скачущая по экрану, пока
# не попадёт, — это не атака, а фон, от которого нельзя отдохнуть; а исчезнувшая
# в никуда обманывает: игрок не понял, кончилось или нет. Уход к хозяину виден и
# читается как «отбегался».
#
# Восемь — это столько, сколько нужно, чтобы отскок перестал быть случайностью и
# стал правилом, и при этом не столько, чтобы надоесть: на пятом игрок уже ждёт
# её возвращения и смотрит на стены, а не на неё.

const DOG_TEX   := preload("res://assets/items/angry_dog.png")
const SFX_BARK  := preload("res://assets/audio/dog.mp3")

const DOG_PX : float = 72.0
const SPEED  : float = 430.0
# Сколько раз она может отбиться от стены. Восьмой — всегда к хозяину.
const MAX_BOUNCES : int = 8
# Поля, за которые она не заезжает: стены арены.
const MARGIN : float = 26.0

var damage : int = 1

# Кого ловит и к кому возвращается — ставит босс.
var target : Node2D = null
var owner_node : Node2D = null

signal came_home

var _vel      : Vector2 = Vector2.ZERO
var _bounces  : int     = 0
var _homing   : bool    = false   # последний заход — к хозяину
var _sprite   : Sprite2D = null
var _spin     : float   = 0.0
var _done     : bool    = false

func _ready() -> void:
	collision_layer = 2
	collision_mask  = 0
	add_to_group("obstacle")
	add_to_group("police_dog")

	_sprite = Sprite2D.new()
	_sprite.texture        = DOG_TEX
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.z_index        = 2
	ItemSizing.fit_sprite_content(_sprite, DOG_PX)
	add_child(_sprite)

	var cs   := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(DOG_PX * 0.66, DOG_PX * 0.58)
	cs.shape  = rect
	add_child(cs)

	_aim_at_target()
	_bark()

func _aim_at_target() -> void:
	var to : Vector2 = target.global_position if is_instance_valid(target) \
		else position + Vector2(-400.0, 0.0)
	var d := to - position
	_vel = (d.normalized() if d.length() > 1.0 else Vector2.LEFT) * SPEED
	_spin = 5.0 if _vel.x < 0.0 else -5.0

func _process(delta: float) -> void:
	if _done:
		return
	position += _vel * delta
	if is_instance_valid(_sprite):
		_sprite.rotation += _spin * delta
		# Морда смотрит туда, куда летит: собака, летящая затылком вперёд,
		# читается как брошенный предмет, а не как живое.
		_sprite.flip_h = _vel.x > 0.0

	if _homing:
		_check_home()
		return
	_bounce_off_walls()

# ── ОТСКОК ОТ СТЕН ─────────────────────────────────────────────────────────
# Считается по КАЖДОЙ стене отдельно и с прижимом обратно в поле: иначе на
# быстрой собаке за кадр можно уехать за край настолько, что следующий кадр
# отразит её ещё раз и она залипнет в стене, дрожа на месте.
func _bounce_off_walls() -> void:
	var vp := get_viewport_rect().size
	var hit := false
	if position.x < MARGIN:
		position.x = MARGIN
		_vel.x = absf(_vel.x)
		hit = true
	elif position.x > vp.x - MARGIN:
		position.x = vp.x - MARGIN
		_vel.x = -absf(_vel.x)
		hit = true
	if position.y < MARGIN:
		position.y = MARGIN
		_vel.y = absf(_vel.y)
		hit = true
	elif position.y > vp.y - MARGIN:
		position.y = vp.y - MARGIN
		_vel.y = -absf(_vel.y)
		hit = true
	if not hit:
		return

	_bounces += 1
	_bark()
	if _bounces >= MAX_BOUNCES:
		_go_home()
		return
	# После отскока она СНОВА берёт курс на Нормальдо — но от стены, то есть с
	# новой стороны. Чистое зеркальное отражение отправило бы её гулять по
	# треугольнику мимо игрока, и атака перестала бы быть атакой.
	if is_instance_valid(target):
		var d := target.global_position - position
		if d.length() > 1.0:
			# Половину курса берём от отражения, половину — от направления на
			# цель: так виден и отскок, и намерение.
			_vel = (_vel.normalized() + d.normalized() * 1.35).normalized() * SPEED
			_spin = 5.0 if _vel.x < 0.0 else -5.0

func _go_home() -> void:
	_homing = true
	var to : Vector2 = owner_node.global_position if is_instance_valid(owner_node) \
		else Vector2(get_viewport_rect().size.x + 120.0, position.y)
	var d := to - position
	_vel = (d.normalized() if d.length() > 1.0 else Vector2.RIGHT) * SPEED

func _check_home() -> void:
	var to : Vector2 = owner_node.global_position if is_instance_valid(owner_node) \
		else Vector2(get_viewport_rect().size.x + 120.0, position.y)
	# ДОВОДИМ каждый кадр: хозяин на месте не стоит, и собака, взявшая курс
	# один раз, промахнулась бы мимо него и ушла за край.
	var d := to - position
	if d.length() < 46.0 or position.x > get_viewport_rect().size.x + 100.0:
		_done = true
		came_home.emit()
		queue_free()
		return
	_vel = d.normalized() * SPEED

func _bark() -> void:
	if not is_inside_tree():
		return
	var p := AudioStreamPlayer.new()
	p.stream    = SFX_BARK
	p.volume_db = -10.0
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)

# Собаку можно сбить спеллом. Она при этом «приходит домой» — атака кончается,
# и босс не ждёт её вечно.
func on_hit() -> void:
	if _done:
		return
	_done = true
	came_home.emit()
	queue_free()
