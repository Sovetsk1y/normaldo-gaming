extends Area2D

# ── Вызванный боссом клуба ────────────────────────────────────────────────────
# Охранник, коп или девочка. Разные они только картинкой, скоростью и стороной,
# с которой приходят: поведение у всех одно — ИДТИ ПО СВОЕЙ ЛИНИИ И НЕ
# СВОРАЧИВАТЬ.
#
# Не сворачивать — это и есть весь договор с игроком. Босс клуба сам почти не
# бьёт, он звонит, и опасность на экране — это вызванные. Линию, по которой они
# придут, показывают ЗАРАНЕЕ полосой вызова (см. club_boss.gd → `_call_lane`).
# Наводящийся вызванный обесценил бы эту полосу: сходить с линии было бы
# незачем, всё равно догонит.
#
# Отдельным узлом, а не предметом спавнера: во время босса спавнер заморожен,
# и его волны, разгон и таблицы к вызванным отношения не имеют.

var speed  : float = 250.0
var damage : int   = 1

var _dir  : Vector2 = Vector2.LEFT
var _spr  : Sprite2D = null
var _bob  : float = 0.0
var _base_y : float = 0.0

# Покачивание на ходу. Идущий ровной прямой без единого движения читается как
# летящая картинка, а не как персонаж; амплитуда маленькая, чтобы не сбивать
# чтение линии.
const BOB_AMP  : float = 3.0
const BOB_RATE : float = 7.0

func init(tex: Texture2D, px: float, dir: Vector2, spd: float) -> void:
	_dir  = dir.normalized() if dir.length() > 0.001 else Vector2.LEFT
	speed = spd
	_tex  = tex
	_px   = px

var _tex : Texture2D = null
var _px  : float = 74.0

func _ready() -> void:
	collision_layer = 2
	collision_mask  = 0
	add_to_group("obstacle")
	add_to_group("club_minion")
	_base_y = position.y
	_bob    = randf() * TAU

	_spr = Sprite2D.new()
	_spr.texture        = _tex
	_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Нарисованы все лицом ВЛЕВО. Пришедший справа идёт как нарисован, пришедшего
	# слева отражаем — иначе он пятится спиной вперёд.
	_spr.flip_h         = _dir.x > 0.0
	ItemSizing.fit_sprite_content(_spr, _px)
	ItemSizing.anchor_sprite(_spr, 0.5, 0.5)
	_spr.z_index        = 3
	add_child(_spr)

	var cs     := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = _px * 0.34
	cs.shape      = circle
	add_child(cs)

func _process(delta: float) -> void:
	position.x += _dir.x * speed * delta
	_bob += delta * BOB_RATE
	position.y = _base_y + sin(_bob) * BOB_AMP
	var vp := get_viewport_rect().size
	if position.x < -180.0 or position.x > vp.x + 180.0:
		queue_free()

# Сбивается спеллом, как обычный предмет потока.
func on_hit() -> void:
	queue_free()
