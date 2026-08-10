extends Area2D

const BOMB_TEX := preload("res://assets/items/bomb.png")
const BOOM_TEX := preload("res://assets/items/boom.png")
const SFX      := preload("res://assets/audio/bomb.mp3")

var speed: float     = 250.0
var _exploding: bool = false
var _wobble_t: float = 0.0

@onready var _sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	_sprite.texture = BOMB_TEX
	_sprite.scale   = Vector2.ONE * 0.21
	collision_layer = 2
	collision_mask  = 0
	add_to_group("bomb")
	var circle     := CircleShape2D.new()
	circle.radius   = 30.0
	$CollisionShape2D.shape = circle

func _process(delta: float) -> void:
	if _exploding:
		return
	position.x -= speed * delta
	if position.x < -200.0:
		queue_free()
		return
	_wobble_t      += delta * 2.5
	_sprite.rotation = sin(_wobble_t) * 0.12

func explode() -> void:
	if _exploding:
		return
	_exploding = true

	var audio := AudioStreamPlayer.new()
	audio.stream = SFX
	get_parent().add_child(audio)
	audio.play()
	audio.finished.connect(audio.queue_free)

	# Clear every item currently on screen
	for child in get_parent().get_children():
		if child == self:
			continue
		if child.is_in_group("pizza") or child.is_in_group("obstacle") \
				or child.is_in_group("pizza_pack") or child.is_in_group("bomb"):
			child.queue_free()

	# Boom flash at bomb position
	var boom := Sprite2D.new()
	boom.texture  = BOOM_TEX
	boom.scale    = Vector2.ZERO
	boom.position = position
	# Sit above items / Normaldo / running rat (z = 0/1/3) for the flash.
	boom.z_index  = 50
	get_parent().add_child(boom)
	var tw := boom.create_tween()
	tw.tween_property(boom, "scale", Vector2.ONE * 0.55, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(boom, "modulate:a", 0.0, 0.28)
	tw.tween_callback(boom.queue_free)

	# Fade bomb out
	var tw2 := create_tween()
	tw2.tween_property(self, "modulate:a", 0.0, 0.1)
	tw2.tween_callback(queue_free)
