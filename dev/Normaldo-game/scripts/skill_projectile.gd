extends Area2D

# Generic skin-ability projectile. Flies in a straight line; the PHYSICS ENGINE
# reports overlaps via `area_entered` (Area2D + CircleShape, mask = 2 = item layer)
# — БЕЗ покадрового ручного скана групп. `hit_handler` вызывается один раз на ноду
# и возвращает true → СНАРЯД ПОГЛОЩАЕТСЯ (одиночные касты вроде Трансформуса) или
# false → ПРОБИВАЕТ насквозь (Рыгалити / Штурвал / карты / паутина).
#
# scan_groups фильтрует, какие из предметов слоя 2 засчитываются (например, только
# препятствия), т.к. на слое 2 сидят и пиццы, и доллары, и препятствия.

var velocity    : Vector2  = Vector2.ZERO
var radius      : float    = 34.0
var life        : float    = 2.2
var spin        : float    = 0.0
var scan_groups : Array    = ["obstacle"]
var hit_handler : Callable

var _spr  : Node2D     = null
var _hit  : Dictionary = {}

func setup(spr: Node2D) -> void:
	_spr = spr
	if spr != null:
		add_child(spr)
	# Коллизия — как у обычных предметов: круг, ловим слой 2 (предметы/препятствия).
	# Строим здесь (а не в _ready), т.к. radius выставляется вызывающим уже ПОСЛЕ
	# add_child — к моменту setup() он гарантированно задан.
	collision_layer = 0
	collision_mask  = 2
	monitorable     = false
	var cs := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	cs.shape = circle
	add_child(cs)
	area_entered.connect(_on_area_entered)

func _on_area_entered(area: Area2D) -> void:
	if area == self or not is_instance_valid(area):
		return
	var matched := false
	for g in scan_groups:
		if area.is_in_group(g):
			matched = true
			break
	if not matched:
		return
	var nid : int = area.get_instance_id()
	if _hit.has(nid):
		return
	_hit[nid] = true
	var consumed := false
	if hit_handler.is_valid():
		consumed = bool(hit_handler.call(area))
	if consumed:
		queue_free()

func _process(delta: float) -> void:
	position += velocity * delta
	life     -= delta
	if _spr != null and spin != 0.0:
		_spr.rotation += spin * delta

	var vp := get_viewport_rect().size
	if life <= 0.0 or position.x < -140.0 or position.x > vp.x + 140.0 \
			or position.y < -140.0 or position.y > vp.y + 140.0:
		queue_free()
