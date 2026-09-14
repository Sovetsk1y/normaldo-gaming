extends Area2D

# ── ОДИН УДАР, ДВЕ ПОРОДЫ ───────────────────────────────────────────────────
# Влетел справа, встал у края, зарядился под красной полосой, ударил по линии
# через весь экран. Это не «перчатка», это ПРИЁМ — и на уровнях, где по
# раскладке водятся собаки, тот же приём делает собака.
#
# ── ПОЧЕМУ НЕ ВТОРОЙ СКРИПТ ────────────────────────────────────────────────
# Потому что это тот же приём, и всё, что в нём есть, — три фазы, телеграф,
# сроки зарядки, вынос предметов на пути, — обязано вести себя ОДИНАКОВО.
# Скопируй машину фаз во второй файл, и она немедленно начнёт расходиться:
# правку сроков зарядки под новую фазу внесут в один, телеграф подкрутят в
# другом, и через месяц собака будет бить не так, как перчатка, без единого
# решения об этом.
#
# Поэтому разница живёт РОВНО ТАМ, ГДЕ ОНА ЕСТЬ: картинка, звук, цвет искр и
# группа (от неё зависит, чей резист скина сработает). Всё остальное общее.
enum Breed { GLOVE, DOG }

const TEX_GLOVE := preload("res://assets/items/boxing_glove.png")
const TEX_DOG   := preload("res://assets/items/angry_dog.png")

const HIT_SOUND := preload("res://assets/audio/boxing_glove.mp3")
const SFX_BARK  := preload("res://assets/audio/dog.mp3")

# Кто именно летит. Ставится спавнером ДО добавления в дерево — `_ready`
# собирает по нему внешность.
@export var breed : Breed = Breed.GLOVE

# Масштаб картинки. У перчатки он исторически лежит в сцене, у собаки взят
# ТОТ ЖЕ, что у неё в потоке (dog.gd): одна и та же тварь обязана быть одного
# размера, летит она по линии или плывёт в потоке.
const DOG_SCALE : float = 0.20
# Хитбокс. У перчатки круг 22, у собаки чуть шире — она и нарисована крупнее
# (74×71 против 56×35).
const R_GLOVE : float = 22.0
const R_DOG   : float = 26.0

# ── ЦВЕТ ИСКР ГОВОРИТ, КТО ЛЕТИТ ───────────────────────────────────────────
# У перчатки выхлоп рыжий, а зарядка жёлтая — это пружина и разряд. У собаки
# из-под лап идёт ПЫЛЬ (бурая, а не рыжая: она бежит по земле, а не работает
# на тяге), а копит она не заряд, а злость — красным.
const EXHAUST_GLOVE : Color = Color(1.00, 0.50, 0.05, 0.90)
const EXHAUST_DOG   : Color = Color(0.62, 0.48, 0.34, 0.85)
const CHARGE_GLOVE  : Color = Color(1.00, 0.90, 0.20, 0.95)
const CHARGE_DOG    : Color = Color(1.00, 0.25, 0.12, 0.95)

@export var speed : float = 300.0

enum Phase { ENTERING, CHARGING, PUNCHING }

const ENTER_STOP_MARGIN := 38.0   # px от правого края экрана при зарядке
# Default charge duration — used when the spawner doesn't override it (boss
# attacks, dev hotkeys, etc). For phase-driven scaling the spawner sets
# `charge_duration` per glove before adding it to the scene.
const CHARGE_DURATION_DEFAULT := 0.30
const PUNCH_SPEED             := 1500.0

@export var charge_duration : float = CHARGE_DURATION_DEFAULT
# Telegraph bar mirrors the molotov warning oval: shows the lane the punch
# will sweep and how soon. Grows leftward from the glove during CHARGING and
# fades out the instant the punch fires.
const WARN_BAR_HEIGHT   := 30.0
const WARN_BAR_FADE     := 0.12

var _phase       : Phase  = Phase.ENTERING
var _phase_timer : float  = 0.0
var _vp_w        : float  = 0.0
var _base_scale  : Vector2
# Public horizontal velocity (px/sec). Background decor (lamps) read this to
# pick a swing direction when the glove brushes past them.
var velocity_x   : float  = 0.0
var _prev_x      : float  = 0.0

var _exhaust     : CPUParticles2D
var _charge_vfx  : CPUParticles2D
var _audio       : AudioStreamPlayer
var _warn_bar  : Node2D = null
var _warn_fill : ColorRect = null

# Как это называть в аналитике (читает normaldo._cause_name). Сцена у обеих
# пород одна, и без этого поля смерть от собаки попадала бы в отчёт перчаткой.
var cause_name : String = ""

func _ready() -> void:
	_vp_w = get_viewport_rect().size.x

	var dog := breed == Breed.DOG
	cause_name = "charging_dog" if dog else "boxing_glove"
	if dog:
		$Sprite2D.texture = TEX_DOG
		$Sprite2D.scale   = Vector2.ONE * DOG_SCALE
	_base_scale = $Sprite2D.scale

	var circle    := CircleShape2D.new()
	circle.radius  = R_DOG if dog else R_GLOVE
	$CollisionShape2D.shape = circle
	add_to_group("obstacle")
	# ── ГРУППА РЕШАЕТ, ЧЕЙ РЕЗИСТ СРАБОТАЕТ ────────────────────────────────
	# `normaldo._area_tag` читает группу, и по ней ищет иммунитет скина. Собака
	# в группе "glove" означала бы, что от неё защищает «иммунитет к перчатке»,
	# — а от неё обязан защищать иммунитет к СОБАКЕ, он для того и есть.
	add_to_group("dog" if dog else "glove")
	monitoring     = false   # включится только на фазе удара

	_exhaust = _make_exhaust()
	add_child(_exhaust)

	_charge_vfx = _make_charge_vfx()
	add_child(_charge_vfx)

	_audio = AudioStreamPlayer.new()
	_audio.stream    = SFX_BARK if dog else HIT_SOUND
	_audio.volume_db = -2.0
	add_child(_audio)
	_audio.play()  # звук ринга (лай) при появлении

	area_entered.connect(_on_punch_area_entered)

func _process(delta: float) -> void:
	_phase_timer += delta
	var prev_x := position.x
	match _phase:
		Phase.ENTERING:  _do_entering(delta)
		Phase.CHARGING:  _do_charging()
		Phase.PUNCHING:  _do_punching(delta)
	if delta > 0.0:
		velocity_x = (position.x - prev_x) / delta
	_prev_x = position.x

# ── Фаза 1: влетает справа и останавливается у края ──────────────────────────

func _do_entering(delta: float) -> void:
	var target_x := _vp_w - ENTER_STOP_MARGIN
	position.x    = move_toward(position.x, target_x, speed * 2.0 * delta)
	$Sprite2D.rotation = sin(_phase_timer * 5.0) * 0.18
	if position.x <= target_x + 0.5:
		_begin_charge()

# ── Фаза 2: зарядка ──────────────────────────────────────────────────────────

func _begin_charge() -> void:
	_phase       = Phase.CHARGING
	_phase_timer = 0.0
	_charge_vfx.emitting = true
	_exhaust.amount      = 20

	# Quick wind-up scaled to fit inside charge_duration so the squash pulse
	# resolves right as the punch fires regardless of phase pacing.
	var pulse_t : float = maxf(0.05, charge_duration * 0.5)
	var tw := create_tween()
	tw.tween_property($Sprite2D, "scale", _base_scale * 1.20, pulse_t) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property($Sprite2D, "scale", _base_scale,        pulse_t) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	_spawn_warn_bar()

func _do_charging() -> void:
	$Sprite2D.rotation = sin(_phase_timer * 10.0) * 0.04  # мелкая вибрация
	if _phase_timer >= charge_duration:
		_begin_punch()

# ── Фаза 3: удар через весь экран ────────────────────────────────────────────

func _begin_punch() -> void:
	_phase       = Phase.PUNCHING
	_phase_timer = 0.0
	monitoring      = true
	collision_mask  = 2          # детектируем предметы (layer 2)
	_charge_vfx.emitting = false
	_exhaust.amount      = 28

	_fade_warn_bar()

	# ── СОБАКА СРЫВАЕТСЯ С ЛАЕМ ────────────────────────────────────────────
	# У перчатки момент удара МОЛЧИТ, и это верно: пружина своё уже прозвенела
	# на влёте, а второй звонок на рывке слился бы с первым в дребезг. Собака же,
	# уходящая в бросок беззвучно, читается как картинка, которую подвинули.
	#
	# Тон выше первого лая — чтобы второй лай был вторым, а не эхом; и он же
	# остаётся на удар по игроку: собака, которая уже сорвалась, спокойным
	# голосом не лает.
	if breed == Breed.DOG:
		_audio.pitch_scale = 1.18
		_audio.play()

	# squash-and-stretch — рывок вперёд
	var tw := create_tween()
	tw.tween_property($Sprite2D, "scale", _base_scale * Vector2(0.65, 1.35), 0.05) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property($Sprite2D, "scale", _base_scale * Vector2(1.35, 0.75), 0.07) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property($Sprite2D, "scale", _base_scale,                        0.18) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func _do_punching(delta: float) -> void:
	position.x         -= PUNCH_SPEED * delta
	$Sprite2D.rotation  = 0.0
	if position.x < -200.0:
		queue_free()

# ── Вызывается normaldo при попадании ────────────────────────────────────────

func on_hit() -> void:
	_audio.play()
	# Перчатка продолжает лететь — не останавливается

# ── Сносим всё на пути во время удара ────────────────────────────────────────

func _on_punch_area_entered(area: Area2D) -> void:
	if not is_instance_valid(area) or area == self:
		return
	if area.has_method("explode"):
		area.explode()
	else:
		area.queue_free()

# ── Частицы ──────────────────────────────────────────────────────────────────

func _make_exhaust() -> CPUParticles2D:
	var p                  := CPUParticles2D.new()
	p.position              = Vector2(15.0, 0.0)
	p.emitting              = true
	p.amount                = 10
	p.lifetime              = 0.20
	p.explosiveness         = 0.0
	p.direction             = Vector2(1, 0)
	p.spread                = 20.0
	p.gravity               = Vector2.ZERO
	p.initial_velocity_min  = 45.0
	p.initial_velocity_max  = 85.0
	p.scale_amount_min      = 1.5
	p.scale_amount_max      = 3.2
	p.color                 = EXHAUST_DOG if breed == Breed.DOG else EXHAUST_GLOVE
	p.emission_shape        = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(1.0, 4.0)
	return p

# ── Telegraph bar ─────────────────────────────────────────────────────────────

func _spawn_warn_bar() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var vp_w := get_viewport_rect().size.x
	_warn_bar          = Node2D.new()
	_warn_bar.position = Vector2(0.0, position.y)
	# Above the background (z=-1) and items (z=0), below Normaldo (z=3).
	_warn_bar.z_index  = 1
	parent.add_child(_warn_bar)

	# Bar spans the full screen along the punch line and grows in height
	# (0 → WARN_BAR_HEIGHT), centered on the lane Y. Single flat fill in the
	# molotov landing-zone red so the two telegraphs read as one language.
	_warn_fill        = ColorRect.new()
	_warn_fill.color  = Color(1.00, 0.10, 0.05, 0.38)
	_warn_fill.size   = Vector2(vp_w, 0.0)
	_warn_fill.position = Vector2(0.0, 0.0)
	_warn_bar.add_child(_warn_fill)

	var tw := _warn_bar.create_tween().set_parallel(true)
	tw.tween_property(_warn_fill, "size:y",     WARN_BAR_HEIGHT,        charge_duration)
	tw.tween_property(_warn_fill, "position:y", -WARN_BAR_HEIGHT * 0.5, charge_duration)

func _fade_warn_bar() -> void:
	if not is_instance_valid(_warn_bar):
		return
	var bar := _warn_bar
	_warn_bar  = null
	_warn_fill = null
	var tw := bar.create_tween()
	tw.tween_property(bar, "modulate:a", 0.0, WARN_BAR_FADE)
	tw.tween_callback(bar.queue_free)

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if is_instance_valid(_warn_bar):
			_warn_bar.queue_free()
			_warn_bar = null

func _make_charge_vfx() -> CPUParticles2D:
	var p                   := CPUParticles2D.new()
	p.position               = Vector2(0.0, 0.0)
	p.emitting               = false
	p.amount                 = 28
	p.lifetime               = 0.32
	p.explosiveness          = 0.05
	p.direction              = Vector2(-1, 0)
	p.spread                 = 65.0
	p.gravity                = Vector2.ZERO
	p.initial_velocity_min   = 18.0
	p.initial_velocity_max   = 55.0
	p.scale_amount_min       = 2.0
	p.scale_amount_max       = 5.5
	p.color                  = CHARGE_DOG if breed == Breed.DOG else CHARGE_GLOVE
	p.emission_shape         = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 14.0
	return p
