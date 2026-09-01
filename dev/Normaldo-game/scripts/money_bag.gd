extends Area2D

const BAG_TEX    := preload("res://assets/items/money_bag.png")
const DOLLAR_TEX := preload("res://assets/items/dollar.png")
const DOLLAR_SFX := preload("res://assets/audio/dollars.mp3")
const ITEM_SCENE := preload("res://scenes/item.tscn")

const DOLLAR_COUNT := 8
const DOLLAR_SCALE := 0.36

# Мешок — САМЫЙ КРУПНЫЙ ресурс в потоке, и это его единственная реклама. Он
# стоит на линии один и обещает восемь долларов сразу; чтобы за ним имело смысл
# лететь через полэкрана, его надо УВИДЕТЬ раньше, чем он поравняется с
# головой.
#
# Раньше здесь стоял голый scale 0.36 по кадру 90×83 — то есть 32 пикселя
# рисунка, меньше банана (52) и вдвое меньше предмета-эффекта (58). Джекпот
# выглядел мелочью. Теперь размер считает ItemSizing по РИСУНКУ, как у всех
# остальных предметов, и берётся он в полтора базовых.
const BAG_PX : float = 84.0

@export var speed: float = 250.0

var _burst_done : bool  = false
var _pulse_t    : float = 0.0
# Базовый масштаб, вокруг которого дышит пульс. Держим числом, а не пересчётом
# каждый кадр: пульс умножает именно его.
var _bag_scale  : float = 1.0

@onready var _sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	_sprite.texture  = BAG_TEX
	_bag_scale       = ItemSizing.content_scale(BAG_TEX, BAG_PX)
	_sprite.scale    = Vector2.ONE * _bag_scale
	collision_layer  = 2
	collision_mask   = 0
	add_to_group("money_bag")
	var circle       := CircleShape2D.new()
	# Зона подбора едет за рисунком: у мешка это ресурс, и промахнуться мимо
	# нарисованного из-за того, что круг остался от прежнего размера, — худший
	# вид несправедливости.
	circle.radius     = BAG_PX * 0.46
	$CollisionShape2D.shape = circle

func _process(delta: float) -> void:
	if _burst_done:
		return
	position.x -= speed * delta
	if position.x < -200.0:
		queue_free()
		return
	_pulse_t      += delta * 3.5
	_sprite.scale  = Vector2.ONE * _bag_scale * (1.0 + sin(_pulse_t) * 0.12)

func burst(mult: int = 1) -> void:
	if _burst_done:
		return
	_burst_done = true

	var audio := AudioStreamPlayer.new()
	audio.stream = DOLLAR_SFX
	get_parent().add_child(audio)
	audio.play()
	audio.finished.connect(audio.queue_free)

	var vp   := get_viewport_rect()
	var vp_h := vp.size.y
	var vp_w := vp.size.x

	# Scatter dollars: evenly distributed vertically with jitter,
	# staggered horizontally so they arrive at different times
	var total_dollars := DOLLAR_COUNT * mult
	var indices := range(total_dollars)
	(indices as Array).shuffle()
	for i in total_dollars:
		var dollar        := ITEM_SCENE.instantiate()
		dollar.speed       = speed
		dollar.is_eatable  = false
		dollar.damage      = 0
		dollar.rotates     = true
		dollar.pulses      = true
		dollar.item_group  = "dollar"
		var spr: Sprite2D  = dollar.get_node("Sprite2D")
		spr.texture        = DOLLAR_TEX
		spr.scale          = Vector2.ONE * DOLLAR_SCALE
		var row_h          := vp_h / total_dollars
		var base_y         = row_h * (indices[i] + 0.5)
		var jitter         := randf_range(-row_h * 0.35, row_h * 0.35)
		dollar.position    = Vector2(vp_w + randf_range(40.0, 220.0), base_y + jitter)
		get_parent().add_child(dollar)

	var tw := create_tween()
	tw.tween_property(self, "modulate", Color(1, 1, 1, 0), 0.25)
	tw.tween_callback(queue_free)
