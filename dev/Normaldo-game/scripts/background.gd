extends Node2D

# ── Фон канализации ───────────────────────────────────────────────────────────
# Фон — это НАРИСОВАННАЯ ПОЛОСА со старого проекта, а не плитка с процедурным
# декором. Полоса `level1.png` (9379 × 430) нарезана на четырнадцать кусков
# 645 × 430 и проигрывается по кругу: 01 → 02 → … → 14 → 01. Порядок обязателен —
# это одна непрерывная картина, у соседних кусков сходятся кладка, линия пола и
# рисунок, и перемешать их значит получить ступеньки и обрывы.
#
# Высота куска равна высоте вьюпорта (430), поэтому масштаб ровно 1.0: фон не
# растягивается и пиксель остаётся пикселем.
#
# ── Что отсюда убрано и почему ───────────────────────────────────────────────
# Прошлая версия склеивала фон из плитки 344 × 192 в четырёх вариантах и
# ОЖИВЛЯЛА её процедурно: лампы под потолком, трубы из стыков кладки, крысы с
# сыром, бегущие крысы, город-параллакс в проёмах стены. Пятьсот строк на то,
# чтобы повторяющаяся плитка не читалась как повторяющаяся плитка.
#
# У нарисованной полосы этой задачи нет: там всё это УЖЕ НАРИСОВАНО — паутина,
# висящее мясо, трубы, крыса в слизи, окно с городом. Процедурный декор поверх
# неё не добавлял бы жизни, а спорил с рисунком: своя труба поверх нарисованной
# и своя крыса рядом с нарисованной.
#
# ── Затемнение ───────────────────────────────────────────────────────────────
# Полоса яркая и подробная — это её достоинство и её же проблема: летящая пицца
# на фоне красного кирпича с граффити читается хуже, чем на глухой стене.
# Поэтому поверх фона лежит ровная тёмная плёнка. Она внутри Background, то есть
# накрывает ФОН и только его: предметы, Нормальдо, куш и телевизор рисуются
# позже и остаются в полную силу.
#
# См. /Концепция/Уровни/1-Канализация.md, dev/art/level1/README.md

const SCROLL_SPEED : float = 100.0   # вдвое медленнее предметов
const SLICE_W      : float = 645.0
const SLICE_H      : float = 430.0
const SLICE_COUNT  : int   = 14

# Куски идут ПО ПОРЯДКУ. Массив — это и есть порядок; случайная выборка,
# как было у плитки, разорвала бы картину по всем швам сразу.
const SLICES : Array = [
	preload("res://assets/backgrounds/level1/level1_01.png"),
	preload("res://assets/backgrounds/level1/level1_02.png"),
	preload("res://assets/backgrounds/level1/level1_03.png"),
	preload("res://assets/backgrounds/level1/level1_04.png"),
	preload("res://assets/backgrounds/level1/level1_05.png"),
	preload("res://assets/backgrounds/level1/level1_06.png"),
	preload("res://assets/backgrounds/level1/level1_07.png"),
	preload("res://assets/backgrounds/level1/level1_08.png"),
	preload("res://assets/backgrounds/level1/level1_09.png"),
	preload("res://assets/backgrounds/level1/level1_10.png"),
	preload("res://assets/backgrounds/level1/level1_11.png"),
	preload("res://assets/backgrounds/level1/level1_12.png"),
	preload("res://assets/backgrounds/level1/level1_13.png"),
	preload("res://assets/backgrounds/level1/level1_14.png"),
]

# Кусок 01 — это старый ГЛАВНЫЙ ЭКРАН: на нём нарисованы диван, телевизор и
# вывеска NORMALDO. В меню диван и телевизор стоят настоящими узлами (Нормальдо
# с них спрыгивает и кидает в них пульт), поэтому забег начинается со ВТОРОГО
# куска: иначе рядом с настоящим диваном ехал бы нарисованный.
const START_SLICE : int = 1

# Меню: арка с «БАРом», под которую поставлены настоящие диван и телевизор.
# Кусок полосы её не заменяет — вся мизансцена меню собрана именно под неё.
const TEX_INTRO2 := preload("res://assets/backgrounds/bg_intro2.png")
const INTRO_SRC_W : float = 344.0
const INTRO_SRC_H : float = 192.0
const INTRO_SCALE : float = SLICE_H / INTRO_SRC_H
const INTRO_W     : float = INTRO_SRC_W * INTRO_SCALE
# Плитка масштабируется на дробное число, из-за чего соседние куски садятся на
# полпикселя и на шве проступает щель. Небольшой нахлёст её закрывает.
const INTRO_SEAM_OVERLAP : float = 2.0
const INTRO_STEP  : float = INTRO_W - INTRO_SEAM_OVERLAP

# Плёнка затемнения. 0.25 — «немного»: рисунок фона остаётся читаемым, но
# перестаёт спорить с предметами за внимание.
const DIM_ALPHA : float = 0.25
const DIM_COLOR : Color = Color(0.02, 0.02, 0.04, DIM_ALPHA)

@onready var _bg_intro : Sprite2D = $BgIntro
var _bg_intro2 : Sprite2D = null
@onready var _bg_a : Sprite2D = $BgA
@onready var _bg_b : Sprite2D = $BgB
@onready var _bg_c : Sprite2D = $BgC

var _tiles     : Array[Sprite2D] = []
var _next_idx  : int  = 0     # какой кусок полосы уедет в кадр следующим
var _scrolling : bool = false
var _dim       : ColorRect = null

func start_scrolling() -> void:
	_scrolling = true

func stop_scrolling() -> void:
	_scrolling = false

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("#1a1612"))

	# Правая половина меню: арка не покрывает экран целиком.
	_bg_intro2 = Sprite2D.new()
	_bg_intro2.name     = "BgIntro2"
	_bg_intro2.texture  = TEX_INTRO2
	_bg_intro2.centered = _bg_intro.centered
	add_child(_bg_intro2)
	move_child(_bg_intro2, _bg_intro.get_index() + 1)

	for s: Sprite2D in [_bg_intro, _bg_intro2]:
		s.scale          = Vector2.ONE * INTRO_SCALE
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_bg_intro.position  = Vector2(0.0, 0.0)
	_bg_intro2.position = Vector2(INTRO_STEP, 0.0)

	# Полоса. Три куска по 645 закрывают 1935 px при экране 960 — один в кадре,
	# один на подходе и один в запасе, чтобы подмена текстуры никогда не
	# случалась в видимой зоне.
	_tiles = [_bg_a, _bg_b, _bg_c]
	_next_idx = START_SLICE
	for i in _tiles.size():
		var t : Sprite2D = _tiles[i]
		t.scale          = Vector2.ONE           # 430 в 430, без растяжения
		t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		t.position       = Vector2(INTRO_STEP * 2.0 + SLICE_W * float(i), 0.0)
		t.texture         = _take_next_slice()

	_build_dim()

# Множитель скорости прокрутки. Песочные часы замедляют мир целиком, поэтому
# фон обязан ехать медленнее вместе с предметами — иначе стены «убегают» от
# зависших в воздухе бочек и сцена расползается. Ставит spawner.apply_slow_mo().
var speed_mult : float = 1.0

func _process(delta: float) -> void:
	if not _scrolling:
		return
	var shift := SCROLL_SPEED * speed_mult * delta

	# Меню уезжает и больше не возвращается — дальше идёт только полоса.
	for s: Sprite2D in [_bg_intro, _bg_intro2]:
		if s == null or not s.visible:
			continue
		s.position.x -= shift
		if s.position.x <= -INTRO_W:
			s.visible = false

	for t: Sprite2D in _tiles:
		t.position.x -= shift

	for t: Sprite2D in _tiles:
		if t.position.x <= -SLICE_W:
			var rightmost : float = t.position.x
			for o: Sprite2D in _tiles:
				rightmost = maxf(rightmost, o.position.x)
			t.position.x = rightmost + SLICE_W
			t.texture    = _take_next_slice()

# Следующий кусок полосы по кругу. Именно ПО КРУГУ и по порядку: полоса
# зациклена, кусок 14 сходится с куском 01.
func _take_next_slice() -> Texture2D:
	var tex : Texture2D = SLICES[_next_idx]
	_next_idx = (_next_idx + 1) % SLICE_COUNT
	return tex

# Плёнка добавляется ПОСЛЕДНИМ ребёнком Background: так она рисуется поверх всех
# кусков фона и под всем остальным — диван, телевизор, предметы и Нормальдо
# лежат в сцене дальше и её не задевают.
func _build_dim() -> void:
	var vp := get_viewport_rect().size
	_dim = ColorRect.new()
	_dim.color        = DIM_COLOR
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# С запасом в три экрана и со сдвигом на экран влево. Background целиком
	# ездит на тюинах при переходах между экранами меню (см. hud
	# `_SCENE_PAN_NODES`), и плёнка размером ровно в экран уехала бы вместе с
	# ним, оставив у края полосу неприкрытого фона.
	_dim.size     = vp * 3.0
	_dim.position = -vp
	add_child(_dim)
