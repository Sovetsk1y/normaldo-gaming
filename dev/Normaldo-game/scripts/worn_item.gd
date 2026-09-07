class_name WornItem
extends RefCounted

# ── Посадка надеваемой вещи ───────────────────────────────────────────────────
# Шляпа мага и маска Кейси садятся на голову Нормальдо. Расчёт вынесен сюда из
# `normaldo.gd`, потому что теперь его зовут ДВОЕ: сам забег и лаборатория
# скинов, где посадку и подбирают глазами. Своя копия расчёта в лаборатории
# означала бы, что подбирают одну посадку, а в игре работает другая — то есть
# инструмент, которому нельзя верить.
#
# ── Посадка «на макушку», а не «на долю кадра» ────────────────────────────────
# Кадр Нормальдо — квадрат 1000×1000, и рисунок занимает в нём хорошо если
# треть: у классика он один, у викинга с рогами другой, у пирата со шляпой
# третий. Доля кадра поэтому ничего не говорит о том, где макушка, и одна цифра
# садилась по-разному на каждом скине — на ком-то шляпа лежала на голове, на
# ком-то висела над ней.
#
# Считаем от НЕПРОЗРАЧНОЙ РАМКИ рисунка: берём её верх и опускаем вещь на `sink`
# долей высоты рисунка вниз. Тогда «шляпа надета на 18 % головы» означает одно и
# то же на всех скинах, чем бы ни был набит кадр вокруг.
#
# Маска считается иначе — по доле кадра сверху вниз: она садится на ЛИЦО, и
# макушка ей не ориентир. Отсюда два способа задать вертикаль, и сводить их к
# одному нельзя (см. `SkinMetrics.WORN_DEFAULTS`).
#
# См. /Концепция/Скины.md, scripts/skin_metrics.gd

# ── Непрозрачная рамка рисунка ────────────────────────────────────────────────
# `get_image()` РАСПАКОВЫВАЕТ текстуру на каждый вызов, а зовут её здесь дважды
# на каждую пересборку вещи — то есть в лаборатории на каждый кадр перетаскивания.
# Рамка при этом у текстуры одна и навсегда, считать её повторно незачем.
static var _used_cache : Dictionary = {}

static func used_rect(tex: Texture2D) -> Rect2i:
	if tex == null:
		return Rect2i()
	var key := tex.get_rid()
	if _used_cache.has(key):
		return _used_cache[key]
	var r : Rect2i = tex.get_image().get_used_rect()
	_used_cache[key] = r
	return r

# ── Ширина вещи В ПИКСЕЛЯХ ────────────────────────────────────────────────────
# `width_k` — доля ШИРИНЫ КАДРА хозяина, и кадр этот у каждого жира свой: у
# худого он один, у убера другой. Поэтому ОДНО И ТО ЖЕ `k` даёт РАЗНЫЙ размер на
# экране, и подбирать по нему «одинаковую шляпу на всех жирах» нельзя — ровно на
# это и наткнулись, когда лаборатория показывала только коэффициент.
#
# Меряем РИСУНОК, а не кадр: у шляпы кадр 536×615, и рисунок занимает в нём
# меньше половины по ширине. Число «по кадру» показывало бы поля, а не шляпу.
static func art_px(host_tex: Texture2D, tex: Texture2D, width_k: float,
		host_scale: float) -> float:
	if host_tex == null or tex == null or tex.get_size().x <= 0.0:
		return 0.0
	var art : float = float(used_rect(tex).size.x)
	if art <= 0.0:
		art = tex.get_size().x
	return art * host_tex.get_size().x * width_k * host_scale / tex.get_size().x

# Обратное: какой `k` даёт заданную ширину. Нужен, чтобы уравнять вещь по жирам —
# посчитать это в уме нельзя, а подбирать колесом до совпадения пикселей значит
# так никогда и не попасть.
static func k_for_px(host_tex: Texture2D, tex: Texture2D, px: float,
		host_scale: float) -> float:
	var one : float = art_px(host_tex, tex, 1.0, host_scale)
	if one <= 0.0:
		return 0.0
	return px / one

# Собирает спрайт вещи, но НЕ добавляет его в дерево: кто зовёт, тот и решает,
# чьим ребёнком вещь станет и как появится.
static func make(host_tex: Texture2D, tex: Texture2D, width_k: float,
		pos: Vector2, sink: float = -1.0) -> Sprite2D:
	var w := Sprite2D.new()
	w.texture        = tex
	w.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	w.z_index        = 6
	if host_tex == null or tex == null:
		return w
	var head : Vector2 = host_tex.get_size()
	w.scale    = Vector2.ONE * (head.x * width_k / tex.get_size().x)
	w.position = Vector2(pos.x * head.x, pos.y * head.y)
	if sink >= 0.0:
		w.position.y = crown_y(host_tex, w, sink)
	return w

static func crown_y(host_tex: Texture2D, w: Sprite2D, sink: float) -> float:
	var head : Vector2 = host_tex.get_size()
	var used : Rect2i  = used_rect(host_tex)
	if used.size.y <= 0:
		return -head.y * 0.5
	var art_top : float = float(used.position.y) - head.y * 0.5
	var art_h   : float = float(used.size.y)
	# У САМОЙ ВЕЩИ кадр тоже с полями: у шляпы это 536×615, из которых рисунок
	# занимает меньше половины по высоте. Считать от её геометрической середины
	# значило бы повторить ту же ошибку с другой стороны — берём нижнюю кромку
	# её РИСУНКА, то есть край полей шляпы, которым она и садится на голову.
	var w_tex  : Vector2 = w.texture.get_size()
	var w_used : Rect2i  = used_rect(w.texture)
	if w_used.size.y <= 0:
		return art_top + art_h * sink - w_tex.y * w.scale.y * 0.5
	var w_bottom : float = (float(w_used.end.y) - w_tex.y * 0.5) * w.scale.y
	return art_top + art_h * sink - w_bottom
