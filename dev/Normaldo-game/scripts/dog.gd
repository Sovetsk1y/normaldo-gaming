extends Area2D

const DOG_TEX := preload("res://assets/items/angry_dog.png")
const SFX     := preload("res://assets/audio/dog.mp3")

# Death whines — one picked at random when the dog is broken.
const DEATH_SFX := [
	preload("res://assets/audio/dog_die1.mp3"),
	preload("res://assets/audio/dog_die2.mp3"),
]

@export var speed : float = 250.0

var damage    : int     = 1
var _wobble_t : float   = 0.0
var _hit      : bool    = false
var _fly_vel  : Vector2 = Vector2.ZERO

var _falling   : bool    = false
var _fall_spin : float   = 0.0

@onready var _sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	_sprite.texture        = DOG_TEX
	_sprite.scale          = Vector2.ONE * 0.20
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	collision_layer = 2
	collision_mask  = 0
	add_to_group("obstacle")
	var rect  := RectangleShape2D.new()
	rect.size  = Vector2(83, 68)
	$CollisionShape2D.shape = rect

func _process(delta: float) -> void:
	if _falling:
		_fly_vel.y      += 900.0 * delta
		position        += _fly_vel * delta
		_sprite.rotation += _fall_spin * delta
		if position.y > get_viewport_rect().size.y + 200.0:
			queue_free()
		return
	if not _hit:
		position.x      -= speed * delta
		_wobble_t       += delta * 7.0
		_sprite.rotation = sin(_wobble_t) * 0.10
		if position.x < -200.0:
			queue_free()
	else:
		position   += _fly_vel * delta
		_fly_vel.y  -= 600.0 * delta
		var vp := get_viewport_rect()
		if position.x > vp.size.x + 200.0 or position.y < -200.0:
			queue_free()

# Smacked by the giant ЖИРОБОСС head: drop dead under gravity + random spin.
func knock_down() -> void:
	if _falling or _hit:
		return
	_falling   = true
	collision_layer = 0
	_fly_vel   = Vector2(-speed * 0.12, randf_range(-60.0, -10.0))
	_fall_spin = randf_range(-3.0, 3.0)
	var a := AudioStreamPlayer.new()
	a.stream = DEATH_SFX[randi() % DEATH_SFX.size()]
	get_parent().add_child(a)
	a.play()
	a.finished.connect(a.queue_free)

func on_hit() -> void:
	if _hit:
		return
	_hit = true
	collision_layer = 0
	_fly_vel = Vector2(speed * 2.8, -speed * 0.5)

	var audio  := AudioStreamPlayer.new()
	audio.stream = SFX
	get_parent().add_child(audio)
	audio.play()
	audio.finished.connect(audio.queue_free)

	var tw := create_tween()
	for i in 5:
		tw.tween_property(_sprite, "position:x", 6.0 if i % 2 == 0 else -6.0, 0.035)
	tw.tween_property(_sprite, "position:x", 0.0, 0.035)
