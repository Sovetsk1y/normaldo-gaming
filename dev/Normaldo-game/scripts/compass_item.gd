extends Area2D

# Компас — подбирается Нормальдо и на 5 c РЕВЕРСИТ управление: свайп вправо двигает
# влево, по вертикали тоже наоборот. Не наносит урона. Спавнер добавляет в группу.

const TEX := preload("res://assets/items/compass.png")

@export var speed : float = 250.0
var damage : int = 0

func _ready() -> void:
	collision_layer = 2
	collision_mask  = 0
	add_to_group("compass")
	var spr := Sprite2D.new()
	spr.texture        = TEX
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var tsz := TEX.get_size()
	spr.scale = Vector2.ONE * (54.0 / maxf(tsz.x, tsz.y))
	add_child(spr)
	var cs := CollisionShape2D.new()
	var c  := CircleShape2D.new()
	c.radius = 27.0
	cs.shape = c
	add_child(cs)
	# Медленно крутится — «стрелка компаса».
	var tw := create_tween().set_loops()
	tw.tween_property(spr, "rotation", TAU, 3.0)

func _process(delta: float) -> void:
	position.x -= speed * delta
	if position.x < -200.0:
		queue_free()
