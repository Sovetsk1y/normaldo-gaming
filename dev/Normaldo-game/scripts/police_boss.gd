extends Node2D

# ── Босс: КАПИТАН ПОЛИЦИИ ────────────────────────────────────────────────────
# Четвёртый босс игры — конец эпизода ДВОР. Он единственный, кто НЕ ДЕРЁТСЯ САМ:
# капитан стоит у правого края с рацией и ВЫЗЫВАЕТ. Собаку, отряд, вертолёт.
#
# Из этого и растёт вся битва. Крокодил спрашивает «успей сойти с линии», пират
# — «успей ударить первым»; капитан спрашивает «сколько ты выдержишь, пока их
# становится больше». Он не наносит ни одного удара лично, и в этом шутка: самый
# опасный тут — тот, кто просто говорит в рацию.
#
# ── ТРИ АКТА, И КАЖДЫЙ КОНЧАЕТСЯ ДО НАЧАЛА СЛЕДУЮЩЕГО ──────────────────────
#
#   Акт 1 «СОБАКИ»   — «читай геометрию». Три волны: одна собака, потом две,
#                      потом три. Первая ОХОТИТСЯ — доворачивает на Нормальдо
#                      после каждого отскока; стая просто носится по случайным
#                      углам. Волна кончается, когда все отбегали своё.
#   Акт 2 «ОТРЯД»    — «отдай полосу». Вертолёт проходит над кадром и роняет
#                      СВАТ: щит, ствол, граната. Акт идёт до последнего бойца.
#   Акт 3 «ШТУРМОВКА»— «полосы кончаются». Сначала отряд, и СРАЗУ ЗА НИМ
#                      вертолёт: подходит к верхнему краю, наводит турель на
#                      начало полосы, держит паузу и ведёт очередь справа
#                      налево, доворачивая ствол за ней. Три захода, и больше
#                      ДВУХ горящих полос одновременно не бывает.
#
# Нарастание тут не в числах, а в ВОПРОСАХ: геометрия → площадь → площадь под
# огнём. Акт, который просто добавлял бы врагов, читался бы как «то же самое, но
# гуще» — ровно этим и был четвёртый акт, которого больше нет.
#
# ── И КАЖДЫЙ АКТ УБИРАЕТ ЗА СОБОЙ ──────────────────────────────────────────
# Волна собак ждёт своих собак, отряд — своих бойцов. Это не аккуратность, а то,
# что делает бой проходимым: пока акты кончались по таймеру, следующий ложился
# поверх недобитого предыдущего, и к третьему заходу на арене стояла шеренга при
# двух горящих полосах.
#
# ── ФИНАЛ ──────────────────────────────────────────────────────────────────
# Вертолёт спускает трос, капитан хватается и уезжает — а на голову ему падает
# пицца. Он не побеждён в драке (драки и не было), он ОТСТУПАЕТ, и пицца
# догоняет его уже в воздухе.
#
# См. /Концепция/Босс — Капитан полиции.md

signal defeated

const SCREEN_SHAKE := preload("res://scripts/screen_shake.gd")
const BOSS_SPEECH  := preload("res://scripts/boss_speech.gd")
const HELI_SCRIPT  := preload("res://scripts/police_heli.gd")
const SWAT_SCRIPT  := preload("res://scripts/police_swat.gd")
const DOG_SCRIPT   := preload("res://scripts/police_dog.gd")
const FIRE_SCENE   := preload("res://scenes/fire.tscn")

const COP_TEX    := preload("res://assets/bosses/police/cop.png")
const RADIO_TEX  := preload("res://assets/bosses/police/radio.png")
const BANNER_TEX := preload("res://assets/bosses/police/banner.png")
# ── ПИЦЦА НА ЛИЦО — ДРУГАЯ, НЕ ТА, ЧТО ЛЕТАЕТ В ПОТОКЕ ─────────────────────
# Здесь стояла обычная пицца из потока, и знак читался неверно: «в капитана
# прилетел предмет». Победная пицца нарисована отдельно и РАЗМАЗАННОЙ — она
# садится боссу на морду, а не падает ему на голову.
#
# Рисунок общий с крокодилом и пиратом, и это принципиально: «босс кончился —
# сверху пицца» уже выучено игроком на двух боссах, и свой знак для третьего
# означал бы, что учить надо заново.
const PIZZA_TEX  := preload("res://assets/bosses/leatherhead/pizza_face.png")
const UI_FONT    := preload("res://assets/fonts/RussoOne-Regular.ttf")

const BOSS_STINGER := preload("res://assets/audio/boss_fight.mp3")
const BOSS_MUSIC   := preload("res://assets/audio/hard_track.mp3")
const SFX_PIZZA    := preload("res://assets/audio/super_pizza.mp3")

# ── Размеры ─────────────────────────────────────────────────────────────────
const COP_PX   : float = 150.0
const RADIO_PX : float = 62.0
# Капитан стоит У ПРАВОГО КРАЯ и никуда не двигается: он не боец, он штаб.
# Отступ больше половины головы: ровно половина прижала бы её к самому краю, и
# фуражка срезалась бы рамкой экрана.
const COP_X_PAD : float = 108.0

# ── КУДА САДИТСЯ ПОБЕДНАЯ ПИЦЦА ────────────────────────────────────────────
# НЕ на макушку, а на лицо, и это считано, а не подобрано на глаз. Капитан
# нарисован в кадре 500×500 фигурой 341×312, поднятой над центром кадра на 29
# пикселей; в игре фигура высотой COP_PX*312/341 ≈ 137 и её верх приходится на
# −81 от узла. Фуражка — верхняя треть фигуры, лицо начинается ниже, и центр
# лица ложится чуть НИЖЕ узла, а не выше.
#
# Первым заходом пицца стояла на −0.40 COP_PX и садилась ровно на козырёк:
# получалось «ему на фуражку что-то уронили», а не «ему конец».
const PIZZA_FACE_Y : float = 0.04
# И размером в лицо: пицца, закрывающая пол-лица, читается как прилетевший
# предмет, а не как печать на морде.
const PIZZA_PX_K   : float = 0.72

# Полос пять — те же, что у потока.
const LANES : int = 5

# ── Тайминги актов ──────────────────────────────────────────────────────────
# ── ВОЛНЫ СОБАК: ОДНА, ДВЕ, ТРИ ────────────────────────────────────────────
# Первая волна — одна собака, и она ОХОТИТСЯ: после каждого отскока снова берёт
# курс на Нормальдо. Вопрос от неё — «прочитай, откуда она вернётся».
#
# Вторая и третья — две и три, и они НЕ охотятся, а носятся по случайным углам
# (см. police_dog.hunts). Три доворачивающих на игрока собаки — это не три
# вопроса, а один и тот же, заданный втройне: куда ни уйди, все три уже летят
# туда. Стая заполняет арену, и уходить надо из МЕСТА, а не с линии.
const DOG_WAVES      : int   = 3
# Сколько ждём, пока волна отбегает своё. Потолок по ЧАСАМ и с запасом: волна
# кончается сама, но акт не имеет права зависнуть, если собака где-то залипла.
const DOG_WAVE_MAX_MS : int  = 26000
const SQUAD_SIZE     : int   = 3      # сколько бойцов за один заход вертолёта

# ── ВЫСАДКА ИДЁТ В ДАЛЬНЕЙ ТРЕТИ ЭКРАНА ────────────────────────────────────
# Доли ширины, между которыми прыгают бойцы. Третья треть — это 0.67..1.0, и весь
# отряд обязан уложиться в неё.
#
# Раньше прыжки шли ПО СЕКУНДОМЕРУ: пауза 0.65 после входа вертолёта и дальше по
# 0.55 между бойцами. На бумаге аккуратно, на экране — первый прыгал на x=888,
# второй на 640, третий на 392, то есть последний высаживался за серединой,
# почти у Нормальдо под носом. Реакции на него не оставалось никакой: боец
# приземлялся, разворачивался и уже был рядом.
#
# Теперь прыжок привязан к МЕСТУ, а не ко времени: вертолёт летит, и боец
# отделяется, когда тот проходит свою отметку. Правило «отряд высаживается в
# дальней трети» держится само собой при любой скорости захода — а с
# секундомером его пришлось бы пересчитывать при каждой правке HELI_PASS_T.
const DROP_X_FROM_K  : float = 0.96
const DROP_X_TO_K    : float = 0.70
const HELI_PASS_T    : float = 3.20   # сколько вертолёт идёт через кадр
# Сколько ждём, пока отряд кончится сам. Боец идёт свои 46 px/c от дальней трети
# до левого края примерно семнадцать секунд, спелл убивает его раньше — потолок
# стоит с запасом и только на случай, если кто-то застрял.
const SQUAD_WAIT_MAX_MS : int = 24000

# ── БОЛЬШЕ ДВУХ ГОРЯЩИХ ПОЛОС ОДНОВРЕМЕННО НЕ БЫВАЕТ ───────────────────────
# Полоса горит десять секунд, а заходов три — и они складывались: к третьему на
# поле оставалось две свободные линии из пяти, и это при живом отряде. Формально
# «сжимающееся поле», на деле — стена.
#
# Теперь при третьей полосе САМАЯ СТАРАЯ гасится досрочно. Не «новый заход
# отменяется»: отменённый заход читался бы как осечка вертолёта, а гаснущая
# старая полоса — как «эта уже отгорела», то есть как обычное течение боя.
const MAX_BURNING : int = 2
const STRAFE_RUNS    : int   = 3      # заходов штурмовки
const FIRE_LIVE_T    : float = 10.0   # сколько горит полоса
const FIRE_FADE_T    : float = 1.6    # и сколько гаснет, справа налево
const STRAFE_SWEEP_T : float = 1.30   # очередь идёт справа налево
const AIM_HOLD_T     : float = 0.45   # навёлся на начало полосы и держит
# Откуда и докуда идёт вертолёт за очередь — доли ширины экрана. Он ЛЕТИТ ВДОЛЬ
# ПОЛОСЫ вместе со своей очередью, а не висит на месте: висящий к концу очереди
# целится почти горизонтально назад, и турель на подвесе так не ходит.
const HELI_X_FROM    : float = 0.875
const HELI_X_TO      : float = 0.135
# На какой высоте он висит, ведя очередь. Отсюда же считается, по каким полосам
# он вообще может стрелять (см. STRAFE_LANES), поэтому число — именованное.
const HELI_HOVER_Y   : float = 18.0

# ── ШТУРМУЮТСЯ ТОЛЬКО ТРИ НИЖНИЕ ПОЛОСЫ ────────────────────────────────────
# Турель висит под брюхом, то есть НИЖЕ вертолёта: ось ствола приходится на 150,
# а верхние полосы — на 43 и 129. Стрелять по ним значит стрелять СНИЗУ ВВЕРХ,
# из-под собственного вертолёта.
#
# Пока ствол не поворачивался, этого не было видно — он смотрел в одну сторону
# при любой полосе, и врал одинаково. Стоило навести его честно, и верхние полосы
# сразу показали, что там не так.
#
# Опустить вертолёт нельзя: чтобы оказаться над верхней полосой, он должен уйти
# за кадр целиком вместе с турелью. Поэтому штурмуются нижние три — и обещание
# акта от этого не страдает: заходов ровно три, и игроку остаются те же ДВЕ
# полосы из пяти, что и раньше.
const STRAFE_LANES : Array = [2, 3, 4]
const ACT_GAP        : float = 1.10

# ── ШАГ МЕЖДУ ОГНЯМИ ───────────────────────────────────────────────────────
# Пламя нарисовано шириной 71 пиксель и живёт в масштабе 0.83 — на экране это
# 59 пикселей. Шаг взят ЧУТЬ МЕНЬШЕ ширины: языки должны стоять впритык и
# перекрываться краями, а не висеть отдельными кострами.
#
# Сначала здесь было девять огней на полосу и шаг под 110 — вдвое шире самого
# пламени. Между ними свободно проходил и Нормальдо, и сватовец, и «полоса
# выключена на десять секунд» оказывалась полосой, по которой можно ходить.
# Горящая полоса обязана быть СПЛОШНОЙ, иначе она не отбирает ничего.
#
# Число огней при этом НЕ ЗАДАНО ЧИСЛОМ, а считается из ширины экрана: на другом
# разрешении шаг остался бы тем же, а вот девять костров разъехались бы.
const FIRE_STEP_PX : float = 52.0
const FIRE_X_FROM  : float = 30.0     # отступ справа
const FIRE_X_TO    : float = 40.0     # и слева

const COL_BG     : Color = Color(0.07, 0.10, 0.20, 0.96)
const COL_BORDER : Color = Color(0.45, 0.62, 1.00, 0.95)
const COL_INK    : Color = Color(0.92, 0.96, 1.00)

const SAY_ENTER  : String = "Приём! Пицца уходит на юг.\nВысылайте всех."
const SAY_FINALE : String = "Отбой. Я вас предупреждал."

var _normaldo  : Node2D = null
var _spawner   : Node   = null
var _game_root : Node2D = null
var boss_test_mode : bool = false

var _sprite : Sprite2D = null
var _radio  : Sprite2D = null
var _music  : AudioStreamPlayer = null
var _alive_flag : bool = true

# Что сейчас на арене — чтобы прибрать за собой на выходе.
var _units : Array = []
var _fires : Array = []

func setup(normaldo: Node2D, spawner: Node, game_root: Node2D,
		test_mode: bool = false) -> void:
	_normaldo      = normaldo
	_spawner       = spawner
	_game_root     = game_root
	boss_test_mode = test_mode

func _ready() -> void:
	z_index = 40

	_sprite = Sprite2D.new()
	_sprite.texture        = COP_TEX
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ItemSizing.fit_sprite_content(_sprite, COP_PX)
	add_child(_sprite)

	# Рация в руке — единственное, чем он «атакует», и потому она в кадре
	# всегда, а не только на вызове.
	_radio = Sprite2D.new()
	_radio.texture        = RADIO_TEX
	_radio.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_radio.z_index        = 1
	ItemSizing.fit_sprite_content(_radio, RADIO_PX)
	_radio.position       = Vector2(-COP_PX * 0.42, COP_PX * 0.26)
	add_child(_radio)

	_music = AudioStreamPlayer.new()
	var ms := BOSS_MUSIC.duplicate() as AudioStreamMP3
	ms.loop          = true
	_music.stream    = ms
	_music.volume_db = -14.0
	add_child(_music)

	_run_boss.call_deferred()

# Живы ли мы и есть ли дерево. Каждый акт — корутина, и она переживает и смерть
# игрока, и перезагрузку сцены: проснуться вне дерева значит упасть на
# `get_tree()`.
func _alive() -> bool:
	return _alive_flag and is_instance_valid(self) and is_inside_tree() \
		and is_instance_valid(_game_root)

func lane_y(i: int) -> float:
	var vp := get_viewport_rect().size
	return vp.y / float(LANES) * (float(clampi(i, 0, LANES - 1)) + 0.5)

# ── Главная последовательность ──────────────────────────────────────────────

func _run_boss() -> void:
	var vp := get_viewport_rect().size
	position = Vector2(vp.x + COP_PX, vp.y * 0.5)

	if is_instance_valid(_spawner):
		_spawner.set_process(false)
		if _spawner.has_method("clear_items"):
			_spawner.call("clear_items")
	var bg := _game_root.get_node_or_null("Background")
	if bg and bg.has_method("stop_scrolling"):
		bg.call("stop_scrolling")
	var game_music := _game_root.get_node_or_null("Music")
	if game_music and game_music.has_method("fade_out"):
		game_music.call("fade_out")
	_music.play()

	# ── Въезд ───────────────────────────────────────────────────────────────
	var tw_in := create_tween()
	tw_in.tween_property(self, "position:x", vp.x - COP_X_PAD, 0.85)\
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	await tw_in.finished
	if not _alive():
		return
	SCREEN_SHAKE.play(_game_root, 12.0, 8)

	await BOSS_SPEECH.show(self, _game_root, SAY_ENTER, COP_PX,
		COL_BG, COL_BORDER, COL_INK)
	if not _alive():
		return
	await _show_banner()
	if not _alive():
		return

	# ── Акты ────────────────────────────────────────────────────────────────
	await _act_dog()
	if not _alive():
		return
	await _gap()
	await _act_squad()
	if not _alive():
		return
	await _gap()
	await _act_strafe()
	if not _alive():
		return
	await _gap()

	await _finale()
	if not _alive():
		return

	_music.stop()
	if is_instance_valid(game_music) and game_music.has_method("start"):
		game_music.call("start")
	if boss_test_mode and is_instance_valid(_spawner):
		if _spawner.has_method("force_resume"):
			_spawner.call("force_resume")
		_spawner.set("_pattern_running", false)
		_spawner.set_process(true)
		if is_instance_valid(bg) and bg.has_method("start_scrolling"):
			bg.call("start_scrolling")
	await get_tree().create_timer(0.4).timeout
	if not _alive():
		return
	defeated.emit()
	queue_free()

func _gap() -> void:
	if not _alive():
		return
	await get_tree().create_timer(ACT_GAP).timeout

# ── Акт 1: СОБАКА ───────────────────────────────────────────────────────────
# Спускает с поводка и ждёт, пока вернётся. Ждёт ПО СИГНАЛУ, а не по таймеру:
# сколько она пробегает, зависит от того, как игрок уходит, и таймер тут либо
# оборвал бы её на середине, либо держал бы пустую паузу.
func _act_dog() -> void:
	for wave in DOG_WAVES:
		if not _alive():
			return
		# Волна 0 — одна охотница; дальше две и три, и они уже не охотятся.
		for i in wave + 1:
			if not _alive():
				return
			_send_dog(wave > 0)
			if i < wave:
				# Вразбивку, а не разом: три собаки, вылетевшие в один кадр,
				# читаются как одна большая, и разлёт по углам не виден.
				await get_tree().create_timer(0.22).timeout
		# Ждём, пока ВСЯ волна отбегает своё. По арене, а не по сигналам: собак
		# теперь несколько, и считать их по одному сигналу нечем.
		var deadline : int = Time.get_ticks_msec() + DOG_WAVE_MAX_MS
		while Time.get_ticks_msec() < deadline and not _dogs_clear():
			await get_tree().process_frame
		if not _alive():
			return
		await get_tree().create_timer(0.7).timeout

# Ушла ли вся стая. Считаем ПО АРЕНЕ — по той же причине, что и у отряда:
# собака, вернувшаяся к хозяину, освобождает себя сама.
func _dogs_clear() -> bool:
	if not _alive():
		return false
	for n in get_tree().get_nodes_in_group("police_dog"):
		if is_instance_valid(n):
			return false
	return true

func _send_dog(pack: bool = false) -> void:
	var dog := Area2D.new()
	dog.set_script(DOG_SCRIPT)
	dog.set("target", _normaldo)
	dog.set("owner_node", self)
	dog.set("hunts", not pack)
	dog.position = position + Vector2(-COP_PX * 0.4, COP_PX * 0.15)
	_game_root.add_child(dog)
	_units.append(dog)
	SCREEN_SHAKE.play(_game_root, 5.0, 3)

# ── Акт 2: ОТРЯД С ВЕРТОЛЁТА ────────────────────────────────────────────────
# Отряд и НИЧЕГО БОЛЬШЕ, до последнего бойца. Акт кончается не по таймеру, а
# когда арена чиста: третий акт начинается с того же отряда, и наложить его на
# недобитый второй значило бы вернуть ту самую шеренгу, из-за которой бой и был
# непроходим.
func _act_squad() -> void:
	await _heli_drop([])
	if not _alive():
		return
	var deadline : int = Time.get_ticks_msec() + SQUAD_WAIT_MAX_MS
	while Time.get_ticks_msec() < deadline and not _squad_clear():
		await get_tree().process_frame

# Вертолёт идёт через кадр над первой-второй полосой и роняет бойцов на
# СЛУЧАЙНЫЕ полосы, кроме запрещённых (`avoid` — горящие).
func _heli_drop(avoid: Array) -> void:
	var vp := get_viewport_rect().size
	var heli := Node2D.new()
	heli.set_script(HELI_SCRIPT)
	heli.position = Vector2(vp.x + 220.0, lane_y(0) * 0.72)
	_game_root.add_child(heli)
	_units.append(heli)
	heli.call("set_door_open", true)

	var tw := heli.create_tween()
	tw.tween_property(heli, "position:x", -260.0, HELI_PASS_T)\
		.set_trans(Tween.TRANS_LINEAR)

	# Бойцы прыгают, пока вертолёт идёт, и прыгать они обязаны ИЗ НЕГО, а не
	# появляться сверху: иначе вертолёт в кадре не нужен вовсе.
	var kinds := ["shield", "rifle", "grenade"]
	kinds.shuffle()
	var marks : Array = []
	for i in SQUAD_SIZE:
		var k : float = 0.0 if SQUAD_SIZE <= 1 \
			else float(i) / float(SQUAD_SIZE - 1)
		marks.append(vp.x * lerpf(DROP_X_FROM_K, DROP_X_TO_K, k))

	var next : int = 0
	# Ждём КАЖДУЮ отметку, но с потолком: если вертолёт по какой-то причине не
	# доедет (твин убили, сцену снесли), цикл обязан кончиться сам, а не держать
	# акт до конца забега.
	#
	# Потолок по ЧАСАМ, а не по накопленной дельте кадров. Накопление дельт уже
	# однажды подвесило тут всё намертво (см. police_grenade.gd): в headless кадры
	# идут в микросекундах, и сумма до нужных секунд не доползает никогда.
	var deadline : int = Time.get_ticks_msec() + int((HELI_PASS_T + 1.0) * 1000.0)
	while next < marks.size() and Time.get_ticks_msec() < deadline:
		if not _alive() or not is_instance_valid(heli):
			break
		if heli.position.x <= float(marks[next]):
			_drop_one(heli, String(kinds[next % kinds.size()]), avoid)
			next += 1
			continue
		await get_tree().process_frame
	if not _alive():
		return
	if is_instance_valid(heli):
		await tw.finished
	if is_instance_valid(heli):
		heli.queue_free()

# ── НОВЫЙ ОТРЯД — ТОЛЬКО КОГДА КОНЧИЛСЯ ПРОШЛЫЙ ────────────────────────────
# Капитан сыпал отряд после КАЖДОГО захода штурмовки: акт 2 — одна тройка, акт 3
# — ещё три, акт 4 — ещё одна. Пятнадцать бойцов за бой, и каждый живёт до ухода
# за край семнадцать секунд, то есть они просто копились. К третьему заходу на
# экране стояла шеренга из десятка, две полосы горели, и пройти это было нельзя —
# не потому что сложно, а потому что некуда деться.
#
# Правило теперь такое: ОДНА группа за раз. Пока хоть один боец на арене, новых
# капитан не вызывает — работает вертолёт. Убил отряд или дождался, пока он уйдёт
# за край, — прилетит следующий.
#
# Это и делает отряд ответом на действия игрока, а не расписанием: расчистил —
# получил новых; не трогал — обходишь этих и дерёшься с вертолётом.
#
# Считаем ПО АРЕНЕ, а не по своему списку `_units`: боец, ушедший за край,
# освобождает себя сам, и в списке от него остаётся невалидная ссылка.
func _squad_clear() -> bool:
	if not _alive():
		return false
	for n in get_tree().get_nodes_in_group("swat"):
		if is_instance_valid(n):
			return false
	return true

func _drop_one(heli: Node2D, kind: String, avoid: Array) -> void:
	var lanes : Array = []
	for i in LANES:
		if not avoid.has(i):
			lanes.append(i)
	if lanes.is_empty():
		return
	var lane : int = int(lanes[randi() % lanes.size()])
	var s := Area2D.new()
	s.set_script(SWAT_SCRIPT)
	s.set("kind", kind)
	s.set("target", _normaldo)
	s.position = Vector2(heli.position.x, heli.position.y + 30.0)
	_game_root.add_child(s)
	_units.append(s)
	s.call("drop_to", lane_y(lane))

# ── Акт 3: ШТУРМОВКА ────────────────────────────────────────────────────────
# Вертолёт зависает у верхнего края, наполовину за кадром, и ведёт очередь по
# ВЫБРАННОЙ полосе справа налево. За очередью встаёт огонь — он и есть атака:
# полоса выключается на десять секунд.
#
# Полосы КАЖДЫЙ РАЗ РАЗНЫЕ, и это не украшение. Три захода по одной и той же
# полосе — это одна атака, повторённая трижды; по трём разным — сжимающееся
# поле, и к третьему заходу игроку остаётся две полосы из пяти.
func _act_strafe() -> void:
	var lanes : Array = STRAFE_LANES.duplicate()
	lanes.shuffle()
	var burning : Array = []

	for run in STRAFE_RUNS:
		if not _alive():
			return
		var lane : int = int(lanes[run % lanes.size()])
		burning.append(lane)
		# ── СНАЧАЛА ОТРЯД, И СРАЗУ ЗА НИМ ВЕРТОЛЁТ ──────────────────────────
		# Порядок именно такой, а не наоборот. Отряд высаживается в дальней трети
		# и идёт влево; вертолёт заходит следом и выжигает полосу. Игрок видит
		# сначала, КТО приехал, и только потом узнаёт, какой линии лишается, —
		# то есть успевает решить, куда уходить, до того как выбор сузился.
		#
		# Отряд идёт ТОЛЬКО с чистой арены (см. `_squad_clear`): пока жив
		# прошлый, работает один вертолёт. И садится он МИМО ГОРЯЩЕЙ ПОЛОСЫ —
		# боец, приземлившийся в огонь, сгорел бы у игрока на глазах, и вся
		# угроза от штурмовки прочиталась бы как «она бьёт и своих».
		if _squad_clear():
			await _heli_drop(burning.duplicate())
			if not _alive():
				return
		await _strafe_lane(lane)
		if not _alive():
			return
		# Огонь держится десять секунд с момента, как встал; за это время
		# отряд успевает дойти до середины.
		await get_tree().create_timer(1.2).timeout

	await get_tree().create_timer(2.0).timeout

func _strafe_lane(lane: int) -> void:
	var vp := get_viewport_rect().size
	var y := lane_y(lane)
	var x_from : float = vp.x - FIRE_X_FROM
	var x_to   : float = FIRE_X_TO

	# ── МЕСТО В УЧЁТЕ ЗАНИМАЕМ ДО ЗАХОДА ───────────────────────────────────
	# Здесь же, если полос уже две, начинает гаснуть самая старая — а на её уход
	# есть целая секунда, пока вертолёт подходит и наводится. Сначала эта строка
	# стояла прямо перед первым языком пламени, и гаснущая полоса накладывалась
	# на встающую: на экране на секунду оказывалось ТРИ горящих линии, ровно то,
	# ради чего потолок и заводился.
	var made : Array = _claim_lane()

	var heli := Node2D.new()
	heli.set_script(HELI_SCRIPT)
	# ВИСИТ НАПОЛОВИНУ ЗА КАДРОМ: видно брюхо с турелью, и только.
	heli.position = Vector2(vp.x * HELI_X_FROM, -60.0)
	_game_root.add_child(heli)
	_units.append(heli)
	heli.call("set_gun_visible", true)

	# Подходит к краю — это и есть телеграф: игрок видит турель до первой
	# очереди и успевает понять, что сейчас будет.
	var tw_in := heli.create_tween()
	tw_in.tween_property(heli, "position:y", HELI_HOVER_Y, 0.55)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tw_in.finished
	if not _alive():
		if is_instance_valid(heli):
			heli.queue_free()
		return

	# ── СНАЧАЛА НАВОДИТСЯ НА НАЧАЛО ПУТИ, И ТОЛЬКО ПОТОМ СТРЕЛЯЕТ ───────────
	# Ствол разворачивается к правому краю полосы и держит паузу. Это второй
	# телеграф, и он точнее первого: первый говорит «сейчас будет стрельба»,
	# этот — «вот отсюда и вот по какой полосе».
	heli.call("aim_at", Vector2(x_from, y))
	await get_tree().create_timer(AIM_HOLD_T).timeout
	if not _alive():
		if is_instance_valid(heli):
			heli.queue_free()
		return

	heli.call("set_firing", true)
	SCREEN_SHAKE.play(_game_root, 6.0, 10)

	# ── И ИДЁТ ВДОЛЬ ПОЛОСЫ ВМЕСТЕ СО СВОЕЙ ОЧЕРЕДЬЮ ───────────────────────
	# Не ради красоты. Вертолёт, висящий на месте и выжигающий полосу от края до
	# края, к концу очереди целится почти горизонтально назад — турель на подвесе
	# так не ходит, и сцена читается как «пулемёт вывернуло».
	#
	# Идя вровень с очередью, он всё время держит ствол ВНИЗ: сначала вниз-вперёд,
	# в середине отвесно, к концу вниз-назад. Ствол проходит градусов шестьдесят,
	# и каждый из них — вниз. Заодно из этого получается настоящий ЗАХОД: пришёл,
	# прошёл вдоль полосы, ушёл.
	var tw_run := heli.create_tween()
	tw_run.tween_property(heli, "position:x", vp.x * HELI_X_TO, STRAFE_SWEEP_T)\
		.set_trans(Tween.TRANS_LINEAR)

	# Очередь идёт СПРАВА НАЛЕВО, и огонь встаёт за ней. Не разом по всей
	# полосе: игрок должен успеть увидеть, куда она едет, и уйти вперёд неё.
	var steps : int = int(ceil(absf(x_from - x_to) / FIRE_STEP_PX)) + 1
	for i in steps:
		if not _alive():
			break
		var k := float(i) / float(steps - 1)
		var at := Vector2(lerpf(x_from, x_to, k), y)
		# ПОРЯДОК ВАЖЕН: сперва довернуть, потом спросить дуло. Наоборот — и
		# линия выйдет из того места, куда ствол смотрел на прошлом шаге.
		if is_instance_valid(heli):
			heli.call("aim_at", at)
			_tracer(heli.call("muzzle"), at)
		var f := _light_fire(at)
		if f != null:
			made.append(f)
		await get_tree().create_timer(STRAFE_SWEEP_T / float(steps)).timeout

	# И УХОДИТ — влево и вверх, тем же курсом, каким шёл. Уход вертикально вверх
	# из точки, до которой он долетел, читался бы как «его выдернули».
	if is_instance_valid(heli):
		heli.call("set_firing", false)
		var tw_out := heli.create_tween()
		tw_out.set_parallel(true)
		tw_out.tween_property(heli, "position:y", -220.0, 0.6)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tw_out.tween_property(heli, "position:x", -180.0, 0.6)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tw_out.chain().tween_callback(heli.queue_free)

	_burn_out(made)

# Одна очередь: жёлто-оранжевая линия от дула до точки. Живёт мгновение — это
# трассер, а не луч.
func _tracer(from: Vector2, to: Vector2) -> void:
	if not _alive():
		return
	var line := Line2D.new()
	line.add_point(_game_root.to_local(from))
	line.add_point(_game_root.to_local(to))
	line.width         = 4.0
	line.default_color = Color(1.00, 0.78, 0.18, 0.95)
	line.z_index       = 45
	_game_root.add_child(line)
	var tw := line.create_tween()
	tw.tween_property(line, "modulate:a", 0.0, 0.16)
	tw.tween_callback(line.queue_free)

func _light_fire(at: Vector2) -> Node:
	if not _alive():
		return null
	var f := FIRE_SCENE.instantiate()
	f.position = at
	if f.get("speed") != null:
		f.set("speed", 0.0)          # огонь СТОИТ: полоса выключена, а не едет
	_game_root.add_child(f)
	_fires.append(f)
	return f

# ── УЧЁТ ГОРЯЩИХ ПОЛОС ─────────────────────────────────────────────────────
# Каждая полоса — свой список огней. Заводится он ДО того, как полоса
# разгорится: пока вертолёт ведёт очередь слева направо, полоса уже считается
# занятой, иначе два захода подряд успели бы начаться вдвоём и потолок в две
# полосы не сработал бы ни разу.
var _lanes_on : Array = []

func _claim_lane() -> Array:
	while _lanes_on.size() >= MAX_BURNING:
		var oldest : Array = _lanes_on.pop_front()
		# Самую старую гасим ВДВОЕ БЫСТРЕЕ обычного: она и так отгорела почти всё
		# своё, и растягивать её уход означало бы держать три полосы разом ровно
		# то время, ради которого потолок и заводился.
		_fade_lane(oldest, FIRE_FADE_T * 0.5)
	var made : Array = []
	_lanes_on.append(made)
	return made

# Огонь гаснет СПРАВА НАЛЕВО — тем же ходом, каким встал. Гаснущий разом
# читался бы как «его выключили», а не как «он догорел».
func _fade_lane(made: Array, total: float) -> void:
	if made.is_empty():
		return
	var step : float = total / float(made.size())
	for i in made.size():
		if not _alive():
			return
		var f = made[i]
		if is_instance_valid(f):
			var tw := (f as Node2D).create_tween()
			tw.tween_property(f, "scale", Vector2.ZERO, step)
			tw.tween_callback((f as Node).queue_free)
		await get_tree().create_timer(step).timeout

func _burn_out(made: Array) -> void:
	if made.is_empty():
		return
	await get_tree().create_timer(FIRE_LIVE_T).timeout
	if not _alive():
		return
	# Полосу могли погасить досрочно — тогда её в учёте уже нет, и `erase` просто
	# ничего не найдёт. Догорание при этом отработает вхолостую: огни уже
	# освобождены, и каждый шаг увидит невалидную ссылку.
	_lanes_on.erase(made)
	await _fade_lane(made, FIRE_FADE_T)

# ── ЧЕТВЁРТОГО АКТА БОЛЬШЕ НЕТ ─────────────────────────────────────────────
# Здесь был «ВСЁ РАЗОМ»: собака, отряд и штурмовка одновременно, как экзамен по
# трём предыдущим. Он и добивал бой до непроходимости — экзамен из трёх атак
# сразу поверх уже стоящей на арене шеренги.
#
# Три акта хватает, и они уже нарастают сами: одна собака → стая → отряд →
# отряд под огнём. Четвёртый добавлял не новый вопрос, а громкость.

# ── Финал ───────────────────────────────────────────────────────────────────
# Вертолёт спускает трос, капитан хватается и уезжает. Пицца догоняет его уже в
# воздухе — он не побеждён в драке, он отступает.
func _finale() -> void:
	_clear_units()
	var vp := get_viewport_rect().size

	await BOSS_SPEECH.show(self, _game_root, SAY_FINALE, COP_PX,
		COL_BG, COL_BORDER, COL_INK, 2.0)
	if not _alive():
		return

	var heli := Node2D.new()
	heli.set_script(HELI_SCRIPT)
	heli.position = Vector2(vp.x + 240.0, 40.0)
	_game_root.add_child(heli)
	_units.append(heli)

	var tw_in := heli.create_tween()
	tw_in.tween_property(heli, "position:x", position.x + 30.0, 1.1)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tw_in.finished
	if not _alive():
		return

	# ТРОС. Тёмно-коричневый и толстый — верёвка, а не леска: тонкую линию на
	# пёстром фоне не видно, и капитан улетал бы «сам по себе».
	var rope := Line2D.new()
	rope.width         = 7.0
	rope.default_color = Color(0.28, 0.17, 0.08)
	rope.z_index       = 39
	rope.add_point(_game_root.to_local(heli.global_position))
	rope.add_point(_game_root.to_local(heli.global_position))
	_game_root.add_child(rope)
	_units.append(rope)

	var grab := position + Vector2(0.0, -COP_PX * 0.35)
	var tw_r := rope.create_tween()
	tw_r.tween_method(func(v: float) -> void:
		if is_instance_valid(rope) and is_instance_valid(heli):
			rope.set_point_position(0, _game_root.to_local(heli.global_position))
			rope.set_point_position(1,
				_game_root.to_local(heli.global_position).lerp(
					_game_root.to_local(grab), v)),
		0.0, 1.0, 0.7)
	await tw_r.finished
	if not _alive():
		return

	# ПИЦЦА НА ГОЛОВУ. Прилетает сверху и садится на фуражку — тот же приём, что
	# у крокодила и пирата: победа печатается предметом, ради которого забег и
	# идёт.
	var pizza := Sprite2D.new()
	pizza.texture        = PIZZA_TEX
	pizza.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pizza.z_index        = 60
	# Во всю морду, а не шапочкой на макушке: она садится НА ЛИЦО.
	ItemSizing.fit_sprite_content(pizza, COP_PX * PIZZA_PX_K)
	pizza.position       = Vector2(0.0, -vp.y)
	add_child(pizza)
	var tw_p := pizza.create_tween()
	tw_p.tween_property(pizza, "position:y", COP_PX * PIZZA_FACE_Y, 0.42)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw_p.finished
	if not _alive():
		return
	_play(SFX_PIZZA, -4.0)
	SCREEN_SHAKE.play(_game_root, 10.0, 6)
	# Голову вжимает в плечи — по этому видно, что пицца ПРИЛЕТЕЛА, а не легла.
	var tw_h := create_tween()
	tw_h.tween_property(_sprite, "position:y", 10.0, 0.10)
	tw_h.tween_property(_sprite, "position:y", 0.0, 0.16)

	await get_tree().create_timer(0.5).timeout
	if not _alive():
		return

	# И ПОДЪЁМ — ВЕРТОЛЁТ УЖЕ ЕДЕТ. Он не висит, дожидаясь, пока капитан
	# заберётся: тянет его на ходу, и это единственное, что делает уход
	# отступлением, а не эвакуацией по расписанию.
	var tw_up := create_tween()
	tw_up.set_parallel(true)
	tw_up.tween_property(self, "position", Vector2(vp.x + 220.0, -160.0), 1.4)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	if is_instance_valid(heli):
		tw_up.tween_property(heli, "position", Vector2(vp.x + 340.0, -220.0), 1.4)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	var tw_rope := rope.create_tween()
	tw_rope.tween_method(func(_v: float) -> void:
		if is_instance_valid(rope) and is_instance_valid(heli) and is_instance_valid(self):
			rope.set_point_position(0, _game_root.to_local(heli.global_position))
			rope.set_point_position(1, _game_root.to_local(global_position)),
		0.0, 1.0, 1.4)
	await tw_up.finished
	_clear_units()

# ── Титр BOSS FIGHT ─────────────────────────────────────────────────────────
# Тот же, что у остальных: кольцо, шипы, лицо босса в круге. Меняется только
# лицо — набранное шрифтом «БОСС ФАЙТ» выпадало бы из ряда.
func _show_banner() -> void:
	var vp := get_viewport_rect().size
	var cl := CanvasLayer.new()
	SafeArea.apply(cl)
	cl.layer = 99
	_game_root.add_child(cl)

	var overlay := ColorRect.new()
	overlay.color = Color(0.02, 0.04, 0.10, 0.0)
	overlay.size  = vp
	cl.add_child(overlay)

	var lbl := TextureRect.new()
	lbl.texture        = BANNER_TEX
	lbl.expand_mode    = TextureRect.EXPAND_IGNORE_SIZE
	lbl.stretch_mode   = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	lbl.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var bw : float = vp.x * 0.56
	var bh : float = bw * float(BANNER_TEX.get_height()) / float(BANNER_TEX.get_width())
	lbl.size         = Vector2(bw, bh)
	lbl.position     = Vector2((vp.x - bw) * 0.5, vp.y * 0.22)
	lbl.pivot_offset = lbl.size * 0.5
	lbl.scale        = Vector2.ZERO
	cl.add_child(lbl)

	var sub := Label.new()
	sub.add_theme_font_override("font", UI_FONT)
	sub.add_theme_font_size_override("font_size", 22)
	sub.text                 = "КАПИТАН ПОЛИЦИИ"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.modulate             = Color(0.55, 0.75, 1.00, 0.0)
	sub.size                 = Vector2(vp.x, 36)
	sub.position             = Vector2(0, vp.y * 0.22 + bh + 6.0)
	cl.add_child(sub)

	var tw_ov := overlay.create_tween()
	tw_ov.tween_property(overlay, "color:a", 0.65, 0.28)
	await tw_ov.finished
	if not _alive():
		cl.queue_free()
		return
	_play(BOSS_STINGER, -6.0)

	var tw_l := lbl.create_tween()
	tw_l.tween_property(lbl, "scale", Vector2.ONE, 0.28)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tw_l.finished
	if not _alive():
		cl.queue_free()
		return
	SCREEN_SHAKE.play(_game_root, 10.0, 8)

	var tw_s := sub.create_tween()
	tw_s.tween_property(sub, "modulate:a", 1.0, 0.22)
	await tw_s.finished
	await get_tree().create_timer(0.75).timeout
	if not _alive():
		cl.queue_free()
		return

	var tw_out := cl.create_tween()
	tw_out.set_parallel(true)
	tw_out.tween_property(overlay, "color:a", 0.0, 0.42)
	tw_out.tween_property(lbl,     "modulate:a", 0.0, 0.38)
	tw_out.tween_property(sub,     "modulate:a", 0.0, 0.38)
	await tw_out.finished
	cl.queue_free()

# ── Уборка ──────────────────────────────────────────────────────────────────
# Всё, что босс наплодил, — ЕГО дети по учёту, а не спавнера, и убрать их
# обязан он сам. Оставленный на экране сватовец пережил бы бой и стрелял бы по
# уже победившему игроку.
func _clear_units() -> void:
	for u in _units:
		if is_instance_valid(u):
			(u as Node).queue_free()
	_units.clear()
	for f in _fires:
		if is_instance_valid(f):
			(f as Node).queue_free()
	_fires.clear()

func _exit_tree() -> void:
	_alive_flag = false
	_clear_units()

func _play(stream: AudioStream, db: float) -> void:
	if stream == null or not is_inside_tree():
		return
	var p := AudioStreamPlayer.new()
	p.stream    = stream
	p.volume_db = db
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)
