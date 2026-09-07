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
const CROWD_COUNT  : int   = 26      # сколько бомжей в овале
const CROWD_PX     : float = 54.0    # рост рядового в толпе
const CROWD_PAD_X  : float = 0.10    # отступ овала от краёв экрана, доли
const CROWD_PAD_Y  : float = 0.14
const CROWD_Z      : int   = 8       # за бойцами, но перед фоном

# Мелкие облачка над толпой. Это ГУЛ, а не реплики: короткие, без хвостов, по
# одному в случайном месте раз в секунду с небольшим. Читать их не надо — надо
# слышать, что вокруг орут.
const SHOUTS : Array = ["ДАВАЙ!", "БЕЙ!", "ДЕРЖИСЬ!", "ВАЛИ ЕГО!", "ЭЙ!", "У-У-У!"]
const SHOUT_EVERY : float = 1.10
const SHOUT_LIFE  : float = 1.30

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

func _alive() -> bool:
	return is_instance_valid(self) and is_instance_valid(_normaldo) \
		and is_instance_valid(_game_root)

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
	var rx : float = vp.x * (0.5 - CROWD_PAD_X)
	var ry : float = vp.y * (0.5 - CROWD_PAD_Y)
	for i in CROWD_COUNT:
		var a : float = TAU * float(i) / float(CROWD_COUNT)
		var s := Sprite2D.new()
		s.texture        = CROWD_TEX[i % CROWD_TEX.size()]
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var px : float = CROWD_PX * randf_range(0.85, 1.15)
		s.scale          = Vector2.ONE * (px / maxf(1.0, s.texture.get_size().y))
		s.position       = Vector2(cx + cos(a) * rx, cy + sin(a) * ry)
		s.z_index        = CROWD_Z
		# Нижние — крупнее и поверх: они ближе к зрителю.
		if sin(a) > 0.0:
			s.scale   *= 1.15
			s.z_index += 1
		add_child(s)
		_crowd.append(s)
		# Каждый качается по-своему. Общая анимация на всю толпу читалась бы как
		# дрожащая картинка, а не как двадцать шесть человек.
		var tw := s.create_tween().set_loops()
		var dy : float = randf_range(3.0, 8.0)
		var t  : float = randf_range(0.5, 1.1)
		tw.tween_property(s, "position:y", s.position.y + dy, t)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(s, "position:y", s.position.y, t)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _shout() -> void:
	if _crowd.is_empty():
		return
	var who : Sprite2D = _crowd[randi() % _crowd.size()]
	if not is_instance_valid(who):
		return
	var l := Label.new()
	l.add_theme_font_override("font", UI_FONT)
	l.add_theme_font_size_override("font_size", 11)
	l.add_theme_color_override("font_color", Color(0.10, 0.09, 0.07))
	l.text                 = String(SHOUTS[randi() % SHOUTS.size()])
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
	var hero_n : int = _hero_lives()
	var bw : float = float(KING_HP) * BAR_SEG_W + float(KING_HP - 1) * BAR_GAP
	var hw : float = float(hero_n) * BAR_SEG_W + float(maxi(0, hero_n - 1)) * BAR_GAP
	var total : float = bw + BAR_MID_GAP + hw
	var x0 : float = (vp.x - total) * 0.5
	_boss_segs = _make_bar(Vector2(x0, BAR_Y), KING_HP, Color(0.85, 0.30, 0.26))
	_hero_segs = _make_bar(Vector2(x0 + bw + BAR_MID_GAP, BAR_Y), hero_n,
		Color(0.35, 0.80, 0.45))

func _hero_lives() -> int:
	# Жизни Нормальдо — это его жир: на нуле следующий удар убивает. Отдельного
	# счётчика здесь нет и быть не должно — второй счётчик тех же жизней разошёлся
	# бы с настоящим в первый же неучтённый удар.
	if not is_instance_valid(_normaldo):
		return 1
	return maxi(1, int(_normaldo.get("fat_state")) + 1)

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

func _spawn_foe(tex: Texture2D, px: float, tint: Color) -> void:
	_clear_foe()
	_foe_sprite = Sprite2D.new()
	_foe_sprite.texture        = tex
	_foe_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_foe_sprite.scale          = Vector2.ONE * (px / maxf(1.0, tex.get_size().y))
	_foe_sprite.modulate       = tint
	_foe_sprite.position       = Vector2(_foe_x, _fight_y)
	_foe_sprite.z_index        = 30
	add_child(_foe_sprite)
	# Выходит ИЗ ТОЛПЫ: приезжает справа, а не появляется на месте. Возникший из
	# воздуха противник читался бы как подмена картинки.
	var tw := _foe_sprite.create_tween()
	_foe_sprite.position.x = get_viewport_rect().size.x + px
	tw.tween_property(_foe_sprite, "position:x", _foe_x, 0.55)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

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
		_shout()
	if not _running:
		return
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
	if is_instance_valid(_normaldo) and _normaldo.has_method("_take_hit"):
		_normaldo.call("_take_hit", 1)
	_burn(_hero_segs, maxi(0, _hero_lives() - 1))

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

# ── Волна 1: серый бомж ──────────────────────────────────────────────────────
# Учит одному: тап = удар. НЕ БЬЁТ ВООБЩЕ — не «редко». Первая же плюха на
# обучении означала бы, что игрок выучил не «тап бьёт», а «тапать опасно».
func _wave_grey() -> void:
	current_wave = "grey"
	foe_hp = 1
	_spawn_foe(CROWD_TEX[0], FOE_PX, Color(0.62, 0.62, 0.66))
	_caption("БЕЙ!", Color(0.75, 1.00, 0.80))
	await _await_foe_down()

# ── Волна 2: рыжий бомж ──────────────────────────────────────────────────────
# Учит блоку. Не бьёт первым НИКОГДА — только отвечает на твой удар, и отвечает
# по порядку: первый размен уходит в блок, второй попадает.
#
# Порядок именно такой. Наоборот игрок выучил бы «рыжий бьёт», а не «рыжий
# отвечает», и блок остался бы случайностью, которую он однажды увидел.
# Время полёта кулака от головы до головы. СЧИТАЕТСЯ, а не выписано числом:
# именно от него зависит, чем кончится размен, и разъехавшись с реальностью оно
# молча отменяет либо блок, либо попадание.
func fist_flight_time() -> float:
	return maxf(0.05, (_foe_x - _hero_x - HEAD_R * 2.0) / FIST_SPEED)

# Ответ ПОЧТИ ОДНОВРЕМЕННО — кулаки встречаются примерно посередине, это блок.
const GINGER_ANSWER_DELAY : float = 0.02
# Ответ ЗАВЕДОМО ПОЗЖЕ полёта: твой кулак к этому моменту уже воткнулся и
# отдёргивается, встречать его нечем — этот доедет. Множитель, а не число: с
# другой скоростью кулака или другой шириной арены число промахнулось бы.
const GINGER_LATE_MULT : float = 1.35

var _ginger_answers : int = 0

func _wave_ginger() -> void:
	current_wave = "ginger"
	foe_hp = 1
	_ginger_answers = 0
	_spawn_foe(CROWD_TEX[1], FOE_PX, Color(1.00, 0.72, 0.42))
	await _await_foe_down()

# ── Волна 3: сам босс ────────────────────────────────────────────────────────
# Пять ХП, и с каждым потерянным он ЗЛЕЕ: пауза между ударами короче. Пять
# ступеней сложности вместо пяти одинаковых попаданий.
const KING_GAP_START : float = 2.30
const KING_GAP_END   : float = 0.95

func king_gap() -> float:
	var lost : float = float(KING_HP - king_hp) / float(maxi(1, KING_HP - 1))
	return lerpf(KING_GAP_START, KING_GAP_END, clampf(lost, 0.0, 1.0))

func _wave_king() -> void:
	current_wave = "king"
	king_hp = KING_HP
	_burn(_boss_segs, king_hp)
	_spawn_foe(F_IDLE, BOSS_PX, Color.WHITE)
	_caption("СТАРЫЙ ПИРАТ", Color(1.00, 0.85, 0.40))
	HAPTICS.buzz(HAPTICS.BOSS)
	var t := 0.0
	while _alive() and _running and king_hp > 0:
		await get_tree().process_frame
		if not _alive():
			return
		t += get_process_delta_time()
		# Движется рвано: короткие рывки по вертикали вокруг своей линии. Ровное
		# скольжение читалось бы как «стоит», а он должен выглядеть неудобной
		# целью.
		if is_instance_valid(_foe_sprite):
			_foe_sprite.position.y = _fight_y + sin(t * 3.1) * 26.0 \
				+ sin(t * 7.7) * 8.0 * (1.0 + float(KING_HP - king_hp) * 0.25)
		if t >= king_gap():
			t = 0.0
			foe_punch()
			# Кадр возвращается к «скалится» сразу после замаха: нахмуренность
			# это телеграф удара, а не постоянное выражение лица.
			if is_instance_valid(_foe_sprite):
				var s := _foe_sprite
				get_tree().create_timer(0.35).timeout.connect(func():
					if is_instance_valid(s):
						s.texture = F_IDLE, CONNECT_ONE_SHOT)
	_drop_foe()

# Ждать, пока текущий рядовой не кончится. Рыжий отвечает отсюда же: ответ —
# это реакция на ТВОЙ удар, и место ему там, где удар и виден.
func _await_foe_down() -> void:
	# Слепок берётся ПО ТОЙ ЖЕ ВЕЛИЧИНЕ, по которой потом сравнивается. Возьми
	# другую — и рыжий выйдет в мир, где счётчик уже больше слепка, и ответит на
	# удар, которого не было, в первый же кадр. На экране это читается как «рыжий
	# бьёт первым», то есть ровно наоборот тому, чему волна заведена учить.
	var seen : int = punches
	while _alive() and _running and foe_hp > 0:
		await get_tree().process_frame
		if not _alive():
			return
		if current_wave == "ginger" and punches > seen:
			seen = punches
			_ginger_answers += 1
			var delay : float = GINGER_ANSWER_DELAY if _ginger_answers == 1 \
				else fist_flight_time() * GINGER_LATE_MULT
			get_tree().create_timer(delay).timeout.connect(foe_punch, CONNECT_ONE_SHOT)
	_drop_foe()
	await get_tree().create_timer(0.5).timeout

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
