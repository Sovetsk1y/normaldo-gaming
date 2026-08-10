extends ScrollContainer

# Auto-scroll behaviour for the skill list inside a shop card.
# Slowly pans the contents from top to bottom, pauses briefly, reverses, and
# loops forever. Any user touch / drag / wheel pauses the loop for IDLE_DELAY
# seconds, then it picks up from wherever the player left it.

const AUTO_SPEED  : float = 11.0   # px/sec — intentionally slow, ambient feel
const IDLE_DELAY  : float = 1.4    # secs after user input before auto resumes
const PAUSE_AT_END: float = 0.7    # secs to hold at the top / bottom edge

var _dir         : int   = 1     # +1 = scrolling down, -1 = back up
var _v_float     : float = 0.0
var _idle_timer  : float = 0.0
var _user_active : bool  = false
var _end_pause   : float = 0.0

func _ready() -> void:
	# Carry the inherited setup (deadzone, hidden bar) from the caller. PASS
	# keeps clicks reaching the row buttons until the scroll deadzone kicks in.
	if mouse_filter == Control.MOUSE_FILTER_IGNORE:
		mouse_filter = Control.MOUSE_FILTER_PASS

func _process(delta: float) -> void:
	if _user_active:
		_idle_timer -= delta
		if _idle_timer <= 0.0:
			_user_active = false
			_v_float = float(scroll_vertical)
		return
	var max_v : float = float(_max_scroll())
	if max_v <= 0.0:
		return
	if _end_pause > 0.0:
		_end_pause -= delta
		return
	_v_float += AUTO_SPEED * delta * float(_dir)
	if _v_float >= max_v:
		_v_float   = max_v
		_dir       = -1
		_end_pause = PAUSE_AT_END
	elif _v_float <= 0.0:
		_v_float   = 0.0
		_dir       = 1
		_end_pause = PAUSE_AT_END
	scroll_vertical = int(_v_float)

func _input(event: InputEvent) -> void:
	# Any pointer activity inside the scroll's screen rect counts as manual
	# control. We deliberately don't accept the event — the ScrollContainer
	# itself still handles dragging via its own _gui_input.
	var pos : Vector2
	if event is InputEventScreenTouch:
		if not (event as InputEventScreenTouch).pressed:
			return
		pos = (event as InputEventScreenTouch).position
	elif event is InputEventScreenDrag:
		pos = (event as InputEventScreenDrag).position
	elif event is InputEventMouseButton:
		if not (event as InputEventMouseButton).pressed:
			return
		pos = (event as InputEventMouseButton).position
	else:
		return
	if get_global_rect().has_point(pos):
		_user_active = true
		_idle_timer  = IDLE_DELAY

func _max_scroll() -> int:
	var bar := get_v_scroll_bar()
	if bar == null:
		return 0
	return int(bar.max_value - bar.page)
