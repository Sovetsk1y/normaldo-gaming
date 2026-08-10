extends Node2D

const SCROLL_SPEED: float = 100.0   # halved — фон едет вдвое медленнее предметов
const IMG_W: float        = 344.0
const IMG_H: float        = 192.0
const BG_SCALE: float     = 430.0 / IMG_H
const BG_WIDTH: float     = IMG_W * BG_SCALE
# Overlap (in viewport px) between adjacent wall tiles. BG_SCALE is fractional
# (~2.24), so tile positions land on sub-pixels and the seam between two
# tiles can show a 1-px gap — through which the city parallax layer bleeds.
# A small forward overlap hides the seam without visibly cutting the art.
const BG_SEAM_OVERLAP: float = 2.0
const BG_STEP: float      = BG_WIDTH - BG_SEAM_OVERLAP

const TEX_LOOP  := preload("res://assets/backgrounds/bg_loop.png")
const TEX_LOOP4 := preload("res://assets/backgrounds/bg_loop4.png")
# "Hole" variants — bricks have transparent windows, stone floor underneath.
# When one of these is the active tile, the parallax city shows through and
# certain decor (pipes, running rats) is suppressed; cheese rats / lamp2 get
# tighter X ranges so they don't clip the stones / windows.
const TEX_LOOP3 := preload("res://assets/backgrounds/bg_loop3.png")
const TEX_LOOP5 := preload("res://assets/backgrounds/bg_loop5.png")

# Chance per tile recycle that the new tile is a hole-variant. 0.16 ≈ one
# hole tile every ~5 screens of scrolling (~6.25 recycles).
const HOLE_TILE_CHANCE : float = 0.16

# ── Parallax city layer ──────────────────────────────────────────────────────
# Panoramic city texture used as the slow distant layer behind wall holes.
# preload (compile-time) — keeps the bitmap warm in memory before _ready runs,
# avoiding a one-off load hitch the first frame a hole-variant wall slides in.
const CITY_TEX          := preload("res://assets/backgrounds/city_layer.png")
const CITY_SCROLL_SPEED : float  = 30.0   # ~30 % of wall speed → distant feel
const CITY_Y_OFFSET     : float  = -50.0  # vertical placement (negative = up)
# Extra scale factor on top of BG_SCALE. <1.0 shrinks the city for a more
# distant look. 0.80 = 20 % smaller.
const CITY_SCALE_FACTOR : float  = 1.0
# Initial X shift of both city tiles, expressed as a fraction of one tile's
# screen width. Negative = shift LEFT (more of the city's right side is
# in view at the start). Flip sign or zero out to shift right.
const CITY_X_OFFSET_FRAC : float = -0.30

# ── Ceiling lamp decor ───────────────────────────────────────────────────────
const BG_LAMP_SCRIPT          := preload("res://scripts/bg_lamp.gd")
const LAMP_FRAME_PX           : float = 48.0
const LAMP_SCALE              : float = 1.5
const LAMP_DISPLAY_W          : float = LAMP_FRAME_PX * LAMP_SCALE
const LAMP_MIN_SPACING        : float = LAMP_DISPLAY_W * 3.0   # >= 3 widths between adjacent lamps
const LAMP_SPAWN_INTERVAL_MIN : float = 3.5
const LAMP_SPAWN_INTERVAL_MAX : float = 7.5
const LAMP_TOP_OFFSET         : float = 0.0  # 0 = sprite top flush with screen top

# ── Wall pipe decor ──────────────────────────────────────────────────────────
const BG_PIPE_SCRIPT    := preload("res://scripts/bg_pipe.gd")
const PIPE_FRAME_PX     : float = 48.0
const PIPE_SCALE        : float = 1.5
const PIPE_DISPLAY_W    : float = PIPE_FRAME_PX * PIPE_SCALE
const PIPE_MOUSE_CHANCE : float = 0.20
# Other 80 % is split 50/50 between SHORT and FAT_LOOP.

# Probability that ANY pipe spawns when a tile cycles into view. Each tile
# is ~0.8 screens wide, so 0.30 ≈ one pipe every ~3 screens of scroll.
const PIPE_PER_TILE_CHANCE : float = 0.30

# Anchor points (X, Y) for the pipe OPENING centre, in SOURCE pixels of the
# respective bg art (img is IMG_W × IMG_H = 344 × 192). Each anchor is a spot
# on the wall where a pipe is allowed to come out — typically a dark mortar
# gap. Multiple anchors per variant let us choose a random one per spawn.
#
# To populate: open the png in Aseprite/Photoshop, hover over a candidate
# spot, read its X & Y. Add Vector2(x, y) to the variant's array.
const LOOP_PIPE_ANCHORS : Dictionary = {
	"loop":  [
		Vector2(27.0, 116.0),
		Vector2(161.0, 136.0),
		Vector2(330.0, 22.0),
		Vector2(268.0, 123.0),
	],
	"loop4": [
		Vector2(26.0, 115.0),
		Vector2(241.0, 50.0),
		Vector2(157.0, 134.0),
	],
	# Hole variants — no pipes by design.
	"loop3": [],
	"loop5": [],
}
# Optional fine-tune knob: extra screen-px shift applied to Y if the anchor
# in art doesn't quite line up with the sprite's left-centre. Usually 0.
const PIPE_OPENING_OFFSET_Y : float = 0.0

# ── Wall lantern decor (lamp2) ───────────────────────────────────────────────
const BG_LAMP2_SCRIPT       := preload("res://scripts/bg_lamp2.gd")
const LAMP2_FRAME_PX        : float = 48.0
const LAMP2_SCALE           : float = 1.5
const LAMP2_DISPLAY_W       : float = LAMP2_FRAME_PX * LAMP2_SCALE
# Up to LAMP2_ATTEMPTS_PER_TILE roll for spawn, each with LAMP2_SPAWN_CHANCE.
# 1 attempt × 35 % ≈ 0–1 lanterns per tile (~0.45 per screen).
const LAMP2_SPAWN_CHANCE      : float = 0.35
const LAMP2_ATTEMPTS_PER_TILE : int   = 1
# Y range in SOURCE pixels — keep lanterns above the floor strip (user spec).
const LAMP2_Y_MIN_SOURCE    : float = 20.0
const LAMP2_Y_MAX_SOURCE    : float = 125.0
# Don't spawn within this many pixels of either tile edge in source coords.
const LAMP2_X_MARGIN_SOURCE : float = 24.0
# Min screen distance to any other lamp1/lamp2/pipe — avoids clutter.
const LAMP2_MIN_DIST_TO_OTHER : float = LAMP2_DISPLAY_W * 1.6

# ── Floor rats (rat_cheese_sheet) ────────────────────────────────────────────
const BG_RAT_SCRIPT  := preload("res://scripts/bg_rat.gd")
const RAT_FRAME_PX   : float = 48.0
const RAT_SCALE      : float = 1.5
const RAT_DISPLAY_W  : float = RAT_FRAME_PX * RAT_SCALE
# 1 tile ≈ 0.8 screens. ~0.13 per tile = 1 rat per ~6 screens.
const RAT_PER_TILE_CHANCE : float = 0.13
# Random spawn box in SOURCE pixels (user-specified).
const RAT_X_MIN_SOURCE : float = 4.0
const RAT_X_MAX_SOURCE : float = 334.0
const RAT_Y_MIN_SOURCE : float = 162.0
const RAT_Y_MAX_SOURCE : float = 162.0

# ── Running rats (rat_run_sheet) ─────────────────────────────────────────────
const BG_RAT_RUN_SCRIPT       := preload("res://scripts/bg_rat_run.gd")
const RAT_RUN_FRAME_PX        : float = 48.0
const RAT_RUN_SCALE           : float = 1.5
const RAT_RUN_DISPLAY_W       : float = RAT_RUN_FRAME_PX * RAT_RUN_SCALE
# Time between successive run-by events. Tune for desired density.
const RAT_RUN_INTERVAL_MIN    : float = 10.0
const RAT_RUN_INTERVAL_MAX    : float = 22.0

# Static menu/intro tiles. _bg_intro is authored in the .tscn; _bg_intro2 is the
# right-side extension that sits next to it on the main-menu screen and scrolls
# off the same way once gameplay starts.
const TEX_INTRO2 := preload("res://assets/backgrounds/bg_intro2.png")
@onready var _bg_intro: Sprite2D = $BgIntro
var _bg_intro2: Sprite2D = null
@onready var _bg_a: Sprite2D     = $BgA
@onready var _bg_b: Sprite2D     = $BgB
@onready var _bg_c: Sprite2D     = $BgC

var _loop_tiles: Array[Sprite2D]
var _scrolling: bool = false

var _lamps           : Array[Sprite2D] = []
var _next_lamp_spawn : float           = 0.0

var _pipes        : Array[Sprite2D] = []
var _lamps2       : Array[Sprite2D] = []
var _rats         : Array[Sprite2D] = []
var _rats_run     : Array[Sprite2D] = []
var _next_rat_run : float           = 0.0

# Parallax city tiles (two for seamless loop).
var _city_a : Sprite2D = null
var _city_b : Sprite2D = null
var _city_w : float    = 0.0  # tile width on screen

func start_scrolling() -> void:
	_scrolling = true

func stop_scrolling() -> void:
	_scrolling = false

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("#1a1612"))

	# Build the bg_intro2 sibling once at startup so the menu wall extends past
	# the arch + couch tile (bg_intro) to the right.
	_bg_intro2 = Sprite2D.new()
	_bg_intro2.texture        = TEX_INTRO2
	_bg_intro2.centered       = _bg_intro.centered
	add_child(_bg_intro2)
	# Keep it directly above bg_intro in the tree so its draw order matches.
	move_child(_bg_intro2, _bg_intro.get_index() + 1)

	_loop_tiles = [_bg_a, _bg_b, _bg_c]
	for s: Sprite2D in [_bg_intro, _bg_intro2] + _loop_tiles:
		s.scale          = Vector2.ONE * BG_SCALE
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	for tile in _loop_tiles:
		tile.texture = _rand_loop_tex()

	# bg_intro stays at 0, bg_intro2 at BG_WIDTH; loop tiles begin one slot to
	# the right so they line up behind bg_intro2 instead of overlapping it.
	_bg_intro.position.x  = 0.0
	_bg_intro2.position.x = BG_STEP
	_bg_intro2.position.y = _bg_intro.position.y
	_bg_a.position.x      = BG_STEP * 2.0
	_bg_b.position.x      = BG_STEP * 3.0
	_bg_c.position.x      = BG_STEP * 4.0

	_next_lamp_spawn = randf_range(LAMP_SPAWN_INTERVAL_MIN, LAMP_SPAWN_INTERVAL_MAX)
	_next_rat_run    = randf_range(RAT_RUN_INTERVAL_MIN, RAT_RUN_INTERVAL_MAX)

	_setup_city_layer()

	# Initial tiles may already host pipes / lanterns / rats when the run begins.
	for tile in _loop_tiles:
		_maybe_spawn_pipe_for_tile(tile)
		_maybe_spawn_lamp2_for_tile(tile)
		_maybe_spawn_rat_for_tile(tile)

func _process(delta: float) -> void:
	# Running rats keep ticking on the menu/intro too — gives the empty room a
	# bit of life before the player starts scrolling.
	_update_rats_run(delta)
	if not _scrolling:
		return
	var shift := SCROLL_SPEED * delta

	_bg_intro.position.x -= shift
	if _bg_intro.visible and _bg_intro.position.x <= -BG_WIDTH:
		_bg_intro.visible = false
	if _bg_intro2 != null:
		_bg_intro2.position.x -= shift
		if _bg_intro2.visible and _bg_intro2.position.x <= -BG_WIDTH:
			_bg_intro2.visible = false

	for tile: Sprite2D in _loop_tiles:
		tile.position.x -= shift

	for tile: Sprite2D in _loop_tiles:
		if tile.position.x <= -BG_WIDTH:
			var rightmost := _loop_tiles[0].position.x
			for t: Sprite2D in _loop_tiles:
				if t.position.x > rightmost:
					rightmost = t.position.x
			# Step by BG_STEP (= BG_WIDTH - SEAM_OVERLAP) so the new tile
			# slightly overlaps its left neighbour and hides the seam.
			tile.position.x = rightmost + BG_STEP
			tile.texture    = _rand_loop_tex()
			_maybe_spawn_pipe_for_tile(tile)
			_maybe_spawn_lamp2_for_tile(tile)
			_maybe_spawn_rat_for_tile(tile)

	_update_city(delta)
	_update_lamps(delta, shift)
	_update_pipes(delta, shift)
	_update_lamps2(delta, shift)
	_update_rats(delta, shift)

# ── Lamps ────────────────────────────────────────────────────────────────────

func _update_lamps(delta: float, shift: float) -> void:
	# Scroll existing lamps left
	var stale : Array = []
	for lamp in _lamps:
		lamp.position.x -= shift
		if lamp.position.x < -LAMP_DISPLAY_W:
			stale.append(lamp)
	for lamp in stale:
		_lamps.erase(lamp)
		lamp.queue_free()

	# Timer-based spawn with min-spacing safeguard
	_next_lamp_spawn -= delta
	if _next_lamp_spawn <= 0.0:
		_try_spawn_lamp()
		_next_lamp_spawn = randf_range(LAMP_SPAWN_INTERVAL_MIN, LAMP_SPAWN_INTERVAL_MAX)

func _try_spawn_lamp() -> void:
	var vp_w := get_viewport_rect().size.x
	var spawn_x := vp_w + LAMP_DISPLAY_W * 0.5
	var rightmost := -INF
	for lamp in _lamps:
		if lamp.position.x > rightmost:
			rightmost = lamp.position.x
	# Enforce 3-widths spacing; bail if would crowd the previous lamp.
	if rightmost != -INF and spawn_x - rightmost < LAMP_MIN_SPACING:
		return
	var lamp := Sprite2D.new()
	lamp.set_script(BG_LAMP_SCRIPT)
	lamp.scale = Vector2.ONE * LAMP_SCALE
	# Pivot is at the top of the sprite (chain attach point), so place that
	# pivot directly at LAMP_TOP_OFFSET — sprite body hangs below.
	lamp.position = Vector2(spawn_x, LAMP_TOP_OFFSET)
	add_child(lamp)
	_lamps.append(lamp)

# ── Pipes ────────────────────────────────────────────────────────────────────

func _update_pipes(delta: float, shift: float) -> void:
	var stale : Array = []
	for pipe in _pipes:
		pipe.position.x -= shift
		# Mouse pipes are taller; generous despawn margin off the left edge.
		if pipe.position.x < -PIPE_DISPLAY_W * 2.0:
			stale.append(pipe)
	for pipe in stale:
		_pipes.erase(pipe)
		pipe.queue_free()

# Called whenever a tile (re)enters the cycle. Rolls a die to decide if a pipe
# spawns on one of that variant's pre-defined anchor points.
func _maybe_spawn_pipe_for_tile(tile: Sprite2D) -> void:
	if randf() >= PIPE_PER_TILE_CHANCE:
		return
	var variant_key : String = _variant_key_for(tile)
	var anchors : Array = LOOP_PIPE_ANCHORS.get(variant_key, [])
	if anchors.is_empty():
		return

	# Roll kind: 20 % mouse, 40 % short, 40 % fat-loop
	var r := randf()
	var kind : int
	if r < PIPE_MOUSE_CHANCE:
		kind = 2  # BgPipe.Kind.FAT_MOUSE
	elif r < PIPE_MOUSE_CHANCE + (1.0 - PIPE_MOUSE_CHANCE) * 0.5:
		kind = 0  # BgPipe.Kind.SHORT
	else:
		kind = 1  # BgPipe.Kind.FAT_LOOP

	# Pick a random anchor point in source coords. Pipe's own anchor is at the
	# LEFT-CENTRE of its sprite, so this lines up the wall opening directly.
	var anchor : Vector2 = anchors[randi() % anchors.size()]
	var screen_x : float = tile.position.x + anchor.x * BG_SCALE
	var screen_y : float = anchor.y * BG_SCALE + PIPE_OPENING_OFFSET_Y

	var pipe := Sprite2D.new()
	pipe.set_script(BG_PIPE_SCRIPT)
	pipe.scale = Vector2.ONE * PIPE_SCALE
	pipe.position = Vector2(screen_x, screen_y)
	# setup() MUST be called before add_child so _ready picks the right kind.
	pipe.call("setup", kind)
	add_child(pipe)
	_pipes.append(pipe)

# ── Wall lanterns (lamp2) ────────────────────────────────────────────────────

func _update_lamps2(delta: float, shift: float) -> void:
	var stale : Array = []
	for l2 in _lamps2:
		l2.position.x -= shift
		if l2.position.x < -LAMP2_DISPLAY_W * 1.5:
			stale.append(l2)
	for l2 in stale:
		_lamps2.erase(l2)
		l2.queue_free()

func _maybe_spawn_lamp2_for_tile(tile: Sprite2D) -> void:
	var variant := _variant_key_for(tile)
	# Per-variant X bounds. Hole bgs have a window in part of the wall — keep
	# lanterns on the brick side only.
	var x_min : float = LAMP2_X_MARGIN_SOURCE
	var x_max : float = IMG_W - LAMP2_X_MARGIN_SOURCE
	if variant == "loop3":
		x_max = 150.0
	elif variant == "loop5":
		x_min = 241.0
	for i in LAMP2_ATTEMPTS_PER_TILE:
		if randf() >= LAMP2_SPAWN_CHANCE:
			continue
		# Random (X, Y) inside the tile, constrained Y to the wall area.
		var source_x : float = randf_range(x_min, x_max)
		var source_y : float = randf_range(LAMP2_Y_MIN_SOURCE, LAMP2_Y_MAX_SOURCE)
		var pos := Vector2(
			tile.position.x + source_x * BG_SCALE,
			source_y * BG_SCALE,
		)
		if not _lamp2_pos_clear(pos):
			continue
		var l2 := Sprite2D.new()
		l2.set_script(BG_LAMP2_SCRIPT)
		l2.scale = Vector2.ONE * LAMP2_SCALE
		l2.position = pos
		add_child(l2)
		_lamps2.append(l2)

# Returns true if no existing lamp1, pipe, or lamp2 is within
# LAMP2_MIN_DIST_TO_OTHER of `pos`.
func _lamp2_pos_clear(pos: Vector2) -> bool:
	for lamp in _lamps:
		if pos.distance_to(lamp.position) < LAMP2_MIN_DIST_TO_OTHER:
			return false
	for pipe in _pipes:
		if pos.distance_to(pipe.position) < LAMP2_MIN_DIST_TO_OTHER:
			return false
	for l2 in _lamps2:
		if pos.distance_to(l2.position) < LAMP2_MIN_DIST_TO_OTHER:
			return false
	return true

# ── Floor rats ───────────────────────────────────────────────────────────────

func _update_rats(delta: float, shift: float) -> void:
	var stale : Array = []
	for rat in _rats:
		rat.position.x -= shift
		if rat.position.x < -RAT_DISPLAY_W * 1.5:
			stale.append(rat)
	for rat in stale:
		_rats.erase(rat)
		rat.queue_free()

func _maybe_spawn_rat_for_tile(tile: Sprite2D) -> void:
	if randf() >= RAT_PER_TILE_CHANCE:
		return
	var variant := _variant_key_for(tile)
	var source_x : float
	var source_y : float
	match variant:
		"loop3":
			source_y = 163.0
			source_x = randf_range(10.0, 96.0)
		"loop5":
			source_y = 163.0
			# Two valid X bands separated by the broken floor section.
			if randf() < 0.5:
				source_x = randf_range(14.0, 82.0)
			else:
				source_x = randf_range(222.0, 326.0)
		_:
			source_y = randf_range(RAT_Y_MIN_SOURCE, RAT_Y_MAX_SOURCE)
			source_x = randf_range(RAT_X_MIN_SOURCE, RAT_X_MAX_SOURCE)
	var rat := Sprite2D.new()
	rat.set_script(BG_RAT_SCRIPT)
	rat.scale = Vector2.ONE * RAT_SCALE
	rat.position = Vector2(
		tile.position.x + source_x * BG_SCALE,
		source_y * BG_SCALE,
	)
	add_child(rat)
	_rats.append(rat)

# ── Running rats ─────────────────────────────────────────────────────────────

func _update_rats_run(delta: float) -> void:
	# Despawn rats that have left the screen to the left.
	var stale : Array = []
	for r in _rats_run:
		if r.position.x < -RAT_RUN_DISPLAY_W * 1.5:
			stale.append(r)
	for r in stale:
		_rats_run.erase(r)
		r.queue_free()

	_next_rat_run -= delta
	if _next_rat_run <= 0.0:
		_spawn_rat_run()
		_next_rat_run = randf_range(RAT_RUN_INTERVAL_MIN, RAT_RUN_INTERVAL_MAX)

func _spawn_rat_run() -> void:
	var vp_w := get_viewport_rect().size.x
	var spawn_x : float = vp_w + RAT_RUN_DISPLAY_W * 0.5
	# Skip if the tile entering the screen here has a stone floor (hole bgs).
	for tile in _loop_tiles:
		if tile.position.x <= spawn_x and spawn_x < tile.position.x + BG_WIDTH:
			if _is_hole_variant(_variant_key_for(tile)):
				return
			break
	# Pick a per-spawn size: 100 %, 80 % or 60 % of the base RAT_RUN_SCALE.
	const SIZE_FACTORS : Array[float] = [1.0, 0.8, 0.6]
	var f : float = SIZE_FACTORS[randi() % SIZE_FACTORS.size()]
	var final_scale : float = RAT_RUN_SCALE * f
	var source_y : float = randf_range(RAT_Y_MIN_SOURCE, RAT_Y_MAX_SOURCE)
	# Default-anchored Sprite2D is centred, so the full-size mouse's bottom sits
	# at source_y*BG_SCALE + half_h_full. Hold that bottom Y constant across all
	# scales so the smaller mice still touch the floor instead of floating.
	var bottom_y : float = source_y * BG_SCALE + RAT_RUN_FRAME_PX * 0.5 * RAT_RUN_SCALE
	var center_y : float = bottom_y - RAT_RUN_FRAME_PX * 0.5 * final_scale
	var rat := Sprite2D.new()
	rat.set_script(BG_RAT_RUN_SCRIPT)
	rat.scale = Vector2.ONE * final_scale
	rat.position = Vector2(spawn_x, center_y)
	add_child(rat)
	_rats_run.append(rat)

# ── Parallax city layer ──────────────────────────────────────────────────────

func _setup_city_layer() -> void:
	_city_w = CITY_TEX.get_width() * BG_SCALE * CITY_SCALE_FACTOR
	var x0 : float = _city_w * CITY_X_OFFSET_FRAC
	_city_a = _make_city_tile(x0)
	_city_b = _make_city_tile(x0 + _city_w)
	# Insert as the first children so they render BEHIND all wall tiles & decor.
	move_child(_city_a, 0)
	move_child(_city_b, 1)

func _make_city_tile(x: float) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture        = CITY_TEX
	s.scale          = Vector2.ONE * BG_SCALE * CITY_SCALE_FACTOR
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.centered       = false
	s.z_index        = -1
	s.position       = Vector2(x, CITY_Y_OFFSET)
	add_child(s)
	return s

func _update_city(delta: float) -> void:
	if _city_a == null or _city_b == null:
		return
	var shift := CITY_SCROLL_SPEED * delta
	_city_a.position.x -= shift
	_city_b.position.x -= shift
	if _city_a.position.x <= -_city_w:
		_city_a.position.x = _city_b.position.x + _city_w
	if _city_b.position.x <= -_city_w:
		_city_b.position.x = _city_a.position.x + _city_w

func _rand_loop_tex() -> Texture2D:
	if randf() < HOLE_TILE_CHANCE:
		return TEX_LOOP3 if randf() < 0.5 else TEX_LOOP5
	return TEX_LOOP if randf() < 0.5 else TEX_LOOP4

func _variant_key_for(tile: Sprite2D) -> String:
	if tile.texture == TEX_LOOP:   return "loop"
	if tile.texture == TEX_LOOP4:  return "loop4"
	if tile.texture == TEX_LOOP3:  return "loop3"
	if tile.texture == TEX_LOOP5:  return "loop5"
	return "loop"

func _is_hole_variant(key: String) -> bool:
	return key == "loop3" or key == "loop5"
