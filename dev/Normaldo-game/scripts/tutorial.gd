extends Node
class_name Tutorial

# ── ОБУЧЕНИЕ: ПЕРВЫЙ ЗАБЕГ ───────────────────────────────────────────────────
# См. /Концепция/Обучение — первый забег и меню.md
#
# Первый забег — НЕ обычный забег со всплывашками поверх. Поток предметов в нём
# выдан вручную, такт за тактом: каждая новая вещь появляется одна, в пустоте, и
# промахнуться мимо неё нельзя. Всплывашки поверх обычного потока прощёлкивают
# не читая — не потому, что игрок не хочет учиться, а потому, что за окном уже
# что-то летит и он боится пропустить.
#
# ── ЧЕТЫРЕ ПРАВИЛА ──────────────────────────────────────────────────────────
# 1. УПРАВЛЕНИЕ НЕ ОТНИМАЕТСЯ. Ни паузы, ни модальных окон, ни «нажмите ДАЛЕЕ».
#    Максимум — замедление мира: игрок уже знает это ощущение по часам и мешку
#    и читает его как «дали подумать», а не как «у меня забрали игру».
#
# 2. ТАКТ КОНЧАЕТСЯ ПО ДЕЙСТВИЮ, А НЕ ПО ТАЙМЕРУ. Попросили вести пальцем —
#    ждём, пока сдвинется. Это единственный способ разом не потерять того, кто
#    читает медленно, и не задержать того, кто понял с полувзгляда. Таймер у
#    такта всё-таки есть, но он не «сколько показывать», а страховка от
#    зависания: истёк — идём дальше молча.
#
# 3. ОДНА МЫСЛЬ НА ЭКРАНЕ. Две подсказки разом — значит, тактов должно быть два.
#
# 4. В ПЕРВОМ ЗАБЕГЕ НЕЛЬЗЯ УМЕРЕТЬ. Умереть в обучении — самый надёжный способ
#    сделать первое впечатление «игра наказала меня за то, чего не объяснила».
#    Жир при этом теряется по-настоящему: удар обязан что-то стоить, иначе
#    третий такт ничему не учит.
#
# ── ПОЧЕМУ ОТДЕЛЬНЫЙ УЗЕЛ, А НЕ ЧАСТЬ СПАВНЕРА ──────────────────────────────
# Обучение глушит поток через `pause_for_event()`, а тот делает спавнеру
# `set_process(false)`. Живущее внутри спавнера обучение остановилось бы вместе
# с ним — ровно на этом однажды погорел мешок денег. Поэтому узел живёт в корне
# сцены, рядом со спавнером, и тикает сам.

const UI_FONT   := preload("res://assets/fonts/RussoOne-Regular.ttf")
# Стрелка — та же, которой в слотах показывают свайп. Второй рисунок пальца
# выглядел бы как другая игра.
const ARROW_TEX := preload("res://assets/ui/quests/back_arrow.png")

# ── СЦЕНАРИЙ ────────────────────────────────────────────────────────────────
# Порядок не случайный. Управление — раньше всего, без него нет ничего. Награда
# раньше угрозы: игрок должен сначала захотеть двигаться и только потом узнать,
# чего избегать. Жир — сразу после того, как объелся: это единственный момент,
# когда объяснение совпадает с ощущением в пальце. Способность — последней,
# потому что до неё игроку хватает забот.
#
# Слова лежат здесь, рядом с порядком, а не внутри кода тактов: править
# формулировку и править логику — разные занятия, и делать их в одном месте
# значит рисковать вторым ради первого.
const BEATS : Array = [
	{ "id": "move",   "big": "ВЕДИ ПАЛЬЦЕМ",       "small": "голова идёт следом",      "limit": 20.0 },
	{ "id": "eat",    "big": "ЕШЬ ПИЦЦУ",          "small": "это очки и вес",          "limit": 22.0 },
	{ "id": "dodge",  "big": "МУСОР — ОБЛЕТАЙ",    "small": "в него нельзя",           "limit": 14.0 },
	{ "id": "fat",    "big": "НАЕЛСЯ — ПОТЯЖЕЛЕЛ", "small": "тяжёлый слушается хуже",  "limit": 20.0 },
	{ "id": "dollar", "big": "ДОЛЛАР — НЕ ЕДА",    "small": "на них берут скины",      "limit": 14.0 },
	{ "id": "skill",  "big": "ДВОЙНОЙ ТАП",        "small": "это способность скина",   "limit": 20.0 },
]

# Насколько надо увести голову, чтобы такт «веди пальцем» засчитался. Полосы по
# 86 пикселей: шестьдесят — это «сменил полосу», а не «дрогнул палец».
const MOVE_ENOUGH : float = 60.0

# Замедление на подлёте мусора. Не 0.15 (нижняя граница спавнера): мир должен
# стать читаемым, а не встать.
const DODGE_SLOW  : float = 0.45

signal finished

var _game     : Node   = null
var _spawner  : Node   = null
var _normaldo : Node2D = null

var _layer   : CanvasLayer = null
var _caption : Control     = null
var _arrows  : Node2D      = null

var _skipped   : bool = false
var _running   : bool = false
var _held_pause: bool = false
var _immortal_before : bool = false

# Считает то, что случилось ПОКА ИДЁТ ТАКТ. Сравнивать с полями Нормальдо
# напрямую нельзя: пицца могла прилететь и до начала такта.
var _ate      : int  = 0
var _got_buck : int  = 0
var _was_hit  : bool = false
var _fired    : bool = false

# ── Запуск ──────────────────────────────────────────────────────────────────
# Зовёт HUD в начале первого забега. Возвращает узел, чтобы тест мог его
# дождаться.
static func start(game_root: Node) -> Tutorial:
	if game_root == null:
		return null
	var t := Tutorial.new()
	t.name = "Tutorial"
	game_root.add_child(t)
	return t

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_game     = get_parent()
	_spawner  = _game.get_node_or_null("Spawner")
	_normaldo = _game.get_node_or_null("Normaldo") as Node2D
	if _spawner == null or _normaldo == null:
		queue_free()
		return
	_build_ui()
	_hook()
	_run()

# Уйти надо ЧИСТО в любом случае — и по концу, и когда забег оборвали смертью
# или выходом в меню. Незакрытая пауза спавнера означает поток, замороженный
# навсегда, а незакрытая неуязвимость — бессмертного Нормальдо в обычной игре.
func _exit_tree() -> void:
	_release()

# ── Ход сценария ────────────────────────────────────────────────────────────

# Сколько ждать перед первым словом. Забег начинается карточкой эпизода
# («Выберись из канализации») и баннером задания дня — они появляются сами и
# занимают экран первые пару секунд. Первая подсказка, выданная поверх них,
# ложится буквами на буквы, и игрок читает обе наполовину.
#
# Поток к этому моменту уже заглушен, так что ждём мы в тишине, а не «пока
# что-то пролетит».
const INTRO_WAIT : float = 3.0

func _run() -> void:
	_running = true
	_grab()
	await _breath(INTRO_WAIT)
	for beat in BEATS:
		if _skipped or not _alive():
			break
		await _play(beat as Dictionary)
		if not _alive():
			return
		await _breath(0.6)
	_release()
	SaveData.tutorial_done = true
	SaveData._save()
	if _alive():
		finished.emit()
		queue_free()

func _play(beat: Dictionary) -> void:
	var id : String = String(beat.get("id", ""))
	# Способность объясняем только тому, у кого она есть. Подсказка про то, чего
	# у игрока нет, — это не обучение, а обещание.
	if id == "skill" and not bool(_normaldo.call("has_active_ability")):
		return
	_ate      = 0
	_got_buck = 0
	_was_hit  = false
	_fired    = false
	_say(String(beat.get("big", "")), String(beat.get("small", "")))
	await _serve(id)
	if not _alive():
		return
	await _wait_until(_cond_for(id), float(beat.get("limit", 20.0)))
	if not _alive():
		return
	await _after(id)
	_hush()

# Что выдать в поток на такте.
func _serve(id: String) -> void:
	match id:
		"move":
			_show_arrows()
		"eat":
			# Первая пицца — В ЕГО ЖЕ ПОЛОСЕ: её поймают не глядя, и это ровно то,
			# что нужно первым, — «съел, и что-то произошло». Остальные три
			# лесенкой по соседним: за ними уже надо вести.
			_send("pizza", _lane_of_normaldo())
			await _breath(0.9)
			for step in [-1, 1, -2]:
				if not _alive():
					return
				_send("pizza", _lane_of_normaldo() + step)
				await _breath(0.7)
		"dodge":
			var trash := _send("trash", _lane_of_normaldo())
			# Замедление ставится ПОСЛЕ спавна: спавнер домножает скорость живым
			# предметам, и выданный при уже замедленном мире бак поехал бы вдвое
			# медленнее нужного.
			if trash != null:
				_spawner.call("set_world_speed", DODGE_SLOW)
		"fat":
			for i in 5:
				if not _alive():
					return
				_send("pizza", _lane_of_normaldo() + (1 if i % 2 == 0 else -1))
				await _breath(0.45)
		"dollar":
			_send("dollar", _lane_of_normaldo() + 1)
		"skill":
			# Мишень под способность: три бака стенкой. Без мишени двойной тап
			# отрабатывает в пустоту, и игрок видит вспышку, а не то, что она
			# делает.
			await _breath(0.8)
			for lane in [1, 2, 3]:
				if not _alive():
					return
				_send("trash", lane)

# Чем такт кончается. Именно ДЕЙСТВИЕМ игрока, а не временем.
func _cond_for(id: String) -> Callable:
	match id:
		"move":
			var y0 : float = _normaldo.position.y
			return func() -> bool:
				return absf(_normaldo.position.y - y0) >= MOVE_ENOUGH
		"eat":
			return func() -> bool: return _ate >= 3
		"dodge":
			# Бак либо съеден лбом, либо уехал за левый край — в обоих случаях
			# такт сыгран, и разговор дальше разный (см. `_after`).
			return func() -> bool:
				return _was_hit or _no_items_of("obstacle")
		"fat":
			return func() -> bool:
				return int(_normaldo.get("fat_state")) >= 1 or _ate >= 5
		"dollar":
			return func() -> bool:
				return _got_buck > 0 or _no_items_of("dollar")
		"skill":
			return func() -> bool: return _fired
	return func() -> bool: return true

# Что сказать вслед. Только там, где ответ игрока бывает разным: одинаковое
# «молодец» на любой исход — это шум.
func _after(id: String) -> void:
	match id:
		"dodge":
			_spawner.call("set_world_speed", 1.0)
			if _was_hit:
				_say("ПОТЕРЯЛ ВЕС", "в следующий раз облетай")
			else:
				_say("ВОТ ТАК", "")
			await _breath(1.4)

# ── Слежка за игроком ───────────────────────────────────────────────────────

func _hook() -> void:
	if _normaldo.has_signal("stats_changed"):
		_normaldo.connect("stats_changed", _on_stats)
	if _normaldo.has_signal("dollars_changed"):
		_normaldo.connect("dollars_changed", _on_dollars)
	if _normaldo.has_signal("hit_taken"):
		_normaldo.connect("hit_taken", _on_hit)
	if _normaldo.has_signal("ability_fired"):
		_normaldo.connect("ability_fired", _on_fired)

var _pizza_seen : int = -1

func _on_stats(_fat: int, pizza: int, _total: int) -> void:
	if _pizza_seen >= 0 and pizza > _pizza_seen:
		_ate += pizza - _pizza_seen
	_pizza_seen = pizza

func _on_dollars(_count: int) -> void:
	_got_buck += 1

func _on_hit(_fat_before: int) -> void:
	_was_hit = true

func _on_fired(_id: String) -> void:
	_fired = true

# ── Захват и возврат забега ─────────────────────────────────────────────────

func _grab() -> void:
	if _held_pause:
		return
	_held_pause = true
	_spawner.call("pause_for_event")
	_spawner.call("clear_items")
	_immortal_before = bool(_normaldo.get("_dev_immortal"))
	_normaldo.call("set_dev_immortal", true)

# Возврат идёт РОВНО ОДИН РАЗ, сколько бы путей сюда ни вело: и по концу
# сценария, и из `_exit_tree`, когда забег оборвали посреди такта.
func _release() -> void:
	if not _held_pause:
		return
	_held_pause = false
	_running    = false
	if is_instance_valid(_spawner):
		_spawner.call("set_world_speed", 1.0)
		_spawner.call("resume_after_event")
	if is_instance_valid(_normaldo):
		_normaldo.call("set_dev_immortal", _immortal_before)

# ── Мелочи ──────────────────────────────────────────────────────────────────

func _alive() -> bool:
	return is_instance_valid(self) and is_inside_tree() \
		and is_instance_valid(_spawner) and is_instance_valid(_normaldo) \
		and not bool(_normaldo.get("_dead"))

func _send(kind: String, lane: int) -> Node:
	if not _alive():
		return null
	return _spawner.call("tutorial_send", kind, clampi(lane, 0, 4), 0.0) as Node

func _lane_of_normaldo() -> int:
	var lanes : Array = _spawner.call("_lane_centers")
	var best : int = 0
	for i in lanes.size():
		if absf(float(lanes[i]) - _normaldo.position.y) \
				< absf(float(lanes[best]) - _normaldo.position.y):
			best = i
	return best

func _no_items_of(group: String) -> bool:
	for c in _spawner.get_children():
		if c is Node and (c as Node).is_in_group(group):
			return false
	return true

# Ждать по НАСТЕННЫМ часам, а не по накопленной дельте: замедление мира на такте
# с мусором к сроку страховки отношения не имеет, а под headless дельта кадра и
# вовсе своя.
func _wait_until(cond: Callable, limit: float) -> bool:
	var t0 := Time.get_ticks_msec()
	while _alive() and not _skipped:
		if bool(cond.call()):
			return true
		if Time.get_ticks_msec() - t0 >= int(limit * 1000.0):
			return false
		await get_tree().process_frame
	return false

func _breath(sec: float) -> void:
	var t0 := Time.get_ticks_msec()
	while _alive() and not _skipped and Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		await get_tree().process_frame

# ── Подсказка на экране ─────────────────────────────────────────────────────

func _build_ui() -> void:
	_layer = CanvasLayer.new()
	SafeArea.apply(_layer)
	_layer.layer        = 95
	_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_layer)
	_build_skip()

# ── ГДЕ СТОИТ ПОДСКАЗКА ─────────────────────────────────────────────────────
# ПОД ВЕРХНЕЙ ПОЛОСОЙ, по центру. Место выбрано не из вкуса: низ экрана уже
# занят — там баннер задания дня и карточка эпизода, и подсказка ложилась прямо
# на них, буквами по буквам. Верхняя полоса, в отличие от них, стоит на месте
# весь забег, и под ней ничего не появляется само.
#
# Плашка под текстом не украшение: обучение идёт поверх ЖИВОГО забега, фон
# едет, и белые буквы на светлом кирпиче пропадают ровно в тот момент, когда их
# надо читать.
const SAY_Y : float = 56.0

func _say(big: String, small: String) -> void:
	_hush()
	var vp := get_viewport().get_visible_rect().size
	_caption = Control.new()
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption.position     = Vector2(vp.x * 0.5, SAY_Y)
	_layer.add_child(_caption)

	var plate := ColorRect.new()
	plate.color        = Color(0.04, 0.04, 0.07, 0.72)
	plate.size         = Vector2(420.0, 30.0 if small == "" else 48.0)
	plate.position     = Vector2(-210.0, -6.0)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption.add_child(plate)

	var b := _label(big, 22)
	b.position = Vector2(-260.0, -4.0)
	_caption.add_child(b)
	if small != "":
		var s := _label(small, 13)
		s.modulate  = Color(0.80, 0.80, 0.86)
		s.position  = Vector2(-260.0, 22.0)
		_caption.add_child(s)

	_caption.modulate = Color(1, 1, 1, 0.0)
	var tw := _caption.create_tween()
	tw.tween_property(_caption, "modulate:a", 1.0, 0.22)

func _label(text: String, size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", UI_FONT)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(1, 1, 1))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", 6)
	l.text                 = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size                 = Vector2(520.0, 26.0)
	l.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	return l

func _hush() -> void:
	if is_instance_valid(_caption):
		_caption.queue_free()
	_caption = null
	if is_instance_valid(_arrows):
		_arrows.queue_free()
	_arrows = null

# Две стрелки над головой и под ней, качаются врозь: показывают ось, по которой
# и ходит Нормальдо.
func _show_arrows() -> void:
	_arrows = Node2D.new()
	_layer.add_child(_arrows)
	for up in [true, false]:
		var s := Sprite2D.new()
		s.texture        = ARROW_TEX
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		# БЕЛЫМ. Стрелка нарисована зелёной — тем же цветом, что и сам Нормальдо,
		# и что половина канализации на фоне; в своём цвете она читалась как
		# часть декорации.
		s.modulate       = Color(1.0, 1.0, 1.0)
		s.scale          = Vector2(1.1, 1.1)
		s.rotation       = -PI * 0.5 if up else PI * 0.5
		s.position       = Vector2(0.0, -58.0 if up else 58.0)
		_arrows.add_child(s)
		var tw := s.create_tween().set_loops()
		var away : float = (-78.0 if up else 78.0)
		var home : float = (-58.0 if up else 58.0)
		tw.tween_property(s, "position:y", away, 0.45).set_trans(Tween.TRANS_SINE)
		tw.tween_property(s, "position:y", home, 0.45).set_trans(Tween.TRANS_SINE)

func _process(_delta: float) -> void:
	# Стрелки держатся головы: они про НЕЁ, а не про место на экране.
	if is_instance_valid(_arrows) and is_instance_valid(_normaldo):
		_arrows.position = _normaldo.position

# ── ПРОПУСТИТЬ ──────────────────────────────────────────────────────────────
# С первой секунды и не спрятанная. Игрок, который уже играл, не обязан
# доказывать это, проходя обучение целиком.
func _build_skip() -> void:
	var vp := get_viewport().get_visible_rect().size
	var root := Control.new()
	root.position = Vector2(vp.x - 118.0, vp.y - 34.0)
	root.size     = Vector2(110.0, 26.0)
	_layer.add_child(root)

	var bg := ColorRect.new()
	bg.color        = Color(0.06, 0.06, 0.10, 0.72)
	bg.size         = root.size
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)

	var l := _label("ПРОПУСТИТЬ", 11)
	l.size     = root.size
	l.position = Vector2(0.0, 4.0)
	root.add_child(l)

	var btn := Button.new()
	btn.flat       = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.size       = root.size
	btn.pressed.connect(_skip)
	root.add_child(btn)

func _skip() -> void:
	if _skipped:
		return
	_skipped = true
	_hush()
	_release()
	# Пропуск — это тоже ответ. Переспрашивать его каждый запуск значит не
	# услышать; тур по меню тоже отменяется — тот, кто отказался учиться играть,
	# не просил взамен экскурсию по кнопкам.
	SaveData.tutorial_done = true
	SaveData.menu_tips_seen["tour"] = true
	SaveData._save()
	finished.emit()
	queue_free()
