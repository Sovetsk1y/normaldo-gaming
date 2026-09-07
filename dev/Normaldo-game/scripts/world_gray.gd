extends Node2D

# БЕЗ `class_name` НАМЕРЕННО. Глобальное имя живёт в кэше классов проекта, а он
# наполняется только импортом; до него скрипты, которые ссылаются на имя, просто
# не компилируются — и первым падает весь забег, а не этот эффект. Здесь берут
# через `preload`, как и остальные вспомогательные скрипты проекта.

# Обесцвечивание мира на время замедления времени.
#
# Узел собирается на лету (`ensure`) и живёт под корнем сцены забега, рядом с
# фоном, предметами и героем.
#
# ── ПОЧЕМУ ИМЕННО ТУТ, А НЕ В CanvasLayer ────────────────────────────────────
# Интерфейс забега (`HUD`) — это CanvasLayer, а слои всегда рисуются ПОВЕРХ
# обычного холста, каким бы z_index на нём ни стоял. Значит слой с огромным
# z_index под корнем сцены накрывает ровно мир — фон, предметы, героя, буквы,
# боссов — и не трогает интерфейс.
#
# Так и задумано. Обесцвеченный HUD выглядел бы не как эффект, а как поломка:
# счётчик пицц, полоска жира и кружки перков опознаются по цвету, и серые они
# читаются как «отключились». Замедление касается мира; про игрока и его приборы
# оно ничего не сообщает.
const GRAY_SHADER := preload("res://shaders/world_gray.gdshader")

# Выше любого игрового z_index (самые верхние — буквы и боссы, около 10).
const Z : int = 4000
# Уход и возврат цвета. Быстро, но не мгновенно: щелчок в один кадр читается как
# подмена картинки, а не как эффект.
const FADE_IN  : float = 0.12
const FADE_OUT : float = 0.22

var _mat  : ShaderMaterial = null
var _rect : ColorRect      = null
var _tw   : Tween          = null

# Найти или собрать слой под корнем сцены забега.
static func ensure(root: Node) -> Node:
	var n : Node = root.get_node_or_null("WorldGray")
	if n != null:
		return n
	var made := new()
	made.name = "WorldGray"
	root.add_child(made)
	return made

func _ready() -> void:
	# Копия кадра — то, из чего шейдер берёт картинку: `hint_screen_texture`
	# отдаёт именно этот снимок. Без неё читать нечего.
	var bbc := BackBufferCopy.new()
	bbc.name      = "GrayCopy"
	bbc.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	bbc.z_index   = Z
	add_child(bbc)

	_mat = ShaderMaterial.new()
	_mat.shader = GRAY_SHADER
	_mat.set_shader_parameter("amount", 0.0)

	# Запас в три экрана, как у плёнки затемнения и слоя порчи фона: узлы сцены
	# ездят на тюинах при переходах между экранами, и прямоугольник ровно в экран
	# уехал бы вместе с ними, оставив у края цветную полосу.
	var vp := get_viewport_rect().size
	_rect = ColorRect.new()
	_rect.name         = "Gray"
	_rect.material     = _mat
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.size         = vp * 3.0
	_rect.position     = -vp
	_rect.z_index      = Z
	_rect.visible      = false
	add_child(_rect)

# Включить или выключить. Слой поднимается только на время эффекта: копия кадра
# каждый кадр — не та цена, которую платят просто так.
func set_gray(on: bool) -> void:
	if _mat == null or not is_instance_valid(_rect):
		return
	if _tw != null and _tw.is_valid():
		_tw.kill()
	if on:
		_rect.visible = true
	_tw = create_tween()
	_tw.tween_method(_set_amount, _amount(), 1.0 if on else 0.0,
		FADE_IN if on else FADE_OUT)
	if not on:
		# Прячем ПОСЛЕ возврата цвета, а не вместе с ним: спрятать раньше значит
		# оборвать переход на середине, то есть тем самым щелчком, ради ухода от
		# которого переход и сделан.
		_tw.tween_callback(func() -> void:
			if is_instance_valid(_rect):
				_rect.visible = false)

func is_gray() -> bool:
	return _amount() > 0.001

func _amount() -> float:
	return float(_mat.get_shader_parameter("amount")) if _mat != null else 0.0

func _set_amount(v: float) -> void:
	if _mat != null:
		_mat.set_shader_parameter("amount", v)
