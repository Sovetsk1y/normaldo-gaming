class_name StatusFx
extends RefCounted

# ── Статус-эффекты ───────────────────────────────────────────────────────────
# Десять зацикленных анимаций по 16 кадров 64×64 (набор Vivid Motion) на
# одиннадцать состояний игры. Это принципиально: эффект, повешенный
# «для красоты», добавляет мельтешения, а не понятности, — а половина состояний
# в игре была не видна вовсе. Замедление читалось только по тому, что голова
# вдруг стала хуже слушаться; сработавший резист — по тому, что удара почему-то
# не случилось; проклятие шамана — по одной всплывающей строке, которая уезжала
# раньше, чем игрок успевал понять, что управление перевернулось.
#
# Кто где. СЛЕВА — состояние игры, СПРАВА — папка с картинкой, и это разные
# вещи намеренно: папка называется тем, что НАРИСОВАНО, состояние — тем, что
# происходит. Пока имя было одно на двоих, любой обмен картинками между
# состояниями делал имена враньём — папка «slow» с часами оказывалась надета на
# компас, и прочитать код становилось нельзя.
#
#   состояние     картинка   что это
#   slow        → hex        Нормальдо замедлен
#   invert      → clock      управление перевёрнуто (шаман, компас)
#   hourglass   → clock      мир замедлен (песочные часы, «остановка времени»)
#   armor       → armor      неуязвимость (маска Кейси, шрамы Джокера)
#   charm       → charm      девочка-зазывала
#   shield      → shield     сработал резист скина
#   stun        → stun       получен удар
#   heal        → heal       набран следующий жир
#   shock       → shock      рывок Очков
#   rage        → rage       удар кулаком (Тайсон, викинг)
#   blessed     → blessed    пойман мешок денег
#
# Часы стоят СРАЗУ НА ДВУХ состояниях — компасе и песочных часах — и это не
# небрежность: оба про время, и оба останавливают игроку привычный ход вещей.
# Магента-шары ушли на замедление: замедление длится дольше всех прочих
# состояний, и ему нужна картинка, которую видно, а не тонкое кольцо.
const ART : Dictionary = {
	"slow": "hex", "invert": "clock", "hourglass": "clock",
	"armor": "armor", "charm": "charm", "shield": "shield", "stun": "stun",
	"heal": "heal", "shock": "shock", "rage": "rage", "blessed": "blessed",
}

const DIR    : String = "res://assets/vfx/%s/"
const FRAMES : int    = 16
const FPS    : float  = 14.0

# Кадры грузятся один раз на эффект: их 16 на штуку, и перезагружать лист на
# каждый банан — это по 16 обращений к диску в момент, когда на экране и так
# каша.
static var _cache : Dictionary = {}

# Имя СОСТОЯНИЯ на входе, папка с картинкой — через таблицу ART. Незнакомое имя
# пропускаем через себя как есть: так тест и кадросъёмка могут попросить
# картинку по её собственному имени.
static func _sprite_frames(name: String) -> SpriteFrames:
	var art : String = String(ART.get(name, name))
	if _cache.has(art):
		return _cache[art]
	var sf := SpriteFrames.new()
	sf.set_animation_speed("default", FPS)
	sf.set_animation_loop("default", true)
	var got := 0
	for i in FRAMES:
		var p : String = (DIR % art) + "%02d.png" % i
		if not ResourceLoader.exists(p):
			continue
		sf.add_frame("default", load(p))
		got += 1
	if got == 0:
		return null
	_cache[art] = sf
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
