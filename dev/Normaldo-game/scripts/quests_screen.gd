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
var _layout      : Dictionary = {}
var _reset_lbl   : Label = null
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
	if is_instance_valid(_reset_lbl):
		_reset_lbl.text = _time_to_midnight()
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

	# ── Шапка: сколько осталось до сброса заданий ──────────────────────────
	_build_reset_chip(vp)

	# ── Баннер бонуса за вход + три карточки В РЯД ─────────────────────────
	# Экран альбомный (960×430), а список был вертикальный: половина ширины
	# пустовала, и при этом третья карточка не влезала и требовала скролла.
	# Три задания в ряд помещаются целиком — скролл не нужен вовсе.
	# См. /Концепция/Экран заданий.md
	_layout = _compute_layout(vp)
	_build_bonus_banner(_layout["banner_pos"], _layout["banner_size"])

	_cd_timer_lbls = [null, null, null]
	for i in 3:
		var node := _build_card(_card_pos(i), _layout["card_size"], i)
		_slide_root.add_child(node)
		_cards.append(node)

# Все размеры экрана в одном месте: раскладку считает и сборка, и перерисовка,
# и разъезжались они каждый раз, когда правишь одну из двух.
func _compute_layout(vp: Vector2) -> Dictionary:
	var margin : float = vp.x * 0.022
	var gap    : float = vp.x * 0.016
	var banner_y : float = vp.y * 0.145
	var banner_h : float = vp.y * 0.115
	var cards_y  : float = banner_y + banner_h + vp.y * 0.035
	var cards_h  : float = vp.y - cards_y - vp.y * 0.045
	var card_w   : float = (vp.x - margin * 2.0 - gap * 2.0) / 3.0
	return {
		"margin": margin, "gap": gap, "cards_y": cards_y,
		"banner_pos":  Vector2(margin, banner_y),
		"banner_size": Vector2(vp.x - margin * 2.0, banner_h),
		"card_size":   Vector2(card_w, cards_h),
	}

func _card_pos(i: int) -> Vector2:
	return Vector2(float(_layout["margin"]) + i * (float(_layout["card_size"].x) + float(_layout["gap"])),
		float(_layout["cards_y"]))

# Чип «до сброса» в шапке. Время до полуночи считалось и раньше, но нигде не
# показывалось — на вопрос «когда появится новое» экран не отвечал.
func _build_reset_chip(vp: Vector2) -> void:
	var scale_x : float = vp.x / CANVAS_W
	var scale_y : float = vp.y / CANVAS_H
	var w : float = 150.0
	var h : float = 24.0 * scale_y
	# Правый край чипа обязан остаться левее строки ресурсов, иначе он налезает
	# на мешок с деньгами.
	var x : float = vp.x - (RES_RIGHT_PAD * -1.0) * scale_x - 224.0 - w
	var y : float = RES_Y * scale_y - 2.0
	var panel := Panel.new()
	panel.add_theme_stylebox_override("panel", _rounded(Color(0.10, 0.08, 0.06, 0.85), 8, Color(0.55, 0.45, 0.22, 0.9)))
	panel.size         = Vector2(w, h)
	panel.position     = Vector2(x, y)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slide_root.add_child(panel)

	_reset_lbl = Label.new()
	_reset_lbl.add_theme_font_override("font", UI_FONT)
	_reset_lbl.add_theme_font_size_override("font_size", 12)
	_apply_quests_text_fx(_reset_lbl)
	_reset_lbl.text                 = _time_to_midnight()
	_reset_lbl.modulate             = Color(1.0, 0.88, 0.50)
	_reset_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reset_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_reset_lbl.size                 = Vector2(w, h)
	_reset_lbl.position             = Vector2(x, y)
	_reset_lbl.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	_slide_root.add_child(_reset_lbl)

# Скруглённая подложка с рамкой — общий кирпич всех панелей этого экрана.
func _rounded(fill: Color, radius: int, border: Color = Color(0, 0, 0, 0), border_w: int = 2) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.corner_radius_top_left     = radius
	sb.corner_radius_top_right    = radius
	sb.corner_radius_bottom_left  = radius
	sb.corner_radius_bottom_right = radius
	if border.a > 0.0:
		sb.border_color = border
		sb.border_width_left   = border_w
		sb.border_width_right  = border_w
		sb.border_width_top    = border_w
		sb.border_width_bottom = border_w
	return sb

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

func _build_bonus_banner(pos: Vector2, size: Vector2) -> void:
	_bonus_root = Node2D.new()
	_slide_root.add_child(_bonus_root)
	var w : float = size.x
	var h : float = size.y
	var avail : bool = QuestManager.daily_bonus_avail

	var panel := Panel.new()
	panel.add_theme_stylebox_override("panel", _rounded(
		Color(0.13, 0.20, 0.08, 0.95) if avail else Color(0.09, 0.09, 0.08, 0.92), 10,
		Color(0.55, 0.95, 0.35, 0.95) if avail else Color(0.30, 0.30, 0.28, 0.8)))
	panel.size         = size
	panel.position     = pos
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bonus_root.add_child(panel)

	var ico := _make_icon(TEX_MONEYBAG, h * 0.66)
	ico.position     = pos + Vector2(10.0, (h - h * 0.66) * 0.5)
	ico.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bonus_root.add_child(ico)

	var lbl := Label.new()
	lbl.add_theme_font_override("font", UI_FONT)
	lbl.add_theme_font_size_override("font_size", 14)
	_apply_quests_text_fx(lbl)
	lbl.text                 = "БОНУС ЗА ВХОД   +%d $" % QuestManager.ENTRY_BONUS
	lbl.modulate             = Color(0.85, 1.0, 0.60) if avail else Color(0.62, 0.62, 0.58)
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl.size                 = Vector2(w - 120.0, h)
	lbl.position             = pos + Vector2(14.0 + h * 0.66, 0.0)
	lbl.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	_bonus_root.add_child(lbl)

	if not avail:
		# Состояние словом и галочкой, а не одним лишь приглушением цвета.
		var done := Label.new()
		done.add_theme_font_override("font", UI_FONT)
		done.add_theme_font_size_override("font_size", 12)
		_apply_quests_text_fx(done)
		done.text                 = "✓ ЗАБРАНО"
		done.modulate             = Color(0.60, 0.80, 0.50)
		done.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		done.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		done.size                 = Vector2(w - 16.0, h)
		done.position             = pos
		done.mouse_filter         = Control.MOUSE_FILTER_IGNORE
		_bonus_root.add_child(done)
		return

	var btn_size := Vector2(112.0, h - 12.0)
	var btn_pos  := pos + Vector2(w - btn_size.x - 8.0, 6.0)
	_claim_button(_bonus_root, btn_pos, btn_size, "ЗАБРАТЬ",
		_on_claim_bonus.bind(btn_pos + btn_size * 0.5))

# Кнопка получения награды — одна на баннер и на карточки, чтобы они не
# разъезжались по виду и по отклику на нажатие.
func _claim_button(root: Node, pos: Vector2, size: Vector2, text: String, action: Callable) -> void:
	var visual := Control.new()
	visual.size         = size
	visual.position     = pos
	visual.pivot_offset = size * 0.5
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(visual)

	var bg := Panel.new()
	bg.add_theme_stylebox_override("panel", _rounded(Color(0.22, 0.52, 0.14, 0.98), 8,
		Color(0.65, 1.0, 0.45, 0.95)))
	bg.size         = size
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	visual.add_child(bg)

	var lbl := Label.new()
	lbl.add_theme_font_override("font", UI_FONT)
	lbl.add_theme_font_size_override("font_size", 14)
	_apply_quests_text_fx(lbl)
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
	root.add_child(btn)

# ── Карточка задания ─────────────────────────────────────────────────────────
# Три состояния, и каждое различается ФОРМОЙ, ЗНАЧКОМ И СЛОВОМ, а не только
# цветом: готовое — золотая рамка с пульсацией и кнопка «ЗАБРАТЬ», в процессе —
# полоса прогресса с числами, забранное — галочка и таймер до нового задания.
# Сложность тоже кодируется дважды: номер ① ② ③ в медальоне плюс слово.
# См. /Концепция/Экран заданий.md
func _build_card(pos: Vector2, size: Vector2, slot: int) -> Node2D:
	var card := Node2D.new()
	_build_card_content(card, pos, size, slot)
	return card

func _tier_look(tier: String) -> Dictionary:
	match tier:
		"easy":   return { "col": CLR_STRIPE_EASY,   "name": "ЛЁГКОЕ",  "num": "1" }
		"medium": return { "col": CLR_STRIPE_MEDIUM, "name": "СРЕДНЕЕ", "num": "2" }
	return { "col": CLR_STRIPE_HARD, "name": "ТЯЖЁЛОЕ", "num": "3" }

func _build_card_content(root: Node2D, pos: Vector2, size: Vector2, slot: int) -> void:
	var q    : Dictionary = QuestManager.daily_quests[slot]
	var look : Dictionary = _tier_look(String(q["tier"]))
	var cd   : bool = QuestManager.is_slot_on_cooldown(slot)
	var done : bool = bool(q["completed"])
	var claimed : bool = bool(q["claimed"])
	var ready : bool = done and not claimed and not cd

	var w : float = size.x
	var h : float = size.y

	# Подложка. Готовая карточка — золотая рамка; остальные — спокойная тёмная.
	var panel := Panel.new()
	panel.add_theme_stylebox_override("panel", _rounded(
		Color(0.12, 0.16, 0.07, 0.96) if ready else CLR_CARD, 12,
		Color(1.0, 0.82, 0.25, 1.0) if ready else Color(0.28, 0.24, 0.20, 0.9),
		3 if ready else 2))
	panel.size         = size
	panel.position     = pos
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(panel)
	if ready:
		# Пульсация рамки: единственный элемент экрана, который двигается, —
		# взгляд идёт к нему сам, без чтения.
		var tw := panel.create_tween().set_loops()
		tw.tween_property(panel, "modulate", Color(1.15, 1.12, 1.0), 0.55)
		tw.tween_property(panel, "modulate", Color(1.0, 1.0, 1.0), 0.55)

	_build_tier_badge(root, pos + Vector2(10.0, 10.0), look)

	var pad : float = 12.0
	var def : Dictionary = QuestManager._daily_def(slot)

	var title := Label.new()
	title.add_theme_font_override("font", UI_FONT)
	title.add_theme_font_size_override("font_size", 16)
	_apply_quests_text_fx(title)
	title.text          = String(def.get("title", ""))
	title.modulate      = Color(1.0, 0.97, 0.90)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD
	title.size          = Vector2(w - pad * 2.0, 44.0)
	title.position      = pos + Vector2(pad, 44.0)
	title.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	root.add_child(title)

	var desc := Label.new()
	desc.add_theme_font_override("font", UI_FONT)
	desc.add_theme_font_size_override("font_size", 11)
	_apply_quests_text_fx(desc)
	desc.text          = String(def.get("desc", ""))
	# Не тусклее 0.80 белого — иначе описание не читается на подложке.
	desc.modulate      = Color(0.86, 0.86, 0.82)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc.size          = Vector2(w - pad * 2.0, 40.0)
	desc.position      = pos + Vector2(pad, 90.0)
	desc.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	root.add_child(desc)

	# Награда иконкой, а не текстом «+100 $»: во всей остальной игре валюта
	# показана спрайтом, и текст здесь читался как чужеродный.
	_build_reward_row(root, pos + Vector2(pad, h - 96.0), w - pad * 2.0, def)

	if cd:
		_build_cooldown_block(root, pos, size, slot)
		return

	_build_progress_bar(root, pos + Vector2(pad, h - 132.0), w - pad * 2.0, slot,
		Color(look["col"]))

	if ready:
		var bs := Vector2(w - pad * 2.0, 42.0)
		var bp := pos + Vector2(pad, h - 52.0)
		_claim_button(root, bp, bs, "ЗАБРАТЬ", _on_claim_daily.bind(slot, bp + bs * 0.5))
	else:
		var state := Label.new()
		state.add_theme_font_override("font", UI_FONT)
		state.add_theme_font_size_override("font_size", 12)
		_apply_quests_text_fx(state)
		state.text                 = "✓ ЗАБРАНО" if claimed else "ИДЁТ"
		state.modulate             = Color(0.60, 0.80, 0.50) if claimed else Color(0.70, 0.70, 0.66)
		state.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		state.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		state.size                 = Vector2(w - pad * 2.0, 42.0)
		state.position             = pos + Vector2(pad, h - 52.0)
		state.mouse_filter         = Control.MOUSE_FILTER_IGNORE
		root.add_child(state)

# Медальон сложности: кружок с НОМЕРОМ плюс слово рядом. Номер обязателен —
# по одному цвету полоски уровень сложности не различает ни дальтоник, ни
# игрок, который видит экран впервые.
func _build_tier_badge(root: Node2D, pos: Vector2, look: Dictionary) -> void:
	var col : Color = look["col"]
	const SZ := 26.0
	var disc := Panel.new()
	disc.add_theme_stylebox_override("panel", _rounded(
		Color(col.r * 0.35, col.g * 0.35, col.b * 0.35, 0.98), int(SZ * 0.5), col, 2))
	disc.size         = Vector2(SZ, SZ)
	disc.position     = pos
	disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(disc)

	var num := Label.new()
	num.add_theme_font_override("font", UI_FONT)
	num.add_theme_font_size_override("font_size", 15)
	_apply_quests_text_fx(num)
	num.text                 = String(look["num"])
	num.modulate             = Color(1, 1, 1)
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	num.size                 = Vector2(SZ, SZ)
	num.position             = pos
	num.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	root.add_child(num)

	var name_lbl := Label.new()
	name_lbl.add_theme_font_override("font", UI_FONT)
	name_lbl.add_theme_font_size_override("font_size", 11)
	_apply_quests_text_fx(name_lbl)
	name_lbl.text               = String(look["name"])
	name_lbl.modulate           = col
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_lbl.size               = Vector2(120.0, SZ)
	name_lbl.position           = pos + Vector2(SZ + 8.0, 0.0)
	name_lbl.mouse_filter       = Control.MOUSE_FILTER_IGNORE
	root.add_child(name_lbl)

# Полоса прогресса с числами прямо на ней. Раньше прогресс был только текстом
# «0 / 1000 пицц» — взглядом такое не читается, а именно по нему игрок решает,
# идти ли в ещё один забег.
func _build_progress_bar(root: Node2D, pos: Vector2, w: float, slot: int, col: Color) -> void:
	const H := 18.0
	var pr : Vector2i = QuestManager.daily_progress(slot)
	var frac : float = clampf(float(pr.x) / maxf(1.0, float(pr.y)), 0.0, 1.0)

	var bg := Panel.new()
	bg.add_theme_stylebox_override("panel", _rounded(Color(0.05, 0.04, 0.03, 0.95), 6,
		Color(0.30, 0.27, 0.22, 0.9)))
	bg.size         = Vector2(w, H)
	bg.position     = pos
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)

	if frac > 0.0:
		var fill := Panel.new()
		fill.add_theme_stylebox_override("panel", _rounded(col, 6))
		fill.size         = Vector2(maxf(6.0, (w - 4.0) * frac), H - 4.0)
		fill.position     = pos + Vector2(2.0, 2.0)
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(fill)

	var lbl := Label.new()
	lbl.add_theme_font_override("font", UI_FONT)
	lbl.add_theme_font_size_override("font_size", 10)
	_apply_quests_text_fx(lbl)
	# У части условий («пройди кампанию») промежуточного счётчика нет, и текст
	# оставался «0 / 1» на полной полосе. Выполненное подписываем словом.
	lbl.text                 = "ГОТОВО" if _slot_done(slot) else QuestManager.daily_progress_text(slot)
	lbl.modulate             = Color(1, 1, 1)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl.size                 = Vector2(w, H)
	lbl.position             = pos
	lbl.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	root.add_child(lbl)

func _slot_done(slot: int) -> bool:
	return bool((QuestManager.daily_quests[slot] as Dictionary).get("completed", false))

func _build_reward_row(root: Node2D, pos: Vector2, w: float, def: Dictionary) -> void:
	var d : int = int(def.get("reward_d", 0))
	var t : int = int(def.get("reward_t", 0))
	var x : int = int(def.get("reward_xp", 0))
	var tex : Texture2D = TEX_DOLLAR
	var txt : String = ""
	if d > 0:
		txt = "+%d" % d
	elif t > 0:
		tex = TEX_TOKEN
		txt = "+%d" % t
	elif x > 0:
		tex = null
		txt = "+%d ОПЫТ" % x

	var ico_sz := 26.0
	if tex != null:
		var ico := _make_icon(tex, ico_sz)
		ico.position     = pos
		ico.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(ico)

	var lbl := Label.new()
	lbl.add_theme_font_override("font", UI_FONT)
	lbl.add_theme_font_size_override("font_size", 18)
	_apply_quests_text_fx(lbl)
	lbl.text               = txt
	lbl.modulate           = Color(1.0, 0.88, 0.35)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.size               = Vector2(w - ico_sz - 6.0, ico_sz)
	lbl.position           = pos + Vector2(ico_sz + 6.0 if tex != null else 0.0, 0.0)
	lbl.mouse_filter       = Control.MOUSE_FILTER_IGNORE
	root.add_child(lbl)

# Слот на откате: вместо полосы и кнопки — часы и таймер до нового задания.
# Метку помним, чтобы _process тикал её, не пересобирая карточку.
func _build_cooldown_block(root: Node2D, pos: Vector2, size: Vector2, slot: int) -> void:
	var w : float = size.x
	var h : float = size.y

	var hint := Label.new()
	hint.add_theme_font_override("font", UI_FONT)
	hint.add_theme_font_size_override("font_size", 11)
	_apply_quests_text_fx(hint)
	hint.text                 = "НОВОЕ ЗАДАНИЕ ЧЕРЕЗ"
	hint.modulate             = Color(0.80, 0.80, 0.76)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.size                 = Vector2(w - 24.0, 18.0)
	hint.position             = pos + Vector2(12.0, h - 132.0)
	hint.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	root.add_child(hint)

	var cd_lbl := Label.new()
	cd_lbl.add_theme_font_override("font", UI_FONT)
	cd_lbl.add_theme_font_size_override("font_size", 22)
	_apply_quests_text_fx(cd_lbl)
	cd_lbl.text                 = _format_cooldown(QuestManager.slot_cooldown_remaining(slot))
	cd_lbl.modulate             = Color(1.0, 0.95, 0.80)
	cd_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cd_lbl.size                 = Vector2(w - 24.0, 30.0)
	cd_lbl.position             = pos + Vector2(12.0, h - 112.0)
	cd_lbl.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	root.add_child(cd_lbl)
	_cd_timer_lbls[slot] = cd_lbl

	var done := Label.new()
	done.add_theme_font_override("font", UI_FONT)
	done.add_theme_font_size_override("font_size", 12)
	_apply_quests_text_fx(done)
	done.text                 = "✓ ЗАБРАНО"
	done.modulate             = Color(0.60, 0.80, 0.50)
	done.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	done.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	done.size                 = Vector2(w - 24.0, 42.0)
	done.position             = pos + Vector2(12.0, h - 52.0)
	done.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	root.add_child(done)

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
	return "ДО СБРОСА  %02d:%02d:%02d" % [rh, rm, rs]

func _refresh() -> void:
	if not is_instance_valid(_slide_root):
		return
	if is_instance_valid(_bonus_root):
		_bonus_root.queue_free()
	_build_bonus_banner(_layout["banner_pos"], _layout["banner_size"])

	for c in _cards:
		if is_instance_valid(c):
			c.queue_free()
	_cards.clear()
	_cd_timer_lbls = [null, null, null]
	for i in 3:
		var node := _build_card(_card_pos(i), _layout["card_size"], i)
		_slide_root.add_child(node)
		_cards.append(node)

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
