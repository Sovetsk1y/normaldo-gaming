extends Node2D
class_name QuestsScreen

# Russo One — main UI font, matches the new main-menu chrome.
const UI_FONT        := preload("res://assets/fonts/RussoOne-Regular.ttf")
const TEX_DOLLAR     := preload("res://assets/items/dollar.png")
const TEX_MONEYBAG   := preload("res://assets/items/money_bag.png")
const TEX_TOKEN      := preload("res://assets/items/token.png")
# Full-screen quests-room background (430×192 pixel-art, same canvas as menu).
const TEX_BG_QUESTS  := preload("res://assets/ui/quests/bg_quests.png")
const TEX_BACK_ARROW := preload("res://assets/ui/quests/back_arrow.png")

const CLR_BG     := Color(0.06, 0.04, 0.02, 0.96)
const CLR_CARD   := Color(0.10, 0.08, 0.06, 0.95)
const CLR_DONE   := Color(0.12, 0.22, 0.10, 0.95)
const CLR_STRIPE_EASY   := Color(0.35, 0.75, 0.30, 0.85)
const CLR_STRIPE_MEDIUM := Color(0.90, 0.65, 0.10, 0.85)
const CLR_STRIPE_HARD   := Color(0.90, 0.22, 0.22, 0.85)

# ── Layout (canvas pixels, 430×192) — edit these to slide UI around ──────────
const CANVAS_W : float = 430.0
const CANVAS_H : float = 192.0
# Top chrome strip (back button, title, resources). Height in canvas px.
const CHROME_H : float = 30.0
# Back button (top-left). x,y in canvas px relative to top-left of screen.
# Native source PNG is 51×32 — use a canvas-px width that keeps the aspect.
const BACK_BTN_POS  : Vector2 = Vector2(10.0, 6.0)
const BACK_BTN_SIZE : Vector2 = Vector2(24.0, 15.0)
# Title "ЗАДАНИЯ" — centred horizontally + nudged by TITLE_X_OFFSET (canvas
# px; negative = shift left). y/height in canvas px.
const TITLE_X_OFFSET : float = -30.0
const TITLE_Y        : float = 6.0
const TITLE_H        : float = 20.0
const TITLE_FONT_SZ  : int   = 16
# Resources (top-right). The whole pair is right-anchored at this distance
# from the right edge, then laid out as [icon  number   icon  number].
const RES_RIGHT_PAD : float = -10.0
const RES_Y         : float = 7.0
const RES_ICON_SZ   : float = 16.0
const RES_GAP       : float = 2.0
const RES_NUM_W     : float = 36.0
const RES_FONT_SZ   : int   = 14
# Central "black zone" where the quest cards live. Edit these to grow/shrink
# the playable column of cards. Values are CANVAS px.
const ZONE_X : float = 65.0
const ZONE_Y : float = 38.0
const ZONE_W : float = 300.0
const ZONE_H : float = 148.0
# Slide-down entrance animation. Increase SLIDE_TIME for a more dramatic fall.
const SLIDE_TIME : float = 0.45
const SLIDE_TRANS : int = Tween.TRANS_QUAD
const SLIDE_EASE_IN  : int = Tween.EASE_IN     # entrance (drops in)
const SLIDE_EASE_OUT : int = Tween.EASE_IN     # exit (yanks back up; same curve feels consistent)

# Legacy constants — kept so existing card/banner code that references them
# still compiles. They are NO LONGER used for chrome positioning.
const HDR_H := 46.0
const RES_H := 32.0

var _hud         : Node = null
# Root that holds every visible element. We animate its position.y between
# -vp.y (off-screen above) and 0 (covering the main menu) for the slide-down /
# slide-up entrance & exit.
var _slide_root  : Control = null
# Legacy `_overlay` is still consumed by the card / banner / refresh helpers.
# In the new layout it points at the same node as `_slide_root` so the cards
# parent themselves inside the slide-animated container.
var _overlay     : Control = null
var _timer_lbl   : Label = null
var _cards       : Array = []
var _bonus_root  : Node2D = null
var _dollar_lbl  : Label = null
var _token_lbl   : Label = null
var _dollar_target : Vector2 = Vector2.ZERO
var _token_target  : Vector2 = Vector2.ZERO
var _claim_busy   : bool = false
var _scroll_content : Control = null
# Per-slot cooldown timer labels. _process keeps them ticking down each frame
# without rebuilding the whole card. Indexed by slot (0..2); null when that
# slot is currently showing a normal quest card.
var _cd_timer_lbls : Array = [null, null, null]

func setup(hud: Node) -> void:
	_hud = hud

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Roll fresh quests for slots whose cooldown elapsed while the menu was up.
	QuestManager.check_cooldowns()
	var vp := get_viewport().get_visible_rect().size
	_build(vp)
	# "Camera pan down" entrance: we sit BELOW the menu (y = +vp.y) and slide
	# up to y = 0. The menu itself simultaneously slides up off-screen — that
	# part lives in HUD._on_quests_open_anim_start so both movements share the
	# same tween duration / curve.
	_slide_root.position = Vector2(0.0, vp.y)
	var tw := create_tween()
	tw.tween_property(_slide_root, "position", Vector2.ZERO, SLIDE_TIME)\
		.set_trans(SLIDE_TRANS).set_ease(SLIDE_EASE_IN)
	if _hud != null and _hud.has_method("_on_quests_open_anim_start"):
		_hud._on_quests_open_anim_start(SLIDE_TIME, SLIDE_TRANS, SLIDE_EASE_IN)
	QuestManager.quests_updated.connect(_refresh)
	SaveData.data_changed.connect(_on_data_changed)
	set_process(true)

func _process(_delta: float) -> void:
	# Per-slot cooldown countdowns. Auto-replace the placeholder with a fresh
	# quest the moment the timer hits zero — no need to wait for another open.
	for i in _cd_timer_lbls.size():
		var lbl = _cd_timer_lbls[i]
		if not is_instance_valid(lbl):
			continue
		var rem : int = QuestManager.slot_cooldown_remaining(i)
		lbl.text = _format_cooldown(rem)
		if rem <= 0:
			# Cooldown over — roll a new quest and rebuild the cards.
			if QuestManager.check_cooldowns():
				return

func _build(vp: Vector2) -> void:
	var scale_x : float = vp.x / CANVAS_W
	var scale_y : float = vp.y / CANVAS_H

	# Slide root: every visible element lives inside, so the entrance tween
	# moves the whole thing as one piece.
	_slide_root = Control.new()
	_slide_root.size         = vp
	_slide_root.position     = Vector2.ZERO
	_slide_root.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_slide_root)
	# Legacy alias — card / banner / refresh helpers still parent into _overlay.
	_overlay = _slide_root

	# Full-screen background image (430×192 pixel art).
	var bg := TextureRect.new()
	bg.texture             = TEX_BG_QUESTS
	bg.stretch_mode        = TextureRect.STRETCH_SCALE
	bg.expand_mode         = TextureRect.EXPAND_IGNORE_SIZE
	bg.custom_minimum_size = Vector2.ZERO
	bg.size                = vp
	bg.position            = Vector2.ZERO
	bg.texture_filter      = CanvasItem.TEXTURE_FILTER_NEAREST
	bg.mouse_filter        = Control.MOUSE_FILTER_IGNORE
	_slide_root.add_child(bg)

	# ── Top-left back button (pixel-art arrow icon) ─────────────────────────
	# Wrap the icon in a Control so we can scale-tween it on press just like
	# the main-menu buttons do — same SCALE / TIME constants.
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

	# ── Top-centre title ────────────────────────────────────────────────────
	var title_lbl := Label.new()
	title_lbl.add_theme_font_override("font", UI_FONT)
	title_lbl.add_theme_font_size_override("font_size", TITLE_FONT_SZ)
	_apply_quests_text_fx(title_lbl)
	title_lbl.text                 = "ЗАДАНИЯ"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	title_lbl.size                 = Vector2(vp.x, TITLE_H * scale_y)
	title_lbl.position             = Vector2(TITLE_X_OFFSET * scale_x, TITLE_Y * scale_y)
	title_lbl.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	_slide_root.add_child(title_lbl)

	# ── Top-right resources ────────────────────────────────────────────────
	_build_resource_strip(vp)

	# ── Central "black zone" — ScrollContainer for quest cards ─────────────
	var zone_pos  := Vector2(ZONE_X * scale_x, ZONE_Y * scale_y)
	var zone_size := Vector2(ZONE_W * scale_x, ZONE_H * scale_y)
	var pad       := 12.0
	var card_w    := zone_size.x - pad * 2.0

	var scroll := ScrollContainer.new()
	scroll.name = "QuestScroll"
	scroll.size = zone_size
	scroll.position = zone_pos
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# Hide the vertical scrollbar — drag-to-scroll still works, we just don't
	# want the grey bar overlaying the cards.
	scroll.vertical_scroll_mode   = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	# scroll_deadzone > 0 lets the container steal a touch from its child
	# buttons once the finger moves past the threshold — required so list
	# scrolling works on mobile, where every tap initially hits a card. 18 px
	# tuned for Retina: low enough to feel responsive, high enough to avoid
	# accidentally swallowing taps.
	scroll.set("scroll_deadzone", 18)
	_slide_root.add_child(scroll)

	var scroll_content := Control.new()
	scroll_content.name = "ScrollContent"
	scroll_content.custom_minimum_size = Vector2(zone_size.x, 0.0)
	scroll_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(scroll_content)
	_scroll_content = scroll_content

	var inner_y := 0.0

	# Entry bonus banner (inside scroll)
	_build_bonus_banner_scrollable(Vector2(pad, inner_y), card_w)
	if is_instance_valid(_bonus_root):
		_passthrough_scroll_inputs(_bonus_root)
	inner_y += 54.0

	# Daily quest cards
	_cd_timer_lbls = [null, null, null]
	for i in 3:
		var slot   := i
		var card_h := 100.0
		var node   := _build_card_scrollable(Vector2(pad, inner_y), card_w, card_h, slot)
		scroll_content.add_child(node)
		_cards.append(node)
		inner_y += card_h + 10.0

	# Daily reset banner removed — each slot now shows its own per-tier
	# cooldown when claimed, so a global "сброс через …" line is redundant.
	scroll_content.custom_minimum_size = Vector2(zone_size.x, inner_y)

func _build_resource_strip(vp: Vector2) -> void:
	# Top-right resources: money_bag + dollars, then token + tokens. Laid out in
	# canvas px and right-anchored so the right edge sits RES_RIGHT_PAD from the
	# screen edge.
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

	# Money_bag + dollars
	var dol_x : float = start_x
	var dol_icon := _make_icon(TEX_DOLLAR, icon_sz)
	dol_icon.position = Vector2(dol_x, top_y)
	_slide_root.add_child(dol_icon)
	_dollar_lbl = Label.new()
	_dollar_lbl.add_theme_font_override("font", UI_FONT)
	_dollar_lbl.add_theme_font_size_override("font_size", RES_FONT_SZ)
	_apply_quests_text_fx(_dollar_lbl)
	_dollar_lbl.text                 = str(SaveData.dollars)
	_dollar_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_dollar_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_dollar_lbl.size                 = Vector2(num_w, icon_sz + 4.0)
	_dollar_lbl.position             = Vector2(dol_x + icon_sz + 2.0, top_y - 2.0)
	_slide_root.add_child(_dollar_lbl)
	_dollar_target = Vector2(dol_x + icon_sz * 0.5, top_y + icon_sz * 0.5)

	# Token + tokens
	var tkn_x : float = dol_x + pair_w + gap
	var tkn_icon := _make_icon(TEX_TOKEN, icon_sz)
	tkn_icon.position = Vector2(tkn_x, top_y)
	_slide_root.add_child(tkn_icon)
	_token_lbl = Label.new()
	_token_lbl.add_theme_font_override("font", UI_FONT)
	_token_lbl.add_theme_font_size_override("font_size", RES_FONT_SZ)
	_apply_quests_text_fx(_token_lbl)
	_token_lbl.text                 = str(SaveData.tokens)
	_token_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_token_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_token_lbl.size                 = Vector2(num_w, icon_sz + 4.0)
	_token_lbl.position             = Vector2(tkn_x + icon_sz + 2.0, top_y - 2.0)
	_slide_root.add_child(_token_lbl)
	_token_target = Vector2(tkn_x + icon_sz * 0.5, top_y + icon_sz * 0.5)

# Walk a card subtree and force every non-Button Control to IGNORE input.
# Decorative ColorRects default to MOUSE_FILTER_STOP, which steals finger
# drags from the parent ScrollContainer and breaks list scrolling on touch.
# Buttons are left alone so taps still register — the container's
# scroll_deadzone takes the touch back when the finger moves far enough.
func _passthrough_scroll_inputs(root: Node) -> void:
	for child in root.get_children():
		if child is Control and not (child is Button):
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_passthrough_scroll_inputs(child)

# Press-feedback for tap-targets — mirrors the main-menu button shrink so the
# back arrow squeezes the same way as the chips that opened this screen.
const _PRESS_SCALE : float = 0.90
const _PRESS_TIME  : float = 0.07
func _press_anim(visual_root: Control, pressed: bool) -> void:
	if not is_instance_valid(visual_root):
		return
	var target := Vector2.ONE * (_PRESS_SCALE if pressed else 1.0)
	var tw := create_tween()
	tw.tween_property(visual_root, "scale", target, _PRESS_TIME)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

# Russo One text — black outline + soft shadow (same spec as the main-menu
# button captions). Pulled into a single helper so every label on this screen
# looks consistent.
func _apply_quests_text_fx(lbl: Label) -> void:
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.65))
	lbl.add_theme_constant_override("outline_size", 2)
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.80))
	lbl.add_theme_constant_override("shadow_offset_x", 0)
	lbl.add_theme_constant_override("shadow_offset_y", 0)
	lbl.add_theme_constant_override("shadow_outline_size", 3)

func _build_bonus_banner(pos: Vector2, w: float) -> void:
	_bonus_root = Node2D.new()
	_overlay.add_child(_bonus_root)

	var h    := 44.0
	var bg   := ColorRect.new()
	bg.color    = Color(0.14, 0.20, 0.08, 0.95)
	bg.size     = Vector2(w, h)
	bg.position = pos
	_bonus_root.add_child(bg)

	var stripe := ColorRect.new()
	stripe.color    = Color(0.45, 0.85, 0.25, 0.70)
	stripe.size     = Vector2(w, 2.0)
	stripe.position = pos
	_bonus_root.add_child(stripe)

	var lbl := Label.new()
	lbl.add_theme_font_override("font", UI_FONT)
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.text                 = "БОНУС ЗА ВХОД  +%d $" % QuestManager.ENTRY_BONUS
	lbl.modulate             = Color(0.75, 1.0, 0.45)
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl.size                 = Vector2(w - 100.0, h)
	lbl.position             = pos + Vector2(10.0, 0.0)
	_bonus_root.add_child(lbl)

	if not QuestManager.daily_bonus_avail:
		var done := Label.new()
		done.add_theme_font_override("font", UI_FONT)
		done.add_theme_font_size_override("font_size", 11)
		done.text                 = "✓ Забрано"
		done.modulate             = Color(0.55, 0.75, 0.45, 0.70)
		done.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		done.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		done.size                 = Vector2(w - 10.0, h)
		done.position             = pos
		_bonus_root.add_child(done)
		return

	var claim_w := 90.0
	var claim_bg := ColorRect.new()
	claim_bg.color    = Color(0.20, 0.45, 0.12, 0.95)
	claim_bg.size     = Vector2(claim_w, h - 12.0)
	claim_bg.position = pos + Vector2(w - claim_w - 6.0, 6.0)
	_bonus_root.add_child(claim_bg)

	var claim_lbl := Label.new()
	claim_lbl.add_theme_font_override("font", UI_FONT)
	claim_lbl.add_theme_font_size_override("font_size", 13)
	claim_lbl.text                 = "ЗАБРАТЬ"
	claim_lbl.modulate             = Color(0.85, 1.0, 0.65)
	claim_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	claim_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	claim_lbl.size                 = Vector2(claim_w, h - 12.0)
	claim_lbl.position             = claim_bg.position
	claim_lbl.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	_bonus_root.add_child(claim_lbl)

	var btn_pos := claim_bg.position + claim_bg.size * 0.5
	var btn := Button.new()
	btn.flat       = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.size       = claim_bg.size
	btn.position   = claim_bg.position
	btn.pressed.connect(_on_claim_bonus.bind(btn_pos))
	_bonus_root.add_child(btn)

func _build_bonus_banner_scrollable(pos: Vector2, w: float) -> void:
	_bonus_root = Node2D.new()
	_scroll_content.add_child(_bonus_root)

	var h    := 44.0
	var bg   := ColorRect.new()
	bg.color    = Color(0.14, 0.20, 0.08, 0.95)
	bg.size     = Vector2(w, h)
	bg.position = pos
	_bonus_root.add_child(bg)

	var stripe := ColorRect.new()
	stripe.color    = Color(0.45, 0.85, 0.25, 0.70)
	stripe.size     = Vector2(w, 2.0)
	stripe.position = pos
	_bonus_root.add_child(stripe)

	var lbl := Label.new()
	lbl.add_theme_font_override("font", UI_FONT)
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.text                 = "БОНУС ЗА ВХОД  +%d $" % QuestManager.ENTRY_BONUS
	lbl.modulate             = Color(0.75, 1.0, 0.45)
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl.size                 = Vector2(w - 100.0, h)
	lbl.position             = pos + Vector2(10.0, 0.0)
	_bonus_root.add_child(lbl)

	if not QuestManager.daily_bonus_avail:
		var done := Label.new()
		done.add_theme_font_override("font", UI_FONT)
		done.add_theme_font_size_override("font_size", 11)
		done.text                 = "✓ Забрано"
		done.modulate             = Color(0.55, 0.75, 0.45, 0.70)
		done.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		done.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		done.size                 = Vector2(w - 10.0, h)
		done.position             = pos
		_bonus_root.add_child(done)
		return

	var claim_w := 90.0
	var claim_bg := ColorRect.new()
	claim_bg.color    = Color(0.20, 0.45, 0.12, 0.95)
	claim_bg.size     = Vector2(claim_w, h - 12.0)
	claim_bg.position = pos + Vector2(w - claim_w - 6.0, 6.0)
	_bonus_root.add_child(claim_bg)

	var claim_lbl := Label.new()
	claim_lbl.add_theme_font_override("font", UI_FONT)
	claim_lbl.add_theme_font_size_override("font_size", 13)
	claim_lbl.text                 = "ЗАБРАТЬ"
	claim_lbl.modulate             = Color(0.85, 1.0, 0.65)
	claim_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	claim_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	claim_lbl.size                 = Vector2(claim_w, h - 12.0)
	claim_lbl.position             = claim_bg.position
	claim_lbl.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	_bonus_root.add_child(claim_lbl)

	var btn_pos := claim_bg.position + claim_bg.size * 0.5
	var btn := Button.new()
	btn.flat       = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.size       = claim_bg.size
	btn.position   = claim_bg.position
	btn.pressed.connect(_on_claim_bonus.bind(btn_pos))
	_bonus_root.add_child(btn)

func _build_card(pos: Vector2, w: float, h: float, slot: int) -> Node2D:
	var card := Node2D.new()
	_build_card_content(card, pos, w, h, slot)
	return card

func _build_card_scrollable(pos: Vector2, w: float, h: float, slot: int) -> Node2D:
	var card := Node2D.new()
	_build_card_content(card, pos, w, h, slot)
	_passthrough_scroll_inputs(card)
	return card

func _build_card_content(root: Node2D, pos: Vector2, w: float, h: float, slot: int) -> void:
	var q     := QuestManager.daily_quests[slot] as Dictionary
	var tier  := q["tier"] as String

	var stripe_col : Color
	var tier_label : String
	match tier:
		"easy":
			stripe_col = CLR_STRIPE_EASY
			tier_label = "ЛЁГКОЕ"
		"medium":
			stripe_col = CLR_STRIPE_MEDIUM
			tier_label = "СРЕДНЕЕ"
		_:
			stripe_col = CLR_STRIPE_HARD
			tier_label = "ТЯЖЁЛОЕ"

	# Slot on per-tier cooldown — render a placeholder with the countdown to the
	# next quest of this tier instead of the full quest card.
	if QuestManager.is_slot_on_cooldown(slot):
		_build_cooldown_card(root, pos, w, h, slot, tier_label, stripe_col)
		return

	var def     := QuestManager._daily_def(slot)
	var done    := bool(q["completed"])
	var claimed := bool(q["claimed"])

	var bg := ColorRect.new()
	bg.color    = CLR_DONE if (done and not claimed) else CLR_CARD
	bg.size     = Vector2(w, h)
	bg.position = pos
	root.add_child(bg)

	var st := ColorRect.new()
	st.color    = stripe_col
	st.size     = Vector2(w, 2.0)
	st.position = pos
	root.add_child(st)

	var tier_lbl := Label.new()
	tier_lbl.add_theme_font_override("font", UI_FONT)
	tier_lbl.add_theme_font_size_override("font_size", 9)
	tier_lbl.text     = tier_label
	tier_lbl.modulate = Color(stripe_col.r, stripe_col.g, stripe_col.b, 0.90)
	tier_lbl.size     = Vector2(80.0, 16.0)
	tier_lbl.position = pos + Vector2(8.0, 6.0)
	root.add_child(tier_lbl)

	var title_lbl := Label.new()
	title_lbl.add_theme_font_override("font", UI_FONT)
	title_lbl.add_theme_font_size_override("font_size", 16)
	title_lbl.text     = def.get("title", "") as String
	title_lbl.modulate = Color(1.0, 0.95, 0.85)
	title_lbl.clip_text = true
	title_lbl.size     = Vector2(w - 120.0, 24.0)
	title_lbl.position = pos + Vector2(8.0, 21.0)
	root.add_child(title_lbl)

	# Description is the main "what do I have to do" line — bumped up two sizes
	# and brighter so it's the first thing the eye lands on inside the card.
	var desc_lbl := Label.new()
	desc_lbl.add_theme_font_override("font", UI_FONT)
	desc_lbl.add_theme_font_size_override("font_size", 12)
	desc_lbl.text     = def.get("desc", "") as String
	desc_lbl.modulate = Color(0.95, 0.95, 0.92)
	desc_lbl.size     = Vector2(w - 110.0, 20.0)
	desc_lbl.position = pos + Vector2(8.0, 44.0)
	root.add_child(desc_lbl)

	var prog_lbl := Label.new()
	prog_lbl.add_theme_font_override("font", UI_FONT)
	prog_lbl.add_theme_font_size_override("font_size", 10)
	prog_lbl.text     = QuestManager.daily_progress_text(slot)
	prog_lbl.modulate = Color(0.75, 0.75, 0.65)
	prog_lbl.size     = Vector2(w - 110.0, 16.0)
	prog_lbl.position = pos + Vector2(8.0, 64.0)
	root.add_child(prog_lbl)

	var reward_str := _reward_str(def)
	var rwd_lbl := Label.new()
	rwd_lbl.add_theme_font_override("font", UI_FONT)
	rwd_lbl.add_theme_font_size_override("font_size", 13)
	rwd_lbl.text                 = reward_str
	rwd_lbl.modulate             = Color(1.0, 0.85, 0.35)
	rwd_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rwd_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	rwd_lbl.size                 = Vector2(100.0, 24.0)
	rwd_lbl.position             = pos + Vector2(w - 108.0, 20.0)
	root.add_child(rwd_lbl)

	if done and not claimed:
		var claim_w := 90.0
		var claim_h := 44.0
		var cbg := ColorRect.new()
		cbg.color    = Color(0.20, 0.45, 0.12, 0.95)
		cbg.size     = Vector2(claim_w, claim_h)
		cbg.position = pos + Vector2(w - claim_w - 6.0, h - claim_h - 8.0)
		root.add_child(cbg)

		var clbl := Label.new()
		clbl.add_theme_font_override("font", UI_FONT)
		clbl.add_theme_font_size_override("font_size", 12)
		clbl.text                 = "ЗАБРАТЬ"
		clbl.modulate             = Color(0.85, 1.0, 0.65)
		clbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		clbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		clbl.size                 = cbg.size
		clbl.position             = cbg.position
		clbl.mouse_filter         = Control.MOUSE_FILTER_IGNORE
		root.add_child(clbl)

		var btn_pos := cbg.position + cbg.size * 0.5
		var btn := Button.new()
		btn.flat       = true
		btn.focus_mode = Control.FOCUS_NONE
		btn.size       = cbg.size
		btn.position   = cbg.position
		btn.pressed.connect(_on_claim_daily.bind(slot, btn_pos))
		root.add_child(btn)
	elif claimed:
		var done_lbl := Label.new()
		done_lbl.add_theme_font_override("font", UI_FONT)
		done_lbl.add_theme_font_size_override("font_size", 11)
		done_lbl.text                 = "✓"
		done_lbl.modulate             = Color(0.45, 0.75, 0.35, 0.70)
		done_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		done_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		done_lbl.size                 = Vector2(32.0, h)
		done_lbl.position             = pos + Vector2(w - 38.0, 0.0)
		root.add_child(done_lbl)

	return

# Cooldown placeholder card — shown for the slot whose quest was just claimed
# until its tier's cooldown (1h / 3h / 6h) elapses. Stores the countdown
# label so _process can tick it without rebuilding the whole card.
func _build_cooldown_card(root: Node2D, pos: Vector2, w: float, h: float, slot: int, tier_label: String, stripe_col: Color) -> void:
	var bg := ColorRect.new()
	bg.color    = CLR_CARD
	bg.size     = Vector2(w, h)
	bg.position = pos
	root.add_child(bg)

	var st := ColorRect.new()
	st.color    = Color(stripe_col.r, stripe_col.g, stripe_col.b, 0.50)
	st.size     = Vector2(w, 2.0)
	st.position = pos
	root.add_child(st)

	var tier_lbl := Label.new()
	tier_lbl.add_theme_font_override("font", UI_FONT)
	tier_lbl.add_theme_font_size_override("font_size", 9)
	tier_lbl.text     = tier_label
	tier_lbl.modulate = Color(stripe_col.r, stripe_col.g, stripe_col.b, 0.85)
	tier_lbl.size     = Vector2(80.0, 16.0)
	tier_lbl.position = pos + Vector2(8.0, 6.0)
	root.add_child(tier_lbl)

	var hint_lbl := Label.new()
	hint_lbl.add_theme_font_override("font", UI_FONT)
	hint_lbl.add_theme_font_size_override("font_size", 11)
	hint_lbl.text     = "Следующее задание через"
	hint_lbl.modulate = Color(0.75, 0.75, 0.72, 0.90)
	hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_lbl.size     = Vector2(w - 16.0, 18.0)
	hint_lbl.position = pos + Vector2(8.0, h * 0.32)
	root.add_child(hint_lbl)

	var cd_lbl := Label.new()
	cd_lbl.add_theme_font_override("font", UI_FONT)
	cd_lbl.add_theme_font_size_override("font_size", 22)
	cd_lbl.text     = _format_cooldown(QuestManager.slot_cooldown_remaining(slot))
	cd_lbl.modulate = Color(1.0, 0.97, 0.85)
	cd_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cd_lbl.size     = Vector2(w - 16.0, 28.0)
	cd_lbl.position = pos + Vector2(8.0, h * 0.55)
	root.add_child(cd_lbl)
	_cd_timer_lbls[slot] = cd_lbl

func _format_cooldown(sec: int) -> String:
	if sec <= 0:
		return "00:00:00"
	var h := sec / 3600
	var m := (sec % 3600) / 60
	var s := sec % 60
	return "%02d:%02d:%02d" % [h, m, s]

func _reward_str(def: Dictionary) -> String:
	var d := int(def.get("reward_d", 0))
	var t := int(def.get("reward_t", 0))
	var x := int(def.get("reward_xp", 0))
	if d > 0:  return "+%d $" % d
	if t == 1: return "+1 жетон"
	if t > 1:  return "+%d жетона" % t
	if x > 0:  return "+%d ОПЫТ" % x
	return ""

func _time_to_midnight() -> String:
	var now    := Time.get_time_dict_from_system()
	var h      := int(now.get("hour", 0))
	var m      := int(now.get("minute", 0))
	var s      := int(now.get("second", 0))
	var rem    := (23 - h) * 3600 + (59 - m) * 60 + (60 - s)
	var rh     := rem / 3600
	var rm     := (rem % 3600) / 60
	var rs     := rem % 60
	return "Сброс через: %02d:%02d:%02d" % [rh, rm, rs]

func _refresh() -> void:
	if is_instance_valid(_bonus_root):
		_bonus_root.queue_free()
	var vp       := get_viewport().get_visible_rect().size
	var scale_x  : float = vp.x / CANVAS_W
	var zone_w   : float = ZONE_W * scale_x
	var pad      := 12.0
	# Cards always live inside the central scroll content — bonus banner sits
	# at the top of the scroll, not at a viewport-pixel offset any more.
	_build_bonus_banner_scrollable(Vector2(pad, 0.0), zone_w - pad * 2.0)
	if is_instance_valid(_bonus_root):
		_passthrough_scroll_inputs(_bonus_root)

	for c in _cards:
		if is_instance_valid(c):
			c.queue_free()
	_cards.clear()
	_cd_timer_lbls = [null, null, null]
	var card_w    := zone_w - pad * 2.0
	var content_y := 54.0
	for i in 3:
		var card_h := 100.0
		var node   := _build_card_scrollable(Vector2(pad, content_y), card_w, card_h, i)
		_scroll_content.add_child(node)
		_cards.append(node)
		content_y += card_h + 10.0

func _on_claim_bonus(src: Vector2) -> void:
	if _claim_busy:
		return
	_claim_busy = true
	if _hud and _hud.has_method("_play_btn_sfx"):
		_hud._play_btn_sfx()
	_fly_icons_to(TEX_DOLLAR, src, _dollar_target, 5, Color.WHITE)
	get_tree().create_timer(0.45).timeout.connect(func():
		QuestManager.claim_entry_bonus()
		_claim_busy = false
	)

func _on_claim_daily(slot: int, src: Vector2) -> void:
	if _claim_busy:
		return
	_claim_busy = true
	if _hud and _hud.has_method("_play_btn_sfx"):
		_hud._play_btn_sfx()
	var def  := QuestManager._daily_def(slot)
	var d    := int(def.get("reward_d", 0))
	var t    := int(def.get("reward_t", 0))
	if d > 0:
		_fly_icons_to(TEX_DOLLAR, src, _dollar_target, 5, Color.WHITE)
	if t > 0:
		_fly_icons_to(TEX_TOKEN, src, _token_target,
			mini(maxi(t, 1), 4), Color.WHITE)

	# Collapse the card itself in parallel with the icons flying off.
	if slot < _cards.size() and is_instance_valid(_cards[slot]):
		_collapse_card(_cards[slot])

	get_tree().create_timer(0.45).timeout.connect(func():
		QuestManager.claim_daily(slot)
		_claim_busy = false
	)

# Visual flair when a card is claimed — fades and squashes the card to nothing
# before the underlying quest data flips to its "on cooldown" placeholder.
func _collapse_card(card: Node2D) -> void:
	if not is_instance_valid(card):
		return
	# Pivot doesn't apply to Node2D; the scale is around its origin (top-left).
	# That looks correct here because the card lays out from its top-left
	# anchor inside the scroll content.
	var tw := card.create_tween().set_parallel(true)
	tw.tween_property(card, "scale", Vector2(1.0, 0.0), 0.32)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(card, "modulate:a", 0.0, 0.32)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

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

func _make_icon(tex: Texture2D, sz: float) -> TextureRect:
	var r := TextureRect.new()
	r.texture      = tex
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
	r.size         = Vector2(sz, sz)
	return r

func _on_close() -> void:
	if not is_instance_valid(_slide_root):
		queue_free()
		return
	# Reverse "camera pan": quests slides back DOWN off-screen while the menu
	# slides back DOWN from above into view. Both tweens share timing.
	var vp := get_viewport().get_visible_rect().size
	var tw := create_tween()
	tw.tween_property(_slide_root, "position", Vector2(0.0, vp.y), SLIDE_TIME)\
		.set_trans(SLIDE_TRANS).set_ease(SLIDE_EASE_OUT)
	tw.tween_callback(Callable(self, "queue_free"))
	if _hud != null and _hud.has_method("_on_quests_close_anim_start"):
		_hud._on_quests_close_anim_start(SLIDE_TIME, SLIDE_TRANS, SLIDE_EASE_OUT)
