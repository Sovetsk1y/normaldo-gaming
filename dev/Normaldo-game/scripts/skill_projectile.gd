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
	# ── СНАРЯД ИГРОКА ПОМЕЧЕН ГРУППОЙ ────────────────────────────────────────
	# Собака капитана ЛОВИТ ЗУБАМИ чужие снаряды, и найти их ей нечем: у снаряда
	# collision_layer = 0 и monitorable = false — физика не показывает его вообще
	# никому, он сам всех видит, а его не видит никто.
	#
	# Группа — единственный способ узнать, что по экрану летит чей-то каст. Она
	# общая на все скины, и это не упрощение: снаряд у всех один и тот же узел,
	# разными бывают только картинка, скорость и обработчик попадания.
	add_to_group("skill_shot")
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

# ── ОТСКОКИ ОТ КРАЁВ И ВОЗВРАТ К ХОЗЯИНУ ────────────────────────────────────
# Колода Джокера: карта отбивается от краёв экрана `wall_bounces` раз, а потом НЕ
# ГАСНЕТ, а идёт обратно к тому, кто её бросил.
#
# Это не то же самое, что `bounces` выше. Тот — рикошет ПО ЦЕЛЯМ: разбил предмет
# и довернул к следующему. Здесь отскок от ПУСТОЙ СТЕНЫ, и цели он не касается
# вовсе. Два разных слова для двух разных вещей нарочно: свести их в одно
# значило бы, что батаранг начнёт отскакивать от рамки, а карта — доворачивать к
# предметам.
#
# По умолчанию 0 — снаряд улетает за край и гаснет, как раньше.
var wall_bounces : int    = 0
var return_to    : Node2D = null

var _walls_left : int  = 0
var _returning  : bool = false

# Насколько круто карта доворачивает домой. Не мгновенный разворот: карта,
# щёлкнувшая направление в одном кадре, читается как новая карта, вылетевшая
# оттуда же. Дуга разворота — это то, по чему видно, что вернулась ТА ЖЕ.
const RETURN_TURN : float = 7.0
# На каком расстоянии считается пойманной.
const CATCH_R : float = 36.0

func arm_walls(times: int, home: Node2D) -> void:
	wall_bounces = times
	_walls_left  = times
	return_to    = home

# Отражение по КАЖДОЙ стене отдельно и только если снаряд летит НАРУЖУ: без
# второй проверки карта, поджатая к краю, отражалась бы каждый кадр и дрожала в
# стене, сжигая отскоки за долю секунды.
func _bounce_walls() -> bool:
	var vp := get_viewport_rect().size
	var m  := radius * 0.5
	var hit := false
	if position.x < m and velocity.x < 0.0:
		position.x = m
		velocity.x = absf(velocity.x)
		hit = true
	elif position.x > vp.x - m and velocity.x > 0.0:
		position.x = vp.x - m
		velocity.x = -absf(velocity.x)
		hit = true
	if position.y < m and velocity.y < 0.0:
		position.y = m
		velocity.y = absf(velocity.y)
		hit = true
	elif position.y > vp.y - m and velocity.y > 0.0:
		position.y = vp.y - m
		velocity.y = -absf(velocity.y)
		hit = true
	return hit

func _steer_home(delta: float) -> void:
	# Хозяина не стало (умер, забег кончился) — возвращаться некому.
	if not is_instance_valid(return_to):
		queue_free()
		return
	var d : Vector2 = return_to.global_position - global_position
	if d.length() < CATCH_R:
		queue_free()
		return
	var want : Vector2 = d.normalized() * velocity.length()
	velocity = velocity.lerp(want, clampf(RETURN_TURN * delta, 0.0, 1.0))

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
	if _returning:
		_steer_home(delta)
		if not is_instance_valid(self):
			return
	position += velocity * delta
	life     -= delta
	if _spr != null and spin != 0.0:
		_spr.rotation += spin * delta

	# ВОЗВРАЩАЮЩАЯСЯ КАРТА ОТ СТЕН НЕ ОТСКАКИВАЕТ. Иначе она отбилась бы от
	# ближайшего края обратно и не дошла бы домой никогда.
	if wall_bounces > 0 and not _returning:
		if _bounce_walls():
			_walls_left -= 1
			if _walls_left <= 0:
				_returning = true
		# Улететь за край она не может, поэтому проверка границ ей не нужна —
		# только время жизни, и то как страховка.
		if life <= 0.0:
			queue_free()
		return

	var vp := get_viewport_rect().size
	if life <= 0.0 or position.x < -140.0 or position.x > vp.x + 140.0 \
			or position.y < -140.0 or position.y > vp.y + 140.0:
		queue_free()
