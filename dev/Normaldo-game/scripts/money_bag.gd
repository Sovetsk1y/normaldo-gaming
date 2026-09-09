extends Area2D

# ── Мешок с деньгами ──────────────────────────────────────────────────────────
# Самый редкий ресурс потока и единственный, за который надо РАБОТАТЬ. Летит
# небольшим, с числом «1» на боку и просьбой «ТАП!» над головой. Каждый тап
# прибавляет к числу единицу и чуть-чуть раздувает мешок. Поймал — получил
# столько долларов, сколько успел натапать.
#
# ── Почему так, а не «поймал и получил» ──────────────────────────────────────
# Ресурс, который просто подбирают, ничего не решает: игрок и так летит по
# экрану, и мешок оказывается на пути или не оказывается. Тапы превращают его в
# СДЕЛКУ: мешок едет мимо, и каждая секунда, потраченная на стук по нему, — это
# секунда, не потраченная на уворот. Сколько выжать и когда остановиться, решает
# игрок.
#
# Здесь была другая механика: пойманный мешок перелетал на голову и выстреливал
# долларами, которые вставали за экраном знаком валюты — $, ₽, ¥, € — и потом
# заезжали обратно. Она убрана целиком вместе с растрами знаков. Знак был
# красивым, но всё, что игрок в нём делал, — ловил доллары, как ловит их и так;
# решение он принимал ноль раз. Новый мешок спрашивает раньше и по делу.
#
# ── ЧЕМ БОЛЬШЕ, ТЕМ ОПАСНЕЕ ДЛЯ ОСТАЛЬНЫХ ───────────────────────────────────
# Раздутый мешок перестаёт быть хрупким: он не разбивается о предметы, а
# разбивает их сам. Это не бонус, а следствие — тапая, игрок делает из мешка
# таран и сам решает, насколько тяжёлый. Мешок обычного размера (никто не тапал)
# по-прежнему горит от молотова и огня, как любой ресурс.
#
# См. /Концепция/Эффекты и бонусы.md, /Концепция/Уровни/Раскладка по уровням.md

const BAG_TEX    := preload("res://assets/items/money_bag.png")
const DOLLAR_SFX := preload("res://assets/audio/dollars.mp3")
const UI_FONT    := preload("res://assets/fonts/RussoOne-Regular.ttf")
# Подсказка «тапай» — ОБЩИЙ КИРПИЧ с мини-играми (`tap_prompt.gd`): картинка
# TAP! и два тапающих пальца. «По этому надо тапать» — один приём игры, и
# показывать его двумя разными способами значит учить дважды.
const TAP_PROMPT := preload("res://scripts/tap_prompt.gd")
const TAP_W      : float = 96.0

# Стартовый размер — НЕБОЛЬШОЙ. Мешок больше не «самый крупный ресурс в потоке»:
# крупным он теперь становится, и разница между «летит мимо» и «раздули» обязана
# читаться. 52 — примерно как банан, то есть рядовой предмет.
const BAG_PX : float = 52.0
# Сколько прибавляет один тап и докуда мешок может вырасти. Потолок нужен: лейн
# 86 px, и мешок, переросший его, начинает есть соседние линии и закрывать
# половину экрана собой.
const GROW_PER_TAP : float = 0.085
const GROW_MAX     : float = 2.30

# С какого размера мешок становится тараном. Ровно «больше стандартного»: один
# тап уже делает его тяжелее обычного предмета, и это честно — игрок за него
# заплатил вниманием.
const RAM_FROM : float = 1.0 + GROW_PER_TAP * 0.5

# ── ТАПЫ ЗАМЕДЛЯЮТ ВРЕМЯ ───────────────────────────────────────────────────
# Пока по мешку стучат, мир плавно замедляется; стучат без перерыва — держится
# замедленным; перестали или стучат редко — так же плавно возвращается.
#
# ЗАЧЕМ. Мешок был сделкой «секунда стука против секунды уворота», и на бумаге
# это правильно, а в руках выходила нервотрёпка: за то время, что мешок пересекал
# экран, набивалось восемь-двенадцать долларов, и всё это — вслепую, потому что
# смотреть надо было на поток. Игрок платил вниманием дважды и оба раза не по
# делу.
#
# Замедление возвращает сделке смысл. Цена та же — ты стоишь и стучишь вместо
# того, чтобы уворачиваться, — но теперь у тебя есть чем расплатиться: время,
# которое ты сам и растянул. Успеть натапать И поймать становится возможным, а
# не «повезло с траекторией».
#
# ── ПОЧЕМУ ЗАРЯД, А НЕ ТАЙМЕР ПОСЛЕ ТАПА ───────────────────────────────────
# Заряд копится с каждого тапа и всё время утекает сам. Из одного этого выходят
# сразу все три поведения, которых мы хотим, и ни одно не пришлось описывать
# отдельно:
#
#   часто тапаешь  — приход обгоняет утечку, заряд у потолка, замедление держится;
#   редко тапаешь  — утечка обгоняет приход, замедление само отползает назад;
#   перестал       — остаётся одна утечка, мир плавно возвращается к своей скорости.
#
# Таймер «замедление на N секунд после тапа» дал бы то же самое только для
# первого случая, а на границе — мигание: успел в окно / не успел.
const SLOW_FLOOR      : float = 0.34   # куда доходит время на полном заряде
const CHARGE_PER_TAP  : float = 0.20   # сколько добавляет один тап
const CHARGE_DECAY    : float = 0.62   # и сколько утекает за секунду
# Насколько быстро фактическая скорость догоняет заряд. Отдельно от заряда,
# потому что резкий тап не должен давать рывка времени: замедление обязано
# ВПОЛЗАТЬ, иначе первый же тап читается как подвисание игры.
const SLOW_EASE       : float = 3.2

var _charge   : float = 0.0
var _world_k  : float = 1.0
var _holding  : bool  = false   # держим ли мы сейчас паузу потока

@export var speed : float = 250.0

var _taps      : int   = 1     # число на боку и будущая выплата
var _grow      : float = 1.0   # множитель размера
var _bag_scale : float = 1.0
var _pulse_t   : float = 0.0
var _spent     : bool  = false # поймали или сожгли — второй раз не считается

var _lbl    : Label  = null
var _prompt : Node2D = null

@onready var _sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	_sprite.texture = BAG_TEX
	_bag_scale      = ItemSizing.content_scale(BAG_TEX, BAG_PX)
	collision_layer = 2
	# МАСКА НЕ НУЛЕВАЯ, в отличие от прочих предметов: раздутый мешок обязан САМ
	# видеть, во что врезался, иначе таранить ему нечего — предметы друг друга не
	# замечают, их замечает только Нормальдо.
	collision_mask  = 2
	add_to_group("money_bag")
	# Ловим тапы: в этом вся механика.
	input_pickable  = true
	input_event.connect(_on_input)
	area_entered.connect(_on_area)

	$CollisionShape2D.shape = CircleShape2D.new()

	# Число на боку. Оно и есть выплата, поэтому стоит на самом мешке, а не над
	# ним: цифра в стороне читалась бы как счётчик чего-то другого.
	_lbl = Label.new()
	_lbl.add_theme_font_override("font", UI_FONT)
	_lbl.add_theme_font_size_override("font_size", 20)
	_lbl.add_theme_color_override("font_color", Color(1.00, 0.97, 0.72))
	_lbl.add_theme_color_override("font_outline_color", Color(0.06, 0.05, 0.02))
	_lbl.add_theme_constant_override("outline_size", 6)
	_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_lbl.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	add_child(_lbl)

	_prompt = Node2D.new()
	_prompt.set_script(TAP_PROMPT)
	add_child(_prompt)
	_prompt.call("setup", TAP_W)

	_resize()

# Размер, коллизия, число и место подсказки — ОДНОЙ функцией. Их четверо, они
# завязаны на один множитель, и разъехавшись дают мешок, который бьётся мимо
# себя: рисунок вырос, круг подбора остался прежним.
func _resize() -> void:
	var k : float = _bag_scale * _grow
	_sprite.scale = Vector2.ONE * k
	var px : float = BAG_PX * _grow
	($CollisionShape2D.shape as CircleShape2D).radius = px * 0.46
	_lbl.text     = str(_taps)
	_lbl.size     = Vector2(70.0, 30.0)
	_lbl.position = Vector2(-35.0, -15.0)
	if is_instance_valid(_prompt):
		# Над мешком и с запасом на собственную высоту подсказки: пальцы торчат
		# выше картинки, и без запаса нижний палец лез бы на сам мешок.
		_prompt.position = Vector2(0.0, -px * 0.55 - float(_prompt.call("half_height")) * 0.45)

func _process(delta: float) -> void:
	ItemFlow.advance(self, speed, delta)
	_drive_time(delta)
	if ItemFlow.gone(self, 200.0):
		queue_free()
		return
	# Пульс — реклама: мешок стоит на линии один и должен быть замечен раньше,
	# чем поравняется с головой.
	_pulse_t      += delta * 3.5
	_sprite.scale  = Vector2.ONE * _bag_scale * _grow * (1.0 + sin(_pulse_t) * 0.10)

# ── ВЕДЁМ ВРЕМЯ ────────────────────────────────────────────────────────────
# Считает МЕШОК, а не спавнер, и это не случайность: спавнер на время события
# снимает себе `_process` (`pause_for_event`), и вести из него плавное значение
# было бы нечем. Мешок живёт своей обработкой и потому может вести его до конца —
# в том числе тогда, когда поток стоит.
func _drive_time(delta: float) -> void:
	# Заряд утекает ВСЕГДА, приходит только с тапов. Отсюда и «держится, пока
	# стучишь»: держит его не флаг, а перевес прихода над утечкой.
	_charge = maxf(0.0, _charge - CHARGE_DECAY * delta)
	var want : float = lerpf(1.0, SLOW_FLOOR, clampf(_charge, 0.0, 1.0))
	_world_k = lerpf(_world_k, want, clampf(SLOW_EASE * delta, 0.0, 1.0))

	var sp := get_parent()
	if sp == null or not sp.has_method("set_world_speed"):
		return
	# Порог, а не точное сравнение: значение подползает к единице асимптотически и
	# без порога мешок держал бы поток на паузе до самого края экрана.
	if _world_k < 0.985 and not _spent:
		if not _holding:
			_holding = true
			# ПОТОК ВСТАЁТ на время замедления — по той же причине, что и у
			# песочных часов: паттерн захватывает скорость один раз в начале и
			# продолжил бы сыпать колонки прежним темпом, а ехали бы они медленно,
			# то есть налезали бы друг на друга. Заодно это и есть та передышка,
			# ради которой всё затевалось.
			sp.call("pause_for_event")
		sp.call("set_world_speed", _world_k)
	elif _holding:
		_release_time()

# Вернуть миру скорость и отдать паузу. Зовётся и по затуханию заряда, и при
# поимке, и из `_exit_tree`: мешок, исчезнувший с зажатой паузой, заморозил бы
# поток до конца забега, а такое не чинится ничем, кроме следующего босса.
func _release_time() -> void:
	if not _holding:
		return
	_holding = false
	_charge  = 0.0
	_world_k = 1.0
	var sp := get_parent()
	if sp != null and sp.has_method("set_world_speed"):
		sp.call("set_world_speed", 1.0)
		sp.call("resume_after_event")

func _exit_tree() -> void:
	_release_time()

func _on_input(_vp: Node, ev: InputEvent, _shape_idx: int) -> void:
	var pressed := (ev is InputEventScreenTouch and (ev as InputEventScreenTouch).pressed) \
		or (ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed \
			and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT)
	if pressed:
		tap()

# Публичный: им же пользуется тест.
func tap() -> void:
	if _spent or _grow >= GROW_MAX:
		return
	_taps += 1
	_grow  = minf(GROW_MAX, _grow + GROW_PER_TAP)
	# Заряд времени копится ТОЛЬКО пока мешок ещё растёт: до потолка размера сюда
	# просто не доходит (выход стоит в начале функции). Это осознанно — доросший
	# мешок больше не растёт и не платит, и тянуть за него время значило бы делать
	# вид, что тапать по нему всё ещё есть зачем.
	_charge = minf(1.0, _charge + CHARGE_PER_TAP)
	_resize()
	# Отклик на тап — короткий подскок числа. Без него прибавка читается только
	# по цифре, а цифра мелкая и на ходу её не поймать.
	var tw := _lbl.create_tween()
	tw.tween_property(_lbl, "scale", Vector2(1.35, 1.35), 0.07)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_lbl, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_SINE)

# Сколько мешок сейчас стоит.
func payout() -> int:
	return _taps

# Раздут ли он настолько, чтобы таранить.
func is_ram() -> bool:
	return _grow >= RAM_FROM

# Дорос ли до потолка. С этого момента тапы не делают НИЧЕГО: ни размера, ни
# выплаты, ни замедления. Публичный, потому что этим и кончается взаимодействие,
# и проверять это надо снаружи, а не по трём полям сразу.
func is_maxed() -> bool:
	return _grow >= GROW_MAX

# ── Таран ────────────────────────────────────────────────────────────────────
# Раздутый мешок ломает то, во что врезался, и летит дальше. Ресурсы он НЕ
# трогает: снести пиццу по дороге к счётчику — это отнять у игрока то, за что он
# и тапал.
const RAM_BREAKS : Array = ["obstacle", "slowing", "fire"]

func _on_area(other: Area2D) -> void:
	if _spent or not is_ram() or not is_instance_valid(other):
		return
	var hit := false
	for g in RAM_BREAKS:
		if other.is_in_group(g):
			hit = true
	if not hit:
		return
	if other.has_method("knock_down"):
		other.call("knock_down")
	elif other.has_method("on_hit"):
		other.call("on_hit")
	else:
		other.queue_free()

# ── Поимка ───────────────────────────────────────────────────────────────────
# `mult` — пиратские ×2. `catcher` может быть null: мешок ловит не только
# Нормальдо, его ещё жжёт огонь и молотов (`fire.gd` зовёт `burst()` без
# аргументов). Сгоревший мешок не платит — потому раздутый и не горит.
func burst(mult: int = 1, catcher: Node2D = null) -> int:
	if _spent:
		return 0
	# РАЗДУТЫЙ НЕ СГОРАЕТ. Огонь зовёт эту же функцию без ловца; для обычного
	# мешка это «сгорел и пропал», а для раздутого — ничего: он таран, и горящий
	# предмет он ломает сам (см. `_on_area`).
	if catcher == null and is_ram():
		return 0
	_spent          = true
	collision_layer = 0
	input_pickable  = false
	# Время отпускаем СРАЗУ, а не по затуханию заряда: мешка больше нет, тапать
	# нечего, и держать мир замедленным было бы наградой ни за что.
	_release_time()
	if is_instance_valid(_prompt):
		_prompt.call("dismiss", 0.12)

	var paid : int = 0
	if is_instance_valid(catcher):
		paid = _taps * maxi(1, mult)
		var audio := AudioStreamPlayer.new()
		audio.stream = DOLLAR_SFX
		get_parent().add_child(audio)
		audio.play()
		audio.finished.connect(audio.queue_free)

	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2.ZERO, 0.22)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)
	return paid

# Попадает ли точка в тело мешка — Нормальдо спрашивает, чтобы не считать тап по
# мешку за дабл-тап спелла. Тот же приём, что был у конуса, пока по нему тапали:
# один жест не должен значить двух разных действий.
func contains_point(p: Vector2) -> bool:
	var shape : Shape2D = $CollisionShape2D.shape
	if shape == null:
		return false
	var r : float = (shape as CircleShape2D).radius + 14.0
	return (p - global_position).length() <= r
