class_name Phrases
extends RefCounted

# ── Выкрики Нормальдо ─────────────────────────────────────────────────────────
# Короткие реплики, вылетающие над головой в двух случаях: когда сработал резист
# и когда прилетело по жиру.
#
# Выкрики НАРИСОВАНЫ — это граффити-стикеры в стиле игры, а не набранный шрифтом
# текст. Набирать их шрифтом было бы отдельной ошибкой: подпись читается как
# служебная строка интерфейса (как «РЕЗИСТ!» или «×2 XP»), а рисунок — как голос
# самого Нормальдо. Оба момента и без того озвучены вспышкой, звуком и
# счётчиком, и все три сообщения говорят одно: ЧТО произошло. Выкрик говорит
# другое — как к этому относится герой.
#
# ── Разделение по тону ───────────────────────────────────────────────────────
# Главное здесь не список, а то, что списка ДВА.
#
# Раньше на удар выпадал случайный стикер из общей кучи, и половина набора
# празднует: получить по жиру и увидеть над головой «POW!» или «LOL» — значит
# прочитать, что игра над тобой смеётся за её же промах. Резист при этом не
# показывал ничего, хотя это ровно тот момент, где похвастаться уместно.
#
# Теперь наоборот: победные — на резист, болезненные — на удар.
#
# См. /Концепция/Эффекты и бонусы.md → «Выкрики»

# Резист сработал: удар был, а урона нет. Тон — торжество и насмешка.
const RESIST : Array = [
	preload("res://assets/ui/reactions/pow.png"),
	preload("res://assets/ui/reactions/bam1.png"),
	preload("res://assets/ui/reactions/bam2.png"),
	preload("res://assets/ui/reactions/kek.png"),
	preload("res://assets/ui/reactions/lol.png"),
]

# Прилетело: жир снят. Тон — досада и «ай».
const HIT : Array = [
	preload("res://assets/ui/reactions/oops.png"),
	preload("res://assets/ui/reactions/dang.png"),
	preload("res://assets/ui/reactions/dangbang.png"),
	preload("res://assets/normaldo/ahh.png"),
	preload("res://assets/normaldo/slakebake.png"),
	preload("res://assets/normaldo/slakebake2.png"),
]

# Последний показанный выкрик в каждой таблице. Подряд один и тот же читается как
# «игра залипла», а на списке из пяти-шести штук случайный выбор повторяется
# чаще, чем кажется: каждый пятый показ, то есть несколько раз за забег.
static var _last : Dictionary = {}

# Случайный выкрик из таблицы, но НЕ тот же, что в прошлый раз.
static func pick(key: String, pool: Array) -> Texture2D:
	if pool.is_empty():
		return null
	if pool.size() == 1:
		return pool[0]
	var prev : Texture2D = _last.get(key, null)
	var idx : int = randi() % pool.size()
	if pool[idx] == prev:
		idx = (idx + 1 + randi() % (pool.size() - 1)) % pool.size()
	_last[key] = pool[idx]
	return pool[idx]

static func resist() -> Texture2D:
	return pick("resist", RESIST)

static func hit() -> Texture2D:
	return pick("hit", HIT)
