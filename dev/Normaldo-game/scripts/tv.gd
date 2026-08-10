extends Sprite2D

# Living-room TV across from the couch on the menu/intro scene.
# Two sheets: tv_play_sheet (idle on-air loop) and tv_crash_sheet
# (broken/static — kept for later use). Currently only PLAY loops.
#
# Also drives the "channel-surfing" loop used while we're on the main menu:
# plays a random tv*.mp3 clip, and 3 seconds before it ends asks Normaldo to
# play his remote-control animation. The audio swaps to the next random clip
# at the exact moment Normaldo emits menu_remote_button_pressed, so the click
# and the channel change line up perfectly.

const SHEET_PLAY  := preload("res://assets/background_items/tv/tv_play_sheet.png")
const SHEET_CRASH := preload("res://assets/background_items/tv/tv_crash_sheet.png")
const CRASH_SFX   := preload("res://assets/audio/tv/crash.mp3")

const FRAME_W     : int = 48
const FRAME_H     : int = 48
const FRAME_COUNT : int = 17
const FRAME_TIME  : float = 0.13
# Ping-pong cadence for the crash loop — a touch slower than the play loop so
# the glitchy frames register before flipping direction.
const CRASH_FRAME_TIME : float = 0.10

# ── Position on the menu screen (offset from viewport centre) ────────────────
# Couch sits at MENU_OFFSET = Vector2(-260, 110) in couch.gd. The TV is placed
# mirrored on the right side so the room looks "couch ↔ TV". Tweak these to
# move the TV around.
const MENU_OFFSET := Vector2(0.0, 110.0)
const SCALE_FACTOR : float = 2.0
# Same scroll speed as the background — TV is a piece of the scene.
# (Синхронизировано с background.gd SCROLL_SPEED = 100 — иначе ТВ отрывается от пола.)
const SCROLL_SPEED : float = 100.0

# How many seconds before the current track ends to cue Normaldo to start his
# remote animation. The animation takes ~ this long so the press jerk lands
# right around the same time the track would've naturally faded out.
const REMOTE_LEAD_TIME : float = 3.0

var _frame_index     : int     = 0
var _frame_timer     : float   = 0.0
var _frame_step      : int     = 1   # +1 / -1 for the crash ping-pong loop
var _crashed         : bool    = false
var _locked_position : Vector2 = Vector2.ZERO
var _bg              : Node    = null

# Channel-surfing playback
var _tv_audio       : AudioStreamPlayer = null
var _crash_audio    : AudioStreamPlayer = null
var _tv_tracks      : Array       = []
var _current_track  : int         = -1
var _remote_cued    : bool        = false   # true once we've asked Normaldo to start the anim for this clip
var _normaldo       : Node        = null

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	region_enabled = true
	texture        = SHEET_PLAY
	scale          = Vector2.ONE * SCALE_FACTOR
	# Sits above the Background (z 0) so the thrown remote can slot UNDER the
	# TV (z 1) while still drawing above the floor — z = -1 would hide it
	# behind the bg entirely.
	z_index        = 2
	# top_level=true makes the node ignore any parent transforms — it lives in
	# absolute world space, so nothing in the scene can push it around.
	top_level      = true
	_set_frame(randi() % FRAME_COUNT)
	_locked_position = get_viewport_rect().get_center() + MENU_OFFSET
	global_position  = _locked_position
	_bg = get_parent().get_node_or_null("Background")

	_load_tv_tracks()
	_tv_audio = AudioStreamPlayer.new()
	_tv_audio.bus = "Master"
	_tv_audio.volume_db = -6.0   # background TV chatter, not the main attraction
	add_child(_tv_audio)

	# Pre-warm the crash SFX player — adding the player + assigning the stream
	# at impact time costs a frame or two before play() actually fires, which
	# the player perceives as audio lag behind the visual smash. Keeping it
	# resident lets trigger_crash() just call .play() with zero latency.
	_crash_audio = AudioStreamPlayer.new()
	_crash_audio.bus       = "Master"
	# 15 % quieter than unity → linear 0.85 → −1.4 dB.
	_crash_audio.volume_db = -1.4
	_crash_audio.stream    = CRASH_SFX
	add_child(_crash_audio)

	# Connect to Normaldo's remote-press signal so the channel swaps in lock-
	# step with the on-screen button click. Connection happens after one frame
	# so both nodes are guaranteed to be ready (TV and Normaldo are siblings).
	call_deferred("_hook_remote_signal")

	# Always boot with tv1.mp3 — the rest cycle randomly after the first
	# channel change.
	if not _tv_tracks.is_empty():
		_current_track = 0
		_tv_audio.stream = _tv_tracks[0]
		_tv_audio.play()
		_remote_cued = false

func _set_frame(idx: int) -> void:
	_frame_index = idx
	region_rect = Rect2(idx * FRAME_W, 0, FRAME_W, FRAME_H)

func _process(delta: float) -> void:
	# Once the background starts scrolling, advance the TV with it — it's a
	# piece of the room, not a HUD element. Until then it stays put.
	if _bg != null and _bg.get("_scrolling") == true:
		_locked_position.x -= SCROLL_SPEED * delta
	global_position = _locked_position
	if _locked_position.x < -FRAME_W * SCALE_FACTOR * 1.5:
		queue_free()
		return
	# Frame loop — straight forward during play, ping-pong (0 → last → 0) once
	# the TV has been smashed by Normaldo's remote.
	_frame_timer += delta
	var step_time : float = CRASH_FRAME_TIME if _crashed else FRAME_TIME
	if _frame_timer >= step_time:
		_frame_timer = 0.0
		if _crashed:
			_frame_index += _frame_step
			if _frame_index >= FRAME_COUNT - 1:
				_frame_index = FRAME_COUNT - 1
				_frame_step  = -1
			elif _frame_index <= 0:
				_frame_index = 0
				_frame_step  = 1
		else:
			_frame_index = (_frame_index + 1) % FRAME_COUNT
		_set_frame(_frame_index)

	# After the crash the TV is silent — no more channel surfing or remote cues.
	if _crashed:
		return

	# Cue Normaldo's remote animation 3 seconds before the current clip ends.
	if _tv_audio != null and _tv_audio.playing and not _remote_cued and _tv_audio.stream != null:
		var total : float = _tv_audio.stream.get_length()
		if total > 0.0:
			var remaining : float = total - _tv_audio.get_playback_position()
			if remaining <= REMOTE_LEAD_TIME:
				_remote_cued = true
				if _normaldo and _normaldo.has_method("play_tv_remote_anim"):
					_normaldo.play_tv_remote_anim()
	# Safety: if a track ended naturally without anyone pressing the button
	# (e.g. Normaldo wasn't in menu-idle), roll straight to the next clip so
	# the TV never falls silent.
	if _tv_audio != null and not _tv_audio.playing and not _tv_tracks.is_empty():
		_play_next_track()

# ── Channel surfing ──────────────────────────────────────────────────────────

func _load_tv_tracks() -> void:
	_tv_tracks.clear()
	for i in range(1, 8):
		var p : String = "res://assets/audio/tv/tv%d.mp3" % i
		if ResourceLoader.exists(p):
			_tv_tracks.append(load(p))

func _hook_remote_signal() -> void:
	_normaldo = get_parent().get_node_or_null("Normaldo")
	if _normaldo and _normaldo.has_signal("menu_remote_button_pressed"):
		# Late-bind: connecting via call_deferred → already in tree.
		if not _normaldo.menu_remote_button_pressed.is_connected(_on_remote_pressed):
			_normaldo.menu_remote_button_pressed.connect(_on_remote_pressed)

func _play_next_track() -> void:
	if _tv_tracks.is_empty():
		return
	var idx : int = randi() % _tv_tracks.size()
	# Avoid playing the same clip twice in a row when we have a choice.
	if idx == _current_track and _tv_tracks.size() > 1:
		idx = (idx + 1) % _tv_tracks.size()
	_current_track = idx
	_tv_audio.stream = _tv_tracks[idx]
	_tv_audio.play()
	_remote_cued = false

# Called the instant Normaldo's remote-button jerk hits its lowest point.
func _on_remote_pressed() -> void:
	_play_next_track()

# Called by hud.gd when the player launches a run. Kept as a no-op stub —
# the actual TV smash is driven by trigger_crash(), called the instant
# Normaldo's thrown remote reaches the screen.
func start_game() -> void:
	pass

# Slams the TV: kills the channel-surfing audio, swaps the sprite sheet to
# the smashed/static frames, plays the crash SFX, and kicks off the
# ping-pong frame loop (0 → last → 0 → last → …).
func trigger_crash() -> void:
	if _crashed:
		return
	_crashed = true
	# Fire the SFX FIRST while the on-screen visual swap is still pending —
	# audio dispatch and the next render frame line up that way. Doing the
	# sprite-sheet swap first introduces a perceptible visual-leads-audio gap.
	if _crash_audio:
		_crash_audio.play()
	if _tv_audio:
		_tv_audio.stop()
	texture     = SHEET_CRASH
	_frame_index = 0
	_frame_step  = 1
	_frame_timer = 0.0
	_set_frame(0)

# True once trigger_crash() has fired — used by the intro orchestrator.
func is_crashed() -> bool:
	return _crashed
