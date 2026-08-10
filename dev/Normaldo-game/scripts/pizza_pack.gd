extends Area2D

const CLOSED_TEX  := preload("res://assets/items/pizza_pack_closed.png")
const SFX         := preload("res://assets/audio/super_pizza.mp3")
const PIZZA_SCENE := preload("res://scenes/item.tscn")
const PIZZA_TEX   := preload("res://assets/items/pizza.png")

const PACK_HEAD_OFFSET := Vector2(0.0, -60.0)
const EFFECT_DURATION  := 2.5

# Сколько считаем добычу «супер пиццы» для множителя рейта. Взрыв превращает
# препятствия в пиццу по всему экрану, и до дальних Нормальдо долетает уже
# после того, как сам пакет истаял: при 250 px/s правый край едет к голове
# ~3.8 c. Поэтому окно учёта заметно длиннее EFFECT_DURATION.
# См. loot_multiplier.gd
const TALLY_WINDOW := 5.5

@export var speed: float = 250.0

var _active   : bool   = false
var _pulse_t  : float  = 0.0
var _normaldo : Node2D = null

@onready var _sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	_sprite.texture = CLOSED_TEX
	_sprite.scale   = Vector2.ONE * 0.08
	collision_layer = 2
	collision_mask  = 0
	add_to_group("pizza_pack")
	var circle      := CircleShape2D.new()
	circle.radius    = 34.0
	$CollisionShape2D.shape = circle

func _process(delta: float) -> void:
	_pulse_t      += delta * 3.5
	_sprite.scale  = Vector2.ONE * (0.08 + sin(_pulse_t) * 0.010)
	if _active:
		if _normaldo and is_instance_valid(_normaldo):
			position = _normaldo.position + PACK_HEAD_OFFSET
		return
	position.x -= speed * delta
	if position.x < -200.0:
		queue_free()

func explode() -> void:
	if _active:
		return
	_active         = true
	collision_layer = 0

	_normaldo = get_parent().get_parent().get_node_or_null("Normaldo") as Node2D
	if _normaldo:
		position = _normaldo.position + PACK_HEAD_OFFSET

	var audio        := AudioStreamPlayer.new()
	audio.stream      = SFX
	get_parent().add_child(audio)
	audio.play()
	audio.finished.connect(audio.queue_free)

	var ptc                      := CPUParticles2D.new()
	ptc.emitting                  = true
	ptc.amount                    = 28
	ptc.lifetime                  = 0.65
	ptc.local_coords              = false
	ptc.direction                 = Vector2(0.0, 1.0)
	ptc.spread                    = 50.0
	ptc.gravity                   = Vector2.ZERO
	ptc.initial_velocity_min      = 35.0
	ptc.initial_velocity_max      = 90.0
	ptc.scale_amount_min          = 3.0
	ptc.scale_amount_max          = 6.0
	ptc.color                     = Color(1.0, 0.55, 0.1, 1.0)
	ptc.position                  = Vector2(0.0, 12.0)
	add_child(ptc)

	# Учёт добычи для множителя ×1…×5 стартует ДО превращения — иначе первые
	# пиццы, съеденные вплотную к голове, в бросок не попадут. Ждёт и начисляет
	# сама голова: пакет к концу окна учёта уже освобождён.
	if _normaldo and _normaldo.has_method("run_loot_tally"):
		_normaldo.run_loot_tally(TALLY_WINDOW, get_parent())

	var spawner := get_parent()
	var to_transform : Array = []
	for child in spawner.get_children():
		if child == self: continue
		if child.is_in_group("pizza") or child.is_in_group("dollar"): continue
		if child.is_in_group("obstacle") or child.is_in_group("slowing") or child.is_in_group("bomb"):
			to_transform.append(child)

	for node in to_transform:
		if not is_instance_valid(node): continue
		var pos       = node.position
		var spd       := (node.get("speed") as float) if node.get("speed") != null else speed
		node.queue_free()
		var pizza         := PIZZA_SCENE.instantiate()
		pizza.speed        = spd
		pizza.is_eatable   = true
		pizza.pulses       = true
		var spr: Sprite2D  = pizza.get_node("Sprite2D")
		spr.texture        = PIZZA_TEX
		spr.scale          = Vector2.ONE * 0.09
		pizza.position     = pos
		spawner.add_child(pizza)

	_screen_shake()
	Input.vibrate_handheld(250)
	_white_flash()

	await get_tree().create_timer(EFFECT_DURATION).timeout
	ptc.emitting = false
	var tw := create_tween()
	tw.tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 0.0), 0.30)
	tw.tween_callback(queue_free)

func _screen_shake() -> void:
	var game := get_parent().get_parent() as Node2D
	if not game: return
	var tw  := game.create_tween()
	var amp := 14.0
	for i in 8:
		var pos := Vector2(randf_range(-amp, amp), randf_range(-amp * 0.75, amp * 0.75))
		tw.tween_property(game, "position", pos, 0.03)
		amp *= 0.78
	tw.tween_property(game, "position", Vector2.ZERO, 0.06)

func _white_flash() -> void:
	var game := get_parent().get_parent() as Node2D
	if not game: return
	var flash     := ColorRect.new()
	flash.color    = Color(1.0, 1.0, 1.0, 0.85)
	flash.size     = get_viewport_rect().size
	flash.position = Vector2.ZERO
	flash.z_index  = 100
	game.add_child(flash)
	var tw := flash.create_tween()
	tw.tween_property(flash, "modulate:a", 0.0, 0.30) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(flash.queue_free)
