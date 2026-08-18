class_name UiKit
extends RefCounted

# ── Общие кирпичи интерфейса ──────────────────────────────────────────────────
# Интерфейс собирается кодом, и каждая новая панель до сих пор рисовалась
# заново: скругления и рамки у экрана скинов, заданий и лидеров разъезжались,
# хотя выглядеть должны одинаково. Здесь лежит то, что нужно всем.
#
# См. /Концепция/UI — паттерны интерфейса.md

# Скруглённая подложка. Радиус 12 — карточка, 8 — кнопка и чип, 6 — полоса.
static func rounded(fill: Color, radius: int,
		border: Color = Color(0, 0, 0, 0), border_w: int = 2) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.corner_radius_top_left     = radius
	sb.corner_radius_top_right    = radius
	sb.corner_radius_bottom_left  = radius
	sb.corner_radius_bottom_right = radius
	if border.a > 0.0:
		sb.border_color = border
		sb.border_width_left   = border_w
		sb.border_width_right  = border_w
		sb.border_width_top    = border_w
		sb.border_width_bottom = border_w
	return sb

# Панель со скруглением — самый частый вызов, чтобы не писать три строки подряд.
static func panel(parent: Node, pos: Vector2, size: Vector2, fill: Color,
		radius: int, border: Color = Color(0, 0, 0, 0), border_w: int = 2) -> Panel:
	var p := Panel.new()
	p.add_theme_stylebox_override("panel", rounded(fill, radius, border, border_w))
	p.size         = size
	p.position     = pos
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(p)
	return p
