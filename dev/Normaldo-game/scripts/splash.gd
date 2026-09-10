extends CanvasLayer
class_name Splash

# ── ЗАСТАВКА ЗАПУСКА ─────────────────────────────────────────────────────────
# Системный сплеш подменить нечем — он показывается до того, как игра вообще
# запустилась, и умеет ровно одно: показать картинку. Поэтому системный сделан
# ПРОСТО ЧЁРНЫМ (project.godot → boot_splash), а настоящая заставка живёт здесь,
# уже внутри игры, и потому умеет двигаться.
#
# Такты:
#   1. По чёрному сверху вниз сыплется пицца.
#   2. Появляется логотип NORMALDO — тот же и на том же месте, что в меню.
#   3. Новая пицца сыпаться перестаёт, оставшаяся долетает.
#   4. Чёрное гаснет, и под ним оказывается обычное меню — вместе с логотипом,
#      который всё это время был на своём месте.
#
# ── ПОЧЕМУ ЛОГОТИП РИСУЕТСЯ ДВАЖДЫ ──────────────────────────────────────────
# Заставка рисует СВОЮ копию логотипа поверх чёрного и гасит её вместе с ним. За
# ней открывается настоящий логотип меню — ровно на том же месте, потому что
# место спрашивается у самого меню (`hud.menu_logo_rect`). Переход выходит без
# единого движения: с точки зрения игрока логотип просто не двигался.
#
# Двигать вместо этого настоящий логотип меню значило бы, что заставка правит
# чужой экран и обязана вернуть его как было — а не вернуть его как было можно
# ровно одним способом из десяти.
#
# ── ПОКА ЗАСТАВКА НЕ УШЛА, КНОПКИ НЕ РАБОТАЮТ ───────────────────────────────
# Не «выглядят выключенными», а не получают тапов вовсе: слой перекрывает экран
# сплошным Control, который ест ввод. Тап, случайно попавший в кнопку сквозь
# гаснущее чёрное, открыл бы экран, которого игрок не собирался открывать.

const PIZZA_TEX := preload("res://assets/items/pizza.png")

# ── ТАКТЫ ──────────────────────────────────────────────────────────────────
# Заставка целиком укладывается в три секунды. Дольше — и она из «игра
# просыпается» превращается в «игра не запускается».
const RAIN_T    : float = 1.55   # сколько сыплется новая пицца
const LOGO_AT   : float = 0.55   # когда появляется логотип
const LOGO_IN_T : float = 0.42
const DRAIN_T   : float = 0.75   # даём долететь оставшейся
const FADE_T    : float = 0.50

const SPAWN_EVERY : float = 0.055
const FALL_MIN    : float = 260.0
const FALL_MAX    : float = 480.0
const PIZZA_PX    : float = 46.0

signal finished

# ЗАСТАВКА ОДНА НА ЗАПУСК. Выход в меню перезагружает сцену целиком, и без
# этого флага она игралась бы каждый раз — то есть работала бы наказанием за
# выход из забега.
static var _played : bool = false

var _rain   : Node2D  = null
var _black  : ColorRect = null
var _logo   : TextureRect = null
var _rain_t : float   = 0.0
var _raining: bool    = false

# Заводится ТОЛЬКО на обычном запуске игры. Дев-скрипты и тесты поднимают
# `game.tscn` руками, добавляя её в корень, — у такой сцены `current_scene`
# пуст, и заставка им не мешает: иначе каждый снимок меню пришлось бы делать
# сквозь чёрное, а каждый тест — ждать её три секунды.
static func should_play(host: Node) -> bool:
	if _played or host == null or not host.is_inside_tree():
		return false
	var tree := host.get_tree()
	return tree != null and tree.current_scene == host.get_parent()

static func play(hud: Node) -> Splash:
	_played = true
	var s := Splash.new()
	s.name = "Splash"
	hud.add_child(s)
	return s

func _ready() -> void:
	layer        = 250          # выше всего, включая модалки и подсказки
	process_mode = Node.PROCESS_MODE_ALWAYS
	var vp := get_viewport().get_visible_rect().size

	# Чёрное — и оно же ЕСТ ВВОД: `MOUSE_FILTER_STOP` на весь экран.
	_black = ColorRect.new()
	_black.color        = Color(0.0, 0.0, 0.0, 1.0)
	_black.size         = vp
	_black.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_black)

	_rain = Node2D.new()
	add_child(_rain)

	_run()

func _process(delta: float) -> void:
	if not _raining:
		return
	_rain_t -= delta
	if _rain_t <= 0.0:
		_rain_t = SPAWN_EVERY
		_drop()

func _drop() -> void:
	var vp := get_viewport().get_visible_rect().size
	var s := Sprite2D.new()
	s.texture        = PIZZA_TEX
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ItemSizing.fit_sprite_content(s, PIZZA_PX * randf_range(0.75, 1.25))
	s.position = Vector2(randf_range(-20.0, vp.x + 20.0), -60.0)
	s.rotation = randf_range(-PI, PI)
	_rain.add_child(s)
	var fall : float = randf_range(FALL_MIN, FALL_MAX)
	var t : float = (vp.y + 140.0) / fall
	var tw := s.create_tween().set_parallel(true)
	tw.tween_property(s, "position:y", vp.y + 80.0, t)
	tw.tween_property(s, "rotation", s.rotation + randf_range(-6.0, 6.0), t)
	tw.chain().tween_callback(s.queue_free)

func _run() -> void:
	_raining = true
	await _wait(LOGO_AT)
	if not is_inside_tree():
		return
	_show_logo()
	await _wait(maxf(0.0, RAIN_T - LOGO_AT))
	if not is_inside_tree():
		return
	# Новая пицца перестаёт сыпаться, оставшаяся долетает сама.
	_raining = false
	await _wait(DRAIN_T)
	if not is_inside_tree():
		return
	# Чёрное и своя копия логотипа гаснут вместе — под ними ровно то же меню с
	# тем же логотипом на том же месте.
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_black, "color:a", 0.0, FADE_T)
	tw.tween_property(_rain, "modulate:a", 0.0, FADE_T)
	if is_instance_valid(_logo):
		tw.tween_property(_logo, "modulate:a", 0.0, FADE_T)
	await _wait(FADE_T)
	if not is_inside_tree():
		return
	finished.emit()
	queue_free()

# Логотип рисуется НА МЕСТЕ МЕНЮШНОГО. Если меню ещё не собрано (а такого быть
# не должно), кладём его по центру — заставка без логотипа хуже, чем логотип
# чуть не там.
func _show_logo() -> void:
	var hud := get_parent()
	var vp := get_viewport().get_visible_rect().size
	var r : Rect2 = hud.call("menu_logo_rect") if hud.has_method("menu_logo_rect") else Rect2()
	if r.size.x <= 1.0:
		var w : float = vp.x * 0.58
		r = Rect2(Vector2((vp.x - w) * 0.5, vp.y * 0.22), Vector2(w, w * 0.2))
	_logo = TextureRect.new()
	_logo.texture        = load("res://assets/ui/menu/logo.png")
	if _logo.texture == null:
		_logo.queue_free()
		_logo = null
		return
	_logo.stretch_mode   = TextureRect.STRETCH_SCALE
	_logo.expand_mode    = TextureRect.EXPAND_IGNORE_SIZE
	_logo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_logo.size           = r.size
	_logo.position       = r.position
	_logo.mouse_filter   = Control.MOUSE_FILTER_IGNORE
	_logo.pivot_offset   = r.size * 0.5
	add_child(_logo)
	# Появляется ПРОСАДКОЙ, а не проявлением: логотип должен «встать», иначе
	# заставка выглядит как медленно грузящаяся картинка.
	_logo.modulate = Color(1, 1, 1, 0.0)
	_logo.scale    = Vector2(1.18, 1.18)
	var tw := _logo.create_tween().set_parallel(true)
	tw.tween_property(_logo, "modulate:a", 1.0, LOGO_IN_T * 0.6)
	tw.tween_property(_logo, "scale", Vector2.ONE, LOGO_IN_T)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# По настенным часам: заставка идёт поверх ещё не запущенной игры, и дерево в
# этот момент бывает на паузе.
func _wait(sec: float) -> void:
	var t0 := Time.get_ticks_msec()
	while is_inside_tree() and Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		await get_tree().process_frame
