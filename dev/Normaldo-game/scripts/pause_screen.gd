extends Control

# ─── Пауза ────────────────────────────────────────────────────────────────────
# Две колонки: слева ЭТОТ ЗАБЕГ и действия, справа задания дня.
#
# До переделки пауза показывала задания дня — и молчала про сам забег, хотя
# поставили на паузу именно его: счётчики жили в HUD, который на паузе затемнён
# и наполовину закрыт панелью. А ещё с паузы нельзя было убавить звук — только
# выйти в меню, потеряв прогресс, при том что игра шумит ровно в забеге.
#
# См. /Концепция/Экран паузы.md

const UI_FONT      := preload("res://assets/fonts/RussoOne-Regular.ttf")
const TEX_PIZZA    := preload("res://assets/items/pizza.png")
const TEX_DOLLAR   := preload("res://assets/items/dollar.png")

const CLR_PAGE      := Color(0.07, 0.07, 0.10, 0.96)
const CLR_PAGE_EDGE := Color(0.42, 0.48, 0.62, 0.85)
const CLR_ROW       := Color(0.11, 0.11, 0.15, 0.95)
const CLR_ROW_EDGE  := Color(0.26, 0.27, 0.34, 0.85)
const CLR_ACCENT    := Color(0.55, 0.85, 1.00, 0.95)
const CLR_GOLD      := Color(1.00, 0.85, 0.35)
const CLR_TEXT      := Color(0.96, 0.97, 1.00)
const CLR_TEXT_DIM  := Color(0.84, 0.86, 0.90)
const CLR_GO        := Color(0.22, 0.52, 0.14, 0.98)
const CLR_GO_EDGE   := Color(0.65, 1.00, 0.45, 0.95)
const CLR_QUIT_EDGE := Color(1.00, 0.55, 0.50, 0.90)

const TIER_STR : Dictionary = { "easy": "ЛЁГКОЕ", "medium": "СРЕДНЕЕ", "hard": "ТЯЖЁЛОЕ" }
const TIER_COL : Dictionary = {
	"easy":   Color(0.55, 0.85, 1.00),
	"medium": Color(1.00, 0.78, 0.30),
	"hard":   Color(1.00, 0.45, 0.45),
}

# ── Раскладка (канвас 430×192, как на остальных экранах) ─────────────────────
const CANVAS_W : float = 430.0
const CANVAS_H : float = 192.0
const TITLE_Y  : float = 8.0
const TITLE_H  : float = 22.0
const LEFT_X   : float = 26.0
const LEFT_W   : float = 176.0
const RIGHT_X  : float = 210.0
const RIGHT_W  : float = 194.0
const COL_Y    : float = 36.0
const COL_H    : float = 148.0
const PAD      : float = 12.0

var _hud   : Node = null
var _lay   : Dictionary = {}
var _root  : Control = null

func setup(hud: Node) -> void:
	_hud = hud

func _ready() -> void:
	# Экран живёт при `get_tree().paused = true` — иначе он сам замрёт вместе с
	# игрой и кнопки перестанут нажиматься.
	process_mode = Node.PROCESS_MODE_ALWAYS
	var vp := get_viewport().get_visible_rect().size
	size         = vp
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index      = 90
	_build(vp)

func _layout(vp: Vector2) -> Dictionary:
	var sx : float = vp.x / CANVAS_W
	var sy : float = vp.y / CANVAS_H
	var top : float = COL_Y * sy
	var hgt : float = COL_H * sy
	return {
		"sx": sx, "sy": sy,
		"left":  Rect2(LEFT_X  * sx, top, LEFT_W  * sx, hgt),
		"right": Rect2(RIGHT_X * sx, top, RIGHT_W * sx, hgt),
	}

func _build(vp: Vector2) -> void:
	_lay = _layout(vp)
	var sy : float = _lay["sy"]

	var dim := ColorRect.new()
	dim.color        = Color(0.0, 0.0, 0.0, 0.76)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	UiKit.place(self, dim, Vector2.ZERO, vp)

	_root = Control.new()
	_root.mouse_filter = Control.MOUSE_FILTER_PASS
	UiKit.place(self, _root, Vector2.ZERO, vp)

	var title := Label.new()
	title.add_theme_font_override("font", UI_FONT)
	title.add_theme_font_size_override("font_size", 22)
	_apply_text_fx(title)
	title.text                 = "ПАУЗА"
	title.modulate             = CLR_ACCENT
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	title.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	UiKit.place(_root, title, Vector2(0.0, TITLE_Y * sy), Vector2(vp.x, TITLE_H * sy))

	_build_run_panel()
	_build_quests_panel()

# ── Левая колонка: этот забег + действия ─────────────────────────────────────
func _build_run_panel() -> void:
	var r : Rect2 = _lay["left"]
	UiKit.panel(_root, r.position, r.size, CLR_PAGE, 12, CLR_PAGE_EDGE, 2)

	var x : float = r.position.x + PAD
	var w : float = r.size.x - PAD * 2.0
	var y : float = r.position.y + PAD

	_caption("ЭТОТ ЗАБЕГ", Vector2(x, y), w, CLR_ACCENT)
	y += 20.0

	# Собранное за забег — то, ради чего паузу и жмут. В HUD это есть, но он на
	# паузе затемнён и наполовину закрыт.
	var pizzas  : int = _run_pizzas()
	var dollars : int = _run_dollars()
	var third : float = w / 3.0
	_stat_cell(Vector2(x, y), third, TEX_PIZZA, str(pizzas))
	_stat_cell(Vector2(x + third, y), third, TEX_DOLLAR, str(dollars))
	_time_cell(Vector2(x + third * 2.0, y), third, _fmt_time(_run_time()))
	y += 40.0

	# Жир — словом и числом, ровно как в забеге.
	var fat : int = _fat_state()
	var names : Array = _hud.get("_FAT_NAMES") if _hud != null else []
	var fat_name : String = String(names[clampi(fat, 0, names.size() - 1)]) if names.size() > 0 else "—"
	var fp : Vector2i = _fat_progress(fat)
	UiKit.panel(_root, Vector2(x, y), Vector2(w, 34.0), CLR_ROW, 8, CLR_ROW_EDGE, 1)
	var flbl := Label.new()
	flbl.add_theme_font_override("font", UI_FONT)
	flbl.add_theme_font_size_override("font_size", 11)
	_apply_text_fx(flbl)
	flbl.text               = "ЖИР · %s" % fat_name
	flbl.modulate           = CLR_TEXT
	flbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	flbl.mouse_filter       = Control.MOUSE_FILTER_IGNORE
	UiKit.place(_root, flbl, Vector2(x + 8.0, y + 2.0), Vector2(w - 16.0, 16.0))
	_bar(Vector2(x + 8.0, y + 19.0), w - 16.0, 11.0,
		float(fp.x) / maxf(1.0, float(fp.y)), Color(1.0, 0.55, 0.10),
		"МАКСИМУМ" if fp.y <= 0 else "%d / %d" % [fp.x, fp.y])
	y += 40.0

	# Рекорд — чтобы текущие 137 было с чем сравнить.
	var best : int = int(SaveData.get_skin_best_for(SaveData.active_skin))
	var blbl := Label.new()
	blbl.add_theme_font_override("font", UI_FONT)
	blbl.add_theme_font_size_override("font_size", 10)
	_apply_text_fx(blbl)
	blbl.text               = "Рекорд скина: %d пицц" % best if best > 0 else "Рекорда пока нет"
	blbl.modulate           = CLR_TEXT_DIM
	blbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	blbl.mouse_filter       = Control.MOUSE_FILTER_IGNORE
	UiKit.place(_root, blbl, Vector2(x, y), Vector2(w, 14.0))

	# Действия прижаты к низу панели: их место постоянно, куда бы ни выросли
	# счётчики выше.
	const BTN_H : float = 34.0
	var by : float = r.position.y + r.size.y - PAD - BTN_H * 2.0 - 8.0
	_action(Vector2(x, by), Vector2(w, BTN_H), "ПРОДОЛЖИТЬ", 15,
		CLR_GO, CLR_GO_EDGE, Color(0.92, 1.0, 0.85), _on_resume)
	# Настройки и выход — вдвое уже и контурные: выход разрушителен и выглядеть
	# равным продолжению не должен.
	var half : float = (w - 8.0) * 0.5
	_action(Vector2(x, by + BTN_H + 8.0), Vector2(half, BTN_H), "НАСТРОЙКИ", 12,
		Color(0.10, 0.12, 0.18, 0.95), CLR_ACCENT, CLR_TEXT, _on_settings)
	_action(Vector2(x + half + 8.0, by + BTN_H + 8.0), Vector2(half, BTN_H), "ВЫХОД", 12,
		Color(0.14, 0.08, 0.09, 0.95), CLR_QUIT_EDGE, Color(1.0, 0.80, 0.78), _on_quit)

# ── Правая колонка: задания дня ──────────────────────────────────────────────
func _build_quests_panel() -> void:
	var r : Rect2 = _lay["right"]
	UiKit.panel(_root, r.position, r.size, CLR_PAGE, 12, CLR_PAGE_EDGE, 2)

	var x : float = r.position.x + PAD
	var w : float = r.size.x - PAD * 2.0
	var y : float = r.position.y + PAD
	_caption("ЗАДАНИЯ ДНЯ", Vector2(x, y), w, CLR_GOLD)
	y += 20.0

	var slots : int = QuestManager.daily_quests.size()
	if slots == 0:
		var empty := Label.new()
		empty.add_theme_font_override("font", UI_FONT)
		empty.add_theme_font_size_override("font_size", 11)
		_apply_text_fx(empty)
		empty.text         = "Заданий пока нет"
		empty.modulate     = CLR_TEXT_DIM
		empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
		UiKit.place(_root, empty, Vector2(x, y), Vector2(w, 16.0))
		return

	var avail : float = r.position.y + r.size.y - PAD - y
	# Высоту строки ограничиваем: растянутая на треть панели карточка из трёх
	# строк текста — это дыра посередине, а не «просторно».
	var row_h : float = minf(78.0, (avail - 6.0 * float(slots - 1)) / float(slots))
	y += maxf(0.0, (avail - (row_h + 6.0) * float(slots) + 6.0) * 0.5)
	for slot in slots:
		_quest_row(Vector2(x, y), Vector2(w, row_h), slot)
		y += row_h + 6.0

func _quest_row(pos: Vector2, size: Vector2, slot: int) -> void:
	var q     : Dictionary = QuestManager.daily_quests[slot]
	var on_cd : bool = QuestManager.is_slot_on_cooldown(slot)
	var done  : bool = bool(q.get("completed", false))
	var taken : bool = bool(q.get("claimed", false))
	var tier  : String = str(q.get("tier", "easy"))
	var col   : Color  = TIER_COL.get(tier, Color.WHITE) as Color
	var def   : Dictionary = QuestManager._daily_def(slot)

	UiKit.panel(_root, pos, size,
		Color(0.06, 0.06, 0.09, 0.90) if on_cd else CLR_ROW, 10,
		Color(col.r, col.g, col.b, 0.55) if not on_cd else CLR_ROW_EDGE, 2)

	var title := Label.new()
	title.add_theme_font_override("font", UI_FONT)
	title.add_theme_font_size_override("font_size", 12)
	_apply_text_fx(title)
	title.text                  = "—" if on_cd else String(def.get("title", ""))
	title.modulate              = CLR_TEXT if not on_cd else Color(0.65, 0.66, 0.72)
	title.vertical_alignment    = VERTICAL_ALIGNMENT_CENTER
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.mouse_filter          = Control.MOUSE_FILTER_IGNORE
	UiKit.place(_root, title, pos + Vector2(9.0, 3.0), Vector2(size.x - 90.0, 16.0))

	var tl := Label.new()
	tl.add_theme_font_override("font", UI_FONT)
	tl.add_theme_font_size_override("font_size", 9)
	_apply_text_fx(tl)
	tl.text                 = String(TIER_STR.get(tier, tier.to_upper()))
	tl.modulate             = col
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	tl.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	UiKit.place(_root, tl, pos + Vector2(size.x - 82.0, 3.0), Vector2(74.0, 16.0))

	var desc := Label.new()
	desc.add_theme_font_override("font", UI_FONT)
	desc.add_theme_font_size_override("font_size", 10)
	_apply_text_fx(desc)
	desc.text                  = "Слот на кулдауне" if on_cd else String(def.get("desc", ""))
	desc.modulate              = Color(CLR_TEXT_DIM.r, CLR_TEXT_DIM.g, CLR_TEXT_DIM.b, 0.92)
	desc.vertical_alignment    = VERTICAL_ALIGNMENT_CENTER
	desc.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	desc.mouse_filter          = Control.MOUSE_FILTER_IGNORE
	UiKit.place(_root, desc, pos + Vector2(9.0, 20.0), Vector2(size.x - 18.0, 14.0))

	# Полоса прогресса с числами — раньше состояние было только текстом, а
	# именно по нему игрок решает, идти ли ещё круг.
	var line : String
	var frac : float
	var bcol : Color = col
	if on_cd:
		line = "новое через %s" % _fmt_cooldown(QuestManager.slot_cooldown_remaining(slot))
		frac = 0.0
		bcol = Color(0.45, 0.46, 0.52)
	elif taken:
		line = "ЗАБРАНО"
		frac = 1.0
		bcol = Color(0.45, 0.80, 0.35)
	elif done:
		line = "ГОТОВО — ЗАБЕРИ НАГРАДУ"
		frac = 1.0
		bcol = Color(0.45, 1.00, 0.55)
	else:
		var pr : Vector2i = QuestManager.daily_progress(slot)
		line = QuestManager.daily_progress_text(slot)
		frac = float(pr.x) / maxf(1.0, float(pr.y))
	_bar(pos + Vector2(9.0, size.y - 20.0), size.x - 18.0, 15.0, frac, bcol, line)

# ── Кирпичи ──────────────────────────────────────────────────────────────────
func _caption(text: String, pos: Vector2, w: float, col: Color) -> void:
	var l := Label.new()
	l.add_theme_font_override("font", UI_FONT)
	l.add_theme_font_size_override("font_size", 12)
	_apply_text_fx(l)
	l.text               = text
	l.modulate           = col
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter       = Control.MOUSE_FILTER_IGNORE
	UiKit.place(_root, l, pos, Vector2(w, 16.0))

func _stat_cell(pos: Vector2, w: float, tex: Texture2D, value: String) -> void:
	const ICO : float = 22.0
	var ico := TextureRect.new()
	ico.texture      = tex
	ico.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ico.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
	ico.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.place(_root, ico, pos + Vector2(0.0, 4.0), Vector2(ICO, ICO))

	var l := Label.new()
	l.add_theme_font_override("font", UI_FONT)
	l.add_theme_font_size_override("font_size", 16)
	_apply_text_fx(l)
	l.text               = value
	l.modulate           = CLR_TEXT
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter       = Control.MOUSE_FILTER_IGNORE
	UiKit.place(_root, l, pos + Vector2(ICO + 4.0, 4.0), Vector2(w - ICO - 6.0, ICO))

func _time_cell(pos: Vector2, w: float, value: String) -> void:
	var l := Label.new()
	l.add_theme_font_override("font", UI_FONT)
	l.add_theme_font_size_override("font_size", 16)
	_apply_text_fx(l)
	l.text                 = value
	l.modulate             = CLR_TEXT
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	UiKit.place(_root, l, pos + Vector2(0.0, 4.0), Vector2(w, 22.0))

	var cap := Label.new()
	cap.add_theme_font_override("font", UI_FONT)
	cap.add_theme_font_size_override("font_size", 8)
	_apply_text_fx(cap)
	cap.text                 = "ВРЕМЯ"
	cap.modulate             = Color(0.66, 0.68, 0.74)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cap.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	UiKit.place(_root, cap, pos + Vector2(0.0, 26.0), Vector2(w, 10.0))

# Полоса с числами ПОВЕРХ неё — общий приём всех экранов игры.
func _bar(pos: Vector2, w: float, h: float, frac: float, col: Color, text: String) -> void:
	UiKit.panel(_root, pos, Vector2(w, h),
		Color(0.03, 0.03, 0.05, 0.95), 6, Color(0.28, 0.30, 0.38, 0.9), 1)
	var f : float = clampf(frac, 0.0, 1.0)
	if f > 0.0:
		var fill := Panel.new()
		fill.add_theme_stylebox_override("panel", UiKit.rounded(
			Color(col.r, col.g, col.b, 0.85), 5))
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		UiKit.place(_root, fill, pos + Vector2(2.0, 2.0),
			Vector2(maxf(3.0, (w - 4.0) * f), h - 4.0))
	if text == "":
		return
	var l := Label.new()
	l.add_theme_font_override("font", UI_FONT)
	l.add_theme_font_size_override("font_size", 9)
	_apply_text_fx(l)
	l.text                 = text
	l.modulate             = Color(1, 1, 1)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	UiKit.place(_root, l, pos, Vector2(w, h))

func _action(pos: Vector2, size: Vector2, text: String, font_sz: int,
		fill: Color, border: Color, fg: Color, action: Callable) -> void:
	var visual := Control.new()
	visual.pivot_offset = size * 0.5
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	visual.process_mode = Node.PROCESS_MODE_ALWAYS
	UiKit.place(_root, visual, pos, size)

	var bg := Panel.new()
	bg.add_theme_stylebox_override("panel", UiKit.rounded(fill, 8, border, 2))
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.place(visual, bg, Vector2.ZERO, size)

	var lbl := Label.new()
	lbl.add_theme_font_override("font", UI_FONT)
	lbl.add_theme_font_size_override("font_size", font_sz)
	_apply_text_fx(lbl)
	lbl.text                 = text
	lbl.modulate             = fg
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	UiKit.place(visual, lbl, Vector2.ZERO, size)

	var btn := Button.new()
	btn.flat         = true
	btn.focus_mode   = Control.FOCUS_NONE
	btn.process_mode = Node.PROCESS_MODE_ALWAYS
	btn.pressed.connect(func():
		if _hud and _hud.has_method("_play_btn_sfx"):
			_hud._play_btn_sfx()
		action.call())
	btn.button_down.connect(_press_anim.bind(visual, true))
	btn.button_up.connect(_press_anim.bind(visual, false))
	btn.mouse_exited.connect(_press_anim.bind(visual, false))
	UiKit.place(_root, btn, pos, size)

# ── Данные забега ────────────────────────────────────────────────────────────
func _normaldo() -> Node:
	if _hud == null:
		return null
	var scene := _hud.get_parent()
	return scene.get_node_or_null("Normaldo") if scene != null else null

func _run_pizzas() -> int:
	var n := _normaldo()
	return int(n.get("_total_pizza_count")) if n != null else 0

func _run_dollars() -> int:
	return int(_hud.get("_dollars_this_run")) if _hud != null else 0

func _run_time() -> float:
	return float(_hud.get("_elapsed_time")) if _hud != null else 0.0

func _fat_state() -> int:
	var n := _normaldo()
	return int(n.get("fat_state")) if n != null else 0

# Сколько пицц набрано внутри текущего состояния и сколько нужно до следующего.
# Пустой знаменатель означает «максимум» — тот же порядок, что в HUD забега.
func _fat_progress(fat: int) -> Vector2i:
	var n := _normaldo()
	if n == null or _hud == null:
		return Vector2i(0, 0)
	var thr : Array = _hud.get("FAT_THRESHOLDS")
	var max_fat : int = int(_hud.call("_max_unlocked_fat"))
	if fat >= thr.size() or fat >= max_fat:
		return Vector2i(0, 0)
	var start : int = 0 if fat == 0 else int(thr[fat - 1])
	var size  : int = int(thr[fat]) - start
	var have  : int = int(n.get("_pizza_count")) - start
	return Vector2i(clampi(have, 0, size), size)

func _fmt_time(sec: float) -> String:
	var t : int = int(sec)
	return "%d:%02d" % [t / 60, t % 60]

func _fmt_cooldown(sec_total: int) -> String:
	if sec_total <= 0:
		return "0:00"
	var h : int = sec_total / 3600
	var m : int = (sec_total % 3600) / 60
	var s : int = sec_total % 60
	if h > 0:
		return "%d:%02d:%02d" % [h, m, s]
	return "%d:%02d" % [m, s]

# ── Действия ─────────────────────────────────────────────────────────────────
# «ПРОДОЛЖИТЬ» не снимает паузу сразу: экран уходит, а игра ждёт отсчёта 3-2-1.
# См. HUD._resume_with_countdown и /Концепция/Экран паузы.md
func _on_resume() -> void:
	if _hud != null and _hud.has_method("_resume_with_countdown"):
		_hud.call("_resume_with_countdown")
	elif _hud != null and _hud.has_method("_close_pause_menu"):
		_hud.call("_close_pause_menu")

func _on_settings() -> void:
	# Игра остаётся на паузе: убавить звук и вернуться — ровно то, зачем сюда
	# приходят. См. /Концепция/Экран паузы.md
	if _hud != null and _hud.has_method("_show_settings_modal"):
		_hud.call("_show_settings_modal")

func _on_quit() -> void:
	_show_quit_confirm()

# Подтверждение с ПОЛНЫМ затемнением под собой: раньше диалог был
# полупрозрачной панелью поверх карточек, и заголовок читался вместе с текстом
# задания под ним.
func _show_quit_confirm() -> void:
	var vp := get_viewport().get_visible_rect().size
	var layer := Control.new()
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	layer.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.z_index      = 5
	UiKit.place(self, layer, Vector2.ZERO, vp)

	var dim := ColorRect.new()
	dim.color        = Color(0.0, 0.0, 0.0, 0.80)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	UiKit.place(layer, dim, Vector2.ZERO, vp)

	var pw : float = 340.0
	var ph : float = 168.0
	var px : float = (vp.x - pw) * 0.5
	var py : float = (vp.y - ph) * 0.5
	var panel := Panel.new()
	panel.add_theme_stylebox_override("panel", UiKit.rounded(
		Color(0.09, 0.07, 0.09, 0.99), 12, CLR_QUIT_EDGE, 2))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.place(layer, panel, Vector2(px, py), Vector2(pw, ph))

	var t := Label.new()
	t.add_theme_font_override("font", UI_FONT)
	t.add_theme_font_size_override("font_size", 18)
	_apply_text_fx(t)
	t.text                 = "ВЫЙТИ ИЗ ЗАБЕГА?"
	t.modulate             = Color(1.0, 0.75, 0.72)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	t.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	UiKit.place(layer, t, Vector2(px, py + 18.0), Vector2(pw, 26.0))

	var d := Label.new()
	d.add_theme_font_override("font", UI_FONT)
	d.add_theme_font_size_override("font_size", 11)
	_apply_text_fx(d)
	d.text                 = "Пиццы и доллары этого забега не засчитаются"
	d.modulate             = CLR_TEXT_DIM
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	d.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	d.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	UiKit.place(layer, d, Vector2(px + 16.0, py + 50.0), Vector2(pw - 32.0, 18.0))

	const BW : float = 140.0
	const BH : float = 38.0
	var by : float = py + ph - BH - 18.0
	_confirm_btn(layer, Vector2(px + pw * 0.5 - BW - 6.0, by), Vector2(BW, BH),
		"ОСТАТЬСЯ", Color(0.12, 0.26, 0.42, 0.98), CLR_ACCENT, CLR_TEXT,
		func(): layer.queue_free())
	_confirm_btn(layer, Vector2(px + pw * 0.5 + 6.0, by), Vector2(BW, BH),
		"ВЫЙТИ", Color(0.30, 0.12, 0.12, 0.98), CLR_QUIT_EDGE, Color(1.0, 0.80, 0.78),
		func():
			if _hud != null and _hud.has_method("_exit_run_to_menu"):
				_hud.call("_exit_run_to_menu"))

func _confirm_btn(parent: Control, pos: Vector2, size: Vector2, text: String,
		fill: Color, border: Color, fg: Color, action: Callable) -> void:
	var visual := Control.new()
	visual.pivot_offset = size * 0.5
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	visual.process_mode = Node.PROCESS_MODE_ALWAYS
	UiKit.place(parent, visual, pos, size)
	var bg := Panel.new()
	bg.add_theme_stylebox_override("panel", UiKit.rounded(fill, 8, border, 2))
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.place(visual, bg, Vector2.ZERO, size)
	var lbl := Label.new()
	lbl.add_theme_font_override("font", UI_FONT)
	lbl.add_theme_font_size_override("font_size", 14)
	_apply_text_fx(lbl)
	lbl.text                 = text
	lbl.modulate             = fg
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	UiKit.place(visual, lbl, Vector2.ZERO, size)
	var btn := Button.new()
	btn.flat         = true
	btn.focus_mode   = Control.FOCUS_NONE
	btn.process_mode = Node.PROCESS_MODE_ALWAYS
	btn.pressed.connect(func():
		if _hud and _hud.has_method("_play_btn_sfx"):
			_hud._play_btn_sfx()
		action.call())
	btn.button_down.connect(_press_anim.bind(visual, true))
	btn.button_up.connect(_press_anim.bind(visual, false))
	btn.mouse_exited.connect(_press_anim.bind(visual, false))
	UiKit.place(parent, btn, pos, size)

func _apply_text_fx(lbl: Label) -> void:
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.65))
	lbl.add_theme_constant_override("outline_size", 2)
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.80))
	lbl.add_theme_constant_override("shadow_offset_x", 0)
	lbl.add_theme_constant_override("shadow_offset_y", 0)
	lbl.add_theme_constant_override("shadow_outline_size", 3)

func _press_anim(visual_root: Control, pressed: bool) -> void:
	UiKit.press_anim(visual_root, pressed)
