extends Node2D

# ── Денежное облако с сюжетной строкой ───────────────────────────────────────
# Влетает справа сразу после броска пульта, тормозит посреди экрана, висит
# несколько секунд с надписью и уходит дальше влево.
#
# ── Зачем оно вообще ─────────────────────────────────────────────────────────
# Сюжетную строку эпизода («Выберись из канализации») показывает занавес между
# эпизодами. Но у ПЕРВОГО эпизода занавеса нет и быть не должно: занавес
# прикрывает подмену фона, а первый эпизод начинается на том же фоне, на котором
# доиграло интро, — прикрывать нечего, и лишняя шторка после прыжка с дивана
# читалась бы как заминка.
#
# Значит первому эпизоду нужен свой способ сказать то же самое, и он не должен
# останавливать игру: забег уже идёт, Нормальдо летит. Облако — единственное,
# что здесь подходит: оно ЛЕТИТ ВМЕСТЕ С МИРОМ, как всё остальное на экране, и
# потому не воспринимается как окно поверх игры.
#
# ── Почему облако, а не панель с текстом ─────────────────────────────────────
# Панель — это интерфейс, и посреди начавшегося забега она означала бы «игра
# остановлена». Куча долларов — предмет того же мира, что и поток: она приезжает
# справа с той же стороны, что и всё, и уезжает влево, никого не задев.
#
# Столкновений у облака нет вовсе: это Node2D со спрайтами, без Area2D. Поймать
# его нельзя, разбить нельзя, урона оно не наносит — иначе первые же секунды
# первого эпизода превратились бы в ловушку из ничего.
const DOLLAR_TEX := preload("res://assets/items/dollar.png")
const UI_FONT    := preload("res://assets/fonts/RussoOne-Regular.ttf")

# Размер облака в пикселях экрана. Оно должно быть заметно шире надписи, иначе
# читается не как облако с текстом, а как текст, вокруг которого что-то насыпано.
const CLOUD_W : float = 380.0
const CLOUD_H : float = 170.0
const BILLS   : int   = 30
const BILL_PX : float = 40.0

# Хореография. Влёт длиннее вылета: приезд надо успеть заметить и прочитать, а
# уезд уже ничего не сообщает.
const FLY_IN  : float = 1.05
const HOLD    : float = 2.60
const FLY_OUT : float = 0.85

# Где облако останавливается — доля ширины экрана. Правее середины: слева в этот
# момент летит сам Нормальдо, и вставать ему на голову облако не должно.
const HOLD_X_RATIO : float = 0.60
const HOLD_Y_RATIO : float = 0.34

# Выше предметов потока, но ниже интерфейса забега.
const Z : int = 30

var _bills : Array = []

# Собрать и запустить. `story` пустая — не показываем вовсе: облако без текста
# это просто мусор, пролетевший через экран.
#
# Называется `spawn`, а НЕ `show`: `show()` уже есть у CanvasItem, и статический
# метод с тем же именем не даёт скрипту скомпилироваться вовсе.
static func spawn(parent: Node, story: String) -> Node2D:
	if parent == null or not is_instance_valid(parent) or story.strip_edges().is_empty():
		return null
	var c := new()
	parent.add_child(c)
	c.call("_run", story)
	return c

func _run(story: String) -> void:
	z_index = Z
	var vp : Vector2 = get_viewport_rect().size
	var home := Vector2(vp.x * HOLD_X_RATIO, vp.y * HOLD_Y_RATIO)
	position = Vector2(vp.x + CLOUD_W, home.y)

	_build_bills()
	_build_label(story)

	# Влёт с торможением, стоянка, вылет с разгоном. Разные кривые нарочно:
	# одинаковые превратили бы пролёт в равномерное скольжение, в котором
	# остановки не видно.
	var tw := create_tween()
	tw.tween_property(self, "position:x", home.x, FLY_IN)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_interval(HOLD)
	tw.tween_property(self, "position:x", -CLOUD_W, FLY_OUT)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)

# Купюры раскиданы ВНУТРИ ЭЛЛИПСА и гуще к центру: равномерная россыпь по
# прямоугольнику читается как сетка, а не как облако.
func _build_bills() -> void:
	var ts : Vector2 = DOLLAR_TEX.get_size()
	for i in BILLS:
		var a := randf() * TAU
		# Корень от случайного числа даёт равномерность по площади; без него
		# точки сбиваются в центр и края облака оказываются пустыми.
		var r := sqrt(randf())
		var b := Sprite2D.new()
		b.texture        = DOLLAR_TEX
		b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var px : float = BILL_PX * randf_range(0.65, 1.25)
		b.scale          = Vector2.ONE * (px / maxf(ts.x, ts.y))
		b.position       = Vector2(cos(a) * r * CLOUD_W * 0.5, sin(a) * r * CLOUD_H * 0.5)
		b.rotation       = randf_range(-0.6, 0.6)
		b.modulate       = Color(1, 1, 1, randf_range(0.75, 1.0))
		# Ближние к центру — ПОД надписью, дальние поверх: так текст лежит внутри
		# облака, а не поверх плоской кучи.
		b.z_index        = -1 if r < 0.55 else 1
		add_child(b)
		_bills.append(b)
		# Каждая купюра дышит по-своему. Общая анимация на всё облако выглядела
		# бы как дрожащая картинка, а не как ворох бумажек в воздухе.
		var bob := b.create_tween().set_loops()
		var dy  : float = randf_range(4.0, 11.0)
		var t   : float = randf_range(0.7, 1.4)
		bob.tween_property(b, "position:y", b.position.y + dy, t)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		bob.tween_property(b, "position:y", b.position.y, t)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		var spin := b.create_tween().set_loops()
		spin.tween_property(b, "rotation", b.rotation + randf_range(-0.35, 0.35),
			randf_range(1.1, 2.0)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		spin.tween_property(b, "rotation", b.rotation,
			randf_range(1.1, 2.0)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

# Надпись с ЖИРНОЙ обводкой: она лежит на пёстрой куче зелёных бумажек, и без
# обводки буквы теряются в них целиком.
func _build_label(story: String) -> void:
	var l := Label.new()
	l.add_theme_font_override("font", UI_FONT)
	l.add_theme_font_size_override("font_size", 21)
	l.add_theme_color_override("font_color", Color(1.00, 0.97, 0.85))
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.02))
	l.add_theme_constant_override("outline_size", 8)
	l.text                 = story
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode        = TextServer.AUTOWRAP_WORD_SMART
	l.size                 = Vector2(CLOUD_W, 60.0)
	l.position             = Vector2(-CLOUD_W * 0.5, -30.0)
	l.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	l.z_index              = 2
	add_child(l)
