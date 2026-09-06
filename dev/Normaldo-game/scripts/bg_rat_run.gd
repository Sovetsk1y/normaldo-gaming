extends Sprite2D
class_name BgRatRun

# Running rat: spawns off-screen right, dashes across the floor to the left,
# despawns past the left edge. 9-frame loop, mirrored so it faces the
# direction of travel.

const SHEET       := preload("res://assets/background_items/rat_run_sheet.png")
const FRAME_W     : int = 48
const FRAME_H     : int = 48
const FRAME_COUNT : int = 9

const FRAME_TIME : float = 0.06   # quick paw-cycle while running
const RUN_SPEED  : float = 320.0  # absolute screen px/s leftward

var _frame_index : int   = 0
var _frame_timer : float = 0.0

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	texture        = SHEET
	region_enabled = true
	flip_h         = true
	# z = 0 puts the rat in the same draw bucket as the wall tiles, but it's
	# added LATER in the Background subtree so it renders above them. The
	# Spawner sits as a later sibling at the same z, so its items + Normaldo
	# + BOOM flash all draw on top of the rat — exactly what we want.
	z_index        = 0
	_frame_index   = randi() % FRAME_COUNT
	_set_frame(_frame_index)

func _set_frame(idx: int) -> void:
	_frame_index = idx
	region_rect = Rect2(idx * FRAME_W, 0, FRAME_W, FRAME_H)

func _process(delta: float) -> void:
	_frame_timer += delta
	if _frame_timer >= FRAME_TIME:
		_frame_timer = 0.0
		_frame_index = (_frame_index + 1) % FRAME_COUNT
		_set_frame(_frame_index)
	position.x -= RUN_SPEED * delta
