extends Node2D

# ── Босс — Старый пират (король бомжей) ──────────────────────────────────────
# Босс третьего эпизода. Полное описание — /Концепция/Босс — Старый пират.md
#
# ── Чем он отличается от всех прежних ────────────────────────────────────────
# Крокодил, ниндзя и хозяин клуба спрашивали одно и то же: «успеешь ли уйти с
# линии». Игрок двигался и уворачивался — ровно как весь забег до боя, только
# быстрее.
#
# Этот спрашивает обратное: успеешь ли ты НЕ УДАРИТЬ. Нормальдо приклеен к
# месту, толпа сомкнулась, уходить некуда, спелл не работает. Единственное
# действие — кулак, и весь бой в том, когда его НЕ выпускать.
#
# ── Почему столкновения считаются вручную, а не физикой ──────────────────────
# Кулаки — не предметы потока: они летят по одной горизонтали навстречу друг
# другу и обязаны разрешаться ТРЕМЯ исходами (попал / получил / блок), причём
# блок это когда «оба одновременно». Физика Godot решает такие ничьи порядком
# сигналов area_entered, то есть случайно, — и блок то срабатывал бы, то нет.
# Здесь же кадр считает пересечение отрезков сам, и ничья остаётся ничьёй.
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

# Кулак Нормальдо — ТОТ ЖЕ, что у Викинга. Зелёный, крупный, уже нарисован и уже
# означает в этой игре «удар». Рисовать второй кулак значило бы завести второй
# язык для одного и того же.
const F_PLAYER_FIST := preload("res://assets/skills/viking/fist.png")

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
const CROWD_RINGS  : Array = [
	# [доля радиуса, сколько в кольце, множитель роста]
	[1.00, 30, 1.15],   # внешнее — крупные, ближе к зрителю
	[0.88, 26, 1.00],
	[0.76, 22, 0.88],   # дальние — мельче, уходят в глубину
]
const CROWD_PX     : float = 54.0    # рост рядового в толпе
const CROWD_PAD_X  : float = 0.02    # отступ овала от краёв экрана, доли
const CROWD_PAD_Y  : float = 0.04
const CROWD_Z      : int   = 8       # за бойцами, но перед фоном
# Разброс каждого от его места в кольце. Без него кольца читаются кольцами;
# с ним — толпой.
const CROWD_JITTER : float = 16.0

# ── СЦЕНА БОЯ — СВОБОДНА ─────────────────────────────────────────────────────
# Плотная толпа первым делом залезла внутрь и встала поверх Нормальдо и его
# противника: кольца считаются от центра экрана, а бой идёт ровно там же. На
# кадре это читалось не как «толпа вокруг», а как «в кадре каша».
#
# Поэтому вокруг линии боя держится пустая полоса, и всякий, кто попал в неё,
# выталкивается ПО ВЕРТИКАЛИ наружу — вверх или вниз, куда ближе. По вертикали,
# а не по радиусу: толпа обязана остаться замкнутой, а радиальный выброс
# проделал бы в ней дыры ровно там, где стоят бойцы.
const ARENA_HALF_H : float = 96.0    # полувысота свободной полосы
const ARENA_PAD_X  : float = 110.0   # запас слева от героя и справа от врага

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

# Где стоят бойцы. Нормальдо в левой части овала, противник — в правой.
const HERO_X_RATIO : float = 0.30
const FOE_X_RATIO  : float = 0.72
const FIGHT_Y_RATIO: float = 0.52

# ── Кулаки ───────────────────────────────────────────────────────────────────
const FIST_PX     : float = 84.0
const FIST_SPEED  : float = 900.0   # px/с, туда и обратно
const FIST_Z      : int   = 45

# Перезарядка удара. Без неё бой — мэшинг, а весь его смысл в паузе ПЕРЕД
# ударом: тапнув вхолостую, ты остаёшься без кулака ровно тогда, когда он нужен.
const PUNCH_CD    : float = 0.85

# Головы. Радиусы условные — драка идёт по одной горизонтали, и «попал» тут
# значит «кулак доехал до головы», а не «пересеклись окружности».
const HEAD_R      : float = 34.0

const BOSS_PX     : float = 210.0
const FOE_PX      : float = 120.0   # рядовой из волн 1–2

# ── Полосы ХП ────────────────────────────────────────────────────────────────
const BAR_SEG_W   : float = 22.0
const BAR_SEG_H   : float = 12.0
const BAR_GAP     : float = 4.0
# Ниже верхней полосы забега (счётчики и таймер занимают первые ~30 px).
const BAR_Y       : float = 38.0
# Просвет между его полосой и твоей: без него десять сегментов подряд читались
# бы как одна полоса на двоих.
const BAR_MID_GAP : float = 46.0
const BAR_Z       : int   = 90

const KING_HP     : int = 5
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
var _foe_x       : float = 0.0
var _fight_y     : float = 0.0
var _hero_x      : float = 0.0

# Кулак в полёте: null или словарь {node, x, dir, retract}. Словарь, а не узел с
# полями: считает их всё равно `_process`, и держать состояние рядом с ним
# короче и виднее.
var _p_fist : Dictionary = {}
var _e_fist : Dictionary = {}
var _p_cd   : float = 0.0

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
	_foe_x   = vp.x * FOE_X_RATIO

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

	_build_crowd()
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
			# Каждый качается по-своему. Общая анимация на всю толпу выглядела бы
			# как дрожащая картинка, а не как восемь десятков человек.
			var tw := s2.create_tween().set_loops()
			var dy : float = randf_range(3.0, 8.0)
			var t  : float = randf_range(0.5, 1.1)
			tw.tween_property(s2, "position:y", s2.position.y + dy, t)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			tw.tween_property(s2, "position:y", s2.position.y, t)\
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

# Полоса боя — от героя до места, где встаёт противник, с запасом по краям.
# Считается по живым координатам, а не по числам: сдвинь бойцов, и дыра в толпе
# переедет за ними сама.
func _arena_rect() -> Rect2:
	var x0 : float = minf(_hero_x, get_viewport_rect().size.x * FOE_STOP_X_RATIO)
	var x1 : float = maxf(_hero_x, get_viewport_rect().size.x * FOE_STOP_X_RATIO)
	return Rect2(x0 - ARENA_PAD_X, _fight_y - ARENA_HALF_H,
		(x1 - x0) + ARENA_PAD_X * 2.0, ARENA_HALF_H * 2.0)

func _push_out_of_arena(p: Vector2) -> Vector2:
	var r := _arena_rect()
	if not r.has_point(p):
		return p
	# Куда ближе — вверх или вниз. Выталкивание всегда в одну сторону сложило бы
	# всех вытесненных в одну кучу над ареной.
	var up   : float = p.y - r.position.y
	var down : float = r.end.y - p.y
	if up < down:
		return Vector2(p.x, r.position.y - randf_range(4.0, 26.0))
	return Vector2(p.x, r.end.y + randf_range(4.0, 26.0))

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
	l.size                 = Vector2(84.0, 20.0)
	l.mouse_filter         = Control.MOUSE_FILTER_IGNORE

	var bub := Panel.new()
	bub.add_theme_stylebox_override("panel",
		UiKit.rounded(Color(0.96, 0.94, 0.86, 0.95), 8,
			Color(0.35, 0.30, 0.22, 0.9), 1))
	bub.size         = l.size
	bub.position     = who.position + Vector2(-42.0, -CROWD_PX * 0.95)
	bub.z_index      = CROWD_Z + 3
	bub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bub.add_child(l)
	add_child(bub)

	var tw := bub.create_tween()
	tw.tween_property(bub, "position:y", bub.position.y - 12.0, SHOUT_LIFE)
	tw.parallel().tween_property(bub, "modulate:a", 0.0, SHOUT_LIFE)\
		.set_delay(SHOUT_LIFE * 0.55)
	tw.tween_callback(bub.queue_free)

# ── Нормальдо приклеен ───────────────────────────────────────────────────────
# Не «управление отключено», а «тебя не пускают»: свайп сдвигает на несколько
# пикселей и отпускает пружиной. Разница читается сразу — отключённое управление
# ощущается поломкой, а пружина объясняет себя сама.
func _lock_hero() -> void:
	if not is_instance_valid(_normaldo):
		return
	_normaldo.position = Vector2(_hero_x, _fight_y)
	if _normaldo.has_method("disable_input"):
		_normaldo.call("disable_input")
	if _normaldo.has_method("set_spells_blocked"):
		_normaldo.call("set_spells_blocked", true)
	_build_cd_bar()

# ── Полоска перезарядки ──────────────────────────────────────────────────────
# Под Нормальдо и узкая. Перезарядка без индикатора — это правило, которое игрок
# может только УГАДАТЬ: тапнул, ничего не вылетело, и непонятно, промахнулся ты
# по кнопке или кулак ещё не вернулся. Пауза перед ударом — весь смысл боя, и
# видеть её надо.
const CD_W : float = 74.0
const CD_H : float = 7.0
const CD_DY: float = 58.0

var _cd_fill : ColorRect = null

func _build_cd_bar() -> void:
	var back := ColorRect.new()
	back.color    = Color(0.06, 0.05, 0.04, 0.85)
	back.size     = Vector2(CD_W + 4.0, CD_H + 4.0)
	back.position = Vector2(_hero_x - CD_W * 0.5 - 2.0, _fight_y + CD_DY - 2.0)
	back.z_index  = FIST_Z + 1
	add_child(back)
	_cd_fill = ColorRect.new()
	_cd_fill.color    = Color(0.40, 0.85, 0.50, 0.95)
	_cd_fill.size     = Vector2(CD_W, CD_H)
	_cd_fill.position = Vector2(_hero_x - CD_W * 0.5, _fight_y + CD_DY)
	_cd_fill.z_index  = FIST_Z + 2
	add_child(_cd_fill)

func _update_cd_bar() -> void:
	if not is_instance_valid(_cd_fill):
		return
	var ready : float = 1.0 - clampf(_p_cd / PUNCH_CD, 0.0, 1.0)
	_cd_fill.size.x = CD_W * ready
	# Цветом тоже: полная полоса зелёная, набирающаяся — тусклая. Одной длины
	# мало, когда смотришь не на неё, а на кулаки.
	_cd_fill.color = Color(0.40, 0.85, 0.50, 0.95) if ready >= 1.0 \
		else Color(0.70, 0.62, 0.30, 0.85)

# ── Арена выталкивает ────────────────────────────────────────────────────────
# Не «управление отключено», а «тебя не пускают». Разница читается сразу:
# отключённое управление ощущается поломкой, а пружина объясняет себя сама —
# ты дёрнулся, толпа вернула на место.
#
# Сдвиг МАЛЕНЬКИЙ и всегда возвращается: сделай его больше — и это станет
# движением, то есть тем самым уворотом, которого в этом бою нет.
const PUSH_PX   : float = 9.0
const PUSH_BACK : float = 0.22

func _nudge_hero(dir: Vector2) -> void:
	if not is_instance_valid(_normaldo) or dir.length() < 0.01:
		return
	var home := Vector2(_hero_x, _fight_y)
	var to := home + dir.normalized() * PUSH_PX
	var tw := _normaldo.create_tween()
	tw.tween_property(_normaldo, "position", to, 0.06)
	tw.tween_property(_normaldo, "position", home, PUSH_BACK)\
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func _release_hero() -> void:
	if not is_instance_valid(_normaldo):
		return
	if _normaldo.has_method("set_spells_blocked"):
		_normaldo.call("set_spells_blocked", false)
	if _normaldo.has_method("enable_input"):
		_normaldo.call("enable_input")

# ── Интро ────────────────────────────────────────────────────────────────────
const SPEECH : String = "Моя набережная, парень.\nПокажи, что у тебя в руках."

func _intro() -> void:
	current_wave = "intro"
	await BOSS_SPEECH.show(self, _game_root, SPEECH, BOSS_PX,
		Color(0.16, 0.13, 0.09, 0.96), Color(0.85, 0.72, 0.35, 0.95),
		Color(1.00, 0.95, 0.82))
	SCREEN_SHAKE.play(_game_root, 12.0, 8)

# ── Полосы ХП ────────────────────────────────────────────────────────────────
# СЕГМЕНТАМИ, а не заливкой: сегмент = удар, и «сколько осталось» читается
# счётом. Заливка на пяти хитах превратила бы каждый в незаметный шаг на 20 %.
#
# Полоса босса стоит ВЕСЬ БОЙ, а не появляется на третьей волне: волны 1 и 2
# занимают её первый сегмент по очереди. Иначе интерфейс менялся бы посреди боя.
func _build_bars() -> void:
	_bars_root = CanvasLayer.new()
	_bars_root.layer = BAR_Z
	_game_root.add_child(_bars_root)
	var vp := get_viewport_rect().size
	# ПО ЦЕНТРУ И НИЖЕ ВЕРХНЕЙ ПОЛОСЫ ЗАБЕГА. Интерфейс забега на боссах
	# остаётся (см. hud.gd: игрок должен видеть свой жир и уметь поставить
	# паузу), и углы экрана заняты: слева пауза, счётчики и стопка резистов,
	# справа таймер. Полосы, поставленные в углы, легли ровно под них — на первом
	# же кадре было видно, что боссовой не видно вовсе.
	var hero_n : int = HERO_HP
	var bw : float = float(KING_HP) * BAR_SEG_W + float(KING_HP - 1) * BAR_GAP
	var hw : float = float(hero_n) * BAR_SEG_W + float(maxi(0, hero_n - 1)) * BAR_GAP
	var total : float = bw + BAR_MID_GAP + hw
	var x0 : float = (vp.x - total) * 0.5
	_boss_segs = _make_bar(Vector2(x0, BAR_Y), KING_HP, Color(0.85, 0.30, 0.26))
	_hero_segs = _make_bar(Vector2(x0 + bw + BAR_MID_GAP, BAR_Y), hero_n,
		Color(0.35, 0.80, 0.45))


func _make_bar(at: Vector2, n: int, col: Color) -> Array:
	var out : Array = []
	for i in n:
		var p := Panel.new()
		p.add_theme_stylebox_override("panel",
			UiKit.rounded(col, 3, Color(0.05, 0.04, 0.03, 0.9), 1))
		p.position     = at + Vector2(float(i) * (BAR_SEG_W + BAR_GAP), 0.0)
		p.size         = Vector2(BAR_SEG_W, BAR_SEG_H)
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

# Куда противник в итоге встаёт — НА РАССТОЯНИЕ УДАРА, и ни шагом ближе.
# Вплотную подошедший противник закрыл бы собой и Нормальдо, и оба кулака; на
# дистанции удара видно всё, ради чего этот бой и сделан.
const FOE_STOP_X_RATIO : float = 0.70
# Скорость подхода. Медленно: он ПРЕСЛЕДУЕТ, а не выпрыгивает — идти на игрока
# страшнее, чем возникнуть перед ним.
const FOE_WALK : float = 150.0

var _foe_target_x : float = 0.0
var _foe_walking  : bool  = false

func _spawn_foe(tex: Texture2D, px: float, tint: Color) -> void:
	_clear_foe()
	_foe_sprite = Sprite2D.new()
	_foe_sprite.texture        = tex
	_foe_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_foe_sprite.scale          = Vector2.ONE * (px / maxf(1.0, tex.get_size().y))
	_foe_sprite.modulate       = tint
	_foe_sprite.z_index        = 30
	# ВЫХОДИТ ИЗ ТОЛПЫ И ИДЁТ НА ТЕБЯ. Прежняя версия подъезжала твином за
	# полсекунды и вставала — это читалось как «его поставили», а не как «он
	# пошёл». Теперь он шагает своим ходом (см. `_walk_foe`) и тормозит ровно на
	# дистанции удара.
	_foe_target_x = get_viewport_rect().size.x * FOE_STOP_X_RATIO
	_foe_x        = get_viewport_rect().size.x + px * 0.5
	_foe_sprite.position = Vector2(_foe_x, _fight_y)
	_foe_walking  = true
	add_child(_foe_sprite)

# Шаг подхода. `_foe_x` — ЖИВАЯ координата противника, и попадания считаются по
# ней: кулак, брошенный пока тот ещё идёт, обязан не долететь.
func _walk_foe(delta: float) -> void:
	if not _foe_walking or not is_instance_valid(_foe_sprite):
		return
	_foe_x = maxf(_foe_target_x, _foe_x - FOE_WALK * delta)
	# Вразвалку: шаг читается по покачиванию, а ровно едущая голова выглядит
	# как спрайт на рельсах.
	_foe_sprite.position = Vector2(_foe_x,
		_fight_y + sin(_foe_x * 0.06) * 5.0)
	if is_equal_approx(_foe_x, _foe_target_x):
		_foe_walking = false
		_foe_sprite.position = Vector2(_foe_x, _fight_y)

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
	var tw := s.create_tween()
	tw.tween_property(s, "position:y", s.position.y + 260.0, 0.45)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(s, "rotation", 1.4, 0.45)
	tw.tween_callback(s.queue_free)

# ── Кулаки ───────────────────────────────────────────────────────────────────

func _make_fist(tex: Texture2D, from_x: float, dir: int) -> Dictionary:
	var s := Sprite2D.new()
	s.texture        = tex
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.scale          = Vector2.ONE * (FIST_PX / maxf(1.0, tex.get_size().x))
	s.flip_h         = dir < 0
	s.position       = Vector2(from_x, _fight_y)
	s.z_index        = FIST_Z
	add_child(s)
	return { "node": s, "x": from_x, "dir": dir, "retract": false }

# Тап = удар. ЭТОТ ЖЕ ЖЕСТ в обычном забеге кастует спелл, и потому спелл здесь
# заблокирован: два действия на один жест — это не глубина, а промах.
func punch() -> void:
	if not _running or _p_cd > 0.0 or not _p_fist.is_empty():
		return
	_p_cd    = PUNCH_CD
	punches += 1
	_p_fist  = _make_fist(F_PLAYER_FIST, _hero_x + HEAD_R, 1)

func _input(event: InputEvent) -> void:
	if not _running:
		return
	# Свайп НЕ двигает, а упирается: Нормальдо дёргается на несколько пикселей и
	# возвращается пружиной. Молча проглоченный свайп читался бы как «игра не
	# поняла», и игрок пробовал бы снова вместо того, чтобы драться.
	if event is InputEventScreenDrag:
		_nudge_hero((event as InputEventScreenDrag).relative)
		return
	if event is InputEventMouseMotion \
			and (event as InputEventMouseMotion).button_mask != 0:
		_nudge_hero((event as InputEventMouseMotion).relative)
		return
	var pressed := (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed) \
		or (event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT)
	if pressed:
		punch()

# Удар противника. Публичный: им пользуются волны и тест.
func foe_punch() -> void:
	if not _running or not _e_fist.is_empty() or not is_instance_valid(_foe_sprite):
		return
	# Нахмуренный кадр — РОВНО на его удар. Это его телеграф: у босса нет ни
	# ленты, ни прицела, и предупреждает он лицом.
	if current_wave == "king":
		_foe_sprite.texture = F_FROWN
	_e_fist = _make_fist(F_FIST, _foe_x - HEAD_R, -1)

func _process(delta: float) -> void:
	if _p_cd > 0.0:
		_p_cd = maxf(0.0, _p_cd - delta)
	_update_cd_bar()
	_shout_t += delta
	if _shout_t >= SHOUT_EVERY:
		_shout_t = 0.0
		for i in SHOUT_AT_ONCE:
			_shout()
	if not _running:
		return
	_walk_foe(delta)
	_advance(_p_fist, delta)
	_advance(_e_fist, delta)
	_resolve()

func _advance(f: Dictionary, delta: float) -> void:
	if f.is_empty():
		return
	f["x"] = float(f["x"]) + FIST_SPEED * delta * (float(f["dir"]) * (-1.0 if f["retract"] else 1.0))
	var s : Sprite2D = f["node"]
	if is_instance_valid(s):
		s.position.x = float(f["x"])

# Один кадр разбора. ПОРЯДОК ЗДЕСЬ И ЕСТЬ ПРАВИЛО: сперва ничья, потом
# попадания. Проверь попадания первыми — и размен, в котором оба доехали в один
# кадр, разрешился бы в пользу того, чья строка стоит выше, то есть блока не
# было бы никогда.
func _resolve() -> void:
	if not _p_fist.is_empty() and not _e_fist.is_empty() \
			and not bool(_p_fist["retract"]) and not bool(_e_fist["retract"]) \
			and float(_p_fist["x"]) + FIST_PX * 0.5 >= float(_e_fist["x"]) - FIST_PX * 0.5:
		_block()
		return
	if not _p_fist.is_empty() and not bool(_p_fist["retract"]) \
			and float(_p_fist["x"]) >= _foe_x - HEAD_R:
		_land_on_foe()
	# Кулак, брошенный в подходящего издалека, не висит в воздухе вечно: дойдя до
	# места, где противник ВСТАНЕТ, он отдёргивается. Иначе он ждал бы там, пока
	# тот сам не наткнётся, и промах превращался бы в бесплатное попадание.
	if not _p_fist.is_empty() and not bool(_p_fist["retract"]) \
			and float(_p_fist["x"]) >= _foe_target_x - HEAD_R:
		_p_fist["retract"] = true
	if not _e_fist.is_empty() and not bool(_e_fist["retract"]) \
			and float(_e_fist["x"]) <= _hero_x + HEAD_R:
		_land_on_hero()
	_retire(_p_fist)
	_retire(_e_fist)

# Улетевший обратно к хозяину кулак убирается. Возвращаются они всегда — кулак,
# исчезнувший в момент удара, читался бы как «пропал», а не как «отдёрнул руку».
func _retire(f: Dictionary) -> void:
	if f.is_empty() or not bool(f["retract"]):
		return
	var home : float = (_hero_x if int(f["dir"]) > 0 else _foe_x)
	if absf(float(f["x"]) - home) <= HEAD_R + 2.0:
		var s : Sprite2D = f["node"]
		if is_instance_valid(s):
			s.queue_free()
		f.clear()

func _block() -> void:
	blocks += 1
	# Кулаки ПАДАЮТ, как сбитый предмет. Отдёрнутые назад читались бы как «оба
	# передумали», а падение говорит «столкнулись» на языке, который в этой игре
	# уже есть.
	for f in [_p_fist, _e_fist]:
		var s : Sprite2D = f["node"]
		if is_instance_valid(s):
			var tw := s.create_tween()
			tw.tween_property(s, "position:y", s.position.y + 220.0, 0.42)\
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw.parallel().tween_property(s, "rotation", randf_range(-1.6, 1.6), 0.42)
			tw.tween_callback(s.queue_free)
	_p_fist = {}
	_e_fist = {}
	_p_cd   = PUNCH_CD
	_caption("БЛОК!", Color(1.00, 0.92, 0.55))
	SCREEN_SHAKE.play(_game_root, 7.0, 5)

func _land_on_foe() -> void:
	hits_dealt += 1
	_p_fist["retract"] = true
	if current_wave == "king":
		king_hp = maxi(0, king_hp - 1)
		_burn(_boss_segs, king_hp)
	else:
		foe_hp = maxi(0, foe_hp - 1)
		_burn(_boss_segs, KING_HP if foe_hp > 0 else KING_HP - 1)
	if is_instance_valid(_foe_sprite):
		var tw := _foe_sprite.create_tween()
		tw.tween_property(_foe_sprite, "position:x", _foe_x + 26.0, 0.07)
		tw.tween_property(_foe_sprite, "position:x", _foe_x, 0.14)
	SCREEN_SHAKE.play(_game_root, 11.0, 7)

func _land_on_hero() -> void:
	hits_taken += 1
	_e_fist["retract"] = true
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
	l.position             = Vector2(0.0, BAR_Y + BAR_SEG_H + 10.0)
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
# Учит одному: тап = удар. Выходит из толпы и ИДЁТ на тебя, тормозя на дистанции
# удара. НЕ БЬЁТ ВООБЩЕ — не «редко»: первая же плюха на обучении означала бы,
# что игрок выучил не «тап бьёт», а «тапать опасно». 1 ХП.
func _wave_grey() -> void:
	current_wave = "grey"
	foe_hp = 1
	# homeless2 — СЕРЫЙ (homeless1 рыжий). Первым выходит именно серый, и путать
	# их местами нельзя: цвет — единственное, чем волны различаются на вид.
	_spawn_foe(CROWD_TEX[1], FOE_PX, Color.WHITE)
	_caption("БЕЙ!", Color(0.75, 1.00, 0.80))
	await _await_foe_down()

# ── Волна 2: РЫЖИЙ бомж ──────────────────────────────────────────────────────
# Учит блоку. Сам не начинает никогда — ждёт твоего удара и отвечает ТУТ ЖЕ, так
# что кулаки встречаются: это блок. Второй твой удар он уже не парирует и падает.
#
# Отвечает он на ЗАМАХ, а не на попадание: ответ на попадание опаздывает ровно
# на полёт кулака, к его приходу твой уже отдёрнут, и блок в таком размене
# невозможен физически.
#
# ОТВЕЧАЕТ ОН РОВНО ОДИН РАЗ. Раньше второй ответ доезжал и бил игрока — то есть
# рядовой из обучающей волны отнимал жизнь до того, как игрок увидел настоящий
# бой. Бьёт в этом бою только король.
const GINGER_ANSWER_DELAY : float = 0.02

var _ginger_answers : int = 0

func _wave_ginger() -> void:
	current_wave = "ginger"
	foe_hp = 2          # первый размен уходит в блок, второй удар добивает
	_ginger_answers = 0
	_spawn_foe(CROWD_TEX[0], FOE_PX, Color.WHITE)
	_caption("БЛОКИРУЙ!", Color(1.00, 0.92, 0.55))
	await _await_foe_down()

# Время полёта кулака от головы до головы. СЧИТАЕТСЯ, а не выписано числом:
# именно от него зависит, чем кончится размен, и разъехавшись с реальностью оно
# молча отменяет либо блок, либо попадание.
func fist_flight_time() -> float:
	return maxf(0.05, (_foe_x - _hero_x - HEAD_R * 2.0) / FIST_SPEED)

# ── Волна 3: сам босс ────────────────────────────────────────────────────────
# Пять ХП, и с каждым потерянным он ЗЛЕЕ: пауза между ударами короче. Пять
# ступеней сложности вместо пяти одинаковых попаданий.
const KING_GAP_START : float = 2.30
const KING_GAP_END   : float = 0.95

func king_gap() -> float:
	var lost : float = float(KING_HP - king_hp) / float(maxi(1, KING_HP - 1))
	return lerpf(KING_GAP_START, KING_GAP_END, clampf(lost, 0.0, 1.0))

# Толпа объявляет его САМА — и это единственное место, где она говорит не
# подсказку, а имя. До этого выходили безымянные рядовые; теперь понятно, что
# началось.
const KING_CALL : Array = ["СТАРЫЙ ПИРАТ!", "ПОРВИ ЕГО!!", "КОРОЛЬ!", "У-У-У!!"]

func _wave_king() -> void:
	current_wave = "king"
	king_hp = KING_HP
	_burn(_boss_segs, king_hp)
	_spawn_foe(F_IDLE, BOSS_PX, Color.WHITE)
	_caption("СТАРЫЙ ПИРАТ", Color(1.00, 0.85, 0.40))
	for i in SHOUT_AT_ONCE * 2:
		_shout(KING_CALL)
	_crowd_cheer()
	HAPTICS.buzz(HAPTICS.BOSS)
	var t := 0.0
	while king_hp > 0:
		if not await _step():
			return
		t += get_process_delta_time()
		# Движется рвано: короткие рывки по вертикали вокруг своей линии. Ровное
		# скольжение читалось бы как «стоит», а он должен выглядеть неудобной
		# целью. Пока идёт — не дёргается: шаг и дёрганье разом читаются как сбой.
		if is_instance_valid(_foe_sprite) and not _foe_walking:
			_foe_sprite.position.y = _fight_y + sin(t * 3.1) * 26.0 \
				+ sin(t * 7.7) * 8.0 * (1.0 + float(KING_HP - king_hp) * 0.25)
		if t >= king_gap() and not _foe_walking:
			t = 0.0
			foe_punch()
			# Кадр возвращается к «скалится» сразу после замаха: нахмуренность
			# это телеграф удара, а не постоянное выражение лица.
			if is_instance_valid(_foe_sprite):
				var sp := _foe_sprite
				get_tree().create_timer(0.35).timeout.connect(func():
					if is_instance_valid(sp):
						sp.texture = F_IDLE, CONNECT_ONE_SHOT)
	if king_hp <= 0:
		_crowd_cheer()
	_drop_foe()

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
	var king := Sprite2D.new()
	king.texture        = F_IDLE
	king.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	king.scale          = Vector2.ONE * (BOSS_PX * 0.8 / maxf(1.0, F_IDLE.get_size().y))
	king.position       = Vector2(_foe_x, _fight_y)
	king.z_index        = 32
	add_child(king)

	var bearers : Array = []
	for i in 4:
		var b := Sprite2D.new()
		b.texture        = CROWD_TEX[i % CROWD_TEX.size()]
		b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		b.scale          = Vector2.ONE * (CROWD_PX * 1.1 / maxf(1.0, b.texture.get_size().y))
		b.position       = Vector2(_foe_x - 54.0 + float(i) * 36.0, _fight_y + 62.0)
		b.z_index        = 31
		add_child(b)
		bearers.append(b)

	# Толпа расступается: овал разъезжается к краям и гаснет.
	for e in _crowd:
		if not is_instance_valid(e):
			continue
		var c : Sprite2D = e
		var away : Vector2 = (c.position - vp * 0.5).normalized() * 240.0
		var tw : Tween = c.create_tween()
		tw.tween_property(c, "position", c.position + away, 0.8)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(c, "modulate:a", 0.0, 0.8)

	# Подняли — и понесли.
	var lift := king.create_tween()
	lift.tween_property(king, "position:y", _fight_y - 58.0, 0.45)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	lift.tween_property(king, "position:x", -BOSS_PX, 1.5)\
		.set_trans(Tween.TRANS_SINE)
	for b in bearers:
		var tw2 := (b as Sprite2D).create_tween()
		tw2.tween_interval(0.45)
		tw2.tween_property(b, "position:x", -BOSS_PX, 1.5).set_trans(Tween.TRANS_SINE)
	await lift.finished

func _finish() -> void:
	_running = false
	current_wave = "done"
	_drop_bars()
	_clear_foe()
	var hud := _game_root.get_node_or_null("HUD")
	if hud != null and hud.has_method("hide_run_hud_for_boss"):
		hud.call("hide_run_hud_for_boss", false)
	var bg := _game_root.get_node_or_null("Background")
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
