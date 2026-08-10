extends Area2D

# ── Ниндзя ────────────────────────────────────────────────────────────────────
# Единственный предмет, который не просто пролетает мимо: ниндзя ВЪЕЗЖАЕТ на
# экран, тормозит примерно на трёх четвертях ширины, кидает веер сюрикенов по
# голове и уходит рывком влево.
#
# Смысл в том, что все остальные угрозы читаются по позиции — увидел лейн, ушёл
# с лейна. Сюрикен наводится на голову в момент броска (shuriken.gd), поэтому
# ниндзя — единственная угроза, от которой нельзя уклониться заранее: надо
# двигаться ПОСЛЕ броска. Отсюда и телеграф: перед каждым броском ниндзя
# вспыхивает красным, у игрока есть THROW_TELEGRAPH секунд.
#
# Сам ниндзя тоже бьёт при касании (группа obstacle, урон 1).
#
# См. /Концепция/Паттерны препятствий.md → «Ниндзя»

const NINJA_TEX      := preload("res://assets/bosses/ninja_foot/ninja_foot1.png")
const SHURIKEN_SCENE := preload("res://scenes/shuriken.tscn")
const THROW_SFX      := preload("res://assets/audio/shurikens.mp3")
const SMOKE_TEX      := preload("res://assets/bosses/ninja_foot/ninja_foot_smoke.png")

# Ниндзя крупнее рядового предмета — он «персонаж», а не мусор в трубе.
const NINJA_PX : float = 96.0

const ENTER_SPEED_MULT : float = 1.9    # въезд быстрее потока предметов
const PARK_X_RATIO     : float = 0.74   # где тормозит (доля ширины экрана)
const THROW_COUNT      : int   = 3
const THROW_INTERVAL   : float = 0.75
const THROW_TELEGRAPH  : float = 0.35   # вспышка перед броском
const SHURIKEN_SPEED   : float = 430.0
const EXIT_SPEED_MULT  : float = 2.6    # рывок на выход

@export var speed : float = 250.0

var damage : int = 1

enum State { ENTER, ATTACK, EXIT }
var _state    : int     = State.ENTER
var _park_x   : float   = 0.0
var _bob_t    : float   = 0.0
var _normaldo : Node2D  = null
var _sprite   : Sprite2D = null

func _ready() -> void:
	collision_layer = 2
	collision_mask  = 0
	add_to_group("obstacle")
	add_to_group("ninja")

	_sprite = Sprite2D.new()
	_sprite.texture = NINJA_TEX
	ItemSizing.fit_sprite(_sprite, NINJA_PX)
	add_child(_sprite)

	var cs    := CollisionShape2D.new()
	var rect  := RectangleShape2D.new()
	rect.size  = Vector2(NINJA_PX * 0.5, NINJA_PX * 0.8)
	cs.shape   = rect
	add_child(cs)

	_park_x   = get_viewport_rect().size.x * PARK_X_RATIO
	_normaldo = _find_normaldo()
	_puff()

func _find_normaldo() -> Node2D:
	var p := get_parent()
	if p == null:
		return null
	var root := p.get_parent()
	if root == null:
		return null
	return root.get_node_or_null("Normaldo") as Node2D

func _process(delta: float) -> void:
	# Лёгкое покачивание — «висит в воздухе», а не приклеен к лейну.
	_bob_t += delta * 4.0
	_sprite.position.y = sin(_bob_t) * 4.0

	match _state:
		State.ENTER:
			position.x -= speed * ENTER_SPEED_MULT * delta
			if position.x <= _park_x:
				position.x = _park_x
				_state     = State.ATTACK
				_run_attack()
		State.ATTACK:
			pass   # висит на месте, бросками управляет _run_attack()
		State.EXIT:
			position.x -= speed * EXIT_SPEED_MULT * delta
			if position.x < -200.0:
				queue_free()

func _run_attack() -> void:
	for i in THROW_COUNT:
		if not is_instance_valid(self):
			return
		await _telegraph()
		if not is_instance_valid(self):
			return
		_throw()
		if i < THROW_COUNT - 1:
			await get_tree().create_timer(THROW_INTERVAL).timeout
	if not is_instance_valid(self):
		return
	await get_tree().create_timer(0.35).timeout
	if not is_instance_valid(self):
		return
	_puff()
	_state = State.EXIT

# Красная вспышка-предупреждение: у игрока есть THROW_TELEGRAPH, чтобы начать
# уходить с линии броска.
func _telegraph() -> void:
	var tw := create_tween()
	tw.tween_property(_sprite, "modulate", Color(1.6, 0.45, 0.45), THROW_TELEGRAPH * 0.5)
	tw.tween_property(_sprite, "modulate", Color(1.0, 1.0, 1.0), THROW_TELEGRAPH * 0.5)
	await tw.finished

func _throw() -> void:
	var sh := SHURIKEN_SCENE.instantiate()
	sh.position = position + Vector2(-NINJA_PX * 0.35, 0.0)
	get_parent().add_child(sh)
	# Наводится на голову в момент вылета — уклоняться надо после броска.
	sh.init(_normaldo, SHURIKEN_SPEED, 0.0)

	var audio := AudioStreamPlayer.new()
	audio.stream = THROW_SFX
	get_parent().add_child(audio)
	audio.play()
	audio.finished.connect(audio.queue_free)

	# Отдача.
	var tw := create_tween()
	tw.tween_property(self, "position:x", position.x + 14.0, 0.08)
	tw.tween_property(self, "position:x", position.x, 0.14)

# Клуб дыма на появлении и на уходе — ниндзя же.
func _puff() -> void:
	var s := Sprite2D.new()
	s.texture        = SMOKE_TEX
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var sc := ItemSizing.fit_scale(SMOKE_TEX, NINJA_PX * 1.3)
	s.scale    = Vector2.ONE * sc * 0.4
	s.position = position
	s.z_index  = 2
	# Через deferred: _puff() зовётся в том числе из _ready(), а в этот момент
	# родитель ещё занят добавлением самого ниндзя и обычный add_child падает.
	get_parent().add_child.call_deferred(s)
	await get_tree().process_frame
	if not is_instance_valid(s):
		return
	var tw := s.create_tween()
	tw.set_parallel(true)
	tw.tween_property(s, "scale", Vector2.ONE * sc, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(s, "modulate:a", 0.0, 0.42)
	tw.chain().tween_callback(s.queue_free)
