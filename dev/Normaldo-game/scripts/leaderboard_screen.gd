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
var _tab_best_bg  : ColorRect = null
var _tab_total_bg : ColorRect = null
var _tab_best_lbl : Label     = null
var _tab_total_lbl: Label     = null
var _my_pos_btn   : Node2D    = null
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

	# Reset-timer label — pinned RIGHT under the title text. Same X offset as
	# the title so it sits centred under "ЛИДЕРЫ".
	_timer_lbl = Label.new()
	_timer_lbl.add_theme_font_override("font", UI_FONT)
	_timer_lbl.add_theme_font_size_override("font_size", 11)
	_apply_text_fx(_timer_lbl)
	_timer_lbl.text                 = "Призы через %s" % _fmt_duration(_reset_seconds_left)
	_timer_lbl.modulate             = Color(0.92, 0.85, 0.55)
	_timer_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timer_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_timer_lbl.size                 = Vector2(vp.x, 14.0)
	# y = title bottom (TITLE_Y + TITLE_H) - small overlap to tuck under.
	_timer_lbl.position             = Vector2(TITLE_X_OFFSET * scale_x,
			(TITLE_Y + TITLE_H - 4.0) * scale_y)
	_timer_lbl.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	_slide_root.add_child(_timer_lbl)

	# Tabs row — placed just above the central zone.
	var tab_y := ZONE_Y * scale_y - TAB_H - 2.0
	var tab_w := vp.x * 0.5

	_tab_best_bg = ColorRect.new()
	_tab_best_bg.size     = Vector2(tab_w, TAB_H)
	_tab_best_bg.position = Vector2(0.0, tab_y)
	_overlay.add_child(_tab_best_bg)

	_tab_best_lbl = Label.new()
	_tab_best_lbl.add_theme_font_override("font", UI_FONT)
	_tab_best_lbl.add_theme_font_size_override("font_size", 13)
	_apply_text_fx(_tab_best_lbl)
	_tab_best_lbl.text                 = "РЕКОРД ЗАБЕГА"
	_tab_best_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tab_best_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_tab_best_lbl.size                 = _tab_best_bg.size
	_tab_best_lbl.position             = _tab_best_bg.position
	_tab_best_lbl.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(_tab_best_lbl)

	var btn_best := Button.new()
	btn_best.flat       = true
	btn_best.focus_mode = Control.FOCUS_NONE
	btn_best.size       = _tab_best_bg.size
	btn_best.position   = _tab_best_bg.position
	btn_best.pressed.connect(_on_tab_best)
	_overlay.add_child(btn_best)

	_build_help_pill(_tab_best_bg.position + Vector2(tab_w - 30.0, (TAB_H - 18.0) * 0.5),
		Color(1.00, 0.85, 0.35), LeaderboardMock.Metric.BEST)

	_tab_total_bg = ColorRect.new()
	_tab_total_bg.size     = Vector2(tab_w, TAB_H)
	_tab_total_bg.position = Vector2(tab_w, tab_y)
	_overlay.add_child(_tab_total_bg)

	_tab_total_lbl = Label.new()
	_tab_total_lbl.add_theme_font_override("font", UI_FONT)
	_tab_total_lbl.add_theme_font_size_override("font_size", 13)
	_apply_text_fx(_tab_total_lbl)
	_tab_total_lbl.text                 = "ГОРА ПИЦЦ"
	_tab_total_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tab_total_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_tab_total_lbl.size                 = _tab_total_bg.size
	_tab_total_lbl.position             = _tab_total_bg.position
	_tab_total_lbl.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(_tab_total_lbl)

	var btn_total := Button.new()
	btn_total.flat       = true
	btn_total.focus_mode = Control.FOCUS_NONE
	btn_total.size       = _tab_total_bg.size
	btn_total.position   = _tab_total_bg.position
	btn_total.pressed.connect(_on_tab_total)
	_overlay.add_child(btn_total)

	_build_help_pill(_tab_total_bg.position + Vector2(tab_w - 30.0, (TAB_H - 18.0) * 0.5),
		Color(1.00, 0.85, 0.35), LeaderboardMock.Metric.TOTAL)

	# Scroll list — confined to the central zone.
	var zone_pos  := Vector2(ZONE_X * scale_x, ZONE_Y * scale_y)
	var zone_size := Vector2(ZONE_W * scale_x, ZONE_H * scale_y)
	_scroll = ScrollContainer.new()
	_scroll.position = zone_pos
	_scroll.size     = zone_size
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_slide_root.add_child(_scroll)

	_content = Control.new()
	_scroll.add_child(_content)

	# Floating "My position" button (bottom-right) + dev prize trigger.
	_build_my_position_btn(vp)
	if DevFlags.ENABLED:
		_build_dev_prize_btn(vp)

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
const _PRESS_SCALE : float = 0.90
const _PRESS_TIME  : float = 0.07
func _press_anim(visual_root: Control, pressed: bool) -> void:
	if not is_instance_valid(visual_root):
		return
	var target := Vector2.ONE * (_PRESS_SCALE if pressed else 1.0)
	var tw := create_tween()
	tw.tween_property(visual_root, "scale", target, _PRESS_TIME)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

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

func _build_my_position_btn(vp: Vector2) -> void:
	const BTN_W : float = 160.0
	const BTN_H : float = 36.0
	var btn_x := vp.x - BTN_W - 12.0
	var btn_y := vp.y - BTN_H - 12.0
	_my_pos_btn = Node2D.new()
	_my_pos_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	_my_pos_btn.position = Vector2(btn_x, btn_y)
	add_child(_my_pos_btn)

	var bg := ColorRect.new()
	bg.color = Color(0.12, 0.32, 0.16, 0.95)
	bg.size  = Vector2(BTN_W, BTN_H)
	_my_pos_btn.add_child(bg)

	var stripe := ColorRect.new()
	stripe.color = Color(0.45, 0.85, 0.30, 0.80)
	stripe.size  = Vector2(BTN_W, 2.0)
	_my_pos_btn.add_child(stripe)

	var lbl := Label.new()
	lbl.add_theme_font_override("font", UI_FONT)
	lbl.add_theme_font_size_override("font_size", 13)
	_apply_text_fx(lbl)
	lbl.text                 = "МОЯ ПОЗИЦИЯ"
	lbl.modulate             = Color(0.85, 1.0, 0.65)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl.size                 = Vector2(BTN_W, BTN_H)
	lbl.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	_my_pos_btn.add_child(lbl)

	var btn := Button.new()
	btn.flat       = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.size       = Vector2(BTN_W, BTN_H)
	btn.pressed.connect(_on_my_position)
	_my_pos_btn.add_child(btn)

func _build_dev_prize_btn(vp: Vector2) -> void:
	const BTN_W : float = 110.0
	const BTN_H : float = 28.0
	var pos := Vector2(10.0, vp.y - BTN_H - 12.0)
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

func _refresh_tab_visual() -> void:
	if _active_metric == LeaderboardMock.Metric.BEST:
		_tab_best_bg.color      = CLR_TAB_ACTV
		_tab_total_bg.color     = CLR_TAB_DIM
		_tab_best_lbl.modulate  = CLR_GOLD
		_tab_total_lbl.modulate = Color(0.50, 0.45, 0.40)
	else:
		_tab_best_bg.color      = CLR_TAB_DIM
		_tab_total_bg.color     = CLR_TAB_ACTV
		_tab_best_lbl.modulate  = Color(0.50, 0.45, 0.40)
		_tab_total_lbl.modulate = CLR_GOLD

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
	var vp_w : float = (ZONE_W) * (get_viewport().get_visible_rect().size.x / CANVAS_W)
	# Bottom padding so the last rows can be scrolled above the floating
	# "Моя позиция" button (button is 36 tall + 12 margin + 12 breathing room).
	const BOTTOM_GAP : float = 72.0
	var total_h := rows.size() * ROW_H + 16.0 + BOTTOM_GAP
	_content.custom_minimum_size = Vector2(vp_w, total_h)
	var cy := 6.0
	var alt := false
	for r in rows:
		if r.has("separator"):
			_add_separator_row(cy)
		else:
			_add_player_row(r, cy, alt)
			alt = not alt
		cy += ROW_H

func _add_separator_row(cy: float) -> void:
	var vp_w : float = (ZONE_W) * (get_viewport().get_visible_rect().size.x / CANVAS_W)
	var lbl := Label.new()
	lbl.add_theme_font_override("font", UI_FONT)
	lbl.add_theme_font_size_override("font_size", 14)
	_apply_text_fx(lbl)
	lbl.text                 = "•   •   •"
	lbl.modulate             = Color(0.45, 0.45, 0.50)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl.size                 = Vector2(vp_w, ROW_H)
	lbl.position             = Vector2(0.0, cy)
	lbl.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	_content.add_child(lbl)

func _add_player_row(r: Dictionary, cy: float, alt: bool) -> void:
	var vp_w : float = (ZONE_W) * (get_viewport().get_visible_rect().size.x / CANVAS_W)
	var is_player := bool(r.get("is_player", false))
	var rank      := int(r["rank"])
	var pname     : String = str(r.get("name", r.get("display_name", "")))
	var score     := int(r["score"])
	var av_skin   : String = str(r.get("avatar_skin", "classic"))
	var av_fat    : int    = int(r.get("avatar_fat", 0))

	var bg := ColorRect.new()
	if is_player:
		bg.color = CLR_ROW_PLR
	else:
		bg.color = CLR_ROW_BG_A if alt else CLR_ROW_BG_B
	bg.size     = Vector2(vp_w, ROW_H - 1.0)
	bg.position = Vector2(0.0, cy)
	_content.add_child(bg)

	# Rank
	var rank_col := Color(0.85, 0.80, 0.65)
	if rank == 1:   rank_col = CLR_GOLD
	elif rank == 2: rank_col = CLR_SILVER
	elif rank == 3: rank_col = CLR_BRONZE

	var rank_lbl := Label.new()
	rank_lbl.add_theme_font_override("font", UI_FONT)
	rank_lbl.add_theme_font_size_override("font_size", 14)
	_apply_text_fx(rank_lbl)
	rank_lbl.text                 = "%d" % rank
	rank_lbl.modulate             = rank_col
	rank_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rank_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	rank_lbl.size                 = Vector2(44.0, ROW_H)
	rank_lbl.position             = Vector2(8.0, cy)
	rank_lbl.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	_content.add_child(rank_lbl)

	if is_player:
		var marker := Label.new()
		marker.add_theme_font_override("font", UI_FONT)
		marker.add_theme_font_size_override("font_size", 14)
		_apply_text_fx(marker)
		marker.text                 = "►"
		marker.modulate             = Color(0.55, 1.0, 0.55)
		marker.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		marker.size                 = Vector2(14.0, ROW_H)
		marker.position             = Vector2(58.0, cy)
		marker.mouse_filter         = Control.MOUSE_FILTER_IGNORE
		_content.add_child(marker)

	# Avatar (just to the left of the name)
	const AV_SZ : float = 24.0
	var av_x := 78.0
	var av := TextureRect.new()
	av.texture       = SkinRegistry.get_avatar_texture(av_skin, av_fat)
	av.stretch_mode  = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	av.expand_mode   = TextureRect.EXPAND_IGNORE_SIZE
	av.size          = Vector2(AV_SZ, AV_SZ)
	av.position      = Vector2(av_x, cy + (ROW_H - AV_SZ) * 0.5)
	av.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	_content.add_child(av)

	# Name
	var name_lbl := Label.new()
	name_lbl.add_theme_font_override("font", UI_FONT)
	name_lbl.add_theme_font_size_override("font_size", 13)
	_apply_text_fx(name_lbl)
	name_lbl.text                 = pname
	name_lbl.modulate             = Color(0.70, 1.0, 0.60) if is_player else Color(0.95, 0.95, 0.85)
	name_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	name_lbl.clip_text            = true
	name_lbl.size                 = Vector2(vp_w * 0.36, ROW_H)
	name_lbl.position             = Vector2(av_x + AV_SZ + 8.0, cy)
	name_lbl.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	_content.add_child(name_lbl)

	# Score (pizza icon + number)
	var score_x := vp_w * 0.58
	var pz_icon := _make_icon(TEX_PIZZA, 18.0)
	pz_icon.position = Vector2(score_x, cy + (ROW_H - 18.0) * 0.5)
	_content.add_child(pz_icon)

	var score_lbl := Label.new()
	score_lbl.add_theme_font_override("font", UI_FONT)
	score_lbl.add_theme_font_size_override("font_size", 13)
	_apply_text_fx(score_lbl)
	score_lbl.text                 = str(score)
	score_lbl.modulate             = Color(1.0, 0.85, 0.50)
	score_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	score_lbl.size                 = Vector2(80.0, ROW_H)
	score_lbl.position             = Vector2(score_x + 22.0, cy)
	score_lbl.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	_content.add_child(score_lbl)

	# Reward (right side) — text + small token icon (the word/letter "ж" is
	# replaced by the actual token glyph for visual consistency with quests
	# and book screens).
	var reward := LeaderboardMock.reward_for_place(rank)
	var reward_d : int = int(reward.get("dollars", 0))
	var reward_t : int = int(reward.get("tokens", 0))
	var rwd_text : String
	if reward_d > 0 and reward_t > 0:
		rwd_text = "+%d $  +%d" % [reward_d, reward_t]
	elif reward_d > 0:
		rwd_text = "+%d $" % reward_d
	elif reward_t > 0:
		rwd_text = "+%d" % reward_t
	else:
		rwd_text = "—"
	var has_token : bool = reward_t > 0

	const _RWD_FONT_SZ_ROW : int   = 11
	const _ROW_TKN_SZ      : float = 14.0
	const _ROW_TKN_GAP     : float = 3.0
	# Right-anchored layout: icon hugs the right edge of the reward column,
	# text is right-aligned to the icon's left edge.
	var rwd_right_x : float = vp_w - 10.0
	var rwd_lbl := Label.new()
	rwd_lbl.add_theme_font_override("font", UI_FONT)
	rwd_lbl.add_theme_font_size_override("font_size", _RWD_FONT_SZ_ROW)
	_apply_text_fx(rwd_lbl)
	rwd_lbl.text                 = rwd_text
	rwd_lbl.modulate             = CLR_GOLD
	rwd_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rwd_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	var lbl_right_pad : float = (_ROW_TKN_SZ + _ROW_TKN_GAP) if has_token else 0.0
	rwd_lbl.size                 = Vector2(170.0, ROW_H)
	rwd_lbl.position             = Vector2(rwd_right_x - 170.0 - lbl_right_pad, cy)
	rwd_lbl.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	_content.add_child(rwd_lbl)

	if has_token:
		var tkn := _make_icon(TEX_TOKEN, _ROW_TKN_SZ)
		tkn.position = Vector2(rwd_right_x - _ROW_TKN_SZ,
				cy + (ROW_H - _ROW_TKN_SZ) * 0.5)
		_content.add_child(tkn)

	# Bottom thin line
	var sep := ColorRect.new()
	sep.color    = Color(0.14, 0.12, 0.08, 0.40)
	sep.size     = Vector2(vp_w, 1.0)
	sep.position = Vector2(0.0, cy + ROW_H - 1.0)
	_content.add_child(sep)

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
