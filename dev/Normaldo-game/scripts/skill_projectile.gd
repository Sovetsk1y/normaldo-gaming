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

# Покадровая анимация снаряда. Архивы скинов принесли раскадровки (батаранг 6
# кадров, паутина 8, магический шар 4), и крутить их вращением спрайта было бы
# обманом — кадры рисованные, а не повёрнутые.
var frames : Array = []          # Array[Texture2D]
var fps    : float = 14.0
var _frame_t : float = 0.0
var _frame_i : int   = 0

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
		if bounces > 0:
			bounces -= 1
			_bounce()
			return
		queue_free()

# ── Рикошет ──────────────────────────────────────────────────────────────────
# Батаранг Бэтмена не гаснет на первой цели: разбил предмет — ДОВЕРНУЛ к
# ближайшему следующему и полетел в него, и так `bounces` раз.
#
# Именно доворот к цели, а не отражение по нормали. Отражённый снаряд улетает
# куда попало, и цепочка из трёх получалась бы только случайно — а игроку
# обещаны три цели, значит снаряд обязан искать их сам.
#
# Цели, по которым уже попали, исключены (`_hit`): без этого снаряд у первой же
# разбитой цели начинал крутиться вокруг её обломков, пока не истечёт время.
var bounces : int = 0

# Времени жизни после доворота — не меньше этого: снаряд, доживающий последние
# кадры, доворачивал к цели и гас на полпути, и рикошет читался как промах.
const BOUNCE_LIFE : float = 0.9

func _bounce() -> void:
	var best : Node2D = null
	var best_d : float = INF
	for g in scan_groups:
		for n in get_tree().get_nodes_in_group(g):
			if not (n is Node2D) or not is_instance_valid(n):
				continue
			if _hit.has(n.get_instance_id()):
				continue
			var d : float = global_position.distance_to((n as Node2D).global_position)
			if d < best_d:
				best_d = d
				best = n
	life = maxf(life, BOUNCE_LIFE)
	if best == null:
		return          # некуда доворачивать — летим дальше своим курсом
	velocity = global_position.direction_to(best.global_position) * velocity.length()

func _process(delta: float) -> void:
	if frames.size() > 1 and _spr is Sprite2D:
		_frame_t += delta * fps
		var i := int(_frame_t) % frames.size()
		if i != _frame_i:
			_frame_i = i
			(_spr as Sprite2D).texture = frames[i]
			# Ободок под тёмным снарядом — та же раскадровка, иначе он застынет
			# на первом кадре и поедет отдельно от самого снаряда.
			var rim := _spr.get_node_or_null("Rim")
			if rim is Sprite2D:
				(rim as Sprite2D).texture = frames[i]
	position += velocity * delta
	life     -= delta
	if _spr != null and spin != 0.0:
		_spr.rotation += spin * delta

	var vp := get_viewport_rect().size
	if life <= 0.0 or position.x < -140.0 or position.x > vp.x + 140.0 \
			or position.y < -140.0 or position.y > vp.y + 140.0:
		queue_free()
