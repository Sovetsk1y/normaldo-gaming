extends Node

# ── Аура предмета ─────────────────────────────────────────────────────────────
# Радиальное свечение под спрайтом: круглый градиент от цвета к прозрачности,
# нарисованный СЛОЖЕНИЕМ (BLEND_MODE_ADD), поэтому он подсвечивает фон, а не
# кладёт на него мутный блин.
#
# Кирпич общий. Свечение придумывалось для предметов-эффектов (песочные часы,
# наручники, туз), а потом понадобилось кобре — и второй копией того же кода
# оно немедленно начало расходиться: там 96 пикселей, тут 110, там пульс 0.85–
# 1.25, тут какой-нибудь свой. Аура — это один визуальный словарь на всю игру:
# «вокруг этого предмета светится» должно означать одно и то же, отличаться
# может только ЦВЕТ, которым он светится.
#
# Пользоваться так:
#   const ItemAura := preload("res://scripts/item_aura.gd")
#   _glow = ItemAura.make(Color(0.55, 0.82, 0.25))   # ДО спрайта — аура под ним
#   add_child(_glow)
#   ...
#   ItemAura.pulse(_glow, p)                          # p = 0..1 из своего таймера

const PX        : float = 96.0    # размер кадра градиента
const ALPHA     : float = 0.75    # непрозрачность в центре
const SCALE_MIN : float = 0.85    # дыхание ауры: от и до
const SCALE_MAX : float = 1.25
const FADE_MIN  : float = 0.55
const FADE_MAX  : float = 1.00

# Спрайт-аура цвета `col`. `px` — диаметр свечения на экране; по умолчанию кадр
# рисуется как есть, крупным предметам его имеет смысл растянуть.
static func make(col: Color, px: float = PX) -> Sprite2D:
	var grad := Gradient.new()
	grad.set_color(0, Color(col.r, col.g, col.b, ALPHA))
	grad.set_color(1, Color(col.r, col.g, col.b, 0.0))

	var gt := GradientTexture2D.new()
	gt.gradient  = grad
	gt.fill      = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to   = Vector2(0.5, 0.0)
	gt.width     = int(PX)
	gt.height    = int(PX)

	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

	var glow := Sprite2D.new()
	glow.texture  = gt
	glow.material = mat
	glow.z_index  = 0
	glow.scale    = Vector2.ONE * (px / PX)
	return glow

# Дыхание: `p` = 0..1, обычно `0.5 + 0.5 * sin(t)`. Базовый масштаб ауры (тот,
# что задали в `make`) сохраняется — множитель ложится поверх него.
static func pulse(glow: Sprite2D, p: float, base_px: float = PX) -> void:
	if not is_instance_valid(glow):
		return
	var k : float = base_px / PX
	glow.scale    = Vector2.ONE * k * lerpf(SCALE_MIN, SCALE_MAX, p)
	glow.modulate = Color(1.0, 1.0, 1.0, lerpf(FADE_MIN, FADE_MAX, p))
