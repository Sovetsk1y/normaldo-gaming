extends Node2D
class_name AchievementsScreen

# ─── Книга учителя — сюжетная кампания ────────────────────────────────────────
# Разворот книги: слева корешок с главами и общим прогрессом, справа страница
# выбранной главы с её заданиями. До переделки это был один вертикальный список
# на 17 заданий в окне высотой в две с половиной строки — где ты в кампании,
# понять было нельзя, а половина альбомного экрана пустовала.
#
# См. /Концепция/Экран книги учителя.md

const UI_FONT        := preload("res://assets/fonts/RussoOne-Regular.ttf")
const TEX_DOLLAR     := preload("res://assets/items/dollar.png")
const TEX_TOKEN      := preload("res://assets/items/token.png")
const TEX_BG_BOOK    := preload("res://assets/ui/book/bg_book.png")
const TEX_BACK_ARROW := preload("res://assets/ui/quests/back_arrow.png")

const CLR_PAGE      := Color(0.09, 0.07, 0.04, 0.94)
const CLR_PAGE_EDGE := Color(0.42, 0.32, 0.14, 0.85)
const CLR_ROW       := Color(0.13, 0.11, 0.07, 0.95)
const CLR_ROW_EDGE  := Color(0.28, 0.23, 0.14, 0.85)
const CLR_ROW_SEL   := Color(0.22, 0.17, 0.08, 0.98)
const CLR_ROW_DONE  := Color(0.07, 0.07, 0.05, 0.90)
const CLR_ROW_READY := Color(0.13, 0.26, 0.09, 0.97)
const CLR_READY_EDGE:= Color(0.55, 0.95, 0.40, 0.95)
const CLR_GOLD      := Color(1.00, 0.85, 0.35)
const CLR_ACCENT    := Color(0.86, 0.68, 0.28, 0.95)
const CLR_ENDLESS   := Color(0.55, 0.85, 1.00)
const CLR_TEXT      := Color(1.00, 0.96, 0.88)
const CLR_TEXT_DIM  := Color(0.88, 0.86, 0.80)
# Забранное приглушается до 0.55 — ниже уже не прочитать, что именно ты сделал.
const DIM_CLAIMED   : float = 0.55

# ── Раскладка (канвас 430×192, как на остальных экранах) ─────────────────────
const CANVAS_W : float = 430.0
const CANVAS_H : float = 192.0
const BACK_BTN_POS    : Vector2 = Vector2(10.0, 6.0)
const BACK_BTN_SIZE   : Vector2 = Vector2(24.0, 15.0)
const TITLE_X_OFFSET  : float   = -30.0
const TITLE_Y         : float   = 6.0
const TITLE_H         : float   = 20.0
const TITLE_FONT_SZ   : int     = 16
const RES_RIGHT_PAD   : float   = -10.0
const RES_Y           : float   = 7.0
const RES_ICON_SZ     : float   = 16.0
const RES_GAP         : float   = 2.0
const RES_NUM_W       : float   = 36.0
const RES_FONT_SZ     : int     = 14
# Разворот: корешок слева, страница главы справа.
const SPINE_X : float = 12.0
const SPINE_W : float = 118.0
const PAGE_X  : float = 136.0
const PAGE_W  : float = 282.0
const SPREAD_Y : float = 34.0
const SPREAD_H : float = 150.0
# Въезд экрана — тот же тайминг, что у заданий и автоматов.
const SLIDE_TIME      : float = 0.45
const SLIDE_TRANS     : int   = Tween.TRANS_QUAD
const SLIDE_EASE_IN   : int   = Tween.EASE_IN
const SLIDE_EASE_OUT  : int   = Tween.EASE_IN

# Внутренние размеры страниц (экранные px, считаются от разворота).
const PAD          : float = 10.0
const CH_ROW_H_MIN : float = 36.0
const CH_ROW_H_MAX : float = 52.0
const CH_ROW_GAP   : float = 5.0
const Q_ROW_GAP    : float = 8.0
const Q_ROW_H_MAX  : float = 78.0
const STATUS_W     : float = 120.0
const RWD_W        : float = 150.0
const BADGE_SZ     : float = 30.0

var _hud          : Node = null
var _slide_root   : Control = null
# Корешок (главы) и страница (задания главы) — у каждой свой скролл на случай,
# если кампанию расширят; при нынешнем контенте обе помещаются целиком.
var _spine_scroll : ScrollContainer = null
var _spine_body   : Control = null
var _page_scroll  : ScrollContainer = null
var _page_body    : Control = null
var _page_head    : Control = null
var _overall_root : Control = null
var _dollar_lbl   : Label = null
var _token_lbl    : Label = null
var _dollar_target : Vector2 = Vector2.ZERO
var _token_target  : Vector2 = Vector2.ZERO
var _claim_busy   : bool = false
var _lay          : Dictionary = {}

# Выбранная глава — индекс в QuestManager.CHAPTERS (не порядковый номер среди
# видимых: главы про бесконечный режим до его открытия скрыты).
var _sel_chapter    : int = -1
# Задание, на которое привёл переход по уведомлению: его строка подсвечивается.
var _focus_story_idx : int = -1

func setup(hud: Node, focus_story_idx: int = -1) -> void:
	_hud = hud
	_focus_story_idx = focus_story_idx

func _ready() -> void:
	var vp := get_viewport().get_visible_rect().size
	_build(vp)
	# Проезд камеры: экран приезжает снизу, меню уезжает вверх в такт.
	_slide_root.position = Vector2(0.0, vp.y)
	var tw := create_tween()
	tw.tween_property(_slide_root, "position", Vector2.ZERO, SLIDE_TIME)\
		.set_trans(SLIDE_TRANS).set_ease(SLIDE_EASE_IN)
	if _hud != null and _hud.has_method("_on_book_open_anim_start"):
		_hud._on_book_open_anim_start(SLIDE_TIME, SLIDE_TRANS, SLIDE_EASE_IN)
	QuestManager.quests_updated.connect(_on_quests_updated)
	SaveData.data_changed.connect(_on_data_changed)

# ── Геометрия ────────────────────────────────────────────────────────────────
func _layout(vp: Vector2) -> Dictionary:
	var sx : float = vp.x / CANVAS_W
	var sy : float = vp.y / CANVAS_H
	var top : float = SPREAD_Y * sy
	var hgt : float = SPREAD_H * sy
	var spine := Rect2(SPINE_X * sx, top, SPINE_W * sx, hgt)
	var page  := Rect2(PAGE_X * sx,  top, PAGE_W * sx,  hgt)
	return {
		"sx": sx, "sy": sy,
		"spine": spine,
		"page": page,
		# Корешок: заголовок с числом, общая полоса, ниже список глав.
		"overall": Rect2(spine.position.x + PAD, spine.position.y + PAD,
			spine.size.x - PAD * 2.0, 40.0),
		"ch_list": Rect2(spine.position.x + PAD, spine.position.y + PAD + 46.0,
			spine.size.x - PAD * 2.0, spine.size.y - PAD * 2.0 - 46.0),
		# Страница: шапка главы, ниже её задания.
		"page_head": Rect2(page.position.x + PAD + 4.0, page.position.y + PAD,
			page.size.x - (PAD + 4.0) * 2.0, 26.0),
		"q_list": Rect2(page.position.x + PAD + 4.0, page.position.y + PAD + 34.0,
			page.size.x - (PAD + 4.0) * 2.0, page.size.y - PAD * 2.0 - 34.0),
	}

# ── Данные ───────────────────────────────────────────────────────────────────
# Главы, где все задания завязаны на ещё не открытый бесконечный режим, не
# показываем: экран не должен рассказывать про режим, о котором игрок не знает.
func _visible_chapters() -> Array:
	var out : Array = []
	for i in QuestManager.CHAPTERS.size():
		if _visible_quests(i).size() > 0:
			out.append(i)
	return out

func _visible_quests(ch_idx: int) -> Array:
	var chapter := QuestManager.CHAPTERS[ch_idx] as Dictionary
	var allow_endless : bool = QuestManager.is_endless_unlocked()
	var out : Array = []
	for qi in (chapter["quests"] as Array):
		if not allow_endless and _is_endless_quest(int(qi)):
			continue
		out.append(int(qi))
	return out

func _is_endless_quest(idx: int) -> bool:
	var def := QuestManager.STORY_QUESTS[idx] as Dictionary
	var cond_key = (def.get("cond", "") as String).split(":")[0]
	return QuestManager.is_endless_cond(cond_key)

func _chapter_of(story_idx: int) -> int:
	for i in QuestManager.CHAPTERS.size():
		if _visible_quests(i).has(story_idx):
			return i
	return -1

func _chapter_done(ch_idx: int) -> int:
	var n := 0
	for qi in _visible_quests(ch_idx):
		if bool(QuestManager.story_claimed[qi]):
			n += 1
	return n

func _chapter_has_ready(ch_idx: int) -> bool:
	for qi in _visible_quests(ch_idx):
		if bool(QuestManager.story_completed[qi]) and not bool(QuestManager.story_claimed[qi]):
			return true
	return false

# «Глава 1 — Первый полёт» → «ПЕРВЫЙ ПОЛЁТ»: номер главы уже написан в медальоне.
func _chapter_short(title: String) -> String:
	var parts := title.split("—")
	var tail : String = parts[parts.size() - 1]
	return tail.strip_edges().to_upper()

# Общий прогресс книги — забранные задания из всех видимых глав.
func _overall_progress() -> Vector2i:
	var done := 0
	var total := 0
	for ci in _visible_chapters():
		var qs := _visible_quests(ci)
		total += qs.size()
		for qi in qs:
			if bool(QuestManager.story_claimed[qi]):
				done += 1
	return Vector2i(done, total)

# ── Сборка ───────────────────────────────────────────────────────────────────
func _build(vp: Vector2) -> void:
	_lay = _layout(vp)
	var sx : float = _lay["sx"]
	var sy : float = _lay["sy"]

	_slide_root = Control.new()
	_slide_root.size         = vp
	_slide_root.position     = Vector2.ZERO
	_slide_root.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_slide_root)

	var bg := TextureRect.new()
	bg.texture             = TEX_BG_BOOK
	bg.stretch_mode        = TextureRect.STRETCH_SCALE
	bg.expand_mode         = TextureRect.EXPAND_IGNORE_SIZE
	bg.custom_minimum_size = Vector2.ZERO
	bg.size                = vp
	bg.position            = Vector2.ZERO
	bg.texture_filter      = CanvasItem.TEXTURE_FILTER_NEAREST
	bg.mouse_filter        = Control.MOUSE_FILTER_IGNORE
	_slide_root.add_child(bg)

	_build_back_button(sx, sy)

	var title_lbl := Label.new()
	title_lbl.add_theme_font_override("font", UI_FONT)
	title_lbl.add_theme_font_size_override("font_size", TITLE_FONT_SZ)
	_apply_text_fx(title_lbl)
	title_lbl.text                 = "КНИГА УЧИТЕЛЯ"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	title_lbl.size                 = Vector2(vp.x, TITLE_H * sy)
	title_lbl.position             = Vector2(TITLE_X_OFFSET * sx, TITLE_Y * sy)
	title_lbl.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	_slide_root.add_child(title_lbl)

	_build_resource_strip(vp)

	# Две страницы разворота.
	var spine : Rect2 = _lay["spine"]
	var page  : Rect2 = _lay["page"]
	UiKit.panel(_slide_root, spine.position, spine.size, CLR_PAGE, 12, CLR_PAGE_EDGE, 2)
	UiKit.panel(_slide_root, page.position,  page.size,  CLR_PAGE, 12, CLR_PAGE_EDGE, 2)

	_overall_root = Control.new()
	_overall_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slide_root.add_child(_overall_root)

	var ch_rect : Rect2 = _lay["ch_list"]
	_spine_scroll = _make_scroll(ch_rect)
	_slide_root.add_child(_spine_scroll)
	_spine_body = Control.new()
	_spine_body.mouse_filter = Control.MOUSE_FILTER_PASS
	_spine_scroll.add_child(_spine_body)

	_page_head = Control.new()
	_page_head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slide_root.add_child(_page_head)

	var q_rect : Rect2 = _lay["q_list"]
	_page_scroll = _make_scroll(q_rect)
	_slide_root.add_child(_page_scroll)
	_page_body = Control.new()
	_page_body.mouse_filter = Control.MOUSE_FILTER_PASS
	_page_scroll.add_child(_page_body)

	# Какую главу открыть: ту, куда привёл переход по уведомлению; иначе первую
	# с готовой наградой; иначе первую незакрытую; иначе просто первую.
	_sel_chapter = _initial_chapter()
	_rebuild_content()

func _initial_chapter() -> int:
	var vis := _visible_chapters()
	if vis.is_empty():
		return -1
	if _focus_story_idx >= 0:
		var ci := _chapter_of(_focus_story_idx)
		if ci >= 0:
			return ci
	for ci in vis:
		if _chapter_has_ready(ci):
			return ci
	for ci in vis:
		if _chapter_done(ci) < _visible_quests(ci).size():
			return ci
	return int(vis[0])

func _make_scroll(rect: Rect2) -> ScrollContainer:
	var sc := ScrollContainer.new()
	sc.position               = rect.position
	sc.size                   = rect.size
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.vertical_scroll_mode   = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	sc.mouse_filter           = Control.MOUSE_FILTER_PASS
	# scroll_deadzone > 0 позволяет контейнеру отобрать касание у кнопки, когда
	# палец уехал дальше порога: иначе на телефоне список не листается — каждый
	# тап сначала попадает в строку.
	sc.set("scroll_deadzone", 18)
	return sc

func _rebuild_content() -> void:
	if not is_instance_valid(_slide_root):
		return
	var vis := _visible_chapters()
	if not vis.has(_sel_chapter):
		_sel_chapter = _initial_chapter()
	_build_overall()
	_build_spine(vis)
	_build_page()

# ── Корешок: общий прогресс ──────────────────────────────────────────────────
func _build_overall() -> void:
	for c in _overall_root.get_children():
		c.queue_free()
	var r : Rect2 = _lay["overall"]
	var pr := _overall_progress()

	var cap := Label.new()
	cap.add_theme_font_override("font", UI_FONT)
	cap.add_theme_font_size_override("font_size", 12)
	_apply_text_fx(cap)
	cap.text               = "ПРОЙДЕНО %d / %d" % [pr.x, pr.y]
	cap.modulate           = CLR_GOLD
	cap.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cap.size               = Vector2(r.size.x, 16.0)
	cap.position           = r.position
	cap.mouse_filter       = Control.MOUSE_FILTER_IGNORE
	_overall_root.add_child(cap)

	_bar(_overall_root, r.position + Vector2(0.0, 20.0), r.size.x, 12.0,
		float(pr.x) / maxf(1.0, float(pr.y)), CLR_ACCENT)

# Полоса прогресса: тёмный жёлоб + заливка. Общий кирпич экранов.
func _bar(root: Node, pos: Vector2, w: float, h: float, frac: float, col: Color) -> void:
	var trough := Panel.new()
	trough.add_theme_stylebox_override("panel", UiKit.rounded(
		Color(0.04, 0.03, 0.02, 0.95), 6, Color(0.30, 0.26, 0.18, 0.9), 1))
	trough.size         = Vector2(w, h)
	trough.position     = pos
	trough.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(trough)
	var f : float = clampf(frac, 0.0, 1.0)
	if f > 0.0:
		var fill := Panel.new()
		fill.add_theme_stylebox_override("panel", UiKit.rounded(col, 6))
		fill.size         = Vector2(maxf(4.0, (w - 4.0) * f), h - 4.0)
		fill.position     = pos + Vector2(2.0, 2.0)
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(fill)

# ── Корешок: список глав ─────────────────────────────────────────────────────
func _build_spine(vis: Array) -> void:
	for c in _spine_body.get_children():
		c.queue_free()
	var rect : Rect2 = _lay["ch_list"]
	var w : float = rect.size.x
	# Главы растягиваются на высоту корешка: пять глав не должны оставлять под
	# собой пустую половину панели, шесть — не должны вылезать за неё.
	var n : int = maxi(1, vis.size())
	var row_h : float = maxf(CH_ROW_H_MIN,
		minf(CH_ROW_H_MAX, (rect.size.y - CH_ROW_GAP * float(n - 1)) / float(n)))
	var y := 0.0
	for ci in vis:
		_build_chapter_row(Vector2(0.0, y), Vector2(w, row_h), int(ci))
		y += row_h + CH_ROW_GAP
	_spine_body.custom_minimum_size = Vector2(w, maxf(0.0, y - CH_ROW_GAP))

func _build_chapter_row(pos: Vector2, size: Vector2, ch_idx: int) -> void:
	var chapter := QuestManager.CHAPTERS[ch_idx] as Dictionary
	var qs      := _visible_quests(ch_idx)
	var done    := _chapter_done(ch_idx)
	var sel     : bool = ch_idx == _sel_chapter
	var ready   : bool = _chapter_has_ready(ch_idx)
	var full    : bool = done >= qs.size()

	var fill   : Color = CLR_ROW_SEL if sel else CLR_ROW
	var border : Color = CLR_ACCENT if sel else CLR_ROW_EDGE
	var bg := Panel.new()
	bg.add_theme_stylebox_override("panel", UiKit.rounded(fill, 10, border, 2))
	bg.size         = size
	bg.position     = pos
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_spine_body.add_child(bg)

	# Медальон с номером главы — номер и есть её имя в разговоре игроков.
	var num_col : Color = CLR_ACCENT if (sel or full) else Color(0.55, 0.47, 0.30, 0.95)
	var disc := Panel.new()
	disc.add_theme_stylebox_override("panel", UiKit.rounded(
		Color(num_col.r * 0.30, num_col.g * 0.30, num_col.b * 0.30, 0.98), 11, num_col, 2))
	disc.size         = Vector2(22.0, 22.0)
	disc.position     = pos + Vector2(8.0, (size.y - 22.0) * 0.5)
	disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_spine_body.add_child(disc)

	var num := Label.new()
	num.add_theme_font_override("font", UI_FONT)
	num.add_theme_font_size_override("font_size", 13)
	_apply_text_fx(num)
	num.text                 = str(ch_idx + 1)
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	num.size                 = disc.size
	num.position             = disc.position
	num.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	_spine_body.add_child(num)

	var title := Label.new()
	title.add_theme_font_override("font", UI_FONT)
	title.add_theme_font_size_override("font_size", 11)
	_apply_text_fx(title)
	title.text                    = _chapter_short(chapter["title"] as String)
	title.modulate                = CLR_TEXT if sel else CLR_TEXT_DIM
	title.vertical_alignment      = VERTICAL_ALIGNMENT_CENTER
	title.text_overrun_behavior   = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.size                    = Vector2(size.x - 38.0 - 20.0, size.y - 20.0)
	title.position                = pos + Vector2(38.0, 3.0)
	title.mouse_filter            = Control.MOUSE_FILTER_IGNORE
	_spine_body.add_child(title)

	var bar_w : float = size.x - 38.0 - 40.0
	_bar(_spine_body, pos + Vector2(38.0, size.y - 15.0), bar_w, 9.0,
		float(done) / maxf(1.0, float(qs.size())),
		Color(0.45, 0.80, 0.35) if full else CLR_ACCENT)

	var cnt := Label.new()
	cnt.add_theme_font_override("font", UI_FONT)
	cnt.add_theme_font_size_override("font_size", 10)
	_apply_text_fx(cnt)
	cnt.text                 = "%d/%d" % [done, qs.size()]
	cnt.modulate             = Color(0.60, 0.90, 0.45) if full else CLR_TEXT_DIM
	cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cnt.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	cnt.size                 = Vector2(34.0, 12.0)
	cnt.position             = pos + Vector2(size.x - 38.0, size.y - 16.0)
	cnt.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	_spine_body.add_child(cnt)

	# Золотая точка — «в этой главе есть что забрать». Единственный способ
	# увидеть готовую награду, не открывая главу.
	if ready:
		var dot := Panel.new()
		dot.add_theme_stylebox_override("panel", UiKit.rounded(CLR_GOLD, 6))
		dot.size         = Vector2(12.0, 12.0)
		dot.position     = pos + Vector2(size.x - 20.0, 6.0)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_spine_body.add_child(dot)
		_pulse_forever(dot)

	var btn := Button.new()
	btn.flat       = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.size       = size
	btn.position   = pos
	btn.pressed.connect(_on_select_chapter.bind(ch_idx))
	_spine_body.add_child(btn)

func _on_select_chapter(ch_idx: int) -> void:
	if ch_idx == _sel_chapter:
		return
	_sel_chapter = ch_idx
	# Подсветка от уведомления живёт ровно до первого ручного переключения.
	_focus_story_idx = -1
	if _hud and _hud.has_method("_play_btn_sfx"):
		_hud._play_btn_sfx()
	_rebuild_content()

# ── Страница главы ───────────────────────────────────────────────────────────
func _build_page() -> void:
	for c in _page_head.get_children():
		c.queue_free()
	for c in _page_body.get_children():
		c.queue_free()
	if _sel_chapter < 0:
		return

	var head : Rect2 = _lay["page_head"]
	var chapter := QuestManager.CHAPTERS[_sel_chapter] as Dictionary
	var qs := _visible_quests(_sel_chapter)

	var title := Label.new()
	title.add_theme_font_override("font", UI_FONT)
	title.add_theme_font_size_override("font_size", 15)
	_apply_text_fx(title)
	title.text               = (chapter["title"] as String).to_upper()
	title.modulate           = CLR_GOLD
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.size               = Vector2(head.size.x - 70.0, head.size.y)
	title.position           = head.position
	title.mouse_filter       = Control.MOUSE_FILTER_IGNORE
	_page_head.add_child(title)

	var done := _chapter_done(_sel_chapter)
	var cnt := Label.new()
	cnt.add_theme_font_override("font", UI_FONT)
	cnt.add_theme_font_size_override("font_size", 13)
	_apply_text_fx(cnt)
	cnt.text                 = "%d / %d" % [done, qs.size()]
	cnt.modulate             = Color(0.60, 0.90, 0.45) if done >= qs.size() else CLR_TEXT_DIM
	cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cnt.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	cnt.size                 = head.size
	cnt.position             = head.position
	cnt.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	_page_head.add_child(cnt)

	var rule := ColorRect.new()
	rule.color        = Color(0.40, 0.32, 0.16, 0.55)
	rule.size         = Vector2(head.size.x, 1.0)
	rule.position     = head.position + Vector2(0.0, head.size.y + 3.0)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page_head.add_child(rule)

	# Строки делят высоту страницы поровну — так глава из двух заданий не
	# выглядит обрезанной, а из четырёх помещается без скролла.
	var list : Rect2 = _lay["q_list"]
	var n : int = maxi(1, qs.size())
	var row_h : float = minf(Q_ROW_H_MAX,
		(list.size.y - Q_ROW_GAP * float(n - 1)) / float(n))
	var y := 0.0
	for qi in qs:
		_build_quest_row(Vector2(0.0, y), Vector2(list.size.x, row_h), int(qi))
		y += row_h + Q_ROW_GAP
	_page_body.custom_minimum_size = Vector2(list.size.x, maxf(0.0, y - Q_ROW_GAP))

func _build_quest_row(pos: Vector2, size: Vector2, idx: int) -> void:
	var q_def   := QuestManager.STORY_QUESTS[idx] as Dictionary
	var done    : bool = bool(QuestManager.story_completed[idx])
	var claimed : bool = bool(QuestManager.story_claimed[idx])
	var ready   : bool = done and not claimed
	var focused : bool = idx == _focus_story_idx
	var dim     : float = DIM_CLAIMED if claimed else 1.0

	var fill   : Color = CLR_ROW_READY if ready else (CLR_ROW_DONE if claimed else CLR_ROW)
	var border : Color = CLR_READY_EDGE if ready else CLR_ROW_EDGE
	if focused and not ready:
		border = CLR_ACCENT
	var bg := Panel.new()
	bg.add_theme_stylebox_override("panel", UiKit.rounded(fill, 12, border, 2))
	bg.size         = size
	bg.position     = pos
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page_body.add_child(bg)
	if ready:
		_pulse_forever(bg)

	_build_state_badge(pos + Vector2(12.0, (size.y - BADGE_SZ) * 0.5), done, claimed)

	var status_x : float = size.x - 12.0 - STATUS_W
	var rwd_x    : float = status_x - 10.0 - RWD_W
	var text_x   : float = 12.0 + BADGE_SZ + 10.0
	var text_w   : float = maxf(60.0, rwd_x - 8.0 - text_x)

	var title := Label.new()
	title.add_theme_font_override("font", UI_FONT)
	title.add_theme_font_size_override("font_size", 16)
	_apply_text_fx(title)
	title.text                  = q_def.get("title", "") as String
	title.modulate              = Color(CLR_TEXT.r, CLR_TEXT.g, CLR_TEXT.b, dim)
	title.vertical_alignment    = VERTICAL_ALIGNMENT_BOTTOM
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.size                  = Vector2(text_w, size.y * 0.5 - 2.0)
	title.position              = pos + Vector2(text_x, 4.0)
	title.mouse_filter          = Control.MOUSE_FILTER_IGNORE
	_page_body.add_child(title)

	var desc := Label.new()
	desc.add_theme_font_override("font", UI_FONT)
	desc.add_theme_font_size_override("font_size", 12)
	_apply_text_fx(desc)
	desc.text                  = q_def.get("desc", "") as String
	desc.modulate              = Color(CLR_TEXT_DIM.r, CLR_TEXT_DIM.g, CLR_TEXT_DIM.b, dim)
	desc.vertical_alignment    = VERTICAL_ALIGNMENT_TOP
	desc.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	desc.size                  = Vector2(text_w, size.y * 0.5 - 6.0)
	desc.position              = pos + Vector2(text_x, size.y * 0.5 + 2.0)
	desc.mouse_filter          = Control.MOUSE_FILTER_IGNORE
	_page_body.add_child(desc)

	_build_reward(pos + Vector2(rwd_x, 0.0), Vector2(RWD_W, size.y), q_def, dim)

	var st_pos  := pos + Vector2(status_x, 0.0)
	var st_size := Vector2(STATUS_W, size.y)
	if ready:
		var btn_h : float = minf(34.0, size.y - 16.0)
		_claim_button(st_pos + Vector2(0.0, (size.y - btn_h) * 0.5),
			Vector2(STATUS_W, btn_h), "ЗАБРАТЬ",
			_on_claim_story.bind(idx, st_pos + Vector2(STATUS_W, size.y) * 0.5))
	else:
		var st := Label.new()
		st.add_theme_font_override("font", UI_FONT)
		st.add_theme_font_size_override("font_size", 12)
		_apply_text_fx(st)
		st.text                 = "ЗАБРАНО" if claimed else "В ПРОЦЕССЕ"
		st.modulate             = Color(0.55, 0.80, 0.45, 0.85) if claimed \
			else Color(0.80, 0.76, 0.66, 0.95)
		st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		st.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		st.size                 = st_size
		st.position             = st_pos
		st.mouse_filter         = Control.MOUSE_FILTER_IGNORE
		_page_body.add_child(st)

# Состояние передаётся значком, а слово стоит рядом в правой колонке: цвет тут
# только усиливает.
func _build_state_badge(pos: Vector2, done: bool, claimed: bool) -> void:
	var col : Color = Color(0.50, 0.85, 0.40) if claimed \
		else (CLR_GOLD if done else Color(0.55, 0.50, 0.40))
	var ring := Panel.new()
	ring.add_theme_stylebox_override("panel", UiKit.rounded(
		Color(0.05, 0.05, 0.04, 0.85), int(BADGE_SZ * 0.5), col, 2))
	ring.size         = Vector2(BADGE_SZ, BADGE_SZ)
	ring.position     = pos
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page_body.add_child(ring)

	if claimed:
		var ck := Label.new()
		ck.add_theme_font_override("font", UI_FONT)
		ck.add_theme_font_size_override("font_size", 16)
		_apply_text_fx(ck)
		ck.text                 = "✓"
		ck.modulate             = col
		ck.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ck.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		ck.size                 = ring.size
		ck.position             = pos
		ck.mouse_filter         = Control.MOUSE_FILTER_IGNORE
		_page_body.add_child(ck)
	elif done:
		# Готово к получению — кольцо с залитой точкой внутри.
		var core := Panel.new()
		core.add_theme_stylebox_override("panel", UiKit.rounded(col, 7))
		core.size         = Vector2(14.0, 14.0)
		core.position     = pos + Vector2((BADGE_SZ - 14.0) * 0.5, (BADGE_SZ - 14.0) * 0.5)
		core.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_page_body.add_child(core)

# Награда — спрайтом: доллары мешком, жетоны жетоном. Текст «+200 $» внутри
# игрового экрана читается как заглушка.
func _build_reward(pos: Vector2, size: Vector2, q_def: Dictionary, dim: float) -> void:
	var endless : bool = bool(q_def.get("reward_endless", false))
	var d_rwd : int = int(q_def.get("reward_d", 0))
	var t_rwd : int = int(q_def.get("reward_t", 0))

	if endless:
		var lbl := Label.new()
		lbl.add_theme_font_override("font", UI_FONT)
		lbl.add_theme_font_size_override("font_size", 11)
		_apply_text_fx(lbl)
		lbl.text                 = "БЕСКОНЕЧНЫЙ\nРЕЖИМ"
		lbl.modulate             = Color(CLR_ENDLESS.r, CLR_ENDLESS.g, CLR_ENDLESS.b, dim)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		lbl.size                 = Vector2(size.x - 30.0, size.y)
		lbl.position             = pos + Vector2(30.0, 0.0)
		lbl.mouse_filter         = Control.MOUSE_FILTER_IGNORE
		_page_body.add_child(lbl)
		_draw_endless_icon(_page_body, pos + Vector2(2.0, (size.y - 24.0) * 0.5), 24.0,
			Color(CLR_ENDLESS.r, CLR_ENDLESS.g, CLR_ENDLESS.b, dim))
		return

	# Пары «иконка + число» выкладываются в ряд по центру колонки.
	var pairs : Array = []
	if d_rwd > 0:
		pairs.append([TEX_DOLLAR, str(d_rwd)])
	if t_rwd > 0:
		pairs.append([TEX_TOKEN, str(t_rwd)])
	if pairs.is_empty():
		return

	const ICON := 20.0
	const GAP  := 4.0
	const PAIR_GAP := 12.0
	var widths : Array = []
	var total := 0.0
	for p in pairs:
		var tw : float = UI_FONT.get_string_size(String(p[1]),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		widths.append(tw)
		total += ICON + GAP + tw
	total += PAIR_GAP * float(pairs.size() - 1)

	var x : float = pos.x + (size.x - total) * 0.5
	var cy : float = pos.y + size.y * 0.5
	for i in pairs.size():
		var ico := _make_icon(pairs[i][0], ICON)
		ico.position = Vector2(x, cy - ICON * 0.5)
		ico.modulate = Color(1, 1, 1, dim)
		_page_body.add_child(ico)
		var num := Label.new()
		num.add_theme_font_override("font", UI_FONT)
		num.add_theme_font_size_override("font_size", 14)
		_apply_text_fx(num)
		num.text               = String(pairs[i][1])
		num.modulate           = Color(CLR_GOLD.r, CLR_GOLD.g, CLR_GOLD.b, dim)
		num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		num.size               = Vector2(float(widths[i]) + 4.0, ICON + 4.0)
		num.position           = Vector2(x + ICON + GAP, cy - ICON * 0.5 - 2.0)
		num.mouse_filter       = Control.MOUSE_FILTER_IGNORE
		_page_body.add_child(num)
		x += ICON + GAP + float(widths[i]) + PAIR_GAP

# Кнопка действия: панель + подпись + невидимый Button с усадкой при нажатии.
func _claim_button(pos: Vector2, size: Vector2, text: String, action: Callable) -> void:
	var visual := Control.new()
	visual.size         = size
	visual.position     = pos
	visual.pivot_offset = size * 0.5
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page_body.add_child(visual)

	var bg := Panel.new()
	bg.add_theme_stylebox_override("panel", UiKit.rounded(
		Color(0.22, 0.52, 0.14, 0.98), 8, Color(0.65, 1.0, 0.45, 0.95)))
	bg.size         = size
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	visual.add_child(bg)

	var lbl := Label.new()
	lbl.add_theme_font_override("font", UI_FONT)
	lbl.add_theme_font_size_override("font_size", 14)
	_apply_text_fx(lbl)
	lbl.text                 = text
	lbl.modulate             = Color(0.92, 1.0, 0.80)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl.size                 = size
	lbl.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	visual.add_child(lbl)

	var btn := Button.new()
	btn.flat       = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.size       = size
	btn.position   = pos
	btn.pressed.connect(action)
	btn.button_down.connect(_press_anim.bind(visual, true))
	btn.button_up.connect(_press_anim.bind(visual, false))
	btn.mouse_exited.connect(_press_anim.bind(visual, false))
	_page_body.add_child(btn)

# Пульсирует ровно то, к чему игрок должен подойти: готовая строка и золотая
# точка на её главе.
func _pulse_forever(node: Control) -> void:
	node.pivot_offset = node.size * 0.5
	var tw := node.create_tween().set_loops()
	tw.tween_property(node, "modulate:a", 0.72, 0.55).set_trans(Tween.TRANS_SINE)
	tw.tween_property(node, "modulate:a", 1.0, 0.55).set_trans(Tween.TRANS_SINE)

# ── Шапка ────────────────────────────────────────────────────────────────────
func _build_back_button(sx: float, sy: float) -> void:
	var back_size := Vector2(BACK_BTN_SIZE.x * sx, BACK_BTN_SIZE.y * sy)
	var back_visual := Control.new()
	back_visual.size         = back_size
	back_visual.position     = Vector2(BACK_BTN_POS.x * sx, BACK_BTN_POS.y * sy)
	back_visual.pivot_offset = back_size * 0.5
	back_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slide_root.add_child(back_visual)

	var back_icon := TextureRect.new()
	back_icon.texture             = TEX_BACK_ARROW
	back_icon.stretch_mode        = TextureRect.STRETCH_SCALE
	back_icon.expand_mode         = TextureRect.EXPAND_IGNORE_SIZE
	back_icon.custom_minimum_size = Vector2.ZERO
	back_icon.size                = back_size
	back_icon.position            = Vector2.ZERO
	back_icon.texture_filter      = CanvasItem.TEXTURE_FILTER_NEAREST
	back_icon.mouse_filter        = Control.MOUSE_FILTER_IGNORE
	back_visual.add_child(back_icon)

	var back_btn := Button.new()
	back_btn.flat       = true
	back_btn.focus_mode = Control.FOCUS_NONE
	back_btn.size       = back_size + Vector2(14.0, 14.0)
	back_btn.position   = back_visual.position - Vector2(7.0, 7.0)
	back_btn.pressed.connect(_on_close)
	back_btn.button_down.connect(_press_anim.bind(back_visual, true))
	back_btn.button_up.connect(_press_anim.bind(back_visual, false))
	back_btn.mouse_exited.connect(_press_anim.bind(back_visual, false))
	_slide_root.add_child(back_btn)

func _build_resource_strip(vp: Vector2) -> void:
	# Ресурсы справа сверху — та же раскладка, что на экранах заданий и лидеров.
	var sx : float = vp.x / CANVAS_W
	var sy : float = vp.y / CANVAS_H

	var icon_sz : float = RES_ICON_SZ * sy
	var num_w   : float = RES_NUM_W * sx
	var gap     : float = RES_GAP * sx
	var pair_w  : float = icon_sz + 2.0 + num_w
	var total_w : float = pair_w * 2.0 + gap
	var right_x : float = vp.x - RES_RIGHT_PAD * sx
	var start_x : float = right_x - total_w
	var top_y   : float = RES_Y * sy

	var dol_x : float = start_x
	var dol_icon := _make_icon(TEX_DOLLAR, icon_sz)
	dol_icon.position = Vector2(dol_x, top_y)
	_slide_root.add_child(dol_icon)
	_dollar_lbl = Label.new()
	_dollar_lbl.add_theme_font_override("font", UI_FONT)
	_dollar_lbl.add_theme_font_size_override("font_size", RES_FONT_SZ)
	_apply_text_fx(_dollar_lbl)
	_dollar_lbl.text                 = str(SaveData.dollars)
	_dollar_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_dollar_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_dollar_lbl.size                 = Vector2(num_w, icon_sz + 4.0)
	_dollar_lbl.position             = Vector2(dol_x + icon_sz + 2.0, top_y - 2.0)
	_slide_root.add_child(_dollar_lbl)
	_dollar_target = Vector2(dol_x + icon_sz * 0.5, top_y + icon_sz * 0.5)

	var tkn_x : float = dol_x + pair_w + gap
	var tkn_icon := _make_icon(TEX_TOKEN, icon_sz)
	tkn_icon.position = Vector2(tkn_x, top_y)
	_slide_root.add_child(tkn_icon)
	_token_lbl = Label.new()
	_token_lbl.add_theme_font_override("font", UI_FONT)
	_token_lbl.add_theme_font_size_override("font_size", RES_FONT_SZ)
	_apply_text_fx(_token_lbl)
	_token_lbl.text                 = str(SaveData.tokens)
	_token_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_token_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_token_lbl.size                 = Vector2(num_w, icon_sz + 4.0)
	_token_lbl.position             = Vector2(tkn_x + icon_sz + 2.0, top_y - 2.0)
	_slide_root.add_child(_token_lbl)
	_token_target = Vector2(tkn_x + icon_sz * 0.5, top_y + icon_sz * 0.5)

# Russo One — чёрная обводка и мягкая тень, как в меню и на заданиях.
func _apply_text_fx(lbl: Label) -> void:
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.65))
	lbl.add_theme_constant_override("outline_size", 2)
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.80))
	lbl.add_theme_constant_override("shadow_offset_x", 0)
	lbl.add_theme_constant_override("shadow_offset_y", 0)
	lbl.add_theme_constant_override("shadow_outline_size", 3)

# Усадка при нажатии — один тайминг на всю игру.
func _press_anim(visual_root: Control, pressed: bool) -> void:
	UiKit.press_anim(visual_root, pressed)

# ── Значок бесконечности ─────────────────────────────────────────────────────
func _draw_endless_icon(parent: Node, pos: Vector2, sz: float, col: Color) -> Node2D:
	var root := Node2D.new()
	root.position = pos
	parent.add_child(root)
	var ring_sz   := sz * 0.62
	var ring_thk  := maxf(2.0, sz * 0.12)
	var overlap   := ring_sz * 0.32
	var ring_y    := (sz - ring_sz) * 0.5
	var l_x       := 0.0
	var r_x       := ring_sz - overlap
	_draw_square_ring(root, Vector2(l_x, ring_y), ring_sz, ring_thk, col)
	_draw_square_ring(root, Vector2(r_x, ring_y), ring_sz, ring_thk, col)
	var dot := ColorRect.new()
	dot.color    = col
	dot.size     = Vector2(ring_thk, ring_thk)
	dot.position = Vector2(r_x + (overlap - ring_thk) * 0.5, ring_y + (ring_sz - ring_thk) * 0.5)
	root.add_child(dot)
	return root

func _draw_square_ring(parent: Node, pos: Vector2, sz: float, thk: float, col: Color) -> void:
	var top := ColorRect.new()
	top.color    = col
	top.size     = Vector2(sz, thk)
	top.position = pos
	parent.add_child(top)
	var bot := ColorRect.new()
	bot.color    = col
	bot.size     = Vector2(sz, thk)
	bot.position = pos + Vector2(0.0, sz - thk)
	parent.add_child(bot)
	var lf := ColorRect.new()
	lf.color    = col
	lf.size     = Vector2(thk, sz)
	lf.position = pos
	parent.add_child(lf)
	var rt := ColorRect.new()
	rt.color    = col
	rt.size     = Vector2(thk, sz)
	rt.position = pos + Vector2(sz - thk, 0.0)
	parent.add_child(rt)

func _make_icon(tex: Texture2D, sz: float) -> TextureRect:
	var r := TextureRect.new()
	r.texture      = tex
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
	r.size         = Vector2(sz, sz)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

# ── Получение награды ────────────────────────────────────────────────────────
func _on_claim_story(idx: int, src_content: Vector2) -> void:
	if _claim_busy:
		return
	_claim_busy = true
	if _hud and _hud.has_method("_play_btn_sfx"):
		_hud._play_btn_sfx()
	var q_def := QuestManager.STORY_QUESTS[idx] as Dictionary
	var d     := int(q_def.get("reward_d", 0))
	var t     := int(q_def.get("reward_t", 0))
	var endless_rwd := bool(q_def.get("reward_endless", false))
	# Координаты строки живут внутри скролла — переводим их в экранные.
	var src_screen := src_content + _page_scroll.position \
		- Vector2(_page_scroll.scroll_horizontal, _page_scroll.scroll_vertical)
	if d > 0:
		_fly_icons_to(TEX_DOLLAR, src_screen, _dollar_target, 5, Color.WHITE)
	if t > 0:
		_fly_icons_to(TEX_TOKEN, src_screen, _token_target,
			mini(maxi(t, 1), 4), Color.WHITE)
	if endless_rwd:
		_celebrate_endless_unlock(src_screen)
	# Само начисление откладываем, чтобы счётчик щёлкнул по прилёту иконок.
	get_tree().create_timer(0.45).timeout.connect(func():
		QuestManager.claim_story(idx)
		_claim_busy = false
	)

func _celebrate_endless_unlock(src: Vector2) -> void:
	var col       := CLR_ENDLESS
	var icon_sz   := 64.0
	var vp        := get_viewport().get_visible_rect().size
	var target    := Vector2(vp.x * 0.5 - icon_sz * 0.5, vp.y * 0.32 - icon_sz * 0.5)
	var icon_root := _draw_endless_icon(_slide_root,
		src - Vector2(icon_sz * 0.5, icon_sz * 0.5), icon_sz, col)
	icon_root.z_index = 30
	var tw := icon_root.create_tween().set_parallel(true)
	tw.tween_property(icon_root, "position", target, 0.50) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.chain().tween_interval(0.55)
	tw.chain().tween_property(icon_root, "modulate:a", 0.0, 0.35)
	tw.chain().tween_callback(icon_root.queue_free)

	var lbl := Label.new()
	lbl.add_theme_font_override("font", UI_FONT)
	lbl.add_theme_font_size_override("font_size", 16)
	_apply_text_fx(lbl)
	lbl.text                 = "БЕСКОНЕЧНЫЙ ОТКРЫТ"
	lbl.modulate             = Color(0.75, 0.95, 1.0)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl.size                 = Vector2(vp.x, 28.0)
	lbl.position             = Vector2(0.0, vp.y * 0.32 + icon_sz * 2.0)
	lbl.modulate.a           = 0.0
	lbl.z_index              = 30
	lbl.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	_slide_root.add_child(lbl)
	var tw2 := lbl.create_tween()
	tw2.tween_interval(0.30)
	tw2.tween_property(lbl, "modulate:a", 1.0, 0.25)
	tw2.tween_interval(0.85)
	tw2.tween_property(lbl, "modulate:a", 0.0, 0.30)
	tw2.tween_callback(lbl.queue_free)

func _fly_icons_to(tex: Texture2D, from: Vector2, to: Vector2, count: int, tint: Color) -> void:
	for i in count:
		var ico       := _make_icon(tex, 16.0)
		ico.modulate   = tint
		ico.position   = from + Vector2(randf_range(-14.0, 14.0), randf_range(-8.0, 8.0))
		ico.z_index    = 30
		_slide_root.add_child(ico)
		var tw := ico.create_tween()
		tw.tween_interval(float(i) * 0.07)
		tw.tween_property(ico, "position", to, 0.40) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(ico, "modulate:a", 0.0, 0.16).set_delay(0.30)
		tw.tween_callback(ico.queue_free)

# ── Реакция на данные ────────────────────────────────────────────────────────
func _on_quests_updated() -> void:
	_rebuild_content()

func _on_data_changed() -> void:
	if is_instance_valid(_dollar_lbl):
		_pulse_label(_dollar_lbl, str(SaveData.dollars))
	if is_instance_valid(_token_lbl):
		_pulse_label(_token_lbl, str(SaveData.tokens))

func _pulse_label(lbl: Label, new_text: String) -> void:
	if lbl.text == new_text:
		return
	lbl.text = new_text
	var tw := lbl.create_tween()
	tw.tween_property(lbl, "scale", Vector2(1.18, 1.18), 0.08)
	tw.tween_property(lbl, "scale", Vector2.ONE, 0.16) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_close() -> void:
	if not is_instance_valid(_slide_root):
		queue_free()
		return
	# Обратный проезд камеры: книга уезжает вниз, меню возвращается.
	var vp := get_viewport().get_visible_rect().size
	var tw := create_tween()
	tw.tween_property(_slide_root, "position", Vector2(0.0, vp.y), SLIDE_TIME)\
		.set_trans(SLIDE_TRANS).set_ease(SLIDE_EASE_OUT)
	tw.tween_callback(Callable(self, "queue_free"))
	if _hud != null and _hud.has_method("_on_book_close_anim_start"):
		_hud._on_book_close_anim_start(SLIDE_TIME, SLIDE_TRANS, SLIDE_EASE_OUT)
