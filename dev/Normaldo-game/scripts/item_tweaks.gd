extends RefCounted

# ── Ручной слой размеров и хитбоксов предметов ────────────────────────────────
# Размер предмета на экране считается из его рисунка (`ItemSizing`), а хитбокс —
# каждым скриптом у себя. Обычно это верно. Но иногда нет: у предмета оказывается
# длинный хвост, из-за которого рисунок ужимается сильнее нужного; или наоборот —
# хитбокс размером с кадр, и предмет бьёт воздухом вокруг себя.
#
# Раньше такое чинилось правкой числа в скрипте: пересобрал, посмотрел,
# пересобрал. Тут — тем же способом, что и у скинов: РУЧНОЙ СЛОЙ поверх
# посчитанного, который правится прямо в игре и лежит в `dev/item_layout.json`.
#
# ── Ключ — путь к текстуре, а не имя предмета ────────────────────────────────
# Имена у предметов есть не у всех: половина потока летит одним скриптом
# `item.gd`, отличаясь только картинкой, а другая половина — своими сценами.
# Единственное, что есть у каждого и одинаково читается, — это его рисунок.
#
# ── Почему правка применяется к УЗЛУ, а не к расчёту ─────────────────────────
# Размер и хитбокс ставят тридцать пять разных скриптов, каждый по-своему:
# кто-то через `ItemSizing.content_scale`, кто-то числом в `_ready`, кто-то —
# формой из сцены. Влезть в расчёт значило бы править тридцать пять мест и
# помнить про тридцать шестое, когда его напишут.
#
# Поэтому правка накладывается на ГОТОВЫЙ УЗЕЛ, уже собравший себя: находим его
# спрайт и его формы столкновения и умножаем то, что там стоит. Спавнер зовёт
# это один раз — на `child_entered_tree`, то есть на любой предмет, каким бы
# путём он ни появился, включая те пути, которых ещё нет.
#
# См. scripts/skin_lab.gd (раздел ПРЕДМЕТЫ), scripts/item_sizing.gd

const LAYOUT_PATH : String = "res://dev/item_layout.json"

# Множители. 1.0 — «замер не трогаем», и такие записи в файл не пишутся вовсе:
# файл из единиц прячет настоящие правки среди пустых строк.
const DEFAULT : Dictionary = { "size": 1.0, "hit": 1.0 }

# Пределы. Не вкусовщина: множитель вне этих границ означает не «подправил», а
# «поменял предмет» — такое чинится рисунком, а не ползунком.
const MULT_MIN : float = 0.35
const MULT_MAX : float = 3.00

static var _layer : Dictionary = {}
static var _loaded : bool = false

static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(LAYOUT_PATH):
		return
	var f := FileAccess.open(LAYOUT_PATH, FileAccess.READ)
	if f == null:
		return
	var raw = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(raw) == TYPE_DICTIONARY:
		var items = (raw as Dictionary).get("items", {})
		if typeof(items) == TYPE_DICTIONARY:
			_layer = items

# ── Чтение ───────────────────────────────────────────────────────────────────

static func mult_for(tex_path: String) -> Dictionary:
	_ensure()
	var e = _layer.get(tex_path, null)
	if typeof(e) != TYPE_DICTIONARY:
		return DEFAULT.duplicate()
	return {
		"size": clampf(float((e as Dictionary).get("size", 1.0)), MULT_MIN, MULT_MAX),
		"hit":  clampf(float((e as Dictionary).get("hit",  1.0)), MULT_MIN, MULT_MAX),
	}

static func has_tweak(tex_path: String) -> bool:
	_ensure()
	return _layer.has(tex_path)

# Все правленные пути — их показывает лаборатория списком.
static func tweaked_paths() -> Array:
	_ensure()
	var out : Array = _layer.keys()
	out.sort()
	return out

# ── Правка ───────────────────────────────────────────────────────────────────

static func set_mult(tex_path: String, size: float, hit: float) -> void:
	_ensure()
	if tex_path.is_empty():
		return
	var s := clampf(size, MULT_MIN, MULT_MAX)
	var h := clampf(hit,  MULT_MIN, MULT_MAX)
	# Возврат к единице — это УДАЛЕНИЕ записи, а не запись единицы. Иначе файл
	# копит строки «ничего не менял», и найти в нём настоящие правки нельзя.
	if is_equal_approx(s, 1.0) and is_equal_approx(h, 1.0):
		_layer.erase(tex_path)
		return
	_layer[tex_path] = { "size": s, "hit": h }

static func reset(tex_path: String) -> void:
	_ensure()
	_layer.erase(tex_path)

static func snapshot() -> Dictionary:
	_ensure()
	return _layer.duplicate(true)

static func restore(snap: Dictionary) -> void:
	_layer  = snap.duplicate(true)
	_loaded = true

# Запись обратно в исходник. Пустая строка — успех, текст — ошибка: `res://`
# пишется только из редактора, а в собранной игре открытие на запись не удастся,
# и молчать об этом нельзя — иначе полчаса правок уйдут в никуда.
static func save() -> String:
	_ensure()
	var out : Dictionary = {
		"_comment": "Ручной слой размеров и хитбоксов предметов. "
			+ "Ключ — путь к текстуре, значения — МНОЖИТЕЛИ поверх посчитанного "
			+ "(size — рисунок, hit — форма столкновения). Правится в лаборатории "
			+ "(раздел ПРЕДМЕТЫ), руками сюда лезть незачем. "
			+ "Записи с обоими множителями 1.0 не хранятся.",
		"items": _layer,
	}
	var f := FileAccess.open(LAYOUT_PATH, FileAccess.WRITE)
	if f == null:
		return "нет доступа на запись (%s)" % LAYOUT_PATH
	f.store_string(JSON.stringify(out, "  ", false) + "\n")
	f.close()
	return ""

# ── Наложение на живой узел ──────────────────────────────────────────────────
# Узел уже собрал себя сам: спрайт отмасштабирован, форма поставлена. Мы только
# УМНОЖАЕМ то, что там стоит, и помечаем узел, чтобы не умножить дважды.
#
# Помета обязательна. Спавнер зовёт это на `child_entered_tree`, а предмет может
# войти в дерево повторно — например, когда его перевешивают на другой узел
# (мэджик бокс, спелл Спайди). Второй проход умножил бы предмет ещё раз, и он
# рос бы с каждым переносом.
const MARK : String = "_item_tweaked"

static func apply(node: Node) -> void:
	if node == null or not is_instance_valid(node) or node.has_meta(MARK):
		return
	var spr := _find_sprite(node)
	if spr == null:
		return
	var path : String = spr.texture.resource_path if spr.texture != null else ""
	if path.is_empty() or not has_tweak(path):
		return
	var m := mult_for(path)
	node.set_meta(MARK, true)
	spr.scale *= float(m["size"])
	for sh in _find_shapes(node):
		_scale_shape(sh, float(m["hit"]))

# Спрайт ищется ВГЛУБЬ: у сцен предметов он лежит то прямо в корне, то внутри
# обёртки. Берётся ПЕРВЫЙ — у предметов с несколькими спрайтами (бомж с бочкой)
# первый и есть тот, по которому предмет узнают.
static func _find_sprite(node: Node) -> Sprite2D:
	if node is Sprite2D:
		return node
	for c in node.get_children():
		var s := _find_sprite(c)
		if s != null:
			return s
	return null

static func _find_shapes(node: Node) -> Array:
	var out : Array = []
	if node is CollisionShape2D and (node as CollisionShape2D).shape != null:
		out.append(node)
	for c in node.get_children():
		out.append_array(_find_shapes(c))
	return out

# Форма правится ПО ТИПУ, а не общим `scale` узла: масштабированная
# CollisionShape2D в Godot 2D работает, но её `shape` при этом врёт всем, кто
# спросит радиус, — а спрашивают его и предметы, и тесты.
static func _scale_shape(cs: CollisionShape2D, k: float) -> void:
	var sh : Shape2D = cs.shape
	if sh is CircleShape2D:
		# Форма ДУБЛИРУЕТСЯ: одна и та же CircleShape2D нередко висит на всех
		# экземплярах сцены сразу, и правка на месте раздула бы каждый предмет
		# этого вида, включая уже летящие.
		var c := (sh as CircleShape2D).duplicate() as CircleShape2D
		c.radius *= k
		cs.shape = c
	elif sh is RectangleShape2D:
		var r := (sh as RectangleShape2D).duplicate() as RectangleShape2D
		r.size *= k
		cs.shape = r
	elif sh is CapsuleShape2D:
		var p := (sh as CapsuleShape2D).duplicate() as CapsuleShape2D
		p.radius *= k
		p.height *= k
		cs.shape = p
