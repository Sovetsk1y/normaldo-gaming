extends Node2D
class_name LeaderboardScreen

# Master toggle for all dev-only UI. Flip ENABLED in dev_flags.gd to restore.
const DevFlags = preload("res://scripts/dev_flags.gd")

const UI_FONT        := preload("res://assets/fonts/RussoOne-Regular.ttf")
const TEX_PIZZA      := preload("res://assets/items/pizza.png")
const TEX_DOLLAR     := preload("res://assets/items/dollar.png")
const TEX_TOKEN      := preload("res://assets/items/token.png")
const TEX_BG_LEADERS := preload("res://assets/ui/leaders/bg_leaders.png")
const TEX_BACK_ARROW := preload("res://assets/ui/quests/back_arrow.png")

const CLR_BG        := Color(0.06, 0.04, 0.02, 0.96)
const CLR_HDR_BG    := Color(0.04, 0.03, 0.01, 1.0)
const CLR_TAB_ACTV  := Color(0.18, 0.20, 0.12, 0.98)
const CLR_TAB_DIM   := Color(0.07, 0.06, 0.04, 0.95)
const CLR_ROW_BG_A  := Color(0.09, 0.07, 0.04, 0.85)
const CLR_ROW_BG_B  := Color(0.07, 0.06, 0.03, 0.85)
const CLR_ROW_PLR   := Color(0.10, 0.30, 0.14, 0.95)
const CLR_GOLD      := Color(1.00, 0.85, 0.35)
const CLR_SILVER    := Color(0.83, 0.85, 0.90)
const CLR_BRONZE    := Color(0.78, 0.51, 0.32)

# ── Layout (canvas pixels 430×192) — same conventions as quests/book screen ──
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
# Central black zone for the scroll list of player rows.
const ZONE_X : float = 30.0
const ZONE_Y : float = 56.0
const ZONE_W : float = 370.0
const ZONE_H : float = 116.0
# Slide-down transition.
const SLIDE_TIME      : float = 0.45
const SLIDE_TRANS     : int   = Tween.TRANS_QUAD
const SLIDE_EASE_IN   : int   = Tween.EASE_IN
const SLIDE_EASE_OUT  : int   = Tween.EASE_IN

# Legacy values kept for row-builder math (offsets, etc.).
const HDR_H := 46.0
const TAB_H := 32.0
const ROW_H := 30.0

var _hud            : Node = null
var _initial_metric : int  = 0
var _active_metric  : int  = 0
var _view_mode      : int  = 0  # 0 = full top-100, 1 = window around player

# Slide-root holds every visible element. Camera-pan entrance / exit moves
# the entire screen as one piece. `_overlay` is a legacy alias for row /
# popup builders that parent into it.
var _slide_root   : Control = null
var _overlay      : Control = null
var _timer_lbl    : Label     = null
var _scroll       : ScrollContainer = null
var _content      : Control   = null
var _tab_best_bg  : Panel = null
var _tab_total_bg : Panel = null
var _tab_best_lbl : Label     = null
var _tab_total_lbl: Label     = null
var _my_pos_btn   : Node2D    = null
var _podium_root  : Control   = null
# Что именно отрисовано сейчас: подиум и список по номерам мест. Пригождается и
# при разборе жалоб «почему я не вижу себя», и в прогоне dev/smoke_leaders.gd.
var _podium_ranks : Array     = []
var _list_ranks   : Array     = []
var _my_strip_lbl : Label     = null
var _lock_overlay : Node2D    = null
var _toast_node   : Node2D    = null

var _reset_seconds_left : float = 0.0

# Cached server rows keyed by metric. When we get a successful fetch, we cache
# rows here so tab-switching feels instant.
var _server_rows  : Dictionary = {}
var _server_window: Dictionary = {}
var _data_origin  : String     = "demo"   # "live" once we successfully fetched
var _origin_lbl   : Label      = null
var _fetch_busy   : bool       = false

func setup(hud: Node, initial_metric: int = 0) -> void:
	_hud = hud
	_initial_metric = initial_metric

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_active_metric = _initial_metric
	_reset_seconds_left = LeaderboardMock.get_reset_seconds()
	var vp := get_viewport().get_visible_rect().size
	_build(vp)
	_refresh_tab_visual()
	# Show loading placeholder first; live data (or mock fallback on error)
	# replaces it via _fetch_from_server_async.
	_show_loading_state()
	_fetch_from_server_async()
	set_process(true)
	# Camera-pan-down entrance — same choreography as quests / book / skins.
	_slide_root.position = Vector2(0.0, vp.y)
	var tw := create_tween()
	tw.tween_property(_slide_root, "position", Vector2.ZERO, SLIDE_TIME)\
		.set_trans(SLIDE_TRANS).set_ease(SLIDE_EASE_IN)
	if _hud != null and _hud.has_method("_on_leaders_open_anim_start"):
		_hud._on_leaders_open_anim_start(SLIDE_TIME, SLIDE_TRANS, SLIDE_EASE_IN)
	# Lock overlay (endless not unlocked yet) is built AFTER the slide-down
	# completes so the modal doesn't pop in mid-pan and look glitchy.
	if not QuestManager.is_endless_unlocked():
		tw.finished.connect(func():
			if is_instance_valid(self):
				_build_lock_overlay(get_viewport().get_visible_rect().size)
		)

func _process(delta: float) -> void:
	_reset_seconds_left = maxf(0.0, _reset_seconds_left - delta)
	if is_instance_valid(_timer_lbl):
		_timer_lbl.text = "Призы через %s" % _fmt_duration(_reset_seconds_left)

# ── Build ────────────────────────────────────────────────────────────────────

func _build(vp: Vector2) -> void:
	var scale_x : float = vp.x / CANVAS_W
	var scale_y : float = vp.y / CANVAS_H

	# Slide root — every visible element parents into it so the entrance and
	# exit tweens move the whole screen as one piece.
	_slide_root = Control.new()
	_slide_root.size         = vp
	_slide_root.position     = Vector2.ZERO
	_slide_root.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_slide_root)
	_overlay = _slide_root   # legacy alias for row / popup builders

	# Full-screen pixel-art background.
	var bg := TextureRect.new()
	bg.texture             = TEX_BG_LEADERS
	bg.stretch_mode        = TextureRect.STRETCH_SCALE
	bg.expand_mode         = TextureRect.EXPAND_IGNORE_SIZE
	bg.custom_minimum_size = Vector2.ZERO
	bg.size                = vp
	bg.position            = Vector2.ZERO
	bg.texture_filter      = CanvasItem.TEXTURE_FILTER_NEAREST
	bg.mouse_filter        = Control.MOUSE_FILTER_IGNORE
	_slide_root.add_child(bg)

	# ── Top-left back button (press-shrink) ────────────────────────────────
	var back_size := Vector2(BACK_BTN_SIZE.x * scale_x, BACK_BTN_SIZE.y * scale_y)
	var back_visual := Control.new()
	back_visual.size         = back_size
	back_visual.position     = Vector2(BACK_BTN_POS.x * scale_x, BACK_BTN_POS.y * scale_y)
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

	# ── Top-centre title ───────────────────────────────────────────────────
	var title_lbl := Label.new()
	title_lbl.add_theme_font_override("font", UI_FONT)
	title_lbl.add_theme_font_size_override("font_size", TITLE_FONT_SZ)
	_apply_text_fx(title_lbl)
	title_lbl.text                 = "ЛИДЕРЫ"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	title_lbl.size                 = Vector2(vp.x, TITLE_H * scale_y)
	title_lbl.position             = Vector2(TITLE_X_OFFSET * scale_x, TITLE_Y * scale_y)
	title_lbl.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	_slide_root.add_child(title_lbl)

	# ── Top-right resources ────────────────────────────────────────────────
	_build_top_resources(vp, scale_x, scale_y)

	# Таймер розыгрыша — чипом в шапке, а не мелкой подписью под заголовком:
	# это главный мотиватор экрана, а подан был как сноска.
	# См. /Концепция/Экран лидеров.md
	var chip_w : float = 210.0
	var chip_h : float = 26.0
	var chip_x : float = vp.x - 250.0 - chip_w
	var chip_y : float = 9.0
	UiKit.panel(_slide_root, Vector2(chip_x, chip_y), Vector2(chip_w, chip_h),
		Color(0.10, 0.08, 0.05, 0.88), 8, Color(0.62, 0.50, 0.24, 0.95))
	_timer_lbl = Label.new()
	_timer_lbl.add_theme_font_override("font", UI_FONT)
	_timer_lbl.add_theme_font_size_override("font_size", 12)
	_apply_text_fx(_timer_lbl)
	_timer_lbl.text                 = "ПРИЗЫ ЧЕРЕЗ %s" % _fmt_duration(_reset_seconds_left)
	_timer_lbl.modulate             = Color(1.0, 0.88, 0.45)
	_timer_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timer_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_timer_lbl.size                 = Vector2(chip_w, chip_h)
	_timer_lbl.position             = Vector2(chip_x, chip_y)
	_timer_lbl.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	_slide_root.add_child(_timer_lbl)

	# ── Вкладки-пилюли ─────────────────────────────────────────────────────
	# Активная отличается ФОРМОЙ (залитая против контурной), а не оттенком фона:
	# по одному оттенку выбранную вкладку не видно.
	var lay := _layout(vp)
	var tab_w : float = 268.0
	var tab_h : float = float(lay["tabs_h"])
	var tab_y : float = float(lay["tabs_y"])
	var gap   : float = 14.0
	var tabs_x : float = (vp.x - tab_w * 2.0 - gap) * 0.5

	_tab_best_bg = _tab_pill(Vector2(tabs_x, tab_y), Vector2(tab_w, tab_h))
	_tab_best_lbl = _tab_label("РЕКОРД ЗАБЕГА", Vector2(tabs_x, tab_y), Vector2(tab_w, tab_h))
	_tab_button(Vector2(tabs_x, tab_y), Vector2(tab_w, tab_h), _on_tab_best)
	_build_help_pill(Vector2(tabs_x + tab_w - 26.0, tab_y + (tab_h - 18.0) * 0.5),
		Color(1.00, 0.85, 0.35), LeaderboardMock.Metric.BEST)

	var tx2 : float = tabs_x + tab_w + gap
	_tab_total_bg = _tab_pill(Vector2(tx2, tab_y), Vector2(tab_w, tab_h))
	_tab_total_lbl = _tab_label("ГОРА ПИЦЦ", Vector2(tx2, tab_y), Vector2(tab_w, tab_h))
	_tab_button(Vector2(tx2, tab_y), Vector2(tab_w, tab_h), _on_tab_total)
	_build_help_pill(Vector2(tx2 + tab_w - 26.0, tab_y + (tab_h - 18.0) * 0.5),
		Color(1.00, 0.85, 0.35), LeaderboardMock.Metric.TOTAL)

	# Подиум первой тройки — витрина экрана; список идёт с 4-го места.
	_podium_root = Control.new()
	_podium_root.size         = vp
	_podium_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slide_root.add_child(_podium_root)

	# Список: непрозрачная скруглённая панель. Раньше строки были полупрозрачные,
	# и сквозь них просвечивала кирпичная стена — текст дрался с текстурой.
	var list_pos  := Vector2(float(lay["margin"]), float(lay["list_y"]))
	var list_size := Vector2(vp.x - float(lay["margin"]) * 2.0, float(lay["list_h"]))
	UiKit.panel(_slide_root, list_pos - Vector2(4.0, 4.0), list_size + Vector2(8.0, 8.0),
		Color(0.05, 0.04, 0.03, 0.94), 12, Color(0.26, 0.22, 0.16, 0.95))

	_scroll = ScrollContainer.new()
	_scroll.position = list_pos
	_scroll.size     = list_size
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode   = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_scroll.set("scroll_deadzone", 18)
	_slide_root.add_child(_scroll)

	_content = Control.new()
	_scroll.add_child(_content)

	# Своя строка закреплена внизу и видна всегда: раньше на вопрос «где я»
	# экран отвечал только после нажатия и прокрутки.
	_build_my_strip(vp)
	if DevFlags.ENABLED:
		_build_dev_prize_btn(vp)

# Раскладка экрана в одном месте — её спрашивают и сборка, и перестройка списка.
func _layout(vp: Vector2) -> Dictionary:
	var margin   : float = 22.0
	var tabs_y   : float = 46.0
	var tabs_h   : float = 30.0
	var podium_y : float = tabs_y + tabs_h + 8.0
	var podium_h : float = 112.0
	var strip_h  : float = 36.0
	var strip_y  : float = vp.y - strip_h - 8.0
	var list_y   : float = podium_y + podium_h + 10.0
	return {
		"margin": margin, "tabs_y": tabs_y, "tabs_h": tabs_h,
		"podium_y": podium_y, "podium_h": podium_h,
		"list_y": list_y, "list_h": strip_y - 10.0 - list_y,
		"strip_y": strip_y, "strip_h": strip_h,
	}

func _tab_pill(pos: Vector2, size: Vector2) -> Panel:
	var p := UiKit.panel(_slide_root, pos, size, CLR_TAB_DIM, 10,
		Color(0.40, 0.36, 0.26, 0.95))
	return p

func _tab_label(text: String, pos: Vector2, size: Vector2) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", UI_FONT)
	l.add_theme_font_size_override("font_size", 13)
	_apply_text_fx(l)
	l.text                 = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	l.size                 = size
	l.position             = pos
	l.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	_slide_root.add_child(l)
	return l

func _tab_button(pos: Vector2, size: Vector2, action: Callable) -> void:
	var b := Button.new()
	b.flat       = true
	b.focus_mode = Control.FOCUS_NONE
	b.size       = size
	b.position   = pos
	b.pressed.connect(action)
	_slide_root.add_child(b)

# Russo One text — black outline + soft shadow. Single helper applied to every
# label on this screen for visual consistency with the menu / quests / book.
func _apply_text_fx(lbl: Label) -> void:
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.65))
	lbl.add_theme_constant_override("outline_size", 2)
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.80))
	lbl.add_theme_constant_override("shadow_offset_x", 0)
	lbl.add_theme_constant_override("shadow_offset_y", 0)
	lbl.add_theme_constant_override("shadow_outline_size", 3)

# Press feedback for tap-targets — mirrors the main-menu chip shrink.
func _press_anim(visual_root: Control, pressed: bool) -> void:
	UiKit.press_anim(visual_root, pressed)

# Top-right resources (dollar + token), mirroring the quests / book chrome.
func _build_top_resources(vp: Vector2, scale_x: float, scale_y: float) -> void:
	var icon_sz : float = RES_ICON_SZ * scale_y
	var num_w   : float = RES_NUM_W * scale_x
	var gap     : float = RES_GAP * scale_x
	var pair_w  : float = icon_sz + 2.0 + num_w
	var total_w : float = pair_w * 2.0 + gap
	var right_x : float = vp.x - RES_RIGHT_PAD * scale_x
	var start_x : float = right_x - total_w
	var top_y   : float = RES_Y * scale_y

	var dol_x : float = start_x
	var dol_icon := _make_icon(TEX_DOLLAR, icon_sz)
	dol_icon.position = Vector2(dol_x, top_y)
	_slide_root.add_child(dol_icon)
	var dol_lbl := Label.new()
	dol_lbl.add_theme_font_override("font", UI_FONT)
	dol_lbl.add_theme_font_size_override("font_size", RES_FONT_SZ)
	_apply_text_fx(dol_lbl)
	dol_lbl.text                 = str(SaveData.dollars)
	dol_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	dol_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	dol_lbl.size                 = Vector2(num_w, icon_sz + 4.0)
	dol_lbl.position             = Vector2(dol_x + icon_sz + 2.0, top_y - 2.0)
	_slide_root.add_child(dol_lbl)

	var tkn_x : float = dol_x + pair_w + gap
	var tkn_icon := _make_icon(TEX_TOKEN, icon_sz)
	tkn_icon.position = Vector2(tkn_x, top_y)
	_slide_root.add_child(tkn_icon)
	var tkn_lbl := Label.new()
	tkn_lbl.add_theme_font_override("font", UI_FONT)
	tkn_lbl.add_theme_font_size_override("font_size", RES_FONT_SZ)
	_apply_text_fx(tkn_lbl)
	tkn_lbl.text                 = str(SaveData.tokens)
	tkn_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	tkn_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	tkn_lbl.size                 = Vector2(num_w, icon_sz + 4.0)
	tkn_lbl.position             = Vector2(tkn_x + icon_sz + 2.0, top_y - 2.0)
	_slide_root.add_child(tkn_lbl)

# Подиум первой тройки: второе слева, первое по центру и крупнее, третье справа.
# Раньше тройка отличалась только цветом номера — витрины не было вовсе, а
# дальтоник не отличал её от остального списка.
func _build_podium(rows: Array) -> void:
	if not is_instance_valid(_podium_root):
		return
	for c in _podium_root.get_children():
		c.queue_free()
	var vp := get_viewport().get_visible_rect().size
	var lay := _layout(vp)
	var y  : float = float(lay["podium_y"])
	var h  : float = float(lay["podium_h"])

	var side_w : float = 254.0
	var mid_w  : float = 292.0
	var gap    : float = 16.0
	var total  : float = side_w * 2.0 + mid_w + gap * 2.0
	var x0     : float = (vp.x - total) * 0.5

	# порядок на экране: 2 — 1 — 3
	var order : Array = [
		{ "place": 2, "x": x0,                       "w": side_w, "dy": 14.0, "col": CLR_SILVER },
		{ "place": 1, "x": x0 + side_w + gap,        "w": mid_w,  "dy": 0.0,  "col": CLR_GOLD },
		{ "place": 3, "x": x0 + side_w + mid_w + gap * 2.0, "w": side_w, "dy": 14.0, "col": CLR_BRONZE },
	]
	for o in order:
		var idx : int = int(o["place"]) - 1
		if idx >= rows.size():
			continue
		_build_podium_card(rows[idx], Vector2(float(o["x"]), y + float(o["dy"])),
			Vector2(float(o["w"]), h - float(o["dy"])), int(o["place"]), Color(o["col"]))

func _build_podium_card(r: Dictionary, pos: Vector2, size: Vector2, place: int, col: Color) -> void:
	UiKit.panel(_podium_root, pos, size, Color(0.09, 0.07, 0.05, 0.97), 12, col, 3 if place == 1 else 2)

	# Медальон с НОМЕРОМ: место названо цифрой, а не только цветом рамки.
	var disc_sz : float = 30.0 if place == 1 else 26.0
	UiKit.panel(_podium_root, pos + Vector2(10.0, 8.0), Vector2(disc_sz, disc_sz),
		Color(col.r * 0.30, col.g * 0.30, col.b * 0.30, 0.98), int(disc_sz * 0.5), col, 2)
	var num := _label("%d" % place, 16 if place == 1 else 14, Color(1, 1, 1),
		pos + Vector2(10.0, 8.0), Vector2(disc_sz, disc_sz))
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER

	var av_sz : float = 46.0 if place == 1 else 40.0
	_add_avatar(_podium_root, String(r.get("avatar_skin", "classic")),
		int(r.get("avatar_fat", 0)), pos + Vector2(size.x - av_sz - 10.0, 6.0), av_sz)

	# Имя в одну строку с медальоном: на боковых карточках (они ниже центральной)
	# строка под медальоном налезала на счёт.
	var pname : String = String(r.get("name", r.get("display_name", "")))
	var name_x : float = 10.0 + disc_sz + 8.0
	var nm := _label(pname, 15 if place == 1 else 13, Color(1.0, 0.97, 0.90),
		pos + Vector2(name_x, 8.0), Vector2(size.x - name_x - av_sz - 16.0, disc_sz))
	nm.clip_text          = true
	nm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	var sy : float = size.y - 52.0
	var pz := _make_icon(TEX_PIZZA, 20.0)
	pz.position     = pos + Vector2(10.0, sy)
	pz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_podium_root.add_child(pz)
	_label(str(int(r.get("score", 0))), 17, Color(1.0, 0.88, 0.45),
		pos + Vector2(34.0, sy - 2.0), Vector2(size.x - 44.0, 24.0))

	_build_reward_block(_podium_root, pos + Vector2(10.0, size.y - 26.0),
		size.x - 20.0, LeaderboardMock.reward_for_place(place), 18.0)

# Своя строка внизу экрана — видна всегда. Тап прокручивает список к себе
# (бывшая плавающая кнопка «МОЯ ПОЗИЦИЯ», которая закрывала строки списка).
func _build_my_strip(vp: Vector2) -> void:
	var lay := _layout(vp)
	var pos  := Vector2(float(lay["margin"]), float(lay["strip_y"]))
	var size := Vector2(vp.x - float(lay["margin"]) * 2.0, float(lay["strip_h"]))
	_my_pos_btn = Node2D.new()
	_my_pos_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	# В _slide_root, а не в экран: иначе строка стоит на месте, пока весь
	# остальной экран въезжает снизу.
	_slide_root.add_child(_my_pos_btn)

	UiKit.panel(_my_pos_btn, pos, size, Color(0.09, 0.20, 0.10, 0.97), 10,
		Color(0.45, 0.90, 0.35, 0.95))
	# Слово «ТЫ», а не только зелёный фон: состояние обязано быть названо.
	var you := _label("ТЫ", 13, Color(0.70, 1.0, 0.60), pos + Vector2(12.0, 0.0),
		Vector2(34.0, size.y), _my_pos_btn)
	you.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	_my_strip_lbl = _label("", 13, Color(0.95, 1.0, 0.90), pos + Vector2(52.0, 0.0),
		Vector2(size.x - 272.0, size.y), _my_pos_btn)
	_my_strip_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_refresh_my_strip()

	var hint := _label("ПОКАЗАТЬ В СПИСКЕ", 12, Color(0.80, 1.0, 0.70),
		pos + Vector2(size.x - 200.0, 0.0), Vector2(188.0, size.y), _my_pos_btn)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER

	var btn := Button.new()
	btn.flat       = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.size       = size
	btn.position   = pos
	btn.pressed.connect(_on_my_position)
	_my_pos_btn.add_child(btn)

func _refresh_my_strip() -> void:
	if not is_instance_valid(_my_strip_lbl):
		return
	var rank : int = _player_rank_for_active_metric()
	var nick : String = SaveData.display_name if SaveData.display_name != "" else "—"
	var total : int = int(LeaderboardMock.MOCK_TOTAL_PLAYERS)
	_my_strip_lbl.text = "%d место из %d   ·   %s" % [rank, total, nick]

# Награда местом: иконка + число, как во всей остальной игре. Текст «+5000 $»
# внутри игрового экрана читается как заглушка.
func _build_reward_block(parent: Node, pos: Vector2, w: float, reward: Dictionary, sz: float) -> void:
	var d : int = int(reward.get("dollars", 0))
	var t : int = int(reward.get("tokens", 0))
	var x : float = pos.x
	if d > 0:
		var di := _make_icon(TEX_DOLLAR, sz)
		di.position     = Vector2(x, pos.y)
		di.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(di)
		var dl := _label("+%d" % d, int(sz * 0.72), CLR_GOLD,
			Vector2(x + sz + 3.0, pos.y - 2.0), Vector2(78.0, sz + 4.0), parent)
		dl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		x += sz + 3.0 + _text_w("+%d" % d, int(sz * 0.72)) + 10.0
	if t > 0:
		var ti := _make_icon(TEX_TOKEN, sz)
		ti.position     = Vector2(x, pos.y)
		ti.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(ti)
		var tl := _label("+%d" % t, int(sz * 0.72), CLR_GOLD,
			Vector2(x + sz + 3.0, pos.y - 2.0), Vector2(60.0, sz + 4.0), parent)
		tl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

func _text_w(text: String, size_px: int) -> float:
	return UI_FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x

# Аватар игрока. Голова сажается в коробку тем же способом, что и в HUD, —
# иначе у скинов с руками (Джокер) голова выходит втрое мельче соседских.
func _add_avatar(parent: Node, skin: String, fat: int, pos: Vector2, sz: float) -> void:
	if _hud != null and is_instance_valid(_hud) and _hud.has_method("_skin_head_icon"):
		var holder : Control = _hud.call("_skin_head_icon", skin, fat, sz)
		holder.position = pos
		parent.add_child(holder)
		return
	var av := _make_icon(SkinRegistry.get_avatar_texture(skin, fat), sz)
	av.position     = pos
	av.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(av)

func _label(text: String, size_px: int, col: Color, pos: Vector2, size: Vector2,
		parent: Node = null) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", UI_FONT)
	l.add_theme_font_size_override("font_size", size_px)
	_apply_text_fx(l)
	l.text         = text
	l.modulate     = col
	l.size         = size
	l.position     = pos
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(parent if parent != null else _podium_root).add_child(l)
	return l

func _build_dev_prize_btn(vp: Vector2) -> void:
	const BTN_W : float = 110.0
	const BTN_H : float = 28.0
	# Над своей строкой, а не поверх неё.
	var pos := Vector2(10.0, float(_layout(vp)["strip_y"]) - BTN_H - 6.0)
	var root := Node2D.new()
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	root.position = pos
	add_child(root)

	var bg := ColorRect.new()
	bg.color = Color(0.18, 0.10, 0.28, 0.92)
	bg.size  = Vector2(BTN_W, BTN_H)
	root.add_child(bg)

	var stripe := ColorRect.new()
	stripe.color = Color(0.75, 0.45, 1.0, 0.80)
	stripe.size  = Vector2(BTN_W, 2.0)
	root.add_child(stripe)

	var lbl := Label.new()
	lbl.add_theme_font_override("font", UI_FONT)
	lbl.add_theme_font_size_override("font_size", 10)
	_apply_text_fx(lbl)
	lbl.text                 = "DEV: ТЕСТ ПРИЗА"
	lbl.modulate             = Color(0.90, 0.70, 1.0)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl.size                 = Vector2(BTN_W, BTN_H)
	lbl.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	root.add_child(lbl)

	var btn := Button.new()
	btn.flat       = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.size       = Vector2(BTN_W, BTN_H)
	btn.pressed.connect(_on_dev_prize_test)
	root.add_child(btn)

# ── Tab switching ────────────────────────────────────────────────────────────

# Активная вкладка — ЗАЛИТАЯ пилюля с тёмным текстом, неактивная — контурная с
# тусклым. Различие по форме, а не по оттенку фона: по оттенку выбранную
# вкладку не видно ни на солнце, ни дальтонику.
func _refresh_tab_visual() -> void:
	var best_on : bool = _active_metric == LeaderboardMock.Metric.BEST
	_set_tab_style(_tab_best_bg,  _tab_best_lbl,  best_on)
	_set_tab_style(_tab_total_bg, _tab_total_lbl, not best_on)

func _set_tab_style(pill: Panel, lbl: Label, active: bool) -> void:
	if not is_instance_valid(pill) or not is_instance_valid(lbl):
		return
	if active:
		pill.add_theme_stylebox_override("panel",
			UiKit.rounded(CLR_GOLD, 10, Color(1.0, 0.95, 0.70, 1.0)))
		lbl.modulate = Color(0.10, 0.08, 0.04)
		# Чёрная обводка по тёмному тексту на золоте превращает его в кашу.
		lbl.add_theme_constant_override("outline_size", 0)
		lbl.add_theme_constant_override("shadow_outline_size", 0)
	else:
		pill.add_theme_stylebox_override("panel",
			UiKit.rounded(CLR_TAB_DIM, 10, Color(0.40, 0.36, 0.26, 0.95)))
		lbl.modulate = Color(0.72, 0.68, 0.58)
		lbl.add_theme_constant_override("outline_size", 3)
		lbl.add_theme_constant_override("shadow_outline_size", 3)

func _on_tab_best() -> void:
	if not QuestManager.is_endless_unlocked():
		_show_lock_toast()
		return
	if _active_metric == LeaderboardMock.Metric.BEST:
		return
	_active_metric = LeaderboardMock.Metric.BEST
	_view_mode = 0
	_refresh_tab_visual()
	if _server_rows.has(_active_metric):
		_rebuild_list()
	else:
		_show_loading_state()
	_fetch_from_server_async()

func _on_tab_total() -> void:
	if not QuestManager.is_endless_unlocked():
		_show_lock_toast()
		return
	if _active_metric == LeaderboardMock.Metric.TOTAL:
		return
	_active_metric = LeaderboardMock.Metric.TOTAL
	_view_mode = 0
	_refresh_tab_visual()
	if _server_rows.has(_active_metric):
		_rebuild_list()
	else:
		_show_loading_state()
	_fetch_from_server_async()

# ── My position ──────────────────────────────────────────────────────────────

func _on_my_position() -> void:
	if not QuestManager.is_endless_unlocked():
		_show_lock_toast()
		return
	# Try the server-side window first (real ranks)
	if LeaderboardClient.is_ready():
		await _fetch_window_async()
	var rank := _player_rank_for_active_metric()
	if rank >= 1 and rank <= 100:
		_view_mode = 0
		_rebuild_list()
		await get_tree().process_frame
		_scroll_to_player_row()
	elif rank > 100:
		_view_mode = 1
		_rebuild_list()
		await get_tree().process_frame
		_scroll_to_player_row()
	# rank == 0 → not on the board yet, just stay in current view

func _player_rank_for_active_metric() -> int:
	# Prefer cached server top-100 if present; fall back to mock.
	# Демо-режим: строки подсунуты моком, и своего uid в них нет — ранг тоже
	# берём у мока. Иначе экран честно писал «101 место», хотя данные мока
	# говорят 47-е. Раньше это было незаметно: ранг спрашивала только кнопка
	# прыжка, теперь он висит в строке внизу постоянно.
	if _data_origin == "demo":
		return LeaderboardMock.get_player_rank(_active_metric)
	if _server_rows.has(_active_metric):
		var my_uid := LeaderboardClient.get_user_id()
		var rows : Array = _server_rows[_active_metric]
		for r in rows:
			if r is Dictionary and r.get("user_id", "") == my_uid:
				return int(r.get("rank", 0))
		# Not in top-100 — fall back to window lookup or mock
		if _server_window.has(_active_metric):
			var w : Array = _server_window[_active_metric]
			for r in w:
				if r is Dictionary and r.get("user_id", "") == my_uid:
					return int(r.get("rank", 0))
		# Unknown — return >100 to nudge into window view
		return 101
	return LeaderboardMock.get_player_rank(_active_metric)

func _scroll_to_player_row() -> void:
	var rank := LeaderboardMock.get_player_rank(_active_metric)
	var row_idx := -1
	if _view_mode == 0:
		row_idx = rank - 1
	else:
		var first := maxi(1, rank - 5)
		row_idx = 10 + 1 + (rank - first)
	if row_idx < 0:
		return
	var target_y := row_idx * ROW_H
	var scroll_h := _scroll.size.y
	var v := maxf(0.0, target_y - scroll_h * 0.5 + ROW_H * 0.5)
	_scroll.scroll_vertical = int(v)

# ── List rebuild ─────────────────────────────────────────────────────────────

func _rebuild_list() -> void:
	for c in _content.get_children():
		c.queue_free()
	var rows : Array = []
	var have_server := _server_rows.has(_active_metric)
	if have_server:
		if _view_mode == 0:
			rows = (_server_rows[_active_metric] as Array).duplicate(true)
		else:
			rows.append_array((_server_rows[_active_metric] as Array).slice(0, 10))
			rows.append({"separator": true})
			if _server_window.has(_active_metric):
				rows.append_array((_server_window[_active_metric] as Array).duplicate(true))
	else:
		if _view_mode == 0:
			rows = LeaderboardMock.get_top_n(_active_metric, 100)
		else:
			var top_rows := LeaderboardMock.get_top_n(_active_metric, 10)
			rows.append_array(top_rows)
			rows.append({"separator": true})
			var window := LeaderboardMock.get_window_around_player(_active_metric, 5)
			rows.append_array(window)
	# Mark player row when using live data
	if have_server and LeaderboardClient.is_ready():
		var my_uid := LeaderboardClient.get_user_id()
		for r in rows:
			if r is Dictionary and r.get("user_id", "") == my_uid:
				r["is_player"] = true
				r["name"] = "ТЫ"
	_update_origin_badge()
	_refresh_my_strip()

	# Первая тройка уходит на подиум, список начинается с 4-го места: дублировать
	# их в списке нечем, а место наверху экрана дорогое.
	var podium : Array = []
	for r in rows:
		if r is Dictionary and not r.has("separator") and int(r.get("rank", 0)) <= 3:
			podium.append(r)
	podium.sort_custom(func(a, b): return int(a["rank"]) < int(b["rank"]))
	_podium_ranks = []
	for r in podium:
		_podium_ranks.append(int(r["rank"]))
	_build_podium(podium)

	var list_rows : Array = []
	for r in rows:
		if r is Dictionary and not r.has("separator") and int(r.get("rank", 0)) <= 3:
			continue
		list_rows.append(r)

	_list_ranks = []
	for r in list_rows:
		if not r.has("separator"):
			_list_ranks.append(int(r.get("rank", 0)))

	var w : float = _scroll.size.x
	_content.custom_minimum_size = Vector2(w, list_rows.size() * ROW_H + 10.0)
	var cy := 4.0
	var alt := false
	for r in list_rows:
		if r.has("separator"):
			_add_separator_row(cy)
		else:
			_add_player_row(r, cy, alt)
			alt = not alt
		cy += ROW_H

func _add_separator_row(cy: float) -> void:
	var lbl := Label.new()
	lbl.add_theme_font_override("font", UI_FONT)
	lbl.add_theme_font_size_override("font_size", 14)
	_apply_text_fx(lbl)
	lbl.text                 = "•   •   •"
	lbl.modulate             = Color(0.45, 0.45, 0.50)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl.size                 = Vector2(_scroll.size.x, ROW_H)
	lbl.position             = Vector2(0.0, cy)
	lbl.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	_content.add_child(lbl)

func _add_player_row(r: Dictionary, cy: float, alt: bool) -> void:
	var w : float = _scroll.size.x
	var is_player := bool(r.get("is_player", false))
	var rank      := int(r["rank"])
	var pname     : String = str(r.get("name", r.get("display_name", "")))
	var score     := int(r["score"])

	# Подложка непрозрачная: сквозь прежние полупрозрачные строки просвечивала
	# кирпичная стена, и текст на ней не читался.
	UiKit.panel(_content, Vector2(2.0, cy + 1.0), Vector2(w - 4.0, ROW_H - 3.0),
		Color(0.13, 0.20, 0.11, 0.98) if is_player else (Color(0.11, 0.09, 0.06, 0.98) if alt else Color(0.08, 0.07, 0.05, 0.98)),
		8, Color(0.45, 0.90, 0.35, 0.95) if is_player else Color(0, 0, 0, 0))

	var rank_lbl := _label("%d" % rank, 14, Color(0.88, 0.84, 0.70),
		Vector2(6.0, cy), Vector2(40.0, ROW_H), _content)
	rank_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rank_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER

	if is_player:
		# Своя строка помечена СЛОВОМ, а не только цветом подложки.
		var you := _label("ТЫ", 11, Color(0.70, 1.0, 0.60),
			Vector2(50.0, cy), Vector2(26.0, ROW_H), _content)
		you.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	const AV_SZ : float = 22.0
	var av_x := 78.0
	_add_avatar(_content, String(r.get("avatar_skin", "classic")),
		int(r.get("avatar_fat", 0)), Vector2(av_x, cy + (ROW_H - AV_SZ) * 0.5), AV_SZ)

	var name_lbl := _label(pname, 13,
		Color(0.75, 1.0, 0.65) if is_player else Color(0.96, 0.96, 0.90),
		Vector2(av_x + AV_SZ + 8.0, cy), Vector2(w * 0.30, ROW_H), _content)
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_lbl.clip_text          = true

	var score_x := w * 0.46
	var pz := _make_icon(TEX_PIZZA, 18.0)
	pz.position     = Vector2(score_x, cy + (ROW_H - 18.0) * 0.5)
	pz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(pz)
	var score_lbl := _label(str(score), 13, Color(1.0, 0.87, 0.50),
		Vector2(score_x + 22.0, cy), Vector2(90.0, ROW_H), _content)
	score_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	_build_reward_block(_content, Vector2(w * 0.70, cy + (ROW_H - 16.0) * 0.5),
		w * 0.28, LeaderboardMock.reward_for_place(rank), 16.0)

func _reward_str(reward: Dictionary) -> String:
	var d := int(reward.get("dollars", 0))
	var t := int(reward.get("tokens",  0))
	if d > 0 and t > 0: return "+%d $ +%d ж" % [d, t]
	if d > 0:           return "+%d $" % d
	if t > 0:           return "+%d ж" % t
	return "—"

func _make_icon(tex: Texture2D, sz: float) -> TextureRect:
	var r := TextureRect.new()
	r.texture      = tex
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
	r.size         = Vector2(sz, sz)
	return r

func _fmt_duration(secs: float) -> String:
	var s := int(secs)
	var d := s / 86400
	s -= d * 86400
	var h := s / 3600
	s -= h * 3600
	var m := s / 60
	if d > 0: return "%dд %dч" % [d, h]
	if h > 0: return "%dч %dм" % [h, m]
	return "%dм" % m

# ── Lock overlay ─────────────────────────────────────────────────────────────

func _build_lock_overlay(vp: Vector2) -> void:
	_lock_overlay = Node2D.new()
	_lock_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	_lock_overlay.z_index = 5
	# Fade in after the slide-down: build everything at modulate.a = 0 and
	# tween up, so the modal arrives smoothly instead of snapping into view.
	_lock_overlay.modulate.a = 0.0
	add_child(_lock_overlay)
	var tw_in := create_tween()
	tw_in.tween_property(_lock_overlay, "modulate:a", 1.0, 0.25)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	# Dim cover sits over the central zone (where rows live), leaving the top
	# chrome visible so the user can still tap "back".
	var scale_y : float = vp.y / CANVAS_H
	var content_top : float = ZONE_Y * scale_y
	var dim := ColorRect.new()
	dim.color    = Color(0.02, 0.01, 0.0, 0.88)
	dim.size     = Vector2(vp.x, vp.y - content_top)
	dim.position = Vector2(0.0, content_top)
	_lock_overlay.add_child(dim)

	var dim_btn := Button.new()
	dim_btn.flat       = true
	dim_btn.focus_mode = Control.FOCUS_NONE
	dim_btn.size       = dim.size
	dim_btn.position   = dim.position
	dim_btn.pressed.connect(_show_lock_toast)
	_lock_overlay.add_child(dim_btn)

	var panel_w := 380.0
	var panel_h := 180.0
	var panel_x := (vp.x - panel_w) * 0.5
	var panel_y := content_top + (vp.y - content_top - panel_h) * 0.5

	var panel := ColorRect.new()
	panel.color    = Color(0.10, 0.08, 0.05, 0.96)
	panel.size     = Vector2(panel_w, panel_h)
	panel.position = Vector2(panel_x, panel_y)
	_lock_overlay.add_child(panel)

	var stripe := ColorRect.new()
	stripe.color    = Color(0.55, 0.85, 1.0, 0.70)
	stripe.size     = Vector2(panel_w, 2.0)
	stripe.position = Vector2(panel_x, panel_y)
	_lock_overlay.add_child(stripe)

	_draw_padlock(_lock_overlay, Vector2(panel_x + (panel_w - 38.0) * 0.5, panel_y + 14.0), 38.0)

	var title_lbl := Label.new()
	title_lbl.add_theme_font_override("font", UI_FONT)
	title_lbl.add_theme_font_size_override("font_size", 16)
	_apply_text_fx(title_lbl)
	title_lbl.text                 = "ЛИДЕРБОРД ЗАКРЫТ"
	title_lbl.modulate             = Color(0.85, 0.95, 1.0)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.size                 = Vector2(panel_w, 24.0)
	title_lbl.position             = Vector2(panel_x, panel_y + 64.0)
	_lock_overlay.add_child(title_lbl)

	var desc_lbl := Label.new()
	desc_lbl.add_theme_font_override("font", UI_FONT)
	desc_lbl.add_theme_font_size_override("font_size", 11)
	_apply_text_fx(desc_lbl)
	desc_lbl.text                 = "Открой Бесконечный режим —\nпобеди NinjaFoot в кампании"
	desc_lbl.modulate             = Color(0.65, 0.70, 0.78)
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.autowrap_mode        = TextServer.AUTOWRAP_WORD
	desc_lbl.size                 = Vector2(panel_w - 32.0, 40.0)
	desc_lbl.position             = Vector2(panel_x + 16.0, panel_y + 92.0)
	_lock_overlay.add_child(desc_lbl)

	var btn_w := 160.0
	var btn_h := 32.0
	var btn_x := panel_x + (panel_w - btn_w) * 0.5
	var btn_y := panel_y + panel_h - btn_h - 12.0

	var btn_bg := ColorRect.new()
	btn_bg.color    = Color(0.18, 0.18, 0.36, 0.95)
	btn_bg.size     = Vector2(btn_w, btn_h)
	btn_bg.position = Vector2(btn_x, btn_y)
	_lock_overlay.add_child(btn_bg)

	var btn_lbl := Label.new()
	btn_lbl.add_theme_font_override("font", UI_FONT)
	btn_lbl.add_theme_font_size_override("font_size", 13)
	_apply_text_fx(btn_lbl)
	btn_lbl.text                 = "К СЮЖЕТУ"
	btn_lbl.modulate             = Color(0.85, 0.90, 1.0)
	btn_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	btn_lbl.size                 = Vector2(btn_w, btn_h)
	btn_lbl.position             = Vector2(btn_x, btn_y)
	btn_lbl.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	_lock_overlay.add_child(btn_lbl)

	var btn := Button.new()
	btn.flat       = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.size       = Vector2(btn_w, btn_h)
	btn.position   = Vector2(btn_x, btn_y)
	btn.pressed.connect(_on_close)
	_lock_overlay.add_child(btn)

	if is_instance_valid(_my_pos_btn):
		_my_pos_btn.visible = false

func _draw_padlock(parent: Node, pos: Vector2, sz: float) -> void:
	var col := Color(0.85, 0.95, 1.0)
	var body_w := sz
	var body_h := sz * 0.55
	var body_y := pos.y + sz * 0.42
	var body := ColorRect.new()
	body.color    = col
	body.size     = Vector2(body_w, body_h)
	body.position = Vector2(pos.x, body_y)
	parent.add_child(body)
	var shk_w := sz * 0.70
	var shk_h := sz * 0.46
	var shk_x := pos.x + (sz - shk_w) * 0.5
	var shk_y := pos.y
	var top := ColorRect.new()
	top.color    = col
	top.size     = Vector2(shk_w, 4.0)
	top.position = Vector2(shk_x, shk_y)
	parent.add_child(top)
	var lf := ColorRect.new()
	lf.color    = col
	lf.size     = Vector2(4.0, shk_h)
	lf.position = Vector2(shk_x, shk_y)
	parent.add_child(lf)
	var rt := ColorRect.new()
	rt.color    = col
	rt.size     = Vector2(4.0, shk_h)
	rt.position = Vector2(shk_x + shk_w - 4.0, shk_y)
	parent.add_child(rt)
	var key := ColorRect.new()
	key.color    = Color(0.08, 0.08, 0.10)
	key.size     = Vector2(sz * 0.18, sz * 0.20)
	key.position = Vector2(pos.x + (sz - sz * 0.18) * 0.5, body_y + body_h * 0.25)
	parent.add_child(key)

func _show_lock_toast() -> void:
	var vp := get_viewport().get_visible_rect().size
	if is_instance_valid(_toast_node):
		_toast_node.queue_free()
	_toast_node = Node2D.new()
	_toast_node.process_mode = Node.PROCESS_MODE_ALWAYS
	_toast_node.z_index = 10
	add_child(_toast_node)
	var toast_w := 320.0
	var toast_h := 36.0
	var toast_x := (vp.x - toast_w) * 0.5
	var toast_y := vp.y * 0.16
	var bg := ColorRect.new()
	bg.color    = Color(0.10, 0.08, 0.05, 0.96)
	bg.size     = Vector2(toast_w, toast_h)
	bg.position = Vector2(toast_x, toast_y)
	_toast_node.add_child(bg)
	var stripe := ColorRect.new()
	stripe.color    = Color(1.0, 0.55, 0.30)
	stripe.size     = Vector2(toast_w, 2.0)
	stripe.position = bg.position
	_toast_node.add_child(stripe)
	var lbl := Label.new()
	lbl.add_theme_font_override("font", UI_FONT)
	lbl.add_theme_font_size_override("font_size", 11)
	_apply_text_fx(lbl)
	lbl.text                 = "Сначала открой Бесконечный режим"
	lbl.modulate             = Color(1.0, 0.85, 0.65)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl.size                 = bg.size
	lbl.position             = bg.position
	_toast_node.add_child(lbl)
	var tw := _toast_node.create_tween()
	tw.tween_interval(1.7)
	tw.tween_property(_toast_node, "modulate:a", 0.0, 0.30)
	tw.tween_callback(_toast_node.queue_free)

# ── Dev / close ──────────────────────────────────────────────────────────────

func _build_help_pill(pos: Vector2, accent: Color, metric: int) -> void:
	const PILL_W : float = 22.0
	const PILL_H : float = 18.0
	var bg := ColorRect.new()
	bg.color    = Color(0.05, 0.07, 0.12, 0.95)
	bg.size     = Vector2(PILL_W, PILL_H)
	bg.position = pos
	_overlay.add_child(bg)

	var stripe := ColorRect.new()
	stripe.color    = Color(accent.r, accent.g, accent.b, 0.70)
	stripe.size     = Vector2(PILL_W, 2.0)
	stripe.position = pos
	_overlay.add_child(stripe)

	var lbl := Label.new()
	lbl.add_theme_font_override("font", UI_FONT)
	lbl.add_theme_font_size_override("font_size", 11)
	_apply_text_fx(lbl)
	lbl.text                 = "?"
	lbl.modulate             = Color(accent.r, accent.g, accent.b, 0.95)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl.size                 = Vector2(PILL_W, PILL_H)
	lbl.position             = pos
	lbl.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(lbl)

	var btn := Button.new()
	btn.flat       = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.size       = Vector2(PILL_W + 12.0, PILL_H + 12.0)
	btn.position   = pos - Vector2(6.0, 6.0)
	btn.pressed.connect(_show_metric_tooltip.bind(metric))
	_overlay.add_child(btn)

func _show_metric_tooltip(metric: int) -> void:
	var title : String
	var body  : String
	if metric == LeaderboardMock.Metric.BEST:
		title = "РЕКОРД ЗАБЕГА"
		body  = "Лучший результат за один забег в Бесконечном режиме за неделю."
	else:
		title = "ГОРА ПИЦЦ"
		body  = "Сумма пицц за все твои забеги в Бесконечном режиме за неделю."
	var vp := get_viewport().get_visible_rect().size
	if is_instance_valid(_toast_node):
		_toast_node.queue_free()
	_toast_node = Node2D.new()
	_toast_node.process_mode = Node.PROCESS_MODE_ALWAYS
	_toast_node.z_index = 15
	add_child(_toast_node)

	var panel_w := 360.0
	var panel_h := 110.0
	var panel_x := (vp.x - panel_w) * 0.5
	# Position just below the central zone's top edge.
	var panel_y : float = ZONE_Y * (vp.y / CANVAS_H) + 4.0

	# Dim that closes the tooltip on tap outside
	var dim := Button.new()
	dim.flat       = true
	dim.focus_mode = Control.FOCUS_NONE
	dim.size       = vp
	dim.position   = Vector2.ZERO
	dim.pressed.connect(func():
		if is_instance_valid(_toast_node):
			_toast_node.queue_free()
	)
	_toast_node.add_child(dim)

	var bg := ColorRect.new()
	bg.color    = Color(0.07, 0.06, 0.04, 0.97)
	bg.size     = Vector2(panel_w, panel_h)
	bg.position = Vector2(panel_x, panel_y)
	_toast_node.add_child(bg)

	var stripe := ColorRect.new()
	stripe.color    = Color(1.00, 0.85, 0.35, 0.85)
	stripe.size     = Vector2(panel_w, 2.0)
	stripe.position = Vector2(panel_x, panel_y)
	_toast_node.add_child(stripe)

	var title_lbl := Label.new()
	title_lbl.add_theme_font_override("font", UI_FONT)
	title_lbl.add_theme_font_size_override("font_size", 14)
	_apply_text_fx(title_lbl)
	title_lbl.text                 = title
	title_lbl.modulate             = CLR_GOLD
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.size                 = Vector2(panel_w, 22.0)
	title_lbl.position             = Vector2(panel_x, panel_y + 8.0)
	title_lbl.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	_toast_node.add_child(title_lbl)

	var body_lbl := Label.new()
	body_lbl.add_theme_font_override("font", UI_FONT)
	body_lbl.add_theme_font_size_override("font_size", 11)
	_apply_text_fx(body_lbl)
	body_lbl.text                 = body
	body_lbl.modulate             = Color(0.85, 0.85, 0.78)
	body_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_TOP
	body_lbl.autowrap_mode        = TextServer.AUTOWRAP_WORD
	body_lbl.size                 = Vector2(panel_w - 24.0, 64.0)
	body_lbl.position             = Vector2(panel_x + 12.0, panel_y + 34.0)
	body_lbl.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	_toast_node.add_child(body_lbl)

func _on_dev_prize_test() -> void:
	if _hud and _hud.has_method("_show_prize_claim_modal"):
		_hud._show_prize_claim_modal(LeaderboardMock.make_mock_prize_reward())

# ── Server fetch ─────────────────────────────────────────────────────────────

func _fetch_from_server_async() -> void:
	if _fetch_busy:
		return
	if not LeaderboardClient.is_ready():
		# Auth still pending — wait, then retry
		await get_tree().create_timer(0.5).timeout
		if not LeaderboardClient.is_ready():
			_fall_back_to_mock()
			return
	_fetch_busy = true
	var captured_metric := _active_metric
	var resp = await LeaderboardClient.fetch_leaderboard(captured_metric, 100)
	_fetch_busy = false
	if not resp.ok:
		push_warning("[Leaderboard] fetch failed: %s" % str(resp.get("error", "")))
		if captured_metric == _active_metric:
			_fall_back_to_mock()
		return
	_server_rows[captured_metric] = resp.data.get("rows", [])
	_data_origin = "live"
	if captured_metric == _active_metric:
		_rebuild_list()

func _fall_back_to_mock() -> void:
	# Inject mock rows so _rebuild_list can show something
	if not _server_rows.has(_active_metric):
		var mock_rows := LeaderboardMock.get_top_n(_active_metric, 100)
		for r in mock_rows:
			r["avatar_skin"] = "classic"
			r["avatar_fat"]  = 0
		_server_rows[_active_metric] = mock_rows
	_data_origin = "demo"
	_rebuild_list()

func _show_loading_state() -> void:
	for c in _content.get_children():
		c.queue_free()
	var vp_w : float = (ZONE_W) * (get_viewport().get_visible_rect().size.x / CANVAS_W)
	_content.custom_minimum_size = Vector2(vp_w, _scroll.size.y)
	# "Загрузка…" centered in the scroll viewport
	var lbl := Label.new()
	lbl.add_theme_font_override("font", UI_FONT)
	lbl.add_theme_font_size_override("font_size", 14)
	_apply_text_fx(lbl)
	lbl.text                 = "Загрузка…"
	lbl.modulate             = Color(0.65, 0.65, 0.65)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl.size                 = Vector2(vp_w, _scroll.size.y)
	lbl.position             = Vector2(0.0, 0.0)
	lbl.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	_content.add_child(lbl)
	# Subtle pulsing tween
	var tw := lbl.create_tween().set_loops()
	tw.tween_property(lbl, "modulate:a", 0.35, 0.55).set_trans(Tween.TRANS_SINE)
	tw.tween_property(lbl, "modulate:a", 1.0, 0.55).set_trans(Tween.TRANS_SINE)
	_update_origin_badge()

func _fetch_window_async() -> void:
	if _fetch_busy:
		return
	if not LeaderboardClient.is_ready():
		return
	_fetch_busy = true
	var captured_metric := _active_metric
	var resp = await LeaderboardClient.fetch_window(captured_metric, 5)
	_fetch_busy = false
	if not resp.ok:
		return
	_server_window[captured_metric] = resp.data.get("rows", [])

func _update_origin_badge() -> void:
	# "ДЕМО ДАННЫЕ" badge removed by request — the leaderboard reveals mock
	# rows silently until the server fetch lands. Keep the cleanup of any
	# leftover label from older sessions just in case.
	if is_instance_valid(_origin_lbl):
		_origin_lbl.queue_free()
	_origin_lbl = null

func _on_close() -> void:
	if not is_instance_valid(_slide_root):
		queue_free()
		return
	# Reverse the camera pan: leaders slides DOWN, main menu drops back into view.
	var vp := get_viewport().get_visible_rect().size
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_slide_root, "position", Vector2(0.0, vp.y), SLIDE_TIME)\
		.set_trans(SLIDE_TRANS).set_ease(SLIDE_EASE_OUT)
	# Lock overlay lives outside _slide_root (added directly to self), so the
	# slide-down doesn't carry it. Tween its y in lockstep so the padlock
	# panel exits the screen together with the leaderboard chrome.
	if is_instance_valid(_lock_overlay):
		tw.tween_property(_lock_overlay, "position:y", vp.y, SLIDE_TIME)\
			.set_trans(SLIDE_TRANS).set_ease(SLIDE_EASE_OUT)
	tw.chain().tween_callback(Callable(self, "queue_free"))
	if _hud != null and _hud.has_method("_on_leaders_close_anim_start"):
		_hud._on_leaders_close_anim_start(SLIDE_TIME, SLIDE_TRANS, SLIDE_EASE_OUT)
