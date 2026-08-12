extends Node

# ── Прогрессия скинов: что даёт каждый уровень ────────────────────────────────
# Раньше награды за уровни были ОБЩИЕ для всех скинов — два массива в
# save_data.gd (LEVEL_DOLLAR_REWARD / LEVEL_TOKEN_REWARD). Теперь у каждого
# скина своя лестница: дешёвые скины платят меньше, но и качаются к тем же
# десяти уровням, а иммунитеты подобраны под то, от чего страдает конкретный
# герой.
#
# ВАЖНО: уровень 1 награды НЕ даёт. Скин покупается сразу первым уровнем,
# и награда на нём была бы просто скидкой к цене покупки. Поэтому лестница
# начинается со 2-го уровня, а на 10-м стоит «венец» скина.
#
# Ритм лестницы одинаков у всех: чётные уровни — сила (жир и иммунитеты),
# нечётные — валюта. Игрок всегда знает, за чем идёт следующий уровень.
#
#   2  — открывает 4-е состояние жира
#   3,5,7,9 — деньги и жетоны
#   4,6,8   — иммунитеты к предметам
#   10      — уникальная награда скина
#
# Виды наград (`kind`):
#   "money"    — dollars / tokens
#   "fat"      — открывает состояние жира `fat` (0..3)
#   "immunity" — открывает РЕЗИСТ к предмету `item`: предмет разбивается
#                вместо удара, затем откат (см. skin_skills.resist_cd)
#   "perk"     — уникальная способность 10-го уровня, `perk` = id
#
# См. /Концепция/Скины.md

# Человекочитаемые названия предметов для UI.
const ITEM_NAMES : Dictionary = {
	"cone": "конус", "stone": "камень", "trash": "бочка", "safe": "сейф",
	"banana": "банан", "beer": "пиво", "cocktail": "коктейль",
	"bum": "бомж", "snake": "змея", "thief": "вор", "compass": "компас",
	"glove": "перчатка", "dog": "собака", "cop": "коп", "handcuffs": "наручники",
	"poison": "яд", "bird": "птица", "helm": "штурвал", "shaman": "шаман",
	"black_ace": "чёрная карта", "loser_ticket": "чек лузера",
}

# Раньше здесь висели семь предметов из ТЗ, которых в игре не существовало, —
# резисты к ним были пустыми обещаниями. Все семь добавлены (hazard_item.gd),
# список пуст. Оставлен как механизм: если в лестницу впишут предмет раньше,
# чем его сделают, магазин сможет честно пометить награду.
const DORMANT_ITEMS : Array = []

const _FAT_MAX : Dictionary = { "kind": "fat", "fat": 3 }

# Хелперы-конструкторы, чтобы таблица ниже читалась как таблица, а не как код.
static func _money(d: int, t: int) -> Dictionary:
	return { "kind": "money", "dollars": d, "tokens": t }

static func _imm(item: String) -> Dictionary:
	return { "kind": "immunity", "item": item }

static func _perk(id: String, label: String, desc: String) -> Dictionary:
	return { "kind": "perk", "perk": id, "label": label, "desc": desc }

# level -> reward. Ключи 2..10; на 1-м уровне награды нет намеренно.
var LEVELS : Dictionary = {}

# Строим в _init, а не в _ready: SaveData стоит в списке автолоадов раньше,
# и порядок вызова _ready на него полагаться не даёт.
func _init() -> void:
	LEVELS = {
		# ── Обычные (5000) ────────────────────────────────────────────────────
		"viking": {
			2: _FAT_MAX, 3: _money(300, 2), 4: _imm("cone"), 5: _money(500, 2),
			6: _imm("stone"), 7: _money(500, 2), 8: _imm("trash"), 9: _money(1500, 3),
			10: _imm("safe"),
		},
		"kuss": {
			2: _FAT_MAX, 3: _money(300, 2), 4: _imm("banana"), 5: _money(500, 2),
			6: _imm("beer"), 7: _money(500, 2), 8: _imm("cocktail"), 9: _money(1500, 3),
			# В ТЗ на 10-м уровне стоял «???????». Кусс — единственный скин с
			# одноцелевым дальним броском, поэтому венцом сделан второй заряд:
			# это усиливает его собственную механику, а не выдаёт чужую.
			10: _perk("kuss_double_shot", "ДВЕ ЛОПАТКИ",
				"Бросок уходит двумя лопатками подряд — вторая летит следом"),
		},
		"halloween": {
			2: _FAT_MAX, 3: _money(100, 2), 4: _imm("bum"), 5: _money(100, 2),
			6: _imm("snake"), 7: _money(100, 2), 8: _imm("thief"), 9: _money(500, 3),
			10: _imm("compass"),
		},
		"tyson": {
			2: _FAT_MAX, 3: _money(300, 2), 4: _imm("glove"), 5: _money(500, 2),
			6: _imm("bum"), 7: _money(500, 2), 8: _imm("dog"), 9: _money(1500, 3),
			10: _perk("tyson_fast_fists", "БЫСТРЫЕ КУЛАКИ",
				"Откат удара перчаткой короче на 1 секунду"),
		},
		"batman": {
			2: _FAT_MAX, 3: _money(100, 2), 4: _imm("bum"), 5: _money(100, 2),
			6: _imm("thief"), 7: _money(100, 2), 8: _imm("cop"), 9: _money(1000, 3),
			10: _imm("handcuffs"),
		},

		# ── Эпические (7000) ──────────────────────────────────────────────────
		"dracula": {
			2: _FAT_MAX, 3: _money(300, 2), 4: _imm("snake"), 5: _money(500, 2),
			6: _imm("dog"), 7: _money(500, 2), 8: _imm("compass"), 9: _money(1500, 3),
			10: _imm("shaman"),
		},
		"glasses": {
			# Единственный скин, который качается только жетонами — он и в бою
			# ничего не ломает, а бафает, поэтому его валюта тоже «не боевая».
			2: _FAT_MAX, 3: _money(0, 2), 4: _imm("banana"), 5: _money(0, 5),
			6: _imm("beer"), 7: _money(0, 5), 8: _imm("loser_ticket"), 9: _money(0, 10),
			10: _perk("double_money", "ДВОЙНАЯ ВЫГОДА", "Все доллары за забег идут ×2"),
		},
		"wizard": {
			2: _FAT_MAX, 3: _money(100, 2), 4: _imm("snake"), 5: _money(100, 2),
			6: _imm("poison"), 7: _money(100, 2), 8: _imm("bum"), 9: _money(100, 3),
			10: _perk("time_slow", "ОСТАНОВКА ВРЕМЕНИ",
				"Раз в 30 секунд время само замедляется на 3 секунды"),
		},

		# ── Легендарные (9999) ────────────────────────────────────────────────
		"harry_potter": {
			2: _FAT_MAX, 3: _money(100, 2), 4: _imm("snake"), 5: _money(100, 2),
			6: _imm("dog"), 7: _money(100, 2), 8: _imm("bird"), 9: _money(100, 3),
			10: _perk("second_chance", "МАЛЬЧИК, КОТОРЫЙ ВЫЖИЛ",
				"Один раз за забег переживаешь смертельный удар"),
		},
		"pirate": {
			2: _FAT_MAX, 3: _money(50, 2), 4: _imm("bum"), 5: _money(50, 2),
			6: _imm("thief"), 7: _money(50, 2), 8: _imm("helm"), 9: _money(100, 3),
			10: _imm("compass"),
		},
		"joker": {
			2: _FAT_MAX, 3: _money(100, 2), 4: _imm("bum"), 5: _money(100, 2),
			6: _imm("thief"), 7: _money(100, 2), 8: _imm("cop"), 9: _money(100, 3),
			10: _imm("black_ace"),
		},
		"spider_man": {
			2: _FAT_MAX, 3: _money(100, 2), 4: _imm("bum"), 5: _money(100, 2),
			6: _imm("thief"), 7: _money(100, 2), 8: _imm("dog"), 9: _money(100, 3),
			10: _perk("spider_reflex", "ПАУЧЬЯ РЕАКЦИЯ",
				"Повышенная ловкость срабатывает сама раз в 10 секунд"),
		},

		# ── Скины вне ТЗ ──────────────────────────────────────────────────────
		# «Нормальдо» и «Санта» в присланной таблице отсутствуют. Чтобы они не
		# остались вовсе без прогрессии, им оставлена прежняя общая лестница:
		# жир на 2-м, дальше только деньги, без иммунитетов и венца.
		"classic":  _plain_ladder(),
		"new_year": _plain_ladder(),
	}

static func _plain_ladder() -> Dictionary:
	return {
		2: _FAT_MAX, 3: _money(200, 1), 4: _money(400, 1), 5: _money(600, 2),
		6: _money(800, 2), 7: _money(1000, 2), 8: _money(1200, 3), 9: _money(1500, 3),
		10: _money(2000, 3),
	}

# ── Доступ ────────────────────────────────────────────────────────────────────

func reward_for(skin_id: String, level: int) -> Dictionary:
	return (LEVELS.get(skin_id, {}) as Dictionary).get(level, {})

# Максимальное состояние жира, открытое скину на данном уровне (0..3).
# Базово доступны два первых состояния; 4-е открывает награда уровня 2.
func max_fat_state(skin_id: String, level: int) -> int:
	var best := 1
	for lv in range(2, level + 1):
		var r := reward_for(skin_id, lv)
		if r.get("kind", "") == "fat":
			best = maxi(best, int(r.get("fat", 1)))
	return best

# Теги предметов, к которым скин получил резист к этому уровню.
func immunities(skin_id: String, level: int) -> Array:
	var out : Array = []
	for lv in range(2, level + 1):
		var r := reward_for(skin_id, lv)
		if r.get("kind", "") == "immunity":
			out.append(String(r.get("item", "")))
	return out

# Открыт ли уникальный перк 10-го уровня.
func has_perk(skin_id: String, level: int, perk_id: String) -> bool:
	for lv in range(2, level + 1):
		var r := reward_for(skin_id, lv)
		if r.get("kind", "") == "perk" and String(r.get("perk", "")) == perk_id:
			return true
	return false

func perk_of(skin_id: String) -> Dictionary:
	var r := reward_for(skin_id, 10)
	return r if r.get("kind", "") == "perk" else {}

func item_name(item: String) -> String:
	return String(ITEM_NAMES.get(item, item))

func is_dormant(item: String) -> bool:
	return item in DORMANT_ITEMS

# Короткая подпись награды для магазина и экрана скина.
func reward_label(skin_id: String, level: int) -> String:
	var r := reward_for(skin_id, level)
	match String(r.get("kind", "")):
		"money":
			var parts : Array = []
			if int(r.get("dollars", 0)) > 0: parts.append("%d $" % int(r["dollars"]))
			if int(r.get("tokens", 0))  > 0: parts.append("%d жетон" % int(r["tokens"]))
			return " / ".join(parts)
		"fat":
			return "Открыто %d-е состояние жира" % (int(r.get("fat", 3)) + 1)
		"immunity":
			var nm := item_name(String(r.get("item", "")))
			return "Иммунитет: %s%s" % [nm, " (скоро)" if is_dormant(String(r.get("item", ""))) else ""]
		"perk":
			return String(r.get("label", ""))
	return ""
