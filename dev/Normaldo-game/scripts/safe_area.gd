extends Node

# ── ОСТРОВОК, ЧЁЛКА И ПОЛОСКА «ДОМОЙ» ────────────────────────────────────────
# На айфонах с Dynamic Island часть экрана занята железом. В АЛЬБОМНОЙ
# ориентации — а игра только альбомная — островок уезжает на БОКОВОЙ край, левый
# или правый, смотря как игрок держит телефон (`window/handheld/orientation=4`,
# то есть поворот разрешён в обе стороны). Снизу к этому добавляется полоска
# «домой».
#
# Полотно игры 960 × 430 растягивается по ширине экрана целиком, поэтому под
# островком оказывается ровно тот угол, где живёт самое нужное: чип паузы,
# счётчики пиццы и долларов, стрелка «назад» на экранах.
#
# ── ПОЧЕМУ ОДИН СЛОЙ, А НЕ СЕМЬДЕСЯТ ОТСТУПОВ ────────────────────────────────
# Разметка интерфейса раскидана по десятку экранов и семидесяти с лишним местам,
# каждое из которых считает своё от `get_visible_rect().size` и прижимается к
# краю своей константой. Вносить отступ в каждое — это семьдесят шансов забыть
# одно, и ещё столько же при следующем экране.
#
# Поэтому отступ берётся не элементами, а СЛОЕМ: CanvasLayer интерфейса
# ужимается в безопасный прямоугольник целиком. Разметка внутри продолжает
# считать в тех же 960 × 430 и знать про островок не обязана.
#
# Масштаб РАВНОМЕРНЫЙ, по меньшей стороне. Ужать по-разному вдоль и поперёк —
# это овальные кружки способностей и растянутые буквы; лучше потерять процент
# размера, чем форму.
#
# ── ЧТО ОСТАЁТСЯ ВО ВЕСЬ ЭКРАН ───────────────────────────────────────────────
# Мир — фон, предметы, сам Нормальдо — живёт в Node2D, а не в этом слое, и не
# ужимается. Это намеренно: полосы должны доходить до краёв экрана, иначе по
# бокам появятся пустые поля, а предметы будут «влетать из ниоткуда» в десятке
# пикселей от края. Островок краем и заслонит — но заслонит он тот участок, где
# предмет только показывается, а не тот, где игрок принимает решение.
#
# Вспышки на весь экран (удар ниндзя, смерть) тоже остаются как есть: вспышка,
# у которой по краю светлая рамка, — это не вспышка.

signal changed

# Тот же размер, что в project.godot → display/window/size. Держать копию здесь
# приходится потому, что считать нужно ДО того, как появится вьюпорт.
const CANVAS : Vector2 = Vector2(960.0, 430.0)

var _safe   : Rect2 = Rect2(Vector2.ZERO, CANVAS)
var _layers : Array = []      # WeakRef на CanvasLayer, которым назначен отступ

# ── ДЕВ-ПОДМЕНА ──────────────────────────────────────────────────────────────
# Островок есть только на устройстве, а разметку правят на настольной машине.
# Без подмены проверка выглядит как «собери, залей в TestFlight, посмотри» —
# и так проверяют один раз, а потом перестают.
var _sim    : Vector4 = Vector4.ZERO
var _sim_on : bool    = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.size_changed.connect(_recompute)
	_recompute()

# Безопасный прямоугольник в координатах холста.
func rect() -> Rect2:
	return _safe

# Отступы словами: слева, сверху, справа, снизу. Ими удобно и читать, и писать
# тесты — «сколько отъело» понятнее, чем «где теперь угол».
func insets() -> Vector4:
	return Vector4(
		_safe.position.x, _safe.position.y,
		CANVAS.x - _safe.end.x, CANVAS.y - _safe.end.y)

func is_simulated() -> bool:
	return _sim_on

# Преобразование слоя: во что превращается точка холста после отступа. Нужно
# тем, кто ЖИВЁТ В ДРУГОМ СЛОЕ, но целится в интерфейс, — см. `hud`.
func layer_transform() -> Transform2D:
	var s := _fit_scale()
	return Transform2D(0.0, Vector2(s, s), 0.0,
		_safe.position + (_safe.size - CANVAS * s) * 0.5)

# Взять слой под отступ. Слой запоминается, и при повороте телефона отступ
# пересчитается ему сам — иначе после первого же поворота половина интерфейса
# осталась бы под островком.
func apply(cl: CanvasLayer) -> void:
	if cl == null:
		return
	var known := false
	for w in _layers:
		if (w as WeakRef).get_ref() == cl:
			known = true
			break
	if not known:
		_layers.append(weakref(cl))
	_apply_one(cl)

# ── Дев ──────────────────────────────────────────────────────────────────────
# Подменить отступы вручную: слева, сверху, справа, снизу — в пикселях холста.
# Нулевой вектор возвращает настоящие.
func simulate(inset: Vector4) -> void:
	_sim    = inset
	_sim_on = inset != Vector4.ZERO
	_recompute()

# ── Внутреннее ───────────────────────────────────────────────────────────────

func _fit_scale() -> float:
	return minf(_safe.size.x / CANVAS.x, _safe.size.y / CANVAS.y)

func _apply_one(cl: CanvasLayer) -> void:
	if not is_instance_valid(cl):
		return
	var s := _fit_scale()
	cl.scale  = Vector2(s, s)
	cl.offset = _safe.position + (_safe.size - CANVAS * s) * 0.5

func _recompute() -> void:
	var r := _measure()
	if r.position.is_equal_approx(_safe.position) \
			and r.size.is_equal_approx(_safe.size):
		return
	_safe = r
	var alive : Array = []
	for w in _layers:
		var cl = (w as WeakRef).get_ref()
		if cl != null and is_instance_valid(cl):
			alive.append(w)
			_apply_one(cl)
	_layers = alive
	changed.emit()

# Безопасная область приходит от системы В ПИКСЕЛЯХ ЭКРАНА, а разметка живёт в
# координатах холста; между ними стоит растяжение canvas_items с полями по
# краям. Переводит одно в другое сам вьюпорт — его же преобразованием, а не
# нашей арифметикой: считать растяжение второй раз значило бы разойтись с ним
# при первой же смене режима.
func _measure() -> Rect2:
	var full := Rect2(Vector2.ZERO, CANVAS)
	if _sim_on:
		return Rect2(Vector2(_sim.x, _sim.y),
			CANVAS - Vector2(_sim.x + _sim.z, _sim.y + _sim.w))
	# Ни окна, ни дерева — настольная сборка, headless, момент до запуска.
	# Везде это значит «резать нечего».
	var tree := get_tree()
	if tree == null or tree.root == null:
		return full
	var win := Vector2(DisplayServer.window_get_size())
	if win.x <= 0.0 or win.y <= 0.0:
		return full
	var safe := Rect2(DisplayServer.get_display_safe_area())
	if safe.size.x <= 0.0 or safe.size.y <= 0.0:
		return full
	var inv := (tree.root as Viewport).get_screen_transform().affine_inverse()
	var a : Vector2 = inv * safe.position
	var b : Vector2 = inv * (safe.position + safe.size)
	var r := Rect2(a, b - a).intersection(full)
	# Вырожденное пересечение — значит, мы неверно поняли, что нам дали. Лучше
	# отдать весь экран, чем схлопнуть интерфейс в точку.
	if r.size.x < CANVAS.x * 0.5 or r.size.y < CANVAS.y * 0.5:
		return full
	return r
