extends Node2D
class_name SettingsScreen

# ─── Настройки ────────────────────────────────────────────────────────────────
# Разворот, как в книге учителя: разделы в корешке слева, содержимое выбранного
# справа. До переделки это была стопка модалок, где подэкран ЗАМЕНЯЛ родителя:
# закрыл уведомления — оказался в главном меню, а не обратно в настройках, и
# кнопки «назад» не было ни одной. Подэкранов больше нет, а значит нет и
# проблемы.
#
# Настоящими диалогами остались только «изменить имя» и «восстановить аккаунт»
# — операции с подтверждением. Они открываются поверх экрана и возвращают в
# него.
#
# См. /Концепция/Экран настроек.md

# Общий выключатель dev-строк — как в hud.gd и на экране лидеров.
const DevFlags = preload("res://scripts/dev_flags.gd")

const UI_FONT        := preload("res://assets/fonts/RussoOne-Regular.ttf")
const TEX_DOLLAR     := preload("res://assets/items/dollar.png")
const TEX_TOKEN      := preload("res://assets/items/token.png")
const TEX_BACK_ARROW := preload("res://assets/ui/quests/back_arrow.png")

const CLR_PAGE      := Color(0.07, 0.07, 0.10, 0.95)
const CLR_PAGE_EDGE := Color(0.42, 0.48, 0.62, 0.85)
const CLR_ROW       := Color(0.11, 0.11, 0.15, 0.95)
const CLR_ROW_EDGE  := Color(0.26, 0.27, 0.34, 0.85)
const CLR_ROW_SEL   := Color(0.16, 0.20, 0.30, 0.98)
const CLR_ACCENT    := Color(0.55, 0.85, 1.00, 0.95)
const CLR_GOLD      := Color(1.00, 0.85, 0.35)
const CLR_TEXT      := Color(0.96, 0.97, 1.00)
const CLR_TEXT_DIM  := Color(0.84, 0.86, 0.90)
const CLR_ON        := Color(0.30, 0.72, 0.32, 0.98)
const CLR_OFF       := Color(0.16, 0.16, 0.20, 0.95)

# ── Раскладка (канвас 430×192, как на остальных экранах) ─────────────────────
const CANVAS_W : float = 430.0
const CANVAS_H : float = 192.0
const BACK_BTN_POS   : Vector2 = Vector2(10.0, 6.0)
const BACK_BTN_SIZE  : Vector2 = Vector2(24.0, 15.0)
const TITLE_X_OFFSET : float   = -30.0
const TITLE_Y        : float   = 6.0
const TITLE_H        : float   = 20.0
const TITLE_FONT_SZ  : int     = 16
const RES_RIGHT_PAD  : float   = -10.0
const RES_Y          : float   = 7.0
const RES_ICON_SZ    : float   = 16.0
const RES_GAP        : float   = 2.0
const RES_NUM_W      : float   = 36.0
const RES_FONT_SZ    : int     = 14
const SPINE_X  : float = 12.0
const SPINE_W  : float = 118.0
const PAGE_X   : float = 136.0
const PAGE_W   : float = 282.0
const SPREAD_Y : float = 34.0
const SPREAD_H : float = 150.0
const SLIDE_TIME     : float = 0.45
const SLIDE_TRANS    : int   = Tween.TRANS_QUAD
const SLIDE_EASE_IN  : int   = Tween.EASE_IN
const SLIDE_EASE_OUT : int   = Tween.EASE_IN

const PAD          : float = 10.0
const SEC_ROW_H    : float = 34.0
const SEC_ROW_GAP  : float = 6.0
const TOGGLE_W     : float = 74.0
const TOGGLE_H     : float = 24.0

# Разделы. Порядок — по частоте: убавить звук заходят чаще всего.
const SECTIONS : Array = [
	{ "key": "sound",  "title": "ЗВУК" },
	{ "key": "notif",  "title": "УВЕДОМЛЕНИЯ" },
	{ "key": "profile","title": "ПРОФИЛЬ" },
	{ "key": "account","title": "АККАУНТ" },
]

# Категории уведомлений — подписи те же, что были в старой модалке.
const CAT_ROWS : Array = [
	["A", "Возвращение в игру"],
	["B", "Ежедневные напоминания"],
	["C", "Прогресс скина"],
	["D", "Бесплатный спин в автомате"],
	["E", "Сюжет и босс"],
	["F", "Серверные награды"],
	["G", "Таблица лидеров"],
	["H", "События и новый контент"],
]

var _hud         : Node = null
var _slide_root  : Control = null
var _spine_body  : Control = null
var _page_scroll : ScrollContainer = null
var _page_body   : Control = null
var _page_head   : Control = null
var _dollar_lbl  : Label = null
var _token_lbl   : Label = null
var _lay         : Dictionary = {}
var _sel         : String = "sound"

func setup(hud: Node, section: String = "sound") -> void:
	_hud = hud
	_sel = section

func _ready() -> void:
	var vp := get_viewport().get_visible_rect().size
	_build(vp)
	_slide_root.position = Vector2(0.0, vp.y)
	var tw := create_tween()
	tw.tween_property(_slide_root, "position", Vector2.ZERO, SLIDE_TIME)\
		.set_trans(SLIDE_TRANS).set_ease(SLIDE_EASE_IN)
	if _hud != null and _hud.has_method("_on_settings_open_anim_start"):
		_hud._on_settings_open_anim_start(SLIDE_TIME, SLIDE_TRANS, SLIDE_EASE_IN)
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
		"sec_list": Rect2(spine.position.x + PAD, spine.position.y + PAD,
			spine.size.x - PAD * 2.0, spine.size.y - PAD * 2.0 - 18.0),
		"page_head": Rect2(page.position.x + PAD + 4.0, page.position.y + PAD,
			page.size.x - (PAD + 4.0) * 2.0, 26.0),
		"body": Rect2(page.position.x + PAD + 4.0, page.position.y + PAD + 34.0,
			page.size.x - (PAD + 4.0) * 2.0, page.size.y - PAD * 2.0 - 34.0),
	}

# ── Сборка ───────────────────────────────────────────────────────────────────
func _build(vp: Vector2) -> void:
	_lay = _layout(vp)
	var sx : float = _lay["sx"]
	var sy : float = _lay["sy"]

	_slide_root = Control.new()
	_slide_root.size         = vp
	_slide_root.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_slide_root)

	# Затемнение вместо своего фона: настройки открываются поверх меню, и
	# отдельная картинка тут только оторвала бы экран от того, откуда пришли.
	var dim := ColorRect.new()
	dim.color        = Color(0.02, 0.02, 0.04, 0.88)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.place(_slide_root, dim, Vector2.ZERO, vp)

	_build_back_button(sx, sy)

	var title := Label.new()
	title.add_theme_font_override("font", UI_FONT)
	title.add_theme_font_size_override("font_size", TITLE_FONT_SZ)
	_apply_text_fx(title)
	title.text                 = "НАСТРОЙКИ"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	title.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	UiKit.place(_slide_root, title, Vector2(TITLE_X_OFFSET * sx, TITLE_Y * sy),
		Vector2(vp.x, TITLE_H * sy))

	_build_resource_strip(vp)

	var spine : Rect2 = _lay["spine"]
	var page  : Rect2 = _lay["page"]
	UiKit.panel(_slide_root, spine.position, spine.size, CLR_PAGE, 12, CLR_PAGE_EDGE, 2)
	UiKit.panel(_slide_root, page.position,  page.size,  CLR_PAGE, 12, CLR_PAGE_EDGE, 2)

	_spine_body = Control.new()
	_spine_body.mouse_filter = Control.MOUSE_FILTER_PASS
	UiKit.place(_slide_root, _spine_body, _lay["sec_list"].position, _lay["sec_list"].size)

	# Версия — внизу корешка. Она нужна раз в жизни, при письме в поддержку, и
	# не должна занимать место в содержимом.
	var ver := str(ProjectSettings.get_setting("application/config/version", ""))
	var ver_lbl := Label.new()
	ver_lbl.add_theme_font_override("font", UI_FONT)
	ver_lbl.add_theme_font_size_override("font_size", 9)
	ver_lbl.text                 = "v%s" % (ver if ver != "" else "—")
	ver_lbl.modulate             = Color(0.55, 0.57, 0.62, 0.85)
	ver_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ver_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	ver_lbl.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	UiKit.place(_slide_root, ver_lbl,
		Vector2(spine.position.x, spine.position.y + spine.size.y - 18.0),
		Vector2(spine.size.x, 14.0))

	_page_head = Control.new()
	_page_head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.place(_slide_root, _page_head, Vector2.ZERO, Vector2.ZERO)

	var body : Rect2 = _lay["body"]
	_page_scroll = ScrollContainer.new()
	_page_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_page_scroll.vertical_scroll_mode   = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_page_scroll.mouse_filter           = Control.MOUSE_FILTER_PASS
	# scroll_deadzone > 0 — иначе на телефоне список категорий не листается:
	# каждый тап сначала попадает в строку переключателя.
	_page_scroll.set("scroll_deadzone", 18)
	UiKit.place(_slide_root, _page_scroll, body.position, body.size)
	_page_body = Control.new()
	_page_body.mouse_filter = Control.MOUSE_FILTER_PASS
	_page_scroll.add_child(_page_body)

	_rebuild()

func _rebuild() -> void:
	_build_spine()
	_build_page()

# ── Корешок: список разделов ─────────────────────────────────────────────────
func _build_spine() -> void:
	for c in _spine_body.get_children():
		c.queue_free()
	var w : float = _spine_body.size.x
	var y := 0.0
	for s in SECTIONS:
		_build_section_row(Vector2(0.0, y), Vector2(w, SEC_ROW_H), s as Dictionary)
		y += SEC_ROW_H + SEC_ROW_GAP
	_spine_body.custom_minimum_size = Vector2(w, maxf(0.0, y - SEC_ROW_GAP))

func _build_section_row(pos: Vector2, size: Vector2, sec: Dictionary) -> void:
	var key : String = String(sec["key"])
	var on  : bool   = key == _sel
	var bg := Panel.new()
	bg.add_theme_stylebox_override("panel", UiKit.rounded(
		CLR_ROW_SEL if on else CLR_ROW, 10,
		CLR_ACCENT if on else CLR_ROW_EDGE, 2))
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.place(_spine_body, bg, pos, size)

	# Выбранный раздел помечен и полоской, и заливкой, и рамкой — не одним
	# лишь цветом текста.
	if on:
		var mark := Panel.new()
		mark.add_theme_stylebox_override("panel", UiKit.rounded(CLR_ACCENT, 2))
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		UiKit.place(_spine_body, mark, pos + Vector2(6.0, 8.0),
			Vector2(4.0, size.y - 16.0))

	var lbl := Label.new()
	lbl.add_theme_font_override("font", UI_FONT)
	lbl.add_theme_font_size_override("font_size", 12)
	_apply_text_fx(lbl)
	lbl.text                  = String(sec["title"])
	lbl.modulate              = CLR_TEXT if on else CLR_TEXT_DIM
	lbl.vertical_alignment    = VERTICAL_ALIGNMENT_CENTER
	lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	lbl.mouse_filter          = Control.MOUSE_FILTER_IGNORE
	UiKit.place(_spine_body, lbl, pos + Vector2(16.0, 0.0),
		Vector2(size.x - 22.0, size.y))

	var btn := Button.new()
	btn.flat       = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.pressed.connect(_on_select.bind(key))
	UiKit.place(_spine_body, btn, pos, size)

func _on_select(key: String) -> void:
	if key == _sel:
		return
	_sel = key
	if _hud and _hud.has_method("_play_btn_sfx"):
		_hud._play_btn_sfx()
	_rebuild()

# ── Страница раздела ─────────────────────────────────────────────────────────
func _build_page() -> void:
	for c in _page_head.get_children():
		c.queue_free()
	for c in _page_body.get_children():
		c.queue_free()
	_page_scroll.scroll_vertical = 0

	var head : Rect2 = _lay["page_head"]
	var title := Label.new()
	title.add_theme_font_override("font", UI_FONT)
	title.add_theme_font_size_override("font_size", 15)
	_apply_text_fx(title)
	title.text               = _section_title(_sel)
	title.modulate           = CLR_ACCENT
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.mouse_filter       = Control.MOUSE_FILTER_IGNORE
	UiKit.place(_page_head, title, head.position, head.size)

	var rule := ColorRect.new()
	rule.color        = Color(0.35, 0.40, 0.52, 0.55)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.place(_page_head, rule, head.position + Vector2(0.0, head.size.y + 3.0),
		Vector2(head.size.x, 1.0))

	var w : float = _lay["body"].size.x
	var h := 0.0
	match _sel:
		"sound":   h = _page_sound(w)
		"notif":   h = _page_notif(w)
		"profile": h = _page_profile(w)
		_:         h = _page_account(w)
	_page_body.custom_minimum_size = Vector2(w, h)

func _section_title(key: String) -> String:
	for s in SECTIONS:
		if String((s as Dictionary)["key"]) == key:
			return String((s as Dictionary)["title"])
	return ""

# ── Раздел «Звук» ────────────────────────────────────────────────────────────
func _page_sound(w: float) -> float:
	var y := 6.0
	y = _slider_row(w, y, "Громкость звуков", SaveData.sfx_volume,
		func(v: float): SaveData.set_sfx_volume(v))
	y = _slider_row(w, y, "Громкость музыки", SaveData.music_volume,
		func(v: float): SaveData.set_music_volume(v))
	return y

# Полоса громкости С ЧИСЛОМ: длина полосы отвечает «примерно столько», а игрок
# сверяет «было 70, стало 40».
func _slider_row(w: float, y: float, title: String, value: float,
		on_changed: Callable) -> float:
	var lbl := Label.new()
	lbl.add_theme_font_override("font", UI_FONT)
	lbl.add_theme_font_size_override("font_size", 12)
	_apply_text_fx(lbl)
	lbl.text               = title
	lbl.modulate           = CLR_TEXT
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter       = Control.MOUSE_FILTER_IGNORE
	UiKit.place(_page_body, lbl, Vector2(0.0, y), Vector2(w - 70.0, 18.0))

	var pct := Label.new()
	pct.add_theme_font_override("font", UI_FONT)
	pct.add_theme_font_size_override("font_size", 12)
	_apply_text_fx(pct)
	pct.text                 = "%d %%" % int(round(value * 100.0))
	pct.modulate             = CLR_ACCENT
	pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pct.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	pct.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	UiKit.place(_page_body, pct, Vector2(w - 70.0, y), Vector2(70.0, 18.0))

	var bar_y := y + 22.0
	UiKit.panel(_page_body, Vector2(0.0, bar_y), Vector2(w, 14.0),
		Color(0.04, 0.04, 0.06, 0.95), 6, Color(0.28, 0.30, 0.38, 0.9), 1)
	var fill := Panel.new()
	fill.add_theme_stylebox_override("panel", UiKit.rounded(CLR_ACCENT, 5))
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.place(_page_body, fill, Vector2(2.0, bar_y + 2.0),
		Vector2(maxf(2.0, (w - 4.0) * clampf(value, 0.0, 1.0)), 10.0))

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step      = 0.01
	slider.value     = value
	slider.focus_mode = Control.FOCUS_NONE
	# Ползунок невидим: он только ловит палец, а рисуют полосу панели выше —
	# иначе тема Godot приносит свой вид, чужой всему остальному экрану.
	slider.modulate = Color(1, 1, 1, 0)
	slider.value_changed.connect(func(v: float):
		on_changed.call(v)
		if is_instance_valid(fill):
			fill.size.x = maxf(2.0, (w - 4.0) * clampf(v, 0.0, 1.0))
		if is_instance_valid(pct):
			pct.text = "%d %%" % int(round(v * 100.0)))
	UiKit.place(_page_body, slider, Vector2(0.0, bar_y - 6.0), Vector2(w, 26.0))
	return bar_y + 14.0 + 18.0

# ── Раздел «Уведомления» ─────────────────────────────────────────────────────
func _page_notif(w: float) -> float:
	var y := 6.0
	y = _toggle_row(w, y, "Все уведомления", "_master", true)

	var hint := Label.new()
	hint.add_theme_font_override("font", UI_FONT)
	hint.add_theme_font_size_override("font_size", 9)
	hint.text          = "Если в системных настройках уведомления для Normaldo выключены — переключатели ничего не делают."
	hint.modulate      = Color(0.66, 0.68, 0.74)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	hint.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	UiKit.place(_page_body, hint, Vector2(0.0, y + 2.0), Vector2(w, 26.0))
	y += 32.0

	var cap := Label.new()
	cap.add_theme_font_override("font", UI_FONT)
	cap.add_theme_font_size_override("font_size", 11)
	_apply_text_fx(cap)
	cap.text               = "КАТЕГОРИИ"
	cap.modulate           = CLR_ACCENT
	cap.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cap.mouse_filter       = Control.MOUSE_FILTER_IGNORE
	UiKit.place(_page_body, cap, Vector2(0.0, y), Vector2(w, 16.0))
	y += 20.0

	# Общий выключатель выключен — категории гаснут и не нажимаются: щёлкать по
	# ним бессмысленно, а притворяться рабочими значит врать.
	var live : bool = bool(SaveData.notif_enabled)
	for e in CAT_ROWS:
		y = _toggle_row(w, y, String((e as Array)[1]), String((e as Array)[0]), live)

	y += 6.0
	var qcap := Label.new()
	qcap.add_theme_font_override("font", UI_FONT)
	qcap.add_theme_font_size_override("font_size", 11)
	_apply_text_fx(qcap)
	qcap.text               = "ТИХИЕ ЧАСЫ"
	qcap.modulate           = CLR_GOLD
	qcap.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	qcap.mouse_filter       = Control.MOUSE_FILTER_IGNORE
	UiKit.place(_page_body, qcap, Vector2(0.0, y), Vector2(w, 16.0))
	y += 20.0
	y = _hour_row(w, y, "Начало", "notif_quiet_start")
	y = _hour_row(w, y, "Конец",  "notif_quiet_end")

	var q := Label.new()
	q.add_theme_font_override("font", UI_FONT)
	q.add_theme_font_size_override("font_size", 9)
	q.text          = "С %02d:00 до %02d:00 пуши не приходят." % [
		int(SaveData.notif_quiet_start), int(SaveData.notif_quiet_end)]
	q.modulate      = Color(0.66, 0.68, 0.74)
	q.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	UiKit.place(_page_body, q, Vector2(0.0, y + 2.0), Vector2(w, 14.0))
	y += 22.0

	# Dev-строки проверки пушей жили в старой модалке уведомлений — переезжают
	# сюда как есть, чтобы не потерять сквозную проверку доставки.
	if DevFlags.ENABLED and _hud != null:
		_hud.call("_build_notif_test_row",   _page_body, 0.0, y, w, self)
		y += 36.0
		_hud.call("_build_notif_fire_row",   _page_body, 0.0, y, w, self)
		y += 36.0
		_hud.call("_build_notif_remote_row", _page_body, 0.0, y, w)
		y += 36.0
	return y + 6.0

# Переключатель: положение кружка, заливка И слово. Три признака на одно
# состояние, цвет из них только один.
func _toggle_row(w: float, y: float, label: String, key: String, live: bool) -> float:
	const H : float = 28.0
	var on : bool = bool(_hud.call("_notif_cat_enabled", key))
	var dim : float = 1.0 if live else 0.45

	var bg := Panel.new()
	bg.add_theme_stylebox_override("panel", UiKit.rounded(
		Color(CLR_ROW.r, CLR_ROW.g, CLR_ROW.b, CLR_ROW.a * dim), 8,
		Color(CLR_ROW_EDGE.r, CLR_ROW_EDGE.g, CLR_ROW_EDGE.b, CLR_ROW_EDGE.a * dim), 1))
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.place(_page_body, bg, Vector2(0.0, y), Vector2(w, H))

	var lbl := Label.new()
	lbl.add_theme_font_override("font", UI_FONT)
	lbl.add_theme_font_size_override("font_size", 11)
	_apply_text_fx(lbl)
	lbl.text                  = label
	lbl.modulate              = Color(CLR_TEXT.r, CLR_TEXT.g, CLR_TEXT.b,
		(1.0 if on else 0.65) * dim)
	lbl.vertical_alignment    = VERTICAL_ALIGNMENT_CENTER
	lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	lbl.mouse_filter          = Control.MOUSE_FILTER_IGNORE
	UiKit.place(_page_body, lbl, Vector2(10.0, y),
		Vector2(w - TOGGLE_W - 24.0, H))

	var tx : float = w - TOGGLE_W - 6.0
	var ty : float = y + (H - TOGGLE_H) * 0.5
	var pill := Panel.new()
	pill.add_theme_stylebox_override("panel", UiKit.rounded(
		Color(CLR_ON.r, CLR_ON.g, CLR_ON.b, CLR_ON.a * dim) if on
			else Color(CLR_OFF.r, CLR_OFF.g, CLR_OFF.b, CLR_OFF.a * dim),
		int(TOGGLE_H * 0.5),
		Color(0.60, 0.95, 0.62, 0.95 * dim) if on else Color(0.50, 0.52, 0.60, 0.85 * dim), 2))
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.place(_page_body, pill, Vector2(tx, ty), Vector2(TOGGLE_W, TOGGLE_H))

	var knob := Panel.new()
	knob.add_theme_stylebox_override("panel", UiKit.rounded(
		Color(0.95, 1.00, 0.95, dim) if on else Color(0.60, 0.62, 0.68, dim), 8))
	knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var kx : float = tx + (TOGGLE_W - TOGGLE_H + 3.0) if on else tx + 3.0
	UiKit.place(_page_body, knob, Vector2(kx, ty + 3.0),
		Vector2(TOGGLE_H - 6.0, TOGGLE_H - 6.0))

	var st := Label.new()
	st.add_theme_font_override("font", UI_FONT)
	st.add_theme_font_size_override("font_size", 9)
	_apply_text_fx(st)
	st.text                 = "ВКЛ" if on else "ВЫКЛ"
	st.modulate             = Color(0.90, 1.0, 0.85, dim) if on else Color(0.80, 0.82, 0.88, dim)
	st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	st.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	st.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	var sx : float = tx + 3.0 if on else tx + TOGGLE_H - 3.0
	UiKit.place(_page_body, st, Vector2(sx, ty), Vector2(TOGGLE_W - TOGGLE_H, TOGGLE_H))

	if live:
		var btn := Button.new()
		btn.flat       = true
		btn.focus_mode = Control.FOCUS_NONE
		btn.pressed.connect(func():
			if _hud and _hud.has_method("_play_btn_sfx"):
				_hud._play_btn_sfx()
			_hud.call("_toggle_notif_category", key)
			_build_page())
		UiKit.place(_page_body, btn, Vector2(0.0, y), Vector2(w, H))
	return y + H + 5.0

func _hour_row(w: float, y: float, label: String, key: String) -> float:
	const H : float = 28.0
	UiKit.panel(_page_body, Vector2(0.0, y), Vector2(w, H), CLR_ROW, 8, CLR_ROW_EDGE, 1)

	var lbl := Label.new()
	lbl.add_theme_font_override("font", UI_FONT)
	lbl.add_theme_font_size_override("font_size", 11)
	_apply_text_fx(lbl)
	lbl.text               = label
	lbl.modulate           = CLR_TEXT
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter       = Control.MOUSE_FILTER_IGNORE
	UiKit.place(_page_body, lbl, Vector2(10.0, y), Vector2(w - 130.0, H))

	var val := Label.new()
	val.add_theme_font_override("font", UI_FONT)
	val.add_theme_font_size_override("font_size", 13)
	_apply_text_fx(val)
	val.text                 = "%02d:00" % int(SaveData.get(key))
	val.modulate             = CLR_GOLD
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	val.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	val.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	UiKit.place(_page_body, val, Vector2(w - 106.0, y), Vector2(60.0, H))

	_step_chip(Vector2(w - 118.0, y + 3.0), "−", key, -1)
	_step_chip(Vector2(w - 40.0,  y + 3.0), "+", key,  1)
	return y + H + 5.0

func _step_chip(pos: Vector2, sign_txt: String, key: String, delta: int) -> void:
	var size := Vector2(22.0, 22.0)
	var visual := Control.new()
	visual.pivot_offset = size * 0.5
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.place(_page_body, visual, pos, size)
	var bg := Panel.new()
	bg.add_theme_stylebox_override("panel", UiKit.rounded(
		Color(0.16, 0.20, 0.30, 0.98), 8, CLR_ACCENT, 1))
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.place(visual, bg, Vector2.ZERO, size)
	var lbl := Label.new()
	lbl.add_theme_font_override("font", UI_FONT)
	lbl.add_theme_font_size_override("font_size", 13)
	_apply_text_fx(lbl)
	lbl.text                 = sign_txt
	lbl.modulate             = CLR_TEXT
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	UiKit.place(visual, lbl, Vector2.ZERO, size)

	var btn := Button.new()
	btn.flat       = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.pressed.connect(func():
		if _hud and _hud.has_method("_play_btn_sfx"):
			_hud._play_btn_sfx()
		SaveData.set(key, posmod(int(SaveData.get(key)) + delta, 24))
		SaveData._save()
		SaveData.data_changed.emit()
		_build_page())
	btn.button_down.connect(_press_anim.bind(visual, true))
	btn.button_up.connect(_press_anim.bind(visual, false))
	btn.mouse_exited.connect(_press_anim.bind(visual, false))
	UiKit.place(_page_body, btn, pos, size)

# ── Раздел «Профиль» ─────────────────────────────────────────────────────────
# Имя, аватар и код восстановления жили в трёх разных местах, и ни одно не
# называлось «профиль». Здесь собраны первые два.
func _page_profile(w: float) -> float:
	const AV : float = 64.0
	var av_info : Dictionary = _hud.call("_current_avatar")
	UiKit.panel(_page_body, Vector2(0.0, 6.0), Vector2(AV, AV),
		Color(0.04, 0.04, 0.07, 0.95), 10, CLR_ACCENT, 2)
	var holder : Control = _hud.call("_skin_head_icon",
		String(av_info["skin_id"]), int(av_info["fat"]), AV - 10.0)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.place(_page_body, holder, Vector2(5.0, 11.0), Vector2(AV - 10.0, AV - 10.0))

	var av_btn := Button.new()
	av_btn.flat       = true
	av_btn.focus_mode = Control.FOCUS_NONE
	av_btn.pressed.connect(func():
		if _hud and _hud.has_method("_play_btn_sfx"):
			_hud._play_btn_sfx()
		_hud.call("_show_avatar_picker"))
	UiKit.place(_page_body, av_btn, Vector2(0.0, 6.0), Vector2(AV, AV))

	var hint := Label.new()
	hint.add_theme_font_override("font", UI_FONT)
	hint.add_theme_font_size_override("font_size", 9)
	hint.text                 = "нажми"
	hint.modulate             = Color(0.66, 0.68, 0.74)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	UiKit.place(_page_body, hint, Vector2(0.0, 6.0 + AV + 2.0), Vector2(AV, 12.0))

	var nx : float = AV + 16.0
	var cap := Label.new()
	cap.add_theme_font_override("font", UI_FONT)
	cap.add_theme_font_size_override("font_size", 10)
	_apply_text_fx(cap)
	cap.text               = "ИМЯ В ТАБЛИЦЕ ЛИДЕРОВ"
	cap.modulate           = Color(0.70, 0.74, 0.82)
	cap.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cap.mouse_filter       = Control.MOUSE_FILTER_IGNORE
	UiKit.place(_page_body, cap, Vector2(nx, 8.0), Vector2(w - nx, 14.0))

	var name_lbl := Label.new()
	name_lbl.add_theme_font_override("font", UI_FONT)
	name_lbl.add_theme_font_size_override("font_size", 16)
	_apply_text_fx(name_lbl)
	name_lbl.text                  = String(SaveData.display_name) if String(SaveData.display_name) != "" else "—"
	name_lbl.modulate              = CLR_TEXT
	name_lbl.vertical_alignment    = VERTICAL_ALIGNMENT_CENTER
	name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_lbl.mouse_filter          = Control.MOUSE_FILTER_IGNORE
	UiKit.place(_page_body, name_lbl, Vector2(nx, 24.0), Vector2(w - nx, 24.0))

	_action_button(Vector2(nx, 54.0), Vector2(minf(190.0, w - nx), 30.0),
		"ИЗМЕНИТЬ ИМЯ", Color(0.16, 0.20, 0.30, 0.98), CLR_ACCENT,
		func(): _hud.call("_show_rename_modal"))
	return 6.0 + AV + 24.0

# ── Раздел «Аккаунт» ─────────────────────────────────────────────────────────
func _page_account(w: float) -> float:
	var y := 6.0
	var cap := Label.new()
	cap.add_theme_font_override("font", UI_FONT)
	cap.add_theme_font_size_override("font_size", 11)
	_apply_text_fx(cap)
	cap.text               = "КОД ВОССТАНОВЛЕНИЯ"
	cap.modulate           = CLR_GOLD
	cap.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cap.mouse_filter       = Control.MOUSE_FILTER_IGNORE
	UiKit.place(_page_body, cap, Vector2(0.0, y), Vector2(w, 16.0))
	y += 20.0

	# Код показан ЦЕЛИКОМ: пояснение ниже просит переписать его в надёжное
	# место, а переписать звёздочки нельзя.
	var box_w : float = w - 118.0
	UiKit.panel(_page_body, Vector2(0.0, y), Vector2(box_w, 32.0),
		Color(0.04, 0.04, 0.07, 0.95), 8, Color(0.40, 0.44, 0.55, 0.9), 1)
	var code := Label.new()
	code.add_theme_font_override("font", UI_FONT)
	code.add_theme_font_size_override("font_size", 15)
	_apply_text_fx(code)
	code.text                 = String(SaveData.recovery_code) if String(SaveData.recovery_code) != "" else "—"
	code.modulate             = Color(1.0, 0.97, 0.85)
	code.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	code.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	code.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	UiKit.place(_page_body, code, Vector2(0.0, y), Vector2(box_w, 32.0))

	var copied := Label.new()
	_action_button(Vector2(box_w + 8.0, y), Vector2(110.0, 32.0),
		"КОПИРОВАТЬ", Color(0.12, 0.26, 0.36, 0.98), CLR_ACCENT,
		func():
			DisplayServer.clipboard_set(String(SaveData.recovery_code))
			if is_instance_valid(copied):
				copied.text = "код скопирован"
				copied.modulate = Color(0.60, 1.0, 0.65))
	y += 36.0

	copied.add_theme_font_override("font", UI_FONT)
	copied.add_theme_font_size_override("font_size", 9)
	copied.text          = ""
	copied.modulate      = Color(0.60, 1.0, 0.65)
	copied.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	UiKit.place(_page_body, copied, Vector2(0.0, y), Vector2(w, 12.0))
	y += 14.0

	var exp_lbl := Label.new()
	exp_lbl.add_theme_font_override("font", UI_FONT)
	exp_lbl.add_theme_font_size_override("font_size", 10)
	exp_lbl.text          = "Запасной ключ к аккаунту. Поменяешь телефон или удалишь игру — введи его, и весь прогресс вернётся. Сохрани в надёжном месте и никому не показывай."
	exp_lbl.modulate      = Color(0.74, 0.76, 0.82)
	exp_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	exp_lbl.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	UiKit.place(_page_body, exp_lbl, Vector2(0.0, y), Vector2(w, 44.0))
	y += 50.0

	_action_button(Vector2(0.0, y), Vector2(minf(240.0, w), 32.0),
		"ВОССТАНОВИТЬ АККАУНТ", Color(0.20, 0.16, 0.34, 0.98),
		Color(0.70, 0.60, 1.00, 0.95),
		func(): _hud.call("_show_restore_modal"))
	return y + 40.0

# ── Общие кирпичи ────────────────────────────────────────────────────────────
func _action_button(pos: Vector2, size: Vector2, text: String,
		fill: Color, border: Color, action: Callable) -> void:
	var visual := Control.new()
	visual.pivot_offset = size * 0.5
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.place(_page_body, visual, pos, size)

	var bg := Panel.new()
	bg.add_theme_stylebox_override("panel", UiKit.rounded(fill, 8, border, 2))
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.place(visual, bg, Vector2.ZERO, size)

	var lbl := Label.new()
	lbl.add_theme_font_override("font", UI_FONT)
	lbl.add_theme_font_size_override("font_size", 12)
	_apply_text_fx(lbl)
	lbl.text                 = text
	lbl.modulate             = CLR_TEXT
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	UiKit.place(visual, lbl, Vector2.ZERO, size)

	var btn := Button.new()
	btn.flat       = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.pressed.connect(func():
		if _hud and _hud.has_method("_play_btn_sfx"):
			_hud._play_btn_sfx()
		action.call())
	btn.button_down.connect(_press_anim.bind(visual, true))
	btn.button_up.connect(_press_anim.bind(visual, false))
	btn.mouse_exited.connect(_press_anim.bind(visual, false))
	UiKit.place(_page_body, btn, pos, size)

func _build_back_button(sx: float, sy: float) -> void:
	var back_size := Vector2(BACK_BTN_SIZE.x * sx, BACK_BTN_SIZE.y * sy)
	var visual := Control.new()
	visual.pivot_offset = back_size * 0.5
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.place(_slide_root, visual, Vector2(BACK_BTN_POS.x * sx, BACK_BTN_POS.y * sy), back_size)

	var icon := TextureRect.new()
	icon.texture             = TEX_BACK_ARROW
	icon.stretch_mode        = TextureRect.STRETCH_SCALE
	icon.expand_mode         = TextureRect.EXPAND_IGNORE_SIZE
	icon.custom_minimum_size = Vector2.ZERO
	icon.texture_filter      = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter        = Control.MOUSE_FILTER_IGNORE
	UiKit.place(visual, icon, Vector2.ZERO, back_size)

	var btn := Button.new()
	btn.flat       = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.pressed.connect(_on_close)
	btn.button_down.connect(_press_anim.bind(visual, true))
	btn.button_up.connect(_press_anim.bind(visual, false))
	btn.mouse_exited.connect(_press_anim.bind(visual, false))
	UiKit.place(_slide_root, btn, visual.position - Vector2(7.0, 7.0),
		back_size + Vector2(14.0, 14.0))

func _build_resource_strip(vp: Vector2) -> void:
	var sx : float = vp.x / CANVAS_W
	var sy : float = vp.y / CANVAS_H
	var icon_sz : float = RES_ICON_SZ * sy
	var num_w   : float = RES_NUM_W * sx
	var gap     : float = RES_GAP * sx
	var pair_w  : float = icon_sz + 2.0 + num_w
	var total_w : float = pair_w * 2.0 + gap
	var start_x : float = vp.x - RES_RIGHT_PAD * sx - total_w
	var top_y   : float = RES_Y * sy

	var dol := _make_icon(TEX_DOLLAR, icon_sz)
	UiKit.place(_slide_root, dol, Vector2(start_x, top_y), Vector2(icon_sz, icon_sz))
	_dollar_lbl = _res_label(str(SaveData.dollars))
	UiKit.place(_slide_root, _dollar_lbl,
		Vector2(start_x + icon_sz + 2.0, top_y - 2.0), Vector2(num_w, icon_sz + 4.0))

	var tkn_x : float = start_x + pair_w + gap
	var tkn := _make_icon(TEX_TOKEN, icon_sz)
	UiKit.place(_slide_root, tkn, Vector2(tkn_x, top_y), Vector2(icon_sz, icon_sz))
	_token_lbl = _res_label(str(SaveData.tokens))
	UiKit.place(_slide_root, _token_lbl,
		Vector2(tkn_x + icon_sz + 2.0, top_y - 2.0), Vector2(num_w, icon_sz + 4.0))

func _res_label(txt: String) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", UI_FONT)
	l.add_theme_font_size_override("font_size", RES_FONT_SZ)
	_apply_text_fx(l)
	l.text               = txt
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter       = Control.MOUSE_FILTER_IGNORE
	return l

func _make_icon(tex: Texture2D, sz: float) -> TextureRect:
	var r := TextureRect.new()
	r.texture      = tex
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
	r.size         = Vector2(sz, sz)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

func _apply_text_fx(lbl: Label) -> void:
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.65))
	lbl.add_theme_constant_override("outline_size", 2)
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.80))
	lbl.add_theme_constant_override("shadow_offset_x", 0)
	lbl.add_theme_constant_override("shadow_offset_y", 0)
	lbl.add_theme_constant_override("shadow_outline_size", 3)

const _PRESS_SCALE : float = 0.90
const _PRESS_TIME  : float = 0.07
func _press_anim(visual_root: Control, pressed: bool) -> void:
	if not is_instance_valid(visual_root):
		return
	var target := Vector2.ONE * (_PRESS_SCALE if pressed else 1.0)
	var tw := create_tween()
	tw.tween_property(visual_root, "scale", target, _PRESS_TIME)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

# Диалоги имени и восстановления пишут в SaveData — страница обязана
# перерисоваться, иначе на ней остаётся старое имя.
func _on_data_changed() -> void:
	if not is_instance_valid(_page_body):
		return
	if is_instance_valid(_dollar_lbl):
		_dollar_lbl.text = str(SaveData.dollars)
	if is_instance_valid(_token_lbl):
		_token_lbl.text = str(SaveData.tokens)
	if _sel == "profile":
		_build_page()

func _on_close() -> void:
	if not is_instance_valid(_slide_root):
		queue_free()
		return
	var vp := get_viewport().get_visible_rect().size
	var tw := create_tween()
	tw.tween_property(_slide_root, "position", Vector2(0.0, vp.y), SLIDE_TIME)\
		.set_trans(SLIDE_TRANS).set_ease(SLIDE_EASE_OUT)
	tw.tween_callback(Callable(self, "queue_free"))
	if _hud != null and _hud.has_method("_on_settings_close_anim_start"):
		_hud._on_settings_close_anim_start(SLIDE_TIME, SLIDE_TRANS, SLIDE_EASE_OUT)
