extends Sprite2D
class_name BgLamp

# Ceiling-decor lamp. One 9-frame sheet (dim → bright). On spawn the lamp
# rolls a 50/50: either plays all 9 frames (full lit) or just the first 3
# (partial dim). Some lamps spawn already done so the lighting moment is
# distributed across the whole screen, not clumped near the right edge.
#
# Pivot is at the TOP-CENTER (where the chain meets the ceiling), so we can
# rotate the lamp to swing it. Normaldo brushing past the lamp triggers the
# swing — direction matches his horizontal velocity at impact.

const FRAME_W      : int   = 48
const FRAME_H      : int   = 48
const FRAME_COUNT  : int   = 9
const FRAME_TIME   : float = 0.14

const SHEET_UP := preload("res://assets/background_items/lamp1/lamp1_light_up_down_sheet.png")

const PARTIAL_CHANCE : float = 0.5
const PARTIAL_FRAMES : int   = 3
# Some lamps appear already lit so animation moments are spread across the screen.
const PRE_LIT_CHANCE : float = 0.3
const DELAY_MIN_S    : float = 0.0
const DELAY_MAX_S    : float = 5.0

# Swing parameters
const SWING_AMPLITUDE_DEG : float = 22.0
const SWING_DURATION_S    : float = 1.4
const SWING_FREQUENCY     : float = 3.5  # oscillations per second
const HIT_COOLDOWN_S      : float = 0.5

# Light halo (mutagen-green tint, half as strong as the original warm version)
const GLOW_MAX_ALPHA  : float = 0.22
const GLOW_MIN_SCALE  : float = 0.6
const GLOW_MAX_SCALE  : float = 2.0
const GLOW_TEX_PX     : int   = 96
const GLOW_PEAK_FRAME : int   = 2     # index 2 = 3rd frame (peak brightness)
const GLOW_BASE_F0    : float = 0.15  # how bright the lamp glows on frame 0

enum State { WAITING, PLAYING, FROZEN }

var _state         : int   = State.WAITING
var _frame_index   : int   = 0
var _frame_timer   : float = 0.0
var _delay_left    : float = 0.0
var _end_frame     : int   = FRAME_COUNT - 1

var _swing_active  : bool  = false
var _swing_dir     : int   = 1
var _swing_time    : float = 0.0
var _hit_cooldown  : float = 0.0

var _glow : Sprite2D = null

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	region_enabled = true
	texture        = SHEET_UP
	# Pivot at top-center: shift the visible texture down by half a frame so
	# the sprite's origin sits where the chain attaches to the ceiling.
	offset         = Vector2(0.0, FRAME_H * 0.5)
	_end_frame     = (PARTIAL_FRAMES - 1) if randf() < PARTIAL_CHANCE else (FRAME_COUNT - 1)

	# Build the soft glow first so _set_frame can update its intensity.
	_build_glow()

	if randf() < PRE_LIT_CHANCE:
		_state = State.FROZEN
		_set_frame(_end_frame)
	else:
		_delay_left = randf_range(DELAY_MIN_S, DELAY_MAX_S)
		_set_frame(0)

	_build_hitbox()

func _build_glow() -> void:
	_glow = Sprite2D.new()
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	grad.colors  = PackedColorArray([
		Color(0.65, 1.00, 0.55, 1.00),  # bright mutagen-green core
		Color(0.30, 0.85, 0.40, 0.45),  # mid-green halo
		Color(0.10, 0.55, 0.25, 0.00),  # transparent dark-green edge
	])
	var tex := GradientTexture2D.new()
	tex.gradient  = grad
	tex.fill      = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to   = Vector2(1.0, 0.5)
	tex.width     = GLOW_TEX_PX
	tex.height    = GLOW_TEX_PX
	_glow.texture           = tex
	_glow.position          = Vector2(0.0, FRAME_H * 0.65)
	_glow.show_behind_parent = true
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material   = mat
	_glow.modulate.a = 0.0
	_glow.scale      = Vector2.ONE * GLOW_MIN_SCALE
	add_child(_glow)

func _update_glow() -> void:
	if _glow == null:
		return
	# Glow follows a triangle curve:
	#   frame 0           → small base glow (GLOW_BASE_F0)
	#   frame GLOW_PEAK   → full brightness (peak flicker)
	#   frame last (8)    → 0 (lamp has gone out)
	# PARTIAL lamps stop at the peak frame → stay fully lit.
	# FULL lamps run all the way through → end extinguished.
	var t : float
	if _frame_index <= GLOW_PEAK_FRAME:
		var u := float(_frame_index) / float(GLOW_PEAK_FRAME)
		t = lerp(GLOW_BASE_F0, 1.0, u)
	else:
		var u := float(_frame_index - GLOW_PEAK_FRAME) \
			/ float(FRAME_COUNT - 1 - GLOW_PEAK_FRAME)
		t = lerp(1.0, 0.0, u)
	_glow.modulate.a = t * GLOW_MAX_ALPHA
	_glow.scale = Vector2.ONE * lerp(GLOW_MIN_SCALE, GLOW_MAX_SCALE, t)

func _build_hitbox() -> void:
	var area := Area2D.new()
	area.monitoring  = true
	area.monitorable = false  # we listen for Normaldo, not the other way around
	var shape  := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 12.0  # local, will scale with sprite
	shape.shape    = circle
	shape.position = Vector2(0.0, FRAME_H * 0.62)  # over the lamp body, below the chain
	area.add_child(shape)
	area.area_entered.connect(_on_area_entered)
	add_child(area)

func _set_frame(idx: int) -> void:
	_frame_index = idx
	region_rect = Rect2(idx * FRAME_W, 0, FRAME_W, FRAME_H)
	_update_glow()

func _on_area_entered(area: Area2D) -> void:
	if _hit_cooldown > 0.0 or area == null:
		return
	# Only Normaldo exposes `velocity_x`. Anything else: ignore.
	if not ("velocity_x" in area):
		return
	var vx : float = area.velocity_x
	# Stationary actors (e.g. boxing glove during its charge phase) don't
	# transfer momentum to the lamp.
	if absf(vx) < 50.0:
		return
	# Pivot is at the top, so positive Godot rotation tilts the body LEFT.
	# Invert the sign so the lamp body follows the actor's motion direction.
	var dir : int = -1 if vx > 0.0 else 1
	swing(dir)
	_hit_cooldown = HIT_COOLDOWN_S

func swing(dir: int) -> void:
	_swing_active = true
	_swing_dir    = dir
	_swing_time   = 0.0

func _process(delta: float) -> void:
	_hit_cooldown = maxf(0.0, _hit_cooldown - delta)

	# Swing motion: damped oscillation around the top-center pivot.
	if _swing_active:
		_swing_time += delta
		if _swing_time >= SWING_DURATION_S:
			_swing_active = false
			rotation = 0.0
		else:
			var t   := _swing_time / SWING_DURATION_S
			var amp := SWING_AMPLITUDE_DEG * (1.0 - t)
			var phase := t * SWING_FREQUENCY * TAU
			rotation = deg_to_rad(amp * sin(phase) * float(_swing_dir))

	# Lighting animation
	match _state:
		State.WAITING:
			_delay_left -= delta
			if _delay_left <= 0.0:
				_state = State.PLAYING
				_frame_timer = 0.0
		State.PLAYING:
			_frame_timer += delta
			if _frame_timer < FRAME_TIME:
				return
			_frame_timer = 0.0
			if _frame_index >= _end_frame:
				_state = State.FROZEN
				return
			_frame_index += 1
			_set_frame(_frame_index)
		State.FROZEN:
			pass
