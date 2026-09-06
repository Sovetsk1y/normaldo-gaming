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
# Шляпа и маска — следующий шаг: сейчас `HAT_POS` одна на все четырнадцать
# скинов, и разложить её по скинам и жирам это отдельная правка в игре, а не
# только в лаборатории.
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

var _hud   : Node = null
var _skin  : int  = 0
var _fat   : int  = 0
var _root  : Control = null
var _sprite : Sprite2D = null
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
var _skin_lbl : Label = null
var _last_chip_label : Label = null
var _head_ruler_lbl : Label = null

func setup(hud: Node) -> void:
	_hud = hud
	_skin = SkinRegistry.get_skin_index(SaveData.active_skin)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 90
	_read_live_geometry()
	_snapshot = SkinMetrics.layout_snapshot()
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
	return SkinRegistry.get_avatar_texture(_skin_id(), _fat)

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
	_label("эталон 91", 9, CLR_RULER, Vector2(_hero_pos.x + 56.0, 46.0),
		Vector2(80.0, 16.0), HORIZONTAL_ALIGNMENT_LEFT)
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
	UiKit.panel(_root, Vector2(x, 10.0), Vector2(w, 250.0),
		Color(0.05, 0.04, 0.03, 0.92), 10, Color(0.30, 0.26, 0.18, 0.95))
	_info.clear()
	for i in 11:
		_info.append(_label("", 11, CLR_TEXT, Vector2(x + 10.0, 16.0 + 21.0 * float(i)),
			Vector2(w - 20.0, 20.0), HORIZONTAL_ALIGNMENT_LEFT))

func _build_controls(vp: Vector2) -> void:
	# Назад
	_chip(Vector2(10.0, 10.0), Vector2(52.0, 26.0), "НАЗАД", _on_close)

	# Скин: влево / вправо и подпись между ними.
	var y : float = vp.y - 36.0
	_chip(Vector2(10.0, y), Vector2(34.0, 26.0), "◀", func(): _step_skin(-1))
	_chip(Vector2(160.0, y), Vector2(34.0, 26.0), "▶", func(): _step_skin(1))
	_skin_lbl = _label("", 12, CLR_TEXT, Vector2(48.0, y), Vector2(108.0, 26.0),
		HORIZONTAL_ALIGNMENT_CENTER)

	# Жир 1…4 — четыре кнопки, а не стрелки: прыгать между состояниями надо
	# в любом порядке, «жир 1 против жира 4» сравнивают чаще соседних.
	_fat_lbl.clear()
	for i in 4:
		var bx : float = 210.0 + 40.0 * float(i)
		_chip(Vector2(bx, y), Vector2(34.0, 26.0), str(i + 1), func(): _set_fat(i))
		_fat_lbl.append(_last_chip_label)

	_chip(Vector2(390.0, y), Vector2(96.0, 26.0), "РАЗМЕТКА", _toggle_marks)

	# Размер: шаг 0.01 — с ним заметно за одно нажатие и не проскакивает мимо.
	_chip(Vector2(500.0, y), Vector2(30.0, 26.0), "−", func(): _bump_tweak(-0.01))
	_chip(Vector2(534.0, y), Vector2(30.0, 26.0), "+", func(): _bump_tweak(0.01))
	_chip(Vector2(576.0, y), Vector2(66.0, 26.0), "СБРОС", _reset_current)
	_chip(Vector2(648.0, y), Vector2(72.0, 26.0), "ОТМЕНА", _revert_all)
	_chip(Vector2(726.0, y), Vector2(92.0, 26.0), "СОХРАНИТЬ", _save)

	_status = _label("", 10, CLR_DIM, Vector2(10.0, y - 22.0), Vector2(500.0, 18.0),
		HORIZONTAL_ALIGNMENT_LEFT)

func _chip(pos: Vector2, size: Vector2, text: String, on_press: Callable) -> void:
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
	var k : float = SkinMetrics.sprite_scale(id, _fat, tex.get_size())
	var sz : Vector2 = tex.get_size()
	if k <= 0.0 or sz.x <= 0.0 or sz.y <= 0.0:
		return
	var n : Vector2 = SkinMetrics.nudge_for(id, _fat)
	n -= Vector2(delta.x / (sz.x * k), delta.y / (sz.y * k))
	_apply(id, SkinMetrics.tweak_for(id, _fat), n)

func _bump_tweak(d: float) -> void:
	var id : String = _skin_id()
	# Нижняя граница 0.10, а не 0: на нуле скин исчезает, и вернуть его можно
	# только СБРОСОМ — а игрок к тому моменту уже не понимает, что произошло.
	var t : float = clampf(SkinMetrics.tweak_for(id, _fat) + d, 0.10, 4.0)
	_apply(id, t, SkinMetrics.nudge_for(id, _fat))

func _apply(id: String, tweak: float, nudge: Vector2) -> void:
	SkinMetrics.layout_set(id, _fat, tweak, nudge)
	_dirty = true
	_refresh()

func _reset_current() -> void:
	_apply(_skin_id(), 1.0, Vector2.ZERO)
	_set_status("сброшено к замеру: %s, жир %d" % [_skin_id(), _fat + 1])

func _revert_all() -> void:
	SkinMetrics.layout_restore(_snapshot)
	_dirty = false
	_refresh()
	_set_status("все правки отменены")

func _save() -> void:
	var err : String = SkinMetrics.layout_save()
	if err.is_empty():
		_dirty = false
		_set_status("сохранено в dev/skin_layout.json")
	else:
		# Отдельным цветом и словами: запись в res:// работает только при
		# запуске из редактора, и молчаливый отказ съел бы всю правку.
		_set_status("НЕ СОХРАНЕНО: %s" % err, CLR_WARN)

func _set_status(text: String, col: Color = CLR_DIM) -> void:
	if is_instance_valid(_status):
		_status.text = text
		_status.modulate = col

# ── Обновление ───────────────────────────────────────────────────────────────

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
	var id : String = _skin_id()
	var tex : Texture2D = _tex()
	_skin_lbl.text = String(SkinRegistry.SKINS[_skin].get("name_ru", id))
	for i in _fat_lbl.size():
		(_fat_lbl[i] as Label).modulate = CLR_TEXT if i == _fat else CLR_DIM

	# Посадка — ТА ЖЕ арифметика, что в `normaldo._apply_skin_to_sprite`. Своя
	# копия формулы разошлась бы с игрой на первой же правке, и лаборатория
	# показывала бы не то, что видит игрок.
	if tex != null:
		var s : float = SkinMetrics.sprite_scale(id, _fat, tex.get_size())
		_sprite.texture  = tex
		_sprite.scale    = Vector2(s, s)
		_sprite.position = _hero_pos + _sprite_offset(id, tex, s)
	_marks.queue_redraw()
	_refresh_info(id, tex)
	if tex != null and is_instance_valid(_head_ruler_lbl):
		var hd : Vector2 = SkinMetrics.head_size_for(id, _fat)
		_head_ruler_lbl.text = "голова %d" % int(hd.x * tex.get_size().x
			* SkinMetrics.sprite_scale(id, _fat, tex.get_size()))

func _sprite_offset(id: String, tex: Texture2D, s: float) -> Vector2:
	if id == "classic":
		return CLASSIC_NUDGE_PX
	var sz : Vector2 = tex.get_size()
	var off := SkinMetrics.offset_for(id, _fat)
	return Vector2(-off.x * sz.x * s, -off.y * sz.y * s)

# Правая панель. Показывает не «что нарисовано», а ЧИСЛА, по которым это
# нарисовано, — и отдельно то, из чего они сложились: замер, коробка, ручная
# правка. Иначе непонятно, почему скин мелкий: так замерили или так ужали.
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
		["кадр", "%d×%d" % [int(sz.x), int(sz.y)]],
		["", ""],
		["замер", "×%.3f" % base],
		["коробка", "×%.3f" % clamp_k],
		["ручная", "×%.3f" % tweak],
		["ИТОГ", "×%.3f" % final],
		["", ""],
		["голова", "%d×%d px" % [int(head_px.x), int(head_px.y)]],
		["туша", "%d×%d px" % [int(body_px.x), int(body_px.y)]],
		["сдвиг", "%.4f / %.4f" % [nudge.x, nudge.y]],
	]
	# Звёздочка у ручной правки — единственный способ отличить «так и было
	# замерено» от «я это подвинул»: числа в панели одинаковые в обоих случаях.
	if not is_equal_approx(tweak, 1.0) or nudge != Vector2.ZERO:
		rows[5][1] = String(rows[5][1]) + "  *"
	for i in _info.size():
		var l : Label = _info[i]
		var r : Array = rows[i]
		if String(r[0]).is_empty():
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

	var id : String = _skin_id()
	var tex : Texture2D = _tex()
	if tex == null:
		return
	var sz : Vector2 = tex.get_size()
	var k : float = SkinMetrics.sprite_scale(id, _fat, sz)

	# Разлёт всего рисунка и коробка туши — рамками вокруг героя.
	_rect(c, _hero_pos, SkinMetrics.MAX_SPREAD, CLR_SPREAD)
	_rect(c, _hero_pos, SkinMetrics.MAX_BODY,  CLR_BODY)

	# Габариты САМОГО скина в этих же координатах — видно, упёрся он в коробку
	# или в ней ещё есть место.
	var box : Vector2 = SkinMetrics.box_for(id, _fat)
	_rect(c, _hero_pos, Vector2(box.x * sz.x * k, box.y * sz.y * k),
		Color(CLR_BODY.r, CLR_BODY.g, CLR_BODY.b, 0.30))

	# Голова: рамка вокруг того, что замер считает лицом. Она обязана сидеть на
	# хитбоксе — ради этого и заведён сдвиг.
	var head : Vector2 = SkinMetrics.head_size_for(id, _fat)
	var head_px := Vector2(head.x * sz.x * k, head.y * sz.y * k)
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
