extends Node2D

# ── Босс — Старый пират (король бомжей) ──────────────────────────────────────
# Босс третьего эпизода. Полное описание — /Концепция/Босс — Старый пират.md
#
# ── Чем он отличается от всех прежних ────────────────────────────────────────
# Крокодил, ниндзя и хозяин клуба спрашивали одно и то же: «успеешь ли уйти с
# линии». Игрок уворачивался — ровно как весь забег до боя, только быстрее.
#
# Этот спрашивает про ДИСТАНЦИЮ. Двигаться можно как обычно, но круг тесный,
# кулак достаёт ровно на длину руки, а противник идёт за тобой сам. Подойти,
# ударить и разорвать дистанцию до его броска — вот весь бой.
#
# Первая версия была другой: Нормальдо стоял приклеенным, свайп отдавал
# пружиной, а весь бой сводился к тому, когда нажать. Замысел «успей НЕ
# ударить» она держала, но ценой того, что всё выученное за забег на время боя
# выключалось; движение вернули, а торг оставили — только теперь он про то,
# когда подойти.
#
# ── Почему столкновения считаются вручную, а не физикой ──────────────────────
# Удар — не предмет потока: он обязан разрешаться ТРЕМЯ исходами (попал /
# получил / блок), причём блок это когда «оба одновременно». Физика Godot
# решает такие ничьи порядком сигналов area_entered, то есть случайно, — и блок
# то срабатывал бы, то нет. Здесь кадр считает дистанцию сам, и ничья остаётся
# ничьёй.
#
# Побочная выгода: бой целиком проверяется тестом без единого кадра рендера.

signal defeated

const SCREEN_SHAKE := preload("res://scripts/screen_shake.gd")
const BOSS_SPEECH  := preload("res://scripts/boss_speech.gd")
const HAPTICS      := preload("res://scripts/haptics.gd")
const UI_FONT      := preload("res://assets/fonts/RussoOne-Regular.ttf")

# ── Кадры ────────────────────────────────────────────────────────────────────
# Три рисунка, и каждый занят делом: idle — он скалится, frown — нахмурен, и
# ставится РОВНО на его удар, fist — его кулак.
const F_IDLE  := preload("res://assets/bosses/bum_king/idle.png")
const F_FROWN := preload("res://assets/bosses/bum_king/frown.png")
const F_FIST  := preload("res://assets/bosses/bum_king/fist.png")

# Кулак Нормальдо — ТОТ ЖЕ, что у Викинга, только ЗЕЛЁНЫЙ. Форма, размер и
# обводка викинговские: этот кулак уже нарисован и уже означает в игре «удар»,
# а второй такой же значил бы второй язык для одного и того же.
#
# А вот цвет — свой. У викинга кулак серый, и на арене выходило два серых
# бойца, различимых только по тому, кто где стоит. Зелёный тот же, что у головы
# Нормальдо, и нарисован автором: перекраска заливки скриптом была временной
# подменой, пока картинки не было.
const F_PLAYER_FIST := preload("res://assets/skills/fist_green.png")

# Куда смотрят сами рисунки кулаков: зелёный нарисован бьющим ВПРАВО, кулак
# пирата — ВЛЕВО. Хранится явно, потому что по картинке этого из кода не видно, а
# ошибка тихая: кулак просто оказывается отражённым и бьёт тыльной стороной.
const PLAYER_FIST_FACES : int =  1
const FOE_FIST_FACES    : int = -1

# ── Звуки ────────────────────────────────────────────────────────────────────
# Все взяты ИЗ УЖЕ ИМЕЮЩИХСЯ, а не записаны заново: перчатка — тот же удар, что
# у боксёрской перчатки в потоке, `hit` — то же попадание, что везде в забеге,
# `homeless_die` — те же бомжи. Бой обязан звучать как эта игра, а не как
# отдельный аттракцион со своим звуковым словарём.
#
# Бой без звука читался как немой: замах уходил беззвучно, попадание отличалось
# от промаха только полоской, а блок — вообще ничем.
const SFX_SWING  := preload("res://assets/audio/boxing_glove.mp3")
const SFX_HIT    := preload("res://assets/audio/hit.mp3")
const SFX_BLOCK  := preload("res://assets/audio/crash.mp3")
const SFX_DOWN   : Array = [
	preload("res://assets/audio/homeless_die1.mp3"),
	preload("res://assets/audio/homeless_die2.mp3"),
	preload("res://assets/audio/homeless_die3.mp3"),
]
const SFX_PIZZA  := preload("res://assets/audio/super_pizza.mp3")

# ЭТО СТИНГЕР, А НЕ ТЕМА БОЯ. Ровно так он и звучит у крокодила и ниндзя: одна
# фанфара на выход босса. Зациклённым он превращался в шарманку — четыре такта
# по кругу всю драку, из-за которых не слышно ни замаха, ни попадания.
const BOSS_STINGER := preload("res://assets/audio/boss_fight.mp3")

# Разовый звук. Игрок AudioStreamPlayer живёт ровно столько, сколько звучит:
# держать пул на четыре звука в бою, который идёт полминуты, незачем.
func _sfx(stream: AudioStream, volume_db: float = 0.0) -> void:
	if stream == null or not is_instance_valid(_game_root):
		return
	var p := AudioStreamPlayer.new()
	p.stream    = stream
	p.volume_db = volume_db
	_game_root.add_child(p)
	p.play()
	p.finished.connect(p.queue_free)

# Толпа — те же два бомжа, что стоят в потоке и в мини-игре. Толпа обязана
# читаться как «те самые бомжи», а не как новый народ.
const CROWD_TEX : Array = [
	preload("res://assets/items/homeless1.png"),
	preload("res://assets/items/homeless2.png"),
]

# ── Арена ────────────────────────────────────────────────────────────────────
# ТОЛПА ПЛОТНАЯ. Одно кольцо из двадцати шести читалось как хоровод с
# просветами между людьми: сквозь него было видно стену, и «уходить некуда»
# держалось только на словах. Теперь колец несколько, они вложены друг в друга и
# заходят внахлёст — получается сплошная масса голов, из которой и выходят
# противники.
#
# Серые и рыжие ВПЕРЕМЕШКУ и поровну: толпа из одного цвета читается как копии
# одного человека.
# Кольца стоят ПЛОТНО ПО КРАЮ, а не занимают весь экран вглубь. Раньше внутреннее
# кольцо стояло на 0.70 радиуса, то есть толпа съедала треть экрана с каждой
# стороны и арена выходила тесной: подойти и отойти было негде, вся драка шла в
# пятне размером с двух бойцов.
const CROWD_RINGS  : Array = [
	# [доля радиуса, сколько в кольце, множитель роста]
	[1.00, 38, 1.12],   # внешнее — крупные, ближе к зрителю
	[0.93, 34, 1.00],
	[0.86, 30, 0.90],   # дальние — мельче, уходят в глубину
]
# РОСТ КАК В ПОТОКЕ. Бомж в забеге — это 328 px картинки в масштабе 0.2, то есть
# около 66 на экране; в толпе стояло 54, и рядовые выглядели мельче тех же самых
# бомжей, мимо которых игрок только что пролетел. Толпа обязана читаться как «те
# самые», а не как их уменьшенные копии.
const CROWD_PX     : float = 72.0    # рост рядового в толпе
const CROWD_PAD_X  : float = 0.02    # отступ овала от краёв экрана, доли
const CROWD_PAD_Y  : float = 0.04
const CROWD_Z      : int   = 8       # за бойцами, но перед фоном
# Разброс каждого от его места в кольце. Без него кольца читаются кольцами;
# с ним — толпой.
const CROWD_JITTER : float = 16.0

# ── Толпа НАБЕГАЕТ ───────────────────────────────────────────────────────────
# Откуда стартует каждый (за своим краем экрана), сколько бежит и насколько
# растянут заезд. Разброс задержек обязателен: одновременный приезд сотни
# спрайтов читается как выдвижение декорации целиком, а не как сбежавшаяся
# толпа.
const CROWD_RUN_FROM   : float = 420.0
const CROWD_RUN_TIME   : float = 0.85
const CROWD_RUN_SPREAD : float = 0.55

# ── АРЕНА — КРУГ ВНУТРИ ТОЛПЫ ────────────────────────────────────────────────
# Внутри толпы пусто, и в этом круге Нормальдо ДВИГАЕТСЯ КАК ОБЫЧНО. Раньше он
# был приклеен к точке: свайп отдавал пружиной, а весь бой сводился к тому,
# когда нажать. Это верно ровно для одной механики — «успей не ударить», — но
# всё остальное, чему игрок учился весь забег, при этом выключалось.
#
# Теперь управление своё, обычное, и ограничение ровно одно: за круг не выйти.
# Толпа стоит по эллипсу экрана, поэтому и круг эллиптический — вписанный в неё
# с запасом, чтобы голова не залезала людям в лица.
const ARENA_RX_K : float = 0.38   # доли ширины экрана
const ARENA_RY_K : float = 0.34   # доли высоты
# Запас от края круга до центра головы: без него голова наполовину въезжает в
# толпу и читается как «застрял в людях».
const ARENA_MARGIN : float = 26.0

# Мелкие облачка над толпой. Это ГУЛ, а не реплики: короткие, без хвостов, по
# одному в случайном месте раз в секунду с небольшим. Читать их не надо — надо
# слышать, что вокруг орут.
# Толпа не болеет за кого-то — она ПОДСКАЗЫВАЕТ, что сейчас делать. Четыре
# слова, и каждое называет действие, которое в этом бою есть: ударить, сойти с
# места, уклониться, поставить блок. Это дешевле любого туториала и не
# останавливает бой.
const SHOUTS : Array = ["БЕЙ!", "ДВИГАЙСЯ!", "УКЛОНЯЙСЯ!", "БЛОКИРУЙ!"]
const SHOUT_EVERY : float = 1.15
const SHOUT_LIFE  : float = 1.30
# Сколько облачков висит разом. Одно на всю толпу читалось как «кто-то там
# что-то сказал», а гул стадиона — это несколько голосов сразу. Но и не больше
# двух: на первом же кадре с тремя облачками разом их набралось восемь, и они
# закрыли и бойцов, и рейки — подсказка стала помехой.
const SHOUT_AT_ONCE : int = 2

# Откуда бойцы начинают. Нормальдо в левой части круга, противник входит справа.
const HERO_X_RATIO : float = 0.30
const FOE_X_RATIO  : float = 0.72
const FIGHT_Y_RATIO: float = 0.52

# ── Кулаки — КАК У ВИКИНГА ───────────────────────────────────────────────────
# Удар не летящий снаряд, а ЗАМАХ: кулак вырастает у головы, проходит короткую
# дугу вперёд и гаснет. Ровно так бьёт викинг (`normaldo._cast_melee`), и это
# единственный удар, который в этой игре уже есть, — второй язык для того же
# действия сделал бы бой боссовой поделкой рядом с остальным забегом.
#
# Летящий кулак был неправ ещё и по игре: он превращал драку в перестрелку на
# одной линии, где всё решает, кто раньше нажал, а расстояние не значит ничего.
# Замах достаёт ровно на длину руки — значит дистанция и есть игра.
const FIST_PX        : float = 215.0   # как VIKING_FIST_PX: кулак крупнее головы
const FIST_Z         : int   = 45
# ЧЕЙ КУЛАК СВЕРХУ — ТОТ И УДАРИЛ ВТОРЫМ. В блоке две руки сходятся в одной
# точке, и на равном слое было не разобрать, кто кого встретил: получалась каша
# из двух кулаков. Теперь пришедший вторым ложится поверх — блок видно.
const FIST_Z_TOP     : int   = FIST_Z + 1
const SWING_TIME     : float = 0.26    # длина замаха, как MELEE_SWEEP_TIME
const SWING_HIT_AT   : float = 0.13    # когда считается попадание — середина дуги
const SWING_ARC      : float = 0.85    # раствор дуги, радианы
const SWING_REACH    : float = 132.0   # докуда достаёт кулак от центра головы

# Перезарядка удара. Без неё бой — мэшинг, а весь его смысл в паузе ПЕРЕД
# ударом: тапнув вхолостую, ты остаёшься без кулака ровно тогда, когда он нужен.
const PUNCH_CD    : float = 0.85

# Радиус головы — для расчёта дистанции удара: бьют не в точку, а в голову.
const HEAD_R      : float = 34.0

# ── Противник ПРЕСЛЕДУЕТ ─────────────────────────────────────────────────────
# Тот же рисунок, что у хозяина клуба в его последнем акте (`club_boss`):
# подходит → замирает на заряд → рывок → отдышка. Прежний противник ехал по
# одной горизонтали и вставал столбом: пока Нормальдо был приклеен, этого
# хватало, а свободному игроку такой враг не соперник — от него достаточно
# отойти вбок.
# ХОДЯТ МЕДЛЕННО. Быстрый подход не оставлял выбора: пока думаешь, подходить или
# ждать, он уже подошёл сам, и вся игра с дистанцией схлопывалась.
const FOE_WALK     : float = 84.0    # скорость подхода
const FOE_KEEP     : float = 118.0   # на какой дистанции держится
const CHARGE_T     : float = 0.70    # заряд перед рывком: столько есть на уход
const DASH_SPEED   : float = 520.0
const DASH_MAX_T   : float = 0.60
const RECOVER_T    : float = 0.90

# РАЗМЕР БОЙЦОВ. Они мельче толпы вокруг не по недосмотру: круг просторный, и
# двое крупных в нём занимали половину свободного места — отойти было некуда, а
# «подойти на длину руки» превращалось в «стоять вплотную всегда».
const BOSS_PX     : float = 150.0
const FOE_PX      : float = 92.0    # рядовой из волн 1–2

# ── Полосы ХП ────────────────────────────────────────────────────────────────
# РЕЙКИ СТОЯТ СВЕРХУ ВО ВЕСЬ ЭКРАН, как в старых играх: широкие сегменты в один
# ряд, а под ними тёмная подложка, сходящая на нет. Прежние 22×12 терялись на
# кирпичной стене — их приходилось искать глазами в тот момент, когда смотреть
# надо на кулаки.
#
# Ширина сегмента ПОДБИРАЕТСЯ: у короля их десять, у игрока три, и на узком
# экране фиксированная ширина просто не влезла бы. Берём предельную и ужимаем,
# пока строка не встанет в экран с полями.
const BAR_SEG_W   : float = 34.0    # предел; реальная считается под экран
const BAR_SEG_H   : float = 18.0
const BAR_GAP     : float = 5.0
const BAR_SIDE_PAD: float = 16.0
# Ниже верхней полосы забега (счётчики и таймер занимают первые ~30 px).
const BAR_Y       : float = 38.0
# Просвет между его полосой и твоей: без него десять сегментов подряд читались
# бы как одна полоса на двоих.
const BAR_MID_GAP : float = 40.0
const BAR_Z       : int   = 90

const KING_HP     : int = 10
# У рядовых ПО ОДНОЙ рейке. У рыжего первый размен уходит в блок, и его единица
# сгорает со второго удара — блок не отнимает жизнь, он её откладывает.
const FOE_HP      : int = 1
# ЖИЗНИ ИГРОКА В ЭТОМ БОЮ — СВОИ ТРИ, а не его жир. Жир — валюта забега: он
# растёт от пиццы и падает от ударов, и войти в бой можно как со скинни, так и с
# убером, то есть с одной жизнью или с четырьмя. Бой при этом задуман ровно
# одинаковым для всех: три рейки против пяти.
#
# Поэтому здесь свой счётчик, а последняя потерянная рейка убивает напрямую.
const HERO_HP     : int = 3

# ── Волны ────────────────────────────────────────────────────────────────────
# Волна — отдельный противник, и каждая учит РОВНО ОДНОМУ правилу. Следующая
# приходит только после того, как предыдущее сработало.
enum Wave { GREY, GINGER, KING }

var _normaldo  : Node2D = null
var _spawner   : Node   = null
var _game_root : Node2D = null
var boss_test_mode : bool = false

# Публичные — их читает тест. «Что сейчас происходит» иначе восстанавливается
# только по экрану, а тест экрана не видит.
var current_wave : String = ""     # "", "grey", "ginger", "king", "done"
var king_hp      : int    = KING_HP
var hero_hp      : int    = HERO_HP
var foe_hp       : int    = 0
var blocks       : int    = 0      # сколько разменов ушло в блок
var hits_dealt   : int    = 0
var hits_taken   : int    = 0
# Сколько раз игрок ЗАМАХНУЛСЯ. Считается отдельно от попаданий, потому что
# отвечают противники именно на замах: ответ на попадание опаздывает ровно на
# полёт кулака, и к его приходу твой уже отдёрнут — блок в таком размене
# невозможен физически.
var punches      : int    = 0

var _foe_sprite  : Sprite2D = null
var _foe_pos     : Vector2 = Vector2.ZERO   # живая позиция противника
var _fight_y     : float = 0.0
var _hero_x      : float = 0.0
# Как противник себя ведёт: "" (стоит) | approach | charge | dash | recover.
var _foe_state   : String = ""
var _foe_state_t : float  = 0.0
var _dash_to     : Vector2 = Vector2.ZERO
# Бьёт ли он вообще. Серый не бьёт никогда, рыжий — только в ответ, король — сам.
var _foe_attacks : bool = false

# Кулак в полёте: null или словарь {node, x, dir, retract}. Словарь, а не узел с
# полями: считает их всё равно `_process`, и держать состояние рядом с ним
# короче и виднее.
var _p_swing : Dictionary = {}   # замах игрока: {"t", "resolved"}
var _e_swing : Dictionary = {}   # замах противника
var _p_cd   : float = 0.0
# Кулаки, висящие в кадре. Нужны ровно для порядка слоёв: пришедший вторым
# ложится поверх (см. FIST_Z_TOP).
var _fists  : Array = []

var _crowd  : Array = []
var _shout_t: float = 0.0
var _bars_root : CanvasLayer = null
var _boss_segs : Array = []
var _hero_segs : Array = []
var _running   : bool  = false

func setup(normaldo: Node2D, spawner: Node, game_root: Node2D,
		test_mode: bool = false) -> void:
	_normaldo      = normaldo
	_spawner       = spawner
	_game_root     = game_root
	boss_test_mode = test_mode

func _ready() -> void:
	z_index = 40
	_run_boss()

# ЖИВ — ЗНАЧИТ И В ДЕРЕВЕ. `is_instance_valid` у `queue_free`-нутого узла ещё
# возвращает true до конца кадра, а `get_tree()` у вынутого из дерева уже null —
# и `await get_tree().process_frame` падал с «Invalid get index on null
# instance». Ровно так бой и падал, когда дев-кнопкой звали второго босса.
func _alive() -> bool:
	return is_instance_valid(self) and is_inside_tree() \
		and is_instance_valid(_normaldo) and is_instance_valid(_game_root)

# Один шаг ожидания: ждёт кадр и говорит, можно ли продолжать. Все циклы боя
# крутятся через него — иначе каждый пришлось бы обвешивать одной и той же
# парой проверок до и после `await`, и забытая проверка роняла бы игру.
func _step() -> bool:
	if not _alive() or not _running:
		return false
	await get_tree().process_frame
	return _alive() and _running

# ── Главная последовательность ───────────────────────────────────────────────

func _run_boss() -> void:
	var vp := get_viewport_rect().size
	_fight_y = vp.y * FIGHT_Y_RATIO
	_hero_x  = vp.x * HERO_X_RATIO
	_foe_pos = Vector2(vp.x * FOE_X_RATIO, _fight_y)

	# Поток замирает СЧЁТЧИКОМ, а не записью в поле: заморозка считается (см.
	# spawner.pause_for_event), и запись мимо счётчика разошлась бы с ним.
	if is_instance_valid(_spawner):
		_spawner.set_process(false)
		if _spawner.has_method("clear_items"):
			_spawner.call("clear_items")
	var bg := _game_root.get_node_or_null("Background")
	if bg and bg.has_method("stop_scrolling"):
		bg.call("stop_scrolling")

	# ЧИСТЫЙ ЭКРАН. Жира в этом бою нет — у игрока свои три рейки, — а счётчики
	# пиццы и долларов на арене с отключённым потоком показывают неподвижные
	# числа и только отвлекают. Кнопка паузы остаётся: выйти игрок обязан уметь.
	var hud := _game_root.get_node_or_null("HUD")
	if hud != null and hud.has_method("hide_run_hud_for_boss"):
		hud.call("hide_run_hud_for_boss", true)

	# Тема уровня уходит, как на крокодиле: под бегущую музыку драка читается
	# продолжением забега. Стингер играет один раз, на выход, — см. `_intro`.
	var lvl_music := _game_root.get_node_or_null("Music")
	if is_instance_valid(lvl_music) and lvl_music.has_method("fade_out"):
		lvl_music.call("fade_out")

	_build_crowd()
	_build_king_in_crowd()
	_lock_hero()
	_build_bars()

	await _intro()
	if not _alive():
		return

	_running = true
	await _wave_grey()
	if not _alive() or not _running: return
	await _wave_ginger()
	if not _alive() or not _running: return
	await _wave_king()
	if not _alive() or not _running: return

	await _victory()
	_finish()

# ── Толпа ────────────────────────────────────────────────────────────────────
# Овал, а не прямоугольник и не дуга: овал закрывает арену со ВСЕХ сторон, и
# «уходить некуда» видно, не читая правил. Бомжи по краям крупнее, чем в
# середине глубины, — дешёвая перспектива, от которой круг читается кругом.
func _build_crowd() -> void:
	var vp := get_viewport_rect().size
	var cx : float = vp.x * 0.5
	var cy : float = vp.y * 0.5
	# Цвета чередуются ПО ОБЩЕМУ СЧЁТЧИКУ, а не по номеру в кольце: считая внутри
	# кольца, соседние кольца получают один и тот же порядок, и на экране
	# проступают ровные полосы серого и рыжего.
	var n := 0
	for ring in CROWD_RINGS:
		var kr    : float = float((ring as Array)[0])
		var count : int   = int((ring as Array)[1])
		var kpx   : float = float((ring as Array)[2])
		var rx : float = vp.x * (0.5 - CROWD_PAD_X) * kr
		var ry : float = vp.y * (0.5 - CROWD_PAD_Y) * kr
		for i in count:
			# Полкольца сдвига через одно кольцо: иначе головы соседних колец
			# встают строго друг за другом и заднее кольцо не видно вовсе.
			var a : float = TAU * (float(i) + (0.5 if n % 2 == 0 else 0.0)) / float(count)
			var s2 := Sprite2D.new()
			s2.texture        = CROWD_TEX[n % CROWD_TEX.size()]
			s2.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			var px : float = CROWD_PX * kpx * randf_range(0.88, 1.12)
			s2.scale    = Vector2.ONE * (px / maxf(1.0, s2.texture.get_size().y))
			s2.position = _push_out_of_arena(
				Vector2(cx + cos(a) * rx, cy + sin(a) * ry)
				+ Vector2(randf_range(-CROWD_JITTER, CROWD_JITTER),
					randf_range(-CROWD_JITTER, CROWD_JITTER)))
			# Ближе к низу — поверх: там зритель, и нижние головы обязаны закрывать
			# верхние, а не наоборот.
			s2.z_index = CROWD_Z + int(s2.position.y / 40.0)
			add_child(s2)
			_crowd.append(s2)
			n += 1
			# ── СБЕГАЮТСЯ СО ВСЕХ СТОРОН ────────────────────────────────────
			# Толпа не стоит готовой к началу боя: она НАБЕГАЕТ и замыкает
			# Нормальдо в кольцо. Готовый овал читался как декорация, которую
			# нарисовали заранее; набегающая толпа — как событие, которое с
			# тобой происходит.
			#
			# Каждый стартует ЗА СВОИМ краем экрана — по направлению от центра к
			# своему месту, — и приезжает со своей задержкой: одновременный
			# заезд всех ста выглядит как выдвижение декорации целиком.
			var home : Vector2 = s2.position
			var away : Vector2 = (home - Vector2(cx, cy)).normalized()
			if away.length() < 0.01:
				away = Vector2.RIGHT
			s2.position = home + away * CROWD_RUN_FROM
			var run := s2.create_tween()
			run.tween_interval(randf_range(0.0, CROWD_RUN_SPREAD))
			run.tween_property(s2, "position", home, CROWD_RUN_TIME)\
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			# Покачивание заводится ПОСЛЕ прибытия: пущенное сразу, оно тянет
			# узел за собой во время забега и тот приезжает не на своё место.
			run.tween_callback(func() -> void:
				if is_instance_valid(s2):
					_sway(s2))

# ── Пират стоит в кольце С САМОГО НАЧАЛА ─────────────────────────────────────
# Он не приезжает на третью волну из-за края экрана — он всё это время стоит
# среди своих и смотрит, как дерутся его бомжи. Поэтому зов толпы («ПИРАТА В
# БОЙ!») адресован тому, кого видно, а выход читается как «он согласился», а не
# как «подвезли следующего противника».
#
# В кольце он крупнее рядовых, но мельче себя же боевого: шаг из толпы на арену
# и есть увеличение — он подходит ближе к зрителю.
const KING_CROWD_PX  : float = 112.0
const KING_CROWD_ANG : float = 0.06   # почти строго справа: оттуда выходят все

var _king_crowd : Sprite2D = null

func _king_home() -> Vector2:
	var vp := get_viewport_rect().size
	var c := vp * 0.5
	return Vector2(c.x + cos(KING_CROWD_ANG) * vp.x * (0.5 - CROWD_PAD_X) * 0.97,
		c.y + sin(KING_CROWD_ANG) * vp.y * (0.5 - CROWD_PAD_Y) * 0.97)

func _build_king_in_crowd() -> void:
	var home := _king_home()
	var s := Sprite2D.new()
	s.texture        = F_IDLE
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.scale          = Vector2.ONE * (KING_CROWD_PX / maxf(1.0, F_IDLE.get_size().y))
	s.position       = home
	# Поверх соседей: он в толпе, но он в ней главный, и загороженный чужими
	# затылками он бы просто не читался.
	s.z_index = CROWD_Z + 40
	add_child(s)
	_king_crowd = s
	# Набегает вместе со всеми и последним: кольцо смыкается, и в нём он.
	var away : Vector2 = (home - get_viewport_rect().size * 0.5).normalized()
	if away.length() < 0.01:
		away = Vector2.RIGHT
	s.position = home + away * CROWD_RUN_FROM
	var run := s.create_tween()
	run.tween_interval(CROWD_RUN_SPREAD)
	run.tween_property(s, "position", home, CROWD_RUN_TIME)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	run.tween_callback(func() -> void:
		if is_instance_valid(s):
			_sway(s))

# Где он сейчас стоит. Именно ПОЗИЦИЯ, а не место в кольце: он покачивается, и
# боец обязан появиться там, где толпа только что видела его самого.
func _king_crowd_pos() -> Vector2:
	if is_instance_valid(_king_crowd):
		return _king_crowd.position
	return _king_home()

# ── И РЯДОВЫЕ ТОЖЕ ВЫХОДЯТ ИЗ КОЛЬЦА ─────────────────────────────────────────
# Из толпы выходит не только пират: каждый противник — это КТО-ТО ИЗ ЭТИХ, а не
# ещё один такой же, подъехавший из-за края. Берём того, кто того же вида и стоит
# правее прочих: он уходит из кольца, и на его месте остаётся просвет — видно,
# что вышел именно он.
func _take_from_crowd(tex: Texture2D) -> Vector2:
	var best : Sprite2D = null
	for e in _crowd:
		if not is_instance_valid(e):
			continue
		var s : Sprite2D = e
		if s.texture != tex:
			continue
		if best == null or s.position.x > best.position.x:
			best = s
	if best == null:
		return Vector2.INF   # толпы нет — выйдет из-за края, как раньше
	var at : Vector2 = best.position
	_crowd.erase(best)
	_stop_sway(best)
	best.queue_free()
	return at

# ── ЕГО РЕПЛИКА ИДЁТ ЗА НИМ ───────────────────────────────────────────────────
# Реплика босса на входе — не титр посреди экрана, а облачко НАД НИМ: он выходит
# из кольца и идёт через полэкрана, и слова, оставшиеся висеть там, где он был,
# читались бы как чужие. Облачко держится у головы, пока он входит в круг, и
# гаснет, когда бой начался.
const KING_ENTER_SAY : String = "Моя набережная, парень."

var _king_say : Panel = null

func _say_over_king(text: String) -> void:
	if not is_instance_valid(_game_root):
		return
	var l := Label.new()
	l.add_theme_font_override("font", UI_FONT)
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", Color(1.00, 0.95, 0.82))
	l.text                 = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	var w : float = UI_FONT.get_string_size(text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 24.0
	l.size = Vector2(w, 26.0)

	var b := Panel.new()
	b.add_theme_stylebox_override("panel",
		UiKit.rounded(Color(0.16, 0.13, 0.09, 0.96), 10,
			Color(0.85, 0.72, 0.35, 0.95), 2))
	b.size         = l.size
	b.z_index      = FIST_Z_TOP + 2
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(l)
	add_child(b)
	_king_say = b
	_move_king_say()

# Каждый кадр — у его головы. Твином тут не обойтись: он идёт своим ходом, и
# путь его заранее неизвестен.
func _move_king_say() -> void:
	if not is_instance_valid(_king_say):
		return
	var at : Vector2 = _foe_pos
	if is_instance_valid(_foe_sprite):
		at = _foe_sprite.position
	elif is_instance_valid(_king_crowd):
		at = _king_crowd.position
	var vp := get_viewport_rect().size
	_king_say.position = Vector2(
		clampf(at.x - _king_say.size.x * 0.5, 4.0, vp.x - _king_say.size.x - 4.0),
		maxf(BAR_Y + BAR_SEG_H + 56.0, at.y - BOSS_PX * 0.75))

func _drop_king_say() -> void:
	if not is_instance_valid(_king_say):
		return
	var b := _king_say
	_king_say = null
	var tw := b.create_tween()
	tw.tween_property(b, "modulate:a", 0.0, 0.35)
	tw.tween_callback(b.queue_free)

func _king_steps_out() -> void:
	if is_instance_valid(_king_crowd):
		_king_crowd.queue_free()
	_king_crowd = null

# Каждый качается по-своему. Общая анимация на всю толпу выглядела бы как
# дрожащая картинка, а не как сотня человек.
func _sway(s2: Sprite2D) -> void:
	var tw := s2.create_tween().set_loops()
	var dy : float = randf_range(3.0, 8.0)
	var t  : float = randf_range(0.5, 1.1)
	tw.tween_property(s2, "position:y", s2.position.y + dy, t)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(s2, "position:y", s2.position.y, t)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# Ссылку на качание НАДО ХРАНИТЬ, потому что его придётся ВЫКЛЮЧАТЬ.
	# Качание — вечный цикл по абсолютным координатам, запомненным при заводе. Кто
	# бы потом ни двигал этого бомжа — разбег в финале, подход под тело, — качание
	# каждый второй кадр возвращало его на место в кольце. В финале это выглядело
	# так: носильщики подбегают под короля, тот поднимается, а они уезжают обратно
	# в толпу, и король висит в воздухе один, далеко от всех.
	s2.set_meta("sway", tw)

func _stop_sway(s2: Node) -> void:
	if not is_instance_valid(s2) or not s2.has_meta("sway"):
		return
	var tw = s2.get_meta("sway")
	if tw is Tween and (tw as Tween).is_valid():
		(tw as Tween).kill()
	s2.remove_meta("sway")

# ── Круг арены ───────────────────────────────────────────────────────────────
# Центр — центр экрана, радиусы — доли экрана. Считается каждый раз, а не
# запоминается: экран у телефонов разный, а константы здесь в долях.
func _arena_center() -> Vector2:
	return get_viewport_rect().size * 0.5

func _arena_radii() -> Vector2:
	var vp := get_viewport_rect().size
	return Vector2(vp.x * ARENA_RX_K, vp.y * ARENA_RY_K)

# Зажать точку внутри круга. Эллипс, а не окружность: экран альбомный, и круглая
# арена оставила бы половину ширины толпе.
func _clamp_to_arena(p: Vector2, margin: float = ARENA_MARGIN) -> Vector2:
	var c := _arena_center()
	var r := _arena_radii() - Vector2(margin, margin)
	if r.x <= 1.0 or r.y <= 1.0:
		return p
	var d := p - c
	var k : float = sqrt((d.x * d.x) / (r.x * r.x) + (d.y * d.y) / (r.y * r.y))
	if k <= 1.0:
		return p
	return c + d / k

# Толпа не заходит внутрь круга. Кольца стоят по радиусам 0.70…1.00 экрана, а
# круг — 0.30 × 0.26, так что пересечься они могут только разбросом; выталкивание
# РАДИАЛЬНОЕ — наружу от центра, туда же, куда смотрит само кольцо.
# Внутри ли круга. Считается тем же зажимом, что и держит бойцов: два разных
# способа отвечать на один вопрос рано или поздно разошлись бы в краях.
func _in_arena(p: Vector2, margin: float = ARENA_MARGIN) -> bool:
	return _clamp_to_arena(p, margin).distance_to(p) < 0.5

func _push_out_of_arena(p: Vector2) -> Vector2:
	var c := _arena_center()
	var r := _arena_radii()
	var d := p - c
	var k : float = sqrt((d.x * d.x) / maxf(1.0, r.x * r.x)
		+ (d.y * d.y) / maxf(1.0, r.y * r.y))
	if k >= 1.0:
		return p
	if d.length() < 1.0:
		d = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
		k = 0.001
	return c + d / maxf(0.001, k) * randf_range(1.02, 1.14)

# ── Толпа ЛИКУЕТ ─────────────────────────────────────────────────────────────
# Сбил противника — и вся арена подпрыгивает разом. Это единственный момент, где
# толпа делает что-то СООБЩА: всё остальное время каждый качается сам по себе,
# и на общем фоне синхронный прыжок читается как «получилось».
func _crowd_cheer() -> void:
	for e in _crowd:
		if not is_instance_valid(e):
			continue
		var c : Sprite2D = e
		var up : float = randf_range(18.0, 34.0)
		var y0 : float = c.position.y
		var tw : Tween = c.create_tween()
		tw.tween_property(c, "position:y", y0 - up, 0.16)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(c, "position:y", y0, 0.22)\
			.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	for i in SHOUT_AT_ONCE * 2:
		_shout()

func _shout(words: Array = SHOUTS) -> void:
	if _crowd.is_empty() or words.is_empty():
		return
	var who : Sprite2D = _crowd[randi() % _crowd.size()]
	if not is_instance_valid(who):
		return
	var l := Label.new()
	l.add_theme_font_override("font", UI_FONT)
	l.add_theme_font_size_override("font_size", 11)
	l.add_theme_color_override("font_color", Color(0.10, 0.09, 0.07))
	l.text                 = String(words[randi() % words.size()])
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	# Облачко ПО ТЕКСТУ, а не фиксированное. Раньше оно было 84 px под слова
	# вроде «БЕЙ!»; зов пирата длиннее любого из них и вылезал бы за края.
	# Считаем шириной строки, а не переносом: `autowrap` у Label меряет минимум
	# по ТЕКУЩЕЙ ширине, а она в момент вставки нулевая — и текст ломается по
	# букве в строку (та же ловушка, что чинили в UiKit.place).
	var tw_px : float = UI_FONT.get_string_size(l.text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 16.0
	l.size                 = Vector2(maxf(84.0, tw_px), 20.0)
	l.mouse_filter         = Control.MOUSE_FILTER_IGNORE

	var bub := Panel.new()
	bub.add_theme_stylebox_override("panel",
		UiKit.rounded(Color(0.96, 0.94, 0.86, 0.95), 8,
			Color(0.35, 0.30, 0.22, 0.9), 1))
	bub.size         = l.size
	# И НЕ ВЫЛЕЗАЕТ ЗА ЭКРАН: толпа стоит по самому краю, и облачко над крайним
	# обрезалось ровно посередине слова.
	var vp_s := get_viewport_rect().size
	bub.position     = Vector2(
		clampf(who.position.x - l.size.x * 0.5, 4.0, vp_s.x - l.size.x - 4.0),
		who.position.y - CROWD_PX * 0.95)
	bub.z_index      = CROWD_Z + 3
	bub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bub.add_child(l)
	add_child(bub)

	var tw := bub.create_tween()
	tw.tween_property(bub, "position:y", bub.position.y - 12.0, SHOUT_LIFE)
	tw.parallel().tween_property(bub, "modulate:a", 0.0, SHOUT_LIFE)\
		.set_delay(SHOUT_LIFE * 0.55)
	tw.tween_callback(bub.queue_free)

# ── Нормальдо ДВИГАЕТСЯ, но из круга не выходит ──────────────────────────────
# Управление обычное, то самое, которым игрок играл весь забег: свайп ведёт
# голову. Отнимается ровно одно — право уйти с арены, и отнимается оно не
# запретом ввода, а зажимом позиции: свайп в толпу докручивает голову до края
# круга и там оставляет. Уперся — видно, что уперся, и почему.
#
# Спеллы заблокированы: тап здесь бьёт кулаком, и дабл-тап, кастующий спелл, тем
# же жестом означал бы два действия сразу.
func _lock_hero() -> void:
	if not is_instance_valid(_normaldo):
		return
	_normaldo.position = _clamp_to_arena(Vector2(_hero_x, _fight_y))
	# ВЗГЛЯД — НА ПРОТИВНИКА, и только на него. В забеге направление решает
	# движение, но здесь есть тот, с кем дерутся: голова, смотрящая туда, куда
	# последний раз вели пальцем, дерётся затылком к сопернику. Куда именно
	# смотреть, говорим каждый кадр (`_face_foe`).
	if _normaldo.has_method("set_face_lock"):
		_normaldo.call("set_face_lock", true)
	if _normaldo.has_method("set_spells_blocked"):
		_normaldo.call("set_spells_blocked", true)
	if _normaldo.has_method("resume_input"):
		_normaldo.call("resume_input")
	_build_cd_bar()

# Каждый кадр возвращает голову внутрь круга. Именно каждый: игрок ведёт её
# пальцем непрерывно, и однократной проверки на входе хватило бы ровно на один
# свайп.
func _keep_hero_in_arena() -> void:
	if not is_instance_valid(_normaldo):
		return
	_normaldo.position = _clamp_to_arena(_normaldo.position)

# ── Полоска перезарядки ──────────────────────────────────────────────────────
# Под Нормальдо и узкая. Перезарядка без индикатора — это правило, которое игрок
# может только УГАДАТЬ: тапнул, ничего не вылетело, и непонятно, промахнулся ты
# по кнопке или кулак ещё не вернулся. Пауза перед ударом — весь смысл боя, и
# видеть её надо.
const CD_W : float = 74.0
const CD_H : float = 7.0
const CD_DY: float = 58.0

var _cd_fill : ColorRect = null
var _cd_back : ColorRect = null

func _build_cd_bar() -> void:
	var home := _hero_pos()
	_cd_back = ColorRect.new()
	_cd_back.color    = Color(0.06, 0.05, 0.04, 0.85)
	_cd_back.size     = Vector2(CD_W + 4.0, CD_H + 4.0)
	# ВЫШЕ ЛЮБОГО КУЛАКА: кулаки теперь занимают два слоя (FIST_Z и FIST_Z_TOP),
	# и полоска, стоявшая на верхнем из них, оказалась бы под рукой соперника.
	_cd_back.z_index  = FIST_Z_TOP + 4
	add_child(_cd_back)
	_cd_fill = ColorRect.new()
	_cd_fill.color    = Color(0.40, 0.85, 0.50, 0.95)
	_cd_fill.size     = Vector2(CD_W, CD_H)
	_cd_fill.z_index  = FIST_Z_TOP + 5
	add_child(_cd_fill)
	_move_cd_bar()

# ПОЛОСКА ЕДЕТ ЗА ГОЛОВОЙ. Раньше она стояла в точке, к которой Нормальдо был
# приклеен; теперь он ходит по кругу, и оставленная на месте полоска читалась бы
# как чужой элемент интерфейса, лежащий на полу.
func _move_cd_bar() -> void:
	if not is_instance_valid(_cd_fill) or not is_instance_valid(_cd_back):
		return
	var home := _hero_pos()
	_cd_back.position = Vector2(home.x - CD_W * 0.5 - 2.0, home.y + CD_DY - 2.0)
	_cd_fill.position = Vector2(home.x - CD_W * 0.5, home.y + CD_DY)

func _update_cd_bar() -> void:
	if not is_instance_valid(_cd_fill):
		return
	var ready : float = 1.0 - clampf(_p_cd / PUNCH_CD, 0.0, 1.0)
	_cd_fill.size.x = CD_W * ready
	# Цветом тоже: полная полоса зелёная, набирающаяся — тусклая. Одной длины
	# мало, когда смотришь не на неё, а на кулаки.
	_cd_fill.color = Color(0.40, 0.85, 0.50, 0.95) if ready >= 1.0 \
		else Color(0.70, 0.62, 0.30, 0.85)

func _release_hero() -> void:
	if not is_instance_valid(_normaldo):
		return
	# Взгляд возвращается забегу: дальше смотреть надо туда, откуда всё летит.
	if _normaldo.has_method("set_face_lock"):
		_normaldo.call("set_face_lock", false)
	if _normaldo.has_method("set_spells_blocked"):
		_normaldo.call("set_spells_blocked", false)
	if _normaldo.has_method("resume_input"):
		_normaldo.call("resume_input")

# ── Интро ────────────────────────────────────────────────────────────────────
const SPEECH : String = "Моя набережная, парень.\nПокажи, что у тебя в руках."

func _intro() -> void:
	current_wave = "intro"
	_sfx(BOSS_STINGER, -6.0)
	await BOSS_SPEECH.show(self, _game_root, SPEECH, BOSS_PX,
		Color(0.16, 0.13, 0.09, 0.96), Color(0.85, 0.72, 0.35, 0.95),
		Color(1.00, 0.95, 0.82))
	SCREEN_SHAKE.play(_game_root, 12.0, 8)

# ── Полосы ХП ────────────────────────────────────────────────────────────────
# СЕГМЕНТАМИ, а не заливкой: сегмент = удар, и «сколько осталось» читается
# счётом. Заливка на пяти хитах превратила бы каждый в незаметный шаг на 20 %.
#
# СКОЛЬКО У ВЫШЕДШЕГО РЕЕК — СТОЛЬКО И СЕГМЕНТОВ. Раньше полоса всегда стояла на
# пять, а рядовые занимали её первый сегмент по очереди: на экране это читалось
# как «бомжа надо ударить пять раз», хотя падал он с первого, — и половина полосы
# всю первую половину боя стояла погашенной непонятно почему. Теперь у рядового
# одна рейка, у пирата пять, и по длине полосы сразу видно, кто вышел.
func _build_bars() -> void:
	_bars_root = CanvasLayer.new()
	_bars_root.layer = BAR_Z
	_game_root.add_child(_bars_root)
	# Подложка кладётся ПЕРВОЙ и живёт отдельно от реек: раскладка реек
	# перестраивается каждой волной, а подложка стоит весь бой. Была бы она их
	# частью — мигала бы на каждой смене противника.
	_build_bar_shade()
	_layout_bars(FOE_HP, "")

# Тёмная полоса сверху, сходящая на нет книзу. Рейки стоят на кирпичной стене, и
# без подложки их приходится искать глазами — ровно в тот момент, когда смотреть
# надо на кулаки.
func _build_bar_shade() -> void:
	var vp := get_viewport_rect().size
	var g := Gradient.new()
	g.set_color(0, Color(0.0, 0.0, 0.0, 0.80))
	g.set_color(1, Color(0.0, 0.0, 0.0, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient  = g
	tex.fill_from = Vector2(0.0, 0.0)
	tex.fill_to   = Vector2(0.0, 1.0)
	tex.width     = 8
	tex.height    = 128
	var tr := TextureRect.new()
	tr.texture      = tex
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.position     = Vector2.ZERO
	tr.size         = Vector2(vp.x, BAR_Y + BAR_SEG_H + 54.0)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bars_root.add_child(tr)

func _layout_bars(foe_n: int, foe_text: String) -> void:
	if not is_instance_valid(_bars_root):
		return
	for old in [_hero_name, _foe_name]:
		if is_instance_valid(old):
			(old as Node).queue_free()
	for arr in [_hero_segs, _boss_segs]:
		for p in (arr as Array):
			if is_instance_valid(p):
				(p as Node).queue_free()
	var vp := get_viewport_rect().size
	# ПО ЦЕНТРУ И НИЖЕ ВЕРХНЕЙ ПОЛОСЫ ЗАБЕГА. Интерфейс забега на боссах
	# остаётся (см. hud.gd: игрок должен видеть свой жир и уметь поставить
	# паузу), и углы экрана заняты: слева пауза, счётчики и стопка резистов,
	# справа таймер. Полосы, поставленные в углы, легли ровно под них — на первом
	# же кадре было видно, что боссовой не видно вовсе.
	#
	# СВОЯ ПОЛОСА СЛЕВА, ЧУЖАЯ СПРАВА — как стоят и сами бойцы: Нормальдо в левой
	# половине круга, противник в правой. Раньше было наоборот, и в горячий
	# момент рейки читались задом наперёд: игрок смотрел, как «у него убавилось»,
	# а убавилось у него самого.
	var hero_n : int = HERO_HP
	var foe_c  : int = maxi(1, foe_n)
	# Сегмент — не меньше, чем позволяет экран, и не шире предела.
	var gaps  : float = float(hero_n - 1 + foe_c - 1) * BAR_GAP
	var avail : float = vp.x - BAR_SIDE_PAD * 2.0 - BAR_MID_GAP - gaps
	var seg_w : float = minf(BAR_SEG_W, avail / float(maxi(1, hero_n + foe_c)))
	var hw : float = float(hero_n) * seg_w + float(maxi(0, hero_n - 1)) * BAR_GAP
	var bw : float = float(foe_c) * seg_w + float(foe_c - 1) * BAR_GAP
	var total : float = hw + BAR_MID_GAP + bw
	var x0 : float = (vp.x - total) * 0.5
	_hero_segs = _make_bar(Vector2(x0, BAR_Y), hero_n, Color(0.35, 0.80, 0.45), seg_w)
	_boss_segs = _make_bar(Vector2(x0 + hw + BAR_MID_GAP, BAR_Y), foe_c,
		Color(0.85, 0.30, 0.26), seg_w)
	# ЧЬИ ЭТО РЕЙКИ — НАПИСАНО. Две одинаковые полоски по краям экрана ничем не
	# отличаются, кроме цвета, а цвет в драке разбирать некогда. Слева имя скина,
	# которым играют, справа — имя того, кто сейчас вышел; правая подпись и число
	# сегментов меняются от волны к волне — их и передаёт сюда каждая волна.
	_hero_name = _bar_caption(Vector2(x0, BAR_Y - 16.0), hw,
		String(SkinRegistry.get_skin(SaveData.active_skin).get("name_ru", "НОРМАЛЬДО")).to_upper(),
		Color(0.62, 0.95, 0.70))
	# Подпись шире своей полосы и стоит по её центру: у рядового полоса — один
	# сегмент в 22 px, а имя в него не влезает ни при каком размере шрифта.
	var cap_w : float = maxf(bw, 130.0)
	_foe_name  = _bar_caption(
		Vector2(x0 + hw + BAR_MID_GAP + (bw - cap_w) * 0.5, BAR_Y - 16.0),
		cap_w, foe_text, Color(1.00, 0.66, 0.60))
	# Перестроенные рейки показывают ТЕКУЩЕЕ здоровье, а не полное: полосу игрока
	# перекладывает каждая волна, а он к третьей приходит уже побитым.
	_burn(_hero_segs, hero_hp)
	_build_hint()

# ── ЧЕМ БЬЮТ — НАПИСАНО НА ЭКРАНЕ ────────────────────────────────────────────
# Удар здесь по ДВОЙНОМУ нажатию, и это единственное место в игре, где жест
# значит не то же, что в забеге: там тем же дабл-тапом кастуют спелл. Догадаться
# об этом неоткуда — толпа кричит «БЕЙ!», игрок тапает, ничего не происходит.
# Поэтому не подсказка на пару секунд, а надпись, которая висит весь бой: цена
# ей — строка внизу экрана, а без неё бой начинается с непонимания.
const HINT_TEXT : String = "ДВОЙНОЕ НАЖАТИЕ — УДАР"

func _build_hint() -> void:
	if is_instance_valid(_hint):
		return
	var vp := get_viewport_rect().size
	_hint = Label.new()
	_hint.add_theme_font_override("font", UI_FONT)
	_hint.add_theme_font_size_override("font_size", 16)
	_hint.add_theme_color_override("font_color", Color(1.00, 0.94, 0.72, 0.92))
	_hint.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.03))
	_hint.add_theme_constant_override("outline_size", 6)
	_hint.text                 = HINT_TEXT
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_hint.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	# ПОД РЕЙКАМИ, а не у нижнего края. Внизу она стояла на кирпичах мелкой
	# строчкой и терялась; здесь — на тёмной подложке, в той же панели, куда
	# игрок и так смотрит, проверяя рейки.
	UiKit.place(_bars_root, _hint,
		Vector2(0.0, BAR_Y + BAR_SEG_H + 10.0), Vector2(vp.x, 20.0))

var _hint : Label = null

var _hero_name : Label = null
var _foe_name  : Label = null

func _bar_caption(at: Vector2, w: float, text: String, col: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", UI_FONT)
	l.add_theme_font_size_override("font_size", 11)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.03))
	l.add_theme_constant_override("outline_size", 4)
	l.text                 = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	UiKit.place(_bars_root, l, at, Vector2(w, 14.0))
	return l


func _make_bar(at: Vector2, n: int, col: Color, seg_w: float = BAR_SEG_W) -> Array:
	var out : Array = []
	for i in n:
		var p := Panel.new()
		p.add_theme_stylebox_override("panel",
			UiKit.rounded(col, 3, Color(0.05, 0.04, 0.03, 0.9), 1))
		p.position     = at + Vector2(float(i) * (seg_w + BAR_GAP), 0.0)
		p.size         = Vector2(seg_w, BAR_SEG_H)
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_bars_root.add_child(p)
		out.append(p)
	return out

func _burn(segs: Array, left: int) -> void:
	for i in segs.size():
		var p : Panel = segs[i]
		if not is_instance_valid(p):
			continue
		p.modulate.a = 1.0 if i < left else 0.18

func _drop_bars() -> void:
	if is_instance_valid(_bars_root):
		_bars_root.queue_free()
	_bars_root = null

# ── Противник в кадре ────────────────────────────────────────────────────────

func _spawn_foe(tex: Texture2D, px: float, tint: Color,
		from: Vector2 = Vector2.INF) -> void:
	_clear_foe()
	_foe_sprite = Sprite2D.new()
	_foe_sprite.texture        = tex
	_foe_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_foe_sprite.scale          = Vector2.ONE * (px / maxf(1.0, tex.get_size().y))
	_foe_sprite.modulate       = tint
	_foe_sprite.z_index        = 30
	# ВЫХОДИТ ИЗ ТОЛПЫ И ИДЁТ НА ТЕБЯ, своим ходом. Подъезжающий твином за
	# полсекунды читался бы как «его поставили», а не как «он пошёл».
	#
	# `from` задан — значит выходит С КОНКРЕТНОГО МЕСТА В КОЛЬЦЕ: так выходит
	# пират, который всё это время там стоял. Без него — из-за правого края, как
	# рядовые: те безымянные, и откуда именно они взялись, значения не имеет.
	_foe_pos = from if from.is_finite() \
		else Vector2(get_viewport_rect().size.x + px * 0.5, _fight_y)
	_foe_sprite.position = _foe_pos
	# ВХОД — ОТДЕЛЬНОЕ СОСТОЯНИЕ, и вот почему. `_walk_foe` каждый кадр зажимает
	# противника в круг: без этого рывок выносил бы его в толпу. Но тот же зажим
	# срабатывал и на первом кадре после появления — и «выходит из толпы своим
	# ходом» превращалось в телепорт на край арены, сколько бы комментарий ни
	# утверждал обратное. Пока он входит, круг его не держит.
	_foe_state   = "enter"
	_foe_state_t = 0.0
	add_child(_foe_sprite)

# ── Преследование ────────────────────────────────────────────────────────────
# Тот же рисунок, что у хозяина клуба: подходит, пока далеко; на дистанции удара
# замирает на заряд; рывком проходит сквозь запомненную точку; отдыхает и снова
# подходит. Заряд — единственный телеграф, и он обязан быть виден: точка
# запоминается В НАЧАЛЕ заряда, иначе стоять до последнего выгоднее, чем уходить.
#
# Серый и рыжий этот цикл проходят наполовину: у них `_foe_attacks` снят, и
# дальше «подошёл и держит дистанцию» дело не идёт.
func _walk_foe(delta: float) -> void:
	if not is_instance_valid(_foe_sprite):
		return
	var target : Vector2 = _hero_pos()
	var to     : Vector2 = target - _foe_pos
	_foe_state_t += delta
	# КОРОЛЬ ДЕРЖИТ СВОЙ БОЙ САМ. Прямое преследование — язык рядовых: подошёл,
	# зарядил, бросился. Оно и делало короля лёгким: он приходил по прямой на
	# известную дистанцию и стоял там весь заряд.
	if current_wave == "king" and _foe_state != "enter":
		_walk_king(delta, to)
		return
	match _foe_state:
		"enter":
			# Идёт к кругу — оттуда, где появился: из-за края (рядовые) или из
			# кольца (пират). Дошёл до круга — дальше преследование: у рядовых
			# прямое, у короля своё (см. `_walk_king`).
			var into : Vector2 = _arena_center() - _foe_pos
			if into.length() > 1.0:
				_foe_pos += into.normalized() * FOE_WALK * delta
			_foe_sprite.position = _foe_pos + Vector2(0.0, sin(_foe_pos.x * 0.06) * 5.0)
			if _in_arena(_foe_pos):
				_foe_state   = "stalk" if current_wave == "king" else "approach"
				_foe_state_t = 0.0
			if is_instance_valid(_foe_sprite):
				_foe_sprite.flip_h = to.x > 0.0
			return
		"approach":
			if to.length() > FOE_KEEP:
				_foe_pos += to.normalized() * FOE_WALK * delta
			elif _foe_attacks and _foe_state_t >= 0.25:
				_enter_charge()
			# Вразвалку: шаг читается по покачиванию, а ровно едущая голова
			# выглядит как спрайт на рельсах.
			_foe_sprite.position = _foe_pos + Vector2(0.0, sin(_foe_pos.x * 0.06) * 5.0)
		"charge":
			if _foe_state_t >= CHARGE_T:
				_enter_dash()
			_foe_sprite.position = _foe_pos
		"dash":
			var d2 : Vector2 = _dash_to - _foe_pos
			_foe_pos += d2.normalized() * DASH_SPEED * delta
			# Долетел ИЛИ проскочил: на такой скорости кадр перепрыгивает цель, и
			# по одному расстоянию рывок не кончался бы никогда.
			if d2.length() <= DASH_SPEED * delta or _foe_state_t >= DASH_MAX_T:
				_enter_recover()
			_foe_sprite.position = _foe_pos
		"recover":
			# Отдышка КОРОЛЯ короче с каждой потерянной рейкой — в ней и живёт его
			# злость (см. `king_gap`). У рядовых она постоянная: им злеть не с
			# чего, они и не бьют.
			var wait : float = king_gap() if current_wave == "king" else RECOVER_T
			if _foe_state_t >= wait:
				_foe_state   = "approach"
				_foe_state_t = 0.0
			_foe_sprite.position = _foe_pos
		_:
			_foe_sprite.position = _foe_pos
	# Противник тоже держится круга: выскочивший в толпу боец читается как ушедший
	# из боя, а на деле он просто перелетел рывком.
	_foe_pos = _clamp_to_arena(_foe_pos, ARENA_MARGIN * 0.5)
	if is_instance_valid(_foe_sprite):
		_foe_sprite.flip_h = to.x > 0.0

# ── УМ КОРОЛЯ ────────────────────────────────────────────────────────────────
# Он был лёгким, и лёгким по понятной причине: он дрался как рядовой, только с
# пятью рейками. Подходил по прямой, вставал на дистанции удара и семь десятых
# секунды стоял в заряде — то есть сам приходил под кулак и сам же ждал, пока
# его ударят. А каждое попадание сбивало ему заряд, и бой сводился к «бей, как
# перезарядится»: игрок ни разу не был вынужден отойти.
#
# Чинится это не числами. Прибавь ему рейку — и то же самое станет дольше;
# ускорь рывок — и станет несправедливо, потому что читать в нём всё равно
# нечего. Ему нужны СВОИ решения, и вот четыре, которые их дают:
#
#   1. ОН КРУЖИТ. Держит полосу дистанции — не подходит ближе `KING_NEAR` и не
#      отпускает дальше `KING_FAR`, — и всё это время смещается вбок, меняя
#      сторону. Стоять на месте и ждать, пока он придёт на длину руки, больше
#      нельзя: он приходит не туда, где ты стоял.
#   2. ОН ЧИТАЕТ УДАР. На твой замах, если тот дотягивается, он отвечает —
#      ставит блок (и тут же бьёт в ответ) или уходит с линии. Чем меньше у него
#      реек, тем чаще читает. Бить наугад перестаёт работать: каждый замах — это
#      ставка.
#   3. ОН ФИНТИТ. Часть зарядов обрывается отскоком вместо рывка. Наказание
#      ровно за то, чему учит пункт 2: за удар на опережение по телеграфу.
#   4. ОН НЕ РАССЫПАЕТСЯ ОТ КАЖДОГО ПОПАДАНИЯ. Стойкость: сбивает его каждый
#      второй удар, остальные он проходит насквозь и доводит свой. Размен
#      перестаёт быть бесплатным.
#
# Всё это — только у него. Рядовые остаются обучением: у них тот же прямой
# рисунок, потому что их волны заведены объяснить по одному правилу.
const KING_WALK       : float = 124.0   # кружит быстрее, чем ходят рядовые
# ПОЛОСА, В КОТОРОЙ ОН КРУЖИТ, СЧИТАЕТСЯ ОТ ДЛИНЫ ТВОЕЙ РУКИ, а не задана числом.
# Числом она и была — 158…252 px, — и в этом была вся его лёгкость: рука
# достаёт на 265, то есть он кружил ВНУТРИ неё. Стоять и бить по готовности было
# выигрышной стратегией, потому что он сам всё время держался под кулаком.
#
# Теперь без дела он стоит там, куда ты не дотягиваешься, и входит в твою
# дистанцию только рывком. Отсюда и весь бой: ждать его броска и наказывать
# отдышку — или идти за ним самому, зная, что он читает.
const KING_SAFE       : float = 30.0    # запас поверх длины твоей руки
const KING_BAND       : float = 120.0   # ширина полосы обхода

func _king_near() -> float:
	return SWING_REACH + FIST_R + _foe_r() + KING_SAFE

func _king_far() -> float:
	return _king_near() + KING_BAND

const KING_STRAFE     : float = 0.95    # доля боковой скорости в кружении
const KING_STRAFE_T   : float = 1.05    # как часто меняет сторону обхода
# Читает он ЧАСТО — но только вне отдышки. Бить наугад, пока он кружит или
# заряжается, теперь плохая мысль: почти каждый такой замах он встретит блоком и
# ответит. А окно после его броска остаётся честным.
const KING_READ_BASE  : float = 0.45    # шанс прочитать замах на полных рейках
const KING_READ_GROW  : float = 0.40    # ...и насколько он растёт к последней
const KING_PARRY_T    : float = 0.40    # сколько держит блок
const KING_COUNTER_T  : float = 0.12    # ответ после парирования
const KING_BACKSTEP_T : float = 0.28
const KING_BACKSTEP_V : float = 330.0   # отскок быстрый: он уходит ОТ удара
const KING_FEINT      : float = 0.30    # доля зарядов, которые окажутся финтом
const KING_FEINT_T    : float = 0.26
const KING_JAB        : float = 0.45    # добивающий джеб сразу после рывка
const KING_JAB_T      : float = 0.20
const KING_CHARGE_MIN : float = 0.34    # заряд на последней рейке
const KING_POISE      : int   = 2       # каждый второй удар его НЕ сбивает
# ОТ НЕГО НЕ УБЕЖИШЬ. Круг тесный, но игрок в нём быстрее пешего короля, и
# кружить от него можно было бесконечно: бой превращался в ничью на таймере — ни
# он не достаёт, ни его не бьют. Поэтому чем дольше он не доставал, тем быстрее
# идёт и тем дальше решается броситься.
const KING_HUNT_FROM  : float = 1.60    # с какой паузы без атаки начинает гнать
const KING_HUNT_FULL  : float = 4.50    # ...и когда разгоняется до предела
const KING_HUNT_SPEED : float = 2.05    # во столько раз быстрее на пределе
const KING_HUNT_REACH : float = 1.75    # и во столько раз дальше бросается

var _no_hit_t : float = 0.0   # сколько он не доставал до игрока

# Насколько он уже разошёлся в погоне: 0 — только что бил, 1 — гоняет давно.
func _hunt() -> float:
	return clampf((_no_hit_t - KING_HUNT_FROM)
		/ maxf(0.1, KING_HUNT_FULL - KING_HUNT_FROM), 0.0, 1.0)

var _strafe_dir : float = 1.0
var _strafe_t   : float = 0.0
var _feint      : bool  = false
var _king_hits  : int   = 0

# Насколько он зол: 0 на полных рейках, 1 на последней.
func _king_rage() -> float:
	return clampf(float(KING_HP - king_hp) / float(maxi(1, KING_HP - 1)), 0.0, 1.0)

# Заряд перед рывком короче с каждой потерянной рейкой: телеграф остаётся, но
# времени на уход всё меньше.
func _charge_time() -> float:
	if current_wave != "king":
		return CHARGE_T
	return lerpf(CHARGE_T, KING_CHARGE_MIN, _king_rage())

func _read_chance() -> float:
	return KING_READ_BASE + KING_READ_GROW * _king_rage()

func _walk_king(delta: float, to: Vector2) -> void:
	_no_hit_t += delta
	var d   : float   = to.length()
	var dir : Vector2 = to.normalized() if d > 1.0 else Vector2.RIGHT
	match _foe_state:
		"stalk":
			# Полоса дистанции плюс обход. Сторона обхода меняется сама: обходя
			# всё время в одну, он читался бы как едущий по кругу, а не как
			# ищущий, с какой стороны зайти.
			_strafe_t += delta
			if _strafe_t >= KING_STRAFE_T:
				_strafe_t   = 0.0
				_strafe_dir = -_strafe_dir
			var move : Vector2 = dir.orthogonal() * _strafe_dir * KING_STRAFE
			if d > _king_far():
				move += dir
			elif d < _king_near():
				move -= dir
			if move.length() > 0.01:
				_foe_pos += move.normalized() \
					* KING_WALK * lerpf(1.0, KING_HUNT_SPEED, _hunt()) * delta
			_foe_sprite.position = _foe_pos + Vector2(0.0, sin(_foe_pos.x * 0.06) * 5.0)
			# Бросается тем раньше и тем издалека, чем дольше его водят.
			var from_d : float = _king_far() * lerpf(1.15, KING_HUNT_REACH, _hunt())
			var wait   : float = king_gap() * lerpf(1.0, 0.45, _hunt())
			if _foe_attacks and _foe_state_t >= wait and d <= from_d:
				_enter_charge()
		"charge":
			# Финт обрывается ОТСКОКОМ, а не просто отменой: отменённый на месте
			# заряд неотличим от лага, а отскок читается как «передумал».
			if _feint and _foe_state_t >= KING_FEINT_T:
				_enter_backstep()
			elif not _feint and _foe_state_t >= _charge_time():
				_enter_dash()
			_foe_sprite.position = _foe_pos
		"dash":
			var d2 : Vector2 = _dash_to - _foe_pos
			_foe_pos += d2.normalized() * DASH_SPEED * delta
			if d2.length() <= DASH_SPEED * delta or _foe_state_t >= DASH_MAX_T:
				_enter_recover()
			_foe_sprite.position = _foe_pos
		"parry":
			# Стоит в глухой: пока держит, твой удар в него не проходит.
			if _foe_state_t >= KING_PARRY_T:
				_enter_stalk()
			_foe_sprite.position = _foe_pos
		"backstep":
			_foe_pos -= dir * KING_BACKSTEP_V * delta
			if _foe_state_t >= KING_BACKSTEP_T:
				_enter_stalk()
			_foe_sprite.position = _foe_pos
		"recover":
			if _foe_state_t >= king_gap():
				_enter_stalk()
			_foe_sprite.position = _foe_pos
		_:
			_enter_stalk()
			_foe_sprite.position = _foe_pos
	_foe_pos = _clamp_to_arena(_foe_pos, ARENA_MARGIN * 0.5)
	if is_instance_valid(_foe_sprite):
		_foe_sprite.flip_h = to.x > 0.0

func _enter_stalk() -> void:
	_foe_state   = "stalk"
	_foe_state_t = 0.0
	if is_instance_valid(_foe_sprite) and current_wave == "king":
		_foe_sprite.texture = F_IDLE

func _enter_parry() -> void:
	_foe_state   = "parry"
	_foe_state_t = 0.0
	if is_instance_valid(_foe_sprite):
		_foe_sprite.texture = F_FROWN

func _enter_backstep() -> void:
	_foe_state   = "backstep"
	_foe_state_t = 0.0
	_feint       = false
	if is_instance_valid(_foe_sprite):
		_foe_sprite.texture = F_IDLE

# ЧИТАЕТ ЗАМАХ. Зовётся из `punch()` — то есть в момент, когда игрок только
# начал бить, а кулак ещё идёт по дуге. Отвечать на попадание было бы поздно, а
# отвечать на замах, который и так не дотягивается, — нечестно: он реагировал бы
# на движение пальца, а не на удар.
func _king_reads() -> void:
	if current_wave != "king" or not is_instance_valid(_foe_sprite):
		return
	# ОТДЫШКА — ЭТО ОТДЫШКА. Читать в ней он не может, и это не поблажка, а весь
	# смысл его броска: он рискует, ты наказываешь. Читай он и здесь — наказывать
	# было бы негде, и бой превратился бы в лотерею «дадут ли ударить».
	if _foe_state == "dash" or _foe_state == "parry" \
			or _foe_state == "backstep" or _foe_state == "recover":
		return
	if not _hero_can_reach():
		return
	if randf() > _read_chance():
		return
	# Два ответа, и они разные по цене. Блок оставляет его вплотную и даёт ему
	# ответный удар; отскок безопаснее для него, но отпускает игрока.
	if randf() < 0.55:
		_enter_parry()
	else:
		_enter_backstep()

# Парировал: удар не прошёл, и он тут же отвечает.
func _parried() -> void:
	blocks += 1
	_caption("ПАРИРОВАЛ!", Color(1.00, 0.78, 0.55))
	_sfx(SFX_BLOCK, -4.0)
	SCREEN_SHAKE.play(_game_root, 7.0, 5)
	_p_cd = PUNCH_CD
	# Расходятся МЕНЬШЕ, чем на обычном блоке: ответ обязан доставать, иначе
	# парирование не наказывает, а просто отменяет размен.
	_knock_apart(KNOCK_FOE * 0.35, KNOCK_HERO * 0.35)
	get_tree().create_timer(KING_COUNTER_T).timeout.connect(foe_punch, CONNECT_ONE_SHOT)

func _enter_charge() -> void:
	_foe_state   = "charge"
	_foe_state_t = 0.0
	# Финтит только король, и решается это ЗДЕСЬ, на входе: решай он в середине
	# заряда — телеграф был бы честным ровно до момента, когда врать выгодно.
	_feint = current_wave == "king" and randf() < KING_FEINT
	# Целится НЕ В САМОГО ИГРОКА, а на длину вытянутой руки перед ним. Раньше
	# точкой рывка была ровно позиция головы, и не ушедший игрок обнаруживал
	# пирата в своей собственной точке — две головы в одной.
	var to_hero : Vector2 = _hero_pos() - _foe_pos
	_dash_to = _hero_pos() - (to_hero.normalized() if to_hero.length() > 1.0
		else Vector2.LEFT) * _min_gap()
	# Нахмуренный кадр — телеграф заряда: у босса нет ни ленты, ни прицела, и
	# предупреждает он лицом.
	if current_wave == "king" and is_instance_valid(_foe_sprite):
		_foe_sprite.texture = F_FROWN
	SCREEN_SHAKE.play(_game_root, 6.0, 4)

func _enter_dash() -> void:
	_foe_state   = "dash"
	_foe_state_t = 0.0
	# Рывок И ЕСТЬ удар: замах выпускается в начале броска, и достанет он ровно
	# если рывок довёл его на длину руки — И ЕСЛИ ИГРОК ОСТАЛСЯ НА ЛИНИИ.
	foe_punch(_dash_to)

func _enter_recover() -> void:
	_foe_state   = "recover"
	_foe_state_t = 0.0
	if current_wave == "king" and is_instance_valid(_foe_sprite):
		_foe_sprite.texture = F_IDLE
		# ДОБИВАЮЩИЙ ДЖЕБ. Рывок кончился вплотную — значит у него есть вторая
		# рука, и уходить надо СРАЗУ, а не досматривать, чем кончилось. Без него
		# конец рывка был безопасным окном, в котором игрок бил бесплатно.
		if randf() < KING_JAB and _foe_can_reach():
			get_tree().create_timer(KING_JAB_T).timeout\
				.connect(foe_punch, CONNECT_ONE_SHOT)

func _hero_pos() -> Vector2:
	if is_instance_valid(_normaldo):
		return _normaldo.position
	return Vector2(_hero_x, _fight_y)

# ── Получил — мигнул ─────────────────────────────────────────────────────────
# Тот же красный и та же частота, что у Нормальдо в `_flash_hit`: попадание по
# врагу и попадание по себе обязаны выглядеть одинаково, иначе в размене их
# приходится различать по тому, чья голова где, — а именно на это в размене и
# нет времени.
const HURT_RED : Color = Color(1.00, 0.25, 0.25)

func _flash_red(s: Sprite2D, times: int = 3) -> void:
	if not is_instance_valid(s):
		return
	var tw := s.create_tween()
	tw.set_loops(times)
	tw.tween_property(s, "modulate", HURT_RED,   0.08)
	tw.tween_property(s, "modulate", Color.WHITE, 0.08)

func _clear_foe() -> void:
	if is_instance_valid(_foe_sprite):
		_foe_sprite.queue_free()
	_foe_sprite = null

# Побеждённый рядовой падает, как сбитый предмет: тот же язык, что у всего
# остального в игре.
func _drop_foe() -> void:
	if not is_instance_valid(_foe_sprite):
		return
	var s := _foe_sprite
	_foe_sprite = null
	# Падает СО СВОИМ голосом — тем же, каким бомжи падают в потоке.
	_sfx(SFX_DOWN[randi() % SFX_DOWN.size()], -3.0)
	var tw := s.create_tween()
	tw.tween_property(s, "position:y", s.position.y + 260.0, 0.45)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(s, "rotation", 1.4, 0.45)
	tw.tween_callback(s.queue_free)

# ── Кулаки: ЗАМАХ, а не снаряд ───────────────────────────────────────────────
# Кулак вырастает у головы, проходит короткую дугу вперёд и гаснет — ровно как
# у викинга. Попадание считается ОДИН РАЗ, в середине дуги, и только по
# дистанции: достал — попал, не достал — промахнулся.
#
# Летящий снаряд, стоявший тут раньше, был неправ вдвойне. Во-первых, он рисовал
# в игре второй язык удара: у викинга замах, у босса — перестрелка кулаками.
# Во-вторых, он превращал дистанцию в ничто — важно было только, кто раньше
# нажал, а подходить или отходить не имело смысла вовсе.
# `faces` — куда смотрит САМА КАРТИНКА: +1 нарисована бьющей вправо, −1 влево.
#
# Это не мелочь и не украшение. Кулак Нормальдо нарисован костяшками ВПРАВО,
# кулак пирата — ВЛЕВО, а код зеркалил обоих по одному правилу «бьёт влево —
# отрази». Для игрока выходило верно, а пират получал свой кулак отражённым:
# он бил тыльной стороной, костяшками назад. Со стороны это читается не как
# «другой замах», а как перевёрнутая картинка.
#
# Поэтому отражение считается от собственной ориентации рисунка: отражаем ровно
# тогда, когда бьют не в ту сторону, в какую он нарисован.
func _spawn_swing_fist(from: Vector2, dir: Vector2, tex: Texture2D,
		faces: int) -> void:
	var s := Sprite2D.new()
	s.texture        = tex
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Масштаб по РИСУНКУ, а не по кадру. У кулака пирата кадр 500×500, а рисунок
	# занимает в нём 275 по ширине; у зелёного рисунок занимает почти весь кадр.
	# При масштабе по кадру одно и то же число давало руки, отличающиеся вдвое:
	# у бомжа выходил кулачок вдвое меньше того, которым бьёт игрок.
	var art : float = float(maxi(1, ItemSizing.content_rect(tex).size.x))
	s.scale          = Vector2.ONE * (FIST_PX / art)
	s.flip_h         = (dir.x < 0.0) != (faces < 0)
	# Пришедший вторым ложится ПОВЕРХ уже висящего: см. FIST_Z_TOP. Прежние
	# опускаются обратно на нижний слой — иначе первый же размен оставил бы на
	# верхнем слое обе руки и разбирать снова было бы нечего.
	for old in _fists:
		if is_instance_valid(old):
			(old as Sprite2D).z_index = FIST_Z
	_fists = _fists.filter(func(f): return is_instance_valid(f))
	s.z_index        = FIST_Z_TOP
	s.position       = from + dir * (HEAD_R + 10.0)
	add_child(s)
	_fists.append(s)
	# Кулак ВЫРАСТАЕТ за первую треть замаха, а не появляется целиком: именно
	# рост и читается как превращение руки, а не как подставленная картинка.
	var full := s.scale
	s.scale = full * 0.45
	var tw := s.create_tween()
	tw.tween_property(s, "scale", full, SWING_TIME * 0.35)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# И проходит дугу: от замаха сверху к доводке снизу, с вылетом вперёд.
	var steps := 4
	var arc := s.create_tween()
	for i in range(1, steps + 1):
		var t : float = float(i) / float(steps)
		var ang : float = lerpf(-SWING_ARC * 0.5, SWING_ARC * 0.5, t)
		var rad : float = lerpf(HEAD_R + 10.0, SWING_REACH, sin(t * PI * 0.75))
		arc.tween_property(s, "position", from + dir.rotated(ang) * rad,
			SWING_TIME / float(steps))
	arc.tween_property(s, "modulate:a", 0.0, SWING_TIME * 0.3)
	arc.tween_callback(s.queue_free)

# Тап = удар. ЭТОТ ЖЕ ЖЕСТ в обычном забеге кастует спелл, и потому спелл здесь
# заблокирован: два действия на один жест — это не глубина, а промах.
func punch() -> void:
	if not _running or _p_cd > 0.0 or not _p_swing.is_empty():
		return
	_p_cd    = PUNCH_CD
	punches += 1
	var from := _hero_pos()
	var dir  : Vector2 = (_foe_pos - from)
	dir = dir.normalized() if dir.length() > 1.0 else Vector2.RIGHT
	_p_swing = { "t": 0.0, "resolved": false, "dir": dir }
	_spawn_swing_fist(from, dir, F_PLAYER_FIST, PLAYER_FIST_FACES)
	_sfx(SFX_SWING, -6.0)
	# Король ЧИТАЕТ замах — здесь, пока кулак только пошёл по дуге.
	_king_reads()

# Тап бьёт, свайп ведёт голову. Свайп сюда даже не заходит: движением занимается
# сам Нормальдо своим обычным управлением, а босс только держит его в круге.
# ── УДАР — ДАБЛ-ТАП, а не одиночный тап ─────────────────────────────────────
# Одиночным тапом бить нельзя, потому что тем же пальцем игрок ВЕДЁТ ГОЛОВУ:
# каждое касание для движения засчитывалось ударом, кулак уходил в пустоту, и к
# моменту, когда он нужен, тот был на перезарядке. Драка получалась не про
# выбор, а про то, чтобы случайно не задеть экран.
#
# Дабл-тап — тот же жест, которым в забеге кастуют спелл, и пороги у него те же
# (`normaldo._DTAP_TIME` / `_DTAP_DIST`): два быстрых касания рядом. Спелл здесь
# заблокирован, так что жест свободен и учить ему заново не приходится.
# Окно ЗДЕСЬ ШИРЕ, чем у спелла в забеге (0.20 с / 55 px). Спелл — необязательное
# действие: не вышло — просто не скастовал. Здесь дабл-тап это ЕДИНСТВЕННЫЙ
# способ ударить, и не распознанное касание читается не как «не попал в окно», а
# как «удар не работает». Плата за широкое окно — случайный удар при быстром
# ведении головы; она меньше, чем бой, в котором не бьётся.
const DTAP_TIME : float = 0.32
const DTAP_DIST : float = 80.0

var _last_tap_t   : float   = -10.0
var _last_tap_pos : Vector2 = Vector2.ZERO

func _input(event: InputEvent) -> void:
	if not _running:
		return
	var pressed := (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed) \
		or (event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT)
	if not pressed:
		return
	var at : Vector2 = Vector2.ZERO
	if event is InputEventScreenTouch:
		at = (event as InputEventScreenTouch).position
	elif event is InputEventMouseButton:
		at = (event as InputEventMouseButton).position
	var now : float = float(Time.get_ticks_msec()) / 1000.0
	if now - _last_tap_t <= DTAP_TIME and at.distance_to(_last_tap_pos) <= DTAP_DIST:
		# Отметка сбрасывается, иначе третье касание подряд сойдёт за второй
		# дабл-тап и удар уйдёт дважды на три касания.
		_last_tap_t = -10.0
		punch()
		return
	_last_tap_t   = now
	_last_tap_pos = at

# Удар противника. Публичный: им пользуются волны и тест.
# `aim` — куда бьёт. Задан — бьёт ПО ЭТОЙ ЛИНИИ: так бьёт рывок, и целится он в
# точку, которую запомнил в начале заряда. Целься он в живого игрока — заряд
# телеграфировал бы одно, а удар приходил бы по другому, и уходить было бы
# некуда.
func foe_punch(aim: Vector2 = Vector2.INF) -> void:
	if not _running or not _e_swing.is_empty() or not is_instance_valid(_foe_sprite):
		return
	var from := _foe_pos
	var dir  : Vector2 = ((aim if aim.is_finite() else _hero_pos()) - from)
	dir = dir.normalized() if dir.length() > 1.0 else Vector2.LEFT
	_e_swing = { "t": 0.0, "resolved": false, "dir": dir }
	_spawn_swing_fist(from, dir, F_FIST, FOE_FIST_FACES)
	# Чужой замах ТИШЕ своего: свой — это действие игрока, чужой — фон, и равная
	# громкость превращала бы размен в кашу из двух одинаковых шлепков.
	_sfx(SFX_SWING, -11.0)

func _process(delta: float) -> void:
	if _p_cd > 0.0:
		_p_cd = maxf(0.0, _p_cd - delta)
	_update_cd_bar()
	_shout_t += delta
	if _shout_t >= SHOUT_EVERY:
		_shout_t = 0.0
		for i in SHOUT_AT_ONCE:
			_shout()
	# КРУГ ДЕРЖИТ ВЕСЬ БОЙ, а не только пока идут волны. Управление игроку
	# возвращают сразу, до реплики босса, — и пока `_running` был ещё снят, в
	# толпу можно было уйти прямо под его слова.
	_keep_hero_in_arena()
	_move_cd_bar()
	# ВЗГЛЯД ТОЖЕ ВЕСЬ БОЙ, а не только пока идут волны: под реплику босса и в
	# паузах между волнами Нормальдо обязан стоять к сопернику лицом, а не
	# застывать в том развороте, в каком его застало последнее движение.
	_face_foe()
	# Реплика короля держится у его головы, пока он входит в круг.
	if is_instance_valid(_king_say):
		_move_king_say()
		if is_instance_valid(_foe_sprite) and _foe_state != "enter":
			_drop_king_say()
	if not _running:
		return
	_walk_foe(delta)
	_keep_apart()
	_resolve(delta)

# Дистанция между головами — по ней и решается всё. Не «кулак доехал», а
# «дотянулся»: у замаха длина руки постоянная, и подойти на неё — это ход.
func _fight_dist() -> float:
	return _hero_pos().distance_to(_foe_pos)

# ── ДОСТАЁТ ТУДА, КУДА ДОЕЗЖАЕТ РИСУНОК ──────────────────────────────────────
# Считалось это одной длиной на обоих и от ЦЕНТРОВ голов: `SWING_REACH + HEAD_R`,
# то есть 166 px. А кулак на экране — картинка в 215 px шириной, и её край
# проезжал по противнику задолго до этих 166: игрок видел, как рука проходит
# сквозь бомжа, и ничего не происходило. Попадать приходилось вплотную.
#
# Теперь дальность складывается из того, что видно: длина дуги + костяшки +
# голова того, в кого бьют. У каждой стороны своя, потому что головы разного
# размера: у Нормальдо HEAD_R, у пирата — его собственный рост.
const FIST_R : float = FIST_PX * 0.34   # костяшки, а не вся картинка кулака

func _foe_r() -> float:
	if not is_instance_valid(_foe_sprite) or _foe_sprite.texture == null:
		return FOE_PX * 0.42
	return ItemSizing.content_rect(_foe_sprite.texture).size.y \
		* _foe_sprite.scale.y * 0.42

# ── РАЗМЕН РАСТАЛКИВАЕТ ОБОИХ ────────────────────────────────────────────────
# Любой исход — попал, получил, блок — разводит бойцов. Раньше отлетал только
# получивший от игрока, а всё остальное оставляло их стоять вплотную: после
# блока оба уже стояли нос к носу, и следующий размен начинался без дистанции,
# то есть без самой игры. Ударил — разошлись, и подходить надо заново.
const KNOCK_FOE  : float = 40.0
const KNOCK_HERO : float = 30.0

# Ближе этого бойцы не сходятся НИКОГДА. Пират в рывке целился в запомненную
# точку — то есть ровно туда, где стоит игрок, — и, если тот не уходил, оказывался
# прямо в его позиции: две головы в одной точке.
func _min_gap() -> float:
	return HEAD_R + _foe_r() + 10.0

func _knock_apart(k_foe: float, k_hero: float, stagger: bool = true) -> void:
	var axis : Vector2 = _foe_pos - _hero_pos()
	axis = axis.normalized() if axis.length() > 1.0 else Vector2.RIGHT
	_foe_pos = _clamp_to_arena(_foe_pos + axis * k_foe, ARENA_MARGIN * 0.5)
	if is_instance_valid(_normaldo):
		_normaldo.position = _clamp_to_arena(
			_normaldo.position - axis * k_hero, ARENA_MARGIN)
	# И разгон сбивается: размен в разгоне — это размен, а не проезд насквозь.
	# Но у КОРОЛЯ есть стойкость: сбивает его каждый второй удар, остальные он
	# проходит насквозь и доводит свой. Пока сбивало каждое попадание, размен с
	# ним был бесплатным — бей, и он никогда не дойдёт.
	if _foe_state == "dash" or _foe_state == "charge":
		if stagger:
			_enter_recover()

# Каждый кадр: разъехаться, если сошлись ближе допустимого.
func _keep_apart() -> void:
	if not is_instance_valid(_foe_sprite) or _foe_state == "enter":
		return
	var d : Vector2 = _foe_pos - _hero_pos()
	var gap : float = _min_gap()
	if d.length() >= gap:
		return
	var axis : Vector2 = d.normalized() if d.length() > 1.0 else Vector2.RIGHT
	_foe_pos = _clamp_to_arena(_hero_pos() + axis * gap, ARENA_MARGIN * 0.5)

# Смотреть на противника. Каждый кадр, а не на входе: он ходит кругом, и один
# разворот на старте боя означал бы «смотрит туда, где противник был».
func _face_foe() -> void:
	if is_instance_valid(_normaldo) and _normaldo.has_method("face_towards"):
		_normaldo.call("face_towards", _foe_pos.x)

# ── УДАР ИДЁТ ПО ЛИНИИ, А НЕ В ТОЧКУ ─────────────────────────────────────────
# Дистанции мало: замах — это дуга в одну сторону, и человек, отошедший вбок,
# из-под неё выходит. Без этого уход с линии не работал вовсе: пират целился в
# ту точку, где игрок оказывался НА МОМЕНТ БРОСКА, и уйти от рывка было нельзя
# никак — заряд телеграфировал линию, а бил он всё равно по тебе.
const SWING_CONE : float = 0.55   # раствор, в котором замах ещё достаёт, радианы

func _in_cone(swing: Dictionary, from_p: Vector2, to_p: Vector2) -> bool:
	if not swing.has("dir"):
		return true
	var now : Vector2 = to_p - from_p
	if now.length() < 1.0:
		return true
	return absf((swing["dir"] as Vector2).angle_to(now.normalized())) <= SWING_CONE

# Мой кулак достаёт до него.
func _hero_can_reach() -> bool:
	return _fight_dist() <= SWING_REACH + FIST_R + _foe_r()

# Его кулак достаёт до меня.
func _foe_can_reach() -> bool:
	return _fight_dist() <= SWING_REACH + FIST_R + HEAD_R

# Доходит ли замах: и по дистанции, и по стороне.
func _hero_lands() -> bool:
	return _hero_can_reach() and _in_cone(_p_swing, _hero_pos(), _foe_pos)

func _foe_lands() -> bool:
	return _foe_can_reach() and _in_cone(_e_swing, _foe_pos, _hero_pos())

# Один кадр разбора. ПОРЯДОК ЗДЕСЬ И ЕСТЬ ПРАВИЛО: сперва ничья, потом
# попадания. Проверь попадания первыми — и размен, в котором оба достали в один
# кадр, разрешился бы в пользу того, чья строка стоит выше, то есть блока не
# было бы никогда.
func _resolve(delta: float) -> void:
	if not _p_swing.is_empty():
		_p_swing["t"] = float(_p_swing["t"]) + delta
	if not _e_swing.is_empty():
		_e_swing["t"] = float(_e_swing["t"]) + delta

	# БЛОК: оба замаха идут одновременно и оба дотягиваются. Кулаки встречаются —
	# ни один не проходит. Дотягиваться должны ОБА: размен, в котором один стоит
	# вне досягаемости, — это не ничья, это два промаха.
	if _swing_live(_p_swing) and _swing_live(_e_swing) \
			and _hero_lands() and _foe_lands() \
			and (_swing_ripe(_p_swing) or _swing_ripe(_e_swing)):
		_block()
		return

	if _swing_ripe(_p_swing):
		_p_swing["resolved"] = true
		if _hero_lands():
			# Прочитал и встал в блок — удар не проходит, и он отвечает.
			if _foe_state == "parry":
				_parried()
			else:
				_land_on_foe()
	if _swing_ripe(_e_swing):
		_e_swing["resolved"] = true
		if _foe_lands():
			_land_on_hero()

	# Замах кончился — руку убрали. Дальше кулак живёт своим твином и гаснет сам.
	if not _p_swing.is_empty() and float(_p_swing["t"]) >= SWING_TIME:
		_p_swing = {}
	if not _e_swing.is_empty() and float(_e_swing["t"]) >= SWING_TIME:
		_e_swing = {}

func _swing_live(s: Dictionary) -> bool:
	return not s.is_empty() and not bool(s["resolved"])

func _swing_ripe(s: Dictionary) -> bool:
	return _swing_live(s) and float(s["t"]) >= SWING_HIT_AT

func _block() -> void:
	blocks += 1
	_p_swing["resolved"] = true
	_e_swing["resolved"] = true
	_p_cd = PUNCH_CD
	_caption("БЛОК!", Color(1.00, 0.92, 0.55))
	# Кулаки встретились — обоих отбросило. Раньше после блока они оставались
	# стоять нос к носу, и следующий размен шёл уже без дистанции.
	_knock_apart(KNOCK_FOE, KNOCK_HERO)
	_sfx(SFX_BLOCK, -4.0)
	SCREEN_SHAKE.play(_game_root, 7.0, 5)

func _land_on_foe() -> void:
	hits_dealt += 1
	if current_wave == "king":
		king_hp = maxi(0, king_hp - 1)
		_burn(_boss_segs, king_hp)
	else:
		foe_hp = maxi(0, foe_hp - 1)
		_burn(_boss_segs, foe_hp)
	# ПОЛУЧИЛ — МИГНУЛ КРАСНЫМ. Отлёт назад читается и как «его толкнули», и как
	# «он сам отошёл», а рейка стоит вверху экрана, куда в размене не смотрят.
	# Тем же красным мигает и Нормальдо (`_flash_hit`) — язык один на обоих.
	_flash_red(_foe_sprite)
	# Разводит ОБОИХ: он отлетает дальше, но и бьющего отдачей отбрасывает.
	var stagger := true
	if current_wave == "king":
		_king_hits += 1
		stagger = (_king_hits % KING_POISE) == 0
	_knock_apart(KNOCK_FOE, KNOCK_HERO * 0.6, stagger)
	_sfx(SFX_HIT, -2.0)
	SCREEN_SHAKE.play(_game_root, 11.0, 7)

func _land_on_hero() -> void:
	hits_taken += 1
	_no_hit_t = 0.0   # достал — и погоня начинается заново
	# И здесь тоже разводит обоих — иначе пират, достав в рывке, оставался стоять
	# ровно там же, где стоит игрок.
	_knock_apart(KNOCK_FOE * 0.6, KNOCK_HERO)
	SCREEN_SHAKE.play(_game_root, 12.0, 8)
	hero_hp = maxi(0, hero_hp - 1)
	_burn(_hero_segs, hero_hp)
	# Отклик у Нормальдо остаётся его собственный — вспышка, звук, пузырь: игрок
	# уже знает этот язык, и заводить для боя второй значило бы учить заново.
	if is_instance_valid(_normaldo) and _normaldo.has_method("_flash_hit"):
		_normaldo.call("_flash_hit")
	if hero_hp > 0:
		return
	# Рейки кончились — забег кончился. Смерть зовётся НАПРЯМУЮ, а не через
	# `_take_hit`: тот считает жир, а жира в этом бою нет, и на убере он оставил
	# бы игрока стоять с пустой полосой.
	_running = false
	if is_instance_valid(_normaldo) and _normaldo.has_method("_die"):
		_normaldo.call("_die")

# Титр по центру ВВЕРХУ: там его видно, не отводя глаз от кулаков. Сбоку или у
# ног он попадал бы в слепое пятно ровно в тот момент, ради которого написан.
func _caption(text: String, col: Color) -> void:
	if not is_instance_valid(_game_root):
		return
	var vp := get_viewport_rect().size
	var l := Label.new()
	l.add_theme_font_override("font", UI_FONT)
	l.add_theme_font_size_override("font_size", 30)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.02))
	l.add_theme_constant_override("outline_size", 8)
	l.text                 = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	l.size                 = Vector2(vp.x, 44.0)
	# Ниже подсказки: обе строки в верхней панели, и наезжать друг на друга им
	# нельзя — «БЛОК!» появляется ровно тогда, когда подсказка ещё нужна.
	l.position             = Vector2(0.0, BAR_Y + BAR_SEG_H + 38.0)
	l.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	var lay := CanvasLayer.new()
	lay.layer = BAR_Z + 1
	lay.add_child(l)
	_game_root.add_child(lay)
	var tw := l.create_tween()
	tw.tween_property(l, "scale", Vector2(1.12, 1.12), 0.10)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "scale", Vector2.ONE, 0.12)
	tw.tween_interval(0.55)
	tw.tween_property(l, "modulate:a", 0.0, 0.25)
	tw.tween_callback(lay.queue_free)

# ── Волна 1: СЕРЫЙ бомж ──────────────────────────────────────────────────────
# Учит одному: тап = удар. Выходит из толпы и ПРЕСЛЕДУЕТ — идёт за Нормальдо по
# всему кругу и держится на дистанции удара, но НЕ БЬЁТ ВООБЩЕ. Не «редко»:
# первая же плюха на обучении означала бы, что игрок выучил не «тап бьёт», а
# «тапать опасно». Одна рейка.
func _wave_grey() -> void:
	current_wave = "grey"
	foe_hp = FOE_HP
	_foe_attacks = false
	# ОДНА рейка — у него их и правда одна.
	_layout_bars(FOE_HP, "СЕРЫЙ БОМЖ")
	_burn(_boss_segs, foe_hp)
	# homeless2 — СЕРЫЙ (homeless1 рыжий). Первым выходит именно серый, и путать
	# их местами нельзя: цвет — единственное, чем волны различаются на вид.
	_spawn_foe(CROWD_TEX[1], FOE_PX, Color.WHITE, _take_from_crowd(CROWD_TEX[1]))
	_caption("БЕЙ!", Color(0.75, 1.00, 0.80))
	await _await_foe_down()

# ── Волна 2: РЫЖИЙ бомж ──────────────────────────────────────────────────────
# Учит блоку. Сам не начинает никогда — преследует, держит дистанцию и ждёт
# твоего удара, отвечая ТУТ ЖЕ, так что замахи встречаются: это блок. Второй
# удар он уже не парирует и падает. Одна рейка: блок её не тратит, он её
# откладывает.
#
# Отвечает он на ЗАМАХ, а не на попадание: ответ на попадание опаздывает на всю
# длину дуги, к его приходу твой кулак уже убран, и блок в таком размене
# невозможен физически.
#
# ОТВЕЧАЕТ ОН РОВНО ОДИН РАЗ. Раньше второй ответ доходил и бил игрока — то есть
# рядовой из обучающей волны отнимал жизнь до того, как игрок увидел настоящий
# бой. Бьёт в этом бою только король.
const GINGER_ANSWER_DELAY : float = 0.02

var _ginger_answers : int = 0

func _wave_ginger() -> void:
	current_wave = "ginger"
	foe_hp = FOE_HP
	_ginger_answers = 0
	_foe_attacks = false   # сам не нападает: только отвечает на твой замах
	_layout_bars(FOE_HP, "РЫЖИЙ БОМЖ")
	_burn(_boss_segs, foe_hp)
	_spawn_foe(CROWD_TEX[0], FOE_PX, Color.WHITE, _take_from_crowd(CROWD_TEX[0]))
	_caption("БЛОКИРУЙ!", Color(1.00, 0.92, 0.55))
	await _await_foe_down()

# ── Волна 3: сам босс ────────────────────────────────────────────────────────
# Пять ХП, и с каждым потерянным он ЗЛЕЕ: отдышка между бросками короче. Пять
# ступеней сложности вместо пяти одинаковых попаданий.
const KING_GAP_START : float = 1.60
const KING_GAP_END   : float = 0.65

func king_gap() -> float:
	var lost : float = float(KING_HP - king_hp) / float(maxi(1, KING_HP - 1))
	return lerpf(KING_GAP_START, KING_GAP_END, clampf(lost, 0.0, 1.0))

# Толпа объявляет его САМА — и это единственное место, где она говорит не
# подсказку, а имя. До этого выходили безымянные рядовые; теперь понятно, что
# началось.
const KING_CALL : Array = [
	"ПИРАТА В БОЙ!", "СТАРЫЙ ПИРАТ ЗАДАСТ ЕМУ ЖАРУ!",
	"СТАРЫЙ ПИРАТ!", "ПОРВИ ЕГО!!", "КОРОЛЬ!", "У-У-У!!",
]
# Сколько толпа зовёт его, прежде чем он шагнёт из кольца. Меньше секунды — и
# зов не успевает прочитаться, вышел бы одновременно с первым облачком.
const KING_CALL_TIME : float = 1.40

func _wave_king() -> void:
	current_wave = "king"
	king_hp = KING_HP
	_foe_attacks = true     # ЕДИНСТВЕННЫЙ, кто нападает сам
	# ПЯТЬ реек — и они появляются ровно сейчас, вместе с ним.
	_layout_bars(KING_HP, "СТАРЫЙ ПИРАТ")
	_burn(_boss_segs, king_hp)
	_caption("СТАРЫЙ ПИРАТ", Color(1.00, 0.85, 0.40))
	for i in SHOUT_AT_ONCE * 2:
		_shout(KING_CALL)
	_crowd_cheer()
	HAPTICS.buzz(HAPTICS.BOSS)

	# ОН ВЫХОДИТ ИЗ ТОЛПЫ, А НЕ ИЗ-ЗА КРАЯ ЭКРАНА. Всё это время он стоял в
	# кольце — крупнее рядовых и на своём месте, — и зов толпы адресован тому,
	# кого видно. Приезжающий из-за края читался бы как «подвезли ещё одного»,
	# хотя вся сцена построена на том, что вокруг СВОИ и он тут главный.
	var from : Vector2 = _king_crowd_pos()
	var t0 : int = Time.get_ticks_msec()
	while float(Time.get_ticks_msec() - t0) / 1000.0 < KING_CALL_TIME:
		if not await _step():
			return
		# Пока зовут — он поднимается над кольцом: видно, к кому обращаются.
		if is_instance_valid(_king_crowd):
			_king_crowd.z_index = CROWD_Z + 60
	_king_steps_out()
	_spawn_foe(F_IDLE, BOSS_PX, Color.WHITE, from)
	# И говорит он это, ВЫХОДЯ, — облачко идёт с ним до самого круга.
	_say_over_king(KING_ENTER_SAY)
	# Драка идёт сама: преследование, заряд и рывок крутятся в `_walk_foe`, а
	# злость выражается тем, что отдышка короче — см. `king_gap`. Здесь остаётся
	# только дождаться, пока рейки кончатся.
	while king_hp > 0:
		if not await _step():
			return
	_crowd_cheer()
	# А ронять его ЗДЕСЬ НЕЛЬЗЯ — это делает финал, и делает иначе. `_drop_foe`
	# роняет рядового: тот проваливается вниз и исчезает. Король же заваливается
	# набок и остаётся лежать, ему на голову падает пицца, и уносят его тем же
	# самым телом. Пока падение стояло здесь, финал начинался с того, что боец
	# уезжает вниз, а на его месте появляется свежая копия и падает второй раз.

# Ждать, пока текущий рядовой не кончится. Рыжий отвечает отсюда же: ответ —
# это реакция на ТВОЙ удар, и место ему там, где удар и виден.
func _await_foe_down() -> void:
	# Слепок берётся ПО ТОЙ ЖЕ ВЕЛИЧИНЕ, по которой потом сравнивается. Возьми
	# другую — и рыжий выйдет в мир, где счётчик уже больше слепка, и ответит на
	# удар, которого не было, в первый же кадр. На экране это читается как «рыжий
	# бьёт первым», то есть ровно наоборот тому, чему волна заведена учить.
	var seen : int = punches
	while foe_hp > 0:
		if not await _step():
			return
		if current_wave == "ginger" and punches > seen:
			seen = punches
			# ОТВЕЧАЕТ ТОЛЬКО НА УДАР, КОТОРЫЙ ДО НЕГО ДОХОДИТ. Раньше он отвечал
			# на любой замах, хоть с другого конца арены: игрок бил в воздух,
			# рыжий бил в ответ в свой воздух, и на экране это ловилось как
			# «блок», хотя друг до друга они не дотягивались. Блок — это встреча
			# двух кулаков, а не совпадение двух промахов по времени.
			if not _hero_can_reach():
				continue
			_ginger_answers += 1
			# Только на ПЕРВЫЙ замах: он показывает блок и на этом свою работу
			# кончает. Второй ответ был бы ударом по игроку от учебного рядового.
			if _ginger_answers == 1:
				get_tree().create_timer(GINGER_ANSWER_DELAY).timeout\
					.connect(foe_punch, CONNECT_ONE_SHOT)
	if not _alive():
		return
	# Сбил — и вся арена подпрыгивает. Это и есть награда за волну: денег тут не
	# дают, а сказать «получилось» надо.
	_crowd_cheer()
	_drop_foe()
	await get_tree().create_timer(0.7).timeout

# ── Победа ───────────────────────────────────────────────────────────────────
# Не падение и не взрыв: он король, и уносят его как короля — трое-четверо
# поднимают над головами и уходят за левый край.
func _victory() -> void:
	current_wave = "done"
	_running = false
	_caption("ПОБЕДА", Color(0.75, 1.00, 0.80))
	SCREEN_SHAKE.play(_game_root, 16.0, 10)

	var vp := get_viewport_rect().size
	# Побеждённый босс — ТОТ ЖЕ узел, что дрался, а не новая копия на его месте.
	# Подменять спрайт в момент падения значит на один кадр показать, как он
	# дёрнулся: копия встаёт в свою позицию, а не туда, где он стоял.
	var king : Sprite2D = _foe_sprite
	_foe_sprite = null
	if not is_instance_valid(king):
		king = Sprite2D.new()
		king.texture        = F_IDLE
		king.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		king.scale          = Vector2.ONE * (BOSS_PX / maxf(1.0, F_IDLE.get_size().y))
		king.position       = _foe_pos
		king.z_index        = 32
		add_child(king)

	# ── ПАДАЕТ НАБОК ─────────────────────────────────────────────────────────
	# Не оседает и не исчезает: заваливается на бок и остаётся лежать. Дальше в
	# этом же положении его и унесут, поэтому поворот делается один раз и не
	# отыгрывается назад.
	var fall := king.create_tween()
	fall.tween_property(king, "rotation", -PI * 0.5, KING_FALL_T)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall.parallel().tween_property(king, "position:y",
		king.position.y + BOSS_PX * 0.22, KING_FALL_T)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await fall.finished
	if not _alive():
		return
	SCREEN_SHAKE.play(_game_root, 12.0, 8)
	_sfx(SFX_DOWN[0], 0.0)
	HAPTICS.buzz(HAPTICS.HEAVY)

	# ── И ЕМУ НА ГОЛОВУ ПАДАЕТ ПИЦЦА ─────────────────────────────────────────
	# Та же, что падает на морду крокодилу: это уже язык игры — «босс кончился,
	# сверху пицца». Второй знак для того же события значил бы, что игрок должен
	# выучить его заново.
	var head : Vector2 = king.position + Vector2(-BOSS_PX * 0.30, -BOSS_PX * 0.10)
	var pie := Sprite2D.new()
	pie.texture        = _victory_pizza_tex()
	pie.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pie.scale          = Vector2.ONE * (PIZZA_ON_HEAD_PX
		/ maxf(1.0, pie.texture.get_size().y))
	pie.position       = head - Vector2(0.0, vp.y * 0.7)
	# Поверх всего: она падает ему на голову, когда бой уже кончился.
	pie.z_index        = PIZZA_Z
	pie.rotation       = randf_range(-0.5, 0.5)
	add_child(pie)
	var drop := pie.create_tween()
	drop.tween_property(pie, "position", head, 0.42)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await drop.finished
	if not _alive():
		return
	_sfx(SFX_PIZZA, -4.0)
	SCREEN_SHAKE.play(_game_root, 7.0, 5)
	await get_tree().create_timer(0.45).timeout
	if not _alive():
		return

	# ── ТОЛПА РАЗБЕГАЕТСЯ ────────────────────────────────────────────────────
	# В РАЗНЫЕ СТОРОНЫ и вразнобой, а не ровным овалом наружу: расходящееся
	# кольцо читается как обратная перемотка того, как они сбегались, а бой уже
	# кончился — они не отступают, они расходятся.
	#
	# ТРОЕ ОСТАЮТСЯ. Их выбирают из ближних к боссу: бежать через весь экран,
	# чтобы поднять его, было бы дольше самого выноса.
	var carriers := _pick_carriers(king.position, 3)
	for e in _crowd:
		if not is_instance_valid(e) or carriers.has(e):
			continue
		var c : Sprite2D = e
		_stop_sway(c)
		var away : Vector2 = (c.position - vp * 0.5).normalized()
		if away.length() < 0.01:
			away = Vector2.RIGHT
		away = away.rotated(randf_range(-0.6, 0.6)) * randf_range(280.0, 460.0)
		var tw : Tween = c.create_tween()
		tw.tween_interval(randf_range(0.0, 0.35))
		tw.tween_property(c, "position", c.position + away, randf_range(0.7, 1.1))\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(c, "modulate:a", 0.0, 0.9)

	# ── ТРОЕ ПОДБЕГАЮТ И УНОСЯТ ЕГО ЛЁЖА ─────────────────────────────────────
	# Сперва встают под него — по длине лежащего тела, — и только потом поднимают:
	# поднятый до подхода носильщиков король висит в воздухе сам по себе.
	# Носильщики встают ПОД ЛЕЖАЩЕЕ ТЕЛО: он повёрнут набок, и его длина на экране
	# — это ширина рисунка, а не высота кадра. Раньше слоты считались от BOSS_PX,
	# то есть от высоты стоящего, и крайние вставали в пустоту рядом с телом.
	var body_w : float = ItemSizing.content_rect(king.texture).size.y * king.scale.y
	var body_h : float = ItemSizing.content_rect(king.texture).size.x * king.scale.x
	var slots : Array = [-body_w * 0.32, 0.0, body_w * 0.32]
	for i in carriers.size():
		var b : Sprite2D = carriers[i]
		_stop_sway(b)
		var spot : Vector2 = king.position + Vector2(float(slots[i]), body_h * 0.5 + 8.0)
		var run := b.create_tween()
		run.tween_property(b, "position", spot, 0.45)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(0.5).timeout
	if not _alive():
		return

	# Подняли — и понесли. ЛЁЖА: поворот с падения не отыгрывается назад, его
	# уносят в том положении, в каком он упал.
	# ВЫСОТА ПОДЪЁМА — ДО ИХ РУК, а не «на глаз». Поднятый на фиксированные 46 px
	# король отрывался от носильщиков и ехал сам по себе, а между ним и ними
	# зияла пустота. Считаем так, чтобы низ лежащего тела лёг на макушки: они
	# стоят под ним, значит поднять надо ровно на полголовы носильщика.
	var lift_h : float = maxf(8.0, CROWD_PX * 0.5 - 8.0)
	var lift := king.create_tween()
	lift.tween_property(king, "position:y", king.position.y - lift_h, 0.40)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	lift.tween_property(king, "position:x", -BOSS_PX, 1.6)\
		.set_trans(Tween.TRANS_SINE)
	# Уносят его ВМЕСТЕ С СОБОЙ и с той же скоростью: разъехавшись хоть на кадр,
	# тело и носильщики читаются как две отдельные едущие картинки.
	for b in carriers:
		var tw2 := (b as Sprite2D).create_tween()
		tw2.tween_interval(0.40)
		tw2.tween_property(b, "position:x",
			(b as Sprite2D).position.x - (king.position.x + BOSS_PX), 1.6)\
			.set_trans(Tween.TRANS_SINE)
	if is_instance_valid(pie):
		# Пицца едет НА НЁМ: она лежит на голове, и оставшаяся висеть в воздухе
		# читалась бы как отдельный предмет, случайно оказавшийся в кадре.
		var tw3 := pie.create_tween()
		tw3.tween_interval(0.40)
		tw3.tween_property(pie, "position:y", pie.position.y - 46.0, 0.0)
		tw3.tween_property(pie, "position:x", -BOSS_PX, 1.6).set_trans(Tween.TRANS_SINE)
	await lift.finished

# Кто понесёт: ближние к телу. Отбираются по расстоянию, а не по номеру в
# массиве — иначе носильщиками стали бы первые созданные, то есть случайные
# люди с другого края арены.
func _pick_carriers(at: Vector2, n: int) -> Array:
	var alive : Array = []
	for e in _crowd:
		if is_instance_valid(e):
			alive.append(e)
	alive.sort_custom(func(a, b):
		return (a as Node2D).position.distance_to(at) \
			< (b as Node2D).position.distance_to(at))
	return alive.slice(0, mini(n, alive.size()))

# Пицца, падающая на побеждённого. Своя, а не потоковая: у потоковой светлая
# заливка без обводки, и на боссе она читается пятном. Грузится ПО ПУТИ и с
# откатом — пока файла нет, финал играет обычной пиццей и ничего не ломается.
const PIZZA_VICTORY_PATH : String = "res://assets/bosses/leatherhead/pizza_face.png"
const PIZZA_STREAM_TEX   := preload("res://assets/items/pizza.png")
const PIZZA_ON_HEAD_PX   : float = 88.0
const KING_FALL_T        : float = 0.55
# Слой пиццы. Отдельным числом, а не «на единицу выше кулака»: кулаков теперь два
# слоя, и на общем с верхним из них пицца путалась бы с рукой — и на экране, и в
# тесте, который ищет их обоих по слою.
const PIZZA_Z            : int   = 60

func _victory_pizza_tex() -> Texture2D:
	if ResourceLoader.exists(PIZZA_VICTORY_PATH):
		var t = load(PIZZA_VICTORY_PATH)
		if t != null:
			return t
	return PIZZA_STREAM_TEX

func _finish() -> void:
	_running = false
	current_wave = "done"
	_drop_bars()
	_clear_foe()
	var hud := _game_root.get_node_or_null("HUD")
	if hud != null and hud.has_method("hide_run_hud_for_boss"):
		hud.call("hide_run_hud_for_boss", false)
	var bg := _game_root.get_node_or_null("Background")
	# Тема уровня возвращается: гасили её на входе в бой (см. `_run_boss`).
	var game_music := _game_root.get_node_or_null("Music")
	if is_instance_valid(game_music) and game_music.has_method("start"):
		game_music.call("start")
	_release_hero()
	if boss_test_mode:
		# Дев-вызов: вернуть забег в рабочее состояние. Через `force_resume`, а не
		# записью в поле — заморозка считается (см. spawner.pause_for_event).
		if is_instance_valid(_spawner) and _spawner.has_method("force_resume"):
			_spawner.call("force_resume")
			_spawner.set("_pattern_running", false)
			_spawner.set_process(true)
		if is_instance_valid(bg) and bg.has_method("start_scrolling"):
			bg.call("start_scrolling")
		queue_free()
		return
	defeated.emit()
	queue_free()
