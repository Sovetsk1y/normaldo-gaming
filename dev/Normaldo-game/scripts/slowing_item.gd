extends Area2D

@export var speed         : float = 250.0
@export var slow_duration : float = 4.0
@export var slow_sound    : AudioStream

var _rot_speed: float = 0.0

func _ready() -> void:
	var circle      := CircleShape2D.new()
	circle.radius    = 30.0
	$CollisionShape2D.shape = circle
	add_to_group("slowing")
	set_meta("slow_duration", slow_duration)
	set_meta("slow_sound", slow_sound)
	var tag := "banana"
	if slow_sound and "beer" in slow_sound.resource_path:
		tag = "beer"
	set_meta("item_tag", tag)
	if tag != "banana":
		_rot_speed = (0.6 + randf() * 0.3) * (1.0 if randf() > 0.5 else -1.0)

func _process(delta: float) -> void:
	position.x        -= speed * delta
	$Sprite2D.rotation += _rot_speed * delta
	if position.x < -200.0:
		queue_free()
