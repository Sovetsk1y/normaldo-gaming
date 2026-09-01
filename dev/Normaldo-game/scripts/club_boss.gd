extends Node2D

# ── Босс: ХОЗЯИН КЛУБА (Club Boss) ───────────────────────────────────────────
# Третий босс игры после Ноги Ниндзя и Крокодила. Из старого проекта он там
# стоял последним, на пятом уровне.
#
# Главное про него: ОН САМ ПОЧТИ НЕ БЬЁТ. Он достаёт телефон и ЗВОНИТ, а бьют
# те, кого он вызвал. Крокодил стрелял лично и был опасен собой; этот опасен
# тем, что у него есть чей номер, — и весь бой строится вокруг того, кого он
# набирает следующим.
#
# Три акта, и каждый задаёт свой вопрос:
#
#   Акт 1 «ОХРАНА»   — «выбери линию». Полосы вызова заранее загораются на тех
#                      линиях, по которым побегут охранники. Волны ускоряются.
#   Акт 2 «ПОЛИЦИЯ»  — «выбери сторону». Мигалка красит края экрана: синий —
#                      приедут слева, красный — справа. Копы быстрые и идут
#                      залпом, свободной остаётся одна линия.
#   Акт 3 «ТАНЦПОЛ»  — «он идёт сам». Пол заливает девочками — стена с ползущей
#                      дырой, — а поверх этого хозяин надевает кастеты и
#                      начинает ГНАТЬСЯ. Единственный такт, где опасен он сам.
#
#   Финал            — толпа, которую он весь бой вызывал, приходит в последний
#                      раз и сходится НА НЁМ.
#
# Общее правило, как у всех: СНАЧАЛА ТЕЛЕГРАФ, ПОТОМ УДАР. У этого босса
# телеграф ещё и сюжетный — сначала видно, как он звонит, и только потом видно,
# кто приехал.
#
# ── Что взято из старого проекта и что переделано ────────────────────────────
# В Flutter-версии (lib/game/components/item_components/bosses/club_boss/) бой
# был списком из девяти одинаковых тактов:
#
#     охрана, охрана, полиция, охрана, охрана, полиция, девочки, трек, финал
#
#   • Нарастания не было вовсе: первая волна охраны ничем не отличалась от
#     четвёртой, а между ними дважды повторялась полиция. Отсюда три акта с
#     разными вопросами и разгон внутри акта.
#   • Телеграфа не было ни одного: вызванные просто появлялись за правым краем
#     на случайных линиях. Отсюда полосы вызова и мигалка.
#   • Приходили все ТОЛЬКО СПРАВА. Мигалка, красящая края, появилась ровно
#     затем, чтобы у полиции был свой вопрос, а не «то же самое, но быстрее».
#   • «Трек» существовал: 13 секунд, в которые босс ехал на игрока с кастетами.
#     Это лучший такт боя, и он здесь остался почти как был — но теперь поверх
#     девочек, а не в пустоте.
#
# См. /Концепция/Босс — Хозяин клуба.md

signal defeated

# ── Кадры ────────────────────────────────────────────────────────────────────
# Все позы босса нарисованы в общей рамке 500×500 и ужимаются одинаково, поэтому
# на смене позы голова не прыгает.
const F_IDLE : Array = [
	preload("res://assets/bosses/club_boss/idle1.png"),
	preload("res://assets/bosses/club_boss/idle2.png"),
]
const F_TALK : Array = [
	preload("res://assets/bosses/club_boss/talk1.png"),
	preload("res://assets/bosses/club_boss/talk2.png"),
	preload("res://assets/bosses/club_boss/talk3.png"),
	preload("res://assets/bosses/club_boss/talk4.png"),
]
const F_RAGE : Array = [
	preload("res://assets/bosses/club_boss/rage1.png"),
	preload("res://assets/bosses/club_boss/rage2.png"),
	preload("res://assets/bosses/club_boss/rage3.png"),
	preload("res://assets/bosses/club_boss/rage4.png"),
]
const F_CALL_GIRLS := preload("res://assets/bosses/club_boss/call_girls.png")
const F_PHONE      := preload("res://assets/bosses/club_boss/phone.png")
const F_KNUCKLE_L  := preload("res://assets/bosses/club_boss/knuckle_l.png")
const F_KNUCKLE_R  := preload("res://assets/bosses/club_boss/knuckle_r.png")
const F_BANNER     := preload("res://assets/bosses/club_boss/banner.png")
const T_POLICE_CAR := preload("res://assets/bosses/club_boss/police_car.png")

const T_SECURITY := preload("res://assets/bosses/club_boss/security.png")
const T_COP      := preload("res://assets/items/cop.png")
const T_GIRL : Array = [
	preload("res://assets/bosses/club_boss/girl1.png"),
	preload("res://assets/bosses/club_boss/girl2.png"),
]

const MINION_SCRIPT := preload("res://scripts/club_boss_minion.gd")
const FIST_SCRIPT   := preload("res://scripts/club_boss_fist.gd")
const UI_FONT       := preload("res://assets/fonts/RussoOne-Regular.ttf")

const SFX_WHOS_NEXT := preload("res://assets/audio/club_boss/whos_next.mp3")
const SFX_TALK      := preload("res://assets/audio/club_boss/talk.mp3")
const SFX_SECURITY  := preload("res://assets/audio/club_boss/security.mp3")
const SFX_NEED_HELP := preload("res://assets/audio/club_boss/need_help.mp3")
const SFX_TALKING2  := preload("res://assets/audio/club_boss/talking2.mp3")
const SFX_KISS      := preload("res://assets/audio/club_boss/kiss.mp3")
const SFX_BRACERS   := preload("res://assets/audio/club_boss/bracers.mp3")
const SFX_LAUGH     := preload("res://assets/audio/club_boss/laugh.mp3")
const SFX_FINAL     := preload("res://assets/audio/club_boss/final.mp3")
# Клубный бас — не «ещё один боевой трек», а декорация места: этот босс сидит в
# клубе, и стробоскоп третьего акта бьёт под него.
const BOSS_MUSIC   := preload("res://assets/audio/subbwoofer.mp3")
const BOSS_STINGER := preload("res://assets/audio/boss_fight.mp3")

# ── Размеры ──────────────────────────────────────────────────────────────────
# Ширина головы босса на экране. Крокодил в бою — 178 (полторы головы
# Нормальдо); этот хозяин заведения, и он крупнее: две головы.
const W_FIGHT : float = 210.0
const MINION_PX : float = 76.0   # вызванные — чуть крупнее рядового предмета
const LANES : int = 5

var boss_test_mode : bool = false

@export var autostart : bool = true

var _normaldo  : Node2D = null
var _spawner   : Node   = null
var _game_root : Node2D = null
var _sprite    : Sprite2D = null
var _phone     : Sprite2D = null
var _music     : AudioStreamPlayer = null

# Какой акт идёт прямо сейчас. Тест читает это поле, чтобы не гадать по
# таймингам, и по нему же видно, на каком такте бой оборвали.
var current_act : String = ""

var _stopped  : bool = false
var _tracking : bool = false
var _knuckles : Node2D = null
var _fist     : Area2D = null
# Линия, на которой сейчас дыра в стене девочек, или −1, когда стены нет.
# Хозяин в неё не заходит — см. `_keep_off_gap`.
var _gap_lane : int = -1
var _bar_lamps : Array = []
var _bar_layer : CanvasLayer = null
var _anim_t   : float = 0.0
var _anim_set : Array = []

# Живой ли бой. Проверяется ПЕРЕД каждым следующим тактом: такты сшиты через
# `get_tree().create_timer()`, а тот тикает и на паузе — без этой проверки босс
# спокойно доигрывал бы акт поверх экрана смерти.
func _alive() -> bool:
	return is_instance_valid(self) and not _stopped and is_inside_tree()

func setup(normaldo: Node2D, spawner: Node, game_root: Node2D, test_mode: bool = false) -> void:
	_normaldo      = normaldo
	_spawner       = spawner
	_game_root     = game_root
	boss_test_mode = test_mode

func _ready() -> void:
	z_index = 40
	_sprite = Sprite2D.new()
	_sprite.texture        = F_IDLE[0]
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)
	_set_pose(F_IDLE[0], W_FIGHT)
	var vp := get_viewport_rect().size
	position = Vector2(vp.x + W_FIGHT, vp.y * 0.5)

	_music = AudioStreamPlayer.new()
	var ms := BOSS_MUSIC.duplicate() as AudioStreamMP3
	ms.loop          = true
	_music.stream    = ms
	_music.volume_db = -12.0
	add_child(_music)

	if is_instance_valid(_normaldo) and _normaldo.has_signal("died"):
		_normaldo.connect("died", _on_player_died)

	if autostart:
		_run_boss.call_deferred()

func _on_player_died(_pizzas: int = 0, _pos: Vector2 = Vector2.ZERO) -> void:
	_abort()

# Забег окончен — на экране не должно остаться ни босса, ни его вызванных, ни
# декораций. Само оно не уберётся: дерево на паузе, а убирают всё это твины, и
# они замирают вместе с ним — поверх экрана смерти висели бы мигалка,
# стробоскоп и полдюжины охранников.
func _abort() -> void:
	if _stopped:
		return
	_stopped  = true
	_tracking = false
	_gap_lane = -1
	if is_instance_valid(_music):
		_music.stop()
	for grp in ["club_minion", "club_fx"]:
		for n in get_tree().get_nodes_in_group(grp):
			if is_instance_valid(n):
				n.queue_free()
	# Тряска двигает КОРЕНЬ СЦЕНЫ. Замерев на паузе, она оставила бы весь мир
	# сдвинутым набок.
	if is_instance_valid(_game_root):
		_game_root.position = Vector2.ZERO
	_drop_bars()
	for c in tree_exited.get_connections():
		tree_exited.disconnect(c["callable"])
	queue_free()

# ── Позы ─────────────────────────────────────────────────────────────────────

func _set_pose(tex: Texture2D, width: float = -1.0) -> void:
	if not is_instance_valid(_sprite) or tex == null:
		return
	_sprite.texture = tex
	var w : float = width if width > 0.0 else float(_sprite.get_meta("w", W_FIGHT))
	_sprite.set_meta("w", w)
	_sprite.scale = Vector2.ONE * (w / maxf(1.0, tex.get_size().x))

# Перелистывание набора кадров. Босс «говорит» ровно тогда, когда звонит, и
# молчит, когда стоит: анимация тут не украшение, а признак того, что вызов идёт
# ПРЯМО СЕЙЧАС.
func _animate(frames: Array, fps: float = 6.0) -> void:
	_anim_set = frames
	_anim_t   = 0.0
	_anim_fps = fps
	if not frames.is_empty():
		_set_pose(frames[0])

var _anim_fps : float = 6.0

func _stop_anim(rest: Texture2D = null) -> void:
	_anim_set = []
	if rest != null:
		_set_pose(rest)

func _process(delta: float) -> void:
	if not _anim_set.is_empty():
		_anim_t += delta * _anim_fps
		_set_pose(_anim_set[int(_anim_t) % _anim_set.size()])
	if _tracking and is_instance_valid(_normaldo):
		_track_step(delta)

# ── Главная последовательность ───────────────────────────────────────────────

func _run_boss() -> void:
	var vp := get_viewport_rect().size
	position = Vector2(vp.x + W_FIGHT, vp.y * 0.5)

	if is_instance_valid(_spawner):
		_spawner.set_process(false)
		if _spawner.has_method("clear_items"):
			_spawner.clear_items()
	var bg := _game_root.get_node_or_null("Background")
	if bg and bg.has_method("stop_scrolling"):
		bg.stop_scrolling()
	var game_music := _game_root.get_node_or_null("Music")
	if game_music and game_music.has_method("fade_out"):
		game_music.fade_out()
	_music.play()

	await _intro()
	if not _alive():
		return
	_build_bars()

	await _act_security()
	if not _alive(): return
	_burn_bar(0)
	await _act_police()
	if not _alive(): return
	_burn_bar(1)
	await _act_floor()
	if not _alive(): return
	_burn_bar(2)
	await _finale()
	if not _alive(): return

	current_act = "done"
	_music.stop()
	_drop_bars()
	if boss_test_mode:
		# Дев-вызов: возвращаем забег в рабочее состояние — заморозку снял бы
		# только конец кампании, а его тут нет.
		if is_instance_valid(game_music) and game_music.has_method("start"):
			game_music.start()
		if is_instance_valid(_spawner):
			_spawner.set("_frozen", false)
			_spawner.set("_pattern_running", false)
			_spawner.set_process(true)
		if is_instance_valid(bg) and bg.has_method("start_scrolling"):
			bg.start_scrolling()
		if is_instance_valid(_normaldo) and _normaldo.has_method("enable_input"):
			_normaldo.enable_input()
		queue_free()
		return
	defeated.emit()
	queue_free()

# ── Интро ────────────────────────────────────────────────────────────────────

func _intro() -> void:
	current_act = "intro"
	var vp := get_viewport_rect().size
	var tw_in := create_tween()
	tw_in.tween_property(self, "position:x", vp.x - W_FIGHT * 0.55, 0.85)\
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	await tw_in.finished
	if not _alive():
		return
	_play_sfx(SFX_WHOS_NEXT)
	_screen_shake(12.0, 9)
	_animate(F_TALK, 7.0)

	var shake := create_tween()
	for _i in 3:
		shake.tween_property(_sprite, "rotation",  0.07, 0.08)
		shake.tween_property(_sprite, "rotation", -0.07, 0.08)
	shake.tween_property(_sprite, "rotation", 0.0, 0.08)
	await get_tree().create_timer(0.55).timeout
	if not _alive():
		return
	_stop_anim(F_IDLE[0])

	await _show_speech()
	if not _alive():
		return
	var tw_vol := create_tween()
	tw_vol.tween_property(_music, "volume_db", -3.0, 2.4)
	await _show_banner()
	if not _alive():
		return
	if is_instance_valid(_normaldo) and _normaldo.has_method("enable_input"):
		_normaldo.enable_input()

# Реплика босса. У крокодила она про меткость, у этого — про то, что он никого
# не бьёт сам: он тут хозяин, и у него для этого есть люди.
const SPEECH : String = "Ты не в списке.\nСейчас подойдут мои люди."

func _show_speech() -> void:
	if is_instance_valid(_normaldo) and _normaldo.has_method("disable_input"):
		_normaldo.disable_input()
	var vp := get_viewport_rect().size
	var cl := CanvasLayer.new()
	cl.layer = 95
	cl.add_to_group("club_fx")
	_game_root.add_child(cl)

	var w : float = 330.0
	var h : float = 84.0
	var root := Control.new()
	root.size         = Vector2(w, h)
	root.position     = Vector2(vp.x - W_FIGHT - w - 10.0, vp.y * 0.30)
	root.pivot_offset = Vector2(w, h * 0.5)
	root.scale        = Vector2(0.2, 0.2)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(root)
	UiKit.panel(root, Vector2.ZERO, Vector2(w, h), Color(0.10, 0.05, 0.13, 0.96),
		12, Color(0.85, 0.35, 0.95, 0.95), 3)
	var lbl := Label.new()
	lbl.add_theme_font_override("font", UI_FONT)
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.text                 = SPEECH
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl.modulate             = Color(1.0, 0.88, 1.0)
	lbl.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	UiKit.place(root, lbl, Vector2(10.0, 0.0), Vector2(w - 20.0, h))

	var tw := root.create_tween()
	tw.tween_property(root, "scale", Vector2.ONE, 0.26)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(2.6).timeout
	if is_instance_valid(cl):
		var out := root.create_tween()
		out.tween_property(root, "modulate:a", 0.0, 0.22)
		out.tween_callback(cl.queue_free)

func _show_banner() -> void:
	var vp := get_viewport_rect().size
	var cl := CanvasLayer.new()
	cl.layer = 99
	cl.add_to_group("club_fx")
	_game_root.add_child(cl)
	var dim := ColorRect.new()
	dim.color = Color(0.06, 0.02, 0.08, 0.0)
	dim.size  = vp
	cl.add_child(dim)

	# Титр НАРИСОВАННЫЙ, как у крокодила: «BOSS FIGHT» с мордой хозяина вместо
	# буквы O. Это тот же лист из старого проекта (`BOSSFIGHT FA.png`) и та же
	# рамка, что у крокодила, — у боссов один титр на всех, и меняется в нём
	# только лицо. Набранное шрифтом имя, которое стояло тут раньше, выпадало из
	# этого ряда: у одного босса рисунок, у другого надпись.
	var pic := TextureRect.new()
	pic.texture        = F_BANNER
	pic.expand_mode    = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode   = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var bw : float = vp.x * 0.56
	var bh : float = bw * float(F_BANNER.get_height()) / float(F_BANNER.get_width())
	pic.size         = Vector2(bw, bh)
	pic.position     = Vector2((vp.x - bw) * 0.5, vp.y * 0.22)
	pic.pivot_offset = pic.size * 0.5
	pic.scale        = Vector2.ZERO
	cl.add_child(pic)

	var sub := Label.new()
	sub.add_theme_font_override("font", UI_FONT)
	sub.add_theme_font_size_override("font_size", 22)
	sub.text                 = "ХОЗЯИН КЛУБА"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.modulate             = Color(1.0, 0.55, 1.0, 0.0)
	sub.size                 = Vector2(vp.x, 32.0)
	sub.position             = Vector2(0.0, vp.y * 0.22 + bh + 6.0)
	cl.add_child(sub)

	var tw_d := dim.create_tween()
	tw_d.tween_property(dim, "color:a", 0.66, 0.26)
	await tw_d.finished
	_play_sfx(BOSS_STINGER)
	var tw_p := pic.create_tween()
	tw_p.tween_property(pic, "scale", Vector2.ONE, 0.30)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw_p.parallel().tween_property(sub, "modulate:a", 1.0, 0.30)
	await tw_p.finished
	await get_tree().create_timer(1.0).timeout
	if is_instance_valid(cl):
		var out := dim.create_tween()
		out.tween_property(dim, "color:a", 0.0, 0.30)
		out.parallel().tween_property(pic, "modulate:a", 0.0, 0.30)
		out.parallel().tween_property(sub, "modulate:a", 0.0, 0.30)
		out.tween_callback(cl.queue_free)
		await out.finished

# ── Телефон ──────────────────────────────────────────────────────────────────
# Достаёт телефон и говорит. Это ТЕЛЕГРАФ ВСЕГО АКТА: пока он не позвонил, никто
# не придёт, и по одному этому кадру игрок понимает, что сейчас начнётся.
#
# Из телефона расходятся КОЛЬЦА ВЫЗОВА — просто затухающие окружности. Звук
# звонка на маленьком экране легко пропустить, а расходящееся кольцо видно
# боковым зрением, даже когда смотришь на свою линию.

const PHONE_PX : float = 54.0

func _phone_up() -> void:
	if is_instance_valid(_phone):
		return
	_phone = Sprite2D.new()
	_phone.texture        = F_PHONE
	_phone.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ItemSizing.fit_sprite_content(_phone, PHONE_PX)
	_phone.position = Vector2(-W_FIGHT * 0.34, W_FIGHT * 0.06)
	_phone.z_index  = 2
	_phone.scale   *= 0.1
	add_child(_phone)
	var tw := _phone.create_tween()
	tw.tween_property(_phone, "scale", _phone.scale * 10.0, 0.14)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _phone_down() -> void:
	if not is_instance_valid(_phone):
		return
	var p := _phone
	_phone = null
	var tw := p.create_tween()
	tw.tween_property(p, "scale", p.scale * 0.1, 0.12)
	tw.tween_callback(p.queue_free)

# Кольцо вызова: окружность, разбегающаяся от телефона.
func _ring(col: Color) -> void:
	if not is_instance_valid(_game_root) or not is_instance_valid(_phone):
		return
	var r := Node2D.new()
	r.set_script(RING_SCRIPT)
	r.add_to_group("club_fx")
	r.position = _phone.global_position
	r.set("color", col)
	_game_root.add_child(r)

const RING_SCRIPT := preload("res://scripts/club_boss_ring.gd")

# Звонок: телефон вверх, кадры разговора, три кольца — и вызванные.
func _make_call(sfx: AudioStream, col: Color) -> void:
	_phone_up()
	_animate(F_TALK, 8.0)
	_play_sfx(sfx)
	for i in 3:
		_ring(col)
		await get_tree().create_timer(0.16).timeout
		if not _alive():
			return

# ── Полоса вызова ────────────────────────────────────────────────────────────
# Линия, по которой сейчас побегут вызванные, ЗАГОРАЕТСЯ ЗАРАНЕЕ — узкой лентой
# во всю ширину экрана, с бегущим по ней бликом. Это тот же приём, что нить
# прицела у крокодила: сначала показать, куда прилетит, потом прилететь.
#
# Цвет ленты — цвет того, кого вызвали: зелёный охрана, синий/красный полиция,
# розовый девочки. Игрок за бой успевает выучить, что за кем идёт.

const LANE_TELE_T : float = 0.55   # сколько лента висит до появления вызванных

func _call_lane(lane: int, col: Color, dur: float = LANE_TELE_T) -> void:
	if not is_instance_valid(_game_root):
		return
	var vp := get_viewport_rect().size
	var h  : float = vp.y / float(LANES)
	var y  : float = h * (float(lane) + 0.5)
	var strip := ColorRect.new()
	strip.color    = Color(col.r, col.g, col.b, 0.0)
	strip.size     = Vector2(vp.x, h * 0.86)
	strip.position = Vector2(0.0, y - h * 0.43)
	strip.z_index  = 1
	strip.add_to_group("club_fx")
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_game_root.add_child(strip)
	var tw := strip.create_tween()
	tw.tween_property(strip, "color:a", 0.30, dur * 0.35)
	tw.tween_property(strip, "color:a", 0.10, dur * 0.30)
	tw.tween_property(strip, "color:a", 0.0,  dur * 0.35)
	tw.tween_callback(strip.queue_free)

func _lane_y(lane: int) -> float:
	var vp := get_viewport_rect().size
	return vp.y / float(LANES) * (float(lane) + 0.5)

# Вызванный выходит из-за края и идёт по своей линии. Сторона задаётся знаком
# направления: −1 справа налево, +1 слева направо.
func _send(tex: Texture2D, lane: int, dir_x: float, spd: float, px: float = MINION_PX) -> void:
	if not is_instance_valid(_game_root):
		return
	var vp := get_viewport_rect().size
	var m := Area2D.new()
	m.set_script(MINION_SCRIPT)
	m.call("init", tex, px, Vector2(dir_x, 0.0), spd)
	m.position = Vector2(vp.x + 90.0 if dir_x < 0.0 else -90.0, _lane_y(lane))
	_game_root.add_child(m)

# ── Акт 1: ОХРАНА ────────────────────────────────────────────────────────────
# «Выбери линию». Хозяин звонит, загораются полосы, и по ним бегут охранники.
#
# Акт РАЗГОНЯЕТСЯ и по паузе, и по числу занятых линий: 2 → 3 → 3 → 4 из пяти.
# Раньше (в старом проекте) все волны были одинаковыми, по пять охранников на
# случайные линии, и после первой волны игрок знал про акт всё. Разгон паузы
# отбирает время на раздумье, разгон числа линий — место, куда уходить; вместе
# это ощущается как «их становится больше», а не «стало быстрее».
#
# Ускоряется ПАУЗА МЕЖДУ волнами, а не телеграф: лента по-прежнему висит свои
# 0.55 с, и последняя волна так же честна, как первая.
const SEC_WAVES : Array = [2, 2, 3, 3, 4, 4]   # сколько линий занимает волна
const SEC_WAITS : Array = [1.50, 1.30, 1.10, 0.95, 0.82, 0.70]
const SEC_SPEED : float = 300.0
const COL_SEC : Color = Color(0.40, 1.00, 0.45)

func _act_security() -> void:
	current_act = "security"
	await _make_call(SFX_SECURITY, COL_SEC)
	if not _alive():
		return
	for w in SEC_WAVES.size():
		var lanes : Array = _pick_lanes(int(SEC_WAVES[w]))
		for l in lanes:
			_call_lane(int(l), COL_SEC)
		await get_tree().create_timer(LANE_TELE_T).timeout
		if not _alive():
			return
		_screen_shake(4.0, 3)
		for l in lanes:
			_send(T_SECURITY, int(l), -1.0, SEC_SPEED)
		await get_tree().create_timer(float(SEC_WAITS[w])).timeout
		if not _alive():
			return
	_phone_down()
	_stop_anim(F_IDLE[0])
	await get_tree().create_timer(1.1).timeout

# Сколько-то РАЗНЫХ линий из пяти. Дубли недопустимы: две ленты на одной линии
# читаются как одна, и волна выходит меньше обещанного.
func _pick_lanes(count: int) -> Array:
	var all : Array = []
	for i in LANES:
		all.append(i)
	all.shuffle()
	return all.slice(0, clampi(count, 1, LANES))

# ── Акт 2: ПОЛИЦИЯ ───────────────────────────────────────────────────────────
# «Выбери сторону». Копы быстрые и идут залпом на четыре линии из пяти —
# уворачиваться от каждого некогда, надо заранее встать на свободную.
#
# Свободную показывает МИГАЛКА. Края экрана заливает синим или красным, и цвет —
# это не декорация, а сама подсказка: синий значит «приедут слева», красный —
# «справа». Дальше загорается лента свободной линии, и на неё нужно успеть.
#
# Приход С ДВУХ СТОРОН — то, чего в старом проекте не было вовсе: там все
# вызванные появлялись за правым краем, и полиция отличалась от охраны только
# скоростью, то есть ничем.
# Шесть залпов, и сторона у каждого СВОЯ СЛУЧАЙНАЯ. Чередование через один
# читалось как считалка: после второго залпа сторону третьего можно было не
# смотреть, а просто знать, — и мигалка, ради которой акт и делался, переставала
# что-либо значить. Случайная сторона возвращает ей работу: смотреть придётся
# каждый раз.
const POL_VOLLEYS : int   = 6
const POL_SPEED   : float = 430.0
const POL_GAP     : float = 1.45   # между залпами
const COL_BLUE : Color = Color(0.30, 0.55, 1.00)
const COL_RED  : Color = Color(1.00, 0.25, 0.25)

func _act_police() -> void:
	current_act = "police"
	await _make_call(SFX_NEED_HELP, COL_RED)
	if not _alive():
		return
	_animate(F_RAGE, 9.0)
	for v in POL_VOLLEYS:
		var from_left : bool = randf() < 0.5
		var col : Color = COL_BLUE if from_left else COL_RED
		_siren(col, from_left)
		var free_lane : int = randi() % LANES
		_call_lane(free_lane, Color(0.95, 0.95, 0.35), LANE_TELE_T + 0.25)
		await get_tree().create_timer(LANE_TELE_T + 0.25).timeout
		if not _alive():
			return
		_screen_flash(col)
		_screen_shake(7.0, 5)
		for l in LANES:
			if l == free_lane:
				continue
			_send(T_COP, l, 1.0 if from_left else -1.0, POL_SPEED)
		await get_tree().create_timer(POL_GAP).timeout
		if not _alive():
			return
	_phone_down()
	_stop_anim(F_IDLE[0])
	await get_tree().create_timer(1.0).timeout

# Мигалка. Две шторки по краям, и та, из-под которой приедут, горит ярче и
# дольше — иначе цвет пришлось бы просто выучить, а так сторону видно и не зная
# правила.
func _siren(col: Color, from_left: bool) -> void:
	if not is_instance_valid(_game_root):
		return
	var vp := get_viewport_rect().size
	var cl := CanvasLayer.new()
	cl.layer = 8
	cl.add_to_group("club_fx")
	_game_root.add_child(cl)
	for side in 2:
		var near : bool = (side == 0) == from_left
		var g := ColorRect.new()
		var w : float = vp.x * (0.22 if near else 0.13)
		g.color    = Color(col.r, col.g, col.b, 0.0)
		g.size     = Vector2(w, vp.y)
		g.position = Vector2(0.0 if side == 0 else vp.x - w, 0.0)
		cl.add_child(g)
		# Разница между сторонами ЧЕТЫРЁХКРАТНАЯ — сторона видна и не зная
		# правила. Ярче делать нельзя: за плотной шторкой пропадал сам босс, а
		# помеха в бою должна мешать смотреть, а не отменять зрение.
		var peak : float = 0.34 if near else 0.08
		var tw := g.create_tween()
		tw.set_loops(3)
		tw.tween_property(g, "color:a", peak, 0.18)
		tw.tween_property(g, "color:a", 0.0,  0.18)
	await get_tree().create_timer(1.15).timeout
	if is_instance_valid(cl):
		cl.queue_free()

# ── Акт 3: ТАНЦПОЛ ───────────────────────────────────────────────────────────
# «Он идёт сам». Единственный такт боя, где опасен сам хозяин.
#
# Сначала он зовёт девочек, и пол заливает стеной: пять линий минус ОДНА ДЫРА, и
# дыра ползёт от волны к волне. Идут они медленно — стена не про реакцию, а про
# то, чтобы всё время двигаться в нужную сторону.
#
# А поверх этого он надевает кастеты и НАЧИНАЕТ ГНАТЬСЯ. В старом проекте «трек»
# шёл в пустоте и был лучшим тактом боя; здесь он идёт поверх стены, и место,
# куда уходить от кулаков, каждый раз занято девочками.
#
# Стробоскоп бьёт под клубный бас — это и декорация места, и честная помеха:
# вспышки короткие и не гасят силуэты, но заставляют смотреть, а не считать.
const GIRL_WAVES  : int   = 3
const GIRL_SPEED  : float = 165.0
# Пауза между стенами держит между ними КОРИДОР шире двух голов: стена, идущая
# сплошняком, перестаёт быть стеной с дырой и становится просто смертью.
const GIRL_GAP    : float = 1.55
const TRACK_T     : float = 9.0
const TRACK_SPEED : float = 96.0
const COL_PINK : Color = Color(1.00, 0.40, 0.85)

func _act_floor() -> void:
	current_act = "floor"
	await _make_call(SFX_TALKING2, COL_PINK)
	if not _alive():
		return
	_phone_down()
	_stop_anim(F_CALL_GIRLS)
	_play_sfx(SFX_KISS)
	_strobe(TRACK_T + GIRL_WAVES * GIRL_GAP + 1.0)

	# Дыра ползёт: игрок обязан ДВИГАТЬСЯ, а не занять одну линию и стоять.
	var gap : int = randi() % LANES
	_gap_lane = gap
	var step : int = 1 if randf() < 0.5 else -1
	for w in GIRL_WAVES:
		for l in LANES:
			if l != gap:
				_call_lane(l, COL_PINK, LANE_TELE_T)
		await get_tree().create_timer(LANE_TELE_T).timeout
		if not _alive():
			return
		for l in LANES:
			if l == gap:
				continue
			_send(T_GIRL[randi() % T_GIRL.size()], l, -1.0, GIRL_SPEED, MINION_PX + 8.0)
		# Дыра уходит на соседнюю линию и отражается от краёв — так она всегда
		# рядом с прежней, и уйти к ней успевают.
		if gap + step < 0 or gap + step >= LANES:
			step = -step
		gap += step
		_gap_lane = gap
		# Выталкиваем ЕГО СРАЗУ, а не со следующим кадром погони: дыра переехала
		# на соседнюю линию, и один кадр он стоял бы ровно в ней.
		if _tracking:
			position.y = _keep_off_gap(position.y)
		# Со второй волны он уже гонится — ждать конца стены незачем.
		if w == 1:
			_start_track()
		await get_tree().create_timer(GIRL_GAP).timeout
		if not _alive():
			return

	# Стена кончилась — запрет на линию дыры снимается, и последние секунды
	# погони хозяин ходит где угодно.
	_gap_lane = -1
	await get_tree().create_timer(TRACK_T).timeout
	if not _alive():
		return
	_stop_track()
	await get_tree().create_timer(0.8).timeout

# Погоня. Он ЕДЕТ на голову, а не телепортируется: скорость заметно ниже
# рывка Нормальдо, и уйти можно всегда — вопрос в том, есть ли куда.
func _start_track() -> void:
	if _tracking:
		return
	_play_sfx(SFX_BRACERS)
	_knuckles_up()
	_animate(F_RAGE, 10.0)
	# Ударная зона появляется ВМЕСТЕ с кастетами и уходит вместе с ними: два
	# первых акта хозяин звонит, а не дерётся, и постоянный хитбокс у правого
	# края был бы просто стеной, в которую нельзя войти.
	_fist = Area2D.new()
	_fist.set_script(FIST_SCRIPT)
	_fist.call("setup", W_FIGHT * 0.30)
	_fist.connect("punched", _on_punched)
	add_child(_fist)
	_tracking = true

# Достал — отскакивает назад. Без отскока зона просто ехала бы дальше вместе с
# ним и на откате читалась как «он промахнулся», а не «он попал».
func _on_punched() -> void:
	_screen_shake(9.0, 6)
	if not is_instance_valid(_normaldo):
		return
	var away : Vector2 = (position - _normaldo.global_position).normalized()
	var tw := create_tween()
	tw.tween_property(self, "position", position + away * PUNCH_RECOIL, 0.18)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

const PUNCH_RECOIL : float = 130.0

func _stop_track() -> void:
	if not _tracking:
		return
	_tracking = false
	if is_instance_valid(_fist):
		_fist.queue_free()
	_fist = null
	_knuckles_down()
	_stop_anim(F_IDLE[0])
	var vp := get_viewport_rect().size
	var tw := create_tween()
	tw.tween_property(self, "position",
		Vector2(vp.x - W_FIGHT * 0.55, vp.y * 0.5), 0.7)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _track_step(delta: float) -> void:
	var vp := get_viewport_rect().size
	var target : Vector2 = _normaldo.global_position
	var d : Vector2 = target - position
	if d.length() > 1.0:
		position += d.normalized() * TRACK_SPEED * delta
	position.x = clampf(position.x, W_FIGHT * 0.4, vp.x - W_FIGHT * 0.2)
	position.y = clampf(position.y, vp.y * 0.12, vp.y * 0.88)
	position.y = _keep_off_gap(position.y)
	# Смотрит туда, куда идёт. Нарисован он лицом влево.
	if is_instance_valid(_sprite):
		_sprite.flip_h = d.x > 0.0

# ── Коридор неприкосновенен ──────────────────────────────────────────────────
# Пока стоит стена девочек, у неё есть ровно ОДНА дыра, и это единственный
# честный путь. Хозяин, гонящийся за головой, вставал ровно в эту дыру: игрок
# шёл к проходу, а проход был уже занят, и пройти было физически нельзя.
#
# Поэтому на время стены линия дыры для него ЗАКРЫТА — он ходит рядом с ней, но
# не внутрь. Кончилась стена (`_gap_lane = -1`) — запрет снимается, и последние
# секунды погони он ходит где угодно.
const GAP_KEEP : float = 0.62   # в долях высоты линии

func _keep_off_gap(y: float) -> float:
	if _gap_lane < 0:
		return y
	var vp := get_viewport_rect().size
	var h  : float = vp.y / float(LANES)
	var gy : float = h * (float(_gap_lane) + 0.5)
	var keep : float = h * GAP_KEEP
	if absf(y - gy) >= keep:
		return y
	# Выталкиваем в ближнюю сторону, но не за экран: у крайних линий дыры
	# отходить некуда вверх или вниз, и там он встаёт по другую её сторону.
	var up   : float = gy - keep
	var down : float = gy + keep
	if up < vp.y * 0.12:
		return down
	if down > vp.y * 0.88:
		return up
	return up if y < gy else down

# Кастеты. Появляются рывком масштаба — «надел», а не «были всегда», — и всё
# время погони качаются: неподвижные кулаки читались бы как часть картинки.
func _knuckles_up() -> void:
	if is_instance_valid(_knuckles):
		return
	_knuckles = Node2D.new()
	add_child(_knuckles)
	for i in 2:
		var k := Sprite2D.new()
		k.texture        = F_KNUCKLE_L if i == 0 else F_KNUCKLE_R
		k.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ItemSizing.fit_sprite_content(k, W_FIGHT * 0.30)
		k.position = Vector2(W_FIGHT * (-0.42 if i == 0 else 0.42), W_FIGHT * 0.22)
		k.z_index  = 2
		k.scale   *= 0.1
		_knuckles.add_child(k)
		var tw := k.create_tween()
		tw.tween_interval(0.06 * float(i))
		tw.tween_property(k, "scale", k.scale * 10.0, 0.16)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		var sw := k.create_tween()
		sw.set_loops()
		sw.tween_property(k, "rotation",  0.35 * (1.0 if i == 0 else -1.0), 0.28)\
			.set_trans(Tween.TRANS_SINE)
		sw.tween_property(k, "rotation", -0.35 * (1.0 if i == 0 else -1.0), 0.28)\
			.set_trans(Tween.TRANS_SINE)

func _knuckles_down() -> void:
	if not is_instance_valid(_knuckles):
		return
	var k := _knuckles
	_knuckles = null
	var tw := k.create_tween()
	tw.tween_property(k, "scale", Vector2(0.1, 0.1), 0.14)
	tw.tween_callback(k.queue_free)

# Стробоскоп: короткие вспышки поверх сцены под клубный бас. Держится он ровно
# столько, сколько идёт танцпол, и снимается сам.
func _strobe(dur: float) -> void:
	if not is_instance_valid(_game_root):
		return
	var vp := get_viewport_rect().size
	var cl := CanvasLayer.new()
	cl.layer = 9
	cl.add_to_group("club_fx")
	_game_root.add_child(cl)
	var r := ColorRect.new()
	r.color = Color(1.0, 0.6, 1.0, 0.0)
	r.size  = vp
	cl.add_child(r)
	var tw := r.create_tween()
	tw.set_loops(int(dur / 0.5) + 1)
	# Вспышка КОРОТКАЯ и слабая: длинная белая заливка съедала бы силуэты, а
	# помеха в бою должна мешать смотреть, а не отменять зрение.
	tw.tween_property(r, "color:a", 0.16, 0.05)
	tw.tween_property(r, "color:a", 0.0,  0.10)
	tw.tween_interval(0.35)
	await get_tree().create_timer(dur).timeout
	if is_instance_valid(cl):
		cl.queue_free()

# ── Финал ────────────────────────────────────────────────────────────────────
# Толпа, которую он весь бой вызывал, приходит в последний раз — и сходится НА
# НЁМ. Бить его тапами не просят: весь бой был про то, что дерётся не он, и
# добивание кулаком было бы про другого босса.
func _finale() -> void:
	current_act = "finale"
	var vp := get_viewport_rect().size
	_stop_anim(F_IDLE[0])
	if is_instance_valid(_normaldo) and _normaldo.has_method("disable_input"):
		_normaldo.disable_input()
	if is_instance_valid(_sprite):
		_sprite.flip_h = false

	# Выходит в центр — сам, спокойно, как хозяин.
	var mid := Vector2(vp.x * 0.58, vp.y * 0.52)
	var tw := create_tween()
	tw.tween_property(self, "position", mid, 0.6)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tw.finished
	if not _alive():
		return
	_phone_up()
	_animate(F_TALK, 8.0)
	_play_sfx(SFX_FINAL)
	for i in 3:
		_ring(COL_PINK)
		await get_tree().create_timer(0.14).timeout
		if not _alive():
			return
	_phone_down()
	_stop_anim(F_IDLE[0])

	# ── Его УВОЗЯТ ───────────────────────────────────────────────────────────
	# Раньше тут была толпа, слетающаяся к боссу со всех сторон. На экране это
	# читалось как «все спрятались за него», а не как конец: приехавшие просто
	# исчезали за его спиной, и было непонятно, чем всё кончилось.
	#
	# Теперь конец рассказан движением, и рассказывает он ровно то, что нужно:
	# его УВОДЯТ. К нему с двух сторон подходят девочки, подъезжает полицейская
	# машина, все садятся в неё, и машина уезжает за экран. Хозяин не побеждён
	# ударом — он снят с точки, и заведение осталось без хозяина.
	var girls : Array = []
	for i in 2:
		var g := _walk_in(T_GIRL[i % T_GIRL.size()], i == 0,
			mid + Vector2(-118.0 if i == 0 else 118.0, 26.0), MINION_PX + 6.0)
		girls.append(g)
	_play_sfx(SFX_KISS)
	await get_tree().create_timer(0.75).timeout
	if not _alive():
		return

	# Машина въезжает СПРАВА и тормозит рядом — с мигалкой, чтобы её ни с чем не
	# спутали: этот же синий с красным мигал весь второй акт.
	var car := Sprite2D.new()
	car.texture        = T_POLICE_CAR
	car.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ItemSizing.fit_sprite_content(car, CAR_PX)
	car.position = Vector2(vp.x + CAR_PX, mid.y + 34.0)
	car.z_index  = 41
	car.add_to_group("club_fx")
	_game_root.add_child(car)
	# Встаёт РЯДОМ, а не поверх: машина шире босса, и остановленная вплотную она
	# просто накрывала его собой — вместо «за ним приехали» получалось «он
	# исчез».
	var car_stop := Vector2(mid.x + W_FIGHT * 0.5 + CAR_PX * 0.42, mid.y + 34.0)
	var tw_car := car.create_tween()
	tw_car.tween_property(car, "position", car_stop, 0.75)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_siren(COL_BLUE, false)
	await tw_car.finished
	if not _alive():
		return
	_screen_shake(6.0, 4)
	# Поворачивается к машине: садиться, глядя в другую сторону, — не садиться.
	if is_instance_valid(_sprite):
		_sprite.flip_h = true
	await get_tree().create_timer(0.3).timeout
	if not _alive():
		return

	# Садятся: все трое сходятся к машине и «ныряют» в неё — уменьшаясь и гаснув.
	_play_sfx(SFX_LAUGH)
	for gv in girls:
		var g : Sprite2D = gv
		if not is_instance_valid(g):
			continue
		var tg : Tween = g.create_tween()
		tg.tween_property(g, "position", car_stop, 0.34)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tg.parallel().tween_property(g, "scale", g.scale * 0.25, 0.34)
		tg.parallel().tween_property(g, "modulate:a", 0.0, 0.34)
		tg.tween_callback(g.queue_free)
	var tb := create_tween()
	tb.tween_property(self, "position", car_stop, 0.40)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tb.parallel().tween_property(_sprite, "scale", _sprite.scale * 0.25, 0.40)
	tb.parallel().tween_property(self, "modulate:a", 0.0, 0.40)
	await tb.finished
	if not _alive():
		return

	# И машина уезжает — быстро и ЗА ЛЕВЫЙ край, туда же, куда весь забег уходит
	# всё остальное.
	var tw_out := car.create_tween()
	tw_out.tween_property(car, "position:x", -CAR_PX * 1.5, 0.85)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw_out.tween_callback(car.queue_free)
	await tw_out.finished
	if not _alive():
		return
	if is_instance_valid(_normaldo) and _normaldo.has_method("enable_input"):
		_normaldo.enable_input()
	await get_tree().create_timer(0.3).timeout

const CAR_PX : float = 300.0

# Подходит из-за края и ВСТАЁТ рядом. Не «прилетает», как вызванные в бою:
# бой кончился, и то же самое движение на той же скорости читалось бы как ещё
# одна атака.
func _walk_in(tex: Texture2D, from_left: bool, to: Vector2, px: float) -> Sprite2D:
	if not is_instance_valid(_game_root):
		return null
	var vp := get_viewport_rect().size
	var s := Sprite2D.new()
	s.texture        = tex
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.flip_h         = from_left
	ItemSizing.fit_sprite_content(s, px)
	s.position = Vector2(-80.0 if from_left else vp.x + 80.0, to.y)
	s.z_index  = 41
	s.add_to_group("club_fx")
	_game_root.add_child(s)
	var tw := s.create_tween()
	tw.tween_property(s, "position", to, 0.7)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	return s

# ── Индикатор актов ──────────────────────────────────────────────────────────
# Три полоски сигнала на телефоне: сколько ещё звонков в нём осталось. У
# крокодила на этом месте патроны — там считали выстрелы; здесь считают ЗВОНКИ,
# потому что вся битва про них.
const BAR_W : float = 12.0
const BAR_H : float = 30.0

func _build_bars() -> void:
	var vp := get_viewport_rect().size
	_bar_layer = CanvasLayer.new()
	_bar_layer.layer = 60
	_bar_layer.add_to_group("club_fx")
	_game_root.add_child(_bar_layer)
	var total : float = 3.0 * BAR_W + 2.0 * 8.0
	for i in 3:
		var root := Control.new()
		root.size         = Vector2(BAR_W, BAR_H)
		root.position     = Vector2((vp.x - total) * 0.5 + i * (BAR_W + 8.0), 8.0)
		root.pivot_offset = root.size * 0.5
		root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_bar_layer.add_child(root)
		# Полоски РАЗНОЙ высоты, как деления сигнала: три одинаковых столбика
		# читались бы как патроны, а это не патроны.
		var h : float = BAR_H * (0.45 + 0.275 * float(i))
		var body := ColorRect.new()
		body.color    = Color(0.95, 0.45, 1.00)
		body.size     = Vector2(BAR_W, h)
		body.position = Vector2(0.0, BAR_H - h)
		root.add_child(body)
		_bar_lamps.append(root)

func _burn_bar(i: int) -> void:
	if i < 0 or i >= _bar_lamps.size():
		return
	var s : Control = _bar_lamps[i]
	if not is_instance_valid(s):
		return
	var tw := s.create_tween()
	tw.tween_property(s, "scale", Vector2(1.35, 1.35), 0.10)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(s, "modulate", Color(0.30, 0.30, 0.34, 0.55), 0.22)
	tw.parallel().tween_property(s, "scale", Vector2(0.85, 0.85), 0.22)

func _drop_bars() -> void:
	if is_instance_valid(_bar_layer):
		_bar_layer.queue_free()
	_bar_layer = null
	_bar_lamps.clear()

# ── Общее ────────────────────────────────────────────────────────────────────

func _play_sfx(stream: AudioStream) -> void:
	if not is_instance_valid(_game_root):
		return
	var p := AudioStreamPlayer.new()
	p.stream = stream
	_game_root.add_child(p)
	p.play()
	p.finished.connect(p.queue_free)

func _screen_shake(amp: float, count: int) -> void:
	if not is_instance_valid(_game_root):
		return
	var tw := _game_root.create_tween()
	var a := amp
	for _i in count:
		tw.tween_property(_game_root, "position",
			Vector2(randf_range(-a, a), randf_range(-a * 0.65, a * 0.65)), 0.033)
		a *= 0.80
	tw.tween_property(_game_root, "position", Vector2.ZERO, 0.05)

func _screen_flash(col: Color) -> void:
	if not is_instance_valid(_game_root):
		return
	var cl := CanvasLayer.new()
	cl.layer = 97
	cl.add_to_group("club_fx")
	_game_root.add_child(cl)
	var r := ColorRect.new()
	r.color = Color(col.r, col.g, col.b, 0.0)
	r.size  = get_viewport_rect().size
	cl.add_child(r)
	var tw := r.create_tween()
	tw.tween_property(r, "color:a", 0.40, 0.08)
	tw.tween_property(r, "color:a", 0.0, 0.30)
	tw.tween_callback(cl.queue_free)
