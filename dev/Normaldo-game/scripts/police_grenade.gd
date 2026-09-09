extends Area2D

# ── Граната сватовца ─────────────────────────────────────────────────────────
# Летит ПО НАВЕСНОЙ в точку, где Нормальдо был в момент броска, падает и через
# паузу взрывается кругом.
#
# ── ПОЧЕМУ НАВЕСНАЯ, А НЕ ПО ПРЯМОЙ ────────────────────────────────────────
# Прямая — это пуля, и уходить от неё надо С ЛИНИИ. Дуга говорит другое: она
# показывает ТОЧКУ ПАДЕНИЯ заранее, и уходить надо ОТ МЕСТА. Два разных вопроса
# от двух разных бойцов — ровно за этим гранатомётчик в отряде и нужен.
#
# Пауза между падением и взрывом — не «реализм запала», а то самое окно, в
# которое игрок успевает уйти. Без неё граната была бы миной, которая
# срабатывает там, где ты уже стоишь.

const GRENADE_TEX := preload("res://assets/bosses/police/grenade.png")

const GRENADE_PX : float = 30.0
const FLY_T      : float = 0.75
const ARC_H      : float = 130.0    # высота дуги
const FUSE_T     : float = 0.55     # лежит и мигает перед взрывом
const BLAST_R    : float = 92.0     # радиус поражения
const BLAST_T    : float = 0.26     # сколько живёт вспышка

var from_pos : Vector2 = Vector2.ZERO
var to_pos   : Vector2 = Vector2.ZERO
var damage   : int     = 1

var _sprite : Sprite2D = null
var _armed  : bool     = false      # true только на время взрыва

func _ready() -> void:
	collision_layer = 2
	collision_mask  = 0
	position = from_pos

	_sprite = Sprite2D.new()
	_sprite.texture        = GRENADE_TEX
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.z_index        = 4
	ItemSizing.fit_sprite_content(_sprite, GRENADE_PX)
	add_child(_sprite)

	var cs     := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = BLAST_R
	cs.shape      = circle
	# ФОРМА ОТКЛЮЧЕНА ДО ВЗРЫВА. Граната в полёте не бьёт — бьёт взрыв, и
	# включённый круг радиусом в полполосы означал бы урон по всей дуге.
	cs.disabled   = true
	cs.name       = "CollisionShape2D"
	add_child(cs)

	_fly()

# ── ДУГА ВЕДЁТСЯ ТВИНОМ, А НЕ РУЧНЫМ ЦИКЛОМ ────────────────────────────────
# Первым заходом здесь стоял `while t < FLY_T: await process_frame; t += delta`.
# В игре он работал, а headless ВЕШАЛ НАМЕРТВО: там кадры идут так быстро, как
# может процессор, `get_process_delta_time()` возвращает микросекунды, и `t`
# доползал бы до 0.75 за миллионы кадров.
#
# Тест уровней при этом не падал — он просто переставал заканчиваться, а это
# худший вид поломки: непонятно даже, что именно сломалось. Нашлось по тому, что
# прогон, шедший три минуты, встал на четырнадцать.
#
# Твин считает по НАСТОЯЩЕМУ времени и живёт ровно столько, сколько сказано, при
# любой частоте кадров.
func _fly() -> void:
	var tw := create_tween()
	tw.tween_method(func(k: float) -> void:
		if not is_instance_valid(self):
			return
		# Прямая плюс парабола: в середине пути граната поднята на ARC_H.
		position = from_pos.lerp(to_pos, k) - Vector2(0.0, sin(k * PI) * ARC_H)
		if is_instance_valid(_sprite):
			_sprite.rotation = k * FLY_T * 7.0,
		0.0, 1.0, FLY_T)
	await tw.finished
	if not is_instance_valid(self) or not is_inside_tree():
		return
	position = to_pos

	# ЛЕЖИТ И МИГАЕТ. Это и есть окно на уход.
	var blink := create_tween()
	blink.set_loops(int(FUSE_T / 0.12))
	blink.tween_property(_sprite, "modulate", Color(1.6, 0.6, 0.5), 0.06)
	blink.tween_property(_sprite, "modulate", Color(1, 1, 1), 0.06)
	await get_tree().create_timer(FUSE_T).timeout
	if not is_instance_valid(self) or not is_inside_tree():
		return
	_blast()

func _blast() -> void:
	_armed = true
	add_to_group("obstacle")
	var cs := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if cs != null:
		cs.disabled = false
	if is_instance_valid(_sprite):
		_sprite.visible = false

	# Вспышка — круг, который вырастает и гаснет. Рисуется ТЕМ ЖЕ радиусом, что
	# и поражение: нарисовать больше, чем бьёт, значит соврать про опасность,
	# нарисовать меньше — про безопасность.
	var flash := Node2D.new()
	flash.z_index = 5
	add_child(flash)
	var poly := Polygon2D.new()
	var pts  := PackedVector2Array()
	for i in 20:
		var a := TAU * float(i) / 20.0
		pts.append(Vector2(cos(a), sin(a)) * BLAST_R)
	poly.polygon  = pts
	poly.color    = Color(1.0, 0.78, 0.30, 0.85)
	flash.add_child(poly)
	flash.scale = Vector2.ONE * 0.3

	var tw := flash.create_tween()
	tw.tween_property(flash, "scale", Vector2.ONE, BLAST_T * 0.4)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(poly, "color:a", 0.0, BLAST_T)
	await get_tree().create_timer(BLAST_T).timeout
	if is_instance_valid(self):
		queue_free()

# Гранату можно сбить в полёте — как обычный предмет.
func on_hit() -> void:
	if _armed:
		return
	queue_free()
