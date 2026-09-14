extends Node2D

# ── СЛОТЫ mini-game controller ────────────────────────────────────────────────
# Child of the Game root. Rarely a glowing/blinking SLOT MACHINE (two lanes tall)
# flies in like the mutagen. Catch it and:
#   • a reels-spin sound plays; every item on screen tumbles away (collapse);
#   • Normaldo does a somersault jump to the bottom and switches to COLUMN control
#     — swipe left/right to hop between 7 invisible columns (no free movement);
#   • items rain DOWN those columns (pizza, rarer dollars, бочки/бомжи/собаки/змеи);
#   • the background dims, two boomboxes appear left & right, and slots_music2 fades
#     in quietly under a looping reels track;
#   • at 15 s into the track the items fall TWICE as fast and the boomboxes rave;
#   • after 15–25 s (from the first item) the machine releases and the run resumes.
#
# SFX/music use the project's slots assets. `# SFX:` marks hookable spots.

const SLOTS_BG    := preload("res://assets/slots/slots_music2.mp3")   # background track
const FIREWORKS_SFX := preload("res://assets/audio/fireworks.mp3")    # outro fireworks
const UI_FONT     := preload("res://assets/fonts/RussoOne-Regular.ttf")
const FINGER_TEX  := preload("res://assets/ui/quests/back_arrow.png") # points LEFT by default
const BOOM1_TEX   := preload("res://assets/items/boombox1.png")
const BOOM2_TEX   := preload("res://assets/items/boombox2.png")
const NOTA1_TEX   := preload("res://assets/items/nota.png")
const NOTA2_TEX   := preload("res://assets/items/nota2.png")

const ITEM_SCENE     := preload("res://scenes/item.tscn")
const HOMELESS_SCENE := preload("res://scenes/homeless.tscn")
const DOG_SCENE      := preload("res://scenes/dog.tscn")
const SNAKE_SCENE    := preload("res://scenes/snake.tscn")
const PIZZA_TEX  := preload("res://assets/items/pizza.png")
const DOLLAR_TEX := preload("res://assets/items/dollar.png")
const TRASH_TEX  := preload("res://assets/items/trash_bin.png")
const FIRECRACKER := preload("res://assets/audio/firecracker.mp3")

# ── Tunables ──────────────────────────────────────────────────────────────────
@export var enabled        : bool  = true
# Слоты — самая сложная мини-игра: появляется только с ~4-й минуты эпизода и
# не чаще 1 раза за кампанию (`_episode_done`). См.
# /Концепция/Эпизод 1 — прогрессия предметов (редизайн).md
@export var first_delay    : float = 235.0
@export var repeat_interval: float = 60.0
@export var slots_chance   : float = 0.004    # per-frame chance to send the machine
var _episode_done : bool = false              # campaign: играется 1× за эпизод

const GOLD_SCALE    : float = 0.17            # the flying golden pizza's size
# The pickup's light/particles are a 1:1 copy of the mutagen's, recoloured GOLD.
const GOLD_COL  : Color = Color(1.0, 0.80, 0.25)
const PROX_FAR  : float = 420.0
const PROX_NEAR : float = 45.0
const BOOMBOX_SCALE : float = 0.30            # side DJ boomboxes (bigger)
# Symmetric note directions, same idea as the in-game boombox.
const NOTE_PAIRS : Array = [
	[Vector2( 1.0, -1.3), Vector2(-1.0, -1.3)],
	[Vector2( 1.4, -0.4), Vector2(-1.4, -0.4)],
	[Vector2( 0.4, -1.5), Vector2(-0.4, -1.5)],
]
const COLUMNS       : int   = 7
const COL_STEP      : float = 82.0            # px between columns — wide enough that an
                                              # item one column over can't clip Normaldo
                                              # (his ~32px hitbox + item ~30px ≈ 62px)
const BOTTOM_FRAC   : float = 0.82            # Normaldo's row, as a fraction of height

# Items rain as a GRID: every column gets a cell each row, rows kept ROW_GAP apart.
const ROW_GAP        : float = 130.0          # vertical spacing between rows
const FALL_SPEED     : float = 149.6          # px/s start (slow, +5%); ×2 after FAST_AT
const FAST_AT        : float = 16.0           # track-time when everything speeds up
const DUR_MIN        : float = 30.0           # mini-game length (from the first item)
const DUR_MAX        : float = 35.0           # ≈ FAST_AT + ~20 s of fast play
const DROP_STOP_LEAD : float = 3.0            # stop dropping this long before the end
const SWIPE_MIN      : float = 38.0           # px of horizontal drag to count as a swipe
# During the fast phase the falling items "dance" to the beat (size + rotation).
const BEAT_FREQ      : float = 11.0
const BEAT_ROT       : float = 0.13
const BEAT_SCALE     : float = 0.10
# Explosion onset times (s) in fireworks.mp3 — each shell bursts on its boom.
const FW_BURSTS      : Array = [1.50, 2.03, 2.37, 2.62, 2.84]

enum State { IDLE, FLY_IN, INTRO, PLAY, OUTRO }
var _state     : int   = State.IDLE
var _arm_timer : float = 0.0
var _base_item_speed : float = 330.0

var _col       : int   = 3
var _columns_live : bool = false   # swipe + column glue active (intro hint + play)
var _beat_t    : float = 0.0       # beat phase for the fast-phase item dance
var _bottom_y  : float = 0.0
var _row_accum : float = 0.0   # fall distance since the last spawned row
var _play_t    : float = 0.0
var _track_t   : float = 0.0
var _fast      : bool  = false
var _event_frozen : bool = false

# Swipe tracking
var _swiping     : bool  = false
var _swipe_dx    : float = 0.0
var _swipe_fired : bool  = false

var _machine   : Area2D = null
var _mach_spr  : Sprite2D = null          # the golden pizza sprite
var _mach_glow : Sprite2D = null
var _mach_rays : Node2D = null
var _mach_fount: CPUParticles2D = null
var _mach_blink: float = 0.0
var _mach_spin : float = 0.0

var _ui        : CanvasLayer = null
var _falling   : Array = []                  # live falling items
var _boomboxes : Array = []                  # [{spr, frame_t, frame, note_t, rock_t}]

var _bg_player    : AudioStreamPlayer = null
var _sq_cache     : Texture2D = null           # white square for the firework rocket

@onready var _normaldo    = get_parent().get_node_or_null("Normaldo")
@onready var _spawner     = get_parent().get_node_or_null("Spawner")
@onready var _background   = get_parent().get_node_or_null("Background")
@onready var _music        = get_parent().get_node_or_null("Music")
@onready var _fatboss      = get_parent().get_node_or_null("FatBoss")
@onready var _pizzaparty    = get_parent().get_node_or_null("PizzaParty")

func _ready() -> void:
	_arm_timer = first_delay
	if is_instance_valid(_normaldo) and _normaldo.has_signal("slot_machine_caught"):
		_normaldo.slot_machine_caught.connect(_on_caught)
	if is_instance_valid(_normaldo) and _normaldo.has_signal("died"):
		_normaldo.died.connect(_on_normaldo_died)

	_bg_player = AudioStreamPlayer.new()
	_bg_player.stream = _looped(SLOTS_BG)
	_bg_player.volume_db = -40.0
	add_child(_bg_player)

func _looped(src: AudioStream) -> AudioStream:
	var s := src.duplicate()
	if s is AudioStreamMP3:
		(s as AudioStreamMP3).loop = true
	return s

func is_busy() -> bool:
	return _state != State.IDLE or is_instance_valid(_machine)

func _run_active() -> bool:
	return enabled \
		and is_instance_valid(_normaldo) and _normaldo.has_method("is_input_enabled") \
		and _normaldo.is_input_enabled() \
		and is_instance_valid(_spawner) and not _spawner._frozen \
		and not (is_instance_valid(_fatboss) and _fatboss.has_method("is_busy") and _fatboss.is_busy()) \
		and not (is_instance_valid(_pizzaparty) and _pizzaparty.has_method("is_busy") and _pizzaparty.is_busy())

func _col_x(i: int) -> float:
	# Columns are a tight cluster centred on screen (step COL_STEP), not spread
	# across the whole width — leaves the sides free for the boomboxes.
	return get_viewport_rect().size.x * 0.5 + (float(i) - float(COLUMNS - 1) * 0.5) * COL_STEP

# ── Process ───────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if _state == State.INTRO or _state == State.PLAY:
		_track_t += delta
		if not _fast and _track_t >= FAST_AT:
			_fast = true   # _update_boomboxes / _fall_speed read this live
			_bg_player.volume_db = -6.0   # the track gets louder / "active"
		_update_boomboxes(delta)
		_drive_falling(delta)
		# Column glue runs as soon as columns go live — already during the hint,
		# so the player can practise swiping before the rain starts.
		if _columns_live and is_instance_valid(_normaldo):
			_normaldo.position.x = lerpf(_normaldo.position.x, _col_x(_col), clampf(delta * 16.0, 0.0, 1.0))
			_normaldo.position.y = _bottom_y
	match _state:
		State.IDLE:
			if _run_active() and not _episode_done:
				if _arm_timer > 0.0:
					_arm_timer -= delta
				elif not is_instance_valid(_machine):
					if randf() < slots_chance:
						_send_machine()
						# Campaign: the golden pizza appears only once per episode.
						if is_instance_valid(_spawner) and _spawner.get("campaign_mode"):
							_episode_done = true
		State.FLY_IN:
			_tick_fly_in(delta)
		State.PLAY:
			_tick_play(delta)

# ── Flying, catchable slot machine ────────────────────────────────────────────

func _send_machine() -> void:
	if not is_instance_valid(_spawner):
		return
	if _spawner.has_method("current_phase_speed"):
		_base_item_speed = _spawner.current_phase_speed()
	var vp := get_viewport_rect().size

	_machine = Area2D.new()
	_machine.collision_layer = 2
	_machine.collision_mask  = 0
	_machine.add_to_group("slot_machine")
	_machine.z_index = 2
	var lane_y := vp.y / 5.0 * (float(randi() % 5) + 0.5)
	_machine.position = Vector2(vp.x + 120.0, lane_y)
	var psize := PIZZA_TEX.get_width() * GOLD_SCALE   # on-screen pizza size
	var shape := CircleShape2D.new()
	shape.radius = psize * 0.5
	var cs := CollisionShape2D.new()
	cs.shape = shape
	_machine.add_child(cs)

	# ── Light + particles: a 1:1 copy of mutagen._build_light, in GOLD ──────────
	var add_mat := CanvasItemMaterial.new()
	add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

	# Rotating rays — thin additive spikes radiating in all directions.
	_mach_rays = Node2D.new()
	_mach_rays.z_index = 0
	_machine.add_child(_mach_rays)
	for i in 12:
		var spike := Polygon2D.new()
		spike.color    = Color(GOLD_COL.r, GOLD_COL.g, GOLD_COL.b, 0.22)
		spike.polygon  = PackedVector2Array([Vector2(0.0, -4.0), Vector2(0.0, 4.0), Vector2(78.0, 0.0)])
		spike.rotation = TAU * float(i) / 12.0
		spike.material = add_mat
		_mach_rays.add_child(spike)

	# Soft radial glow behind the sprite.
	var grad := Gradient.new()
	grad.set_color(0, Color(GOLD_COL.r, GOLD_COL.g, GOLD_COL.b, 0.8))
	grad.set_color(1, Color(GOLD_COL.r, GOLD_COL.g, GOLD_COL.b, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient  = grad
	gt.fill      = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to   = Vector2(0.5, 0.0)
	gt.width     = 128
	gt.height    = 128
	_mach_glow = Sprite2D.new()
	_mach_glow.texture  = gt
	_mach_glow.material = add_mat
	_mach_glow.z_index  = 0
	_machine.add_child(_mach_glow)

	# Soft round dot so the particles are actually visible.
	var dot_grad := Gradient.new()
	dot_grad.set_color(0, Color(1, 1, 1, 1))
	dot_grad.set_color(1, Color(1, 1, 1, 0))
	var dot_tex := GradientTexture2D.new()
	dot_tex.gradient  = dot_grad
	dot_tex.fill      = GradientTexture2D.FILL_RADIAL
	dot_tex.fill_from = Vector2(0.5, 0.5)
	dot_tex.fill_to   = Vector2(0.5, 0.0)
	dot_tex.width     = 24
	dot_tex.height    = 24

	# Gold radioactive particles streaming out in every direction (spread 180°).
	_mach_fount = CPUParticles2D.new()
	_mach_fount.z_index   = 0
	_mach_fount.texture   = dot_tex
	_mach_fount.amount    = 60
	_mach_fount.lifetime  = 0.8
	_mach_fount.emitting  = true
	_mach_fount.spread    = 180.0
	_mach_fount.direction = Vector2(0.0, -1.0)
	_mach_fount.gravity   = Vector2.ZERO
	_mach_fount.color     = GOLD_COL
	_machine.add_child(_mach_fount)

	# The flying GOLDEN PIZZA — face in front of its own light/fx.
	_mach_spr = Sprite2D.new()
	_mach_spr.texture  = PIZZA_TEX
	_mach_spr.scale    = Vector2.ONE * GOLD_SCALE
	_mach_spr.modulate = Color(1.35, 1.05, 0.45)
	_mach_spr.z_index  = 1
	_machine.add_child(_mach_spr)

	add_child(_machine)
	_mach_blink = 0.0
	_mach_spin = 0.0
	_state = State.FLY_IN

func _tick_fly_in(delta: float) -> void:
	if not is_instance_valid(_machine):
		_state = State.IDLE
		return
	_machine.position.x -= _base_item_speed * delta

	# Blink — identical to the mutagen, recoloured gold.
	_mach_blink += delta * 6.0
	_mach_spin  += delta * 3.0
	var p := 0.5 + 0.5 * sin(_mach_blink)
	if is_instance_valid(_mach_spr):
		_mach_spr.scale = Vector2.ONE * GOLD_SCALE * lerpf(0.92, 1.15, p)
	_machine.modulate = Color(1, 1, 1).lerp(Color(GOLD_COL.r * 1.7, GOLD_COL.g * 1.7, GOLD_COL.b * 1.7), p)
	if is_instance_valid(_mach_rays):
		_mach_rays.rotation += delta * 0.8
		_mach_rays.scale = Vector2.ONE * lerpf(0.9, 1.15, p)
	if is_instance_valid(_mach_glow):
		_mach_glow.scale = Vector2.ONE * lerpf(1.4, 1.9, p)

	# Proximity reaction — the closer Normaldo flies, the bigger the fountain +
	# the harder the shake (identical to the mutagen).
	var prox := 0.0
	if is_instance_valid(_normaldo):
		var dist := _machine.global_position.distance_to(_normaldo.global_position)
		prox = clampf(inverse_lerp(PROX_FAR, PROX_NEAR, dist), 0.0, 1.0)
	if is_instance_valid(_mach_fount):
		_mach_fount.initial_velocity_min = lerpf(22.0, 140.0, prox)
		_mach_fount.initial_velocity_max = lerpf(55.0, 300.0, prox)
		_mach_fount.scale_amount_min     = lerpf(0.30, 0.90, prox)
		_mach_fount.scale_amount_max     = lerpf(0.60, 1.80, prox)
	var shake := lerpf(0.0, 7.0, prox)
	if is_instance_valid(_mach_spr):
		_mach_spr.position = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake
		_mach_spr.rotation = sin(_mach_spin) * 0.22 + randf_range(-1.0, 1.0) * 0.16 * prox

	if _machine.position.x < -200.0:
		_machine.queue_free()
		_machine = null
		_mach_spr = null
		_mach_glow = null
		_mach_rays = null
		_mach_fount = null
		_state = State.IDLE

# Dev hook.
func dev_send_machine() -> void:
	if _state != State.IDLE or is_instance_valid(_machine):
		return
	if is_instance_valid(_fatboss) and _fatboss.has_method("is_busy") and _fatboss.is_busy():
		return
	if is_instance_valid(_pizzaparty) and _pizzaparty.has_method("is_busy") and _pizzaparty.is_busy():
		return
	if not is_instance_valid(_normaldo) or not is_instance_valid(_spawner):
		return
	_send_machine()

# ── Catch → set the stage ─────────────────────────────────────────────────────

func _on_caught() -> void:
	if _state != State.FLY_IN:
		return
	_machine = null
	_mach_spr = null
	_mach_glow = null
	_mach_rays = null
	_mach_fount = null

	# The background track fades in quietly from this moment.
	_bg_player.volume_db = -40.0
	_bg_player.play()
	var bgtw := _bg_player.create_tween()
	bgtw.tween_property(_bg_player, "volume_db", -16.0, 2.0)
	if is_instance_valid(_music) and _music.has_method("fade_out"):
		_music.fade_out()

	# Freeze the run, clear what's flying.
	_event_frozen = true
	if is_instance_valid(_spawner):
		if _spawner.has_method("pause_for_event"): _spawner.pause_for_event()
		if _spawner.has_method("collapse_items"):  _spawner.collapse_items()
		# Пицца-пати и ЖИРОБОСС держат свои снаряды у себя, и collapse_items()
		# их не видит: спиты пачки продолжали лететь поверх развернувшихся на
		# весь экран автоматов. Это и был баг «летят предметы поверх автоматов».
		if _spawner.has_method("collapse_minigame_debris"):
			_spawner.call("collapse_minigame_debris", self)
	if is_instance_valid(_background) and _background.has_method("stop_scrolling"):
		_background.stop_scrolling()

	_track_t = 0.0
	_fast = false
	_col = 3
	if _normaldo.has_method("begin_slots_mode"):
		_normaldo.begin_slots_mode()
	_dim_background(true)
	_build_boomboxes()
	_state = State.INTRO
	_run_intro()

func _run_intro() -> void:
	var vp := get_viewport_rect().size
	_bottom_y = vp.y * BOTTOM_FRAC

	# Golden-pizza reward: jump straight to the last fat (spin morph), then a random
	# comic reaction (lol / kek / oops).
	if _normaldo.has_method("fatten_to_max"):
		_normaldo.fatten_to_max()
	await get_tree().create_timer(0.5).timeout
	if _normaldo.has_method("show_reaction"):
		_normaldo.show_reaction(["lol", "kek", "oops"][randi() % 3])
	await get_tree().create_timer(0.7).timeout

	# Somersault jump to the centre column at the bottom.
	if _normaldo.has_method("slots_intro_jump"):
		var jt = _normaldo.slots_intro_jump(Vector2(_col_x(_col), _bottom_y))
		if jt:
			await jt.finished
	else:
		await get_tree().create_timer(0.6).timeout

	# Columns go live NOW (during the hint) so the player can practise swiping —
	# the "СВАЙПАЙ" text is telling them to swipe already.
	_columns_live = true
	_show_tutorial()
	await get_tree().create_timer(2.6).timeout   # let the hint read before the rain

	_row_accum = ROW_GAP   # spawn the first row immediately
	_play_t = randf_range(DUR_MIN, DUR_MAX)   # duration counts from the first row
	_state = State.PLAY

# ── Play: swipe columns, dodge/catch the rain ─────────────────────────────────

func _tick_play(delta: float) -> void:
	_play_t -= delta
	# (column glue is driven in _process while _columns_live)
	# Seamless grid: emit a full row every ROW_GAP of fall distance. The drop STOPS
	# DROP_STOP_LEAD seconds before the end so the last rows can clear the screen.
	if _play_t > DROP_STOP_LEAD:
		_row_accum += _fall_speed() * delta
		while _row_accum >= ROW_GAP:
			_row_accum -= ROW_GAP
			_spawn_row()
	# Once the drop has stopped, end as soon as the LAST row has passed Normaldo —
	# that's the moment the fireworks should launch (no dead wait to play_t = 0).
	if _play_t <= DROP_STOP_LEAD and not _items_above_normaldo():
		_end_minigame()

# True while any falling item is still at/above Normaldo's row (not yet passed).
func _items_above_normaldo() -> bool:
	for n in _falling:
		if is_instance_valid(n) and n.position.y < _bottom_y + 40.0:
			return true
	return false

func _input(event: InputEvent) -> void:
	if not _columns_live:   # active from the hint through play
		return
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			_swiping = true
			_swipe_dx = 0.0
			_swipe_fired = false
		else:
			_swiping = false
	elif event is InputEventScreenDrag and _swiping and not _swipe_fired:
		_swipe_dx += (event as InputEventScreenDrag).relative.x
		if absf(_swipe_dx) >= SWIPE_MIN:
			_swipe_fired = true
			_hop(1 if _swipe_dx > 0.0 else -1)

func _hop(dir: int) -> void:
	_col = clampi(_col + dir, 0, COLUMNS - 1)

func _fall_speed() -> float:
	return FALL_SPEED * (2.0 if _fast else 1.0)

# One full row — an item in EVERY column, so the falling mat has no gaps.
func _spawn_row() -> void:
	for col in COLUMNS:
		_spawn_cell(col)

func _spawn_cell(col: int) -> void:
	var roll := randf()
	var node : Node
	if roll < 0.50:
		node = _make_item(PIZZA_TEX, 0.09, true, 0, "")
	elif roll < 0.70:
		node = _make_item(DOLLAR_TEX, 0.36, false, 0, "dollar")
	elif roll < 0.81:
		node = _make_item(TRASH_TEX, 0.22, false, 1, "")   # бочка
		node.rotates = false
		node.knock_sound = FIRECRACKER
		(node.get_node("Sprite2D") as Sprite2D).rotation = PI / 2.0
	elif roll < 0.89:
		node = HOMELESS_SCENE.instantiate()
	elif roll < 0.97:
		node = DOG_SCENE.instantiate()
	else:
		node = SNAKE_SCENE.instantiate()
	if node.get("speed") != null:
		node.speed = 0.0            # we drive the vertical fall ourselves
	node.position = Vector2(_col_x(col), -ROW_GAP * 0.5)
	add_child(node)
	_falling.append(node)

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

func _drive_falling(delta: float) -> void:
	var vy := _fall_speed() * delta
	var bottom := get_viewport_rect().size.y + 120.0
	# In the fast phase the items "dance" to the beat — all in sync.
	if _fast:
		_beat_t += delta * BEAT_FREQ
	var b : float = sin(_beat_t)
	var alive : Array = []
	for n in _falling:
		if is_instance_valid(n):
			n.position.y += vy
			if _fast and n is Node2D:
				(n as Node2D).rotation = b * BEAT_ROT
				(n as Node2D).scale = Vector2.ONE * (1.0 + b * BEAT_SCALE)
			if n.position.y < bottom:
				alive.append(n)
			else:
				n.queue_free()
	_falling = alive

# Наш собственный поток — падающие ячейки барабанов.
func drop_flying() -> void:
	_clear_falling()

func _clear_falling() -> void:
	for n in _falling:
		if is_instance_valid(n):
			n.queue_free()
	_falling.clear()

# ── End ───────────────────────────────────────────────────────────────────────

func _end_minigame() -> void:
	if _state == State.OUTRO:
		return
	_state = State.OUTRO
	_columns_live = false
	# All items have cleared the centre — celebrate with particle fireworks.
	_fireworks()
	# Печать SLAKE BAKE больше НЕ здесь: она стала общим финальным тактом окна
	# итогов (minigame_payout.gd) — крупно по центру, сразу после барабанов.
	# Мелкий штамп над головой на своём такте у каждой мини-игры читался как
	# случайная наклейка.
	# The last items have already passed Normaldo — fade out every slots element
	# (boomboxes, any stragglers, the bg dim) before handing back to the run.
	await _fade_out_elements()
	_clear_falling()
	_clear_ui()
	_clear_boomboxes()
	if _normaldo.has_method("end_slots_mode"):
		_normaldo.end_slots_mode()
	# Music back: fade the slots track out, bring the run theme back.
	var t2 := _bg_player.create_tween()
	t2.tween_property(_bg_player, "volume_db", -40.0, 0.4)
	t2.tween_callback(_bg_player.stop)
	if is_instance_valid(_music) and _music.has_method("start"):
		_music.start()
	if is_instance_valid(_spawner) and _spawner.has_method("resume_after_event"):
		_spawner.resume_after_event()
	if is_instance_valid(_background) and _background.has_method("start_scrolling"):
		_background.start_scrolling()
	_event_frozen = false
	_arm_timer = repeat_interval
	_state = State.IDLE

# Fade boomboxes + any leftover items to transparent and un-dim the background,
# all over the same beat. Normaldo isn't faded — he carries on into the run.
func _fade_out_elements() -> void:
	const FADE := 0.6
	_dim_background(false)   # brightens the bg back over ~0.5 s
	for bb in _boomboxes:
		var spr = bb["spr"]
		if is_instance_valid(spr):
			spr.create_tween().tween_property(spr, "modulate:a", 0.0, FADE)
	for n in _falling:
		if is_instance_valid(n):
			n.create_tween().tween_property(n, "modulate:a", 0.0, FADE)
	await get_tree().create_timer(FADE + 0.05).timeout

# Outro fireworks, synced to fireworks.mp3: a few shells arc up from below the
# screen and BURST on each explosion sound (FW_BURSTS), in the new-level style.
const _FW_PALETTE : Array = [
	[Color(1.00, 0.92, 0.28), Color(1.00, 0.55, 0.10)],
	[Color(0.28, 0.90, 0.40), Color(0.10, 0.60, 0.28)],
	[Color(0.28, 0.62, 1.00), Color(0.80, 0.30, 1.00)],
	[Color(1.00, 0.30, 0.35), Color(1.00, 0.78, 0.15)],
	[Color(0.28, 1.00, 0.55), Color(1.00, 0.92, 0.28)],
]

func _fireworks() -> void:
	var vp := get_viewport_rect().size
	var sfx := AudioStreamPlayer.new()
	sfx.stream = FIREWORKS_SFX
	sfx.volume_db = -4.0
	add_child(sfx)
	sfx.play()
	sfx.finished.connect(sfx.queue_free)
	# Shells launch IMMEDIATELY in a quick volley (the moment the last row passes);
	# each rises for `rise` so it bursts exactly on its boom in the audio.
	for i in FW_BURSTS.size():
		var t : float = FW_BURSTS[i]
		var launch_at : float = float(i) * 0.10
		var rise : float = maxf(0.25, t - launch_at)
		var apex := Vector2(vp.x * 0.5 + randf_range(-200.0, 200.0), vp.y * randf_range(0.26, 0.40))
		var pal : Array = _FW_PALETTE[i % _FW_PALETTE.size()]
		get_tree().create_timer(launch_at).timeout.connect(_launch_shell.bind(apex, pal[0], pal[1], rise))

# A shell arcs up from below the screen to `apex`, then bursts (boss-toss style arc).
func _launch_shell(apex: Vector2, c1: Color, c2: Color, rise: float) -> void:
	var vp := get_viewport_rect().size
	var start := Vector2(apex.x + randf_range(-50.0, 50.0), vp.y + 40.0)
	var ctrl  := Vector2((start.x + apex.x) * 0.5 + randf_range(-70.0, 70.0), apex.y - 50.0)
	var rocket := Sprite2D.new()
	rocket.texture        = _square()
	rocket.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rocket.scale          = Vector2.ONE * 0.9
	rocket.modulate       = c1
	rocket.position       = start
	rocket.z_index        = 70
	add_child(rocket)
	# Blocky rocket trail (square particles left behind in world).
	var trail := CPUParticles2D.new()
	trail.local_coords = false
	trail.emitting  = true
	trail.amount    = 20
	trail.lifetime  = 0.4
	trail.spread    = 14.0
	trail.direction = Vector2(0.0, 1.0)
	trail.gravity   = Vector2.ZERO
	trail.initial_velocity_min = 12.0
	trail.initial_velocity_max = 34.0
	trail.scale_amount_min = 2.0
	trail.scale_amount_max = 4.0
	trail.color     = c1
	rocket.add_child(trail)
	var tw := rocket.create_tween()
	tw.tween_method(func(s: float): rocket.position = _qbezier(start, ctrl, apex, s), 0.0, 1.0, rise) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func():
		_burst_firework(apex, c1, c2)
		if is_instance_valid(trail):
			trail.emitting = false
		if is_instance_valid(rocket):
			rocket.queue_free())

func _qbezier(a: Vector2, b: Vector2, c: Vector2, t: float) -> Vector2:
	return a.lerp(b, t).lerp(b.lerp(c, t), t)

# New-level-style burst — textureless particles render as crisp SQUARES (like the
# ninja-foot smoke), ported from hud._spawn_fireworks.
func _burst_firework(pos: Vector2, c1: Color, c2: Color) -> void:
	var p := CPUParticles2D.new()
	p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	p.one_shot      = true
	p.emitting      = true
	p.amount        = 34
	p.lifetime      = 1.5
	p.explosiveness = 0.92
	p.spread        = 180.0
	p.gravity       = Vector2(0.0, 90.0)
	p.initial_velocity_min = 90.0
	p.initial_velocity_max = 270.0
	p.scale_amount_min = 4.0
	p.scale_amount_max = 10.0
	var g := Gradient.new()
	g.set_color(0, Color(c1.r, c1.g, c1.b, 1.0))
	g.set_color(1, Color(c2.r, c2.g, c2.b, 0.0))
	p.color_ramp    = g
	p.position      = pos
	p.z_index       = 71
	add_child(p)
	p.finished.connect(p.queue_free)

# Solid white square texture for the rocket (crisp blocky look with NEAREST).
func _square() -> Texture2D:
	if _sq_cache == null:
		var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
		img.fill(Color(1, 1, 1, 1))
		_sq_cache = ImageTexture.create_from_image(img)
	return _sq_cache

func _on_normaldo_died(_total_pizzas: int, _death_pos: Vector2) -> void:
	if _state == State.IDLE:
		return
	_columns_live = false
	if _normaldo.has_method("end_slots_mode"):
		_normaldo.end_slots_mode()
	_clear_falling()
	_clear_ui()
	_clear_boomboxes()
	_dim_background(false)
	_bg_player.stop()
	if is_instance_valid(_machine):
		_machine.queue_free()
	_machine = null
	_event_frozen = false
	_state = State.IDLE

# ── Background dim ─────────────────────────────────────────────────────────────

func _dim_background(on: bool) -> void:
	if not is_instance_valid(_background):
		return
	var tw := _background.create_tween()
	tw.tween_property(_background, "modulate", Color(0.45, 0.45, 0.52) if on else Color(1, 1, 1), 0.5)

# ── Boomboxes (left & right), inline DJ props ─────────────────────────────────

func _build_boomboxes() -> void:
	_clear_boomboxes()
	var vp := get_viewport_rect().size
	var half_w := BOOM1_TEX.get_width() * BOOMBOX_SCALE * 0.5
	for side in [-1, 1]:
		var spr := Sprite2D.new()
		spr.texture = BOOM1_TEX
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		spr.scale = Vector2.ONE * BOOMBOX_SCALE
		spr.z_index = 1
		var x : float = half_w + 10.0 if side < 0 else vp.x - half_w - 10.0
		spr.position = Vector2(x, vp.y * 0.45)
		add_child(spr)
		_boomboxes.append({ "spr": spr, "ft": 0.0, "frame": 0, "nt": 0.0, "rock": randf() * TAU, "pidx": 0 })

func _update_boomboxes(delta: float) -> void:
	var anim_fps : float = 14.0 if _fast else 8.0
	var note_int : float = 0.09 if _fast else 0.18   # fast phase → notes come thicker
	var rock_spd : float = 4.0 if _fast else 2.2
	for bb in _boomboxes:
		var spr : Sprite2D = bb["spr"]
		if not is_instance_valid(spr):
			continue
		bb["rock"] += delta * rock_spd
		spr.rotation = sin(bb["rock"]) * (0.26 if _fast else 0.16)
		spr.scale = Vector2.ONE * BOOMBOX_SCALE * (1.0 + sin(bb["rock"] * 1.7) * (0.14 if _fast else 0.08))
		bb["ft"] += delta
		if bb["ft"] >= 1.0 / anim_fps:
			bb["ft"] = 0.0
			bb["frame"] = 1 - bb["frame"]
			spr.texture = BOOM2_TEX if bb["frame"] == 1 else BOOM1_TEX
		bb["nt"] += delta
		if bb["nt"] >= note_int:
			bb["nt"] = 0.0
			_spawn_note_pair(bb)

# Two notes fly out symmetrically, same as the in-game boombox (NOTE_PAIRS).
func _spawn_note_pair(bb: Dictionary) -> void:
	var spr : Sprite2D = bb["spr"]
	var pair : Array = NOTE_PAIRS[int(bb["pidx"]) % NOTE_PAIRS.size()]
	bb["pidx"] = int(bb["pidx"]) + 1
	var origin : Vector2 = spr.position + Vector2(0.0, -BOOM1_TEX.get_height() * BOOMBOX_SCALE * 0.35)
	for i in 2:
		var dir : Vector2 = (pair[i] as Vector2).normalized()
		var note := Sprite2D.new()
		note.texture = NOTA1_TEX if i == 0 else NOTA2_TEX
		note.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		note.scale = Vector2.ONE * 0.11
		note.position = origin
		note.z_index = 1
		add_child(note)
		var tw := note.create_tween()
		tw.tween_property(note, "position", origin + dir * 95.0, 0.45) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(note, "modulate:a", 0.0, 0.45)
		tw.tween_callback(note.queue_free)

func _clear_boomboxes() -> void:
	for bb in _boomboxes:
		if is_instance_valid(bb["spr"]):
			bb["spr"].queue_free()
	_boomboxes.clear()

# ── Swipe tutorial (centre text + finger arrows) ──────────────────────────────

func _show_tutorial() -> void:
	_clear_ui()
	var vp := get_viewport_rect().size
	_ui = CanvasLayer.new()
	_ui.layer = 50
	add_child(_ui)

	var root := Control.new()
	root.position = Vector2(vp.x * 0.5, vp.y * 0.42)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(root)

	var lbl := Label.new()
	lbl.add_theme_font_override("font", UI_FONT)
	lbl.add_theme_font_size_override("font_size", 30)
	lbl.add_theme_color_override("font_color", Color(1, 1, 1))
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	lbl.add_theme_constant_override("outline_size", 6)
	lbl.text = "СВАЙПАЙ ВЛЕВО И ВПРАВО"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.size = Vector2(440.0, 44.0)
	lbl.position = Vector2(-220.0, -22.0)
	root.add_child(lbl)

	# A finger/arrow on each side, animating outward to mime the swipe.
	var fl := _make_finger(false)   # points left
	fl.position = Vector2(-250.0, 0.0)
	root.add_child(fl)
	var fr := _make_finger(true)    # points right
	fr.position = Vector2(250.0, 0.0)
	root.add_child(fr)
	# Wiggle both fingers outward to mime the swipe.
	var wig := root.create_tween().set_loops()
	wig.tween_property(fl, "position:x", -280.0, 0.45).set_trans(Tween.TRANS_SINE)
	wig.parallel().tween_property(fr, "position:x", 280.0, 0.45).set_trans(Tween.TRANS_SINE)
	wig.tween_property(fl, "position:x", -250.0, 0.45).set_trans(Tween.TRANS_SINE)
	wig.parallel().tween_property(fr, "position:x", 250.0, 0.45).set_trans(Tween.TRANS_SINE)

	# Pop in, hold, fade out.
	root.modulate = Color(1, 1, 1, 0.0)
	var ftw := root.create_tween()
	ftw.tween_property(root, "modulate:a", 1.0, 0.25)
	ftw.tween_interval(2.6)
	ftw.tween_property(root, "modulate:a", 0.0, 0.4)

func _make_finger(point_right: bool) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = FINGER_TEX
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.scale = Vector2(-0.95 if point_right else 0.95, 0.95)   # default art points left
	return s

func _clear_ui() -> void:
	if is_instance_valid(_ui):
		_ui.queue_free()
	_ui = null
