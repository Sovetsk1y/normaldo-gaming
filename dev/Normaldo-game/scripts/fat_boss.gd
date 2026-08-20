extends Node2D

# ── ЖИРОБОСС mini-game controller ─────────────────────────────────────────────
# Child of the Game root. Watches the active run and periodically sends in a
# lone blinking mutagen that freezes the world. When Normaldo eats it, the
# mini-game runs:
#
#   Phase A (GROW): Normaldo is parked left-of-centre, made invincible, control
#       off, and balloons to ×8 in 3 earthquake steps (camera shake + ceiling
#       debris + sfx hooks). Speech bubbles "Я ЧУВСТВУЮ..." → "ЖИИИРРР!!!", a
#       "ЖИРОБОСС" title card drops in, and the music crossfades to hard_track.
#       A blinking "ТАПАЙ" title (finger on each side) cues the tapping — it
#       shows while idle and hides while the player is tapping.
#
#   Phase B (PLAY): ЖИР — одна величина, которая управляет всем. Не тапаешь —
#       жир стекает, голова СДУВАЕТСЯ на глазах и поток вянет. Тапаешь — жир
#       держится (остаёшься огромным) и поток разгоняется. Мини-игра кончается,
#       когда жир дошёл до нуля; фиксированного таймера нет. Отдача от тапа
#       падает с ростом жира, а слив растёт со временем — поэтому она всегда
#       заканчивается. Пока большой, Нормальдо неуязвим и жрёт лут; на выходе
#       возвращаются управление, урон, музыка и спавнер.
#
# SFX: players are created with no stream and marked `# SFX:` — drop audio onto
# them later and they'll fire at the right beat.

const MUTAGEN_SCENE  := preload("res://scenes/mutagen.tscn")
const ITEM_SCENE     := preload("res://scenes/item.tscn")
const HOMELESS_SCENE := preload("res://scenes/homeless.tscn")
const DOG_SCENE      := preload("res://scenes/dog.tscn")

const PIZZA_TEX  := preload("res://assets/items/pizza.png")
const DOLLAR_TEX := preload("res://assets/items/dollar.png")
const TRASH_TEX  := preload("res://assets/items/trash_bin.png")
const HARD_TRACK  := preload("res://assets/audio/hard_track.mp3")
const CRASH_SFX   := preload("res://assets/audio/crash.mp3")
const FIRECRACKER := preload("res://assets/audio/firecracker.mp3")
const UI_FONT    := preload("res://assets/fonts/RussoOne-Regular.ttf")
const FINGER_TEX := preload("res://assets/ui/quests/back_arrow.png")
const SLAKE_TEX  := preload("res://assets/normaldo/slakebake.png")   # parting "slake bake" stamp

# ── Tunables (designer-facing) ────────────────────────────────────────────────
@export var enabled         : bool  = true
# Мутаген — УЛЬТРА-РЕДКИЙ предмет: пролетает нечасто (примерно раз в ~2 мин).
# Гейт см. /Концепция/Эпизод 1 — прогрессия предметов (редизайн).md
@export var first_delay     : float = 55.0   # run grace before mutagens can appear
@export var repeat_interval : float = 110.0  # long cooldown — редко
# Per-frame chance to send a lone mutagen flying across (only while none is on
# screen and we're idle). It flies like any item; catching it triggers ЖИРОБОСС.
@export var mutagen_chance  : float = 0.0022

# Growth — ×2, ×2, then ×3 → ×12 (way taller than the screen).
# Ступени раздувания — ДОЛИ от финального множителя, а не абсолютные числа:
# сам множитель теперь свой у каждого скина и состояния жира.
const GROW_STEPS  : Array[float] = [0.17, 0.34, 1.0]
# Per-step tilt (degrees): jerk left, then right, … ending dead straight at the
# max-fat step so he stands normally for the tap phase.
const GROW_ANGLES_DEG : Array[float] = [-30.0, 15.0, 0.0]
const GROW_STEP_T : float = 0.45             # tween time per step
const GROW_HOLD_T : float = 0.40             # tremble pause between steps
# Высота нарисованной головы на пике, в долях высоты экрана. Чуть больше
# единицы: лицо должно упираться в верх и низ кадра, но остаться лицом.
const BOSS_FACE_H : float = 1.05

# ── Фаза Б: ЖИР — одна величина на всё ───────────────────────────────────────
# `_bar` (0..1) — это ЖИР, и он же управляет всем:
#   • размером головы на экране: не тапаешь — сдуваешься на глазах;
#   • скоростью потока предметов: тапаешь — поток разгоняется.
# Мини-игра кончается, когда жир дошёл до нуля. Таймера нет: длительность —
# следствие того, как игрок тапает. См. /Концепция/Мини-игра — Жиробосс (мутаген).md
const BAR_START     : float = 1.0            # мутаген взят — ты СРАЗУ огромный
# Пол размера: даже на нуле жира голова заметно больше обычной, иначе последние
# секунды босс уже не босс, а предметы летят сквозь маленькую голову.
const FAT_FLOOR     : float = 0.40
# Слив растёт с набранным жиром (квадратично) и со временем в мини-игре. База
# небольшая: у самого низа сдувание замедляется, и концовка не обрывается.
const BAR_DECAY     : float = 0.10
const BAR_DECAY_RAMP: float = 0.42
const BAR_TAP_GAIN  : float = 0.075          # прибавка за тап у пустой полосы
# Отдача от тапа падает по мере набора: у полного жира тап даёт вчетверо меньше.
# Без этого мэшер держал бы максимум бесконечно.
const BAR_TAP_FALLOFF : float = 0.25
# Со временем слив нарастает, А ОТДАЧА ОТ ТАПА ПАДАЕТ — Нормальдо выдыхается.
# Второе обязательно: одного нарастающего слива мало. Пока тап у пустой полосы
# даёт больше, чем стекает у самого дна, у мэшера есть равновесие выше нуля, и
# мини-игра не кончается ВООБЩЕ — при 14 тапах в секунду она честно висела 40
# секунд, пока в неё не упёрся тест.
const DECAY_GRACE     : float = 5.0
const DECAY_RAMP_T    : float = 12.0
# ×3 не хватало: при 14 тапах в секунду слив и прибавка сходились на середине
# полосы, и мини-игра не кончалась вовсе. ×6 перекрывает любой человеческий темп.
const DECAY_TIME_MULT : float = 6.0
const TAP_STAMINA_MIN : float = 0.25         # во что вырождается отдача от тапа
# Аварийный потолок: даже при полностью сломанной математике игрок не должен
# застрять в мини-игре навсегда.
const FRENZY_HARD_CAP : float = 45.0

# Phase-B item speed, as a multiple of the run phase's base speed. SLOW is well
# below 1.0 so the very first taps read as a clear, immediate acceleration.
const ITEM_SPEED_FAST   : float = 2.8        # at bar = 1.0 (madness — very fast)
const ITEM_SPEED_SLOW   : float = 0.40       # at bar = 0.0 (crawling trickle)
const MG_SPAWN_INTERVAL : float = 0.20       # denser stream of incoming items

# Invisible 3-stage split by bar level, with hysteresis so it doesn't chatter at
# a boundary: 0 спокойно · 1 средняя (экран танцует) · 2 безумие (диско-свет +
# очень быстро). Each stage also fires a music hook (see _set_stage).
const STAGE_MID_UP : float = 0.45
const STAGE_MID_DN : float = 0.38
const STAGE_MAD_UP : float = 0.82
const STAGE_MAD_DN : float = 0.74
const DANCE_AMP_MID : float = 6.0            # camera sway amplitude, stage 1
const DANCE_AMP_MAD : float = 16.0           # camera sway amplitude, stage 2
# The shake would expose the top/bottom edges of the wall (the city layer bleeds
# through). A slight zoom-IN scaled with the sway amplitude overscans those edges
# out of view (and adds punch). 0.006·amp ⇒ ~×1.1 at full madness.
const ZOOM_PER_AMP  : float = 0.006

# Deflation at the end: he sags back to normal size over this long instead of
# snapping, then puffs out the parting speech bubble.
const DEFLATE_T : float = 0.6

const PROMPT_REAPPEAR : float = 0.55         # idle gap before the tap-prompt returns

# Speed-bar HUD geometry.
const BAR_W : float = 300.0
const BAR_H : float = 20.0

enum State { IDLE, GROW, PLAY, OUTRO }
var _state    : int   = State.IDLE
var _arm_timer: float = 0.0

var _bar       : float = 0.0      # ЖИР 0..1: и размер головы, и скорость потока
var _frenzy_t  : float = 0.0      # аварийный потолок длительности
var _play_time : float = 0.0      # время в фазе Б — по нему нарастает слив
var _max_factor : float = 12.0    # пик размера, считается под скин в _refresh_max_factor
var _pre_boss_pos : Vector2 = Vector2.ZERO   # куда вернуть голову после мини-игры
var _pizza_got : int   = 0        # loot tallied this mini-game (credited at the end)
var _dollar_got: int   = 0
var _breathe_t : float = 0.0      # phase accumulator for the idle size-breathing
var _stage     : int   = 0        # 0 calm · 1 mid (screen dances) · 2 madness (disco)
var _fx_t      : float = 0.0       # stage-fx time accumulator (sway/strobe)
var _dance_amp : float = 0.0       # smoothed camera-sway amplitude
var _disco_hue : float = 0.0       # cycling hue for the madness light wash
var _disco_a   : float = 0.0       # smoothed disco alpha
var _mg_timer : float = 0.0
var _base_item_speed : float = 330.0
var _last_tap_msec   : int   = 0
var _tap_pulse    : float = 0.0   # transient impact wobble on tap (decays, NOT growth)
var _tap_rot      : float = 0.0   # transient CW/CCW jerk on tap (decays)
var _prompt_shown : bool  = false
var _event_frozen : bool  = false # run frozen for the current mutagen event

var _mutagen  : Node2D = null
var _mg_items : Array[Node] = []

# Overlay / fx nodes (created lazily)
var _ui         : CanvasLayer = null
var _title_root : Node2D = null   # holds the title label + its two fingers
var _title_tw   : Tween = null
var _shake_cam  : Camera2D = null
var _debris    : CPUParticles2D = null
var _disco      : ColorRect = null   # full-screen additive light wash at madness

# Phase-B HUD: the speed bar + the live pizza/dollar tally beneath it.
var _bar_root        : Control = null
var _bar_fill        : ColorRect = null
var _bar_mult_lbl    : Label = null
var _pizza_count_lbl : Label = null
var _dollar_count_lbl: Label = null
var _pizza_count_icon : TextureRect = null   # fly-from origin for the end transfer
var _dollar_count_icon: TextureRect = null

var _orig_music_stream : AudioStream = null

# SFX
var _sfx_quake : AudioStreamPlayer = null   # SFX: heavy earthquake rumble (none yet)
var _sfx_grow  : AudioStreamPlayer = null   # crash.mp3 — the inflate hit per grow step
var _tap_player : AudioStreamPlayer = null  # tap.mp3 — each tap on Normaldo (if present)
var _tap_burst  : CPUParticles2D = null     # green particle puff on each tap

@onready var _normaldo   = get_parent().get_node_or_null("Normaldo")
@onready var _spawner    = get_parent().get_node_or_null("Spawner")
@onready var _background  = get_parent().get_node_or_null("Background")
@onready var _music       = get_parent().get_node_or_null("Music")
@onready var _pizzaparty   = get_parent().get_node_or_null("PizzaParty")
@onready var _slotsgame    = get_parent().get_node_or_null("SlotsGame")

func _ready() -> void:
	_arm_timer = first_delay
	if is_instance_valid(_normaldo) and _normaldo.has_signal("mutagen_caught"):
		_normaldo.mutagen_caught.connect(_on_mutagen_caught)
	if is_instance_valid(_normaldo) and _normaldo.has_signal("fat_boss_loot_collected"):
		_normaldo.fat_boss_loot_collected.connect(_on_loot_collected)

	_ui = CanvasLayer.new()
	_ui.layer = 50
	add_child(_ui)

	_sfx_quake = AudioStreamPlayer.new()
	_sfx_quake.volume_db = -2.0
	add_child(_sfx_quake)
	_sfx_grow = AudioStreamPlayer.new()
	_sfx_grow.stream    = CRASH_SFX
	_sfx_grow.volume_db = -2.0
	add_child(_sfx_grow)

	# tap.mp3 may not be in the project yet — load it safely if it's there.
	_tap_player = AudioStreamPlayer.new()
	_tap_player.volume_db = -2.0
	add_child(_tap_player)
	if ResourceLoader.exists("res://assets/audio/tap.mp3"):
		_tap_player.stream = load("res://assets/audio/tap.mp3")

# ── Trigger loop ──────────────────────────────────────────────────────────────

# True while a mutagen is flying OR a mini-game is running — used by the pizza
# mini-game so the two never overlap.
func is_busy() -> bool:
	return _state != State.IDLE or is_instance_valid(_mutagen)

func _other_minigame_busy() -> bool:
	if is_instance_valid(_pizzaparty) and _pizzaparty.has_method("is_busy") and _pizzaparty.is_busy():
		return true
	if is_instance_valid(_slotsgame) and _slotsgame.has_method("is_busy") and _slotsgame.is_busy():
		return true
	return false

func _run_active() -> bool:
	return enabled \
		and is_instance_valid(_normaldo) and _normaldo.has_method("is_input_enabled") \
		and _normaldo.is_input_enabled() \
		and is_instance_valid(_spawner) and not _spawner._frozen \
		and not _other_minigame_busy()

func _process(delta: float) -> void:
	match _state:
		State.IDLE:
			# The mutagen is now just a rare flying pickup: while the run is live
			# and none is on screen, roll each frame to send one across a lane. It
			# does NOT freeze/clear anything — only CATCHING it starts the game.
			if _run_active():
				if _arm_timer > 0.0:
					_arm_timer -= delta
				elif not is_instance_valid(_mutagen) and randf() < mutagen_chance:
					_send_mutagen()
		State.PLAY:
			_tick_play(delta)

func _send_mutagen() -> void:
	if not is_instance_valid(_spawner) or not is_instance_valid(_background):
		return
	if _spawner.has_method("current_phase_speed"):
		_base_item_speed = _spawner.current_phase_speed()

	# Flies in a random lane, right→left, at the run's item speed — like any other
	# item. No park, no freeze; it just sails through (and frees itself off-screen
	# if uncaught). Parented to FatBoss so nothing else sweeps it away.
	_mutagen = MUTAGEN_SCENE.instantiate()
	var vp := get_viewport_rect().size
	var lane_y := vp.y / 5.0 * ((randi() % 5) + 0.5)
	_mutagen.position    = Vector2(vp.x + 80.0, lane_y)
	_mutagen.target_node = _normaldo   # for the proximity reaction
	_mutagen.speed       = _base_item_speed
	add_child(_mutagen)

# Stop the world for the mini-game itself (fires only when the mutagen is caught):
# freeze the spawner, clear stray run items, halt the background scroll.
func _freeze_run() -> void:
	if _event_frozen:
		return
	_event_frozen = true
	if is_instance_valid(_spawner):
		_spawner.pause_for_event()
		_spawner.collapse_items()   # items tumble down instead of blinking out
	if is_instance_valid(_background):
		_background.stop_scrolling()

# Куда ставится голова на время френзи: ЦЕНТРОМ ровно на левый край кадра.
# Спрайт скина посажен так, что центр головы совпадает с началом координат узла
# (см. normaldo._apply_head_offset), поэтому на экране остаётся ровно правая
# половина головы — половина лица, как и задумано.
# Куда вернуть голову после мини-игры. Брать текущую позицию «как есть» нельзя:
# если мини-игра почему-то начинается, когда голова УЖЕ стоит на якоре босса
# (левый край), то забег после неё продолжится вплотную к краю, и играть
# станет невозможно. В таком случае возвращаем на обычное игровое место.
const RETURN_X_FRAC : float = 0.28
func _safe_return_pos(vp: Vector2) -> Vector2:
	var pos : Vector2 = _normaldo.position
	if absf(pos.x - boss_anchor(vp).x) < vp.x * 0.06:
		return Vector2(vp.x * RETURN_X_FRAC, pos.y)
	return pos

func boss_anchor(vp: Vector2) -> Vector2:
	return Vector2(0.0, vp.y * 0.5)

# Пик размера считается ПОД СКИН и состояние жира: голова растягивается до
# BOSS_FACE_H высоты экрана. Прежнее фиксированное ×12 давало у классики голову
# шириной 1092 px на экране 960 — лица не видно, и у каждого скина размер свой.
func _refresh_max_factor() -> void:
	var vp := get_viewport_rect().size
	if is_instance_valid(_normaldo) and _normaldo.has_method("boss_face_factor"):
		_max_factor = _normaldo.boss_face_factor(vp.y * BOSS_FACE_H)
	if is_instance_valid(_normaldo) and _normaldo.has_method("set_fat_boss_max"):
		_normaldo.set_fat_boss_max(_max_factor)

# Dev hook: поставить босса в позу френзи без погони за мутагеном. Нужен
# dev/shot_boss.gd, который снимает кадр по каждому скину и состоянию жира.
func dev_pose_boss() -> void:
	if not is_instance_valid(_normaldo):
		return
	var vp := get_viewport_rect().size
	_refresh_max_factor()
	_normaldo.position = boss_anchor(vp)
	if _normaldo.has_method("set_fat_boss_factor"):
		_normaldo.set_fat_boss_factor(_max_factor)
	if _normaldo.has_method("set_fat_boss_rotation"):
		_normaldo.set_fat_boss_rotation(0.0)

# Dev hook: поставить фазу Б напрямую, без мутагена и без анимации раздува.
# Нужен dev/smoke_boss.gd, который прогоняет саму механику жира: и без него
# проверить «не тапаешь — сдуваешься» можно только глазами.
func dev_begin_play(bar: float = BAR_START) -> void:
	if not is_instance_valid(_normaldo):
		return
	# Только из покоя: если предыдущая мини-игра ещё доигрывает аутро, её
	# корутина через мгновение поставит IDLE — и оборвёт только что начатую.
	if _state != State.IDLE:
		return
	_freeze_run()
	if _normaldo.has_method("begin_fat_boss"):
		_normaldo.begin_fat_boss()
	_refresh_max_factor()
	_pre_boss_pos = _safe_return_pos(get_viewport_rect().size)
	_normaldo.position = boss_anchor(get_viewport_rect().size)
	_bar        = clampf(bar, 0.0, 1.0)
	_frenzy_t   = FRENZY_HARD_CAP
	_play_time  = 0.0
	_pizza_got  = 0
	_dollar_got = 0
	_breathe_t  = 0.0
	_stage      = 0
	_fx_t       = 0.0
	_dance_amp  = 0.0
	_disco_a    = 0.0
	_tap_pulse  = 0.0
	_tap_rot    = 0.0
	_mg_timer   = 0.0
	_last_tap_msec = Time.get_ticks_msec()
	if _normaldo.has_method("set_fat_boss_factor"):
		_normaldo.set_fat_boss_factor(fat_factor_for(_bar))
	_build_bar_hud()
	_state = State.PLAY

# Dev hook: fire a mutagen right now. No-op if a mini-game is already in progress.
func dev_send_mutagen() -> void:
	if _state != State.IDLE or is_instance_valid(_mutagen):
		return
	if not is_instance_valid(_normaldo) or not is_instance_valid(_spawner):
		return
	_send_mutagen()

func _on_mutagen_caught() -> void:
	if _state != State.IDLE:
		return
	_event_frozen = false
	_freeze_run()        # the world freezes now, on catch — the mini-game begins
	_mutagen = null
	_run_grow()

# ── Phase A: grow ─────────────────────────────────────────────────────────────

func _run_grow() -> void:
	_state = State.GROW
	if _normaldo.has_method("begin_fat_boss"):
		_normaldo.begin_fat_boss()
	_refresh_max_factor()
	var vp := get_viewport_rect().size
	# Fattening starts IMMEDIATELY — Normaldo slides into position while already
	# inflating (don't wait for him to arrive / for the mutagen to have parked).
	# Куда вернуть голову после мини-игры. Раньше босс стоял почти на месте
	# забега и возвращать было нечего; теперь он уезжает центром на левый край,
	# и без возврата игрок продолжал бы забег вплотную к краю экрана.
	_pre_boss_pos = _safe_return_pos(vp)
	if _normaldo.has_method("move_to"):
		_normaldo.move_to(boss_anchor(vp), 0.5)

	_speech_bubble("Я ЧУВСТВУЮ...")

	for i in GROW_STEPS.size():
		var from_f : float = 1.0 if i == 0 else GROW_STEPS[i - 1] * _max_factor
		var to_f   : float = GROW_STEPS[i] * _max_factor
		var angle  : float = deg_to_rad(GROW_ANGLES_DEG[i])
		# Inflate + tilt together (jerk left, then right, … straight at the top).
		var tw := create_tween().set_parallel(true)
		tw.tween_method(Callable(_normaldo, "set_fat_boss_factor"), from_f, to_f, GROW_STEP_T) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		if _normaldo.has_method("set_fat_boss_rotation"):
			tw.tween_property(_normaldo, "rotation", angle, GROW_STEP_T) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		await tw.finished
		_earthquake(10.0 + i * 5.0, 0.45)
		_spew_debris()
		if _sfx_grow.stream:     # crash.mp3 — the inflate hit
			_sfx_grow.play()
		await get_tree().create_timer(GROW_HOLD_T).timeout

	# Peak fatness reached — он держит свой пиковый множитель всю френзи.
	_speech_bubble("ЖИИИРРР!!!")
	_crossfade_music()

	_bar          = BAR_START
	_frenzy_t     = FRENZY_HARD_CAP
	_play_time    = 0.0
	_pizza_got    = 0
	_dollar_got   = 0
	_breathe_t    = 0.0
	_stage        = 0
	_fx_t         = 0.0
	_dance_amp    = 0.0
	_disco_a      = 0.0
	_set_stage(0)
	_tap_pulse    = 0.0
	_tap_rot      = 0.0
	_last_tap_msec = Time.get_ticks_msec()
	_mg_timer     = 0.0
	if _normaldo.has_method("set_fat_boss_factor"):
		_normaldo.set_fat_boss_factor(_max_factor)
	_build_bar_hud()
	_show_prompt()
	_state = State.PLAY

# ── Phase B: shrink + tap ─────────────────────────────────────────────────────

func _tick_play(delta: float) -> void:
	_frenzy_t  -= delta
	_play_time += delta
	# Жир сам стекает; тап возвращает его наверх (см. `_on_tap`).
	_bar = clampf(_bar - _bar_decay() * delta, 0.0, 1.0)
	_refresh_stage()
	_update_stage_fx(delta)

	# Tap feedback decays back to rest.
	_tap_pulse = lerpf(_tap_pulse, 0.0, delta * 12.0)
	_tap_rot   = lerpf(_tap_rot, 0.0, delta * 9.0)

	# СДУВАЯСЬ, БОСС ОТЪЕЗЖАЕТ ОТ КРАЯ. На пике голова стоит центром на левом
	# краю — видна ровно половина лица. Если оставить её там же и просто
	# уменьшать, сдувание уезжает за кадр вместе с головой, и главную обратную
	# связь мини-игры игрок не видит. Поэтому якорь едет от края к обычному
	# игровому месту по мере похудения — заодно к концу он уже почти там, куда
	# его вернёт аутро.
	var vp := get_viewport_rect().size
	_normaldo.position.x = lerpf(vp.x * RETURN_X_FRAC, boss_anchor(vp).x, _bar)

	# РАЗМЕР ИДЁТ ЗА ЖИРОМ. Это и есть главная обратная связь мини-игры: перестал
	# тапать — видишь, как сдуваешься, и понимаешь, что время уходит.
	_breathe_t += delta * 5.0
	if _normaldo.has_method("set_fat_boss_factor"):
		var wobble := 1.0 + sin(_breathe_t) * 0.012 + _tap_pulse
		_normaldo.set_fat_boss_factor(fat_factor_for(_bar) * wobble)
	if _normaldo.has_method("set_fat_boss_rotation"):
		_normaldo.set_fat_boss_rotation(_tap_rot)

	_update_bar_hud()

	# Tap prompt ("ТАПАЙ" title): hidden while the player taps, reappears when idle.
	if not _prompt_shown and (Time.get_ticks_msec() - _last_tap_msec) / 1000.0 > PROMPT_REAPPEAR:
		_show_prompt()

	# Fast loot/obstacle stream.
	_mg_timer -= delta
	if _mg_timer <= 0.0:
		_mg_timer = MG_SPAWN_INTERVAL
		_spawn_mg_item()

	# Item speed tracks the bar; drive every live item.
	var spd := _base_item_speed * lerpf(ITEM_SPEED_SLOW, ITEM_SPEED_FAST, _bar)
	var alive : Array[Node] = []
	for it in _mg_items:
		if is_instance_valid(it):
			it.speed = spd
			alive.append(it)
	_mg_items = alive

	# Сдулся до нуля — мини-игра кончилась. Таймера нет: длительность целиком в
	# руках игрока. `_frenzy_t` остаётся аварийным потолком.
	if _bar <= 0.0 or _frenzy_t <= 0.0:
		_end_minigame()

# Множитель размера по уровню жира. Даже на нуле голова заметно больше обычной:
# ниже пола босс перестаёт читаться боссом, а предметы начинают пролетать мимо.
func fat_factor_for(bar: float) -> float:
	return lerpf(_max_factor * FAT_FLOOR, _max_factor, clampf(bar, 0.0, 1.0))

func _on_tap() -> void:
	_last_tap_msec = Time.get_ticks_msec()
	if _prompt_shown:
		_hide_prompt()
	if _state != State.PLAY:
		return
	# Тап делает ровно две вещи разом: держит жир (а значит и размер) и разгоняет
	# поток. Отдача падает по мере набора — удержать максимум нельзя.
	_bar = clampf(_bar + tap_gain(), 0.0, 1.0)
	_tap_pulse = 0.03   # transient jolt, decays in a few frames (reads as a shudder)
	_tap_rot   = randf_range(0.05, 0.10) * (1.0 if randf() < 0.5 else -1.0)
	# Tap feedback: tap.mp3 (if present) + a green particle puff.
	if _tap_player.stream:
		_tap_player.play()
	_tap_particles()

func _input(event: InputEvent) -> void:
	if _state != State.PLAY and _state != State.GROW:
		return
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		_on_tap()

func _end_minigame() -> void:
	if _state == State.OUTRO:
		return
	_state = State.OUTRO
	_run_outro()

# Outro: cut the music + settle the screen, deflate him SMOOTHLY (not a snap),
# puff out the parting bubble, resume the run, then fly the tallied pizza/dollars
# up-left into the run score and credit them for real.
func _run_outro() -> void:
	_hide_prompt()
	_hide_title()
	_clear_mg_items()
	# Settle the screen + cut the hard track the instant the frenzy ends.
	if is_instance_valid(_shake_cam):
		_shake_cam.offset = Vector2.ZERO
		_shake_cam.zoom   = Vector2.ONE
	_clear_disco()
	_set_stage(0)
	_restore_music()
	if _normaldo.has_method("set_fat_boss_rotation"):
		_normaldo.set_fat_boss_rotation(0.0)

	# Sag back to normal size, then the "slake bake" stamp pops over the deflated him.
	await _deflate()
	_show_slake()
	_tap_particles()

	if _normaldo.has_method("end_fat_boss"):
		_normaldo.end_fat_boss()

	# Итог мини-игры: барабаны бросают множитель, плашка показывает умножение,
	# добыча улетает в счётчики HUD. Поток предметов на это время ОСТАЁТСЯ на
	# паузе — иначе игрок под окном итогов уворачивается вслепую.
	var mult : int = LootMultiplier.roll()
	if is_instance_valid(_bar_root):
		_bar_root.create_tween().tween_property(_bar_root, "modulate:a", 0.0, 0.35)
	var tg : Array = MinigamePayout.targets_from(get_parent().get_node_or_null("HUD"))
	await MinigamePayout.play(_ui, _pizza_got, _dollar_got, mult, tg[0], tg[1])
	if _normaldo.has_method("fat_boss_award"):
		_normaldo.fat_boss_award(_pizza_got * mult, _dollar_got * mult)
	_teardown_bar_hud()

	if is_instance_valid(_spawner) and _spawner.has_method("resume_after_event"):
		_spawner.resume_after_event()
	if is_instance_valid(_background):
		_background.start_scrolling()

	# Drop the shake camera so the default (no-camera) framing is fully restored.
	if is_instance_valid(_shake_cam):
		_shake_cam.queue_free()
	_shake_cam = null
	_event_frozen = false
	_arm_timer = repeat_interval
	_state = State.IDLE

# Smooth deflation: a tiny anticipation puff (BACK/EASE_IN overshoots up first),
# then he sags from the peak factor back to normal size over DEFLATE_T.
func _deflate() -> void:
	if not _normaldo.has_method("set_fat_boss_factor"):
		return
	var tw := create_tween()
	tw.tween_method(Callable(_normaldo, "set_fat_boss_factor"), _max_factor, 1.0, DEFLATE_T) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	# Сдувается и одновременно возвращается на своё место в забеге.
	if _pre_boss_pos != Vector2.ZERO:
		tw.parallel().tween_property(_normaldo, "position", _pre_boss_pos, DEFLATE_T) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await tw.finished

# Parting "slake bake" image: pops in over the now-deflated Normaldo, holds, fades.
func _show_slake() -> void:
	if not is_instance_valid(_normaldo):
		return
	var s : float = 170.0 / maxf(1.0, float(SLAKE_TEX.get_height()))   # ~170 px tall
	var spr := Sprite2D.new()
	spr.texture  = SLAKE_TEX
	spr.position = _normaldo.position + Vector2(0.0, -150.0)   # well above his head
	spr.scale    = Vector2(s, s) * 0.2
	spr.z_index  = 10
	_ui.add_child(spr)
	var tw := spr.create_tween()
	tw.tween_property(spr, "scale", Vector2(s, s), 0.26) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.1)
	tw.tween_property(spr, "modulate:a", 0.0, 0.3)
	tw.tween_callback(spr.queue_free)

# ── Phase-B item spawning ─────────────────────────────────────────────────────

func _spawn_mg_item() -> void:
	if not is_instance_valid(_spawner):
		return
	var vp := get_viewport_rect().size
	var lane_y := vp.y / 5.0 * ((randi() % 5) + 0.5)
	var spd := _base_item_speed * lerpf(ITEM_SPEED_SLOW, ITEM_SPEED_FAST, _bar)
	# Loot-heavy stream: ~65% pizza/dollars, the rest obstacles.
	var roll := randf()
	var node : Node
	if roll < 0.46:
		node = _make_item(PIZZA_TEX, 0.09, true, 0, "")
	elif roll < 0.65:
		node = _make_item(DOLLAR_TEX, 0.36, false, 0, "dollar")
	elif roll < 0.80:
		node = _make_item(TRASH_TEX, 0.22, false, 1, "")   # бочка
		node.rotates = false
		node.knock_sound = FIRECRACKER                     # firecracker on impact
		(node.get_node("Sprite2D") as Sprite2D).rotation = PI / 2.0
	elif roll < 0.91:
		node = HOMELESS_SCENE.instantiate()                # бомж
	else:
		node = DOG_SCENE.instantiate()                     # собака
	node.position = Vector2(vp.x + 80.0, lane_y)
	if node.get("speed") != null:
		node.speed = spd
	_spawner.add_child(node)
	_mg_items.append(node)

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

func _clear_mg_items() -> void:
	# Collapse them (tumble + fall) instead of blinking out, same as the freeze.
	for it in _mg_items:
		if is_instance_valid(it):
			if is_instance_valid(_spawner) and _spawner.has_method("collapse_node") and it is Node2D:
				_spawner.collapse_node(it)
			else:
				it.queue_free()
	_mg_items.clear()

# ── Overlays: title ("ТАПАЙ" + fingers) and speech bubble ─────────────────────

# Boss-fight-style banner (54 px red RussoOne) with a "finger" (back-arrow)
# pointing inward on each side of the text. The whole thing blinks (scale +
# alpha) for the entire mini-game; quick fade-out at the end via _hide_title().
func _show_title(text: String) -> void:
	_hide_title()
	var vp := get_viewport_rect().size
	var font_size := 54
	var tw_px : float = UI_FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x

	# Root centred on screen — label + fingers all scale/blink together.
	var root := Node2D.new()
	root.position = Vector2(vp.x * 0.5, vp.y * 0.30 + 40.0)
	_ui.add_child(root)
	_title_root = root

	var lbl := Label.new()
	lbl.add_theme_font_override("font", UI_FONT)
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.12, 0.06))
	lbl.text                 = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl.size                 = Vector2(tw_px, 80.0)
	lbl.position             = Vector2(-tw_px * 0.5, -40.0)
	root.add_child(lbl)

	# A finger on each side, pointing inward at the text (back_arrow points left).
	const FSC  := 0.9
	const FGAP := 30.0
	var fw : float = FINGER_TEX.get_width() * FSC
	var fl := Sprite2D.new()
	fl.texture        = FINGER_TEX
	fl.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	fl.scale          = Vector2(-FSC, FSC)   # flipped → points right toward text
	fl.position       = Vector2(-tw_px * 0.5 - FGAP - fw * 0.5, 0.0)
	root.add_child(fl)
	var fr := Sprite2D.new()
	fr.texture        = FINGER_TEX
	fr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	fr.scale          = Vector2(FSC, FSC)    # default → points left toward text
	fr.position       = Vector2(tw_px * 0.5 + FGAP + fw * 0.5, 0.0)
	root.add_child(fr)

	root.scale = Vector2(0.2, 0.2)
	_title_tw = root.create_tween().set_loops()
	_title_tw.tween_property(root, "scale", Vector2(1.18, 1.18), 0.24) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_title_tw.parallel().tween_property(root, "modulate:a", 0.5, 0.24)
	_title_tw.tween_property(root, "scale", Vector2(1.0, 1.0), 0.24)
	_title_tw.parallel().tween_property(root, "modulate:a", 1.0, 0.24)

func _hide_title() -> void:
	if _title_tw and _title_tw.is_valid():
		_title_tw.kill()
	_title_tw = null
	if is_instance_valid(_title_root):
		var root := _title_root
		var tw := root.create_tween()
		tw.tween_property(root, "modulate:a", 0.0, 0.18)
		tw.tween_callback(root.queue_free)
	_title_root = null

# Ninja-boss style speech cloud (mirrors ninja_foot._show_intro_speech): light
# rounded card with a red top stripe + tail, dark text, pop in / hold / pop out.
# Fire-and-forget coroutine — runs concurrently with the growth animation.
func _speech_bubble(text: String, hold: float = 1.4) -> void:
	var vp := get_viewport_rect().size
	const BUBBLE_W : float = 280.0
	const BUBBLE_H : float = 70.0
	var root := Control.new()
	root.size         = Vector2(BUBBLE_W, BUBBLE_H)
	root.position     = Vector2(vp.x * 0.30, vp.y * 0.12)
	root.pivot_offset = root.size * 0.5
	root.scale        = Vector2(0.6, 0.6)
	root.modulate     = Color(1.0, 1.0, 1.0, 0.0)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(root)

	var bg := ColorRect.new()
	bg.color = Color(0.96, 0.96, 0.98, 0.97)
	bg.size  = root.size
	root.add_child(bg)

	var stripe := ColorRect.new()
	stripe.color = Color(0.20, 0.05, 0.05, 0.85)
	stripe.size  = Vector2(BUBBLE_W, 3.0)
	root.add_child(stripe)

	# Tail pointing down-left toward Normaldo.
	var tail := ColorRect.new()
	tail.color    = bg.color
	tail.size     = Vector2(20.0, 14.0)
	tail.position = Vector2(24.0, BUBBLE_H - 5.0)
	tail.rotation = 0.30
	root.add_child(tail)

	var msg := Label.new()
	msg.add_theme_font_override("font", UI_FONT)
	msg.add_theme_font_size_override("font_size", 20)
	msg.add_theme_color_override("font_color", Color(0.10, 0.06, 0.10))
	msg.text                 = text
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	msg.size                 = Vector2(BUBBLE_W - 16.0, BUBBLE_H - 12.0)
	msg.position             = Vector2(8.0, 6.0)
	root.add_child(msg)

	var tw_in := create_tween().set_parallel(true)
	tw_in.tween_property(root, "modulate:a", 1.0, 0.16)
	tw_in.tween_property(root, "scale", Vector2.ONE, 0.24) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tw_in.finished
	await get_tree().create_timer(hold).timeout
	var tw_out := create_tween().set_parallel(true)
	tw_out.tween_property(root, "modulate:a", 0.0, 0.2)
	tw_out.tween_property(root, "scale", Vector2(0.6, 0.6), 0.2)
	await tw_out.finished
	if is_instance_valid(root):
		root.queue_free()

# ── Tap prompt (the blinking "ТАПАЙ" title) ───────────────────────────────────
# The title IS the prompt now: it shows while idle and hides while tapping.

func _show_prompt() -> void:
	if _prompt_shown:
		return
	_prompt_shown = true
	_show_title("ТАПАЙ")

func _hide_prompt() -> void:
	if not _prompt_shown:
		return
	_prompt_shown = false
	_hide_title()

# ── Phase-B HUD: speed bar + pizza/dollar tally ───────────────────────────────
# The bar fills on tap (driving item speed) and the row beneath shows what's
# been devoured so far. None of it is the run score yet — it flies into the HUD
# at the end — его забирает MinigamePayout (см. _run_outro).

func _build_bar_hud() -> void:
	_teardown_bar_hud()
	var vp := get_viewport_rect().size
	var root := Control.new()
	root.position     = Vector2(vp.x * 0.5 - BAR_W * 0.5, 56.0)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(root)
	_bar_root = root

	var cap := Label.new()
	cap.add_theme_font_override("font", UI_FONT)
	cap.add_theme_font_size_override("font_size", 16)
	cap.add_theme_color_override("font_color", Color(0.90, 1.0, 0.92))
	cap.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	cap.add_theme_constant_override("outline_size", 4)
	cap.text                 = "ЖИР — ТАПАЙ, ЧТОБЫ ДЕРЖАТЬСЯ"
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.size                 = Vector2(BAR_W, 20.0)
	cap.position             = Vector2(0.0, -24.0)
	cap.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	root.add_child(cap)

	var outline := ColorRect.new()
	outline.color    = Color(0.0, 0.0, 0.0, 0.85)
	outline.size     = Vector2(BAR_W + 4.0, BAR_H + 4.0)
	outline.position = Vector2(-2.0, -2.0)
	root.add_child(outline)

	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.12, 0.09, 0.95)
	bg.size  = Vector2(BAR_W, BAR_H)
	root.add_child(bg)

	_bar_fill = ColorRect.new()
	_bar_fill.color = Color(0.35, 1.0, 0.45)
	_bar_fill.size  = Vector2(BAR_W * _bar, BAR_H)
	root.add_child(_bar_fill)

	# Число ПОВЕРХ полосы — во сколько раз ты сейчас больше обычного. Полоса
	# без числа отвечает «примерно столько», а тут есть что назвать.
	_bar_mult_lbl = Label.new()
	_bar_mult_lbl.add_theme_font_override("font", UI_FONT)
	_bar_mult_lbl.add_theme_font_size_override("font_size", 14)
	_bar_mult_lbl.add_theme_color_override("font_color", Color(1, 1, 1))
	_bar_mult_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_bar_mult_lbl.add_theme_constant_override("outline_size", 4)
	_bar_mult_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bar_mult_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_bar_mult_lbl.size                 = Vector2(BAR_W, BAR_H)
	_bar_mult_lbl.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	root.add_child(_bar_mult_lbl)

	var row_y := BAR_H + 12.0
	_pizza_count_icon = _make_count_icon(PIZZA_TEX)
	_pizza_count_icon.position = Vector2(BAR_W * 0.5 - 80.0, row_y)
	root.add_child(_pizza_count_icon)
	_pizza_count_lbl = _make_count_label()
	_pizza_count_lbl.position = Vector2(BAR_W * 0.5 - 50.0, row_y - 2.0)
	root.add_child(_pizza_count_lbl)

	_dollar_count_icon = _make_count_icon(DOLLAR_TEX)
	_dollar_count_icon.position = Vector2(BAR_W * 0.5 + 16.0, row_y)
	root.add_child(_dollar_count_icon)
	_dollar_count_lbl = _make_count_label()
	_dollar_count_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35))
	_dollar_count_lbl.position = Vector2(BAR_W * 0.5 + 46.0, row_y - 2.0)
	root.add_child(_dollar_count_lbl)

func _make_count_icon(tex: Texture2D) -> TextureRect:
	var r := TextureRect.new()
	r.texture      = tex
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
	r.size         = Vector2(26.0, 26.0)
	r.pivot_offset = Vector2(13.0, 13.0)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

func _make_count_label() -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", UI_FONT)
	l.add_theme_font_size_override("font_size", 22)
	l.add_theme_color_override("font_color", Color(1, 1, 1))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", 5)
	l.text                 = "0"
	l.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	l.size                 = Vector2(48.0, 28.0)
	l.pivot_offset         = Vector2(24.0, 14.0)
	l.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	return l

func _update_bar_hud() -> void:
	if is_instance_valid(_bar_fill):
		_bar_fill.size.x = BAR_W * _bar
		# Tint heats up green→gold as the player mashes — pure juice.
		_bar_fill.color  = Color(0.35, 1.0, 0.45).lerp(Color(1.0, 0.95, 0.30), _bar)
	if is_instance_valid(_bar_mult_lbl):
		_bar_mult_lbl.text = "×%d" % int(round(fat_factor_for(_bar)))

func _teardown_bar_hud() -> void:
	_clear_disco()
	if is_instance_valid(_bar_root):
		_bar_root.queue_free()
	_bar_root = null
	_bar_fill = null
	_pizza_count_lbl = null
	_dollar_count_lbl = null
	_bar_mult_lbl = null
	_pizza_count_icon = null
	_dollar_count_icon = null

# A good item touched the giant: tally it (NOT the run score) + punch the counter.
func _on_loot_collected(kind: String, _world_pos: Vector2) -> void:
	if _state != State.PLAY:
		return
	if kind == "dollar":
		_dollar_got += 1
		if is_instance_valid(_dollar_count_lbl):
			_dollar_count_lbl.text = str(_dollar_got)
		_punch(_dollar_count_lbl)
		_punch(_dollar_count_icon)
	else:
		_pizza_got += 1
		if is_instance_valid(_pizza_count_lbl):
			_pizza_count_lbl.text = str(_pizza_got)
		_punch(_pizza_count_lbl)
		_punch(_pizza_count_icon)

func _punch(node: Control) -> void:
	if not is_instance_valid(node):
		return
	node.scale = Vector2(1.35, 1.35)
	var tw := node.create_tween()
	tw.tween_property(node, "scale", Vector2.ONE, 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# ── Intensity stages: calm → mid (screen dances) → madness (disco light) ───────
# Этап — функция уровня ЖИРА, с гистерезисом, чтобы не дребезжало на границе.
# Каждый переход — момент, на который может встать музыка (см. `_set_stage`);
# сама картинка едет за жиром плавно.

# Слив растёт двояко: с набранным жиром (квадратично) и со временем в мини-игре
# — первые DECAY_GRACE секунд обычный, потом за DECAY_RAMP_T нарастает до
# ×DECAY_TIME_MULT. Второе и гарантирует, что мини-игра всегда кончается.
func _bar_decay() -> float:
	var t := clampf((_play_time - DECAY_GRACE) / DECAY_RAMP_T, 0.0, 1.0)
	var time_mult := lerpf(1.0, DECAY_TIME_MULT, t)
	return (BAR_DECAY + BAR_DECAY_RAMP * _bar * _bar) * time_mult

# Прибавка за один тап. Падает дважды: у полного жира тап даёт вчетверо меньше,
# чем у пустого, и вся отдача угасает со временем — Нормальдо выдыхается. Без
# второго множителя мини-игра при быстром тапе не кончается никогда.
func tap_gain() -> float:
	return BAR_TAP_GAIN \
		* lerpf(1.0, BAR_TAP_FALLOFF, clampf(_bar, 0.0, 1.0)) \
		* tap_stamina()

# 1.0 в начале, TAP_STAMINA_MIN к концу разгона сложности.
func tap_stamina() -> float:
	var t := clampf((_play_time - DECAY_GRACE) / DECAY_RAMP_T, 0.0, 1.0)
	return lerpf(1.0, TAP_STAMINA_MIN, t)

func _refresh_stage() -> void:
	var s := _stage
	match _stage:
		0:
			if _bar >= STAGE_MID_UP: s = 1
		1:
			if _bar >= STAGE_MAD_UP:   s = 2
			elif _bar < STAGE_MID_DN:  s = 0
		2:
			if _bar < STAGE_MAD_DN:    s = 1
	if s != _stage:
		_set_stage(s)

func _set_stage(s: int) -> void:
	_stage = s
	# Music hook: harder track per stage, softer on drop. When the designer wires
	# escalation onto the music player, it drives from here — nothing else to do.
	if is_instance_valid(_music) and _music.has_method("set_frenzy_stage"):
		_music.set_frenzy_stage(s)

# Per-frame stage visuals: a camera sway/"dance" whose amplitude grows with the
# stage, plus a strobing disco light wash at madness.
func _update_stage_fx(delta: float) -> void:
	_fx_t += delta
	_ensure_cam()
	var target_amp := 0.0
	if _stage == 1:   target_amp = DANCE_AMP_MID
	elif _stage == 2: target_amp = DANCE_AMP_MAD
	_dance_amp = lerpf(_dance_amp, target_amp, delta * 5.0)
	if is_instance_valid(_shake_cam):
		var sway := Vector2(sin(_fx_t * 7.0), cos(_fx_t * 9.3) * 0.7) * _dance_amp
		var jit := Vector2.ZERO
		if _stage == 2:   # madness adds a high-freq jitter on top of the sway
			jit = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _dance_amp * 0.4
		_shake_cam.offset = sway + jit
		# Zoom in just enough to keep the wall edges off-screen while it shakes.
		_shake_cam.zoom = Vector2.ONE * (1.0 + _dance_amp * ZOOM_PER_AMP)

	# Disco wash — only at madness; depth = how far past the threshold.
	var mad := 0.0
	if _stage == 2:
		mad = clampf((_bar - STAGE_MAD_DN) / (1.0 - STAGE_MAD_DN), 0.0, 1.0)
	_update_disco(delta, mad)

func _update_disco(delta: float, intensity: float) -> void:
	if intensity <= 0.001 and not is_instance_valid(_disco):
		return
	_ensure_disco()
	_disco_hue = fmod(_disco_hue + delta * 1.6, 1.0)
	_disco_a   = lerpf(_disco_a, 0.26 * intensity, delta * 8.0)
	var strobe := 0.7 + 0.3 * sin(_fx_t * 22.0)   # club-strobe pulse
	var col := Color.from_hsv(_disco_hue, 0.9, 1.0)
	col.a = _disco_a * strobe
	if is_instance_valid(_disco):
		_disco.color = col

func _ensure_disco() -> void:
	if is_instance_valid(_disco):
		return
	_disco = ColorRect.new()
	_disco.size         = get_viewport_rect().size
	_disco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := CanvasItemMaterial.new()
	m.blend_mode  = CanvasItemMaterial.BLEND_MODE_ADD
	_disco.material = m
	_disco.color  = Color(0, 0, 0, 0)
	_ui.add_child(_disco)
	_ui.move_child(_disco, 0)   # behind the bar/title text so the UI stays readable

func _clear_disco() -> void:
	if is_instance_valid(_disco):
		_disco.queue_free()
	_disco = null
	_disco_a = 0.0

# ── FX: earthquake camera shake + ceiling debris ──────────────────────────────

func _ensure_cam() -> void:
	if _shake_cam == null:
		_shake_cam = Camera2D.new()
		# Placing the camera at the viewport centre with the default drag-centre
		# anchor reproduces the no-camera framing exactly, so making it current
		# doesn't shift anything — we only ever touch its `offset` to shake.
		_shake_cam.position = get_viewport_rect().size * 0.5
		get_parent().add_child(_shake_cam)
		_shake_cam.make_current()

func _earthquake(strength: float = 14.0, dur: float = 0.45) -> void:
	_ensure_cam()
	var steps : int = maxi(1, int(dur / 0.04))
	var tw := _shake_cam.create_tween()
	for i in steps:
		var s : float = strength * (1.0 - float(i) / float(steps))
		tw.tween_property(_shake_cam, "offset",
			Vector2(randf_range(-s, s), randf_range(-s, s)), 0.04)
	tw.tween_property(_shake_cam, "offset", Vector2.ZERO, 0.05)
	# Zoom in for the duration of the shake so the jolt never exposes the wall's
	# top/bottom edges (city layer bleed). Pops to match `strength`, eases back.
	_shake_cam.zoom = Vector2.ONE * (1.0 + strength * ZOOM_PER_AMP)
	_shake_cam.create_tween().tween_property(_shake_cam, "zoom", Vector2.ONE, dur + 0.05)

func _ensure_debris() -> void:
	if _debris != null:
		return
	_debris = CPUParticles2D.new()
	var vp := get_viewport_rect().size
	_debris.emitting              = false
	_debris.one_shot              = true
	_debris.explosiveness         = 0.7
	_debris.amount                = 48
	_debris.lifetime              = 1.5
	_debris.position              = Vector2(vp.x * 0.5, -8.0)
	_debris.emission_shape        = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_debris.emission_rect_extents = Vector2(vp.x * 0.5, 4.0)
	_debris.direction             = Vector2(0.0, 1.0)
	_debris.spread                = 22.0
	_debris.gravity               = Vector2(0.0, 900.0)
	_debris.initial_velocity_min  = 120.0
	_debris.initial_velocity_max  = 280.0
	_debris.scale_amount_min      = 2.0
	_debris.scale_amount_max      = 5.0
	_debris.color                 = Color(0.22, 0.14, 0.07)   # sewage brown/black
	add_child(_debris)

func _spew_debris() -> void:
	_ensure_debris()
	_debris.restart()
	_debris.emitting = true

# Green particle puff at Normaldo on every tap (matches the mutagen colour).
func _tap_particles() -> void:
	if _tap_burst == null:
		_tap_burst = CPUParticles2D.new()
		_tap_burst.emitting             = false
		_tap_burst.one_shot             = true
		_tap_burst.explosiveness        = 1.0
		_tap_burst.amount               = 16
		_tap_burst.lifetime             = 0.6
		_tap_burst.spread               = 180.0
		_tap_burst.direction            = Vector2(0.0, -1.0)
		_tap_burst.gravity              = Vector2.ZERO
		_tap_burst.initial_velocity_min = 80.0
		_tap_burst.initial_velocity_max = 190.0
		_tap_burst.scale_amount_min     = 1.5
		_tap_burst.scale_amount_max     = 3.5
		_tap_burst.color                = Color(0.35, 1.0, 0.45)
		add_child(_tap_burst)
	if is_instance_valid(_normaldo):
		_tap_burst.position = _normaldo.position
	_tap_burst.restart()
	_tap_burst.emitting = true

# ── Music crossfade ───────────────────────────────────────────────────────────

func _crossfade_music() -> void:
	# Quick fade so the hard track lands *with* the "ЖИИИРРР" bubble, not after it.
	if is_instance_valid(_music) and _music.has_method("swap_to"):
		_orig_music_stream = _music.stream
		_music.swap_to(HARD_TRACK, 0.5)

func _restore_music() -> void:
	# Quick cut so the hard track ends right as the mini-game ends.
	if is_instance_valid(_music) and _music.has_method("swap_to") and _orig_music_stream:
		_music.swap_to(_orig_music_stream, 0.3)
		_orig_music_stream = null
