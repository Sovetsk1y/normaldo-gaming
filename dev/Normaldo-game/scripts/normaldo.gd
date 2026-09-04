extends Area2D

signal stats_changed(fat_state: int, pizza_count: int, total_pizzas: int)
signal died(total_pizzas: int, death_pos: Vector2)
signal dollars_changed(count: int)
signal unique_ability_changed(ready: bool)
signal wizard_state_changed(pizzas_done: int, bonus_active: bool, bonus_type: int, bonus_remaining: float)
signal mutagen_caught
signal slot_machine_caught   # СЛОТЫ mini-game trigger (caught like the mutagen)
# ЖИРОБОСС mini-game: a good item touched the giant. fat_boss.gd tallies it into
# the local counter (NOT the run score) and credits it all at the end.
signal fat_boss_loot_collected(kind: String, world_pos: Vector2)
signal active_denied   # tried to fire the active ability while on cooldown

const FAT_THRESHOLDS = [30, 60, 90]

# Множитель скорости движения по жиру
const FAT_SPEED_MULT = [1.0, 0.72, 0.50, 0.30]

# Classic skin textures (fallback / used when active_skin == "classic")
const _CLASSIC_TEX = [
	preload("res://assets/normaldo/normaldo1.png"),
	preload("res://assets/normaldo/normaldo2.png"),
	preload("res://assets/normaldo/normaldo3.png"),
	preload("res://assets/normaldo/normaldo4.png"),
]
const _CLASSIC_EAT_TEX = [
	preload("res://assets/normaldo/normaldo1_eat.png"),
	preload("res://assets/normaldo/normaldo2_eat.png"),
	preload("res://assets/normaldo/normaldo3_eat.png"),
	preload("res://assets/normaldo/normaldo4_eat.png"),
]
# «Доллары в глазах» — реакция классики на УДАЧНЫЙ «Размен». Лежат рядом со
# старыми normaldoN, а не в папке скина: у классики tex_dir пустой, она одна
# живёт на легаси-именах.
const _CLASSIC_CASH_TEX = [
	preload("res://assets/normaldo/normaldo1_cash.png"),
	preload("res://assets/normaldo/normaldo2_cash.png"),
	preload("res://assets/normaldo/normaldo3_cash.png"),
	preload("res://assets/normaldo/normaldo4_cash.png"),
]
const _CLASSIC_EAT_SFX = [
	preload("res://assets/audio/eat1.mp3"),
	preload("res://assets/audio/eat2.mp3"),
]
const _CLASSIC_HIT_SFX := preload("res://assets/audio/hit.mp3")
const _CLASSIC_FAT_SFX := preload("res://assets/audio/get_fat.mp3")

const BANANA_SOUND    := preload("res://assets/audio/banana.mp3")
const BEER_SOUND      := preload("res://assets/audio/beer.mp3")
const DOLLAR_SOUND    := preload("res://assets/audio/dollars.mp3")
const MAGNET_SOUND    := preload("res://assets/audio/magnet.mp3")

const UI_FONT := preload("res://assets/fonts/RussoOne-Regular.ttf")

# Active skin resources — populated in _load_skin()
var _skin_tex     : Array = []
var _skin_eat_tex : Array = []
var _skin_spell_tex : Array = []   # поза каста на каждое состояние жира
var _skin_spell2_tex    : Array = []   # второй кадр позы (Очки: «пьёт» → «скалится»)
var _skin_ghost_tex     : Array = []   # серые кадры Дракулы на время невидимости
var _skin_ghost_eat_tex : Array = []
var _ghost_active       : bool  = false
var _skin_eat_sfx : Array = []
var _skin_hit_sfx : AudioStream = null
var _skin_fat_sfx : AudioStream = null

const SLOW_MULTIPLIER  := 0.30
const PROXIMITY_RADIUS := 80.0
const EAT_ANIM_TIME    := 0.25

# Ручные добавки к масштабу больше не нужны: их заменили замеры голов в
# skin_metrics.gd. Раньше здесь на глаз стояли 1.10 для Викинга и Тайсона —
# по замерам им нужно 1.74 и 1.56, то есть глаз ошибался в полтора раза.

# ── Menu idle (decor before the run starts) ──────────────────────────────────
# Fired at the exact frame the remote "button press" jerk happens. The TV node
# listens for this and swaps to a new track at that moment so the on-screen
# action and the audio change are in lock-step.
signal menu_remote_button_pressed

const _MENU_REMOTE_TEX       := preload("res://assets/normaldo/menu_remote.png")
const _MENU_PIZZA_TEX        := preload("res://assets/items/pizza.png")
# Random delay (seconds) between menu pizzas spawning behind Normaldo.
const _MENU_PIZZA_INTERVAL_MIN : float = 4.0
const _MENU_PIZZA_INTERVAL_MAX : float = 9.0
# Two-phase animation: pizza emerges from behind Normaldo (slower, BEHIND his
# sprite) up to a peak position, then snaps to his mouth (faster, IN FRONT).
const _MENU_PIZZA_OUT_TIME     : float = 0.24
const _MENU_PIZZA_IN_TIME      : float = 0.45
# Peak offset relative to Normaldo's centre. Pizza emerges diagonally — out to
# the side AND slightly up — instead of sliding straight horizontally.
const _MENU_PIZZA_OFFSET_X     : float = 55.0
const _MENU_PIZZA_OFFSET_Y     : float = -18.0   # negative = up
# Pizza source is 511×449; this scale renders a small slice next to Normaldo.
const _MENU_PIZZA_SCALE        : float = 0.055

# Remote-control animation (Normaldo "changes the TV channel" between tracks).
# Timing breakdown: slide out → tiny jerk down (button press) → jerk back up →
# slide back behind him.
const _MENU_REMOTE_SCALE       : float = 1.0
# Out to the right toward the TV, sitting a few pixels below Normaldo's
# centre so the remote rests around hand/lap height.
const _MENU_REMOTE_PEAK        : Vector2 = Vector2(28.0, 10.0)
const _MENU_REMOTE_PRESS_DROP  : float = 5.0
const _MENU_REMOTE_OUT_TIME    : float = 0.45
const _MENU_REMOTE_PRESS_TIME  : float = 0.08
const _MENU_REMOTE_RETURN_TIME : float = 0.40
# Suppress pizza spawns while this many seconds remain on the current TV clip
# — otherwise the remote animation and a pizza in flight can end up on screen
# at the same time.
const _MENU_PIZZA_TV_LOCKOUT   : float = 5.0

# ── Hit speech bubbles ───────────────────────────────────────────────────────
# Pop a random sticker above Normaldo's head when he takes damage. Same
# fade-in + scale-up + hold + fade-out shape as the intro-throw "ahh".
# Comic reaction stickers, addressable by name (show_reaction) and also folded
# into the random damage-pop pool below.
const REACTIONS : Dictionary = {
	"bam1":     preload("res://assets/ui/reactions/bam1.png"),
	"bam2":     preload("res://assets/ui/reactions/bam2.png"),
	"dang":     preload("res://assets/ui/reactions/dang.png"),
	"dangbang": preload("res://assets/ui/reactions/dangbang.png"),
	"kek":      preload("res://assets/ui/reactions/kek.png"),
	"lol":      preload("res://assets/ui/reactions/lol.png"),
	"oops":     preload("res://assets/ui/reactions/oops.png"),
	"pow":      preload("res://assets/ui/reactions/pow.png"),
}
# Пул выкриков переехал в scripts/phrases.gd и там же разделён по тону: победные
# на резист, болезненные на удар. Общая куча выдавала на удар «POW!» и «LOL» —
# то есть игра праздновала собственное попадание по игроку.
const _HIT_BUBBLE_OFFSET    : Vector2 = Vector2(0.0, -52.0)
# Выкрик приводится к одному ЭКРАННОМУ размеру по содержимому рисунка. Раньше
# стоял общий множитель 0.22 на кадр — а кадры у выкриков от 500 до 1016
# пикселей и с разными полями, и один и тот же набор выпадал то вдвое крупнее,
# то вдвое мельче соседнего.
const _HIT_BUBBLE_PX        : float   = 132.0
const _HIT_BUBBLE_START_SC  : float   = 0.30
const _HIT_BUBBLE_IN_TIME   : float   = 0.14
const _HIT_BUBBLE_HOLD_TIME : float   = 0.35
const _HIT_BUBBLE_OUT_TIME  : float   = 0.20

# ── Intro-throw sequence (game-start) ────────────────────────────────────────
const _INTRO_AHH_TEX        := preload("res://assets/normaldo/ahh.png")
# Hand origin for the thrown remote — same lap height as the menu remote.
# Clear of the right edge of Normaldo's silhouette (classic sprite reaches
# ~+32 from his centre, wider skins ~+50) so the remote sticks out where the
# eye can see it even though it draws behind him (z_index = -1).
const _INTRO_REMOTE_OFFSET  : Vector2 = Vector2(54.0, 6.0)
# "ahh" emote — small cloud that pops above Normaldo's head and vanishes.
const _INTRO_AHH_OFFSET     : Vector2 = Vector2(-4.0, -56.0)
const _INTRO_AHH_PEAK_SCALE : float   = 0.20
const _INTRO_AHH_START_SCALE: float   = 0.06
const _INTRO_AHH_IN_TIME    : float   = 0.18
const _INTRO_AHH_HOLD_TIME  : float   = 0.45
const _INTRO_AHH_OUT_TIME   : float   = 0.22
# Jump-off: small arc forward + up over mid-screen, lands at viewport centre.
const _INTRO_JUMP_RIGHT     : float   = 60.0
const _INTRO_JUMP_PEAK_UP   : float   = 90.0
const _INTRO_JUMP_UP_TIME   : float   = 0.32
const _INTRO_JUMP_DOWN_TIME : float   = 0.30


@onready var _sprite : Sprite2D = $Sprite2D
@onready var _gauge            = $StickGauge

var _base_scale     : Vector2 = Vector2.ONE
var fat_state       : int     = 0
var _pizza_count    : int   = 0
var _dead           : bool  = false
# Cause of the last hit, captured in _handle_obstacle for the analytics death
# event (cleared on each non-fatal hit; whatever's set when _die fires is what
# killed the player).
var _last_hit_group : String = ""
var _last_hit_name  : String = ""
var _invincible     : bool  = false
var _input_enabled  : bool  = false
var _fat_boss_active : bool = false   # ЖИРОБОСС mini-game in progress
var _fat_boss_factor : float = 1.0    # live size factor (1 = normal)
var _fat_boss_max    : float = 12.0   # пик размера этого забега (ставит fat_boss.gd)
var _run_shape       : Shape2D = null # боевой хитбокс, подменённый на время босса

# Насколько круг хитбокса босса уже нарисованной головы по высоте. Единица —
# круг ровно по овалу; чуть меньше, чтобы он гарантированно не торчал наружу.
const BOSS_HITBOX_INSET : float = 0.95
var _dev_immortal   : bool  = false  # dev toggle: no death on Skinny hit
var _bobbing        : bool  = false
# Public x-velocity (px/sec), updated each physics tick. Used by ceiling decor
# (e.g. lamps) to pick a swing direction when Normaldo brushes past them.
var velocity_x      : float = 0.0
var _prev_x         : float = 0.0
var _slow_remaining   : float = 0.0
var _slow_total       : float = 0.0
var _was_slowed       : bool  = false
var _invert_remaining : float = 0.0   # компас: реверс управления на N секунд
var _music_reversed   : bool  = false # играет ли реверс-трек во время компаса
const _MUSIC_FWD := preload("res://assets/audio/main_theme.mp3")
const _MUSIC_REV := preload("res://assets/audio/main_theme_reversed.mp3")
var _sway_t           : float = 0.0
var _magnet_remaining : float = 0.0
var _was_magnetic     : bool  = false

const COUCH_SEAT_OFFSET := Vector2(0, -20)  # положение относительно центра дивана

var _touching : bool = false
# Count of fingers currently down on the screen. The old code tracked a
# single bool from InputEventScreenTouch.pressed, which flipped to `false`
# the instant ANY finger released — even if a second finger was still down
# and actively dragging. Counting touches by index lets us keep accepting
# drag events from whichever finger is moving.
var _touch_count : int = 0

# Pizza-pack mini-game: confine Normaldo to the left region. `_region_max_x` < 0
# means no limit. Touches that START past it are ignored (so right-side taps spit
# pizza instead of dragging the head); we remember their finger index to also drop
# their drag/release events.
var _region_max_x    : float      = -1.0
var _ignored_touches : Dictionary = {}

var _couch              : Node2D = null
var _total_pizza_count  : int   = 0
var _dollars            : int   = 0
var _nearby_pizzas      : int   = 0
var _eating             : bool  = false
var _eat_timer          : float = 0.0
var _morphing           : bool  = false   # fat-morph spin in progress (owns the sprite)
var _bob_t              : float = 0.0
# Menu-idle decor: keeps Normaldo bobbing + lets a pizza occasionally slide in
# from one of his sides. Only runs while we're on the main menu; gameplay
# turns it off via stop_menu_idle().
var _menu_idle          : bool      = false
var _menu_pizza_timer   : float     = 0.0
var _menu_pizza         : Sprite2D  = null
var _menu_remote        : Sprite2D  = null
# Lazy reference to the Tv sibling — used to ask whether the current channel
# is about to flip so we can stop spawning pizzas during that window.
var _menu_tv_node       : Node      = null
var _audio              : AudioStreamPlayer
var _fat_audio          : AudioStreamPlayer
var _dollar_audio       : AudioStreamPlayer

# ── Skill system state ────────────────────────────────────────────────────────

var _skill_bonus_xp          : int   = 0
var _dracula_immortal_ready  : bool  = true
var _harry_second_chance_ready: bool = true
var _joker_doubled_skill     : int   = -1

# Wizard magic
const WIZARD_PIZZA_THRESHOLD : int = 50
var _wizard_run_pizzas   : int   = 0
var _wizard_bonus_active : bool  = false
var _wizard_bonus_timer  : float = 0.0
var _wizard_bonus_type   : int   = -1  # 0=magnet 1=xp_boost 2=speed_boost
var _wizard_aura         : CPUParticles2D = null

var _skill_audio : AudioStreamPlayer

# ── Skill SFX ────────────────────────────────────────────────────────────────

const _SKILL_SFX_DODGE     := preload("res://assets/audio/resist.mp3")
const _SKILL_SFX_COUNTER   := preload("res://assets/audio/dollars.mp3")
const _SKILL_SFX_TRANSFORM := preload("res://assets/audio/get_fat.mp3")

# ── NEW skin model runtime: resists / active ability / passive cooldowns ──────
const _PROJECTILE_SCRIPT := preload("res://scripts/skill_projectile.gd")
const _SMOKE_TEX         := preload("res://assets/bosses/ninja_foot/smoke.png")
const _WHEEL_TEX         := preload("res://assets/skills/ship_wheel.png")
const _CARD_TEX          := preload("res://assets/skills/card.png")
const _X3_TEX            := preload("res://assets/skills/x3.png")
const _CASEY_TEX         := preload("res://assets/items/casey_mask.png")
const _MAGIC_HAT_TEX     := preload("res://assets/items/magic_hat.png")
const _SFX_GLITTER       := preload("res://assets/audio/magic_glitter.mp3")   # transformus flight
const _SFX_POOF          := preload("res://assets/audio/magic_poof.mp3")      # item → pizza/dollar
const _ITEM_SCENE        := preload("res://scenes/item.tscn")
const _PIZZA_TEX         := preload("res://assets/items/pizza.png")
const _DOLLAR_TEX        := preload("res://assets/items/dollar.png")
const _RESIST_SFX        := preload("res://assets/audio/resist.mp3")
# На предмете остаётся ПАУТИНА, а не руки. Раньше сюда был подставлен
# big_shot.png — а это пара ладоней Спайди, и на залепленной бочке вырастали
# две красные руки неизвестно чьи. Паутина — последний кадр раскадровки, там
# она раскрыта полностью.
const _WEB_BIG_TEX       := preload("res://assets/skills/spider_man/web8.png")
const _WEB_HANDS_TEX     := preload("res://assets/skills/spider_man/big_shot.png")
# Кулак Викинга и перчатка Тайсона лежат в assets/skills/<скин>/ и рисуются
# прямо в позе каста (stateN_spell). Отдельными спрайтами их больше не спавним —
# именно от этого на экране получалось два кулака сразу.
# Лопатка Кусса. До приезда его архива тут стоял сюрикен ниндзя — спелл
# назывался «БРОСОК ЛОПАТКИ», а летела метательная звезда.
const _SHOVEL_TEX        := preload("res://assets/skills/kuss/spatula.png")
const _BIRD_TEX          := preload("res://assets/skills/halloween/blackbird.png")

# key -> [remaining, total]; keys: "resist:<tag>", "active", "passive:<id>"
var _skill_cd        : Dictionary = {}
var _resist_cd_for   : Dictionary = {}   # item tag -> cooldown seconds (открыт уровнем)
var _ability_cfg     : Dictionary = {}   # active ability dict ({} = none)
var _passive_id      : String     = ""
var _double_ryag     : bool        = false   # glasses: fires Рыгалити twice
var _active_charges  : int         = 1       # shots left before the cooldown
var _active_max_charges : int      = 1       # charges the ability recharges to
var _treasure_passive: bool        = false   # pirate: 50% x5 dollar
var _scars_passive   : bool        = false   # joker: invuln after fattening
var _skin_runtime_built : bool     = false   # _build_skin_runtime has run this run
var _scars_active    : bool        = false   # joker mask currently worn
var _scars_token     : int         = 0       # invalidates stale mask timers
var _scars_mask      : Sprite2D    = null
var _last_tap_t      : float       = -10.0
var _last_tap_pos    : Vector2     = Vector2.ZERO
const _DTAP_TIME : float = 0.20   # max gap between taps — must be a FAST double-tap
const _DTAP_DIST : float = 55.0   # taps must be close together (не путать с кайтом)

# ── Эффекты новых предметов ───────────────────────────────────────────────────
# Три эффекта живут таймерами и тикают в _physics_process. Длительность у всех
# короткая (3 c) намеренно: это «окно возможности», а не режим — за 3 секунды
# успеваешь продавить одну стену, но не пройти паттерн целиком.
#
#   шляпа мага  — _slow_immune_remaining, гасит apply_slow()
#   банка колы  — _speed_boost_remaining, множитель в _move_speed_mult()
#   маска Кейси — переиспользует механику шрамов Джокера (_begin_scars)
#
# См. /Концепция/Эффекты и бонусы.md
# Маска и шляпа держатся ВОСЕМЬ секунд, а не три. Три — это меньше, чем время
# между двумя волнами: подобрал, увидел надпись «НЕУЯЗВИМ!» — и эффект кончился,
# ни разу не пригодившись. Предмет, который нельзя РЕАЛИЗОВАТЬ, читается как
# ничего не делающий, сколько бы правды ни было написано в его описании.
#
# Восемь — это две-три волны: успеваешь и увидеть, что стал неуязвим, и решить,
# куда этим пролететь. Кола осталась на трёх: у неё эффект не «можно рискнуть»,
# а «быстрее двигаешься», и он читается сразу.
const CASEY_MASK_DURATION : float = 8.0
const MAGIC_HAT_DURATION  : float = 8.0
const COLA_DURATION       : float = 3.0
const COLA_SPEED_MULT     : float = 1.55

var _slow_immune_remaining : float = 0.0
var _speed_boost_remaining : float = 0.0

# ── Учёт добычи мини-игр ──────────────────────────────────────────────────────
# Пока учёт включён, каждая съеденная пицца и каждый доллар попадают ещё и в
# _loot_tally. В конце мини-игры бросается множитель ×1…×5 и разница
# доначисляется — см. loot_multiplier.gd.
var _loot_tally_active : bool = false
var _loot_pizza_tally  : int  = 0
var _loot_dollar_tally : int  = 0

# ─────────────────────────────────────────────────────────────────────────────

func _apply_skin_to_sprite() -> void:
	_sprite.texture = _skin_tex[fat_state]
	_base_scale     = _head_scale()
	_sprite.scale   = _base_scale
	_apply_head_offset()
	_refresh_wings()

# Масштаб считается так, чтобы ГОЛОВА была одного размера у всех скинов, но
# силуэт целиком не вылезал за коробку MAX_BODY. Раньше нормировали ширину
# КАДРА, и скины с руками выходили мельче: у Джокера голова занимает 27 % кадра,
# то есть была почти втрое меньше классической. Одна лишь нормировка головы
# перегибала в другую сторону — Гарри и Джокер вырастали в два лейна.
# Вся арифметика и замеры — в skin_metrics.gd.
func _head_scale() -> Vector2:
	var tex : Texture2D = _skin_tex[fat_state]
	if tex == null:
		return Vector2.ONE
	var s : float = SkinMetrics.sprite_scale(SaveData.active_skin, fat_state, tex.get_size())
	return Vector2(s, s)

# Голова в кадре бывает смещена от центра (у Гарри, Мага и Кусса — заметно), а
# хитбокс сидит в начале координат. Сдвигаем спрайт так, чтобы голова села
# именно на хитбокс, иначе удар засчитывается «по воздуху» рядом с ней.
func _apply_head_offset() -> void:
	var tex : Texture2D = _skin_tex[fat_state]
	if tex == null:
		return
	var pos : Vector2
	if SaveData.active_skin == "classic" and not _fat_boss_active:
		# У классики в кадре только голова, но нарисована со сдвигом влево.
		# Правка ручная, в пикселях забега. На ЖИРОБОССЕ она умножается на
		# множитель размера и уводит лицо за левый край — там берём замер.
		pos = Vector2(-14.0, 0.0)
	else:
		var sz  : Vector2 = tex.get_size()
		var off := SkinMetrics.offset_for(SaveData.active_skin, fat_state)
		pos = Vector2(-off.x * sz.x * _base_scale.x, -off.y * sz.y * _base_scale.y)
	_sprite.position = pos
	_recalc_head_anchor(tex, pos)

# Точка, в которой стоит ЦЕНТР ГОЛОВЫ обычного кадра. К ней прикалываются кадры
# варианта (см. _place_head): у них своя рамка, и без якоря голова на подмене
# уезжает вбок — у классики «доллары в глазах» прыгали на четверть ширины.
#
# Якорь берёт ОБЕ координаты посадки, и вертикаль в том числе.
#
# Долго стояло `y = 0` с объяснением «вертикаль всё равно приводится к нулю,
# покачивание владеет y». Объяснение было кольцевым: к нулю она приводилась
# ровно потому, что якорь и был нулём, — а смысл `_apply_head_offset` в том,
# чтобы посадить НАРИСОВАННУЮ ГОЛОВУ на хитбокс. Обнуляя вертикаль, мы сажали
# на хитбокс центр КАДРА, и у скинов, где голова заметно выше центра рисунка,
# хитбокс оказывался под подбородком: у Кусса на третьем жире голова выше
# центра кадра на 21 % — это больше половины хитбокса, и удары шли по пузу.
#
# Покачивание при этом ничего не теряет: оно колеблется вокруг `_head_home`,
# а не вокруг нуля (см. `_physics_process`), — то есть вокруг правильной
# посадки.
func _recalc_head_anchor(tex: Texture2D, pos: Vector2) -> void:
	var sz  : Vector2 = tex.get_size()
	var off := SkinMetrics.offset_for(SaveData.active_skin, fat_state)
	_head_idle_pos = pos
	_head_anchor   = _head_idle_pos + Vector2(
		off.x * sz.x * _base_scale.x, off.y * sz.y * _base_scale.y)
	_head_home     = _head_idle_pos

# Swap the sprite to the current fat-state texture + recompute _base_scale, WITHOUT
# touching the live scale (the morph tween drives scale itself). Returns the base.
func _refresh_fat_sprite() -> Vector2:
	_sprite.texture = _skin_tex[fat_state]
	_base_scale     = _head_scale()
	_apply_head_offset()
	return _base_scale

# Fat-change morph: the head spins CLOCKWISE down to a point, swaps to the new fat
# sprite at the point, then spins back out at full size. Used on every fattening
# (normal eating + the slots golden-pizza), so it's the universal "got fat" beat.
func play_fat_morph() -> void:
	if not is_instance_valid(_sprite):
		return
	_morphing = true
	var spr := _sprite
	var start_rot := spr.rotation
	var tw := create_tween()
	tw.tween_property(spr, "scale", Vector2.ZERO, 0.16) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(spr, "rotation", start_rot + TAU, 0.16) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		if not is_instance_valid(spr):
			_morphing = false
			return
		var bs := _refresh_fat_sprite()
		spr.scale = Vector2.ZERO
		var t2 := create_tween()
		t2.tween_property(spr, "scale", bs, 0.26) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t2.parallel().tween_property(spr, "rotation", start_rot + TAU * 2.0, 0.26) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t2.tween_callback(func():
			if is_instance_valid(spr):
				spr.rotation = 0.0
			_morphing = false))

# СЛОТЫ golden pizza: jump straight to the LAST fat state (one morph), regardless
# of the pizza count (and bump the count so it persists past the next eaten pizza).
func fatten_to_max() -> void:
	var target : int = _skin_tex.size() - 1
	if fat_state >= target:
		return
	fat_state = target
	if target - 1 < FAT_THRESHOLDS.size():
		_pizza_count = maxi(_pizza_count, FAT_THRESHOLDS[target - 1])
	_fat_audio.play()
	stats_changed.emit(fat_state, _pizza_count, _total_pizza_count)
	play_fat_morph()

func _ready() -> void:
	_load_skin(SaveData.active_skin)
	_couch    = get_parent().get_node("Couch")
	position  = _couch.menu_position() + COUCH_SEAT_OFFSET
	area_entered.connect(_on_area_entered)
	_apply_skin_to_sprite()

	# AudioStreamPlayer — создаём программно
	_audio = AudioStreamPlayer.new()
	_audio.volume_db = -4.0
	add_child(_audio)

	_fat_audio = AudioStreamPlayer.new()
	_fat_audio.stream    = _skin_fat_sfx if _skin_fat_sfx else _CLASSIC_FAT_SFX
	_fat_audio.volume_db = -10.0
	add_child(_fat_audio)

	_dollar_audio = AudioStreamPlayer.new()
	_dollar_audio.stream    = DOLLAR_SOUND
	_dollar_audio.volume_db = 2.0
	add_child(_dollar_audio)

	_skill_audio = AudioStreamPlayer.new()
	_skill_audio.volume_db = -6.0
	add_child(_skill_audio)

	# ProximityArea — большой радиус для детекта пиццы рядом (открытие рта)
	var prox          := Area2D.new()
	prox.name          = "ProximityArea"
	prox.collision_layer = 0
	prox.collision_mask  = 2
	prox.monitorable     = false
	var prox_col      := CollisionShape2D.new()
	var prox_circle   := CircleShape2D.new()
	prox_circle.radius = PROXIMITY_RADIUS
	prox_col.shape     = prox_circle
	prox.add_child(prox_col)
	add_child(prox)
	prox.area_entered.connect(_on_pizza_nearby)
	prox.area_exited.connect(_on_pizza_left)

func reload_skin() -> void:
	_load_skin(SaveData.active_skin)
	_apply_skin_to_sprite()
	_fat_audio.stream = _skin_fat_sfx if _skin_fat_sfx else _CLASSIC_FAT_SFX
	_dracula_immortal_ready    = true
	_harry_second_chance_ready = true

func enable_input() -> void:
	_input_enabled = true
	# Kill the lingering couch-idle bob — once the run starts, the head should
	# sit steady. Leaving _bobbing on (set by Couch.start_game → start_bob)
	# kept the menu wobble running through gameplay.
	_bobbing = false
	_bob_t   = 0.0
	if is_instance_valid(_sprite):
		_sprite.position.y = _head_home.y
	_skill_bonus_xp = 0
	_dracula_immortal_ready    = true
	_harry_second_chance_ready = true
	_wizard_run_pizzas   = 0
	_wizard_bonus_active = false
	_wizard_bonus_type   = -1
	_wizard_cleanup_aura()
	_joker_doubled_skill = -1
	_last_tap_t = -10.0
	_build_skin_runtime()
	unique_ability_changed.emit(true)

func disable_input() -> void:
	_input_enabled = false

func is_input_enabled() -> bool:
	return _input_enabled

# ── ЖИРОБОСС mini-game hooks (driven by fat_boss.gd) ──────────────────────────
# begin: lock control + go invincible, clear transient debuffs and the gauge.
# set_fat_boss_factor: scale the WHOLE Area2D (sprite + collision) so the huge
#   head also eats everything near it. factor 1.0 = normal size.
# end: restore normal scale, control and vulnerability.

# ── Размер и хитбокс ЖИРОБОССА ────────────────────────────────────────────────
# Раньше босс раздувался фиксированным ×12 на любом скине. Голова классики при
# этом выходила 1092 px в ширину на экране 960×430 — лица не видно вовсе,
# зелёное пятно во весь кадр, и у каждого скина свой размер, потому что головы
# разного соотношения сторон.
#
# Теперь множитель считается ПОД ЭКРАН: голова растягивается до заданной высоты,
# одинаковой для всех скинов и состояний жира. Голова ставится центром ровно на
# левый край кадра, поэтому видно ровно её правую половину — половину лица.
func boss_face_factor(target_h: float) -> float:
	var h : float = _boss_head_px().y
	if h <= 1.0:
		return 6.0
	return clampf(target_h / h, 1.5, 40.0)

# Публичная обёртка: fat_boss.gd считает по ней якорь — насколько отодвинуть
# центр головы от края, чтобы на экране было три четверти лица.
func boss_head_px() -> Vector2:
	return _boss_head_px()

# Размер нарисованной головы в экранных пикселях при масштабе 1 — по замеру
# ИМЕННО ЭТОГО состояния жира.
func _boss_head_px() -> Vector2:
	var tex : Texture2D = _skin_tex[fat_state]
	if tex == null:
		return Vector2(64.0, 64.0)
	var sz : Vector2 = tex.get_size()
	var fr : Vector2 = SkinMetrics.head_size_for(SaveData.active_skin, fat_state)
	return Vector2(fr.x * sz.x * _base_scale.x, fr.y * sz.y * _base_scale.y)

# Хитбокс босса — круг, ВПИСАННЫЙ в нарисованную голову по высоте.
#
# Круг радиусом с полуширину головы торчал бы сверху и снизу за нарисованный
# овал (у классики голова 683×451 на экране), и предметы лопались бы в пустоте
# перед лицом — «об невидимую стену». Вписанный по высоте круг ошибается в
# другую сторону: предмет чуть утопает в лице, прежде чем исчезнуть, и это
# читается как «съеден», а не как стена.
func boss_head_radius() -> float:
	var hp : Vector2 = _boss_head_px()
	# По МЕНЬШЕЙ стороне: круг обязан помещаться в овал головы и по ширине, и по
	# высоте. У Кусса и Мага голова выше, чем шире, — вписывай только по высоте, и
	# круг вылезет по бокам.
	return maxf(8.0, minf(hp.x, hp.y) * 0.5 * BOSS_HITBOX_INSET)

func _set_hitbox_radius(radius: float) -> void:
	var cs := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if cs == null:
		return
	if _run_shape == null:
		_run_shape = cs.shape          # боевой хитбокс забега, вернём его в конце
	var c := CircleShape2D.new()
	c.radius = radius
	cs.shape = c

func _restore_hitbox() -> void:
	var cs := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if cs == null or _run_shape == null:
		return
	cs.shape = _run_shape

func begin_fat_boss() -> void:
	_set_hitbox_radius(boss_head_radius())
	_fat_boss_active  = true
	_apply_head_offset()   # у классики на боссе своя посадка головы (см. ниже)
	_input_enabled    = false
	_invincible       = true
	_touching         = false
	_touch_count      = 0
	_slow_remaining   = 0.0
	_magnet_remaining = 0.0
	_cleanup_attract_sparks()
	if is_instance_valid(_gauge) and _gauge.has_method("hide_gauge"):
		_gauge.hide_gauge()

func set_fat_boss_factor(f: float) -> void:
	scale = Vector2(f, f)
	_fat_boss_factor = f

# Пик размера этого забега — от него считается низкий питч чавканья.
func set_fat_boss_max(f: float) -> void:
	_fat_boss_max = maxf(f, 1.01)

# Eat-sfx pitch: lowest at max size, back to normal as he deflates. Пик размера
# теперь считается под скин, поэтому опорная точка приходит из fat_boss.gd.
func _eat_pitch() -> float:
	if not _fat_boss_active:
		return 1.0
	return clampf(remap(_fat_boss_factor, 1.0, _fat_boss_max, 1.0, 0.72), 0.72, 1.0)

func set_fat_boss_rotation(r: float) -> void:
	rotation = r

func end_fat_boss() -> void:
	_restore_hitbox()
	_fat_boss_active = false
	_apply_head_offset()
	scale            = Vector2.ONE
	rotation         = 0.0
	_fat_boss_factor = 1.0
	_invincible      = false
	_input_enabled   = true
	self.modulate    = Color(1.0, 1.0, 1.0)
	_audio.pitch_scale = 1.0   # clear any low pitch left from the mini-game

# Credit the mini-game's tallied loot to the run score in one shot, after the
# end fly-in. Mirrors _eat_pizza / _collect_dollar bookkeeping (fat_state bump
# + signals) without the per-item animation/sfx spam of calling them N times.
func fat_boss_award(pizzas: int, dollars: int) -> void:
	if pizzas > 0:
		_pizza_count       += pizzas
		_total_pizza_count += pizzas
		var new_state := fat_state
		for i in FAT_THRESHOLDS.size():
			if _pizza_count >= FAT_THRESHOLDS[i]:
				new_state = i + 1
		fat_state = maxi(fat_state, mini(new_state, _max_fat_state()))
		stats_changed.emit(fat_state, _pizza_count, _total_pizza_count)
	if dollars > 0:
		_dollars += dollars
		dollars_changed.emit(_dollars)
	if pizzas > 0 or dollars > 0:
		_pulse_fat()

# ── Pizza-pack mini-game: confine to the left region ──────────────────────────
# Clamp the head to x ≤ max_x and stop right-region touches from moving it (they
# spit pizza instead). Control + damage stay ON — he must dodge in the left part.
func set_left_region(max_x: float) -> void:
	_region_max_x = max_x

func clear_left_region() -> void:
	_region_max_x = -1.0
	_ignored_touches.clear()

# ── СЛОТЫ mini-game: free drag off, column-driven externally, stays vulnerable ─
func begin_slots_mode() -> void:
	_input_enabled    = false
	_invincible       = false
	_touching         = false
	_touch_count      = 0
	_slow_remaining   = 0.0
	_magnet_remaining = 0.0
	_region_max_x     = -1.0
	_ignored_touches.clear()
	# Make sure resists / active / passive are configured for this skin so they
	# work during the top-down slots mini-game too (covers dev-launched runs
	# where enable_input()/_build_skin_runtime() may not have fired).
	if not _skin_runtime_built:
		_build_skin_runtime()

func end_slots_mode() -> void:
	_input_enabled   = true
	_sprite.rotation = 0.0

# Arc jump to `target` with a full somersault (кувырок). Returns the position
# tween so the caller can await the landing.
func slots_intro_jump(target: Vector2) -> Tween:
	var peak := Vector2((position.x + target.x) * 0.5, minf(position.y, target.y) - 90.0)
	var jt := create_tween()
	jt.tween_property(self, "position", peak, 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	jt.tween_property(self, "position", target, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	var st := create_tween()
	st.tween_property(_sprite, "rotation", TAU, 0.60).set_trans(Tween.TRANS_LINEAR)
	st.tween_callback(func():
		if is_instance_valid(_sprite):
			_sprite.rotation = 0.0)
	return jt

func start_bob() -> void:
	_bobbing = true
	_bob_t   = 0.0

# ── Menu idle: bob + occasional pizza emerging from behind ──────────────────
# Called by HUD when the main-menu screen is up. Drives a subtle sway
# (via existing _bobbing) and schedules a pizza prop to spawn every few
# seconds. Tapping into the same eat-animation + SFX makes the moment feel
# native instead of bolted on.
func start_menu_idle() -> void:
	_menu_idle        = true
	_bobbing          = true
	_bob_t            = 0.0
	_menu_pizza_timer = randf_range(_MENU_PIZZA_INTERVAL_MIN, _MENU_PIZZA_INTERVAL_MAX)

func stop_menu_idle() -> void:
	_menu_idle = false
	_bobbing   = false
	if is_instance_valid(_menu_pizza):
		_menu_pizza.queue_free()
	_menu_pizza = null
	if is_instance_valid(_menu_remote):
		_menu_remote.queue_free()
	_menu_remote = null

# Triggered by the TV node 3 seconds before its current track ends. Pulls a
# remote-control sprite out of Normaldo's "lap", does a tiny press jerk, then
# slides it back. The press jerk emits menu_remote_button_pressed which the
# TV listens to so the audio swap is frame-synced with the on-screen click.
func play_tv_remote_anim() -> void:
	if not _menu_idle or is_instance_valid(_menu_remote):
		return
	var remote := Sprite2D.new()
	remote.texture        = _MENU_REMOTE_TEX
	remote.scale          = Vector2.ONE * _MENU_REMOTE_SCALE
	remote.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# New asset already points east (toward the TV) — no flip required.
	# Sits in FRONT of Normaldo's body (he's holding it out to the side).
	remote.z_index        = 1
	remote.position       = Vector2.ZERO
	add_child(remote)
	_menu_remote = remote

	var peak     := _MENU_REMOTE_PEAK
	var pressed  := peak + Vector2(0.0, _MENU_REMOTE_PRESS_DROP)

	var tw := create_tween()
	# Phase 1: slide out from behind to the peak (held toward TV).
	tw.tween_property(remote, "position", peak, _MENU_REMOTE_OUT_TIME)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# Phase 2a: jerk down — Normaldo presses the button.
	tw.tween_property(remote, "position", pressed, _MENU_REMOTE_PRESS_TIME)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# Press moment — TV listens to this and swaps tracks in lock-step.
	tw.tween_callback(func(): menu_remote_button_pressed.emit())
	# Phase 2b: jerk back up.
	tw.tween_property(remote, "position", peak, _MENU_REMOTE_PRESS_TIME)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Phase 3: retract back behind body.
	tw.tween_property(remote, "position", Vector2.ZERO, _MENU_REMOTE_RETURN_TIME)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(func():
		if is_instance_valid(remote):
			remote.queue_free()
		_menu_remote = null
	)

# Spawns the thrown remote at Normaldo's hand and returns it to the caller as
# a free Sprite2D parented to Normaldo's parent (the scene root). The caller
# tweens it toward the TV and frees it on impact. z_index sits behind the TV
# so the remote visually disappears when it slides under the screen.
func spawn_thrown_remote() -> Sprite2D:
	# Yank the menu-remote out of the way first — otherwise the lap one and
	# the thrown one render on top of each other for the first frame.
	if is_instance_valid(_menu_remote):
		_menu_remote.queue_free()
		_menu_remote = null
	var rem := Sprite2D.new()
	rem.texture        = _MENU_REMOTE_TEX
	rem.scale          = Vector2.ONE * _MENU_REMOTE_SCALE
	rem.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Sits below the TV (z 2) but above the Background (z 0) — the offset is
	# tuned so the remote sticks out past Normaldo's silhouette, so it still
	# reads as "leaving his hand" even though Normaldo (z 3) draws over it.
	rem.z_index        = 1
	# Add to the scene root FIRST, then set global_position — assigning the
	# global property before the node is in the tree silently degrades to a
	# plain local-position write, which lands the remote at (0,0) of the root.
	get_parent().add_child(rem)
	rem.global_position = global_position + _INTRO_REMOTE_OFFSET
	return rem

# Pops the "ahh" emote above Normaldo's head: fade-in + scale-up, brief hold,
# then fade-out + scale-down. Self-frees when the tween completes.
func spawn_ahh_emote() -> void:
	var ahh := Sprite2D.new()
	ahh.texture        = _INTRO_AHH_TEX
	ahh.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	ahh.position       = _INTRO_AHH_OFFSET
	ahh.scale          = Vector2.ONE * _INTRO_AHH_START_SCALE
	ahh.modulate       = Color(1.0, 1.0, 1.0, 0.0)
	ahh.z_index        = 5
	add_child(ahh)

	var tw := create_tween()
	tw.tween_property(ahh, "modulate:a", 1.0, _INTRO_AHH_IN_TIME)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(ahh, "scale", Vector2.ONE * _INTRO_AHH_PEAK_SCALE, _INTRO_AHH_IN_TIME)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(_INTRO_AHH_HOLD_TIME)
	tw.tween_property(ahh, "modulate:a", 0.0, _INTRO_AHH_OUT_TIME)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(ahh, "scale", Vector2.ONE * _INTRO_AHH_START_SCALE, _INTRO_AHH_OUT_TIME)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		if is_instance_valid(ahh):
			ahh.queue_free()
	)

# Two-phase arc up-and-forward, then down to mid-screen. While airborne the
# sprite does a full flip so the jump reads as a tumble, not a slide.
# Returns the await-able final Tween so the caller can hand off to input.
func play_intro_jump() -> Tween:
	var vp     := get_viewport_rect()
	var land   := Vector2(position.x + _INTRO_JUMP_RIGHT, vp.get_center().y)
	var peak   := Vector2((position.x + land.x) * 0.5, land.y - _INTRO_JUMP_PEAK_UP)

	var jump_tw := create_tween()
	jump_tw.tween_property(self, "position", peak, _INTRO_JUMP_UP_TIME)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	jump_tw.tween_property(self, "position", land, _INTRO_JUMP_DOWN_TIME)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	# Full somersault timed to match the whole arc — kicked off in parallel so
	# the sprite tumbles while the position tween carries it through the peak.
	var spin_tw := create_tween()
	spin_tw.tween_property(_sprite, "rotation", TAU, _INTRO_JUMP_UP_TIME + _INTRO_JUMP_DOWN_TIME)\
		.set_trans(Tween.TRANS_LINEAR)
	spin_tw.tween_callback(func():
		if is_instance_valid(_sprite):
			_sprite.rotation = 0.0
	)
	return jump_tw

func _tick_menu_idle(delta: float) -> void:
	if not _menu_idle:
		return
	# Only schedule a new pizza if the previous one has finished its lifecycle,
	# the remote isn't currently out, and the TV isn't about to flip channels.
	# Otherwise the remote click and a pizza in flight overlap on screen.
	if is_instance_valid(_menu_pizza):
		return
	if is_instance_valid(_menu_remote):
		return
	if _is_tv_near_channel_swap():
		return
	_menu_pizza_timer -= delta
	if _menu_pizza_timer <= 0.0:
		_spawn_menu_pizza()
		_menu_pizza_timer = randf_range(_MENU_PIZZA_INTERVAL_MIN, _MENU_PIZZA_INTERVAL_MAX)

func _is_tv_near_channel_swap() -> bool:
	if _menu_tv_node == null:
		var parent := get_parent()
		if parent != null:
			_menu_tv_node = parent.get_node_or_null("Tv")
	if _menu_tv_node == null:
		return false
	# TV exposes its AudioStreamPlayer as `_tv_audio`. We read it via .get() to
	# avoid a tight class-level dependency.
	var audio = _menu_tv_node.get("_tv_audio")
	if audio == null or not audio.playing:
		return false
	var stream = audio.stream
	if stream == null:
		return false
	var total : float = stream.get_length()
	if total <= 0.0:
		return false
	var remaining : float = total - audio.get_playback_position()
	return remaining <= _MENU_PIZZA_TV_LOCKOUT

func _spawn_menu_pizza() -> void:
	var pizza := Sprite2D.new()
	pizza.texture        = _MENU_PIZZA_TEX
	pizza.scale          = Vector2.ONE * _MENU_PIZZA_SCALE
	pizza.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Phase 1 — pizza emerges from BEHIND Normaldo's sprite (z_index = -1),
	# starting at his centre so the body fully hides it before it slides out.
	pizza.z_index        = -1
	var side : float = 1.0 if randf() < 0.5 else -1.0
	# Mirror the slice when it spawns from the LEFT side so its visual
	# orientation reads as "facing Normaldo" rather than away from him.
	pizza.flip_h = side < 0.0
	pizza.position = Vector2.ZERO
	add_child(pizza)
	_menu_pizza = pizza

	# Diagonal peak: out to the side and slightly up — not a flat horizontal slide.
	var peak := Vector2(side * _MENU_PIZZA_OFFSET_X, _MENU_PIZZA_OFFSET_Y)

	var tw := create_tween()
	# Phase 1: emerge from behind to the peak. Slower, eases out so it lingers
	# briefly at the high point before being pulled back.
	tw.tween_property(pizza, "position", peak, _MENU_PIZZA_OUT_TIME)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# Snap the pizza IN FRONT of Normaldo for the return leg so it visibly
	# crosses over his silhouette into his mouth instead of sliding through it.
	tw.tween_callback(func():
		if is_instance_valid(pizza):
			pizza.z_index = 1
	)
	# Phase 2: rocket back to his mouth — faster, accelerating in.
	tw.tween_property(pizza, "position", Vector2.ZERO, _MENU_PIZZA_IN_TIME)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(Callable(self, "_eat_pizza_menu"))
	tw.tween_callback(Callable(pizza, "queue_free"))

# Like _eat_pizza() but without any of the gameplay side-effects (no fat
# state, no XP, no quest counters). Just the visual + SFX.
func _eat_pizza_menu() -> void:
	if not is_instance_valid(self):
		return
	if not _skin_eat_sfx.is_empty():
		_audio.stream = _skin_eat_sfx[randi() % _skin_eat_sfx.size()]
		_audio.play()
	_eating         = true
	_eat_timer      = EAT_ANIM_TIME
	_show_eat_frame()

# Кадр поедания. Отдельной функцией, потому что анимация еды НЕ проходит через
# _update_mouth (тот выходит при _eating) и раньше писала обычный кадр напрямую:
# Дракула под невидимостью проявлялся на каждой съеденной пицце.
func _show_eat_frame() -> void:
	var variant := "_eat"
	if _ghost_active and fat_state < _skin_ghost_eat_tex.size() \
			and _skin_ghost_eat_tex[fat_state] != null:
		variant = "_ghost_eat"
	_show_head(_head_tex(true), variant)

func set_tilt(angle: float, duration: float) -> void:
	var tw := create_tween()
	tw.tween_property(_sprite, "rotation", angle, duration) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func move_to(target: Vector2, duration: float) -> void:
	var tw := create_tween()
	tw.tween_property(self, "position", target, duration) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func fly_to_seat(duration: float) -> void:
	if not _couch:
		return
	var target := _couch.get_viewport_rect().get_center() + COUCH_SEAT_OFFSET
	var tw := create_tween()
	tw.tween_property(self, "position", target, duration) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

func _load_skin(skin_id: String) -> void:
	# Смена скина посреди невидимости оставила бы признак призрака поднятым, и
	# новая голова приехала бы серой — а серых кадров у неё может не быть вовсе.
	_ghost_active = false
	_drop_wings()
	var skin := SkinRegistry.get_skin(skin_id)
	var tex_dir : String = skin.get("tex_dir", "")
	var aud_dir : String = skin.get("audio_dir", "")

	if tex_dir.is_empty():
		_skin_tex       = _CLASSIC_TEX.duplicate()
		_skin_eat_tex   = _CLASSIC_EAT_TEX.duplicate()
		_skin_spell_tex = [null, null, null, null]
		_skin_spell2_tex    = [null, null, null, null]
		_skin_ghost_tex     = [null, null, null, null]
		_skin_ghost_eat_tex = [null, null, null, null]
	else:
		_skin_tex     = []
		_skin_eat_tex = []
		_skin_spell_tex = []
		_skin_spell2_tex    = []
		_skin_ghost_tex     = []
		_skin_ghost_eat_tex = []
		for i in 4:
			_skin_tex.append(    load(tex_dir + "state%d.png"     % (i + 1)))
			_skin_eat_tex.append(load(tex_dir + "state%d_eat.png" % (i + 1)))
			# Поза каста есть не у всех скинов — только у тех, чьи архивы уже
			# приехали. Нет файла → в массиве null, и поза просто не играется.
			# У Спайдера каст нарисован направленным (_spell_l / _spell_r) и
			# ненаправленного варианта на части состояний нет — берём правый.
			var sp := ""
			for suffix in ["_spell", "_spell_r", "_spell_l"]:
				var cand := tex_dir + "state%d%s.png" % [i + 1, suffix]
				if ResourceLoader.exists(cand):
					sp = cand
					break
			_skin_spell_tex.append(load(sp) if sp != "" else null)
			# Второй кадр позы — есть только у Очков: там каст нарисован в два
			# шага, «пьёт банку» и «скалится». Нет файла → поза одноходовая.
			var sp2 := tex_dir + "state%d_spell2.png" % (i + 1)
			_skin_spell2_tex.append(load(sp2) if ResourceLoader.exists(sp2) else null)
			# Призрачные кадры Дракулы: серые версии покоя и поедания, которыми
			# он подменяется на время невидимости.
			var gh  := tex_dir + "state%d_ghost.png"     % (i + 1)
			var ghe := tex_dir + "state%d_ghost_eat.png" % (i + 1)
			_skin_ghost_tex.append(load(gh) if ResourceLoader.exists(gh) else null)
			_skin_ghost_eat_tex.append(load(ghe) if ResourceLoader.exists(ghe) else null)

	if aud_dir.is_empty():
		_skin_eat_sfx = _CLASSIC_EAT_SFX.duplicate()
		_skin_hit_sfx = _CLASSIC_HIT_SFX
		_skin_fat_sfx = _CLASSIC_FAT_SFX
	else:
		_skin_eat_sfx = []
		for f in ["eat1.mp3", "eat2.mp3"]:
			var p = aud_dir + f
			if ResourceLoader.exists(p):
				_skin_eat_sfx.append(load(p))
		if _skin_eat_sfx.is_empty():
			_skin_eat_sfx = _CLASSIC_EAT_SFX.duplicate()
		var hp := aud_dir + "hit.mp3"
		_skin_hit_sfx = load(hp) if ResourceLoader.exists(hp) else _CLASSIC_HIT_SFX
		var fp := aud_dir + "fat.mp3"
		_skin_fat_sfx = load(fp) if ResourceLoader.exists(fp) else _CLASSIC_FAT_SFX

# ── Skill speed helpers ───────────────────────────────────────────────────────

func _effective_fat_speed(state: int) -> float:
	var base = FAT_SPEED_MULT[state]
	if SaveData.active_skin == "glasses":
		var penalty = 1.0 - base
		return 1.0 - penalty * 0.5
	return base

func _move_speed_mult() -> float:
	# Банка колы складывается с бонусами скинов — она короткая (3 c) и должна
	# ощущаться рывком даже на быстром скине.
	var boost := COLA_SPEED_MULT if _speed_boost_remaining > 0.0 else 1.0
	if SaveData.active_skin == "spider_man":
		return 1.25 * boost
	if _wizard_bonus_active and _wizard_bonus_type == 2:
		return 1.4 * boost
	return boost

# ── Input ─────────────────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if _dead or not _input_enabled:
		return
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		# Increment/decrement on each finger touch so alternating thumbs
		# (very common for fast play) don't reset the active state when one
		# finger releases while the other is still dragging.
		if t.pressed:
			# Right-region touch (pizza mini-game) → not for movement; remember it.
			if _region_max_x >= 0.0 and t.position.x > _region_max_x:
				_ignored_touches[t.index] = true
				return
			# Double-tap → fire the active ability toward the tap point.
			if _touch_on_cone(t.position):
				_ignored_touches[t.index] = true
				return
			var now := Time.get_ticks_msec() / 1000.0
			if now - _last_tap_t <= _DTAP_TIME and t.position.distance_to(_last_tap_pos) <= _DTAP_DIST:
				_last_tap_t = -10.0
				_try_fire_ability(t.position)
			else:
				_last_tap_t   = now
				_last_tap_pos = t.position
			_touch_count += 1
		else:
			if _ignored_touches.erase(t.index):
				return
			_touch_count = maxi(0, _touch_count - 1)
		_touching = _touch_count > 0
	elif event is InputEventScreenDrag:
		# Any drag event implies *some* finger is moving — feed all of them
		# into the position update so the head responds smoothly even when
		# two fingers are down at once. event.relative is per-finger.
		var d := event as InputEventScreenDrag
		if _ignored_touches.has(d.index):
			return
		if _dash_active:
			return   # рывком управляет тюин, палец в это время не тянет голову
		if _touch_count > 0:
			var speed = _effective_fat_speed(fat_state) * _move_speed_mult() * (SLOW_MULTIPLIER if _slow_remaining > 0.0 else 1.0)
			if _invert_remaining > 0.0:
				speed = -speed   # компас: свайп в одну сторону двигает в другую (и по X, и по Y)
			position  += d.relative * speed
			var s      := get_viewport_rect().size
			var xmax    : float = s.x if _region_max_x < 0.0 else minf(_region_max_x, s.x)
			position.x = clampf(position.x, 0.0, xmax)
			position.y = clampf(position.y, 0.0, s.y)

func _physics_process(delta: float) -> void:
	if _dead:
		return

	_update_web_line()
	_update_dash_trail()
	_sweep_dash_loot()
	_tick_skill_cd(delta)

	# Eat animation timer
	if _eat_timer > 0.0:
		_eat_timer -= delta
		if _eat_timer <= 0.0:
			_eating = false
			_update_mouth()

	# Schedule and tick the menu-idle pizza prop.
	_tick_menu_idle(delta)

	# Slow countdown + state change detection
	if _slow_remaining > 0.0:
		_slow_remaining -= delta
	if _slow_immune_remaining > 0.0:
		_slow_immune_remaining -= delta
	if _speed_boost_remaining > 0.0:
		_speed_boost_remaining -= delta
	if _invert_remaining > 0.0:
		_invert_remaining -= delta
		if _invert_remaining <= 0.0 and _music_reversed:
			_set_music_reversed(false)
	var is_slowed := _slow_remaining > 0.0
	if is_slowed != _was_slowed:
		_was_slowed = is_slowed
		if is_slowed:
			_on_slow_start()
		else:
			_on_slow_end()

	# Wizard bonus countdown
	if _wizard_bonus_active:
		_wizard_bonus_timer -= delta
		if _wizard_bonus_timer <= 0.0:
			_wizard_bonus_active = false
			_wizard_bonus_type   = -1
			_wizard_cleanup_aura()
			wizard_state_changed.emit(_wizard_run_pizzas % WIZARD_PIZZA_THRESHOLD, false, -1, 0.0)
		else:
			wizard_state_changed.emit(_wizard_run_pizzas % WIZARD_PIZZA_THRESHOLD, true, _wizard_bonus_type, _wizard_bonus_timer)

	var s := get_viewport_rect().size
	var xmax : float = s.x if _region_max_x < 0.0 else minf(_region_max_x, s.x)
	position.x = clampf(position.x, 0.0, xmax)
	position.y = clampf(position.y, 0.0, s.y)
	if delta > 0.0:
		velocity_x = (position.x - _prev_x) / delta
	_prev_x = position.x

	# Bob: only while the couch-idle flag is set (menu / pre-run). Gameplay
	# clears it in enable_input() so the head stays steady during the run.
	# Целимся не в ноль, а в посадку ТЕКУЩЕГО кадра: у кадров-вариантов она своя,
	# и покачивание, целясь в ноль, стирало бы вертикальную поправку.
	if _bobbing:
		_bob_t += delta * 1.8
		_sprite.position.y = lerp(_sprite.position.y, _head_home.y + sin(_bob_t) * 3.0, 0.15)
	else:
		_sprite.position.y = lerp(_sprite.position.y, _head_home.y, 0.20)

	# Магнит — притягивает пиццы и доллары
	var is_magnetic := _magnet_remaining > 0.0
	if is_magnetic != _was_magnetic:
		_was_magnetic = is_magnetic
		if not is_magnetic:
			_cleanup_attract_sparks()
	if is_magnetic:
		_magnet_remaining -= delta
		var spawner := get_parent().get_node_or_null("Spawner")
		if spawner:
			var target_local = spawner.to_local(global_position)
			for child in spawner.get_children():
				if child.is_in_group("pizza") or child.is_in_group("dollar"):
					var dir = target_local - child.position
					if dir.length_squared() > 25.0:
						var item_spd := (child.get("speed") as float) if child.get("speed") != null else 0.0
						child.position += dir.normalized() * (item_spd + 350.0) * delta
					_ensure_attract_sparks(child)

	# Sway + modulate под дебафом замедления — оба непрерывно управляются по таймеру
	if is_slowed:
		var t         := _slow_remaining / _slow_total if _slow_total > 0.0 else 0.0
		var strength  := clampf(t / 0.25, 0.0, 1.0)  # полная сила до последних 25%, потом быстрый фейд
		self.modulate  = Color(1.0, 1.0, 1.0).lerp(Color(0.72, 0.30, 1.40), strength)
		_sway_t += delta * 3.5
		_sprite.rotation = sin(_sway_t) * 0.13 * strength
	else:
		self.modulate    = Color(1.0, 1.0, 1.0)
		_sprite.rotation = lerp(_sprite.rotation, 0.0, 0.12)

# ── Slow visual feedback ─────────────────────────────────────────────────────

func _on_slow_start() -> void:
	_sway_t = 0.0

func _on_slow_end() -> void:
	pass

# ── Proximity (mouth open/close) ──────────────────────────────────────────────

func _on_pizza_nearby(area: Area2D) -> void:
	if area.is_in_group("pizza"):
		_nearby_pizzas += 1
		_update_mouth()

func _on_pizza_left(area: Area2D) -> void:
	if area.is_in_group("pizza"):
		_nearby_pizzas = maxi(0, _nearby_pizzas - 1)
		_update_mouth()

func _update_mouth() -> void:
	if _eating or _morphing:   # the morph owns the sprite while spinning
		return
	var eating := _nearby_pizzas > 0
	var variant := ""
	if _ghost_active and fat_state < _skin_ghost_tex.size() \
			and _skin_ghost_tex[fat_state] != null:
		variant = "_ghost_eat" if eating else "_ghost"
	elif _hold_variant != "" and fat_state < _skin_spell2_tex.size() \
			and _skin_spell2_tex[fat_state] != null:
		variant = _hold_variant
	elif eating:
		variant = "_eat"
	_show_head(_head_tex(eating), variant)

# Подмена кадра головы вместе с ПОПРАВКОЙ на кадрирование. Варианты нарисованы
# в своих рамках, а масштаб спрайта посчитан по обычному кадру: без поправки
# голова на подмене меняет размер (у классики «доллары в глазах» приезжали в
# 2.7 раза крупнее и читались как пролаг). См. SkinMetrics.POSE_K.
var _head_k : float = 1.0

# Где стоит голова: якорь обычного кадра, посадка обычного кадра и посадка
# ТЕКУЩЕГО кадра. Последняя — цель для покачивания: вертикалью спрайта владеет
# оно, и если целиться в ноль, поправка варианта тут же стиралась бы.
var _head_anchor   : Vector2 = Vector2.ZERO
var _head_idle_pos : Vector2 = Vector2.ZERO
var _head_home     : Vector2 = Vector2.ZERO
var _head_variant  : String  = ""

func _show_head(tex: Texture2D, variant: String) -> void:
	if tex == null:
		return
	_sprite.texture = tex
	_head_k = 1.0 if variant == "" \
		else SkinMetrics.pose_k(SaveData.active_skin, variant, fat_state)
	_sprite.scale = _base_scale * _head_k
	_place_head(tex, variant)

# Посадка кадра. Размер варианта уже приведён (POSE_K), но кадр нарисован в
# своей рамке — и голова на подмене прыгает вбок. Считаем, куда сдвинуть спрайт,
# чтобы ЦЕНТР ГОЛОВЫ варианта попал в тот же якорь, что и у обычного кадра.
#
# Вертикаль снимается ТОЛЬКО в момент смены кадра: между сменами y принадлежит
# покачиванию, и переписывать его каждый вызов значило бы убить бобинг в меню.
func _place_head(tex: Texture2D, variant: String) -> void:
	var changed := variant != _head_variant
	_head_variant = variant
	if variant == "" or not SkinMetrics.has_pose_off(SaveData.active_skin, variant):
		# Кадра нет в замерах — садимся как обычный: старое поведение, без сюрпризов.
		_head_home = _head_idle_pos
	else:
		var off := SkinMetrics.pose_off(SaveData.active_skin, variant, fat_state)
		var sz  : Vector2 = tex.get_size()
		var sc  : Vector2 = _base_scale * _head_k
		_head_home = _head_anchor - Vector2(off.x * sz.x * sc.x, off.y * sz.y * sc.y)
	_sprite.position.x = _head_home.x
	if changed:
		_sprite.position.y = _head_home.y

# Какой кадр головы сейчас на экране. Отдельной функцией, потому что вариантов
# уже три пары: обычная, «ест» и серая призрачная у Дракулы под невидимостью.
# Призрачные кадры нарисованы и для покоя, и для поедания — жевать под
# невидимостью можно, и голова не должна для этого проявляться.
func _head_tex(eating: bool) -> Texture2D:
	if _ghost_active and fat_state < _skin_ghost_tex.size():
		var g = _skin_ghost_eat_tex[fat_state] if eating else _skin_ghost_tex[fat_state]
		if g != null:
			return g
	# Удерживаемая поза: у Очков «поехало» держится ВСЁ время ускорения, а не
	# мгновение. Эффект длится две секунды, и если лицо возвращается через треть
	# секунды, спелл читается как мигание, а не как состояние.
	if _hold_variant != "" and fat_state < _skin_spell2_tex.size():
		var h = _skin_spell2_tex[fat_state]
		if h != null:
			return h
	return _skin_eat_tex[fat_state] if eating else _skin_tex[fat_state]

var _hold_variant : String = ""
var _hold_token   : int = 0

func _hold_pose(variant: String, duration: float) -> void:
	_hold_variant = variant
	_hold_token  += 1
	var tok := _hold_token
	_update_mouth()
	await get_tree().create_timer(duration).timeout
	if is_instance_valid(self) and tok == _hold_token:
		_hold_variant = ""
		_update_mouth()

# ── Collisions ────────────────────────────────────────────────────────────────

func apply_slow(duration: float) -> void:
	# Шляпа мага гасит замедление целиком, а не сокращает — иначе за 3 секунды
	# эффект не читается.
	if _slow_immune_remaining > 0.0:
		_vfx_dodge_flash()
		return
	if duration >= _slow_remaining:
		_slow_total     = duration
		_slow_remaining = duration

# ── Эффекты новых предметов ───────────────────────────────────────────────────

# Маска Кейси: неуязвимость к физическому урону. Переиспользует механику
# «шрамов» Джокера — та же маска на голове, тот же бейдж, но без 60-секундного
# гейта перезарядки: гейт нужен пассивке скина, а не подобранному предмету.
func apply_casey_mask(duration: float = CASEY_MASK_DURATION) -> void:
	_begin_scars(duration, false)

# Шляпа мага: иммунитет к замедляющим предметам. Активное замедление тоже
# снимаем — подобрать шляпу под бананом и остаться медленным было бы обманом.
func apply_slow_immunity(duration: float = MAGIC_HAT_DURATION) -> void:
	_slow_immune_remaining = maxf(_slow_immune_remaining, duration)
	_slow_remaining        = 0.0
	start_skill_cd("item:magic_hat", duration)
	_show_floating_text("НЕ ЗАМЕДЛИТЬ!", Color(0.45, 0.60, 1.00))
	_vfx_particles(SkinSkills.TRANSFORM)
	_play_oneshot(_RESIST_SFX)
	# ШЛЯПА НАДЕВАЕТСЯ — как маска Кейси. Пока эффект шёл, на экране не менялось
	# ничего, кроме кружка в углу: голова та же, а «иммунитет к замедлению» —
	# состояние, которое иначе видно только в момент, когда тебя НЕ замедлили,
	# то есть никогда. Надетая шляпа отвечает на «а он ещё действует?» там же,
	# где игрок и смотрит, — на своей голове.
	_wear_hat(duration)

# Банка колы: ускорение движения головы.
func apply_speed_boost(duration: float = COLA_DURATION) -> void:
	_speed_boost_remaining = maxf(_speed_boost_remaining, duration)
	start_skill_cd("item:cola", duration)
	_show_floating_text("УСКОРЕНИЕ!", Color(1.00, 0.35, 0.30))
	_vfx_particles(SkinSkills.TRANSFORM)
	_play_oneshot(_SFX_GLITTER)

# Чек лузера: доллары, набранные за забег, сгорают. Прогресс жира и опыт не
# трогаем — предмет бьёт по кошельку, а не по забегу.
func apply_loser_ticket() -> void:
	if _dollars <= 0:
		_show_floating_text("И ТАК НОЛЬ", Color(0.70, 0.70, 0.70))
		return
	_dollars = 0
	dollars_changed.emit(_dollars)
	_show_floating_text("LOOOOSER", Color(1.00, 0.85, 0.20))
	_flash_hit()
	_play_oneshot(_SFX_POOF)

# Чёрный туз: сжигает жир до минимума одним касанием. На SKINNY жира уже нет —
# тогда это обычный смертельный удар, как у любого препятствия.
func apply_fat_burn() -> void:
	if fat_state <= 0:
		_take_hit(1)
		return
	fat_state    = 0
	_pizza_count = 0
	_apply_skin_to_sprite()
	stats_changed.emit(fat_state, _pizza_count, _total_pizza_count)
	_show_floating_text("ЖИР СГОРЕЛ!", Color(0.85, 0.20, 0.55))
	_flash_hit()
	_spawn_hit_bubble()
	_play_oneshot(_skin_hit_sfx)
	# Короткая неуязвимость, иначе следующий предмет в той же линии добивает
	# игрока раньше, чем он успевает среагировать на потерю жира.
	_invincible = true
	await get_tree().create_timer(1.5).timeout
	_invincible = false

# Наручники: энд гейм.
func apply_handcuffs() -> void:
	# Маска Кейси разбирается выше, в диспетчере (она ломается и слетает, как от
	# любого препятствия). Здесь остаются dev-бессмертие и обычное окно
	# неуязвимости после удара — иначе предмет ломал бы и тестирование, и
	# честную паузу после потери жира.
	if _dev_immortal or _invincible:
		_vfx_dodge_flash()
		return
	_last_hit_group = "handcuffs"
	_last_hit_name  = "handcuffs"
	_show_floating_text("ЭНД ГЕЙМ", Color(1.00, 0.20, 0.20))
	_die()

# Песочные часы: замедляют МИР, а не голову. Разница принципиальная — эффект
# должен читаться как передышка, поэтому предметы и фон едут медленнее, а
# управление остаётся прежним. Владеет эффектом спавнер (он же чинит тайминги
# паттернов), здесь только запуск.
func _apply_hourglass() -> void:
	var spawner := get_parent().get_node_or_null("Spawner")
	if spawner and spawner.has_method("apply_slow_mo"):
		spawner.apply_slow_mo()
	_show_floating_text("ВРЕМЯ ЗАМЕДЛЕНО", Color(0.55, 0.85, 1.00))
	_vfx_particles(SkinSkills.TRANSFORM)
	_play_oneshot(_SFX_GLITTER)

# Жетон казино: единственный предмет забега, который платит ВНЕ забега —
# начисляется сразу в сейв, чтобы не сгорел вместе со смертью.
func apply_casino_chip() -> void:
	SaveData.add_tokens(1, "run_drop")
	_show_floating_text("+1 ЖЕТОН", Color(1.00, 0.80, 0.15))
	_dollar_audio.play()
	_vfx_particles(SkinSkills.TRANSFORM)

# ── Учёт добычи мини-игр ──────────────────────────────────────────────────────

# Учёт с автоматическим начислением через `window` секунд. Нужен «супер пицце»:
# сам предмет исчезает через ~3 c, а превращённое им поле игрок доедает дольше,
# и корутина, живущая на предмете, до начисления просто не доживает — Godot
# отменяет await у освобождённого объекта. Голова живёт весь забег, поэтому
# ждём здесь.
func run_loot_tally(window: float, popup_host: Node = null) -> void:
	begin_loot_tally()
	await get_tree().create_timer(window).timeout
	if not is_instance_valid(self):
		return
	var got  : Vector2i = loot_tally()
	var mult : int      = LootMultiplier.roll()
	if got == Vector2i.ZERO:
		award_loot_tally(mult)
		return
	var host : Node = popup_host if (popup_host != null and is_instance_valid(popup_host)) else get_parent()
	if host == null:
		award_loot_tally(mult)
		return
	# На время итогов поток предметов встаёт: окно с барабанами держится около
	# четырёх секунд, и уворачиваться под ним вслепую игрок не должен. Сама
	# «супер пицца» событие не замораживает, поэтому паузу ставим здесь.
	var game    : Node = get_parent()   # Normaldo лежит в Game рядом со Spawner и HUD
	var spawner : Node = game.get_node_or_null("Spawner") if game != null else null
	var paused  : bool = spawner != null and spawner.has_method("pause_for_event")
	if paused:
		spawner.pause_for_event()
	var tg : Array = MinigamePayout.targets_from(game.get_node_or_null("HUD") if game != null else null)
	await MinigamePayout.play(host, got.x, got.y, mult, tg[0], tg[1])
	award_loot_tally(mult)
	if paused and is_instance_valid(spawner) and spawner.has_method("resume_after_event"):
		spawner.resume_after_event()

func begin_loot_tally() -> void:
	_loot_tally_active = true
	_loot_pizza_tally  = 0
	_loot_dollar_tally = 0

func loot_tally() -> Vector2i:
	return Vector2i(_loot_pizza_tally, _loot_dollar_tally)

# Доначисляет (mult - 1) от собранного за мини-игру. Возвращает добавку, чтобы
# мини-игра могла показать её в своём итоговом окне.
func award_loot_tally(mult: int) -> Vector2i:
	_loot_tally_active = false
	var extra_pizza  : int = _loot_pizza_tally  * (mult - 1)
	var extra_dollar : int = _loot_dollar_tally * (mult - 1)
	_loot_pizza_tally  = 0
	_loot_dollar_tally = 0
	if extra_pizza <= 0 and extra_dollar <= 0:
		return Vector2i.ZERO
	for _i in extra_pizza:
		_eat_pizza()
	for _i in extra_dollar:
		_collect_dollar()
	return Vector2i(extra_pizza, extra_dollar)

# Тап пришёлся на тело конуса? (мир ≈ экран, без камеры) — тогда это тап по конусу,
# а не движение/дабл-тап Нормальдо.
func _touch_on_cone(pos: Vector2) -> bool:
	for c in get_tree().get_nodes_in_group("cone"):
		if is_instance_valid(c) and c.has_method("contains_point") and c.contains_point(pos):
			return true
	return false

# Компас: реверс управления на `duration` секунд.
func apply_invert(duration: float) -> void:
	_invert_remaining = maxf(_invert_remaining, duration)
	start_skill_cd("compass", _invert_remaining)   # кружок-кулдаун в HUD
	_show_floating_text("РЕВЕРС!", Color(0.85, 0.5, 1.0))
	if not _music_reversed:
		_set_music_reversed(true)

# Разворачивает/возвращает фоновую музыку (реверс-трек на время компаса).
# Не трогаем, если играет НЕ основная тема (напр. трек мини-игры).
func _set_music_reversed(on: bool) -> void:
	var m = get_parent().get_node_or_null("Music")
	if m == null or not m.has_method("swap_to"):
		return
	var length : float = _MUSIC_FWD.get_length()
	var cur_path : String = m.stream.resource_path if m.stream != null else ""
	if on:
		if cur_path == _MUSIC_FWD.resource_path:
			# Реверс «продолжается» с текущей точки, только назад.
			var rev_from : float = clampf(length - m.get_playback_position(), 0.0, length)
			m.swap_to(_MUSIC_REV, 0.3, rev_from)
			_music_reversed = true
	else:
		if cur_path == _MUSIC_REV.resource_path:
			var fwd_from : float = clampf(length - m.get_playback_position(), 0.0, length)
			m.swap_to(_MUSIC_FWD, 0.3, fwd_from)
		_music_reversed = false

# Урон от «хазарда», который сам себя не уничтожает (напр. крутящийся знак бомжа).
# Уважает неуязвимость / маску Джокера — 1.5-c грейс ставит сам _take_hit.
func hazard_hit(dmg: int = 1) -> void:
	if _dead or _invincible or _scars_active or not _input_enabled or _fat_boss_active:
		return
	_take_hit(dmg)

# ── Skill system helpers ──────────────────────────────────────────────────────

func _area_tag(area: Area2D) -> String:
	var t = area.get("skin_tag")
	if t != null and str(t) != "": return str(t)
	if area.has_meta("item_tag"): return str(area.get_meta("item_tag"))
	# По группам. Список расширен под иммунитеты из лестницы скинов
	# (см. skin_progression.gd) — раньше тегов было четыре, и «иммунитет к вору»
	# было просто не на что навесить.
	# Порядок важен: коктейль и яд лежат ЕЩЁ и в slowing/obstacle, поэтому их
	# собственные группы обязаны проверяться раньше общих.
	for grp in ["fire", "glove", "snake", "bum", "dog", "thief", "compass", "cone",
			"handcuffs", "black_ace", "loser_ticket", "ninja",
			"safe", "cocktail", "cop", "poison", "bird", "helm", "shaman",
			"slowing"]:
		if area.is_in_group(grp):
			# Замедляющие делятся на банан и пиво — их различает звук предмета.
			if grp == "slowing":
				var snd = area.get_meta("slow_sound", null)
				if snd != null and str(snd.resource_path).get_file().begins_with("beer"):
					return "beer"
				return "banana"
			return grp
	# Texture-based fallback for the shared item.tscn negatives (trash / stone).
	if area.has_node("Sprite2D"):
		var tex := (area.get_node("Sprite2D") as Sprite2D).texture
		if tex != null:
			var fn := str(tex.resource_path).get_file()
			if fn.begins_with("trash"): return "trash"
			if fn.begins_with("stone"): return "stone"
	return ""

func _skill_matches(skill: Dictionary, area: Area2D) -> bool:
	var in_group := false
	for g in skill["groups"]:
		if area.is_in_group(g):
			in_group = true; break
	if not in_group: return false
	var tags : Array = skill.get("tags", [])
	if tags.is_empty(): return true
	var tag := _area_tag(area)
	for t in tags:
		if tag == t or area.is_in_group(t): return true
	return false

func _resolve_skills(area: Area2D) -> Dictionary:
	var r := { "dodged": false, "transformed": "", "counter_xp": 0, "counter_dollars": 0,
			   "counter_triggered": false, "adapted": false, "adapted_duration": 0.0 }
	var skills := SkinSkills.get_skills(SaveData.active_skin)
	for i in skills.size():
		var s : Dictionary = skills[i]
		if not _skill_matches(s, area): continue
		var chance := float(s.get("chance", 1.0))
		if SaveData.active_skin == "joker" and i == _joker_doubled_skill:
			chance = minf(chance * 2.0, 1.0)
		match s["type"]:
			SkinSkills.TRANSFORM:
				if r.transformed.is_empty() and randf() < chance:
					r.transformed = s.get("into", "pizza")
			SkinSkills.DODGE:
				if not r.dodged and r.transformed.is_empty() and randf() < chance:
					r.dodged = true
			SkinSkills.ADAPT:
				if not r.adapted:
					r.adapted_duration = float(area.get_meta("slow_duration", 4.0)) * 0.5
					r.adapted = true
			SkinSkills.COUNTER:
				if not r.dodged and r.transformed.is_empty():
					r.counter_triggered = true
					r.counter_xp      += int(s.get("bonus_xp", 0))
					r.counter_dollars += int(s.get("bonus_dollars", 0))
					if SaveData.active_skin == "joker" and r.counter_xp == 0 and r.counter_dollars == 0:
						var rr := randf()
						if rr < 0.33:   r.counter_xp = 20
						elif rr < 0.66: r.counter_dollars = 15
						else:           r.counter_xp = 10
	return r

# ── NEW skin model: cooldowns, resists, active ability, passives ──────────────

# Read by the HUD cooldown badges (scripts/skill_badges.gd).
func skill_cd_total(key: String) -> float:
	var c = _skill_cd.get(key)
	return c[1] if c != null else 0.0

func skill_cd_remaining(key: String) -> float:
	var c = _skill_cd.get(key)
	return c[0] if c != null else 0.0

func is_skill_ready(key: String) -> bool:
	var c = _skill_cd.get(key)
	return c == null or c[0] <= 0.0

# Charge readout for the HUD active-ability badge.
func active_charges() -> int:
	# The cooldown refills charges lazily on the next fire; reflect that here so
	# the badge shows full charges the instant the cooldown ends.
	if _active_charges <= 0 and is_skill_ready("active"):
		return _active_max_charges
	return _active_charges

func active_max_charges() -> int:
	return _active_max_charges

func start_skill_cd(key: String, total: float) -> void:
	if total <= 0.0:
		return
	_skill_cd[key] = [total, total]

func _tick_skill_cd(delta: float) -> void:
	if _skill_cd.is_empty():
		return
	for k in _skill_cd.keys():
		var c = _skill_cd[k]
		if c[0] > 0.0:
			c[0] = maxf(0.0, c[0] - delta)

# Configure the active skin's resists / ability / passive for this run.
func _build_skin_runtime() -> void:
	_skin_runtime_built = true
	var sid := SaveData.active_skin
	_skill_cd.clear()
	_resist_cd_for.clear()
	# Резисты открывает ЛЕСТНИЦА УРОВНЕЙ: get_resists собирает их из прогрессии
	# для текущего уровня скина (см. skin_skills.resists_at). Механика прежняя —
	# предмет разбивается вместо удара, затем защита уходит на перезарядку.
	for r in SkinSkills.get_resists(sid):
		var cd := float(r.get("cd", 8.0))
		for tag in r.get("items", [r.get("item", "")]):
			if str(tag) != "":
				_resist_cd_for[str(tag)] = cd
	_ability_cfg      = SkinSkills.get_ability(sid)
	_active_max_charges = maxi(1, int(_ability_cfg.get("charges", 1)))
	_active_charges   = _active_max_charges
	_passive_id       = SkinSkills.get_passive(sid).get("id", "")
	_double_ryag      = (sid == "glasses")
	_treasure_passive = (_passive_id == "treasure")
	_scars_passive    = (_passive_id == "scars")
	_harry_second_chance_ready = (_passive_id == "second_chance")
	# Retired legacy uniques (Dracula immortality / Wizard magic) — the new model
	# gives Dracula «Бомж-жор» and Wizard no passive.
	_dracula_immortal_ready = false

# A resist fired: break the item instead of taking the hit, start its cooldown.
func _trigger_resist(tag: String, area: Area2D) -> void:
	start_skill_cd("resist:" + tag, float(_resist_cd_for.get(tag, 8.0)))
	_skill_audio.stream    = _RESIST_SFX
	_skill_audio.volume_db = -6.0
	_skill_audio.play()
	_vfx_resist_break(area.global_position)
	_show_floating_text("РЕЗИСТ!", Color(0.95, 0.32, 0.28))
	# Выкрик — не вместо строки, а вместе с ней: строка говорит, ЧТО произошло,
	# рисунок — как к этому относится Нормальдо.
	_pop_sticker(Phrases.resist())
	_bum_feast(tag)
	_kill_item(area)

# Destroy an obstacle with the "falling death" used in the ЖИРОБОСС mini-game:
# knock_down() drops it under gravity with a spin AND plays its death cry
# (бомж/собака have their own). Falls back to on_hit / queue_free.
func _kill_item(area: Object) -> void:
	if not is_instance_valid(area):
		return
	if area.has_method("knock_down"):
		area.knock_down()
	elif area.has_method("on_hit"):
		area.on_hit()
	else:
		area.queue_free()

func _vfx_resist_break(pos: Vector2) -> void:
	var p := CPUParticles2D.new()
	p.emitting = true; p.one_shot = true; p.explosiveness = 0.9
	p.amount = 16; p.lifetime = 0.45; p.spread = 180.0
	p.initial_velocity_min = 70.0; p.initial_velocity_max = 150.0
	p.scale_amount_min = 3.0; p.scale_amount_max = 7.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 10.0
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.45, 0.35, 1.0))
	g.add_point(1.0, Color(0.9, 0.15, 0.10, 0.0))
	p.color_ramp = g
	get_parent().add_child(p)
	p.global_position = pos
	p.finished.connect(p.queue_free)

# ── Active ability (double-tap) ───────────────────────────────────────────────

# Спелл заблокирован извне — на время такта, который обязан играться руками, а
# не кнопкой. Флаг публичный и снимается ТЕМ ЖЕ, кто поставил: если хозяин
# такта умер вместе с забегом, снимать блокировку некому, поэтому все, кто её
# ставит, обязаны снимать её и в своём аварийном выходе.
var spells_blocked : bool = false

func set_spells_blocked(v: bool) -> void:
	spells_blocked = v

func _try_fire_ability(target: Vector2) -> void:
	if _ability_cfg.is_empty():
		return
	if spells_blocked:
		# Отказ ВИДЕН: молча проглоченный двойной тап читается как «игра не
		# поняла», и игрок жмёт ещё раз вместо того, чтобы играть такт.
		_show_floating_text("Не сейчас", Color(0.85, 0.85, 0.90))
		active_denied.emit()
		return
	# Charge-based cooldown: the ability holds `_active_max_charges` shots; the
	# cooldown only starts once the LAST charge is spent, then refills them all.
	if _active_charges <= 0:
		if not is_skill_ready("active"):
			# On cooldown — deny with feedback: pulse the badge + float a word.
			_show_floating_text("Перезарядка", Color(1.0, 0.55, 0.25))
			active_denied.emit()
			return
		_active_charges = _active_max_charges   # cooldown finished → recharge
	# Точка тапа запоминается ЦЕЛИКОМ, а не только направление: рывок Очков
	# летит в конкретное место экрана, и нормализованного вектора ему мало.
	_last_ability_target = target
	var dir := (target - global_position)
	if dir.length() < 4.0:
		dir = Vector2.RIGHT
	dir = dir.normalized()
	if _ability_cfg.get("type", "") == SkinSkills.RYAGALITY:
		_fire_rygality(dir, _ability_cfg.get("color", Color(0.35, 1.0, 0.45)))
		if _double_ryag:
			await get_tree().create_timer(0.16).timeout
			if is_instance_valid(self):
				_fire_rygality(dir, _ability_cfg.get("color", Color(0.35, 1.0, 0.45)))
	else:
		# Поза каста играется НЕ у всех. У викинга кулак нарисован и в позе, и
		# летит анимированным — на экране получалось два кулака сразу. Кулак
		# должен быть один, и это тот, который двигается: позу пропускаем.
		if not _POSE_SKIP.has(String(_ability_cfg.get("id", ""))):
			_show_spell_pose(pose_time_for(String(_ability_cfg.get("id", ""))))
		_cast_spell(str(_ability_cfg.get("id", "")), dir)
	# Consume a charge; start the cooldown only when they're all gone.
	_active_charges -= 1
	if _active_charges <= 0:
		start_skill_cd("active", float(_ability_cfg.get("cd", 8.0)))

# Generic projectile spawned at Normaldo, flying along `dir`.
func _spawn_skill_projectile(dir: Vector2, speed: float, spr: Node2D, radius: float,
		scan: Array, handler: Callable, spin: float = 0.0, life: float = 2.4) -> Node2D:
	var proj := Area2D.new()   # Area2D: коллизию предметов ловит движок (area_entered)
	proj.set_script(_PROJECTILE_SCRIPT)
	proj.z_index = 38
	get_parent().add_child(proj)
	proj.global_position = global_position
	proj.set("velocity", dir * speed)
	proj.set("radius", radius)
	proj.set("life", life)
	proj.set("spin", spin)
	proj.set("scan_groups", scan)
	proj.set("hit_handler", handler)
	proj.call("setup", spr)
	return proj

func _make_sprite(tex: Texture2D, px: float, mod: Color = Color(1, 1, 1)) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture        = tex
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var tsz := tex.get_size()
	var sc  := px / maxf(tsz.x, tsz.y)
	s.scale    = Vector2(sc, sc)
	s.modulate = mod
	return s

# Every kind of item the Рыгалити cloud can smash — anything from a pizza to a
# ninja-foot shuriken. Mini-game pickups (mutagen / slot machine) are excluded.
const _RYAG_HIT_GROUPS : Array = ["obstacle", "fire", "slowing", "pizza",
	"pizza_pack", "dollar", "money_bag", "bomb", "molotov", "magnet"]

# Рыгалити: a big tinted smoke cloud flies along the tap line, breaks the FIRST
# item it touches and dissipates. No spin — it pulsates in size instead.
func _fire_rygality(dir: Vector2, col: Color) -> void:
	var spr := _make_sprite(_SMOKE_TEX, 92.0, Color(col.r, col.g, col.b, 0.95))
	var base := spr.scale
	_spawn_skill_projectile(dir, 460.0, spr, 52.0, _RYAG_HIT_GROUPS, _break_once_handler(), 0.0)
	var tw := spr.create_tween().set_loops()
	tw.tween_property(spr, "scale", base * 1.18, 0.35).set_trans(Tween.TRANS_SINE)
	tw.tween_property(spr, "scale", base * 0.88, 0.35).set_trans(Tween.TRANS_SINE)
	_skill_audio.stream = _SKILL_SFX_DODGE
	_skill_audio.volume_db = -7.0
	_skill_audio.play()

# Поза каста: на время SPELL_POSE_TIME голова принимает нарисованную для этого
# позу вместо обычной. Владеет спрайтом ненадолго и уступает его обратно
# _update_mouth, поэтому с анимацией поедания не дерётся.
const SPELL_POSE_TIME : float = 0.34

# У большинства скинов поза — это РЕАКЦИЯ: спелл уже ушёл, поза его комментирует,
# и держать её треть секунды нормально. У Очков поза — это ЗАРЯД: рывок ждёт,
# пока она доиграет, и игрок всё это время стоит на месте. Полсекунды с лишним
# ожидания перед рывком читаются не как замах, а как задержка нажатия.
#
# Поэтому у заряжающих спеллов кадр свой, короче общего. Оба кадра при этом
# остаются: «глотнул энергетик» → «поехало» — по одному кадру спелл Очков не
# читается вовсе.
const POSE_TIME_BY_ID : Dictionary = { "electric_dash": 0.20 }

func pose_time_for(id: String) -> float:
	return float(POSE_TIME_BY_ID.get(id, SPELL_POSE_TIME))

var _spell_pose_token : int = 0

func _show_spell_pose(frame_t: float = SPELL_POSE_TIME) -> void:
	if _morphing or fat_state >= _skin_spell_tex.size():
		return
	var tex = _skin_spell_tex[fat_state]
	if tex == null:
		return
	_spell_pose_token += 1
	var tok := _spell_pose_token
	_show_head(tex, "_spell")
	await get_tree().create_timer(frame_t).timeout
	if not is_instance_valid(self) or tok != _spell_pose_token or _morphing:
		return
	# Второй кадр, если он нарисован: у Очков каст — это «глотнул энергетик» и
	# только потом «поехало». Одним кадром такое не читается: на экране либо
	# банка без реакции, либо реакция без банки.
	var tex2 = _skin_spell2_tex[fat_state] if fat_state < _skin_spell2_tex.size() else null
	if tex2 != null:
		_show_head(tex2, "_spell2")
		await get_tree().create_timer(frame_t).timeout
		if not is_instance_valid(self) or tok != _spell_pose_token or _morphing:
			return
	_update_mouth()

# ── Тёмный снаряд на тёмном фоне ─────────────────────────────────────────────
# Птицы Тыквы и батаранг Бэтмена нарисованы чёрным силуэтом, а забег идёт по
# тёмному подземелью: снаряда просто не видно, и спелл читается как «ничего не
# произошло». Увеличение одно не спасает — чёрное на чёрном не становится
# заметнее от размера.
#
# Ободок — копия того же спрайта чуть крупнее, покрашенная в цвет скина и
# положенная ПОД оригинал. Дёшево, работает на любой раскадровке (кадры
# подменяются у обоих сразу) и не требует шейдера.
# Магические звёзды мага: три РАЗНЫХ снаряда, по одному на каст.
# Режет их из авторского листа dev/tools/bake_wizard_stars.py.
const WIZARD_STARS : Array = [
	preload("res://assets/skills/wizard/star1.png"),
	preload("res://assets/skills/wizard/star2.png"),
	preload("res://assets/skills/wizard/star3.png"),
]
const WIZARD_STAR_PX   : float = 56.0
const WIZARD_STAR_SPIN : float = 9.0    # рад/с — звезда крутится в полёте

const PROJ_BIRD_PX : float = 66.0
const PROJ_BAT_PX  : float = 74.0
const RIM_GROW     : float = 1.30

func _add_rim(spr: Sprite2D, col: Color) -> void:
	var rim := Sprite2D.new()
	rim.texture        = spr.texture
	rim.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rim.scale          = Vector2.ONE * RIM_GROW
	rim.modulate       = Color(col.r, col.g, col.b, 0.95)
	rim.z_index        = -1
	rim.name           = "Rim"
	spr.add_child(rim)

# Спрайт снаряда из раскадровки: кадры лежат в assets/skills/<скин>/<имя>N.png.
func _make_anim_sprite(dir_path: String, prefix: String, count: int, px: float) -> Sprite2D:
	var frames : Array = []
	for i in range(1, count + 1):
		var p := "%s%s%d.png" % [dir_path, prefix, i]
		if ResourceLoader.exists(p):
			frames.append(load(p))
	if frames.is_empty():
		return _make_sprite(_WHEEL_TEX, px)
	var spr := _make_sprite(frames[0], px)
	spr.set_meta("frames", frames)
	return spr

# Ближний бой: ОДИН удар, а не летящий снаряд.
#
# Раньше здесь спавнился снаряд с картинкой кулака, который улетал от головы. На
# экране получались два кулака сразу: один нарисован в позе каста (stateN_spell),
# второй улетал прочь — читалось как баг, будто перчатку метнули.
#
# Теперь бьёт невидимая зона: она проходит короткую ДУГУ перед головой, снося
# всё, чего коснулась. Кулак игрок видит ровно один — тот, что нарисован в позе,
# а сама голова на время удара подаётся вперёд по той же дуге.
const MELEE_SWEEP_TIME : float = 0.26
const MELEE_ARC        : float = 0.85   # раствор дуги в радианах
const MELEE_RADIUS     : float = 60.0   # радиус поражения по умолчанию
# Викингу радиус СВОЙ и заметно больший: его спелл — не точечный тычок, а
# «взрывной кулак», и обещание карточки «сносит всё вплотную» с радиусом 60
# сбывалось ровно на одной цели. Линии стоят через 86 пикселей, поэтому 96
# накрывает свою и обе соседние — три цели, как и задумано.
const VIKING_MELEE_RADIUS : float = 96.0
# И кулак под этот радиус: бьющая зона больше нарисованного кулака читается как
# «попало мимо картинки».
const VIKING_FIST_PX : float = 215.0

func _cast_melee(dir: Vector2, reach: float, show_fist: bool = true,
		radius: float = MELEE_RADIUS, fist_px: float = FIST_PX) -> void:
	var proj := _spawn_skill_projectile(dir, 0.0, null, radius,
		_RYAG_HIT_GROUPS, _melee_hit_handler(), 0.0, MELEE_SWEEP_TIME + 0.05)
	if proj == null:
		return
	if show_fist:
		_attach_big_fist(proj, dir, fist_px)
	# Дуга: от «замаха» сверху к «доводке» снизу, с вылетом вперёд на reach.
	var steps := 4
	var tw := proj.create_tween()
	for i in range(steps + 1):
		var t : float = float(i) / float(steps)
		var ang : float = lerpf(-MELEE_ARC * 0.5, MELEE_ARC * 0.5, t)
		var rad : float = lerpf(30.0, reach, sin(t * PI * 0.75))
		var target : Vector2 = global_position + dir.rotated(ang) * rad
		if i == 0:
			proj.global_position = target
		else:
			tw.tween_property(proj, "global_position", target, MELEE_SWEEP_TIME / float(steps))
	_lunge(dir)

# ── Кулак размером с героя (отсылка к Battletoads) ───────────────────────────
# В Battletoads удар — это когда конечность на кадр превращается в НЕСОРАЗМЕРНО
# огромный кулак или сапог. Ровно этот приём здесь и берётся.
#
# Раньше мили-спелл вообще ничего не рисовал: била невидимая зона, а кулак был
# только нарисован в позе каста. Причина была уважительная — когда-то снаряд с
# кулаком улетал от головы, и на экране оказывалось ДВА кулака сразу, будто
# перчатку метнули. Лечится это не отказом от кулака, а размером: кулак впятеро
# крупнее нарисованного в позе не читается как «второй», он читается как «вот
# этим он и бьёт».
const _FIST_TEX : Dictionary = {
	"viking": preload("res://assets/skills/viking/fist.png"),
	"tyson":  preload("res://assets/skills/tyson/punch.png"),
}
const _FIST_FALLBACK : Texture2D = preload("res://assets/skills/fist_generic.png")
const _POWER_TEX     : Texture2D = preload("res://assets/skills/power.png")
const FIST_PX        : float = 150.0   # голова — 99: кулак заведомо крупнее её

func _attach_big_fist(proj: Node2D, dir: Vector2, px: float = FIST_PX) -> void:
	var tex : Texture2D = _FIST_TEX.get(SaveData.active_skin, _FIST_FALLBACK)
	var fist := _make_sprite(tex, px)
	fist.rotation = dir.angle()
	# Кулак «вырастает» за первую треть замаха, а не появляется целиком: именно
	# рост и читается как превращение руки, а не как подставленная картинка.
	var full := fist.scale
	fist.scale = full * 0.45
	proj.add_child(fist)
	var tw := fist.create_tween()
	tw.tween_property(fist, "scale", full, MELEE_SWEEP_TIME * 0.35)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(MELEE_SWEEP_TIME * 0.35)
	tw.tween_property(fist, "modulate:a", 0.0, MELEE_SWEEP_TIME * 0.3)

# Удар ломает предмет и печатает «POWER!» — но только по ПОПАДАНИЮ. Промах
# оставляет экран чистым: слово на каждом касте превратилось бы в фон.
func _melee_hit_handler() -> Callable:
	var base := _break_handler()
	return func(node):
		var hit := is_instance_valid(node)
		var pos : Vector2 = (node as Node2D).global_position if hit else Vector2.ZERO
		var res = base.call(node)
		if hit:
			_pop_power(pos)
		return res

var _power_until : float = 0.0

func _pop_power(pos: Vector2) -> void:
	# Один взмах сносит несколько предметов подряд — слово печатаем один раз,
	# иначе на экране вырастает стопка из четырёх «POWER!».
	var now : float = float(Time.get_ticks_msec()) / 1000.0
	if now < _power_until:
		return
	_power_until = now + 0.4
	var host := get_parent()
	if host == null:
		return
	var spr := _make_sprite(_POWER_TEX, 124.0)
	spr.z_index = 41
	spr.global_position = pos + Vector2(0.0, -42.0)
	var full := spr.scale
	spr.scale = full * 0.4
	host.add_child(spr)
	var tw := spr.create_tween()
	tw.tween_property(spr, "scale", full, 0.16)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(spr, "position", spr.position + Vector2(0.0, -18.0), 0.42)
	tw.tween_property(spr, "modulate:a", 0.0, 0.20)
	tw.tween_callback(spr.queue_free)

# Спеллы, у которых своя картинка удара и поза каста ЛИШНЯЯ.
const _POSE_SKIP : Array = ["explosive_fist"]

# Доворот головы к точке тапа: мгновенно повернулся — плавно вернулся. Тайсону
# он заменяет летящий кулак, и именно поворот делает удар «в сторону», а не
# «вообще».
#
# Поворот ТОЧНЫЙ — ровно в точку дабл-тапа. Раньше угол зажимался 40°, и на
# любой тап дальше сорока градусов Тайсон бил «примерно вправо»: игрок целится в
# конкретный предмет, а голова смотрит мимо.
#
# Голова нарисована в профиль вправо, поэтому удар ВЛЕВО делается зеркалом по
# горизонтали (flip_h) плюс поворотом на угол минус развёрнутый: честный поворот
# на 170° показал бы лицо вверх ногами, а зеркало оставляет его прямым.
const FACE_SNAP_BACK : float = 0.22   # возврат: плавный, но быстрый

func _snap_face_to(dir: Vector2) -> void:
	if not is_instance_valid(_sprite):
		return
	if dir.length_squared() < 0.000001:
		return
	var flip := dir.x < 0.0
	# При зеркале «нос» спрайта смотрит в rotation + PI, отсюда и поправка.
	var ang : float = wrapf(dir.angle() - PI, -PI, PI) if flip else dir.angle()
	_sprite.rotation = ang
	_sprite.flip_h   = flip
	var spr := _sprite
	var tw := _sprite.create_tween()
	if tw == null:
		_sprite.rotation = 0.0
		_sprite.flip_h   = false
		return
	tw.tween_property(_sprite, "rotation", 0.0, FACE_SNAP_BACK)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Зеркало снимается В КОНЦЕ возврата: снять его раньше — значит крутить
	# голову обратно уже развёрнутой, и она проедет вверх ногами.
	tw.tween_callback(func() -> void:
		if is_instance_valid(spr):
			spr.flip_h = false)

# Короткий выпад головы в сторону удара — то, что делает мили-спелл «ударом», а
# не срабатыванием невидимой зоны.
func _lunge(dir: Vector2) -> void:
	var home := _sprite.position
	var tw := _sprite.create_tween()
	tw.tween_property(_sprite, "position", home + dir * 16.0, 0.09) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_sprite, "position", home, 0.17)

func _cast_spell(spell_id: String, dir: Vector2) -> void:
	match spell_id:
		"expecto_patronum", "light_flash":
			# Вспышка Гарри обнуляет весь экран разом.
			_cast_expecto()
		"explosive_fist":
			# Викинг: кулак проходит дугой вплотную перед собой. Позы каста у
			# него нет (см. _POSE_SKIP) — кулак ровно один, и он движется.
			# Радиус и кулак у него СВОИ: «взрывной кулак» обязан сносить три
			# цели, а не одну (см. VIKING_MELEE_RADIUS).
			_cast_melee(dir, 92.0, true, VIKING_MELEE_RADIUS, VIKING_FIST_PX)
			_play_skill_sfx(SkinSkills.COUNTER)
		"glove_punch":
			# Тайсон бьёт ПОЗОЙ, без летящего кулака: у него удар нарисован
			# целиком, и второй кулак поверх рисунка только мешал. Вместо
			# снаряда — доворот головы к точке тапа.
			_snap_face_to(dir)
			_cast_melee(dir, 78.0, false)
			_play_skill_sfx(SkinSkills.COUNTER)
		"shovel_throw":
			# Кусс: одна цель. На 10-м уровне уходит вторая лопатка следом.
			_throw_shovel(dir)
			if SkinProgression.has_perk(SaveData.active_skin, SaveData.skin_level, "kuss_double_shot"):
				await get_tree().create_timer(0.14).timeout
				if is_instance_valid(self):
					_throw_shovel(dir)
		"black_birds":
			# Тыква: стая срывается веером в разные стороны от головы.
			# Птицы чёрные на тёмном подземелье — без ободка и следа их
			# попросту не видно, сколько ни увеличивай.
			for a in [-0.42, 0.0, 0.42]:
				var b := _make_sprite(_BIRD_TEX, PROJ_BIRD_PX)
				_add_rim(b, Color(1.00, 0.62, 0.12))
				b.add_child(_make_skill_trail(Color(1.00, 0.55, 0.10), -dir.rotated(a)))
				_spawn_skill_projectile(dir.rotated(a), 470.0, b, 26.0,
					_RYAG_HIT_GROUPS, _break_once_handler(), 0.0)
			_play_skill_sfx(SkinSkills.DODGE)
		"bat_shuriken":
			# Бэтмен: батаранг крутится покадрово (6 кадров из архива).
			var bat := _make_anim_sprite("res://assets/skills/batman/", "batarang", 6, PROJ_BAT_PX)
			_add_rim(bat, Color(0.45, 0.80, 1.00))
			bat.add_child(_make_skill_trail(Color(0.40, 0.75, 1.00), -dir))
			# Батаранг РИКОШЕТИТ: разбил предмет — довернул к ближайшему
			# следующему, и так три раза. Один разбитый предмет за каст — это
			# спелл уровня «камень», а батаранг у Бэтмена и в кино возвращается
			# и цепляет цепочку.
			var pb := _spawn_skill_projectile(dir, BAT_SPEED, bat, 28.0,
				_RYAG_HIT_GROUPS, _break_once_handler(), 0.0, BAT_LIFE)
			_arm_bounce(pb, BAT_BOUNCES)
			_arm_frames(pb, bat, 18.0)
			_play_skill_sfx(SkinSkills.DODGE)
		"wand_shot":
			# Маг: магический шар, 4 кадра пульсации. Во что попал — то стало
			# МЭДЖИК БОКСОМ: спелл не ломает предмет и не выдаёт добычу, а
			# превращает угрозу в ставку.
			#
			# Звезда КАЖДЫЙ РАЗ одна из трёх и она КРУТИТСЯ. В архиве три разных
			# снаряда лежат на одном листе, и лист улетал целиком — на экране
			# летели все три сразу, каждая втрое мельче задуманного, потому что
			# масштаб считался по ширине листа. Лист разрезан
			# (dev/tools/bake_wizard_stars.py), здесь выбирается одна.
			var star : Texture2D = WIZARD_STARS[randi() % WIZARD_STARS.size()]
			var ball := _make_sprite(star, WIZARD_STAR_PX)
			var pw := _spawn_skill_projectile(dir, 520.0, ball, 26.0,
				_RYAG_HIT_GROUPS, _to_magic_box_handler(), WIZARD_STAR_SPIN)
			_play_oneshot(_SFX_GLITTER, -6.0)
		"web_pull":
			# Спайдер: паутина цепляет предмет и ТЯНЕТ его к себе, а не ломает —
			# в этом вся разница с остальными дальними спеллами.
			var web := _make_anim_sprite("res://assets/skills/spider_man/", "web", 8, WEB_SHOT_PX)
			var ps := _spawn_skill_projectile(dir, 600.0, web, 28.0,
				["obstacle", "pizza", "dollar"], _pull_handler(), 0.0)
			_arm_frames(ps, web, 20.0)
			_attach_web_line(ps)
			_play_skill_sfx(SkinSkills.DODGE)
		"card_deck":
			# Три карты веером, каждая крутится своей раскадровкой из 9 кадров.
			_cast_card_deck(dir)
			_play_skill_sfx(SkinSkills.DODGE)
		"invisibility":
			_cast_invisibility(float(_ability_cfg.get("duration", 2.0)))
		"electric_dash":
			_cast_electric_dash(_last_ability_target)
		"helm_throw":
			# Штурвал пробивает любые предметы на линии и НЕ ломается (pierce).
			var spr := _make_sprite(_WHEEL_TEX, 56.0)
			_spawn_skill_projectile(dir, 520.0, spr, 34.0, _RYAG_HIT_GROUPS, _break_handler(), 9.0, 3.0)
			_play_skill_sfx(SkinSkills.DODGE)
			_pirate_flair()
		"royal_gambit":
			# Middle card flies straight; top/bottom fan out slightly diagonally.
			# Each card hits the first item it meets (any type) and vanishes,
			# trailing a small purple wake.
			_cast_three_lines(_CARD_TEX, 40.0, 8.0, _break_once_handler(), Color(1, 1, 1),
				_RYAG_HIT_GROUPS, 150.0, Color(0.62, 0.24, 0.95))
			_play_skill_sfx(SkinSkills.DODGE)
		"web_shot":
			# Комок белых партиклов (без облачка) — ломает первый задетый предмет
			# и исчезает. 3 заряда, см. _try_fire_ability.
			var bolt := Node2D.new()
			bolt.add_child(_make_skill_trail(Color(1, 1, 1), -dir))
			_spawn_skill_projectile(dir, 540.0, bolt, 30.0, _RYAG_HIT_GROUPS, _break_once_handler(), 0.0)
			_play_skill_sfx(SkinSkills.DODGE)
		"dollar_shot":
			# Классика: «Размен». Снаряд — золотой комок со следом, а НЕ доллар:
			# летящая купюра читалась бы как добыча, за которой надо тянуться, и
			# игрок ловил бы собственный выстрел.
			var gold := Color(1.00, 0.82, 0.25)
			var coin := Node2D.new()
			coin.add_child(_make_skill_trail(gold, -dir))
			_spawn_skill_projectile(dir, 520.0, coin, 30.0,
				_RYAG_HIT_GROUPS, _to_dollar_handler(), 0.0)
			_play_oneshot(_SFX_GLITTER, -6.0)
			_pop_pointing_hand(dir)
		"transformus":
			# Превращает ПЕРВЫЙ задетый предмет любого типа в пиццу/доллар.
			# Снаряд — не облачко, а комок «магических» партиклов со следом.
			var magic := Color(0.70, 0.40, 1.00)
			var bolt := Node2D.new()
			bolt.add_child(_make_skill_trail(magic, -dir))
			_spawn_skill_projectile(dir, 480.0, bolt, 30.0, _RYAG_HIT_GROUPS, _transform_handler(), 0.0)
			_play_oneshot(_SFX_GLITTER, -6.0)   # charge flight
		_:
			_cast_expecto()

# ── Пират: чем толще, тем громче ─────────────────────────────────────────────
# На третьем жире у пирата на плече нарисован попугай, на четвёртом — флаг. Обе
# детали до сих пор просто висели на спрайте и молчали. Теперь каст их
# ОЗВУЧИВАЕТ: попугай орёт «ГААР», и надпись вылетает прямо в экран; на
# четвёртом вместо неё разворачивается флаг.
#
# Летит НЕ в сторону тапа, а на зрителя: растёт от головы к полному размеру и
# гаснет. Это не удар, а реплика — она не должна читаться как ещё один снаряд.
const PIRATE_GAAR_TEX : Texture2D = preload("res://assets/skills/pirate/gaar.png")
const PIRATE_FLAG_TEX : Texture2D = preload("res://assets/skills/pirate/flag.png")
const PIRATE_FLAIR_T  : float = 0.55
# Размер по голове, а не «побольше, чтоб заметили»: первая версия рисовала
# надпись в 260 px при голове в 90 и наглухо закрывала ей лицо — на кадре
# оставался флаг, а пирата под ним не было видно вовсе.
const PIRATE_FLAIR_PX : float = 132.0

func _pirate_flair() -> void:
	# Индексы жира нулевые: 2 — это «третий жир», 3 — «четвёртый».
	var tex : Texture2D = null
	match fat_state:
		2: tex = PIRATE_GAAR_TEX
		3: tex = PIRATE_FLAG_TEX
	if tex == null:
		return
	var host := get_parent()
	if host == null:
		return
	var spr := _make_sprite(tex, PIRATE_FLAIR_PX)
	spr.z_index = 40                      # поверх снарядов, но под HUD
	# Уходит ВВЕРХ И ВПРАВО, в пустую часть кадра: реплика не должна перекрывать
	# того, кто её подаёт, — иначе спелл читается как «экран чем-то залепило».
	spr.global_position = global_position + Vector2(18.0, -46.0)
	var full := spr.scale
	spr.scale    = full * 0.55
	spr.modulate = Color(1, 1, 1, 0)
	host.add_child(spr)

	var tw := spr.create_tween()
	tw.set_parallel(true)
	tw.tween_property(spr, "scale", full, PIRATE_FLAIR_T)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(spr, "position", spr.position + Vector2(56.0, -30.0), PIRATE_FLAIR_T)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(spr, "modulate:a", 1.0, PIRATE_FLAIR_T * 0.25)
	tw.chain().tween_property(spr, "modulate:a", 0.0, PIRATE_FLAIR_T * 0.5)\
		.set_delay(PIRATE_FLAIR_T * 0.25)
	tw.chain().tween_callback(spr.queue_free)

# Передать кадры анимации уже созданному снаряду.
# Сколько раз батаранг доворачивает к следующей цели. Три отскока — это ЧЕТЫРЕ
# разбитых предмета за каст, и это осознанно много: спелл Бэтмена долго был
# «камнем, который ломает одну штуку», и от легендарного скина такое не читается.
const BAT_BOUNCES : int   = 3
const BAT_SPEED   : float = 560.0
# Время жизни с запасом на всю цепочку: снаряд гас на втором довороте.
const BAT_LIFE    : float = 3.4

func _arm_bounce(proj: Node2D, n: int) -> void:
	if proj != null:
		proj.set("bounces", n)

func _arm_frames(proj: Node2D, spr: Sprite2D, fps: float) -> void:
	if proj == null or spr == null or not spr.has_meta("frames"):
		return
	proj.set("frames", spr.get_meta("frames"))
	proj.set("fps", fps)

# Колода Джокера. Не через _cast_three_lines: тем нужна одна общая текстура, а
# здесь у каждой карты своя анимация вращения, и веер строится от направления
# тапа, а не по фиксированным трём рядам.
func _cast_card_deck(dir: Vector2) -> void:
	for a in [-0.34, 0.0, 0.34]:
		var card := _make_anim_sprite("res://assets/skills/joker/", "card", 9, 46.0)
		var pc := _spawn_skill_projectile(dir.rotated(a), 560.0, card, 26.0,
			_RYAG_HIT_GROUPS, _break_once_handler(), 0.0)
		_arm_frames(pc, card, 20.0)
		if pc != null:
			pc.add_child(_make_skill_trail(Color(0.62, 0.24, 0.95), -dir))

func _throw_shovel(dir: Vector2) -> void:
	var sh := _make_sprite(_SHOVEL_TEX, 52.0)
	_spawn_skill_projectile(dir, 540.0, sh, 26.0, _RYAG_HIT_GROUPS, _break_once_handler(), 11.0)
	_play_skill_sfx(SkinSkills.DODGE)

# Паутина работает по-разному в зависимости от того, во что попала:
#
#   ДОБЫЧА (пицца, доллар, бонус) — подтягивается к голове. Это и есть
#     «притягивание паутиной»: собрать то, до чего не дотянуться.
#   ПРЕПЯТСТВИЕ — ломать его паутина не должна, она липкая, а не режущая.
#     Паутина ОСТАЁТСЯ на предмете и тормозит его, давая время объехать.
#
# Разделение важно: иначе спелл с откатом 2 секунды просто уничтожал бы любую
# угрозу и обесценивал весь остальной набор скинов.
const WEB_SLOW_FACTOR   : float = 0.35   # во столько раз замедляется предмет
const WEB_STICK_TIME    : float = 3.0    # сколько держится паутина

func _pull_handler() -> Callable:
	return func(node: Node) -> bool:
		if not is_instance_valid(node) or not (node is Node2D):
			return false
		var n := node as Node2D
		if n.is_in_group("obstacle") or n.is_in_group("slowing"):
			_web_stick(n)
		else:
			_web_pull(n)
		return true

# Липкая паутина на препятствии: большой спрайт поверх предмета + замедление.
# ── Паутина Спайдера ─────────────────────────────────────────────────────────
const WEB_SHOT_PX : float = 72.0   # было 50: снаряд терялся на фоне

# Нить, тянущаяся из руки. Без неё паутина читается как отдельный летящий
# предмет, а не как выстрел ИЗ героя — а весь смысл спелла в том, что он тянет
# добычу К СЕБЕ.
var _web_line : Line2D = null
var _web_proj : Node2D = null

# Цвет нити — ЗАМЕР самой картинки паутины (assets/skills/spider_man/web*.png):
# средний цвет непрозрачных пикселей ровно (109, 109, 121). Белёсая нить читалась
# как луч, а не как паутина: снаряд серый, а тянется от него светящаяся леска.
const WEB_COLOR : Color = Color(0.427, 0.427, 0.475, 0.95)

func _attach_web_line(proj: Node2D) -> void:
	if proj == null:
		return
	var host := get_parent()
	if host == null:
		return
	if is_instance_valid(_web_line):
		_web_line.queue_free()
	_web_line = Line2D.new()
	_web_line.width         = 4.0   # серая нить тоньше трёх пикселей теряется
	_web_line.default_color = WEB_COLOR
	_web_line.z_index       = 37          # под снарядом, но над предметами
	_web_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_web_line.end_cap_mode   = Line2D.LINE_CAP_ROUND
	host.add_child(_web_line)
	_web_proj = proj
	_update_web_line()

func _update_web_line() -> void:
	if not is_instance_valid(_web_line):
		return
	if not is_instance_valid(_web_proj):
		_web_line.queue_free()
		_web_line = null
		_web_proj = null
		return
	_web_line.points = PackedVector2Array([
		_web_line.to_local(global_position),
		_web_line.to_local(_web_proj.global_position)])

# Паутина не растворяется в воздухе, а ОТВАЛИВАЕТСЯ: отцепляется от предмета и
# падает вниз с кувырком — так же, как падают сбитые предметы. Растворение
# читалось как «эффект кончился где-то в коде», падение — как «слезла».
func _drop_web(spr: Sprite2D) -> void:
	if not is_instance_valid(spr):
		return
	var host := get_parent()
	if host == null:
		spr.queue_free()
		return
	var at := spr.global_position
	var rot := spr.global_rotation
	spr.get_parent().remove_child(spr)
	host.add_child(spr)
	spr.global_position = at
	spr.global_rotation = rot
	var tw := spr.create_tween()
	tw.set_parallel(true)
	tw.tween_property(spr, "position", spr.position + Vector2(-18.0, 190.0), 0.75)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(spr, "rotation", spr.rotation + 1.4, 0.75)
	tw.tween_property(spr, "modulate:a", 0.0, 0.3).set_delay(0.45)
	tw.chain().tween_callback(spr.queue_free)

func _web_stick(n: Node2D) -> void:
	if n.has_meta("webbed"):
		return
	n.set_meta("webbed", true)
	var spr := Sprite2D.new()
	spr.texture        = _WEB_BIG_TEX
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.z_index        = 5
	# Считаем от РАЗМЕРА ПРЕДМЕТА, а не фиксированным числом: предметы теперь
	# бывают ×1…×3 (см. ItemSizing), и одна паутина на всех смотрелась бы то
	# нашлёпкой, то марлей.
	var px : float = ItemSizing.BASE_PX * 1.9
	spr.scale = Vector2.ONE * ItemSizing.fit_scale(_WEB_BIG_TEX, px)
	spr.modulate = Color(1, 1, 1, 0.0)
	n.add_child(spr)
	var tin := spr.create_tween()
	tin.tween_property(spr, "modulate:a", 0.95, 0.10)

	if n.get("speed") != null:
		var was : float = float(n.speed)
		n.speed = was * WEB_SLOW_FACTOR
		get_tree().create_timer(WEB_STICK_TIME).timeout.connect(func() -> void:
			if not is_instance_valid(n):
				return
			if n.get("speed") != null:
				n.speed = was
			n.remove_meta("webbed")
			_drop_web(spr))
	_play_skill_sfx(SkinSkills.DODGE)

func _web_pull(n: Node2D) -> void:
	if n.has_method("set_process"):
		n.set_process(false)
	var tw := n.create_tween()
	tw.tween_property(n, "global_position", global_position, 0.22) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		if is_instance_valid(n):
			n.set_process(true))

# Невидимость Дракулы: препятствия пролетают сквозь, голова полупрозрачна.
func _cast_invisibility(duration: float) -> void:
	_invincible = true
	# У Дракулы невидимость НАРИСОВАНА: серые полупрозрачные кадры на каждое
	# состояние жира. Пока их не было, спелл изображался общим гашением альфы до
	# 0.25 — голова просто бледнела. Есть арт → показываем его, а альфу гасим
	# слабее, иначе рисунок под ней не разглядеть.
	var has_ghost : bool = fat_state < _skin_ghost_tex.size() \
		and _skin_ghost_tex[fat_state] != null
	_ghost_active = has_ghost
	if has_ghost:
		_update_mouth()
		_sync_wing_tex()
	# С нарисованным кадром гасить альфу почти не надо: «нет меня» говорит сам
	# серый рисунок. Прежние 0.25 поверх серого на тёмном фоне подземелья
	# оставляли от головы вообще ничего.
	var tw := create_tween()
	tw.tween_property(_sprite, "modulate:a", 0.90 if has_ghost else 0.25, 0.12)
	_show_floating_text("НЕВИДИМОСТЬ", Color(0.65, 0.25, 1.0))
	_play_skill_sfx(SkinSkills.TRANSFORM)
	await get_tree().create_timer(duration).timeout
	if not is_instance_valid(self):
		return
	_ghost_active = false
	_update_mouth()
	_sync_wing_tex()
	var tw2 := create_tween()
	tw2.tween_property(_sprite, "modulate:a", 1.0, 0.18)
	_invincible = false

# ── Очки: электрический рывок ────────────────────────────────────────────────
# Раньше спелл был «ускорением»: две секунды голова двигалась быстрее. Проблема
# была не в силе, а в ЧИТАЕМОСТИ — на экране не происходило ничего, кроме того,
# что палец начинал опережать голову. Спелл легендарного скина не должен
# опознаваться по ощущению в пальце.
#
# Теперь это РЫВОК, и он читается тремя вещами подряд:
#   1. Заряд. Играется нарисованная поза каста — «глотнул энергетик», потом
#      «поехало». На втором кадре включается электричество: жёлтая обводка,
#      мелкая тряска и искры. Это окно ожидания, по нему видно, что сейчас будет.
#   2. Рывок. Голова уходит В ТОЧКУ ТАПА за четверть секунды, оставляя за собой
#      хвост кометы — узкий у места старта и широкий у самой головы.
#   3. Проход насквозь. Пока идёт рывок, предметы не задевают вообще: ни плохие,
#      ни хорошие. Съеденная на лету пицца превратила бы рывок в способ фармить,
#      а пропущенный удар — в способ не думать; ни то, ни другое к «пролетел
#      насквозь» отношения не имеет.
const DASH_COL      : Color = Color(1.00, 0.92, 0.15)   # электрический жёлтый
# Заряд идёт РОВНО столько, сколько длится поза каста Очков, — они обязаны
# кончиться вместе, иначе на экране либо рывок из обычной головы, либо поза,
# висящая после рывка. Поэтому длина кадра берётся ИЗ ТОЙ ЖЕ таблицы, по которой
# играется сама поза (POSE_TIME_BY_ID), а не пишется здесь вторым числом: два
# независимых источника одной величины расходятся на первой же правке.
const DASH_CHARGE_T : float = 0.40      # = pose_time_for("electric_dash") * 2
const DASH_T        : float = 0.24
const DASH_TRAIL_W  : float = 84.0    # ширина хвоста У ГОЛОВЫ
const DASH_TAIL_W   : float = 0.10    # и доля этой ширины на дальнем конце
const DASH_RIM_GROW : float = 1.16
const DASH_SHAKE    : float = 0.075   # рад: амплитуда дрожи
const DASH_SHAKE_T  : float = 0.035   # и её период — быстро, как от тока

var _last_ability_target : Vector2 = Vector2.ZERO
var _dash_active  : bool    = false
var _dash_trail   : Line2D  = null
var _dash_from    : Vector2 = Vector2.ZERO
var _dash_sparks  : CPUParticles2D = null

func is_dashing() -> bool:
	return _dash_active

func _cast_electric_dash(target: Vector2) -> void:
	if _dash_active:
		return
	# Электричество включается НА ВТОРОМ кадре позы: на первом он ещё пьёт, и
	# искрить там нечему.
	var frame_t : float = pose_time_for("electric_dash")
	await get_tree().create_timer(frame_t).timeout
	if not is_instance_valid(self):
		return
	var rim := _dash_rim(true)
	_dash_sparks = _dash_spark_emitter()
	_dash_shake(frame_t)
	_play_oneshot(_SFX_GLITTER, -4.0)
	await get_tree().create_timer(frame_t).timeout
	if not is_instance_valid(self):
		_dash_rim(false)
		return

	# ── Рывок ────────────────────────────────────────────────────────────────
	_dash_active = true
	_invincible  = true
	_dash_from   = global_position
	_dash_prev   = global_position
	_dash_trail  = _make_dash_trail()
	_show_floating_text("ЗЗЗАП!", DASH_COL)
	_play_skill_sfx(SkinSkills.DODGE)
	var vp := get_viewport_rect().size
	var to := Vector2(clampf(target.x, 24.0, vp.x - 24.0), clampf(target.y, 24.0, vp.y - 24.0))
	var tw := create_tween()
	tw.tween_property(self, "global_position", to, DASH_T)\
		.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	await tw.finished

	_dash_active = false
	_invincible  = false
	_dash_rim(false)
	if is_instance_valid(_dash_sparks):
		_dash_sparks.emitting = false
		var sp := _dash_sparks
		get_tree().create_timer(0.6).timeout.connect(func() -> void:
			if is_instance_valid(sp):
				sp.queue_free())
	_dash_sparks = null
	_fade_dash_trail()

# Обводка — копия спрайта головы, чуть крупнее и позади. Тот же приём, что у
# снарядов (_add_rim): дешевле шейдера и не зависит от кадра, который сейчас
# показан, — копия берёт текстуру у оригинала в момент создания.
func _dash_rim(on: bool) -> Sprite2D:
	if not is_instance_valid(_sprite):
		return null
	var old := _sprite.get_node_or_null("DashRim")
	if old != null:
		old.queue_free()
	if not on:
		return null
	var rim := Sprite2D.new()
	rim.name           = "DashRim"
	rim.texture        = _sprite.texture
	rim.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rim.scale          = Vector2.ONE * DASH_RIM_GROW
	rim.modulate       = Color(DASH_COL.r, DASH_COL.g, DASH_COL.b, 0.95)
	rim.z_index        = -1
	_sprite.add_child(rim)
	return rim

# Дрожь — по ПОВОРОТУ, а не по позиции. Вертикалью спрайта владеет покачивание
# (см. _place_head), и тряска позиции гасилась бы им на каждом кадре.
func _dash_shake(duration: float) -> void:
	if not is_instance_valid(_sprite):
		return
	var spr := _sprite
	var tw := spr.create_tween()
	if tw == null:
		return
	var steps : int = maxi(2, int(duration / DASH_SHAKE_T))
	for i in steps:
		var a : float = DASH_SHAKE * (1.0 if i % 2 == 0 else -1.0)
		tw.tween_property(spr, "rotation", a, DASH_SHAKE_T)
	tw.tween_property(spr, "rotation", 0.0, DASH_SHAKE_T)

func _dash_spark_emitter() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount               = 26
	p.lifetime             = 0.45
	p.explosiveness        = 0.0
	p.direction            = Vector2.ZERO
	p.spread               = 180.0
	p.gravity              = Vector2.ZERO
	p.initial_velocity_min = 90.0
	p.initial_velocity_max = 210.0
	p.scale_amount_min     = 1.5
	p.scale_amount_max     = 3.5
	p.color                = DASH_COL
	p.z_index              = 6
	p.emitting             = true
	add_child(p)
	return p

func _make_dash_trail() -> Line2D:
	var host := get_parent()
	if host == null:
		return null
	var l := Line2D.new()
	l.width         = DASH_TRAIL_W
	l.default_color = Color(DASH_COL.r, DASH_COL.g, DASH_COL.b, 0.80)
	l.z_index       = 6
	l.begin_cap_mode = Line2D.LINE_CAP_ROUND
	l.end_cap_mode   = Line2D.LINE_CAP_ROUND
	l.joint_mode     = Line2D.LINE_JOINT_ROUND
	# Кривая ширины и делает из полосы КОМЕТУ: у дальнего конца хвост почти
	# сходится в точку, у головы — во всю ширину.
	var c := Curve.new()
	c.add_point(Vector2(0.0, DASH_TAIL_W))
	c.add_point(Vector2(1.0, 1.0))
	l.width_curve = c
	l.points = PackedVector2Array([_dash_from, _dash_from])
	host.add_child(l)
	return l

# Хвост — отрезок «откуда стартовал → где сейчас». Обновляется каждый кадр, а не
# копится точками: рывок прямой, и двух точек хватает.
func _update_dash_trail() -> void:
	if not is_instance_valid(_dash_trail):
		return
	if not _dash_active:
		return
	_dash_trail.points = PackedVector2Array([_dash_from, global_position])

# Сбор добычи ПО ЛИНИИ рывка, а не по касанию.
#
# Голову за рывок тащит тюин через полэкрана за четверть секунды — это по
# полтора десятка пикселей за кадр физики. Предмет размером с пиццу движок между
# кадрами просто не увидит: `area_entered` срабатывает по ПЕРЕСЕЧЕНИЮ в момент
# опроса, а между двумя опросами голова успевает перепрыгнуть предмет целиком.
# Обещание «рывок собирает всё по пути» держится только развёрткой: каждый кадр
# берём ОТРЕЗОК, пройденный головой, и собираем всё, что к нему ближе радиуса.
#
# Радиус чуть больше хитбокса: линия рывка — это заявка «лечу сюда», и промах в
# пять пикселей по пицце, которую игрок явно вёл, читается как баг.
const DASH_PICK_R : float = 46.0

var _dash_prev : Vector2 = Vector2.ZERO

func _sweep_dash_loot() -> void:
	if not _dash_active:
		return
	var a := _dash_prev
	var b := global_position
	_dash_prev = b
	for g in ["pizza", "dollar"]:
		for node in get_tree().get_nodes_in_group(g):
			if not (node is Node2D) or not is_instance_valid(node):
				continue
			var p : Vector2 = (node as Node2D).global_position
			if Geometry2D.get_closest_point_to_segment(p, a, b).distance_to(p) > DASH_PICK_R:
				continue
			if g == "pizza":
				_eat_pizza()
			else:
				_collect_dollar()
			node.queue_free()

func _fade_dash_trail() -> void:
	if not is_instance_valid(_dash_trail):
		return
	var l := _dash_trail
	_dash_trail = null
	var tw := l.create_tween()
	if tw == null:
		l.queue_free()
		return
	tw.tween_property(l, "modulate:a", 0.0, 0.22)
	tw.tween_callback(l.queue_free)

# ── Крылья Дракулы ───────────────────────────────────────────────────────────
# В архиве крыло ОДНО. Пара собирается зеркалом: правое — тот же спрайт с
# отрицательным масштабом по X, и обе половины машут навстречу друг другу.
# Первая попытка вешала одно крыло по центру головы, и оно закрывало лицо —
# отсюда правило: крыло крепится СБОКУ и уходит за голову, а не ложится на неё.
#
# Опорная точка — у корня крыла, а не в центре спрайта. Sprite2D вращается
# вокруг начала координат узла, поэтому текстура сдвинута `offset` наружу: тогда
# поворот читается как взмах от плеча, а не как вращение крыла вокруг себя.
const WING_TEX       : Texture2D = preload("res://assets/skills/dracula/wing_open.png")
const WING_TEX_GHOST : Texture2D = preload("res://assets/skills/dracula/wing_ghost.png")
const WING_FAT       : int   = 3      # нулевой индекс: «четвёртый жир»
const WING_PX        : float = 112.0  # крупнее головы (99 px) — так и просили
# Корни разведены почти к краям головы. Первая версия ставила их на ±20 и прятала
# крылья ЦЕЛИКОМ за головой: наружу торчали только зубцы перепонки, и читались
# они как красный воротник, а не как крылья.
const WING_X         : float = 54.0
const WING_Y         : float = -20.0
const WING_REST_DEG  : float = -24.0  # сложены
const WING_UP_DEG    : float = -60.0  # взмах вверх
const WING_FLAP_T    : float = 0.34
const WING_PAUSE_T   : float = 1.6    # между взмахами: «периодически», не мельтешит

var _wings : Array = []

# Крылья положены только тому, кому их нарисовали, и только на том жире, на
# котором нарисовали: у Дракулы это четвёртый.
func _wings_wanted() -> bool:
	return SaveData.active_skin == "dracula" and fat_state == WING_FAT \
		and not _fat_boss_active

func _refresh_wings() -> void:
	if not _wings_wanted():
		_drop_wings()
		return
	if not _wings.is_empty():
		_sync_wing_tex()
		return
	var tsz := WING_TEX.get_size()
	var sc  : float = WING_PX / maxf(tsz.x, tsz.y)
	for side in [-1.0, 1.0]:
		var w := Sprite2D.new()
		w.texture        = WING_TEX
		w.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		w.scale    = Vector2(sc * side, sc)      # правое — зеркало левого
		w.z_index  = -1                           # ЗА головой
		w.position = Vector2(WING_X * side, WING_Y)
		# Сдвиг текстуры наружу: корень крыла оказывается в начале координат.
		w.offset   = Vector2(tsz.x * 0.34, 0.0)
		w.rotation = deg_to_rad(WING_REST_DEG) * side
		add_child(w)
		_wings.append(w)
	_sync_wing_tex()
	_flap_wings()

func _drop_wings() -> void:
	for w in _wings:
		if is_instance_valid(w):
			w.queue_free()
	_wings.clear()

# Под невидимостью крылья сереют вместе с головой — иначе от Дракулы остаётся
# призрак с двумя яркими красными крыльями.
func _sync_wing_tex() -> void:
	var tex : Texture2D = WING_TEX_GHOST if _ghost_active else WING_TEX
	for w in _wings:
		if is_instance_valid(w):
			(w as Sprite2D).texture = tex

# Взмах: обе половины вверх, обратно, и пауза. Цикл бесконечный, твин привязан к
# самому крылу и умирает вместе с ним.
func _flap_wings() -> void:
	if _wings.size() < 2 or not is_instance_valid(_wings[0]):
		return
	var l : Sprite2D = _wings[0]
	var r : Sprite2D = _wings[1]
	var tw := l.create_tween()
	tw.set_loops()
	tw.tween_property(l, "rotation", deg_to_rad(-WING_UP_DEG), WING_FLAP_T)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(r, "rotation", deg_to_rad(WING_UP_DEG), WING_FLAP_T)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.chain().tween_property(l, "rotation", deg_to_rad(-WING_REST_DEG), WING_FLAP_T)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(r, "rotation", deg_to_rad(WING_REST_DEG), WING_FLAP_T)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.chain().tween_interval(WING_PAUSE_T)

# Three projectiles in three rows. `spread` > 0 fans the outer two out diagonally
# (top goes up-right, bottom down-right), the middle one always flies straight.
# `trail_col` (alpha > 0) attaches a small coloured particle wake to each.
func _cast_three_lines(tex: Texture2D, px: float, spin: float, handler: Callable,
		mod: Color = Color(1, 1, 1), groups: Array = ["obstacle", "fire"], spread: float = 0.0,
		trail_col: Color = Color(0, 0, 0, 0)) -> void:
	for off in [-46.0, 0.0, 46.0]:
		# Area2D, а не Node2D: скрипт снаряда наследует Area2D, и set_script на
		# Node2D молча не применялся — три карты Джокера падали на setup() и не
		# вылетали вовсе. Баг был и до переработки скинов.
		var proj := Area2D.new()
		proj.set_script(_PROJECTILE_SCRIPT)
		proj.z_index = 38
		get_parent().add_child(proj)
		proj.global_position = global_position + Vector2(0.0, off)
		proj.set("velocity", Vector2(560.0, spread * signf(off)))
		proj.set("radius", 30.0)
		proj.set("life", 2.6)
		proj.set("spin", spin)
		proj.set("scan_groups", groups)
		proj.set("hit_handler", handler)
		var spr := _make_sprite(tex, px, mod)
		proj.call("setup", spr)
		if trail_col.a > 0.0:
			spr.add_child(_make_skill_trail(trail_col))

# Fire-and-forget SFX: temporary player that frees itself when done.
func _play_oneshot(stream: AudioStream, vol_db: float = -4.0) -> void:
	if stream == null:
		return
	var a := AudioStreamPlayer.new()
	a.stream    = stream
	a.volume_db = vol_db
	get_parent().add_child(a)
	a.play()
	a.finished.connect(a.queue_free)

# Small world-space particle wake that lingers behind a moving projectile.
func _make_skill_trail(col: Color, back_dir: Vector2 = Vector2(-1, 0)) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.local_coords         = false   # particles stay in world → real trail
	p.emitting             = true
	p.amount               = 20
	p.lifetime             = 0.42
	p.direction            = back_dir.normalized()
	p.spread               = 22.0
	p.gravity              = Vector2.ZERO
	p.initial_velocity_min = 12.0
	p.initial_velocity_max = 40.0
	p.scale_amount_min     = 2.0
	p.scale_amount_max     = 4.5
	var g := Gradient.new()
	g.set_color(0, Color(col.r, col.g, col.b, 0.9))
	g.add_point(1.0, Color(col.r, col.g, col.b, 0.0))
	p.color_ramp = g
	return p

# Экспекто патронум: white flash + wipe every obstacle on screen.
func _cast_expecto() -> void:
	var fl := CanvasLayer.new()
	fl.layer = 80
	get_parent().add_child(fl)
	var cr := ColorRect.new()
	cr.color = Color(1, 1, 1, 0.0)
	cr.size  = get_viewport_rect().size
	fl.add_child(cr)
	var tw := cr.create_tween()
	tw.tween_property(cr, "color:a", 0.85, 0.12)
	tw.tween_property(cr, "color:a", 0.0, 0.55)
	tw.tween_callback(fl.queue_free)
	for grp in _RYAG_HIT_GROUPS:
		for node in get_tree().get_nodes_in_group(grp):
			if is_instance_valid(node):
				_kill_item(node)
	_play_skill_sfx(SkinSkills.TRANSFORM)

# Hit handlers (return true → consume the projectile, false → pierce on).
func _break_handler() -> Callable:
	return func(node):
		if not is_instance_valid(node):
			return false
		_vfx_resist_break((node as Node2D).global_position)
		_kill_item(node)
		return false

# Break the first item hit, then consume the projectile (Рыгалити).
func _break_once_handler() -> Callable:
	return func(node):
		if not is_instance_valid(node):
			return false
		_vfx_resist_break((node as Node2D).global_position)
		_kill_item(node)
		return true

# Маг: задетый предмет становится МЭДЖИК БОКСОМ. Отдельно от _transform_handler,
# который бросает монетку пицца-или-доллар: там добыча выдаётся сразу, а тут
# спелл выдаёт СТАВКУ — ящик ещё надо поймать, и он выплюнет что попало.
# В этом и разница между магом и классикой: классика обналичивает, маг — играет.
const _MAGIC_BOX_SCRIPT := preload("res://scripts/magic_box.gd")

func _to_magic_box_handler() -> Callable:
	return func(node):
		if not is_instance_valid(node):
			return false
		var pos : Vector2 = (node as Node2D).global_position
		var spd := 250.0
		if node.get("speed") != null:
			spd = float(node.get("speed"))
		if node.has_method("on_hit"):
			node.on_hit()
		else:
			node.queue_free()
		# Ящик кладём в СПАВНЕР, а не в сцену рядом с Нормальдо. Пойманный ящик
		# берёт `get_parent()` и просит у него `build_random_item()` — то есть
		# рассчитывает, что родитель и есть спавнер. Родителем оказывалась сцена,
		# метода у неё нет, и ящик молча ничего не выплёвывал: перелетал на
		# голову, крутился и таял. Снаружи это выглядело как «ящик от мага
		# сломанный», хотя сломано было место, куда его положили.
		var host : Node = get_parent().get_node_or_null("Spawner") if get_parent() != null \
			else null
		if host != null:
			var box := Area2D.new()
			box.set_script(_MAGIC_BOX_SCRIPT)
			box.set("speed", spd)   # ящик едет с потоком, как заменённый предмет
			# Позиция ставится ДО добавления, а добавление откладывается: попадание
			# приходит из обработки столкновений, и новый Area2D прямо посреди неё
			# физика принять не может («can't change this state while flushing»).
			box.position = (host as Node2D).to_local(pos) if host is Node2D else pos
			host.call_deferred("add_child", box)
		_vfx_particles(SkinSkills.TRANSFORM)
		_play_oneshot(_SFX_POOF, -3.0)
		return true

func _transform_handler() -> Callable:
	return func(node):
		if not is_instance_valid(node):
			return false
		var pos : Vector2 = (node as Node2D).global_position
		# Inherit the original item's speed so the transformed pizza/dollar keeps
		# drifting at the same pace instead of snapping to a fixed speed.
		var spd := 250.0
		if node.get("speed") != null:
			spd = float(node.get("speed"))
		if node.has_method("on_hit"):
			node.on_hit()
		else:
			node.queue_free()
		_spawn_transformed(pos, spd)
		_vfx_particles(SkinSkills.TRANSFORM)
		return true

# «Размен» классики: задетый предмет становится ИМЕННО долларом. Отдельно от
# _transform_handler: тот бросает монетку пицца-или-доллар, а здесь обещание
# спелла — деньги, и выпавшая пицца читалась бы как осечка.
func _to_dollar_handler() -> Callable:
	return func(node):
		if not is_instance_valid(node):
			return false
		var pos : Vector2 = (node as Node2D).global_position
		var spd := 250.0
		if node.get("speed") != null:
			spd = float(node.get("speed"))
		if node.has_method("on_hit"):
			node.on_hit()
		else:
			node.queue_free()
		_spawn_transformed(pos, spd, true)
		_vfx_particles(SkinSkills.COUNTER)
		_show_cash_face()
		return true

# Рука с пальцем на выстреле классики. У неё в кадре нет ни рук, ни оружия —
# стрелять ей нечем, и «Размен» оставался выстрелом из ниоткуда. Рука появляется
# у головы и показывает пальцем туда, куда ушёл снаряд.
#
# Тот же приём, что у пальца-указателя в подсказках интерфейса: жест понятен без
# подписи, и глаз идёт по нему в сторону выстрела.
const _POINT_HAND_TEX : Texture2D = preload("res://assets/skills/classic/hand.png")
const POINT_HAND_PX   : float = 58.0
const POINT_HAND_T    : float = 0.40

func _pop_pointing_hand(dir: Vector2) -> void:
	var host := get_parent()
	if host == null:
		return
	var spr := _make_sprite(_POINT_HAND_TEX, POINT_HAND_PX)
	spr.z_index = 39
	# Рука нарисована пальцем вправо, поэтому доворачиваем её по направлению
	# тапа; при выстреле влево переворачиваем, чтобы не висела вверх ногами.
	spr.rotation = dir.angle()
	if dir.x < 0.0:
		spr.scale.y = -spr.scale.y
	spr.global_position = global_position + dir * 34.0
	var full := spr.scale
	spr.scale = full * 0.5
	host.add_child(spr)
	var tw := spr.create_tween()
	tw.tween_property(spr, "scale", full, POINT_HAND_T * 0.35)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(spr, "global_position",
		spr.global_position + dir * 18.0, POINT_HAND_T)
	tw.tween_property(spr, "modulate:a", 0.0, POINT_HAND_T * 0.4)
	tw.tween_callback(spr.queue_free)

# Реакция на УДАЧНЫЙ размен: доллары в глазах. Показывается по попаданию, а не
# по касту — в этом вся разница с позой каста. Промахнулся мимо предмета — лицо
# не меняется, и это честно: денег-то не появилось.
const CASH_FACE_TIME : float = 0.45
var _cash_face_token : int = 0

func _show_cash_face() -> void:
	if _morphing or SaveData.active_skin != "classic":
		return
	if fat_state >= _CLASSIC_CASH_TEX.size():
		return
	_cash_face_token += 1
	var tok := _cash_face_token
	# Тем же токеном, что и поза каста: иначе два кадра дерутся за спрайт, и
	# чей таймер придёт вторым, тот и вернёт голову раньше времени.
	_spell_pose_token += 1
	var pose_tok := _spell_pose_token
	_show_head(_CLASSIC_CASH_TEX[fat_state], "_cash")
	await get_tree().create_timer(CASH_FACE_TIME).timeout
	if is_instance_valid(self) and tok == _cash_face_token \
			and pose_tok == _spell_pose_token and not _morphing:
		_update_mouth()

func _slow_handler() -> Callable:
	return func(node):
		if not is_instance_valid(node):
			return false
		if node.get("speed") != null:
			node.set("speed", float(node.get("speed")) * 0.35)
		if node.has_node("Sprite2D"):
			(node.get_node("Sprite2D") as Sprite2D).modulate = Color(0.7, 0.85, 1.0)
		return false

# Spawn a pizza or dollar where an obstacle was (Трансформус).
# `force_dollar` — для «Размена» классики, где монетка не бросается.
func _spawn_transformed(pos: Vector2, speed: float = 250.0,
		force_dollar: bool = false) -> void:
	var as_pizza := randf() < 0.5 and not force_dollar
	var item := _ITEM_SCENE.instantiate()
	item.speed      = speed
	item.is_eatable = as_pizza
	item.damage     = 0
	item.rotates    = true
	item.pulses     = as_pizza
	if not as_pizza:
		item.item_group = "dollar"
	var sprite := item.get_node("Sprite2D") as Sprite2D
	sprite.texture = _PIZZA_TEX if as_pizza else _DOLLAR_TEX
	sprite.scale   = Vector2.ONE * (0.09 if as_pizza else 0.36)
	get_parent().add_child(item)
	item.global_position = pos
	_play_oneshot(_SFX_POOF, -3.0)   # poof: item → pizza/dollar

# ── Skill VFX / SFX ──────────────────────────────────────────────────────────

func _play_skill_sfx(skill_type: String) -> void:
	match skill_type:
		SkinSkills.DODGE:
			_skill_audio.stream    = _SKILL_SFX_DODGE
			_skill_audio.volume_db = -8.0
		SkinSkills.ADAPT:
			_skill_audio.stream    = BANANA_SOUND
			_skill_audio.volume_db = -14.0
		SkinSkills.COUNTER:
			_skill_audio.stream    = _SKILL_SFX_COUNTER
			_skill_audio.volume_db = -4.0
		SkinSkills.TRANSFORM:
			_skill_audio.stream    = _SKILL_SFX_TRANSFORM
			_skill_audio.volume_db = -8.0
	_skill_audio.play()

func _vfx_particles(skill_type: String) -> void:
	var p                      := CPUParticles2D.new()
	p.emitting                  = true
	p.one_shot                  = true
	p.explosiveness             = 0.85
	p.amount                    = 14
	p.lifetime                  = 0.45
	p.direction                 = Vector2.ZERO
	p.spread                    = 180.0
	p.gravity                   = Vector2(0, -40)
	p.initial_velocity_min      = 55.0
	p.initial_velocity_max      = 110.0
	p.scale_amount_min          = 3.0
	p.scale_amount_max          = 7.0
	p.emission_shape            = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius    = 10.0
	var base_col : Color
	match skill_type:
		SkinSkills.DODGE:      base_col = Color(0.25, 0.75, 1.00)
		SkinSkills.ADAPT:      base_col = Color(1.00, 0.85, 0.20)
		SkinSkills.COUNTER:    base_col = Color(1.00, 0.45, 0.10)
		SkinSkills.TRANSFORM:  base_col = Color(0.30, 1.00, 0.50)
		_:                     base_col = Color(1.00, 1.00, 1.00)
	p.color = base_col
	var g := Gradient.new()
	g.set_color(0, Color(base_col.r, base_col.g, base_col.b, 1.0))
	g.add_point(1.0, Color(base_col.r, base_col.g, base_col.b, 0.0))
	p.color_ramp = g
	get_parent().add_child(p)
	p.global_position = global_position
	var tw := p.create_tween()
	tw.tween_interval(p.lifetime + 0.1)
	tw.tween_callback(p.queue_free)

func _vfx_dodge_flash() -> void:
	var tw := create_tween()
	tw.tween_property(_sprite, "modulate", Color(0.40, 0.80, 1.00), 0.05)
	tw.tween_property(_sprite, "modulate", Color(1.00, 1.00, 1.00), 0.18)

func _vfx_unique_trigger() -> void:
	var skin := SkinRegistry.get_skin(SaveData.active_skin)
	var rc   = SkinRegistry.RARITY_COLORS[skin.get("rarity", 0)]
	var tw   := create_tween()
	tw.tween_property(_sprite, "modulate", Color(rc.r * 1.8, rc.g * 1.8, rc.b * 1.8), 0.07)
	tw.tween_property(_sprite, "modulate", Color(1.0, 1.0, 1.0), 0.35)
	var p                     := CPUParticles2D.new()
	p.emitting                 = true
	p.one_shot                 = true
	p.explosiveness            = 0.9
	p.amount                   = 24
	p.lifetime                 = 0.6
	p.direction                = Vector2.ZERO
	p.spread                   = 180.0
	p.gravity                  = Vector2(0, -30)
	p.initial_velocity_min     = 70.0
	p.initial_velocity_max     = 150.0
	p.scale_amount_min         = 4.0
	p.scale_amount_max         = 9.0
	p.emission_shape           = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius   = 16.0
	p.color                    = rc
	var g := Gradient.new()
	g.set_color(0, Color(rc.r, rc.g, rc.b, 1.0))
	g.add_point(1.0, Color(rc.r, rc.g, rc.b, 0.0))
	p.color_ramp               = g
	get_parent().add_child(p)
	p.global_position = global_position
	var tw2 := p.create_tween()
	tw2.tween_interval(p.lifetime + 0.1)
	tw2.tween_callback(p.queue_free)

func _show_floating_text(text: String, col: Color) -> void:
	var lbl := Label.new()
	lbl.add_theme_font_override("font", UI_FONT)
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.text     = text
	lbl.modulate = col
	get_parent().add_child(lbl)
	lbl.global_position = global_position + Vector2(-20.0, -30.0)
	var tw := lbl.create_tween()
	tw.tween_property(lbl, "global_position:y", lbl.global_position.y - 45.0, 0.75) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.75).set_ease(Tween.EASE_IN)
	tw.tween_callback(lbl.queue_free)

# ── Wizard magic ──────────────────────────────────────────────────────────────

func _activate_wizard_magic() -> void:
	_wizard_bonus_type   = randi() % 3
	_wizard_bonus_active = true
	_wizard_bonus_timer  = 5.0
	_vfx_unique_trigger()
	_play_skill_sfx(SkinSkills.TRANSFORM)
	_wizard_start_aura()
	wizard_state_changed.emit(0, true, _wizard_bonus_type, _wizard_bonus_timer)
	match _wizard_bonus_type:
		0:
			if _magnet_remaining <= 0.0:
				_magnet_remaining = 3.0
			_show_floating_text("МАГНИТ!", Color(0.30, 0.85, 1.00))
		1: _show_floating_text("×2 XP!", Color(0.75, 0.50, 1.00))
		2: _show_floating_text("УСКОРЕНИЕ!", Color(1.00, 0.75, 0.20))

func _wizard_aura_color() -> Color:
	match _wizard_bonus_type:
		0: return Color(0.30, 0.85, 1.00)
		1: return Color(0.75, 0.50, 1.00)
		2: return Color(1.00, 0.75, 0.20)
		_: return Color(0.70, 0.40, 1.00)

func _wizard_start_aura() -> void:
	_wizard_cleanup_aura()
	var p                      := CPUParticles2D.new()
	p.emitting                  = true
	p.one_shot                  = false
	p.amount                    = 18
	p.lifetime                  = 0.70
	p.explosiveness             = 0.0
	p.randomness                = 0.60
	p.direction                 = Vector2(0, 1)
	p.spread                    = 90.0
	p.gravity                   = Vector2(0, 100)
	p.initial_velocity_min      = 35.0
	p.initial_velocity_max      = 85.0
	p.scale_amount_min          = 2.5
	p.scale_amount_max          = 5.5
	p.emission_shape            = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius    = 18.0
	p.z_index                   = -1
	var c := _wizard_aura_color()
	p.color = c
	var g := Gradient.new()
	g.set_color(0, Color(c.r, c.g, c.b, 0.85))
	g.add_point(1.0, Color(c.r, c.g, c.b, 0.0))
	p.color_ramp = g
	add_child(p)
	p.position   = Vector2(0, 30)
	_wizard_aura = p

func _wizard_cleanup_aura() -> void:
	if is_instance_valid(_wizard_aura):
		_wizard_aura.emitting = false
		var tw := _wizard_aura.create_tween()
		tw.tween_interval(_wizard_aura.lifetime + 0.05)
		tw.tween_callback(_wizard_aura.queue_free)
	_wizard_aura = null

# ── Core gameplay ─────────────────────────────────────────────────────────────

# Потолок жира задаёт лестница скина: 4-е состояние открывает награда 2-го
# уровня (см. skin_progression.gd). Раньше пороги были зашиты здесь и одинаковы
# для всех скинов.
func _max_fat_state() -> int:
	return SkinProgression.max_fat_state(SaveData.active_skin, SaveData.skin_level)

func _eat_pizza() -> void:
	_pizza_count       += 1
	_total_pizza_count += 1
	if _loot_tally_active:
		_loot_pizza_tally += 1

	# Wizard: extra XP on boost
	if _wizard_bonus_active and _wizard_bonus_type == 1:
		_total_pizza_count += 1
	# (Legacy wizard «Колдовство» bonus retired — Wizard has no passive now.)

	var new_state := fat_state
	for i in FAT_THRESHOLDS.size():
		if _pizza_count >= FAT_THRESHOLDS[i]:
			new_state = i + 1
	# The skin-level cap only limits how far EATING can raise fat — it must never
	# LOWER an already-higher state (e.g. the slots golden pizza over-fattens to
	# uber; catching a pizza afterwards must not drop you back to the level cap).
	new_state = maxi(fat_state, mini(new_state, _max_fat_state()))
	var got_fatter := new_state > fat_state
	fat_state = new_state
	stats_changed.emit(fat_state, _pizza_count, _total_pizza_count)

	if got_fatter:
		_fat_audio.play()
		play_fat_morph()   # spin into a point, re-emerge in the new fat sprite
		# Joker passive «Знаешь, откуда эти шрамы?»: 5 s of invulnerability, shown
		# as the Casey mask worn on the head.
		if _scars_passive:
			_activate_scars()
	else:
		# Звук поедания — случайный из двух; в мини-игре питчуется по размеру.
		_audio.stream = _skin_eat_sfx[randi() % _skin_eat_sfx.size()]
		_audio.pitch_scale = _eat_pitch()
		_audio.play()
		# Анимация: открытый рот на EAT_ANIM_TIME, потом обратно
		_eating    = true
		_eat_timer = EAT_ANIM_TIME
		_show_eat_frame()

func set_dev_immortal(v: bool) -> void:
	_dev_immortal = v

func _take_hit(damage: int = 1) -> void:
	if fat_state == 0:
		# Dev immortality: skip death entirely, just brief invincibility + flash.
		if _dev_immortal:
			_audio.stream = _skin_hit_sfx
			_audio.play()
			_flash_hit()
			_spawn_hit_bubble()
			_invincible = true
			await get_tree().create_timer(1.0).timeout
			_invincible = false
			return
		# Harry Potter second chance
		if _harry_second_chance_ready and SaveData.active_skin == "harry_potter":
			_harry_second_chance_ready = false
			fat_state    = 1
			_pizza_count = 0
			# Re-apply through the helper so scale + x-offset are recomputed for
			# the new texture. Just swapping `_sprite.texture` leaves the previous
			# state's scale/offset in place, which drifts the sprite off its
			# CollisionShape2D when texture widths differ across fat states.
			_apply_skin_to_sprite()
			_vfx_unique_trigger()
			_play_skill_sfx(SkinSkills.TRANSFORM)
			_show_floating_text("ВТОРОЙ ШАНС!", Color(1.00, 0.85, 0.15))
			_flash_hit()
			_spawn_hit_bubble()
			stats_changed.emit(fat_state, _pizza_count, _total_pizza_count)
			unique_ability_changed.emit(false)
			_invincible = true
			await get_tree().create_timer(1.5).timeout
			_invincible = false
			return
		_die()
		return

	# Dracula immortality: fire before applying damage that would reach 0
	var new_fat := fat_state - damage
	if new_fat <= 0 and _dracula_immortal_ready and SaveData.active_skin == "dracula":
		_dracula_immortal_ready = false
		fat_state    = 1
		_pizza_count = 0
		# Re-apply through the helper so scale + x-offset are recomputed for
		# the new texture. Just swapping `_sprite.texture` leaves the previous
		# state's scale/offset in place, which drifts the sprite off its
		# CollisionShape2D when texture widths differ across fat states.
		_apply_skin_to_sprite()
		_vfx_unique_trigger()
		_play_skill_sfx(SkinSkills.TRANSFORM)
		_show_floating_text("БЕЗ ПОТЕРИ ЖИРА!", Color(0.70, 0.15, 1.00))
		_flash_hit()
		_spawn_hit_bubble()
		stats_changed.emit(fat_state, _pizza_count, _total_pizza_count)
		unique_ability_changed.emit(false)
		_invincible = true
		await get_tree().create_timer(1.5).timeout
		_invincible = false
		return

	fat_state    = maxi(0, fat_state - damage)
	_pizza_count = 0 if fat_state == 0 else FAT_THRESHOLDS[fat_state - 1]
	# See note in the Harry-Potter branch — recompute scale + x-offset for
	# the new fat state, otherwise the slim sprite ends up offset from its
	# collision shape because textures have different widths per state.
	_apply_skin_to_sprite()
	_audio.stream   = _skin_hit_sfx
	_audio.play()
	_flash_hit()
	_spawn_hit_bubble()
	stats_changed.emit(fat_state, _pizza_count, _total_pizza_count)
	_invincible = true
	await get_tree().create_timer(1.5).timeout
	_invincible = false

func _pulse_fat() -> void:
	var tw := create_tween()
	tw.tween_property(_sprite, "scale", _base_scale * _head_k * 1.35, 0.12) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_sprite, "scale", _base_scale * _head_k, 0.22) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

	# Дрожание во время раздувания (параллельный tween, только по x)
	var shake_tw := create_tween()
	for i in 5:
		shake_tw.tween_property(_sprite, "position:x", 4.0 if i % 2 == 0 else -4.0, 0.024)
	shake_tw.tween_property(_sprite, "position:x", 0.0, 0.024)

func _flash_hit() -> void:
	var tween := create_tween()
	tween.set_loops(5)
	tween.tween_property(_sprite, "modulate", Color(1.0, 0.25, 0.25), 0.12)
	tween.tween_property(_sprite, "modulate", Color(1.0, 1.0, 1.0),   0.12)

# Random sticker (AHHH / DANG / SLAKEBAKE …) pops above Normaldo's head on
# damage. Fades in with a slight back-easing scale-up, holds briefly, then
# fades out and self-frees. Slightly randomised X offset and tilt so back-to-
# back hits don't stack into a single static sprite.
func _spawn_hit_bubble() -> void:
	_pop_sticker(Phrases.hit())

# Show a named comic reaction (e.g. "oops", "pow") over Normaldo's head.
func show_reaction(reaction: String) -> void:
	var tex = REACTIONS.get(reaction)
	if tex != null:
		_pop_sticker(tex)

func _pop_sticker(tex: Texture2D) -> void:
	if tex == null:
		return
	var bubble := Sprite2D.new()
	bubble.texture        = tex
	bubble.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	bubble.position       = _HIT_BUBBLE_OFFSET + Vector2(randf_range(-12.0, 12.0), 0.0)
	bubble.rotation       = randf_range(-0.15, 0.15)
	bubble.modulate       = Color(1.0, 1.0, 1.0, 0.0)
	bubble.z_index        = 6
	# По СОДЕРЖИМОМУ рисунка, а не по кадру: поля у выкриков разные, и общий
	# множитель делал одни вдвое крупнее других.
	ItemSizing.fit_sprite_content(bubble, _HIT_BUBBLE_PX)
	var peak : Vector2 = bubble.scale
	bubble.scale = peak * _HIT_BUBBLE_START_SC
	add_child(bubble)

	var tw := create_tween()
	tw.tween_property(bubble, "modulate:a", 1.0, _HIT_BUBBLE_IN_TIME)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(bubble, "scale", peak, _HIT_BUBBLE_IN_TIME)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(_HIT_BUBBLE_HOLD_TIME)
	tw.tween_property(bubble, "modulate:a", 0.0, _HIT_BUBBLE_OUT_TIME)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(bubble, "scale", peak * _HIT_BUBBLE_START_SC, _HIT_BUBBLE_OUT_TIME)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		if is_instance_valid(bubble):
			bubble.queue_free()
	)

func _ensure_attract_sparks(item: Node2D) -> void:
	if item.has_node("AttractSparks"):
		return
	var s                      := CPUParticles2D.new()
	s.name                      = "AttractSparks"
	s.z_index                   = 0
	s.emitting                  = true
	s.amount                    = 14
	s.lifetime                  = 0.50
	s.explosiveness             = 0.0
	s.direction                 = Vector2.ZERO
	s.spread                    = 180.0
	s.gravity                   = Vector2(0, -30)
	s.initial_velocity_min      = 30.0
	s.initial_velocity_max      = 65.0
	s.scale_amount_min          = 3.0
	s.scale_amount_max          = 6.0
	s.emission_shape            = CPUParticles2D.EMISSION_SHAPE_SPHERE
	s.emission_sphere_radius    = 8.0
	s.color                     = Color(0.4, 0.8, 1.0)
	var g                       := Gradient.new()
	g.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	g.add_point(0.3, Color(0.5, 0.9, 1.0, 1.0))
	g.add_point(0.7, Color(0.1, 0.4, 1.0, 0.7))
	g.add_point(1.0, Color(0.05, 0.1, 0.8, 0.0))
	s.color_ramp                = g
	item.add_child(s)
	item.move_child(s, 0)  # первый в дереве = рисуется раньше Sprite2D = за предметом

func _cleanup_attract_sparks() -> void:
	var spawner := get_parent().get_node_or_null("Spawner")
	if not spawner:
		return
	for child in spawner.get_children():
		var s := child.get_node_or_null("AttractSparks")
		if s:
			s.emitting = false
			var tw := s.create_tween()
			tw.tween_interval(s.lifetime)
			tw.tween_callback(s.queue_free)

func _collect_dollar() -> void:
	_dollars += 1
	if _loot_tally_active:
		_loot_dollar_tally += 1
	_dollar_audio.play()
	dollars_changed.emit(_dollars)

# ── Joker passive «Знаешь, откуда эти шрамы?» (Casey mask) ────────────────────
# Worn on the head for 5 s (invulnerable). The mask falls off when the timer
# ends OR the moment Normaldo ploughs into something (one-hit shield).
func _activate_scars() -> void:
	_begin_scars(5.0, true)

# Общая машинка «маска на голове + неуязвимость»: пассивка Джокера и предмет
# «маска Кейси» отличаются только длительностью и наличием гейта перезарядки.
func _begin_scars(duration: float, gated: bool) -> void:
	# Пассивка повторяемая, но не чаще раза в 60 c (скрытый гейт перезарядки).
	if gated and not is_skill_ready("scars_recharge"):
		return
	_scars_active = true
	_invincible   = true
	_scars_token += 1
	var tok := _scars_token
	start_skill_cd("passive:scars", duration)   # бейдж маски = окно неуязвимости
	if gated:
		start_skill_cd("scars_recharge", 60.0)
	_show_floating_text("НЕУЯЗВИМ!", Color(0.65, 0.25, 1.0))
	if not is_instance_valid(_scars_mask):
		_spawn_scars_mask()
	get_tree().create_timer(duration).timeout.connect(func():
		if is_instance_valid(self) and _scars_active and _scars_token == tok:
			_end_scars())

# ── Носимое на голове ────────────────────────────────────────────────────────
# Маска Кейси и шляпа мага надеваются ОДИНАКОВО: спрайт вешается ребёнком на
# спрайт головы. Оттого он и едет с ней, и крутится на морфе жира, и меняется
# вместе с кадром — своей синхронизации не нужно ни строчки.
#
# `width_k` — доля ШИРИНЫ ГОЛОВЫ, которую занимает вещь; `pos` — в тех же
# единицах, то есть в долях кадра головы, а не в пикселях экрана: голова у
# скинов разного размера, и пиксельный отступ уехал бы у каждого второго.
func _spawn_worn(tex: Texture2D, width_k: float, pos: Vector2) -> Sprite2D:
	var w := Sprite2D.new()
	w.texture        = tex
	w.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	w.z_index        = 6
	var head : Vector2 = _sprite.texture.get_size()
	w.scale    = Vector2.ONE * (head.x * width_k / tex.get_size().x)
	w.position = Vector2(pos.x * head.x, pos.y * head.y)
	w.modulate = Color(1, 1, 1, 0.0)
	_sprite.add_child(w)
	var tw := w.create_tween()
	tw.tween_property(w, "modulate:a", 1.0, 0.14)
	return w

# Шляпа сидит НАД головой и уже, чем маска: маска — это лицо, её кладут поверх
# морды, а шляпа надевается сверху и морду закрывать не должна.
const HAT_WIDTH_K : float = 0.74
const HAT_POS     : Vector2 = Vector2(0.02, -0.46)
var _hat_worn  : Sprite2D = null
var _hat_token : int = 0

func _wear_hat(duration: float) -> void:
	_hat_token += 1
	var tok := _hat_token
	if not is_instance_valid(_hat_worn):
		_hat_worn = _spawn_worn(_MAGIC_HAT_TEX, HAT_WIDTH_K, HAT_POS)
	# Подобрал вторую шляпу — эффект продлевается, и старый таймер снимать её
	# больше не должен: по токену он поймёт, что он уже не последний.
	get_tree().create_timer(duration).timeout.connect(func() -> void:
		if is_instance_valid(self) and _hat_token == tok:
			_drop_worn(_hat_worn)
			_hat_worn = null)

func _spawn_scars_mask() -> void:
	_scars_mask = _spawn_worn(_CASEY_TEX, 0.98, Vector2(0.0, -0.006))

func _end_scars() -> void:
	if not _scars_active:
		return
	_scars_active = false
	_scars_token += 1
	_invincible   = false
	_skill_cd.erase("passive:scars")   # badge vanishes
	_drop_scars_mask()

# Detach the mask from the head and let it tumble off the screen.
func _drop_scars_mask() -> void:
	if not is_instance_valid(_scars_mask):
		return
	var m := _scars_mask
	_scars_mask = null
	_drop_worn(m)

# Снять вещь с головы: она отцепляется, ПЕРЕСАЖИВАЕТСЯ В МИР с сохранением
# экранного положения и падает. Пересадка обязательна — оставшись ребёнком
# головы, она уезжала бы вместе с ней, и «слетела» читалось бы как «поехала».
func _drop_worn(m: Sprite2D) -> void:
	if not is_instance_valid(m):
		return
	var gp    := m.global_position
	var grot  := m.global_rotation
	var gscl  := m.global_scale
	_sprite.remove_child(m)
	get_parent().add_child(m)
	m.global_position = gp
	m.global_rotation = grot
	m.scale   = gscl
	m.z_index = 20
	var tw := m.create_tween()
	tw.set_parallel(true)
	tw.tween_property(m, "global_position", gp + Vector2(-24.0, 160.0), 0.75) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(m, "rotation", grot + 1.9, 0.75)
	tw.tween_property(m, "modulate:a", 0.0, 0.35).set_delay(0.42)
	tw.finished.connect(m.queue_free)

# Pirate «Сокровище» jackpot: pop the x3 graffiti above the caught dollar.
func _show_x3_popup(pos: Vector2) -> void:
	var spr := Sprite2D.new()
	spr.texture        = _X3_TEX
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.z_index        = 60
	var tsz := _X3_TEX.get_size()
	var sc  := 56.0 / maxf(tsz.x, tsz.y)
	spr.scale = Vector2(sc, sc) * 0.4
	get_parent().add_child(spr)
	spr.global_position = pos + Vector2(0, -24)
	var tw := spr.create_tween()
	tw.set_parallel(true)
	tw.tween_property(spr, "scale", Vector2(sc, sc), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(spr, "position:y", spr.position.y - 26.0, 0.7)
	tw.chain().tween_property(spr, "modulate:a", 0.0, 0.4)
	tw.chain().tween_callback(spr.queue_free)

func _die() -> void:
	_dead = true
	_touching = false
	_gauge.hide_gauge()
	_sprite.modulate = Color(0.8, 0.0, 0.0, 0.5)
	var death_stream = load("res://assets/audio/death.mp3")
	if death_stream:
		_audio.stream = death_stream
		_audio.play()
	var music := get_parent().get_node_or_null("Music") as AudioStreamPlayer
	if music and music.has_method("fade_out"):
		music.fade_out()
	Analytics.event("death", {
		"cause_group":    _last_hit_group,
		"cause_specific": _last_hit_name,
		"lane_y":         int(position.y),
		"fat_level":      int(fat_state),
		"pizza_count":    int(_total_pizza_count),
	})
	died.emit(_total_pizza_count + _skill_bonus_xp, position)

# Maps a colliding obstacle to one of the cause buckets used by analytics.
# Order matters — more specific groups win over the catch-all "obstacle".
func _classify_hit_group(area: Area2D) -> String:
	for grp in ["molotov", "fire", "glove", "snake", "bomb", "slowing"]:
		if area.is_in_group(grp):
			return grp
	return "obstacle"

# ── Collision dispatch ────────────────────────────────────────────────────────

func _on_area_entered(area: Area2D) -> void:
	if _dead: return

	# Электрический рывок Очков проходит НАСКВОЗЬ через всё, что бьёт: ни удара,
	# ни замедления, ни эффектов. А вот пиццу и доллары по пути он СОБИРАЕТ —
	# это и есть смысл целиться рывком, а не просто уходить от удара: игрок
	# выбирает линию, на которой больше добычи.
	#
	# Собирается только добыча-мелочь. Пачка, мешок, магнит, мутаген, автомат и
	# прочее, что ЗАПУСКАЕТ событие, сквозь рывок не берётся: подобранный на
	# лету мутаген влетал бы в мини-игру прямо посреди рывка, а рывок в это время
	# ещё тащит голову тюином.
	if _dash_active:
		if area.is_in_group("pizza"):
			_eat_pizza()
			area.queue_free()
		elif area.is_in_group("dollar"):
			_collect_dollar()
			area.queue_free()
		return

	if area.is_in_group("mutagen"):
		# FatBoss owns the freeze/mini-game; we just consume the pickup and signal.
		area.queue_free()
		mutagen_caught.emit()
		return
	if area.is_in_group("slot_machine"):
		area.queue_free()
		slot_machine_caught.emit()
		return

	# ЖИРОБОСС mini-game: the giant doesn't eat into the run score in real time.
	# Good items are tallied by fat_boss.gd (and credited at the end); bad items
	# shatter against the head. Routed here so the size/score logic stays untouched.
	if _fat_boss_active:
		if area.is_in_group("pizza") or area.is_in_group("dollar"):
			var kind := "dollar" if area.is_in_group("dollar") else "pizza"
			fat_boss_loot_collected.emit(kind, area.global_position)
			area.queue_free()
			return
		elif area.is_in_group("obstacle") or area.is_in_group("fire"):
			if area.has_method("knock_down"):
				area.knock_down()
			else:
				area.queue_free()
			return

	# ── Новые предметы ────────────────────────────────────────────────────────
	# Стоят ВЫШЕ веток obstacle/slowing намеренно: наручники и чёрный туз лежат
	# ещё и в группе obstacle (чтобы их сносил бумбокс и жёг молотов), и общая
	# ветка урона перехватила бы их раньше собственного эффекта.
	if area.is_in_group("handcuffs") or area.is_in_group("black_ace"):
		# Маска Кейси гасит их так же, как любое препятствие: ломается предмет,
		# маска слетает. Иначе получалось бы, что неуязвимость работает от бочки,
		# но не от наручников — а игрок видит один и тот же щит.
		if _scars_active:
			_last_hit_group = "handcuffs" if area.is_in_group("handcuffs") else "black_ace"
			_end_scars()
			_vfx_resist_break(area.global_position)
			_kill_item(area)
			return
		# Под невидимостью не срабатывают и они: и наручники, и чёрный туз —
		# негативные предметы, а спелл обещает пролёт сквозь любой такой.
		if _invincible:
			return
		var lethal := area.is_in_group("handcuffs")
		area.queue_free()
		if lethal:
			apply_handcuffs()
		else:
			apply_fat_burn()
		return
	if area.is_in_group("casey_mask"):
		area.queue_free()
		apply_casey_mask()
		return
	if area.is_in_group("magic_hat"):
		area.queue_free()
		apply_slow_immunity()
		return
	if area.is_in_group("cola"):
		area.queue_free()
		apply_speed_boost()
		return
	if area.is_in_group("loser_ticket"):
		area.queue_free()
		apply_loser_ticket()
		return
	if area.is_in_group("casino_chip"):
		area.queue_free()
		apply_casino_chip()
		return
	if area.is_in_group("hourglass"):
		area.queue_free()
		_apply_hourglass()
		return
	if area.is_in_group("magic_box"):
		area.open(self)
		return

	if area.is_in_group("pizza"):
		_eat_pizza()
		area.queue_free()
	elif area.is_in_group("pizza_pack"):
		area.explode()
	elif area.is_in_group("bomb"):
		area.explode()
	elif area.is_in_group("dollar"):
		# Pirate passive «Сокровище»: 50% chance the caught dollar pays ×3.
		if _treasure_passive and randf() < 0.5:
			for _i in 3:
				_collect_dollar()
			_vfx_particles(SkinSkills.TRANSFORM)
			_show_x3_popup(area.global_position)
			_show_floating_text("×3 $!", Color(1.0, 0.85, 0.20))
		else:
			_collect_dollar()
		area.queue_free()
	elif area.is_in_group("money_bag"):
		var mult := 2 if (SaveData.active_skin == "pirate") else 1
		if mult > 1:
			_vfx_particles(SkinSkills.TRANSFORM)
			_show_floating_text("×2 МЕШОК!", Color(1.0, 0.75, 0.15))
		area.burst(mult)
	elif area.is_in_group("magnet") and _magnet_remaining <= 0.0:
		_magnet_remaining = 3.0
		area.activate(self)
	elif area.is_in_group("compass"):
		if _invincible:
			return
		apply_invert(5.0)
		area.queue_free()
	elif area.is_in_group("slowing"):
		# Под невидимостью предмет пролетает насквозь: спелл обещает «пролетают
		# сквозь», и замедление — такой же негативный эффект, как удар.
		if _invincible:
			return
		# Резист (например, банан у Кусса) — предмет ломается, замедления нет.
		var stag := _area_tag(area)
		if stag != "" and _resist_cd_for.has(stag) and is_skill_ready("resist:" + stag):
			_trigger_resist(stag, area)
			return
		_audio.stream = area.get_meta("slow_sound")
		_audio.play()
		apply_slow(float(area.get_meta("slow_duration", 4.0)))
		area.queue_free()
	elif area.is_in_group("obstacle") or area.is_in_group("fire"):
		if _scars_active:
			# The Casey mask absorbs the impact: break the item, mask falls off.
			_last_hit_group = _classify_hit_group(area)
			_end_scars()
			_vfx_resist_break(area.global_position)
			_kill_item(area)
		elif not _invincible:
			_handle_obstacle(area)

# Пассивка Дракулы «ОТЖОР ЛЮДЕЙ». На карточке написано «сбил человека — и сразу
# толстеешь на 3 пиццы», без оговорок. А работала она ТОЛЬКО через резист: в
# волне бомжей, где резист либо не открыт, либо на откате, Дракула просто
# получал урон — то есть карточка обещала одно, а игра делала другое.
#
# «Человек» — это не только бомж: бандит, коп и шаман нарисованы людьми, и
# отжирать одного бомжа означало читать карточку выборочно. Ниндзя-нога сюда НЕ
# входит намеренно: это босс, и съесть его с одного касания — не пассивка, а
# отмена боя.
const HUMAN_TAGS : Array = ["bum", "thief", "cop", "shaman"]

func _bum_feast(tag: String) -> bool:
	if _passive_id != "bum_feast" or not HUMAN_TAGS.has(tag):
		return false
	for _i in 3:
		_eat_pizza()
	_vfx_particles(SkinSkills.TRANSFORM)
	_show_floating_text("+3", Color(0.72, 0.20, 1.00))
	return true

func _handle_obstacle(area: Area2D) -> void:
	# Cache the cause for analytics — _die() reads it. Prefer the most specific
	# group (snake/glove/molotov/fire) and fall back to the scene-file name.
	_last_hit_group = _classify_hit_group(area)
	_last_hit_name  = area.scene_file_path.get_file().get_basename() if area.scene_file_path != "" else area.name

	# Резист, открытый уровнем скина: если не на откате — предмет разбивается
	# вместо удара, и защита уходит на перезарядку.
	var tag := _area_tag(area)
	if tag != "" and _resist_cd_for.has(tag) and is_skill_ready("resist:" + tag):
		_trigger_resist(tag, area)
		return

	# Отжор людей: бомж не бьёт Дракулу, а идёт в еду.
	if _bum_feast(tag):
		_vfx_resist_break(area.global_position)
		_kill_item(area)
		return

	var dmg := int(area.get("damage")) if area.get("damage") != null else 1
	_take_hit(dmg)
	if area.get("slow_on_hit"):
		apply_slow(float(area.get("slow_duration")))
	# Предметы вроде яда травят сверх урона, шаман вдобавок разворачивает
	# управление — оба эффекта приходят метаданными от hazard_item.gd.
	if area.has_meta("slow_duration"):
		apply_slow(float(area.get_meta("slow_duration")))
	if area.has_meta("invert_duration"):
		apply_invert(float(area.get_meta("invert_duration")))
		_show_floating_text("ПРОКЛЯТИЕ!", Color(0.55, 1.00, 0.45))
	_kill_item(area)
