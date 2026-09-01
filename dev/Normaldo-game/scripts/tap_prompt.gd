extends Node2D

# ── Подсказка «тапай» ────────────────────────────────────────────────────────
# Картинка «TAP!» из набора выкриков и два тапающих пальца по бокам от неё.
#
# Кирпич общий на все мини-игры, где надо долбить по экрану: пицца-пати и
# ЖИРОБОСС. Раньше каждая рисовала свою подсказку СЛОВОМ «ТАПАЙ», набранным
# шрифтом, и у одной по бокам ещё стояли стрелки «назад» из экрана заданий.
# Рядом с рисованной пиццей и мордой босса это читалось как отладочная подпись:
# у игры есть свой набор выкриков, и подсказка обязана быть из него.
#
# Палец ТАПАЕТ: идёт вниз и В НИЖНЕЙ ТОЧКЕ меняет кадр на прижатый — с молниями
# и следом удара. Кадр меняется именно внизу, а не по таймеру: иначе прижатая
# ладонь мелькает на подъёме, и движение читается как дрожь. Кадр без движения —
# мигание, движение без кадра — качание; тап получается только из обоих сразу.
#
# Кадры авторские, режет их из раскладки `dev/tools/bake_tap.py`. Левый и правый
# палец нарисованы ОТДЕЛЬНО, а не зеркалятся: у них по-разному лежит большой
# палец и разлетаются молнии.

const TAP_TEX : Texture2D = preload("res://assets/ui/reactions/tap.png")
const FINGERS : Dictionary = {
	-1.0: [preload("res://assets/ui/reactions/finger_l1.png"),
	       preload("res://assets/ui/reactions/finger_l2.png")],
	 1.0: [preload("res://assets/ui/reactions/finger_r1.png"),
	       preload("res://assets/ui/reactions/finger_r2.png")],
}

const FINGER_H   : float = 74.0    # высота пальца на экране
const FINGER_GAP : float = 10.0    # зазор между надписью и пальцем
const DROP       : float = 20.0    # ход пальца вниз
const DOWN_T     : float = 0.15
const HOLD_T     : float = 0.08
const UP_T       : float = 0.19
const REST_T     : float = 0.09
const BLINK_T    : float = 0.26

var _taps  : Array = []
var _blink : Tween = null
var _tap_spr : Sprite2D = null
var _half_w : float = 0.0
var _half_h : float = 0.0

# Габариты ПОДСКАЗКИ ЦЕЛИКОМ, вместе с пальцами. Нужны тому, кто её ставит:
# подсказка ездит за пачкой пиццы, пачка паркуется у правого края и в середине
# экрана по высоте — без этих чисел правый палец уезжал за кадр, а верх картинки
# срезался о полосу интерфейса.
func half_width() -> float:
	return _half_w

func half_height() -> float:
	return _half_h

# `width` — ширина картинки TAP! на экране; пальцы считаются от неё.
func setup(width: float = 190.0) -> void:
	_tap_spr = Sprite2D.new()
	_tap_spr.texture = TAP_TEX
	_tap_spr.scale   = Vector2.ONE * (width / float(TAP_TEX.get_width()))
	add_child(_tap_spr)
	_half_w = width * 0.5
	_half_h = TAP_TEX.get_height() * _tap_spr.scale.y * 0.5

	for side in [-1.0, 1.0]:
		var frames : Array = FINGERS[side]
		var f := Sprite2D.new()
		f.texture        = frames[0]
		f.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var k : float = FINGER_H / float((frames[0] as Texture2D).get_height())
		f.scale    = Vector2(k, k)
		f.position = Vector2(
			side * (width * 0.5 + FINGER_GAP + (frames[0] as Texture2D).get_width() * k * 0.5),
			-DROP * 0.5)
		add_child(f)
		_half_w = maxf(_half_w,
			absf(f.position.x) + (frames[0] as Texture2D).get_width() * k * 0.5)
		_half_h = maxf(_half_h, absf(f.position.y) + DROP + FINGER_H * 0.5)
		_taps.append(_tap_cycle(f, frames))

	# Мигание всей подсказки целиком: картинка и пальцы дышат вместе, иначе на
	# экране три независимо пульсирующих предмета.
	scale = Vector2(0.2, 0.2)
	_blink = create_tween().set_loops()
	_blink.tween_property(self, "scale", Vector2(1.12, 1.12), BLINK_T) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_blink.parallel().tween_property(self, "modulate:a", 0.55, BLINK_T)
	_blink.tween_property(self, "scale", Vector2.ONE, BLINK_T)
	_blink.parallel().tween_property(self, "modulate:a", 1.0, BLINK_T)

func _tap_cycle(f: Sprite2D, frames: Array) -> Tween:
	var y0 : float = f.position.y
	var tw := f.create_tween().set_loops()
	tw.tween_property(f, "position:y", y0 + DROP, DOWN_T) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		if is_instance_valid(f):
			f.texture = frames[1])
	tw.tween_interval(HOLD_T)
	tw.tween_callback(func():
		if is_instance_valid(f):
			f.texture = frames[0])
	tw.tween_property(f, "position:y", y0, UP_T) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_interval(REST_T)
	return tw

# Погасить твины, не удаляя узел: вызывающий сам решает, растворить его или
# убрать сразу. Забыть об этом нельзя — зацикленные твины держат ссылки на
# спрайты и продолжают тикать по уже спрятанной подсказке.
func stop() -> void:
	for t in _taps:
		if t != null and (t as Tween).is_valid():
			(t as Tween).kill()
	_taps.clear()
	if _blink != null and _blink.is_valid():
		_blink.kill()
	_blink = null

# Плавно убрать подсказку с экрана.
func dismiss(t: float = 0.18) -> void:
	stop()
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, t)
	tw.tween_callback(queue_free)
