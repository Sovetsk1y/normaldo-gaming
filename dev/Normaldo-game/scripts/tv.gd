extends Sprite2D

# Living-room TV across from the couch on the menu/intro scene.
# Two sheets: tv_play_sheet (idle on-air loop) and tv_crash_sheet
# (broken/static — kept for later use). Currently only PLAY loops.
#
# Also drives the "channel-surfing" loop used while we're on the main menu:
# ведёт отсчёт до смены канала и за три секунды до неё просит Нормальдо взяться
# за пульт. Канал переключается ровно в тот момент, когда он жмёт кнопку
# (`menu_remote_button_pressed`), — щелчок и смена совпадают.
#
# ── ТЕЛЕВИЗОР МОЛЧИТ ─────────────────────────────────────────────────────────
# Болтовня каналов (tv1…tv7.mp3) с главной убрана: на меню играет музыка, и
# поверх неё второй звуковой слой не складывался — два источника спорили друг с
# другом, а музыка при этом была тише, чем сама по себе.
#
# Убрана именно ОЗВУЧКА, а не сцена: телевизор так же светится, так же
# переключает каналы, Нормальдо так же тянется за пультом. Раньше ритм этого
# всего задавала ДЛИНА КЛИПА — снять звук и не заменить часы значило бы
# заморозить картинку на одном канале навсегда и заодно убить достижение
# «Пульт нашёлся». Поэтому отсчёт теперь свой, `CHANNEL_TIME`.
#
# Файлы tv*.mp3 оставлены в assets: они ещё пригодятся, если телевизор
# когда-нибудь заговорит там, где музыки нет.
const CHANNEL_TIME : float = 22.0   # сколько «идёт» канал до смены

const SHEET_PLAY  := preload("res://assets/background_items/tv/tv_play_sheet.png")
const SHEET_CRASH := preload("res://assets/background_items/tv/tv_crash_sheet.png")
const CRASH_SFX   := preload("res://assets/audio/tv/crash.mp3")

const FRAME_W     : int = 48
const FRAME_H     : int = 48
const FRAME_COUNT : int = 17
const FRAME_TIME  : float = 0.13
# Ping-pong cadence for the crash loop — a touch slower than the play loop so
# the glitchy frames register before flipping direction.
const CRASH_FRAME_TIME : float = 0.10

# ── Position on the menu screen (offset from viewport centre) ────────────────
# Couch sits at MENU_OFFSET = Vector2(-260, 110) in couch.gd. The TV is placed
# mirrored on the right side so the room looks "couch ↔ TV". Tweak these to
# move the TV around.
const MENU_OFFSET := Vector2(0.0, 110.0)
const SCALE_FACTOR : float = 2.0
# Same scroll speed as the background — TV is a piece of the scene.
# (Синхронизировано с background.gd SCROLL_SPEED = 68 — иначе ТВ отрывается от пола.)
const SCROLL_SPEED : float = 68.0

# За сколько секунд до смены канала звать Нормальдо за пультом. Анимация длится
# примерно столько же, так что рывок с нажатием приходится ровно на смену.
const REMOTE_LEAD_TIME : float = 3.0

var _frame_index     : int     = 0
var _frame_timer     : float   = 0.0
var _frame_step      : int     = 1   # +1 / -1 for the crash ping-pong loop
var _crashed         : bool    = false
var _locked_position : Vector2 = Vector2.ZERO
var _bg              : Node    = null

# Channel-surfing
var _crash_audio    : AudioStreamPlayer = null
var _channel_left   : float       = CHANNEL_TIME   # до смены канала
var _remote_cued    : bool        = false   # уже позвали Нормальдо за пультом
var _normaldo       : Node        = null

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	region_enabled = true
	texture        = SHEET_PLAY
	scale          = Vector2.ONE * SCALE_FACTOR
	# Sits above the Background (z 0) so the thrown remote can slot UNDER the
	# TV (z 1) while still drawing above the floor — z = -1 would hide it
	# behind the bg entirely.
	z_index        = 2
	# top_level=true makes the node ignore any parent transforms — it lives in
	# absolute world space, so nothing in the scene can push it around.
	top_level      = true
	_set_frame(randi() % FRAME_COUNT)
	_locked_position = get_viewport_rect().get_center() + MENU_OFFSET
	global_position  = _locked_position
	_bg = get_parent().get_node_or_null("Background")

	# Pre-warm the crash SFX player — adding the player + assigning the stream
	# at impact time costs a frame or two before play() actually fires, which
	# the player perceives as audio lag behind the visual smash. Keeping it
	# resident lets trigger_crash() just call .play() with zero latency.
	_crash_audio = AudioStreamPlayer.new()
	_crash_audio.bus       = "Master"
	# 15 % quieter than unity → linear 0.85 → −1.4 dB.
	_crash_audio.volume_db = -1.4
	_crash_audio.stream    = CRASH_SFX
	add_child(_crash_audio)

	# Connect to Normaldo's remote-press signal so the channel swaps in lock-
	# step with the on-screen button click. Connection happens after one frame
	# so both nodes are guaranteed to be ready (TV and Normaldo are siblings).
	call_deferred("_hook_remote_signal")
	_channel_left = CHANNEL_TIME
	_remote_cued  = false

func _set_frame(idx: int) -> void:
	_frame_index = idx
	region_rect = Rect2(idx * FRAME_W, 0, FRAME_W, FRAME_H)

func _process(delta: float) -> void:
	# Once the background starts scrolling, advance the TV with it — it's a
	# piece of the room, not a HUD element. Until then it stays put.
	if _bg != null and _bg.get("_scrolling") == true:
		_locked_position.x -= SCROLL_SPEED * delta
	global_position = _locked_position
	if _locked_position.x < -FRAME_W * SCALE_FACTOR * 1.5:
		queue_free()
		return
	# Frame loop — straight forward during play, ping-pong (0 → last → 0) once
	# the TV has been smashed by Normaldo's remote.
	_frame_timer += delta
	var step_time : float = CRASH_FRAME_TIME if _crashed else FRAME_TIME
	if _frame_timer >= step_time:
		_frame_timer = 0.0
		if _crashed:
			_frame_index += _frame_step
			if _frame_index >= FRAME_COUNT - 1:
				_frame_index = FRAME_COUNT - 1
				_frame_step  = -1
			elif _frame_index <= 0:
				_frame_index = 0
				_frame_step  = 1
		else:
			_frame_index = (_frame_index + 1) % FRAME_COUNT
		_set_frame(_frame_index)

	# After the crash the TV is silent — no more channel surfing or remote cues.
	if _crashed:
		return

	# Часы канала. Раньше их роль играла длина клипа — см. шапку.
	_channel_left -= delta
	# За три секунды до смены зовём Нормальдо взяться за пульт.
	if not _remote_cued and _channel_left <= REMOTE_LEAD_TIME:
		_remote_cued = true
		if _normaldo and _normaldo.has_method("play_tv_remote_anim"):
			_normaldo.play_tv_remote_anim()
	# Подстраховка: если кнопку так никто и не нажал (Нормальдо был занят не
	# сидением на диване), канал всё равно переключается — телевизор не должен
	# залипать на одном кадре.
	if _channel_left <= 0.0:
		_play_next_track()

# ── Channel surfing ──────────────────────────────────────────────────────────

func _hook_remote_signal() -> void:
	_normaldo = get_parent().get_node_or_null("Normaldo")
	if _normaldo and _normaldo.has_signal("menu_remote_button_pressed"):
		# Late-bind: connecting via call_deferred → already in tree.
		if not _normaldo.menu_remote_button_pressed.is_connected(_on_remote_pressed):
			_normaldo.menu_remote_button_pressed.connect(_on_remote_pressed)

# Переключить канал. Звука у канала больше нет (см. шапку), так что вся смена —
# это перезапуск часов; картинку крутит общий кадровый цикл.
func _play_next_track() -> void:
	_channel_left = CHANNEL_TIME
	_remote_cued  = false

# Called the instant Normaldo's remote-button jerk hits its lowest point.
func _on_remote_pressed() -> void:
	_play_next_track()

# Called by hud.gd when the player launches a run. Kept as a no-op stub —
# the actual TV smash is driven by trigger_crash(), called the instant
# Normaldo's thrown remote reaches the screen.
func start_game() -> void:
	pass

# Уйти со сцены — см. `couch.leave_scene`.
#
# Раньше узел жил ещё четверть секунды после ухода: телевизор болтал своим
# каналом, и оборванный на полуслове звук слышался как сбой, поэтому его
# доводили затуханием. Канал молчит — доводить нечего, уходим сразу.
func leave_scene() -> void:
	visible = false
	set_process(false)
	queue_free()

# Slams the TV: swaps the sprite sheet to the smashed/static frames, plays the
# crash SFX, and kicks off the ping-pong frame loop (0 → last → 0 → last → …).
#
# Звон разбитого экрана ОСТАЁТСЯ, хотя каналы замолчали: это не фон, а отклик на
# действие игрока — он сам швырнул пульт.
func trigger_crash() -> void:
	if _crashed:
		return
	_crashed = true
	# Fire the SFX FIRST while the on-screen visual swap is still pending —
	# audio dispatch and the next render frame line up that way. Doing the
	# sprite-sheet swap first introduces a perceptible visual-leads-audio gap.
	if _crash_audio:
		_crash_audio.play()
	texture     = SHEET_CRASH
	_frame_index = 0
	_frame_step  = 1
	_frame_timer = 0.0
	_set_frame(0)

# True once trigger_crash() has fired — used by the intro orchestrator.
func is_crashed() -> bool:
	return _crashed
