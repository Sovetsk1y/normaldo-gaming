extends Area2D

# ── ЗЕРКАЛО ──────────────────────────────────────────────────────────────────
# Подбирается Нормальдо и на пять секунд ОТРАЖАЕТ МИР: фон переворачивается по
# горизонтали, а поток предметов идёт слева направо — и те, что уже летят,
# разворачиваются вместе с новыми.
#
# Раньше это делал компас, и это было неверно по смыслу: компас — про
# направление, которое ты держишь сам, и его дело сбивать РУКУ. Отражает мир
# зеркало, и другого предмета для этого не нужно.
#
# Урона не наносит: под невидимостью пролетает насквозь, как любой негативный.

const TEX := preload("res://assets/items/mirror.png")

@export var speed : float = 250.0
var damage : int = 0

func _ready() -> void:
	collision_layer = 2
	collision_mask  = 0
	add_to_group("mirror")
	var spr := Sprite2D.new()
	spr.texture        = TEX
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var tsz := TEX.get_size()
	spr.scale = Vector2.ONE * (58.0 / maxf(tsz.x, tsz.y))
	add_child(spr)
	var cs := CollisionShape2D.new()
	var c  := CircleShape2D.new()
	c.radius = 27.0
	cs.shape = c
	add_child(cs)
	# Покачивается, а не крутится: крутящееся зеркало не показывает ничего, а
	# качающееся ловит свет — и читается зеркалом, а не монеткой.
	var tw := create_tween().set_loops()
	tw.tween_property(spr, "rotation", 0.22, 0.9)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(spr, "rotation", -0.22, 0.9)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _process(delta: float) -> void:
	ItemFlow.advance(self, speed, delta)
	if ItemFlow.gone(self, 200.0):
		queue_free()
