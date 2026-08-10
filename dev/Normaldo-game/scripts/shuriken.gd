extends Area2D

const SHURIKEN_TEX := preload("res://assets/items/shuriken.png")

var speed          : float   = 500.0
var start_delay    : float   = 0.0
var _normaldo_ref  : Node2D  = null
var _velocity      : Vector2 = Vector2.ZERO
var _launched      : bool    = false
var _delay_t       : float   = 0.0

@onready var _sprite : Sprite2D = $Sprite2D

func _ready() -> void:
	_sprite.texture        = SHURIKEN_TEX
	_sprite.scale          = Vector2.ONE * 0.15
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	collision_layer = 2
	collision_mask  = 0
	add_to_group("obstacle")
	var cs        := CircleShape2D.new()
	cs.radius      = 16.0
	$CollisionShape2D.shape = cs

func init(normaldo: Node2D, spd: float, delay: float = 0.0) -> void:
	_normaldo_ref = normaldo
	speed         = spd
	start_delay   = delay

func _process(delta: float) -> void:
	_sprite.rotation += 6.5 * delta

	if not _launched:
		_delay_t += delta
		if _delay_t >= start_delay:
			_launched = true
			if is_instance_valid(_normaldo_ref):
				var dir   := (_normaldo_ref.global_position - global_position).normalized()
				_velocity  = dir * speed
			else:
				_velocity  = Vector2(-speed, 0.0)
	else:
		global_position += _velocity * delta
		var vp := get_viewport_rect()
		if (global_position.x < -300.0 or global_position.x > vp.size.x + 300.0 or
				global_position.y < -300.0 or global_position.y > vp.size.y + 300.0):
			queue_free()
