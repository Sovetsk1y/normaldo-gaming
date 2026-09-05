extends Node2D

signal boss_time
signal phase_entered(phase: int)
# Уровень пройден. `boss` — кого звать (пусто, если на этом уровне босса нет),
# `next_level` — номер следующего, 0 если кампания кончилась.
signal level_cleared(boss: String, next_level: int)

const ITEM_SCENE         := preload("res://scenes/item.tscn")
const PIZZA_PACK_SCENE   := preload("res://scenes/pizza_pack.tscn")
const BOOMBOX_SCENE      := preload("res://scenes/boombox.tscn")
const MAGNET_SCENE       := preload("res://scenes/magnet.tscn")
const BANANA_PEEL_SCENE  := preload("res://scenes/banana_peel.tscn")
const BEER_SCENE         := preload("res://scenes/beer.tscn")
const BOXING_GLOVE_SCENE := preload("res://scenes/boxing_glove.tscn")
const SNAKE_SCENE        := preload("res://scenes/snake.tscn")
const MONEY_BAG_SCENE    := preload("res://scenes/money_bag.tscn")
const DOG_SCENE          := preload("res://scenes/dog.tscn")
const HOMELESS_SCENE     := preload("res://scenes/homeless.tscn")
const BUM_BARREL_SCRIPT  := preload("res://scripts/bum_barrel.gd")
const MOLOTOV_SCENE      := preload("res://scenes/molotov.tscn")
# Новые предметы (script-only Area2D).
const COMPASS_SCRIPT       := preload("res://scripts/compass_item.gd")
const ROADSIGN_BUM_SCRIPT  := preload("res://scripts/roadsign_bum.gd")
const CONE_SCRIPT          := preload("res://scripts/cone.gd")
const THIEF_SCRIPT         := preload("res://scripts/thief.gd")
# Предметы-эффекты: один скрипт на восемь видов, вид задаётся полем `kind`.
const EFFECT_ITEM_SCRIPT   := preload("res://scripts/effect_item.gd")
const MAGIC_BOX_SCRIPT     := preload("res://scripts/magic_box.gd")
const NINJA_SCRIPT         := preload("res://scripts/ninja_item.gd")
# Семь угроз под резисты скинов: сейф, коктейль, коп, яд, птица, штурвал, шаман.
const HAZARD_ITEM_SCRIPT   := preload("res://scripts/hazard_item.gd")
const PIZZA_TEX          := preload("res://assets/items/pizza.png")
const TRASH_TEX          := preload("res://assets/items/trash_bin.png")
const STONE_TEX          := preload("res://assets/items/stone.png")
const DOLLAR_TEX         := preload("res://assets/items/dollar.png")

const LANE_COUNT : int = 5

# ── Endless mode phase progression ────────────────────────────────────────────
# First 5 phases (Crescendo, 0–7 min) mirror the campaign ramp.
# Phases 5+ (Безумие, 7+ min) stack modifiers every 90 s:
#   no_t1        — T1 patterns excluded (T1 weight forced to 0)
#   trash_only   — T1 negatives are always trash bins (damage 1)
#   short_gap    — POST_PAT_GAPS × 0.7
#   molotov_plus — molotov fire_count + 1
#   twin_pat     — 35 % chance to chain a second pattern with no inter-gap

const ENDLESS_PHASES : Array = [
	{ "name": "Разогрев",    "duration":  60.0, "speed": 220.0, "weights": [7, 3, 0, 0], "mods": {} },
	{ "name": "Поток",       "duration":  80.0, "speed": 242.0, "weights": [2, 5, 3, 0], "mods": {} },
	{ "name": "Натиск",      "duration":  90.0, "speed": 264.0, "weights": [0, 2, 4, 4], "mods": {} },
	{ "name": "Шторм",       "duration":  90.0, "speed": 297.0, "weights": [0, 1, 3, 6], "mods": {} },
	{ "name": "Ад",          "duration": 100.0, "speed": 330.0, "weights": [0, 0, 2, 8], "mods": {} },
	{ "name": "Безумие I",   "duration":  90.0, "speed": 350.0, "weights": [0, 0, 1, 9],  "mods": { "no_t1": true } },
	{ "name": "Безумие II",  "duration":  90.0, "speed": 370.0, "weights": [0, 0, 1, 9],  "mods": { "no_t1": true, "trash_only": true, "short_gap": true } },
	{ "name": "Безумие III", "duration":  90.0, "speed": 390.0, "weights": [0, 0, 0, 10], "mods": { "no_t1": true, "trash_only": true, "short_gap": true, "molotov_plus": true } },
	{ "name": "Безумие IV",  "duration":  90.0, "speed": 410.0, "weights": [0, 0, 0, 10], "mods": { "no_t1": true, "trash_only": true, "short_gap": true, "molotov_plus": true, "twin_pat": true } },
	{ "name": "Безумие V",   "duration":   INF, "speed": 420.0, "weights": [0, 0, 0, 10], "mods": { "no_t1": true, "trash_only": true, "short_gap": true, "molotov_plus": true, "twin_pat": true } },
]

# Calm-wave window after entering each Безумие phase (index ≥ 5).
# Pure T1 pizza line with no obstacles — breather + fat restoration.
const CALM_WAVE_PHASES_FROM : int   = 5
const CALM_WAVE_DURATION    : float = 4.0
const CALM_WAVE_LINE_COUNT  : int   = 7

# ── Pattern tier system (shared by both modes) ────────────────────────────────
# T0=T1 … T4=T5 in concept terms.
# POST_PAT_GAPS: seconds of silence after a pattern completes.
# BONUS_CHANCES: probability of a bonus item spawning between patterns.
# COL_SPACING:  target pixel gap between items in a line.

const POST_PAT_GAPS  : Array = [1.50, 0.65, 0.80, 0.70, 0.60]
const BONUS_CHANCES  : Array = [0.10, 0.12, 0.14, 0.16, 0.18]
const COL_SPACING    : float = 85.0   # ≥ размер предмета (~60px), чтобы не накладывались

# ── T4/T5 alternating batch sequence ─────────────────────────────────────────
# Even indices = glove waves (T4), odd = molotov waves (T5).
# After the last pair (8+8), the final pair loops indefinitely.
const T45_BATCH_SIZES : Array = [3, 3, 5, 5, 8, 8]

# ── Campaign phases ───────────────────────────────────────────────────────────
# pat_tier maps directly to phase index (capped at 4 = T5).
# Phase 5 is the 10-second pre-boss pressure window with no pizza.

@export var campaign_mode  : bool  = false
@export var boss_test_mode : bool  = false

# ── Как идёт цепочка уровней ─────────────────────────────────────────────────
# ЭПИЗОД (endless_chain = false) — играется ОДИН уровень и его босс, после
# победы забег кончается. Эпизоды открываются по одному, и каждый ведёт свой
# зачёт в таблице лидеров: у всех игроков одна и та же дистанция, поэтому счёт
# в эпизоде сравним честно.
#
# БЕСКОНЕЧНЫЙ (endless_chain = true) — все три уровня подряд, и после третьего
# круг начинается заново с первого. Сложность при этом НЕ ОТКАТЫВАЕТСЯ: скорость
# растёт по общему времени забега, а фаза не опускается ниже уже достигнутой
# (`_phase_floor`). Без этого второй круг был бы легче первого, и «бесконечный»
# превратился бы в «повторяющийся».
@export var endless_chain  : bool  = false

# Наибольшая фаза за забег. Нужна только бесконечному: при переходе на новый
# круг уровень тянет за собой свою стартовую планку, и без этого пола первый
# уровень второго круга начинался бы с нуля.
var _phase_floor : int = 0

const BOSS_TEST_DELAY : float = 10.0
var _boss_test_t      : float = 0.0

# Длина эпизода — 285 c (4:45) вместо прежних 420 c (7:00). Семь минут до
# босса не выдерживал никто из тестеров: пик интереса приходился на 3-4-ю
# минуту, дальше шло повторение уже показанных сет-писов. Резали пропорционально
# (×0.68), поэтому форма кривой сложности осталась прежней — просто плотнее.
# Каденцию сет-писов в CAMPAIGN_DIRECTOR ужали тем же коэффициентом, иначе на
# укороченных фазах успевало показаться вдвое меньше сценок.
# Длительности пересчитаны под БУКВЫ: эпизод теперь кончается не по таблице фаз,
# а после последней буквы NORMALDO (см. «Буквы»), то есть на 240-й секунде.
# Прежние 285 с ужаты ×0.842 — пропорционально, поэтому форма кривой сложности
# осталась прежней, изменилась только длина.
# ── Пять уровней кампании ─────────────────────────────────────────────────────
# Из старого проекта перенесены все пять локаций, одна за другой, каждая своей
# нарисованной полосой (см. background.gd). Боссы стоят там же, где стояли: Нога
# Ниндзя в конце первого, Крокодил в конце второго, Хозяин клуба в конце пятого.
# Третий и четвёртый босса не имеют — и это не пробел, а ритм: два уровня подряд
# с боссом и два без него дают кампании дыхание, а пятый читается как финал
# именно потому, что до него боссов не было давно.
#
# КОНЕЦ УРОВНЯ — ЭТО ПОСЛЕДНЯЯ БУКВА. Слово NORMALDO выкладывается заново на
# каждом уровне, и восьмая буква означает «уровень кончился»: на уровнях с
# боссом сразу за ней выходит босс, на остальных — карточка следующего уровня.
# Часы, которые не надо рисовать отдельно, и одни и те же на всю кампанию.
#
#   letter — период между буквами. Он же и задаёт длину уровня: восемь букв
#            плюс их собственный пролёт (~5 с каждая). Уровни укорачиваются к
#            финалу: 8×(14+5)=152 с в начале и 8×(10+5)=120 с в конце.
#   phase  — с какой фазы сложности уровень НАЧИНАЕТСЯ. Внутри уровня фазы идут
#            дальше по таблице, но стартовая планка с каждым уровнем выше:
#            иначе третий уровень начинался бы так же вяло, как первый.
# ТРИ УРОВНЯ, ТРИ БОССА. Нарисованных полос фона пять, но помещений на них три:
# полосы 2 и 3 — один и тот же путь по улице, 4 и 5 — один и тот же двор перед
# клубом (см. background.LEVEL_STRIPS). Пять уровней на трёх помещениях давали
# два «перехода», после которых игрок оказывался ровно там же, откуда ушёл.
#
# Боссов ровно три, и теперь они встают по одному на уровень: нога ниндзя,
# крокодил, хозяин клуба. Раньше два уровня из пяти кончались без боя — то есть
# просто обрывались карточкой.
const CAMPAIGN_LEVELS : Array = [
	{ "name": "КАНАЛИЗАЦИЯ",   "boss": "ninja", "letter": 14.0, "phase": 0 },
	{ "name": "УЛИЦА",         "boss": "croc",  "letter": 12.0, "phase": 2 },
	{ "name": "ДОРОГА В КЛУБ", "boss": "club",  "letter": 10.0, "phase": 4 },
]

# Текущий уровень, 0-based. Публичный: интерфейс рисует по нему карточку и
# счётчик, фон — свою полосу.
var level : int = 0

func level_name() -> String:
	return String(CAMPAIGN_LEVELS[clampi(level, 0, CAMPAIGN_LEVELS.size() - 1)]["name"])

func level_boss() -> String:
	return String(CAMPAIGN_LEVELS[clampi(level, 0, CAMPAIGN_LEVELS.size() - 1)]["boss"])

const CAMPAIGN_PHASES : Array = [
	{ "speed": 220.0, "duration":  38.0, "no_pizza": false },  # T1
	{ "speed": 242.0, "duration":  46.0, "no_pizza": false },  # T2
	{ "speed": 264.0, "duration":  50.0, "no_pizza": false },  # T3
	{ "speed": 297.0, "duration":  50.0, "no_pizza": false },  # T4
	{ "speed": 330.0, "duration":  42.0, "no_pizza": false },  # T5
	{ "speed": 330.0, "duration":  14.0, "no_pizza": true  },  # pre-boss
]

# Per-phase pattern tier weights: [T1_w, T2_w, T3_w, T45_w]
# Probability shifts toward harder patterns as phases progress.
const CAMPAIGN_PAT_WEIGHTS : Array = [
	[7, 3, 0, 0],  # Phase 0: 70% T1, 30% T2
	[2, 5, 3, 0],  # Phase 1: 20% T1, 50% T2, 30% T3
	[0, 2, 4, 4],  # Phase 2: 20% T2, 40% T3, 40% T4/T5
	[0, 1, 3, 6],  # Phase 3: 10% T2, 30% T3, 60% T4/T5
	[0, 0, 2, 8],  # Phase 4: 20% T3, 80% T4/T5
]

# ── Episode-1 "director" (campaign only) ──────────────────────────────────────
# Hybrid spawn: a weighted RANDOM baseline stream interleaved with scripted
# SET-PIECES (reusing the tier pattern fns). Config per phase (0-4):
#   res  — probability a random spawn is a resource (else a hazard)
#   int  — seconds between random spawns (density)
#   cad  — seconds between set-pieces
#   sp   — eligible set-piece ids for this phase
# See /Концепция/Эпизод 1 — прогрессия предметов (редизайн).md
# ЭКРАН НЕ ДОЛЖЕН ПУСТОВАТЬ. Интервалы сжаты примерно на четверть, а сет-писы
# приходят в полтора раза чаще: между двумя событиями игрок не должен успевать
# заскучать, а «сложные предметы с анимацией» — бомж с бочкой, волна бомжей,
# каскад, конус-переросток — и есть то, ради чего забег смотрят.
#
# Сжаты именно ИНТЕРВАЛЫ, а не доля ресурсов: соотношение «еда/угроза» подобрано
# отдельно и трогать его — значит менять сложность, а не плотность.
const CAMPAIGN_DIRECTOR : Array = [
	{ "res": 0.90, "int": 0.62, "cad": 14.0, "sp": ["sandwich", "zigzag", "cone", "bum_crowd"] },
	{ "res": 0.76, "int": 0.54, "cad": 12.0, "sp": ["sandwich", "zigzag", "barrel_cascade", "snake_columns", "bum_crowd", "bum_barrel", "glove_wave", "cone"] },
	{ "res": 0.66, "int": 0.48, "cad": 10.0, "sp": ["barrel_cascade", "snake_columns", "stone_chess", "bum_wall", "bum_crowd", "bum_barrel", "diagonal", "glove_wave", "cone"] },
	{ "res": 0.58, "int": 0.42, "cad":  9.0, "sp": ["snake_columns", "stone_chess", "glove_wave", "diagonal", "bum_wall", "bum_crowd", "bum_barrel", "cone"] },
	{ "res": 0.52, "int": 0.38, "cad":  8.0, "sp": ["stone_chess", "glove_wave", "molotov_wave", "diagonal", "bum_crowd", "bum_barrel"] },
]

# Item speed goes up in STEPS (background scrolls at a fixed, slower pace — see
# background.gd). Первое ускорение — на 16-й секунде (+10%), затем каждые 16 c ещё
# +10%, КОМПАУНДОМ (каждый шаг считается от уже ускоренного значения), до максимума.
const CAMPAIGN_SPEED_MIN   : float = 200.0
const CAMPAIGN_SPEED_MAX   : float = 360.0
const SPEEDUP_FIRST_AT     : float = 16.0    # когда срабатывает первое ускорение
const SPEEDUP_INTERVAL     : float = 16.0    # период между последующими ускорениями
const SPEEDUP_STEP         : float = 0.10    # +10% за шаг, компаундом

func _campaign_item_speed() -> float:
	if _elapsed < SPEEDUP_FIRST_AT:
		return CAMPAIGN_SPEED_MIN * world_speed_mult
	# Кол-во сработавших ускорений: 1 на 17-й секунде, +1 каждые SPEEDUP_INTERVAL.
	var steps := 1 + int((_elapsed - SPEEDUP_FIRST_AT) / SPEEDUP_INTERVAL)
	var mult  := pow(1.0 + SPEEDUP_STEP, float(steps))
	return minf(CAMPAIGN_SPEED_MIN * mult, CAMPAIGN_SPEED_MAX) * world_speed_mult
const LETHAL_SET_PIECES : Array = ["glove_wave", "molotov_wave"]
var _last_sp_at : float  = -999.0   # _elapsed at the last set-piece
var _last_sp_id : String = ""       # avoid immediate repeats

# ── Анти-наложение предметов разного размера ─────────────────────────────────
# Ударяющие предметы теперь спавнятся размером ×1…×3 (см. ItemSizing). Крупный
# экземпляр перестаёт помещаться в свой лейн: при высоте экрана 430 лейн равен
# 86 px, а предмет ×3 — это 180 px, то есть три лейна.
#
# Поэтому перед каждым спавном место РЕЗЕРВИРУЕТСЯ. Все предметы едут влево с
# одной скоростью, значит два предмета пересекаются только если совпали и по
# вертикали, и по времени спавна: горизонтальное расстояние между ними — это
# speed × разница во времени. Отсюда проверка ниже в две строки.
#
# Гарантии разные для двух видов спавна:
#   • ОДИНОЧНЫЙ (случайный поток, бонус между паттернами) — можно до ×3, после
#     чего следующая единица спавна ждёт, пока гигант уедет (_big_clear_t).
#   • В ПАТТЕРНЕ — только до PATTERN_MULT_MAX. Соседние лейны в паттернах заняты
#     осознанно, и предмет обязан остаться внутри своего: 86 px лейн против
#     2 × 37.5 px радиусов двух соседних ×1.25 — не пересекаются.
const SPAN_PAD         : float = 1.02   # с запасом: круги не должны касаться вовсе

# Потолок размера внутри паттерна выводится из двух геометрий поля, а не
# подбирается на глаз. Оба неравенства проверяет dev/smoke_items.gd:
#   по горизонтали  2 × BASE_R × PATTERN_MULT_MAX < COL_SPACING  (75 < 85)
#   по вертикали    BASE_R × (1 + PATTERN_MULT_MAX) < высота лейна (67.5 < 86)
# Первое держит два предмета подряд в одном лейне, второе — двух соседей в
# смежных лейнах. Поднимать потолок без пересчёта COL_SPACING нельзя.
const PATTERN_MULT_MAX : float = 1.25

var _spans       : Array = []     # [{y, r, t}] — занятое место
var _big_clear_t : float = -1.0   # до этого _elapsed нельзя начинать новую единицу

var _elapsed        : float = 0.0
var _spawn_timer    : float = 0.5
var _phase          : int   = 0
var _phase_elapsed  : float = 0.0

# Endless-only state
var _endless_mods   : Dictionary = {}

var _pat_tier        : int  = 0
var _pattern_running : bool = false
var _frozen          : bool = false

var _t45_batch_idx    : int  = 0
var _t45_in_batch     : int  = 0
var _t1_pattern_count : int  = 0
var _t1_trash         : bool = false

# Forced intro for campaign: first N patterns are guaranteed T1 center-line
# (pizza between bananas) — onboarding the player to the inertia mechanic.
const CAMPAIGN_INTRO_COUNT : int = 3
var _campaign_intro_left   : int = CAMPAIGN_INTRO_COUNT

func _ready() -> void:
	set_process(false)

func _process(delta: float) -> void:
	if boss_test_mode:
		_boss_test_t += delta
		if _boss_test_t >= BOSS_TEST_DELAY:
			boss_test_mode = false
			set_process(false)
			boss_time.emit()
			return

	_elapsed     += delta
	_spawn_timer -= delta

	if campaign_mode:
		_phase_elapsed += delta
		if not _pattern_running and not _frozen and _spawn_timer <= 0.0:
			_pattern_running = true
			_run_campaign_pattern()
		_tick_letters(delta)
		var dur := CAMPAIGN_PHASES[_phase]["duration"] as float
		if _phase_elapsed >= dur:
			_phase        += 1
			_phase_elapsed = 0.0
			_phase_floor   = mini(_phase, CAMPAIGN_PHASES.size() - 1)
			if _phase >= CAMPAIGN_PHASES.size():
				# Боссом командует ПОСЛЕДНЯЯ БУКВА, а не таблица фаз: иначе эпизод
				# кончался бы посреди слова. Кончились фазы — держимся на
				# последней и ждём букву.
				_phase = CAMPAIGN_PHASES.size() - 1
				_phase_elapsed = dur
				return
			phase_entered.emit(_phase)
			_spawn_timer = 0.8
			# Pre-boss phase doubles as a "loot rain" gauntlet: pizza + dollar
			# swarms keep arriving while molotov/glove waves try to wipe them.
			if _phase == CAMPAIGN_PHASES.size() - 1:
				_start_pre_boss_resource_rain()
	else:
		_phase_elapsed += delta
		if not _pattern_running and not _frozen and _spawn_timer <= 0.0:
			_pattern_running = true
			_run_endless_pattern()
		var dur := ENDLESS_PHASES[_phase]["duration"] as float
		if dur != INF and _phase_elapsed >= dur:
			_advance_endless_phase()

# ── Буквы NORMALDO ───────────────────────────────────────────────────────────
# Раз в 30 секунд поток ЗАМИРАЕТ и через экран проплывает одна буква слова
# NORMALDO — во весь экран по высоте, целиком собранная из пицц или из долларов.
#
# Зачем это нужно. Забег устроен как непрерывное давление: предметы идут стеной,
# и единственная пауза в нём — смерть. Оазис даёт ритм — восемь точек, в которых
# игрок не уворачивается, а СОБИРАЕТ, и по ним же читает, сколько эпизода
# осталось: буквы складываются в слово, и когда выложено NORMALDO — приходит
# босс. Это часы, которые не надо рисовать отдельно.
#
# Оазис означает буквально «никакие другие предметы не вылетают»: на время
# пролёта буквы поток заморожен. Буква, разбавленная бочками, перестаёт быть
# передышкой и становится обычным паттерном с редкой формой.
#
# Из пиццы буква или из долларов — бросок на каждую. Пицца кормит (жир, а с ним
# и запас жизней), доллар платит; смешивать в одной букве нельзя — тогда она
# читается как случайная россыпь, а не как выложенный знак.
#
# Глиф — сетка 5×7. Тот же формат, что у растровых шрифтов восьмибитных машин, и
# по той же причине: меньше пяти столбцов не читается M, больше семи строк не
# влезает в высоту экрана.
const LETTER_WORD   : String = "NORMALDO"
# Период БЕРЁТСЯ У УРОВНЯ (`CAMPAIGN_LEVELS.letter`), а не задан общим числом:
# слово выкладывается заново на каждом уровне, и оно же задаёт его длину.
# Константа осталась значением по умолчанию — для бесконечного режима и тестов,
# где таблицы уровней нет.
const LETTER_PERIOD : float  = 14.0
const LETTER_ROWS   : int    = 7
const LETTER_COLS   : int    = 5
const LETTER_H_FRAC : float  = 0.86    # какую долю высоты экрана занимает буква
const LETTER_GLYPHS : Dictionary = {
	"N": ["X...X", "XX..X", "X.X.X", "X.X.X", "X..XX", "X...X", "X...X"],
	"O": [".XXX.", "X...X", "X...X", "X...X", "X...X", "X...X", ".XXX."],
	"R": ["XXXX.", "X...X", "X...X", "XXXX.", "X.X..", "X..X.", "X...X"],
	"M": ["X...X", "XX.XX", "X.X.X", "X.X.X", "X...X", "X...X", "X...X"],
	"A": ["..X..", ".X.X.", "X...X", "X...X", "XXXXX", "X...X", "X...X"],
	"L": ["X....", "X....", "X....", "X....", "X....", "X....", "XXXXX"],
	"D": ["XXXX.", "X...X", "X...X", "X...X", "X...X", "X...X", "XXXX."],
	# W и I в слове NORMALDO не нужны — они для WIN, которое выкладывается
	# долларами после победы над боссом (см. `lay_word`). Живут здесь же, а не
	# отдельным словарём: два набора букв разошлись бы на первой же правке
	# сетки, и на экране завелись бы два шрифта.
	"W": ["X...X", "X...X", "X...X", "X.X.X", "X.X.X", "XX.XX", "X...X"],
	"I": ["XXXXX", "..X..", "..X..", "..X..", "..X..", "..X..", "XXXXX"],
}
# Пробел между буквами слова, в клетках. Без него WIN слипается в одну кляксу:
# у W правый столбец занят, у I левый — тоже.
const WORD_GAP_COLS : float = 1.0

var _letter_idx    : int   = 0
var _letter_timer  : float = LETTER_PERIOD
var _letter_active : bool  = false

func _letter_period() -> float:
	if not campaign_mode:
		return LETTER_PERIOD
	return float(CAMPAIGN_LEVELS[clampi(level, 0, CAMPAIGN_LEVELS.size() - 1)]["letter"])

func letters_done() -> int:
	return _letter_idx

func _tick_letters(delta: float) -> void:
	if _letter_active or _letter_idx >= LETTER_WORD.length():
		return
	_letter_timer -= delta
	if _letter_timer <= 0.0:
		_letter_timer = _letter_period()
		_run_letter()

# Выкладывает СЛОВО за правым краем экрана — по букве из сетки 5×7, целиком из
# пиццы или целиком из долларов. Возвращает, сколько ждать, пока слово пройдёт
# мимо игрока.
#
# Одной буквой это зовёт оазис NORMALDO, тремя — победа над боссом (WIN из
# долларов). Общий метод намеренно: обе выкладки — один и тот же приём, и
# разъехавшись, они разъехались бы и на экране.
func lay_word(word: String, as_pizza: bool, speed_override: float = -1.0) -> float:
	var vp    := get_viewport_rect().size
	var speed : float = speed_override if speed_override > 0.0 else _campaign_item_speed()
	var cell  : float = vp.y * LETTER_H_FRAC / float(LETTER_ROWS)
	var top   : float = (vp.y - cell * float(LETTER_ROWS)) * 0.5 + cell * 0.5
	var left  : float = vp.x + 90.0

	for i in word.length():
		var glyph : Array = LETTER_GLYPHS.get(word[i], LETTER_GLYPHS["O"])
		var ox : float = left + float(i) * cell * (float(LETTER_COLS) + WORD_GAP_COLS)
		for row in LETTER_ROWS:
			var line : String = glyph[row]
			for col in LETTER_COLS:
				if col >= line.length() or line[col] != "X":
					continue
				var item : Node = _make_item(
					PIZZA_TEX if as_pizza else DOLLAR_TEX,
					0.09 if as_pizza else 0.36,
					speed, 0, as_pizza, true, as_pizza)
				if not as_pizza:
					item.item_group = "dollar"
				item.position = Vector2(ox + float(col) * cell, top + float(row) * cell)
				add_child(item)

	# Держим, пока слово не пройдёт мимо игрока. Ждать полного ухода за левый
	# край незачем: за спиной у Нормальдо поток уже никому не мешает.
	var width : float = cell * (float(LETTER_COLS) * float(word.length())
		+ WORD_GAP_COLS * float(maxi(0, word.length() - 1)))
	return (left + width - 160.0) / maxf(speed, 1.0)

func _run_letter() -> void:
	var ch : String = LETTER_WORD[_letter_idx]
	_letter_idx += 1
	_letter_active   = true
	# Замораживаем ПОТОК, но не сам спавнер: set_process(false) остановил бы и
	# часы фаз, и отсчёт до следующей буквы.
	_frozen          = true
	_pattern_running = false

	var hold : float = lay_word(ch, randf() < 0.5)
	await get_tree().create_timer(hold).timeout
	if not is_inside_tree():
		return
	_letter_active = false
	_frozen        = false
	_spawn_timer   = 0.6
	_reset_spans()
	# Слово выложено — УРОВЕНЬ КОНЧИЛСЯ. Именно тут, а не по таблице фаз:
	# уровень должен кончаться на последней букве, а не посреди слова.
	if _letter_idx >= LETTER_WORD.length():
		_finish_level()

# Уровень пройден. Дальше решает интерфейс: на уровне с боссом он поднимает
# босса и вызовет `advance_level()` после победы, на уровне без босса — покажет
# карточку и вызовет её сразу.
func _finish_level() -> void:
	set_process(false)
	_frozen = true
	var boss : String = level_boss() if campaign_mode else "ninja"
	# Куда дальше. −1 означает «дальше некуда, забег кончился»:
	#   ЭПИЗОД кончается всегда — в нём ровно один уровень;
	#   БЕСКОНЕЧНЫЙ не кончается никогда — после третьего уровня круг заходит
	#   на первый.
	# Ноль здесь раньше значил «кампания пройдена», и это мешало: в
	# бесконечном ноль — законный номер следующего уровня.
	var nxt  : int = -1
	if campaign_mode and endless_chain:
		nxt = (level + 1) % CAMPAIGN_LEVELS.size()
	# `boss_time` оставлен ради всего, что уже на него подписано (задания,
	# аналитика, дев-кнопка): для них «дошёл до босса» не изменилось.
	if boss != "":
		boss_time.emit()
	level_cleared.emit(boss, nxt)

# Перейти на следующий уровень. Зовёт интерфейс — после победы над боссом или
# сразу, если босса на уровне не было.
func advance_level() -> void:
	if not campaign_mode:
		return
	if endless_chain:
		level = (level + 1) % CAMPAIGN_LEVELS.size()
	else:
		level = clampi(level + 1, 0, CAMPAIGN_LEVELS.size() - 1)
	_start_level()

# С какого уровня начинается забег. Эпизод ставит сюда свой номер, бесконечный
# начинает с первого. Планка сложности берётся у уровня: эпизод 3, начатый с
# фазы 0, был бы легче эпизода 1, хотя стоит в конце кампании.
func set_start_level(idx: int) -> void:
	level         = clampi(idx, 0, CAMPAIGN_LEVELS.size() - 1)
	_phase        = int(CAMPAIGN_LEVELS[level]["phase"])
	_phase_floor  = _phase
	# Период до первой буквы — тоже у уровня. Значение по умолчанию — период
	# ПЕРВОГО, и без этой строки третий эпизод начинал бы слово в своём темпе
	# только со второй буквы.
	_letter_idx   = 0
	_letter_timer = _letter_period()

# Общая часть старта уровня: слово с начала, фаза со своей планки, поток
# разморожен. Скорость предметов НЕ сбрасывается — она растёт по общему времени
# забега, и обнулять её на каждом уровне значило бы каждый раз начинать сначала.
func _start_level() -> void:
	_letter_idx    = 0
	_letter_active = false
	_letter_timer  = _letter_period()
	# Планка уровня, но НЕ НИЖЕ уже достигнутой: на втором круге бесконечного
	# первый уровень не имеет права стать снова лёгким.
	_phase         = maxi(int(CAMPAIGN_LEVELS[level]["phase"]), _phase_floor)
	_phase_floor   = _phase
	_phase_elapsed = 0.0
	_frozen        = false
	_pattern_running = false
	_spawn_timer   = 1.2
	_reset_spans()
	clear_items()
	set_process(true)
	phase_entered.emit(_phase)

# Забыть резервы, до которых предмету уже не догнать.
func _prune_spans(speed: float) -> void:
	if speed <= 0.0:
		return
	# Тот же запас, что и в проверке конфликта, иначе резерв успевал бы истечь
	# на волосок раньше, чем перестаёт мешать.
	var reach := ItemSizing.radius_for(ItemSizing.MULT_MAX) * 2.0 * SPAN_PAD
	var keep : Array = []
	for e in _spans:
		if speed * (_elapsed - float(e["t"])) < reach:
			keep.append(e)
	_spans = keep

func _register_span(y: float, r: float) -> void:
	_spans.append({"y": y, "r": r, "t": _elapsed})

func _span_conflict(y: float, r: float, speed: float) -> bool:
	for e in _spans:
		var reach : float = (r + float(e["r"])) * SPAN_PAD
		if absf(y - float(e["y"])) < reach and speed * (_elapsed - float(e["t"])) < reach:
			return true
	return false

# Самый крупный размер из допустимых: не вылезает за экран и ни с чем не
# пересекается. Всегда возвращает минимум ×1 — базовый размер паттернами уже
# заложен и конфликтовать не может.
func _fit_size_mult(y: float, speed: float, want: float) -> float:
	var vp_h := get_viewport_rect().size.y
	var m    := want
	while m > 1.0:
		var r := ItemSizing.radius_for(m)
		if y - r >= 4.0 and y + r <= vp_h - 4.0 and not _span_conflict(y, r, speed):
			return m
		m -= 0.15
	return 1.0

# Выдать ударяющему предмету случайный размер и занять под него место.
# solo=true — предмет прилетел один (случайный поток / бонус), ему можно до ×3.
func _size_hazard(node: Node2D, y: float, speed: float, solo: bool) -> void:
	_prune_spans(speed)
	var want : float = ItemSizing.roll_hazard_mult() if solo else randf_range(1.0, PATTERN_MULT_MAX)
	var m    : float = _fit_size_mult(y, speed, want)
	ItemSizing.apply_node_scale(node, m)
	var r := ItemSizing.radius_for(m)
	_register_span(y, r)
	# Гигант забирает себе целую полосу — держим следующую единицу спавна, пока
	# он не уедет на свой диаметр, иначе она въедет ему в бок.
	if m > PATTERN_MULT_MAX and speed > 0.0:
		_big_clear_t = maxf(_big_clear_t, _elapsed + (2.0 * r) / speed)

# Ресурсы и прочие предметы место не занимают собой, но ЗАНИМАЮТ его для
# крупных: иначе следующий гигант вырастет прямо поверх пиццы.
func _mark_base_span(y: float) -> void:
	_register_span(y, ItemSizing.BASE_R)

# Дождаться, пока уедет крупный предмет (см. _size_hazard).
func _await_big_clear() -> void:
	if _big_clear_t <= _elapsed:
		return
	var wait := _big_clear_t - _elapsed
	_big_clear_t = -1.0
	await get_tree().create_timer(wait).timeout

# ── Песочные часы: замедление мира ───────────────────────────────────────────
# Замедляем не время движка, а сам мир: скорость всех живых предметов и
# прокрутку фона. Управление головой не трогаем — в этом весь смысл эффекта,
# игрок получает передышку, а не общий тормоз.
#
# Живым предметам скорость домножаем разово: они уже расставлены по расстоянию,
# и одинаковый множитель для всех сохраняет интервалы между ними в точности.
#
# А вот НОВЫЕ предметы на время эффекта не спавним вовсе, и это не лень. Паттерн
# захватывает `speed` один раз в начале и от него же считает паузы между
# колонками (_col_gap = COL_SPACING / speed). Замедли предметы посреди паттерна —
# и его оставшиеся колонки продолжат вылетать с прежним темпом, но ехать будут
# медленнее: расстояние между ними схлопнется с 85 px до 38, то есть предметы
# налезут друг на друга. Пауза потока убирает проблему целиком и заодно делает
# эффект честной «передышкой»: поле медленно доезжает и пустеет.
const SLOW_MO_FACTOR   : float = 0.45
const SLOW_MO_DURATION : float = 5.0

var world_speed_mult : float = 1.0
var _slow_mo_token   : int   = 0

func apply_slow_mo(factor: float = SLOW_MO_FACTOR, duration: float = SLOW_MO_DURATION) -> void:
	_slow_mo_token += 1
	var tok := _slow_mo_token
	# Если поток уже стоит — значит идёт мини-игра или босс, и пауза/возобновление
	# принадлежат им. Тогда только замедляем то, что уже летит.
	var owns_pause := not _frozen
	if is_equal_approx(world_speed_mult, 1.0):
		_scale_live_speeds(factor)
	world_speed_mult = factor
	_set_background_mult(factor)
	if owns_pause:
		pause_for_event()

	await get_tree().create_timer(duration).timeout

	# Пока часы висели, мог прилететь второй экземпляр — тогда выход из режима
	# принадлежит ему, а не нам.
	if not is_instance_valid(self) or tok != _slow_mo_token:
		return
	_scale_live_speeds(1.0 / factor)
	world_speed_mult = 1.0
	_set_background_mult(1.0)
	if owns_pause:
		resume_after_event()

func _scale_live_speeds(k: float) -> void:
	for child in get_children():
		if child.get("speed") != null:
			child.speed = float(child.speed) * k

func _set_background_mult(k: float) -> void:
	var bg := get_parent().get_node_or_null("Background")
	if bg and bg.get("speed_mult") != null:
		bg.speed_mult = k

func _lane_centers() -> Array:
	var h      := get_viewport_rect().size.y
	var result : Array = []
	for i in LANE_COUNT:
		result.append(h / LANE_COUNT * (i + 0.5))
	return result

# ── Campaign pattern runner ───────────────────────────────────────────────────

func _campaign_pick_pat_tier() -> int:
	var weights : Array = CAMPAIGN_PAT_WEIGHTS[mini(_phase, 4)]
	var total : int = 0
	for w in weights: total += w
	var r := randi() % total
	var acc : int = 0
	for i in weights.size():
		acc += weights[i]
		if r < acc: return i
	return weights.size() - 1

# Episode-1 director: one "unit" per call (driven by _process). Either a short
# RANDOM burst or a scripted SET-PIECE, chosen by the per-phase cadence.
func _run_campaign_pattern() -> void:
	var cfg    = CAMPAIGN_PHASES[_phase]
	var speed := _campaign_item_speed()   # непрерывный разгон предметов по времени
	var lanes := _lane_centers()
	var vp_w  := get_viewport_rect().size.x

	await _await_big_clear()

	if cfg["no_pizza"]:
		await _campaign_pre_boss_pattern(speed, lanes, vp_w)
		_pattern_running = false
		return

	if _campaign_intro_left > 0:
		# Onboarding: first few units are a gentle centred resource line.
		_campaign_intro_left -= 1
		await _t1_center_line(speed, lanes, vp_w)
		_last_sp_at = _elapsed
	else:
		var dc : Dictionary = CAMPAIGN_DIRECTOR[mini(_phase, CAMPAIGN_DIRECTOR.size() - 1)]
		if _elapsed - _last_sp_at >= float(dc["cad"]):
			# SET-PIECE window.
			var sp := _pick_set_piece(dc["sp"])
			await _run_set_piece(sp, speed, lanes, vp_w)
			_last_sp_at = _elapsed
			# Breather (resource river) after a lethal set-piece.
			if not _frozen and sp in LETHAL_SET_PIECES:
				await _breather(speed, lanes, vp_w)
		else:
			# RANDOM window.
			await _random_burst(dc, speed, lanes, vp_w)

	if _frozen:
		_pattern_running = false
		return
	# Зазор на СТЫКЕ единиц = один шаг колонки, чтобы предметы соседних юнитов не
	# налезали друг на друга (та же дистанция, что и внутри линии).
	await get_tree().create_timer(_col_gap(speed)).timeout
	_pattern_running = false

# ── Director: random baseline stream ──────────────────────────────────────────

func _random_burst(dc: Dictionary, speed: float, lanes: Array, vp_w: float) -> void:
	var interval := float(dc["int"])
	var count := randi_range(3, 5)
	for i in count:
		if _frozen: return
		# Перед КАЖДЫМ предметом, а не только перед серией: гигант рождается
		# именно здесь, и следующий предмет серии — первый, кто может въехать
		# ему в бок.
		await _await_big_clear()
		if _frozen: return
		_spawn_random_item(dc, speed, lanes, vp_w)
		if i < count - 1:
			await get_tree().create_timer(interval).timeout

# One weighted-random item. Lethal telegraph threats (glove/molotov/bomb) never
# come from the random stream — only from readable set-pieces.
#
# Одиночные предметы (solo=true) — единственное место, где ударяющему предмету
# разрешён размер до ×3: вокруг него гарантированно пусто, и спавнер придержит
# следующую единицу, пока гигант не уедет.
func _spawn_random_item(dc: Dictionary, speed: float, lanes: Array, vp_w: float) -> void:
	var y : float = lanes[randi() % LANE_COUNT] + _t1_osc_y()

	# РОЗЫГРЫШ РЕСУРСА. Пицца берёт почти три четверти — она главный ресурс и
	# главная еда: жир, а с ним и запас жизней, набирается только ей. Доллар
	# вчетверо реже: он платит за скины, а не за выживание, и валится он реже
	# намеренно — иначе кошелёк наполняется быстрее, чем игрок успевает
	# захотеть покупку.
	#
	# БОНУСЫ РЕДКИ. Все девять вместе — десятая часть ресурсных спавнов, а мешок
	# с деньгами внутри неё ещё и один из самых редких: мешок — это событие
	# («восемь долларов сразу, лети за ними»), а событие, случающееся каждые
	# двадцать секунд, перестаёт быть событием.
	if randf() < float(dc["res"]):
		var r := randf()
		if   r < 0.740: _spawn_item(y, vp_w, PIZZA_TEX, 0.09, speed, 0, true, true, true)
		elif r < 0.900: _spawn_dollar(y, vp_w, speed)
		elif r < 0.920: _inst_lane(MAGNET_SCENE, speed, vp_w, lanes)        # магнит
		elif r < 0.935: _inst_lane(MONEY_BAG_SCENE, speed, vp_w, lanes)     # мешок (редкий)
		elif r < 0.950: _spawn_effect_item("cola", y, vp_w, speed)          # банка колы (ускорение)
		elif r < 0.964: _spawn_effect_item("magic_hat", y, vp_w, speed)     # шляпа мага (иммун к замедлению)
		elif r < 0.978: _spawn_effect_item("casey_mask", y, vp_w, speed)    # маска Кейси (иммун к урону)
		elif r < 0.988: _spawn_effect_item("hourglass", y, vp_w, speed)     # песочные часы (замедление мира)
		elif r < 0.996: _spawn_scripted(MAGIC_BOX_SCRIPT, y, vp_w, speed)   # мэджик бокс
		else:           _spawn_effect_item("casino_chip", y, vp_w, speed)   # жетон автомата (редкий)
	else:
		_spawn_level_hazard(_pick_level_hazard(), y, vp_w, speed)

# ── Угрозы ПО УРОВНЯМ ────────────────────────────────────────────────────────
# У КАЖДОГО УРОВНЯ СВОЙ НАБОР — и это не украшение, а то, из чего локация
# состоит. Канализация — это банан под ногами, бочки и бомжи; река — штурвал,
# бутылка и костёр на берегу; задворки — пляжный хлам; дорога в клубе — двор с
# машинами и колёсами; перед клубом — копы, наручники и зазывалы.
#
# Раньше был общий список `HAZ_BASE`, который добавлялся ко всем уровням разом:
# камень, змея, собака, вор, компас, туз, ниндзя, чек и семь «сюжетных» угроз
# летели ВЕЗДЕ. От этого все уровни ощущались одним и тем же уровнем с
# разной картинкой на заднике.
#
# Теперь везде летит только ОДНО — боксёрская перчатка: это не предмет места, а
# ритм-событие, и на всех уровнях оно читается одинаково.
#
# Ресурсы и бонусы (пицца, доллар, мешок, магнит, маска, шляпа, мэджик бокс,
# кола, часы, магнитофон) идут отдельным розыгрышем и тоже есть везде — см.
# `_spawn_random_item`.
#
# См. /Концепция/Уровни/Раскладка по уровням.md
const HAZ_ALWAYS : Dictionary = {
	"glove": 6,
}

# Ниндзя приходит в поток ТОЛЬКО СО ВТОРОГО уровня — после того, как игрок
# встретил его боссом в конце первого. Предмет, объясняющий сам себя боем с
# боссом, до этого боя ничего не объясняет: игрок видит непонятную фигуру,
# которая почему-то останавливается посреди экрана.
const HAZ_LEVEL : Array = [
	# 1. КАНАЛИЗАЦИЯ — бочки, камни, бомжи, конусы, банан, дорожный знак.
	# Кобра и яд — своя фауна канализации, отсюда они и не уходят.
	{ "banana": 26, "trash": 16, "stone": 14, "homeless": 16, "cone": 12,
	  "roadsign": 10, "snake": 12, "poison": 6 },
	# 2. УЛИЦА — река и пляж на одном пути: штурвал, бутылка с письмом, птица,
	# зонт, костёр, шезлонг, компас, пиво, шаман. Конус и камень держат связь с
	# первым уровнем: набор обязан меняться, а не подменяться целиком.
	{ "helm": 12, "bottle": 12, "bird": 12, "umbrella": 14, "campfire": 10,
	  "lounger": 10, "compass": 8, "beer": 12, "stone": 10, "banana": 12,
	  "cone": 8, "shaman": 6, "ninja": 6 },
	# 3. ДОРОГА В КЛУБ — двор и парковка: машина копов, колесо, молотов, собака,
	# бочка, бандит, бомж, сейф; клубное — конус, полицейский, наручники,
	# девочка-зазывала, коктейль, чёрный туз и чек лузера.
	{ "police_car": 10, "tire": 12, "molotov": 10, "dog": 12, "trash": 10,
	  "thief": 10, "homeless": 10, "safe": 6, "cone": 10, "cop": 10,
	  "handcuffs": 8, "girl": 10, "cocktail": 6, "black_ace": 4,
	  "loser_ticket": 3, "ninja": 6 },
]

func _pick_level_hazard() -> String:
	var pool : Dictionary = HAZ_ALWAYS.duplicate()
	var lvl : Dictionary = HAZ_LEVEL[clampi(level, 0, HAZ_LEVEL.size() - 1)] \
		if campaign_mode else HAZ_LEVEL[HAZ_LEVEL.size() - 1]
	for k in lvl:
		pool[k] = int(pool.get(k, 0)) + int(lvl[k])
	var total : int = 0
	for k in pool:
		total += int(pool[k])
	var roll : int = randi() % maxi(1, total)
	for k in pool:
		roll -= int(pool[k])
		if roll < 0:
			return String(k)
	return "stone"

func _spawn_level_hazard(kind: String, y: float, vp_w: float, speed: float) -> void:
	match kind:
		"banana":       _spawn_slowing(y, vp_w, speed, true)
		"trash":        _spawn_t1_negative(y, vp_w, speed, true)
		"stone":        _spawn_item(y, vp_w, STONE_TEX, 0.16, speed, 1, false, false, false, "stone", true)
		"snake":        _spawn_snake(y, vp_w, speed, true)
		"homeless":     _spawn_homeless(y, vp_w, speed, true)
		"dog":          _spawn_dog(y, vp_w, speed, true)
		"thief":        _spawn_scripted(THIEF_SCRIPT, y, vp_w, speed)
		"roadsign":     _spawn_scripted(ROADSIGN_BUM_SCRIPT, y, vp_w, speed)
		"compass":      _spawn_scripted(COMPASS_SCRIPT, y, vp_w, speed)
		"black_ace":    _spawn_effect_item("black_ace", y, vp_w, speed)
		"ninja":        _spawn_ninja(y, vp_w, speed)
		"loser_ticket": _spawn_effect_item("loser_ticket", y, vp_w, speed)
		"beer":         _spawn_slowing(y, vp_w, speed)
		"handcuffs":    _spawn_effect_item("handcuffs", y, vp_w, speed)
		"cone":         _spawn_cone(vp_w, speed)
		"glove":        _spawn_glove(y, vp_w)
		"police_car":   _spawn_police_car(y, vp_w, speed)
		"safe":         _spawn_safe(y, vp_w, speed)
		"girl":         _spawn_girl(y, vp_w, speed)
		"molotov":      _spawn_molotov_single(y, vp_w, speed)
		# Всё остальное — предметы `hazard_item.gd`: они названы в раскладке
		# ПОИМЁННО (штурвал, зонт, костёр, шезлонг, колесо, коп, сейф…), и имя
		# обязано дойти до спавна. Раньше здесь стоял слепой `_pick_hazard()`:
		# раскладка просила зонт, а прилетал случайный из семи — и уровни снова
		# становились одинаковыми, только теперь незаметно.
		_:
			if HAZARD_ITEM_SCRIPT.KINDS.has(kind):
				_spawn_hazard(kind, y, vp_w, speed)
			else:
				_spawn_hazard(_pick_hazard(), y, vp_w, speed)

# Сейф — не рядовая угроза, а СДЕЛКА: бьёт на 2 и тем же ударом вскрывается,
# высыпая доллары (см. safe.gd). Своим скриптом, а не строкой в hazard_item:
# у него своя хореография — перелёт на голову, раскрытие, россыпь и падение.
const SAFE_SCRIPT := preload("res://scripts/safe.gd")

func _spawn_safe(y: float, vp_w: float, speed: float) -> void:
	var node := Area2D.new()
	node.set_script(SAFE_SCRIPT)
	node.set("speed", speed)
	node.position = Vector2(vp_w + 90.0, y)
	_mark_base_span(y)
	add_child(node)

# Полицейская машина — не предмет, а СОБЫТИЕ: идёт по двум линиям, быстрее
# потока, пашет всё на своём пути и разбивается у игрока, вываливая двух копов.
# Вся хореография — в `police_car.gd`; здесь только выбор пары линий.
#
# Раньше она была рядовой картинкой в потоке и вела себя как камень, только
# длиннее. Аргумент «по длине читается, что облететь можно только сверху или
# снизу» на деле описывал шезлонг, а не машину.
const POLICE_CAR_SCRIPT := preload("res://scripts/police_car.gd")

func _spawn_police_car(_y: float, vp_w: float, speed: float) -> void:
	# Линию выбираем не по переданному y, а сами: занимает она ПАРУ, и верхняя
	# из пары не может быть последней.
	var lane : int = randi() % (LANE_COUNT - 1)
	var lanes := _lane_centers()
	var car := Area2D.new()
	car.set_script(POLICE_CAR_SCRIPT)
	car.set("speed", speed)
	car.set("lane", lane)
	car.set("lanes_total", LANE_COUNT)
	car.position = Vector2(vp_w + 260.0,
		(float(lanes[lane]) + float(lanes[lane + 1])) * 0.5)
	add_child(car)

# Тяжёлые и «сюжетные» угрозы приходят не раньше указанной фазы: сейф с копом
# на первой минуте задавили бы новичка, а шаман с реверсом управления читается
# только тогда, когда игрок уже уверенно ведёт голову.
const HAZARD_FROM_PHASE : Dictionary = {
	"cocktail": 0, "poison": 1, "bird": 1, "helm": 2, "safe": 2, "cop": 3, "shaman": 3,
}

func _pick_hazard() -> String:
	var pool : Array = []
	for k in HAZARD_FROM_PHASE:
		if _phase >= int(HAZARD_FROM_PHASE[k]):
			pool.append(k)
	if pool.is_empty():
		return "cocktail"
	return pool[randi() % pool.size()]

func _spawn_hazard(kind: String, y: float, vp_w: float, speed: float) -> void:
	# Сейф — свой скрипт, и попасть сюда он может из общего пула угроз
	# (`_pick_hazard`), а не только из раскладки уровня. Развилка здесь одна на
	# все входы: иначе в игре завёлся бы второй, «тихий» сейф без выплаты.
	if kind == "safe":
		_spawn_safe(y, vp_w, speed)
		return
	var node := Area2D.new()
	node.set_script(HAZARD_ITEM_SCRIPT)
	node.set("kind", kind)
	node.set("speed", speed)
	node.position = Vector2(vp_w + 90.0, y)
	_mark_base_span(y)
	add_child(node)

# Ниндзя трёх видов (см. ninja_item.gd). Чёрный чаще остальных: он самый
# читаемый, по нему игрок и учится, что такое ниндзя. Красный и жёлтый — это уже
# вариации на знакомом, и вываливать их наравне значило бы учить трём вещам
# сразу.
const NINJA_KINDS : Array = ["shuriken", "shuriken", "predator", "smoke"]

func _spawn_ninja(y: float, vp_w: float, speed: float) -> void:
	var node := Area2D.new()
	node.set_script(NINJA_SCRIPT)
	node.set("speed", speed)
	# kind ставится ДО add_child: _ready() читает его, чтобы покрасить спрайт и
	# записаться в свою группу.
	node.set("kind", NINJA_KINDS[randi() % NINJA_KINDS.size()])
	node.position = Vector2(vp_w + 80.0, y)
	_mark_base_span(y)
	add_child(node)

# Предмет-эффект: скрипт один, вид задаётся полем `kind` (см. effect_item.gd).
func _spawn_effect_item(kind: String, y: float, vp_w: float, speed: float) -> void:
	var node := Area2D.new()
	node.set_script(EFFECT_ITEM_SCRIPT)
	node.set("kind", kind)
	node.set("speed", speed)
	node.position = Vector2(vp_w + 80.0, y)
	_mark_base_span(y)
	add_child(node)

func _spawn_homeless(y: float, vp_w: float, speed: float, solo: bool = false) -> void:
	var hm := HOMELESS_SCENE.instantiate()
	if hm.get("speed") != null:
		hm.speed = speed
	hm.position = Vector2(vp_w + 80.0, y)
	_size_hazard(hm, y, speed, solo)
	add_child(hm)

# Dev: заспавнить вора вручную (кнопка в HUD).
func dev_send_thief() -> void:
	var vp_w  := get_viewport_rect().size.x
	var lanes := _lane_centers()
	var speed : float = _campaign_item_speed() if campaign_mode else 250.0
	_spawn_scripted(THIEF_SCRIPT, lanes[randi() % LANE_COUNT], vp_w, speed)

# Дев-вызов волны бомжей и бомжа с бочкой. Оба — сет-писы, и «просто заспавнить
# предмет» их не воспроизводит: у волны есть смена щели между тучами, у бочки —
# три зависимых такта. Поэтому дёргаем ровно те же функции, что и забег.
func dev_send_bum_crowd() -> void:
	var vp_w  := get_viewport_rect().size.x
	var lanes := _lane_centers()
	var speed : float = _campaign_item_speed() if campaign_mode else 250.0
	_setpiece_bum_crowd(speed, lanes, vp_w)

func dev_send_bum_barrel() -> void:
	var vp_w  := get_viewport_rect().size.x
	var lanes := _lane_centers()
	var speed : float = _campaign_item_speed() if campaign_mode else 250.0
	_setpiece_bum_barrel(speed, lanes, vp_w)

# Спавн любого из новых script-only предметов (компас/вор/бомж-со-знаком).
func _spawn_scripted(script: Script, y: float, vp_w: float, speed: float) -> void:
	var node := Area2D.new()
	node.set_script(script)
	if node.get("speed") != null:
		node.speed = speed
	node.position = Vector2(vp_w + 80.0, y)
	_mark_base_span(y)
	add_child(node)

# Конус — высокий (3 лейна), ставим по центру, блокирует средние ряды.
# ── Девочка-зазывала ─────────────────────────────────────────────────────────
# Приходит из свиты [[хозяина клуба]] и работает ровно так же: НЕ БЬЁТ, а
# ЗАМЕДЛЯЕТ. Это и делает её уместной на дороге в клуб — угроза без урона,
# которая портит не жизнь, а линию: влип в девочку — не успел уйти от того, что
# летит следом.
#
# Узел тот же, что у босса (`club_boss_minion.gd`), с теми же метаданными
# замедления: заводить второй «почти такой же» вид значило бы получить две
# девочки с разным поведением.
const GIRL_SCRIPT := preload("res://scripts/club_boss_minion.gd")
const GIRL_TEX : Array = [
	preload("res://assets/bosses/club_boss/girl1.png"),
	preload("res://assets/bosses/club_boss/girl2.png"),
]
const GIRL_SFX     := preload("res://assets/audio/club_boss/kiss.mp3")
const GIRL_PX      : float = 96.0
const GIRL_SLOW_T  : float = 1.6

func _spawn_girl(y: float, vp_w: float, speed: float) -> void:
	var g := Area2D.new()
	g.set_script(GIRL_SCRIPT)
	# init ДО add_child: узел читает текстуру и размер в своём _ready.
	g.call("init", GIRL_TEX[randi() % GIRL_TEX.size()], GIRL_PX, Vector2.LEFT, speed)
	g.set("slows", true)
	g.set("slow_duration", GIRL_SLOW_T)
	g.set("slow_sound", GIRL_SFX)
	g.set("damage", 0)
	g.position = Vector2(vp_w + 90.0, y)
	add_child(g)

# Одиночный молотов — тот же снаряд, что и в волне, но без хвостовой паузы:
# в потоке уровня он один из многих, а не сет-пис.
func _spawn_molotov_single(y: float, vp_w: float, speed: float) -> void:
	var m := MOLOTOV_SCENE.instantiate()
	m.speed      = speed
	m.fire_count = 4
	m.position   = Vector2(vp_w + 80.0, y)
	add_child(m)

func _spawn_cone(vp_w: float, speed: float) -> void:
	var node := Area2D.new()
	node.set_script(CONE_SCRIPT)
	node.set("speed", speed)
	node.position = Vector2(vp_w + 130.0, get_viewport_rect().size.y * 0.5)
	add_child(node)

# Short resource river — the mandatory "breather" after a lethal set-piece.
func _breather(speed: float, lanes: Array, vp_w: float) -> void:
	var gap := _col_gap(speed) * 1.05
	for i in 5:
		if _frozen: return
		_spawn_item(lanes[2] + _t1_osc_y(), vp_w, PIZZA_TEX, 0.09, speed, 0, true, true, true)
		if i < 4:
			await get_tree().create_timer(gap).timeout
	if _frozen: return
	await get_tree().create_timer(0.35).timeout

# ── Director: scripted set-pieces (reuse the tier pattern fns) ─────────────────

# Сет-писы, ВРЕМЕННО убранные из забега. Держатся отдельным списком, а не
# вычёркиванием из CAMPAIGN_DIRECTOR: таблица — это запись замысла, и стереть из
# неё вид значит потерять, в каких фазах он стоял. Код вида остаётся живым и
# вызывается тестами и дев-кнопкой напрямую.
#
# Сейчас список пуст: бомжа с бочкой убирали, пока хореография не читалась, и
# вернули, когда она пришла раскадровкой (см. scripts/bum_barrel.gd).
const SP_DISABLED : Array = []

func _pick_set_piece(pool: Array) -> String:
	if pool.is_empty():
		return "sandwich"
	var choices := pool.duplicate()
	for off in SP_DISABLED:
		choices.erase(off)
	if choices.is_empty():
		return "sandwich"
	if choices.size() > 1 and _last_sp_id in choices:
		choices.erase(_last_sp_id)   # no immediate repeats
	var pick : String = choices[randi() % choices.size()]
	_last_sp_id = pick
	return pick

func _run_set_piece(id: String, speed: float, lanes: Array, vp_w: float) -> void:
	match id:
		"sandwich":       await _t1_two_sandwiches(speed, lanes, vp_w, randf() < 0.5)
		"zigzag":         await _t2_zigzag_wide(speed, lanes, vp_w)
		"barrel_cascade": await _t1_cascade(speed, lanes, vp_w, randf() < 0.5)
		"snake_columns":  await _t2_gate_attack(speed, lanes, vp_w, randi_range(3, 6))
		"bum_wall":       await _setpiece_bum_wall(speed, lanes, vp_w)
		"bum_crowd":      await _setpiece_bum_crowd(speed, lanes, vp_w)
		"cone":           await _setpiece_cone(speed, lanes, vp_w)
		"bum_barrel":     await _setpiece_bum_barrel(speed, lanes, vp_w)
		"stone_chess":    await _t3_checkerboard(speed, lanes, vp_w)
		"diagonal":       await _t3_diagonal(speed, lanes, vp_w)
		"glove_wave":     await _wave_glove_sweep(speed, lanes, vp_w)
		"molotov_wave":   await _pat_t5(speed, lanes, vp_w)
		_:                await _t1_center_line(speed, lanes, vp_w)

# Толпа бомжей — тучи бомжей БЫСТРО пролетают большими кучами, оставляя ровно
# 2 СОСЕДНИХ свободных лейна; каждая следующая туча сдвигает щель НА ОДИН лейн.
# Доступно уже после 1-й минуты (фаза 1+).
#
# Волна была почти непроходимой. Складывались три вещи: скорость ×1.5, короткая
# пауза между тучами и щель, прыгавшая куда угодно — с крайней пары на
# противоположную. Игрок должен был пересечь три лейна быстрее, чем долетала
# следующая туча. Разрежено всё три: скорость, пауза и величина прыжка щели.
const BUM_CROWD_SPEED : float = 1.30   # было 1.50
const BUM_CROWD_GAP   : float = 3.20   # было 2.40
func _setpiece_bum_crowd(speed: float, lanes: Array, vp_w: float) -> void:
	var fast := speed * BUM_CROWD_SPEED
	var waves := randi_range(3, 4)
	var free_start := randi() % (LANE_COUNT - 1)   # свободны лейны free_start и free_start+1
	var gap := _col_gap(fast) * BUM_CROWD_GAP
	for w in waves:
		if _frozen: return
		for lane in LANE_COUNT:
			if lane != free_start and lane != free_start + 1:
				_spawn_homeless_clump(lanes[lane], vp_w, fast)
		if w < waves - 1:
			await get_tree().create_timer(gap).timeout
			# Просвет ПЕРЕЕЗЖАЕТ НА СОСЕДНИЙ, а не куда угодно. Раньше пара
			# свободных лейнов могла прыгнуть с (0,1) на (3,4) — через три лейна
			# на полуторной скорости, то есть волна требовала перелёта, который
			# физически не успеваешь. Теперь щель уходит максимум на один лейн:
			# двигаться надо всегда, но дорога есть всегда.
			var step : int = 1 if randf() < 0.5 else -1
			var nxt : int = free_start + step
			if nxt < 0 or nxt > LANE_COUNT - 2:
				nxt = free_start - step
			free_start = clampi(nxt, 0, LANE_COUNT - 2)

# Бомж с бочкой: приезжает, ставит бочку, бочка открывается и стреляет собакой
# по линии Нормальдо. Отличается от остальных сет-писов тем, что угроза
# ПОЯВЛЯЕТСЯ НЕ СРАЗУ: сначала читается подготовка, и только потом летит собака.
# См. scripts/bum_barrel.gd
func _setpiece_bum_barrel(speed: float, lanes: Array, vp_w: float) -> void:
	var lane : int = randi() % LANE_COUNT
	_mark_base_span(lanes[lane])
	var node := Node2D.new()
	# Скрипт и setup — ДО add_child: _ready() читает lane_y и speed, а поставь
	# скрипт после добавления, и порядок вызовов держится на честном слове.
	node.set_script(BUM_BARREL_SCRIPT)
	node.call("setup", get_parent().get_node_or_null("Normaldo"), lanes[lane], speed)
	add_child(node)
	# Пока идёт хореография, поток не наваливается сверху: угроза тут одна и
	# читаемая, и заваливать её обычными предметами значит спрятать. Такт стал
	# длиннее с тех пор, как бомж сначала ВЛЕТАЕТ как обычный предмет и лишь
	# потом отыгрывает атаку: до собаки теперь около 2.2 секунды.
	await get_tree().create_timer(2.8).timeout

# Конус-сет-пис: центральный конус (3 ряда) + сверху/снизу немного ресурсов,
# чтобы соблазнить пройти сбоку либо сбить конус тапами.
func _setpiece_cone(speed: float, lanes: Array, vp_w: float) -> void:
	_spawn_cone(vp_w, speed)
	var gap := _col_gap(speed) * 1.2
	for i in 3:
		if _frozen: return
		_spawn_item(lanes[0], vp_w, PIZZA_TEX, 0.09, speed, 0, true, true, true)
		_spawn_item(lanes[4], vp_w, PIZZA_TEX, 0.09, speed, 0, true, true, true)
		if i < 2:
			await get_tree().create_timer(gap).timeout

# Одна "куча" — 2-3 бомжа плотным горизонтальным кластером в одном лейне.
func _spawn_homeless_clump(y: float, vp_w: float, speed: float) -> void:
	var n := randi_range(2, 3)
	# Куче размер НЕ рандомим: бомжи в ней стоят плотно (шаг 36 px), это её
	# смысл, и любое увеличение развалило бы кластер. Но место она занимает —
	# иначе следующим спавном поверх кучи мог бы родиться гигант.
	_mark_base_span(y)
	for i in n:
		var hm := HOMELESS_SCENE.instantiate()
		if hm.get("speed") != null:
			hm.speed = speed
		hm.position = Vector2(vp_w + 80.0 + float(i) * 36.0, y + randf_range(-14.0, 14.0))
		add_child(hm)

# Столбы бомжей — стена бомжей с бегущим свободным лейном + приз-пицца.
func _setpiece_bum_wall(speed: float, lanes: Array, vp_w: float) -> void:
	var gap  := _col_gap(speed) * 2.0
	var free := randi() % LANE_COUNT
	var reps := randi_range(3, 4)
	for rep in reps:
		if _frozen: return
		for i in LANE_COUNT:
			if i != free:
				_spawn_homeless(lanes[i], vp_w, speed)
		if rep < reps - 1:
			await get_tree().create_timer(gap).timeout
			var dir := 1 if randf() < 0.5 else -1
			if free + dir < 0 or free + dir >= LANE_COUNT:
				dir = -dir
			free += dir
	if _frozen: return
	await get_tree().create_timer(gap * 1.5).timeout
	_spawn_item(lanes[free], vp_w, PIZZA_TEX, 0.09, speed, 0, true, true, true)

# Pre-boss molotov cadence: one molotov drops every 4 s, constrained to the
# right half of the screen.
const PRE_BOSS_MOLOTOV_INTERVAL    : float = 4.0
const PRE_BOSS_MOLOTOV_X_MIN_RATIO : float = 0.5

# Last pre-boss attack we ran (0 = glove sweep, 1 = single molotov). Used to
# enforce strict alternation so a single molotov is always followed by a
# glove sweep, and vice-versa.
var _pre_boss_last_type : int = -1

func _campaign_pre_boss_pattern(speed: float, lanes: Array, vp_w: float) -> void:
	if _frozen: return
	var picked : int = 1 if _pre_boss_last_type == 0 else 0
	_pre_boss_last_type = picked

	match picked:
		0:
			await _wave_glove_sweep(speed, lanes, vp_w)
			await get_tree().create_timer(POST_PAT_GAPS[4] + 0.6).timeout
		1:
			await _wave_molotov_right(speed, lanes, vp_w)

# ── Single-threat waves (shared) ─────────────────────────────────────────────
# Pre-boss style: one clear punch line at a time. Reused by both the campaign
# pre-boss alternation and the endless T4/T5 slots, replacing the old multi-
# column glove walls and molotov checkerboards.

func _wave_glove_sweep(speed: float, lanes: Array, vp_w: float) -> void:
	# 3 columns of gloves with a shifting safe lane. Column gap waits for the
	# previous wave to fully punch + an extra breather so each wall reads as a
	# distinct beat.
	var gap  := _glove_punch_delay(speed) + 0.7
	var safe := randi() % LANE_COUNT
	for col in 3:
		if _frozen: return
		for lane in LANE_COUNT:
			if lane != safe:
				_spawn_glove(lanes[lane], vp_w)
		safe = (safe + 2) % LANE_COUNT
		if col < 2:
			await get_tree().create_timer(gap).timeout

func _wave_molotov_right(speed: float, lanes: Array, vp_w: float) -> void:
	# One molotov in a random lane, target clamped to the right half. Trailing
	# 4 s wait gives the player room to clear the burning zone before the next
	# pattern arrives.
	var lane := randi() % LANE_COUNT
	var m       := MOLOTOV_SCENE.instantiate()
	m.speed              = speed
	m.fire_count         = 4 + (1 if _endless_mods.get("molotov_plus", false) else 0)
	m.target_x_min_ratio = PRE_BOSS_MOLOTOV_X_MIN_RATIO
	m.position           = Vector2(vp_w + 80.0, lanes[lane])
	add_child(m)
	await get_tree().create_timer(PRE_BOSS_MOLOTOV_INTERVAL).timeout

# ── Endless pattern runner ────────────────────────────────────────────────────

func _endless_pick_pat_tier() -> int:
	var weights : Array = ENDLESS_PHASES[_phase]["weights"]
	if _endless_mods.get("no_t1", false):
		weights = weights.duplicate()
		weights[0] = 0
	var total : int = 0
	for w in weights: total += w
	if total <= 0: return 3
	var r := randi() % total
	var acc : int = 0
	for i in weights.size():
		acc += weights[i]
		if r < acc: return i
	return 3

func _run_endless_pattern(allow_twin: bool = true) -> void:
	var cfg     = ENDLESS_PHASES[_phase]
	var speed  := (cfg["speed"] as float) * world_speed_mult
	var lanes  := _lane_centers()
	var vp_w   := get_viewport_rect().size.x
	var pt     := _endless_pick_pat_tier()
	await _await_big_clear()
	_pat_tier   = pt
	await _dispatch_pat(pt, speed, lanes, vp_w)
	if _frozen:
		_pattern_running = false
		return
	await get_tree().create_timer(0.2).timeout
	if not _frozen and randf() < BONUS_CHANCES[mini(pt, 4)]:
		_spawn_bonus_item(speed, vp_w, lanes)
	# Twin patterns: chain a second one immediately, no gap.
	if allow_twin and _endless_mods.get("twin_pat", false) and randf() < 0.35:
		await _run_endless_pattern(false)
		return
	var gap := POST_PAT_GAPS[mini(pt, 4)] as float
	if _endless_mods.get("short_gap", false):
		gap *= 0.7
	await get_tree().create_timer(gap).timeout
	_pattern_running = false

# ── Endless phase advancement ────────────────────────────────────────────────

func _advance_endless_phase() -> void:
	_phase         += 1
	_phase_elapsed  = 0.0
	if _phase >= ENDLESS_PHASES.size():
		_phase = ENDLESS_PHASES.size() - 1
	_endless_mods = (ENDLESS_PHASES[_phase]["mods"] as Dictionary).duplicate()
	phase_entered.emit(_phase)
	# Калм-волна на старте каждой Безумие-фазы (отдыхающая T1 без врагов).
	if _phase >= CALM_WAVE_PHASES_FROM:
		_run_calm_wave()
	else:
		_spawn_timer = 0.8

func _run_calm_wave() -> void:
	_frozen          = true
	_pattern_running = true
	var speed := ENDLESS_PHASES[_phase]["speed"] as float
	var vp_w  := get_viewport_rect().size.x
	var lanes := _lane_centers()
	var gap   := _col_gap(speed) * 1.1
	var lane_y : float = lanes[2]
	for i in CALM_WAVE_LINE_COUNT:
		_spawn_item(lane_y, vp_w, PIZZA_TEX, 0.09, speed, 0, true, true, true)
		if i < CALM_WAVE_LINE_COUNT - 1:
			await get_tree().create_timer(gap).timeout
	await get_tree().create_timer(CALM_WAVE_DURATION).timeout
	_frozen          = false
	_pattern_running = false
	_spawn_timer     = 0.4

# ── Pattern dispatch ──────────────────────────────────────────────────────────

func _dispatch_pat(pt: int, speed: float, lanes: Array, vp_w: float) -> void:
	match pt:
		0: await _pat_t1(speed, lanes, vp_w)
		1: await _pat_t2(speed, lanes, vp_w)
		2: await _pat_t3(speed, lanes, vp_w)
		3, 4: await _dispatch_t45(speed, lanes, vp_w)

func _dispatch_t45(speed: float, lanes: Array, vp_w: float) -> void:
	var idx := mini(_t45_batch_idx, T45_BATCH_SIZES.size() - 1)
	if _t45_batch_idx % 2 == 0:
		await _pat_t4(speed, lanes, vp_w)
	else:
		await _pat_t5(speed, lanes, vp_w)
	_t45_in_batch += 1
	if _t45_in_batch >= T45_BATCH_SIZES[idx]:
		_t45_in_batch  = 0
		_t45_batch_idx += 1
		if _t45_batch_idx >= T45_BATCH_SIZES.size():
			_t45_batch_idx = T45_BATCH_SIZES.size() - 2

func _col_gap(speed: float) -> float:
	return COL_SPACING / speed

# Seconds between spawning a boxing glove and the moment it starts punching.
# Used to time multi-wave glove patterns so the next wave arrives the
# instant the previous one fires — instead of stacking gloves on screen.
# Numbers mirror boxing_glove.gd: enter distance ≈ 118 px at `speed * 2.0`,
# followed by the phase-dependent charge duration.
func _glove_punch_delay(speed: float) -> float:
	return 118.0 / (speed * 2.0) + _glove_charge_duration_for_phase()

func _t1_osc_y() -> float:
	var t := _phase_elapsed if campaign_mode else _elapsed
	if t < 30.0:
		return 0.0
	return sin(t * 0.8) * 25.0

# ── T1: Resource lines ────────────────────────────────────────────────────────

func _pat_t1(speed: float, lanes: Array, vp_w: float) -> void:
	_t1_pattern_count += 1
	_t1_trash = _t1_pattern_count > 5 or _endless_mods.get("trash_only", false)
	match randi() % 6:
		0: await _t1_double_line(speed, lanes, vp_w)
		1: await _t1_center_line(speed, lanes, vp_w)
		2: await _t1_two_sandwiches(speed, lanes, vp_w, true)
		3: await _t1_two_sandwiches(speed, lanes, vp_w, false)
		4: await _t1_cascade(speed, lanes, vp_w, true)
		5: await _t1_cascade(speed, lanes, vp_w, false)

func _spawn_t1_negative(y: float, vp_w: float, speed: float, use_trash: bool = false) -> void:
	if use_trash:
		var tb := _spawn_item(y, vp_w, TRASH_TEX, 0.22, speed, 1, false, false, false)
		(tb.get_node("Sprite2D") as Sprite2D).rotation = PI / 2.0
	else:
		_spawn_slowing(y, vp_w, speed, true)

# Вар.1 — pizzas on edges (0,4), negative on 1,3, centre empty; boombox at end.
func _t1_double_line(speed: float, lanes: Array, vp_w: float) -> void:
	var gap := _col_gap(speed)
	for i in 5:
		if _frozen: return
		var oy := _t1_osc_y()
		_spawn_item(lanes[0] + oy, vp_w, PIZZA_TEX, 0.09, speed, 0, true, true, true)
		_spawn_t1_negative(lanes[1] + oy, vp_w, speed, _t1_trash)
		_spawn_t1_negative(lanes[3] + oy, vp_w, speed, _t1_trash)
		_spawn_item(lanes[4] + oy, vp_w, PIZZA_TEX, 0.09, speed, 0, true, true, true)
		if i < 4:
			await get_tree().create_timer(gap).timeout
	if _frozen: return
	await get_tree().create_timer(gap * 1.2).timeout
	var bl_y   = lanes[0 if randf() < 0.5 else 4] + _t1_osc_y()
	var bl     := BOOMBOX_SCENE.instantiate()
	if bl.get("speed") != null: bl.speed = speed
	bl.position = Vector2(vp_w + 80.0, bl_y)
	add_child(bl)

# Вар.2 — pizza on centre (2), negative on 1 and 3, outer lanes empty.
func _t1_center_line(speed: float, lanes: Array, vp_w: float) -> void:
	var gap := _col_gap(speed)
	for i in 5:
		if _frozen: return
		var oy := _t1_osc_y()
		_spawn_t1_negative(lanes[1] + oy, vp_w, speed, _t1_trash)
		_spawn_item(lanes[2] + oy, vp_w, PIZZA_TEX, 0.09, speed, 0, true, true, true)
		_spawn_t1_negative(lanes[3] + oy, vp_w, speed, _t1_trash)
		if i < 4:
			await get_tree().create_timer(gap).timeout

# Вар.3 (down=true) / Вар.4 (down=false) — two sandwiches in sequence.
# down=true:  sandwich 1 at lane 1, sandwich 2 at lane 3 (player moves down).
# down=false: sandwich 1 at lane 3, sandwich 2 at lane 1 (player moves up).
func _t1_two_sandwiches(speed: float, lanes: Array, vp_w: float, down: bool) -> void:
	var gap := _col_gap(speed)
	var top := 1 if down else 3
	var bot := 3 if down else 1
	for i in 5:
		if _frozen: return
		var oy := _t1_osc_y()
		_spawn_t1_negative(lanes[top - 1] + oy, vp_w, speed, _t1_trash)
		_spawn_item(lanes[top] + oy, vp_w, PIZZA_TEX, 0.09, speed, 0, true, true, true)
		_spawn_t1_negative(lanes[top + 1] + oy, vp_w, speed, _t1_trash)
		if i < 4:
			await get_tree().create_timer(gap).timeout
	if _frozen: return
	await get_tree().create_timer(gap * 1.2).timeout
	_spawn_item(lanes[2] + _t1_osc_y(), vp_w, PIZZA_TEX, 0.09, speed, 0, true, true, true)
	await get_tree().create_timer(gap * 1.3).timeout
	for i in 5:
		if _frozen: return
		var oy := _t1_osc_y()
		_spawn_t1_negative(lanes[bot - 1] + oy, vp_w, speed, _t1_trash)
		_spawn_item(lanes[bot] + oy, vp_w, PIZZA_TEX, 0.09, speed, 0, true, true, true)
		_spawn_t1_negative(lanes[bot + 1] + oy, vp_w, speed, _t1_trash)
		if i < 4:
			await get_tree().create_timer(gap).timeout

# Вар.5 (down=true) / Вар.6 (down=false) — three short sandwiches cascading.
# down=true:  pizza on lane 1 → 2 → 3.
# down=false: pizza on lane 3 → 2 → 1.
func _t1_cascade(speed: float, lanes: Array, vp_w: float, down: bool) -> void:
	var gap   := _col_gap(speed)
	var order := [1, 2, 3] if down else [3, 2, 1]
	for chunk_idx in order.size():
		var c = order[chunk_idx]
		for i in 4:
			if _frozen: return
			var oy := _t1_osc_y()
			_spawn_t1_negative(lanes[c - 1] + oy, vp_w, speed, _t1_trash)
			_spawn_item(lanes[c] + oy, vp_w, PIZZA_TEX, 0.09, speed, 0, true, true, true)
			_spawn_t1_negative(lanes[c + 1] + oy, vp_w, speed, _t1_trash)
			if i < 3:
				await get_tree().create_timer(gap).timeout
		if chunk_idx < order.size() - 1:
			if _frozen: return
			await get_tree().create_timer(gap * 1.2).timeout
			_spawn_item(lanes[2] + _t1_osc_y(), vp_w, PIZZA_TEX, 0.09, speed, 0, true, true, true)
			await get_tree().create_timer(gap * 1.3).timeout

# ── T2: Mixed lines ───────────────────────────────────────────────────────────

func _pat_t2(speed: float, lanes: Array, vp_w: float) -> void:
	var r          := randf()
	var gate_count := randi_range(3, mini(3 + _pat_tier * 2, 10))
	if   r < 0.40: await _t2_mixed_line(speed, lanes, vp_w)
	elif r < 0.70: await _t2_zigzag_wide(speed, lanes, vp_w)
	else:          await _t2_gate_attack(speed, lanes, vp_w, gate_count)

func _t2_mixed_line(speed: float, lanes: Array, vp_w: float) -> void:
	var gap         := _col_gap(speed)
	var dollar_lane := 1 if randf() < 0.5 else 2
	var glove_lane  = [0, dollar_lane][randi() % 2]
	for i in 5:
		if _frozen: return
		_spawn_item(lanes[0], vp_w, PIZZA_TEX, 0.09, speed, 0, true, true, true)
		_spawn_dollar(lanes[dollar_lane], vp_w, speed)
		if i < 4:
			await get_tree().create_timer(gap).timeout
	if _frozen: return
	await get_tree().create_timer(gap * 0.6).timeout
	_spawn_glove(lanes[glove_lane], vp_w)

func _t2_zigzag_wide(speed: float, lanes: Array, vp_w: float) -> void:
	var gap     := _col_gap(speed) * 1.3
	var pattern := [0, 1, 2, 3, 4, 3, 2]
	for i in pattern.size():
		if _frozen: return
		_spawn_item(lanes[pattern[i]], vp_w, PIZZA_TEX, 0.09, speed, 0, true, true, true)
		if i < pattern.size() - 1:
			await get_tree().create_timer(gap).timeout

func _spawn_t2_gate_obstacle(y: float, vp_w: float, speed: float) -> void:
	_spawn_snake(y, vp_w, speed)

func _t2_gate_attack(speed: float, lanes: Array, vp_w: float, count: int = 3) -> void:
	var gap  := _col_gap(speed) * 2.0
	var free := randi() % LANE_COUNT
	for rep in count:
		if _frozen: return
		for i in LANE_COUNT:
			if i != free:
				_spawn_t2_gate_obstacle(lanes[i], vp_w, speed)
		if rep < count - 1:
			await get_tree().create_timer(gap).timeout
			# shift free lane by exactly ±1; flip direction at edges so it never repeats
			var dir := 1 if randf() < 0.5 else -1
			if free + dir < 0 or free + dir >= LANE_COUNT:
				dir = -dir
			free += dir
	# Prize appears after the last gate with extra delay
	if _frozen: return
	await get_tree().create_timer(gap * 1.5).timeout
	_spawn_item(lanes[free], vp_w, PIZZA_TEX, 0.09, speed, 0, true, true, true)

# ── T3: Figures ───────────────────────────────────────────────────────────────

func _pat_t3(speed: float, lanes: Array, vp_w: float) -> void:
	if randf() < 0.5:
		await _t3_checkerboard(speed, lanes, vp_w)
	else:
		await _t3_diagonal(speed, lanes, vp_w)

func _t3_checkerboard(speed: float, lanes: Array, vp_w: float) -> void:
	var gap    := _col_gap(speed) * 2.5
	var cols   := 4 + _pat_tier * 2
	var offset := 0
	for col in cols:
		if _frozen: return
		for lane in LANE_COUNT:
			if (lane + offset) % 2 == 0:
				_spawn_item(lanes[lane], vp_w, PIZZA_TEX, 0.09, speed, 0, true, true, true)
			else:
				_spawn_item(lanes[lane], vp_w, STONE_TEX, 0.16, speed, 1, false, false, false, "stone")
		offset = 1 - offset
		if col < cols - 1:
			await get_tree().create_timer(gap).timeout

func _t3_diagonal(speed: float, lanes: Array, vp_w: float) -> void:
	var gap        := _col_gap(speed) * 1.5
	var forward    := randf() < 0.5
	var glove_step := randi() % LANE_COUNT
	for i in LANE_COUNT:
		if _frozen: return
		var lane := i if forward else (LANE_COUNT - 1 - i)
		_spawn_item(lanes[lane], vp_w, PIZZA_TEX, 0.09, speed, 0, true, true, true)
		if i == glove_step:
			# glove fires on the lane adjacent to the pizza lane
			var glove_lane := (lane + 2) % LANE_COUNT
			_spawn_glove(lanes[glove_lane], vp_w)
		if i < LANE_COUNT - 1:
			await get_tree().create_timer(gap).timeout

# ── T4: Glove waves ───────────────────────────────────────────────────────────

func _pat_t4(speed: float, lanes: Array, vp_w: float) -> void:
	# Endless T4 runs the pre-boss glove sweep instead of the old multi-wave
	# glove patterns. Campaign T4 (phases 2-4) keeps the rich variant pool.
	if not campaign_mode:
		await _wave_glove_sweep(speed, lanes, vp_w)
		return
	match randi() % 6:
		0: await _t4_glove_basic(speed, lanes, vp_w)
		1: await _t4_glove_multiwave(speed, lanes, vp_w)
		2: await _t4_glove_split_23(speed, lanes, vp_w)
		3: await _t4_glove_split_32(speed, lanes, vp_w)
		4: await _t4_glove_1_vs_all(speed, lanes, vp_w)
		5: await _t4_glove_all_vs_1(speed, lanes, vp_w)

func _t4_glove_basic(speed: float, lanes: Array, vp_w: float) -> void:
	var gap       := _col_gap(speed)
	var glove_set := [0, 2, 4] if randf() < 0.5 else [1, 3]
	var safe_set  : Array = []
	for lane in LANE_COUNT:
		if not (lane in glove_set): safe_set.append(lane)
	# Glove snapshot + 1 pizza on a random safe lane
	if _frozen: return
	for lane in glove_set:
		_spawn_glove(lanes[lane], vp_w)
	_spawn_item(lanes[safe_set[randi() % safe_set.size()]], vp_w, PIZZA_TEX, 0.09, speed, 0, true, true, true)
	# 1 pizza reward on a random safe lane
	if _frozen: return
	await get_tree().create_timer(gap).timeout
	_spawn_item(lanes[safe_set[randi() % safe_set.size()]], vp_w, PIZZA_TEX, 0.09, speed, 0, true, true, true)

func _t4_glove_multiwave(speed: float, lanes: Array, vp_w: float) -> void:
	var gap  := _col_gap(speed)
	var s1   := [1, 3]
	var s2   := [0, 2, 4]
	# Wave 1: gloves on 0,2,4 — 1 pizza on random safe lane
	if _frozen: return
	for lane in [0, 2, 4]:
		_spawn_glove(lanes[lane], vp_w)
	_spawn_item(lanes[s1[randi() % s1.size()]], vp_w, PIZZA_TEX, 0.09, speed, 0, true, true, true)
	if _frozen: return
	await get_tree().create_timer(gap).timeout
	_spawn_item(lanes[s1[randi() % s1.size()]], vp_w, PIZZA_TEX, 0.09, speed, 0, true, true, true)
	if _frozen: return
	# Wait until wave 1 fires (enter + charge), then immediately spawn wave 2.
	await get_tree().create_timer(maxf(0.0, _glove_punch_delay(speed) - gap)).timeout
	# Wave 2: gloves on 1,3 — 1 pizza on random safe lane
	for lane in [1, 3]:
		_spawn_glove(lanes[lane], vp_w)
	_spawn_item(lanes[s2[randi() % s2.size()]], vp_w, PIZZA_TEX, 0.09, speed, 0, true, true, true)
	if _frozen: return
	await get_tree().create_timer(gap).timeout
	_spawn_item(lanes[s2[randi() % s2.size()]], vp_w, PIZZA_TEX, 0.09, speed, 0, true, true, true)

# Вар.3 — split 2|3: top-2 vs bottom-3 (or reversed). Пара чередующихся волн по блокам.
func _t4_glove_split_23(speed: float, lanes: Array, vp_w: float) -> void:
	var gap       := _col_gap(speed)
	var top_first := randf() < 0.5
	var w1 : Array = [0, 1] if top_first else [2, 3, 4]
	var w2 : Array = [2, 3, 4] if top_first else [0, 1]
	var s1 : Array = []
	var s2 : Array = []
	for i in LANE_COUNT:
		if not (i in w1): s1.append(i)
		if not (i in w2): s2.append(i)
	if _frozen: return
	for lane in w1:
		_spawn_glove(lanes[lane], vp_w)
	_spawn_item(lanes[s1[randi() % s1.size()]], vp_w, PIZZA_TEX, 0.09, speed, 0, true, true, true)
	if _frozen: return
	await get_tree().create_timer(gap).timeout
	_spawn_item(lanes[s1[randi() % s1.size()]], vp_w, PIZZA_TEX, 0.09, speed, 0, true, true, true)
	if _frozen: return
	# Next glove wave arrives the moment the previous one fires.
	await get_tree().create_timer(maxf(0.0, _glove_punch_delay(speed) - gap)).timeout
	for lane in w2:
		_spawn_glove(lanes[lane], vp_w)
	_spawn_item(lanes[s2[randi() % s2.size()]], vp_w, PIZZA_TEX, 0.09, speed, 0, true, true, true)
	if _frozen: return
	await get_tree().create_timer(gap).timeout
	_spawn_item(lanes[s2[randi() % s2.size()]], vp_w, PIZZA_TEX, 0.09, speed, 0, true, true, true)

# Вар.4 — split 3|2: top-3 vs bottom-2 (or reversed). Несимметричная пара.
func _t4_glove_split_32(speed: float, lanes: Array, vp_w: float) -> void:
	var gap       := _col_gap(speed)
	var top_first := randf() < 0.5
	var w1 : Array = [0, 1, 2] if top_first else [3, 4]
	var w2 : Array = [3, 4] if top_first else [0, 1, 2]
	var s1 : Array = []
	var s2 : Array = []
	for i in LANE_COUNT:
		if not (i in w1): s1.append(i)
		if not (i in w2): s2.append(i)
	if _frozen: return
	for lane in w1:
		_spawn_glove(lanes[lane], vp_w)
	_spawn_item(lanes[s1[randi() % s1.size()]], vp_w, PIZZA_TEX, 0.09, speed, 0, true, true, true)
	if _frozen: return
	await get_tree().create_timer(gap).timeout
	_spawn_item(lanes[s1[randi() % s1.size()]], vp_w, PIZZA_TEX, 0.09, speed, 0, true, true, true)
	if _frozen: return
	# Next glove wave arrives the moment the previous one fires.
	await get_tree().create_timer(maxf(0.0, _glove_punch_delay(speed) - gap)).timeout
	for lane in w2:
		_spawn_glove(lanes[lane], vp_w)
	_spawn_item(lanes[s2[randi() % s2.size()]], vp_w, PIZZA_TEX, 0.09, speed, 0, true, true, true)
	if _frozen: return
	await get_tree().create_timer(gap).timeout
	_spawn_item(lanes[s2[randi() % s2.size()]], vp_w, PIZZA_TEX, 0.09, speed, 0, true, true, true)

# Вар.5 — 1 vs all (сложный): сначала одна перчатка, потом сразу 4 — только 1 безопасная дорожка.
func _t4_glove_1_vs_all(speed: float, lanes: Array, vp_w: float) -> void:
	var gap    := _col_gap(speed)
	var solo   := randi() % LANE_COUNT
	var others : Array = []
	for i in LANE_COUNT:
		if i != solo: others.append(i)
	if _frozen: return
	_spawn_glove(lanes[solo], vp_w)
	_spawn_item(lanes[others[randi() % others.size()]], vp_w, PIZZA_TEX, 0.09, speed, 0, true, true, true)
	if _frozen: return
	await get_tree().create_timer(gap).timeout
	_spawn_item(lanes[others[randi() % others.size()]], vp_w, PIZZA_TEX, 0.09, speed, 0, true, true, true)
	if _frozen: return
	# Spawn the follow-up wave as the first one fires.
	await get_tree().create_timer(maxf(0.0, _glove_punch_delay(speed) - gap)).timeout
	for lane in others:
		_spawn_glove(lanes[lane], vp_w)
	_spawn_item(lanes[solo], vp_w, PIZZA_TEX, 0.09, speed, 0, true, true, true)

# Вар.6 — all vs 1 (сложный): сначала 4 перчатки (1 безопасная), потом перчатка бьёт по ней же.
func _t4_glove_all_vs_1(speed: float, lanes: Array, vp_w: float) -> void:
	var gap    := _col_gap(speed)
	var safe   := randi() % LANE_COUNT
	var gloved : Array = []
	for i in LANE_COUNT:
		if i != safe: gloved.append(i)
	if _frozen: return
	for lane in gloved:
		_spawn_glove(lanes[lane], vp_w)
	_spawn_item(lanes[safe], vp_w, PIZZA_TEX, 0.09, speed, 0, true, true, true)
	if _frozen: return
	# Spawn the follow-up wave as the first one fires.
	await get_tree().create_timer(maxf(0.0, _glove_punch_delay(speed) - gap)).timeout
	_spawn_glove(lanes[safe], vp_w)
	var new_safe : Array = []
	for i in LANE_COUNT:
		if i != safe: new_safe.append(i)
	_spawn_item(lanes[new_safe[randi() % new_safe.size()]], vp_w, PIZZA_TEX, 0.09, speed, 0, true, true, true)
	if _frozen: return
	await get_tree().create_timer(gap).timeout
	_spawn_item(lanes[new_safe[randi() % new_safe.size()]], vp_w, PIZZA_TEX, 0.09, speed, 0, true, true, true)

# ── T5: Molotov waves ─────────────────────────────────────────────────────────
# Cadence rules (player feedback driven):
#   • Cap of ~5 molotovs in flight at once → walls cap at 3 fires per column,
#     checkerboard parities are sized so two adjacent columns can't add up to
#     more than 5 visible at the same x.
#   • 5-second rest after every wave so the screen has time to breathe.
#   • Walls are the bread-and-butter shape; checkerboard only kicks in on the
#     hardest phases (with an inverse follow-up at the very top).
const COL_T5_STEP   : float = 1.30   # spacing between columns (× _col_gap)
const T5_WAVE_REST  : float = 5.0    # pause appended at the end of every wave

# Wall presets — 5-row bitmask (1 = molotov, 0 = safe lane). Each preset has
# 2-3 gaps so the player can drift between them with the standard inertia.
const T5_WALL_PRESETS : Array = [
	[1, 1, 0, 0, 1],   # gap rows 2-3
	[1, 0, 0, 1, 1],   # gap rows 1-2
	[1, 1, 0, 1, 0],   # gap rows 2, 4
	[0, 1, 1, 0, 1],   # gap rows 0, 3
	[1, 0, 1, 0, 1],   # alt: rows 0,2,4 lit (max 3)
	[1, 1, 0, 1, 0],   # mirror of above
]

func _pat_t5(speed: float, lanes: Array, vp_w: float) -> void:
	# Endless T5 now runs the pre-boss single-molotov-right wave instead of
	# the old wall / checkerboard variants. Pizza reward on the central lane
	# is kept so endless economy isn't gutted. Campaign T5 keeps its walls.
	if not campaign_mode:
		await _wave_molotov_right(speed, lanes, vp_w)
		if _frozen: return
		_spawn_item(lanes[2], vp_w, PIZZA_TEX, 0.09, speed, 0, true, true, true)
		return

	# Pick the wave shape by phase:
	#   0–3: plain wall, single column, 3 fires + 2 safe gaps.
	#   4 (Ад): wall, then an inverse-style second column right after.
	#   5+ (Безумие): 2-column checkerboard.
	#   7+ (Безумие III+): checkerboard + inverse follow-up (cross).
	if _phase <= 3:
		await _t5_wall(speed, lanes, vp_w)
	elif _phase <= 4:
		await _t5_two_walls(speed, lanes, vp_w)
	elif _phase <= 6:
		await _t5_molotov_checkerboard(speed, lanes, vp_w, 2, 0)
	else:
		await _t5_molotov_checkerboard(speed, lanes, vp_w, 2, 0)
		if _frozen: return
		await get_tree().create_timer(_col_gap(speed) * COL_T5_STEP).timeout
		await _t5_molotov_checkerboard(speed, lanes, vp_w, 2, 1)

	# Pizza reward on the central safe lane after the wave fully passes.
	if _frozen: return
	await get_tree().create_timer(_col_gap(speed) * COL_T5_STEP).timeout
	_spawn_item(lanes[2], vp_w, PIZZA_TEX, 0.09, speed, 0, true, true, true)

	# Mandatory cooldown so consecutive T5 patterns don't pile on.
	if _frozen: return
	await get_tree().create_timer(T5_WAVE_REST).timeout

# Single "wall" column: 3 molotovs + 2 safe gaps, layout picked at random
# from T5_WALL_PRESETS so the player can't memorise one path.
func _t5_wall(speed: float, lanes: Array, vp_w: float) -> void:
	if _frozen: return
	var preset : Array = T5_WALL_PRESETS[randi() % T5_WALL_PRESETS.size()]
	for row in lanes.size():
		if int(preset[row]) == 1:
			_spawn_molotov(lanes[row], vp_w, speed)

# Two walls in a row with DIFFERENT gap positions so the player has to slide
# from one safe column to another. Step gap is wide enough that the first
# column is mostly past Normaldo before the second arrives, keeping <= 5 in
# flight at any moment.
func _t5_two_walls(speed: float, lanes: Array, vp_w: float) -> void:
	var first  : Array = T5_WALL_PRESETS[randi() % T5_WALL_PRESETS.size()]
	# Pick a second preset whose gap pattern differs from the first.
	var second : Array = first
	var safety : int   = 8
	while second == first and safety > 0:
		second  = T5_WALL_PRESETS[randi() % T5_WALL_PRESETS.size()]
		safety -= 1
	if _frozen: return
	for row in lanes.size():
		if int(first[row]) == 1:
			_spawn_molotov(lanes[row], vp_w, speed)
	if _frozen: return
	await get_tree().create_timer(_col_gap(speed) * COL_T5_STEP * 1.4).timeout
	for row in lanes.size():
		if int(second[row]) == 1:
			_spawn_molotov(lanes[row], vp_w, speed)

# Multi-column checkerboard — reserved for the toughest phases. Parity flips
# per column so the safe lanes alternate. Two columns max keeps the in-flight
# count under 5 (3 + 2 = 5).
func _t5_molotov_checkerboard(speed: float, lanes: Array, vp_w: float, cols: int, parity_start: int) -> void:
	var step : float = _col_gap(speed) * COL_T5_STEP
	for c in cols:
		if _frozen: return
		var parity : int = (c + parity_start) % 2
		for row in lanes.size():
			if (row % 2) == parity:
				_spawn_molotov(lanes[row], vp_w, speed)
		if c < cols - 1:
			await get_tree().create_timer(step).timeout

# ── Bonus item (inter-pattern) ────────────────────────────────────────────────

# В бесконечном режиме случайного потока нет — весь «инвентарь» новых предметов
# приходит через этот бонус между паттернами. Поэтому пул здесь шире, чем был:
# иначе половина предметов существовала бы только в кампании.
func _spawn_bonus_item(speed: float, vp_w: float, lanes: Array) -> void:
	var y : float = lanes[randi() % LANE_COUNT]
	var roll := randf()
	if   roll < 0.18: _inst_lane(MAGNET_SCENE,      speed, vp_w, lanes)
	elif roll < 0.34: _inst_lane(BOOMBOX_SCENE,     speed, vp_w, lanes)
	elif roll < 0.48: _inst_lane(PIZZA_PACK_SCENE,  speed, vp_w, lanes)
	elif roll < 0.60: _inst_lane(MONEY_BAG_SCENE,   speed, vp_w, lanes)
	elif roll < 0.68: _spawn_effect_item("hourglass",  y, vp_w, speed)
	elif roll < 0.76: _spawn_effect_item("casey_mask", y, vp_w, speed)
	elif roll < 0.83: _spawn_effect_item("magic_hat",  y, vp_w, speed)
	elif roll < 0.89: _spawn_effect_item("cola",       y, vp_w, speed)
	elif roll < 0.93: _spawn_scripted(MAGIC_BOX_SCRIPT, y, vp_w, speed)
	elif roll < 0.96: _spawn_effect_item("black_ace",    y, vp_w, speed)
	elif roll < 0.98: _spawn_ninja(y, vp_w, speed)
	elif roll < 0.975: _spawn_effect_item("loser_ticket", y, vp_w, speed)
	elif roll < 0.995: _spawn_hazard(_pick_hazard(), y, vp_w, speed)
	else:              _spawn_effect_item("casino_chip",  y, vp_w, speed)

# ── Scene helpers ─────────────────────────────────────────────────────────────

func _spawn_snake(y: float, vp_w: float, speed: float, solo: bool = false) -> void:
	var s      := SNAKE_SCENE.instantiate()
	s.speed     = speed * 1.05
	s.position  = Vector2(vp_w + 80.0, y)
	_size_hazard(s, y, speed, solo)
	add_child(s)

func _spawn_dog(y: float, vp_w: float, speed: float, solo: bool = false) -> void:
	var d      := DOG_SCENE.instantiate()
	d.speed     = speed
	d.position  = Vector2(vp_w + 80.0, y)
	_size_hazard(d, y, speed, solo)
	add_child(d)

func _spawn_molotov(y: float, vp_w: float, speed: float, fire_count: int = 4) -> void:
	var m       := MOLOTOV_SCENE.instantiate()
	m.speed      = speed
	m.fire_count = fire_count + (1 if _endless_mods.get("molotov_plus", false) else 0)
	m.position   = Vector2(vp_w + 80.0, y)
	add_child(m)

func _spawn_glove(y: float, vp_w: float) -> void:
	var g      := BOXING_GLOVE_SCENE.instantiate()
	g.position  = Vector2(vp_w + 80.0, y)
	g.charge_duration = _glove_charge_duration_for_phase()
	add_child(g)

# Charge duration scales linearly with the current phase index:
#   first phase  → GLOVE_CHARGE_SLOW (more reaction time, training-friendly)
#   last phase   → GLOVE_CHARGE_FAST (pre-boss tension matches old behaviour)
# Campaign has 6 phases (0..5), endless has 10 (0..9). Pre-boss phase keeps
# the fast charge so the slot still feels like the climax.
const GLOVE_CHARGE_SLOW : float = 0.90   # длиннее чардж на ранних фазах (со 2-й минуты)
const GLOVE_CHARGE_FAST : float = 0.30

func _glove_charge_duration_for_phase() -> float:
	var last_idx : int
	if campaign_mode:
		last_idx = CAMPAIGN_PHASES.size() - 1
	else:
		last_idx = ENDLESS_PHASES.size() - 1
	if last_idx <= 0:
		return GLOVE_CHARGE_FAST
	var t : float = clampf(float(_phase) / float(last_idx), 0.0, 1.0)
	return lerpf(GLOVE_CHARGE_SLOW, GLOVE_CHARGE_FAST, t)

func _inst_lane(scene: PackedScene, speed: float, vp_w: float, lanes: Array, set_speed: bool = true) -> void:
	var node := scene.instantiate()
	if set_speed and node.get("speed") != null:
		node.speed = speed
	node.position = Vector2(vp_w + 80.0, lanes[randi() % LANE_COUNT])
	add_child(node)

# Собрать предмет, НЕ добавляя в дерево — нужно и обычному спавну, и мэджик
# боксу, который сам решает, куда предмет полетит.
# Текстура → запись каталога для предметов на общем `item.gd`.
#
# Каталог берётся ПО ПУТИ в дереве, а не по имени автолоада: `godot --script`
# компилирует спавнер раньше, чем поднимаются автолоады, и любой тест, который
# его подгружает, падал бы на «Identifier not found: Bestiary».
const BESTIARY_BY_TEX : Dictionary = {
	PIZZA_TEX: "pizza", DOLLAR_TEX: "dollar", STONE_TEX: "stone",
	TRASH_TEX: "trash",
}

func _make_item(tex: Texture2D, scale: float, speed: float, damage: int,
		eatable: bool = false, rotates: bool = true, pulses: bool = false,
		skin_tag: String = "") -> Node2D:
	# Пицца, доллар и часть опасностей летят ОДНИМ скриптом `item.gd` и
	# отличаются только текстурой — хук каталога по скрипту их не различает.
	# Поэтому здесь, где текстура ещё известна, запись помечается вручную.
	var bid : String = String(BESTIARY_BY_TEX.get(tex, ""))
	if bid != "":
		var cat : Node = get_node_or_null("/root/Bestiary")
		if cat != null:
			cat.call("mark", bid)
	var item          := ITEM_SCENE.instantiate()
	item.speed         = speed
	item.is_eatable    = eatable
	item.damage        = damage
	item.rotates       = rotates
	item.pulses        = pulses
	if skin_tag != "":
		item.skin_tag = skin_tag
	var sprite        := item.get_node("Sprite2D") as Sprite2D
	sprite.texture     = tex
	sprite.scale       = Vector2.ONE * scale
	return item

func _spawn_item(y: float, vp_w: float, tex: Texture2D, scale: float,
		speed: float, damage: int, eatable: bool = false, rotates: bool = true,
		pulses: bool = false, skin_tag: String = "", solo: bool = false) -> Node:
	var item := _make_item(tex, scale, speed, damage, eatable, rotates, pulses, skin_tag)
	item.position = Vector2(vp_w + 80.0, y)
	# Размер рандомим только ударяющим — ресурсы должны читаться «на съедобность»
	# мгновенно, а для этого пицца обязана быть всегда одного размера.
	if damage > 0:
		_size_hazard(item, y, speed, solo)
	else:
		_mark_base_span(y)
	add_child(item)
	return item

# ── Пул мэджик бокса ─────────────────────────────────────────────────────────
# Ящик сам решает, куда полетит предмет, поэтому получает его НЕ добавленным в
# дерево. Пул смещён в плюс (пицца/доллары ≈ 60 %), но с ощутимой долей риска —
# иначе ящик превращается в гарантированную награду и обесценивает поток.
# См. magic_box.gd
func build_random_item(speed: float) -> Node2D:
	var roll := randf()
	if roll < 0.42:
		return _make_item(PIZZA_TEX, 0.09, speed, 0, true, true, true)
	elif roll < 0.60:
		var d := _make_item(DOLLAR_TEX, 0.36, speed, 0, false, true, true)
		d.item_group = "dollar"
		return d
	elif roll < 0.66:
		return _effect_node("casey_mask", speed)
	elif roll < 0.72:
		return _effect_node("magic_hat", speed)
	elif roll < 0.78:
		return _effect_node("cola", speed)
	elif roll < 0.83:
		return _effect_node("hourglass", speed)
	elif roll < 0.92:
		# Замедляющие — банан, пиво и коктейль. Их доля выросла за счёт жетона
		# автомата: жетон из ящика выпадать перестал. Жетон — валюта, а ящик по
		# замыслу ставка на ПОЛЕ: выпавшая валюта не создаёт на экране никакой
		# ситуации, её просто подбирают.
		var sl : Node2D
		var pick := randf()
		if pick < 0.34:
			sl = BANANA_PEEL_SCENE.instantiate()
		elif pick < 0.68:
			sl = BEER_SCENE.instantiate()
		else:
			return _hazard_node("cocktail", speed)
		sl.speed = speed
		return sl
	elif roll < 0.97:
		var sn := SNAKE_SCENE.instantiate()
		sn.speed = speed
		return sn
	else:
		return _effect_node("black_ace", speed)

# Опасный предмет ОТДЕЛЬНЫМ узлом, без постановки в поток: мэджик бокс сам
# решает, куда его выплюнуть (см. magic_box.gd), и позиция ему выдаётся позже.
func _hazard_node(kind: String, speed: float) -> Node2D:
	var node := Area2D.new()
	node.set_script(HAZARD_ITEM_SCRIPT)
	node.set("kind", kind)
	node.set("speed", speed)
	return node

func _effect_node(kind: String, speed: float) -> Node2D:
	var node := Area2D.new()
	node.set_script(EFFECT_ITEM_SCRIPT)
	node.set("kind", kind)
	node.set("speed", speed)
	return node

func _spawn_dollar(y: float, vp_w: float, speed: float) -> void:
	var item       := ITEM_SCENE.instantiate()
	item.speed      = speed
	item.is_eatable = false
	item.damage     = 0
	item.rotates    = true
	item.pulses     = true
	item.item_group = "dollar"
	var sprite     := item.get_node("Sprite2D") as Sprite2D
	sprite.texture  = DOLLAR_TEX
	sprite.scale    = Vector2.ONE * 0.36
	item.position   = Vector2(vp_w + 80.0, y)
	_mark_base_span(y)
	add_child(item)

func _spawn_slowing(y: float, vp_w: float, speed: float, banana_only: bool = false) -> void:
	var scene := BANANA_PEEL_SCENE if (banana_only or randf() < 0.5) else BEER_SCENE
	var item  := scene.instantiate()
	item.speed    = speed
	item.position = Vector2(vp_w + 80.0, y)
	add_child(item)

# ── Pre-boss resource rain ───────────────────────────────────────────────────
# During the campaign's pre-boss phase we keep showering pizza/dollar swarms
# (80/20 mix, more pizzas than a money-bag burst) on top of the existing
# molotov + glove waves. The molotovs and their fires already destroy items
# from "pizza"/"dollar" groups on contact, so the player sees waves of loot
# arrive and then get torched mid-flight.
const PRE_BOSS_BURST_INTERVAL  : float = 2.0
const PRE_BOSS_BURST_COUNT_MIN : int   = 12
const PRE_BOSS_BURST_COUNT_MAX : int   = 16
const PRE_BOSS_DOLLAR_RATIO    : float = 0.20
const PRE_BOSS_PIZZA_SCALE     : float = 0.09
const PRE_BOSS_DOLLAR_SCALE    : float = 0.36

var _pre_boss_burst_active : bool = false

func _start_pre_boss_resource_rain() -> void:
	if _pre_boss_burst_active:
		return
	_pre_boss_burst_active = true
	_pre_boss_resource_loop()

func _pre_boss_resource_loop() -> void:
	while _pre_boss_burst_active:
		if _frozen or not campaign_mode or _phase != CAMPAIGN_PHASES.size() - 1:
			break
		_spawn_pre_boss_resource_burst()
		await get_tree().create_timer(PRE_BOSS_BURST_INTERVAL).timeout
	_pre_boss_burst_active = false

func _spawn_pre_boss_resource_burst() -> void:
	if _phase < 0 or _phase >= CAMPAIGN_PHASES.size():
		return
	var speed   := CAMPAIGN_PHASES[_phase]["speed"] as float
	var vp      := get_viewport_rect()
	var vp_w    := vp.size.x
	var vp_h    := vp.size.y
	var count   := randi_range(PRE_BOSS_BURST_COUNT_MIN, PRE_BOSS_BURST_COUNT_MAX)
	# Even vertical distribution with jitter + staggered horizontal offsets so
	# items arrive at different times (same recipe as money_bag.burst()).
	var indices : Array = range(count)
	indices.shuffle()
	var row_h := vp_h / float(count)
	for i in count:
		var base_y : float = row_h * (indices[i] + 0.5)
		var jitter : float = randf_range(-row_h * 0.35, row_h * 0.35)
		var x_off  : float = randf_range(40.0, 220.0)
		var y      : float = base_y + jitter
		var item   := ITEM_SCENE.instantiate()
		item.speed    = speed
		item.damage   = 0
		item.rotates  = true
		item.pulses   = true
		var sprite   := item.get_node("Sprite2D") as Sprite2D
		if randf() < PRE_BOSS_DOLLAR_RATIO:
			item.is_eatable = false
			item.item_group = "dollar"
			sprite.texture  = DOLLAR_TEX
			sprite.scale    = Vector2.ONE * PRE_BOSS_DOLLAR_SCALE
		else:
			item.is_eatable = true
			sprite.texture  = PIZZA_TEX
			sprite.scale    = Vector2.ONE * PRE_BOSS_PIZZA_SCALE
		item.position = Vector2(vp_w + x_off, y)
		add_child(item)

func dev_spawn_money_bag() -> void:
	var vp_w  := get_viewport_rect().size.x
	var speed := (CAMPAIGN_PHASES[_phase]["speed"] if campaign_mode else ENDLESS_PHASES[_phase]["speed"]) as float
	_inst_lane(MONEY_BAG_SCENE, speed, vp_w, _lane_centers())

# Dev hotkey: jump straight to the next phase without waiting out the timer.
# Campaign: stepping past the final (pre-boss) phase fires boss_time, mirroring
# the natural campaign end. Endless: clamps at the last Безумие phase.
func dev_skip_to_next_phase() -> void:
	_phase_elapsed = 0.0
	if campaign_mode:
		_phase += 1
		_campaign_intro_left = 0
		_pre_boss_last_type  = -1
		if _phase >= CAMPAIGN_PHASES.size():
			set_process(false)
			boss_time.emit()
			return
		_spawn_timer = 0.4
		phase_entered.emit(_phase)
		if _phase == CAMPAIGN_PHASES.size() - 1:
			_start_pre_boss_resource_rain()
	else:
		_advance_endless_phase()

func clear_items() -> void:
	set_process(false)
	_frozen          = true
	_pattern_running = false
	_reset_spans()
	for child in get_children():
		child.queue_free()

# Резервы места привязаны к _elapsed, а он не идёт, пока спавнер заморожен.
# Любая пауза/зачистка обязана их сбросить, иначе после возобновления спавнер
# считает, что весь экран ещё занят уехавшими предметами.
func _reset_spans() -> void:
	_spans.clear()
	_big_clear_t = -1.0

# ── Event hooks (ЖИРОБОСС mini-game) ──────────────────────────────────────────
# pause_for_event stops phase advancement + new pattern spawns while keeping the
# current phase intact; resume_after_event restarts the runner where it left off.

func pause_for_event() -> void:
	_frozen          = true
	_pattern_running = false
	_reset_spans()
	set_process(false)

# Like clear_items(), but the items visibly COLLAPSE — drop off the bottom with
# a tumble + fade — instead of blinking out. Used when the mutagen freezes the
# run for the ЖИРОБОСС mini-game. Each item's own _process is stopped so the
# fall tween fully owns its motion.
# Collapse a single node: stop its own motion + collision, then tumble it down
# off the bottom with a spin + fade and free it. Reused for the whole field
# (collapse_items) and for the mini-game's own items when it ends.
func collapse_node(node: Node2D) -> void:
	node.set_process(false)
	node.set_physics_process(false)
	if node is CollisionObject2D:
		node.set_deferred("collision_layer", 0)
	var t := randf_range(0.55, 0.95)
	var tw := node.create_tween().set_parallel(true)
	tw.tween_property(node, "position:y", get_viewport_rect().size.y + 260.0, t) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(node, "rotation", node.rotation + randf_range(-4.0, 4.0), t)
	tw.tween_property(node, "modulate:a", 0.0, t)
	tw.chain().tween_callback(node.queue_free)

# ── Чужой мусор в воздухе ────────────────────────────────────────────────────
# Мини-игры держат свои снаряды У СЕБЯ, а не здесь: спиты пицца-пати и поток
# ЖИРОБОССА — дети своих узлов. Поэтому `collapse_items()` их не видит: он
# перебирает СВОИХ детей, и всё, что уже вылетело из пачки, продолжало лететь
# поверх развернувшихся на весь экран автоматов.
#
# Замораживающая забег мини-игра зовёт это вместе с `collapse_items()` и
# передаёт себя, чтобы не уронить собственный поток.
const MINIGAME_NODES : Array = ["PizzaParty", "FatBoss", "SlotsGame"]

func collapse_minigame_debris(except: Node = null) -> void:
	var root := get_parent()
	if root == null:
		return
	for n in MINIGAME_NODES:
		var mg : Node = root.get_node_or_null(String(n))
		if mg == null or mg == except or not mg.has_method("drop_flying"):
			continue
		mg.call("drop_flying")

func collapse_items() -> void:
	set_process(false)
	_frozen          = true
	_pattern_running = false
	_reset_spans()
	for child in get_children():
		if child is Node2D:
			collapse_node(child)
		else:
			child.queue_free()

func resume_after_event() -> void:
	_frozen          = false
	_pattern_running = false
	_spawn_timer     = 0.6
	_reset_spans()
	set_process(true)

func current_phase_speed() -> float:
	if campaign_mode:
		return CAMPAIGN_PHASES[mini(_phase, CAMPAIGN_PHASES.size() - 1)]["speed"]
	return ENDLESS_PHASES[mini(_phase, ENDLESS_PHASES.size() - 1)]["speed"]
