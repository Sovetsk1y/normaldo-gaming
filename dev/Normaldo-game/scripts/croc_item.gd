extends Area2D

# ── Крокодил в потоке ────────────────────────────────────────────────────────
# Тот же приём, что у ниндзя: побеждённый босс возвращается в поток УМЕНЬШЕННЫМ
# и с ОДНИМ своим ходом. Не бой — цитата боя.
#
# Крокодил въезжает, тормозит на трёх четвертях ширины, ВЕДЁТ СТВОЛОМ за
# головой, передёргивает дробовик — и в этот момент ствол ЗАМИРАЕТ. Куда навёл,
# туда и уйдёт пуля. Один выстрел, и он уходит рывком влево.
#
# ── ПОЧЕМУ ИМЕННО ЭТОТ ХОД ──────────────────────────────────────────────────
# У босса три акта: охота стволом, стена хвоста, картечь с пастью. В поток
# годится только первый.
#
# Хвост идёт СТЕНОЙ поперёк экрана, и уклониться от него нельзя — можно только
# заранее быть не там; в бою про это говорит выложенная дорожка добычи, а в
# потоке такой дорожки нет и взяться ей неоткуда. Картечь перекрывает всё, кроме
# одной линии, то есть требует всего экрана — в потоке рядом летят пиццы и
# бомжи, и «свободная линия» перестаёт быть свободной.
#
# Охота же — вопрос ровно на три секунды: «успей сойти с линии». Он читается сам
# по себе, без арены и без интерфейса боя.
#
# ── ГЛАВНОЕ ПРАВИЛО: СНАЧАЛА ТЕЛЕГРАФ, ПОТОМ УДАР ──────────────────────────
# Наведение — это ещё не выстрел. Выстрел начинается с передёрга: его слышно и
# видно, и ровно в этот момент ствол перестаёт вести. Пуля уйдёт туда, куда
# наведено, а не туда, где голова окажется, — иначе это не уворот, а
# подбрасывание монетки.
#
# См. /Концепция/Босс — Крокодил.md → «Акт 1: ОХОТА»
# См. /Концепция/Паттерны препятствий.md → «Прошлые боссы в потоке»

const BULLET_SCRIPT := preload("res://scripts/leatherhead_bullet.gd")

# Кадры и звуки берутся У БОССА, а не копируются в свою папку: это тот же самый
# крокодил, и разъехаться его вид в бою и в потоке не должен.
const LEATHERHEAD := preload("res://scripts/leatherhead.gd")

const SFX_SNIPER := preload("res://assets/audio/leatherhead/sniper.mp3")
const SFX_RELOAD := preload("res://assets/audio/leatherhead/reload.mp3")

@export var speed : float = 240.0

# ── РАЗМЕР: МЕРИТЬ НАДО ВЫСОТУ ─────────────────────────────────────────────
# Крокодил нарисован ЛЁЖА: рисунок 253 × 123, вдвое шире, чем выше. Пока размер
# считался по длинной стороне — «86 пикселей, как у ниндзя», — длинной стороной
# была ШИРИНА, и на экран он выходил высотой в 42 пикселя при линии в 86. То
# есть вдвое ниже своей полосы: не угроза, а ящерица на её фоне.
#
# Поэтому здесь высота, а не длинная сторона. 78 при линии 86 — это «почти во
# всю линию»: остаётся зазор, по которому видно, что он идёт ПО полосе, а не
# растёт из её краёв. Ширина при этом выходит около 160 — он и должен быть
# длинным, он крокодил.
const CROC_H_PX : float = 78.0

const ENTER_SPEED_MULT : float = 1.7    # въезд быстрее потока
const PARK_X_RATIO     : float = 0.78   # где тормозит (доля ширины экрана)
const EXIT_SPEED_MULT  : float = 2.4    # рывок на выход

# Сколько ведёт стволом, прежде чем начать выстрел. Меньше секунды — игрок не
# успевает понять, что его ведут; больше полутора — успевает заскучать.
const TRACK_T : float = 1.10
# Передёрг: по нему слышно и видно, что сейчас будет выстрел.
const RELOAD_F : float = 0.07
# Пауза с ЗАМЕРШИМ стволом. Это и есть окно на уворот.
const AIM_T : float = 0.42
const BULLET_SPEED : float = 620.0
const BULLET_PX    : float = 34.0

# Дальше этого угла голова крокодила заваливается на спину.
const AIM_CLAMP : float = 0.55
# Дуло на кадре с поднятым стволом — доля рамки. Число боссовское: пуля обязана
# вылетать ИЗ СТВОЛА, а не из воздуха рядом.
const MUZZLE_AIM : Vector2 = Vector2(0.091, 0.473)

var damage : int = 1

enum State { ENTER, ATTACK, EXIT }
var _state    : int      = State.ENTER
var _park_x   : float    = 0.0
var _bob_t    : float    = 0.0
var _tracking : bool     = false
var _normaldo : Node2D   = null
var _sprite   : Sprite2D = null

func _ready() -> void:
	collision_layer = 2
	collision_mask  = 0
	add_to_group("obstacle")
	add_to_group("croc")

	_sprite = Sprite2D.new()
	_sprite.texture        = LEATHERHEAD.F_RELOAD_UP[0]
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.z_index        = 2
	ItemSizing.fit_sprite_content(_sprite, CROC_H_PX, ItemSizing.AXIS_H)
	add_child(_sprite)

	# Хитбокс считается ОТ НАРИСОВАННОГО, а не от константы: крокодил вдвое шире,
	# чем выше, и квадрат «по росту» оставил бы половину туши насквозь проходимой.
	var drawn := Vector2(ItemSizing.content_rect(_sprite.texture).size) * _sprite.scale
	var cs   := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(drawn.x * 0.62, drawn.y * 0.72)
	cs.shape  = rect
	add_child(cs)

	_park_x   = get_viewport_rect().size.x * PARK_X_RATIO
	_normaldo = _find_normaldo()

func _find_normaldo() -> Node2D:
	var p := get_parent()
	if p == null:
		return null
	var root := p.get_parent()
	if root == null:
		return null
	return root.get_node_or_null("Normaldo") as Node2D

func _process(delta: float) -> void:
	_bob_t += delta * 3.4
	_sprite.position.y = sin(_bob_t) * 3.0

	# Ведёт стволом, пока ведёт. С началом выстрела `_tracking` гаснет, и
	# наведение замирает — в этом весь телеграф.
	if _tracking and is_instance_valid(_normaldo):
		_aim_at(_normaldo.global_position)

	match _state:
		State.ENTER:
			position.x -= speed * ENTER_SPEED_MULT * delta
			if position.x <= _park_x:
				position.x = _park_x
				_state     = State.ATTACK
				_run_hunt()
		State.ATTACK:
			pass   # висит на месте, выстрелом управляет _run_hunt()
		State.EXIT:
			position.x -= speed * EXIT_SPEED_MULT * delta
			if position.x < -220.0:
				queue_free()

# Доворот ствола к точке. Нос — локальная −X, отсюда «минус развёрнутый угол».
func _aim_at(target: Vector2) -> void:
	if not is_instance_valid(_sprite):
		return
	var d := target - global_position
	if d.length() < 1.0:
		return
	_sprite.rotation = clampf(wrapf(d.angle() - PI, -PI, PI), -AIM_CLAMP, AIM_CLAMP)

# Точка на кадре в мировых координатах — считается ЧЕРЕЗ спрайт, поэтому едет
# вместе с его поворотом и масштабом.
func _muzzle() -> Vector2:
	if not is_instance_valid(_sprite) or _sprite.texture == null:
		return global_position
	var sz := _sprite.texture.get_size()
	return _sprite.to_global((MUZZLE_AIM - Vector2(0.5, 0.5)) * sz)

func _run_hunt() -> void:
	_tracking = true
	await get_tree().create_timer(TRACK_T).timeout
	if not _alive():
		return

	# Передёрг — по нему слышно и видно, что сейчас будет выстрел.
	_play_sfx(SFX_RELOAD)
	for f in LEATHERHEAD.F_RELOAD_UP:
		_sprite.texture = f
		await get_tree().create_timer(RELOAD_F).timeout
		if not _alive():
			return

	# СТВОЛ ЗАМЕР. Дальше он уже не доводит — направление зафиксировано, и это
	# окно, в котором игрок сходит с линии.
	_tracking = false
	var from := _muzzle()
	var to : Vector2 = _normaldo.global_position if is_instance_valid(_normaldo) \
		else from + Vector2(-600.0, 0.0)
	var dir := (to - from).normalized()
	await get_tree().create_timer(AIM_T).timeout
	if not _alive():
		return

	_sprite.texture = LEATHERHEAD.F_SNIPE[0]
	await get_tree().create_timer(0.06).timeout
	if not _alive():
		return
	_sprite.texture = LEATHERHEAD.F_SNIPE[1]
	_play_sfx(SFX_SNIPER)
	# Стреляем из ДУЛА, посчитанного заново: за время паузы спрайт покачался, и
	# точка уехала. Направление при этом старое — то, которое зафиксировали.
	_fire(_muzzle(), dir)
	_recoil()
	await get_tree().create_timer(0.12).timeout
	if not _alive():
		return
	_sprite.texture = LEATHERHEAD.F_SNIPE[2]
	await get_tree().create_timer(0.18).timeout
	if not _alive():
		return
	_sprite.texture = LEATHERHEAD.F_RELOAD_UP[0]
	_state = State.EXIT

func _fire(from: Vector2, dir: Vector2) -> void:
	var host := get_parent()
	if host == null:
		return
	var b := Area2D.new()
	b.set_script(BULLET_SCRIPT)
	b.call("init", dir, BULLET_SPEED, BULLET_PX)
	b.position = host.to_local(from)
	host.add_child(b)

func _recoil() -> void:
	if not is_inside_tree():
		return
	var tw := create_tween()
	if tw == null:
		return
	var home := position.x
	tw.tween_property(self, "position:x", home + 10.0, 0.06)
	tw.tween_property(self, "position:x", home, 0.12)

# Живы ли мы и есть ли ещё дерево. Корутина переживает и зачистку потока, и
# конец забега: проснуться вне дерева значит упасть на `get_tree()`.
func _alive() -> bool:
	return is_instance_valid(self) and is_inside_tree() and is_instance_valid(_sprite)

func _play_sfx(stream: AudioStream) -> void:
	if stream == null or not is_inside_tree():
		return
	var p := AudioStreamPlayer.new()
	p.stream    = stream
	p.volume_db = -6.0
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)
