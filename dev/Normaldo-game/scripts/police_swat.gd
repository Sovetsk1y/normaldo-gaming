extends Area2D

# ── СВАТ: боец, сброшенный с вертолёта ───────────────────────────────────────
# Часть боя с [[Босс — Капитан полиции]]. Прыгает из вертолёта на случайную
# полосу, приземляется, разворачивается к Нормальдо и медленно идёт влево.
#
# ── ТРИ ВИДА, ОДИН СКРИПТ ───────────────────────────────────────────────────
# Вид задаётся полем `kind`, и отличаются они не полётом, а ТЕМ, ЧЕМ ВООРУЖЕНЫ.
# Разводить под это три файла значило бы трижды скопировать прыжок, посадку,
# разворот и ход:
#
#   shield  — со щитом. НЕ СТРЕЛЯЕТ ВОВСЕ и потому опасен иначе всех: он просто
#             занимает полосу и едет по ней, а сбить его спеллом нельзя — щит
#             держит. Вопрос от него: «куда ты денешься, когда полоса кончится».
#   rifle   — с M16. Приземлившись, ДОВОРАЧИВАЕТСЯ к Нормальдо и бьёт
#             одиночными по прямой. Уходить надо с линии, а не от него.
#   grenade — с гранатой. Кидает ОДНУ по навесной, граната взрывается там, где
#             упала, — и после броска он становится обычным стрелком. Это и
#             делает его читаемым: пока в руке граната, он опасен площадью,
#             дальше — линией.
#
# ── ПОЧЕМУ ОНИ ЕДУТ ВЛЕВО, А НЕ СТОЯТ ──────────────────────────────────────
# Стоящий боец — это стена, и вопрос от него один: «успел уйти или нет». Едущий
# отбирает полосу ПОСТЕПЕННО, и у игрока есть выбор: уйти сейчас в тесноту или
# потерпеть и уйти позже в свободное место. Второе интереснее, и цена ошибки
# та же.

const SWAT_TEX    := preload("res://assets/bosses/police/swat.png")
const SHIELD_TEX  := preload("res://assets/bosses/police/shield.png")
const M16_TEX     := preload("res://assets/bosses/police/m16.png")
const HAND_GR_TEX := preload("res://assets/bosses/police/hand_grenade.png")
const THROW_TEX   := preload("res://assets/bosses/police/throw.png")
const GRENADE_SCRIPT := preload("res://scripts/police_grenade.gd")
const BULLET_SCRIPT  := preload("res://scripts/leatherhead_bullet.gd")

const SFX_SHOT := preload("res://assets/audio/leatherhead/sniper.mp3")

# ── РАЗМЕР БОЙЦА ───────────────────────────────────────────────────────────
# Сперва он был заметно мельче Нормальдо — из опасения, что трое разом закроют
# пол-экрана. Опасение не подтвердилось: они не стоят кучей, а идут по разным
# полосам, и мелкий боец читался не как «их много», а как «они далеко».
# Штурмовой отряд, который выглядит мельче того, кого штурмует, угрозой не
# выглядит вовсе.
const HEAD_PX   : float = 84.0
const SHIELD_PX : float = 88.0
# ── СТВОЛ ВДВОЕ БОЛЬШЕ ГОЛОВЫ ──────────────────────────────────────────────
# И это не описка. M16 — единственное, по чему стрелка отличают от щитоносца на
# скорости, и отличать надо ДО первого выстрела, а не после. Ствол в полголовы
# сливался со снаряжением; ствол вдвое длиннее головы виден с другого края
# экрана и сам по себе говорит, чего от этого бойца ждать.
const M16_PX    : float = 156.0
const HAND_PX   : float = 45.0

# Падение с вертолёта.
const DROP_T    : float = 0.55
const DROP_SPIN : float = 2.2

# Разворот к Нормальдо после посадки — пауза, за которую игрок успевает понять,
# что сейчас будет.
const TURN_T : float = 0.45

# Ход влево. МЕДЛЕННО: на арене это не угроза в потоке, а стена, которая
# наступает.
const WALK : float = 46.0

# ── ТОТ ЖЕ БОЕЦ УМЕЕТ ЛЕТАТЬ В ПОТОКЕ ──────────────────────────────────────
# На пятом эпизоде СВАТ приходит в поток — как ниндзя и крокодил, цитатой боя с
# капитаном (см. spawner.HAZ_LEVEL). Там он обязан ехать СО СКОРОСТЬЮ ПОТОКА:
# боец, ползущий свои 46 px/c, пока мимо несётся всё остальное, читался бы не
# как угроза, а как забытая на экране декорация.
#
# Поэтому скорость — поле, а не константа. Ставит её тот, кто бойца выпускает.
var walk_speed : float = WALK

# Стрельба.
const SHOOT_FIRST  : float = 1.05   # первый выстрел не сразу после посадки
const SHOOT_EVERY  : float = 1.60
const SHOOT_AIM_T  : float = 0.34   # ствол замер — окно на уход с линии
const BULLET_SPEED : float = 560.0
const BULLET_PX    : float = 26.0

# Бросок гранаты.
const THROW_DELAY : float = 0.85

var kind : String = "rifle"

var damage : int = 1

# Куда идти и в кого целиться — ставит босс.
var target : Node2D = null

enum State { DROP, TURN, LIVE, DEAD }
var _state : int = State.DROP

var _sprite : Sprite2D = null
var _gear   : Sprite2D = null      # щит, ствол или рука с гранатой
var _t      : float    = 0.0
var _shoot_t: float    = 0.0
var _dead   : bool     = false

func _ready() -> void:
	collision_layer = 2
	collision_mask  = 0
	add_to_group("obstacle")
	add_to_group("swat")

	_sprite = Sprite2D.new()
	_sprite.texture        = SWAT_TEX
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.z_index        = 2
	ItemSizing.fit_sprite_content(_sprite, HEAD_PX)
	add_child(_sprite)

	_build_gear()

	var cs   := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(HEAD_PX * 0.62, HEAD_PX * 0.72)
	cs.shape  = rect
	add_child(cs)

# Снаряжение сидит СБОКУ ОТ ГОЛОВЫ и живёт своим узлом: у щита и ствола разный
# размер и разное место, а поворот к цели крутит только его — голова остаётся
# на месте, иначе боец «ложится набок», целясь вниз.
func _build_gear() -> void:
	_gear = Sprite2D.new()
	_gear.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_gear.z_index        = 3
	match kind:
		"shield":
			_gear.texture  = SHIELD_TEX
			ItemSizing.fit_sprite_content(_gear, SHIELD_PX)
			# Щит СПЕРЕДИ, то есть слева: оттуда идёт Нормальдо.
			_gear.position = Vector2(-HEAD_PX * 0.46, HEAD_PX * 0.10)
		"grenade":
			_gear.texture  = HAND_GR_TEX
			ItemSizing.fit_sprite_content(_gear, HAND_PX)
			_gear.position = Vector2(-HEAD_PX * 0.42, HEAD_PX * 0.30)
		_:
			_gear.texture  = M16_TEX
			ItemSizing.fit_sprite_content(_gear, M16_PX)
			_gear.position = Vector2(-HEAD_PX * 0.30, HEAD_PX * 0.28)
	add_child(_gear)

# Вход БЕЗ ВЕРТОЛЁТА — для потока. Боец уже на своей полосе и сразу живой:
# падать ему неоткуда, а пауза на разворот в потоке означала бы, что он въезжает
# спиной вперёд.
func enter_from_edge() -> void:
	_state   = State.LIVE
	_shoot_t = SHOOT_FIRST
	if kind == "grenade":
		_throw_grenade()

# Прыжок из вертолёта на свою полосу. Зовёт босс, сразу после создания.
func drop_to(lane_y: float) -> void:
	if not is_inside_tree():
		return
	_state = State.DROP
	var tw := create_tween()
	tw.tween_property(self, "position:y", lane_y, DROP_T)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	var spin := create_tween()
	spin.tween_property(_sprite, "rotation", DROP_SPIN, DROP_T)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	spin.tween_property(_sprite, "rotation", 0.0, 0.18)
	await tw.finished
	if not is_instance_valid(self) or _dead:
		return
	# ПРИЗЕМЛИЛСЯ. Пауза на разворот — за неё игрок успевает прочитать, кто
	# именно приехал: щит, ствол или граната.
	_state = State.TURN
	_t     = 0.0

func _process(delta: float) -> void:
	if _dead:
		return
	match _state:
		State.DROP:
			pass                       # падением правит твин
		State.TURN:
			_t += delta
			_face_target()
			if _t >= TURN_T:
				_state   = State.LIVE
				_shoot_t = SHOOT_FIRST
				if kind == "grenade":
					_throw_grenade()
		State.LIVE:
			position.x -= walk_speed * delta
			_face_target()
			if position.x < -120.0:
				queue_free()
				return
			if kind == "rifle":
				_shoot_t -= delta
				if _shoot_t <= 0.0:
					_shoot_t = SHOOT_EVERY
					_shoot()

# Доворот СНАРЯЖЕНИЯ к цели, а не всего бойца. Голова нарисована смотрящей
# влево — туда он и идёт; крутить её вслед за Нормальдо значило бы валить бойца
# набок каждый раз, когда игрок уходит вверх.
func _face_target() -> void:
	if kind == "shield" or not is_instance_valid(target) or not is_instance_valid(_gear):
		return
	var d := target.global_position - global_position
	if d.length() < 1.0:
		return
	# Ствол нарисован смотрящим влево, поэтому угол считается от «влево».
	_gear.rotation = clampf(wrapf(d.angle() - PI, -PI, PI), -0.7, 0.7)

func _shoot() -> void:
	if not is_inside_tree() or not is_instance_valid(target):
		return
	# Сначала ствол ЗАМИРАЕТ, и только потом выстрел. Тот же договор, что у
	# крокодила и перчатки: пуля уйдёт туда, куда наведено, а не туда, где
	# голова окажется.
	var to  := target.global_position
	var dir := (to - global_position).normalized()
	var aim := kind
	await get_tree().create_timer(SHOOT_AIM_T).timeout
	if not is_instance_valid(self) or _dead or not is_inside_tree() or kind != aim:
		return
	var host := get_parent()
	if host == null:
		return
	var b := Area2D.new()
	b.set_script(BULLET_SCRIPT)
	b.call("init", dir, BULLET_SPEED, BULLET_PX)
	b.position = position + dir * (HEAD_PX * 0.55)
	host.add_child(b)
	_play(SFX_SHOT, -12.0)
	# Отдача — маленькая, но по ней видно, кто именно выстрелил, когда на экране
	# их трое.
	var tw := create_tween()
	tw.tween_property(self, "position:x", position.x + 6.0, 0.05)
	tw.tween_property(self, "position:x", position.x, 0.10)

# ── ГРАНАТОМЁТЧИК КИДАЕТ ОДИН РАЗ И СТАНОВИТСЯ СТРЕЛКОМ ────────────────────
# Пока граната в руке, он опасен ПЛОЩАДЬЮ: взрыв накрывает круг, и уходить надо
# от места падения. После броска он ничем не отличается от стрелка, и это
# честно — в руках у него ровно то, что видно.
func _throw_grenade() -> void:
	if not is_inside_tree():
		return
	await get_tree().create_timer(THROW_DELAY).timeout
	if not is_instance_valid(self) or _dead or not is_inside_tree():
		return
	# Кадр броска: рука уходит вперёд.
	if is_instance_valid(_gear):
		_gear.texture = THROW_TEX
		ItemSizing.fit_sprite_content(_gear, HAND_PX * 1.25)
	var host := get_parent()
	var to : Vector2 = target.global_position if is_instance_valid(target) \
		else position + Vector2(-260.0, 0.0)
	if host != null:
		var g := Area2D.new()
		g.set_script(GRENADE_SCRIPT)
		g.set("from_pos", position)
		g.set("to_pos", to)
		host.add_child(g)
	await get_tree().create_timer(0.30).timeout
	if not is_instance_valid(self) or _dead or not is_inside_tree():
		return
	# И ПРЕВРАЩАЕТСЯ В СТРЕЛКА — со всем, что к этому прилагается.
	kind = "rifle"
	if is_instance_valid(_gear):
		_gear.queue_free()
	_build_gear()
	_shoot_t = SHOOT_EVERY

# ── СПЕЛЛ СЛОМАЛ БОЙЦА ─────────────────────────────────────────────────────
# ЩИТОНОСЦА ЭТО НЕ БЕРЁТ, и проверка стоит ЗДЕСЬ, а не в группе.
#
# Сначала я развёл их группой «ломаемых» — и это было враньё: ломает предметы
# `normaldo._kill_item`, а он спрашивает не группу, а МЕТОД `on_hit`. Группа
# висела украшением, тест на неё был зелёный, и щит спокойно разлетался от
# первого же спелла.
#
# Отказ живёт там, где принимают удар: щит ЛЯЗГАЕТ и держит. Молча проигнорить
# нельзя — игрок решит, что спелл не сработал вовсе, и будет бить в него снова.
func on_hit() -> void:
	if _dead:
		return
	if kind == "shield":
		_clang()
		return
	_dead  = true
	_state = State.DEAD
	remove_from_group("obstacle")
	var tw := create_tween()
	tw.tween_property(self, "position:y", position.y + 220.0, 0.5)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(_sprite, "rotation", 2.4, 0.5)
	tw.parallel().tween_property(self, "modulate:a", 0.0, 0.5)
	tw.tween_callback(queue_free)

# Щит принял удар: лязг и отдача назад. Это ответ на спелл — «попал, но не
# берёт», — а не отсутствие ответа.
func _clang() -> void:
	if not is_inside_tree():
		return
	var tw := create_tween()
	tw.tween_property(self, "position:x", position.x + 14.0, 0.07)
	tw.tween_property(self, "position:x", position.x, 0.13)
	if is_instance_valid(_gear):
		var fl := _gear.create_tween()
		fl.tween_property(_gear, "modulate", Color(2.2, 2.2, 2.4), 0.05)
		fl.tween_property(_gear, "modulate", Color(1, 1, 1), 0.15)

func _play(stream: AudioStream, db: float) -> void:
	if stream == null or not is_inside_tree():
		return
	var p := AudioStreamPlayer.new()
	p.stream    = stream
	p.volume_db = db
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)
