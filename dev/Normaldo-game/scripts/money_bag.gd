extends Area2D

# ── Мешок с деньгами ──────────────────────────────────────────────────────────
# Самый редкий ресурс потока (1.5 % ресурсных спавнов) и единственный, который
# платит не собой, а СОБЫТИЕМ: пойманный мешок перелетает Нормальдо на голову и
# выстреливает долларами ВПЕРЁД, за правый край экрана. Там они встают знаком
# валюты — $, ₽, ¥ или € — и через секунду знак заезжает обратно в кадр.
#
# Раньше он просто рассыпал восемь долларов по случайным высотам. Это читалось
# как «мешок лопнул», а не как награда: россыпь неотличима от обычного потока
# долларов, только гуще. Знак — читаемая форма, за ним видно, что это твоя
# добыча, и собирать его интереснее: доллары стоят по всем пяти лейнам, и
# сколько ты из знака вынесешь — вопрос того, как поведёшь голову.
#
# Сколько платит. В знаке пятнадцать-семнадцать долларов, но забрать все нельзя:
# знак проезжает мимо один раз, и больше семи-восьми штук из него не вынуть даже
# идеальным ходом. Прежние восемь гарантированных превратились в те же восемь,
# но заработанных.
#
# См. /Концепция/Эффекты и бонусы.md, /Концепция/Уровни/Раскладка по уровням.md

const BAG_TEX    := preload("res://assets/items/money_bag.png")
const DOLLAR_TEX := preload("res://assets/items/dollar.png")
const DOLLAR_SFX := preload("res://assets/audio/dollars.mp3")
const ITEM_SCENE := preload("res://scenes/item.tscn")

const DOLLAR_SCALE := 0.36

# Мешок — САМЫЙ КРУПНЫЙ ресурс в потоке, и это его единственная реклама. Он
# стоит на линии один и обещает знак денег во весь экран; чтобы за ним имело
# смысл лететь через полэкрана, его надо УВИДЕТЬ раньше, чем он поравняется с
# головой.
#
# Раньше здесь стоял голый scale 0.36 по кадру 90×83 — то есть 32 пикселя
# рисунка, меньше банана (52) и вдвое меньше предмета-эффекта (58). Джекпот
# выглядел мелочью. Теперь размер считает ItemSizing по РИСУНКУ, как у всех
# остальных предметов.
#
# 74, а не 84: с пульсом ±12 % мешок доходил до 94 пикселей при лейне в 86 и
# начинал лезть в соседние линии — на экране это уже не «крупный ресурс», а
# предмет не своего масштаба. Сейчас потолок пульса 83, и он остаётся в лейне.
const BAG_PX : float = 74.0

# ── Знаки валют ───────────────────────────────────────────────────────────────
# Сетка 5×7 — та же, что у букв NORMALDO (`spawner.LETTER_GLYPHS`), и по той же
# причине: это минимальный растр, в котором знак ещё читается. Словарь общий
# намеренно — знак из долларов и буква из долларов обязаны быть одной породы,
# иначе на экране заводятся два разных «шрифта».
#
# Клеток в знаках 15–17 — разброс держится в две штуки НАМЕРЕННО: выплата мешка
# почти не зависит от того, какой знак выпал, и «повезло» относится к встрече с
# мешком, а не к жеребьёвке внутри него. Ровно поровну не выходит: знак рисуется
# в пять клеток шириной, и втискивать в один растр и S доллара, и две палки иены
# с одинаковым числом точек — значит портить рисунок ради арифметики.
#
# Рисунки ЛЁГКИЕ: у доллара и рубля вокруг обводки оставлен воздух. Первая
# версия шла жирными строками по четыре-пять клеток, и знак из долларов,
# сложенный из долларов же, превращался в зелёное пятно — читалась одна иена,
# потому что она из прямых.
const GLYPHS : Dictionary = {
	"dollar": ["..X..", ".XXX.", "X.X..", ".XXX.", "..X.X", ".XXX.", "..X.."],
	"ruble":  ["XXX..", "X..X.", "X..X.", "XXX..", "X....", "XXX..", "X...."],
	"yen":    ["X...X", ".X.X.", "..X..", "XXXXX", "..X..", "XXXXX", "..X.."],
	"euro":   ["..XXX", ".X...", "XXXX.", "X....", "XXXX.", ".X...", "..XXX"],
}
const GLYPH_ROWS : int = 7
const GLYPH_COLS : int = 5
# Какую долю высоты экрана занимает знак. Чуть меньше букв NORMALDO (0.86) —
# намеренно: буква ЗАМОРАЖИВАЕТ поток и означает «уровень стал короче на одну»,
# а знак приходит посреди потока и означает только деньги. Путать эти два
# события нельзя, и первое, чем они различаются, — рост.
#
# Ниже не опустить, не уменьшив сами доллары: клетка выходит 50 px при рисунке
# доллара в 36, и это ровно тот зазор, при котором знак ещё читается формой.
# Первая версия стояла на 0.66 — клетки 40 px, доллары касались друг друга, и
# знак из долларов, сложенный из долларов же, превращался в зелёное пятно.
const GLYPH_H_FRAC : float = 0.82
# Отступ первого столбца от правого края. Знак обязан встать ЦЕЛИКОМ за кадром:
# собранный на глазах у игрока, он читался бы как «доллары появились из
# воздуха», а не как «мешок выстрелил ими вперёд».
const GLYPH_MARGIN : float = 120.0

# Полёт доллара из мешка в свою клетку.
const SHOT_STEP : float = 0.022   # с, между соседними выстрелами
const SHOT_FLY  : float = 0.34    # с, сам полёт последнего из них

# Перелёт мешка на голову — тот же такт, что у мэджик бокса.
const HEAD_OFFSET : Vector2 = Vector2(0.0, -62.0)
const HOP_T       : float   = 0.18

@export var speed: float = 250.0

var _burst_done : bool  = false
var _pulse_t    : float = 0.0
# Базовый масштаб, вокруг которого дышит пульс. Держим числом, а не пересчётом
# каждый кадр: пульс умножает именно его.
var _bag_scale  : float = 1.0
var _carrier    : Node2D = null   # голова, на которой сидит мешок, пока стреляет

@onready var _sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	_sprite.texture  = BAG_TEX
	_bag_scale       = ItemSizing.content_scale(BAG_TEX, BAG_PX)
	_sprite.scale    = Vector2.ONE * _bag_scale
	collision_layer  = 2
	collision_mask   = 0
	add_to_group("money_bag")
	var circle       := CircleShape2D.new()
	# Зона подбора едет за рисунком: у мешка это ресурс, и промахнуться мимо
	# нарисованного из-за того, что круг остался от прежнего размера, — худший
	# вид несправедливости.
	circle.radius     = BAG_PX * 0.46
	$CollisionShape2D.shape = circle

func _process(delta: float) -> void:
	if _burst_done:
		# Пока стреляет — сидит на голове и едет вместе с ней.
		if is_instance_valid(_carrier):
			position = _carrier.position + HEAD_OFFSET
		return
	position.x -= speed * delta
	if position.x < -200.0:
		queue_free()
		return
	_pulse_t      += delta * 3.5
	_sprite.scale  = Vector2.ONE * _bag_scale * (1.0 + sin(_pulse_t) * 0.12)

# `catcher` — тот, кто поймал. Мешок может лопнуть и БЕЗ него: его жжёт молотов
# и сносит огонь (`fire.gd` зовёт burst() без аргументов). Тогда перелёта на
# голову нет, и знак выстреливается с того места, где мешок сгорел.
func burst(mult: int = 1, catcher: Node2D = null) -> void:
	if _burst_done:
		return
	_burst_done     = true
	collision_layer = 0

	var audio := AudioStreamPlayer.new()
	audio.stream = DOLLAR_SFX
	get_parent().add_child(audio)
	audio.play()
	audio.finished.connect(audio.queue_free)

	if is_instance_valid(catcher):
		_carrier = catcher
		var hop := create_tween()
		hop.tween_property(self, "position", catcher.position + HEAD_OFFSET, HOP_T)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		await hop.finished
		if not is_inside_tree():
			return

	# Множитель (пиратские ×2) выкладывает ВТОРОЙ знак — другой и правее
	# первого, а не вдвое больше долларов в том же. Удвоенная выплата обязана
	# быть видна как удвоенная, иначе пассивка работает молча.
	var names : Array = GLYPHS.keys()
	names.shuffle()
	for copy in maxi(1, mult):
		if not is_inside_tree():
			return
		await _shoot_glyph(String(names[copy % names.size()]), copy)

	if not is_inside_tree():
		return
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2.ZERO, 0.22)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)

# Выстреливает один знак. Доллары уходят ВЕЕРОМ — по одному, с шагом SHOT_STEP,
# — но приземляются РАЗОМ: длительность полёта у каждого своя и подобрана так,
# чтобы все встали в одну секунду. Иначе знак приезжает перекошенным: первые
# доллары уже поехали влево с потоком, пока последние ещё летят вправо.
func _shoot_glyph(glyph_name: String, copy_idx: int) -> void:
	var vp    := get_viewport_rect().size
	var glyph : Array = GLYPHS.get(glyph_name, GLYPHS["dollar"])
	var cell  : float = vp.y * GLYPH_H_FRAC / float(GLYPH_ROWS)
	var top   : float = (vp.y - cell * float(GLYPH_ROWS)) * 0.5 + cell * 0.5
	# Второй знак встаёт за первым с пробелом в полторы клетки: без пробела два
	# знака слипаются в один нечитаемый ком.
	var left  : float = vp.x + GLYPH_MARGIN \
		+ float(copy_idx) * cell * (float(GLYPH_COLS) + 1.5)

	var cells : Array = []
	for row in GLYPH_ROWS:
		var line : String = glyph[row]
		for col in GLYPH_COLS:
			if col < line.length() and line[col] == "X":
				cells.append(Vector2(left + float(col) * cell,
					top + float(row) * cell))
	# Порядок вылета случайный: по строкам знак «печатался» бы сверху вниз, и
	# выстрел читался бы как построчная выкладка, а не как залп.
	cells.shuffle()

	var total : float = SHOT_FLY + float(cells.size() - 1) * SHOT_STEP
	for i in cells.size():
		if not is_inside_tree():
			return
		_shoot_one(cells[i], total - float(i) * SHOT_STEP)
		await get_tree().create_timer(SHOT_STEP).timeout
	# Ждём приземления последнего — знак должен стоять целиком к тому моменту,
	# когда мешок исчезнет.
	await get_tree().create_timer(SHOT_FLY).timeout

func _shoot_one(to: Vector2, fly_t: float) -> void:
	var parent := get_parent()
	if parent == null:
		return
	var dollar        := ITEM_SCENE.instantiate()
	dollar.speed       = speed
	dollar.is_eatable  = false
	dollar.damage      = 0
	dollar.rotates     = true
	dollar.pulses      = true
	dollar.item_group  = "dollar"
	var spr: Sprite2D  = dollar.get_node("Sprite2D")
	spr.texture        = DOLLAR_TEX
	spr.scale          = Vector2.ONE * DOLLAR_SCALE
	dollar.position    = position
	parent.add_child(dollar)

	# Пока летит вперёд — не двигается сам и не ловится: доллар, пойманный на
	# пути ЗА экран, обесценил бы весь такт (поймал мешок — сразу и деньги).
	dollar.set_process(false)
	var had_layer : int = dollar.collision_layer
	dollar.collision_layer = 0

	var tw := dollar.create_tween()
	tw.tween_property(dollar, "position", to, fly_t)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void:
		if not is_instance_valid(dollar):
			return
		dollar.collision_layer = had_layer
		dollar.set_process(true))
