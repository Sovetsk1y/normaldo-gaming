extends Area2D

# Бомж с дорожным знаком: знак (палка + треугольник) крутится вокруг бомжа, имея
# ЯКОРЬ В НИЗУ ПАЛКИ (у бомжа), треугольник на дальнем конце сметает круг и ЛОМАЕТ
# любые предметы, которых касается. Сам бомж — обычное препятствие (урон 1, падает
# с предсмертным криком). Спавнится директором эпизода.

const HOMELESS_TEX := [
	preload("res://assets/items/homeless1.png"),
	preload("res://assets/items/homeless2.png"),
]
const SIGN_TEX := preload("res://assets/items/road_sign.png")
const DEATH_SFX := [
	preload("res://assets/audio/homeless_die1.mp3"),
	preload("res://assets/audio/homeless_die2.mp3"),
	preload("res://assets/audio/homeless_die3.mp3"),
]

@export var speed : float = 250.0
var damage : int = 1

# Пиксели на текстуре знака (512×512): центр, основание палки, центр треугольника.
const SIGN_CENTER  : Vector2 = Vector2(256.0, 256.0)
const SIGN_BASE_PX : Vector2 = Vector2(415.0, 415.0)   # низ палки → якорь вращения
const SIGN_TRI_PX  : Vector2 = Vector2(175.0, 155.0)   # центр треугольника
const SIGN_SCALE   : float = 0.22    # поменьше + палка короче → треугольник ближе к бомжу
const SIGN_SPIN    : float = -3.0    # обратная сторона вращения
const SIGN_HIT_R   : float = 34.0    # радиус коллизии на треугольнике

var _sign      : Sprite2D
var _tri_local : Vector2 = Vector2.ZERO
var _normaldo  : Node2D  = null
var _falling   : bool    = false
var _fall_vel  : Vector2 = Vector2.ZERO
var _fall_spin : float   = 0.0
var _hit : Dictionary = {}
var _tip : Area2D = null                 # коллайдер на кончике знака (ловит движок)

func _ready() -> void:
	collision_layer = 2
	collision_mask  = 0
	add_to_group("obstacle")
	add_to_group("bum")

	var body := Sprite2D.new()
	body.texture        = HOMELESS_TEX[randi() % HOMELESS_TEX.size()]
	body.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	body.scale          = Vector2.ONE * 0.2
	add_child(body)

	var cs   := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(48.0, 60.0)
	cs.shape = rect
	add_child(cs)

	# Знак: offset смещает текстуру так, что НИЗ ПАЛКИ попадает в origin ноды (=
	# центр бомжа), поэтому rotation крутит знак вокруг основания палки.
	_sign = Sprite2D.new()
	_sign.texture        = SIGN_TEX
	_sign.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sign.z_index        = 2
	# offset двигает центр текстуры так, чтобы НИЗ ПАЛКИ попал в origin ноды
	# (= центр бомжа) — тогда rotation крутит знак вокруг основания палки.
	_sign.offset         = SIGN_CENTER - SIGN_BASE_PX
	_sign.scale          = Vector2.ONE * SIGN_SCALE
	add_child(_sign)
	_tri_local = SIGN_TRI_PX - SIGN_BASE_PX   # центр треугольника относительно якоря
	_normaldo  = _find_normaldo()

	# Коллайдер на КОНЧИКЕ знака: дочерний Area2D у _sign, поэтому крутится и
	# масштабируется вместе со знаком. Движок сам сообщает о касании (area_entered)
	# — никакого покадрового скана предметов. mask = 3: слой 2 (предметы) + слой 1
	# (Нормальдо). radius делим на SIGN_SCALE, т.к. _sign отмасштабирован → в мире
	# получится ровно SIGN_HIT_R.
	_tip = Area2D.new()
	_tip.position        = _tri_local
	_tip.collision_layer = 0
	_tip.collision_mask  = 3
	_tip.monitorable     = false
	var tip_cs := CollisionShape2D.new()
	var tip_circle := CircleShape2D.new()
	tip_circle.radius = SIGN_HIT_R / SIGN_SCALE
	tip_cs.shape = tip_circle
	_tip.add_child(tip_cs)
	_sign.add_child(_tip)
	_tip.area_entered.connect(_on_tip_area)

func _on_tip_area(area: Area2D) -> void:
	if _falling or area == self or not is_instance_valid(area):
		return
	# Нормальдо (слой 1) — бьём его; предмет (слой 2) — ломаем (падением/on_hit).
	if area == _normaldo:
		if _normaldo.has_method("hazard_hit"):
			_normaldo.hazard_hit(damage)
		return
	var nid : int = area.get_instance_id()
	if _hit.has(nid):
		return
	_hit[nid] = true
	if area.has_method("knock_down"):
		area.knock_down()
	elif area.has_method("on_hit"):
		area.on_hit()
	else:
		area.queue_free()

func _find_normaldo() -> Node2D:
	var n := get_parent()
	while n != null:
		var nm = n.get_node_or_null("Normaldo")
		if nm != null:
			return nm
		n = n.get_parent()
	return null

func _process(delta: float) -> void:
	if _falling:
		_fall_vel.y      += 900.0 * delta
		position         += _fall_vel * delta
		_sign.rotation   += _fall_spin * delta
		if position.y > get_viewport_rect().size.y + 200.0:
			queue_free()
		return

	position.x -= speed * delta
	_sign.rotation += SIGN_SPIN * delta   # кончик знака (Area2D) крутится вместе с ним

	if position.x < -220.0:
		queue_free()

# Умирает от удара Нормальдо / скилла — падает + предсмертный крик.
func knock_down() -> void:
	if _falling:
		return
	_falling = true
	collision_layer = 0
	if is_instance_valid(_tip):
		_tip.set_deferred("monitoring", false)   # знак больше не бьёт, когда падает
	_fall_vel  = Vector2(-speed * 0.12, randf_range(-60.0, -10.0))
	_fall_spin = randf_range(-3.0, 3.0)
	var a := AudioStreamPlayer.new()
	a.stream = DEATH_SFX[randi() % DEATH_SFX.size()]
	get_parent().add_child(a)
	a.play()
	a.finished.connect(a.queue_free)
