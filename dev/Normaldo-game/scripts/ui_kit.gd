class_name UiKit
extends RefCounted

# ── Общие кирпичи интерфейса ──────────────────────────────────────────────────
# Интерфейс собирается кодом, и каждая новая панель до сих пор рисовалась
# заново: скругления и рамки у экрана скинов, заданий и лидеров разъезжались,
# хотя выглядеть должны одинаково. Здесь лежит то, что нужно всем.
#
# См. /Концепция/UI — паттерны интерфейса.md

# Скруглённая подложка. Радиус 12 — карточка, 8 — кнопка и чип, 6 — полоса.
static func rounded(fill: Color, radius: int,
		border: Color = Color(0, 0, 0, 0), border_w: int = 2) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.corner_radius_top_left     = radius
	sb.corner_radius_top_right    = radius
	sb.corner_radius_bottom_left  = radius
	sb.corner_radius_bottom_right = radius
	if border.a > 0.0:
		sb.border_color = border
		sb.border_width_left   = border_w
		sb.border_width_right  = border_w
		sb.border_width_top    = border_w
		sb.border_width_bottom = border_w
	return sb

# Положить узел в родителя и ТОЛЬКО ПОТОМ задать размер.
#
# Пока Control не в дереве, он не видит темы сцены и зажимает `size` по
# минимальному размеру ТЕМЫ ПО УМОЛЧАНИЮ. Для подписи это 48 px по высоте:
# выставленные до add_child() 24 молча превращаются в 48, а обратно Godot
# размер уже не ужимает. Видно это только там, где строки стоят вплотную —
# в таблице призов автомата последняя строка вылезала за панель.
static func place(parent: Node, ctrl: Control, pos: Vector2, size: Vector2) -> Control:
	parent.add_child(ctrl)
	ctrl.position = pos
	ctrl.size     = size
	return ctrl

# Усадка при нажатии. Один тайминг на всю игру.
const PRESS_SCALE : float = 0.90
const PRESS_TIME  : float = 0.07

# Кнопка переживает свой экран, и об этом надо помнить ЗДЕСЬ, а не в каждом
# экране заново.
#
# Порядок сигналов у Godot такой: `pressed` → `button_up`. То есть обработчик
# нажатия успевает увести игрока с экрана ДО того, как придёт отпускание, а за
# ним ещё и `mouse_exited` — вьюпорт шлёт его кнопке, когда её вынимают из
# дерева. Выход из забега при этом делает reload_current_scene(), а тот вынимает
# сцену из дерева СРАЗУ и удаляет только на следующем кадре: в этом окне узел
# ещё `is_instance_valid()`, но create_tween() уже возвращает null. Отсюда
# «Cannot call method 'set_pause_mode' on a null value» по кнопке выхода.
#
# Проверять надо не валидность узла, а то, что он в дереве. Размер выставляем
# напрямую: анимировать уже нечего, но масштаб обязан вернуться к единице —
# иначе усаженная кнопка такой и останется на снимке экрана.
static func press_anim(visual_root: Control, pressed: bool) -> void:
	if not is_instance_valid(visual_root):
		return
	var target := Vector2.ONE * (PRESS_SCALE if pressed else 1.0)
	if not visual_root.is_inside_tree():
		visual_root.scale = target
		return
	# Твин привязан к тому, что анимирует, — и умирает вместе с ним.
	var tw := visual_root.create_tween()
	if tw == null:
		visual_root.scale = target
		return
	# Экраны паузы и настроек живут поверх остановленного дерева: без этого
	# усадка на них замирает нажатой.
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(visual_root, "scale", target, PRESS_TIME)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

# Пульсация — «единственный движущийся элемент» экрана.
#
# Узел на момент вызова часто ЕЩЁ НЕ В ДЕРЕВЕ: карточки собираются отдельной
# функцией и добавляются в экран потом. `create_tween()` на отцепленном узле
# возвращает null, и пульсация молча не заводится — экран выглядит собранным
# правильно, просто ничего не двигается, а в консоль сыпется «Cannot call
# method 'set_loops' on a null value».
#
# Поэтому старт откладывается до входа в дерево. Так вызывающему коду не нужно
# знать, в каком порядке его собирают.
static func pulse(node: CanvasItem, property: String, to_value: Variant,
		back_value: Variant, half_period: float) -> void:
	if not is_instance_valid(node):
		return
	if not node.is_inside_tree():
		node.tree_entered.connect(
			func() -> void:
				UiKit.pulse(node, property, to_value, back_value, half_period),
			CONNECT_ONE_SHOT)
		return
	var tw := node.create_tween()
	if tw == null:
		return
	tw.set_loops()
	tw.tween_property(node, property, to_value, half_period)
	tw.tween_property(node, property, back_value, half_period)

# Одиночный переезд свойства — выезд панели, уход интерфейса за край и прочее
# «доехать отсюда туда».
#
# Третье место, где вылезает та же беда, что у `press_anim` и `pulse`: узел уже
# вынут из дерева, а `create_tween()` на таком возвращает null. Здесь она
# приходит с неожиданной стороны — не от кнопки, а от ЧУЖОГО сигнала. Босс на
# своём `tree_exited` возвращает интерфейс забега, и при перезагрузке сцены из
# дерева вынимают обоих: босс уходит, дёргает обработчик, а интерфейс к этому
# моменту уже отцеплен.
#
# Значение при этом обязано доехать: анимировать нечего, но если бросить
# полпути, интерфейс останется стоять за краем экрана. Поэтому не в дереве —
# ставим напрямую и выходим.
static func slide_to(node: CanvasItem, property: String, to_value: Variant,
		duration: float, trans: int = Tween.TRANS_SINE,
		ease_type: int = Tween.EASE_OUT) -> void:
	if not is_instance_valid(node):
		return
	if not node.is_inside_tree():
		node.set_indexed(property, to_value)
		return
	# Твин привязан к тому, что анимирует, — и умирает вместе с ним.
	var tw := node.create_tween()
	if tw == null:
		node.set_indexed(property, to_value)
		return
	tw.tween_property(node, property, to_value, duration) \
		.set_trans(trans).set_ease(ease_type)

# Панель со скруглением — самый частый вызов, чтобы не писать три строки подряд.
static func panel(parent: Node, pos: Vector2, size: Vector2, fill: Color,
		radius: int, border: Color = Color(0, 0, 0, 0), border_w: int = 2) -> Panel:
	var p := Panel.new()
	p.add_theme_stylebox_override("panel", rounded(fill, radius, border, border_w))
	p.size         = size
	p.position     = pos
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(p)
	return p
