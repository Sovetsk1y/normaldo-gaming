class_name LootMultiplier
extends RefCounted

# ── Множитель добычи мини-игр (×1 … ×5) ───────────────────────────────────────
# Проблема, ради которой это сделано: мини-игры («мутаген» / ЖИРОБОСС, «коробка
# пиццы» / ПИЦЦА-ПАТИ, «супер пицца») стоили игроку 10-20 секунд забега, а
# отдавали примерно столько же ресурсов, сколько обычный поток предметов. Тапать
# было незачем — выгоднее было просто облетать.
#
# Теперь ВСЯ добыча, собранная внутри мини-игры, в конце умножается на бросок
# ×1…×5. Средний бросок ≈ ×2.2, то есть мини-игра стабильно выгоднее забега, а
# верхний край (×5) даёт повод её ждать.
#
# Считает и начисляет добавку normaldo.gd (begin_loot_tally / award_loot_tally),
# показывает popup — этот класс.
#
# См. /Концепция/Экономика.md → «Множитель мини-игр».

const UI_FONT := preload("res://assets/fonts/RussoOne-Regular.ttf")
const X3_TEX  := preload("res://assets/skills/x3.png")
const SFX     := preload("res://assets/audio/magic_glitter.mp3")

# [вес, множитель]. Сумма весов 100 — читается как проценты.
const ROLL_TABLE : Array = [
	[34.0, 1],
	[28.0, 2],
	[22.0, 3],
	[11.0, 4],
	[ 5.0, 5],
]

# Цвет подписи по величине броска — ×1 тусклый, ×5 горячий.
const TIER_COLORS : Array = [
	Color(0.78, 0.78, 0.78),   # ×1
	Color(0.55, 0.90, 1.00),   # ×2
	Color(0.45, 1.00, 0.55),   # ×3
	Color(1.00, 0.72, 0.20),   # ×4
	Color(1.00, 0.30, 0.30),   # ×5
]

static func roll() -> int:
	var total : float = 0.0
	for row in ROLL_TABLE:
		total += row[0] as float
	var r : float = randf() * total
	var acc : float = 0.0
	for row in ROLL_TABLE:
		acc += row[0] as float
		if r < acc:
			return row[1] as int
	return 1

# Popup «×N РЕЙТ» в центре экрана: влетает с овершутом, держится, уходит вверх.
# `parent` — любой CanvasItem-контейнер мини-игры; ждать анимацию не обязательно,
# но возвращаемый Tween позволяет синхронизировать с ним начисление.
static func show_popup(parent: Node, mult: int, at: Vector2) -> Tween:
	if parent == null or not is_instance_valid(parent):
		return null

	var col : Color = TIER_COLORS[clampi(mult - 1, 0, TIER_COLORS.size() - 1)]

	var root := Node2D.new()
	root.z_index = 90
	root.position = at
	parent.add_child(root)

	# Подложка-граффити «x3» из набора навыков — она чисто декоративная, поэтому
	# тускнеет тем сильнее, чем меньше бросок.
	var badge := Sprite2D.new()
	badge.texture        = X3_TEX
	badge.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var bsc := 190.0 / maxf(1.0, maxf(X3_TEX.get_size().x, X3_TEX.get_size().y))
	badge.scale    = Vector2(bsc, bsc)
	badge.modulate = Color(col.r, col.g, col.b, 0.30 + 0.10 * float(mult))
	root.add_child(badge)

	var lbl := Label.new()
	lbl.text = "×%d" % mult
	lbl.add_theme_font_override("font", UI_FONT)
	lbl.add_theme_font_size_override("font_size", 64)
	lbl.add_theme_color_override("font_color", col)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	lbl.add_theme_constant_override("outline_size", 10)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.size     = Vector2(220.0, 76.0)
	lbl.position = Vector2(-110.0, -60.0)
	root.add_child(lbl)

	var sub := Label.new()
	sub.text = "РЕЙТ"
	sub.add_theme_font_override("font", UI_FONT)
	sub.add_theme_font_size_override("font_size", 22)
	sub.add_theme_color_override("font_color", col)
	sub.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	sub.add_theme_constant_override("outline_size", 6)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.size     = Vector2(220.0, 30.0)
	sub.position = Vector2(-110.0, 10.0)
	root.add_child(sub)

	var audio := AudioStreamPlayer.new()
	audio.stream = SFX
	root.add_child(audio)
	audio.play()

	root.scale = Vector2.ZERO
	var tw := root.create_tween()
	tw.tween_property(root, "scale", Vector2.ONE, 0.30) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Чем крупнее бросок, тем дольше держим — ×5 должен успеть считаться.
	tw.tween_interval(0.55 + 0.15 * float(mult))
	tw.tween_property(root, "position:y", at.y - 70.0, 0.45)
	tw.parallel().tween_property(root, "modulate:a", 0.0, 0.45)
	tw.tween_callback(root.queue_free)
	return tw
