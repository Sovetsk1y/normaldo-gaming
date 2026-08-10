extends Area2D

# ── Mutagen — trigger for the ЖИРОБОСС mini-game ──────────────────────────────
# A lone, glowing, blinking pickup that flies across like any other item (random
# lane, right→left) and frees itself off-screen if uncaught. It does NOT freeze or
# clear the run — catching it (handled in normaldo.gd, group "mutagen") is what
# fires the mini-game. Pulses size + green glow; behind it sits a light source —
# a soft radial glow plus slowly rotating rays shooting out in every direction.

const TEX       := preload("res://assets/items/mutagen.png")
const SHINE_SFX := preload("res://assets/audio/shine.mp3")

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
var _glow  : Sprite2D = null
var _rays  : Node2D   = null
var _pp    : CPUParticles2D = null
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
	var add_mat := CanvasItemMaterial.new()
	add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

	# Rotating rays — thin additive spikes radiating outward in all directions.
	# NB: keep all fx at z_index 0 (NOT negative) — negative z renders them behind
	# the background wall, which made them invisible. The face sits at z 1.
	_rays = Node2D.new()
	_rays.z_index = 0
	add_child(_rays)
	for i in 12:
		var spike := Polygon2D.new()
		spike.color    = Color(0.45, 1.0, 0.55, 0.22)
		spike.polygon  = PackedVector2Array([Vector2(0.0, -4.0), Vector2(0.0, 4.0), Vector2(78.0, 0.0)])
		spike.rotation = TAU * float(i) / 12.0
		spike.material = add_mat
		_rays.add_child(spike)

	# Soft radial glow behind the sprite.
	var grad := Gradient.new()
	grad.set_color(0, Color(0.45, 1.0, 0.55, 0.8))
	grad.set_color(1, Color(0.45, 1.0, 0.55, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient  = grad
	gt.fill      = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to   = Vector2(0.5, 0.0)
	gt.width     = 128
	gt.height    = 128
	_glow = Sprite2D.new()
	_glow.texture  = gt
	_glow.material = add_mat
	_glow.z_index  = 0
	add_child(_glow)

	# Soft round dot texture so the particles are actually visible (textureless
	# CPUParticles2D draw as ~1 px points — that's why they "weren't there").
	var dot_grad := Gradient.new()
	dot_grad.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	dot_grad.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	var dot_tex := GradientTexture2D.new()
	dot_tex.gradient  = dot_grad
	dot_tex.fill      = GradientTexture2D.FILL_RADIAL
	dot_tex.fill_from = Vector2(0.5, 0.5)
	dot_tex.fill_to   = Vector2(0.5, 0.0)
	dot_tex.width     = 24
	dot_tex.height    = 24

	# Green radioactive particles streaming out evenly in every direction
	# (spread 180° = full circle). Velocity + scale are driven each frame by
	# Normaldo's proximity (slight leak → big fountain).
	_pp = CPUParticles2D.new()
	_pp.z_index   = 0
	_pp.texture   = dot_tex
	_pp.amount    = 60
	_pp.lifetime  = 0.8
	_pp.emitting  = true
	_pp.spread    = 180.0
	_pp.direction = Vector2(0.0, -1.0)
	_pp.gravity   = Vector2.ZERO
	_pp.color     = Color(0.40, 1.0, 0.50)
	add_child(_pp)

func _process(delta: float) -> void:
	# Just sails right→left like any item; frees itself once fully off-screen.
	position.x -= speed * delta
	if position.x < -200.0:
		queue_free()
		return

	# Attention blink: pulse size + green radioactive glow.
	_pulse_t += delta * 6.0
	_spin_t  += delta * 3.0
	var p := 0.5 + 0.5 * sin(_pulse_t)
	_sprite.scale = Vector2.ONE * lerpf(0.09, 0.13, p)
	modulate = Color(1.0, 1.0, 1.0).lerp(Color(0.35, 1.7, 0.55), p)
	if is_instance_valid(_rays):
		_rays.rotation += delta * 0.8
		_rays.scale     = Vector2.ONE * lerpf(0.9, 1.15, p)
	if is_instance_valid(_glow):
		_glow.scale = Vector2.ONE * lerpf(1.4, 1.9, p)

	# ── Proximity reaction ────────────────────────────────────────────────────
	# The closer Normaldo flies, the bigger the green fountain, the harder the
	# shake, and the louder the shine (which loops continuously — no delay).
	var prox := 0.0
	var dist := INF
	if is_instance_valid(target_node):
		dist = global_position.distance_to(target_node.global_position)
		prox = clampf(inverse_lerp(PROX_FAR, PROX_NEAR, dist), 0.0, 1.0)
	if is_instance_valid(_pp):
		_pp.initial_velocity_min = lerpf(22.0, 140.0, prox)
		_pp.initial_velocity_max = lerpf(55.0, 300.0, prox)
		_pp.scale_amount_min     = lerpf(0.30, 0.90, prox)
		_pp.scale_amount_max     = lerpf(0.60, 1.80, prox)
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
