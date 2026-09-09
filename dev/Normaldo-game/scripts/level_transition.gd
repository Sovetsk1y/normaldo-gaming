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
# ── СКОЛЬКО ВИСИТ НАДПИСЬ ────────────────────────────────────────────────────
# Было 1.1 с — и этого не хватало. Надпись здесь не украшение: она называет
# эпизод и говорит, ЗАЧЕМ игрок туда бежит, двумя строками. Прочитать две
# строки, поняв их, за секунду с небольшим нельзя — можно только успеть
# заметить, что там что-то было написано.
#
# Плюс две секунды. Итог — три с небольшим: хватает прочитать обе строки и ещё
# мгновение подумать над ними, а не переводить взгляд наперегонки с таймером.
const HOLD_T   : float = 3.10
const REVEAL_T : float = 0.55    # сколько открывается
# Пауза ПОСЛЕ интро и до шторки. Без неё занавес наезжает на последний кадр
# прыжка с дивана, и прыжок читается как оборванный.
const AFTER_INTRO_T : float = 1.0

# ── ЦВЕТ ШТОРКИ ─────────────────────────────────────────────────────────────
# Был фиолетовый — единственное фиолетовое пятно во всей игре, и посреди
# кирпично-рыжей канализации оно читалось как экран из другого приложения.
# Теперь почти чёрный: шторка ЗАКРЫВАЕТ подмену фона, а показывать в этот момент
# надо не её, а деньги поверх неё.
const COL_CURTAIN : Color = Color(0.05, 0.05, 0.07)
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
# ДЕНЕГ МНОГО, И ОНИ ЛЕЖАТ ДРУГ НА ДРУГЕ. Тридцати четырёх мелких купюр на
# тёмном поле хватало ровно на «что-то пролетело»; теперь экран занят деньгами
# целиком — это и есть переход, а шторка под ними просто прячет подмену фона.
#
# Купюр столько, чтобы при их размере они перекрывались: 130 штук по ~70 px на
# экране 960×430 дают примерно двойное покрытие. На первом кадре 130 всё ещё
# оставляли просветы в правом нижнем углу — отсюда 175.
const BILLS   : int   = 175
const BILL_PX : float = 70.0
const FLY_MIN : float = 0.85
const FLY_MAX : float = 1.70
# Крутится не каждая: сто тридцать вращений — это сто тридцать лишних твинов, а
# в плотной куче вращение отдельной бумажки всё равно не прочитать. Каждая
# четвёртая держит движение живым, остальные летят под своим случайным углом.
const SPIN_EVERY : int = 4

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
		# ПОЧТИ НЕПРОЗРАЧНЫЕ. Прежний разброс 0.45…1.0 в редкой россыпи читался как
		# глубина, а в плотной куче — как дырки: сквозь бледную купюру видно
		# лежащую под ней, и ворох рассыпается на слои.
		b.modulate       = Color(1, 1, 1, randf_range(0.88, 1.0))
		b.rotation       = randf_range(-PI, PI)
		b.process_mode   = Node.PROCESS_MODE_ALWAYS
		# Стартуют РАЗБРОСАННО по всей ширине слева от экрана: выйдя одной
		# колонной, они прошли бы экран волной, и середина перехода осталась бы
		# пустой. Разброс по вертикали — с запасом за края, чтобы верх и низ были
		# заняты так же плотно, как середина.
		b.position       = Vector2(-80.0 - randf_range(0.0, vp.x * 1.6),
			randf_range(-70.0, vp.y + 70.0))
		parent.add_child(b)
		var tw := b.create_tween().set_loops().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw.tween_property(b, "position:x", vp.x + 120.0, randf_range(FLY_MIN, FLY_MAX))\
			.from(b.position.x)
		if i % SPIN_EVERY == 0:
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

# ── ДВА ПЕРЕХОДА, ОДИН ВКЛЮЧЁН ───────────────────────────────────────────────
# «curtain» — ЭТОТ. Зубчатая шторка закрывается ЧЁРНОЙ подложкой, под ней летят
# деньги и висит надпись, и она открывается обратно (`_run_curtain`).
# «money» — облако денег во весь экран, без шторки вообще (`_run_money`).
#
# ВКЛЮЧЁН ЗАНАВЕС, И ЭТО ВЫБОР, А НЕ ЗАСТАВШЕЕСЯ ПОЛОЖЕНИЕ. Какое-то время
# стояло облако; вернулись к занавесу. Разница не в красоте, а в том, что́ каждый
# из них обещает: шторка ГАРАНТИРУЕТ, что подмена фона не видна, — это сплошная
# заливка; облако держит то же самое плотностью кучи и подложкой под ней, то
# есть статистикой. И читается чёрный занавес как «прошло время», а зелёное
# облако — как ещё один игровой эффект, которых в кадре и так хватает.
#
# Облако НЕ УДАЛЕНО: оно рабочее и проверено тестом, вернуться — одна строка.
const STYLE : String = "curtain"

func _run(caption: String, on_covered: Callable, story: String = "") -> void:
	if STYLE == "curtain":
		await _run_curtain(caption, on_covered, story)
		return
	await _run_money(caption, on_covered, story)

func _run_curtain(caption: String, on_covered: Callable, story: String = "") -> void:
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
	# ОБВОДКА ОБЯЗАТЕЛЬНА. Пока под надписью была ровная заливка, текст читался и
	# без неё; на сплошном ворохе зелёных купюр белые буквы тонут в первом же
	# знаке доллара, попавшем под них.
	lbl.add_theme_color_override("font_outline_color", Color(0.03, 0.03, 0.05))
	lbl.add_theme_constant_override("outline_size", 12)
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
		story_lbl.add_theme_font_size_override("font_size", 21)
		story_lbl.add_theme_color_override("font_outline_color", Color(0.03, 0.03, 0.05))
		story_lbl.add_theme_constant_override("outline_size", 10)
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

# ── Переход ОБЛАКОМ ДЕНЕГ ────────────────────────────────────────────────────
# Шторки нет вовсе. Справа влетает одно сплошное облако из сотен купюр, налепших
# друг на друга, — оно закрывает экран целиком; поверх него проступает сюжетный
# текст; всё это висит пару секунд и уезжает дальше влево, вместе с текстом.
#
# ── Почему одно облако, а не дождь ──────────────────────────────────────────
# Дождь из отдельных купюр — это фон, сквозь который видно происходящее; он и
# был у старой шторки в роли украшения. Здесь деньги не украшают переход, они и
# ЕСТЬ переход: за ними меняется эпизод, и потому им надо быть непрозрачной
# массой, а не россыпью.
#
# Отсюда и устройство: все купюры лежат в ОДНОМ узле и едут одним твином. Триста
# отдельных твинов — это триста отдельных скоростей, то есть снова россыпь; да и
# считать их каждый кадр незачем.
#
# ── Купюры стоят по СЕТКЕ, а не разбросаны случайно ─────────────────────────
# Случайная россыпь оставляет дыры: при трёхкратном перекрытии по площади всё
# равно около пяти процентов экрана остаётся пустым — и это не абстракция, а
# мигающие окошки в живой забег ровно в тот момент, когда за ними подменяют фон.
# Сетка с шагом меньше купюры кроет по построению; случайность добавляется
# СВЕРХУ, сдвигом внутри клетки, и на плотность не влияет.
const CLOUD_BILL_PX : float = 112.0
# Шаг сетки — заметно меньше купюры, чтобы соседние перекрывались телами, а не
# краями. 0.46 даёт перекрытие по площади примерно в два с половиной раза — при
# 0.56 выходило полтора, и на подложке между купюрами оставались видимые
# проплешины.
const CLOUD_STEP_K  : float = 0.46
# Насколько облако шире и выше экрана. Запас нужен с обеих сторон: слева и
# справа — чтобы край облака не показался ровной линией, сверху и снизу — чтобы
# при качании оно не отходило от краёв.
const CLOUD_OVER_W  : float = 1.55
const CLOUD_OVER_H  : float = 1.45
# Разброс внутри клетки, доля шага. Больше половины — и сетка снова начинает
# оставлять дыры.
const CLOUD_JITTER_K : float = 0.34

const CLOUD_FLY_IN  : float = 0.85
const CLOUD_HOLD    : float = 2.00
const CLOUD_FLY_OUT : float = 0.85

# ПОДЛОЖКА ЦВЕТА ДЕНЕГ, а не чёрная. У знака доллара внутри дырки, и сквозь
# самую плотную кучу купюр всё равно просвечивает то, что под ней. Чёрная
# подложка вернула бы ровно тот чёрный экран, ради ухода от которого этот переход
# и сделан; тёмно-зелёная читается как тень между бумажками.
#
# Она ПРИБИТА К ЭКРАНУ, а не к облаку: поедь она с облаком, её прямая кромка
# проехала бы через кадр зелёной шторкой. Появляется она под уже сомкнувшейся
# массой и потому невидима сама по себе.
const COL_CLOUD_BACK : Color = Color(0.04, 0.10, 0.06)
const CLOUD_BACK_T   : float = 0.20

func _run_money(caption: String, on_covered: Callable, story: String = "") -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	var vp : Vector2 = get_viewport().get_visible_rect().size

	var back := ColorRect.new()
	back.color        = Color(COL_CLOUD_BACK.r, COL_CLOUD_BACK.g, COL_CLOUD_BACK.b, 0.0)
	back.size         = vp
	back.z_index      = 0
	back.mouse_filter = Control.MOUSE_FILTER_STOP   # тапы сквозь переход не идут
	add_child(back)

	var cloud := _build_cloud(vp)
	cloud.z_index = 1
	add_child(cloud)

	# Текст — РЕБЁНОК ОБЛАКА: он обязан уехать вместе с деньгами, а не растаять
	# на месте, пока они улетают.
	# Кегль КРУПНЕЕ, чем у шторки. Там текст лежал на ровной заливке и читался
	# любым; здесь под ним вороха знаков доллара того же масштаба, и надпись
	# обязана быть заметно крупнее их, иначе тонет в общей ряби.
	var lbl := _cloud_label(caption, 46, COL_TEXT, Vector2(-vp.x * 0.5, -34.0),
		Vector2(vp.x, 64.0))
	cloud.add_child(lbl)
	var story_lbl : Label = null
	if not story.strip_edges().is_empty():
		story_lbl = _cloud_label(story, 28, COL_STORY,
			Vector2(-vp.x * 0.5, 36.0), Vector2(vp.x, 36.0))
		cloud.add_child(story_lbl)

	# ── Влетает ──────────────────────────────────────────────────────────────
	cloud.position = Vector2(vp.x * 1.6, vp.y * 0.5)
	var tw_in := create_tween()
	tw_in.tween_property(cloud, "position:x", vp.x * 0.5, CLOUD_FLY_IN)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	# Подложка догоняет ровно к приходу: раньше — и её кромку видно, позже — и
	# просветы успеют мигнуть.
	tw_in.parallel().tween_property(back, "color:a", 1.0, CLOUD_BACK_T)\
		.set_delay(maxf(0.0, CLOUD_FLY_IN - CLOUD_BACK_T))
	await tw_in.finished
	if not is_inside_tree():
		if on_covered.is_valid():
			on_covered.call()
		return

	# Экран закрыт — вот теперь можно менять всё, что меняется.
	if on_covered.is_valid():
		on_covered.call()

	# ── Текст ────────────────────────────────────────────────────────────────
	var tw := create_tween()
	tw.tween_property(lbl, "modulate:a", 1.0, 0.22)
	if story_lbl != null:
		# Сюжетная строка появляется ЧУТЬ ПОЗЖЕ главной: одновременно они читаются
		# как один блок из двух строк, а по очереди — как «прошло время… и вот
		# зачем ты здесь».
		tw.parallel().tween_property(story_lbl, "modulate:a", 1.0, 0.22).set_delay(0.16)
	await tw.finished
	await get_tree().create_timer(CLOUD_HOLD).timeout
	if not is_inside_tree():
		return

	# ── Улетает ДАЛЬШЕ, вместе с текстом ─────────────────────────────────────
	# Не назад и не растворяясь: облако прошло сквозь кадр и ушло. Обратный ход
	# читался бы как «передумало», а растворение — как выключенный свет.
	var tw_out := create_tween()
	tw_out.tween_property(cloud, "position:x", -vp.x * 1.6, CLOUD_FLY_OUT)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	# Подложка гаснет СРАЗУ: под ней уже новый эпизод, и держать её до конца
	# значило бы смотреть, как облако улетает с тёмного экрана.
	tw_out.parallel().tween_property(back, "color:a", 0.0, CLOUD_BACK_T)
	await tw_out.finished

# Купюры одной кучей. Возвращает узел, у которого начало координат — центр
# облака: так его достаточно возить по x, не пересчитывая ничего внутри.
func _build_cloud(vp: Vector2) -> Node2D:
	var root := Node2D.new()
	var ts : Vector2 = DOLLAR_TEX.get_size()
	var step : float = CLOUD_BILL_PX * CLOUD_STEP_K
	var w : float = vp.x * CLOUD_OVER_W
	var h : float = vp.y * CLOUD_OVER_H
	var cols : int = int(ceil(w / step)) + 1
	var rows : int = int(ceil(h / step)) + 1
	var jit : float = step * CLOUD_JITTER_K
	for cy in rows:
		for cx in cols:
			var b := Sprite2D.new()
			b.texture        = DOLLAR_TEX
			b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			var px : float = CLOUD_BILL_PX * randf_range(0.82, 1.18)
			b.scale    = Vector2.ONE * (px / maxf(ts.x, ts.y))
			b.rotation = randf_range(-PI, PI)
			b.position = Vector2(-w * 0.5 + float(cx) * step + randf_range(-jit, jit),
				-h * 0.5 + float(cy) * step + randf_range(-jit, jit))
			root.add_child(b)
	return root

func _cloud_label(text: String, size_px: int, col: Color, at: Vector2,
		size: Vector2) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", UI_FONT)
	l.add_theme_font_size_override("font_size", size_px)
	# Обводка ОТ КЕГЛЯ, а не постоянная. Шторка ставит 12 px при любом размере, и
	# на ней это незаметно: там под буквами ровная тёмная заливка того же цвета,
	# что и обводка. Здесь фон пёстрый, обводка видна как есть — и 12 px при
	# кегле 30 смыкались поверх штрихов буквы толщиной в четыре пикселя, так что
	# светлая надпись выходила тёмным пятном в зелёном ореоле.
	l.add_theme_color_override("font_outline_color", Color(0.03, 0.03, 0.05))
	l.add_theme_constant_override("outline_size", int(round(float(size_px) * 0.18)))
	l.text                 = text
	l.modulate             = Color(col.r, col.g, col.b, 0.0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	l.size                 = size
	l.position             = at
	l.z_index              = 3
	l.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	return l

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
