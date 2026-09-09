extends Area2D

# ── КОРОБКА ПИЦЦЫ — ключ к мини-игре ПИЦЦА-ПАТИ ──────────────────────────────
# Летит через экран как обычный предмет (случайная полоса, справа налево) и сама
# убирается за краем, если её не поймали. Ничего не замораживает и не чистит:
# мини-игру включает ИМЕННО ПОЙМАННАЯ коробка (`normaldo.gd`, группа
# "pizza_box").
#
# ── ЗАЧЕМ ОНА ВООБЩЕ ────────────────────────────────────────────────────────
# Раньше ПИЦЦА-ПАТИ включалась САМА, по броску кубика раз в кадр. Со стороны
# игрока это выглядело так: он бежит, и вдруг экран замирает, полкадра
# отгораживают, прилетает гигантская пачка. Ни причины, ни его участия — просто
# случилось. Мини-игра при этом даёт добычу, то есть это НАГРАДА, а награда,
# которая падает сама, наградой не читается.
#
# Теперь её надо ПОЙМАТЬ. Тот же договор, что у мутагена, и договор этот в игре
# уже есть — игрок его знает: светящийся предмет в потоке = сейчас будет
# мини-игра, дотянись до него.
#
# ── ЧЕМ ОТЛИЧАЕТСЯ ОТ СУПЕР-ПИЦЦЫ ───────────────────────────────────────────
# Картинка у них одна — та же коробка (`pizza_pack.gd` тоже её берёт), и это
# осознанно: обе про «сейчас будет много пиццы». Различает их СВЕЧЕНИЕ. У
# супер-пиццы его нет вовсе, она просто чуть пульсирует; у ключа — лучи, сияние
# и фонтан частиц, тот же самый эффект, что у мутагена, только оранжевый.
#
# Это и есть язык: светится — значит меняет экран целиком. Зелёное зовёт в
# ЖИРОБОССА, оранжевое — в ПИЦЦА-ПАТИ. Ключ вдобавок заметно КРУПНЕЕ
# супер-пиццы, чтобы их не путать даже боковым зрением.

const TEX       := preload("res://assets/items/pizza_pack_closed.png")
const SHINE_SFX := preload("res://assets/audio/shine.mp3")

# Свечение — ОБЩИЙ КИРПИЧ, тот же, что у мутагена. См. scripts/minigame_glow.gd:
# знак работает, только пока он один и тот же, и разойтись двум копиям тут
# нечему — числа одни, цвет довод.
const GLOW := preload("res://scripts/minigame_glow.gd")

# ОРАНЖЕВЫЙ — цвет самой пиццы на коробке, а не «просто тёплый». Свечение обязано
# читаться как свет ОТ НЕЁ; возьми оттенок мимо — и выйдет предмет в чужой
# подсветке.
const COL_GLOW  : Color = Color(1.00, 0.60, 0.15)
const COL_PP    : Color = Color(1.00, 0.55, 0.12)
# Вспышка лица на пике биения. Красный и зелёный ВЫШЕ единицы — пересвет, как у
# мутагена: предмет должен вспыхивать, а не просто желтеть.
const COL_BLINK : Color = Color(1.70, 1.05, 0.35)

@export var speed : float = 240.0

# Размер. Супер-пицца в потоке — 0.08, эта заметно крупнее: она не добыча, а
# событие. Биение — те же доли, что у мутагена (±20 % вокруг своего размера).
const SIZE_LO : float = 0.125
const SIZE_HI : float = 0.175

# Окно реакции на близость: на PROX_FAR спокойный фон, на PROX_NEAR всё на
# максимуме — фонтан, тряска, громкий звон.
const PROX_FAR  : float = 420.0
const PROX_NEAR : float = 45.0
const SHINE_RANGE : float = 190.0

# Голова, к которой предмет тянется реакцией. Ставит её тот, кто запускает.
var target_node : Node2D = null

var _pulse_t : float = 0.0
var _spin_t  : float = 0.0

@onready var _sprite : Sprite2D = $Sprite2D
var _fx    : Node2D = null
var _shine : AudioStreamPlayer = null

func _ready() -> void:
	_sprite.texture        = TEX
	_sprite.scale          = Vector2.ONE * SIZE_LO
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.z_index        = 1   # лицо коробки поверх собственного света
	collision_layer = 2
	collision_mask  = 0
	add_to_group("pizza_box")
	# ── РАДИУС СЧИТАЕТСЯ ОТ РАЗМЕРА, А НЕ БЕРЁТСЯ У СУПЕР-ПИЦЦЫ ───────────────
	# У супер-пиццы 34 px при масштабе 0.08 — то есть 425 на единицу масштаба.
	# Ключ вдвое крупнее, и её число, скопированное как есть, дало бы хитбокс
	# вдвое меньше нарисованной коробки: игрок ведёт голову ПО картинке, а ключ
	# не ловится. Промах в таком месте не читается как «не попал» — он читается
	# как «предмет сломан», потому что коробка вот она.
	const R_PER_SCALE : float = 425.0
	var circle := CircleShape2D.new()
	circle.radius = R_PER_SCALE * (SIZE_LO + SIZE_HI) * 0.5
	$CollisionShape2D.shape = circle

	_fx = GLOW.make(COL_GLOW, COL_PP)
	add_child(_fx)

	# Звон крутится непрерывно, пока коробка на экране, — но заводится только
	# когда голова подошла (см. `_process`). Поток дублируется, чтобы включить
	# зацикливание и не портить общий ресурс.
	var shine_stream := SHINE_SFX.duplicate()
	if shine_stream is AudioStreamMP3:
		(shine_stream as AudioStreamMP3).loop = true
	_shine = AudioStreamPlayer.new()
	_shine.stream    = shine_stream
	_shine.volume_db = -14.0
	add_child(_shine)

func _process(delta: float) -> void:
	# Просто плывёт справа налево и убирается за краем.
	ItemFlow.advance(self, speed, delta)
	if ItemFlow.gone(self, 200.0):
		queue_free()
		return

	_pulse_t += delta * 6.0
	_spin_t  += delta * 3.0
	var p := 0.5 + 0.5 * sin(_pulse_t)
	_sprite.scale = Vector2.ONE * lerpf(SIZE_LO, SIZE_HI, p)
	modulate = Color(1.0, 1.0, 1.0).lerp(COL_BLINK, p)

	# ── Реакция на близость ───────────────────────────────────────────────────
	var prox := 0.0
	var dist := INF
	if is_instance_valid(target_node):
		dist = global_position.distance_to(target_node.global_position)
		prox = clampf(inverse_lerp(PROX_FAR, PROX_NEAR, dist), 0.0, 1.0)
	if is_instance_valid(_fx):
		_fx.call("tick", delta, p, prox)
	var shake := lerpf(0.0, 7.0, prox)
	_sprite.position = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake
	_sprite.rotation = sin(_spin_t) * 0.22 + randf_range(-1.0, 1.0) * 0.16 * prox

	if is_instance_valid(_shine):
		if dist <= SHINE_RANGE:
			if not _shine.playing:
				_shine.play()
			var st := clampf(inverse_lerp(SHINE_RANGE, PROX_NEAR, dist), 0.0, 1.0)
			_shine.volume_db = lerpf(-14.0, 0.0, st)
		elif _shine.playing:
			_shine.stop()
