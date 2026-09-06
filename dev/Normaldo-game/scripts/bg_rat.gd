extends Sprite2D
class_name BgRat

# Floor decor: rat carrying cheese. 17-frame sheet, looped at a per-instance
# random frame-time and optionally mirrored horizontally so individual rats
# don't move in lockstep.

const SHEET       := preload("res://assets/background_items/rat_cheese_sheet.png")
const FRAME_W     : int = 48
const FRAME_H     : int = 48
const FRAME_COUNT : int = 17

# Random per-rat animation speed
const FRAME_TIME_MIN : float = 0.10
const FRAME_TIME_MAX : float = 0.20

var _frame_index : int   = 0
var _frame_timer : float = 0.0
var _frame_time  : float = 0.15

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	texture        = SHEET
	region_enabled = true
	flip_h         = randf() < 0.5
	# z_index = 0 (default) keeps the rat above background tiles (added
	# earlier in tree) but BELOW Spawner-owned game items (Spawner is a later
	# sibling of Background in game.tscn).
	_frame_time    = randf_range(FRAME_TIME_MIN, FRAME_TIME_MAX)
	_frame_index   = randi() % FRAME_COUNT
	_set_frame(_frame_index)

func _set_frame(idx: int) -> void:
	_frame_index = idx
	region_rect = Rect2(idx * FRAME_W, 0, FRAME_W, FRAME_H)

func _process(delta: float) -> void:
	_frame_timer += delta
	if _frame_timer < _frame_time:
		return
	_frame_timer = 0.0
	_frame_index = (_frame_index + 1) % FRAME_COUNT
	_set_frame(_frame_index)
