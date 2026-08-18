extends Node2D

# Метки резиста ПРЯМО НА ПРЕДМЕТАХ.
#
# Кружки способностей висят в углу экрана, а глаза игрока в забеге живут в двух
# точках: голова Нормальдо и предметы, летящие на неё справа. Отвести взгляд в
# угол значит пропустить удар — поэтому вопрос «этот предмет мне страшен?»
# отвечается на самом предмете:
#
#   • сплошное зелёное кольцо — резист готов, подставляйся без урона;
#   • пунктирное тусклое     — резист остывает, сейчас ударит.
#
# Состояние передаётся и цветом, И формой линии: одного цвета мало.
#
# Слой ничего не добавляет на экран у скина без резистов (у классики их нет) и
# ничего не хранит между кадрами — он просто рисует по текущему состоянию.
#
# См. /Концепция/Интерфейс забега.md

# Группы, в которых лежат опасные предметы. Часть скриптов кладёт себя только в
# свою группу (бомба, коктейль, компас), поэтому «obstacle» одной не хватает.
const HAZARD_GROUPS : Array = [
	"obstacle", "slowing", "bomb", "compass", "molotov",
]

const CLR_READY   := Color(0.35, 1.00, 0.45, 0.85)
const CLR_COOLING := Color(0.85, 0.85, 0.90, 0.38)
# Радиус кольца берётся из РАЗМЕРА предмета: бочка вдвое больше камня, и
# одинаковое кольцо у одного лежало бы внутри картинки, а у другого висело в
# воздухе. Границы — чтобы бомж не получил кольцо в пол-экрана.
const RING_MIN    : float = 20.0
const RING_MAX    : float = 58.0
const RING_PAD    : float = 5.0
const RING_W      : float = 2.5
const DASHES      : int   = 8      # столько дуг в пунктире остывающего кольца

var _nrm : Node = null
# Пересобираем список раз в несколько кадров: предметы спавнятся пачками, и
# обходить дерево каждый кадр незачем.
const RESCAN_EVERY : int = 6
var _tick  : int   = 0
var _items : Array = []

func setup(nrm: Node) -> void:
	_nrm = nrm
	z_index = 5
	_rescan()

func _process(_dt: float) -> void:
	if not is_instance_valid(_nrm) or not bool(_nrm.call("has_any_resist")):
		if not _items.is_empty():
			_items.clear()
			queue_redraw()
		return
	_tick += 1
	if _tick >= RESCAN_EVERY:
		_tick = 0
		_rescan()
	# Рисовать нечего — не будим перерисовку каждый кадр.
	if not _items.is_empty():
		queue_redraw()

func _rescan() -> void:
	_items.clear()
	var tree := get_tree()
	if tree == null:
		return
	var seen : Dictionary = {}
	for grp in HAZARD_GROUPS:
		for n in tree.get_nodes_in_group(grp):
			if not (n is Area2D) or seen.has(n.get_instance_id()):
				continue
			seen[n.get_instance_id()] = true
			# Тег разбирается ОДИН раз, при попадании предмета в список: дальше
			# каждый кадр остаётся только спросить, готов ли резист.
			var tag := String(_nrm.call("resist_tag_for", n))
			if tag == "":
				continue
			_items.append({ "n": n, "tag": tag, "r": _ring_radius(n as Node2D) })

# Полурадиус нарисованного предмета плюс поле. Спрайт масштабируется спавнером
# под скорость волны, поэтому размер считаем по факту, а не по текстуре.
func _ring_radius(n: Node2D) -> float:
	var spr := n.get_node_or_null("Sprite2D") as Sprite2D
	if spr == null or spr.texture == null:
		return RING_MIN + RING_PAD
	var ts := spr.texture.get_size()
	var sc := spr.scale * n.scale
	var half : float = maxf(ts.x * absf(sc.x), ts.y * absf(sc.y)) * 0.5
	return clampf(half + RING_PAD, RING_MIN, RING_MAX)

func _draw() -> void:
	if not is_instance_valid(_nrm):
		return
	for e in _items:
		var area = e["n"]
		if not is_instance_valid(area):
			continue
		var st : int = int(_nrm.call("resist_state_for_tag", String(e["tag"])))
		if st == 0:
			continue
		var p := to_local((area as Node2D).global_position)
		var r : float = float(e["r"])
		# Тонкая тёмная подложка: кольцо висит на кирпичной стене, и без неё
		# зелёный по светлому кирпичу пропадает.
		draw_arc(p, r, 0.0, TAU, 40, Color(0, 0, 0, 0.45), RING_W + 2.0, true)
		if st == 1:
			draw_arc(p, r, 0.0, TAU, 40, CLR_READY, RING_W, true)
		else:
			_draw_dashed(p, r, CLR_COOLING, RING_W)

# Пунктир — половина сегмента рисуется, половина пропускается.
func _draw_dashed(c: Vector2, r: float, col: Color, w: float) -> void:
	var step : float = TAU / float(DASHES)
	for i in DASHES:
		var a0 : float = float(i) * step
		draw_arc(c, r, a0, a0 + step * 0.55, 6, col, w, true)
