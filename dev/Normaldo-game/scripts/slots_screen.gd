extends Node2D
class_name SlotsScreen

const UI_FONT        := preload("res://assets/fonts/RussoOne-Regular.ttf")

const TEX_PIZZA      := preload("res://assets/items/pizza.png")
const TEX_DOLLAR     := preload("res://assets/items/dollar.png")
const TEX_TOKEN      := preload("res://assets/items/token.png")
const TEX_PACK       := preload("res://assets/items/pizza_pack_closed.png")
const TEX_SKIN1      := preload("res://assets/normaldo/normaldo1.png")
const TEX_SNAKE      := preload("res://assets/items/snake.png")
const TEX_STONE      := preload("res://assets/items/stone.png")
const TEX_TRASH      := preload("res://assets/items/trash_bin.png")
const TEX_BG_SLOTS   := preload("res://assets/ui/slots/bg_slots.png")
const TEX_SLOT_MACH  := preload("res://assets/slots/slot_machine.png")
const TEX_BACK_ARROW := preload("res://assets/ui/quests/back_arrow.png")

# ── Layout (canvas pixels, 430×192) ────────────────────────────────────────
const CANVAS_W : float = 430.0
const CANVAS_H : float = 192.0
# Top chrome
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
# Три колонки: скин слева, автоматы по центру, призы справа (канвас-px).
# Центральная колонка забирает столько ширины, сколько можно: размер барабана
# задан артом кабинета (экран — 50.6% его ширины) и растёт только вместе с ним.
const COL_Y      : float = 34.0
const COL_H      : float = 150.0
const SKIN_X     : float = 10.0
const SKIN_W     : float = 92.0
const MACH_X     : float = 108.0
const MACH_W     : float = 212.0
const PAY_X      : float = 326.0
const PAY_W      : float = 94.0
# slot_machine.png — 241×454. Тёмный «экран» внутри кабинета:
const MACH_SCREEN_REL : Rect2 = Rect2(0.241, 0.225, 0.506, 0.255)
# Сколько высоты кабинета показываем: ниже идёт плинтус, который на этом экране
# только съедал бы место под кнопкой. Та же величина, что в выплате мини-игр.
const MACH_CUT   : float = 0.66
const RESULT_H   : float = 24.0
const SPIN_H     : float = 52.0
const REEL_INSET : float = 4.0
# Slide-down transition (mirrors quests_screen).
const SLIDE_TIME      : float = 0.45
const SLIDE_TRANS     : int   = Tween.TRANS_QUAD
const SLIDE_EASE_IN   : int   = Tween.EASE_IN
const SLIDE_EASE_OUT  : int   = Tween.EASE_IN

const FAT_TEXTURES := [
	preload("res://assets/normaldo/normaldo1.png"),
	preload("res://assets/normaldo/normaldo2.png"),
	preload("res://assets/normaldo/normaldo3.png"),
	preload("res://assets/normaldo/normaldo4.png"),
]

# Each reel spins through this strip independently.
# Prize symbols: pizza, dollar, token, normaldo
# Filler symbols: snake, stone, trash (give nothing on their own)
const STRIP := [
	"pizza",   "snake",   "dollar", "stone",   "pizza",
	"trash",   "snake",   "pizza",  "dollar",  "stone",
	"token",   "normaldo","pizza",  "snake",   "dollar",
	"stone",   "pizza",   "trash",  "token",   "snake",
]
const STRIP_SIZE := 20

# Prize table: PRIZES[sym][match_count - 1]
const PRIZES := {
	"pizza": [
		{rtype="xp",      rval=150,  label="+150 XP",   tier=1},
		{rtype="xp",      rval=500,  label="+500 XP",   tier=2},
		{rtype="xp",      rval=1500, label="+1500 XP",  tier=3},
	],
	"dollar": [
		{rtype="dollars", rval=100,  label="+100 $",    tier=1},
		{rtype="dollars", rval=300,  label="+300 $",    tier=2},
		{rtype="dollars", rval=1000, label="+1000 $",   tier=3},
	],
	"token": [
		{rtype="tokens",  rval=1,    label="+1 жетон",  tier=1},
		{rtype="tokens",  rval=2,    label="+2 жетона", tier=2},
		{rtype="tokens",  rval=3,    label="+3 жетона", tier=3},
	],
	"normaldo": [
		{rtype="dollars", rval=30000, label="ДЖЕКПОТ!", tier=4},
	],
}

# Pre-roll table: one entry = one possible spin result (type + count).
# Reels are then assigned accordingly: `count` reels show that symbol, rest show fillers.
const SPIN_OUTCOMES := [
	{sym="pizza",    count=1, weight=20.0},
	{sym="pizza",    count=2, weight=10.0},
	{sym="pizza",    count=3, weight=4.0},
	{sym="dollar",   count=1, weight=15.0},
	{sym="dollar",   count=2, weight=7.0},
	{sym="dollar",   count=3, weight=2.0},
	{sym="token",    count=1, weight=8.0},
	{sym="token",    count=2, weight=4.0},
	{sym="token",    count=3, weight=1.0},
	{sym="normaldo", count=3, weight=0.05},
]

const TIER_COLORS := [
	Color.WHITE,
	Color.WHITE,
	Color(0.45, 0.85, 1.0),
	Color(0.65, 0.35, 1.0),
	Color(1.0,  0.65, 0.15),
]

# Барабаны. Размер не задан числом: он берётся из арта кабинета в
# `_build_machine`, поэтому окно всегда точно совпадает с экраном автомата.
const N_VISIBLE  := 3                    # символов в барабане одновременно
const START_FACES : Array = [1, 5, 10]   # змея / мусор / жетон — заведомо не приз
const SPIN_SPEED := 920.0                # px/s на свободном вращении
var _reel_w    : float = 80.0
var _sym_h     : float = 70.0
var _reel_h    : float = 70.0
var _strip_h   : float = 40.0 * 70.0     # 2 × 20 позиций ленты

var _hud          : Node    = null
# Slide-down container — everything visible lives inside so the entrance and
# exit can move the whole screen as one piece.
var _slide_root   : Control = null
# TV background audio — muted while the slots screen is up so the slots music
# isn't fighting whatever channel Normaldo is "watching". Restored on close.
var _tv_audio     : AudioStreamPlayer = null
var _tv_orig_db   : float = 0.0
# Legacy alias used by the reel / paytable / fly-icons code below.
var _overlay      : Control = null
var _token_lbl    : Label
var _spin_btn_bg  : Panel
var _spin_visual  : Control = null
var _spin_lbl     : Label
var _spin_token   : TextureRect = null
var _spin_pulse   : Tween = null
var _result_lbl   : Label = null
var _skin_avatar  : TextureRect
var _skin_name_lbl: Label
var _skin_lvl_lbl : Label
var _skin_xp_lbl  : Label = null
var _skin_bar_fill: Panel
var _skin_bar_w   : float = 0.0
# Лента последних спинов сессии — заполняет низ левой колонки и отвечает на
# «что там выпало минуту назад». В сейв не пишется: это память экрана.
var _history      : Array = []
var _history_root : Control = null
var _lay          : Dictionary = {}
var _win_popup    : Node2D = null
var _win_applied  : bool   = true

# Reel state
var _reel_clips   : Array        = []   # Control (clipping) nodes
var _reel_tiles   : Array        = []   # [reel][slot] TextureRect
var _scroll_y     : Array[float] = [0.0, 0.0, 0.0]
var _scroll_spd   : Array[float] = [0.0, 0.0, 0.0]
var _reel_stopped : Array[bool]  = [false, false, false]
var _reel_target  : Array[int]   = [0, 0, 0]
var _stopped_count: int          = 0

var _spinning     : bool       = false
var _last_result  : Dictionary = {}
var _music        : AudioStreamPlayer = null
# Looping rolling whoosh played while the reels are spinning. Pre-warmed
# in _build_ui so `.play()` fires with no lag when КРУТИТЬ is tapped.
var _spin_audio   : AudioStreamPlayer = null

var _dollar_lbl    : Label   = null
var _token_target  : Vector2 = Vector2.ZERO
var _dollar_target : Vector2 = Vector2.ZERO
var _xp_bar_target : Vector2 = Vector2.ZERO

var _sym_textures : Array[Texture2D] = []

func _build_symbol_list() -> void:
	_sym_textures.clear()
	for sym in STRIP:
		_sym_textures.append(_tex_for(sym))

func _tex_for(id: String) -> Texture2D:
	match id:
		"snake":    return TEX_SNAKE
		"stone":    return TEX_STONE
		"trash":    return TEX_TRASH
		"normaldo": return TEX_SKIN1
		"pizza":    return TEX_PIZZA
		"dollar":   return TEX_DOLLAR
		"token":    return TEX_TOKEN
		_:          return TEX_PIZZA

func _make_label(txt: String, sz: int, col: Color = Color.WHITE) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", UI_FONT)
	l.add_theme_font_size_override("font_size", sz)
	l.text     = txt
	l.modulate = col
	return l

func _make_icon(tex: Texture2D, size: float) -> TextureRect:
	var r := TextureRect.new()
	r.texture      = tex
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
	r.size         = Vector2(size, size)
	return r

func setup(hud: Node) -> void:
	_hud = hud

func _ready() -> void:
	_build_symbol_list()
	_build_ui()
	_start_music()
	# Camera-pan-down entrance: we sit BELOW the menu and rise into view while
	# HUD slides the main-menu chrome + scene up off-screen in lock-step.
	var vp := get_viewport().get_visible_rect().size
	_slide_root.position = Vector2(0.0, vp.y)
	var tw := create_tween()
	tw.tween_property(_slide_root, "position", Vector2.ZERO, SLIDE_TIME)\
		.set_trans(SLIDE_TRANS).set_ease(SLIDE_EASE_IN)
	if _hud != null and _hud.has_method("_on_slots_open_anim_start"):
		_hud._on_slots_open_anim_start(SLIDE_TIME, SLIDE_TRANS, SLIDE_EASE_IN)
	# Hush the TV so the slots music has the floor.
	_mute_tv() 

func _start_music() -> void:
	_music = AudioStreamPlayer.new()
	var stream := load("res://assets/slots/slots_music.mp3") as AudioStreamMP3
	if stream:
		stream.loop   = true
		_music.stream = stream
	_music.volume_db    = -4.0
	_music.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_music)
	_music.play()

	# Pre-build the spin-rolling SFX so the first КРУТИТЬ tap doesn't pay
	# the load-and-attach cost. Stream is looped so it plays as long as the
	# reels are turning.
	_spin_audio = AudioStreamPlayer.new()
	var spin_stream := load("res://assets/audio/rolling.mp3") as AudioStreamMP3
	if spin_stream:
		spin_stream.loop = true
		_spin_audio.stream = spin_stream
	_spin_audio.volume_db    = -6.0
	_spin_audio.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_spin_audio)

func _mute_tv() -> void:
	# Find the TV node via HUD -> Game (parent). Cache its AudioStreamPlayer
	# and current volume_db so _unmute_tv can restore it.
	if _hud == null:
		return
	var game := _hud.get_parent()
	if game == null:
		return
	var tv := game.get_node_or_null("Tv")
	if tv == null:
		return
	var audio = tv.get("_tv_audio")
	if audio == null or not (audio is AudioStreamPlayer):
		return
	_tv_audio   = audio
	_tv_orig_db = audio.volume_db
	var tw := create_tween()
	tw.tween_property(_tv_audio, "volume_db", -80.0, SLIDE_TIME)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _unmute_tv() -> void:
	if _tv_audio == null or not is_instance_valid(_tv_audio):
		return
	var tw := create_tween()
	tw.tween_property(_tv_audio, "volume_db", _tv_orig_db, SLIDE_TIME)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

func _stop_music() -> void:
	if _music and is_instance_valid(_music):
		_music.stop()
		_music.queue_free()
		_music = null
	if _spin_audio and is_instance_valid(_spin_audio):
		_spin_audio.stop()
		_spin_audio.queue_free()
		_spin_audio = null

# ── Геометрия трёх колонок ───────────────────────────────────────────────────
func _layout(vp: Vector2) -> Dictionary:
	var sx : float = vp.x / CANVAS_W
	var sy : float = vp.y / CANVAS_H
	var top : float = COL_Y * sy
	var hgt : float = COL_H * sy
	return {
		"sx": sx, "sy": sy,
		"skin": Rect2(SKIN_X * sx, top, SKIN_W * sx, hgt),
		"mach": Rect2(MACH_X * sx, top, MACH_W * sx, hgt),
		"pay":  Rect2(PAY_X  * sx, top, PAY_W  * sx, hgt),
	}

func _build_ui() -> void:
	var vp      := get_viewport().get_visible_rect().size
	var scale_x : float = vp.x / CANVAS_W
	var scale_y : float = vp.y / CANVAS_H
	_lay = _layout(vp)

	# Slide-root holds every visible element — entrance / exit tween moves it
	# all together (camera-pan effect, identical to the quests screen).
	_slide_root = Control.new()
	_slide_root.size         = vp
	_slide_root.position     = Vector2.ZERO
	_slide_root.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_slide_root)
	_overlay = _slide_root   # legacy alias for the reel / paytable / fly-icons code

	# Full-screen background.
	var bg := TextureRect.new()
	bg.texture             = TEX_BG_SLOTS
	bg.stretch_mode        = TextureRect.STRETCH_SCALE
	bg.expand_mode         = TextureRect.EXPAND_IGNORE_SIZE
	bg.custom_minimum_size = Vector2.ZERO
	bg.size                = vp
	bg.position            = Vector2.ZERO
	bg.texture_filter      = CanvasItem.TEXTURE_FILTER_NEAREST
	bg.mouse_filter        = Control.MOUSE_FILTER_IGNORE
	_slide_root.add_child(bg)

	# ── Top chrome (back arrow, title, resources) — same spec as quests ─────
	_build_top_chrome(vp, scale_x, scale_y)

	_build_machine()
	_build_skin_panel()
	_build_paytable_panel()

	SaveData.data_changed.connect(_on_data_changed)

# ── Центр: автоматы ──────────────────────────────────────────────────────────
# Сами автоматы — пиксель-арт `slot_machine.png`, как и было: рисовать корпус
# панелями значит терять то, ради чего экран открывают. Ниже плинтуса кабинет
# обрезан (MACH_CUT) — та же обрезка, что в выплате мини-игр: она освобождает
# место под кнопку и строку результата, не трогая ни маркизу, ни экран.
# Три кабинета стоят вплотную на общей подложке — это один автомат с тремя
# барабанами, а не три разных.
func _build_machine() -> void:
	var r : Rect2 = _lay["mach"]

	UiKit.panel(_slide_root, r.position, r.size,
		Color(0.10, 0.05, 0.18, 0.92), 12, Color(0.62, 0.30, 1.00, 0.85), 2)

	# Кабинеты вплотную занимают всю ширину подложки за вычетом полей.
	var pad     : float = 8.0
	var mach_w  : float = (r.size.x - pad * 2.0) / 3.0
	var aspect  : float = float(TEX_SLOT_MACH.get_height()) / float(TEX_SLOT_MACH.get_width())
	var mach_h  : float = mach_w * aspect          # полная высота кабинета
	var vis_h   : float = mach_h * MACH_CUT        # сколько от него видно

	# Барабан — это ЭКРАН кабинета: его размер задан артом, а не выдуман.
	_reel_w  = MACH_SCREEN_REL.size.x * mach_w
	_sym_h   = MACH_SCREEN_REL.size.y * mach_h
	_reel_h  = _sym_h
	_strip_h = float(STRIP_SIZE) * 2.0 * _sym_h

	# Столбец по вертикали: кабинеты, строка результата, кнопка. Считаем разом,
	# чтобы блок стоял по центру подложки, а не «примерно там».
	var block_h : float = vis_h + 12.0 + RESULT_H + 14.0 + SPIN_H
	var top     : float = r.position.y + maxf(10.0, (r.size.y - block_h) * 0.5)
	var left    : float = r.position.x + pad
	var vis_bottom : float = top + vis_h

	_reel_clips.clear()
	_reel_tiles.clear()
	for i in 3:
		var mx : float = left + float(i) * mach_w

		# Нижнюю часть кабинета отрезаем регионом атласа, а не масштабом: пиксели
		# арта остаются пикселями арта.
		var atlas := AtlasTexture.new()
		atlas.atlas  = TEX_SLOT_MACH
		atlas.region = Rect2(0.0, 0.0, float(TEX_SLOT_MACH.get_width()),
			float(TEX_SLOT_MACH.get_height()) * MACH_CUT)
		var mach := TextureRect.new()
		mach.texture             = atlas
		mach.stretch_mode        = TextureRect.STRETCH_SCALE
		mach.expand_mode         = TextureRect.EXPAND_IGNORE_SIZE
		mach.custom_minimum_size = Vector2.ZERO
		mach.texture_filter      = CanvasItem.TEXTURE_FILTER_NEAREST
		mach.mouse_filter        = Control.MOUSE_FILTER_IGNORE
		UiKit.place(_slide_root, mach, Vector2(mx, top), Vector2(mach_w, vis_h))

		# Окно барабана ложится ровно на тёмный экран кабинета.
		var clip := Control.new()
		clip.clip_contents = true
		clip.mouse_filter  = Control.MOUSE_FILTER_IGNORE
		UiKit.place(_slide_root, clip,
			Vector2(mx + MACH_SCREEN_REL.position.x * mach_w,
				top + MACH_SCREEN_REL.position.y * mach_h),
			Vector2(_reel_w, _reel_h))
		clip.pivot_offset = Vector2(_reel_w, _reel_h) * 0.5
		_reel_clips.append(clip)

		var tiles : Array[TextureRect] = []
		for k in N_VISIBLE:
			var tr := TextureRect.new()
			tr.texture      = _sym_textures[0]
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
			UiKit.place(clip, tr, Vector2(REEL_INSET, REEL_INSET + float(k) * _sym_h),
				Vector2(_reel_w - REEL_INSET * 2.0, _sym_h - REEL_INSET * 2.0))
			tiles.append(tr)
		_reel_tiles.append(tiles)
	# Стартовые позиции разные: три одинаковых символа на входе читаются как
	# только что выпавший выигрыш.
	for i in 3:
		_scroll_y[i] = float(START_FACES[i]) * _sym_h
	_update_all_reels()

	# Строка результата — окно выигрыша игрок закрывает и забывает, а строка
	# держит ответ «что там было» до следующего спина.
	_result_lbl = _make_label("ТРИ ОДИНАКОВЫХ — КРУПНЫЙ ПРИЗ", 12, Color(0.80, 0.72, 0.95))
	_apply_text_fx(_result_lbl)
	_result_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_result_lbl.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	UiKit.place(_slide_root, _result_lbl,
		Vector2(r.position.x + 10.0, vis_bottom + 12.0), Vector2(r.size.x - 20.0, RESULT_H))

	# Кнопка спина — единственное действие экрана, значит самая крупная и по
	# центру под автоматом.
	var spin_w : float = minf(240.0, r.size.x - 40.0)
	var spin_h : float = SPIN_H
	var spin_pos := Vector2(r.position.x + (r.size.x - spin_w) * 0.5,
		vis_bottom + 12.0 + RESULT_H + 14.0)

	_spin_visual = Control.new()
	_spin_visual.size         = Vector2(spin_w, spin_h)
	_spin_visual.position     = spin_pos
	_spin_visual.pivot_offset = _spin_visual.size * 0.5
	_spin_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slide_root.add_child(_spin_visual)

	_spin_btn_bg = Panel.new()
	_spin_btn_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.place(_spin_visual, _spin_btn_bg, Vector2.ZERO, Vector2(spin_w, spin_h))

	_spin_lbl = _make_label("КРУТИТЬ", 18, Color(1.0, 0.92, 0.70))
	_apply_text_fx(_spin_lbl)
	_spin_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_spin_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_spin_lbl.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	UiKit.place(_spin_visual, _spin_lbl, Vector2.ZERO, Vector2(spin_w - 34.0, spin_h))

	_spin_token = _make_icon(TEX_TOKEN, 24.0)
	_spin_token.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.place(_spin_visual, _spin_token,
		Vector2(spin_w - 34.0, (spin_h - 24.0) * 0.5), Vector2(24.0, 24.0))

	var spin_btn := Button.new()
	spin_btn.flat       = true
	spin_btn.focus_mode = Control.FOCUS_NONE
	spin_btn.size       = Vector2(spin_w, spin_h)
	spin_btn.position   = spin_pos
	spin_btn.pressed.connect(_on_spin_pressed)
	spin_btn.button_down.connect(_press_anim.bind(_spin_visual, true))
	spin_btn.button_up.connect(_press_anim.bind(_spin_visual, false))
	spin_btn.mouse_exited.connect(_press_anim.bind(_spin_visual, false))
	_slide_root.add_child(spin_btn)

	_refresh_spin_button()

# Состояние кнопки словом, а не одной лишь яркостью: «КРУТИТЬ 1» — можно,
# «НЕТ ЖЕТОНОВ» — нечем, «...» — крутится.
func _refresh_spin_button() -> void:
	if not is_instance_valid(_spin_btn_bg):
		return
	var can : bool = SaveData.tokens >= 1
	if _spinning:
		_spin_btn_bg.add_theme_stylebox_override("panel", UiKit.rounded(
			Color(0.10, 0.05, 0.20, 0.95), 10, Color(0.45, 0.30, 0.65, 0.80), 2))
		_spin_lbl.text     = "..."
		_spin_lbl.modulate = Color(0.75, 0.70, 0.85)
		_spin_token.visible = false
	elif can:
		_spin_btn_bg.add_theme_stylebox_override("panel", UiKit.rounded(
			Color(0.42, 0.12, 0.62, 0.98), 10, Color(1.00, 0.72, 0.30, 0.95), 2))
		_spin_lbl.text     = "КРУТИТЬ  1"
		_spin_lbl.modulate = Color(1.0, 0.92, 0.70)
		_spin_token.visible = true
	else:
		_spin_btn_bg.add_theme_stylebox_override("panel", UiKit.rounded(
			Color(0.14, 0.10, 0.16, 0.95), 10, Color(0.45, 0.35, 0.40, 0.75), 2))
		_spin_lbl.text     = "НЕТ ЖЕТОНОВ"
		_spin_lbl.modulate = Color(0.85, 0.62, 0.62)
		_spin_token.visible = false
	_set_spin_pulse(can and not _spinning)

# Пульсирует ровно одно на экране — кнопка, когда её действительно можно нажать.
func _set_spin_pulse(on: bool) -> void:
	if _spin_pulse != null and _spin_pulse.is_valid():
		_spin_pulse.kill()
		_spin_pulse = null
	if not is_instance_valid(_spin_visual):
		return
	_spin_visual.scale = Vector2.ONE
	if not on:
		return
	_spin_pulse = _spin_visual.create_tween().set_loops()
	_spin_pulse.tween_property(_spin_visual, "scale", Vector2(1.04, 1.04), 0.55)\
		.set_trans(Tween.TRANS_SINE)
	_spin_pulse.tween_property(_spin_visual, "scale", Vector2.ONE, 0.55)\
		.set_trans(Tween.TRANS_SINE)

# ── Левая колонка: скин, опыт, последние спины ───────────────────────────────
# Скин живёт на экране автомата потому, что главный приз автомата — опыт, а
# опыт идёт активному скину.
func _build_skin_panel() -> void:
	var r : Rect2 = _lay["skin"]
	UiKit.panel(_slide_root, r.position, r.size,
		Color(0.08, 0.05, 0.14, 0.94), 12, Color(0.50, 0.28, 0.80, 0.85), 2)

	var skin_data    = SkinRegistry.get_skin(SaveData.active_skin)
	var skin_rarity  := skin_data.get("rarity", 0) as int
	var rarity_color := SkinRegistry.RARITY_COLORS[skin_rarity] as Color

	const AVATAR_SZ := 54.0
	var skin_tex_dir: String = skin_data.get("tex_dir", "")
	var avatar_tex: Texture2D
	if skin_tex_dir.is_empty():
		avatar_tex = FAT_TEXTURES[0]
	else:
		avatar_tex = load(skin_tex_dir + "state1.png")
	var av_pos := r.position + Vector2(10.0, 10.0)
	UiKit.panel(_slide_root, av_pos, Vector2(AVATAR_SZ, AVATAR_SZ),
		Color(0.04, 0.03, 0.08, 0.95), 10,
		Color(rarity_color.r, rarity_color.g, rarity_color.b, 0.90), 2)
	_skin_avatar = _make_icon(avatar_tex, AVATAR_SZ - 8.0)
	_skin_avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.place(_slide_root, _skin_avatar, av_pos + Vector2(4.0, 4.0),
		Vector2(AVATAR_SZ - 8.0, AVATAR_SZ - 8.0))

	var name_x : float = av_pos.x + AVATAR_SZ + 10.0
	var name_w : float = r.position.x + r.size.x - 10.0 - name_x
	_skin_name_lbl = _make_label(skin_data.get("name_ru", "НОРМАЛЬДО") as String, 13)
	_apply_text_fx(_skin_name_lbl)
	_skin_name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_skin_name_lbl.vertical_alignment    = VERTICAL_ALIGNMENT_CENTER
	_skin_name_lbl.mouse_filter          = Control.MOUSE_FILTER_IGNORE
	UiKit.place(_slide_root, _skin_name_lbl, Vector2(name_x, av_pos.y + 4.0),
		Vector2(name_w, 20.0))

	var is_mastery := SaveData.skin_level >= 10
	_skin_lvl_lbl = _make_label("МАСТЕРСТВО" if is_mastery else "УР. %d" % SaveData.skin_level,
		11, Color(0.55, 0.85, 1.0))
	_apply_text_fx(_skin_lvl_lbl)
	_skin_lvl_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_skin_lvl_lbl.mouse_filter       = Control.MOUSE_FILTER_IGNORE
	UiKit.place(_slide_root, _skin_lvl_lbl, Vector2(name_x, av_pos.y + 26.0),
		Vector2(name_w, 16.0))

	# Полоса опыта С ЧИСЛОМ: приз «+1500 XP» не с чем сравнить, если не сказано,
	# сколько осталось до уровня.
	var bar_w : float = r.size.x - 20.0
	var bar_y : float = av_pos.y + AVATAR_SZ + 10.0
	_skin_bar_w = bar_w
	UiKit.panel(_slide_root, Vector2(r.position.x + 10.0, bar_y), Vector2(bar_w, 12.0),
		Color(0.03, 0.03, 0.05, 0.95), 6, Color(0.30, 0.26, 0.35, 0.90), 1)
	_skin_bar_fill = Panel.new()
	_skin_bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.place(_slide_root, _skin_bar_fill, Vector2(r.position.x + 12.0, bar_y + 2.0),
		Vector2(maxf(2.0, (bar_w - 4.0) * SaveData.xp_level_progress()), 8.0))
	_set_bar_color(Color(0.45, 0.80, 1.0))
	_xp_bar_target = Vector2(r.position.x + 10.0 + bar_w * 0.5, bar_y + 6.0)

	_skin_xp_lbl = _make_label(_xp_hint(), 10, Color(0.86, 0.86, 0.92))
	_apply_text_fx(_skin_xp_lbl)
	_skin_xp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_skin_xp_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_skin_xp_lbl.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	UiKit.place(_slide_root, _skin_xp_lbl, Vector2(r.position.x + 10.0, bar_y + 16.0),
		Vector2(bar_w, 14.0))

	# СМЕНИТЬ СКИН
	var chg_h   : float = 30.0
	var chg_pos := Vector2(r.position.x + 10.0, bar_y + 32.0)
	var chg_size := Vector2(bar_w, chg_h)
	var chg_visual := Control.new()
	chg_visual.size         = chg_size
	chg_visual.position     = chg_pos
	chg_visual.pivot_offset = chg_size * 0.5
	chg_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slide_root.add_child(chg_visual)
	var chg_bg := Panel.new()
	chg_bg.add_theme_stylebox_override("panel", UiKit.rounded(
		Color(0.16, 0.09, 0.30, 0.96), 8, Color(0.60, 0.35, 0.95, 0.90), 2))
	chg_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.place(chg_visual, chg_bg, Vector2.ZERO, chg_size)
	var chg_lbl := _make_label("СМЕНИТЬ СКИН", 11, Color(0.88, 0.75, 1.0))
	_apply_text_fx(chg_lbl)
	chg_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chg_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	chg_lbl.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	UiKit.place(chg_visual, chg_lbl, Vector2.ZERO, chg_size)
	var chg_btn := Button.new()
	chg_btn.flat       = true
	chg_btn.focus_mode = Control.FOCUS_NONE
	chg_btn.size       = chg_size
	chg_btn.position   = chg_pos
	chg_btn.pressed.connect(_on_change_skin)
	chg_btn.button_down.connect(_press_anim.bind(chg_visual, true))
	chg_btn.button_up.connect(_press_anim.bind(chg_visual, false))
	chg_btn.mouse_exited.connect(_press_anim.bind(chg_visual, false))
	_slide_root.add_child(chg_btn)

	# Лента последних спинов — раньше на этом месте была пустая треть колонки.
	var hist_y : float = chg_pos.y + chg_h + 12.0
	var hist_lbl := _make_label("ПОСЛЕДНИЕ СПИНЫ", 10, Color(0.72, 0.62, 0.90))
	_apply_text_fx(hist_lbl)
	hist_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hist_lbl.mouse_filter       = Control.MOUSE_FILTER_IGNORE
	UiKit.place(_slide_root, hist_lbl, Vector2(r.position.x + 10.0, hist_y),
		Vector2(bar_w, 14.0))

	_history_root = Control.new()
	_history_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.place(_slide_root, _history_root, Vector2(r.position.x + 10.0, hist_y + 18.0),
		Vector2(bar_w, r.position.y + r.size.y - 10.0 - (hist_y + 18.0)))
	_refresh_history()

func _set_bar_color(col: Color) -> void:
	if is_instance_valid(_skin_bar_fill):
		_skin_bar_fill.add_theme_stylebox_override("panel", UiKit.rounded(col, 4))

func _xp_hint() -> String:
	if SaveData.skin_level >= 10:
		return "ещё %d XP до жетона" % SaveData.xp_to_next_level()
	return "ещё %d XP до ур. %d" % [SaveData.xp_to_next_level(), SaveData.skin_level + 1]

const HISTORY_MAX : int = 3

func _refresh_history() -> void:
	if not is_instance_valid(_history_root):
		return
	for c in _history_root.get_children():
		c.queue_free()
	var w : float = _history_root.size.x
	if _history.is_empty():
		var empty := _make_label("пока ни одного", 10, Color(0.62, 0.60, 0.70))
		_apply_text_fx(empty)
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty.mouse_filter       = Control.MOUSE_FILTER_IGNORE
		UiKit.place(_history_root, empty, Vector2.ZERO, Vector2(w, 16.0))
		return
	const ICO := 14.0
	const ROW := 22.0
	for i in _history.size():
		var e : Dictionary = _history[i]
		var y : float = float(i) * ROW
		var row := Panel.new()
		row.add_theme_stylebox_override("panel", UiKit.rounded(
			Color(0.05, 0.04, 0.09, 0.85), 6))
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		UiKit.place(_history_root, row, Vector2(0.0, y), Vector2(w, ROW - 3.0))
		# Три значка = три барабана: совпавшие символом приза, остальные тусклые.
		for k in 3:
			var ico := _make_icon(_tex_for(String(e["sym"])) if k < int(e["count"]) else TEX_STONE, ICO)
			ico.modulate     = Color(1, 1, 1, 1.0 if k < int(e["count"]) else 0.35)
			ico.mouse_filter = Control.MOUSE_FILTER_IGNORE
			UiKit.place(_history_root, ico,
				Vector2(4.0 + float(k) * (ICO + 2.0), y + (ROW - 3.0 - ICO) * 0.5),
				Vector2(ICO, ICO))
		var lbl := _make_label(String(e["label"]), 10, e["col"] as Color)
		_apply_text_fx(lbl)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		lbl.mouse_filter         = Control.MOUSE_FILTER_IGNORE
		UiKit.place(_history_root, lbl, Vector2(4.0 + 3.0 * (ICO + 2.0), y),
			Vector2(w - (4.0 + 3.0 * (ICO + 2.0)) - 6.0, ROW - 3.0))

# ── Правая колонка: таблица призов ───────────────────────────────────────────
# Сгруппирована заголовками: что значки в строке — это количество совпавших
# барабанов, раньше нигде не говорилось.
func _build_paytable_panel() -> void:
	var r : Rect2 = _lay["pay"]
	UiKit.panel(_slide_root, r.position, r.size,
		Color(0.06, 0.04, 0.12, 0.94), 12, Color(0.50, 0.28, 0.80, 0.85), 2)

	var pt_title := _make_label("ПРИЗЫ", 13, Color(0.90, 0.75, 1.0))
	_apply_text_fx(pt_title)
	pt_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pt_title.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	pt_title.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	UiKit.place(_slide_root, pt_title, r.position + Vector2(0.0, 8.0), Vector2(r.size.x, 20.0))

	# Джекпот сверху отдельной строкой, дальше группы по числу совпадений.
	var groups : Array = [
		{"cap": "ДЖЕКПОТ",  "rows": [{"sym": "normaldo", "count": 3, "prize": PRIZES["normaldo"][0]}]},
		{"cap": "ТРИ В РЯД", "rows": _pay_rows(3)},
		{"cap": "ДВА В РЯД", "rows": _pay_rows(2)},
		{"cap": "ОДИН",      "rows": _pay_rows(1)},
	]

	var inner_x : float = r.position.x + 8.0
	var inner_w : float = r.size.x - 16.0
	var top     : float = r.position.y + 30.0
	var avail   : float = r.position.y + r.size.y - 8.0 - top
	# 4 заголовка + 10 строк призов делят колонку без остатка — таблица обязана
	# помещаться целиком, ничего важного за скроллом.
	var n_rows  : int = 0
	for g in groups:
		n_rows += (g["rows"] as Array).size()
	var cap_h : float = 15.0
	var row_h : float = (avail - cap_h * float(groups.size())) / float(n_rows)

	const ICO_SZ  := 13.0
	const ICO_GAP := 3.0
	var y : float = top
	for g in groups:
		var cap := _make_label(String(g["cap"]), 10, Color(0.72, 0.60, 0.92))
		_apply_text_fx(cap)
		cap.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cap.mouse_filter       = Control.MOUSE_FILTER_IGNORE
		UiKit.place(_slide_root, cap, Vector2(inner_x, y), Vector2(inner_w, cap_h))
		y += cap_h
		for e in (g["rows"] as Array):
			var prize : Dictionary = e["prize"]
			var col   := TIER_COLORS[int(prize.tier)] as Color
			var count : int = int(e["count"])
			for p in count:
				var ico := _make_icon(_tex_for(String(e["sym"])), ICO_SZ)
				ico.mouse_filter = Control.MOUSE_FILTER_IGNORE
				UiKit.place(_slide_root, ico,
					Vector2(inner_x + float(p) * (ICO_SZ + ICO_GAP), y + (row_h - ICO_SZ) * 0.5),
					Vector2(ICO_SZ, ICO_SZ))
			var icons_end : float = inner_x + 3.0 * (ICO_SZ + ICO_GAP) + 2.0
			var lbl := _make_label(String(prize.label), 11, col)
			_apply_text_fx(lbl)
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
			lbl.mouse_filter         = Control.MOUSE_FILTER_IGNORE
			UiKit.place(_slide_root, lbl, Vector2(icons_end, y),
				Vector2(inner_x + inner_w - icons_end, row_h))
			y += row_h

func _pay_rows(count: int) -> Array:
	var out : Array = []
	for sym in ["pizza", "dollar", "token"]:
		out.append({"sym": sym, "count": count, "prize": (PRIZES[sym] as Array)[count - 1]})
	return out

# ── Top chrome (back arrow + title + resources) ─────────────────────────────

func _build_top_chrome(vp: Vector2, scale_x: float, scale_y: float) -> void:
	# Back arrow with press-shrink animation.
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

	# Title "СЛОТЫ".
	var title_lbl := Label.new()
	title_lbl.add_theme_font_override("font", UI_FONT)
	title_lbl.add_theme_font_size_override("font_size", TITLE_FONT_SZ)
	_apply_text_fx(title_lbl)
	title_lbl.text                 = "СЛОТЫ"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	title_lbl.size                 = Vector2(vp.x, TITLE_H * scale_y)
	title_lbl.position             = Vector2(TITLE_X_OFFSET * scale_x, TITLE_Y * scale_y)
	title_lbl.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	_slide_root.add_child(title_lbl)

	# Resources top-right (dollar + token), same layout maths as quests.
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

# Russo One outline + soft shadow — same spec as the main-menu/quests text.
func _apply_text_fx(lbl: Label) -> void:
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.65))
	lbl.add_theme_constant_override("outline_size", 2)
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.80))
	lbl.add_theme_constant_override("shadow_offset_x", 0)
	lbl.add_theme_constant_override("shadow_offset_y", 0)
	lbl.add_theme_constant_override("shadow_outline_size", 3)

# Press feedback (back arrow). Same shrink animation as the main-menu chips.
func _press_anim(visual_root: Control, pressed: bool) -> void:
	UiKit.press_anim(visual_root, pressed)

# ── Reel update ──────────────────────────────────────────────────────────────

func _update_reel_vis(reel_idx: int) -> void:
	var sy : float = _scroll_y[reel_idx]
	# Эпсилон обязателен: барабан останавливается ровно на кратном _sym_h, и без
	# него floor() на границе символа даёт на единицу меньше — в окне оказывается
	# СОСЕД выпавшего символа. Тот же баг ловили в выплате мини-игр.
	var steps   : float = floor(sy / _sym_h + 1e-4)
	var partial : float = sy - steps * _sym_h
	var base    : int   = int(steps) % STRIP_SIZE
	for k in N_VISIBLE:
		var sym_idx := (base + k) % STRIP_SIZE
		var tr      := _reel_tiles[reel_idx][k] as TextureRect
		tr.texture  = _sym_textures[sym_idx]
		tr.modulate = Color.WHITE
		tr.position = Vector2(REEL_INSET, REEL_INSET - partial + float(k) * _sym_h)

func _update_all_reels() -> void:
	for i in 3:
		_update_reel_vis(i)

# Что РЕАЛЬНО видно в окне барабана. Тест обязан проверять именно это, а не
# намерение `_reel_target`: между ними и живёт ошибка на один символ.
func visible_face(reel_idx: int) -> String:
	var steps : float = floor(_scroll_y[reel_idx] / _sym_h + 1e-4)
	return STRIP[int(steps) % STRIP_SIZE]

# ── Spin logic ───────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if not _spinning:
		return
	for i in 3:
		if _scroll_spd[i] > 0.0:
			_scroll_y[i] += _scroll_spd[i] * delta
			_update_reel_vis(i)

func _on_spin_pressed() -> void:
	if _spinning:
		return
	if SaveData.tokens < 1:
		_show_no_tokens()
		return
	SaveData.add_tokens(-1, "slot_spin")

	# Pre-roll the prize type + count before the reels start.
	# Exactly `count` reels will show the prize symbol; the rest show fillers.
	var outcome       := _roll_spin_outcome()
	_last_result       = {sym=outcome.sym as String, count=outcome.count as int}

	var prize_pos  := _positions_for_sym(outcome.sym as String)
	var filler_pos := _filler_positions()
	var reel_order : Array[int] = [0, 1, 2]
	reel_order.shuffle()
	var count : int = outcome.count
	for i in 3:
		if i < count:
			_reel_target[reel_order[i]] = prize_pos[randi() % prize_pos.size()]
		else:
			_reel_target[reel_order[i]] = filler_pos[randi() % filler_pos.size()]
	_start_spin()

func _roll_spin_outcome() -> Dictionary:
	var total := 0.0
	for o in SPIN_OUTCOMES:
		total += float(o.weight)
	var r   := randf() * total
	var acc := 0.0
	for o in SPIN_OUTCOMES:
		acc += float(o.weight)
		if r < acc:
			return o
	return SPIN_OUTCOMES[0]

func _positions_for_sym(sym: String) -> Array[int]:
	var result : Array[int] = []
	for i in STRIP_SIZE:
		if STRIP[i] == sym:
			result.append(i)
	return result

func _filler_positions() -> Array[int]:
	var result : Array[int] = []
	for i in STRIP_SIZE:
		if not (STRIP[i] in PRIZES):
			result.append(i)
	return result

func _start_spin() -> void:
	_spinning      = true
	_stopped_count = 0
	for i in 3:
		_reel_stopped[i] = false
		_scroll_spd[i]   = SPIN_SPEED
	_refresh_spin_button()
	# Looping rolling SFX — rewinds + plays each spin.
	if _spin_audio and is_instance_valid(_spin_audio):
		_spin_audio.stop()
		_spin_audio.play()

	await get_tree().create_timer(1.3).timeout
	if not _spinning: return
	_stop_reel_smooth(0)
	await get_tree().create_timer(0.32).timeout
	if not _spinning: return
	_stop_reel_smooth(1)
	await get_tree().create_timer(0.32).timeout
	if not _spinning: return
	_stop_reel_smooth(2)

func _stop_reel_smooth(idx: int) -> void:
	_scroll_spd[idx] = 0.0

	var target_sym := _reel_target[idx]
	var current    := _scroll_y[idx]
	# Find target scroll position: target symbol at center, always forward
	var target_y   := float(target_sym) * _sym_h
	while target_y < current + _strip_h * 0.5:
		target_y += _strip_h

	var tw := create_tween()
	tw.tween_method(
		func(v: float):
			_scroll_y[idx] = v
			_update_reel_vis(idx),
		current, target_y, 0.55
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func(): _on_reel_landed(idx))

func _on_reel_landed(idx: int) -> void:
	_reel_stopped[idx] = true
	# Прибиваем позицию к целому символу: твин заканчивается «почти» на месте, и
	# накопленная погрешность уводит окно на соседний символ.
	_scroll_y[idx] = roundf(_scroll_y[idx] / _sym_h) * _sym_h
	_update_reel_vis(idx)
	if _hud and _hud.has_method("_play_btn_sfx"):
		_hud._play_btn_sfx()

	# Quick squeeze on reel clip to show impact
	var clip = _reel_clips[idx]
	var tw = clip.create_tween()
	tw.tween_property(clip, "scale", Vector2(1.0, 0.90), 0.05)
	tw.tween_property(clip, "scale", Vector2.ONE, 0.14) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	_stopped_count += 1
	if _stopped_count == 3:
		_on_all_reels_stopped()

func _on_all_reels_stopped() -> void:
	_spinning = false
	_refresh_spin_button()
	# Reels landed — kill the rolling whoosh.
	if _spin_audio and is_instance_valid(_spin_audio):
		_spin_audio.stop()
	_note_result(_last_result)
	QuestManager.notify_slot_spin(int(_last_result.get("count", 1)))
	_show_win_popup(_last_result)

# Строка результата под автоматом и лента слева. Окно выигрыша игрок закроет и
# забудет, а «что там выпало» спрашивают уже через минуту.
func _note_result(result: Dictionary) -> void:
	var prize := _get_prize(result)
	if prize.is_empty():
		return
	var count : int    = int(result.get("count", 1))
	var sym   : String = String(result.get("sym", "pizza"))
	var col   := TIER_COLORS[int(prize.tier)] as Color
	var label : String = String(prize.label)
	if is_instance_valid(_result_lbl):
		_result_lbl.text     = "%s — %s" % [_combo_name(sym, count), label]
		_result_lbl.modulate = col
	_history.push_front({"sym": sym, "count": count, "label": label, "col": col})
	while _history.size() > HISTORY_MAX:
		_history.pop_back()
	_refresh_history()

func _combo_name(sym: String, count: int) -> String:
	if sym == "normaldo":
		return "ДЖЕКПОТ"
	var names := {
		"pizza":  ["ПИЦЦА", "ДВЕ ПИЦЦЫ", "ТРИ ПИЦЦЫ"],
		"dollar": ["ДОЛЛАР", "ДВА ДОЛЛАРА", "ТРИ ДОЛЛАРА"],
		"token":  ["ЖЕТОН", "ДВА ЖЕТОНА", "ТРИ ЖЕТОНА"],
	}
	if not names.has(sym):
		return "ВЫИГРЫШ"
	return String((names[sym] as Array)[clampi(count - 1, 0, 2)])

func _get_prize(result: Dictionary) -> Dictionary:
	if result.is_empty():
		return {}
	var sym   : String = result.sym
	var count : int    = result.count
	if not PRIZES.has(sym):
		return {}
	var tiers := PRIZES[sym] as Array
	if sym == "normaldo":
		return tiers[0]
	return tiers[mini(count - 1, tiers.size() - 1)]

# ── Data / skin ──────────────────────────────────────────────────────────────

func _on_data_changed() -> void:
	if _token_lbl and is_instance_valid(_token_lbl):
		_token_lbl.text = str(SaveData.tokens)
	if _dollar_lbl and is_instance_valid(_dollar_lbl):
		_dollar_lbl.text = str(SaveData.dollars)
	_refresh_skin_panel()
	_refresh_spin_button()

func _refresh_skin_panel() -> void:
	if not is_instance_valid(_skin_name_lbl):
		return
	var skin_data    = SkinRegistry.get_skin(SaveData.active_skin)
	var skin_tex_dir : String = skin_data.get("tex_dir", "")
	var avatar_tex: Texture2D
	if skin_tex_dir.is_empty():
		avatar_tex = FAT_TEXTURES[0]
	else:
		avatar_tex = load(skin_tex_dir + "state1.png")
	_skin_avatar.texture  = avatar_tex
	_skin_name_lbl.text   = skin_data.get("name_ru", "НОРМАЛЬДО") as String
	var is_mastery := SaveData.skin_level >= 10
	_skin_lvl_lbl.text    = "МАСТЕРСТВО" if is_mastery else "УР. %d" % SaveData.skin_level
	_skin_bar_fill.size.x = maxf(2.0, (_skin_bar_w - 4.0) * SaveData.xp_level_progress())
	if is_instance_valid(_skin_xp_lbl):
		_skin_xp_lbl.text = _xp_hint()

# ── Win popup ─────────────────────────────────────────────────────────────────

func _show_win_popup(result: Dictionary) -> void:
	var prize := _get_prize(result)
	if prize.is_empty():
		return
	_win_applied = false

	var vp    := get_viewport().get_visible_rect().size
	var col   := TIER_COLORS[prize.tier as int] as Color
	var sym   := result.sym as String

	if _win_popup and is_instance_valid(_win_popup):
		_win_popup.queue_free()
	_win_popup = Node2D.new()
	_overlay.add_child(_win_popup)

	var pop_w  := 280.0
	var ico_sz := 52.0
	var pop_h  := 14.0 + ico_sz + 10.0 + 34.0 + 4.0 + 18.0 + 6.0 + 12.0 + 36.0 + 12.0

	var pop_x := (vp.x - pop_w) * 0.5
	var pop_y := (vp.y - pop_h) * 0.5

	var dim := ColorRect.new()
	dim.color    = Color(0.0, 0.0, 0.0, 0.62)
	dim.size     = vp
	dim.position = Vector2.ZERO
	_win_popup.add_child(dim)

	var bg := Panel.new()
	bg.add_theme_stylebox_override("panel", UiKit.rounded(
		Color(0.09, 0.05, 0.17, 0.98), 12, Color(col.r, col.g, col.b, 0.95), 3))
	bg.size         = Vector2(pop_w, pop_h)
	bg.position     = Vector2(pop_x, pop_y)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_win_popup.add_child(bg)

	var cur_y := pop_y + 14.0

	var ico := _make_icon(_tex_for(sym), ico_sz)
	ico.position = Vector2(pop_x + (pop_w - ico_sz) * 0.5, cur_y)
	_win_popup.add_child(ico)
	cur_y += ico_sz + 10.0

	var reward_lbl := _make_label(prize.label as String, 22, col)
	reward_lbl.add_theme_font_override("font", UI_FONT)
	_apply_text_fx(reward_lbl)
	reward_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reward_lbl.size                 = Vector2(pop_w, 34.0)
	reward_lbl.position             = Vector2(pop_x, cur_y)
	_win_popup.add_child(reward_lbl)
	cur_y += 34.0 + 4.0

	var tier_names := ["", "ОБЫЧНЫЙ", "ЦЕННЫЙ", "РЕДКИЙ", "ДЖЕКПОТ"]
	var tier_lbl := _make_label(tier_names[prize.tier as int], 10,
			Color(col.r, col.g, col.b, 0.65))
	tier_lbl.add_theme_font_override("font", UI_FONT)
	_apply_text_fx(tier_lbl)
	tier_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tier_lbl.size                 = Vector2(pop_w, 18.0)
	tier_lbl.position             = Vector2(pop_x, cur_y)
	_win_popup.add_child(tier_lbl)
	cur_y += 18.0 + 6.0 + 12.0

	# OK button — wrapped in a press-scale Control so it gets the same shrink
	# feedback as the main menu / slots chips.
	var ok_w   : float = 120.0
	var ok_h   : float = 36.0
	var ok_pos := Vector2(pop_x + (pop_w - ok_w) * 0.5, cur_y)
	var ok_visual := Control.new()
	ok_visual.size         = Vector2(ok_w, ok_h)
	ok_visual.position     = ok_pos
	ok_visual.pivot_offset = ok_visual.size * 0.5
	ok_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_win_popup.add_child(ok_visual)

	var ok_bg := Panel.new()
	ok_bg.add_theme_stylebox_override("panel", UiKit.rounded(
		Color(col.r * 0.35, col.g * 0.25, col.b * 0.55, 0.96), 8,
		Color(col.r, col.g, col.b, 0.90), 2))
	ok_bg.size         = Vector2(ok_w, ok_h)
	ok_bg.position     = Vector2.ZERO
	ok_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ok_visual.add_child(ok_bg)
	var ok_lbl := _make_label("OK", 18, col)
	ok_lbl.add_theme_font_override("font", UI_FONT)
	_apply_text_fx(ok_lbl)
	ok_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ok_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	ok_lbl.size                 = Vector2(ok_w, ok_h)
	ok_lbl.position             = Vector2.ZERO
	ok_visual.add_child(ok_lbl)
	var ok_btn := Button.new()
	ok_btn.flat       = true
	ok_btn.focus_mode = Control.FOCUS_NONE
	ok_btn.size       = Vector2(ok_w, ok_h)
	ok_btn.position   = ok_pos
	ok_btn.pressed.connect(func():
		if _win_popup and is_instance_valid(_win_popup):
			_win_popup.queue_free()
			_win_popup = null
		_apply_win(result)
	)
	ok_btn.button_down.connect(_press_anim.bind(ok_visual, true))
	ok_btn.button_up.connect(_press_anim.bind(ok_visual, false))
	ok_btn.mouse_exited.connect(_press_anim.bind(ok_visual, false))
	_win_popup.add_child(ok_btn)

	_win_popup.scale      = Vector2(0.5, 0.5)
	_win_popup.modulate.a = 0.0
	var tw := _win_popup.create_tween().set_parallel(true)
	tw.tween_property(_win_popup, "scale", Vector2.ONE, 0.22) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_win_popup, "modulate:a", 1.0, 0.18)

func _apply_win(result: Dictionary) -> void:
	var prize := _get_prize(result)
	if prize.is_empty():
		return
	var vp  := get_viewport().get_visible_rect().size
	var src := Vector2(vp.x * 0.5, vp.y * 0.5)
	match prize.rtype:
		"xp":
			var fly_tex := TEX_PACK if (prize.rval as int) >= 500 else TEX_PIZZA
			var total : int = prize.rval as int
			var given := [0]
			var lvl_rewards : Array = []
			# Полоса растёт ПО МЕРЕ прилёта: каждая пицца несёт свою долю опыта
			# и двигает заливку на неё. Раньше все четыре просто долетали, и
			# только потом полоса ехала одним махом — удар пиццы о полосу ни с
			# чем не был связан.
			var step := func(i: int, n: int) -> void:
				var want : int = int(round(float(total) * float(i) / float(n)))
				var chunk : int = want - given[0]
				if chunk <= 0:
					return
				given[0] = want
				var got : Array = SaveData.add_xp(chunk, "slot_prize")
				lvl_rewards.append_array(got)
				_win_applied = true
				_step_xp_bar(SaveData.xp_level_progress(), not got.is_empty())
			_fly_icons_to(fly_tex, src, _xp_bar_target, 4,
				func(): _finish_xp(lvl_rewards), Color.WHITE, step)
		"dollars":
			var dol_fn := func():
				_win_applied = true
				SaveData.add_dollars(prize.rval, "slot_prize")
			_fly_icons_to(TEX_DOLLAR, src, _dollar_target, 5, dol_fn)
		"tokens":
			var tok_fn := func():
				_win_applied = true
				SaveData.add_tokens(prize.rval, "slot_prize")
			_fly_icons_to(TEX_TOKEN, src, _token_target, 3, tok_fn, Color.WHITE)

func _apply_win_instant(result: Dictionary) -> void:
	var prize := _get_prize(result)
	if prize.is_empty():
		return
	match prize.rtype:
		"xp":      SaveData.add_xp(prize.rval, "slot_prize")
		"dollars": SaveData.add_dollars(prize.rval, "slot_prize")
		"tokens":  SaveData.add_tokens(prize.rval, "slot_prize")

func _fly_icons_to(tex: Texture2D, from: Vector2, to: Vector2, count: int,
		on_done: Callable, tint: Color = Color.WHITE,
		on_each: Callable = Callable()) -> void:
	var state := [0]
	for i in count:
		var ico       := _make_icon(tex, 14.0)
		ico.modulate   = tint
		ico.position   = from + Vector2(randf_range(-18.0, 18.0), randf_range(-10.0, 10.0))
		ico.z_index    = 20
		_overlay.add_child(ico)
		var tw := ico.create_tween()
		tw.tween_interval(float(i) * 0.075)
		tw.tween_property(ico, "position", to, 0.38) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(ico, "modulate:a", 0.0, 0.14).set_delay(0.28)
		tw.tween_callback(func():
			ico.queue_free()
			state[0] += 1
			# Каждая долетевшая пицца толкает полосу на свою долю: опыт
			# начисляется порциями, а не одним рывком после последней иконки.
			if on_each.is_valid():
				on_each.call(state[0], count)
			if state[0] == count:
				on_done.call()
		)

# Шаг полосы под одну прилетевшую пиццу. Тайминг короткий: между иконками
# 0.075 c, и длинный твин просто не успел бы доиграть до следующей.
func _step_xp_bar(p: float, levelled: bool) -> void:
	if not is_instance_valid(_skin_bar_fill):
		return
	var tw := _skin_bar_fill.create_tween()
	if tw == null:
		return
	tw.tween_property(_skin_bar_fill, "size:x",
		maxf(2.0, (_skin_bar_w - 4.0) * p), 0.14) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if levelled:
		_set_bar_color(Color(1.0, 0.85, 0.20))

# Уровни, набранные по дороге, показываются ПОСЛЕ прилёта всех пицц: попап
# посреди полёта оборвал бы его на середине.
func _finish_xp(rewards: Array) -> void:
	var p := SaveData.xp_level_progress()
	if rewards.is_empty():
		_set_bar_color(Color(0.45, 0.80, 1.0))
		_refresh_skin_panel()
		return
	_show_next_level_reward(rewards, 0, p)

func _do_apply_xp(amount: int) -> void:
	var _old_p  := SaveData.xp_level_progress()
	var rewards := SaveData.add_xp(amount, "slot_prize")
	_win_applied = true
	var new_p   := SaveData.xp_level_progress()
	if rewards.is_empty():
		var tw := create_tween()
		tw.tween_property(_skin_bar_fill, "size:x",
			maxf(2.0, (_skin_bar_w - 4.0) * new_p), 0.65) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		var tw := create_tween()
		tw.tween_property(_skin_bar_fill, "size:x", _skin_bar_w - 4.0, 0.40) \
			.set_trans(Tween.TRANS_CUBIC)
		tw.tween_callback(func():
			_set_bar_color(Color(1.0, 0.85, 0.20))
			var tw2 := create_tween()
			tw2.tween_method(_set_bar_color, Color(1.0, 0.85, 0.20),
				Color(0.45, 0.80, 1.0), 0.45)
			_show_next_level_reward(rewards, 0, new_p)
		)

func _show_next_level_reward(rewards: Array, i: int, final_progress: float) -> void:
	if i >= rewards.size():
		if _skin_bar_fill and is_instance_valid(_skin_bar_fill):
			_skin_bar_fill.size.x = maxf(2.0, (_skin_bar_w - 4.0) * final_progress)
			_set_bar_color(Color(0.45, 0.80, 1.0))
		_refresh_skin_panel()
		return
	var r : Dictionary = rewards[i]
	_show_level_up_popup_slots(r.level as int, r.dollars as int, r.tokens as int,
		func(): _show_next_level_reward(rewards, i + 1, final_progress))

func _show_level_up_popup_slots(new_level: int, reward_d: int, reward_t: int, on_close: Callable) -> void:
	var vp           := get_viewport().get_visible_rect().size
	var popup_w      := 240.0
	var has_unlock   : bool   = new_level == 2 or new_level == 5
	var unlock_title : String = ""
	var unlock_desc  : String = ""
	var unlock_fat_idx : int  = 0
	if new_level == 2:
		unlock_title   = "+ ЖИР"
		unlock_desc    = "Новое состояние и +1 жизнь"
		unlock_fat_idx = 2
	elif new_level == 5:
		unlock_title   = "+ УБЕР ЖИР"
		unlock_desc    = "Финальная стадия и +1 жизнь"
		unlock_fat_idx = 3

	const UNLOCK_H : float = 56.0
	var popup_h := 62.0
	if reward_d > 0:   popup_h += 32.0
	if reward_t > 0:   popup_h += 32.0
	if has_unlock:     popup_h += UNLOCK_H + 4.0
	popup_h += 52.0

	var dim := ColorRect.new()
	dim.color        = Color(0.0, 0.0, 0.0, 0.0)
	dim.size         = vp
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.add_child(dim)

	var popup := Node2D.new()
	popup.position   = Vector2(vp.x * 0.5, vp.y * 0.42)
	popup.scale      = Vector2(0.55, 0.55)
	popup.modulate.a = 0.0
	_overlay.add_child(popup)

	var ox := -popup_w * 0.5
	var oy := -popup_h * 0.5

	var bg := ColorRect.new()
	bg.color    = Color(0.05, 0.04, 0.09, 0.97)
	bg.size     = Vector2(popup_w, popup_h)
	bg.position = Vector2(ox, oy)
	popup.add_child(bg)

	var stripe := ColorRect.new()
	stripe.color    = Color(1.0, 0.85, 0.20, 0.92)
	stripe.size     = Vector2(popup_w, 3.0)
	stripe.position = Vector2(ox, oy)
	popup.add_child(stripe)

	var lvl_str := "МАСТЕРСТВО!" if new_level <= 0 or new_level >= 10 else "УРОВЕНЬ %d!" % new_level
	var hdr := Label.new()
	hdr.add_theme_font_override("font", UI_FONT)
	hdr.add_theme_font_size_override("font_size", 20)
	_apply_text_fx(hdr)
	hdr.text                 = lvl_str
	hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hdr.modulate             = Color(1.0, 0.92, 0.20)
	hdr.size                 = Vector2(popup_w, 40.0)
	hdr.position             = Vector2(ox, oy + 18.0)
	popup.add_child(hdr)

	var cur_y := oy + 62.0

	if reward_d > 0:
		var d_icon := _make_icon(TEX_DOLLAR, 22.0)
		d_icon.position = Vector2(ox + 30.0, cur_y + 4.0)
		popup.add_child(d_icon)
		var d_lbl := Label.new()
		d_lbl.add_theme_font_override("font", UI_FONT)
		d_lbl.add_theme_font_size_override("font_size", 18)
		_apply_text_fx(d_lbl)
		d_lbl.text     = "+%d $" % reward_d
		d_lbl.modulate = Color(1.0, 0.88, 0.35)
		d_lbl.size     = Vector2(popup_w - 60.0, 28.0)
		d_lbl.position = Vector2(ox + 58.0, cur_y + 2.0)
		popup.add_child(d_lbl)
		cur_y += 32.0

	if reward_t > 0:
		var t_icon := _make_icon(TEX_TOKEN, 22.0)
		t_icon.position = Vector2(ox + 30.0, cur_y + 4.0)
		popup.add_child(t_icon)
		var t_lbl := Label.new()
		t_lbl.add_theme_font_override("font", UI_FONT)
		t_lbl.add_theme_font_size_override("font_size", 18)
		_apply_text_fx(t_lbl)
		t_lbl.text     = "+%d жетон" % reward_t
		t_lbl.modulate = Color(1.0, 0.72, 0.25)
		t_lbl.size     = Vector2(popup_w - 60.0, 28.0)
		t_lbl.position = Vector2(ox + 58.0, cur_y + 2.0)
		popup.add_child(t_lbl)
		cur_y += 32.0

	if has_unlock:
		var ul_bg := ColorRect.new()
		ul_bg.color    = Color(0.10, 0.26, 0.12, 0.92)
		ul_bg.size     = Vector2(popup_w - 20.0, UNLOCK_H)
		ul_bg.position = Vector2(ox + 10.0, cur_y)
		popup.add_child(ul_bg)

		var ul_stripe := ColorRect.new()
		ul_stripe.color    = Color(0.55, 1.00, 0.55, 0.80)
		ul_stripe.size     = Vector2(popup_w - 20.0, 2.0)
		ul_stripe.position = Vector2(ox + 10.0, cur_y)
		popup.add_child(ul_stripe)

		var fat_sz  : float    = UNLOCK_H - 12.0
		var fat_tex : Texture2D = SkinRegistry.get_avatar_texture(SaveData.active_skin, unlock_fat_idx)
		if fat_tex != null:
			var fat_icon := TextureRect.new()
			fat_icon.texture        = fat_tex
			fat_icon.expand_mode    = TextureRect.EXPAND_IGNORE_SIZE
			fat_icon.stretch_mode   = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			fat_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			fat_icon.size           = Vector2(fat_sz, fat_sz)
			fat_icon.position       = Vector2(ox + 18.0, cur_y + 6.0)
			fat_icon.mouse_filter   = Control.MOUSE_FILTER_IGNORE
			popup.add_child(fat_icon)

		var text_x : float = ox + 18.0 + fat_sz + 12.0
		var text_w : float = popup_w - 20.0 - (text_x - (ox + 10.0)) - 10.0

		var ul_title := Label.new()
		ul_title.add_theme_font_override("font", UI_FONT)
		ul_title.add_theme_font_size_override("font_size", 14)
		_apply_text_fx(ul_title)
		ul_title.text                 = unlock_title
		ul_title.modulate             = Color(0.55, 1.00, 0.65)
		ul_title.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		ul_title.size                 = Vector2(text_w, 18.0)
		ul_title.position             = Vector2(text_x, cur_y + 6.0)
		popup.add_child(ul_title)

		var ul_desc := Label.new()
		ul_desc.add_theme_font_override("font", UI_FONT)
		ul_desc.add_theme_font_size_override("font_size", 10)
		_apply_text_fx(ul_desc)
		ul_desc.text                 = unlock_desc
		ul_desc.modulate             = Color(0.85, 0.95, 0.85, 0.95)
		ul_desc.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		ul_desc.autowrap_mode        = TextServer.AUTOWRAP_WORD_SMART
		ul_desc.size                 = Vector2(text_w, UNLOCK_H - 26.0)
		ul_desc.position             = Vector2(text_x, cur_y + 24.0)
		popup.add_child(ul_desc)

		cur_y += UNLOCK_H + 4.0

	cur_y += 10.0
	var btn_sz : Vector2 = Vector2(popup_w - 32.0, 36.0)
	var btn_pos: Vector2 = Vector2(ox + 16.0, cur_y)
	var btn_visual := Control.new()
	btn_visual.size         = btn_sz
	btn_visual.position     = btn_pos
	btn_visual.pivot_offset = btn_sz * 0.5
	btn_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup.add_child(btn_visual)

	var btn_bg := ColorRect.new()
	btn_bg.color    = Color(0.08, 0.22, 0.10, 0.95)
	btn_bg.size     = btn_sz
	btn_bg.position = Vector2.ZERO
	btn_visual.add_child(btn_bg)

	var btn_stripe := ColorRect.new()
	btn_stripe.color    = Color(0.55, 1.0, 0.65, 0.80)
	btn_stripe.size     = Vector2(btn_sz.x, 2.0)
	btn_stripe.position = Vector2.ZERO
	btn_visual.add_child(btn_stripe)

	var btn_lbl := Label.new()
	btn_lbl.add_theme_font_override("font", UI_FONT)
	btn_lbl.add_theme_font_size_override("font_size", 15)
	_apply_text_fx(btn_lbl)
	btn_lbl.text                 = "ЗАБРАТЬ!"
	btn_lbl.modulate             = Color(0.55, 1.0, 0.65)
	btn_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	btn_lbl.size                 = btn_sz
	btn_lbl.position             = Vector2.ZERO
	btn_visual.add_child(btn_lbl)

	var collect_btn := Button.new()
	collect_btn.flat       = true
	collect_btn.focus_mode = Control.FOCUS_NONE
	collect_btn.size       = btn_sz
	collect_btn.position   = btn_pos
	collect_btn.button_down.connect(_press_anim.bind(btn_visual, true))
	collect_btn.button_up.connect(_press_anim.bind(btn_visual, false))
	collect_btn.mouse_exited.connect(_press_anim.bind(btn_visual, false))
	collect_btn.pressed.connect(func():
		if collect_btn.disabled:
			return
		collect_btn.disabled = true
		if _hud and _hud.has_method("_play_btn_sfx"):
			_hud._play_btn_sfx()
		var tw_out := create_tween().set_parallel(true)
		tw_out.tween_property(popup, "modulate:a", 0.0, 0.22)
		tw_out.tween_property(dim,   "color:a",    0.0, 0.22)
		tw_out.chain().tween_callback(func():
			if is_instance_valid(popup): popup.queue_free()
			if is_instance_valid(dim):   dim.queue_free()
			on_close.call()
		)
	)
	popup.add_child(collect_btn)

	var tw_in := popup.create_tween().set_parallel(true)
	tw_in.tween_property(dim,   "color:a",         0.68,        0.22)
	tw_in.tween_property(popup, "scale",           Vector2.ONE, 0.26) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw_in.tween_property(popup, "modulate:a",     1.0,         0.18)

func _show_no_tokens() -> void:
	# Тост поверх арта раньше терялся; теперь он висит под кнопкой, у которой уже
	# написано «НЕТ ЖЕТОНОВ», и только объясняет, где жетоны взять.
	var r : Rect2 = _lay["mach"]
	var w : float = r.size.x - 20.0
	var root := Control.new()
	root.position     = Vector2(r.position.x + 10.0, r.position.y + r.size.y - 92.0)
	root.size         = Vector2(w, 26.0)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(root)

	var box := Panel.new()
	box.add_theme_stylebox_override("panel", UiKit.rounded(
		Color(0.22, 0.06, 0.08, 0.96), 8, Color(1.0, 0.45, 0.45, 0.90), 2))
	box.size         = root.size
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(box)

	var toast := Label.new()
	toast.add_theme_font_override("font", UI_FONT)
	toast.add_theme_font_size_override("font_size", 12)
	_apply_text_fx(toast)
	toast.text                 = "Жетоны дают за задания и уровни скина"
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	toast.modulate             = Color(1.0, 0.85, 0.85)
	toast.size                 = root.size
	toast.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	root.add_child(toast)

	var tw := root.create_tween()
	tw.tween_interval(1.0)
	tw.tween_property(root, "modulate:a", 0.0, 1.0)
	tw.tween_callback(root.queue_free)

func _on_change_skin() -> void:
	if _hud and _hud.has_method("_show_shop_from_slots"):
		_hud._show_shop_from_slots()

func _on_close() -> void:
	if _win_popup and is_instance_valid(_win_popup):
		_apply_win_instant(_last_result)
		_win_popup.queue_free()
		_win_popup = null
	elif not _win_applied and not _last_result.is_empty():
		_apply_win_instant(_last_result)
	if SaveData.data_changed.is_connected(_on_data_changed):
		SaveData.data_changed.disconnect(_on_data_changed)
	_stop_music()
	# Reverse the camera pan: slots slides DOWN, main menu drops back into view.
	if not is_instance_valid(_slide_root):
		queue_free()
		return
	var vp := get_viewport().get_visible_rect().size
	var tw := create_tween()
	tw.tween_property(_slide_root, "position", Vector2(0.0, vp.y), SLIDE_TIME)\
		.set_trans(SLIDE_TRANS).set_ease(SLIDE_EASE_OUT)
	tw.tween_callback(Callable(self, "queue_free"))
	if _hud != null and _hud.has_method("_on_slots_close_anim_start"):
		_hud._on_slots_close_anim_start(SLIDE_TIME, SLIDE_TRANS, SLIDE_EASE_OUT)
	# Bring TV audio back up to its pre-mute level as we slide away.
	_unmute_tv()
