extends Node2D

# ── Дымовая завеса жёлтого ниндзя ─────────────────────────────────────────────
# Это НЕ препятствие. У облака нет ни хитбокса, ни группы `obstacle`, ни урона:
# Нормальдо всегда пролетает под ним, и никогда не бывает так, что он умер «от
# дыма».
#
# Работа у дыма другая — ЗАКРЫВАТЬ. Шашка летит в конкретный летящий предмет,
# облако садится на него и едет вместе с ним, пока тот не уйдёт за край или его
# не сломают. Игрок видит, что там что-то есть, но не видит ЧТО: банан это или
# пицца, уходить с линии или наоборот лететь туда.
#
# Первая версия ставила облака по случайным лейнам и давала им урон. Тогда
# жёлтый превращался в третий вид стены — а стен в игре и так хватает, и от них
# уворачиваются ровно одинаково. «Не вижу, что летит» — вопрос, которого больше
# не задаёт никто.
#
# Рисуется поверх Нормальдо намеренно (z выше его тройки): дым, из-под которого
# торчит герой, читается как «дым за спиной», а не как «я в дыму».
#
# См. /Концепция/Паттерны препятствий.md → «Ниндзя»

const FADE_IN  : float = 0.22
const FADE_OUT : float = 0.45

var _target : Node2D = null
var _sprite : Sprite2D = null
var _dying  : bool = false
# Скорость потока предметов. Дым — часть этого потока, а не наклейка на стекле:
# он всегда уезжает влево ровно как всё остальное, даже когда завешивать уже
# нечего (шашка ушла в пустой лейн или предмет под ней сломали). Первая версия
# без этой скорости просто висела в точке падения — и читалась как грязь на
# экране, а не как облако в кадре.
var speed : float = 0.0

# `target` — предмет, который завешиваем. Пока он жив, облако сидит на нём;
# дальше едет своим ходом и тает.
func setup(sprite: Sprite2D, target: Node2D, life: float, item_speed: float = 0.0) -> void:
	_sprite = sprite
	_target = target
	speed   = item_speed
	add_child(sprite)
	var tw := sprite.create_tween()
	tw.tween_property(sprite, "modulate:a", 0.92, FADE_IN)
	tw.tween_interval(life)
	tw.tween_callback(_dissolve)

func _process(delta: float) -> void:
	# Едем влево ВСЕГДА, в том числе пока растворяемся: облако, замершее на
	# полсекунды фейда, выдаёт себя ничуть не меньше, чем висящее целиком.
	position.x -= speed * delta
	if _dying:
		return
	if _target != null and not is_instance_valid(_target):
		# Предмет сломали или он ушёл за край — закрывать больше нечего, но
		# уезжать облако продолжает.
		_target = null
		_dissolve()
		return
	if is_instance_valid(_target):
		global_position = _target.global_position

func _dissolve() -> void:
	if _dying:
		return
	_dying = true
	if not is_instance_valid(_sprite):
		queue_free()
		return
	var tw := _sprite.create_tween()
	tw.tween_property(_sprite, "modulate:a", 0.0, FADE_OUT)
	tw.tween_callback(queue_free)
