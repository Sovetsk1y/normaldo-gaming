extends SceneTree

# Иконки главного экрана: шайба у всех шести ОДНА И ТА ЖЕ.
#   godot --headless --path . --script res://dev/smoke_menu_icons.gd
#
# Проверка нужна потому, что набор собран ПО ЧАСТЯМ: слоты пришли готовой
# картинкой от автора, остальные пять печёт `dev/tools/bake_menu_icon.py` из
# голых рисунков. Достаточно поменять в скрипте радиус на полпикселя или принести
# новую иконку мимо скрипта — и в столбце, где круги стоят в сорока пикселях друг
# от друга, один окажется чуть другим. По шести отдельным файлам глазами это не
# ловится, а на экране видно сразу.
#
# Меряется не «похожесть картинок» — рисунки внутри у всех разные и проверки не
# касаются, — а сама шайба: кадр, кольцо и спад ореола.
#
# Ореол считается МЕДИАНОЙ по кольцу радиуса, а не значением в точке. Рисунок
# заходит на шайбу и по диагоналям вылезает за неё: у книги угол рисунка достаёт
# до двадцатого пикселя от центра, и проба, ткнувшая ровно туда, показала бы
# книгу вместо ореола. Больше половины кольца рисунок не закрывает никогда —
# медиана поэтому и держится.

# Иконка → минимальная ПЛОТНОСТЬ (сколько пикселей файла на единицу замера).
#
# Пять печёт `bake_menu_icon.py` из оригиналов автора в 500 px, и печёт он их в
# ЧЕТЫРЁХ пикселях на единицу: на телефоне кадр иконки выходит около 190 px, и
# файл в 55 раздувался бы втрое — это и читалось как «иконки заквадратились».
# Плотность здесь и проверяется: пересобрать набор обратно в 55 можно одним
# неверным K в скрипте, а на глаз в 55-пиксельных файлах разницы не видно.
#
# СЛОТЫ — исключение и стоят единицей: это готовая картинка автора, оригинала
# крупнее у нас нет. Как только он пришлёт — строку править вместе с набором.
const ICONS : Dictionary = {
	"res://assets/ui/menu/icons/settings.png":    4,   # НАСТРОЙКИ
	"res://assets/ui/menu/icons/book.png":        4,   # КНИГА УЧИТЕЛЯ
	"res://assets/ui/menu/icons/skins.png":       4,   # СКИНЫ
	"res://assets/ui/menu/icons/slots.png":       1,   # СЛОТЫ — авторская, эталон
	"res://assets/ui/menu/icons/quests.png":      4,   # ЗАДАНИЯ
	"res://assets/ui/menu/icons/leaderboard.png": 4,   # ЛИДЕРЫ
}

# Замер по авторской иконке слотов. Кадр 55×55, центр (27, 27) — В ЕДИНИЦАХ
# ЗАМЕРА. Всё, что ниже, умножается на плотность конкретного файла: геометрия
# шайбы у набора одна, отличается только то, сколькими пикселями она описана.
const FRAME  : int   = 55
const CENTER : float = 27.0
# Спад ореола: расстояние от центра → альфа. С восемнадцатого пикселя не
# начинаем — там граница кольца, и один и тот же круг с разным сглаживанием даёт
# на ней законный разброс.
const GLOW_PROFILE : Dictionary = {
	19: 56, 20: 45, 21: 33, 22: 23, 23: 15, 24: 9, 25: 4,
}
const GLOW_TOL : int = 4

const RING_IN  : float = 15.8   # кольцо: между заливкой и ореолом
const RING_OUT : float = 17.4
const RING_RGB : Color = Color8(0x57, 0x04, 0xEF)
# Сколько кольца обязано быть видно ИЗ-ПОД рисунка. У книги рисунок закрывает
# две трети — отсюда и порог: он ловит не «зарисовали кольцо», а «кольцо стало
# другого цвета», когда доля падает почти до нуля.
const RING_MIN : float = 0.25

var _fails  : int = 0
var _checks : int = 0
const EXPECTED_CHECKS : int = 24

func _check(ok: bool, what: String) -> void:
	_checks += 1
	if ok:
		print("  ok   ", what)
	else:
		_fails += 1
		print("  FAIL ", what)

func _initialize() -> void:
	print("── Шайба иконок меню ──")
	for path in ICONS:
		var tex : Texture2D = load(path)
		var nm : String = String(path).get_file()
		if tex == null:
			_check(false, "%s: нет файла" % nm)
			continue
		var img : Image = tex.get_image()
		var w : int = img.get_width()
		var k : int = w / FRAME
		# Кадр обязан быть ЦЕЛЫМ числом замеров: дробная плотность означает, что
		# шайбу пересчитали не по замеру, а на глаз, и в ряду она встанет чуть
		# другой.
		var square : bool = w == img.get_height() and k >= 1 and w == FRAME * k
		_check(square, "%s: кадр %d×%d — это %d× от замера 55×55"
			% [nm, w, img.get_height(), k])
		if not square:
			continue
		_check(k >= int(ICONS[path]),
			"%s: плотность %d× при обязательных %d×" % [nm, k, int(ICONS[path])])
		_check_glow(img, nm, k)
		_check_ring(img, nm, k)
	_finish()

func _check_glow(img: Image, nm: String, k: int) -> void:
	var rings : Dictionary = {}
	for r in GLOW_PROFILE.keys():
		rings[r] = []
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			# Расстояние переводится В ЕДИНИЦЫ ЗАМЕРА: кривая спада одна на любую
			# плотность, вчетверо более плотный файл просто описывает её подробнее.
			var d : float = Vector2(x - CENTER * float(k), y - CENTER * float(k)).length()
			var r : int = int(round(d / float(k)))
			if rings.has(r):
				(rings[r] as Array).append(int(round(img.get_pixel(x, y).a * 255.0)))
	var worst : int = -1
	var worst_r : int = 0
	for r in rings.keys():
		var got : int = _median(rings[r])
		var d : int = absi(got - int(GLOW_PROFILE[r]))
		if d > worst:
			worst = d
			worst_r = r
	_check(worst <= GLOW_TOL,
		"%s: ореол той же плотности (худшее расхождение %d/255 на радиусе %d)"
			% [nm, worst, worst_r])

func _check_ring(img: Image, nm: String, k: int) -> void:
	var tot : int = 0
	var hit : int = 0
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			var r : float = Vector2(x - CENTER * float(k), y - CENTER * float(k)).length() \
				/ float(k)
			if r < RING_IN or r > RING_OUT:
				continue
			tot += 1
			var c : Color = img.get_pixel(x, y)
			if c.a > 0.97 and _rgb_dist(c, RING_RGB) < 0.13:
				hit += 1
	var frac : float = float(hit) / maxf(1.0, float(tot))
	_check(frac >= RING_MIN,
		"%s: кольцо того же цвета, видно %.0f%% из-под рисунка" % [nm, frac * 100.0])

func _rgb_dist(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()

func _median(values: Array) -> int:
	values.sort()
	if values.is_empty():
		return -1
	return int(values[values.size() / 2])

func _finish() -> void:
	print("")
	if _checks < EXPECTED_CHECKS:
		print("ПРОВАЛ: проверок %d из %d — тест не отработал" % [_checks, EXPECTED_CHECKS])
		quit(1)
		return
	if _fails == 0:
		print("ВСЁ ЗЕЛЁНОЕ (проверок: %d)" % _checks)
	else:
		print("ПРОВАЛОВ: ", _fails)
	quit(1 if _fails > 0 else 0)
