extends Area2D

@export var speed        : float  = 250.0
@export var is_eatable   : bool   = true
@export var damage       : int    = 1
@export var rotates      : bool   = true
@export var slow_on_hit  : bool   = false
@export var slow_duration: float  = 0.0
@export var pulses       : bool   = false
@export var item_group   : String = ""
@export var skin_tag     : String = ""

var _rot_speed  : float   = 0.0
var _base_scale : Vector2 = Vector2.ONE
var _pulse_t    : float   = 0.0

var _falling    : bool    = false
var _fall_vel   : Vector2 = Vector2.ZERO
var _fall_spin  : float   = 0.0
var knock_sound : AudioStream = null   # played when smacked off the giant head

func _ready() -> void:
	var circle := CircleShape2D.new()
	circle.radius = 28.0 if is_eatable else 30.0
	$CollisionShape2D.shape = circle
	var group := item_group if item_group != "" else ("pizza" if is_eatable else "obstacle")
	add_to_group(group)
	var base := 1.2 if is_eatable else 0.7
	_rot_speed  = (base + randf() * 0.4) * (1.0 if randf() > 0.5 else -1.0)
	_base_scale = $Sprite2D.scale

func _process(delta: float) -> void:
	if _falling:
		_fall_vel.y      += 900.0 * delta
		position         += _fall_vel * delta
		$Sprite2D.rotation += _fall_spin * delta
		if position.y > get_viewport_rect().size.y + 200.0:
			queue_free()
		return
	position.x -= speed * delta
	if rotates:
		$Sprite2D.rotation += _rot_speed * delta
	if pulses:
		_pulse_t += delta * 3.5
		$Sprite2D.scale = _base_scale * (1.0 + sin(_pulse_t) * 0.12)
	if position.x < -200.0:
		queue_free()

# Smacked by the giant ЖИРОБОСС head: drop dead under gravity with a slight
# random spin, as if the item bounced off and got carried by the impact.
func knock_down() -> void:
	if _falling:
		return
	_falling   = true
	collision_layer = 0
	_fall_vel  = Vector2(-speed * 0.12, randf_range(-60.0, -10.0))
	_fall_spin = randf_range(-3.0, 3.0)
	if knock_sound:
		var a := AudioStreamPlayer.new()
		a.stream = knock_sound
		get_parent().add_child(a)
		a.play()
		a.finished.connect(a.queue_free)
