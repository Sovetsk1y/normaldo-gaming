class_name ItemSizing
extends RefCounted

# ── Единый размер предметов ───────────────────────────────────────────────────
# Исходники спрайтов приходят из разных источников и различаются в разы (token
# 89 px, ninja_foot 1049 px, pizza 511 px). Раньше каждый спавн подбирал свой
# множитель scale вручную (0.09 для пиццы, 0.16 для камня, 0.22 для бочки…) —
# любой новый спрайт приходилось калибровать на глаз, и промах сразу ломал
# читаемость поля.
#
# fit_scale() считает scale из РАЗМЕРА ТЕКСТУРЫ, поэтому на экране всё выходит
# одинаковым независимо от разрешения исходника: длинная сторона спрайта всегда
# BASE_PX пикселей.
#
# См. /Концепция/Уровни/1-Канализация.md → «Размеры предметов».

# Целевая длинная сторона предмета на экране. Подобрано под существующее поле:
# пицца 511 × 0.09 ≈ 46 px, камень 311 × 0.16 ≈ 50 px, бочка 310 × 0.22 ≈ 68 px.
const BASE_PX : float = 52.0

# Радиус хитбокса предмета базового размера (item.gd исторически 28/30).
const BASE_R  : float = 30.0

# ── Рандомный размер ударяющих предметов (1x…3x) ──────────────────────────────
# Только для ударяющих: ресурсы (пицца/доллар) остаются калиброванными, иначе
# ломается читаемость «что можно съесть».
#
# Веса намеренно перекошены к 1x: паттерны T1-T5 рассчитаны на предмет в один
# лейн, и крупный экземпляр — это событие, а не норма. Крупные размеры ещё и
# отсеиваются спавнером, если рядом нет свободного места (см. spawner.gd →
# _fit_size_mult), так что фактическая доля 3x ниже номинальной.
const MULT_MIN : float = 1.0
const MULT_MAX : float = 3.0

# [вес, нижняя граница, верхняя граница]
const MULT_BUCKETS : Array = [
	[70.0, 1.00, 1.00],   # обычный
	[18.0, 1.15, 1.50],   # чуть крупнее
	[ 9.0, 1.50, 2.20],   # заметно крупный
	[ 3.0, 2.20, 3.00],   # редкий гигант
]

# Scale для спрайта, чтобы его длинная сторона стала target_px пикселей.
static func fit_scale(tex: Texture2D, target_px: float = BASE_PX) -> float:
	if tex == null:
		return 1.0
	var sz := tex.get_size()
	var longest := maxf(sz.x, sz.y)
	if longest <= 0.0:
		return 1.0
	return target_px / longest

# Привести спрайт к единому экранному размеру.
static func fit_sprite(sprite: Sprite2D, target_px: float = BASE_PX) -> void:
	if sprite == null:
		return
	sprite.scale          = Vector2.ONE * fit_scale(sprite.texture, target_px)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

# Розыгрыш размера ударяющего предмета.
static func roll_hazard_mult() -> float:
	var total : float = 0.0
	for b in MULT_BUCKETS:
		total += b[0] as float
	var r : float = randf() * total
	var acc : float = 0.0
	for b in MULT_BUCKETS:
		acc += b[0] as float
		if r < acc:
			return randf_range(b[1] as float, b[2] as float)
	return MULT_MIN

# Радиус, который займёт предмет данного размера — им оперирует спавнер, когда
# резервирует место под предмет (см. spawner.gd → _spans).
static func radius_for(mult: float) -> float:
	return BASE_R * mult

# Масштабирование готового узла целиком: Area2D — это CollisionObject2D, его
# scale тянет за собой и спрайт, и форму столкновения, поэтому каждому скрипту
# предмета не нужно уметь менять свой размер.
static func apply_node_scale(node: Node2D, mult: float) -> void:
	if node == null or is_equal_approx(mult, 1.0):
		return
	node.scale = Vector2.ONE * mult
