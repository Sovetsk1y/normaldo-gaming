extends Area2D

# ── ГРИБ ──────────────────────────────────────────────────────────────────────
# Плохой предмет, встречается на ЛЮБОЙ локации. Урона не наносит — он отравляет:
# восемь секунд игра выглядит и слушается не так, как обычно.
#
# Четыре порчи разом, и это не набор ради набора, а одна мысль с четырёх сторон:
#   • цвет фона вывернут наизнанку,
#   • управление перевёрнуто,
#   • шаг замедлен,
#   • музыка играет задом наперёд,
#   • и всё на экране — пицца. И всё, что вылетит дальше, тоже пицца.
#
# Последнее и есть шутка целиком: игрок весь забег учился отличать съедобное от
# бьющего, а тут ему говорят, что съедобно ВСЁ. Опасность при этом никуда не
# делась — просто её больше не видно, и восемь секунд надо доигрывать по памяти
# о том, где что летело.
#
# Урона нет НАМЕРЕННО. Гриб и так забирает у игрока всё, чем он играет: зрение,
# руку и скорость. Отнять сверху ещё и жир значило бы сделать его не смешным, а
# несправедливым — а он про «что сейчас было», а не про «за что».
#
# См. /Концепция/Предметы.md, scripts/normaldo.gd (apply_shroom)

const TEX := preload("res://assets/items/mushroom.png")

const PX     : float = 58.0
const RADIUS : float = 28.0

@export var speed : float = 250.0
var damage : int = 0

func _ready() -> void:
	collision_layer = 2
	collision_mask  = 0
	add_to_group("mushroom")
	# Не в группе `obstacle`: тот путь ведёт в расчёт урона, а гриб не бьёт.
	# Своя группа — свой разбор в `normaldo._on_area_entered`.
	set_meta("item_tag", "mushroom")

	var spr := Sprite2D.new()
	spr.texture        = TEX
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ItemSizing.fit_sprite_content(spr, PX)
	add_child(spr)

	var cs := CollisionShape2D.new()
	var c  := CircleShape2D.new()
	c.radius = RADIUS
	cs.shape = c
	add_child(cs)

	# Покачивается, а не крутится: гриб растёт, у него есть верх и низ, и
	# перевёрнутая шляпка читалась бы как «ещё один вращающийся предмет».
	var tw := create_tween().set_loops()
	tw.tween_property(spr, "rotation", 0.18, 0.9).set_trans(Tween.TRANS_SINE)
	tw.tween_property(spr, "rotation", -0.18, 0.9).set_trans(Tween.TRANS_SINE)

func _process(delta: float) -> void:
	ItemFlow.advance(self, speed, delta)
	if ItemFlow.gone(self, 200.0):
		queue_free()
