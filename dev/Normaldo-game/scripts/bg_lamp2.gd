extends Sprite2D
class_name BgLamp2

# Wall-mounted lantern. Single static frame, always emits a soft mutagen-green
# halo (same gradient as the ceiling lamp). Occasionally flickers — a brief
# alpha dip — every few seconds for ambient life.

const TEX := preload("res://assets/background_items/lamp2.png")

# Halo — soft warm-yellow tint matching the lamp's bright core, ~3× weaker
# than the original green version so it doesn't drown out the gameplay.
const GLOW_BASE_ALPHA   : float = 0.11
const GLOW_FLICKER_DROP : float = 0.05
const GLOW_SCALE        : float = 1.9
const GLOW_TEX_PX       : int   = 96

# Flicker timing
const FLICKER_INTERVAL_MIN : float = 4.0
const FLICKER_INTERVAL_MAX : float = 11.0
const FLICKER_DURATION_S   : float = 0.18

var _glow         : Sprite2D = null
var _next_flicker : float    = 0.0
var _flicker_left : float    = 0.0

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	texture        = TEX
	_build_glow()
	_next_flicker = randf_range(FLICKER_INTERVAL_MIN, FLICKER_INTERVAL_MAX)

func _build_glow() -> void:
	_glow = Sprite2D.new()
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	grad.colors  = PackedColorArray([
		Color(1.00, 0.95, 0.45, 1.00),  # bright warm-yellow core
		Color(0.85, 0.80, 0.25, 0.45),  # mid yellow-olive halo
		Color(0.45, 0.40, 0.08, 0.00),  # transparent dark-amber edge
	])
	var tex := GradientTexture2D.new()
	tex.gradient  = grad
	tex.fill      = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to   = Vector2(1.0, 0.5)
	tex.width     = GLOW_TEX_PX
	tex.height    = GLOW_TEX_PX
	_glow.texture           = tex
	_glow.show_behind_parent = true
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material   = mat
	_glow.modulate.a = GLOW_BASE_ALPHA
	_glow.scale      = Vector2.ONE * GLOW_SCALE
	add_child(_glow)

func _process(delta: float) -> void:
	if _glow == null:
		return
	if _flicker_left > 0.0:
		_flicker_left -= delta
		if _flicker_left <= 0.0:
			_glow.modulate.a = GLOW_BASE_ALPHA
	else:
		_next_flicker -= delta
		if _next_flicker <= 0.0:
			_glow.modulate.a = GLOW_BASE_ALPHA - GLOW_FLICKER_DROP
			_flicker_left = FLICKER_DURATION_S
			_next_flicker = randf_range(FLICKER_INTERVAL_MIN, FLICKER_INTERVAL_MAX)
