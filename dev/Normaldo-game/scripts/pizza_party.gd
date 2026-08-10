extends Node2D

# ── ПИЦЦА-ПАТИ mini-game controller ───────────────────────────────────────────
# Second trash mini-game. Child of the Game root. Rarely a GIANT glowing pizza
# pack (~3× the in-run pack) flies in from the right and parks in the right part
# of the screen. The instant it appears the run freezes (no other items until the
# end). The pack's corner of the screen becomes UNREACHABLE for Normaldo.
#
#   • Tapping the right part (where the pack sits) makes the pack blink + twist and
#     SPIT an item out along a random left-fan vector (up-left … down-left), with a
#     coloured particle trail behind it: pizza 80 %, бомж/собака/бочка 18 %,
#     змея 2 %.
#   • The more you tap, the stronger the yellow light + particle fountain from
#     under the pack (mutagen-style heat that decays when you stop).
#   • Normaldo moves as usual in the LEFT part and takes damage normally — so you
#     juggle tapping for pizzas while dodging the bad spits.
#   • Lasts the same 8–15 s as the ЖИРОБОСС game, then the pack flies back out and
#     the run resumes.
#
# SFX hooks are marked `# SFX:` — drop streams on later.

const PACK_CLOSED := preload("res://assets/items/pizza_pack_closed.png")
const PACK_OPEN   := preload("res://assets/items/pizza_pack_open.png")

const ITEM_SCENE     := preload("res://scenes/item.tscn")
const HOMELESS_SCENE := preload("res://scenes/homeless.tscn")
const DOG_SCENE      := preload("res://scenes/dog.tscn")
const SNAKE_SCENE    := preload("res://scenes/snake.tscn")

const PIZZA_TEX  := preload("res://assets/items/pizza.png")
const TRASH_TEX  := preload("res://assets/items/trash_bin.png")
const FIRECRACKER := preload("res://assets/audio/firecracker.mp3")
const HARD_TRACK  := preload("res://assets/audio/hard_track.mp3")
const UI_FONT     := preload("res://assets/fonts/RussoOne-Regular.ttf")

# ── Tunables (designer-facing) ────────────────────────────────────────────────
@export var enabled        : bool  = true
# Пицца-пати — средняя мини-игра, вводится второй (с ~2-й минуты). Гейт по
# сложности см. /Концепция/Эпизод 1 — прогрессия предметов (редизайн).md
@export var first_delay    : float = 105.0   # run grace before the pack can appear
@export var repeat_interval: float = 60.0    # cooldown after a mini-game
@export var pizza_chance   : float = 0.004   # per-frame chance to send the pack

const PACK_SCALE   : float = 0.24            # ~3× the in-run pizza pack (0.08)
const FLY_SPEED    : float = 900.0           # pack glide-in speed
const RIGHT_MARGIN : float = 8.0             # gap between pack and right screen edge
# The unreachable right zone is a fixed fraction of the screen (robust, doesn't
# depend on the pack texture size). Normaldo is clamped to its left; taps past it
# spit. The pack parks hugging the right edge, well inside this zone.
const RIGHT_ZONE_FRAC : float = 0.58

# The pizza hides a random STOCK of items (20–50). Each tap spits one and drops
# the bar; when it empties the mini-game ends. No timer → you can't wait it out,
# you HAVE to tap. The number itself is never shown — only the draining bar.
# Мини-игра длится ПО ВРЕМЕНИ (10–20 c рандомно), а не по числу тапов.
const PLAY_DUR_MIN : float = 5.0
const PLAY_DUR_MAX : float = 15.0
const STOCK_MIN : int = 20   # (legacy — больше не завершает игру)
const STOCK_MAX : int = 50

# Spit: a random vector fanning out to the LEFT in a TIGHT cone around straight-left.
const SPIT_FAN   : float = 0.38              # ≈ ±22° around straight-left (narrow wedge)
const SPIT_SPEED : float = 2.9               # × the run's item speed (fast)
const GUARANTEED_PIZZAS : int = 4            # first N spits are always pizza, then by chance

# Tap heat → light/fountain intensity (mutagen-style).
const HEAT_PER_TAP : float = 0.34
const HEAT_DECAY   : float = 1.3             # per second

# Spit kind colours for the particle trail.
const COL_PIZZA : Color = Color(1.00, 0.72, 0.20)
const COL_BAD   : Color = Color(0.80, 0.55, 0.35)
const COL_SNAKE : Color = Color(0.45, 1.00, 0.45)

enum State { IDLE, FLY_IN, PLAY, OUTRO }
var _state     : int   = State.IDLE
var _arm_timer : float = 0.0
var _base_item_speed : float = 330.0
var _park_x    : float = 0.0
var _boundary_x: float = 0.0
var _heat      : float = 0.0
var _spit_count: int   = 0     # how many items spat this mini-game (for the pizza grace)
var _stock     : int   = 0     # (legacy)
var _stock_max : int   = 1
var _play_time : float = 15.0  # общая длительность этого забега мини-игры (10–20 c)
var _play_t    : float = 0.0   # оставшееся время
var _bar_disp  : float = 1.0   # smoothed bar fill (rolls down toward time-left)
var _pulse_t   : float = 0.0
var _open_t    : float = 0.0   # >0 while the pack shows its OPEN frame after a spit
var _event_frozen : bool = false

var _pack     : Node2D = null
var _pack_spr : Sprite2D = null
var _glow     : Sprite2D = null
var _fountain : CPUParticles2D = null
var _bar_fill : ColorRect = null           # the draining stock bar's fill
var _bar_w    : float = 0.0
var _spit_sfx : AudioStreamPlayer = null   # SFX: pack spit (none yet)

var _ui       : CanvasLayer = null         # holds the blinking ТАПАЙ prompt
var _tap_lbl  : Label = null
var _tap_tw   : Tween = null
var _move_lbl : Label = null               # mirrored "ДВИГАЙ" prompt (left side)
var _move_tw  : Tween = null
var _move_ref : Vector2 = Vector2.ZERO     # Normaldo pos when the prompt appeared
var _orig_music_stream : AudioStream = null

# Live projectiles driven by us: [ {"node": Node2D, "vel": Vector2}, … ]
var _proj : Array = []

@onready var _normaldo   = get_parent().get_node_or_null("Normaldo")
@onready var _spawner    = get_parent().get_node_or_null("Spawner")
@onready var _background  = get_parent().get_node_or_null("Background")
@onready var _fatboss     = get_parent().get_node_or_null("FatBoss")
@onready var _music        = get_parent().get_node_or_null("Music")
@onready var _slotsgame     = get_parent().get_node_or_null("SlotsGame")

func _ready() -> void:
	_arm_timer = first_delay
	_spit_sfx = AudioStreamPlayer.new()
	_spit_sfx.volume_db = -3.0
	add_child(_spit_sfx)
	if is_instance_valid(_normaldo) and _normaldo.has_signal("died"):
		_normaldo.died.connect(_on_normaldo_died)

# If Normaldo dies mid-game (he's vulnerable here), drop our visuals immediately
# so nothing lingers over the game-over screen before the scene reloads.
func _on_normaldo_died(_total_pizzas: int, _death_pos: Vector2) -> void:
	if _state == State.IDLE or _state == State.OUTRO:
		return
	if _normaldo.has_method("clear_left_region"):
		_normaldo.clear_left_region()
	_clear_ui()
	_restore_music()
	for e in _proj:
		if is_instance_valid(e["node"]):
			e["node"].queue_free()
	_proj.clear()
	if is_instance_valid(_pack):
		_pack.queue_free()
	_pack = null
	_pack_spr = null
	_glow = null
	_fountain = null
	_bar_fill = null
	_event_frozen = false
	_state = State.IDLE

# ── Trigger loop ──────────────────────────────────────────────────────────────

func _run_active() -> bool:
	return enabled \
		and is_instance_valid(_normaldo) and _normaldo.has_method("is_input_enabled") \
		and _normaldo.is_input_enabled() \
		and is_instance_valid(_spawner) and not _spawner._frozen \
		and not (is_instance_valid(_fatboss) and _fatboss.has_method("is_busy") and _fatboss.is_busy()) \
		and not (is_instance_valid(_slotsgame) and _slotsgame.has_method("is_busy") and _slotsgame.is_busy())

func _process(delta: float) -> void:
	_drive_projectiles(delta)   # spits fly in every state, not just PLAY
	# Dismiss the "ДВИГАЙ" prompt the moment Normaldo actually moves.
	if is_instance_valid(_move_lbl) and is_instance_valid(_normaldo):
		if _normaldo.global_position.distance_to(_move_ref) > 6.0:
			_dismiss_move_prompt()
	match _state:
		State.IDLE:
			if _run_active():
				if _arm_timer > 0.0:
					_arm_timer -= delta
				elif randf() < pizza_chance:
					_start()
		State.FLY_IN:
			_tick_fly_in(delta)
		State.PLAY:
			_tick_play(delta)

func _start() -> void:
	if not is_instance_valid(_spawner) or not is_instance_valid(_background):
		return
	if _spawner.has_method("current_phase_speed"):
		_base_item_speed = _spawner.current_phase_speed()

	# Freeze the run the instant the pack appears — no other items till the end.
	_event_frozen = true
	if _spawner.has_method("pause_for_event"):
		_spawner.pause_for_event()
	if _spawner.has_method("collapse_items"):
		_spawner.collapse_items()
	if is_instance_valid(_background):
		_background.stop_scrolling()

	var vp := get_viewport_rect().size
	var pack_w := PACK_CLOSED.get_width() * PACK_SCALE
	_park_x     = vp.x - pack_w * 0.5 - RIGHT_MARGIN
	_boundary_x = vp.x * RIGHT_ZONE_FRAC
	# Lock the head out of the right zone IMMEDIATELY (don't wait for the pack to
	# park) — control + damage stay on, he just can't enter the pizza's corner.
	if _normaldo.has_method("set_left_region"):
		_normaldo.set_left_region(_boundary_x)
	_crossfade_music()
	_build_pack(Vector2(vp.x + pack_w, vp.y * 0.5))
	_build_tap_prompt()
	_heat    = 0.0
	_spit_count = 0
	_stock_max = randi_range(STOCK_MIN, STOCK_MAX)
	_stock     = _stock_max
	_play_time = randf_range(PLAY_DUR_MIN, PLAY_DUR_MAX)
	_play_t    = _play_time
	_bar_disp  = 1.0
	_pulse_t = 0.0
	_open_t  = 0.0
	_state = State.FLY_IN

# Dev hook: fire the pizza pack right now (no-op if anything is already running).
func dev_send_pizza_pack() -> void:
	if _state != State.IDLE:
		return
	if is_instance_valid(_fatboss) and _fatboss.has_method("is_busy") and _fatboss.is_busy():
		return
	if not is_instance_valid(_normaldo) or not is_instance_valid(_spawner):
		return
	_start()

# ── Phase: pack glides in, then parks ─────────────────────────────────────────

func _tick_fly_in(delta: float) -> void:
	if not is_instance_valid(_pack):
		_finish()
		return
	_update_pack_fx(delta)
	_pack.position.x = maxf(_park_x, _pack.position.x - FLY_SPEED * delta)
	# NB: position.x is stored float32, so it lands a hair ABOVE the float64 _park_x
	# (e.g. 828.40002 > 828.4) and a strict `<= _park_x` NEVER fires — the minigame
	# would stay stuck in FLY_IN and never start its timer. Compare with an epsilon.
	if _pack.position.x <= _park_x + 0.5:
		_pack.position.x = _park_x
		_play_t = _play_time   # отсчёт длительности стартует с началом PLAY
		_state = State.PLAY

# ── Phase: tap to spit, dodge in the left part ────────────────────────────────
# Ends only when the pizza's stock is tapped empty (see _on_pack_tap) — no timer.

func _tick_play(delta: float) -> void:
	_update_pack_fx(delta)
	# Игра идёт ПО ВРЕМЕНИ: заканчивается, когда истекло 10–20 c.
	_play_t -= delta
	if _play_t <= 0.0:
		_end_minigame()

func _input(event: InputEvent) -> void:
	if _state != State.PLAY and _state != State.FLY_IN:
		return
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		if (event as InputEventScreenTouch).position.x >= _boundary_x:
			_on_pack_tap()

func _on_pack_tap() -> void:
	if not is_instance_valid(_pack):
		return
	_heat = minf(1.0, _heat + HEAT_PER_TAP)
	# The pack SPRITE blinks bigger with a small twist (glow/fountain stay put) +
	# flashes its OPEN frame as it "gives".
	if is_instance_valid(_pack_spr):
		_pack_spr.scale    = Vector2.ONE * PACK_SCALE * 1.16
		_pack_spr.rotation = randf_range(0.06, 0.13) * (1.0 if randf() < 0.5 else -1.0)
		var tw := _pack_spr.create_tween().set_parallel(true)
		tw.tween_property(_pack_spr, "scale", Vector2.ONE * PACK_SCALE, 0.18) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(_pack_spr, "rotation", 0.0, 0.18) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_pack_spr.texture = PACK_OPEN
	_open_t = 0.12
	if _spit_sfx.stream:
		_spit_sfx.play()
	_spit_item()
	# Тапы больше НЕ завершают игру — она идёт по времени (см. _tick_play).

func _spit_item() -> void:
	# First few spits are guaranteed pizza (roll forced to 0); then by probability.
	var roll : float = randf() if _spit_count >= GUARANTEED_PIZZAS else 0.0
	_spit_count += 1
	var node : Node
	var col  : Color
	if roll < 0.80:
		node = _make_item(PIZZA_TEX, 0.09, true, 0, "")
		col  = COL_PIZZA
	elif roll < 0.98:
		var pick := randi() % 3
		if pick == 0:
			node = _make_item(TRASH_TEX, 0.22, false, 1, "")   # бочка
			node.rotates = false
			node.knock_sound = FIRECRACKER
			(node.get_node("Sprite2D") as Sprite2D).rotation = PI / 2.0
		elif pick == 1:
			node = HOMELESS_SCENE.instantiate()                 # бомж
		else:
			node = DOG_SCENE.instantiate()                      # собака
		col = COL_BAD
	else:
		node = SNAKE_SCENE.instantiate()                        # змея
		col = COL_SNAKE

	# We drive movement ourselves, so the scene's own straight-left scroll is off.
	if node.get("speed") != null:
		node.speed = 0.0
	var ang := randf_range(-SPIT_FAN, SPIT_FAN)
	var dir := Vector2(-cos(ang), sin(ang))           # left-fan: up-left … down-left
	var vel := dir * (_base_item_speed * SPIT_SPEED)
	# Emerge from the pack's left-centre ("mouth").
	node.position = _pack.position + Vector2(-PACK_CLOSED.get_width() * PACK_SCALE * 0.40, 0.0)
	_attach_trail(node, col, -dir)
	add_child(node)
	_proj.append({ "node": node, "vel": vel })

func _make_item(tex: Texture2D, scl: float, eatable: bool, dmg: int, group: String) -> Node:
	var it := ITEM_SCENE.instantiate()
	it.is_eatable = eatable
	it.damage     = dmg
	it.rotates    = true
	it.pulses     = eatable
	if group != "":
		it.item_group = group
	var spr := it.get_node("Sprite2D") as Sprite2D
	spr.texture = tex
	spr.scale   = Vector2.ONE * scl
	return it

# A short coloured wake behind a spit item (same idea as the boxing-glove exhaust).
func _attach_trail(node: Node2D, col: Color, back_dir: Vector2) -> void:
	var p := CPUParticles2D.new()
	p.local_coords          = false   # particles linger in world → real trail
	p.emitting              = true
	p.amount                = 22
	p.lifetime              = 0.40
	p.direction             = back_dir
	p.spread                = 16.0
	p.gravity               = Vector2.ZERO
	p.initial_velocity_min  = 20.0
	p.initial_velocity_max  = 55.0
	p.scale_amount_min      = 1.6
	p.scale_amount_max      = 3.4
	p.color                 = col
	node.add_child(p)

func _drive_projectiles(delta: float) -> void:
	var vp := get_viewport_rect().size
	var alive : Array = []
	for e in _proj:
		var n = e["node"]
		if is_instance_valid(n):
			n.position += e["vel"] * delta
			# Free spits that have flown off-screen (so nothing leaks after the
			# pack is gone), but let the on-screen ones finish their arc.
			if n.position.x < -220.0 or n.position.x > vp.x + 220.0 \
					or n.position.y < -220.0 or n.position.y > vp.y + 220.0:
				n.queue_free()
			else:
				alive.append(e)
	_proj = alive

func _clear_projectiles() -> void:
	for e in _proj:
		var n = e["node"]
		if is_instance_valid(n):
			if is_instance_valid(_spawner) and _spawner.has_method("collapse_node") and n is Node2D:
				_spawner.collapse_node(n)
			else:
				n.queue_free()
	_proj.clear()

# ── End ───────────────────────────────────────────────────────────────────────

func _end_minigame() -> void:
	if _state == State.OUTRO:
		return
	_state = State.OUTRO
	_run_outro()

func _run_outro() -> void:
	if _normaldo.has_method("clear_left_region"):
		_normaldo.clear_left_region()
	_clear_ui()
	_restore_music()
	# NB: we do NOT clear _proj here — the items that already flew out of the pack
	# keep flying to completion (they self-remove once off-screen in
	# _drive_projectiles). Only the empty pack folds up and dies.

	# Pack folds shut (closed lid) and shrinks away, THEN the run continues.
	await _fold_pack()

	if is_instance_valid(_spawner) and _spawner.has_method("resume_after_event"):
		_spawner.resume_after_event()
	if is_instance_valid(_background):
		_background.start_scrolling()
	_event_frozen = false
	_arm_timer = repeat_interval
	_state = State.IDLE

# Close the lid + fold the pack up (shrink + slight roll + fade), then free it.
func _fold_pack() -> void:
	if not is_instance_valid(_pack):
		return
	var pack := _pack
	_pack = null
	if is_instance_valid(_fountain):
		_fountain.emitting = false
	if is_instance_valid(_pack_spr):
		_pack_spr.texture = PACK_CLOSED   # lid shut = "свернулась"
	_pack_spr = null
	_glow = null
	_fountain = null
	_bar_fill = null
	var tw := pack.create_tween()
	tw.set_parallel(true)
	tw.tween_property(pack, "scale", Vector2.ZERO, 0.35) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_property(pack, "rotation", 0.6, 0.35)
	tw.tween_property(pack, "modulate:a", 0.0, 0.35)
	tw.chain().tween_callback(pack.queue_free)
	await tw.finished

# Bail-out if the pack vanished unexpectedly mid fly-in.
func _finish() -> void:
	_state = State.OUTRO
	_run_outro()

# ── Pack build + per-frame FX ─────────────────────────────────────────────────

func _build_pack(pos: Vector2) -> void:
	# IMPORTANT: `_pack` itself is unscaled — only the SPRITE carries PACK_SCALE.
	# Otherwise the 0.24 scale would shrink the glow/fountain into nothing.
	_pack = Node2D.new()
	_pack.position = pos
	_pack.z_index  = 2
	add_child(_pack)

	var pack_w := PACK_CLOSED.get_width()  * PACK_SCALE   # on-screen px
	var pack_h := PACK_CLOSED.get_height() * PACK_SCALE

	# Soft yellow glow from under/behind the pack (full-size, in screen px).
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.85, 0.30, 0.85))
	grad.set_color(1, Color(1.0, 0.85, 0.30, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient  = grad
	gt.fill      = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to   = Vector2(0.5, 0.0)
	gt.width     = 256
	gt.height    = 256
	var add_mat := CanvasItemMaterial.new()
	add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow = Sprite2D.new()
	_glow.texture  = gt
	_glow.material = add_mat
	_glow.z_index  = -1
	_glow.scale    = Vector2.ONE * (pack_w / 200.0)   # ~1.2 → glow a bit wider than pack
	_glow.position = Vector2(0.0, -pack_h * 0.06)      # raised to the pizza's visual centre
	_pack.add_child(_glow)

	# Yellow particle fountain leaking from under the pack (full-size).
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
	_fountain = CPUParticles2D.new()
	_fountain.z_index           = 0
	_fountain.texture           = dot_tex
	_fountain.amount            = 80
	_fountain.lifetime          = 0.8
	_fountain.emitting          = true
	_fountain.spread            = 150.0
	_fountain.direction         = Vector2(0.0, 1.0)   # downward, from under the pack
	_fountain.gravity           = Vector2(0.0, 80.0)
	_fountain.scale_amount_min  = 2.0
	_fountain.scale_amount_max  = 4.0
	_fountain.color             = Color(1.0, 0.80, 0.25)
	_fountain.position          = Vector2(0.0, -pack_h * 0.02)   # raised to pizza centre
	_pack.add_child(_fountain)

	_pack_spr = Sprite2D.new()
	_pack_spr.texture        = PACK_CLOSED
	_pack_spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_pack_spr.z_index        = 1
	_pack_spr.scale          = Vector2.ONE * PACK_SCALE
	_pack.add_child(_pack_spr)

	# Stock bar under the pizza — fills with the hidden item count, drains per tap.
	_bar_w = pack_w * 0.82
	var bar_h  := 14.0
	var bar_y  := pack_h * 0.5 + 16.0
	var bar_bg := ColorRect.new()
	bar_bg.color    = Color(0.0, 0.0, 0.0, 0.65)
	bar_bg.size     = Vector2(_bar_w + 6.0, bar_h + 6.0)
	bar_bg.position = Vector2(-_bar_w * 0.5 - 3.0, bar_y - 3.0)
	bar_bg.z_index  = 2
	_pack.add_child(bar_bg)
	var bar_track := ColorRect.new()
	bar_track.color    = Color(0.16, 0.11, 0.05, 0.95)
	bar_track.size     = Vector2(_bar_w, bar_h)
	bar_track.position = Vector2(-_bar_w * 0.5, bar_y)
	bar_track.z_index  = 2
	_pack.add_child(bar_track)
	_bar_fill = ColorRect.new()
	_bar_fill.color    = Color(1.0, 0.78, 0.20)
	_bar_fill.size     = Vector2(_bar_w, bar_h)
	_bar_fill.position = Vector2(-_bar_w * 0.5, bar_y)
	_bar_fill.z_index  = 3
	_pack.add_child(_bar_fill)

# Drive the glow + fountain off `_heat` (rises on tap, decays), pulse the glow,
# and drop the OPEN frame back to CLOSED shortly after a spit.
func _update_pack_fx(delta: float) -> void:
	_heat = maxf(0.0, _heat - HEAT_DECAY * delta)
	_pulse_t += delta * 6.0
	if _open_t > 0.0:
		_open_t -= delta
		if _open_t <= 0.0 and _pack_spr:
			_pack_spr.texture = PACK_CLOSED

	var p := 0.5 + 0.5 * sin(_pulse_t)
	if is_instance_valid(_glow):
		var base := PACK_CLOSED.get_width() * PACK_SCALE / 200.0
		_glow.scale = Vector2.ONE * base * lerpf(1.0, 1.9, _heat) * lerpf(0.95, 1.08, p)
		_glow.modulate.a = lerpf(0.55, 1.0, _heat)
	if is_instance_valid(_fountain):
		_fountain.initial_velocity_min = lerpf(20.0, 150.0, _heat)
		_fountain.initial_velocity_max = lerpf(50.0, 320.0, _heat)
		_fountain.scale_amount_min     = lerpf(0.30, 0.95, _heat)
		_fountain.scale_amount_max     = lerpf(0.60, 1.90, _heat)
	# Timer bar runs empty over the run's 10–20 s: fill = time-left fraction, lightly
	# smoothed so it reads as a steady drain; colour heats gold → red toward the end.
	if is_instance_valid(_bar_fill):
		var frac := clampf(_play_t / maxf(0.01, _play_time), 0.0, 1.0)
		_bar_disp = lerpf(_bar_disp, frac, clampf(delta * 3.0, 0.0, 1.0))
		if absf(_bar_disp - frac) < 0.01:
			_bar_disp = frac          # snap so it reaches a clean full / empty
		_bar_fill.size.x = _bar_w * _bar_disp
		_bar_fill.color  = Color(1.0, 0.25, 0.12).lerp(Color(1.0, 0.78, 0.20), _bar_disp)
	# Keep the blinking ТАПАЙ centred above the pack (no camera → world == screen).
	if is_instance_valid(_tap_lbl) and is_instance_valid(_pack):
		var half_h := PACK_CLOSED.get_height() * PACK_SCALE * 0.5
		_tap_lbl.position = _pack.position - Vector2(110.0, half_h + 76.0)

# ── Blinking ТАПАЙ prompt over the pack ───────────────────────────────────────

func _build_tap_prompt() -> void:
	_clear_ui()
	_ui = CanvasLayer.new()
	_ui.layer = 50
	add_child(_ui)
	_tap_lbl = Label.new()
	_tap_lbl.add_theme_font_override("font", UI_FONT)
	_tap_lbl.add_theme_font_size_override("font_size", 44)
	_tap_lbl.add_theme_color_override("font_color", Color(1.0, 0.12, 0.06))
	_tap_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_tap_lbl.add_theme_constant_override("outline_size", 6)
	_tap_lbl.text                 = "ТАПАЙ"
	_tap_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tap_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_tap_lbl.size                 = Vector2(220.0, 60.0)
	_tap_lbl.pivot_offset         = Vector2(110.0, 30.0)
	_ui.add_child(_tap_lbl)
	_tap_tw = _tap_lbl.create_tween().set_loops()
	_tap_tw.tween_property(_tap_lbl, "scale", Vector2(1.18, 1.18), 0.30) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tap_tw.parallel().tween_property(_tap_lbl, "modulate:a", 0.5, 0.30)
	_tap_tw.tween_property(_tap_lbl, "scale", Vector2.ONE, 0.30)
	_tap_tw.parallel().tween_property(_tap_lbl, "modulate:a", 1.0, 0.30)

	# "ДВИГАЙ" prompt on the LEFT (reads normally). Removed on first move.
	var vp := get_viewport_rect().size
	var lsize := Vector2(240.0, 60.0)
	_move_lbl = Label.new()
	_move_lbl.add_theme_font_override("font", UI_FONT)
	_move_lbl.add_theme_font_size_override("font_size", 44)
	_move_lbl.add_theme_color_override("font_color", Color(1.0, 0.12, 0.06))
	_move_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_move_lbl.add_theme_constant_override("outline_size", 6)
	_move_lbl.text                 = "ДВИГАЙ"
	_move_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_move_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_move_lbl.size                 = lsize
	_move_lbl.pivot_offset         = lsize * 0.5                       # scale about centre
	_move_lbl.position             = Vector2(vp.x * 0.24, vp.y * 0.42) - lsize * 0.5
	_ui.add_child(_move_lbl)
	_move_tw = _move_lbl.create_tween().set_loops()
	_move_tw.tween_property(_move_lbl, "scale", Vector2(1.18, 1.18), 0.30) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_move_tw.parallel().tween_property(_move_lbl, "modulate:a", 0.5, 0.30)
	_move_tw.tween_property(_move_lbl, "scale", Vector2.ONE, 0.30)
	_move_tw.parallel().tween_property(_move_lbl, "modulate:a", 1.0, 0.30)
	if is_instance_valid(_normaldo):
		_move_ref = _normaldo.global_position

# Fade out + free just the "ДВИГАЙ" prompt (first movement) — ТАПАЙ stays.
func _dismiss_move_prompt() -> void:
	if _move_tw and _move_tw.is_valid():
		_move_tw.kill()
	_move_tw = null
	if not is_instance_valid(_move_lbl):
		return
	var lbl := _move_lbl
	_move_lbl = null
	var tw := lbl.create_tween()
	tw.tween_property(lbl, "modulate:a", 0.0, 0.22)
	tw.tween_callback(func():
		if is_instance_valid(lbl):
			lbl.queue_free())

func _clear_ui() -> void:
	if _tap_tw and _tap_tw.is_valid():
		_tap_tw.kill()
	_tap_tw = null
	if _move_tw and _move_tw.is_valid():
		_move_tw.kill()
	_move_tw = null
	if is_instance_valid(_ui):
		_ui.queue_free()
	_ui = null
	_tap_lbl = null
	_move_lbl = null

# ── Music: hard_track for the mini-game, run track back at the end ─────────────

func _crossfade_music() -> void:
	if is_instance_valid(_music) and _music.has_method("swap_to"):
		_orig_music_stream = _music.stream
		_music.swap_to(HARD_TRACK, 0.5)

func _restore_music() -> void:
	if is_instance_valid(_music) and _music.has_method("swap_to") and _orig_music_stream:
		_music.swap_to(_orig_music_stream, 0.3)
		_orig_music_stream = null
