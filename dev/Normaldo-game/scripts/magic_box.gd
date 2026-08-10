extends Area2D

# ── Мэджик бокс ───────────────────────────────────────────────────────────────
# Пойманный ящик перелетает Нормальдо на голову и восемь раз выплёвывает
# СЛУЧАЙНЫЙ предмет: тот вылетает из-под крышки и разлетается по свободным
# лейнам, а долетев — становится осязаемым.
#
# Пул намеренно смешанный (см. spawner.build_random_item): в основном пицца и
# доллары, но с шансом вылетит банан, змея или чёрный туз. Ящик — это ставка, а
# не подарок; иначе он превращается в бесплатную пиццу и обесценивает поток.
#
# Пока идёт раздача, предметы летят по тюину с выключенной коллизией — иначе
# игрок собирал бы их прямо у себя над головой, не двигаясь.
#
# См. /Концепция/Эффекты и бонусы.md → «Мэджик бокс»

const BOX_TEX  := preload("res://assets/items/magic_box.png")
const OPEN_SFX := preload("res://assets/audio/magic_poof.mp3")
const POP_SFX  := preload("res://assets/audio/magic_glitter.mp3")

const HEAD_OFFSET  : Vector2 = Vector2(0.0, -62.0)
const SPIT_COUNT   : int     = 8
const SPIT_PERIOD  : float   = 0.22
const FLY_TIME     : float   = 0.34
const LANE_COUNT   : int     = 5
# Куда раскидываем: не ближе четверти экрана (иначе предмет прилетает в лицо) и
# не дальше 0.85 (иначе улетает за правый край раньше, чем долетит).
const SPREAD_X_MIN : float   = 0.28
const SPREAD_X_MAX : float   = 0.85

@export var speed : float = 250.0

var _pulse_t  : float    = 0.0
var _opened   : bool     = false
var _normaldo : Node2D   = null
var _sprite   : Sprite2D = null

func _ready() -> void:
	collision_layer = 2
	collision_mask  = 0
	add_to_group("magic_box")

	_sprite = Sprite2D.new()
	_sprite.texture = BOX_TEX
	ItemSizing.fit_sprite(_sprite, ItemSizing.BASE_PX * 1.15)
	add_child(_sprite)

	var cs        := CollisionShape2D.new()
	var circle    := CircleShape2D.new()
	circle.radius  = ItemSizing.BASE_R
	cs.shape       = circle
	add_child(cs)

func _process(delta: float) -> void:
	_pulse_t += delta * 3.0
	_sprite.rotation = sin(_pulse_t) * 0.18

	if _opened:
		if is_instance_valid(_normaldo):
			position = _normaldo.position + HEAD_OFFSET
		return

	position.x -= speed * delta
	if position.x < -200.0:
		queue_free()

func open(normaldo: Node2D) -> void:
	if _opened:
		return
	_opened         = true
	_normaldo       = normaldo
	collision_layer = 0

	_play(OPEN_SFX)
	if is_instance_valid(_normaldo):
		position = _normaldo.position + HEAD_OFFSET

	var spawner := get_parent()
	var lanes   := _lane_centers()
	var last_lane : int = -1

	for i in SPIT_COUNT:
		if not is_instance_valid(self) or not is_instance_valid(spawner):
			return
		# Подряд в один лейн не кидаем — иначе предметы садятся друг на друга.
		var lane := randi() % LANE_COUNT
		if lane == last_lane:
			lane = (lane + 1 + randi() % (LANE_COUNT - 1)) % LANE_COUNT
		last_lane = lane
		_spit(spawner, Vector2(
			get_viewport_rect().size.x * randf_range(SPREAD_X_MIN, SPREAD_X_MAX),
			lanes[lane]))
		await get_tree().create_timer(SPIT_PERIOD).timeout

	if not is_instance_valid(self):
		return
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2.ZERO, 0.24) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)

func _lane_centers() -> Array:
	var h      := get_viewport_rect().size.y
	var result : Array = []
	for i in LANE_COUNT:
		result.append(h / LANE_COUNT * (i + 0.5))
	return result

func _spit(spawner: Node, to: Vector2) -> void:
	if not spawner.has_method("build_random_item"):
		return
	var node : Node2D = spawner.build_random_item(speed)
	if node == null:
		return

	node.position = position
	spawner.add_child(node)
	_play(POP_SFX, -8.0)

	# Пока летит по дуге — не двигается сам и не ловится.
	node.set_process(false)
	var had_layer : int = node.collision_layer if node is CollisionObject2D else 2
	if node is CollisionObject2D:
		node.collision_layer = 0

	var tw := node.create_tween()
	tw.tween_property(node, "position", to, FLY_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void:
		if not is_instance_valid(node):
			return
		if node is CollisionObject2D:
			node.collision_layer = had_layer
		node.set_process(true))

func _play(stream: AudioStream, vol_db: float = 0.0) -> void:
	var p := get_parent()
	if p == null:
		return
	var a := AudioStreamPlayer.new()
	a.stream    = stream
	a.volume_db = vol_db
	p.add_child(a)
	a.play()
	a.finished.connect(a.queue_free)
