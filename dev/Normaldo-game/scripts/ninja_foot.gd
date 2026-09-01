extends Node2D

const NINJA_FOOT1_TEX := preload("res://assets/bosses/ninja_foot/ninja_foot1.png")
const PRED_TEXS := [
	preload("res://assets/bosses/ninja_foot/nf_predator1.png"),
	preload("res://assets/bosses/ninja_foot/nf_predator2.png"),
	preload("res://assets/bosses/ninja_foot/nf_predator3.png"),
	preload("res://assets/bosses/ninja_foot/nf_predator4.png"),
	preload("res://assets/bosses/ninja_foot/nf_predator5.png"),
	preload("res://assets/bosses/ninja_foot/nf_predator6.png"),
]
const BOSS_MUSIC      := preload("res://assets/audio/hard_track.mp3")
const BOSS_STINGER    := preload("res://assets/audio/boss_fight.mp3")
const SHURIKEN_SFX    := preload("res://assets/audio/shurikens.mp3")
const PREDATOR_SFX    := preload("res://assets/audio/shredder_predator.mp3")
const SHURIKEN_SCENE  := preload("res://scenes/shuriken.tscn")
const SMOKE_SCRIPT    := preload("res://scripts/smoke_obstacle.gd")
const SMOKE_TEX       := preload("res://assets/bosses/ninja_foot/smoke.png")
const SMOKE_PROJ_TEX  := preload("res://assets/bosses/ninja_foot/smoke_projectile.png")
const BANNER_TEX      := preload("res://assets/bosses/ninja_foot/banner.png")
const SWORD1_TEX      := preload("res://assets/bosses/ninja_foot/sword1.png")
const SWORD2_TEX      := preload("res://assets/bosses/ninja_foot/sword2.png")
const UI_FONT         := preload("res://assets/fonts/RussoOne-Regular.ttf")

const BOSS_INTRO_W := 147.0   # intro slide-in size (220 / 1.5)
const BOSS_INTRO_H := 213.0
const BOSS_ATCK_W  :=  90.0   # attack appearance size (~1.5x Normaldo)
const BOSS_ATCK_H  := 130.0
const SHURIKEN_W   :=  58.0
const SHURIKEN_H   :=  82.0
const WAVE_W       :=  40.0   # wave-ninja head size (smaller to reduce overlap)
const WAVE_H       :=  57.0

signal defeated

var _normaldo  : Node2D = null
var _spawner   : Node   = null
var _game_root : Node2D = null
var _sprite        : Sprite2D
var _music         : AudioStreamPlayer
var boss_test_mode : bool = false

func setup(normaldo: Node2D, spawner: Node, game_root: Node2D, test_mode: bool = false) -> void:
	_normaldo      = normaldo
	_spawner       = spawner
	_game_root     = game_root
	boss_test_mode = test_mode

func _ready() -> void:
	z_index = 40

	_sprite = Sprite2D.new()
	_sprite.texture        = NINJA_FOOT1_TEX
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var tsz := NINJA_FOOT1_TEX.get_size()
	_sprite.scale   = Vector2(BOSS_INTRO_W / tsz.x, BOSS_INTRO_H / tsz.y)
	_sprite.flip_h  = false
	_sprite.visible = false
	add_child(_sprite)

	_music = AudioStreamPlayer.new()
	var ms := BOSS_MUSIC.duplicate() as AudioStreamMP3
	ms.loop          = true
	_music.stream    = ms
	_music.volume_db = -14.0
	add_child(_music)

	_run_boss.call_deferred()

# ── Main boss sequence ────────────────────────────────────────────────────────

func _run_boss() -> void:
	var vp := get_viewport_rect()

	position        = Vector2(vp.size.x + BOSS_INTRO_W, vp.size.y * 0.5)
	_sprite.visible = true

	_spawner.set_process(false)
	_clear_spawner_items()

	var bg := _game_root.get_node_or_null("Background")
	if bg:
		bg.stop_scrolling()

	var game_music := _game_root.get_node_or_null("Music")
	if game_music and game_music.has_method("fade_out"):
		game_music.fade_out()

	# Start track at half battle volume as boss head slides in
	_music.play()

	# Slide in from right with slide particles
	_spawn_slide_particles()
	var tw_in := create_tween()
	tw_in.tween_property(self, "position:x", vp.size.x - BOSS_INTRO_W * 0.5 - 20.0, 0.85) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	await tw_in.finished

	_screen_shake(14.0, 10)
	_impact_burst()

	# Boss head shake on landing
	var shake_tw := create_tween()
	for _i in 5:
		shake_tw.tween_property(_sprite, "rotation", 0.10, 0.08)
		shake_tw.tween_property(_sprite, "rotation", -0.10, 0.08)
	shake_tw.tween_property(_sprite, "rotation", 0.0, 0.08)
	await get_tree().create_timer(0.5).timeout

	# Intro speech bubble — boss taunts Normaldo before the fight starts.
	# Player input is locked while the bubble is up so the moment lands.
	await _show_intro_speech()

	# Start gradual volume fade before banner so it reaches battle level by fight start
	var tw_vol := create_tween()
	tw_vol.tween_property(_music, "volume_db", -2.0, 2.8)

	# Boss fight intro banner
	await _show_boss_banner()

	# Slide boss back off-screen right
	var tw_out := create_tween()
	tw_out.tween_property(self, "position:x", vp.size.x + BOSS_INTRO_W, 0.5) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw_out.finished
	_sprite.visible = false

	# ── Attack phases ────────────────────────────────────────────────────────
	var phases := [
		# 1. Shurikens ×4  cd 2.5 s
		{"type": "shuriken", "speed": 500.0, "delay": 2.5},
		{"type": "shuriken", "speed": 500.0, "delay": 2.5},
		{"type": "shuriken", "speed": 500.0, "delay": 2.5},
		{"type": "shuriken", "speed": 500.0, "delay": 2.5},
		# 2. Predator wave 1 — 1 pass (2 per side)
		{"type": "predator_wave", "reps": 1, "speed": 500.0, "inter": 1.0},
		# 3. Shurikens ×4  cd 1.5 s
		{"type": "shuriken", "speed": 520.0, "delay": 1.5},
		{"type": "shuriken", "speed": 520.0, "delay": 1.5},
		{"type": "shuriken", "speed": 520.0, "delay": 1.5},
		{"type": "shuriken", "speed": 520.0, "delay": 1.5},
		# 4. Predator wave 2 — 2 passes
		{"type": "predator_wave", "reps": 2, "speed": 550.0, "inter": 0.9},
		# 5. Smoke corners
		{"type": "smoke_corners"},
		# 6. Shurikens ×8  cd 1.5 s  ninja hidden behind smoke
		{"type": "shuriken", "speed": 560.0, "delay": 1.5, "invisible": true},
		{"type": "shuriken", "speed": 560.0, "delay": 1.5, "invisible": true},
		{"type": "shuriken", "speed": 560.0, "delay": 1.5, "invisible": true},
		{"type": "shuriken", "speed": 560.0, "delay": 1.5, "invisible": true},
		{"type": "shuriken", "speed": 560.0, "delay": 1.5, "invisible": true},
		{"type": "shuriken", "speed": 560.0, "delay": 1.5, "invisible": true},
		{"type": "shuriken", "speed": 560.0, "delay": 1.5, "invisible": true},
		{"type": "shuriken", "speed": 560.0, "delay": 1.5, "invisible": true},
		# 7. Hard shurikens ×4 — 6 per burst
		{"type": "shuriken", "speed": 580.0, "delay": 1.2, "count": 6},
		{"type": "shuriken", "speed": 580.0, "delay": 1.2, "count": 6},
		{"type": "shuriken", "speed": 580.0, "delay": 1.2, "count": 6},
		{"type": "shuriken", "speed": 580.0, "delay": 1.2, "count": 6},
		# 8. Predator wave 3 — 3 passes (hard finale)
		{"type": "predator_wave", "reps": 3, "speed": 500.0, "inter": 1.0, "pre_delay": 2.5},
	]

	for phase in phases:
		if not is_instance_valid(self):
			return
		match phase["type"]:
			"shuriken":       await _shuriken_shower(phase["speed"], phase["delay"], phase.get("invisible", false), phase.get("count", 3))
			"predator_wave":  await _predator_wave(phase["reps"], phase["speed"], phase["inter"], phase.get("pre_delay", 0.0))
			"smoke_corners":  await _smoke_corners()

	await _smoke_final()

	# Defeated
	_music.stop()
	# Музыка возвращается ВСЕГДА, а не только при дев-вызове. Она уходит в
	# fade_out на входе в бой, и в кампании её никто не включал обратно: после
	# победы над боссом забег продолжался в тишине до самой смерти.
	if is_instance_valid(game_music) and game_music.has_method("start"):
		game_music.start()
	if boss_test_mode:
		# Undo the freeze set by clear_items() so patterns can spawn again.
		_spawner.set("_frozen", false)
		_spawner.set("_pattern_running", false)
		_spawner.set_process(true)
		if is_instance_valid(bg):
			bg.start_scrolling()

	_spawn_victory_burst()
	await get_tree().create_timer(1.2).timeout
	defeated.emit()
	if boss_test_mode and is_instance_valid(_normaldo):
		var kill_tw := _game_root.create_tween()
		kill_tw.tween_interval(3.0)
		kill_tw.tween_callback(func(): if is_instance_valid(_normaldo): _normaldo.call("_die"))
	queue_free()

# ── Куда он смотрит ──────────────────────────────────────────────────────────
# Голова нарисована СМОТРЯЩЕЙ ВЛЕВО — она и приезжает справа, навстречу игроку.
# Значит зеркалить надо тогда, когда цель СПРАВА, а не слева.
#
# Стояло наоборот, и обе атаки из ПРАВЫХ углов он отыгрывал спиной к игроку:
# вылезал в углу, отворачивался и кидал сюрикены куда-то за кадр. На рывке это
# ещё как-то читалось (он летит на игрока), а на сюрикенах — нет.
func _face_player() -> void:
	if not is_instance_valid(_normaldo):
		_sprite.flip_h = false
		return
	_sprite.flip_h = _normaldo.global_position.x > global_position.x

# ── Attack: Shuriken Shower ───────────────────────────────────────────────────

func _shuriken_shower(speed: float, end_delay: float, invisible: bool = false, count: int = 3) -> void:
	var vp      := get_viewport_rect()
	var corners := _corner_positions(vp, SHURIKEN_W, SHURIKEN_H)
	corners.shuffle()
	position = corners[0]

	if invisible:
		_play_sfx(SHURIKEN_SFX)
		for i in count:
			_fire_shuriken(speed, i * 0.22)
		await get_tree().create_timer(end_delay).timeout
		return

	_face_player()
	_sprite.texture = NINJA_FOOT1_TEX
	var tsz         := NINJA_FOOT1_TEX.get_size()
	var base_s      := Vector2(SHURIKEN_W / tsz.x, SHURIKEN_H / tsz.y)
	_sprite.scale   = Vector2.ZERO
	_sprite.visible = true

	var tw_in := create_tween()
	tw_in.tween_property(_sprite, "scale", base_s, 0.22) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tw_in.finished

	_play_sfx(SHURIKEN_SFX)
	for i in count:
		_fire_shuriken(speed, i * 0.22)

	await get_tree().create_timer(0.7).timeout

	var tw_out := create_tween()
	tw_out.tween_property(_sprite, "scale", Vector2.ZERO, 0.18) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw_out.finished
	_sprite.visible = false

	await get_tree().create_timer(end_delay).timeout

func _fire_shuriken(speed: float, delay: float) -> void:
	var s := SHURIKEN_SCENE.instantiate()
	_game_root.add_child(s)
	s.global_position = global_position + Vector2(
		randf_range(-45.0, 45.0), randf_range(-55.0, 55.0))
	s.init(_normaldo, speed, delay)

# ── Attack: Predator Rush ─────────────────────────────────────────────────────

func _predator_attack(speed: float, post_delay: float = 0.0) -> void:
	var vp := get_viewport_rect()

	position        = _random_offscreen_pos(vp)
	_sprite.texture = NINJA_FOOT1_TEX
	var tsz         := NINJA_FOOT1_TEX.get_size()
	var base_s      := Vector2(SHURIKEN_W / tsz.x, SHURIKEN_H / tsz.y)
	_sprite.scale   = base_s
	var to_norm     := _normaldo.global_position - global_position
	_face_player()
	_sprite.visible = true

	var dir := to_norm.normalized()
	var arm := _make_sword_arm(dir)
	add_child(arm)

	_play_sfx(PREDATOR_SFX)

	# Brief grow before rush
	var tw_grow := create_tween()
	tw_grow.set_parallel(true)
	tw_grow.tween_property(_sprite, "scale", base_s * 1.45, 0.28) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw_grow.tween_property(arm, "position", dir * 72.0, 0.28) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tw_grow.finished

	# Rush through Normaldo's position and off-screen
	var dest     := _normaldo.global_position + dir * vp.size.length() * 1.4
	var rush_dur := global_position.distance_to(dest) / speed

	var tw_rush := create_tween()
	tw_rush.tween_property(self, "global_position", dest, rush_dur) \
		.set_trans(Tween.TRANS_LINEAR)

	_animate_sword_rush(arm, dir, rush_dur)

	await tw_rush.finished

	arm.queue_free()
	_sprite.visible = false
	_sprite.texture = NINJA_FOOT1_TEX
	position        = Vector2(vp.size.x + BOSS_ATCK_W, vp.size.y * 0.5)
	await get_tree().create_timer(post_delay).timeout

func _make_sword_arm(dir: Vector2) -> Sprite2D:
	var arm := Sprite2D.new()
	arm.texture        = SWORD1_TEX
	arm.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var tsz    := SWORD1_TEX.get_size()
	var arm_sc := 100.0 / maxf(tsz.x, tsz.y)
	arm.scale    = Vector2.ONE * arm_sc
	arm.position = dir * 58.0
	arm.rotation = atan2(dir.y, dir.x)
	return arm

func _animate_sword_rush(arm: Sprite2D, dir: Vector2, dur: float) -> void:
	var base_angle := atan2(dir.y, dir.x)
	var do_spin    := bool(randi() % 2)

	var tw := create_tween()
	# Phase 1 (0–38%): blade points toward Normaldo
	tw.tween_interval(dur * 0.38)
	# Switch to closed grip for strike
	tw.tween_callback(func(): if is_instance_valid(arm): arm.texture = SWORD2_TEX)
	if do_spin:
		# Кувырок — full spin
		tw.tween_property(arm, "rotation", base_angle + TAU, dur * 0.40) \
			.set_trans(Tween.TRANS_SINE)
	else:
		# Vertical slash — wide sweep then snap back
		tw.tween_property(arm, "rotation", base_angle + PI * 1.5, dur * 0.28) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	# Phase 3 (last 15%): open grip, blade in travel direction
	tw.tween_callback(func(): if is_instance_valid(arm): arm.texture = SWORD1_TEX)
	tw.tween_property(arm, "rotation", base_angle, dur * 0.15) \
		.set_trans(Tween.TRANS_SINE)

# ── Attack: Predator Wave ─────────────────────────────────────────────────────
# Always 2 ninjas per group. reps = how many L→R passes to run.
# Wave 1: reps=1, Wave 2: reps=2, Wave 3 (finale): reps=3.

func _predator_wave(reps: int, speed: float, inter_delay: float, pre_delay: float = 0.0) -> void:
	if pre_delay > 0.0:
		await get_tree().create_timer(pre_delay).timeout
	var vp := get_viewport_rect()
	var mx  := WAVE_W * 0.5 + 30.0
	var my  := WAVE_H * 0.5 + 30.0

	for r in reps:
		# 4 evenly-spaced slots; interleaved split gives 2-slot intra-group gap
		var lanes_a: Array[float] = [vp.size.y * 1.0 / 5.0, vp.size.y * 3.0 / 5.0]
		var lanes_b: Array[float] = [vp.size.y * 2.0 / 5.0, vp.size.y * 4.0 / 5.0]
		if bool(randi() % 2):
			var tmp := lanes_a; lanes_a = lanes_b; lanes_b = tmp

		# Random start for group A: left/right edge or one of 4 corners (diagonal)
		var start_mode  := randi() % 6
		var a_from_left := (start_mode == 0 or start_mode == 2 or start_mode == 4)
		var ax_end      := vp.size.x + mx if a_from_left else -mx

		_play_sfx(PREDATOR_SFX)
		for i in 2:
			var ty := lanes_a[i]
			var sx: float
			var sy: float
			match start_mode:
				0: sx = -mx;            sy = ty
				1: sx = vp.size.x + mx; sy = ty
				2: sx = -mx;            sy = -my
				3: sx = vp.size.x + mx; sy = -my
				4: sx = -mx;            sy = vp.size.y + my
				_: sx = vp.size.x + mx; sy = vp.size.y + my
			_spawn_wave_ninja(Vector2(sx, sy), Vector2(ax_end, ty), speed)

		await get_tree().create_timer(inter_delay).timeout

		# Group B: straight horizontal from the opposite side
		_play_sfx(PREDATOR_SFX)
		var b_from_left := not a_from_left
		var bx_s := -mx if b_from_left else vp.size.x + mx
		var bx_e := vp.size.x + mx if b_from_left else -mx
		for y in lanes_b:
			_spawn_wave_ninja(Vector2(bx_s, y), Vector2(bx_e, y), speed)

		if r < reps - 1:
			await get_tree().create_timer(inter_delay).timeout

	var exit_t := (vp.size.x + mx * 2.0) / speed
	await get_tree().create_timer(exit_t + 0.25).timeout

func _spawn_wave_ninja(start: Vector2, end: Vector2, speed: float) -> void:
	var dir := (end - start).normalized()

	var node := Area2D.new()
	node.z_index         = 40
	node.collision_layer = 2
	node.collision_mask  = 0
	node.add_to_group("obstacle")
	_game_root.add_child(node)
	node.global_position = start
	node.rotation        = atan2(dir.y, dir.x)

	var cs     := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = minf(WAVE_W, WAVE_H) * 0.42
	cs.shape = circle
	node.add_child(cs)

	var head := Sprite2D.new()
	head.texture        = NINJA_FOOT1_TEX
	head.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var tsz  := NINJA_FOOT1_TEX.get_size()
	head.scale = Vector2(WAVE_W / tsz.x, WAVE_H / tsz.y)
	node.add_child(head)

	# Dual swords: sword1 left, sword1 flipped right — bob in opposite phase
	var sword_tsz := SWORD1_TEX.get_size()
	var sword_sc  := 100.0 / maxf(sword_tsz.x, sword_tsz.y)
	var bob_amp   := 7.0
	var bob_t     := 0.28

	var arm_l := Sprite2D.new()
	arm_l.texture        = SWORD1_TEX
	arm_l.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	arm_l.scale          = Vector2.ONE * sword_sc
	arm_l.position       = Vector2(-WAVE_W * 0.72, 0.0)
	node.add_child(arm_l)

	var arm_r := Sprite2D.new()
	arm_r.texture        = SWORD1_TEX
	arm_r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	arm_r.scale          = Vector2.ONE * sword_sc
	arm_r.flip_h         = true
	arm_r.position       = Vector2(WAVE_W * 0.72, 0.0)
	node.add_child(arm_r)

	var tw_l := node.create_tween()
	tw_l.set_loops()
	tw_l.tween_property(arm_l, "position:y",  bob_amp, bob_t).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw_l.tween_property(arm_l, "position:y", -bob_amp, bob_t).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	node.tree_exiting.connect(tw_l.kill)

	var tw_r := node.create_tween()
	tw_r.set_loops()
	tw_r.tween_property(arm_r, "position:y", -bob_amp, bob_t).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw_r.tween_property(arm_r, "position:y",  bob_amp, bob_t).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	node.tree_exiting.connect(tw_r.kill)

	var dur := start.distance_to(end) / speed
	var tw := node.create_tween()
	tw.tween_property(node, "global_position", end, dur).set_trans(Tween.TRANS_LINEAR)
	tw.tween_callback(node.queue_free)


# ── Attack: Smoke Corners ─────────────────────────────────────────────────────

func _smoke_corners() -> void:
	var vp      := get_viewport_rect()
	var smoke_w := vp.size.x * 0.187
	var smoke_h := vp.size.y * 0.22
	var sz      := Vector2(smoke_w, smoke_h)

	position        = Vector2(vp.size.x * 0.90, vp.size.y * 0.5)
	_sprite.texture = NINJA_FOOT1_TEX
	var tsz         := NINJA_FOOT1_TEX.get_size()
	var base_s      := Vector2(BOSS_ATCK_W / tsz.x, BOSS_ATCK_H / tsz.y)
	_sprite.scale   = Vector2.ZERO
	_sprite.flip_h  = false
	_sprite.visible = true

	var tw_in := create_tween()
	tw_in.tween_property(_sprite, "scale", base_s, 0.25).set_trans(Tween.TRANS_BACK)
	await tw_in.finished
	await get_tree().create_timer(0.2).timeout

	var center  := vp.size * 0.5
	var corners := [
		Vector2(smoke_w * 0.5,              smoke_h * 0.5),
		Vector2(vp.size.x - smoke_w * 0.5,  smoke_h * 0.5),
		Vector2(smoke_w * 0.5,              vp.size.y - smoke_h * 0.5),
		Vector2(vp.size.x - smoke_w * 0.5,  vp.size.y - smoke_h * 0.5),
	]
	var lifetime := 14.0

	# First throw: central projectile (awaited)
	await _fly_smoke_proj(global_position, center)

	# Burst: 4 corner projectiles from center simultaneously
	for c in corners:
		_launch_smoke_proj(center, c, sz, lifetime)

	await get_tree().create_timer(0.5).timeout

	var tw_fly := create_tween()
	tw_fly.tween_property(self, "position:y", -BOSS_ATCK_H * 2.0, 0.45) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw_fly.finished
	_sprite.visible = false
	position = Vector2(vp.size.x + BOSS_ATCK_W, vp.size.y * 0.5)

# Fly projectile to destination, await arrival — no smoke spawned
func _fly_smoke_proj(from_pos: Vector2, to_pos: Vector2) -> void:
	var proj := Node2D.new()
	_game_root.add_child(proj)
	proj.global_position = from_pos

	var spr := Sprite2D.new()
	spr.texture        = SMOKE_PROJ_TEX
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.scale          = Vector2.ONE * 0.20
	proj.add_child(spr)
	proj.add_child(_make_proj_trail())

	var dur := from_pos.distance_to(to_pos) / 550.0
	var tw  := proj.create_tween()
	tw.tween_property(proj, "global_position", to_pos, dur) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished
	proj.queue_free()

# Fire-and-forget: fly to corner, spawn smoke on arrival
func _launch_smoke_proj(from_pos: Vector2, to_pos: Vector2, smoke_sz: Vector2, lifetime: float) -> void:
	var proj := Node2D.new()
	_game_root.add_child(proj)
	proj.global_position = from_pos

	var spr := Sprite2D.new()
	spr.texture        = SMOKE_PROJ_TEX
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.scale          = Vector2.ONE * 0.20
	proj.add_child(spr)
	proj.add_child(_make_proj_trail())

	var dur := from_pos.distance_to(to_pos) / 550.0
	var tw  := proj.create_tween()
	tw.tween_property(proj, "global_position", to_pos, dur) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished

	proj.queue_free()
	_spawn_corner_smoke(to_pos, smoke_sz, lifetime)

func _spawn_corner_smoke(center: Vector2, sz: Vector2, lifetime: float) -> void:
	var node := Area2D.new()
	node.set_script(SMOKE_SCRIPT)
	node.collision_layer = 2
	node.collision_mask  = 0
	node.add_to_group("obstacle")
	node.z_index = 46

	var spr := Sprite2D.new()
	spr.texture        = SMOKE_TEX
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var tsz            := SMOKE_TEX.get_size()
	var base_scale     := Vector2(sz.x / tsz.x, sz.y / tsz.y)
	spr.scale  = base_scale
	spr.flip_v = bool(randi() % 2)
	node.add_child(spr)

	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = sz * 0.80
	cs.shape = rs
	node.add_child(cs)

	node.modulate.a = 0.0
	_game_root.add_child(node)
	node.global_position = center

	var tw_in := _game_root.create_tween()
	tw_in.tween_property(node, "modulate:a", 1.0, 0.40)

	var tw_pulse := _game_root.create_tween()
	tw_pulse.set_loops()
	tw_pulse.tween_property(spr, "scale", base_scale * 1.18, 0.5).set_trans(Tween.TRANS_SINE)
	tw_pulse.tween_property(spr, "scale", base_scale,        0.5).set_trans(Tween.TRANS_SINE)
	node.tree_exiting.connect(tw_pulse.kill)

	_schedule_smoke_flip(spr, lifetime)

	var tw_fade := _game_root.create_tween()
	tw_fade.tween_interval(lifetime - 0.8)
	tw_fade.tween_property(node, "modulate:a", 0.0, 0.80)
	tw_fade.tween_callback(node.queue_free)

func _schedule_smoke_flip(spr: Sprite2D, duration: float) -> void:
	var elapsed := 0.0
	while elapsed < duration:
		var wait := randf_range(0.5, 2.5)
		await get_tree().create_timer(wait).timeout
		elapsed += wait
		if not is_instance_valid(spr):
			return
		spr.flip_v = not spr.flip_v

# ── Defeat: Smoke Final ───────────────────────────────────────────────────────

func _smoke_final() -> void:
	var vp := get_viewport_rect()

	position        = Vector2(vp.size.x + BOSS_ATCK_W, vp.size.y * 0.5)
	_sprite.texture = NINJA_FOOT1_TEX
	var tsz         := NINJA_FOOT1_TEX.get_size()
	_sprite.scale   = Vector2(BOSS_ATCK_W / tsz.x, BOSS_ATCK_H / tsz.y)
	_sprite.flip_h  = false
	_sprite.visible = true

	var tw_in := create_tween()
	tw_in.tween_property(self, "position:x", vp.size.x * 0.90, 0.5) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	await tw_in.finished
	await get_tree().create_timer(0.35).timeout

	# Финальный дым летит в ЦЕНТР ЭКРАНА, а не в голову. Он накрывает всё поле
	# целиком, и уворачиваться от него нечем; брошенный в игрока, он читался как
	# прицельный удар, от которого просто нельзя уйти. Из центра то же облако
	# читается как «занавес», чем оно и является: это конец боя, а не атака.
	var norm_pos : Vector2 = vp.size * 0.5

	var proj := Node2D.new()
	_game_root.add_child(proj)
	proj.global_position = global_position

	var pspr := Sprite2D.new()
	pspr.texture        = SMOKE_PROJ_TEX
	pspr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pspr.scale          = Vector2.ONE * 0.15
	proj.add_child(pspr)
	proj.add_child(_make_proj_trail())

	var dur := proj.global_position.distance_to(norm_pos) / 550.0
	var tw_proj := proj.create_tween()
	tw_proj.tween_property(proj, "global_position", norm_pos, dur) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw_proj.finished
	proj.queue_free()

	_sprite.visible = false

	var smoke_node := Node2D.new()
	smoke_node.z_index = 60
	_game_root.add_child(smoke_node)
	smoke_node.global_position = norm_pos

	var sspr := Sprite2D.new()
	sspr.texture        = SMOKE_TEX
	sspr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var s_tsz   := SMOKE_TEX.get_size()
	var start_s := Vector2(vp.size.x * 0.25 / s_tsz.x, vp.size.y * 0.25 / s_tsz.y)
	var end_s   := Vector2(vp.size.x * 2.0  / s_tsz.x, vp.size.y * 2.0  / s_tsz.y)
	sspr.scale  = start_s
	smoke_node.add_child(sspr)
	smoke_node.modulate.a = 0.0

	var tw_expand := _game_root.create_tween()
	tw_expand.set_parallel(true)
	tw_expand.tween_property(smoke_node, "modulate:a", 1.0, 0.45)
	tw_expand.tween_property(sspr, "scale", end_s, 1.2) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tw_expand.finished

	await get_tree().create_timer(0.5).timeout

	var tw_fade := _game_root.create_tween()
	tw_fade.tween_property(smoke_node, "modulate:a", 0.0, 2.0)
	await tw_fade.finished
	smoke_node.queue_free()

func _make_proj_trail() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.emitting             = true
	p.amount               = 12
	p.lifetime             = 0.35
	p.explosiveness        = 0.0
	p.direction            = Vector2(0, -1)
	p.spread               = 60.0
	p.gravity              = Vector2.ZERO
	p.initial_velocity_min = 20.0
	p.initial_velocity_max = 55.0
	p.scale_amount_min     = 3.0
	p.scale_amount_max     = 8.0
	var g := Gradient.new()
	g.set_color(0, Color(0.72, 0.72, 0.72, 0.70))
	g.add_point(1.0, Color(0.40, 0.40, 0.40, 0.00))
	p.color_ramp = g
	return p

# ── Visual helpers ────────────────────────────────────────────────────────────

# Pre-fight monologue. A speech bubble pops above the boss with a taunt;
# Normaldo's input is frozen while the bubble is up so the player just
# reads it. Returns once the bubble has fully faded out.
func _show_intro_speech() -> void:
	if _normaldo != null and is_instance_valid(_normaldo) and _normaldo.has_method("disable_input"):
		_normaldo.disable_input()

	const SPEECH : String = "Босс уничтожит всю пиццу в городе.\nМожешь не пытаться его остановить, Нормальдо!"
	const BUBBLE_W : float = 320.0
	const BUBBLE_H : float = 96.0
	const HOLD     : float = 3.4   # seconds the bubble stays on screen
	# Margin between the bubble's right edge and the boss's left silhouette
	# edge so the cloud never overlaps the ninja's head.
	const BUBBLE_GAP : float = 28.0

	var cl := CanvasLayer.new()
	cl.layer = 95   # below the boss banner (which uses 99) but above gameplay
	_game_root.add_child(cl)

	var vp : Vector2 = get_viewport_rect().size
	# Place the bubble fully to the LEFT of the boss silhouette — boss centre
	# is at `position`, so its left edge is `position.x - BOSS_INTRO_W * 0.5`.
	# We clamp inside the viewport so a narrow window still works.
	var bx : float = clampf(position.x - BOSS_INTRO_W * 0.5 - BUBBLE_GAP - BUBBLE_W,
		12.0, vp.x - BUBBLE_W - 12.0)
	var by : float = clampf(position.y - BUBBLE_H * 0.5 - 90.0, 12.0, vp.y - BUBBLE_H - 12.0)

	var root := Control.new()
	root.size         = Vector2(BUBBLE_W, BUBBLE_H)
	root.position     = Vector2(bx, by)
	root.pivot_offset = root.size * 0.5
	root.scale        = Vector2(0.6, 0.6)
	root.modulate     = Color(1.0, 1.0, 1.0, 0.0)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(root)

	var bg := ColorRect.new()
	bg.color    = Color(0.96, 0.96, 0.98, 0.97)
	bg.size     = Vector2(BUBBLE_W, BUBBLE_H)
	bg.position = Vector2.ZERO
	root.add_child(bg)

	var stripe := ColorRect.new()
	stripe.color    = Color(0.20, 0.05, 0.05, 0.85)
	stripe.size     = Vector2(BUBBLE_W, 3.0)
	stripe.position = Vector2.ZERO
	root.add_child(stripe)

	# Tail pointing toward the boss head (right side).
	var tail := ColorRect.new()
	tail.color    = bg.color
	tail.size     = Vector2(22.0, 16.0)
	tail.position = Vector2(BUBBLE_W - 36.0, BUBBLE_H - 6.0)
	tail.rotation = -0.30
	root.add_child(tail)

	var msg := Label.new()
	msg.add_theme_font_override("font", UI_FONT)
	msg.add_theme_font_size_override("font_size", 13)
	msg.add_theme_color_override("font_color", Color(0.10, 0.06, 0.10))
	msg.text                 = SPEECH
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	msg.autowrap_mode        = TextServer.AUTOWRAP_WORD_SMART
	msg.size                 = Vector2(BUBBLE_W - 20.0, BUBBLE_H - 20.0)
	msg.position             = Vector2(10.0, 10.0)
	root.add_child(msg)

	# Pop in.
	var tw_in := create_tween().set_parallel(true)
	tw_in.tween_property(root, "modulate:a", 1.0, 0.18)
	tw_in.tween_property(root, "scale", Vector2.ONE, 0.26)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tw_in.finished

	# Hold for read time.
	await get_tree().create_timer(HOLD).timeout

	# Pop out.
	var tw_out := create_tween().set_parallel(true)
	tw_out.tween_property(root, "modulate:a", 0.0, 0.22)
	tw_out.tween_property(root, "scale", Vector2(0.6, 0.6), 0.22)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tw_out.finished
	cl.queue_free()

	# Hand control back to the player. Boss continues to its banner +
	# attack phases right after this call returns.
	if _normaldo != null and is_instance_valid(_normaldo) and _normaldo.has_method("enable_input"):
		_normaldo.enable_input()

func _show_boss_banner() -> void:
	var vp := get_viewport_rect()

	var cl := CanvasLayer.new()
	cl.layer = 99
	_game_root.add_child(cl)

	var overlay := ColorRect.new()
	overlay.color = Color(0.04, 0.0, 0.08, 0.0)
	overlay.size  = vp.size
	cl.add_child(overlay)

	# Титр НАРИСОВАННЫЙ, как у крокодила и хозяина клуба: «BOSS FIGHT» с мордой
	# босса вместо буквы O. У боссов один титр на всех, и меняется в нём только
	# лицо; набранное шрифтом «БОСС ФАЙТ», которое стояло тут раньше, выпадало
	# из этого ряда — у двоих рисунок, у третьего надпись.
	#
	# Лист собран из авторского `BOSSFIGHT LH.png`: то же кольцо, те же шипы, в
	# круг вставлена голова ноги ниндзя (dev/tools/bake_ninja_banner.py).
	var lbl := TextureRect.new()
	lbl.texture        = BANNER_TEX
	lbl.expand_mode    = TextureRect.EXPAND_IGNORE_SIZE
	lbl.stretch_mode   = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	lbl.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var bw : float = vp.size.x * 0.56
	var bh : float = bw * float(BANNER_TEX.get_height()) / float(BANNER_TEX.get_width())
	lbl.size         = Vector2(bw, bh)
	lbl.position     = Vector2((vp.size.x - bw) * 0.5, vp.size.y * 0.22)
	lbl.pivot_offset = lbl.size * 0.5
	lbl.scale        = Vector2.ZERO
	cl.add_child(lbl)

	var sub := Label.new()
	sub.add_theme_font_override("font", UI_FONT)
	sub.add_theme_font_size_override("font_size", 22)
	sub.text                 = "НОГА НИНДЗЯ"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.modulate             = Color(0.95, 0.75, 0.10, 0.0)
	sub.size                 = Vector2(vp.size.x, 36)
	sub.position             = Vector2(0, vp.size.y * 0.22 + bh + 6.0)
	cl.add_child(sub)

	var tw_ov := overlay.create_tween()
	tw_ov.tween_property(overlay, "color:a", 0.65, 0.28)
	await tw_ov.finished

	_play_sfx(BOSS_STINGER)

	var tw_l := lbl.create_tween()
	tw_l.tween_property(lbl, "scale", Vector2.ONE, 0.28) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tw_l.finished

	_screen_shake(10.0, 8)

	var tw_s := sub.create_tween()
	tw_s.tween_property(sub, "modulate:a", 1.0, 0.22)
	await tw_s.finished

	await get_tree().create_timer(0.65).timeout

	# Pulse
	var tw_p := lbl.create_tween()
	for _i in 2:
		tw_p.tween_property(lbl, "scale", Vector2(0.94, 0.94), 0.12)
		tw_p.tween_property(lbl, "scale", Vector2.ONE, 0.12)
	await tw_p.finished

	await get_tree().create_timer(0.35).timeout

	var tw_out := cl.create_tween()
	tw_out.set_parallel(true)
	tw_out.tween_property(overlay, "color:a", 0.0, 0.42)
	tw_out.tween_property(lbl,     "modulate:a", 0.0, 0.38)
	tw_out.tween_property(sub,     "modulate:a", 0.0, 0.38)
	await tw_out.finished
	cl.queue_free()

func _screen_shake(amp: float, count: int) -> void:
	if not is_instance_valid(_game_root):
		return
	var tw := _game_root.create_tween()
	var a  := amp
	for _i in count:
		tw.tween_property(_game_root, "position",
			Vector2(randf_range(-a, a), randf_range(-a * 0.65, a * 0.65)), 0.033)
		a *= 0.80
	tw.tween_property(_game_root, "position", Vector2.ZERO, 0.05)

func _screen_flash(color: Color) -> void:
	var fl := CanvasLayer.new()
	fl.layer = 97
	_game_root.add_child(fl)
	var cr := ColorRect.new()
	cr.color = color
	cr.size  = get_viewport_rect().size
	fl.add_child(cr)
	var tw := cr.create_tween()
	tw.tween_interval(0.10)
	tw.tween_property(cr, "color:a", 0.0, 0.60)
	tw.tween_callback(fl.queue_free)

func _spawn_slide_particles() -> void:
	var p                    := CPUParticles2D.new()
	p.emitting                = true
	p.one_shot                = true
	p.amount                  = 40
	p.lifetime                = 0.85
	p.explosiveness           = 0.65
	p.direction               = Vector2(-1, 0)
	p.spread                  = 38.0
	p.gravity                 = Vector2(0, 90)
	p.initial_velocity_min    = 110.0
	p.initial_velocity_max    = 230.0
	p.scale_amount_min        = 4.0
	p.scale_amount_max        = 11.0
	var g                    := Gradient.new()
	g.set_color(0, Color(0.60, 0.38, 0.92, 0.90))
	g.add_point(0.45, Color(0.28, 0.10, 0.60, 0.55))
	g.add_point(1.0,  Color(0.10, 0.00, 0.22, 0.00))
	p.color_ramp              = g
	_game_root.add_child(p)
	p.global_position = Vector2(get_viewport_rect().size.x + 30.0,
								get_viewport_rect().size.y * 0.5)
	p.finished.connect(p.queue_free)

func _impact_burst() -> void:
	var p                    := CPUParticles2D.new()
	p.one_shot                = true
	p.emitting                = true
	p.amount                  = 55
	p.lifetime                = 0.72
	p.explosiveness           = 1.0
	p.direction               = Vector2(-1, 0)
	p.spread                  = 95.0
	p.gravity                 = Vector2(0, 130)
	p.initial_velocity_min    = 150.0
	p.initial_velocity_max    = 340.0
	p.scale_amount_min        = 6.0
	p.scale_amount_max        = 20.0
	var g                    := Gradient.new()
	g.set_color(0, Color(0.92, 0.70, 1.00, 1.00))
	g.add_point(0.28, Color(0.60, 0.20, 0.90, 0.85))
	g.add_point(0.65, Color(0.28, 0.02, 0.52, 0.55))
	g.add_point(1.0,  Color(0.08, 0.00, 0.18, 0.00))
	p.color_ramp              = g
	_game_root.add_child(p)
	p.global_position         = global_position
	p.finished.connect(p.queue_free)

func _spawn_victory_burst() -> void:
	var vp := get_viewport_rect()
	for i in 6:
		var p                    := CPUParticles2D.new()
		p.one_shot                = true
		p.emitting                = true
		p.amount                  = 32
		p.lifetime                = 1.3
		p.explosiveness           = 0.90
		p.spread                  = 180.0
		p.gravity                 = Vector2(0, -85)
		p.initial_velocity_min    = 90.0
		p.initial_velocity_max    = 270.0
		p.scale_amount_min        = 5.0
		p.scale_amount_max        = 13.0
		var g                    := Gradient.new()
		g.set_color(0, Color(1.0, 0.92, 0.28, 1.0))
		g.add_point(0.38, Color(0.28, 0.85, 0.28, 0.90))
		g.add_point(1.0,  Color(0.08, 0.38, 0.08, 0.00))
		p.color_ramp              = g
		_game_root.add_child(p)
		p.global_position = Vector2(
			vp.size.x * (0.08 + i * 0.17),
			vp.size.y * randf_range(0.30, 0.70)
		)
		p.finished.connect(p.queue_free)

# ── Utility ───────────────────────────────────────────────────────────────────

func _random_offscreen_pos(vp: Rect2) -> Vector2:
	var mw := BOSS_ATCK_W + 20.0
	var mh := BOSS_ATCK_H + 20.0
	match randi() % 4:
		0: return Vector2(randf_range(0.0, vp.size.x), -mh)
		1: return Vector2(randf_range(0.0, vp.size.x), vp.size.y + mh)
		2: return Vector2(-mw, randf_range(0.0, vp.size.y))
		_: return Vector2(vp.size.x + mw, randf_range(0.0, vp.size.y))

func _corner_positions(vp: Rect2, w: float = BOSS_ATCK_W, h: float = BOSS_ATCK_H) -> Array:
	var hw := w * 0.5
	var hh := h * 0.5
	return [
		Vector2(hw + 12.0,             hh + 12.0),
		Vector2(vp.size.x - hw - 12.0, hh + 12.0),
		Vector2(hw + 12.0,             vp.size.y - hh - 12.0),
		Vector2(vp.size.x - hw - 12.0, vp.size.y - hh - 12.0),
	]

func _clear_spawner_items() -> void:
	# Full wipe + freeze: kills every spawner child (items, molotov warning
	# ovals, glove charge bars, particles, …) and flips the spawner's
	# _frozen flag so in-flight pattern coroutines bail before spawning more
	# obstacles after the wipe. Test-mode resume below clears _frozen.
	if not is_instance_valid(_spawner):
		return
	if _spawner.has_method("clear_items"):
		_spawner.clear_items()
	else:
		for child in _spawner.get_children():
			if is_instance_valid(child):
				child.queue_free()

func _play_sfx(stream: AudioStream) -> void:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	_game_root.add_child(player)
	player.play()
	player.finished.connect(player.queue_free)
