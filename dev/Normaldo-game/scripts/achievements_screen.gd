extends Node2D
class_name AchievementsScreen

const UI_FONT        := preload("res://assets/fonts/RussoOne-Regular.ttf")
const TEX_DOLLAR     := preload("res://assets/items/dollar.png")
const TEX_MONEYBAG   := preload("res://assets/items/money_bag.png")
const TEX_TOKEN      := preload("res://assets/items/token.png")
const TEX_BG_BOOK    := preload("res://assets/ui/book/bg_book.png")
const TEX_BACK_ARROW := preload("res://assets/ui/quests/back_arrow.png")

const CLR_BG      := Color(0.06, 0.04, 0.02, 0.96)
const CLR_CHAPTER := Color(0.08, 0.07, 0.04, 0.95)
const CLR_QUEST   := Color(0.10, 0.08, 0.05, 0.92)
const CLR_DONE    := Color(0.06, 0.06, 0.06, 0.70)
const CLR_READY   := Color(0.10, 0.20, 0.08, 0.95)
const CLR_GOLD    := Color(1.00, 0.85, 0.35)
const CLR_ACCENT  := Color(0.78, 0.58, 0.20, 0.90)

# ── Layout (canvas pixels 430×192) — same conventions as quests_screen ──────
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
# Central black zone where the chapters + quests scroll.
const ZONE_X : float = 30.0
const ZONE_Y : float = 38.0
const ZONE_W : float = 370.0
const ZONE_H : float = 148.0
# Slide-down transition — identical to quests / slots.
const SLIDE_TIME      : float = 0.45
const SLIDE_TRANS     : int   = Tween.TRANS_QUAD
const SLIDE_EASE_IN   : int   = Tween.EASE_IN
const SLIDE_EASE_OUT  : int   = Tween.EASE_IN

# Legacy values still used by row builders below.
const HDR_H     := 46.0
const RES_H     := 32.0
const PAD       := 10.0
const CH_ROW_H  := 34.0
const Q_ROW_H   := 70.0
const CH_GAP    := 8.0
const CLAIM_W   := 80.0

var _hud          : Node = null
# Slide-down container that wraps every visible element.
var _slide_root   : Control = null
var _scroll_con   : ScrollContainer = null
var _content      : Control = null
# Legacy alias — row builders parent into `_overlay`; we point it at the slide
# root so they end up inside the animated container.
var _overlay      : Control = null
var _dollar_lbl   : Label = null
var _token_lbl    : Label = null
var _dollar_target : Vector2 = Vector2.ZERO
var _token_target  : Vector2 = Vector2.ZERO
var _claim_busy   : bool = false

# Per-story y-offset inside `_content`, captured while `_build` walks the list.
# Lets the notification router (E3) ask the screen to scroll directly to a
# claimable chapter on open instead of dropping the player at the top.
var _story_row_y     : Dictionary = {}
var _focus_story_idx : int        = -1

func setup(hud: Node, focus_story_idx: int = -1) -> void:
	_hud = hud
	_focus_story_idx = focus_story_idx

func _ready() -> void:
	var vp := get_viewport().get_visible_rect().size
	_build(vp)
	# Camera-pan-down entrance — sit BELOW the menu and rise into view while
	# HUD slides the main-menu chrome + scene up off-screen in lock-step.
	_slide_root.position = Vector2(0.0, vp.y)
	var tw := create_tween()
	tw.tween_property(_slide_root, "position", Vector2.ZERO, SLIDE_TIME)\
		.set_trans(SLIDE_TRANS).set_ease(SLIDE_EASE_IN)
	if _hud != null and _hud.has_method("_on_book_open_anim_start"):
		_hud._on_book_open_anim_start(SLIDE_TIME, SLIDE_TRANS, SLIDE_EASE_IN)
	QuestManager.quests_updated.connect(_on_quests_updated)
	SaveData.data_changed.connect(_on_data_changed)

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
	_overlay = _slide_root   # legacy alias for row-builders

	# Full-screen pixel-art background.
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

	# ── Top-left back button (with press-shrink) ───────────────────────────
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
	title_lbl.text                 = "КНИГА УЧИТЕЛЯ"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	title_lbl.size                 = Vector2(vp.x, TITLE_H * scale_y)
	title_lbl.position             = Vector2(TITLE_X_OFFSET * scale_x, TITLE_Y * scale_y)
	title_lbl.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	_slide_root.add_child(title_lbl)

	# ── Top-right resources ────────────────────────────────────────────────
	_build_resource_strip(vp)

	# ── Central "black zone" — ScrollContainer for chapters / quests ───────
	var zone_pos  := Vector2(ZONE_X * scale_x, ZONE_Y * scale_y)
	var zone_size := Vector2(ZONE_W * scale_x, ZONE_H * scale_y)
	var content_w := zone_size.x - PAD * 2.0

	_scroll_con = ScrollContainer.new()
	_scroll_con.position               = zone_pos
	_scroll_con.size                   = zone_size
	_scroll_con.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# Hide the vertical scrollbar — drag still works, but the grey rail
	# overlaying the chapter rows looked dated.
	_scroll_con.vertical_scroll_mode   = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_scroll_con.mouse_filter           = Control.MOUSE_FILTER_PASS
	# scroll_deadzone > 0 lets the container steal a touch from its child
	# buttons once the finger moves past the threshold — required so list
	# scrolling works on mobile, where every tap initially hits a row. 18 px
	# tuned for Retina: low enough to feel responsive, high enough to avoid
	# accidentally swallowing taps.
	_scroll_con.set("scroll_deadzone", 18)
	_slide_root.add_child(_scroll_con)

	var total_h := _measure_content_height()
	_content = Control.new()
	_content.custom_minimum_size = Vector2(zone_size.x, total_h + 48.0)
	_content.mouse_filter        = Control.MOUSE_FILTER_PASS
	_scroll_con.add_child(_content)

	var cy := 8.0
	for ch_idx in QuestManager.CHAPTERS.size():
		var chapter := QuestManager.CHAPTERS[ch_idx] as Dictionary
		var q_idxs  := chapter["quests"] as Array

		cy = _add_chapter_row(_content, cy, content_w, chapter, q_idxs)

		for qi in q_idxs:
			# Snapshot the row's top-y BEFORE building it — that's the value
			# we'd want to land on if the notification asked us to focus this
			# chapter. Tracked regardless of whether the deep-link is active
			# so the dictionary stays consistent.
			_story_row_y[int(qi)] = cy
			cy = _add_quest_row(_content, cy, content_w, qi)

		cy += CH_GAP

	# If the screen was opened with a focus index, scroll the container so the
	# requested story lands near the top of the viewport. Deferred a frame to
	# let the ScrollContainer compute its child sizes first.
	if _focus_story_idx >= 0 and _story_row_y.has(_focus_story_idx):
		call_deferred("_scroll_to_focus")

	# Force every decorative Control in the scrolled content to IGNORE mouse
	# input — by default ColorRect uses MOUSE_FILTER_STOP, which eats finger
	# drags before the ScrollContainer sees them. Buttons are left alone.
	_passthrough_scroll_inputs(_content)

# Jump the scroll viewport to the row recorded for `_focus_story_idx`. Backs
# off by 12 px so the chapter header above the row stays readable; the value
# is clamped automatically by ScrollContainer.
func _scroll_to_focus() -> void:
	if not is_instance_valid(_scroll_con):
		return
	if not _story_row_y.has(_focus_story_idx):
		return
	var y : int = int(_story_row_y[_focus_story_idx]) - 12
	_scroll_con.scroll_vertical = maxi(0, y)
	# One-shot — clear so a later replay of the same screen behaves normally.
	_focus_story_idx = -1

# Walk a subtree and flip every non-Button Control to MOUSE_FILTER_IGNORE so
# the parent ScrollContainer reliably gets finger drags. Symmetrical with the
# helper in quests_screen.gd.
func _passthrough_scroll_inputs(root: Node) -> void:
	for child in root.get_children():
		if child is Control and not (child is Button):
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_passthrough_scroll_inputs(child)

# Russo One text — black outline + soft shadow (same spec as menu / quests).
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

func _build_resource_strip(vp: Vector2) -> void:
	# Top-right resources: money_bag + dollars, then token + tokens. Mirrors
	# the quests-screen layout in canvas-px so all the back-row screens share
	# the same chrome convention.
	var scale_x : float = vp.x / CANVAS_W
	var scale_y : float = vp.y / CANVAS_H

	var icon_sz : float = RES_ICON_SZ * scale_y
	var num_w   : float = RES_NUM_W * scale_x
	var gap     : float = RES_GAP * scale_x
	var pair_w  : float = icon_sz + 2.0 + num_w
	var total_w : float = pair_w * 2.0 + gap
	var right_x : float = vp.x - RES_RIGHT_PAD * scale_x
	var start_x : float = right_x - total_w
	var top_y   : float = RES_Y * scale_y

	# Dollar pair
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

	# Token pair
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

func _chapter_visible(q_idxs: Array) -> bool:
	# Hide chapters that contain only endless quests when endless is locked.
	if QuestManager.is_endless_unlocked():
		return true
	for qi in q_idxs:
		if not _is_endless_quest(qi):
			return true
	return false

func _is_endless_quest(idx: int) -> bool:
	var def := QuestManager.STORY_QUESTS[idx] as Dictionary
	var cond_key = (def.get("cond", "") as String).split(":")[0]
	return QuestManager.is_endless_cond(cond_key)

func _measure_content_height() -> float:
	var h := 8.0
	var allow_endless := QuestManager.is_endless_unlocked()
	for ch in QuestManager.CHAPTERS:
		var q_idxs := (ch as Dictionary)["quests"] as Array
		if not _chapter_visible(q_idxs):
			continue
		h += CH_ROW_H + 1.0
		for qi in q_idxs:
			if not allow_endless and _is_endless_quest(qi):
				continue
			h += Q_ROW_H
		h += CH_GAP
	return h

func _add_chapter_row(parent: Control, cy: float, w: float,
		chapter: Dictionary, q_idxs: Array) -> float:
	# Layout uses the content WIDTH (w) — which is the central zone's inner
	# width — not the full viewport. Otherwise rows spill out of the zone.
	var done_count := 0
	for qi in q_idxs:
		if QuestManager.story_claimed[qi]:
			done_count += 1

	var bg := ColorRect.new()
	bg.color    = CLR_CHAPTER
	bg.size     = Vector2(w, CH_ROW_H)
	bg.position = Vector2(0.0, cy)
	parent.add_child(bg)

	var stripe := ColorRect.new()
	stripe.color    = CLR_ACCENT
	stripe.size     = Vector2(3.0, CH_ROW_H)
	stripe.position = Vector2(0.0, cy)
	parent.add_child(stripe)

	var lbl := Label.new()
	lbl.add_theme_font_override("font", UI_FONT)
	lbl.add_theme_font_size_override("font_size", 14)
	_apply_text_fx(lbl)
	lbl.text               = chapter["title"] as String
	lbl.modulate           = Color(0.90, 0.80, 0.55)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.size               = Vector2(w - 50.0, CH_ROW_H)
	lbl.position           = Vector2(PAD + 6.0, cy)
	parent.add_child(lbl)

	var cnt := Label.new()
	cnt.add_theme_font_override("font", UI_FONT)
	cnt.add_theme_font_size_override("font_size", 11)
	_apply_text_fx(cnt)
	cnt.text                 = "%d / %d" % [done_count, q_idxs.size()]
	cnt.modulate             = Color(0.55, 0.85, 0.40) if done_count == q_idxs.size() else Color(0.55, 0.55, 0.55)
	cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cnt.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	cnt.size                 = Vector2(w - 8.0, CH_ROW_H)
	cnt.position             = Vector2(0.0, cy)
	parent.add_child(cnt)

	var sep := ColorRect.new()
	sep.color    = Color(0.20, 0.16, 0.10, 0.60)
	sep.size     = Vector2(w, 1.0)
	sep.position = Vector2(0.0, cy + CH_ROW_H)
	parent.add_child(sep)

	return cy + CH_ROW_H + 1.0

func _add_quest_row(parent: Control, cy: float, w: float, idx: int) -> float:
	# Use content WIDTH (w) instead of full viewport — keeps every element
	# (background, reward label, claim button) inside the central zone.
	var q_def   := QuestManager.STORY_QUESTS[idx] as Dictionary
	var done    := bool(QuestManager.story_completed[idx])
	var claimed := bool(QuestManager.story_claimed[idx])
	var ready   := done and not claimed

	var bg := ColorRect.new()
	bg.color    = CLR_DONE if claimed else (CLR_READY if ready else CLR_QUEST)
	bg.size     = Vector2(w, Q_ROW_H - 1.0)
	bg.position = Vector2(0.0, cy + 1.0)
	parent.add_child(bg)

	var dim := 0.42 if claimed else 1.0

	if claimed:
		var ck := Label.new()
		ck.add_theme_font_override("font", UI_FONT)
		ck.add_theme_font_size_override("font_size", 13)
		_apply_text_fx(ck)
		ck.text               = "✓"
		ck.modulate           = Color(0.40, 0.65, 0.35, 0.65)
		ck.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		ck.size               = Vector2(16.0, Q_ROW_H)
		ck.position           = Vector2(PAD - 2.0, cy)
		parent.add_child(ck)

	# Matches quest-card values from quests_screen: title 16, desc 12 (and the
	# brighter description colour from the recent legibility tweak).
	var title_lbl := Label.new()
	title_lbl.add_theme_font_override("font", UI_FONT)
	title_lbl.add_theme_font_size_override("font_size", 16)
	_apply_text_fx(title_lbl)
	title_lbl.text     = q_def.get("title", "") as String
	title_lbl.modulate = Color(1.0, 0.95, 0.85, dim)
	title_lbl.size     = Vector2(w - 100.0, 24.0)
	title_lbl.position = Vector2(PAD + 14.0, cy + 5.0)
	parent.add_child(title_lbl)

	var desc_lbl := Label.new()
	desc_lbl.add_theme_font_override("font", UI_FONT)
	desc_lbl.add_theme_font_size_override("font_size", 12)
	_apply_text_fx(desc_lbl)
	desc_lbl.text     = q_def.get("desc", "") as String
	desc_lbl.modulate = Color(0.95, 0.95, 0.92, dim)
	desc_lbl.size     = Vector2(w - 100.0, 20.0)
	desc_lbl.position = Vector2(PAD + 14.0, cy + 30.0)
	parent.add_child(desc_lbl)

	var is_endless_reward := bool(q_def.get("reward_endless", false))
	var d_rwd := int(q_def.get("reward_d", 0))
	var t_rwd := int(q_def.get("reward_t", 0))
	var has_token_icon : bool = (t_rwd > 0) and not is_endless_reward
	# Build the reward TEXT — when there are tokens we drop the "жетон/жетоны"
	# word; the token icon glued to the right of the label conveys the unit.
	var rwd : String
	if is_endless_reward:
		rwd = "БЕСКОНЕЧНЫЙ РЕЖИМ"
	elif d_rwd > 0 and t_rwd > 0:
		rwd = "+%d $  +%d" % [d_rwd, t_rwd]
	elif d_rwd > 0:
		rwd = "+%d $" % d_rwd
	elif t_rwd > 0:
		rwd = "+%d" % t_rwd
	else:
		rwd = ""

	var rwd_lbl := Label.new()
	rwd_lbl.add_theme_font_override("font", UI_FONT)
	rwd_lbl.add_theme_font_size_override("font_size", 12)
	_apply_text_fx(rwd_lbl)
	rwd_lbl.text                 = rwd
	if is_endless_reward:
		rwd_lbl.modulate         = Color(0.55, 0.85, 1.0, dim)
	else:
		rwd_lbl.modulate         = Color(CLR_GOLD.r, CLR_GOLD.g, CLR_GOLD.b, dim)
	rwd_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rwd_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	var rwd_right_pad := CLAIM_W + 24.0 if ready else 8.0
	# Reserve space on the right for the token icon when there's a token reward.
	const TOKEN_ICON_SZ  : float = 16.0
	const TOKEN_ICON_GAP : float = 3.0
	var label_right_pad : float = rwd_right_pad
	if has_token_icon:
		label_right_pad += TOKEN_ICON_SZ + TOKEN_ICON_GAP
	rwd_lbl.size     = Vector2(w - label_right_pad, Q_ROW_H)
	rwd_lbl.position = Vector2(0.0, cy)
	parent.add_child(rwd_lbl)
	if has_token_icon:
		var icon := _make_icon(TEX_TOKEN, TOKEN_ICON_SZ)
		icon.position = Vector2(w - rwd_right_pad - TOKEN_ICON_SZ,
				cy + (Q_ROW_H - TOKEN_ICON_SZ) * 0.5)
		icon.modulate = Color(1.0, 1.0, 1.0, dim)
		parent.add_child(icon)
	if is_endless_reward:
		# Place an infinity icon just left of the right-aligned reward text.
		var icon_sz := 22.0
		var text_w  := UI_FONT.get_string_size(rwd, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		var icon_x  := w - rwd_right_pad - text_w - icon_sz - 6.0
		_draw_endless_icon(parent, Vector2(icon_x, cy + (Q_ROW_H - icon_sz) * 0.5), icon_sz,
			Color(0.55, 0.85, 1.0, dim))

	if ready:
		var cbg := ColorRect.new()
		cbg.color    = Color(0.18, 0.40, 0.10, 0.95)
		cbg.size     = Vector2(CLAIM_W, Q_ROW_H - 20.0)
		cbg.position = Vector2(w - CLAIM_W - 8.0, cy + 10.0)
		parent.add_child(cbg)

		var clbl := Label.new()
		clbl.add_theme_font_override("font", UI_FONT)
		clbl.add_theme_font_size_override("font_size", 13)
		_apply_text_fx(clbl)
		clbl.text                 = "ЗАБРАТЬ"
		clbl.modulate             = Color(0.85, 1.0, 0.60)
		clbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		clbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		clbl.size                 = cbg.size
		clbl.position             = cbg.position
		clbl.mouse_filter         = Control.MOUSE_FILTER_IGNORE
		parent.add_child(clbl)

		var btn := Button.new()
		btn.flat       = true
		btn.focus_mode = Control.FOCUS_NONE
		btn.size       = cbg.size
		btn.position   = cbg.position
		btn.pressed.connect(_on_claim_story.bind(idx, cbg.position + cbg.size * 0.5))
		parent.add_child(btn)

	var sep := ColorRect.new()
	sep.color    = Color(0.14, 0.12, 0.08, 0.50)
	sep.size     = Vector2(w, 1.0)
	sep.position = Vector2(0.0, cy + Q_ROW_H - 1.0)
	parent.add_child(sep)

	return cy + Q_ROW_H

# ── Trophy icon ──────────────────────────────────────────────────────────────
func _draw_trophy(pos: Vector2, sz: float) -> void:
	var cup_w  := sz
	var cup_h  := sz * 0.45
	var stem_w := sz * 0.22
	var stem_h := sz * 0.25
	var base_w := sz * 0.85
	var base_h := sz * 0.18
	var gold   := Color(0.92, 0.78, 0.28)
	var shade  := Color(0.65, 0.52, 0.15)

	var cup := ColorRect.new()
	cup.color    = gold
	cup.size     = Vector2(cup_w, cup_h)
	cup.position = pos
	_overlay.add_child(cup)

	var rim := ColorRect.new()
	rim.color    = shade
	rim.size     = Vector2(cup_w, 3.0)
	rim.position = pos
	_overlay.add_child(rim)

	var lh := ColorRect.new()
	lh.color    = shade
	lh.size     = Vector2(4.0, cup_h * 0.55)
	lh.position = pos + Vector2(-4.0, cup_h * 0.15)
	_overlay.add_child(lh)
	var rh := ColorRect.new()
	rh.color    = shade
	rh.size     = Vector2(4.0, cup_h * 0.55)
	rh.position = pos + Vector2(cup_w, cup_h * 0.15)
	_overlay.add_child(rh)

	var stem_x := pos.x + (cup_w - stem_w) * 0.5
	var stem_y := pos.y + cup_h
	var stem := ColorRect.new()
	stem.color    = shade
	stem.size     = Vector2(stem_w, stem_h)
	stem.position = Vector2(stem_x, stem_y)
	_overlay.add_child(stem)

	var base_x := pos.x + (cup_w - base_w) * 0.5
	var base_y := stem_y + stem_h
	var base := ColorRect.new()
	base.color    = gold
	base.size     = Vector2(base_w, base_h)
	base.position = Vector2(base_x, base_y)
	_overlay.add_child(base)

# Infinity / endless-mode icon built from two overlapping square ring outlines.
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
	# Subtle inner cross at overlap point for visual cohesion
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
	return r

func _reward_str(def: Dictionary) -> String:
	if bool(def.get("reward_endless", false)):
		return "БЕСКОНЕЧНЫЙ РЕЖИМ"
	var d := int(def.get("reward_d", 0))
	var t := int(def.get("reward_t", 0))
	if d > 0 and t > 0:
		return "+%d $  +%d жетона" % [d, t]
	if d > 0:  return "+%d $" % d
	if t == 1: return "+1 жетон"
	if t > 1:  return "+%d жетона" % t
	return ""

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
	# Convert content-space coords to overlay-space, accounting for the
	# scroll container's own position + current scroll offset.
	var src_screen := src_content + _scroll_con.position \
		- Vector2(_scroll_con.scroll_horizontal, _scroll_con.scroll_vertical)
	if d > 0:
		_fly_icons_to(TEX_DOLLAR, src_screen, _dollar_target, 5, Color.WHITE)
	if t > 0:
		_fly_icons_to(TEX_TOKEN, src_screen, _token_target,
			mini(maxi(t, 1), 4), Color.WHITE)
	if endless_rwd:
		_celebrate_endless_unlock(src_screen)
	# Defer the actual claim so badges pulse when icons arrive
	get_tree().create_timer(0.45).timeout.connect(func():
		QuestManager.claim_story(idx)
		_claim_busy = false
	)

func _celebrate_endless_unlock(src: Vector2) -> void:
	var col       := Color(0.55, 0.85, 1.0)
	var icon_sz   := 64.0
	var vp        := get_viewport().get_visible_rect().size
	var target    := Vector2(vp.x * 0.5 - icon_sz * 0.5, vp.y * 0.32 - icon_sz * 0.5)
	var icon_root := _draw_endless_icon(_overlay,
		src - Vector2(icon_sz * 0.5, icon_sz * 0.5), icon_sz, col)
	icon_root.z_index = 30
	var tw := icon_root.create_tween().set_parallel(true)
	tw.tween_property(icon_root, "position", target, 0.50) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.chain().tween_interval(0.55)
	tw.chain().tween_property(icon_root, "modulate:a", 0.0, 0.35)
	tw.chain().tween_callback(icon_root.queue_free)

	# "ОТКРЫТО" toast over the icon
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
	_overlay.add_child(lbl)
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
		_overlay.add_child(ico)
		var tw := ico.create_tween()
		tw.tween_interval(float(i) * 0.07)
		tw.tween_property(ico, "position", to, 0.40) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(ico, "modulate:a", 0.0, 0.16).set_delay(0.30)
		tw.tween_callback(ico.queue_free)

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

func _rebuild_content() -> void:
	if not is_instance_valid(_content):
		return
	for c in _content.get_children():
		c.queue_free()
	# Card widths are sized to the central scroll zone, NOT the full viewport
	# — using vp.x here was making rows stretch off the right edge of the
	# screen on every rebuild (after each claim).
	var vp        := get_viewport().get_visible_rect().size
	var scale_x   : float = vp.x / CANVAS_W
	var zone_w    : float = ZONE_W * scale_x
	var content_w : float = zone_w - PAD * 2.0
	var total_h   := _measure_content_height()
	_content.custom_minimum_size = Vector2(zone_w, total_h + 48.0)
	var cy := 8.0
	var allow_endless := QuestManager.is_endless_unlocked()
	for ch_idx in QuestManager.CHAPTERS.size():
		var chapter := QuestManager.CHAPTERS[ch_idx] as Dictionary
		var q_idxs  := chapter["quests"] as Array
		if not _chapter_visible(q_idxs):
			continue
		var visible_idxs : Array = []
		for qi in q_idxs:
			if not allow_endless and _is_endless_quest(qi):
				continue
			visible_idxs.append(qi)
		cy = _add_chapter_row(_content, cy, content_w, chapter, visible_idxs)
		for qi in visible_idxs:
			cy = _add_quest_row(_content, cy, content_w, qi)
		cy += CH_GAP
	_passthrough_scroll_inputs(_content)

func _on_close() -> void:
	if not is_instance_valid(_slide_root):
		queue_free()
		return
	# Reverse the camera pan: book screen slides DOWN, main menu drops back in.
	var vp := get_viewport().get_visible_rect().size
	var tw := create_tween()
	tw.tween_property(_slide_root, "position", Vector2(0.0, vp.y), SLIDE_TIME)\
		.set_trans(SLIDE_TRANS).set_ease(SLIDE_EASE_OUT)
	tw.tween_callback(Callable(self, "queue_free"))
	if _hud != null and _hud.has_method("_on_book_close_anim_start"):
		_hud._on_book_close_anim_start(SLIDE_TIME, SLIDE_TRANS, SLIDE_EASE_OUT)
