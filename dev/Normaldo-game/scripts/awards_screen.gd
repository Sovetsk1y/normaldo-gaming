extends Node2D
class_name AwardsScreen

# ── Экран достижений ─────────────────────────────────────────────────────────
# Слева корешок с двенадцатью категориями и счётчиком у каждой, справа страница
# выбранной категории со строками. Та же мизансцена, что у книги учителя, и по
# той же причине: категорий двенадцать, и вкладками поверху они не помещаются —
# у лидеров их четыре, и полоса уже тесная.
#
# ── Имя файла ────────────────────────────────────────────────────────────────
# `achievements_screen.gd` занят КНИГОЙ УЧИТЕЛЯ — она называлась достижениями,
# когда других не было. Переименовывать её сейчас значит трогать чужой рабочий
# экран ради красоты имени, поэтому этот файл называется наградами. Внутри
# путаницы нет: книга — про сюжет, награды — про Game Center.
#
# ── Экран собран НА МОКАХ ────────────────────────────────────────────────────
# Машинерии счётчиков ещё нет; числа берутся из `achievements_mock.gd`. Список
# достижений при этом НАСТОЯЩИЙ — он сгенерирован из спеки, и когда появится
# менеджер, поменяется ровно источник прогресса: три вызова `_done`, `_counter`,
# `_progress` ниже.
#
# См. /Концепция/Достижения.md, /Концепция/UI — паттерны интерфейса.md

const UI_FONT        := preload("res://assets/fonts/RussoOne-Regular.ttf")
const TEX_DOLLAR     := preload("res://assets/items/dollar.png")
const TEX_TOKEN      := preload("res://assets/items/token.png")
const TEX_BG         := preload("res://assets/ui/leaders/bg_leaders.png")
const TEX_BACK_ARROW := preload("res://assets/ui/quests/back_arrow.png")

const CLR_PAGE      := Color(0.05, 0.04, 0.03, 0.94)
const CLR_PAGE_EDGE := Color(0.26, 0.22, 0.16, 0.95)
const CLR_ROW       := Color(0.10, 0.09, 0.06, 0.95)
const CLR_ROW_DONE  := Color(0.09, 0.16, 0.09, 0.96)
const CLR_ROW_EDGE  := Color(0.22, 0.19, 0.13, 0.90)
const CLR_DONE_EDGE := Color(0.36, 0.62, 0.32, 0.95)
const CLR_SPINE_SEL := Color(0.20, 0.16, 0.08, 0.98)
const CLR_TEXT      := Color(1.00, 0.96, 0.88)
const CLR_TEXT_DIM  := Color(0.72, 0.69, 0.62)
const CLR_GOLD      := Color(1.00, 0.85, 0.35)

# Цвет веса. Он же цвет медали в строке — по нему достижение и опознаётся
# издалека, до чтения подписи.
const TIER_COLOR : Array = [
	Color(0.5, 0.5, 0.5),        # —
	Color(0.78, 0.51, 0.32),     # бронза
	Color(0.83, 0.85, 0.90),     # серебро
	Color(1.00, 0.82, 0.30),     # золото
	Color(0.62, 0.85, 1.00),     # платина
]

# ── Раскладка ────────────────────────────────────────────────────────────────
# Канвас 430×192, как на остальных экранах; всё, что ниже, — канвас-пиксели.
const CANVAS_W : float = 430.0
const CANVAS_H : float = 192.0
const BACK_BTN_POS  : Vector2 = Vector2(10.0, 6.0)
const BACK_BTN_SIZE : Vector2 = Vector2(24.0, 15.0)
const TITLE_Y       : float = 6.0
const TITLE_FONT_SZ : int   = 16
const RES_RIGHT_PAD : float = 10.0
const RES_Y         : float = 7.0
const RES_ICON_SZ   : float = 16.0
const RES_NUM_W     : float = 36.0
const RES_FONT_SZ   : int   = 14

# Разворот: корешок слева, страница справа.
const SPREAD_Y : float = 46.0
const SPREAD_H : float = 138.0
const SPINE_X  : float = 11.0
const SPINE_W  : float = 108.0
const PAGE_X   : float = 126.0
const PAGE_W   : float = 293.0

const SLIDE_TIME  : float = 0.45
const SLIDE_TRANS : int   = Tween.TRANS_QUAD

var _hud       : Node = null
var _cat       : int  = 0
var _slide_root: Control = null
var _page_scroll : ScrollContainer = null
var _page_body   : Control = null
var _spine_bg    : Array = []   # Panel на категорию
var _spine_lbl   : Array = []   # Label на категорию
var _sx : float = 1.0
var _sy : float = 1.0

func setup(hud: Node, category: int = 0) -> void:
	_hud = hud
	_cat = clampi(category, 0, Achievements.CATEGORIES.size() - 1)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var vp := get_viewport().get_visible_rect().size
	_sx = vp.x / CANVAS_W
	_sy = vp.y / CANVAS_H
	_build(vp)
	_rebuild_page()
	_refresh_spine()
	# Тот же заезд сверху, что у заданий, книги, скинов и лидеров.
	_slide_root.position = Vector2(0.0, vp.y)
	var tw := create_tween()
	tw.tween_property(_slide_root, "position", Vector2.ZERO, SLIDE_TIME) \
		.set_trans(SLIDE_TRANS).set_ease(Tween.EASE_IN)

# ── Источник прогресса ───────────────────────────────────────────────────────
# Три функции, и больше экран о происхождении чисел ничего не знает. Появится
# менеджер — меняется только их нутро.
func _done(a: Dictionary) -> bool:      return AchievementsMock.is_done(a)
func _counter(a: Dictionary) -> int:    return AchievementsMock.counter(a)
func _progress(a: Dictionary) -> float: return AchievementsMock.progress(a)
func _cat_done(key: String) -> int:     return AchievementsMock.category_done(key)
func _summary() -> Dictionary:          return AchievementsMock.summary()

# ── Сборка ───────────────────────────────────────────────────────────────────

func _build(vp: Vector2) -> void:
	_slide_root = Control.new()
	_slide_root.size         = vp
	_slide_root.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_slide_root)

	var bg := TextureRect.new()
	bg.texture        = TEX_BG
	bg.stretch_mode   = TextureRect.STRETCH_SCALE
	bg.expand_mode    = TextureRect.EXPAND_IGNORE_SIZE
	bg.size           = vp
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bg.mouse_filter   = Control.MOUSE_FILTER_IGNORE
	_slide_root.add_child(bg)

	_build_back_btn()
	_label("ДОСТИЖЕНИЯ", TITLE_FONT_SZ, CLR_TEXT,
		Vector2(0.0, TITLE_Y * _sy), Vector2(vp.x, 20.0 * _sy),
		HORIZONTAL_ALIGNMENT_CENTER, _slide_root)
	_build_top_resources(vp)
	_build_summary(vp)
	_build_spine()
	_build_page()

func _build_back_btn() -> void:
	var size := Vector2(BACK_BTN_SIZE.x * _sx, BACK_BTN_SIZE.y * _sy)
	var visual := Control.new()
	visual.size         = size
	visual.position     = Vector2(BACK_BTN_POS.x * _sx, BACK_BTN_POS.y * _sy)
	visual.pivot_offset = size * 0.5
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slide_root.add_child(visual)

	var icon := TextureRect.new()
	icon.texture        = TEX_BACK_ARROW
	icon.stretch_mode   = TextureRect.STRETCH_SCALE
	icon.expand_mode    = TextureRect.EXPAND_IGNORE_SIZE
	icon.size           = size
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter   = Control.MOUSE_FILTER_IGNORE
	visual.add_child(icon)

	var btn := Button.new()
	btn.flat       = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.size       = size + Vector2(14.0, 14.0)
	btn.position   = visual.position - Vector2(7.0, 7.0)
	btn.pressed.connect(_on_close)
	btn.button_down.connect(UiKit.press_anim.bind(visual, true))
	btn.button_up.connect(UiKit.press_anim.bind(visual, false))
	btn.mouse_exited.connect(UiKit.press_anim.bind(visual, false))
	_slide_root.add_child(btn)

func _build_top_resources(vp: Vector2) -> void:
	var icon_sz : float = RES_ICON_SZ * _sy
	var num_w   : float = RES_NUM_W * _sx
	var pair_w  : float = icon_sz + 2.0 + num_w
	var start_x : float = vp.x - RES_RIGHT_PAD * _sx - pair_w * 2.0 - 4.0
	var top_y   : float = RES_Y * _sy
	var pairs := [[TEX_DOLLAR, SaveData.dollars], [TEX_TOKEN, SaveData.tokens]]
	for i in pairs.size():
		var x : float = start_x + pair_w * float(i) + 4.0 * float(i)
		var ic := TextureRect.new()
		ic.texture        = pairs[i][0]
		ic.stretch_mode   = TextureRect.STRETCH_SCALE
		ic.expand_mode    = TextureRect.EXPAND_IGNORE_SIZE
		ic.size           = Vector2(icon_sz, icon_sz)
		ic.position       = Vector2(x, top_y)
		ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ic.mouse_filter   = Control.MOUSE_FILTER_IGNORE
		_slide_root.add_child(ic)
		_label(str(pairs[i][1]), RES_FONT_SZ, CLR_TEXT,
			Vector2(x + icon_sz + 2.0, top_y - 2.0), Vector2(num_w, icon_sz + 4.0),
			HORIZONTAL_ALIGNMENT_LEFT, _slide_root)

# Шапка: сколько взято из скольких и на сколько очков, плюс полоса.
# Общее число — главное, что игрок хочет знать на этом экране, и стоять оно
# обязано выше списка: пролистывать двенадцать категорий, чтобы сложить их в
# уме, — не ответ на вопрос «сколько у меня».
func _build_summary(vp: Vector2) -> void:
	var s : Dictionary = _summary()
	var w : float = 300.0 * _sx * 0.8
	var h : float = 24.0 * _sy
	var x : float = (vp.x - w) * 0.5
	var y : float = 24.0 * _sy
	UiKit.panel(_slide_root, Vector2(x, y), Vector2(w, h),
		Color(0.10, 0.08, 0.05, 0.90), 8, Color(0.50, 0.42, 0.22, 0.95))

	var pct : float = float(s["done"]) / maxf(1.0, float(s["total"]))
	var bar_pad : float = 6.0
	var bar_w : float = w - bar_pad * 2.0
	UiKit.panel(_slide_root, Vector2(x + bar_pad, y + h - bar_pad - 3.0),
		Vector2(bar_w, 3.0), Color(0.22, 0.19, 0.12, 0.95), 2)
	if pct > 0.0:
		UiKit.panel(_slide_root, Vector2(x + bar_pad, y + h - bar_pad - 3.0),
			Vector2(maxf(3.0, bar_w * pct), 3.0), CLR_GOLD, 2)

	_label("%d из %d  ·  %d из %d очков"
			% [int(s["done"]), int(s["total"]), int(s["points"]), int(s["points_all"])],
		12, CLR_GOLD, Vector2(x, y - 1.0), Vector2(w, h - 6.0),
		HORIZONTAL_ALIGNMENT_CENTER, _slide_root)

# ── Корешок ──────────────────────────────────────────────────────────────────
# Категорий двенадцать, и в высоту разворота они влезают впритык. Поэтому
# корешок — тоже прокрутка: на телефоне с другим соотношением сторон строки
# иначе обрежутся, и нижние категории станут недоступны молча.
func _build_spine() -> void:
	var x : float = SPINE_X * _sx
	var y : float = SPREAD_Y * _sy
	var w : float = SPINE_W * _sx
	var h : float = SPREAD_H * _sy
	UiKit.panel(_slide_root, Vector2(x - 4.0, y - 4.0), Vector2(w + 8.0, h + 8.0),
		CLR_PAGE, 12, CLR_PAGE_EDGE)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(x, y)
	scroll.size     = Vector2(w, h)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode   = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.set("scroll_deadzone", 18)
	_slide_root.add_child(scroll)

	var body := Control.new()
	scroll.add_child(body)

	var row_h : float = 26.0
	var gap   : float = 2.0
	_spine_bg.clear()
	_spine_lbl.clear()
	for i in Achievements.CATEGORIES.size():
		var cat : Dictionary = Achievements.CATEGORIES[i]
		var ry : float = float(i) * (row_h + gap)
		var p := UiKit.panel(body, Vector2(0.0, ry), Vector2(w - 6.0, row_h),
			CLR_ROW, 8, CLR_ROW_EDGE)
		_spine_bg.append(p)
		var lbl := _label(String(cat["tab"]), 11, CLR_TEXT,
			Vector2(8.0, ry), Vector2(w - 60.0, row_h),
			HORIZONTAL_ALIGNMENT_LEFT, body)
		_spine_lbl.append(lbl)
		# Счётчик у категории — «сколько взято из скольких». Он и делает корешок
		# полезным: без него это просто список слов.
		var total : int = Achievements.in_category(String(cat["key"])).size()
		_label("%d/%d" % [_cat_done(String(cat["key"])), total], 10, CLR_TEXT_DIM,
			Vector2(w - 52.0, ry), Vector2(44.0, row_h),
			HORIZONTAL_ALIGNMENT_RIGHT, body)
		UiKit.tap_zone(body, Vector2(0.0, ry), Vector2(w - 6.0, row_h),
			_on_category.bind(i))

	body.custom_minimum_size = Vector2(w - 6.0,
		float(Achievements.CATEGORIES.size()) * (row_h + gap))

func _build_page() -> void:
	var x : float = PAGE_X * _sx
	var y : float = SPREAD_Y * _sy
	var w : float = PAGE_W * _sx
	var h : float = SPREAD_H * _sy
	UiKit.panel(_slide_root, Vector2(x - 4.0, y - 4.0), Vector2(w + 8.0, h + 8.0),
		CLR_PAGE, 12, CLR_PAGE_EDGE)

	_page_scroll = ScrollContainer.new()
	_page_scroll.position = Vector2(x, y)
	_page_scroll.size     = Vector2(w, h)
	_page_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_page_scroll.vertical_scroll_mode   = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_page_scroll.set("scroll_deadzone", 18)
	_slide_root.add_child(_page_scroll)

	_page_body = Control.new()
	_page_scroll.add_child(_page_body)

# ── Страница категории ───────────────────────────────────────────────────────

const ROW_H : float = 52.0
const ROW_GAP : float = 4.0

func _rebuild_page() -> void:
	if not is_instance_valid(_page_body):
		return
	for c in _page_body.get_children():
		c.queue_free()

	var key : String = String(Achievements.CATEGORIES[_cat]["key"])
	var list : Array = Achievements.in_category(key)
	var w : float = _page_scroll.size.x - 6.0
	var cy : float = 0.0
	for a in list:
		_add_row(a, cy, w)
		cy += ROW_H + ROW_GAP
	_page_body.custom_minimum_size = Vector2(w, cy)
	_page_scroll.scroll_vertical = 0

func _add_row(a: Dictionary, cy: float, w: float) -> void:
	var done : bool = _done(a)
	var tier : int  = int(a["tier"])
	var hidden_now : bool = bool(a.get("hidden", false)) and not done

	UiKit.panel(_page_body, Vector2(0.0, cy), Vector2(w, ROW_H),
		CLR_ROW_DONE if done else CLR_ROW, 10,
		CLR_DONE_EDGE if done else CLR_ROW_EDGE)

	# Медаль — кружок цвета веса с числом очков. Рисованных иконок под каждое
	# достижение ещё нет (их семьдесят восемь, это отдельная работа художника),
	# и до них медаль честнее заглушки: она несёт настоящую величину — вес.
	var med : float = 26.0
	var med_pos := Vector2(8.0, (ROW_H - med) * 0.5)
	var col : Color = TIER_COLOR[tier]
	if hidden_now:
		col = Color(0.35, 0.33, 0.30)
	UiKit.panel(_page_body, med_pos + Vector2(0.0, cy), Vector2(med, med),
		Color(col.r * 0.35, col.g * 0.35, col.b * 0.35, 0.95), int(med * 0.5), col, 2)
	_label("?" if hidden_now else str(Achievements.points(a)), 11, col,
		med_pos + Vector2(0.0, cy), Vector2(med, med),
		HORIZONTAL_ALIGNMENT_CENTER, _page_body)

	var tx : float = med_pos.x + med + 8.0
	var tw : float = w - tx - 10.0

	var title : String = "???" if hidden_now else String(a["title"])
	_label(title, 13, CLR_TEXT if not hidden_now else CLR_TEXT_DIM,
		Vector2(tx, cy + 4.0), Vector2(tw - 60.0, 16.0),
		HORIZONTAL_ALIGNMENT_LEFT, _page_body)

	var desc : String = "Скрытое достижение" if hidden_now else String(a["desc"])
	_label(desc, 10, CLR_TEXT_DIM, Vector2(tx, cy + 19.0), Vector2(tw - 60.0, 14.0),
		HORIZONTAL_ALIGNMENT_LEFT, _page_body)

	# Метка очереди. Экран показывают на согласовании, и отличить «сделаем
	# сразу» от «сделаем потом» надо прямо здесь, а не по таблице.
	#
	# «Резерв» — не третья волна, а отдельное состояние: достижение объявлено, но
	# в App Store Connect не заводится вовсе (см. Achievements.reserved). Метка
	# «2-я волна» на нём была бы враньём — его не сделают и во вторую.
	var tag : String = ""
	var tag_edge : Color = Color(0.42, 0.36, 0.24, 0.90)
	if bool(a.get("reserved", false)):
		tag = "резерв"
		tag_edge = Color(0.62, 0.50, 0.24, 0.95)
	elif int(a.get("wave", 1)) == 2:
		tag = "2-я волна"
	if not tag.is_empty():
		UiKit.panel(_page_body, Vector2(w - 58.0, cy + 5.0), Vector2(50.0, 13.0),
			Color(0.16, 0.14, 0.10, 0.95), 6, tag_edge)
		_label(tag, 8, CLR_TEXT_DIM, Vector2(w - 58.0, cy + 4.0),
			Vector2(50.0, 13.0), HORIZONTAL_ALIGNMENT_CENTER, _page_body)

	# ── Полоса выполнения ────────────────────────────────────────────────────
	# Разовому достижению (goal = 1) полоса не рисуется: полоса на «да/нет» —
	# это либо пустая черта, либо полная, и в обоих случаях она ничего не
	# сообщает сверх подписи.
	var goal : int = int(a["goal"])
	var bar_y : float = cy + ROW_H - 12.0
	if goal > 1 and not hidden_now:
		var bw : float = tw - 66.0
		UiKit.panel(_page_body, Vector2(tx, bar_y), Vector2(bw, 5.0),
			Color(0.20, 0.18, 0.12, 0.95), 2)
		var p : float = _progress(a)
		if p > 0.0:
			UiKit.panel(_page_body, Vector2(tx, bar_y), Vector2(maxf(3.0, bw * p), 5.0),
				CLR_DONE_EDGE if done else TIER_COLOR[tier], 2)
		_label("%s / %s" % [_num(mini(_counter(a), goal)), _num(goal)], 9,
			CLR_TEXT_DIM, Vector2(tx + bw + 6.0, bar_y - 5.0), Vector2(60.0, 14.0),
			HORIZONTAL_ALIGNMENT_LEFT, _page_body)

	# Взятое помечается галочкой справа — цвет рамки один и тот же зелёный, а
	# рамку на тёмном фоне через один экран уже не отличить.
	if done:
		_label("✓", 18, CLR_DONE_EDGE, Vector2(w - 30.0, cy + (ROW_H - 22.0) * 0.5),
			Vector2(22.0, 22.0), HORIZONTAL_ALIGNMENT_CENTER, _page_body)

# Тысячи с неразрывным пробелом: «250 000» читается, «250000» — нет.
func _num(v: int) -> String:
	var s := str(v)
	var out := ""
	var n := s.length()
	for i in n:
		if i > 0 and (n - i) % 3 == 0:
			out += " "
		out += s[i]
	return out

# ── Переключение категории ───────────────────────────────────────────────────

func _on_category(i: int) -> void:
	if i == _cat:
		return
	_cat = i
	_rebuild_page()
	_refresh_spine()

func _refresh_spine() -> void:
	for i in _spine_bg.size():
		var sel : bool = (i == _cat)
		var p : Panel = _spine_bg[i]
		if is_instance_valid(p):
			p.add_theme_stylebox_override("panel", UiKit.rounded(
				CLR_SPINE_SEL if sel else CLR_ROW, 8,
				CLR_GOLD if sel else CLR_ROW_EDGE, 2))
		var l : Label = _spine_lbl[i]
		if is_instance_valid(l):
			l.modulate = CLR_GOLD if sel else CLR_TEXT

# ── Мелочи ───────────────────────────────────────────────────────────────────

func _label(text: String, size_px: int, col: Color, pos: Vector2, size: Vector2,
		align: int, parent: Node) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", UI_FONT)
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.65))
	l.add_theme_constant_override("outline_size", 2)
	l.text                 = text
	l.modulate             = col
	l.horizontal_alignment = align
	l.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	l.clip_text            = true
	l.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	UiKit.place(parent, l, pos, size)
	return l

func _on_close() -> void:
	if not is_instance_valid(_slide_root):
		queue_free()
		return
	var vp := get_viewport().get_visible_rect().size
	var tw := create_tween()
	tw.tween_property(_slide_root, "position", Vector2(0.0, vp.y), SLIDE_TIME) \
		.set_trans(SLIDE_TRANS).set_ease(Tween.EASE_IN)
	tw.tween_callback(Callable(self, "queue_free"))
