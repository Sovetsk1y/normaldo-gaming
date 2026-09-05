extends Node2D

# ── Spring ────────────────────────────────────────────────────────────────────
const SPRING_SHOW_DIST  := 55.0
const SPRING_FULL_DIST  := 160.0
const SPRING_COILS      := 7
const SPRING_PTS        := 14
const SPRING_AMPLITUDE  := 9.0
const SPRING_W_OUTER    := 5.0
const SPRING_W_INNER    := 2.0
const SPRING_CLR_OUTER  := Color(0.18, 0.20, 0.23)
const SPRING_CLR_INNER  := Color(0.80, 0.86, 0.92)

const COUCH_TEX   := preload("res://assets/background_items/couch.png")
const COUCH_SCALE := 2.0

# ── Позиция на экране меню (смещение от центра экрана) ───────────────────────
# Подгони эти значения под углубление на bg_intro
const MENU_OFFSET := Vector2(-260, 110)
# Same scroll speed as the background and the TV — the couch is a piece of
# the room, so once the bg starts moving it slides off-screen with everything
# else instead of hovering in place.
const SCROLL_SPEED : float = 68.0   # синхронно с фоном (background.gd)

var _bob_t          : float             = 0.0
var _normaldo       : Node2D            = null
var _spring_outer   : Line2D            = null
var _spring_inner   : Line2D            = null
var _sprite         : Sprite2D          = null
var _thrusters      : Array             = []
var _game_started   : bool              = false
var _flying         : bool              = false
var _thruster_audio : AudioStreamPlayer = null
var _bg             : Node               = null

func _ready() -> void:
	z_index = 0

	_sprite                = Sprite2D.new()
	_sprite.texture        = COUCH_TEX
	_sprite.scale          = Vector2.ONE * COUCH_SCALE
	_sprite.z_index        = 0
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)

	_spring_outer               = Line2D.new()
	_spring_outer.width         = SPRING_W_OUTER
	_spring_outer.default_color = SPRING_CLR_OUTER
	_spring_outer.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_spring_outer.end_cap_mode   = Line2D.LINE_CAP_ROUND
	_spring_outer.z_index        = 0
	_spring_outer.visible        = false
	add_child(_spring_outer)

	_spring_inner               = Line2D.new()
	_spring_inner.width         = SPRING_W_INNER
	_spring_inner.default_color = SPRING_CLR_INNER
	_spring_inner.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_spring_inner.end_cap_mode   = Line2D.LINE_CAP_ROUND
	_spring_inner.z_index        = 0
	_spring_inner.visible        = false
	add_child(_spring_inner)

	_thrusters.append(_add_thruster(-42.0, 23))
	_thrusters.append(_add_thruster( 32.0, 18))

	_thruster_audio = AudioStreamPlayer.new()
	_thruster_audio.volume_db = -8.0
	add_child(_thruster_audio)
	var thr_stream = load("res://assets/audio/thruster.mp3")
	if thr_stream:
		(thr_stream as AudioStreamMP3).loop = true
		_thruster_audio.stream = thr_stream

	# Стартуем в позиции меню, без огня
	position = get_viewport_rect().get_center() + MENU_OFFSET
	_bg = get_parent().get_node_or_null("Background")

func start_game() -> void:
	# New intro: the couch is a piece of the room — it stays put, no flight,
	# no thrusters, no spring. Normaldo throws the remote and jumps off; the
	# couch just bobs gently in place from this point on.
	_game_started = true
	_flying       = false
	for t in _thrusters:
		t.emitting = false
	if _thruster_audio and _thruster_audio.playing:
		_thruster_audio.stop()
	if _spring_outer:
		_spring_outer.visible = false
	if _spring_inner:
		_spring_inner.visible = false
	if _normaldo and _normaldo.has_method("start_bob"):
		_normaldo.start_bob()

# Уйти со сцены СРАЗУ. Обычно диван уезжает влево вместе с фоном и там же себя
# освобождает — это верно для первого уровня, где комната и есть фон. Но перед
# вторым и третьим эпизодом фон подменяется за занавесом, и занавес поднимается
# раньше, чем диван успевает уехать: на улице пару секунд стоит диван из
# квартиры. За занавесом его и убираем — переставлять мебель при зрителе
# незачем.
func leave_scene() -> void:
	visible = false
	set_process(false)
	if _thruster_audio and _thruster_audio.playing:
		_thruster_audio.stop()
	queue_free()

func menu_position() -> Vector2:
	return get_viewport_rect().get_center() + MENU_OFFSET

func _process(delta: float) -> void:
	if _normaldo == null or not is_instance_valid(_normaldo):
		_normaldo = get_parent().get_node_or_null("Normaldo")
	if _bg == null or not is_instance_valid(_bg):
		_bg = get_parent().get_node_or_null("Background")

	# Once the background starts scrolling, the couch is a piece of the room —
	# it slides left at the same speed and leaves the screen with the rest of
	# the intro decor instead of hovering in place.
	if _bg != null and _bg.get("_scrolling") == true:
		position.x -= SCROLL_SPEED * delta
		# Reclaim memory once the couch is fully past the left edge.
		var sprite_half : float = (COUCH_TEX.get_width() * COUCH_SCALE) * 0.5
		if position.x < -sprite_half:
			queue_free()
			return

	# Couch is glued to its position otherwise — no bob, no chasing Normaldo.
	_sprite.position.y = 0.0
	for t in _thrusters:
		t.position.y = t.get_meta("base_y")

	# Spring is now only ever drawn during menu idle — once the run starts,
	# Normaldo flies off to play and the visual would just be noise.
	if _game_started:
		_spring_outer.visible = false
		_spring_inner.visible = false
	elif _normaldo and is_instance_valid(_normaldo):
		_update_spring()
	else:
		_spring_outer.visible = false
		_spring_inner.visible = false

func _update_spring() -> void:
	var dist := global_position.distance_to(_normaldo.global_position)

	if dist < SPRING_SHOW_DIST:
		_spring_outer.visible = false
		_spring_inner.visible = false
		return

	var alpha := clampf(
		(dist - SPRING_SHOW_DIST) / (SPRING_FULL_DIST - SPRING_SHOW_DIST),
		0.0, 1.0
	)
	_spring_outer.default_color = Color(SPRING_CLR_OUTER, alpha)
	_spring_inner.default_color = Color(SPRING_CLR_INNER, alpha)
	_spring_outer.visible       = true
	_spring_inner.visible       = true

	var spring_start := Vector2(4.0, _sprite.position.y - 8)
	var to           := _normaldo.global_position - global_position - spring_start
	var perp         := to.normalized().rotated(PI * 0.5)
	var pts          := _build_spring_pts(spring_start, to, perp)
	_spring_outer.points = pts
	_spring_inner.points = pts

func _build_spring_pts(start: Vector2, to: Vector2, perp: Vector2) -> PackedVector2Array:
	var pts   := PackedVector2Array()
	var total := SPRING_COILS * SPRING_PTS
	for i in range(total + 1):
		var t      := float(i) / total
		var angle  := t * SPRING_COILS * TAU
		var offset := sin(angle) * SPRING_AMPLITUDE
		pts.append(start + to * t + perp * offset)
	return pts

func _add_thruster(x: float, y: float) -> CPUParticles2D:
	var p                    := CPUParticles2D.new()
	p.position                = Vector2(x, y)
	p.emitting                = false
	p.amount                  = 14
	p.lifetime                = 0.30
	p.explosiveness           = 0.0
	p.direction               = Vector2(0, 1)
	p.spread                  = 15.0
	p.gravity                 = Vector2.ZERO
	p.initial_velocity_min    = 35.0
	p.initial_velocity_max    = 65.0
	p.scale_amount_min        = 2.0
	p.scale_amount_max        = 4.0
	p.color                   = Color(1.0, 0.55, 0.05, 0.85)
	p.emission_shape          = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents   = Vector2(3.0, 0.5)
	p.set_meta("base_y", y)
	add_child(p)
	return p
