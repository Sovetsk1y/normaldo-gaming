class_name MinigamePayout
extends CanvasLayer

# ── Итог мини-игры: барабаны, множитель и перелёт добычи ──────────────────────
# Раньше множитель ×1…×5 просто всплывал надписью «×N РЕЙТ» в центре экрана.
# Игрок видел число, но не понимал, к ЧЕМУ оно применилось: добыча к тому
# моменту уже улетала в общий счёт, и связь «намолотил в мини-игре → умножилось»
# на экране нигде не показывалась.
#
# Теперь это одна сцена из четырёх тактов:
#   1. Плашка. Появляется то, что заработано ИМЕННО в мини-игре: пиццы и доллары.
#   2. Барабаны. Три слота крутятся и по очереди встают. Символы — сами
#      множители (×1…×5), и встают ВСЕГДА три одинаковых: результат брошен
#      заранее (LootMultiplier.roll), барабаны его только показывают.
#   3. Перелёт. «×N» уезжает в плашку, числа на ней прокручиваются до
#      умноженных — вот он, момент «мой улов вырос».
#   4. Вылет. Плашка улетает иконками в счётчики HUD, и забег продолжается.
#
# Начисляет добычу ВЫЗЫВАЮЩИЙ — по сигналу `finished`, чтобы счётчик HUD
# щёлкнул ровно тогда, когда до него долетели иконки.
#
# См. /Концепция/Экономика.md → «Множитель мини-игр»

signal finished(mult: int)

const UI_FONT    := preload("res://assets/fonts/RussoOne-Regular.ttf")
const PIZZA_TEX  := preload("res://assets/items/pizza.png")
const DOLLAR_TEX := preload("res://assets/items/dollar.png")
const ROLL_SFX   := preload("res://assets/audio/rolling.mp3")
const STOP_SFX   := preload("res://assets/audio/tap.mp3")
const WIN_SFX    := preload("res://assets/audio/magic_glitter.mp3")
const BIG_SFX    := preload("res://assets/audio/firecracker.mp3")

# ── Геометрия ─────────────────────────────────────────────────────────────────
# Экран всего 960×430, поэтому барабан ровно на один символ высотой: соседние
# позиции ленты нужны только для прокрутки и живут за границей обрезки.
const REEL_W   : float = 62.0
const SYM_H    : float = 56.0
const REEL_GAP : float = 10.0
const N_TILES  : int   = 3      # символов в ленте барабана (видно всегда верхний)

# Лента барабана. Результат брошен заранее, так что раскладка тут чисто
# декоративная — но частоты те же, что в таблице бросков, иначе на глаз кажется,
# будто ×5 попадается через раз.
const STRIP : Array = [1, 2, 3, 1, 4, 2, 1, 5, 3, 2, 1, 4, 2, 3, 1, 2, 5, 1, 3, 2]

const SPIN_SPEED  : float = 1250.0   # px/с прокрутки ленты
const SPIN_HOLD   : float = 0.75     # сколько крутятся все три до первой остановки
const STOP_STEP   : float = 0.30     # пауза между остановками барабанов
const STOP_TIME   : float = 0.45     # доводка барабана до символа
const FLY_ICONS   : int   = 4        # сколько иконок улетает в счётчик (косметика)

var _mult      : int = 1
var _pizzas    : int = 0
var _dollars   : int = 0
var _pizza_to  : Vector2 = Vector2.ZERO
var _dollar_to : Vector2 = Vector2.ZERO

var _spinning   : bool  = false
var _scroll_y   : Array = [0.0, 0.0, 0.0]
var _scroll_spd : Array = [0.0, 0.0, 0.0]
var _tiles      : Array = []      # [barabaн][k] → Label
var _clips      : Array = []      # Control с обрезкой

var _root       : Control = null
var _dim        : ColorRect = null
var _machine    : Control = null
var _plaque     : Control = null
var _flash      : ColorRect = null
var _pizza_lbl  : Label = null
var _dollar_lbl : Label = null
var _pizza_icon : Control = null
var _dollar_icon: Control = null
var _reels_mid  : Vector2 = Vector2.ZERO
var _plaque_mid : Vector2 = Vector2.ZERO
var _roll_audio : AudioStreamPlayer = null

# Удобная обёртка: создать, проиграть, дождаться. Возвращает управление ровно
# тогда, когда добычу пора начислять.
static func play(parent: Node, pizzas: int, dollars: int, mult: int,
		pizza_to: Vector2, dollar_to: Vector2) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	if pizzas <= 0 and dollars <= 0:
		return   # умножать нечего — сцену не показываем
	var w := MinigamePayout.new()
	w.setup(pizzas, dollars, mult, pizza_to, dollar_to)
	parent.add_child(w)
	await w.finished

# Куда лететь добыче — счётчики пицц и долларов в HUD. Держим здесь, чтобы три
# мини-игры не искали HUD каждая по-своему. Возвращает [пицца, доллар].
static func targets_from(hud: Node) -> Array:
	var p := Vector2(120.0, 14.0)
	var d := Vector2(180.0, 14.0)
	if hud != null and is_instance_valid(hud):
		if hud.has_method("fat_boss_pizza_target"):
			p = hud.fat_boss_pizza_target()
		if hud.has_method("fat_boss_dollar_target"):
			d = hud.fat_boss_dollar_target()
	return [p, d]

func setup(pizzas: int, dollars: int, mult: int,
		pizza_to: Vector2, dollar_to: Vector2) -> void:
	_pizzas    = maxi(pizzas, 0)
	_dollars   = maxi(dollars, 0)
	_mult      = clampi(mult, 1, 5)
	_pizza_to  = pizza_to
	_dollar_to = dollar_to

func _ready() -> void:
	layer        = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_run()

func _process(delta: float) -> void:
	if not _spinning:
		return
	for i in 3:
		if float(_scroll_spd[i]) > 0.0:
			_scroll_y[i] = float(_scroll_y[i]) + float(_scroll_spd[i]) * delta
			_paint_reel(i)

# ── Сборка ────────────────────────────────────────────────────────────────────

func _build() -> void:
	var vp := get_viewport().get_visible_rect().size
	_root = Control.new()
	_root.size         = vp
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	# Затемнение слабое: забег под ним продолжает читаться, а сцена всё равно
	# собирает взгляд в центр.
	_dim = ColorRect.new()
	_dim.color        = Color(0.0, 0.0, 0.0, 0.0)
	_dim.size         = vp
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_dim)
	_dim.create_tween().tween_property(_dim, "color:a", 0.55, 0.22)

	var reels_w : float = REEL_W * 3.0 + REEL_GAP * 2.0
	var reels_x : float = (vp.x - reels_w) * 0.5
	var reels_y : float = vp.y * 0.30
	_reels_mid  = Vector2(vp.x * 0.5, reels_y + SYM_H * 0.5)

	# Корпус и барабаны живут в общем узле: отработав, автомат гаснет целиком,
	# и внимание переходит на плашку. Иконки перелёта лежат вне него, иначе
	# погасли бы вместе с ним на полпути.
	_machine = Control.new()
	_machine.size         = vp
	_machine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_machine)
	_build_cabinet(reels_x, reels_y, reels_w)
	for i in 3:
		_build_reel(reels_x + i * (REEL_W + REEL_GAP), reels_y)

	_build_plaque(vp)

	_roll_audio        = AudioStreamPlayer.new()
	_roll_audio.stream = ROLL_SFX
	_root.add_child(_roll_audio)

# Корпус автомата: тёмная панель с золотой рамкой и подписью «РЕЙТ».
func _build_cabinet(x: float, y: float, w: float) -> void:
	var pad := 9.0
	var frame := ColorRect.new()
	frame.color        = Color(1.0, 0.80, 0.25, 0.95)
	frame.size         = Vector2(w + pad * 2.0, SYM_H + pad * 2.0)
	frame.position     = Vector2(x - pad, y - pad)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_machine.add_child(frame)

	var inner := ColorRect.new()
	inner.color        = Color(0.06, 0.05, 0.09, 0.98)
	inner.size         = frame.size - Vector2(6.0, 6.0)
	inner.position     = frame.position + Vector2(3.0, 3.0)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_machine.add_child(inner)

	var cap := _label("РЕЙТ", 16, Color(1.0, 0.88, 0.35))
	cap.size     = Vector2(w, 20.0)
	cap.position = Vector2(x, y - pad - 24.0)
	_machine.add_child(cap)

func _build_reel(x: float, y: float) -> void:
	var clip := Control.new()
	clip.position      = Vector2(x, y)
	clip.size          = Vector2(REEL_W, SYM_H)
	clip.clip_contents = true
	clip.pivot_offset  = clip.size * 0.5
	clip.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	_machine.add_child(clip)
	_clips.append(clip)

	var tiles : Array = []
	for k in N_TILES:
		var l := _label("×1", 30, Color.WHITE)
		l.size     = Vector2(REEL_W, SYM_H)
		l.position = Vector2(0.0, k * SYM_H)
		clip.add_child(l)
		tiles.append(l)
	_tiles.append(tiles)
	_paint_reel(_tiles.size() - 1)

# Плашка итога: то, что заработано в мини-игре, и больше ничего.
func _build_plaque(vp: Vector2) -> void:
	var pw : float = 226.0
	var ph : float = 54.0
	_plaque_mid = Vector2(vp.x * 0.5, vp.y * 0.70)
	_plaque = Control.new()
	_plaque.size         = Vector2(pw, ph)
	_plaque.position     = _plaque_mid - _plaque.size * 0.5
	_plaque.pivot_offset = _plaque.size * 0.5
	_plaque.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_plaque)

	var bg := ColorRect.new()
	bg.color        = Color(0.06, 0.05, 0.09, 0.96)
	bg.size         = _plaque.size
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plaque.add_child(bg)
	var stripe := ColorRect.new()
	stripe.color        = Color(0.45, 1.0, 0.55, 0.85)
	stripe.size         = Vector2(pw, 2.0)
	stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plaque.add_child(stripe)

	# Вспышка по прилёту множителя — рисуем сразу, держим прозрачной.
	_flash = ColorRect.new()
	_flash.color        = Color(1.0, 1.0, 1.0, 0.0)
	_flash.size         = _plaque.size
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plaque.add_child(_flash)

	# Показываем только то, что реально набрано: пустой счётчик в итогах — шум.
	var slots : Array = []
	if _pizzas  > 0: slots.append("pizza")
	if _dollars > 0: slots.append("dollar")
	var step : float = pw / float(maxi(slots.size(), 1))
	for i in slots.size():
		var cx : float = step * i
		var is_pizza : bool = slots[i] == "pizza"
		var ico := _icon(PIZZA_TEX if is_pizza else DOLLAR_TEX, 30.0)
		ico.position = Vector2(cx + step * 0.5 - 34.0, (ph - 30.0) * 0.5 + 2.0)
		_plaque.add_child(ico)
		var lbl := _label(str(_pizzas if is_pizza else _dollars), 26,
			Color(1, 1, 1) if is_pizza else Color(1.0, 0.88, 0.35))
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		lbl.size         = Vector2(step * 0.5, ph)
		lbl.position     = Vector2(cx + step * 0.5 - 0.0, 2.0)
		lbl.pivot_offset = Vector2(0.0, ph * 0.5)
		_plaque.add_child(lbl)
		if is_pizza:
			_pizza_lbl = lbl
			_pizza_icon = ico
		else:
			_dollar_lbl = lbl
			_dollar_icon = ico

	_plaque.scale      = Vector2(0.6, 0.6)
	_plaque.modulate.a = 0.0

# ── Барабаны ──────────────────────────────────────────────────────────────────

func _paint_reel(idx: int) -> void:
	var sy      : float = float(_scroll_y[idx])
	var partial : float = fposmod(sy, SYM_H)
	var base    : int   = int(floor(sy / SYM_H)) % STRIP.size()
	if base < 0:
		base += STRIP.size()
	for k in N_TILES:
		var v : int = int(STRIP[(base + k) % STRIP.size()])
		var l : Label = _tiles[idx][k]
		l.text     = "×%d" % v
		l.position = Vector2(0.0, -partial + k * SYM_H)
		l.add_theme_color_override("font_color", _tier_color(v))

func _tier_color(v: int) -> Color:
	var t : Array = LootMultiplier.TIER_COLORS
	return t[clampi(v - 1, 0, t.size() - 1)]

# Позиция ленты, при которой сверху окажется нужный множитель. Из нескольких
# подходящих берём случайную — иначе барабан каждый раз встаёт одинаково.
func _target_pos(mult: int) -> int:
	var hits : Array = []
	for i in STRIP.size():
		if int(STRIP[i]) == mult:
			hits.append(i)
	return int(hits[randi() % hits.size()]) if not hits.is_empty() else 0

func _spin() -> void:
	_spinning = true
	for i in 3:
		_scroll_spd[i] = SPIN_SPEED
	_roll_audio.play()
	await _wait(SPIN_HOLD)
	for i in 3:
		_stop_reel(i)
		await _wait(STOP_STEP if i < 2 else STOP_TIME)
	_spinning = false
	if is_instance_valid(_roll_audio):
		_roll_audio.stop()

func _stop_reel(idx: int) -> void:
	_scroll_spd[idx] = 0.0
	var cur : float = float(_scroll_y[idx])
	var strip_h : float = STRIP.size() * SYM_H
	# Доводим ВПЕРЁД и минимум на пол-ленты, иначе барабан дёрнется назад.
	var target : float = float(_target_pos(_mult)) * SYM_H
	while target < cur + strip_h * 0.5:
		target += strip_h
	var tw := create_tween()
	tw.tween_method(_scroll_to.bind(idx), cur, target, STOP_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_callback(_reel_landed.bind(idx))

# Отдельным методом, а не лямбдой: tween_method и bind читаются, а многострочная
# лямбда прямо в аргументах — нет.
func _scroll_to(v: float, idx: int) -> void:
	_scroll_y[idx] = v
	_paint_reel(idx)

func _reel_landed(idx: int) -> void:
	_play_once(STOP_SFX, -4.0)
	var clip : Control = _clips[idx]
	var tw := clip.create_tween()
	tw.tween_property(clip, "scale", Vector2(1.0, 0.88), 0.05)
	tw.tween_property(clip, "scale", Vector2.ONE, 0.14) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# ── Сценарий ──────────────────────────────────────────────────────────────────

func _run() -> void:
	# Плашка приезжает первой: сначала «вот что я намолотил», и только потом —
	# «а вот на сколько это умножится».
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_plaque, "modulate:a", 1.0, 0.20)
	tw.tween_property(_plaque, "scale", Vector2.ONE, 0.28) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tw.finished

	await _spin()
	await _fly_mult_into_plaque()
	await _grow_numbers()
	await _wait(0.35)
	await _fly_to_hud()

	finished.emit(_mult)
	queue_free()

# «×N» вылезает из-под барабанов и уезжает в плашку.
func _fly_mult_into_plaque() -> void:
	var big := _label("×%d" % _mult, 46, _tier_color(_mult))
	big.size         = Vector2(180.0, 60.0)
	big.pivot_offset = big.size * 0.5
	big.position     = _reels_mid + Vector2(-90.0, SYM_H * 0.5 + 6.0)
	big.scale        = Vector2.ZERO
	_root.add_child(big)
	_play_once(BIG_SFX if _mult >= 4 else WIN_SFX, -6.0)

	var pop := create_tween()
	pop.tween_property(big, "scale", Vector2.ONE, 0.26) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.tween_interval(0.30)
	await pop.finished

	var fly := create_tween().set_parallel(true)
	fly.tween_property(big, "position", _plaque_mid - big.size * 0.5, 0.34) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	fly.tween_property(big, "scale", Vector2(0.35, 0.35), 0.34)
	# Автомат своё отработал — гаснет вместе с вылетом множителя.
	fly.tween_property(_machine, "modulate:a", 0.0, 0.34)
	await fly.finished
	big.queue_free()

# Числа на плашке прокручиваются до умноженных — это и есть «икс улетел в плашку».
func _grow_numbers() -> void:
	_play_once(WIN_SFX, -2.0)
	var f := create_tween()
	f.tween_property(_flash, "color:a", 0.75, 0.06)
	f.tween_property(_flash, "color:a", 0.0, 0.28)

	if _mult <= 1:
		# ×1 честно ничего не меняет — только толчок, чтобы такт не «повис».
		_punch(_plaque, 1.06)
		await _wait(0.30)
		return

	_punch(_plaque, 1.12)
	var tw := create_tween().set_parallel(true)
	if _pizza_lbl != null:
		tw.tween_method(_set_count.bind(_pizza_lbl),
			float(_pizzas), float(_pizzas * _mult), 0.45)
	if _dollar_lbl != null:
		tw.tween_method(_set_count.bind(_dollar_lbl),
			float(_dollars), float(_dollars * _mult), 0.45)
	await tw.finished
	_punch(_pizza_lbl, 1.35)
	_punch(_dollar_lbl, 1.35)
	await _wait(0.18)

# Плашка улетает иконками в счётчики HUD — забег получает добычу.
func _fly_to_hud() -> void:
	var flights : Array = []
	if _pizzas  > 0 and _pizza_icon  != null:
		flights.append([_pizza_icon,  _pizza_to])
	if _dollars > 0 and _dollar_icon != null:
		flights.append([_dollar_icon, _dollar_to])

	# Летят по дуге, а не по прямой: прямая линия от плашки к счётчику читается
	# как «съехало», дуга — как «улетело».
	for f in flights:
		var src : Control = f[0]
		var dst : Vector2 = f[1]
		var from : Vector2 = src.global_position + src.size * 0.5
		for n in FLY_ICONS:
			var ico := _icon(src.get_meta("tex") as Texture2D, 22.0)
			ico.position = from - ico.size * 0.5
			_root.add_child(ico)
			var ctrl := Vector2((from.x + dst.x) * 0.5 + randf_range(-40.0, 40.0),
				minf(from.y, dst.y) - randf_range(30.0, 80.0))
			var tw := create_tween()
			tw.tween_interval(n * 0.07)
			tw.tween_method(_arc.bind(ico, from, ctrl, dst), 0.0, 1.0, 0.5) \
				.set_trans(Tween.TRANS_SINE)
			tw.parallel().tween_property(ico, "scale", Vector2(0.45, 0.45), 0.5)
			tw.tween_callback(ico.queue_free)

	var out := create_tween().set_parallel(true)
	out.tween_property(_plaque, "modulate:a", 0.0, 0.32)
	out.tween_property(_plaque, "scale", Vector2(0.7, 0.7), 0.32)
	out.tween_property(_dim, "color:a", 0.0, 0.32)
	await out.finished

# ── Мелочи ────────────────────────────────────────────────────────────────────

func _label(txt: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_override("font", UI_FONT)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", 6)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	return l

func _icon(tex: Texture2D, sz: float) -> TextureRect:
	var r := TextureRect.new()
	r.texture      = tex
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
	r.size         = Vector2(sz, sz)
	r.pivot_offset = r.size * 0.5
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.set_meta("tex", tex)
	return r

# Квадратичная кривая Безье: точка на дуге from → ctrl → to.
func _arc(t: float, node: Control, from: Vector2, ctrl: Vector2, to: Vector2) -> void:
	if not is_instance_valid(node):
		return
	var p : Vector2 = from.lerp(ctrl, t).lerp(ctrl.lerp(to, t), t)
	node.position = p - node.size * 0.5

func _set_count(v: float, lbl: Label) -> void:
	if is_instance_valid(lbl):
		lbl.text = str(int(round(v)))

func _punch(node: Control, to: float) -> void:
	if not is_instance_valid(node):
		return
	node.scale = Vector2(to, to)
	var tw := node.create_tween()
	tw.tween_property(node, "scale", Vector2.ONE, 0.20) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _play_once(stream: AudioStream, db: float) -> void:
	var a := AudioStreamPlayer.new()
	a.stream    = stream
	a.volume_db = db
	_root.add_child(a)
	a.play()
	a.finished.connect(a.queue_free)

func _wait(t: float) -> void:
	await get_tree().create_timer(t, true).timeout
