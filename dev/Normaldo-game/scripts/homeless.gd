extends Area2D

const HumanSway := preload("res://scripts/human_sway.gd")

# ── Homeless ("бомж") — obstacle for the ЖИРОБОСС mini-game ───────────────────
# homeless1 and homeless2 are TWO DIFFERENT bums (not animation frames). Each
# spawn picks one at random as a static character, sized like a normal item
# (≈ snake). `speed` is set live by FatBoss so the bum slows as the head
# deflates. Smacked by the giant head → drops dead under gravity (knock_down).

const TEXTURES := [
	preload("res://assets/items/homeless1.png"),
	preload("res://assets/items/homeless2.png"),
]

# Death cries — one is picked at random whenever the bum is broken.
const DEATH_SFX := [
	preload("res://assets/audio/homeless_die1.mp3"),
	preload("res://assets/audio/homeless_die2.mp3"),
	preload("res://assets/audio/homeless_die3.mp3"),
]

@export var speed : float = 250.0

var damage : int = 1

var _sway_t    : float   = 0.0
var _sway_ph   : float   = 0.0
var _falling   : bool    = false
var _fall_vel  : Vector2 = Vector2.ZERO
var _fall_spin : float   = 0.0

@onready var _sprite : Sprite2D = $Sprite2D

func _ready() -> void:
	_sway_ph               = HumanSway.random_phase()
	_sprite.texture        = TEXTURES[randi() % TEXTURES.size()]
	_sprite.scale          = Vector2.ONE * 0.2
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	collision_layer = 2
	collision_mask  = 0
	add_to_group("obstacle")
	add_to_group("bum")
	var rect := RectangleShape2D.new()
	rect.size = Vector2(48.0, 60.0)
	$CollisionShape2D.shape = rect

func _process(delta: float) -> void:
	if _falling:
		_fall_vel.y      += 900.0 * delta
		position         += _fall_vel * delta
		_sprite.rotation += _fall_spin * delta
		if position.y > get_viewport_rect().size.y + 200.0:
			queue_free()
		return
	position.x -= speed * delta
	# Покачивание — общий кирпич на всех людей потока (см. human_sway.gd): своё
	# у каждого разъехалось бы по амплитуде, и одна порода читалась бы тремя.
	_sway_t += delta
	HumanSway.apply(_sprite, _sway_t, _sway_ph)
	if position.x < -200.0:
		queue_free()

# Broken (by the giant head or anything else that kills him): drop dead under
# gravity + random spin, and let out one of three random death cries.
func knock_down() -> void:
	if _falling:
		return
	_falling   = true
	collision_layer = 0
	_fall_vel  = Vector2(-speed * 0.12, randf_range(-60.0, -10.0))
	_fall_spin = randf_range(-3.0, 3.0)
	var a := AudioStreamPlayer.new()
	a.stream = DEATH_SFX[randi() % DEATH_SFX.size()]
	get_parent().add_child(a)
	a.play()
	a.finished.connect(a.queue_free)
