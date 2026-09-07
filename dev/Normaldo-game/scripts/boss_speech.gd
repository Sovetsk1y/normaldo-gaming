extends RefCounted

# Реплика босса перед боем — ОДНА НА ВСЕХ.
#
# Каждый босс перед дракой говорит фразу: облачко выезжает справа, держится
# несколько секунд и гаснет, управление на это время заперто. Собирали его три
# раза, и три раза по-разному.
#
# Крокодил и хозяин клуба вышли почти одинаковыми — скруглённая панель `UiKit`,
# своя пара цветов, всплытие из 0.2. А Нога Ниндзя рисовал СВОЁ: белый
# прямоугольник с красной полосой сверху и повёрнутым хвостиком снизу. Рядом с
# двумя другими он читался не как «этот босс говорит иначе», а как экран из
# другой игры — тем более что говорят они подряд, в одном забеге, с разницей в
# один эпизод.
#
# Поэтому облачко здесь одно, а боссам оставлено то, что их и различает: ТЕКСТ и
# ПАРА ЦВЕТОВ. Заведут четвёртого босса — он получит тот же вид бесплатно, а не
# нарисует четвёртый вариант.
#
# ── Почему справа ────────────────────────────────────────────────────────────
# Босс стоит у правого края и занимает `boss_w` по ширине. Облачко ставится
# левее его силуэта: наехав на босса, оно закрыло бы ровно то, на что игрок в
# этот момент смотрит.
const UI_FONT := preload("res://assets/fonts/RussoOne-Regular.ttf")

const W        : float = 330.0
const H        : float = 84.0
const GAP      : float = 20.0   # от левого края босса до правого края облачка
const POP_TIME : float = 0.26
const OUT_TIME : float = 0.22
const LAYER    : int   = 95     # ниже титра BOSS FIGHT (99), выше забега

# Показать реплику и дождаться, пока она уйдёт.
#
# `host` — узел босса (нужен его `get_tree()` и `get_viewport_rect()`),
# `root` — куда вешать слой (корень сцены забега),
# `boss_w` — ширина силуэта босса,
# `y_ratio` — доля высоты экрана, на которой стоит облачко.
static func show(host: Node, root: Node, text: String, boss_w: float,
		bg: Color, border: Color, ink: Color,
		hold: float = 3.0, y_ratio: float = 0.32) -> void:
	if not is_instance_valid(host) or not is_instance_valid(root):
		return
	var vp : Vector2 = host.get_viewport_rect().size
	var cl := CanvasLayer.new()
	cl.layer = LAYER
	root.add_child(cl)

	var box := Control.new()
	box.size         = Vector2(W, H)
	box.position     = Vector2(maxf(10.0, vp.x - boss_w - W - GAP), vp.y * y_ratio)
	# Всплывает ОТ БОССА: точка роста у правого края облачка, там же, откуда
	# оно «сказано». Рост от центра читался бы как появление окна интерфейса.
	box.pivot_offset = Vector2(W, H * 0.5)
	box.scale        = Vector2(0.2, 0.2)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(box)

	UiKit.panel(box, Vector2.ZERO, Vector2(W, H), bg, 12, border, 3)

	var lbl := Label.new()
	lbl.add_theme_font_override("font", UI_FONT)
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.text                 = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl.autowrap_mode        = TextServer.AUTOWRAP_WORD_SMART
	lbl.modulate             = ink
	lbl.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	UiKit.place(box, lbl, Vector2(10.0, 0.0), Vector2(W - 20.0, H))

	var tw := box.create_tween()
	tw.tween_property(box, "scale", Vector2.ONE, POP_TIME)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await host.get_tree().create_timer(hold).timeout
	if not is_instance_valid(cl):
		return
	var out := box.create_tween()
	out.tween_property(box, "modulate:a", 0.0, OUT_TIME)
	out.tween_callback(cl.queue_free)
	await out.finished
