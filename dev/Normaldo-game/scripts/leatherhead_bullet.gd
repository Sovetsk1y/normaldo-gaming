extends Area2D

# ── Пуля крокодила ────────────────────────────────────────────────────────────
# Летит ПО ПРЯМОЙ и никуда не доводится. Это принципиально: направление ей
# выдают в момент выстрела, а до выстрела игроку показывают нить прицела (см.
# leatherhead.gd → «Акт 1»). Наводящаяся пуля обесценила бы нить: уходить с
# линии было бы бессмысленно.
#
# В старом проекте пуля тоже летела по прямой, но НИТИ не было — направление
# бралось по голове в кадр выстрела и показывалось только самой пулей. Это не
# уворот, а подбрасывание монетки.

const BULLET_TEX := preload("res://assets/bosses/leatherhead/bullet.png")

var speed  : float   = 700.0
var damage : int     = 1

var _dir : Vector2 = Vector2.LEFT

func init(dir: Vector2, spd: float, px: float = 34.0) -> void:
	_dir  = dir.normalized() if dir.length() > 0.001 else Vector2.LEFT
	speed = spd
	_px   = px

var _px : float = 34.0

func _ready() -> void:
	collision_layer = 2
	collision_mask  = 0
	add_to_group("obstacle")
	add_to_group("bullet")

	var spr := Sprite2D.new()
	spr.texture        = BULLET_TEX
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Пуля нарисована летящей ВЛЕВО, поэтому доворачиваем от направления «влево».
	spr.rotation       = _dir.angle() - PI
	ItemSizing.fit_sprite(spr, _px)
	spr.z_index        = 3
	add_child(spr)

	var cs     := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = _px * 0.34
	cs.shape      = circle
	add_child(cs)

func _process(delta: float) -> void:
	position += _dir * speed * delta
	var vp := get_viewport_rect().size
	if position.x < -160.0 or position.x > vp.x + 160.0 \
			or position.y < -160.0 or position.y > vp.y + 160.0:
		queue_free()

# Пулю можно сбить спеллом — ломается она как обычный предмет.
func on_hit() -> void:
	queue_free()
