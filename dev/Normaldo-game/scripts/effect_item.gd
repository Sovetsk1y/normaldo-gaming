extends Area2D

# ── Предметы-эффекты ──────────────────────────────────────────────────────────
# Один скрипт на восемь предметов: все они летят справа налево как обычный
# предмет и срабатывают в момент касания — вся разница только в спрайте, группе
# и «настроении» (свечение/вращение). Сам эффект живёт в normaldo.gd, здесь его
# нет намеренно: эффекты трогают жир, доллары и иммунитеты, то есть состояние
# головы, а не предмета.
#
#   песочные часы  — замедление мира
#   маска Кейси    — иммунитет к физическому урону
#   шляпа мага     — иммунитет к замедлению
#   банка колы     — ускорение
#   чек лузера     — обнуляет доллары забега
#   наручники      — мгновенная смерть
#   чёрный туз     — сжигает жир до минимума
#   жетон          — валюта автомата
#
# Размер спрайта считает ItemSizing — исходники различаются в разы (жетон 89 px,
# шляпа 615 px), поэтому ручные scale здесь запрещены.
#
# См. /Концепция/Эффекты и бонусы.md

const TEX : Dictionary = {
	"hourglass":    preload("res://assets/items/hourglass.png"),
	"casey_mask":   preload("res://assets/items/casey_mask.png"),
	"magic_hat":    preload("res://assets/items/magic_hat.png"),
	"cola":         preload("res://assets/items/cola.png"),
	"loser_ticket": preload("res://assets/items/loser_ticket.png"),
	"handcuffs":    preload("res://assets/items/handcuffs.png"),
	"black_ace":    preload("res://assets/items/black_ace.png"),
	"casino_chip":  preload("res://assets/items/token.png"),
}

# Цвет ауры под предметом. Считывается и как подсказка: холодные оттенки —
# полезное, красные — смертельное.
const AURA : Dictionary = {
	"hourglass":    Color(0.55, 0.85, 1.00),
	"casey_mask":   Color(0.70, 0.35, 1.00),
	"magic_hat":    Color(0.45, 0.60, 1.00),
	"cola":         Color(1.00, 0.35, 0.30),
	"loser_ticket": Color(1.00, 0.85, 0.20),
	"handcuffs":    Color(1.00, 0.20, 0.20),
	"black_ace":    Color(0.85, 0.20, 0.55),
	"casino_chip":  Color(1.00, 0.80, 0.15),
}

# Крутятся только те предметы, у которых нет «верха»: карта, жетон, часы.
const SPINS : Array = ["hourglass", "black_ace", "casino_chip"]

@export var speed : float = 250.0
@export var kind  : String = "hourglass"

var _pulse_t   : float    = 0.0
var _spin      : bool     = false
var _glow      : Sprite2D = null
var _sprite    : Sprite2D = null

func _ready() -> void:
	collision_layer = 2
	collision_mask  = 0
	add_to_group(kind)
	# Наручники и туз ещё и obstacle: так их сносит бумбокс, жжёт молотов и
	# превращает в пиццу «супер пицца» — как любую другую угрозу.
	if kind == "handcuffs" or kind == "black_ace":
		add_to_group("obstacle")

	_build_glow()   # первым — чтобы аура рисовалась ПОД спрайтом

	_sprite = Sprite2D.new()
	_sprite.texture = TEX.get(kind, TEX["hourglass"])
	# Чуть крупнее рядового предмета: эффект надо УВИДЕТЬ и решить, брать ли, а
	# ресурсы и опасности вокруг мельтешат постоянно.
	ItemSizing.fit_sprite_content(_sprite, ItemSizing.BASE_PX * 1.12)
	_sprite.z_index = 1
	add_child(_sprite)

	var cs        := CollisionShape2D.new()
	var circle    := CircleShape2D.new()
	circle.radius  = ItemSizing.BASE_R * 0.9
	cs.shape       = circle
	add_child(cs)

	_spin = kind in SPINS

func _build_glow() -> void:
	var col : Color = AURA.get(kind, Color(1, 1, 1))
	var grad := Gradient.new()
	grad.set_color(0, Color(col.r, col.g, col.b, 0.75))
	grad.set_color(1, Color(col.r, col.g, col.b, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient  = grad
	gt.fill      = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to   = Vector2(0.5, 0.0)
	gt.width     = 96
	gt.height    = 96

	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

	_glow = Sprite2D.new()
	_glow.texture  = gt
	_glow.material = mat
	_glow.z_index  = 0
	add_child(_glow)

func _process(delta: float) -> void:
	position.x -= speed * delta
	if position.x < -200.0:
		queue_free()
		return

	_pulse_t += delta * 4.0
	var p := 0.5 + 0.5 * sin(_pulse_t)
	if _spin:
		_sprite.rotation += delta * 2.2
	if is_instance_valid(_glow):
		_glow.scale    = Vector2.ONE * lerpf(0.85, 1.25, p)
		_glow.modulate = Color(1.0, 1.0, 1.0, lerpf(0.55, 1.0, p))
