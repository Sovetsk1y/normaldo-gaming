extends Area2D

const BOOMBOX1_TEX := preload("res://assets/items/boombox1.png")
const BOOMBOX2_TEX := preload("res://assets/items/boombox2.png")
const NOTA1_TEX    := preload("res://assets/items/nota.png")
const NOTA2_TEX    := preload("res://assets/items/nota2.png")
const BOOM_TEX     := preload("res://assets/items/boom.png")
const SFX          := preload("res://assets/audio/bomb.mp3")
const SUBWOOFER    := preload("res://assets/audio/subbwoofer.mp3")

const CLEARABLE_GROUPS := [
	"pizza", "obstacle", "slowing", "bomb",
	"pizza_pack", "dollar", "money_bag", "magnet", "molotov",
]

const SCALE         := 0.27
const ANIM_FPS      := 8.0
const NOTE_INTERVAL := 0.18
const NOTE_TRAVEL   := 85.0
const NOTE_DURATION := 0.45
# Пары направлений — каждый тик вылетают две ноты симметрично
const NOTE_PAIRS := [
	[Vector2( 1.0, -1.3), Vector2(-1.0, -1.3)],
	[Vector2( 1.4, -0.4), Vector2(-1.4, -0.4)],
	[Vector2( 0.4, -1.5), Vector2(-0.4, -1.5)],
]

@export var speed: float = 250.0

var _done      : bool  = false
var _rock_t    : float = 0.0
var _pulse_t   : float = 0.0
var _anim_t    : float = 0.0
var _frame     : int   = 0
var _note_t    : float = 0.0
var _pair_idx  : int   = 0

@onready var _sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	_sprite.texture        = BOOMBOX1_TEX
	_sprite.scale          = Vector2.ONE * SCALE
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	collision_layer  = 2
	collision_mask   = 0
	add_to_group("bomb")
	var circle      := CircleShape2D.new()
	circle.radius    = 38.0
	$CollisionShape2D.shape = circle

	var stream      := SUBWOOFER.duplicate() as AudioStreamMP3
	stream.loop      = true
	var sub         := AudioStreamPlayer.new()
	sub.stream       = stream
	sub.volume_db    = -6.0
	add_child(sub)
	sub.play()

func _process(delta: float) -> void:
	if _done:
		return

	position.x -= speed * delta
	if position.x < -200.0:
		queue_free()
		return

	_rock_t          += delta * 2.2
	_sprite.rotation  = sin(_rock_t) * 0.18

	_pulse_t         += delta * 4.0
	_sprite.scale     = Vector2.ONE * SCALE * (1.0 + sin(_pulse_t) * 0.10)

	_anim_t += delta
	if _anim_t >= 1.0 / ANIM_FPS:
		_anim_t  = 0.0
		_frame   = 1 - _frame
		_sprite.texture = BOOMBOX2_TEX if _frame == 1 else BOOMBOX1_TEX

	_note_t += delta
	if _note_t >= NOTE_INTERVAL:
		_note_t = 0.0
		_spawn_note_pair()

func _spawn_note_pair() -> void:
	var pair := NOTE_PAIRS[_pair_idx % NOTE_PAIRS.size()] as Array
	_pair_idx += 1
	for i in 2:
		var dir  := (pair[i] as Vector2).normalized()
		var tex  := NOTA1_TEX if i == 0 else NOTA2_TEX
		var note := Sprite2D.new()
		note.texture        = tex
		note.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		note.scale          = Vector2.ONE * 0.09
		note.position       = global_position + Vector2(0, -10)
		note.z_index        = 2
		get_parent().add_child(note)
		var tw := note.create_tween()
		tw.tween_property(note, "position", note.position + dir * NOTE_TRAVEL, NOTE_DURATION) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(note, "modulate:a", 0.0, NOTE_DURATION) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(note.queue_free)

func explode() -> void:
	if _done:
		return
	_done = true

	var audio := AudioStreamPlayer.new()
	audio.stream = SFX
	get_parent().add_child(audio)
	audio.play()
	audio.finished.connect(audio.queue_free)

	for child in get_parent().get_children():
		if child == self:
			continue
		for grp in CLEARABLE_GROUPS:
			if child.is_in_group(grp):
				child.queue_free()
				break

	var boom       := Sprite2D.new()
	boom.texture    = BOOM_TEX
	boom.scale      = Vector2.ZERO
	boom.position   = position
	# Above everything in the play area — items (z=0), Normaldo (z=3) and the
	# running rat (z=1) all sit beneath the BOOM flash.
	boom.z_index    = 50
	get_parent().add_child(boom)
	var tw := boom.create_tween()
	tw.tween_property(boom, "scale", Vector2.ONE * 0.65, 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(boom, "modulate:a", 0.0, 0.30)
	tw.tween_callback(boom.queue_free)

	_screen_shake()
	Input.vibrate_handheld(350)

	var tw2 := create_tween()
	tw2.tween_property(self, "modulate:a", 0.0, 0.1)
	tw2.tween_callback(queue_free)

func _screen_shake() -> void:
	var game := get_parent().get_parent() as Node2D
	if not game:
		return
	# Заранее строим всю цепочку позиций — tween живёт на game и не зависит от boombox
	var tw  := game.create_tween()
	var amp := 11.0
	for i in 9:
		var pos := Vector2(randf_range(-amp, amp), randf_range(-amp * 0.75, amp * 0.75))
		tw.tween_property(game, "position", pos, 0.033)
		amp *= 0.76
	tw.tween_property(game, "position", Vector2.ZERO, 0.06)
