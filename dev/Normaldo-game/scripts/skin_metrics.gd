extends Node

# ── Метрики голов скинов ──────────────────────────────────────────────────────
# Спрайты скинов кадрированы очень по-разному: у одних в кадре только голова
# (классика занимает всю ширину), у других вокруг неё разведены руки, перчатки
# или посох. Джокер — крайний случай: его голова это лишь 27 процентов ширины
# кадра, остальное — расставленные в стороны руки, кости и карта.
#
# Раньше масштаб считался от ШИРИНЫ ТЕКСТУРЫ (_CLASSIC_TEX_REF / tex_w), то есть
# все спрайты приводились к одинаковой ширине КАДРА. Чем больше в кадре
# посторонних деталей, тем мельче выходила сама голова: у Джокера она была почти
# втрое меньше классической. Игрок же смотрит на голову и по ней оценивает
# размер персонажа — отсюда и ощущение, что скины с руками «мельче».
#
# Здесь лежат замеры, снятые с самих спрайтов: голова определяется как САМАЯ
# КРУПНАЯ связная непрозрачная область (руки и посохи — отдельные пятна).
#
#   scale — множитель, приводящий голову скина к размеру классической
#   off   — смещение центра головы от центра кадра, в долях кадра, по каждому
#           состоянию жира. Нужно, чтобы голова села на хитбокс: у Гарри, Мага и
#           Кусса она уходит от центра больше чем на девять процентов ширины
#
# Масштаб ОДИН на скин (снят с 1-го состояния) намеренно. Нормируй каждое
# состояние отдельно — и пропадёт рост головы при жирении, а он нарисован
# художником и является частью механики толщины.
#
# Таблица СГЕНЕРИРОВАНА замером спрайтов, руками её править не нужно.
# Перерисовали скин — пересчитайте: dev/tools/measure_heads.py
#
# См. /Концепция/Скины.md → «Размер головы»

const HEADS : Dictionary = {
	"classic": { "scale": 1.000, "head": 1.0000, "head_h": 0.8462, "off": [Vector2(-0.0025, -0.0801), Vector2(-0.0025, -0.0027), Vector2(-0.0025, -0.0462), Vector2(-0.0025, -0.0766)], "box": [Vector2(1.0000, 1.0000), Vector2(1.0000, 1.0000), Vector2(1.0000, 1.0000), Vector2(1.0000, 1.0000)], "head_wh": [Vector2(1.0000, 0.8462), Vector2(1.0000, 1.0000), Vector2(1.0000, 0.9130), Vector2(1.0000, 0.8548)] },
	"batman": { "scale": 2.247, "head": 0.4450, "head_h": 0.5700, "off": [Vector2(-0.0050, 0.0125), Vector2(0.0050, -0.0225), Vector2(-0.0250, -0.0850), Vector2(0.0075, -0.0575)], "box": [Vector2(0.6640, 0.7680), Vector2(0.6220, 0.7020), Vector2(0.7960, 0.4350), Vector2(0.8110, 0.4360)], "head_wh": [Vector2(0.4450, 0.5700), Vector2(0.6250, 0.7000), Vector2(0.3450, 0.3650), Vector2(0.4100, 0.3500)] },
	"dracula": { "scale": 1.093, "head": 0.9150, "head_h": 0.8200, "off": [Vector2(-0.0050, -0.0275), Vector2(-0.0125, -0.0275), Vector2(-0.0625, 0.0050), Vector2(-0.0050, -0.0425)], "box": [Vector2(0.9141, 0.8223), Vector2(0.9805, 0.8223), Vector2(0.8711, 0.8789), Vector2(0.9141, 0.8516)], "head_wh": [Vector2(0.9150, 0.8200), Vector2(0.9800, 0.8200), Vector2(0.8700, 0.8750), Vector2(0.9150, 0.8500)] },
	"glasses": { "scale": 1.242, "head": 0.8050, "head_h": 0.6700, "off": [Vector2(0.0200, -0.0075), Vector2(0.0075, 0.0375), Vector2(-0.0075, 0.0000), Vector2(-0.0025, -0.0100)], "box": [Vector2(0.8047, 0.6680), Vector2(0.9082, 0.7578), Vector2(0.9590, 0.7012), Vector2(0.9805, 0.9277)], "head_wh": [Vector2(0.8050, 0.6700), Vector2(0.9100, 0.7600), Vector2(0.9600, 0.7050), Vector2(0.9800, 0.9250)] },
	"halloween": { "scale": 1.626, "head": 0.6150, "head_h": 0.4300, "off": [Vector2(-0.0150, 0.0175), Vector2(-0.0150, 0.0175), Vector2(-0.0150, -0.0925), Vector2(-0.0175, -0.0475)], "box": [Vector2(0.7400, 0.7880), Vector2(0.7400, 0.7880), Vector2(0.7400, 0.7880), Vector2(0.7980, 0.8800)], "head_wh": [Vector2(0.6150, 0.4300), Vector2(0.6150, 0.4300), Vector2(0.6150, 0.6500), Vector2(0.7400, 0.7400)] },
	"harry_potter": { "scale": 2.273, "head": 0.4400, "head_h": 0.4400, "off": [Vector2(-0.1125, -0.0825), Vector2(-0.1375, 0.0400), Vector2(-0.0875, -0.0650), Vector2(-0.0625, -0.0800)], "box": [Vector2(0.8380, 0.7640), Vector2(0.8640, 0.7960), Vector2(0.9640, 0.7260), Vector2(0.9720, 0.8880)], "head_wh": [Vector2(0.4400, 0.4400), Vector2(0.7100, 0.5650), Vector2(0.7900, 0.5650), Vector2(0.8500, 0.7650)] },
	"joker": { "scale": 3.704, "head": 0.2700, "head_h": 0.2450, "off": [Vector2(0.0075, -0.0650), Vector2(-0.0100, -0.0125), Vector2(-0.0200, 0.0075), Vector2(-0.0325, -0.0575)], "box": [Vector2(0.5890, 0.4550), Vector2(0.6500, 0.3980), Vector2(0.7130, 0.4870), Vector2(0.6950, 0.4570)], "head_wh": [Vector2(0.2700, 0.2450), Vector2(0.2750, 0.3300), Vector2(0.3650, 0.3600), Vector2(0.4000, 0.3800)] },
	"kuss": { "scale": 2.000, "head": 0.5000, "head_h": 0.5400, "off": [Vector2(-0.0125, -0.0225), Vector2(-0.0175, 0.0075), Vector2(-0.0550, -0.1925), Vector2(-0.0150, -0.0275)], "box": [Vector2(0.9120, 0.6100), Vector2(0.6050, 0.2920), Vector2(0.5330, 0.4030), Vector2(0.7920, 0.3400)], "head_wh": [Vector2(0.5000, 0.5400), Vector2(0.3100, 0.2900), Vector2(0.3550, 0.3800), Vector2(0.3850, 0.2800)] },
	"new_year": { "scale": 1.493, "head": 0.6700, "head_h": 0.6400, "off": [Vector2(-0.0875, -0.0525), Vector2(-0.0650, 0.0150), Vector2(-0.0525, -0.0225), Vector2(-0.0200, -0.0575)], "box": [Vector2(0.6709, 0.7539), Vector2(0.7939, 0.8223), Vector2(0.8213, 0.9102), Vector2(0.9043, 0.9814)], "head_wh": [Vector2(0.6700, 0.6400), Vector2(0.7950, 0.8250), Vector2(0.8200, 0.9100), Vector2(0.9050, 0.8700)] },
	"pirate": { "scale": 1.550, "head": 0.6450, "head_h": 0.5550, "off": [Vector2(0.0000, -0.0550), Vector2(0.0750, -0.0925), Vector2(0.0750, -0.0925), Vector2(0.0550, -0.1525)], "box": [Vector2(0.7700, 0.7840), Vector2(0.8560, 0.7560), Vector2(0.8600, 0.7560), Vector2(0.9240, 0.7760)], "head_wh": [Vector2(0.6450, 0.5550), Vector2(0.6450, 0.5600), Vector2(0.6450, 0.5600), Vector2(0.6450, 0.6000)] },
	"spider_man": { "scale": 2.247, "head": 0.4450, "head_h": 0.4700, "off": [Vector2(-0.0050, 0.0625), Vector2(-0.0050, 0.0625), Vector2(-0.0050, 0.0625), Vector2(0.0025, -0.0900)], "box": [Vector2(0.6640, 0.7720), Vector2(0.8260, 0.7820), Vector2(0.8320, 0.7760), Vector2(0.9880, 0.7020)], "head_wh": [Vector2(0.4450, 0.4700), Vector2(0.4450, 0.4700), Vector2(0.4450, 0.4700), Vector2(0.6700, 0.6750)] },
	"tyson": { "scale": 1.562, "head": 0.6400, "head_h": 0.6000, "off": [Vector2(-0.0325, 0.0475), Vector2(-0.0350, 0.0750), Vector2(-0.0575, 0.0300), Vector2(-0.0300, 0.0200)], "box": [Vector2(0.7320, 0.8220), Vector2(0.7060, 0.7560), Vector2(0.7240, 0.7900), Vector2(0.5557, 0.5671)], "head_wh": [Vector2(0.6400, 0.6000), Vector2(0.7050, 0.7550), Vector2(0.6700, 0.6650), Vector2(0.5550, 0.5650)] },
	"viking": { "scale": 1.739, "head": 0.5750, "head_h": 0.4600, "off": [Vector2(0.0200, 0.0025), Vector2(0.0100, 0.0100), Vector2(-0.0100, -0.0350), Vector2(-0.0125, 0.0075)], "box": [Vector2(0.7560, 0.7880), Vector2(0.6260, 0.5980), Vector2(0.7820, 0.8420), Vector2(0.8620, 0.5980)], "head_wh": [Vector2(0.5750, 0.4600), Vector2(0.6050, 0.5050), Vector2(0.6950, 0.6450), Vector2(0.7800, 0.6000)] },
	"wizard": { "scale": 1.290, "head": 0.7750, "head_h": 0.8000, "off": [Vector2(-0.0950, -0.0225), Vector2(-0.1400, -0.0375), Vector2(-0.0575, -0.0500), Vector2(-0.0750, -0.0600)], "box": [Vector2(0.7780, 0.8000), Vector2(0.8140, 0.8600), Vector2(0.8220, 0.8340), Vector2(0.9160, 0.7920)], "head_wh": [Vector2(0.7750, 0.8000), Vector2(0.6950, 0.7700), Vector2(0.6900, 0.7650), Vector2(0.7350, 0.7650)] },
}

# ── Размер на экране ──────────────────────────────────────────────────────────
# Голова у всех скинов приводится к классической — это HEAD_TARGET_PX.
#
# Но одной нормировки головы мало. У Гарри, Джокера, Бэтмена и Спайдера в кадре
# нарисовано ещё и тело с посохом, и при равных головах их силуэт вырастает до
# 199×158 против классических 91×71 — вдвое. Бьётся при этом ТОЛЬКО голова:
# хитбокс это круг радиусом 32. Игрок видит тушу в два лейна, которая ничем не
# задевает предметы, и не понимает, где у него граница.
#
# Поэтому силуэт ограничен коробкой MAX_BODY. Она задана в тех же экранных
# пикселях: 150 в ширину и 120 в высоту — это 1.4 высоты лейна (430/5 = 86) и
# 1.9 диаметра хитбокса. Скин, которому коробка тесна, ужимается целиком:
# голова у него получается чуть меньше классической, зато он честно показывает
# свои габариты. Ужимаются четверо; остальные десять проходят как есть.
const HEAD_TARGET_PX : float = 91.0
const MAX_BODY : Vector2 = Vector2(150.0, 120.0)

# ── Поправка на кадрирование вариантов ────────────────────────────────────────
# «Ест», позы каста, призрачные кадры Дракулы и «доллары в глазах» классики
# подменяют текстуру на ТОМ ЖЕ спрайте — а масштаб спрайта посчитан по обычному
# кадру. Кадрировал художник вариант иначе — и голова на подмене меняет размер.
#
# У классики кадр «доллары в глазах» приезжал в 2.7 раза крупнее обычного:
# голова на полсекунды раздувалась вдвое и обратно, и читалось это не как
# анимация, а как пролаг движка. У викинга, очков и пирата позы каста выходили
# в полтора-два раза крупнее по той же причине.
#
# Здесь множитель на _base_scale для каждого варианта и состояния жира, чтобы
# ГОЛОВА осталась того же размера. Таблица СГЕНЕРИРОВАНА замером; перерисовали
# спрайты — пересчитайте: dev/tools/measure_heads.py
const POSE_K : Dictionary = {
	"batman": { "_eat": [1.000, 0.893, 0.986, 1.093], "_spell": [0.967, 0.702, 0.972, 0.739] },
	"classic": { "_cash": [0.444, 0.371, 0.419, 0.691], "_eat": [1.000, 1.000, 0.718, 1.127] },
	"dracula": { "_eat": [0.989, 1.043, 1.055, 0.973], "_ghost_eat": [0.989, 1.043, 1.055, 0.973] },
	"glasses": { "_spell": [0.572, 0.647, 0.683, 0.601], "_spell2": [0.993, 1.123, 0.990, 0.980] },
	"halloween": { "_spell": [0.976, 0.976, 0.591, 0.949] },
	"harry_potter": { "_eat": [1.000, 0.953, 0.898, 0.850], "_spell": [0.989, 1.036, 0.868, 1.000] },
	"joker": { "_eat": [1.000, 1.019, 1.090, 0.976], "_spell": [0.964, 0.982, 0.973, 0.941] },
	"kuss": { "_eat": [0.990, 0.873, 0.855, 0.917] },
	"pirate": { "_eat": [1.000, 1.000, 0.992, 0.849], "_spell": [0.963, 0.977, 0.471, 0.366] },
	"spider_man": { "_eat": [0.856, 0.856, 0.856, 0.957], "_spell": [0.856, 1.000, 1.000, 1.000] },
	"tyson": { "_eat": [0.785, 0.870, 0.964, 0.925], "_spell": [0.941, 1.119, 0.985, 0.984] },
	"viking": { "_eat": [1.000, 0.960, 0.986, 0.929], "_spell": [0.625, 0.658, 0.604, 0.678] },
	"wizard": { "_eat": [0.906, 1.000, 1.007, 0.835], "_spell": [1.220, 0.993, 1.104, 1.114] },
}

# Центр головы В КАДРЕ ВАРИАНТА. Поправки размера мало: у классики кадр
# «доллары в глазах» ещё и смещён на четверть ширины вбок, и голова на подмене
# ПРЫГАЛА. Размер уже совпадал, а прыжок оставался — читалось так же, как
# пролаг. Таблица СГЕНЕРИРОВАНА замером.
const POSE_OFF : Dictionary = {
	"batman": { "_eat": [Vector2(-0.0050, 0.0125), Vector2(-0.0175, -0.0775), Vector2(-0.0475, -0.0450), Vector2(0.0000, -0.0975)], "_spell": [Vector2(-0.0875, -0.0825), Vector2(-0.2700, -0.1300), Vector2(-0.0250, -0.0675), Vector2(-0.0800, 0.0675)] },
	"classic": { "_cash": [Vector2(-0.2275, 0.0900), Vector2(-0.1275, -0.0025), Vector2(-0.0800, -0.0350), Vector2(-0.0500, 0.0900)], "_eat": [Vector2(-0.0025, -0.0032), Vector2(-0.0025, -0.0027), Vector2(-0.0025, -0.0040), Vector2(-0.0025, -0.0255)] },
	"dracula": { "_eat": [Vector2(-0.0300, 0.0400), Vector2(-0.0275, 0.0150), Vector2(-0.0850, -0.0125), Vector2(-0.0275, -0.0025)], "_ghost_eat": [Vector2(-0.0300, 0.0400), Vector2(-0.0275, 0.0150), Vector2(0.0050, 0.0025), Vector2(-0.0275, -0.0025)] },
	"glasses": { "_eat": [Vector2(0.0175, 0.0125), Vector2(0.0000, -0.0125), Vector2(-0.0225, 0.0125), Vector2(-0.0025, -0.0025)], "_spell": [Vector2(0.0375, -0.0475), Vector2(0.0375, -0.0475), Vector2(0.0375, -0.0475), Vector2(0.0150, 0.0075)], "_spell2": [Vector2(-0.0150, -0.0500), Vector2(-0.0150, -0.0500), Vector2(0.0025, 0.0000), Vector2(-0.0025, -0.0100)] },
	"halloween": { "_eat": [Vector2(-0.0150, 0.0025), Vector2(-0.0150, 0.0025), Vector2(0.0050, 0.0375), Vector2(-0.0100, -0.0550)], "_spell": [Vector2(-0.0200, 0.0125), Vector2(-0.0300, -0.0200), Vector2(-0.1325, -0.0350), Vector2(-0.0075, -0.0225)] },
	"harry_potter": { "_eat": [Vector2(0.0875, -0.0225), Vector2(-0.0800, 0.0450), Vector2(-0.0625, 0.0900), Vector2(-0.0025, 0.0025)], "_spell": [Vector2(-0.2150, -0.0900), Vector2(-0.1500, 0.1125), Vector2(-0.0475, 0.0900), Vector2(-0.0625, 0.0925)] },
	"joker": { "_eat": [Vector2(0.0075, -0.0500), Vector2(-0.0175, 0.0175), Vector2(0.0100, -0.0950), Vector2(-0.0125, -0.2175)], "_spell": [Vector2(-0.0525, -0.1350), Vector2(-0.0025, -0.0850), Vector2(-0.0200, 0.0075), Vector2(0.0000, -0.0975)] },
	"kuss": { "_eat": [Vector2(0.0250, -0.0025), Vector2(0.0100, -0.0100), Vector2(-0.0200, 0.0625), Vector2(-0.0175, -0.0375)], "_spell": [Vector2(-0.0150, -0.0400), Vector2(-0.0125, -0.0200), Vector2(-0.0550, -0.1925), Vector2(-0.0150, -0.0175)] },
	"new_year": { "_eat": [Vector2(-0.0875, -0.0500), Vector2(-0.0625, 0.0150), Vector2(-0.0275, -0.0300), Vector2(-0.0200, -0.0575)] },
	"pirate": { "_eat": [Vector2(0.0000, -0.0700), Vector2(0.1000, -0.1675), Vector2(0.0725, -0.1025), Vector2(0.1125, -0.0850)], "_spell": [Vector2(-0.0850, -0.0050), Vector2(-0.1325, -0.0800), Vector2(0.0200, -0.0125), Vector2(0.0175, -0.1475)] },
	"spider_man": { "_eat": [Vector2(-0.0225, -0.0225), Vector2(0.0425, 0.0250), Vector2(-0.0075, 0.0150), Vector2(0.0075, 0.0275)], "_spell": [Vector2(-0.0225, -0.0225), Vector2(0.0000, 0.0000), Vector2(0.0000, 0.0000), Vector2(0.0000, 0.0000)] },
	"tyson": { "_eat": [Vector2(0.0100, -0.0100), Vector2(-0.0725, -0.0575), Vector2(-0.0100, 0.1050), Vector2(-0.0375, 0.0450)], "_spell": [Vector2(0.1125, -0.0100), Vector2(-0.2500, 0.0225), Vector2(0.1125, -0.0100), Vector2(-0.2800, -0.0100)] },
	"viking": { "_eat": [Vector2(0.0200, -0.0075), Vector2(0.0025, -0.0375), Vector2(0.0150, -0.0525), Vector2(-0.0175, -0.0250)], "_spell": [Vector2(0.2025, 0.0350), Vector2(0.2025, 0.0350), Vector2(0.2000, -0.0225), Vector2(0.2000, -0.0225)] },
	"wizard": { "_eat": [Vector2(-0.0700, -0.0525), Vector2(0.0050, 0.0350), Vector2(-0.0250, -0.0125), Vector2(-0.0075, -0.0075)], "_spell": [Vector2(-0.1850, -0.1575), Vector2(-0.1525, -0.0200), Vector2(-0.1800, -0.0650), Vector2(-0.2225, 0.0375)] },
}

func pose_off(skin_id: String, variant: String, fat_state: int) -> Vector2:
	var row : Dictionary = POSE_OFF.get(skin_id, {})
	var offs : Array = row.get(variant, [])
	if offs.is_empty():
		return offset_for(skin_id, fat_state)
	return offs[clampi(fat_state, 0, offs.size() - 1)] + nudge_for(skin_id, fat_state)

func has_pose_off(skin_id: String, variant: String) -> bool:
	return not (POSE_OFF.get(skin_id, {}) as Dictionary).get(variant, []).is_empty()

func pose_k(skin_id: String, variant: String, fat_state: int) -> float:
	var row : Dictionary = POSE_K.get(skin_id, {})
	var ks  : Array = row.get(variant, [])
	if ks.is_empty():
		return 1.0
	return float(ks[clampi(fat_state, 0, ks.size() - 1)])

# ── Ручная доводка ПОВЕРХ замера ──────────────────────────────────────────────
# Замер приводит головы к одному размеру геометрически. Воспринимаемый размер —
# другое: он зависит от того, сколько в кадре «воздуха» вокруг головы и
# насколько плотный силуэт.
#
# Правится ГЛАЗАМИ В ЖИВОМ КАДРЕ, поэтому и лежит не здесь, а в файле
# `dev/skin_layout.json`, который пишет лаборатория скинов (`skin_lab.gd`).
# Раньше это были константы прямо в этом файле, и цикл правки выглядел так:
# посмотрел в игре → запомнил → вышел → нашёл строку → поправил число →
# перезапустил. Файл убирает из этой цепочки всё, кроме первого и последнего
# шага.
#
# `measure_heads.py` его не трогает: перерисовали скин, пересчитали замер —
# ручные правки переживут пересчёт. Ради этого разделение и заведено.
const LAYOUT_PATH : String = "res://dev/skin_layout.json"

var _layout : Dictionary = {}

func _ready() -> void:
	_load_layout()

func _load_layout() -> void:
	_layout = {}
	if not FileAccess.file_exists(LAYOUT_PATH):
		return
	var f := FileAccess.open(LAYOUT_PATH, FileAccess.READ)
	if f == null:
		push_warning("[SkinMetrics] не открылся %s" % LAYOUT_PATH)
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("[SkinMetrics] %s не разобрался" % LAYOUT_PATH)
		return
	_layout = (parsed as Dictionary).get("skins", {})

# ── Посадка надеваемых вещей ─────────────────────────────────────────────────
# Шляпа мага и маска Кейси садятся на голову, и до сих пор садились ОДНИМ
# набором чисел на все четырнадцать скинов. Работать это не могло: у классика в
# кадре одна голова, у викинга рога, у пирата своя шляпа, а у Кусса кепка, —
# и «чуть пониже» для одного означает «на глаза» для другого. Отсюда и правки
# вроде «шляпу всем скинам надевай чуть ниже»: двигали единственное число,
# чинили одного и ломали остальных.
#
# Теперь посадка лежит в том же `dev/skin_layout.json`, по скину и по жиру, и
# правится в лаборатории глазами. Значения по умолчанию — те самые бывшие
# константы: скин, которого нет в файле, ведёт себя ровно как раньше.
#
# У шляпы и маски РАЗНЫЕ вертикальные схемы, и сводить их к одной нельзя.
# Шляпа садится «на макушку»: `sink` — насколько глубоко она надвинута, в долях
# высоты РИСУНКА, считая от его непрозрачной верхней кромки (см.
# `WornItem.crown_y`). Маска садится на ЛИЦО, то есть по доле кадра
# сверху вниз, — макушка ей не ориентир.
const WORN_DEFAULTS : Dictionary = {
	"hat":  { "k": 0.74, "x": 0.02, "sink": 0.42 },
	"mask": { "k": 0.98, "x": 0.0,  "y": -0.006 },
}

func worn_for(skin_id: String, fat_state: int, kind: String) -> Dictionary:
	var base : Dictionary = (WORN_DEFAULTS.get(kind, {}) as Dictionary).duplicate()
	var worn : Dictionary = _layout_row(skin_id, fat_state).get("worn", {})
	var mine : Dictionary = worn.get(kind, {})
	for key in mine:
		base[key] = mine[key]
	return base

# ── Правка ручного слоя из лаборатории ───────────────────────────────────────
# Лаборатория меняет значения ПРЯМО ЗДЕСЬ, а не держит свою копию, и это главное
# решение всей затеи: после `layout_set` пересчитывается всё разом — масштаб,
# посадка, рамки на экране, панель с числами и сам Нормальдо в меню за спиной.
# Своя копия в лаборатории означала бы вторую реализацию `sprite_scale`, то есть
# инструмент, показывающий не то, что покажет игра.
func layout_set(skin_id: String, fat_state: int, tweak: float, nudge: Vector2) -> void:
	if not _layout.has(skin_id):
		_layout[skin_id] = { "fat": [] }
	var row : Dictionary = _layout[skin_id]
	var fats : Array = row.get("fat", [])
	while fats.size() < 4:
		fats.append({ "tweak": 1.0, "nudge": [0.0, 0.0] })
	var i : int = clampi(fat_state, 0, 3)
	# Посадка вещей живёт в той же строке жира и правится ОТДЕЛЬНОЙ кнопкой:
	# затирать её здесь значило бы сбрасывать шляпу при каждом движении скина.
	var keep : Dictionary = (fats[i] as Dictionary).get("worn", {})
	fats[i] = {
		"tweak": snappedf(tweak, 0.001),
		"nudge": [snappedf(nudge.x, 0.0001), snappedf(nudge.y, 0.0001)],
	}
	if not keep.is_empty():
		fats[i]["worn"] = keep
	row["fat"] = fats
	_layout[skin_id] = row

# Снимок на случай отмены. Глубокая копия: вложенные словари жиров иначе уедут
# вместе с правкой, и «отмена» вернула бы то же самое.
# Посадка вещи. Пишется отдельно от размера и сдвига по той же причине, по
# которой отдельно и правится: это разные величины, и трогают их порознь.
func worn_set(skin_id: String, fat_state: int, kind: String, vals: Dictionary) -> void:
	if not _layout.has(skin_id):
		_layout[skin_id] = { "fat": [] }
	var row : Dictionary = _layout[skin_id]
	var fats : Array = row.get("fat", [])
	while fats.size() < 4:
		fats.append({ "tweak": 1.0, "nudge": [0.0, 0.0] })
	var i : int = clampi(fat_state, 0, 3)
	var cur : Dictionary = fats[i]
	var worn : Dictionary = cur.get("worn", {})
	var clean : Dictionary = {}
	for key in vals:
		clean[key] = snappedf(float(vals[key]), 0.0001)
	worn[kind] = clean
	cur["worn"] = worn
	fats[i] = cur
	row["fat"] = fats
	_layout[skin_id] = row

func worn_clear(skin_id: String, fat_state: int, kind: String) -> void:
	var worn : Dictionary = _layout_row(skin_id, fat_state).get("worn", {})
	worn.erase(kind)

func layout_snapshot() -> Dictionary:
	return _layout.duplicate(true)

func layout_restore(snap: Dictionary) -> void:
	_layout = snap.duplicate(true)

# Запись обратно в исходник. Возвращает пустую строку при успехе и текст ошибки
# при неудаче: `res://` пишется только при запуске из редактора, а в собранной
# игре открытие на запись просто не удастся — и молчать об этом нельзя, иначе
# полчаса правок уйдут в никуда.
func layout_save() -> String:
	var head = null
	if FileAccess.file_exists(LAYOUT_PATH):
		var r := FileAccess.open(LAYOUT_PATH, FileAccess.READ)
		if r != null:
			var old = JSON.parse_string(r.get_as_text())
			r.close()
			if typeof(old) == TYPE_DICTIONARY:
				head = (old as Dictionary).get("_comment", null)
	var out : Dictionary = {}
	# Пояснение вверху файла — не украшение: без него следующий читатель не
	# узнает, ни откуда числа, ни почему их нельзя править в коде. Перечитываем
	# его из старого файла, а не храним здесь копию.
	if head != null:
		out["_comment"] = head
	out["skins"] = _layout
	var f := FileAccess.open(LAYOUT_PATH, FileAccess.WRITE)
	if f == null:
		return "нет доступа на запись (%s)" % LAYOUT_PATH
	f.store_string(JSON.stringify(out, "  ", false) + "\n")
	f.close()
	return ""

# Строка ручного слоя для скина и жира. Нет скина — нет и правки: у десяти из
# четырнадцати замер не врёт, и держать для них строки из единиц и нулей значит
# прятать три настоящие правки среди четырнадцати пустых.
func _layout_row(skin_id: String, fat_state: int) -> Dictionary:
	var row : Dictionary = _layout.get(skin_id, {})
	var fats : Array = row.get("fat", [])
	if fats.is_empty():
		return {}
	return fats[clampi(fat_state, 0, fats.size() - 1)]

# ── Ручной замер там, где автоматический врёт ────────────────────────────────
# Автозамер стоит на одном допущении: голова — САМОЕ КРУПНОЕ связное пятно, а
# руки, посохи и прочий реквизит нарисованы отдельными пятнами. Для тринадцати
# скинов это правда. Для Кусса — нет: он лягушка, у которой голова переходит в
# брюхо без единого разрыва, и «самое крупное пятно» это голова ВМЕСТЕ с тушей.
#
# Отсюда две поломки сразу:
#
#   • ЯКОРЬ. Центр такого пятна лежит в животе. На третьем жире хитбокс уезжал
#     под подбородок почти на девятую часть кадра — удары засчитывались по
#     пузу, а не по лицу. Разрезать пятно замером нельзя, оно связное.
#
#   • КОРОБКА. Ладонь и лопатка у Кусса отлетают от туши далеко, и коробка
#     видимого силуэта меряет в основном ВОЗДУХ между ними. MAX_BODY срабатывал
#     на этом воздухе и ужимал персонажа целиком: на четвёртом жире туша
#     занимала 70 пикселей при коробке в 144.
#
# Здесь остался ОДИН ручной замер — коробка:
#
#   box — коробка ТУШИ: главное пятно плюс пятна целиком внутри его столбца
#         (бабочка, лапы). Отлетевший реквизит в неё не входит — он и не
#         читается как туша. Именно по ней работает MAX_BODY; общий разлёт
#         рисунка держит отдельная, более широкая MAX_SPREAD.
#
# Промах ЯКОРЯ лечится сдвигом, и он переехал в `dev/skin_layout.json` вместе с
# остальной ручной доводкой: сдвиг ставится глазами в живом кадре, а коробка —
# это замер, снятый по сетке со спрайта. Разные по природе величины, разные и
# места: коробку лаборатория не правит и правит не должна.
const MANUAL : Dictionary = {
	"kuss": {
		"box":   [Vector2(0.5000, 0.5400), Vector2(0.3100, 0.2900),
		          Vector2(0.3550, 0.3800), Vector2(0.3850, 0.2950)],
	},
}

# Разлёт всего рисунка вместе с отлетевшим реквизитом. Шире MAX_BODY: ладонь в
# стороне и лопатка — не туша, ими ничего не задевается, и ужимать из-за них
# персонажа не за что. Но и разлетаться без предела нельзя, иначе спрайт полезет
# в соседние лейны. Держит только Кусса — у остальных рисунок и так в MAX_BODY.
const MAX_SPREAD : Vector2 = Vector2(230.0, 150.0)

func _manual(skin_id: String, key: String, fat_state: int):
	var row : Dictionary = MANUAL.get(skin_id, {})
	var arr : Array = row.get(key, [])
	if arr.is_empty():
		return null
	return arr[clampi(fat_state, 0, arr.size() - 1)]

# Ручная добавка к якорю головы. Ноль для всех, у кого замер не врёт.
func nudge_for(skin_id: String, fat_state: int) -> Vector2:
	var n = _layout_row(skin_id, fat_state).get("nudge", null)
	if n is Array and (n as Array).size() >= 2:
		return Vector2(float(n[0]), float(n[1]))
	return Vector2.ZERO

func tweak_for(skin_id: String, fat_state: int) -> float:
	return float(_layout_row(skin_id, fat_state).get("tweak", 1.0))

# Множитель масштаба скина, приводящий его голову к классической.
func scale_for(skin_id: String) -> float:
	return float((HEADS.get(skin_id, {}) as Dictionary).get("scale", 1.0))

# Доля ширины кадра, которую занимает голова. Интерфейсу она нужна, чтобы
# посадить голову в коробку аватарки, не таща за собой руки и посохи.
func head_frac_for(skin_id: String) -> float:
	return float((HEADS.get(skin_id, {}) as Dictionary).get("head", 1.0))

# Доля ВЫСОТЫ кадра, которую занимает голова. Нужна ЖИРОБОССУ: там голова
# растягивается на высоту экрана, и считать её размер по ширине нельзя — у
# классики голова заметно шире, чем выше, и она вылезала бы за кадр сильнее
# остальных.
func head_h_frac_for(skin_id: String) -> float:
	return float((HEADS.get(skin_id, {}) as Dictionary).get("head_h", 1.0))

# Габариты ГОЛОВЫ в долях кадра для конкретного состояния жира. При жирении
# голова нарисована крупнее, и ЖИРОБОСС, считающий размер по первому состоянию,
# на четвёртом раздувался бы заметно сильнее, а хитбокс вылезал бы за лицо.
func head_size_for(skin_id: String, fat_state: int) -> Vector2:
	var hs : Array = (HEADS.get(skin_id, {}) as Dictionary).get("head_wh", [])
	if hs.is_empty():
		return Vector2(head_frac_for(skin_id), head_h_frac_for(skin_id))
	return hs[clampi(fat_state, 0, hs.size() - 1)]

# Габариты ТУШИ в долях кадра для состояния жира — то, что MAX_BODY ограничивает.
# У Кусса берётся ручной замер: автоматический меряет воздух между отлетевшими
# ладонью и лопаткой (см. MANUAL).
func box_for(skin_id: String, fat_state: int) -> Vector2:
	var m = _manual(skin_id, "box", fat_state)
	if m != null:
		return m
	return content_box_for(skin_id, fat_state)

# Габариты ВСЕГО рисунка в долях кадра, вместе с отлетевшим реквизитом.
func content_box_for(skin_id: String, fat_state: int) -> Vector2:
	var boxes : Array = (HEADS.get(skin_id, {}) as Dictionary).get("box", [])
	if boxes.is_empty():
		return Vector2.ONE
	return boxes[clampi(fat_state, 0, boxes.size() - 1)]

# Итоговый масштаб спрайта: голова к классической, силуэт не шире MAX_BODY.
func sprite_scale(skin_id: String, fat_state: int, tex_size: Vector2) -> float:
	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return 1.0
	var s : float = HEAD_TARGET_PX / tex_size.x * scale_for(skin_id)
	var box : Vector2 = box_for(skin_id, fat_state)
	var w : float = box.x * tex_size.x * s
	var h : float = box.y * tex_size.y * s
	var k : float = 1.0
	if w > MAX_BODY.x:
		k = minf(k, MAX_BODY.x / w)
	if h > MAX_BODY.y:
		k = minf(k, MAX_BODY.y / h)
	# Ручная доводка идёт ПОСЛЕ коробки: она правит восприятие, а не габариты,
	# и ужимать её обратно под MAX_BODY незачем.
	return s * k * tweak_for(skin_id, fat_state)

# Смещение центра головы от центра кадра (доли кадра) для состояния жира.
func offset_for(skin_id: String, fat_state: int) -> Vector2:
	var row : Dictionary = HEADS.get(skin_id, {})
	var offs : Array = row.get("off", [])
	if offs.is_empty():
		return nudge_for(skin_id, fat_state)
	return offs[clampi(fat_state, 0, offs.size() - 1)] + nudge_for(skin_id, fat_state)
