extends Area2D

const RATTLE_SOUND := preload("res://assets/audio/snake_rattle.mp3")
const SNAKE_TEX    := preload("res://assets/items/snake2.png")

@export var speed        : float = 250.0
@export var damage       : int   = 1
@export var slow_on_hit  : bool  = true
@export var slow_duration: float = 4.0

# Кадры анимации одинаковы для всех змей — строим SpriteFrames один раз и
# переиспользуем во всех экземплярах, чтобы вспышка спавна не грузила кадры и
# не создавала новый ресурс на каждую змею.
static var _shared_frames : SpriteFrames

# Все змеи делят ОДИН зацикленный «рэтл» вместо персонального
# AudioStreamPlayer на каждую — иначе 20-40 одновременных MP3-декодеров грели
# CPU. Счётчик живых змей включает звук на первой и выключает на последней.
static var _rattle_player : AudioStreamPlayer = null
static var _alive_count   : int = 0

var _anim : AnimatedSprite2D

func _enter_tree() -> void:
	_alive_count += 1

func _exit_tree() -> void:
	_alive_count -= 1
	if _alive_count <= 0:
		_alive_count = 0
		if is_instance_valid(_rattle_player) and _rattle_player.playing:
			_rattle_player.stop()

func _ready() -> void:
	var circle    := CircleShape2D.new()
	circle.radius  = 28.5
	$CollisionShape2D.shape = circle
	add_to_group("obstacle")
	add_to_group("snake")

	# Статичный спрайт (snake2) — заменил анимацию кобры.
	var spr := Sprite2D.new()
	spr.texture        = SNAKE_TEX
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var tsz := SNAKE_TEX.get_size()
	spr.scale = Vector2.ONE * (62.0 / maxf(tsz.x, tsz.y))
	add_child(spr)

	_ensure_rattle()

func _ensure_rattle() -> void:
	if _rattle_player == null or not is_instance_valid(_rattle_player):
		var stream      := (RATTLE_SOUND as AudioStreamMP3).duplicate() as AudioStreamMP3
		stream.loop      = true
		_rattle_player   = AudioStreamPlayer.new()
		_rattle_player.stream    = stream
		_rattle_player.volume_db = -4.0
		get_tree().root.add_child(_rattle_player)
	if not _rattle_player.playing:
		_rattle_player.play()

func _process(delta: float) -> void:
	position.x -= speed * delta
	if position.x < -200.0:
		queue_free()
