extends Area2D

const MAGNET_TEX      := preload("res://assets/items/magnet.png")
const MAGNET_SFX      := preload("res://assets/audio/magnet.mp3")
const MAGNET_DURATION := 3.0
const ABOVE_HEAD      := Vector2(0, -72)  # локальная позиция над головой нормальдо

@export var speed: float = 250.0

var _state   : int   = 0  # 0=летит, 1=над головой
var _pulse_t : float = 0.0
var _sparks  : CPUParticles2D
var _audio   : AudioStreamPlayer

@onready var _sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	_sprite.texture        = MAGNET_TEX
	_sprite.scale          = Vector2.ONE * 0.09
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	collision_layer = 2
	collision_mask  = 0
	add_to_group("magnet")
	var circle    := CircleShape2D.new()
	circle.radius  = 32.0
	$CollisionShape2D.shape = circle

	var stream        := (MAGNET_SFX as AudioStreamMP3).duplicate() as AudioStreamMP3
	stream.loop        = true
	_audio             = AudioStreamPlayer.new()
	_audio.stream      = stream
	_audio.volume_db   = -80.0
	add_child(_audio)

	_sparks                     = CPUParticles2D.new()
	_sparks.z_index              = -1
	_sparks.emitting             = false
	_sparks.amount               = 18
	_sparks.lifetime             = 0.55
	_sparks.explosiveness        = 0.0
	_sparks.direction            = Vector2.ZERO
	_sparks.spread               = 180.0
	_sparks.gravity              = Vector2(0, -30)
	_sparks.initial_velocity_min = 30.0
	_sparks.initial_velocity_max = 70.0
	_sparks.scale_amount_min     = 2.5
	_sparks.scale_amount_max     = 4.5
	_sparks.emission_shape       = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_sparks.emission_sphere_radius = 10.0
	_sparks.color                = Color(0.4, 0.8, 1.0)
	_sparks.color_ramp           = _make_spark_gradient()
	add_child(_sparks)

func _process(delta: float) -> void:
	_pulse_t += delta * 3.5
	_sprite.scale = Vector2.ONE * 0.09 * (1.0 + sin(_pulse_t) * 0.12)
	if _state == 0:
		position.x -= speed * delta
		if position.x < -200.0:
			queue_free()

func _make_spark_gradient() -> Gradient:
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 1.0, 1.0, 1.0))       # белый центр
	g.add_point(0.3, Color(0.5, 0.9, 1.0, 1.0))     # голубой
	g.add_point(0.7, Color(0.1, 0.4, 1.0, 0.7))     # синий
	g.add_point(1.0, Color(0.05, 0.1, 0.8, 0.0))    # тёмно-синий прозрачный
	return g

func activate(normaldo: Node2D) -> void:
	_state          = 1
	collision_layer = 0
	collision_mask  = 0
	monitoring      = false
	monitorable     = false

	# Перемещаем в дерево нормальдо, сохраняя мировую позицию
	var world_pos := global_position
	get_parent().remove_child(self)
	normaldo.add_child(self)
	global_position = world_pos

	# Летим над голову
	var tw := create_tween()
	tw.tween_property(self, "position", ABOVE_HEAD, 0.4) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# Запускаем звук и искры как только магнит долетел до позиции
	await get_tree().create_timer(0.4).timeout
	_sparks.emitting = true
	_audio.play()
	var fade_in := create_tween()
	fade_in.tween_property(_audio, "volume_db", -5.0, 0.3)

	# Через оставшееся время — гасим искры и фейдим звук вместе со спрайтом
	await get_tree().create_timer(MAGNET_DURATION - 0.4).timeout
	_sparks.emitting = false
	var fade := create_tween()
	fade.tween_property(self, "modulate:a", 0.0, 0.5)
	fade.parallel().tween_property(_audio, "volume_db", -80.0, 0.5)
	fade.tween_callback(queue_free)
