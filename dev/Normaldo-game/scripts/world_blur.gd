extends Node2D

# БЕЗ `class_name` НАМЕРЕННО — по той же причине, что у `world_gray.gd`:
# глобальное имя живёт в кэше классов проекта, а он наполняется только импортом.
# Здесь берут через `preload`.

# Расфокус мира на время действия ПИВА.
#
# Устройство один в один как у обесцвечивания (`world_gray.gd`), и это
# сознательно: узел собирается на лету (`ensure`), живёт под корнем сцены забега
# и накрывает ровно МИР — фон, предметы, героя, буквы, боссов, — не трогая
# интерфейс. Интерфейс лежит в CanvasLayer, а слои рисуются поверх обычного
# холста при любом z_index.
#
# Замыленный HUD был бы не эффектом, а поломкой: счётчик пицц и полоску жира
# игрок читает ГЛАЗАМИ, и размытые цифры значат «сломалось», а не «штормит».
# Мутит от пива в мире, приборы работают исправно.
const BLUR_SHADER := preload("res://shaders/world_blur.gdshader")

# Выше любого игрового z_index. То же число, что у обесцвечивания: оба слоя
# экранные, и порядок между ними значения не имеет — они складываются.
const Z : int = 4000
const FADE_IN  : float = 0.18
const FADE_OUT : float = 0.35

# Радиус на полной силе. Подбирался по кадру 960×430: на 8 px предметы теряют
# опознаваемость и игра становится нечестной, на 3 px эффекта не видно.
const RADIUS_PX : float = 6.0

var _mat  : ShaderMaterial = null
var _rect : ColorRect      = null
var _tw   : Tween          = null

static func ensure(root: Node) -> Node:
	var n : Node = root.get_node_or_null("WorldBlur")
	if n != null:
		return n
	var made := new()
	made.name = "WorldBlur"
	root.add_child(made)
	return made

func _ready() -> void:
	# Копия кадра — то, из чего шейдер берёт картинку.
	var bbc := BackBufferCopy.new()
	bbc.name      = "BlurCopy"
	bbc.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	bbc.z_index   = Z
	add_child(bbc)

	_mat = ShaderMaterial.new()
	_mat.shader = BLUR_SHADER
	_mat.set_shader_parameter("amount",    0.0)
	_mat.set_shader_parameter("radius_px", RADIUS_PX)

	# ЗАПАС МЕНЬШЕ, ЧЕМ У ОБЕСЦВЕЧИВАНИЯ, И ЭТО РАСЧЁТ, А НЕ НЕДОСМОТР.
	#
	# Запас нужен затем же: узлы сцены ездят на тюинах при переходах, и
	# прямоугольник ровно в экран уехал бы вместе с ними, оставив резкую полосу у
	# края. Но у обесцвечивания один отсчёт на пиксель, а здесь пять, и три
	# экрана — это ДЕВЯТИКРАТНАЯ площадь: почти вся работа шейдера уходила бы за
	# кадр, где её никто не увидит.
	#
	# Полтора экрана закрывают переезд с запасом в четверть экрана в каждую
	# сторону и режут площадь с девяти экранов до двух с четвертью.
	const MARGIN : float = 1.5
	var vp := get_viewport_rect().size
	_rect = ColorRect.new()
	_rect.name         = "Blur"
	_rect.material     = _mat
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.size         = vp * MARGIN
	_rect.position     = -vp * ((MARGIN - 1.0) * 0.5)
	_rect.z_index      = Z
	_rect.visible      = false
	add_child(_rect)

# Включить или выключить. Слой поднимается только на время эффекта: копия кадра
# каждый кадр — не та цена, которую платят просто так.
func set_blur(on: bool) -> void:
	if _mat == null or not is_instance_valid(_rect):
		return
	if _tw != null and _tw.is_valid():
		_tw.kill()
	if on:
		_rect.visible = true
	_tw = create_tween()
	_tw.tween_method(_set_amount, amount(), 1.0 if on else 0.0,
		FADE_IN if on else FADE_OUT)
	if not on:
		# Прячем ПОСЛЕ возврата резкости, а не вместе с ней: спрятать раньше
		# значит оборвать переход на середине — тем самым щелчком, ради ухода от
		# которого переход и сделан.
		_tw.tween_callback(func() -> void:
			if is_instance_valid(_rect):
				_rect.visible = false)

# Вести силу вручную, без тюина. Пиво спадает по СВОЕМУ таймеру (см.
# `normaldo._physics_process`), и расфокус обязан спадать вместе с ним — иначе
# экран остаётся мутным ещё треть секунды после того, как отпустило.
func set_amount(v: float) -> void:
	if _mat == null or not is_instance_valid(_rect):
		return
	if _tw != null and _tw.is_valid():
		_tw.kill()
	v = clampf(v, 0.0, 1.0)
	_set_amount(v)
	_rect.visible = v > 0.001

func is_blurred() -> bool:
	return amount() > 0.001

func amount() -> float:
	return float(_mat.get_shader_parameter("amount")) if _mat != null else 0.0

func _set_amount(v: float) -> void:
	if _mat != null:
		_mat.set_shader_parameter("amount", v)
