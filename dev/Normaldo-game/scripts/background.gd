extends Node2D

# ── Фон ───────────────────────────────────────────────────────────────────────
# Фон умеет ДВА РАЗНЫХ СПОСОБА быть фоном, и уровень выбирает, какой включить:
#
#   • уровень 1 — ПЛИТКА 344×192 в четырёх вариантах, оживлённая процедурным
#     декором: лампы под потолком, трубы из стыков кладки, крысы с сыром,
#     пробегающие крысы, город-параллакс в проёмах стены;
#   • уровни 2 и 3 — НАРИСОВАННЫЕ ПОЛОСЫ, нарезанные на куски 645×430 и
#     проигранные по порядку, как одна непрерывная картина.
#
# Это не переходный период и не недоделка. Помещения разные по своей природе:
# канализация первого уровня — это КОРИДОР, у которого нет ни начала, ни конца, и
# повторяющаяся кладка там читается как «идём и идём». Улица и двор перед клубом
# — это ПУТЬ ИЗ ТОЧКИ В ТОЧКУ, нарисованный целиком, и разрезать его на плитку
# значит выбросить сам рисунок.
#
# У каждого способа своя цена. Плитка повторяется, и без декора это видно —
# поэтому пятьсот строк, которые её оживляют. Полоса не повторяется, но её надо
# рисовать, и куски грузятся по одному, потому что все сразу не помещаются в
# память. Держать оба способа дороже, чем один, — но дешевле, чем платить чужую
# цену за помещение, которому она не подходит.
#
# ── Скорость ─────────────────────────────────────────────────────────────────
# Одна на оба режима, и это не упрощение ради упрощения: `couch.gd` и `tv.gd`
# двигают диван и телевизор СВОИМ кодом на прописанной константе 68 — они едут
# по первому уровню вместе со стеной, и разъехавшись, отрываются от пола.
# У плитки в старом проекте скорость была 100. Менять её обратно нельзя, не
# тронув диван и телевизор, а трогать их незачем: 68 выбрано по отношению к
# скорости ПРЕДМЕТОВ, а не по картинке фона. Задник обязан быть заметно
# медленнее того, что убивает, иначе глаз читает скорость по стене.
#
# См. /Концепция/Уровни/1-Канализация.md, /Концепция/Уровни/Кампания — три уровня.md
const SCROLL_SPEED : float = 68.0

# Множитель скорости прокрутки. Песочные часы замедляют мир целиком, поэтому
# фон обязан ехать медленнее вместе с предметами — иначе стены «убегают» от
# зависших в воздухе бочек и сцена расползается. Ставит spawner.apply_slow_mo().
var speed_mult : float = 1.0

# ── Раскладка уровней ────────────────────────────────────────────────────────
# Первый уровень на плитке, остальные на полосах. Полос в раскладке четыре, а
# уровней на них два: полосы 2 и 3 — один и тот же путь по улице, 4 и 5 — один и
# тот же двор перед клубом, поэтому уровень держит СПИСОК полос и идёт по ним
# подряд.
#
# Полоса 1 (нарезка level1/) в раскладке больше не участвует: её место занял
# исходный тайловый фон. Файлы оставлены на диске — рисунок никуда не делся, и
# вернуть его в раскладку стоит одной строки.
#
# Куски НЕ ПРЕДЗАГРУЖАЮТСЯ. Сто двадцать две текстуры 645×430 — это под сто
# тридцать мегабайт видеопамяти, и держать их все ради трёх, которые сейчас на экране,
# нельзя. Кусок грузится тогда, когда до него дошла очередь: при 68 px/с это
# одна загрузка в девять секунд, а файл весит шестьдесят килобайт.
const TILE_LEVEL   : int = 1
const STRIP_SLICES : Dictionary = { 2: 31, 3: 41, 4: 40, 5: 10 }
const LEVEL_STRIPS : Dictionary = { 2: [2, 3], 3: [4, 5] }
const LEVEL_COUNT  : int = 3

const SLICE_W : float = 645.0
const SLICE_H : float = 430.0

var _level : int = TILE_LEVEL

# ── Плитка ───────────────────────────────────────────────────────────────────
# Кадр плитки и кадр арки меню — ОДНОГО размера 344×192: арка меню и есть плитка
# из этого же набора, только не повторяющаяся. Поэтому масштаб, ширина и шаг у
# них общие, и никаких «почти одинаковых» констант рядом друг с другом.
const TILE_SRC_W : float = 344.0
const TILE_SRC_H : float = 192.0
const TILE_SCALE : float = SLICE_H / TILE_SRC_H
const TILE_W     : float = TILE_SRC_W * TILE_SCALE
# Плитка масштабируется на дробное число (~2.24), из-за чего соседние куски
# садятся на полпикселя и на шве проступает щель — а сквозь неё просвечивает
# слой города. Небольшой нахлёст её закрывает.
const TILE_SEAM_OVERLAP : float = 2.0
const TILE_STEP  : float = TILE_W - TILE_SEAM_OVERLAP

const TEX_LOOP  := preload("res://assets/backgrounds/bg_loop.png")
const TEX_LOOP4 := preload("res://assets/backgrounds/bg_loop4.png")
# Варианты «с проёмом» — в кладке прозрачные окна, за ними каменный пол. Когда
# такая плитка активна, сквозь неё виден город-параллакс, часть декора (трубы,
# бегущие крысы) подавляется, а крысам с сыром и фонарям сужается диапазон X,
# чтобы они не залезли на камни и в окна.
const TEX_LOOP3 := preload("res://assets/backgrounds/bg_loop3.png")
const TEX_LOOP5 := preload("res://assets/backgrounds/bg_loop5.png")

# Шанс на переработку плитки, что новая окажется вариантом с проёмом.
# 0.16 ≈ одна такая плитка на пять экранов прокрутки.
const HOLE_TILE_CHANCE : float = 0.16

# ── Город за проёмами ────────────────────────────────────────────────────────
const CITY_TEX := preload("res://assets/backgrounds/city_layer.png")
# Доля от скорости стены, а не абсолютная величина. В старом проекте тут стояло
# 30 при стене 100 — то есть треть. Стена теперь едет 68, и сохранять надо
# ОТНОШЕНИЕ: параллакс — это разница скоростей, а не число.
const CITY_SPEED_FRAC   : float = 0.30
const CITY_Y_OFFSET     : float = -50.0
const CITY_SCALE_FACTOR : float = 1.0
# Начальный сдвиг обоих кусков города в долях ширины куска. Отрицательный —
# влево: в кадр попадает больше правой части панорамы.
const CITY_X_OFFSET_FRAC : float = -0.30

# ── Лампы под потолком ───────────────────────────────────────────────────────
const BG_LAMP_SCRIPT          := preload("res://scripts/bg_lamp.gd")
const LAMP_FRAME_PX           : float = 48.0
const LAMP_SCALE              : float = 1.5
const LAMP_DISPLAY_W          : float = LAMP_FRAME_PX * LAMP_SCALE
const LAMP_MIN_SPACING        : float = LAMP_DISPLAY_W * 3.0
const LAMP_SPAWN_INTERVAL_MIN : float = 3.5
const LAMP_SPAWN_INTERVAL_MAX : float = 7.5
const LAMP_TOP_OFFSET         : float = 0.0   # 0 = верх спрайта вровень с верхом экрана

# ── Трубы из стены ───────────────────────────────────────────────────────────
const BG_PIPE_SCRIPT    := preload("res://scripts/bg_pipe.gd")
const PIPE_FRAME_PX     : float = 48.0
const PIPE_SCALE        : float = 1.5
const PIPE_DISPLAY_W    : float = PIPE_FRAME_PX * PIPE_SCALE
const PIPE_MOUSE_CHANCE : float = 0.20
# Остальные 80 % делятся поровну между короткой и толстой петлёй.

# Плитка ≈ 0.8 экрана, поэтому 0.30 ≈ одна труба на три экрана прокрутки.
const PIPE_PER_TILE_CHANCE : float = 0.30

# Точки (X, Y) центра ОТВЕРСТИЯ трубы в ИСХОДНЫХ пикселях соответствующей
# плитки (344 × 192). Каждая — место на стене, где трубе позволено выходить,
# как правило тёмный шов кладки. Несколько точек на вариант дают разброс.
const LOOP_PIPE_ANCHORS : Dictionary = {
	"loop":  [
		Vector2(27.0, 116.0),
		Vector2(161.0, 136.0),
		Vector2(330.0, 22.0),
		Vector2(268.0, 123.0),
	],
	"loop4": [
		Vector2(26.0, 115.0),
		Vector2(241.0, 50.0),
		Vector2(157.0, 134.0),
	],
	# Варианты с проёмом — без труб по замыслу.
	"loop3": [],
	"loop5": [],
}
const PIPE_OPENING_OFFSET_Y : float = 0.0

# ── Настенные фонари ─────────────────────────────────────────────────────────
const BG_LAMP2_SCRIPT         := preload("res://scripts/bg_lamp2.gd")
const LAMP2_FRAME_PX          : float = 48.0
const LAMP2_SCALE             : float = 1.5
const LAMP2_DISPLAY_W         : float = LAMP2_FRAME_PX * LAMP2_SCALE
const LAMP2_SPAWN_CHANCE      : float = 0.35
const LAMP2_ATTEMPTS_PER_TILE : int   = 1
# Диапазон Y в исходных пикселях — фонари держатся выше полосы пола.
const LAMP2_Y_MIN_SOURCE      : float = 20.0
const LAMP2_Y_MAX_SOURCE      : float = 125.0
const LAMP2_X_MARGIN_SOURCE   : float = 24.0
const LAMP2_MIN_DIST_TO_OTHER : float = LAMP2_DISPLAY_W * 1.6

# ── Крысы с сыром ────────────────────────────────────────────────────────────
const BG_RAT_SCRIPT       := preload("res://scripts/bg_rat.gd")
const RAT_FRAME_PX        : float = 48.0
const RAT_SCALE           : float = 1.5
const RAT_DISPLAY_W       : float = RAT_FRAME_PX * RAT_SCALE
const RAT_PER_TILE_CHANCE : float = 0.13
const RAT_X_MIN_SOURCE    : float = 4.0
const RAT_X_MAX_SOURCE    : float = 334.0
const RAT_Y_MIN_SOURCE    : float = 162.0
const RAT_Y_MAX_SOURCE    : float = 162.0

# ── Пробегающие крысы ────────────────────────────────────────────────────────
const BG_RAT_RUN_SCRIPT    := preload("res://scripts/bg_rat_run.gd")
const RAT_RUN_FRAME_PX     : float = 48.0
const RAT_RUN_SCALE        : float = 1.5
const RAT_RUN_DISPLAY_W    : float = RAT_RUN_FRAME_PX * RAT_RUN_SCALE
const RAT_RUN_INTERVAL_MIN : float = 10.0
const RAT_RUN_INTERVAL_MAX : float = 22.0

# ── Меню ─────────────────────────────────────────────────────────────────────
# Арка с «БАРом», под которую поставлены настоящие диван и телевизор. Уезжает
# один раз и не возвращается — дальше идёт только фон уровня.
const TEX_INTRO2 := preload("res://assets/backgrounds/bg_intro2.png")

# ── Затемнение ───────────────────────────────────────────────────────────────
# Нарисованные полосы яркие и подробные — это их достоинство и их же проблема:
# летящая пицца на фоне красного кирпича с граффити читается хуже, чем на глухой
# стене. Плёнка гасит фон, не трогая предметы.
#
# На ПЛИТКЕ её нет, и это не забывчивость. Плитка тёмная и почти без деталей —
# на ней предметы читаются и так, а плёнка поверх съела бы единственное, что там
# есть: свет ламп и окна города. Проверять надо кадром, а не рассуждением, —
# `dev/shot_bg.gd 1` и `dev/shot_bg.gd 2` стоят рядом ровно для этого.
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
var _ready_done : bool = false

# Весь процедурный декор живёт в ОТДЕЛЬНОМ узле, а не прямо в фоне. Иначе
# спрайты декора добавлялись бы после плёнки затемнения и рисовались поверх неё
# — а на переходе уровня плёнку пришлось бы каждый раз переставлять в конец.
var _decor : Node2D = null

var _lamps           : Array[Sprite2D] = []
var _next_lamp_spawn : float           = 0.0
var _pipes           : Array[Sprite2D] = []
var _lamps2          : Array[Sprite2D] = []
var _rats            : Array[Sprite2D] = []
var _rats_run        : Array[Sprite2D] = []
var _next_rat_run    : float           = 0.0

var _city_a : Sprite2D = null
var _city_b : Sprite2D = null
var _city_w : float    = 0.0

func start_scrolling() -> void:
	_scrolling = true

func stop_scrolling() -> void:
	_scrolling = false

func level() -> int:
	return _level

func tile_mode() -> bool:
	return _level == TILE_LEVEL

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
		s.scale          = Vector2.ONE * TILE_SCALE
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_bg_intro.position  = Vector2(0.0, 0.0)
	_bg_intro2.position = Vector2(TILE_STEP, 0.0)

	_tiles = [_bg_a, _bg_b, _bg_c]
	for t: Sprite2D in _tiles:
		t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	_decor = Node2D.new()
	_decor.name = "Decor"
	add_child(_decor)

	_build_dim()
	# ПОСЛЕДНИМ ребёнком, и это не вкусовщина: слой забирает всё, что нарисовано
	# до него, — значит фон целиком и ничего сверх.
	_build_trip()

	# Игра открывается в меню, а за меню стоит первый уровень: плитка.
	# Куски встают ЗА двумя кусками арки, а не с нуля, — иначе первая же стена
	# перекрыла бы меню.
	_enter_tile_mode(TILE_STEP * 2.0)
	_ready_done = true

# ── Смена уровня ─────────────────────────────────────────────────────────────
# Фон подменяется ЦЕЛИКОМ и сразу. Плавно перетечь из одного помещения в другое
# нельзя — не сходится ни кладка, ни линия пола, а между плиткой и полосой не
# сходится даже способ рисовать. Поэтому переход прячется: уровень меняют в тот
# момент, когда экран накрыт карточкой уровня (см. hud).
#
# Уровень, который уже идёт, НЕ ПЕРЕСОБИРАЕТСЯ. Начало забега зовёт set_level с
# номером первого уровня эпизода, и для эпизода 1 и бесконечного это тот самый
# уровень, что стоит за меню, — а занавеса в этих двух случаях нет
# (`hud._needs_curtain`: он только со второго эпизода). Пересборка на глазах у
# зрителя срубила бы стену в исходную точку прямо поверх ещё не уехавшей арки
# меню. Плитке и полосе одинаково всё равно, на каком месте цикла их застали,
# так что не делать ничего — не оговорка, а верный ответ.
func set_level(n: int) -> void:
	var want : int = clampi(n, 1, LEVEL_COUNT)
	if want == _level and _ready_done:
		return
	_level = want
	if tile_mode():
		_enter_tile_mode(0.0)
	else:
		_enter_strip_mode()

func _enter_tile_mode(x0: float) -> void:
	_clear_decor()
	_dim.visible = false
	for i in _tiles.size():
		var t : Sprite2D = _tiles[i]
		t.scale    = Vector2.ONE * TILE_SCALE
		t.position = Vector2(x0 + TILE_STEP * float(i), 0.0)
		t.texture  = _rand_loop_tex()

	_next_lamp_spawn = randf_range(LAMP_SPAWN_INTERVAL_MIN, LAMP_SPAWN_INTERVAL_MAX)
	_next_rat_run    = randf_range(RAT_RUN_INTERVAL_MIN, RAT_RUN_INTERVAL_MAX)
	_setup_city_layer()

	# Плитки, уже стоящие в кадре, тоже могут нести трубу, фонарь или крысу —
	# иначе первые три экрана уровня были бы демонстративно пустыми.
	for t: Sprite2D in _tiles:
		_maybe_spawn_pipe_for_tile(t)
		_maybe_spawn_lamp2_for_tile(t)
		_maybe_spawn_rat_for_tile(t)

func _enter_strip_mode() -> void:
	_clear_decor()
	_dim.visible = true
	_next_idx = 0
	for i in _tiles.size():
		var t : Sprite2D = _tiles[i]
		t.scale    = Vector2.ONE          # 430 в 430, без растяжения
		t.position = Vector2(SLICE_W * float(i), 0.0)
		t.texture  = _take_next_slice()

# Уходя с первого уровня, декор надо СНЯТЬ, а не оставить доезжать: на полосе он
# спорил бы с рисунком, где всё это уже нарисовано, а крыса из канализации,
# бегущая по улице, читается как ошибка.
func _clear_decor() -> void:
	for arr: Array in [_lamps, _pipes, _lamps2, _rats, _rats_run]:
		for n in arr:
			if is_instance_valid(n):
				n.queue_free()
		arr.clear()
	for c in [_city_a, _city_b]:
		if is_instance_valid(c):
			c.queue_free()
	_city_a = null
	_city_b = null

func _process(delta: float) -> void:
	if tile_mode():
		# Пробегающие крысы тикают и в меню, до старта прокрутки: пустая комната
		# без единого движения читается как замерший экран.
		_update_rats_run(delta)
	if not _scrolling:
		return
	var shift := SCROLL_SPEED * speed_mult * delta

	# Меню уезжает и больше не возвращается — дальше идёт только фон уровня.
	for s: Sprite2D in [_bg_intro, _bg_intro2]:
		if s == null or not s.visible:
			continue
		s.position.x -= shift
		if s.position.x <= -TILE_W:
			s.visible = false

	if tile_mode():
		_scroll_tiles(delta, shift)
	else:
		_scroll_strip(shift)

# ── Уровень 1: плитка ────────────────────────────────────────────────────────

func _scroll_tiles(delta: float, shift: float) -> void:
	for t: Sprite2D in _tiles:
		t.position.x -= shift

	for t: Sprite2D in _tiles:
		if t.position.x <= -TILE_W:
			var rightmost : float = t.position.x
			for o: Sprite2D in _tiles:
				rightmost = maxf(rightmost, o.position.x)
			# Шаг TILE_STEP (= ширина минус нахлёст), чтобы новая плитка слегка
			# наезжала на соседа слева и прятала шов.
			t.position.x = rightmost + TILE_STEP
			t.texture    = _rand_loop_tex()
			_maybe_spawn_pipe_for_tile(t)
			_maybe_spawn_lamp2_for_tile(t)
			_maybe_spawn_rat_for_tile(t)

	_update_city(delta)
	_update_lamps(delta, shift)
	_update_pipes(shift)
	_update_lamps2(shift)
	_update_rats(shift)

func _rand_loop_tex() -> Texture2D:
	if randf() < HOLE_TILE_CHANCE:
		return TEX_LOOP3 if randf() < 0.5 else TEX_LOOP5
	return TEX_LOOP if randf() < 0.5 else TEX_LOOP4

func _variant_key_for(tile: Sprite2D) -> String:
	if tile.texture == TEX_LOOP:  return "loop"
	if tile.texture == TEX_LOOP4: return "loop4"
	if tile.texture == TEX_LOOP3: return "loop3"
	if tile.texture == TEX_LOOP5: return "loop5"
	return "loop"

func _is_hole_variant(key: String) -> bool:
	return key == "loop3" or key == "loop5"

# ── Лампы ────────────────────────────────────────────────────────────────────

func _update_lamps(delta: float, shift: float) -> void:
	var stale : Array = []
	for lamp in _lamps:
		lamp.position.x -= shift
		if lamp.position.x < -LAMP_DISPLAY_W:
			stale.append(lamp)
	for lamp in stale:
		_lamps.erase(lamp)
		lamp.queue_free()

	_next_lamp_spawn -= delta
	if _next_lamp_spawn <= 0.0:
		_try_spawn_lamp()
		_next_lamp_spawn = randf_range(LAMP_SPAWN_INTERVAL_MIN, LAMP_SPAWN_INTERVAL_MAX)

func _try_spawn_lamp() -> void:
	var vp_w := get_viewport_rect().size.x
	var spawn_x := vp_w + LAMP_DISPLAY_W * 0.5
	var rightmost := -INF
	for lamp in _lamps:
		rightmost = maxf(rightmost, lamp.position.x)
	# Три ширины между соседними лампами: иначе они сбиваются в гирлянду.
	if rightmost != -INF and spawn_x - rightmost < LAMP_MIN_SPACING:
		return
	var lamp := Sprite2D.new()
	lamp.set_script(BG_LAMP_SCRIPT)
	lamp.scale = Vector2.ONE * LAMP_SCALE
	# Точка привязки лампы — верх спрайта (место крепления цепи), поэтому её и
	# ставим на LAMP_TOP_OFFSET: тело лампы висит ниже.
	lamp.position = Vector2(spawn_x, LAMP_TOP_OFFSET)
	_decor.add_child(lamp)
	_lamps.append(lamp)

# ── Трубы ────────────────────────────────────────────────────────────────────

func _update_pipes(shift: float) -> void:
	var stale : Array = []
	for pipe in _pipes:
		pipe.position.x -= shift
		# Труба с мышью выше остальных — запас на уход за левый край больше.
		if pipe.position.x < -PIPE_DISPLAY_W * 2.0:
			stale.append(pipe)
	for pipe in stale:
		_pipes.erase(pipe)
		pipe.queue_free()

func _maybe_spawn_pipe_for_tile(tile: Sprite2D) -> void:
	if randf() >= PIPE_PER_TILE_CHANCE:
		return
	var anchors : Array = LOOP_PIPE_ANCHORS.get(_variant_key_for(tile), [])
	if anchors.is_empty():
		return

	# 20 % мышь, 40 % короткая, 40 % толстая петля.
	var r := randf()
	var kind : int
	if r < PIPE_MOUSE_CHANCE:
		kind = 2  # BgPipe.Kind.FAT_MOUSE
	elif r < PIPE_MOUSE_CHANCE + (1.0 - PIPE_MOUSE_CHANCE) * 0.5:
		kind = 0  # BgPipe.Kind.SHORT
	else:
		kind = 1  # BgPipe.Kind.FAT_LOOP

	# Своя точка привязки трубы — ЛЕВЫЙ ЦЕНТР её спрайта, поэтому отверстие в
	# стене совмещается с ней напрямую.
	var anchor : Vector2 = anchors[randi() % anchors.size()]
	var pipe := Sprite2D.new()
	pipe.set_script(BG_PIPE_SCRIPT)
	pipe.scale = Vector2.ONE * PIPE_SCALE
	pipe.position = Vector2(
		tile.position.x + anchor.x * TILE_SCALE,
		anchor.y * TILE_SCALE + PIPE_OPENING_OFFSET_Y,
	)
	# setup() ОБЯЗАН быть вызван до add_child: _ready трубы читает вид из него.
	pipe.call("setup", kind)
	_decor.add_child(pipe)
	_pipes.append(pipe)

# ── Настенные фонари ─────────────────────────────────────────────────────────

func _update_lamps2(shift: float) -> void:
	var stale : Array = []
	for l2 in _lamps2:
		l2.position.x -= shift
		if l2.position.x < -LAMP2_DISPLAY_W * 1.5:
			stale.append(l2)
	for l2 in stale:
		_lamps2.erase(l2)
		l2.queue_free()

func _maybe_spawn_lamp2_for_tile(tile: Sprite2D) -> void:
	var variant := _variant_key_for(tile)
	# У плиток с проёмом часть стены — окно; фонари держатся на кирпичной части.
	var x_min : float = LAMP2_X_MARGIN_SOURCE
	var x_max : float = TILE_SRC_W - LAMP2_X_MARGIN_SOURCE
	if variant == "loop3":
		x_max = 150.0
	elif variant == "loop5":
		x_min = 241.0
	for _i in LAMP2_ATTEMPTS_PER_TILE:
		if randf() >= LAMP2_SPAWN_CHANCE:
			continue
		var pos := Vector2(
			tile.position.x + randf_range(x_min, x_max) * TILE_SCALE,
			randf_range(LAMP2_Y_MIN_SOURCE, LAMP2_Y_MAX_SOURCE) * TILE_SCALE,
		)
		if not _lamp2_pos_clear(pos):
			continue
		var l2 := Sprite2D.new()
		l2.set_script(BG_LAMP2_SCRIPT)
		l2.scale    = Vector2.ONE * LAMP2_SCALE
		l2.position = pos
		_decor.add_child(l2)
		_lamps2.append(l2)

# Пусто ли место: рядом не должно оказаться ни лампы, ни трубы, ни другого
# фонаря — иначе декор слипается в кучу и стена читается как свалка.
func _lamp2_pos_clear(pos: Vector2) -> bool:
	for arr: Array in [_lamps, _pipes, _lamps2]:
		for n in arr:
			if pos.distance_to((n as Node2D).position) < LAMP2_MIN_DIST_TO_OTHER:
				return false
	return true

# ── Крысы с сыром ────────────────────────────────────────────────────────────

func _update_rats(shift: float) -> void:
	var stale : Array = []
	for rat in _rats:
		rat.position.x -= shift
		if rat.position.x < -RAT_DISPLAY_W * 1.5:
			stale.append(rat)
	for rat in stale:
		_rats.erase(rat)
		rat.queue_free()

func _maybe_spawn_rat_for_tile(tile: Sprite2D) -> void:
	if randf() >= RAT_PER_TILE_CHANCE:
		return
	var source_x : float
	var source_y : float
	match _variant_key_for(tile):
		"loop3":
			source_y = 163.0
			source_x = randf_range(10.0, 96.0)
		"loop5":
			source_y = 163.0
			# Две годные полосы X по обе стороны от пролома в полу.
			source_x = randf_range(14.0, 82.0) if randf() < 0.5 else randf_range(222.0, 326.0)
		_:
			source_y = randf_range(RAT_Y_MIN_SOURCE, RAT_Y_MAX_SOURCE)
			source_x = randf_range(RAT_X_MIN_SOURCE, RAT_X_MAX_SOURCE)
	var rat := Sprite2D.new()
	rat.set_script(BG_RAT_SCRIPT)
	rat.scale    = Vector2.ONE * RAT_SCALE
	rat.position = Vector2(tile.position.x + source_x * TILE_SCALE, source_y * TILE_SCALE)
	_decor.add_child(rat)
	_rats.append(rat)

# ── Пробегающие крысы ────────────────────────────────────────────────────────

func _update_rats_run(delta: float) -> void:
	var stale : Array = []
	for r in _rats_run:
		if r.position.x < -RAT_RUN_DISPLAY_W * 1.5:
			stale.append(r)
	for r in stale:
		_rats_run.erase(r)
		r.queue_free()

	_next_rat_run -= delta
	if _next_rat_run <= 0.0:
		_spawn_rat_run()
		_next_rat_run = randf_range(RAT_RUN_INTERVAL_MIN, RAT_RUN_INTERVAL_MAX)

func _spawn_rat_run() -> void:
	var vp_w := get_viewport_rect().size.x
	var spawn_x : float = vp_w + RAT_RUN_DISPLAY_W * 0.5
	# Если плитка, входящая в кадр здесь, — с каменным полом, крысе некуда бежать.
	for tile in _tiles:
		if tile.position.x <= spawn_x and spawn_x < tile.position.x + TILE_W:
			if _is_hole_variant(_variant_key_for(tile)):
				return
			break
	# Размер на каждую пробежку свой: 100 %, 80 % или 60 % от базового.
	const SIZE_FACTORS : Array[float] = [1.0, 0.8, 0.6]
	var f : float = SIZE_FACTORS[randi() % SIZE_FACTORS.size()]
	var final_scale : float = RAT_RUN_SCALE * f
	var source_y : float = randf_range(RAT_Y_MIN_SOURCE, RAT_Y_MAX_SOURCE)
	# Спрайт центрирован, поэтому низ крысы полного размера сидит на
	# source_y*scale + половина кадра. Этот НИЗ и держим неизменным на всех
	# размерах — иначе мелкие крысы висят над полом.
	var bottom_y : float = source_y * TILE_SCALE + RAT_RUN_FRAME_PX * 0.5 * RAT_RUN_SCALE
	var rat := Sprite2D.new()
	rat.set_script(BG_RAT_RUN_SCRIPT)
	rat.scale    = Vector2.ONE * final_scale
	rat.position = Vector2(spawn_x, bottom_y - RAT_RUN_FRAME_PX * 0.5 * final_scale)
	_decor.add_child(rat)
	_rats_run.append(rat)

# ── Город за проёмами ────────────────────────────────────────────────────────

func _setup_city_layer() -> void:
	_city_w = CITY_TEX.get_width() * TILE_SCALE * CITY_SCALE_FACTOR
	var x0 : float = _city_w * CITY_X_OFFSET_FRAC
	_city_a = _make_city_tile(x0)
	_city_b = _make_city_tile(x0 + _city_w)

func _make_city_tile(x: float) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture        = CITY_TEX
	s.scale          = Vector2.ONE * TILE_SCALE * CITY_SCALE_FACTOR
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.centered       = false
	# Город обязан быть ПОЗАДИ стены, а лежит он в том же узле декора, что и
	# лампы с крысами. Порядок в дереве тут не поможет — решает z_index.
	s.z_index        = -1
	s.position       = Vector2(x, CITY_Y_OFFSET)
	_decor.add_child(s)
	return s

func _update_city(delta: float) -> void:
	if _city_a == null or _city_b == null:
		return
	var shift := SCROLL_SPEED * CITY_SPEED_FRAC * speed_mult * delta
	_city_a.position.x -= shift
	_city_b.position.x -= shift
	if _city_a.position.x <= -_city_w:
		_city_a.position.x = _city_b.position.x + _city_w
	if _city_b.position.x <= -_city_w:
		_city_b.position.x = _city_a.position.x + _city_w

# ── Уровни 2 и 3: нарисованные полосы ────────────────────────────────────────

func _scroll_strip(shift: float) -> void:
	for t: Sprite2D in _tiles:
		t.position.x -= shift

	for t: Sprite2D in _tiles:
		if t.position.x <= -SLICE_W:
			var rightmost : float = t.position.x
			for o: Sprite2D in _tiles:
				rightmost = maxf(rightmost, o.position.x)
			t.position.x = rightmost + SLICE_W
			t.texture    = _take_next_slice()

# ── Порядок кусков: ПО КРУГУ ─────────────────────────────────────────────────
# Куски идут 1 → 2 → … → N → 1 → 2 → …, и порядок обязателен: это одна
# непрерывная картина, у соседей сходятся кладка, линия пола и рисунок.
#
# Замер стыков (разница крайних столбцов, 0…255): по кругу — в среднем 3.6–6.3
# на всех полосах, худший соседский 41. Один плохой стык на круг есть, и это
# замыкание N → 1: полоса не нарисована зацикленной, её хвост короче куска и при
# нарезке отбрасывается. Разрыв на замыкании 29–87 в зависимости от уровня.
#
# Пробовали ПИНГ-ПОНГ — доходить до конца и отматываться назад, чтобы плохого
# замыкания не было вовсе. Это оказалось хуже, и сильно: при движении назад
# соседями становятся ПРАВЫЙ край куска i и ЛЕВЫЙ край куска i−1, а сходятся у
# них другие края. То есть ломается не один стык на круг, а КАЖДЫЙ стык на всём
# обратном ходе — в среднем 29–58 против 3.6–6.3.
#
# Починить пинг-понг зеркалом кусков нельзя: на стене нарисованы EXIT, NORMALDO
# и граффити, и зеркальная стена читается как ошибка сильнее любого стыка.
#
# Куски уровня — это куски ВСЕХ его полос подряд. `_next_idx` считает по этой
# общей ленте, а не по одной полосе: иначе уровень из двух полос крутил бы
# первую и никогда не доходил до второй.
func _level_slice_count() -> int:
	var total := 0
	for strip in _strips():
		total += int(STRIP_SLICES.get(int(strip), 0))
	return maxi(1, total)

func _strips() -> Array:
	return LEVEL_STRIPS.get(_level, LEVEL_STRIPS[2]) as Array

func _take_next_slice() -> Texture2D:
	var n : int = _level_slice_count()
	var idx : int = _next_idx
	var strips : Array = _strips()
	var strip : int = int(strips[0])
	for st in strips:
		var cnt : int = int(STRIP_SLICES.get(int(st), 0))
		if idx < cnt:
			strip = int(st)
			break
		idx -= cnt
	var tex : Texture2D = load("res://assets/backgrounds/level%d/level%d_%02d.png"
		% [strip, strip, idx + 1])
	if n > 1:
		_next_idx = (_next_idx + 1) % n
	return tex

# ── Плёнка затемнения ────────────────────────────────────────────────────────
# Добавляется ПОСЛЕДНИМ ребёнком Background: так она рисуется поверх фона и
# декора и под всем остальным — диван, телевизор, предметы и Нормальдо лежат в
# сцене дальше и её не задевают.
# ── Порча фона: инверсия цвета и зеркало ─────────────────────────────────────
# Гриб выворачивает цвета, компас отражает картинку по горизонтали. Оба эффекта
# ЭКРАННЫЕ: слой берёт уже нарисованный фон и переписывает его перед тем, как
# сверху лягут предметы (см. shaders/bg_trip.gdshader).
#
# Не трансформацией узлов: Background ездит на тюинах при переходах между
# экранами меню, и вторая рука, пишущая в его `position`, дралась бы с первой.
# А инверсию цвета трансформацией не сделать вовсе.
const TRIP_SHADER := preload("res://shaders/bg_trip.gdshader")

var _trip_bbc  : BackBufferCopy = null
var _trip_rect : ColorRect      = null
var _trip_mat  : ShaderMaterial = null

func _build_trip() -> void:
	var vp := get_viewport_rect().size
	# Копия кадра — то, из чего слой и берёт картинку. Без неё шейдеру нечего
	# читать: `hint_screen_texture` отдаёт именно этот снимок.
	_trip_bbc = BackBufferCopy.new()
	_trip_bbc.name      = "TripCopy"
	_trip_bbc.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	_trip_bbc.visible   = false
	add_child(_trip_bbc)

	_trip_mat = ShaderMaterial.new()
	_trip_mat.shader = TRIP_SHADER
	_trip_mat.set_shader_parameter("invert", 0.0)
	_trip_mat.set_shader_parameter("mirror", 0.0)

	# Тот же запас в три экрана и сдвиг, что у плёнки: фон ездит целиком, и слой
	# ровно в экран уехал бы вместе с ним, оставив у края неиспорченную полосу.
	_trip_rect = ColorRect.new()
	_trip_rect.name         = "Trip"
	_trip_rect.material     = _trip_mat
	_trip_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_trip_rect.size         = vp * 3.0
	_trip_rect.position     = -vp
	_trip_rect.visible      = false
	add_child(_trip_rect)

# Инверсия цвета — гриб.
func set_inverted(on: bool) -> void:
	_set_trip("invert", on)

# Зеркало по горизонтали — компас. Зеркалит ТОЛЬКО картинку: предметы
# разворачивает `ItemFlow`, они и правда летят в другую сторону.
func set_mirrored(on: bool) -> void:
	_set_trip("mirror", on)

func trip_on(key: String) -> bool:
	if _trip_mat == null:
		return false
	return float(_trip_mat.get_shader_parameter(key)) > 0.5

func _set_trip(key: String, on: bool) -> void:
	if _trip_mat == null:
		return
	_trip_mat.set_shader_parameter(key, 1.0 if on else 0.0)
	# Слой поднимается, только когда работает хоть один эффект: копия кадра
	# каждый кадр — не та цена, которую платят просто так.
	var any := trip_on("invert") or trip_on("mirror")
	if is_instance_valid(_trip_bbc):
		_trip_bbc.visible = any
	if is_instance_valid(_trip_rect):
		_trip_rect.visible = any

func _build_dim() -> void:
	var vp := get_viewport_rect().size
	_dim = ColorRect.new()
	_dim.name         = "Dim"
	_dim.color        = DIM_COLOR
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# С запасом в три экрана и со сдвигом на экран влево. Background целиком
	# ездит на тюинах при переходах между экранами меню (см. hud
	# `_SCENE_PAN_NODES`), и плёнка размером ровно в экран уехала бы вместе с
	# ним, оставив у края полосу неприкрытого фона.
	_dim.size     = vp * 3.0
	_dim.position = -vp
	add_child(_dim)
