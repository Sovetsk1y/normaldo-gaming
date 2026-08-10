extends Area2D

const FRAMES_DIR  := "res://assets/items/fire2/animations/The_flames_flicker_and_dance_rhythmically_with_th/unknown/"
const FRAME_COUNT := 5
const ANIM_FPS    := 10.0
const FINAL_SCALE := 0.83

var damage : int   = 1
var speed  : float = 250.0

# Кадры огня одинаковы у всех экземпляров — строим SpriteFrames один раз и
# переиспользуем, чтобы залп из нескольких огней (до 8 на молотов) не грузил
# кадры и не плодил ресурсы на каждом спавне.
static var _shared_frames : SpriteFrames

@onready var _anim: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	if _shared_frames == null:
		_shared_frames = SpriteFrames.new()
		_shared_frames.add_animation("burn")
		_shared_frames.set_animation_loop("burn", true)
		_shared_frames.set_animation_speed("burn", ANIM_FPS)
		for i in FRAME_COUNT:
			var tex := load(FRAMES_DIR + "frame_%03d.png" % i) as Texture2D
			_shared_frames.add_frame("burn", tex)

	_anim.sprite_frames  = _shared_frames
	_anim.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_anim.scale          = Vector2.ZERO
	_anim.play("burn")

	collision_layer = 2
	collision_mask  = 2
	add_to_group("obstacle")
	add_to_group("fire")
	area_entered.connect(_on_area_entered)
	var circle    := CircleShape2D.new()
	circle.radius  = 18.0
	$CollisionShape2D.shape = circle

	var tw := create_tween()
	tw.tween_property(_anim, "scale", Vector2.ONE * FINAL_SCALE, 0.22) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	var embers                 := CPUParticles2D.new()
	embers.emitting             = true
	embers.amount               = 10
	embers.lifetime             = 0.50
	embers.explosiveness        = 0.0
	embers.direction            = Vector2(0, -1)
	embers.spread               = 65.0
	embers.gravity              = Vector2(0, -15)
	embers.initial_velocity_min = 18.0
	embers.initial_velocity_max = 45.0
	embers.scale_amount_min     = 2.0
	embers.scale_amount_max     = 5.0
	var eg                     := Gradient.new()
	eg.set_color(0,             Color(1.00, 0.85, 0.15, 1.00))
	eg.add_point(0.45,          Color(1.00, 0.32, 0.00, 0.80))
	eg.add_point(1.00,          Color(0.20, 0.00, 0.00, 0.00))
	embers.color_ramp           = eg
	add_child(embers)

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("fire"):
		return
	if area.has_method("explode"):
		area.explode()
	elif area.has_method("burst"):
		area.burst()
	else:
		area.queue_free()

func _process(delta: float) -> void:
	position.x -= speed * delta
	if position.x < -200.0:
		queue_free()
