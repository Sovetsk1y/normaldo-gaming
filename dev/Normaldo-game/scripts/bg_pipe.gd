extends Sprite2D
class_name BgPipe

# Wall pipe decor. Three flavours, chosen at spawn time:
#   - SHORT     : pipe1_short_sheet, 9 frames @ 48×48. Ping-pong loop.
#   - FAT_LOOP  : pipe1_sheet,       9 frames @ 48×48. Ping-pong loop.
#   - FAT_MOUSE : pipe1_mouse_sheet, 19 frames @ 48×96. Plays ONCE after a
#                 random delay (mouse climbs out & back in), then freezes.
# FAT_LOOP and FAT_MOUSE share frame 0 (empty pipe) so they're visually
# interchangeable at idle. SHORT is a distinct, shorter pipe.

enum Kind { SHORT, FAT_LOOP, FAT_MOUSE }

const FRAME_W            : int = 48
const FRAME_H_NORMAL     : int = 48
const FRAME_H_MOUSE      : int = 96
const FRAME_COUNT_NORMAL : int = 9
const FRAME_COUNT_MOUSE  : int = 19

const FRAME_TIME : float = 0.18

const SHEET_NORMAL := preload("res://assets/background_items/pipe1/pipe1_sheet.png")
const SHEET_SHORT  := preload("res://assets/background_items/pipe1/pipe1_short_sheet.png")
const SHEET_MOUSE  := preload("res://assets/background_items/pipe1/pipe1_mouse_sheet.png")

# Delay range before the mouse animation triggers.
const MOUSE_DELAY_MIN : float = 1.0
const MOUSE_DELAY_MAX : float = 6.0

var _kind        : int   = Kind.SHORT
var _frame_index : int   = 0
var _frame_dir   : int   = 1   # +1 forward, -1 reverse
var _frame_timer : float = 0.0
var _frame_count : int   = FRAME_COUNT_NORMAL
var _frame_h     : int   = FRAME_H_NORMAL

# Mouse-only state
var _mouse_waiting : bool  = true
var _mouse_delay   : float = 0.0
var _mouse_done    : bool  = false

func setup(kind: int) -> void:
	_kind = kind

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	region_enabled = true
	match _kind:
		Kind.SHORT:
			texture       = SHEET_SHORT
			_frame_count  = FRAME_COUNT_NORMAL
			_frame_h      = FRAME_H_NORMAL
		Kind.FAT_LOOP:
			texture       = SHEET_NORMAL
			_frame_count  = FRAME_COUNT_NORMAL
			_frame_h      = FRAME_H_NORMAL
		Kind.FAT_MOUSE:
			texture       = SHEET_MOUSE
			_frame_count  = FRAME_COUNT_MOUSE
			_frame_h      = FRAME_H_MOUSE
			_mouse_delay  = randf_range(MOUSE_DELAY_MIN, MOUSE_DELAY_MAX)
	# Anchor at the LEFT edge of the texture (X) and aligned so that the TOP
	# edge of the visible sprite sits at the SAME screen Y across all variants.
	# For 48-tall sheets (SHORT, FAT_LOOP) this naturally maps to left-vcenter.
	# For the 96-tall mouse sheet we add half the height difference (=24 in
	# un-scaled local) so its top edge aligns with the 48-tall pipes' top edge,
	# making FAT_LOOP and FAT_MOUSE visually interchangeable at one anchor.
	var y_offset : float = 0.0
	if _kind == Kind.FAT_MOUSE:
		y_offset = (FRAME_H_MOUSE - FRAME_H_NORMAL) * 0.5
	offset = Vector2(FRAME_W * 0.5, y_offset)

	# Loop variants start at a random frame so neighbouring pipes don't
	# breathe in lockstep.
	if _kind != Kind.FAT_MOUSE:
		_frame_index = randi() % _frame_count
		_frame_dir   = 1 if randf() < 0.5 else -1
	_set_frame(_frame_index)

func _set_frame(idx: int) -> void:
	_frame_index = idx
	region_rect = Rect2(idx * FRAME_W, 0, FRAME_W, _frame_h)

func _process(delta: float) -> void:
	match _kind:
		Kind.SHORT, Kind.FAT_LOOP:
			_step_pingpong(delta)
		Kind.FAT_MOUSE:
			_step_mouse(delta)

func _step_pingpong(delta: float) -> void:
	_frame_timer += delta
	if _frame_timer < FRAME_TIME:
		return
	_frame_timer = 0.0
	var nxt := _frame_index + _frame_dir
	if nxt >= _frame_count:
		# Bounce back from the right end without holding on the last frame
		_frame_dir = -1
		nxt = _frame_count - 2
	elif nxt < 0:
		_frame_dir = 1
		nxt = 1
	_set_frame(nxt)

func _step_mouse(delta: float) -> void:
	if _mouse_done:
		return
	if _mouse_waiting:
		_mouse_delay -= delta
		if _mouse_delay <= 0.0:
			_mouse_waiting = false
			_frame_timer = 0.0
			_set_frame(0)
		return
	_frame_timer += delta
	if _frame_timer < FRAME_TIME:
		return
	_frame_timer = 0.0
	if _frame_index >= _frame_count - 1:
		_mouse_done = true
		# Freeze on the last frame (empty pipe look)
		return
	_set_frame(_frame_index + 1)
