extends Area2D

# ── Сейф ──────────────────────────────────────────────────────────────────────
# Единственный предмет в игре, за удар о который ПЛАТЯТ. Сейф бьёт на 2 — как и
# раньше, самое тяжёлое в потоке, — но тем же ударом ВСКРЫВАЕТСЯ: перелетает
# Нормальдо на голову, раскрывается и высыпает доллары, а с небольшим шансом и
# мешок с деньгами. Потом отваливается и падает вниз, как любой сбитый предмет.
#
# Зачем предмету, который бьёт, ещё и платить. До этого сейф был просто самым
# дорогим способом потерять жир: медленный, крупный, два урона — и ничего
# взамен. Читался он при этом как СЕЙФ, то есть как ящик с деньгами, и то, что
# из него ничего не сыпалось, было прямым обманом рисунка.
#
# Теперь это ЕДИНСТВЕННАЯ в игре сделка: половина жировой полосы в обмен на
# пачку долларов. Решение принимает игрок, и оно настоящее — на полном жире
# сейф выгоден, на последнем делении это самоубийство.
#
# Вскрывает его УДАР ГОЛОВОЙ — и удар, прошедший сквозь резист, тоже. Резист
# (венец викинга, десятый уровень) отменяет урон, но не отменяет того, что по
# ящику ударили: сейф вскрыт, деньги высыпались, а заплатил за них не жир, а
# прокачанный до конца скин. Это и есть награда за венец.
#
# А вот бумбокс, молотов и спеллы сейф просто уничтожают: вскрывает его ВСТРЕЧА
# С ГОЛОВОЙ, а не факт разрушения. Иначе любой снаряд издалека превращал бы
# сейф в бесплатный банкомат, и сделки бы не осталось.
#
# См. /Концепция/Эффекты и бонусы.md, /Концепция/Уровни/1-Канализация.md

const TEX_CLOSED := preload("res://assets/items/safe.png")
# Открытый кадр — отдельный рисунок. Грузится по пути, а не preload'ом: пока
# файла нет, обе фазы идут закрытым кадром, и подстановка файла включает
# раскрытие сама, без правки кода.
const TEX_OPEN_PATH : String = "res://assets/items/safe_open.png"

const DOLLAR_TEX := preload("res://assets/items/dollar.png")
const ITEM_SCENE := preload("res://scenes/item.tscn")
const MONEY_BAG_SCENE := preload("res://scenes/money_bag.tscn")
const OPEN_SFX := preload("res://assets/audio/dollars.mp3")

const SAFE_PX     : float = 78.0
const SPEED_MULT  : float = 0.78

# Сколько долларов высыпается и с каким шансом вместо одного из них выпадет
# мешок. Восемь — как у мэджик бокса: сейф работает тем же тактом, и платить он
# должен сопоставимо, иначе один из двух «ящиков» обесценивает другой.
#
# Мешок редкий НАМЕРЕННО. Он сам по себе событие (знак валюты во весь экран, см.
# money_bag.gd), и падай он с сейфа через раз, событием быть перестал бы — а
# сейф превратился бы в самый выгодный предмет потока при цене в два урона.
const COIN_COUNT  : int   = 8
const BAG_CHANCE  : float = 0.12

const HEAD_OFFSET : Vector2 = Vector2(0.0, -66.0)
const HOP_T       : float   = 0.20
const SPIT_PERIOD : float   = 0.16
const FLY_TIME    : float   = 0.30
const LANE_COUNT  : int     = 5
# Куда раскидывать: не ближе четверти экрана (иначе прилетает в лицо) и не
# дальше 0.85 (иначе улетает за правый край раньше, чем долетит). Числа те же,
# что у мэджик бокса, и это не совпадение — такт один и тот же.
const SPREAD_X_MIN : float = 0.28
const SPREAD_X_MAX : float = 0.85
# Где в открытом кадре середина ЯЩИКА, долей ширины рисунка. Дверь занимает
# левую треть, ящик — остальное.
const BOX_ANCHOR_X : float = 0.65

@export var speed  : float = 250.0
@export var damage : int   = 2

var _sprite  : Sprite2D = null
var _opened  : bool     = false
var _carrier : Node2D   = null
var _falling : bool     = false
var _fall_vel : Vector2 = Vector2.ZERO

func _ready() -> void:
	speed *= SPEED_MULT
	collision_layer = 2
	collision_mask  = 0
	# Группа `safe` — то, по чему резист узнаёт предмет (см. normaldo._area_tag),
	# `obstacle` — то, по чему он попадает в ветку удара.
	add_to_group("safe")
	add_to_group("obstacle")

	_sprite = Sprite2D.new()
	_sprite.texture = TEX_CLOSED
	ItemSizing.fit_sprite_content(_sprite, SAFE_PX)
	add_child(_sprite)

	var cs := CollisionShape2D.new()
	var c  := CircleShape2D.new()
	c.radius = SAFE_PX * 0.42
	cs.shape = c
	add_child(cs)

func _process(delta: float) -> void:
	if _falling:
		_fall_vel.y      += 900.0 * delta
		position         += _fall_vel * delta
		_sprite.rotation += 2.4 * delta
		if position.y > get_viewport_rect().size.y + 240.0:
			queue_free()
		return
	if _opened:
		# Пока раскрыт — сидит на голове и едет вместе с ней.
		if is_instance_valid(_carrier):
			position = _carrier.position + HEAD_OFFSET
		return
	position.x -= speed * delta
	if position.x < -220.0:
		queue_free()

# ── Вскрытие ──────────────────────────────────────────────────────────────────
# Зовёт `normaldo._crack_or_kill` — из двух мест: из ветки настоящего удара,
# СРАЗУ ПОСЛЕ того, как урон уже нанесён (сначала цена, потом товар; обратный
# порядок читался бы как «дали денег и зачем-то ударили»), и из ветки резиста,
# где цены не было вовсе.
func crack_open(catcher: Node2D) -> void:
	if _opened or _falling:
		return
	_opened         = true
	_carrier        = catcher
	collision_layer = 0

	_play(OPEN_SFX)
	var hop := create_tween()
	hop.tween_property(self, "position", catcher.position + HEAD_OFFSET, HOP_T)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await hop.finished
	if not is_inside_tree():
		return
	_open_frame()

	# Мешок решается ОДИН раз на вскрытие и занимает место одного доллара: иначе
	# «маленький шанс» умножился бы на восемь и перестал быть маленьким.
	var bag_at : int = randi() % COIN_COUNT if randf() < BAG_CHANCE else -1
	var lanes := _lane_centers()
	var last_lane : int = -1
	for i in COIN_COUNT:
		if not is_inside_tree():
			return
		# Подряд в один лейн не кидаем — иначе доллары садятся друг на друга.
		var lane := randi() % LANE_COUNT
		if lane == last_lane:
			lane = (lane + 1 + randi() % (LANE_COUNT - 1)) % LANE_COUNT
		last_lane = lane
		_spit(i == bag_at, Vector2(
			get_viewport_rect().size.x * randf_range(SPREAD_X_MIN, SPREAD_X_MAX),
			float(lanes[lane])))
		await get_tree().create_timer(SPIT_PERIOD).timeout

	if not is_inside_tree():
		return
	_drop_off()

# Пустой сейф ОТВАЛИВАЕТСЯ и падает — тем же движением, каким падает любой
# сбитый предмет (`item.knock_down`). Растаять на голове он не может: это
# железный ящик, и исчезнуть в воздухе ему нечем.
func _drop_off() -> void:
	_opened  = false
	_carrier = null
	_falling = true
	_fall_vel = Vector2(-speed * 0.25, -90.0)

func _open_frame() -> void:
	if not ResourceLoader.exists(TEX_OPEN_PATH):
		return
	var t := load(TEX_OPEN_PATH) as Texture2D
	if t == null:
		return
	_sprite.texture = t
	# Размер считаем ПО ВЫСОТЕ, а не по длинной стороне. У открытого сейфа
	# длинная сторона включает распахнутую дверь: подгони его как обычный
	# предмет — и ящик на глазах у игрока ужмётся вдвое, будто сейф не открылся,
	# а отъехал. Высота у обеих поз одна, по ней и равняем: ящик остаётся того
	# же роста, а дверь честно добавляет ширины.
	var closed := ItemSizing.content_rect(TEX_CLOSED)
	var open_r := ItemSizing.content_rect(t)
	var closed_h : float = float(closed.size.y) * ItemSizing.content_scale(TEX_CLOSED, SAFE_PX)
	_sprite.scale = Vector2.ONE * (closed_h / maxf(1.0, float(open_r.size.y)))
	# Держим на месте ЯЩИК, а не рамку рисунка. Дверь распахнута влево и занимает
	# примерно треть кадра: центрируй по рамке — и ящик уедет вправо, будто сейф
	# в момент раскрытия подпрыгнул вбок.
	ItemSizing.anchor_sprite(_sprite, BOX_ANCHOR_X, 0.5)

func _lane_centers() -> Array:
	var h := get_viewport_rect().size.y
	var out : Array = []
	for i in LANE_COUNT:
		out.append(h / LANE_COUNT * (float(i) + 0.5))
	return out

# Один доллар (или мешок) вылетает из сейфа по дуге и, долетев, становится
# обычной добычей. Пока летит — не двигается сам и не ловится: пойманный в
# полёте, он обесценил бы весь такт (ударился — и сразу деньги в руке).
func _spit(as_bag: bool, to: Vector2) -> void:
	var parent := get_parent()
	if parent == null:
		return
	var node : Node2D = MONEY_BAG_SCENE.instantiate() if as_bag else _make_dollar()
	node.position = position
	if node.get("speed") != null:
		node.speed = speed / SPEED_MULT
	parent.add_child(node)

	node.set_process(false)
	var had_layer : int = node.collision_layer if node is CollisionObject2D else 2
	if node is CollisionObject2D:
		node.collision_layer = 0

	var tw := node.create_tween()
	tw.tween_property(node, "position", to, FLY_TIME)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void:
		if not is_instance_valid(node):
			return
		if node is CollisionObject2D:
			node.collision_layer = had_layer
		node.set_process(true))

func _make_dollar() -> Node2D:
	var d := ITEM_SCENE.instantiate()
	d.speed      = speed / SPEED_MULT
	d.is_eatable = false
	d.damage     = 0
	d.rotates    = true
	d.pulses     = true
	d.item_group = "dollar"
	var spr : Sprite2D = d.get_node("Sprite2D")
	spr.texture = DOLLAR_TEX
	spr.scale   = Vector2.ONE * 0.36
	return d

func _play(stream: AudioStream) -> void:
	var parent := get_parent()
	if parent == null:
		return
	var a := AudioStreamPlayer.new()
	a.stream = stream
	parent.add_child(a)
	a.play()
	a.finished.connect(a.queue_free)
