extends Area2D

# ── Mutagen — trigger for the ЖИРОБОСС mini-game ──────────────────────────────
# A lone, glowing, blinking pickup that flies across like any other item (random
# lane, right→left) and frees itself off-screen if uncaught. It does NOT freeze or
# clear the run — catching it (handled in normaldo.gd, group "mutagen") is what
# fires the mini-game. Pulses size + green glow; behind it sits a light source —
# a soft radial glow plus slowly rotating rays shooting out in every direction.

const TEX       := preload("res://assets/items/mutagen.png")
const SHINE_SFX := preload("res://assets/audio/shine.mp3")

# Свечение — ОБЩИЙ КИРПИЧ (scripts/minigame_glow.gd), тот же, что у коробки
# пиццы. Разница между ними ровно одна — цвет: зелёный зовёт в ЖИРОБОССА,
# оранжевый в ПИЦЦА-ПАТИ. Всё остальное — число лучей, скорость вращения,
# размер фонтана — обязано совпадать, иначе «предмет-ключ» перестаёт быть
# одним узнаваемым знаком и распадается на два похожих красивых предмета.
const GLOW := preload("res://scripts/minigame_glow.gd")

const COL_GLOW  : Color = Color(0.45, 1.00, 0.55)
const COL_PP    : Color = Color(0.40, 1.00, 0.50)
# Цвет вспышки самого лица на пике биения. Зелёный ВЫШЕ единицы — это пересвет,
# и он тут намеренный: предмет должен вспыхивать, а не просто зеленеть.
const COL_BLINK : Color = Color(0.35, 1.70, 0.55)

@export var speed       : float = 240.0

# Proximity reaction window: at PROX_FAR (px) it's the calm baseline, at
# PROX_NEAR it's maxed out (fountain + violent shake + loud shine).
const PROX_FAR  : float = 420.0
const PROX_NEAR : float = 45.0
# Shine only kicks in once Normaldo is within ~a couple of head-widths.
const SHINE_RANGE : float = 190.0

# Set by FatBoss — the head we react to as it approaches.
var target_node : Node2D = null

var _pulse_t : float = 0.0
var _spin_t  : float = 0.0

@onready var _sprite : Sprite2D = $Sprite2D
var _fx    : Node2D = null
var _shine : AudioStreamPlayer = null

func _ready() -> void:
	_sprite.texture        = TEX
	_sprite.scale          = Vector2.ONE * 0.10
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.z_index        = 1   # mutagen face sits in front of its own light/fx
	collision_layer = 2
	collision_mask  = 0
	add_to_group("mutagen")
	var circle := CircleShape2D.new()
	circle.radius = 26.0
	$CollisionShape2D.shape = circle
	_build_light()

	# Shine sting looping continuously (no gap) while the mutagen is on screen.
	# Duplicate the stream so we can force looping without mutating the const.
	var shine_stream := SHINE_SFX.duplicate()
	if shine_stream is AudioStreamMP3:
		(shine_stream as AudioStreamMP3).loop = true
	_shine = AudioStreamPlayer.new()
	_shine.stream    = shine_stream
	_shine.volume_db = -14.0
	add_child(_shine)
	# Not played here — _process starts it only once Normaldo is close enough.

func _build_light() -> void:
	_fx = GLOW.make(COL_GLOW, COL_PP)
	add_child(_fx)

func _process(delta: float) -> void:
	# Just sails right→left like any item; frees itself once fully off-screen.
	ItemFlow.advance(self, speed, delta)
	if ItemFlow.gone(self, 200.0):
		queue_free()
		return

	# Attention blink: pulse size + green radioactive glow.
	_pulse_t += delta * 6.0
	_spin_t  += delta * 3.0
	var p := 0.5 + 0.5 * sin(_pulse_t)
	_sprite.scale = Vector2.ONE * lerpf(0.09, 0.13, p)
	modulate = Color(1.0, 1.0, 1.0).lerp(COL_BLINK, p)

	# ── Proximity reaction ────────────────────────────────────────────────────
	# The closer Normaldo flies, the bigger the green fountain, the harder the
	# shake, and the louder the shine (which loops continuously — no delay).
	var prox := 0.0
	var dist := INF
	if is_instance_valid(target_node):
		dist = global_position.distance_to(target_node.global_position)
		prox = clampf(inverse_lerp(PROX_FAR, PROX_NEAR, dist), 0.0, 1.0)
	if is_instance_valid(_fx):
		_fx.call("tick", delta, p, prox)
	var shake := lerpf(0.0, 7.0, prox)
	_sprite.position = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake
	_sprite.rotation = sin(_spin_t) * 0.22 + randf_range(-1.0, 1.0) * 0.16 * prox

	# Shine only plays once Normaldo is within ~2 head-widths; louder as he nears.
	if is_instance_valid(_shine):
		if dist <= SHINE_RANGE:
			if not _shine.playing:
				_shine.play()
			var st := clampf(inverse_lerp(SHINE_RANGE, PROX_NEAR, dist), 0.0, 1.0)
			_shine.volume_db = lerpf(-14.0, 0.0, st)
		elif _shine.playing:
			_shine.stop()
