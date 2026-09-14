extends CanvasLayer
class_name SkinLab

# ── Лаборатория скинов ────────────────────────────────────────────────────────
# Дев-экран: скин в НАСТОЯЩЕМ кадре игры, со всей разметкой, которая обычно
# невидима, — лейны, хитбокс, коробка габаритов, эталон головы.
#
# ── Почему экран в игре, а не плагин редактора Godot ─────────────────────────
# Размер скина ставится «на глаз, каким я его вижу», а это имеет смысл только в
# настоящем кадре: тот же вьюпорт 960×430, та же высота лейна (430/5 = 86), тот
# же зажим MAX_BODY, тот же фон. Вьюпорт редактора Godot покажет другое — то
# есть соврёт ровно про то, ради чего затевалось.
#
# ── Что тут показано и почему именно это ─────────────────────────────────────
# Каждая линия отвечает на вопрос, который иначе решается угадыванием:
#
#   лейны          — влезает ли скин в свою дорожку и не лезет ли в соседние;
#   хитбокс r=32   — сидит ли ЛИЦО на круге, которым скин бьётся о предметы;
#   MAX_BODY       — не ужат ли скин коробкой (тогда голова выйдет мельче
#                    эталонной, и это будет видно по линейке);
#   MAX_SPREAD     — не разлетелся ли реквизит в соседние лейны;
#   линейка 91 px  — эталон головы: к нему приводятся все скины.
#
# ── Правка ────────────────────────────────────────────────────────────────────
# Тянешь скин — двигается посадка головы, колесо и кнопки −/+ меняют размер.
# Правится РУЧНОЙ СЛОЙ, лежащий в `dev/skin_layout.json`, и правится он прямо в
# `SkinMetrics`: после каждого шага пересчитывается всё разом — масштаб, посадка,
# рамки, числа в панели и сам Нормальдо в меню за спиной. Своя копия значений в
# лаборатории означала бы вторую реализацию `sprite_scale`, то есть инструмент,
# показывающий не то, что покажет игра.
#
# СОХРАНИТЬ пишет файл, ОТМЕНА возвращает всё к снимку на момент открытия,
# СБРОС — к чистому замеру (множитель 1.0, сдвиг 0). Выход без сохранения
# оставляет правки в памяти до перезапуска: они видны в меню и в забеге, и это
# нарочно — так проверяют правку в деле, прежде чем записать.
#
# ── Шляпа и маска ─────────────────────────────────────────────────────────────
# Кнопка ВЕЩЬ переключает «нет → шляпа → маска». Когда вещь надета, тяни-двигай
# правит ЕЁ посадку, а не скин: иначе пришлось бы держать два набора кнопок и
# помнить, к чему сейчас относится колесо.
#
# Вещь рисуется ТЕМ ЖЕ способом, что и в забеге, — `normaldo._spawn_worn`
# считает её место от макушки рисунка, и повторять этот расчёт в лаборатории
# значило бы получить вторую посадку, не совпадающую с игровой. Поэтому здесь
# живёт настоящий узел Нормальдо: скин ставится ему, вещь надевается его же
# кодом, и на экране ровно то, что увидит игрок.
#
# ── Что этот экран НЕ трогает ────────────────────────────────────────────────
# Замеренные таблицы (`HEADS`, `POSE_K`, `POSE_OFF`) считает
# `dev/tools/measure_heads.py` по самим спрайтам. Лаборатория их не редактирует
# и не будет: перерисовали скин, пересчитали — и ручные правки должны выжить.
# Править предстоит ТОЛЬКО ручной слой поверх замера (`TWEAK`, `MANUAL`, посадка
# шляпы и маски).
#
# ── Почему CanvasLayer, а не Node2D ──────────────────────────────────────────
# Лаборатория открывается из меню и обязана накрыть его целиком: первый же кадр
# показал логотип, кнопки и «Нажмите, чтобы начать игру» ПОВЕРХ разметки, а
# вместо плитки уровня — фон меню. Свой слой решает это одной строкой и заодно
# делает порядок внутри самодостаточным: он задаётся порядком в дереве, а не
# гонкой z_index с чужими узлами.
#
# См. /Концепция/Скины.md, scripts/skin_metrics.gd

const UI_FONT   := preload("res://assets/fonts/RussoOne-Regular.ttf")
const TEX_HAT   := preload("res://assets/items/magic_hat.png")
const TEX_MASK  := preload("res://assets/items/casey_mask.png")
const TEX_TILE  := preload("res://assets/backgrounds/bg_loop.png")
const TEX_ARROW := preload("res://assets/ui/quests/back_arrow.png")

# ── Геометрия забега ─────────────────────────────────────────────────────────
# Своих чисел тут нет намеренно. Первая версия переписала три константы из
# `game.tscn` — и первый же прогон `dev/smoke_skinlab.gd` показал, что в живой
# игре они другие: герой стоит не там, где записано в сцене, а поправка
# классики к моменту меню уже пересчитана. Лаборатория обязана показывать игру,
# а не свою версию игры, поэтому всё берётся из первоисточника.
const NORMALDO := preload("res://scripts/normaldo.gd")
const SPAWNER  := preload("res://scripts/spawner.gd")

const LANE_COUNT : int = SPAWNER.LANE_COUNT
const CLASSIC_NUDGE_PX : Vector2 = NORMALDO.CLASSIC_HEAD_NUDGE_PX

# Герой ставится по горизонтали туда же, где стоит в забеге, а по вертикали —
# В ЦЕНТР СРЕДНЕГО ЛЕЙНА. Это не «как в сцене»: в сцене записана стартовая
# точка, а в меню он и вовсе сидит на диване. Судить «влезает ли скин в свою
# дорожку» надо по дорожке, а середина — единственное её честное место.
const HERO_X : float = 220.0
var _hero_pos : Vector2 = Vector2(HERO_X, 215.0)
# Радиус берётся с живого узла забега; 32 — запасное значение на случай, если
# сцена почему-то без него.
var _hitbox_r : float = 32.0

const CLR_LANE   := Color(1.0, 1.0, 1.0, 0.16)
const CLR_LANE_C := Color(1.0, 1.0, 1.0, 0.07)
const CLR_HITBOX := Color(0.40, 1.00, 0.55, 0.85)
const CLR_BODY   := Color(1.00, 0.82, 0.30, 0.75)
const CLR_SPREAD := Color(1.00, 0.45, 0.45, 0.55)
const CLR_RULER  := Color(0.55, 0.80, 1.00, 0.90)
const CLR_TEXT   := Color(1.00, 0.96, 0.88)
const CLR_DIM    := Color(0.74, 0.71, 0.64)
const CLR_WARN   := Color(1.00, 0.55, 0.45)

# ── Раздел ПРЕДМЕТЫ ──────────────────────────────────────────────────────────
# Лаборатория задумывалась под скины, но вопрос у неё один и тот же: «то ли, что
# нарисовано, видит игрок». У предметов он стоит ровно так же — рисунок ужался
# сильнее нужного, хитбокс не совпал с рисунком, — и заводить ради него второй
# экран с той же плиткой, лейнами и кнопками значило бы завести вторую
# лабораторию.
#
# Поэтому здесь РЕЖИМ, а не второй экран: чип СКИНЫ/ПРЕДМЕТЫ меняет то, что
# стоит по центру и что правят −/+, а разметка, фон, СОХРАНИТЬ/ОТМЕНА/СБРОС
# остаются те же.
const ITEM_TWEAKS := preload("res://scripts/item_tweaks.gd")

# Что можно править. Список ЯВНЫЙ, а не «все png из assets/items»: правят не
# каждую картинку в игре, а предметы потока, и каталог из двухсот файлов, среди
# которых иконки интерфейса и куски фона, искать в них мешал бы.
#
# Пары «подпись — путь». Подпись нужна: путь к текстуре не читается с экрана.
const LAB_ITEMS : Array = [
	["ПИЦЦА",     "res://assets/items/pizza.png"],
	["ДОЛЛАР",    "res://assets/items/dollar.png"],
	["КАМЕНЬ",    "res://assets/items/stone.png"],
	["МУСОРКА",   "res://assets/items/trash_bin.png"],
	["БАНАН",     "res://assets/items/banana_peel.png"],
	["ПИВО",      "res://assets/items/beer.png"],
	["КОКТЕЙЛЬ",  "res://assets/items/cocktail.png"],
	["КОНУС",     "res://assets/items/cone.png"],
	["ЖЕТОН",     "res://assets/items/token.png"],
	["МЕШОК",     "res://assets/items/money_bag.png"],
	["ЗМЕЯ",      "res://assets/items/snake.png"],
	["БОМЖ",      "res://assets/items/homeless1.png"],
	["ЗОНТ",      "res://assets/items/umbrella.png"],
	["ШЕЗЛОНГ",   "res://assets/items/lounger.png"],
	["КОЛЕСО",    "res://assets/items/tire.png"],
	["ПТИЦА",     "res://assets/items/bird.png"],
	["КОП",       "res://assets/items/cop.png"],
	["ШАМАН",     "res://assets/items/shaman.png"],
	["ШТУРВАЛ",   "res://assets/skills/ship_wheel.png"],
	["БУТЫЛКА",   "res://assets/items/letter_bottle.png"],
	["ГРИБ",      "res://assets/items/mushroom.png"],
	["ШЛЯПА",     "res://assets/items/magic_hat.png"],
	["МАСКА",     "res://assets/items/casey_mask.png"],
	["НАРУЧНИКИ", "res://assets/items/handcuffs.png"],
]

# Базовый радиус хитбокса для показа. Настоящий ставит каждый предмет сам, и
# единого числа у них нет; здесь нужен ЭТАЛОН, относительно которого видно, во
# что превращает его множитель.
const ITEM_BASE_R : float = 30.0

var _mode      : String = "skins"   # "skins" | "items"
var _item      : int    = 0
var _item_snap : Dictionary = {}
var _mode_lbl  : Label    = null
var _item_lbl  : Label    = null
var _item_spr  : Sprite2D = null

var _hud   : Node = null
var _skin  : int  = 0
var _fat   : int  = 0
var _root  : Control = null
var _sprite : Sprite2D = null
var _worn_spr : Sprite2D = null
var _marks  : Marks   = null
var _info   : Array   = []   # Label по строкам правой панели
var _fat_lbl : Array  = []

# Что показывать поверх скина. Разметка мешает смотреть на сам рисунок, поэтому
# гасится целиком одной кнопкой.
var _show_marks : bool = true

# Снимок ручного слоя на момент открытия — для ОТМЕНЫ.
var _snapshot : Dictionary = {}
var _dirty    : bool = false
var _status   : Label = null
# Перетаскивание. Тянуть можно за любое место кадра, а не только за сам рисунок:
# у скинов вроде Джокера голова занимает четверть кадра, и попасть по ней
# пальцем труднее, чем промахнуться.
var _drag     : bool = false
# Какая вещь надета: "" — никакой, "hat" — шляпа мага, "mask" — маска Кейси.
# Тяни-двигай правит посадку надетой вещи, а не скина.
var _worn      : String = ""
var _worn_lbl  : Label  = null
const WORN_ORDER : Array = ["", "hat", "mask"]
const WORN_TITLE : Dictionary = { "": "ВЕЩЬ: НЕТ", "hat": "ВЕЩЬ: ШЛЯПА", "mask": "ВЕЩЬ: МАСКА" }
var _skin_lbl : Label = null
var _last_chip_label : Label  = null
var _last_chip_btn   : Button = null
# Органы, относящиеся ТОЛЬКО к скинам. В режиме предметов они не просто
# бесполезны — они врут: «ВЕЩЬ: НЕТ» над предметом читается как «на предмет
# можно надеть шляпу», а кнопки жиров как «у предмета есть жиры».
var _skin_only : Array = []
var _item_only : Array = []
var _item_hint : Label = null
var _head_ruler_lbl : Label = null

func setup(hud: Node) -> void:
	_hud = hud
	_skin = SkinRegistry.get_skin_index(SaveData.active_skin)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 90
	_read_live_geometry()
	_snapshot  = SkinMetrics.layout_snapshot()
	_item_snap = ITEM_TWEAKS.snapshot()
	_build()
	_refresh()

# Снимаем с живого забега то, что иначе пришлось бы переписывать константами.
# Ищем узел героя от корня: лаборатория открывается из меню, и сцена забега
# рядом — она же и есть сцена меню.
func _read_live_geometry() -> void:
	var vp := get_viewport().get_visible_rect().size
	_hero_pos = Vector2(HERO_X, vp.y / float(LANE_COUNT) * (float(LANE_COUNT / 2) + 0.5))
	var hero : Node = get_tree().get_root().find_child("Normaldo", true, false)
	if hero == null:
		return
	var cs := hero.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if cs != null and cs.shape is CircleShape2D:
		_hitbox_r = (cs.shape as CircleShape2D).radius

# ── Данные скина ─────────────────────────────────────────────────────────────

func _skin_id() -> String:
	return String(SkinRegistry.SKINS[_skin]["id"])

# Текстура берётся ТЕМ ЖЕ способом, что и везде в игре: у классики своя
# раскладка файлов, и свой путь к ней в лаборатории разъехался бы с игрой.
func _tex() -> Texture2D:
	return SkinRegistry.get_pose_texture(_skin_id(), _fat, _pose)

# ── Кадр: покой или поедание ─────────────────────────────────────────────────
# Жиров четыре, и у каждого ДВА кадра: покой и «ест». Правился всегда только
# покой — кадр поедания держался на одном автозамере. А он там и промахивается
# чаще всего: рот открыт, голова наклонена, силуэт другой, и приведённая
# геометрически голова смотрится то мелкой, то съехавшей. Заметно это ровно в
# тот момент, когда игрок ест, то есть постоянно.
#
# Переключатель, а не отдельный экран: покой и поедание сравнивают ОДИН ПРОТИВ
# ДРУГОГО, на том же месте, тем же взглядом — разъехались они или нет, видно
# только так.
var _pose     : String = ""
var _pose_lbl : Label  = null
const POSE_ORDER : Array = ["", "_eat"]
const POSE_TITLE : Dictionary = { "": "КАДР: ПОКОЙ", "_eat": "КАДР: ЕСТ" }

func _cycle_pose() -> void:
	var i : int = POSE_ORDER.find(_pose)
	_pose = String(POSE_ORDER[(i + 1) % POSE_ORDER.size()])
	if is_instance_valid(_pose_lbl):
		_pose_lbl.text = String(POSE_TITLE[_pose])
	_refresh()

# Размер и сдвиг ТЕКУЩЕГО кадра — покоя или поедания. Всё, что правит скин
# (кнопки, перетаскивание, сброс), ходит через эту пару, а не читает слой
# напрямую: иначе каждое из этих мест пришлось бы учить про позы отдельно.
func _cur_tweak(id: String) -> float:
	return SkinMetrics.tweak_for(id, _fat) if _pose.is_empty() \
		else SkinMetrics.pose_tweak_for(id, _fat, _pose)

func _cur_nudge(id: String) -> Vector2:
	return SkinMetrics.nudge_for(id, _fat) if _pose.is_empty() \
		else SkinMetrics.pose_nudge_for(id, _fat, _pose)

# ── Сборка ───────────────────────────────────────────────────────────────────

func _build() -> void:
	var vp := get_viewport().get_visible_rect().size

	# Порядок добавления — он же порядок отрисовки, и он тут содержательный:
	# фон, потом скин, потом разметка ПОВЕРХ скина (иначе хитбокс скроется под
	# крупным скином, а проверяется именно их взаимное положение), и только
	# потом кнопки с панелью.
	_build_backdrop(vp)

	_sprite = Sprite2D.new()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(_sprite)

	# Предмет живёт СВОИМ спрайтом рядом со скином: они показываются по очереди,
	# и переиспользовать один узел значило бы каждый раз пересобирать посадку.
	_item_spr = Sprite2D.new()
	_item_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_item_spr.visible        = false
	add_child(_item_spr)

	_marks = Marks.new()
	_marks.name = "Marks"
	_marks.lab = self
	add_child(_marks)

	_root = Control.new()
	_root.size         = vp
	_root.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_root)

	_build_panel(vp)
	_build_controls(vp)
	_skin_only.append(_label("эталон 91", 9, CLR_RULER,
		Vector2(_hero_pos.x + 56.0, 46.0), Vector2(80.0, 16.0),
		HORIZONTAL_ALIGNMENT_LEFT))
	_head_ruler_lbl = _label("", 9, Color(1, 1, 1, 0.85),
		Vector2(_hero_pos.x + 56.0, 60.0), Vector2(80.0, 16.0), HORIZONTAL_ALIGNMENT_LEFT)

# Фон уровня — та же плитка и тот же масштаб, что в забеге (background.gd),
# только неподвижная: инструмент для замера, движущийся фон здесь только мешал
# бы глазу.
func _build_backdrop(vp: Vector2) -> void:
	var k : float = vp.y / float(TEX_TILE.get_height())
	var w : float = float(TEX_TILE.get_width()) * k
	var n : int = int(ceil(vp.x / w)) + 1
	for i in n:
		var s := Sprite2D.new()
		s.texture        = TEX_TILE
		s.centered       = false
		s.scale          = Vector2.ONE * k
		s.position       = Vector2(w * float(i), 0.0)
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(s)
	# Плёнка: плитка яркая, а смотреть надо на скин и на линии. Непрозрачная по
	# низу — она же и отрезает меню, поверх которого лаборатория открылась.
	var dim := ColorRect.new()
	dim.color        = Color(0.02, 0.02, 0.04, 0.55)
	dim.size         = vp
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

func _build_panel(vp: Vector2) -> void:
	var w : float = 250.0
	var x : float = vp.x - w - 10.0
	UiKit.panel(_root, Vector2(x, 10.0), Vector2(w, 316.0),
		Color(0.05, 0.04, 0.03, 0.92), 10, Color(0.30, 0.26, 0.18, 0.95))
	_info.clear()
	for i in 14:
		_info.append(_label("", 11, CLR_TEXT, Vector2(x + 10.0, 16.0 + 21.0 * float(i)),
			Vector2(w - 20.0, 20.0), HORIZONTAL_ALIGNMENT_LEFT))

func _build_controls(vp: Vector2) -> void:
	# Назад
	_chip(Vector2(10.0, 10.0), Vector2(52.0, 26.0), "НАЗАД", _on_close)

	# Режим. Стоит рядом с «НАЗАД», а не в нижнем ряду: он переключает ВЕСЬ
	# экран, и место ему там же, где у выхода, — среди того, что делает с
	# лабораторией, а не с тем, что в ней лежит.
	_chip(Vector2(68.0, 10.0), Vector2(104.0, 26.0), "", _cycle_mode)
	_mode_lbl = _last_chip_label

	# Скин: влево / вправо и подпись между ними.
	var y : float = vp.y - 36.0
	_chip(Vector2(10.0, y), Vector2(34.0, 26.0), "◀", func(): _step(-1))
	_chip(Vector2(160.0, y), Vector2(34.0, 26.0), "▶", func(): _step(1))
	_skin_lbl = _label("", 12, CLR_TEXT, Vector2(48.0, y), Vector2(108.0, 26.0),
		HORIZONTAL_ALIGNMENT_CENTER)
	# Подпись предмета стоит НА ТОМ ЖЕ месте, что и подпись скина: стрелки те
	# же, и разводить их подписи по разным углам значило бы учить экран заново.
	_item_lbl = _label("", 12, CLR_TEXT, Vector2(48.0, y), Vector2(108.0, 26.0),
		HORIZONTAL_ALIGNMENT_CENTER)

	# Жир 1…4 — четыре кнопки, а не стрелки: прыгать между состояниями надо
	# в любом порядке, «жир 1 против жира 4» сравнивают чаще соседних.
	_fat_lbl.clear()
	for i in 4:
		var bx : float = 210.0 + 40.0 * float(i)
		_skin_only.append(_chip(Vector2(bx, y), Vector2(34.0, 26.0), str(i + 1),
			func(): _set_fat(i)))
		_skin_only.append(_last_chip_btn)
		_fat_lbl.append(_last_chip_label)

	# Кадр (покой / ест) — В РЯДУ ЖИРОВ, сразу за ними: жир и кадр вместе и
	# задают, что сейчас на экране, и щёлкают их по очереди, сравнивая.
	_skin_only.append(_chip(Vector2(210.0, y - 30.0), Vector2(112.0, 26.0), "",
		_cycle_pose))
	_skin_only.append(_last_chip_btn)
	_pose_lbl = _last_chip_label
	_pose_lbl.text = String(POSE_TITLE[_pose])
	_skin_only.append(_pose_lbl)

	_chip(Vector2(390.0, y), Vector2(96.0, 26.0), "РАЗМЕТКА", _toggle_marks)
	_skin_only.append(_chip(Vector2(390.0, y - 30.0), Vector2(96.0, 26.0), "", _cycle_worn))
	_skin_only.append(_last_chip_btn)
	_worn_lbl = _last_chip_label
	_worn_lbl.text = String(WORN_TITLE[_worn])
	# Рядом с выбором вещи, а не в ряду размеров: относится она к вещи, а не к
	# скину, и стоять должна там, где вещь и выбирают.
	_skin_only.append(_chip(Vector2(494.0, y - 30.0), Vector2(140.0, 26.0),
		"Ш = ВСЕМ ЖИРАМ", _worn_same_width))
	_skin_only.append(_last_chip_btn)

	# Размер: шаг 0.01 — с ним заметно за одно нажатие и не проскакивает мимо.
	_chip(Vector2(500.0, y), Vector2(30.0, 26.0), "−", func(): _bump_tweak(-0.01))
	_chip(Vector2(534.0, y), Vector2(30.0, 26.0), "+", func(): _bump_tweak(0.01))
	# Хитбокс — СВОЯ пара кнопок, а не переключатель «что сейчас правит колесо».
	# Размер и зона удара правятся вперемешку, по очереди, глядя друг на друга, и
	# режим между ними означал бы щелчок на каждый шаг.
	# Место выбрано пустое НАД рядом жиров: первая версия встала на «Ш = ВСЕМ
	# ЖИРАМ», и на кадре было видно две подписи одна поверх другой.
	_item_only.append(_chip(Vector2(210.0, y - 30.0), Vector2(34.0, 26.0), "Х−",
		func(): _bump_item(0.0, -0.02)))
	_item_only.append(_last_chip_btn)
	_item_only.append(_chip(Vector2(250.0, y - 30.0), Vector2(34.0, 26.0), "Х+",
		func(): _bump_item(0.0, 0.02)))
	_item_only.append(_last_chip_btn)
	_item_hint = _label("ХИТБОКС", 10, CLR_DIM, Vector2(288.0, y - 30.0),
		Vector2(80.0, 26.0), HORIZONTAL_ALIGNMENT_LEFT)
	_item_only.append(_item_hint)
	_chip(Vector2(576.0, y), Vector2(66.0, 26.0), "СБРОС", _reset_current)
	_chip(Vector2(648.0, y), Vector2(72.0, 26.0), "ОТМЕНА", _revert_all)
	_chip(Vector2(726.0, y), Vector2(92.0, 26.0), "СОХРАНИТЬ", _save)

	_status = _label("", 10, CLR_DIM, Vector2(10.0, y - 22.0), Vector2(500.0, 18.0),
		HORIZONTAL_ALIGNMENT_LEFT)

func _chip(pos: Vector2, size: Vector2, text: String, on_press: Callable) -> Control:
	var visual := Control.new()
	visual.size         = size
	visual.position     = pos
	visual.pivot_offset = size * 0.5
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(visual)
	UiKit.panel(visual, Vector2.ZERO, size,
		Color(0.10, 0.09, 0.06, 0.94), 8, Color(0.42, 0.36, 0.24, 0.95))
	_last_chip_label = _label(text, 11, CLR_TEXT, Vector2.ZERO, size,
		HORIZONTAL_ALIGNMENT_CENTER, visual)

	var btn := Button.new()
	btn.flat       = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.size       = size
	btn.position   = pos
	btn.pressed.connect(on_press)
	btn.button_down.connect(UiKit.press_anim.bind(visual, true))
	btn.button_up.connect(UiKit.press_anim.bind(visual, false))
	btn.mouse_exited.connect(UiKit.press_anim.bind(visual, false))
	_root.add_child(btn)
	_last_chip_btn = btn
	return visual

func _label(text: String, size_px: int, col: Color, pos: Vector2, size: Vector2,
		align: int, parent: Node = null) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", UI_FONT)
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	l.add_theme_constant_override("outline_size", 2)
	l.text                 = text
	l.modulate             = col
	l.horizontal_alignment = align
	l.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	UiKit.place(parent if parent != null else _root, l, pos, size)
	return l

# Вещь пересобирается заново на каждое обновление: `WornItem.make` считает её
# место от макушки РИСУНКА, а рисунок меняется и со скином, и с жиром, и с
# размером — двигать уже созданный спрайт значило бы повторять этот расчёт.
func _rebuild_worn(id: String, tex: Texture2D) -> void:
	if is_instance_valid(_worn_spr):
		_worn_spr.queue_free()
	_worn_spr = null
	if _worn.is_empty() or tex == null:
		return
	var w : Dictionary = SkinMetrics.worn_for(id, _fat, _worn, _pose)
	if _worn == "hat":
		_worn_spr = WornItem.make(tex, TEX_HAT, float(w["k"]),
			Vector2(float(w["x"]), 0.0), float(w["sink"]))
	else:
		_worn_spr = WornItem.make(tex, TEX_MASK, float(w["k"]),
			Vector2(float(w["x"]), float(w["y"])))
	_sprite.add_child(_worn_spr)

func _cycle_worn() -> void:
	var i : int = WORN_ORDER.find(_worn)
	_worn = String(WORN_ORDER[(i + 1) % WORN_ORDER.size()])
	if is_instance_valid(_worn_lbl):
		_worn_lbl.text = String(WORN_TITLE[_worn])
	_refresh()

# ── Правка ───────────────────────────────────────────────────────────────────
# Ввод ловится на весь экран, а кнопки стоят выше в дереве и событие забирают
# себе, — поэтому таскание не срабатывает поверх нижнего ряда и панели.

func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_bump_tweak(0.01)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_bump_tweak(-0.01)
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			_drag = mb.pressed
	elif ev is InputEventScreenTouch:
		_drag = (ev as InputEventScreenTouch).pressed
	elif _drag and (ev is InputEventMouseMotion or ev is InputEventScreenDrag):
		_drag_by(ev.relative)

# Пиксели тянущего пальца → доли кадра. Знак обратный: спрайт ставится в
# `герой − сдвиг × кадр × масштаб`, то есть уводя сдвиг влево, рисунок едет
# вправо. Делим на РАЗМЕР КАДРА В ПИКСЕЛЯХ ЭКРАНА — иначе на мелком скине палец
# тащил бы рисунок через весь экран, а на крупном не сдвинул бы вовсе.
func _drag_by(delta: Vector2) -> void:
	var tex : Texture2D = _tex()
	if tex == null:
		return
	var id : String = _skin_id()
	if not _worn.is_empty():
		_drag_worn(id, tex, delta)
		return
	var k : float = _shown_scale(id, tex)
	var sz : Vector2 = tex.get_size()
	if k <= 0.0 or sz.x <= 0.0 or sz.y <= 0.0:
		return
	var n : Vector2 = _cur_nudge(id)
	n -= Vector2(delta.x / (sz.x * k), delta.y / (sz.y * k))
	_apply(id, _cur_tweak(id), n)

# Вертикаль у шляпы и маски задаётся ПО-РАЗНОМУ, и свести их к одному нельзя:
# шляпа садится от макушки (`sink` растёт вниз), маска — по доле кадра (`y`).
# Здесь это единственное место, где разница видна наружу.
func _drag_worn(id: String, tex: Texture2D, delta: Vector2) -> void:
	var k : float = SkinMetrics.sprite_scale(id, _fat, tex.get_size())
	var sz : Vector2 = tex.get_size()
	if k <= 0.0 or sz.x <= 0.0 or sz.y <= 0.0:
		return
	var w : Dictionary = SkinMetrics.worn_for(id, _fat, _worn, _pose).duplicate()
	w["x"] = float(w["x"]) + delta.x / (sz.x * k)
	if _worn == "hat":
		w["sink"] = float(w["sink"]) + delta.y / (sz.y * k)
	else:
		w["y"] = float(w["y"]) + delta.y / (sz.y * k)
	SkinMetrics.worn_set(id, _fat, _worn, w, _pose)
	_dirty = true
	_refresh()

# ── Раздел ПРЕДМЕТЫ ──────────────────────────────────────────────────────────

func _cycle_mode() -> void:
	_mode = "items" if _mode == "skins" else "skins"
	_refresh()

func _item_path() -> String:
	return String((LAB_ITEMS[clampi(_item, 0, LAB_ITEMS.size() - 1)] as Array)[1])

func _item_name() -> String:
	return String((LAB_ITEMS[clampi(_item, 0, LAB_ITEMS.size() - 1)] as Array)[0])

func _step_item(d: int) -> void:
	_item = wrapi(_item + d, 0, LAB_ITEMS.size())
	_refresh()

# −/+ правят РАЗМЕР, кнопки «Х −/+» — хитбокс. Один орган на два числа
# потребовал бы ещё одного переключателя и памяти о том, что он сейчас значит.
func _bump_item(dsize: float, dhit: float) -> void:
	var path := _item_path()
	var m : Dictionary = ITEM_TWEAKS.mult_for(path)
	ITEM_TWEAKS.set_mult(path,
		float(m["size"]) + dsize, float(m["hit"]) + dhit)
	_dirty = true
	_refresh()

func _reset_item() -> void:
	ITEM_TWEAKS.reset(_item_path())
	_dirty = true
	_refresh()
	_set_status("предмет сброшен к замеру: %s" % _item_name())

# Предмет показывается В НАСТОЯЩЕМ РАЗМЕРЕ — тем же `content_scale`, каким его
# считает игра, — и поверх него рисуется его хитбокс. Своя формула здесь
# разошлась бы с игрой на первой же правке, и лаборатория показывала бы не то,
# что видит игрок.
func _refresh_item() -> void:
	var tex : Texture2D = load(_item_path()) as Texture2D
	var m : Dictionary = ITEM_TWEAKS.mult_for(_item_path())
	if is_instance_valid(_item_lbl):
		_item_lbl.text = _item_name()
	if is_instance_valid(_item_spr):
		_item_spr.texture  = tex
		_item_spr.position = _hero_pos
		if tex != null:
			_item_spr.scale = Vector2.ONE \
				* (ItemSizing.content_scale(tex, ItemSizing.BASE_PX) * float(m["size"]))

func _item_hit_r() -> float:
	return ITEM_BASE_R * float(ITEM_TWEAKS.mult_for(_item_path())["hit"])

func _bump_tweak(d: float) -> void:
	if _mode == "items":
		_bump_item(d, 0.0)
		return
	var id : String = _skin_id()
	# Надета вещь — колесо и кнопки меняют ЕЁ ширину, а не размер скина: иначе
	# пришлось бы держать два набора кнопок и помнить, к чему сейчас относится
	# колесо.
	if not _worn.is_empty():
		var w : Dictionary = SkinMetrics.worn_for(id, _fat, _worn, _pose).duplicate()
		w["k"] = clampf(float(w["k"]) + d, 0.05, 3.0)
		SkinMetrics.worn_set(id, _fat, _worn, w, _pose)
		_dirty = true
		_refresh()
		return
	# Нижняя граница 0.10, а не 0: на нуле скин исчезает, и вернуть его можно
	# только СБРОСОМ — а игрок к тому моменту уже не понимает, что произошло.
	var t : float = clampf(_cur_tweak(id) + d, 0.10, 4.0)
	_apply(id, t, _cur_nudge(id))

func _apply(id: String, tweak: float, nudge: Vector2) -> void:
	if _pose.is_empty():
		SkinMetrics.layout_set(id, _fat, tweak, nudge)
	else:
		SkinMetrics.pose_set(id, _fat, _pose, tweak, nudge)
	_dirty = true
	_refresh()

func _reset_current() -> void:
	if _mode == "items":
		_reset_item()
		return
	if not _worn.is_empty():
		SkinMetrics.worn_clear(_skin_id(), _fat, _worn, _pose)
		_dirty = true
		_refresh()
		_set_status("посадка вещи сброшена к общей: %s, жир %d" % [_skin_id(), _fat + 1])
		return
	if not _pose.is_empty():
		# Сброс ПОЗЫ — это удаление строки, а не запись единиц: единицы остались
		# бы в файле как «правка, равная замеру», и следующий пересчёт
		# `measure_heads.py` они бы не отменили, а тихо пережили.
		SkinMetrics.pose_clear(_skin_id(), _fat, _pose)
		_dirty = true
		_refresh()
		_set_status("правка кадра «%s» снята: %s, жир %d"
			% [String(POSE_TITLE[_pose]), _skin_id(), _fat + 1])
		return
	_apply(_skin_id(), 1.0, Vector2.ZERO)
	_set_status("сброшено к замеру: %s, жир %d" % [_skin_id(), _fat + 1])

# ОТМЕНА и СОХРАНЕНИЕ трогают ОБА слоя разом, а не только тот, что виден. Иначе
# правки другого режима либо тихо теряются на отмене, либо тихо не сохраняются —
# и то и другое замечаешь через полчаса, когда возвращаться уже не к чему.
func _revert_all() -> void:
	SkinMetrics.layout_restore(_snapshot)
	ITEM_TWEAKS.restore(_item_snap)
	_dirty = false
	_refresh()
	_set_status("все правки отменены")

func _save() -> void:
	var err : String = SkinMetrics.layout_save()
	if err.is_empty():
		err = ITEM_TWEAKS.save()
	if err.is_empty():
		_dirty = false
		_set_status("сохранено в dev/skin_layout.json и dev/item_layout.json")
	else:
		# Отдельным цветом и словами: запись в res:// работает только при
		# запуске из редактора, и молчаливый отказ съел бы всю правку.
		_set_status("НЕ СОХРАНЕНО: %s" % err, CLR_WARN)

func _set_status(text: String, col: Color = CLR_DIM) -> void:
	if is_instance_valid(_status):
		_status.text = text
		_status.modulate = col

# ── Обновление ───────────────────────────────────────────────────────────────

func _step(d: int) -> void:
	if _mode == "items":
		_step_item(d)
		return
	_step_skin(d)

func _step_skin(d: int) -> void:
	_skin = wrapi(_skin + d, 0, SkinRegistry.SKINS.size())
	_refresh()

func _set_fat(i: int) -> void:
	_fat = clampi(i, 0, 3)
	_refresh()

func _toggle_marks() -> void:
	_show_marks = not _show_marks
	_marks.visible = _show_marks
	_marks.queue_redraw()

func _refresh() -> void:
	var items := _mode == "items"
	if is_instance_valid(_mode_lbl):
		_mode_lbl.text = "РЕЖИМ: ПРЕДМЕТЫ" if items else "РЕЖИМ: СКИНЫ"
	# Показывается ровно одно: скин или предмет. Оба разом читались бы как
	# «предмет надет на героя», чего в игре не бывает.
	if is_instance_valid(_sprite):
		_sprite.visible = not items
	if is_instance_valid(_item_spr):
		_item_spr.visible = items
	if is_instance_valid(_worn_spr):
		_worn_spr.visible = not items
	if is_instance_valid(_item_lbl):
		_item_lbl.visible = items
	if is_instance_valid(_skin_lbl):
		_skin_lbl.visible = not items
	for n in _skin_only:
		if is_instance_valid(n):
			(n as CanvasItem).visible = not items
	for n in _item_only:
		if is_instance_valid(n):
			(n as CanvasItem).visible = items
	# Линейка головы — про скины, и над предметом она читается как его размер.
	if is_instance_valid(_head_ruler_lbl):
		_head_ruler_lbl.visible = not items
	if items:
		_refresh_item()
		_marks.queue_redraw()
		_refresh_item_info()
		return

	var id : String = _skin_id()
	var tex : Texture2D = _tex()
	_skin_lbl.text = String(SkinRegistry.SKINS[_skin].get("name_ru", id))
	for i in _fat_lbl.size():
		(_fat_lbl[i] as Label).modulate = CLR_TEXT if i == _fat else CLR_DIM

	# Посадка — ТА ЖЕ арифметика, что в `normaldo._apply_skin_to_sprite`. Своя
	# копия формулы разошлась бы с игрой на первой же правке, и лаборатория
	# показывала бы не то, что видит игрок.
	if tex != null:
		var s : float = _shown_scale(id, tex)
		_sprite.texture  = tex
		_sprite.scale    = Vector2(s, s)
		_sprite.position = _hero_pos + _sprite_offset(id, tex, s)
	_rebuild_worn(id, tex)
	_marks.queue_redraw()
	_refresh_info(id, tex)
	if tex != null and is_instance_valid(_head_ruler_lbl):
		var hd : Vector2 = SkinMetrics.head_size_for(id, _fat)
		_head_ruler_lbl.text = "голова %d" % int(hd.x * tex.get_size().x
			* SkinMetrics.sprite_scale(id, _fat, tex.get_size()))

# Масштаб кадра НА ЭКРАНЕ — та же арифметика, что в `normaldo._show_head`:
# базовый масштаб скина, помноженный на поправку кадра. У покоя поправки нет
# (POSE_K для пустого варианта не спрашивают), у поедания она и есть то, что
# здесь правится.
func _shown_scale(id: String, tex: Texture2D) -> float:
	if _pose.is_empty():
		return SkinMetrics.sprite_scale(id, _fat, tex.get_size())
	# БАЗА БЕРЁТСЯ ПО КАДРУ ПОКОЯ, а не по кадру варианта. Так считает игра
	# (`normaldo._show_head`: `_base_scale * _head_k`), и иначе поправка кадра
	# применяется дважды: `POSE_K` затем и мерили, чтобы привести кадр варианта к
	# масштабу покоя. У классики на четвёртом жире это давало ×1.252 вместо
	# ×0.833 — голова в лаборатории была в полтора раза крупнее, чем в игре.
	var idle : Texture2D = SkinRegistry.get_avatar_texture(id, _fat)
	var base : float = SkinMetrics.sprite_scale(id, _fat,
		idle.get_size() if idle != null else tex.get_size())
	return base * SkinMetrics.pose_k(id, _pose, _fat)

# Посадка КАДРА ПОКОЯ — построчно как `normaldo._apply_head_offset`.
func _idle_offset(id: String, tex: Texture2D, s: float) -> Vector2:
	var sz : Vector2 = tex.get_size()
	if id == "classic":
		# База у классики в пикселях, а не в долях кадра, — но ручная правка
		# поверх неё применяется, как у всех. Пока не применялась, классика была
		# единственным скином, который в лаборатории не двигался: сдвиг копился
		# в файле, а на экране не менялось ничего.
		var nd : Vector2 = SkinMetrics.nudge_for(id, _fat)
		return CLASSIC_NUDGE_PX + Vector2(-nd.x * sz.x * s, -nd.y * sz.y * s)
	var off : Vector2 = SkinMetrics.offset_for(id, _fat)
	return Vector2(-off.x * sz.x * s, -off.y * sz.y * s)

# ЯКОРЬ ГОЛОВЫ — точка, к которой прикалываются кадры вариантов. Считается по
# кадру покоя, ровно как `normaldo._recalc_head_anchor`: иначе кадр «ест»
# садился бы от нуля, а в игре — от якоря, и лаборатория показывала бы не игру.
# У классики разница ровно на её пиксельный сдвиг, то есть постоянные 14 px.
func _anchor_offset(id: String) -> Vector2:
	var idle : Texture2D = SkinRegistry.get_avatar_texture(id, _fat)
	if idle == null:
		return Vector2.ZERO
	var si : float = SkinMetrics.sprite_scale(id, _fat, idle.get_size())
	var off : Vector2 = SkinMetrics.offset_for(id, _fat)
	var sz : Vector2 = idle.get_size()
	return _idle_offset(id, idle, si) + Vector2(off.x * sz.x * si, off.y * sz.y * si)

func _sprite_offset(id: String, tex: Texture2D, s: float) -> Vector2:
	if _pose.is_empty():
		return _idle_offset(id, tex, s)
	var sz : Vector2 = tex.get_size()
	var off : Vector2 = SkinMetrics.pose_off(id, _pose, _fat)
	return _anchor_offset(id) - Vector2(off.x * sz.x * s, off.y * sz.y * s)

# Правая панель. Показывает не «что нарисовано», а ЧИСЛА, по которым это
# нарисовано, — и отдельно то, из чего они сложились: замер, коробка, ручная
# правка. Иначе непонятно, почему скин мелкий: так замерили или так ужали.
# Текстура надетой вещи. Одно место, чтобы `TEX_HAT`/`TEX_MASK` не разъезжались
# между сборкой, замером и уравниванием.
func _worn_tex() -> Texture2D:
	if _worn == "hat":
		return TEX_HAT
	return TEX_MASK if _worn == "mask" else null

# ШИРИНА ВЕЩИ В ПИКСЕЛЯХ на заданном жире. Ради неё всё и затевалось: `k` — доля
# КАДРА хозяина, кадры у жиров разные, и одинаковый `k` даёт РАЗНЫЙ размер. По
# коэффициенту «одинаковую шляпу на всех жирах» подобрать нельзя, по пикселям —
# можно.
func _worn_px_at(id: String, fat: int) -> float:
	var t : Texture2D = _worn_tex()
	var host : Texture2D = SkinRegistry.get_avatar_texture(id, fat)
	if t == null or host == null:
		return 0.0
	var w : Dictionary = SkinMetrics.worn_for(id, fat, _worn, _pose)
	return WornItem.art_px(host, t, float(w["k"]),
		SkinMetrics.sprite_scale(id, fat, host.get_size()))

# Размер вещи: в пикселях и В ДОЛЯХ ГОЛОВЫ. Два числа, потому что «одинаковая
# шляпа» читается двояко — то ли одна и та же на экране, то ли одинаковая
# ОТНОСИТЕЛЬНО головы, а голова у убера втрое больше худой. Какое из двух нужно,
# решает глаз, и оба должны быть на виду.
func _worn_size_line(id: String, tex: Texture2D) -> String:
	if _worn.is_empty():
		return "—"
	var px : float = _worn_px_at(id, _fat)
	if px <= 0.0 or tex == null:
		return "—"
	var head : float = SkinMetrics.head_size_for(id, _fat).x * tex.get_size().x \
		* SkinMetrics.sprite_scale(id, _fat, tex.get_size())
	if head <= 0.0:
		return "%d px" % int(round(px))
	return "%d px  ·  %.2f головы" % [int(round(px)), px / head]

# Строка про надетую вещь. У шляпы и маски РАЗНЫЕ поля, и показывать надо те,
# что реально правятся: иначе непонятно, куда уходит движение пальца. Разница не
# косметическая — шляпа садится от макушки (`глуб` растёт вниз), маска по доле
# кадра (`y`), и свести их к одному нельзя (см. `WornItem`).
func _worn_line(id: String) -> String:
	if _worn.is_empty():
		return "—"
	var w : Dictionary = SkinMetrics.worn_for(id, _fat, _worn, _pose)
	if _worn == "hat":
		return "ш%.2f x%.3f глуб%.3f" % [float(w["k"]), float(w["x"]), float(w["sink"])]
	return "ш%.2f x%.3f y%.3f" % [float(w["k"]), float(w["x"]), float(w["y"])]

# ── Одна ширина на все жиры ──────────────────────────────────────────────────
# Берёт ширину вещи НА ТЕКУЩЕМ жире и пересчитывает `k` остальным трём так,
# чтобы в пикселях вышло то же самое. Руками это не делается: `k` у каждого жира
# свой знаменатель, и подгонять колесом до совпадения — значит не попасть.
#
# Трогает ТОЛЬКО ширину. Посадка (`x`, `глуб`, `y`) у каждого жира своя — макушка
# у худого и у убера в разных местах, — и утащить её заодно значило бы сбить
# то, что подбирали руками.
func _worn_same_width() -> void:
	if _worn.is_empty():
		_set_status("вещь не надета", CLR_WARN)
		return
	var id : String = _skin_id()
	var t : Texture2D = _worn_tex()
	var want : float = _worn_px_at(id, _fat)
	if t == null or want <= 0.0:
		return
	for f in 4:
		if f == _fat:
			continue
		var host : Texture2D = SkinRegistry.get_avatar_texture(id, f)
		if host == null:
			continue
		var k : float = WornItem.k_for_px(host, t, want,
			SkinMetrics.sprite_scale(id, f, host.get_size()))
		if k <= 0.0:
			continue
		var w : Dictionary = SkinMetrics.worn_for(id, f, _worn, _pose).duplicate()
		w["k"] = clampf(k, 0.05, 3.0)
		SkinMetrics.worn_set(id, f, _worn, w, _pose)
	_dirty = true
	_refresh()
	_set_status("ширина %d px разослана на все жиры" % int(round(want)))

func _refresh_info(id: String, tex: Texture2D) -> void:
	if tex == null:
		return
	var sz   : Vector2 = tex.get_size()
	var base : float = SkinMetrics.HEAD_TARGET_PX / sz.x * SkinMetrics.scale_for(id)
	var final : float = SkinMetrics.sprite_scale(id, _fat, sz)
	var tweak : float = SkinMetrics.tweak_for(id, _fat)
	# Коробочный зажим = итог, делённый на замер и ручную правку. Считаем, а не
	# повторяем формулу: повтор разъедется с `sprite_scale` при первой правке.
	var clamp_k : float = final / maxf(0.0001, base * tweak)
	var box  : Vector2 = SkinMetrics.box_for(id, _fat)
	var head : Vector2 = SkinMetrics.head_size_for(id, _fat)
	var head_px : Vector2 = Vector2(head.x * sz.x * final, head.y * sz.y * final)
	var body_px : Vector2 = Vector2(box.x * sz.x * final, box.y * sz.y * final)
	var nudge : Vector2 = SkinMetrics.nudge_for(id, _fat)

	var rows : Array = [
		["СКИН", "%s · жир %d" % [id, _fat + 1]],
		["кадр", "%s · %d×%d"
			% [("покой" if _pose.is_empty() else "ест"), int(sz.x), int(sz.y)]],
		["", ""],
		["замер", "×%.3f" % base],
		["коробка", "×%.3f" % clamp_k],
		["ручная", "×%.3f" % tweak],
		["ИТОГ", "×%.3f" % final],
		["", ""],
		["голова", "%d×%d px" % [int(head_px.x), int(head_px.y)]],
		["туша", "%d×%d px" % [int(body_px.x), int(body_px.y)]],
		["сдвиг", "%.4f / %.4f" % [nudge.x, nudge.y]],
		["", ""],
		["вещь", _worn_size_line(id, tex)],
		["", _worn_line(id)],
	]
	# Звёздочка у ручной правки — единственный способ отличить «так и было
	# замерено» от «я это подвинул»: числа в панели одинаковые в обоих случаях.
	if not is_equal_approx(tweak, 1.0) or nudge != Vector2.ZERO:
		rows[5][1] = String(rows[5][1]) + "  *"
	# В КАДРЕ ПОЕДАНИЯ панель показывает ЕГО числа, а не числа покоя: правятся
	# сейчас они, и видеть в строке «ручная» чужое значение — верный способ
	# крутить кнопку, глядя не туда.
	if not _pose.is_empty():
		var pk : float   = SkinMetrics.pose_k(id, _pose, _fat)
		var pt : float   = SkinMetrics.pose_tweak_for(id, _fat, _pose)
		var pn : Vector2 = SkinMetrics.pose_nudge_for(id, _fat, _pose)
		rows[3][0] = "замер кадра"
		rows[3][1] = "×%.3f" % (pk / maxf(0.0001, pt))
		rows[5][1] = "×%.3f%s" % [pt, ("  *" if not is_equal_approx(pt, 1.0)
			or pn != Vector2.ZERO else "")]
		rows[6][1] = "×%.3f" % (final * pk)
		rows[10][1] = "%.4f / %.4f" % [pn.x, pn.y]
		# Голова и туша замерены по кадру покоя; на поедании это чужие числа, и
		# показывать их как свои нельзя.
		rows[8][1] = "по кадру покоя"
		rows[9][1] = "по кадру покоя"
	for i in mini(_info.size(), rows.size()):
		var l : Label = _info[i]
		var r : Array = rows[i]
		# Отступ — это когда пусто В ОБЕИХ клетках. Раньше хватало пустой
		# подписи, и продолжение строки без своей подписи («ш0.74 x0.020 …»
		# под размером вещи) молча стиралось как отступ.
		if String(r[0]).is_empty() and String(r[1]).is_empty():
			l.text = ""
			continue
		l.text = "%-9s %s" % [String(r[0]), String(r[1])]
		# Красным то, что расходится с эталоном: голова заметно мельче 91 px
		# означает, что скин ужат коробкой, и это надо видеть без счёта в уме.
		if String(r[0]) == "голова":
			l.modulate = CLR_WARN if absf(head_px.x - SkinMetrics.HEAD_TARGET_PX) > 12.0 else CLR_TEXT
		elif String(r[0]) == "коробка":
			l.modulate = CLR_WARN if clamp_k < 0.995 else CLR_DIM
		elif String(r[0]) == "ИТОГ" or String(r[0]) == "СКИН":
			l.modulate = CLR_TEXT
		elif String(r[0]).is_empty():
			l.modulate = CLR_DIM   # продолжение предыдущей строки
		else:
			l.modulate = CLR_DIM

# ── Разметка ─────────────────────────────────────────────────────────────────
# Рисуется в `_draw`, а не спрайтами: линий и рамок полтора десятка, и держать
# под каждую по узлу значит пересобирать полтора десятка узлов на каждое
# переключение жира.
#
# Отдельным УЗЛОМ, а не в `_draw` самой лаборатории: собственный `_draw` узла
# рисуется ПОД его детьми, а разметка обязана лечь поверх скина — именно их
# взаимное положение и проверяется.
# ── Разметка предмета ────────────────────────────────────────────────────────
# Здесь важны ровно две вещи, и обе — про СООТНОШЕНИЕ, а не про абсолют:
#   рисунок против лейна — влезает предмет в свою линию или лезет в соседние;
#   хитбокс против рисунка — бьёт он там, где нарисован, или мимо себя.
#
# Поэтому рядом с предметом рисуется и круг его зоны удара, и коробка лейна.
func _draw_item_marks(c: CanvasItem) -> void:
	var tex : Texture2D = load(_item_path()) as Texture2D
	if tex == null:
		return
	var vp := get_viewport().get_visible_rect().size
	var lane_h : float = vp.y / float(LANE_COUNT)

	# Коробка лейна вокруг предмета: перерос её — начал есть соседние линии.
	_rect(c, _hero_pos, Vector2(lane_h, lane_h), CLR_BODY)

	# Хитбокс — тем же зелёным, что у героя: это одно и то же понятие.
	c.draw_arc(_hero_pos, _item_hit_r(), 0.0, TAU, 48, CLR_HITBOX, 1.5)

	# Габариты нарисованного — красным, если вылез за лейн.
	var r : Rect2i = ItemSizing.content_rect(tex)
	var k : float = ItemSizing.content_scale(tex, ItemSizing.BASE_PX) \
		* float(ITEM_TWEAKS.mult_for(_item_path())["size"])
	var draw_px := Vector2(float(r.size.x) * k, float(r.size.y) * k)
	var over : bool = draw_px.y > lane_h
	_rect(c, _hero_pos, draw_px, CLR_WARN if over else CLR_RULER)

# Правая панель в режиме предметов. Показывает ЧИСЛА, по которым правят: сам
# множитель, во что он превращает размер и хитбокс, и не вылез ли предмет из
# своей линии.
func _refresh_item_info() -> void:
	var tex : Texture2D = load(_item_path()) as Texture2D
	var m : Dictionary = ITEM_TWEAKS.mult_for(_item_path())
	var vp := get_viewport().get_visible_rect().size
	var lane_h : float = vp.y / float(LANE_COUNT)
	var lines : Array = []
	lines.append("ПРЕДМЕТ: %s" % _item_name())
	lines.append(_item_path().replace("res://assets/", ""))
	lines.append("")
	if tex != null:
		var r : Rect2i = ItemSizing.content_rect(tex)
		var base : float = ItemSizing.content_scale(tex, ItemSizing.BASE_PX)
		var k : float = base * float(m["size"])
		var draw_px := Vector2(float(r.size.x) * k, float(r.size.y) * k)
		lines.append("кадр      %d × %d" % [int(tex.get_size().x), int(tex.get_size().y)])
		lines.append("рисунок   %d × %d" % [r.size.x, r.size.y])
		lines.append("")
		lines.append("размер   ×%.2f" % float(m["size"]))
		lines.append("на экране %d × %d px" % [int(draw_px.x), int(draw_px.y)])
		lines.append("лейн      %d px" % int(lane_h))
		if draw_px.y > lane_h:
			lines.append("ВЫЛЕЗ ИЗ ЛИНИИ на %d px" % int(draw_px.y - lane_h))
		lines.append("")
	lines.append("хитбокс  ×%.2f" % float(m["hit"]))
	lines.append("радиус    %d px" % int(_item_hit_r()))
	lines.append("")
	lines.append("правка есть" if ITEM_TWEAKS.has_tweak(_item_path()) else "правки нет")
	for i in _info.size():
		var l : Label = _info[i]
		l.text     = String(lines[i]) if i < lines.size() else ""
		l.modulate = CLR_WARN if l.text.begins_with("ВЫЛЕЗ") else CLR_TEXT

class Marks extends Node2D:
	var lab : Node = null
	func _draw() -> void:
		if lab != null:
			lab.call("draw_marks", self)

func draw_marks(c: CanvasItem) -> void:
	var vp := get_viewport().get_visible_rect().size
	var lane_h : float = vp.y / float(LANE_COUNT)

	# Лейны: границы сплошными, середины — бледнее. Скин садится по СЕРЕДИНЕ,
	# и без неё непонятно, сполз он или так и стоит.
	for i in range(1, LANE_COUNT):
		c.draw_line(Vector2(0.0, lane_h * i), Vector2(vp.x, lane_h * i), CLR_LANE, 1.0)
	for i in LANE_COUNT:
		var y : float = lane_h * (float(i) + 0.5)
		c.draw_line(Vector2(0.0, y), Vector2(vp.x, y), CLR_LANE_C, 1.0)

	if _mode == "items":
		_draw_item_marks(c)
		return

	var id : String = _skin_id()
	var tex : Texture2D = _tex()
	if tex == null:
		return
	var sz : Vector2 = tex.get_size()
	var k : float = SkinMetrics.sprite_scale(id, _fat, sz)

	# Разлёт всего рисунка и коробка туши — рамками вокруг героя.
	_rect(c, _hero_pos, SkinMetrics.MAX_SPREAD, CLR_SPREAD)
	_rect(c, _hero_pos, SkinMetrics.MAX_BODY,  CLR_BODY)

	var head : Vector2 = SkinMetrics.head_size_for(id, _fat)
	var head_px := Vector2(head.x * sz.x * k, head.y * sz.y * k)
	# РАМКИ ГОЛОВЫ И ТУШИ ЗАМЕРЕНЫ ПО КАДРУ ПОКОЯ, и на кадре поедания их не
	# рисуем вовсе. Рот открыт, голова наклонена, рамка у этого кадра своя — а
	# нарисованная поверх чужая рамка не «примерно верна», она врёт ровно в том
	# месте, ради которого сюда и пришли. Хитбокс и линейка эталона остаются:
	# по ним поедание и подгоняют.
	if _pose.is_empty():
		# Габариты САМОГО скина в этих же координатах — видно, упёрся он в
		# коробку или в ней ещё есть место.
		var box : Vector2 = SkinMetrics.box_for(id, _fat)
		_rect(c, _hero_pos, Vector2(box.x * sz.x * k, box.y * sz.y * k),
			Color(CLR_BODY.r, CLR_BODY.g, CLR_BODY.b, 0.30))
		# Голова: рамка вокруг того, что замер считает лицом. Она обязана сидеть
		# на хитбоксе — ради этого и заведён сдвиг.
		_rect(c, _hero_pos, head_px, Color(0.55, 0.80, 1.00, 0.55))

	# Хитбокс — последним и ярче всех: это единственная линия, по которой скин
	# на самом деле бьётся о предметы.
	c.draw_arc(_hero_pos, _hitbox_r, 0.0, TAU, 48, CLR_HITBOX, 1.5)
	c.draw_line(_hero_pos - Vector2(4.0, 0.0), _hero_pos + Vector2(4.0, 0.0), CLR_HITBOX, 1.0)
	c.draw_line(_hero_pos - Vector2(0.0, 4.0), _hero_pos + Vector2(0.0, 4.0), CLR_HITBOX, 1.0)

	# Линейка эталона: 91 px — ширина классической головы, к ней приводятся все.
	# Под ней — настоящая ширина головы этого скина: разницу видно отрезком, а не
	# только числом в панели.
	#
	# СВЕРХУ, а не под героем: снизу их накрывал ряд кнопок — герой стоит на
	# y=325 при экране 430, и места там нет.
	_ruler(c, Vector2(_hero_pos.x, 54.0), SkinMetrics.HEAD_TARGET_PX, CLR_RULER)
	_ruler(c, Vector2(_hero_pos.x, 68.0), head_px.x, Color(1.0, 1.0, 1.0, 0.80))

func _rect(c: CanvasItem, center: Vector2, size: Vector2, col: Color) -> void:
	c.draw_rect(Rect2(center - size * 0.5, size), col, false, 1.0)

func _ruler(c: CanvasItem, center: Vector2, width: float, col: Color) -> void:
	var a := Vector2(center.x - width * 0.5, center.y)
	var b := Vector2(center.x + width * 0.5, center.y)
	c.draw_line(a, b, col, 1.0)
	c.draw_line(a - Vector2(0.0, 3.0), a + Vector2(0.0, 3.0), col, 1.0)
	c.draw_line(b - Vector2(0.0, 3.0), b + Vector2(0.0, 3.0), col, 1.0)

func _on_close() -> void:
	queue_free()
