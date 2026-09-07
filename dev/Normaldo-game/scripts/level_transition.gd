class_name LevelTransition
extends CanvasLayer

# ── Переход «немного позднее» ────────────────────────────────────────────────
# Забег ЛЮБОГО эпизода начинается дома: Нормальдо сидит на диване, швыряет пульт
# в телевизор и спрыгивает. Это верно — домой он возвращается между эпизодами, —
# но фон второго и третьего эпизода не квартира, и до сих пор он подменялся
# ПРЯМО ПОД ИГРОКОМ: интро доигрывало на одном фоне, и следующим же кадром за
# спиной оказывался другой. Читалось это как сбой отрисовки, а не как «прошло
# время».
#
# Теперь между ними стоит занавес: диагональная шторка накрывает экран, под ней
# меняется всё, что должно поменяться, и по центру написано, что произошло, —
# «НЕМНОГО ПОЗДНЕЕ…». Смена декораций за занавесом — приём старый и понятный без
# объяснений; смена декораций на глазах у зрителя — это оговорка.
#
# Шейдер — из присланного набора TransitionKit (assets/transitions). Взята
# диагональная шторка из треугольников: она читается как «время идёт» лучше
# кругов и полос, потому что у неё есть направление.
#
# Всё остальное строится КОДОМ, а не сценой из набора: демо-сцена набора носит
# в себе своё разрешение, свой цвет и свои градиенты, и половина из этого нам
# мешает. Шейдеру нужны две текстуры-градиента, и обе описываются тремя
# строчками каждая.

const SHADER := preload("res://assets/transitions/transition.gdshader")

# Слой выше всего игрового и выше карточек уровня (96): занавес обязан накрывать
# и их тоже, иначе титр уровня останется висеть поверх шторки.
const LAYER : int = 118

const COVER_T  : float = 0.55    # сколько шторка закрывается
const HOLD_T   : float = 1.10    # сколько висит надпись
const REVEAL_T : float = 0.55    # сколько открывается
# Пауза ПОСЛЕ интро и до шторки. Без неё занавес наезжает на последний кадр
# прыжка с дивана, и прыжок читается как оборванный.
const AFTER_INTRO_T : float = 1.0

const COL_CURTAIN : Color = Color(0.48, 0.33, 0.80)
const COL_TEXT    : Color = Color(1.00, 0.97, 0.88)
const COL_STORY   : Color = Color(1.00, 0.90, 0.55)

const UI_FONT := preload("res://assets/fonts/RussoOne-Regular.ttf")
const DOLLAR_TEX := preload("res://assets/items/dollar.png")

# ── Доллары через экран ──────────────────────────────────────────────────────
# Занавес закрыт около полутора секунд, и всё это время на нём не происходило
# ничего: сплошная заливка с надписью. Пауза вместо события. Деньги — то, ради
# чего забег и идёт, и они же связывают конец одного эпизода с началом
# следующего.
#
# Летят СЛЕВА НАПРАВО, против хода забега. В забеге всё несётся навстречу игроку
# справа; пустив деньги туда же, переход сказал бы «уровень продолжается», а он
# говорит обратное — этот кончился.
#
# Функция статическая и живёт здесь, потому что переходов ДВА: занавес между
# эпизодами (этот файл) и карточка уровня в бесконечном (`hud._show_level_card`).
# Два дождя из денег, написанные по отдельности, разошлись бы плотностью и
# скоростью, и переходы перестали бы выглядеть родственниками.
const BILLS   : int   = 34
const BILL_PX : float = 34.0
const FLY_MIN : float = 0.85
const FLY_MAX : float = 1.70

# Возвращает созданные купюры: вызывающий обязан убрать их, когда экран начнёт
# открываться. Оставленные на виду, они полсекунды летели бы уже поверх живого
# забега — как мусор, забытый на экране.
static func rain_dollars(parent: Node, vp: Vector2, z: int = 1) -> Array:
	var made : Array = []
	for i in BILLS:
		var b := Sprite2D.new()
		b.texture        = DOLLAR_TEX
		b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var px : float = BILL_PX * randf_range(0.7, 1.35)
		var ts : Vector2 = DOLLAR_TEX.get_size()
		b.scale          = Vector2.ONE * (px / maxf(ts.x, ts.y))
		b.z_index        = z
		b.modulate       = Color(1, 1, 1, randf_range(0.45, 1.0))
		b.rotation       = randf_range(-0.5, 0.5)
		b.process_mode   = Node.PROCESS_MODE_ALWAYS
		b.position       = Vector2(-80.0 - randf_range(0.0, vp.x),
			randf_range(-40.0, vp.y + 40.0))
		parent.add_child(b)
		var tw := b.create_tween().set_loops().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw.tween_property(b, "position:x", vp.x + 120.0, randf_range(FLY_MIN, FLY_MAX))\
			.from(b.position.x)
		# Крутится на лету: плоская купюра, ползущая по прямой, читается как
		# спрайт, забытый на экране.
		var spin := b.create_tween().set_loops().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		spin.tween_property(b, "rotation",
			b.rotation + TAU * (1.0 if i % 2 == 0 else -1.0), randf_range(1.4, 2.6))
		made.append(b)
	return made

# Занавес: закрыться, дать сменить всё под собой, открыться.
#
# `on_covered` зовётся РОВНО в тот момент, когда экран закрыт полностью. Это и
# есть весь смысл: вызывающему не нужно самому угадывать, когда менять фон.
# `story` — вторая строка под надписью: ЗАЧЕМ игрок сюда бежит («Найди дорогу к
# клубу»). Название эпизода говорит, где он; без этой строки кампания читается
# как набор декораций, а не как дорога куда-то.
static func play(host: Node, caption: String, on_covered: Callable,
		story: String = "") -> void:
	if host == null or not is_instance_valid(host):
		if on_covered.is_valid():
			on_covered.call()
		return
	var t := LevelTransition.new()
	host.add_child(t)
	await t._run(caption, on_covered, story)
	if is_instance_valid(t):
		t.queue_free()

var _rect : ColorRect = null

func _run(caption: String, on_covered: Callable, story: String = "") -> void:
	layer = LAYER
	# Переход обязан идти и на паузе, и до включения управления: он часть
	# сцены, а не часть геймплея.
	process_mode = Node.PROCESS_MODE_ALWAYS
	var vp : Vector2 = get_viewport().get_visible_rect().size

	_rect = ColorRect.new()
	_rect.size          = vp
	_rect.color         = Color(1, 1, 1, 1)   # цвет берёт шейдер, не сам прямоугольник
	_rect.mouse_filter  = Control.MOUSE_FILTER_STOP   # тапы сквозь занавес не идут
	_rect.material      = _make_material(vp)
	add_child(_rect)

	var lbl := Label.new()
	lbl.add_theme_font_override("font", UI_FONT)
	lbl.add_theme_font_size_override("font_size", 30)
	lbl.text                 = caption
	lbl.modulate             = Color(COL_TEXT.r, COL_TEXT.g, COL_TEXT.b, 0.0)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl.size                 = vp
	lbl.z_index              = 3
	lbl.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	add_child(lbl)

	# Сюжетная строка под надписью. Пустую не рисуем вовсе: пустой Label съел бы
	# место и сдвинул бы главную надпись вверх без причины.
	var story_lbl : Label = null
	if not story.strip_edges().is_empty():
		# Главная надпись центрирована по всему экрану, поэтому вторую ставим
		# ровно под неё — от центра вниз на высоту строки с запасом.
		story_lbl = Label.new()
		story_lbl.add_theme_font_override("font", UI_FONT)
		story_lbl.add_theme_font_size_override("font_size", 17)
		story_lbl.text                 = story
		story_lbl.modulate             = Color(COL_STORY.r, COL_STORY.g, COL_STORY.b, 0.0)
		story_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		story_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		story_lbl.size                 = Vector2(vp.x, 26.0)
		story_lbl.position             = Vector2(0.0, vp.y * 0.5 + 30.0)
		story_lbl.z_index              = 3
		story_lbl.mouse_filter         = Control.MOUSE_FILTER_IGNORE
		add_child(story_lbl)

	# ── Закрываемся ──────────────────────────────────────────────────────────
	await _tween_factor(0.0, 1.0, COVER_T)

	# Экран закрыт — вот теперь можно менять всё, что меняется.
	if on_covered.is_valid():
		on_covered.call()

	# Деньги пускаем ТОЛЬКО ЗА ЗАКРЫТЫМ ЗАНАВЕСОМ. Запусти их раньше — полсекунды
	# закрытия они летели бы поверх живого забега, и переход начинался бы с
	# мусора на экране вместо шторки. Слой у них ПОД текстом (z = 1 против 3), но
	# поверх шторки: шторка — это сам `_rect` с z = 0.
	var bills : Array = rain_dollars(self, vp, 1)

	var tw := create_tween()
	tw.tween_property(lbl, "modulate:a", 1.0, 0.22)
	if story_lbl != null:
		# Сюжетная строка появляется ЧУТЬ ПОЗЖЕ главной: одновременно они читаются
		# как один блок из двух строк, а по очереди — как «прошло время… и вот
		# зачем ты здесь».
		tw.parallel().tween_property(story_lbl, "modulate:a", 1.0, 0.22).set_delay(0.16)
	await tw.finished
	await get_tree().create_timer(HOLD_T).timeout
	var tw2 := create_tween()
	tw2.tween_property(lbl, "modulate:a", 0.0, 0.18)
	if story_lbl != null:
		tw2.parallel().tween_property(story_lbl, "modulate:a", 0.0, 0.18)
	await tw2.finished

	# Деньги убираем ДО открытия: за открывающейся шторкой уже видно забег, и
	# купюры на нём читались бы как предметы, которых там нет.
	for b in bills:
		if is_instance_valid(b):
			(b as Node).queue_free()

	# ── Открываемся ──────────────────────────────────────────────────────────
	await _tween_factor(1.0, 0.0, REVEAL_T)

func _tween_factor(from: float, to: float, sec: float) -> void:
	if not is_instance_valid(_rect):
		return
	var mat : ShaderMaterial = _rect.material
	mat.set_shader_parameter("factor", from)
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void:
		if is_instance_valid(_rect):
			(_rect.material as ShaderMaterial).set_shader_parameter("factor", v),
		from, to, sec)
	await tw.finished

# Шейдеру нужны два градиента: по одному он считает, ГДЕ сейчас край шторки, по
# второму — какой формы у неё зубцы.
func _make_material(vp: Vector2) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = SHADER

	# Ход шторки — по диагонали из угла в угол.
	var g_move := GradientTexture2D.new()
	g_move.gradient = Gradient.new()
	g_move.fill_from = Vector2(0, 0)
	g_move.fill_to   = Vector2(1, 1)

	# Форма зубца. Тот же диагональный градиент, но мелкой плиткой: из него
	# шейдер и нарезает треугольники.
	var g_shape := GradientTexture2D.new()
	g_shape.gradient = Gradient.new()
	g_shape.fill_from = Vector2(0, 1)
	g_shape.fill_to   = Vector2(1, 0)

	mat.set_shader_parameter("base_color",       COL_CURTAIN)
	mat.set_shader_parameter("node_resolution",  vp)
	mat.set_shader_parameter("factor",           0.0)
	mat.set_shader_parameter("width",            0.4)
	mat.set_shader_parameter("gradient_texture", g_move)
	mat.set_shader_parameter("gradient_fixed",   true)
	mat.set_shader_parameter("shape_texture",    g_shape)
	# 22 плитки поперёк экрана: на 32 (как в демо набора) треугольники на
	# телефоне мельче полутора миллиметров и сливаются в рябь.
	mat.set_shader_parameter("shape_tiling",     22.0)
	mat.set_shader_parameter("shape_rotation",   0.0)
	mat.set_shader_parameter("shape_scroll",     Vector2(0.0, 0.05))
	mat.set_shader_parameter("shape_feathering", 0.0)
	mat.set_shader_parameter("shape_treshold",   1.01)
	return mat
