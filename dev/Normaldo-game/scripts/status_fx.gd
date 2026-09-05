class_name StatusFx
extends RefCounted

# ── Статус-эффекты ───────────────────────────────────────────────────────────
# Десять зацикленных анимаций по 16 кадров 64×64 (набор Vivid Motion), и у
# каждой в игре есть СВОЁ состояние. Это принципиально: эффект, повешенный
# «для красоты», добавляет мельтешения, а не понятности, — а половина состояний
# в игре была не видна вовсе. Замедление читалось только по тому, что голова
# вдруг стала хуже слушаться; сработавший резист — по тому, что удара почему-то
# не случилось; проклятие шамана — по одной всплывающей строке, которая уезжала
# раньше, чем игрок успевал понять, что управление перевернулось.
#
# Кто где (одно состояние — один эффект, пересечений нет):
#   slow      — Нормальдо замедлен
#   curse     — управление перевёрнуто (шаман, компас)
#   shield    — сработал резист скина
#   armor     — неуязвимость (маска Кейси, шрамы Джокера)
#   heal      — набран следующий жир
#   stun      — получен удар
#   shock     — рывок Очков
#   rage      — удар кулаком (Тайсон, викинг)
#   blessed   — двойная выгода Очков
#   charm     — девочка-зазывала
#
# Не разложены и лежат в наборе про запас: Bleed, Burn, Confusion, Fear, Freeze,
# Haste, Invisibility, Regen, Silence, Sleep, Weaken, PoisonBubble. Под них состояний
# нет, и придумывать их ради картинки — это менять игру ради ассета.
#
# Отказы стоит назвать поимённо, чтобы их не «дорисовали» обратно:
#   • Freeze просился под «остановку времени» мага, но самой остановки в игре
#     нет — перк объявлен в лестнице скинов и не реализован; эффект под него
#     был бы вторым обещанием поверх первого.
#   • Confusion просился под перевёрнутое управление, но игра называет этот
#     эффект ПРОКЛЯТИЕМ (см. hazard_item.gd), и слово должно быть одно; вдобавок
#     у Confusion рисунок занимает малую долю кадра, и над головой висела дымка,
#     которой в потоке не видно. Взят Curse.
#   • Haste просился на ускорение от банки колы, но нарисован тёмно-синей
#     дугой, занимающей меньше половины своего кадра: на тёмном фоне уровня его
#     не видно ни в каком размере — пробовали и вдвое крупнее, и осветлённым.
#     Значок, которого не видно, хуже отсутствия значка: он занимает место
#     состояния и создаёт ощущение, что показывать тут нечего. У колы и без
#     него есть строка «УСКОРЕНИЕ!», частицы и кружок отката в интерфейсе.
#   • Burn просился на огонь и костёр, а у них своя нарисованная анимация
#     пламени (fire.gd, hazard_item._add_fire). Второй огонь поверх огня — это
#     не информация, а мельтешение; отдельного состояния «горит» у Нормальдо
#     нет, урон от огня мгновенный.

const DIR    : String = "res://assets/vfx/%s/"
const FRAMES : int    = 16
const FPS    : float  = 14.0

# Кадры грузятся один раз на эффект: их 16 на штуку, и перезагружать лист на
# каждый банан — это по 16 обращений к диску в момент, когда на экране и так
# каша.
static var _cache : Dictionary = {}

static func _sprite_frames(name: String) -> SpriteFrames:
	if _cache.has(name):
		return _cache[name]
	var sf := SpriteFrames.new()
	sf.set_animation_speed("default", FPS)
	sf.set_animation_loop("default", true)
	var got := 0
	for i in FRAMES:
		var p : String = (DIR % name) + "%02d.png" % i
		if not ResourceLoader.exists(p):
			continue
		sf.add_frame("default", load(p))
		got += 1
	if got == 0:
		return null
	_cache[name] = sf
	return sf

# Постоянный эффект: висит, пока вызывающий его не снимет. Возвращает узел —
# снимать через `queue_free`, а не через флаг: узла нет — эффекта нет, и
# рассинхронизироваться тут нечему.
#
# `px` — желаемый размер по большей стороне; кадр 64×64, но у эффектов внутри
# кадра много воздуха, поэтому размер задаётся по КАДРУ, а не по рисунку: у
# статуса воздух вокруг — часть эффекта (кольцо, орбита, искры по краям).
# `tint` осветляет или красит эффект. Нужен не для красоты: часть набора
# нарисована тёмной (у Haste — синяя дуга), и на тёмном фоне канализации такой
# значок не виден вовсе. Множитель больше единицы поднимает яркость.
static func attach(host: Node2D, name: String, px: float,
		offset : Vector2 = Vector2.ZERO, z : int = 40,
		tint : Color = Color(1, 1, 1)) -> AnimatedSprite2D:
	if host == null or not is_instance_valid(host):
		return null
	var sf := _sprite_frames(name)
	if sf == null:
		return null
	var a := AnimatedSprite2D.new()
	a.sprite_frames  = sf
	a.animation      = "default"
	a.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	a.scale          = Vector2.ONE * (px / 64.0)
	a.position       = offset
	a.z_index        = z
	a.modulate       = tint
	host.add_child(a)
	a.play()
	return a

# Одноразовый эффект: проигрывается один круг и убирает себя сам. Для
# мгновенных событий — удар, срабатывание резиста, набранный жир.
#
# Вешается на РОДИТЕЛЯ, а не на сам предмет: предмет после события чаще всего
# улетает вниз или исчезает, и эффект уехал бы вместе с ним.
static func burst(parent: Node, at: Vector2, name: String, px: float,
		z : int = 41) -> AnimatedSprite2D:
	if parent == null or not is_instance_valid(parent):
		return null
	var sf := _sprite_frames(name)
	if sf == null:
		return null
	var a := AnimatedSprite2D.new()
	a.sprite_frames  = sf
	a.animation      = "default"
	a.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	a.scale          = Vector2.ONE * (px / 64.0)
	a.z_index        = z
	parent.add_child(a)
	a.global_position = at
	a.play()
	# Один круг: SpriteFrames зациклен (постоянные эффекты его же и крутят),
	# поэтому конец круга ловим таймером, а не сигналом `animation_finished` —
	# у зацикленной анимации он не приходит.
	var t := a.get_tree().create_timer(float(FRAMES) / FPS)
	t.timeout.connect(func():
		if is_instance_valid(a):
			a.queue_free())
	return a
