extends Node2D

# ── Кольцо вызова ─────────────────────────────────────────────────────────────
# Окружность, разбегающаяся от телефона босса клуба и гаснущая по дороге.
#
# Нужна затем, что звонок — это ТЕЛЕГРАФ ЦЕЛОГО АКТА: пока хозяин не позвонил,
# никто не придёт. Звук на маленьком экране легко пропустить, а расходящееся
# кольцо видно боковым зрением, даже когда смотришь на свою линию. Цвет у него
# тот же, что у полос вызова этого акта, — по нему видно и КОГО набрали.
#
# Рисуется кодом, а не спрайтом: это одна окружность, и заводить под неё ассет
# значило бы завести ещё и его импорт с размерами.

const LIFE : float = 0.55
const R0   : float = 10.0
const R1   : float = 96.0

var color : Color = Color(1.0, 0.5, 1.0)

var _t : float = 0.0

func _ready() -> void:
	z_index = 41
	add_to_group("club_fx")

func _process(delta: float) -> void:
	_t += delta
	if _t >= LIFE:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var k : float = clampf(_t / LIFE, 0.0, 1.0)
	var r : float = lerpf(R0, R1, k)
	var a : float = (1.0 - k) * 0.75
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 32,
		Color(color.r, color.g, color.b, a), 2.5, true)
