extends Node

# ── Способности скинов ────────────────────────────────────────────────────────
# У каждого скина ровно один АКТИВНЫЙ спелл (двойной тап) и, у части, ПАССИВКА.
# Раньше активка была почти у всех одна и та же — «РЫГАЛИТИ» с разным цветом
# облака, а различались скины только резистами. Теперь спелл — это лицо скина:
# он задаёт дистанцию боя, ритм (откат от 2 до 10 секунд) и то, как игрок
# вообще подходит к забегу.
#
# Три класса боя (`combat`):
#   MELEE  — бьёт вплотную перед собой, направление берётся от тапа
#   RANGED — запускает снаряд в сторону тапа
#   BUFF   — не бьёт вовсе, включает состояние на себе
#
# ИММУНИТЕТЫ — это те же РЕЗИСТЫ с откатом, что и раньше: предмет разбивается
# вместо удара, потом защита уходит на перезарядку. Изменился только источник —
# раньше набор резистов был зашит в скин, теперь его ОТКРЫВАЮТ УРОВНИ
# (см. skin_progression.gd). Скин 4-го уровня получает первый резист, 6-го —
# второй, 8-го — третий.
#
# Откат зависит от редкости: у обычных дольше, у эпических и легендарных короче
# — это часть их ценности.
#
# См. /Концепция/Скины.md

# ── Legacy-константы (на них ещё смотрят normaldo.gd / hud.gd) ────────────────
const ADAPT     := "adapt"
const DODGE     := "dodge"
const COUNTER   := "counter"
const TRANSFORM := "transform"

# ── Классы боя ────────────────────────────────────────────────────────────────
const MELEE  := "melee"
const RANGED := "ranged"
const BUFF   := "buff"

# ── Типы активок ──────────────────────────────────────────────────────────────
const RYAGALITY := "ryagality"   # базовая отрыжка (остаётся у скинов вне ТЗ)
const SPELL     := "spell"

const CD_RYAG_COMMON : float = 10.0
const CD_RESIST_CR   : float = 10.0   # обычные / редкие
const CD_RESIST_EL   : float = 8.0    # эпические / легендарные
const CLOUD_GREEN : Color = Color(0.35, 1.0, 0.45)
const _RYAG_DESC  : String = "Двойной тап — могучая отрыжка летит в сторону тапа и сносит всё на пути"

# ── Данные скинов ─────────────────────────────────────────────────────────────
# ability: { type, id, combat, cd, label, desc, [duration], [color], [projectile] }
# unique : пассивка { id, label, short, desc } — {} если нет
const DATA : Dictionary = {
	# ── Обычные ───────────────────────────────────────────────────────────────
	"viking": {
		"skills": [], "resists": [],
		"ability": { "type": SPELL, "id": "explosive_fist", "combat": MELEE, "cd": 5.0,
			"label": "ВЗРЫВНОЙ КУЛАК",
			"desc": "Удар кулаком перед собой — взрыв сносит всё вплотную" },
		"unique": {},
	},
	"kuss": {
		"skills": [], "resists": [],
		"ability": { "type": SPELL, "id": "shovel_throw", "combat": RANGED, "cd": 3.0,
			"label": "БРОСОК ЛОПАТКИ",
			"desc": "Лопатка летит в сторону тапа и сносит одну цель" },
		"unique": {},
	},
	"halloween": {
		"skills": [], "resists": [],
		"ability": { "type": SPELL, "id": "black_birds", "combat": RANGED, "cd": 5.0,
			"label": "ЧЁРНЫЕ ПТИЦЫ", "projectile": "blackbird",
			"desc": "Стая чёрных птиц срывается с головы и разлетается в разные стороны" },
		"unique": {},
	},
	"tyson": {
		"skills": [], "resists": [],
		"ability": { "type": SPELL, "id": "glove_punch", "combat": MELEE, "cd": 3.0,
			"label": "УДАР ПЕРЧАТКОЙ",
			"desc": "Короткий хук по цели перед собой" },
		"unique": {},
	},
	"batman": {
		"skills": [], "resists": [],
		"ability": { "type": SPELL, "id": "bat_shuriken", "combat": RANGED, "cd": 3.0,
			"label": "БЭТ-СЮРИКЕН", "projectile": "batarang",
			"desc": "Батаранг уходит в сторону тапа, вращаясь на лету" },
		"unique": {},
	},

	# ── Эпические ─────────────────────────────────────────────────────────────
	"dracula": {
		"skills": [], "resists": [],
		"ability": { "type": SPELL, "id": "invisibility", "combat": BUFF, "cd": 5.0,
			"duration": 2.0, "label": "НЕВИДИМОСТЬ",
			"desc": "На 2 секунды исчезаешь — препятствия пролетают сквозь" },
		"unique": { "id": "bum_feast", "label": "ОТЖОР ЛЮДЕЙ", "short": "О",
			"desc": "Сбил человека — и сразу толстеешь на 3 пиццы" },
	},
	"glasses": {
		"skills": [], "resists": [],
		"ability": { "type": SPELL, "id": "haste", "combat": BUFF, "cd": 5.0,
			"duration": 2.0, "label": "УСКОРЕНИЕ",
			"desc": "На 2 секунды голова разгоняется вдвое" },
		"unique": { "id": "aerodynamics", "label": "АЭРОДИНАМИКА", "short": "А",
			"desc": "Жир вообще не замедляет — на любом весе остаёшься шустрым" },
	},
	"wizard": {
		"skills": [], "resists": [],
		"ability": { "type": SPELL, "id": "wand_shot", "combat": RANGED, "cd": 2.0,
			"label": "ВЫСТРЕЛ ПАЛОЧКОЙ", "projectile": "magicball",
			"desc": "Самый быстрый спелл в игре: магический шар каждые 2 секунды" },
		"unique": {},
	},

	# ── Легендарные ───────────────────────────────────────────────────────────
	"harry_potter": {
		"skills": [], "resists": [],
		"ability": { "type": SPELL, "id": "light_flash", "combat": RANGED, "cd": 10.0,
			"label": "ВСПЫШКА СВЕТА",
			"desc": "Вспышка обнуляет ВСЁ на экране разом. Откат самый долгий — 10 секунд" },
		"unique": {},
	},
	"pirate": {
		"skills": [], "resists": [],
		"ability": { "type": SPELL, "id": "helm_throw", "combat": RANGED, "cd": 3.0,
			"label": "ШТУРВАЛ",
			"desc": "Штурвал прошивает всё на линии и не разбивается" },
		"unique": { "id": "treasure", "label": "СОКРОВИЩЕ", "short": "С",
			"desc": "Рейт на деньги ×3 — каждый доллар считается втройне" },
	},
	"joker": {
		"skills": [], "resists": [],
		"ability": { "type": SPELL, "id": "card_deck", "combat": RANGED, "cd": 5.0,
			"label": "КОЛОДА КАРТ",
			"desc": "Три карты разлетаются веером в разные стороны" },
		"unique": {},
	},
	"spider_man": {
		"skills": [], "resists": [],
		"ability": { "type": SPELL, "id": "web_pull", "combat": RANGED, "cd": 2.0,
			"label": "ПРИТЯГИВАНИЕ ПАУТИНОЙ", "projectile": "web",
			"desc": "Паутина цепляет предмет и тянет его к тебе" },
		"unique": { "id": "spider_sense", "label": "ПОВЫШЕННАЯ ЛОВКОСТЬ", "short": "Л",
			"desc": "Паук слушается мгновенно — увороты даются легко на любом жире" },
	},

	# ── Скины вне ТЗ: остаются на прежней отрыжке ─────────────────────────────
	"classic": {
		"skills": [], "resists": [],
		"ability": { "type": RYAGALITY, "cd": CD_RYAG_COMMON, "combat": RANGED,
			"color": CLOUD_GREEN, "label": "РЫГАЛИТИ", "desc": _RYAG_DESC },
		"unique": {},
	},
	"new_year": {
		"skills": [], "resists": [],
		"ability": { "type": RYAGALITY, "cd": CD_RYAG_COMMON, "combat": RANGED,
			"color": Color(1.0, 0.30, 0.35), "label": "РЫГАЛИТИ", "desc": _RYAG_DESC },
		"unique": {},
	},
}

# ── Доступ ────────────────────────────────────────────────────────────────────

func get_skills(skin_id: String) -> Array:
	return DATA.get(skin_id, {}).get("skills", [])

func get_unique(skin_id: String) -> Dictionary:
	return DATA.get(skin_id, {}).get("unique", {})

# Резисты, ОТКРЫТЫЕ скину на его текущем уровне. Собираются из лестницы
# прогрессии, поэтому и HUD-бейджи, и логика урона в normaldo.gd видят один и
# тот же список без отдельной синхронизации.
func get_resists(skin_id: String) -> Array:
	var lvl : int = SaveData.skin_level if skin_id == SaveData.active_skin else 10
	return resists_at(skin_id, lvl)

func resists_at(skin_id: String, level: int) -> Array:
	var cd := resist_cd(skin_id)
	var out : Array = []
	for tag in SkinProgression.immunities(skin_id, level):
		if String(tag) != "":
			out.append({ "item": String(tag), "cd": cd })
	return out

# Откат резиста по редкости скина.
func resist_cd(skin_id: String) -> float:
	var rarity : int = int(SkinRegistry.get_skin(skin_id).get("rarity", 1))
	return CD_RESIST_EL if rarity >= SkinRegistry.EPIC else CD_RESIST_CR

func get_ability(skin_id: String) -> Dictionary:
	return DATA.get(skin_id, {}).get("ability", {})

func get_passive(skin_id: String) -> Dictionary:
	return DATA.get(skin_id, {}).get("unique", {})

# Откат активки с учётом перка 10-го уровня (Тайсон бьёт на секунду чаще).
func ability_cd(skin_id: String, level: int) -> float:
	var ab := get_ability(skin_id)
	var cd := float(ab.get("cd", CD_RYAG_COMMON))
	if SkinProgression.has_perk(skin_id, level, "tyson_fast_fists"):
		cd = maxf(0.5, cd - 1.0)
	return cd

func combat_class(skin_id: String) -> String:
	return String(get_ability(skin_id).get("combat", RANGED))
