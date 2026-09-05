class_name EnergySphere
extends Sprite2D

# ── Сфера вокруг головы ──────────────────────────────────────────────────────
# Синий шар, который вырастает вокруг Нормальдо и спадает. Вешается на резист:
# резист — это «удар не прошёл», и понятнее всего это показывает оболочка,
# которая на мгновение появилась вокруг головы.
#
# Раньше тут был значок из набора Vivid Motion — пиксельный пузырь 64×64. Он
# честно работал, но он ЗНАЧОК: шестнадцать нарисованных кадров, которые в любом
# размере остаются шестнадцатью нарисованными кадрами. Сфера считается шейдером,
# поэтому она любого размера, любого цвета и живёт ровно столько, сколько нужно
# событию, а не сколько нарисовано.
#
# Вид портирован с портала из набора BinbunVFX — сам набор трёхмерный и в этом
# проекте не работает (см. assets/vfx/energy_sphere.gdshader и
# /Концепция/Статус-эффекты.md).

const SHADER := preload("res://assets/vfx/energy_sphere.gdshader")

# Синий — цвет защиты во всей игре: тем же синим горит кольцо резиста в ряду
# кружков и подсвечена шляпа мага.
const COL_MAIN : Color = Color(0.38, 0.80, 1.00)
const COL_DEEP : Color = Color(0.04, 0.13, 0.38)

# Появление и спад. Появление быстрее спада: удар — событие мгновенное, а вот
# «меня прикрыло» игрок должен успеть прочитать.
const OPEN_T : float = 0.16
const HOLD_T : float = 0.22
const CLOSE_T: float = 0.42

# Шум, из которого шейдер вертит слои. Один на все сферы: он одинаковый, а
# генерация своей текстуры на каждый резист — это пересборка картинки в момент
# удара.
static var _noise : NoiseTexture2D = null

static func _shared_noise() -> NoiseTexture2D:
	if _noise != null:
		return _noise
	var n := FastNoiseLite.new()
	n.noise_type      = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency       = 0.014
	n.fractal_octaves = 3
	_noise = NoiseTexture2D.new()
	_noise.noise    = n
	# Бесшовный: шум читается в полярных координатах, и шов был бы виден как
	# трещина через всю сферу.
	_noise.seamless  = true
	_noise.width     = 128
	_noise.height    = 128
	return _noise

# Носитель UV. Шейдер рисует всё сам и текстуру не читает вовсе — она нужна
# ровно затем, чтобы у спрайта была площадь, по которой считать.
#
# И она ПРОЗРАЧНАЯ — на всякий случай, а не как лекарство. Голубой квадрат,
# который вспыхивал вокруг головы, был НЕ отсюда: его давал сам шейдер на
# перескоке огибающей (разбор — в energy_sphere.gdshader). Прозрачный носитель
# оставлен затем, что он бесплатно снимает целый класс мельканий: любой кадр, в
# котором шейдер по какой-то причине не применился, окажется пустым, а не белым
# квадратом во весь размер сферы. Самой сфере он безразличен — шейдер
# присваивает COLOR целиком и текстуру не читает.
#
# Гасить тем же способом `modulate` нельзя, хотя напрашивается: движок домножает
# его на итог фрагмента, и сфера пропадает вместе с квадратом. Проверено кадром.
static var _blank : ImageTexture = null

static func _blank_tex() -> ImageTexture:
	if _blank != null:
		return _blank
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 0))
	_blank = ImageTexture.create_from_image(img)
	return _blank

# `px` — диаметр сферы на экране.
static func make(px: float, col: Color = COL_MAIN) -> EnergySphere:
	var s := EnergySphere.new()
	s.texture        = _blank_tex()
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	s.scale          = Vector2.ONE * (px / 4.0)
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("primary_color",   col)
	mat.set_shader_parameter("secondary_color", COL_DEEP)
	mat.set_shader_parameter("noise_texture",   _shared_noise())
	mat.set_shader_parameter("open_amount",     0.0)
	s.material = mat
	return s

# Открыться, подержаться, закрыться — и убрать себя. Живёт СВОЕЙ жизнью, а не по
# внешнему таймеру: у сферы open_amount и есть её жизнь, и делить это знание с
# вызывающим незачем.
func play(hold: float = HOLD_T) -> void:
	var mat : ShaderMaterial = material
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void:
		if is_instance_valid(self):
			(material as ShaderMaterial).set_shader_parameter("open_amount", v),
		0.0, 1.0, OPEN_T).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(hold)
	tw.tween_method(func(v: float) -> void:
		if is_instance_valid(self):
			(material as ShaderMaterial).set_shader_parameter("open_amount", v),
		1.0, 0.0, CLOSE_T).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	# Схлопываясь, ещё чуть разрастается: так шар читается как лопнувший, а не
	# как выключенный.
	tw.parallel().tween_property(self, "scale", scale * 1.16, CLOSE_T)\
		.set_delay(OPEN_T + hold)
	tw.tween_callback(queue_free)

static func life(hold: float = HOLD_T) -> float:
	return OPEN_T + hold + CLOSE_T
