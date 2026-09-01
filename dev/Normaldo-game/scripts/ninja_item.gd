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
# ── Три вида ─────────────────────────────────────────────────────────────────
# Вид задаётся полем `kind`, скрипт один: отличаются они не механикой полёта, а
# ТЕМ, ЧЕМ БЬЮТ, и разводить под это три файла значило бы трижды скопировать
# въезд, покачивание, дым и уход.
#
#   shuriken (чёрный) — веер наводящихся сюрикенов. Уклоняться надо ПОСЛЕ
#       броска: снаряд наводится в момент вылета.
#   predator (красный) — не тормозит вовсе, а РАЗГОНЯЕТСЯ и проходит насквозь
#       через место, где стоял Нормальдо, с занесённым мечом. Тот же приём, что
#       у босса (ninja_foot._predator_attack), но одним заходом. Уклоняться надо
#       ДО рывка: после начала траектория уже не меняется.
#       smoke (жёлтый) — кидает дымовые шашки В ЛЕТЯЩИЕ ПРЕДМЕТЫ. Облако садится
#       на предмет и едет с ним, закрывая его. Урона у дыма нет вовсе, Нормальдо
#       всегда проходит под ним — опасен не дым, а то, что под ним не видно.
#
# Три вида и отвечают на три разных вопроса: «куда он бросил», «где он пройдёт»
# и «а что там вообще летит».
#
# См. /Концепция/Паттерны препятствий.md → «Ниндзя»

const NINJA_TEX      := preload("res://assets/bosses/ninja_foot/ninja_foot1.png")
const SHURIKEN_SCENE := preload("res://scenes/shuriken.tscn")
const THROW_SFX      := preload("res://assets/audio/shurikens.mp3")
const SMOKE_TEX      := preload("res://assets/bosses/ninja_foot/ninja_foot_smoke.png")
const SWORD1_TEX     := preload("res://assets/bosses/ninja_foot/sword1.png")
const SWORD2_TEX     := preload("res://assets/bosses/ninja_foot/sword2.png")
const CLOUD_TEX      := preload("res://assets/bosses/ninja_foot/smoke.png")
const BOMB_TEX       := preload("res://assets/bosses/ninja_foot/smoke_projectile.png")
const SMOKE_SCREEN_SCRIPT := preload("res://scripts/smoke_screen.gd")
const PREDATOR_SFX   := preload("res://assets/audio/shredder_predator.mp3")

# Цвет — единственное, чем виды различаются на глаз, и различать их надо ДО
# первой атаки: у красного она без телеграфа по месту, уходить надо заранее.
#
# Красит НЕ modulate, а обводка. Ниндзя нарисован фиолетовым (много красного и
# синего, зелёного почти нет), а modulate умножает: жёлтый на фиолетовом даёт
# бурый, и «жёлтый» с «красным» на экране становились одним и тем же грязным
# цветом. Обводка своим цветом рисуется поверх чужого и читается сразу.
const KIND_TINT : Dictionary = {
	"shuriken": Color(1.00, 1.00, 1.00),
	"predator": Color(1.25, 0.80, 0.80),
	"smoke":    Color(1.25, 1.15, 0.80),
}
const KIND_RIM : Dictionary = {
	"predator": Color(1.00, 0.14, 0.10),
	"smoke":    Color(1.00, 0.86, 0.16),
}
const RIM_GROW : float = 1.18

# Красный: разбег, рывок и меч.
const PRED_WINDUP_T : float = 0.42    # замах: видно, куда он сейчас пойдёт
const PRED_SPEED    : float = 760.0
# Меч КРАСНОГО ниндзя. Был 86 при голове 113 — на экране это ножик в руке
# великана, а замах мечом и есть весь его телеграф: не разглядел меч — не понял,
# что сейчас будет рывок. Теперь меч ЗАМЕТНО ДЛИННЕЕ головы.
#
# Считается по РИСУНКУ, а не по кадру: у обоих кадров меча вокруг клинка
# нарисованы поля в 13 % длинной стороны, и по кадру он выходил ещё мельче.
const PRED_ARM_PX   : float = 165.0

# Жёлтый: шашки и облака.
const SMOKE_BOMBS   : int   = 3
const SMOKE_GAP     : float = 0.45
const SMOKE_LIFE    : float = 3.4
const SMOKE_SZ      : float = 118.0
const BOMB_SPEED    : float = 620.0

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
@export var kind  : String = "shuriken"

var damage : int = 1

# EXIT_FROZEN — рывок красного: позицией в это время владеет тюин, и обычный
# EXIT, который сам двигает узел влево, тянул бы его в другую сторону.
enum State { ENTER, ATTACK, EXIT, EXIT_FROZEN }
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

	add_to_group("ninja_" + kind)

	_sprite = Sprite2D.new()
	_sprite.texture = NINJA_TEX
	_sprite.modulate = KIND_TINT.get(kind, Color.WHITE)
	# z_index поднят намеренно: обводка рисуется на слой НИЖЕ спрайта, и при
	# нулевом z она уходила под фон — цветного канта не было видно вовсе.
	_sprite.z_index  = 2
	ItemSizing.fit_sprite_content(_sprite, NINJA_PX)
	add_child(_sprite)
	if KIND_RIM.has(kind):
		var rim := Sprite2D.new()
		rim.name           = "Rim"
		rim.texture        = NINJA_TEX
		rim.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		rim.scale          = Vector2.ONE * RIM_GROW
		rim.modulate       = KIND_RIM[kind]
		rim.z_index        = -1
		_sprite.add_child(rim)

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
				match kind:
					"predator": _run_predator()
					"smoke":    _run_smoke()
					_:          _run_attack()
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

# ── Красный: удар предатора ──────────────────────────────────────────────────
# Один заход того же приёма, что у босса: замах на месте (видно, КУДА он сейчас
# пойдёт), потом рывок насквозь через точку, где стоял Нормальдо, и за край.
#
# Направление берётся ОДИН РАЗ, в конце замаха. Наводящийся всю дорогу ниндзя
# не оставил бы игроку хода: уклонение тут делается ДО рывка, а не во время.
func _run_predator() -> void:
	if _normaldo == null or not is_instance_valid(_normaldo):
		_state = State.EXIT
		return
	# Замах: раздувается и заносит меч. Это и есть телеграф — без него рывок
	# читается как «внезапно умер».
	var arm := Sprite2D.new()
	arm.texture        = SWORD1_TEX
	arm.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	arm.scale          = Vector2.ONE * ItemSizing.content_scale(SWORD1_TEX, PRED_ARM_PX)
	arm.z_index        = 1
	add_child(arm)
	_play_sfx(PREDATOR_SFX)

	var base := _sprite.scale
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_sprite, "scale", base * 1.35, PRED_WINDUP_T)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_sprite, "modulate", Color(2.0, 0.5, 0.45), PRED_WINDUP_T * 0.5)
	await tw.finished
	if not is_instance_valid(self) or not is_instance_valid(_normaldo):
		return

	var dir : Vector2 = (_normaldo.global_position - global_position).normalized()
	if dir.length() < 0.01:
		dir = Vector2.LEFT
	arm.position = dir * NINJA_PX * 0.62
	arm.rotation = dir.angle()
	_sprite.flip_h = dir.x > 0.0

	var vp := get_viewport_rect().size
	var dest := _normaldo.global_position + dir * vp.length()
	var dur : float = global_position.distance_to(dest) / PRED_SPEED
	_state = State.EXIT_FROZEN
	var rush := create_tween()
	rush.tween_property(self, "global_position", dest, dur).set_trans(Tween.TRANS_LINEAR)
	# Меч в рывке проворачивается — по нему и читается, что это УДАР, а не
	# «ниндзя пролетел мимо».
	var spin := create_tween()
	spin.tween_interval(dur * 0.30)
	spin.tween_callback(func() -> void:
		if is_instance_valid(arm):
			arm.texture = SWORD2_TEX)
	spin.tween_property(arm, "rotation", dir.angle() + TAU, dur * 0.55)\
		.set_trans(Tween.TRANS_SINE)
	await rush.finished
	if is_instance_valid(self):
		queue_free()

# ── Жёлтый: дымовые шашки ────────────────────────────────────────────────────
# Кидает шашки В ЛЕТЯЩИЕ ПРЕДМЕТЫ: облако садится на предмет и едет вместе с
# ним, закрывая его. Сам дым безвреден и проходим насквозь — вопрос он задаёт
# не «куда мне нельзя», а «а что там под ним»: банан, от которого надо уйти, или
# пицца, за которой надо лететь.
func _run_smoke() -> void:
	for i in SMOKE_BOMBS:
		if not is_instance_valid(self):
			return
		await _telegraph()
		if not is_instance_valid(self):
			return
		_throw_bomb()
		if i < SMOKE_BOMBS - 1:
			await get_tree().create_timer(SMOKE_GAP).timeout
	if not is_instance_valid(self):
		return
	await get_tree().create_timer(0.35).timeout
	if not is_instance_valid(self):
		return
	_puff()
	_state = State.EXIT

func _throw_bomb() -> void:
	var host := get_parent()
	if host == null:
		return
	var vp := get_viewport_rect().size
	# Цель — ЛЕТЯЩИЙ ПРЕДМЕТ, а не пустой лейн: смысл дыма в том, что он что-то
	# закрывает. Не нашлось ни одного (поле пустое) — шашка уходит в свободный
	# лейн и просто рассеивается: пустое облако честнее, чем облако, повешенное
	# на ниндзю или на самого себя.
	var target : Node2D = _pick_cover_target(host, vp)
	var to : Vector2 = target.position if target != null \
		else Vector2(vp.x * randf_range(0.18, 0.62),
			vp.y * (float(randi() % 5) + 0.5) / 5.0)

	var proj := Sprite2D.new()
	proj.texture        = BOMB_TEX
	proj.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	proj.scale          = Vector2.ONE * ItemSizing.fit_scale(BOMB_TEX, 34.0)
	proj.modulate       = KIND_TINT["smoke"]
	proj.position       = position
	proj.z_index        = 3
	host.add_child(proj)

	var dur : float = maxf(0.12, proj.position.distance_to(to) / BOMB_SPEED)
	var tw := proj.create_tween()
	tw.tween_property(proj, "position", to, dur)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(proj, "rotation", TAU * 1.5, dur)
	tw.tween_callback(func() -> void:
		if is_instance_valid(proj):
			# Цель за время полёта могла уехать или сломаться — тогда садимся
			# туда, куда шашка долетела, а не гонимся за пустотой.
			_spawn_cloud(proj.position, target if is_instance_valid(target) else null)
			proj.queue_free())

	var audio := AudioStreamPlayer.new()
	audio.stream = THROW_SFX
	host.add_child(audio)
	audio.play()
	audio.finished.connect(audio.queue_free)

# Предмет, который стоит завесить: летящий, ещё в кадре и левее ниндзя — за
# спину себе он шашку не кидает. Сам ниндзя, чужой дым и снаряды в счёт не идут.
func _pick_cover_target(host: Node, vp: Vector2) -> Node2D:
	var found : Array = []
	for c in host.get_children():
		if c == self or not (c is Node2D) or not is_instance_valid(c):
			continue
		if c.is_in_group("ninja") or c.is_in_group("smoke") or c.is_in_group("bullet"):
			continue
		var covered := false
		for g in ["obstacle", "pizza", "dollar", "slowing", "fire", "money_bag"]:
			if c.is_in_group(g):
				covered = true
				break
		if not covered:
			continue
		var p : Vector2 = (c as Node2D).position
		if p.x < vp.x * 0.10 or p.x > position.x:
			continue
		found.append(c)
	if found.is_empty():
		return null
	return found[randi() % found.size()]

# Облако. Без хитбокса и без группы `obstacle` — оно ЗАКРЫВАЕТ, а не бьёт.
func _spawn_cloud(at: Vector2, target: Node2D) -> void:
	var host := get_parent()
	if host == null:
		return
	var node := Node2D.new()
	node.set_script(SMOKE_SCREEN_SCRIPT)
	node.position = at
	# Выше Нормальдо (у него тройка): он пролетает ПОД дымом, а не появляется
	# поверх него — иначе дым читается как фон за спиной, а не как завеса.
	node.z_index  = 6

	var spr := Sprite2D.new()
	spr.texture        = CLOUD_TEX
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.scale          = Vector2.ONE * ItemSizing.fit_scale(CLOUD_TEX, SMOKE_SZ)
	spr.modulate       = Color(1.35, 1.20, 0.55, 0.0)

	host.add_child.call_deferred(node)
	await get_tree().process_frame
	if not is_instance_valid(node):
		return
	node.add_to_group("smoke")
	node.call("setup", spr, target, SMOKE_LIFE, speed)

func _play_sfx(stream: AudioStream) -> void:
	var host := get_parent()
	if host == null:
		return
	var a := AudioStreamPlayer.new()
	a.stream = stream
	host.add_child(a)
	a.play()
	a.finished.connect(a.queue_free)

# Красная вспышка-предупреждение: у игрока есть THROW_TELEGRAPH, чтобы начать
# уходить с линии броска.
func _telegraph() -> void:
	var tw := create_tween()
	var tint : Color = KIND_TINT.get(kind, Color.WHITE)
	tw.tween_property(_sprite, "modulate", tint * 1.6, THROW_TELEGRAPH * 0.5)
	tw.tween_property(_sprite, "modulate", tint, THROW_TELEGRAPH * 0.5)
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
