class_name PhonePush
extends Node2D

# ── ТЕЛЕФОН И ПУШ ───────────────────────────────────────────────────────────
# Нормальдо ДОСТАЁТ ТЕЛЕФОН, и сверху экрана падает уведомление: слева иконка
# отправителя, справа его имя и сообщение.
#
# ── ЧТО ЭТО ЗАМЕНИЛО И ПОЧЕМУ ──────────────────────────────────────────────
# До сих пор игра разговаривала с игроком ОБЛАКОМ ИЗ ДОЛЛАРОВ: куча бумажек с
# надписью посередине. Как поверхность для текста это работало, но говорить
# ничего не могло — у реплики не было ОТПРАВИТЕЛЯ. «Выберись из канализации»
# висело в воздухе: неизвестно, кто это сказал и откуда он знает.
#
# Телефон отвечает на этот вопрос одним кадром. Сообщение приходит ОТ КОГО-ТО, у
# него есть лицо и имя, и сюжет из подписи к уровню превращается в переписку.
#
# ── ПОЧЕМУ БАННЕР СВЕРХУ, А НЕ НА ЭКРАНЧИКЕ ТЕЛЕФОНА ───────────────────────
# На экранчике нарисованного телефона сюжетная строка помещается кеглем в семь
# пикселей — то есть не помещается. Баннер сверху читается как настоящий пуш и
# говорит ровно то же самое: телефон в руке внизу, уведомление сверху.
#
# ── ОДИН КИРПИЧ НА ЧЕТЫРЕ МЕСТА ────────────────────────────────────────────
# Стартом уровня дело не ограничивается: тем же телефоном говорят обучение,
# конец уровня и главное меню. Четыре копии этого кода разъехались бы в первую
# же правку — так уже было с подсказками, пока их не свели в `tip_cloud.gd`.

const HAND_TEX := preload("res://assets/ui/phone/phone_hand.png")
const UI_FONT  := preload("res://assets/fonts/RussoOne-Regular.ttf")

# ── ОТПРАВИТЕЛИ ─────────────────────────────────────────────────────────────
# Имя и лицо лежат ЗДЕСЬ, а не у каждого места вызова: иначе «Хлеб» пишется в
# четырёх файлах, и в пятом окажется «ХЛЕБ» или «Хлеб.» — а игрок прочтёт это
# как двух разных людей.
const SENDERS : Dictionary = {
	"hleb": { "name": "Хлеб", "icon": preload("res://assets/ui/phone/hleb.png") },
	"proc": { "name": "Проц", "icon": preload("res://assets/ui/phone/proc.png") },
}
const SENDER_DEFAULT : String = "hleb"

# ── РАЗМЕРЫ БАННЕРА ─────────────────────────────────────────────────────────
# Ширина — чуть больше половины канвы (960): уже читалось бы как плашка, шире —
# как перекрытый экран. Высота считается от содержимого (см. `_layout`), здесь
# только пределы.
const BAN_W     : float = 520.0
const BAN_H_MIN : float = 64.0
# ── ПОД ВЕРХНЕЙ ПОЛОСОЙ, А НЕ НА НЕЙ ────────────────────────────────────────
# Полоса забега (пицца, доллары, секундомер) занимает первые ~16 px канвы и
# стоит там весь забег. Баннер на 10 закрывал её собой: пуш садился прямо на
# секундомер, и пока он висел, счёта времени на экране не было.
const BAN_TOP   : float = 24.0
const BAN_PAD   : float = 10.0
const ICON_PX   : float = 42.0
const RADIUS    : int   = 14

const CLR_BACK   : Color = Color(0.10, 0.10, 0.12, 0.94)
const CLR_EDGE   : Color = Color(0.72, 0.76, 0.86, 0.55)
const CLR_NAME   : Color = Color(1.00, 1.00, 1.00)
const CLR_BODY   : Color = Color(0.86, 0.88, 0.92)
const CLR_LEAD   : Color = Color(1.00, 0.94, 0.72)
const NAME_PX    : int   = 15
const LEAD_PX    : int   = 14
const BODY_PX    : int   = 13

# ── РУКА С ТЕЛЕФОНОМ ────────────────────────────────────────────────────────
# Выдвигается ИЗ САМОГО НОРМАЛЬДО и едет вместе с ним: он его достаёт, а не
# находит рядом с собой. Поэтому рука каждый кадр берёт его положение, а не
# встаёт один раз (он в этот момент летит по экрану вслед за пальцем).
#
# НЕ ребёнком Нормальдо: у него своя анимация — он пульсирует, толстеет и
# наклоняется, — и рука наследовала бы всё это вместе с масштабом.
# ── РАЗМЕР МЕРЯЕТСЯ ПО ГОЛОВЕ, А НЕ ПО ЭКРАНУ ───────────────────────────────
# Голова Нормальдо — 99 px, и рука обязана быть МЕНЬШЕ неё: это его рука, а не
# вторая фигура в кадре. Стояло 150 — рука выходила в полтора раза шире его
# самого, и читалась не как «достал телефон», а как чужая ладонь, влезшая сбоку.
#
# 84 — примерно пять шестых головы: столько, чтобы телефон в ней был виден, и не
# столько, чтобы спорить с хозяином. Отступ (HAND_OUT) считается в долях этого
# размера и уезжает вместе с ним, так что рука сама подобралась ближе к телу.
const HAND_PX   : float = 84.0
# Куда рука выезжает относительно головы, в долях её размера. Вправо-вниз: слева
# от него идёт полоса жира, а снизу-справа пусто.
const HAND_OUT  : Vector2 = Vector2(0.62, 0.34)
const HAND_TILT : float   = -0.18

# Хореография. Рука выезжает чуть раньше баннера: сначала достал, потом пришло.
const HAND_T  : float = 0.32
const BAN_IN  : float = 0.42
const BAN_OUT : float = 0.30
const HOLD_DEFAULT : float = 3.40

# Выше предметов потока, но ниже интерфейса забега — как и облако до него.
const Z : int = 30

var _hand   : Sprite2D = null
var _banner : Control  = null
var _follow : Node2D   = null
var _hand_home : Vector2 = Vector2.ZERO
var _closing : bool = false

# ── ПОКАЗАТЬ ────────────────────────────────────────────────────────────────
# `hold` < 0 — висеть, пока не уберут руками (`dismiss`). Так его держит
# обучение: такт кончается по действию игрока, а не по секундомеру.
#
# `follow` — кого держать за руку. Обычно сам Нормальдо; null — рука не
# показывается вовсе (в меню его на экране нет).
#
# `lead` — необязательная ЖИРНАЯ строка между именем и текстом. Так устроен
# настоящий пуш: имя приложения, заголовок, текст. Сюжету заголовок не нужен —
# сообщение и есть сообщение; а обучению нужен: у такта два уровня («ВЕДИ
# ПАЛЬЦЕМ» и «голова идёт следом»), и слить их в один абзац значит потерять
# команду в объяснении.
static func spawn(parent: Node, body: String, sender: String = SENDER_DEFAULT,
		hold: float = HOLD_DEFAULT, follow: Node2D = null,
		lead: String = "") -> Node2D:
	if parent == null or not is_instance_valid(parent):
		return null
	# Пустое уведомление — просто шум. Пусто это когда нет НИ текста, ни
	# заголовка: у такта обучения бывает один заголовок без пояснения.
	if body.strip_edges().is_empty() and lead.strip_edges().is_empty():
		return null
	var p := new()
	parent.add_child(p)
	p.call("_run", body, sender, hold, follow, lead)
	return p

func _run(body: String, sender: String, hold: float, follow: Node2D,
		lead: String = "") -> void:
	z_index = Z
	_follow = follow
	if is_instance_valid(_follow):
		_build_hand()
	_build_banner(body, sender, lead)
	if hold >= 0.0:
		var tw := create_tween()
		tw.tween_interval(BAN_IN + hold)
		tw.tween_callback(dismiss)

# Убрать по команде: уезжает так же, как приехал, и только потом исчезает.
func dismiss() -> void:
	if _closing:
		return
	_closing = true
	var tw := create_tween().set_parallel(true)
	if is_instance_valid(_banner):
		tw.tween_property(_banner, "position:y", -_banner.size.y - 10.0, BAN_OUT)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tw.tween_property(_banner, "modulate:a", 0.0, BAN_OUT)
	if is_instance_valid(_hand):
		tw.tween_property(_hand, "position", _hand_home, BAN_OUT)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tw.tween_property(_hand, "modulate:a", 0.0, BAN_OUT)
	tw.chain().tween_callback(queue_free)

# ── РУКА ────────────────────────────────────────────────────────────────────

func _build_hand() -> void:
	_hand = Sprite2D.new()
	_hand.texture        = HAND_TEX
	_hand.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ItemSizing.fit_sprite_content(_hand, HAND_PX)
	_hand.rotation = HAND_TILT
	_hand.modulate = Color(1, 1, 1, 0.0)
	add_child(_hand)

	# Начинает СПРЯТАННОЙ В НЁМ, в нулевом смещении: «достал» — это движение
	# наружу, и оно должно начинаться изнутри, а не сбоку.
	_hand_home = Vector2.ZERO
	_hand.position = _hand_home
	var out := HAND_OUT * HAND_PX
	var tw := _hand.create_tween().set_parallel(true)
	tw.tween_property(_hand, "modulate:a", 1.0, HAND_T * 0.6)
	tw.tween_property(_hand, "position", out, HAND_T)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# Рука едет за головой. Не ребёнком Нормальдо (см. HAND_PX выше), поэтому
# положение берётся каждый кадр — иначе она осталась бы там, где он был в
# момент показа, и через секунду висела бы в пустоте.
func _process(_delta: float) -> void:
	if is_instance_valid(_follow):
		global_position = _follow.global_position
	elif _hand != null and is_instance_valid(_hand):
		# Хозяин исчез (смерть, перезапуск) — руку убираем, она без него
		# бессмысленна. Баннер остаётся: он уже сказал то, ради чего появился.
		_hand.queue_free()
		_hand = null

# ── БАННЕР ──────────────────────────────────────────────────────────────────

func _build_banner(body: String, sender: String, lead: String = "") -> void:
	var vp : Vector2 = get_viewport_rect().size
	var snd : Dictionary = SENDERS.get(sender, SENDERS[SENDER_DEFAULT])

	# ── БАННЕР НЕ ЕДЕТ ЗА НОРМАЛЬДО ────────────────────────────────────────
	# Сам узел приклеен к голове (`_process`), а пуш обязан висеть у верхнего
	# края экрана. Раньше его держала «подставка» `top_level` — узел, которому
	# велено не наследовать чужое движение. Работало это ровно до тех пор, пока
	# родитель не начинал ещё и масштабироваться: `top_level` спасает от
	# смещения, но координаты остаются мировыми, и на экране другого размера
	# баннер расползался.
	#
	# Теперь он живёт в СВОЁМ СЛОЕ (CanvasLayer). У слоя координаты экранные и
	# ничьи чужие преобразования его не достают — и он же кладёт баннер поверх
	# интерфейса забега (см. BAN_LAYER).
	var layer := CanvasLayer.new()
	layer.layer = BAN_LAYER
	add_child(layer)

	_banner = Control.new()
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_banner)

	var w := _banner_w(vp)
	var h := _layout(body, snd, lead, w)
	_banner.size = Vector2(w, h)
	_banner.position = Vector2((vp.x - w) * 0.5, -h - 10.0)
	var tw := _banner.create_tween()
	tw.tween_property(_banner, "position:y", BAN_TOP, BAN_IN)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# ── БАННЕР ПО ЦЕНТРУ — И В СВОЁМ СЛОЕ ПОВЕРХ ИНТЕРФЕЙСА ────────────────────
# Пуш приходит сверху по центру. Это и есть его вид: сдвинутый к краю, он
# перестаёт читаться как уведомление и начинается ощущаться как плашка, которая
# «тянется куда-то за экран».
#
# Один заход он таким и был: я прижал его вправо, спасая от КРУЖКОВ РЕЗИСТОВ —
# они стоят слева под верхней полосой и у прокачанного скина дотягиваются до
# трети экрана, закрывая собой иконку отправителя и его имя. Лечение оказалось
# хуже болезни.
#
# Правильный ответ другой: кружки закрывали баннер потому, что интерфейс забега
# живёт СЛОЕМ ВЫШЕ, а баннер — обычным узлом в мире. Поэтому баннер уезжает в
# свой собственный слой поверх интерфейса. Настоящий пуш ровно это и делает —
# ложится поверх всего, что было на экране, и через три секунды уходит.
#
# Слой 120: выше интерфейса забега, но ниже тура по меню (130) — тур обязан
# накрывать всё, включая пуш.
const BAN_LAYER  : int   = 120
const BAN_MARGIN : float = 14.0

# Ширина зажимается по экрану: на узком телефоне 520 не влезли бы, и баннер
# вылез бы за оба края сразу.
func _banner_w(vp: Vector2) -> float:
	return minf(BAN_W, vp.x - BAN_MARGIN * 2.0)

# Собирает содержимое и возвращает высоту. Высота считается ПО ТЕКСТУ, а не
# задана числом: сюжетные строки разной длины, и на двухстрочной фиксированная
# высота обрезала бы вторую строку ровно посередине.
func _layout(body: String, snd: Dictionary, lead: String, w: float) -> float:
	var text_x : float = BAN_PAD * 2.0 + ICON_PX
	var text_w : float = w - text_x - BAN_PAD

	var back := Panel.new()
	back.add_theme_stylebox_override("panel",
		UiKit.rounded(CLR_BACK, RADIUS, CLR_EDGE, 2))
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.add_child(back)

	# Под иконкой — своя скруглённая подложка: у настоящего пуша слева стоит
	# значок приложения, и без неё портрет читается как картинка, случайно
	# положенная на плашку.
	UiKit.panel(_banner, Vector2(BAN_PAD, BAN_PAD), Vector2(ICON_PX, ICON_PX),
		Color(0.16, 0.16, 0.19, 1.0), 8, CLR_EDGE, 1)

	var icon := TextureRect.new()
	icon.texture        = snd.get("icon")
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.expand_mode    = TextureRect.EXPAND_IGNORE_SIZE
	# ЦЕЛИКОМ, а не по краям: портреты отправителей не квадратные (53×45), и
	# «заполнить рамку» срезало бы Хлебу подбородок вместе с полями шляпы.
	icon.stretch_mode   = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter   = Control.MOUSE_FILTER_IGNORE
	UiKit.place(_banner, icon, Vector2(BAN_PAD, BAN_PAD), Vector2(ICON_PX, ICON_PX))

	# Строки кладутся стопкой, и каждая следующая — от НИЖНЕГО края предыдущей.
	# Доли высоты тут не годятся: число строк переменное (у сюжета две, у такта
	# обучения три), а текст ещё и переносится.
	var y : float = BAN_PAD - 1.0
	y = _row(String(snd.get("name", "")), NAME_PX, CLR_NAME, false, text_x, text_w, y)
	if lead.strip_edges() != "":
		y = _row(lead, LEAD_PX, CLR_LEAD, true, text_x, text_w, y)
	if body.strip_edges() != "":
		y = _row(body, BODY_PX, CLR_BODY, true, text_x, text_w, y)

	var h : float = maxf(BAN_H_MIN, y + BAN_PAD)
	back.size = Vector2(w, h)
	return h

# Одна строка стопки. Возвращает, где кончилась, — с этого места начнётся
# следующая. Высота спрашивается у САМОЙ подписи и только ПОСЛЕ того, как ей
# задали ширину: сколько строк выйдет из переноса, столько и высоты.
func _row(txt: String, px: int, col: Color, wrap: bool,
		x: float, w: float, y: float) -> float:
	var l := _label(txt, px, col, wrap)
	UiKit.place(_banner, l, Vector2(x, y), Vector2(w, 1.0))
	var h : float = maxf(float(px) + 4.0, l.get_combined_minimum_size().y)
	l.size = Vector2(w, h)
	return y + h

# ── ТОТ ЖЕ ТЕЛЕФОН, НО В МЕНЮ ───────────────────────────────────────────────
# В забеге пуш падает сверху экрана: там он и читается как пуш, потому что
# внизу бежит игра. В меню падать неоткуда и незачем — экран стоит на месте, а
# подсказка обязана показывать НА КОНКРЕТНУЮ КНОПКУ и стоять рядом с ней.
#
# Поэтому здесь телефон и сообщение стоят РЯДОМ, одной карточкой: слева рука с
# телефоном, справа само уведомление. Карточку ставят «вот сюда», как и облачко
# до неё, — начало координат у неё в центре.
# В меню сравнивать не с кем — Нормальдо там не на экране, — но телефон обязан
# быть ОДНИМ И ТЕМ ЖЕ предметом в обоих местах: рука вдвое крупнее той, что в
# забеге, читалась бы как другой рисунок. Чуть меньше забежной, чтобы влезть в
# высоту карточки, и всё.
const CARD_HAND_PX : float = 78.0
const CARD_GAP     : float = 6.0
const CLR_HINT     : Color = Color(1.00, 0.85, 0.35)

# Внешний размер карточки — им зовущий решает, влезет она под кнопку или её
# надо ставить над. Спрашивается ДО сборки, поэтому высота тут задаётся, а не
# считается по тексту.
static func card_outer(w: float, h: float) -> Vector2:
	return Vector2(w, maxf(h, CARD_HAND_PX))

static func card(lead: String, body: String, sender: String,
		w: float, h: float, hint: String = "") -> Control:
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var snd : Dictionary = SENDERS.get(sender, SENDERS[SENDER_DEFAULT])

	var hand := Sprite2D.new()
	hand.texture        = HAND_TEX
	hand.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ItemSizing.fit_sprite_content(hand, CARD_HAND_PX)
	hand.rotation = HAND_TILT
	hand.position = Vector2(-w * 0.5 + CARD_HAND_PX * 0.5, 0.0)
	root.add_child(hand)

	var ban_x : float = -w * 0.5 + CARD_HAND_PX + CARD_GAP
	var ban_w : float = w * 0.5 - ban_x
	var panel := Control.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(panel)
	panel.position = Vector2(ban_x, -h * 0.5)
	panel.size     = Vector2(ban_w, h)

	UiKit.panel(panel, Vector2.ZERO, Vector2(ban_w, h),
		CLR_BACK, RADIUS, CLR_EDGE, 2)

	var pad : float = BAN_PAD * 0.8
	var y : float = pad
	y = _card_row(panel, String(snd.get("name", "")), NAME_PX - 2, CLR_NAME,
		pad, ban_w - pad * 2.0, y)
	if lead.strip_edges() != "":
		y = _card_row(panel, lead, LEAD_PX, CLR_LEAD, pad, ban_w - pad * 2.0, y)
	if body.strip_edges() != "":
		y = _card_row(panel, body, BODY_PX - 1, CLR_BODY, pad, ban_w - pad * 2.0, y)
	if hint.strip_edges() != "":
		_card_row(panel, hint, BODY_PX - 2, CLR_HINT, pad, ban_w - pad * 2.0, y + 2.0)
	return root

static func _card_row(parent: Control, txt: String, px: int, col: Color,
		x: float, w: float, y: float) -> float:
	var l := Label.new()
	l.add_theme_font_override("font", UI_FONT)
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", col)
	l.text          = txt
	l.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiKit.place(parent, l, Vector2(x, y), Vector2(w, 1.0))
	var h : float = maxf(float(px) + 3.0, l.get_combined_minimum_size().y)
	l.size = Vector2(w, h)
	return y + h

func _label(txt: String, px: int, col: Color, wrap: bool) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", UI_FONT)
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", col)
	l.text         = txt
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l
