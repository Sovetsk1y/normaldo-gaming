extends Node2D

# ── Босс: КРОКОДИЛ (Leatherhead) ─────────────────────────────────────────────
# Крокодил в красной бандане с дробовиком. Второй босс игры после Ноги Ниндзя.
#
# Битва идёт ТРЕМЯ АКТАМИ, и каждый задаёт игроку свой вопрос:
#
#   Акт 1 «ОХОТА»   — «успей сойти с линии». Крокодил ведёт стволом за головой
#                      и бьёт одиночными. Перед каждым выстрелом от ствола до
#                      цели протягивается НИТЬ ПРИЦЕЛА, и она фиксирует
#                      направление: пуля уйдёт туда, куда показали, а не туда,
#                      где голова окажется.
#   Акт 2 «ХВОСТ»   — «смотри, откуда придёт». Хвост стеной проходит поперёк
#                      экрана, оставляя щель у противоположного края. Край, из
#                      которого он выйдет, заранее загорается.
#   Акт 3 «КАРТЕЧЬ» — «выбери сторону». Веер дробин перекрывает всё, кроме
#                      одной линии; потом злая картечь на два залпа; потом
#                      ПАСТЬ — единственный такт, где игрок не уворачивается, а
#                      бьёт в ответ тапами.
#
# Общее правило всей битвы: СНАЧАЛА ТЕЛЕГРАФ, ПОТОМ УДАР. То же, что у
# боксёрской перчатки и у ниндзя.
#
# ── Что взято из старого проекта и что переделано ────────────────────────────
# В Flutter-версии (lib/game/components/item_components/bosses/leatherhead/)
# крокодил был доделан наполовину:
#
#   • Из одиннадцати заведённых состояний выставлялись ШЕСТЬ. Мёртвыми лежали
#     `squint`, `hunt` (21 нарисованный кадр!), `reload1`, `shoot` и —
#     обиднее всего — `crazyBuckshot`: злая картечь с раскрытой пастью,
#     лучшая анимация из всех, загружалась и не игралась ни разу. Здесь
#     используется ВСЁ нарисованное.
#   • Выстрелы шли без телеграфа: пуля летела в точку, где голова была в кадр
#     выстрела. Это не уворот, а подбрасывание монетки. Отсюда нить прицела.
#   • Список атак был плоским: `хвост, хвост, хвост, хвост` дважды подряд.
#     Нарастания не было. Отсюда три акта с разными вопросами.
#   • Охота и картечь длились ровно по 10 секунд независимо ни от чего, и
#     игрок не понимал, сколько ещё осталось. Отсюда ПАТРОНЫ в интерфейсе.
#   • Атаки «РАЗДУВ» и «ИСЧЕЗНОВЕНИЕ» были расписаны в комментарии автором и
#     не написаны кодом. Раздув вернулся как ПАСТЬ, исчезновение — как финал.
#
# См. /Концепция/Босс — Крокодил.md

signal defeated

# ── Кадры ────────────────────────────────────────────────────────────────────
# Все боевые позы нарезаны из ОДНОЙ рамки 1000×957 и ужаты одинаково, поэтому
# при смене позы голова не прыгает. Морда без ружья (idle/squint) нарисована в
# своей рамке и идёт только в финале, где рядом ничего нет.
const F_GUN        : Texture2D = preload("res://assets/bosses/leatherhead/gun.png")
const F_AFTER_SHOT : Texture2D = preload("res://assets/bosses/leatherhead/after_shot.png")
const F_IDLE       : Texture2D = preload("res://assets/bosses/leatherhead/idle.png")
const F_SQUINT     : Texture2D = preload("res://assets/bosses/leatherhead/squint.png")
const F_TAIL       : Texture2D = preload("res://assets/bosses/leatherhead/tail.png")
const F_BANNER     : Texture2D = preload("res://assets/bosses/leatherhead/banner.png")
const F_RELOAD_UP : Array = [
	preload("res://assets/bosses/leatherhead/reload_up1.png"),
	preload("res://assets/bosses/leatherhead/reload_up2.png"),
	preload("res://assets/bosses/leatherhead/reload_up3.png"),
]
const F_SNIPE : Array = [
	preload("res://assets/bosses/leatherhead/snipe1.png"),
	preload("res://assets/bosses/leatherhead/snipe2.png"),
	preload("res://assets/bosses/leatherhead/snipe3.png"),
]
const F_RELOAD_DOWN : Array = [
	preload("res://assets/bosses/leatherhead/reload_down1.png"),
	preload("res://assets/bosses/leatherhead/reload_down2.png"),
	preload("res://assets/bosses/leatherhead/reload_down3.png"),
]
const F_SHOT_DOWN : Array = [
	preload("res://assets/bosses/leatherhead/shot_down1.png"),
	preload("res://assets/bosses/leatherhead/shot_down2.png"),
	preload("res://assets/bosses/leatherhead/shot_down3.png"),
	preload("res://assets/bosses/leatherhead/shot_down4.png"),   # вспышка
	preload("res://assets/bosses/leatherhead/shot_down5.png"),
]
const F_RAGE : Array = [
	preload("res://assets/bosses/leatherhead/rage1.png"),
	preload("res://assets/bosses/leatherhead/rage2.png"),
	preload("res://assets/bosses/leatherhead/rage3.png"),
	preload("res://assets/bosses/leatherhead/rage4.png"),   # пасть + вспышка
	preload("res://assets/bosses/leatherhead/rage5.png"),   # пасть закрыта
	preload("res://assets/bosses/leatherhead/rage6.png"),   # пасть + вспышка
	preload("res://assets/bosses/leatherhead/rage7.png"),
]

const BULLET_SCRIPT := preload("res://scripts/leatherhead_bullet.gd")
const ITEM_SCENE    := preload("res://scenes/item.tscn")
const PIZZA_TEX     := preload("res://assets/items/pizza.png")
const DOLLAR_TEX    := preload("res://assets/items/dollar.png")
const UI_FONT       := preload("res://assets/fonts/RussoOne-Regular.ttf")

const SFX_ROAR     := preload("res://assets/audio/leatherhead/roar.mp3")
const SFX_SNIPER   := preload("res://assets/audio/leatherhead/sniper.mp3")
const SFX_BUCKSHOT := preload("res://assets/audio/leatherhead/buckshot.mp3")
const SFX_TAIL     := preload("res://assets/audio/leatherhead/tail.mp3")
const SFX_TAIL_HIT := preload("res://assets/audio/leatherhead/tail_hit.mp3")
const SFX_RELOAD   := preload("res://assets/audio/leatherhead/reload.mp3")
const BOSS_MUSIC   := preload("res://assets/audio/hard_track.mp3")
const BOSS_STINGER := preload("res://assets/audio/boss_fight.mp3")
const TAP_SFX      := preload("res://assets/audio/tap.mp3")

# ── Геометрия ────────────────────────────────────────────────────────────────
const W_INTRO : float = 250.0   # в интро он большой: это выход, а не атака
const W_FIGHT : float = 178.0   # в бою — полторы головы Нормальдо

# Положение ДУЛА в долях кадра. Замерено не на глаз, а по вспышке: она
# ярко-жёлтая и в кадре одна, так что центр жёлтого пятна и есть срез ствола.
# У трёх поз ствол в разных местах, и общей точкой обойтись нельзя — пуля
# вылетала бы из шеи.
const MUZZLE_AIM  : Vector2 = Vector2(0.091, 0.473)   # ствол поднят
const MUZZLE_DOWN : Vector2 = Vector2(0.167, 0.590)   # ствол опущен
const MUZZLE_RAGE : Vector2 = Vector2(0.100, 0.713)   # злая картечь

# Крокодил нарисован мордой ВЛЕВО, поэтому нос — это локальная ось −X.
const AIM_CLAMP : float = 0.55   # рад: дальше голова заваливается на спину

const BULLET_PX   : float = 34.0
const SNIPE_SPEED : float = 700.0
const SHOT_SPEED  : float = 520.0

var boss_test_mode : bool = false
# Автозапуск. Тесту нужны ОТДЕЛЬНЫЕ акты, а не вся битва с титрами: интро — это
# пять секунд реплики и баннера, и гонять их в каждой проверке значит мерить
# титры, а не бой.
@export var autostart : bool = true

var _normaldo  : Node2D = null
var _spawner   : Node   = null
var _game_root : Node2D = null
var _sprite    : Sprite2D = null
var _music     : AudioStreamPlayer = null

# Какой такт идёт прямо сейчас. Битва сшита из await'ов, и когда она встаёт, по
# одному только экрану не понять, на чём именно: маркер отвечает на это сразу.
var current_act : String = ""

var _shell_lamps : Array = []
var _shell_layer : CanvasLayer = null

func setup(normaldo: Node2D, spawner: Node, game_root: Node2D, test_mode: bool = false) -> void:
	_normaldo      = normaldo
	_spawner       = spawner
	_game_root     = game_root
	boss_test_mode = test_mode

func _ready() -> void:
	z_index = 40
	_sprite = Sprite2D.new()
	_sprite.texture        = F_GUN
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.visible        = true
	add_child(_sprite)
	_set_pose(F_GUN, W_INTRO)
	position = Vector2(get_viewport_rect().size.x + W_INTRO, get_viewport_rect().size.y * 0.5)

	_music = AudioStreamPlayer.new()
	var ms := BOSS_MUSIC.duplicate() as AudioStreamMP3
	ms.loop          = true
	_music.stream    = ms
	_music.volume_db = -14.0
	add_child(_music)

	if autostart:
		_run_boss.call_deferred()

# ── Позы ─────────────────────────────────────────────────────────────────────

func _set_pose(tex: Texture2D, width: float = -1.0) -> void:
	if not is_instance_valid(_sprite) or tex == null:
		return
	_sprite.texture = tex
	var w : float = width if width > 0.0 else _sprite.get_meta("w", W_FIGHT)
	_sprite.set_meta("w", w)
	var sz := tex.get_size()
	_sprite.scale = Vector2.ONE * (w / maxf(1.0, sz.x))

# Дуло В МИРОВЫХ координатах: спрайт вращается вокруг центра, и точка выстрела
# едет вместе с ним. Считать её от позиции узла нельзя — при довороте пуля
# начинала бы вылетать из воздуха рядом со стволом.
func _muzzle(rel: Vector2) -> Vector2:
	if not is_instance_valid(_sprite) or _sprite.texture == null:
		return global_position
	var sz := _sprite.texture.get_size()
	return _sprite.to_global((rel - Vector2(0.5, 0.5)) * sz)

# Доворот ствола к точке. Нос — локальная −X, отсюда «минус развёрнутый угол».
func _aim_at(target: Vector2) -> void:
	if not is_instance_valid(_sprite):
		return
	var d := target - global_position
	if d.length() < 1.0:
		return
	_sprite.rotation = clampf(wrapf(d.angle() - PI, -PI, PI), -AIM_CLAMP, AIM_CLAMP)

# ── Главная последовательность ───────────────────────────────────────────────

func _run_boss() -> void:
	var vp := get_viewport_rect().size
	position = Vector2(vp.x + W_INTRO, vp.y * 0.5)

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
	if not is_instance_valid(self):
		return
	_build_shells()

	await _act_hunt()
	if not is_instance_valid(self): return
	_burn_shell(0)
	await _act_tail()
	if not is_instance_valid(self): return
	_burn_shell(1)
	await _act_shotgun()
	if not is_instance_valid(self): return
	_burn_shell(2)
	await _finale()
	if not is_instance_valid(self): return

	current_act = "done"
	_music.stop()
	_drop_shells()
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
	tw_in.tween_property(self, "position:x", vp.x - W_INTRO * 0.62, 0.85)\
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	await tw_in.finished
	if not is_instance_valid(self):
		return
	_play_sfx(SFX_ROAR)
	_screen_shake(12.0, 9)

	var shake := create_tween()
	for _i in 4:
		shake.tween_property(_sprite, "rotation",  0.09, 0.07)
		shake.tween_property(_sprite, "rotation", -0.09, 0.07)
	shake.tween_property(_sprite, "rotation", 0.0, 0.07)
	await get_tree().create_timer(0.45).timeout
	if not is_instance_valid(self):
		return

	await _show_speech()
	if not is_instance_valid(self):
		return
	var tw_vol := create_tween()
	tw_vol.tween_property(_music, "volume_db", -3.0, 2.4)
	await _show_banner()
	if not is_instance_valid(self):
		return
	if is_instance_valid(_normaldo) and _normaldo.has_method("enable_input"):
		_normaldo.enable_input()
	_set_pose(F_GUN, W_FIGHT)

# Реплика босса. У Ноги Ниндзя она про то, что он уничтожит пиццу; крокодилу
# нужна СВОЯ — иначе два босса говорят одним голосом. Этот стреляет и охотится,
# поэтому и говорит как охотник: не угрожает, а объясняет, кто тут кто.
const SPEECH : String = "Стой смирно, черепашка.\nЯ никогда не мажу дважды."

func _show_speech() -> void:
	if is_instance_valid(_normaldo) and _normaldo.has_method("disable_input"):
		_normaldo.disable_input()
	var vp := get_viewport_rect().size
	var cl := CanvasLayer.new()
	cl.layer = 95
	_game_root.add_child(cl)

	var w : float = 330.0
	var h : float = 84.0
	var root := Control.new()
	root.size         = Vector2(w, h)
	root.position     = Vector2(vp.x - W_INTRO - w - 20.0, vp.y * 0.34)
	root.pivot_offset = Vector2(w, h * 0.5)
	root.scale        = Vector2(0.2, 0.2)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(root)
	UiKit.panel(root, Vector2.ZERO, Vector2(w, h), Color(0.07, 0.10, 0.06, 0.96),
		12, Color(0.45, 0.90, 0.35, 0.95), 3)
	var lbl := Label.new()
	lbl.add_theme_font_override("font", UI_FONT)
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.text                 = SPEECH
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl.modulate             = Color(0.86, 1.0, 0.80)
	lbl.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	UiKit.place(root, lbl, Vector2(10.0, 0.0), Vector2(w - 20.0, h))

	var tw := root.create_tween()
	tw.tween_property(root, "scale", Vector2.ONE, 0.26)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(3.0).timeout
	if is_instance_valid(cl):
		var out := root.create_tween()
		out.tween_property(root, "modulate:a", 0.0, 0.22)
		out.tween_callback(cl.queue_free)

func _show_banner() -> void:
	var vp := get_viewport_rect().size
	var cl := CanvasLayer.new()
	cl.layer = 99
	_game_root.add_child(cl)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.06, 0.02, 0.0)
	dim.size  = vp
	cl.add_child(dim)

	# Титр нарисованный, а не набранный шрифтом: у крокодила он свой, с его
	# мордой в букве O.
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
	sub.text                 = "КРОКОДИЛ"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.modulate             = Color(0.55, 1.0, 0.35, 0.0)
	sub.size                 = Vector2(vp.x, 32.0)
	sub.position             = Vector2(0.0, vp.y * 0.22 + bh + 6.0)
	cl.add_child(sub)

	var tw_d := dim.create_tween()
	tw_d.tween_property(dim, "color:a", 0.62, 0.26)
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

# ── Акт 1: ОХОТА ─────────────────────────────────────────────────────────────
# Ствол ведёт за головой ПОСТОЯННО — по этому и читается «пока он целится, я
# ещё жив». Опасен не доворот, а нить: она загорается, замирает, и вот по ней
# уже прилетит.
const HUNT_SHOTS  : int   = 6
const HUNT_PERIOD : float = 2.2
const LASER_T     : float = 0.45   # столько нить висит, прежде чем выстрел
const TRACK_LERP  : float = 0.055  # насколько лениво он едет за линией игрока

var _tracking : bool = false

func _act_hunt() -> void:
	current_act = "hunt"
	var vp := get_viewport_rect().size
	_set_pose(F_RELOAD_UP[0], W_FIGHT)
	var tw := create_tween()
	tw.tween_property(self, "position:x", vp.x - W_FIGHT * 0.62, 0.5)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tw.finished
	_tracking = true

	for i in HUNT_SHOTS:
		if not is_instance_valid(self):
			return
		await get_tree().create_timer(HUNT_PERIOD - LASER_T - 0.3).timeout
		if not is_instance_valid(self):
			return
		# Передёрг — по нему слышно и видно, что сейчас будет выстрел.
		_play_sfx(SFX_RELOAD)
		for f in F_RELOAD_UP:
			_set_pose(f)
			await get_tree().create_timer(0.09).timeout
			if not is_instance_valid(self):
				return
		# Нить ФИКСИРУЕТ направление: дальше он уже не доводит.
		_tracking = false
		var from := _muzzle(MUZZLE_AIM)
		var to   : Vector2 = _normaldo.global_position if is_instance_valid(_normaldo) \
			else from + Vector2(-vp.x, 0.0)
		var dir  := (to - from).normalized()
		_laser(from, from + dir * vp.length(), LASER_T)
		await get_tree().create_timer(LASER_T).timeout
		if not is_instance_valid(self):
			return
		_set_pose(F_SNIPE[0])
		await get_tree().create_timer(0.06).timeout
		if not is_instance_valid(self):
			return
		_set_pose(F_SNIPE[1])
		_play_sfx(SFX_SNIPER)
		_fire(_muzzle(MUZZLE_AIM), dir, SNIPE_SPEED)
		_recoil()
		await get_tree().create_timer(0.10).timeout
		if not is_instance_valid(self):
			return
		_set_pose(F_SNIPE[2])
		await get_tree().create_timer(0.16).timeout
		if not is_instance_valid(self):
			return
		_set_pose(F_RELOAD_UP[0])
		_tracking = true
	_tracking = false

func _process(delta: float) -> void:
	if not _tracking or not is_instance_valid(_normaldo):
		return
	# Едет за линией игрока ЛЕНИВО: мгновенное слежение означало бы, что уходить
	# с линии бесполезно, а весь акт держится ровно на этом.
	position.y = lerpf(position.y, _normaldo.global_position.y, TRACK_LERP)
	_aim_at(_normaldo.global_position)

# Нить прицела. Красная, тонкая, с пульсом — она обязана читаться как
# «предупреждение», а не как «луч уже стреляет».
func _laser(from: Vector2, to: Vector2, dur: float) -> void:
	if not is_instance_valid(_game_root):
		return
	var l := Line2D.new()
	l.name          = "AimLaser"
	l.width         = 2.0
	l.default_color = Color(1.0, 0.16, 0.12, 0.0)
	l.z_index       = 39
	l.points        = PackedVector2Array([from, to])
	_game_root.add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "default_color:a", 0.85, dur * 0.35)
	tw.tween_property(l, "default_color:a", 0.35, dur * 0.32)
	tw.tween_property(l, "default_color:a", 0.95, dur * 0.33)
	tw.tween_callback(l.queue_free)

func _fire(from: Vector2, dir: Vector2, spd: float) -> void:
	if not is_instance_valid(_game_root):
		return
	var b := Area2D.new()
	b.set_script(BULLET_SCRIPT)
	b.call("init", dir, spd, BULLET_PX)
	b.position = from
	_game_root.add_child(b)

func _recoil() -> void:
	var tw := create_tween()
	var home := position.x
	tw.tween_property(self, "position:x", home + 12.0, 0.06)
	tw.tween_property(self, "position:x", home, 0.12)

# ── Акт 2: ХВОСТ ─────────────────────────────────────────────────────────────
# Хвост идёт СТЕНОЙ поперёк экрана и оставляет щель у противоположного края.
# Уворачиваться от него нельзя — можно только заранее быть не там, поэтому
# край, из которого он выйдет, загорается за 0.4 с.
const TAIL_LEN_FRAC : float = 0.72   # какую долю высоты экрана перекрывает
const TAIL_GLOW_T   : float = 0.40
# Насколько хвост уходит ЗА КРАЙ. Основание — это срез, которым хвост крепится к
# телу, и торчащий в кадр срез читается как «хвост оторвали и бросили», а не как
# «крокодил бьёт хвостом из-за экрана». Прячем его целиком.
const TAIL_HIDE_FRAC : float = 0.35
const TAIL_SWEEPS : Array = [
	{ "side": "bottom", "speed": 300.0 },
	{ "side": "top",    "speed": 380.0 },
	{ "side": "bottom", "speed": 460.0 },
	{ "side": "top",    "speed": 560.0 },
	{ "side": "bottom", "speed": 680.0 },
]

func _act_tail() -> void:
	current_act = "tail"
	var vp := get_viewport_rect().size
	# Уходит за край, торчит нос: бить будет хвост, и голова в кадре только
	# мешала бы читать, откуда он.
	var tw := create_tween()
	tw.tween_property(self, "position:x", vp.x + W_FIGHT * 0.34, 0.45)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished

	for i in TAIL_SWEEPS.size():
		if not is_instance_valid(self):
			return
		var s : Dictionary = TAIL_SWEEPS[i]
		await _edge_glow(String(s["side"]), TAIL_GLOW_T)
		if not is_instance_valid(self):
			return
		await _tail_sweep(String(s["side"]), float(s["speed"]))
		if not is_instance_valid(self):
			return
		# Между проходами — пицца на свободной стороне. Акт не должен быть
		# чистым уворотом: голый уворот читается как наказание, а не как бой.
		if i < TAIL_SWEEPS.size() - 1:
			_drop_loot(vp * Vector2(0.55, 0.5) + Vector2(0.0,
				vp.y * (-0.34 if String(s["side"]) == "bottom" else 0.34)))
			await get_tree().create_timer(0.35).timeout

func _edge_glow(side: String, dur: float) -> void:
	var vp := get_viewport_rect().size
	var g := ColorRect.new()
	g.color = Color(0.35, 1.00, 0.30, 0.0)
	g.size  = Vector2(vp.x, 14.0)
	g.position = Vector2(0.0, vp.y - 14.0 if side == "bottom" else 0.0)
	g.z_index  = 38
	_game_root.add_child(g)
	var tw := g.create_tween()
	tw.set_loops(2)
	tw.tween_property(g, "color:a", 0.75, dur * 0.25)
	tw.tween_property(g, "color:a", 0.15, dur * 0.25)
	await get_tree().create_timer(dur).timeout
	if is_instance_valid(g):
		g.queue_free()

func _tail_sweep(side: String, speed: float) -> void:
	var vp  := get_viewport_rect().size
	# len_px — то, что ВИДНО в кадре; хвост длиннее на TAIL_HIDE_FRAC, и лишнее
	# уходит за край вместе с основанием.
	var len_px : float = vp.y * TAIL_LEN_FRAC
	var hide   : float = len_px * TAIL_HIDE_FRAC
	var full   : float = len_px + hide
	var thick  : float = full * float(F_TAIL.get_height()) / float(F_TAIL.get_width())
	# Полоса хвоста стоит так, чтобы её видимый конец упирался в край экрана, а
	# спрятанный уходил наружу.
	var mid_y  : float = vp.y + (hide - len_px) * 0.5 if side == "bottom" \
		else (len_px - hide) * 0.5
	var from_x : float = -thick if side == "bottom" else vp.x + thick
	var to_x   : float = vp.x + thick if side == "bottom" else -thick

	var node := Area2D.new()
	node.collision_layer = 2
	node.collision_mask  = 0
	node.position        = Vector2(from_x, mid_y)
	node.z_index         = 37
	node.add_to_group("obstacle")
	node.add_to_group("croc_tail")
	node.set_script(preload("res://scripts/smoke_obstacle.gd"))

	var spr := Sprite2D.new()
	spr.texture        = F_TAIL
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.scale          = Vector2.ONE * (full / float(F_TAIL.get_width()))
	# Хвост нарисован лежащим, ОСНОВАНИЕМ ВПРАВО (замер: у левого края толщина 2
	# пикселя, у правого — 75). Разворачиваем так, чтобы основание смотрело В
	# КРАЙ экрана, а в кадр торчал кончик.
	spr.rotation       = PI * 0.5 if side == "bottom" else -PI * 0.5
	node.add_child(spr)

	# Бьёт только ВИДИМАЯ часть: спрятанный за краем кусок хитбоксом не считается,
	# иначе стена оказалась бы выше того, что нарисовано.
	var cs   := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size    = Vector2(thick * 0.62, len_px * 0.92)
	cs.shape     = rect
	cs.position  = Vector2(0.0, -hide * 0.5 if side == "bottom" else hide * 0.5)
	node.add_child(cs)
	_game_root.add_child(node)
	_play_sfx(SFX_TAIL)

	var dur : float = absf(to_x - from_x) / maxf(speed, 1.0)
	var tw := node.create_tween()
	tw.tween_property(node, "position:x", to_x, dur).set_trans(Tween.TRANS_LINEAR)
	await tw.finished
	if is_instance_valid(node):
		node.queue_free()

# ── Акт 3: КАРТЕЧЬ, ЗЛАЯ КАРТЕЧЬ И ПАСТЬ ─────────────────────────────────────
const BUCK_SHOTS  : int   = 4
const BUCK_PERIOD : float = 1.5
const BUCK_SPREAD : float = 92.0    # разлёт крайних дробин по вертикали
const RAGE_SPREAD : float = 58.0
const LUNGE_TAPS  : int   = 12
const LUNGE_TIME  : float = 4.0

func _act_shotgun() -> void:
	current_act = "shotgun"
	var vp := get_viewport_rect().size
	var tw := create_tween()
	tw.tween_property(self, "position", Vector2(vp.x - W_FIGHT * 0.62, vp.y * 0.5), 0.5)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tw.finished
	_sprite.rotation = 0.0
	_set_pose(F_SHOT_DOWN[0])

	# 3.1 Картечь: веер из трёх. Разлёт подобран так, что ОДНА линия из пяти
	# всегда остаётся свободной — веер читается как «выбери сторону», а не как
	# стена, от которой не уйти.
	for i in BUCK_SHOTS:
		if not is_instance_valid(self):
			return
		await _buckshot(3, BUCK_SPREAD)
		if not is_instance_valid(self):
			return
		await get_tree().create_timer(BUCK_PERIOD).timeout

	# 3.2 Злая картечь — та самая анимация, которая в старом проекте ни разу не
	# сыграла. Рёв и красная вспышка дают 0.8 с на то, чтобы уйти.
	if not is_instance_valid(self):
		return
	_play_sfx(SFX_ROAR)
	_screen_flash(Color(1.0, 0.15, 0.10))
	_screen_shake(9.0, 7)
	await get_tree().create_timer(0.8).timeout
	if not is_instance_valid(self):
		return
	await _rage_volley()

	# 3.3 ПАСТЬ — единственный такт, где игрок бьёт в ответ.
	for i in 2:
		if not is_instance_valid(self):
			return
		await get_tree().create_timer(0.6).timeout
		if not is_instance_valid(self):
			return
		await _jaw_lunge()

func _buckshot(count: int, spread: float) -> void:
	for f in [F_RELOAD_DOWN[1], F_SHOT_DOWN[0], F_SHOT_DOWN[1], F_SHOT_DOWN[2]]:
		_set_pose(f)
		await get_tree().create_timer(0.07).timeout
		if not is_instance_valid(self):
			return
	_set_pose(F_SHOT_DOWN[3])          # кадр со вспышкой — на нём и стреляем
	_play_sfx(SFX_BUCKSHOT)
	var from := _muzzle(MUZZLE_DOWN)
	var base : Vector2 = _normaldo.global_position if is_instance_valid(_normaldo) \
		else from + Vector2(-400.0, 0.0)
	var half : int = count / 2
	for i in count:
		var off : float = float(i - half) * spread
		_fire(from, (base + Vector2(0.0, off) - from).normalized(), SHOT_SPEED)
	_recoil()
	await get_tree().create_timer(0.10).timeout
	if not is_instance_valid(self):
		return
	_set_pose(F_SHOT_DOWN[4])

func _rage_volley() -> void:
	# Два залпа по пять дробин: перекрывают четыре линии из пяти. Это самый
	# плотный момент битвы, и он ровно один.
	for idx in F_RAGE.size():
		if not is_instance_valid(self):
			return
		_set_pose(F_RAGE[idx])
		if idx == 3 or idx == 5:       # кадры с раскрытой пастью и вспышкой
			_play_sfx(SFX_BUCKSHOT)
			var from := _muzzle(MUZZLE_RAGE)
			var base : Vector2 = _normaldo.global_position if is_instance_valid(_normaldo) \
				else from + Vector2(-400.0, 0.0)
			for i in 5:
				var off : float = float(i - 2) * RAGE_SPREAD
				_fire(from, (base + Vector2(0.0, off) - from).normalized(), SHOT_SPEED)
			_recoil()
			_screen_shake(6.0, 5)
		await get_tree().create_timer(0.14).timeout

# Пасть: крокодил идёт по линии игрока, тапы его отталкивают. Это возвращённый
# «РАЗДУВ» из старого замысла — единственная точка битвы, где игрок не
# уворачивается, а отвечает. Каждый тап выбивает добычу: удар по боссу обязан
# что-то ДАВАТЬ, иначе тапают из вежливости.
var _lunging   : bool = false
var _lunge_hp  : int  = 0

func _jaw_lunge() -> void:
	var vp := get_viewport_rect().size
	var target_y : float = _normaldo.global_position.y if is_instance_valid(_normaldo) \
		else vp.y * 0.5
	position  = Vector2(vp.x + W_FIGHT * 0.5, target_y)
	_sprite.rotation = 0.0
	_set_pose(F_RAGE[3])
	_play_sfx(SFX_ROAR)
	_lunge_hp = LUNGE_TAPS
	_lunging  = true
	var hint := _tap_hint()

	# Пасть щёлкает: кадр с открытой пастью и кадр с закрытой по очереди.
	var chomp := create_tween()
	chomp.set_loops(int(LUNGE_TIME / 0.28) + 1)
	chomp.tween_callback(func() -> void:
		if is_instance_valid(self) and _lunging:
			_set_pose(F_RAGE[3]))
	chomp.tween_interval(0.14)
	chomp.tween_callback(func() -> void:
		if is_instance_valid(self) and _lunging:
			_set_pose(F_RAGE[4]))
	chomp.tween_interval(0.14)

	var reach_x : float = (_normaldo.global_position.x + 60.0) if is_instance_valid(_normaldo) \
		else vp.x * 0.25
	var t := 0.0
	while t < LUNGE_TIME and _lunge_hp > 0 and is_instance_valid(self):
		await get_tree().process_frame
		var dt := get_process_delta_time()
		t += dt
		position.x -= ((vp.x - reach_x) / LUNGE_TIME) * dt
		if position.x <= reach_x:
			break
	_lunging = false
	if is_instance_valid(chomp):
		chomp.kill()
	if is_instance_valid(hint):
		hint.queue_free()
	if not is_instance_valid(self):
		return
	# Не отбился — удар. Отбился — уходит сам.
	if _lunge_hp > 0 and position.x <= reach_x + 4.0:
		if is_instance_valid(_normaldo) and _normaldo.has_method("_take_hit"):
			_normaldo.call("_take_hit", 1)
		_play_sfx(SFX_TAIL_HIT)
	var back := create_tween()
	back.tween_property(self, "position:x", vp.x - W_FIGHT * 0.62, 0.45)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await back.finished
	_set_pose(F_SHOT_DOWN[0])

func _input(event: InputEvent) -> void:
	if not _lunging:
		return
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		_on_lunge_tap()

func _on_lunge_tap() -> void:
	if _lunge_hp <= 0:
		return
	_lunge_hp -= 1
	var vp := get_viewport_rect().size
	position.x = minf(position.x + vp.x * 0.055, vp.x + W_FIGHT * 0.5)
	_play_sfx(TAP_SFX)
	_spit_loot()
	var tw := create_tween()
	tw.tween_property(_sprite, "modulate", Color(1.7, 0.7, 0.7), 0.05)
	tw.tween_property(_sprite, "modulate", Color.WHITE, 0.12)

func _tap_hint() -> Label:
	var vp := get_viewport_rect().size
	var l := Label.new()
	l.add_theme_font_override("font", UI_FONT)
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 5)
	l.text                 = "ТАПАЙ!"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.modulate             = Color(1.0, 0.92, 0.25)
	l.size                 = Vector2(vp.x, 30.0)
	l.position             = Vector2(0.0, vp.y * 0.12)
	l.z_index              = 60
	_game_root.add_child(l)
	UiKit.pulse(l, "scale", Vector2(1.14, 1.14), Vector2.ONE, 0.22)
	return l

func _spit_loot() -> void:
	_drop_loot(_muzzle(MUZZLE_RAGE))

func _drop_loot(at: Vector2) -> void:
	if not is_instance_valid(_spawner):
		return
	var as_pizza := randf() < 0.62
	var item := ITEM_SCENE.instantiate()
	item.speed      = 240.0
	item.is_eatable = as_pizza
	item.damage     = 0
	item.rotates    = true
	item.pulses     = as_pizza
	if not as_pizza:
		item.item_group = "dollar"
	var spr := item.get_node("Sprite2D") as Sprite2D
	spr.texture = PIZZA_TEX if as_pizza else DOLLAR_TEX
	spr.scale   = Vector2.ONE * (0.09 if as_pizza else 0.36)
	item.position = at
	_spawner.add_child(item)

# ── Финал: ИСЧЕЗНОВЕНИЕ ──────────────────────────────────────────────────────
# Расписан автором старого проекта в комментарии и никогда не написан кодом:
# крокодилу на морду падает пицца, он озирается, и его сносит гигантским
# хвостом. Забирать у битвы такой финал было бы жалко.
func _finale() -> void:
	current_act = "finale"
	var vp := get_viewport_rect().size
	_sprite.rotation = 0.0
	var tw := create_tween()
	tw.tween_property(self, "position", Vector2(vp.x * 0.72, vp.y * 0.5), 0.5)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tw.finished
	if not is_instance_valid(self):
		return
	_set_pose(F_IDLE, W_FIGHT)

	# Пицца падает сверху ему на морду.
	var pie := Sprite2D.new()
	pie.texture        = PIZZA_TEX
	pie.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ItemSizing.fit_sprite(pie, 54.0)
	pie.position = Vector2(vp.x * 0.72, -60.0)
	pie.z_index  = 45
	_game_root.add_child(pie)
	var fall := pie.create_tween()
	fall.tween_property(pie, "position:y", vp.y * 0.5 - 6.0, 0.45)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await fall.finished
	if not is_instance_valid(self):
		return
	_screen_shake(5.0, 4)

	# Озирается: idle ↔ squint.
	for i in 3:
		_set_pose(F_SQUINT)
		await get_tree().create_timer(0.22).timeout
		if not is_instance_valid(self):
			return
		_set_pose(F_IDLE)
		await get_tree().create_timer(0.22).timeout
		if not is_instance_valid(self):
			return
	if is_instance_valid(pie):
		pie.queue_free()

	# И его сносит хвостом — тем же, которым он бил сам.
	var big := Sprite2D.new()
	big.texture        = F_TAIL
	big.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Длиннее экрана намеренно: оба конца всегда за кадром, и срез основания не
	# проезжает по центру.
	var big_len : float = vp.x * 1.3
	big.scale          = Vector2.ONE * (big_len / float(F_TAIL.get_width()))
	big.position       = Vector2(vp.x + big_len * 0.5, vp.y * 0.5)
	big.z_index        = 46
	_game_root.add_child(big)
	_play_sfx(SFX_TAIL)
	var sweep := big.create_tween()
	sweep.tween_property(big, "position:x", -big_len * 0.5, 0.55).set_trans(Tween.TRANS_LINEAR)

	await get_tree().create_timer(0.26).timeout
	if not is_instance_valid(self):
		return
	_play_sfx(SFX_TAIL_HIT)
	_screen_shake(16.0, 10)
	var out := create_tween()
	out.tween_property(self, "position:x", -W_FIGHT * 2.0, 0.55)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	out.parallel().tween_property(_sprite, "rotation", -TAU * 1.5, 0.55)
	await out.finished
	if is_instance_valid(big):
		big.queue_free()

# ── Патроны: сколько битвы осталось ──────────────────────────────────────────
# Полоски здоровья тут быть не может — игрок боссу урона не наносит, и полоска
# врала бы. Но вопрос «сколько ещё» законный, и у Ноги Ниндзя он остался без
# ответа. Три патрона, по одному на акт: догорают по мере прохождения.
const SHELL_W : float = 16.0
const SHELL_H : float = 26.0

func _build_shells() -> void:
	var vp := get_viewport_rect().size
	_shell_layer = CanvasLayer.new()
	_shell_layer.layer = 60
	_game_root.add_child(_shell_layer)
	var total : float = 3.0 * SHELL_W + 2.0 * 8.0
	for i in 3:
		var root := Control.new()
		root.size         = Vector2(SHELL_W, SHELL_H)
		root.position     = Vector2((vp.x - total) * 0.5 + i * (SHELL_W + 8.0), 8.0)
		root.pivot_offset = root.size * 0.5
		root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_shell_layer.add_child(root)
		var body := ColorRect.new()
		body.color    = Color(0.78, 0.14, 0.12)
		body.size     = Vector2(SHELL_W, SHELL_H * 0.62)
		body.position = Vector2.ZERO
		root.add_child(body)
		var brass := ColorRect.new()
		brass.color    = Color(0.85, 0.68, 0.22)
		brass.size     = Vector2(SHELL_W, SHELL_H * 0.38)
		brass.position = Vector2(0.0, SHELL_H * 0.62)
		root.add_child(brass)
		_shell_lamps.append(root)

func _burn_shell(i: int) -> void:
	if i < 0 or i >= _shell_lamps.size():
		return
	var s : Control = _shell_lamps[i]
	if not is_instance_valid(s):
		return
	var tw := s.create_tween()
	tw.tween_property(s, "scale", Vector2(1.35, 1.35), 0.10)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(s, "modulate", Color(0.30, 0.30, 0.34, 0.55), 0.22)
	tw.parallel().tween_property(s, "scale", Vector2(0.85, 0.85), 0.22)

func _drop_shells() -> void:
	if is_instance_valid(_shell_layer):
		_shell_layer.queue_free()
	_shell_layer = null
	_shell_lamps.clear()

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
	_game_root.add_child(cl)
	var r := ColorRect.new()
	r.color = Color(col.r, col.g, col.b, 0.0)
	r.size  = get_viewport_rect().size
	cl.add_child(r)
	var tw := r.create_tween()
	tw.tween_property(r, "color:a", 0.45, 0.08)
	tw.tween_property(r, "color:a", 0.0, 0.32)
	tw.tween_callback(cl.queue_free)
