extends Node2D

# ── Вертолёт SWAT ────────────────────────────────────────────────────────────
# Часть боя с [[Босс — Капитан полиции]]. Делает ДВЕ РАЗНЫЕ РАБОТЫ, и путать их
# нельзя — игрок читает их по тому, ГДЕ вертолёт:
#
#   ВЫСАДКА (`run_drop`)  — идёт ЧЕРЕЗ КАДР, справа налево, над первой-второй
#       полосой, с открытой дверью, и роняет бойцов. Он тут не угроза, а
#       доставка: смотреть надо не на него, а на то, что из него сыпется.
#
#   ШТУРМОВКА (`run_strafe`) — ВИСИТ У ВЕРХНЕГО КРАЯ, наполовину за кадром, и
#       бьёт из турели по выбранной полосе. Он тут и есть угроза, и потому его
#       видно ровно настолько, чтобы понять, что он там.
#
# Половина за кадром — не экономия места. Целиком нарисованный вертолёт над
# полосой читается как «сейчас он сядет», и игрок ждёт посадки; торчащее сверху
# брюхо с турелью не обещает ничего, кроме огня оттуда.

const BODY_TEX  := preload("res://assets/bosses/police/heli_body.png")
const DOOR_TEX  := preload("res://assets/bosses/police/heli_door.png")
const ROTOR_TEX := preload("res://assets/bosses/police/rotor.png")
const GUN1_TEX  := preload("res://assets/bosses/police/gun_big1.png")
const GUN2_TEX  := preload("res://assets/bosses/police/gun_big2.png")

const HELI_PX  : float = 300.0
const ROTOR_PX : float = 210.0
const GUN_PX   : float = 120.0

# Винт крутится СВОИМ узлом поверх корпуса, а не подменой кадров вертолёта.
# Кадров с винтом четыре, и на них винт нарисован в четырёх положениях — но
# вместе с корпусом: подменяя их, мы дёргали бы и корпус тоже.
const ROTOR_SPIN : float = 22.0

# Куда сажать винт относительно центра корпуса — доля кадра.
const ROTOR_OFF : Vector2 = Vector2(0.02, -0.16)

# ── ТУРЕЛЬ ВИСИТ ПОД КАБИНОЙ, А ДЕРЖИТСЯ ЗА СВОЙ РИСУНОК ───────────────────
# Пулемёт нарисован в УГЛУ своего кадра: казённик вверху справа, стволы уходят
# вниз-влево, и добрая треть кадра под ними пустая. Центр кадра приходится мимо
# рисунка — и посаженный «по центру», как все прочие спрайты, пулемёт уезжал на
# треть своей высоты ВВЕРХ и садился кабине НА КРЫШУ. Смещение вниз это лечило
# бы на глаз и разъезжалось бы при любой смене размера.
#
# Поэтому точка крепления берётся ПО РИСУНКУ и приходится на казённик: от него
# турель висит вниз, как ей и положено.
const GUN_ANCHOR : Vector2 = Vector2(0.86, 0.10)
# А само место крепления — низ кабины. Кабина нарисована в нижней половине
# корпуса (вертолёт виден в лоб, хвост уходит вверх), её низ — примерно 0.44
# длинной стороны от центра.
const GUN_OFF : Vector2 = Vector2(-0.02, 0.44)

const GUN_FRAME_T : float = 0.05    # мельтешение ствола на очереди

var _body  : Sprite2D = null
var _rotor : Sprite2D = null
var _gun   : Sprite2D = null
var _gun_t : float    = 0.0
var _firing: bool     = false

func _ready() -> void:
	z_index = 44

	_body = Sprite2D.new()
	_body.texture        = BODY_TEX
	_body.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ItemSizing.fit_sprite_content(_body, HELI_PX)
	add_child(_body)

	_rotor = Sprite2D.new()
	_rotor.texture        = ROTOR_TEX
	_rotor.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_rotor.z_index        = 1
	ItemSizing.fit_sprite_content(_rotor, ROTOR_PX)
	_rotor.position       = Vector2(ROTOR_OFF.x * HELI_PX, ROTOR_OFF.y * HELI_PX)
	add_child(_rotor)

	_gun = Sprite2D.new()
	_gun.texture        = GUN1_TEX
	_gun.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_gun.z_index        = 2
	_gun.visible        = false
	_gun.position       = Vector2(GUN_OFF.x * HELI_PX, GUN_OFF.y * HELI_PX)
	add_child(_gun)
	_fit_gun()

func _process(delta: float) -> void:
	if is_instance_valid(_rotor):
		_rotor.rotation += ROTOR_SPIN * delta
	# Турель мельтешит ДВУМЯ кадрами — это и есть «строчит», а не «выстрелила».
	if _firing and is_instance_valid(_gun):
		_gun_t += delta
		if _gun_t >= GUN_FRAME_T:
			_gun_t = 0.0
			_gun.texture = GUN2_TEX if _gun.texture == GUN1_TEX else GUN1_TEX
			# Пересадка обязательна на КАЖДОЙ смене кадра: рисунок в двух кадрах
			# стоит в рамке чуть по-разному, и турель, посаженная один раз,
			# подпрыгивала бы двадцать раз в секунду.
			_fit_gun()

func set_door_open(on: bool) -> void:
	if is_instance_valid(_body):
		_body.texture = DOOR_TEX if on else BODY_TEX
		ItemSizing.fit_sprite_content(_body, HELI_PX)

func set_gun_visible(on: bool) -> void:
	if is_instance_valid(_gun):
		_gun.visible = on

func set_firing(on: bool) -> void:
	_firing = on
	if is_instance_valid(_gun) and not on:
		_gun.texture = GUN1_TEX
		_fit_gun()

# Размер и посадка турели в одном месте: их нельзя делать порознь, потому что
# опора считается от рисунка, а рисунок у двух кадров разный.
func _fit_gun() -> void:
	if not is_instance_valid(_gun):
		return
	ItemSizing.fit_sprite_content(_gun, GUN_PX)
	ItemSizing.anchor_sprite(_gun, GUN_ANCHOR.x, GUN_ANCHOR.y)

# Мировая точка дула — оттуда и рисуются очереди. Считается от КРЕПЛЕНИЯ (узел
# теперь сидит на казённике), поэтому смещение до срезов стволов — почти вся
# длина рисунка вниз-влево.
func muzzle() -> Vector2:
	if is_instance_valid(_gun):
		return _gun.global_position + Vector2(-GUN_PX * 0.86, GUN_PX * 0.78)
	return global_position
