extends Area2D

const RATTLE_SOUND := preload("res://assets/audio/snake_rattle.mp3")
const SNAKE_TEX    := preload("res://assets/items/snake2.png")
const ItemAura     := preload("res://scripts/item_aura.gd")

# Кобра — единственная угроза, которая не бьёт насмерть, а ЗАМЕДЛЯЕТ, и на общем
# фоне летящего мусора она из-за этого терялась: тёмная, оливковая, размером с
# банан. Свечение — её метка «этот кусает по-своему», и оно того же цвета, что
# и сама змея: тело у неё оливково-зелёное (замер по рисунку — 83,83,52 и
# 136,105,36), поэтому и ореол ядовито-зелёный, а не абстрактно-салатовый. Чужой
# цвет читался бы как подобранный эффект-предмет, а не как своя аура твари.
#
# Сила свечения — 0.40 против 0.75 у предметов-эффектов. Аура эффекта ЗОВЁТ:
# её задача перебить всё вокруг, чтобы предмет заметили и решили, брать ли.
# Кобра ничего не предлагает, ей нужно только пометиться — на полной яркости
# ореол забивал саму змею и читался как подобранный бонус.
const AURA_COLOR : Color = Color(0.55, 0.82, 0.25)
const AURA_PX    : float = 104.0
const AURA_A     : float = 0.40

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

var _anim    : AnimatedSprite2D
var _glow    : Sprite2D = null
var _pulse_t : float    = 0.0

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

	# Аура — ПЕРВЫМ ребёнком, чтобы светилась ПОД змеёй, а не поверх неё.
	_glow = ItemAura.make(AURA_COLOR, AURA_PX, AURA_A)
	add_child(_glow)

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
	if _falling:
		_fall_vel = KnockFall.step(self, self, _fall_vel, _fall_spin, delta)
		if KnockFall.is_gone(self):
			queue_free()
		return
	position.x -= speed * delta
	if position.x < -200.0:
		queue_free()
		return
	_pulse_t += delta * 4.0
	ItemAura.pulse(_glow, 0.5 + 0.5 * sin(_pulse_t), AURA_PX)

# Сбитая змея падает, как любой предмет, — см. `knock_fall.gd`.
var _falling   : bool    = false
var _fall_vel  : Vector2 = Vector2.ZERO
var _fall_spin : float   = 0.0

func knock_down() -> void:
	if _falling:
		return
	_falling   = true
	collision_layer = 0
	_fall_vel  = KnockFall.launch_velocity(speed)
	_fall_spin = KnockFall.launch_spin()
	if is_instance_valid(_glow):
		_glow.visible = false
