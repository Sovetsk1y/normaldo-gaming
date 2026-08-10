extends Area2D

const MOLOTOV_TEX := preload("res://assets/items/molotov1.png")
const SFX         := preload("res://assets/audio/molotov.mp3")
const FIRE_SCENE  := preload("res://scenes/fire.tscn")

const CLEAR_RADIUS     := 80.0
const WARNING_DURATION := 1.4
const CLEARABLE_GROUPS := ["pizza", "obstacle", "slowing", "bomb",
							"pizza_pack", "dollar", "money_bag", "magnet"]

enum State { WARNING, FLYING, DONE }

@export var speed      : float = 250.0
@export var fire_count : int   = 4
# When > 0, clamps the landing x to [vp.size.x * target_x_min_ratio, …],
# letting the spawner restrict the impact to a horizontal slice (e.g. 0.5
# = right half only). Defaults to 0 = full screen.
@export var target_x_min_ratio : float = 0.0

var _state     : State  = State.WARNING
var _start     : Vector2
var _target    : Vector2
var _duration  : float  = 2.0
var _arc_h     : float  = 0.0
var _t         : float  = 0.0
var _warn_t    : float  = 0.0
var _warn_node : Node2D = null

@onready var _sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	_sprite.texture        = MOLOTOV_TEX
	_sprite.scale          = Vector2.ONE * 0.14
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.visible        = false  # скрыт во время предупреждения
	collision_layer = 0
	collision_mask  = 0
	add_to_group("molotov")

	_start  = position
	var vp  := get_viewport_rect()
	var mx  := vp.size.x * 0.15
	var my  := vp.size.y * 0.15
	# Pick a target, but reject roll-attempts that land too close to any
	# molotov already in flight / about to explode. Minimum separation is
	# two fire-spread diameters so the burning zones never overlap.
	var min_sep : float = _fire_radius() * 2.4
	_target = _pick_spaced_target(vp, mx, my, min_sep)
	var dist := _start.distance_to(_target)
	_arc_h    = dist * 0.38
	_duration = clampf(dist / (speed * 0.85), 1.3, 3.2)

	_warn_node = _make_warn_oval()
	get_parent().add_child(_warn_node)
	# Fade-in только после добавления в дерево — create_tween требует get_tree()
	var tw := _warn_node.create_tween()
	tw.tween_property(_warn_node, "modulate:a", 1.0, 0.22)

func _process(delta: float) -> void:
	match _state:
		State.WARNING:
			_warn_t += delta
			if is_instance_valid(_warn_node):
				var pulse := 0.85 + sin(_warn_t * TAU * 1.5) * 0.18
				_warn_node.scale    = Vector2.ONE * pulse
				_warn_node.modulate = Color(1, 1, 1, 0.6 + sin(_warn_t * TAU * 1.5) * 0.3)
			if _warn_t >= WARNING_DURATION:
				_begin_flight()

		State.FLYING:
			_t += delta / _duration
			if _t >= 1.0:
				_land()
				return
			position          = _start.lerp(_target, _t) - Vector2(0, _arc_h * sin(_t * PI))
			_sprite.rotation += 4.5 * delta
			if is_instance_valid(_warn_node):
				_warn_node.modulate.a = maxf(0.0, 1.0 - _t * 1.6)

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if is_instance_valid(_warn_node):
			_warn_node.queue_free()

func _begin_flight() -> void:
	_state          = State.FLYING
	_sprite.visible = true
	var p := _make_fly_particles()
	_sprite.add_child(p)

func _land() -> void:
	_state = State.DONE
	set_process(false)
	position = _target

	if is_instance_valid(_warn_node):
		_warn_node.queue_free()

	# Splash burst removed — the fire pool itself already reads "explosion"
	# without extra particles drowning out the lanes around the impact.
	_play_sfx()
	_screen_shake()
	_clear_area()
	_spawn_fires()
	queue_free()

func _make_fly_particles() -> CPUParticles2D:
	var p                  := CPUParticles2D.new()
	p.emitting              = true
	p.amount                = 22
	p.lifetime              = 0.32
	p.explosiveness         = 0.0
	p.direction             = Vector2(0, -1)
	p.spread                = 38.0
	p.gravity               = Vector2.ZERO
	p.initial_velocity_min  = 90.0
	p.initial_velocity_max  = 180.0
	p.scale_amount_min      = 3.0
	p.scale_amount_max      = 7.0
	p.position              = Vector2(0, -220)  # горлышко в локальном пространстве спрайта
	var g                  := Gradient.new()
	g.set_color(0,          Color(1.00, 0.95, 0.30, 1.00))
	g.add_point(0.30,       Color(1.00, 0.42, 0.04, 0.90))
	g.add_point(1.00,       Color(0.35, 0.04, 0.00, 0.00))
	p.color_ramp            = g
	return p

func _spawn_impact_burst() -> void:
	var p                  := CPUParticles2D.new()
	p.one_shot              = true
	p.emitting              = true
	p.amount                = 60
	p.lifetime              = 0.80
	p.explosiveness         = 1.0
	p.direction             = Vector2(0, -1)
	p.spread                = 180.0
	p.gravity               = Vector2(0, 120)
	p.initial_velocity_min  = 140.0
	p.initial_velocity_max  = 310.0
	p.scale_amount_min      = 5.0
	p.scale_amount_max      = 15.0
	p.global_position       = global_position
	var g                  := Gradient.new()
	g.set_color(0,          Color(1.00, 1.00, 0.70, 1.00))
	g.add_point(0.18,       Color(1.00, 0.52, 0.04, 1.00))
	g.add_point(0.55,       Color(0.80, 0.10, 0.00, 0.75))
	g.add_point(1.00,       Color(0.10, 0.00, 0.00, 0.00))
	p.color_ramp            = g
	get_parent().add_child(p)
	p.finished.connect(p.queue_free)

# ── Предупреждающий овал ──────────────────────────────────────────────────────

func _make_warn_oval() -> Node2D:
	var node    := Node2D.new()
	node.position = _target
	node.z_index  = 1

	var oval := _oval_size()
	var rx   := oval.x
	var ry   := oval.y
	var segs := 36
	var pts  := PackedVector2Array()
	for i in segs:
		var a := i * TAU / segs
		pts.append(Vector2(cos(a) * rx, sin(a) * ry))

	var fill         := Polygon2D.new()
	fill.polygon      = pts
	fill.color        = Color(1.0, 0.10, 0.05, 0.38)
	node.add_child(fill)

	node.modulate.a = 0.0
	return node

# ── Приземление ───────────────────────────────────────────────────────────────

func _play_sfx() -> void:
	var audio  := AudioStreamPlayer.new()
	audio.stream = SFX
	get_parent().add_child(audio)
	audio.play()
	audio.finished.connect(audio.queue_free)

func _screen_shake() -> void:
	var game := get_parent().get_parent() as Node2D
	if not game:
		return
	var tw  := game.create_tween()
	var amp := 7.0
	for i in 6:
		tw.tween_property(game, "position",
			Vector2(randf_range(-amp, amp), randf_range(-amp * 0.75, amp * 0.75)), 0.033)
		amp *= 0.72
	tw.tween_property(game, "position", Vector2.ZERO, 0.05)

func _clear_area() -> void:
	for child in get_parent().get_children():
		if child == self or not is_instance_valid(child) or not child is Node2D:
			continue
		if (child as Node2D).global_position.distance_to(global_position) > CLEAR_RADIUS:
			continue
		for grp in CLEARABLE_GROUPS:
			if child.is_in_group(grp):
				if child.has_method("explode"):
					child.explode()
				else:
					child.queue_free()
				break

func _fire_radius() -> float:
	match fire_count:
		6:    return 52.0
		8:    return 62.0
		_:    return 44.0

func _oval_size() -> Vector2:
	match fire_count:
		6:    return Vector2(62.0, 31.0)
		8:    return Vector2(74.0, 37.0)
		_:    return Vector2(50.0, 25.0)

# Looks at every sibling Molotov currently in the scene tree and tries to
# place this one's target at least `min_sep` away from all of them. After
# `MAX_TRIES` rolls we just accept the last sample to avoid spinning.
func _pick_spaced_target(vp: Rect2, mx: float, my: float, min_sep: float) -> Vector2:
	const MAX_TRIES : int = 18
	var existing : Array = []
	var parent := get_parent()
	if parent != null:
		for n in parent.get_children():
			if n != self and n.is_in_group("molotov"):
				existing.append((n as Node2D).get("_target"))
	var x_min : float = maxf(mx, vp.size.x * target_x_min_ratio)
	var x_max : float = vp.size.x - mx
	var picked := Vector2(
		randf_range(x_min, x_max),
		randf_range(my, vp.size.y - my)
	)
	for _i in MAX_TRIES:
		var ok := true
		for t in existing:
			if t == null:
				continue
			if picked.distance_to(t) < min_sep:
				ok = false
				break
		if ok:
			return picked
		picked = Vector2(
			randf_range(x_min, x_max),
			randf_range(my, vp.size.y - my)
		)
	return picked

func _spawn_fires() -> void:
	var parent := get_parent()
	var radius := _fire_radius()
	for i in fire_count:
		var fire := FIRE_SCENE.instantiate()
		parent.add_child(fire)
		fire.global_position = global_position
		fire.speed           = speed

		if i > 0:
			var angle := (i - 1) * TAU / (fire_count - 1) + randf_range(-0.35, 0.35)
			var r     := radius + randf_range(-10.0, 10.0)
			var dest  := global_position + Vector2(cos(angle), sin(angle)) * r
			var tw    := fire.create_tween()
			tw.tween_property(fire, "global_position", dest, 0.22) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
