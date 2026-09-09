extends Area2D

# ── Собака капитана ──────────────────────────────────────────────────────────
# Часть боя с [[Босс — Капитан полиции]]. Капитан спускает её с поводка, она
# ЛЕТИТ В НОРМАЛЬДО — и дальше одно из двух:
#
#   а) промахнулась и ушла в стену — ОТСКАКИВАЕТ и идёт снова, уже под другим
#      углом. Так до восьми раз;
#   б) восьмой отскок она ВСЕГДА направляет к хозяину и возвращается к нему.
#
# ── ЗАЧЕМ ОТСКОКИ ──────────────────────────────────────────────────────────
# Атака, которая летит в тебя один раз, читается по прямой: сошёл с линии —
# всё. Отскакивающая заставляет читать ГЕОМЕТРИЮ КОМНАТЫ: она вернётся, и
# откуда — зависит от того, в какую стену её отправил твой уход. Это тот же
# вопрос, что у батаранга, но заданный противником, а не игроком.
#
# ── ПОЧЕМУ ВОСЬМОЙ ОТСКОК — К ХОЗЯИНУ ──────────────────────────────────────
# Атака обязана КОНЧАТЬСЯ, и кончаться понятно. Собака, скачущая по экрану, пока
# не попадёт, — это не атака, а фон, от которого нельзя отдохнуть; а исчезнувшая
# в никуда обманывает: игрок не понял, кончилось или нет. Уход к хозяину виден и
# читается как «отбегался».
#
# Восемь — это столько, сколько нужно, чтобы отскок перестал быть случайностью и
# стал правилом, и при этом не столько, чтобы надоесть: на пятом игрок уже ждёт
# её возвращения и смотрит на стены, а не на неё.
#
# ── И ДВЕ ВЕЩИ, КОТОРЫЕ ДЕЛАЮТ ЕЁ СОБАКОЙ, А НЕ СНАРЯДОМ ───────────────────
# Она РАЗГОНЯЕТСЯ всё время, пока спущена, и она ЕСТ СНАРЯДЫ — любые, от любого
# скина. Оба правила ниже расписаны там, где живут; вместе они говорят одно:
# отбиться от неё нельзя, можно только уйти, и с каждой секундой уходить труднее.

const DOG_TEX   := preload("res://assets/items/angry_dog.png")
const SFX_BARK  := preload("res://assets/audio/dog.mp3")

const DOG_PX : float = 72.0

# ── ОНА РАЗГОНЯЕТСЯ ВСЁ ВРЕМЯ, ПОКА СПУЩЕНА ────────────────────────────────
# Собака, идущая с одной скоростью, читается через два отскока: игрок понял темп
# и дальше просто отходит в сторону по расписанию. Разгон ломает это расписание —
# каждый следующий заход быстрее предыдущего, и то, как ты уходил от четвёртого,
# от седьмого уже не спасает.
#
# И он же УКОРАЧИВАЕТ атаку, а не удлиняет: чем быстрее собака, тем быстрее она
# добирает свои восемь отскоков. Разгон тут — не «стало злее», а «стало короче и
# злее», и это ровно то, чего просит акт, который идёт дважды подряд.
const SPEED_0 : float = 430.0   # с чего срывается с поводка
const ACCEL   : float = 110.0   # и сколько добирает за каждую секунду

# ── ПОТОЛОК — ТЕХНИЧЕСКИЙ, А НЕ ВКУСОВОЙ ───────────────────────────────────
# Перекрытие областей проверяется в ДИСКРЕТНЫХ положениях, раз в кадр. Собака,
# шагающая за кадр дальше, чем сумма полуразмеров её и Нормальдо, ПРОЛЕТАЕТ
# СКВОЗЬ него, ни разу не оказавшись с ним в одной точке, — и удар, который игрок
# видел глазами, не случается.
#
# Хитбокс собаки 47×42, у Нормальдо того же порядка; на 60 кадрах 1050 px/c — это
# 17.5 пикселя за кадр, с большим запасом. Дальше начинается не «сложно», а
# «нечестно».
const SPEED_MAX : float = 1050.0

# Сколько раз она может отбиться от стены. Восьмой — всегда к хозяину.
const MAX_BOUNCES : int = 8
# Поля, за которые она не заезжает: стены арены.
const MARGIN : float = 26.0

# ── ОНА ПЕРЕХВАТЫВАЕТ СНАРЯДЫ ЛЮБОГО СКИНА ─────────────────────────────────
# Батаранг, паутина, карты, шар мага, рыгалити — всё, что вылетает из рук
# Нормальдо, собака ЛОВИТ ЗУБАМИ и гасит. Она единственная в игре, кто это
# делает, и потому от неё нельзя отбиться спеллом: только уходить.
#
# Ловит она их САМА, покадровым замером расстояния, а не физикой. У снаряда
# collision_layer = 0 — он никому не виден, он видит всех; группа `skill_shot` и
# есть единственный способ его найти (см. skill_projectile.gd).
const SHOT_GROUP : String = "skill_shot"
# Пасть шире хитбокса: снаряд, погасший ровно в точке касания, читался бы как
# «прошёл насквозь и исчез сам».
const BITE_R : float = 54.0

var damage : int = 1

# Кого ловит и к кому возвращается — ставит босс.
var target : Node2D = null
var owner_node : Node2D = null

signal came_home

var _vel      : Vector2 = Vector2.ZERO
var _speed    : float   = SPEED_0
var _bounces  : int     = 0
var _homing   : bool    = false   # последний заход — к хозяину
var _sprite   : Sprite2D = null
var _done     : bool    = false

func _ready() -> void:
	collision_layer = 2
	collision_mask  = 0
	add_to_group("obstacle")
	add_to_group("police_dog")

	_sprite = Sprite2D.new()
	_sprite.texture        = DOG_TEX
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.z_index        = 2
	ItemSizing.fit_sprite_content(_sprite, DOG_PX)
	add_child(_sprite)

	var cs   := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(DOG_PX * 0.66, DOG_PX * 0.58)
	cs.shape  = rect
	add_child(cs)

	_aim_at_target()
	_bark()

func _aim_at_target() -> void:
	var to : Vector2 = target.global_position if is_instance_valid(target) \
		else position + Vector2(-400.0, 0.0)
	var d := to - position
	_vel = (d.normalized() if d.length() > 1.0 else Vector2.LEFT) * _speed

func _process(delta: float) -> void:
	if _done:
		return
	# Разгон: курс держим, скорость добираем. Направление живёт в `_vel`, поэтому
	# после каждой прибавки его надо ПЕРЕСОБРАТЬ по той же нормали — иначе
	# ускорение зависело бы от того, под каким углом она бежит.
	_speed = minf(_speed + ACCEL * delta, SPEED_MAX)
	if _vel.length() > 1.0:
		_vel = _vel.normalized() * _speed
	position += _vel * delta
	# ── СОБАКА НЕ КРУТИТСЯ ───────────────────────────────────────────────────
	# Здесь она вращалась вокруг себя, и это была ошибка жанра: кувыркается
	# БРОШЕННЫЙ предмет — бумеранг, граната, — а живое, летящее на тебя, держит
	# голову ровно. Крутящаяся собака читалась как чучело, которым кинули.
	if is_instance_valid(_sprite):
		# Морда смотрит туда, куда летит: собака, летящая затылком вперёд,
		# читается как брошенный предмет, а не как живое.
		_sprite.flip_h = _vel.x > 0.0

	_eat_shots()

	if _homing:
		_check_home()
		return
	_bounce_off_walls()

# ── ЛОВИТ ЧУЖИЕ СНАРЯДЫ ────────────────────────────────────────────────────
# Всё, что вылетело из рук Нормальдо, гаснет у неё в зубах. Группа маленькая —
# на экране одновременно два-три каста, — так что покадровый обход дешевле любой
# физики, которую под это пришлось бы заводить.
func _eat_shots() -> void:
	if not is_inside_tree():
		return
	for n in get_tree().get_nodes_in_group(SHOT_GROUP):
		if not (n is Node2D) or not is_instance_valid(n):
			continue
		if global_position.distance_to((n as Node2D).global_position) > BITE_R:
			continue
		(n as Node).queue_free()
		_chomp()

# Щелчок зубами: рывок вперёд и вспышка. БЕЗ ЛАЯ — лай уже занят отскоками, и
# на очереди из трёх карт Джокера собака залаяла бы трижды подряд, перекрыв
# собственный ритм.
func _chomp() -> void:
	if not is_instance_valid(_sprite):
		return
	var tw := _sprite.create_tween()
	tw.tween_property(_sprite, "modulate", Color(2.0, 1.5, 1.4), 0.05)
	tw.tween_property(_sprite, "modulate", Color(1, 1, 1), 0.14)
	var sc := _sprite.scale
	var pop := _sprite.create_tween()
	pop.tween_property(_sprite, "scale", sc * 1.22, 0.06)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.tween_property(_sprite, "scale", sc, 0.12)

# ── ОТСКОК ОТ СТЕН ─────────────────────────────────────────────────────────
# Считается по КАЖДОЙ стене отдельно и с прижимом обратно в поле: иначе на
# быстрой собаке за кадр можно уехать за край настолько, что следующий кадр
# отразит её ещё раз и она залипнет в стене, дрожа на месте.
func _bounce_off_walls() -> void:
	var vp := get_viewport_rect().size
	var hit := false
	if position.x < MARGIN:
		position.x = MARGIN
		_vel.x = absf(_vel.x)
		hit = true
	elif position.x > vp.x - MARGIN:
		position.x = vp.x - MARGIN
		_vel.x = -absf(_vel.x)
		hit = true
	if position.y < MARGIN:
		position.y = MARGIN
		_vel.y = absf(_vel.y)
		hit = true
	elif position.y > vp.y - MARGIN:
		position.y = vp.y - MARGIN
		_vel.y = -absf(_vel.y)
		hit = true
	if not hit:
		return

	_bounces += 1
	_bark()
	if _bounces >= MAX_BOUNCES:
		_go_home()
		return
	# После отскока она СНОВА берёт курс на Нормальдо — но от стены, то есть с
	# новой стороны. Чистое зеркальное отражение отправило бы её гулять по
	# треугольнику мимо игрока, и атака перестала бы быть атакой.
	if is_instance_valid(target):
		var d := target.global_position - position
		if d.length() > 1.0:
			# Половину курса берём от отражения, половину — от направления на
			# цель: так виден и отскок, и намерение.
			_vel = (_vel.normalized() + d.normalized() * 1.35).normalized() * _speed

func _go_home() -> void:
	_homing = true
	var to : Vector2 = owner_node.global_position if is_instance_valid(owner_node) \
		else Vector2(get_viewport_rect().size.x + 120.0, position.y)
	var d := to - position
	_vel = (d.normalized() if d.length() > 1.0 else Vector2.RIGHT) * _speed

func _check_home() -> void:
	var to : Vector2 = owner_node.global_position if is_instance_valid(owner_node) \
		else Vector2(get_viewport_rect().size.x + 120.0, position.y)
	# ДОВОДИМ каждый кадр: хозяин на месте не стоит, и собака, взявшая курс
	# один раз, промахнулась бы мимо него и ушла за край.
	var d := to - position
	if d.length() < 46.0 or position.x > get_viewport_rect().size.x + 100.0:
		_done = true
		came_home.emit()
		queue_free()
		return
	_vel = d.normalized() * _speed

func _bark() -> void:
	if not is_inside_tree():
		return
	var p := AudioStreamPlayer.new()
	p.stream    = SFX_BARK
	p.volume_db = -10.0
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)

# ── СПЕЛЛ ЕЁ НЕ БЕРЁТ ──────────────────────────────────────────────────────
# Раньше собака сбивалась спеллом и «приходила домой». Теперь она снаряды ЕСТ, и
# держать оба поведения нельзя: получилось бы, что один и тот же батаранг то
# гаснет в зубах, то убивает — в зависимости от того, кто из двух путей успел
# первым, физика или покадровый обход.
#
# Поэтому здесь — тот же ответ, что у щитоносца: щёлкнула зубами и побежала
# дальше. Молча проигнорить нельзя, иначе игрок решит, что спелл не сработал, и
# будет жать снова вместо того, чтобы уходить.
#
# Атака от этого бесконечной не становится: её по-прежнему кончают восемь
# отскоков, а с разгоном она их набирает БЫСТРЕЕ, чем набирала раньше.
func on_hit() -> void:
	if _done:
		return
	_chomp()
