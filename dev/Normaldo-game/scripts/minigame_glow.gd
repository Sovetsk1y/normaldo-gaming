extends Node2D

# ── СВЕЧЕНИЕ ПРЕДМЕТА-КЛЮЧА ──────────────────────────────────────────────────
# Лучи, мягкое сияние и фонтан частиц вокруг предмета, который ВКЛЮЧАЕТ
# МИНИ-ИГРУ. Это отдельный язык, и он должен читаться с одного взгляда: обычную
# добычу подбирают не думая, а такой предмет меняет весь экран на десять секунд,
# и увидеть его надо ЗАРАНЕЕ, а не по факту.
#
#   зелёный  — мутаген, ЖИРОБОСС;
#   оранжевый — коробка пиццы, ПИЦЦА-ПАТИ.
#
# ── ПОЧЕМУ ОБЩИЙ КИРПИЧ, А НЕ КОПИЯ ─────────────────────────────────────────
# Эффект здесь — не украшение, а ЗНАК, и знак работает, только пока он один и
# тот же. Двенадцать лучей у мутагена и десять у коробки, разная скорость
# вращения, разный размер фонтана — и игрок больше не узнаёт «это ключ», он
# видит два похожих красивых предмета.
#
# Скопированный блок расходится не потому, что кто-то небрежен, а потому что
# правку вносят в тот файл, который открыли. Здесь разойтись нечему: числа
# одни, цвет — довод.
#
# Все узлы держатся на z_index 0, а НЕ на отрицательном: отрицательный
# отправляет их за стену фона, и эффект просто не виден. Лицо предмета сидит
# выше (z = 1) и рисуется поверх собственного света.

# Лучи.
const RAY_COUNT   : int   = 12
const RAY_LEN     : float = 78.0
const RAY_HALF_W  : float = 4.0
const RAY_ALPHA   : float = 0.22
const RAY_SPIN    : float = 0.8    # оборотов в секунду × 2π
const RAY_SCALE_LO: float = 0.90
const RAY_SCALE_HI: float = 1.15

# Мягкое сияние.
const GLOW_PX       : int   = 128
const GLOW_ALPHA    : float = 0.8
const GLOW_SCALE_LO : float = 1.4
const GLOW_SCALE_HI : float = 1.9

# Частицы. Скорость и размер ведёт БЛИЗОСТЬ головы: издали ровное подтекание,
# вплотную — фонтан. Без этого предмет одинаков на всём пролёте, и «вот-вот
# поймаю» ничем не отличается от «ещё далеко».
const PP_AMOUNT   : int   = 60
const PP_LIFETIME : float = 0.8
const PP_DOT_PX   : int   = 24
const PP_VEL_MIN_LO : float = 22.0
const PP_VEL_MIN_HI : float = 140.0
const PP_VEL_MAX_LO : float = 55.0
const PP_VEL_MAX_HI : float = 300.0
const PP_SCALE_MIN_LO : float = 0.30
const PP_SCALE_MIN_HI : float = 0.90
const PP_SCALE_MAX_LO : float = 0.60
const PP_SCALE_MAX_HI : float = 1.80

var _rays : Node2D          = null
var _glow : Sprite2D        = null
var _pp   : CPUParticles2D  = null

# Собрать свечение и вернуть его. Вешать на предмет ребёнком.
#
# `col` — цвет лучей и сияния, `particle_col` — частиц (у мутагена он на
# полтона другой, и менять это не за чем).
static func make(col: Color, particle_col: Color) -> Node2D:
	var n : Node2D = new()
	n.set_meta("col", col)
	n.set_meta("particle_col", particle_col)
	return n

func _ready() -> void:
	var col : Color = get_meta("col", Color(0.45, 1.0, 0.55))
	var pcol : Color = get_meta("particle_col", col)

	var add_mat := CanvasItemMaterial.new()
	add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

	# Лучи — тонкие складывающиеся иглы во все стороны.
	_rays = Node2D.new()
	_rays.z_index = 0
	add_child(_rays)
	for i in RAY_COUNT:
		var spike := Polygon2D.new()
		spike.color   = Color(col.r, col.g, col.b, RAY_ALPHA)
		spike.polygon = PackedVector2Array([
			Vector2(0.0, -RAY_HALF_W), Vector2(0.0, RAY_HALF_W), Vector2(RAY_LEN, 0.0)])
		spike.rotation = TAU * float(i) / float(RAY_COUNT)
		spike.material = add_mat
		_rays.add_child(spike)

	# Мягкое круглое сияние под лицом предмета.
	var grad := Gradient.new()
	grad.set_color(0, Color(col.r, col.g, col.b, GLOW_ALPHA))
	grad.set_color(1, Color(col.r, col.g, col.b, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient  = grad
	gt.fill      = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to   = Vector2(0.5, 0.0)
	gt.width     = GLOW_PX
	gt.height    = GLOW_PX
	_glow = Sprite2D.new()
	_glow.texture  = gt
	_glow.material = add_mat
	_glow.z_index  = 0
	add_child(_glow)

	# Круглая точка под частицы. БЕЗ ТЕКСТУРЫ CPUParticles2D рисует точки
	# размером в пиксель — именно поэтому в первый раз казалось, что частиц
	# «нет вовсе».
	var dot_grad := Gradient.new()
	dot_grad.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	dot_grad.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	var dot_tex := GradientTexture2D.new()
	dot_tex.gradient  = dot_grad
	dot_tex.fill      = GradientTexture2D.FILL_RADIAL
	dot_tex.fill_from = Vector2(0.5, 0.5)
	dot_tex.fill_to   = Vector2(0.5, 0.0)
	dot_tex.width     = PP_DOT_PX
	dot_tex.height    = PP_DOT_PX

	_pp = CPUParticles2D.new()
	_pp.z_index   = 0
	_pp.texture   = dot_tex
	_pp.amount    = PP_AMOUNT
	_pp.lifetime  = PP_LIFETIME
	_pp.emitting  = true
	_pp.spread    = 180.0            # 180° = полный круг
	_pp.direction = Vector2(0.0, -1.0)
	_pp.gravity   = Vector2.ZERO
	_pp.color     = pcol
	add_child(_pp)

# Вести эффект. `pulse` 0…1 — общее биение предмета, `prox` 0…1 — насколько
# близко голова.
func tick(delta: float, pulse: float, prox: float) -> void:
	if is_instance_valid(_rays):
		_rays.rotation += delta * RAY_SPIN
		_rays.scale     = Vector2.ONE * lerpf(RAY_SCALE_LO, RAY_SCALE_HI, pulse)
	if is_instance_valid(_glow):
		_glow.scale = Vector2.ONE * lerpf(GLOW_SCALE_LO, GLOW_SCALE_HI, pulse)
	if is_instance_valid(_pp):
		_pp.initial_velocity_min = lerpf(PP_VEL_MIN_LO, PP_VEL_MIN_HI, prox)
		_pp.initial_velocity_max = lerpf(PP_VEL_MAX_LO, PP_VEL_MAX_HI, prox)
		_pp.scale_amount_min     = lerpf(PP_SCALE_MIN_LO, PP_SCALE_MIN_HI, prox)
		_pp.scale_amount_max     = lerpf(PP_SCALE_MAX_LO, PP_SCALE_MAX_HI, prox)
