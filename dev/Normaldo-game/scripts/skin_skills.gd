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
		# КД 3 с. Кулак бьёт вплотную и только по трём целям перед собой — на
		# пятисекундном откате скин играл как «раз в пять секунд одно движение»,
		# а мили-скину нужна частота: подставиться под удар он обязан уметь чаще,
		# чем стрелок промахивается.
		"ability": { "type": SPELL, "id": "explosive_fist",
			"icon": "res://assets/skills/viking/fist.png", "combat": MELEE, "cd": 3.0,
			"label": "ВЗРЫВНОЙ КУЛАК",
			"desc": "Удар кулаком перед собой — взрыв сносит всё вплотную" },
		"unique": {},
	},
	"kuss": {
		"skills": [], "resists": [],
		"ability": { "type": SPELL, "id": "shovel_throw",
			"icon": "res://assets/skills/kuss/spatula.png", "combat": RANGED, "cd": 3.0,
			"label": "БРОСОК ЛОПАТКИ",
			"desc": "Лопатка летит в сторону тапа и сносит одну цель" },
		"unique": {},
	},
	"halloween": {
		"skills": [], "resists": [],
		# ── СВЕЧЕНИЕ ПОД ИКОНКОЙ ────────────────────────────────────────────
		# Ворон нарисован ЧИСТО ЧЁРНЫМ — ни одного пикселя светлее нуля, — а диск
		# кружка почти чёрный. На нём птицы не видно вовсе: в кольце пустота.
		#
		# Поэтому под неё кладётся свет. Поле необязательное и есть только у тех
		# иконок, которым оно нужно: рисовать подсветку под каждой значило бы
		# обвести светом и те, что и так читаются.
		"ability": { "type": SPELL, "id": "black_birds",
			"icon": "res://assets/skills/halloween/blackbird.png", "combat": RANGED, "cd": 5.0,
			"icon_glow": Color(1.00, 0.55, 0.10, 1.0),
			"label": "ЧЁРНЫЕ ПТИЦЫ", "projectile": "blackbird",
			"desc": "Стая чёрных птиц срывается с головы и разлетается в разные стороны" },
		"unique": {},
	},
	"tyson": {
		"skills": [], "resists": [],
		# КД 1 с — короче всех в игре. У Тайсона спелл самый скромный по охвату:
		# один хук в точку тапа, без летящего кулака и без радиуса викинга.
		# Компенсируется он частотой, иначе это просто худший удар: на секунде он
		# наконец играет как боксёр, а не как медленный стрелок без снаряда.
		# `icon_k` — перчатка в кружке КРУПНЕЕ обычного. Она же лежит у Тайсона в
		# резистах, и два одинаковых кружка рядом читались бы как «одно и то же»,
		# хотя один это удар, а другой защита.
		"ability": { "type": SPELL, "id": "glove_punch",
			"icon": "res://assets/skills/tyson/punch.png", "icon_k": 1.28,
			"combat": MELEE, "cd": 1.0,
			"label": "УДАР ПЕРЧАТКОЙ",
			"desc": "Короткий хук по цели перед собой" },
		"unique": {},
	},
	"batman": {
		"skills": [], "resists": [],
		# Батаранг чёрный, с тонкой синей обводкой, и на тёмном диске от него
		# остаётся только эта обводка — silhouette не читается вовсе. Свет под
		# ним — жёлтый: bat-signal, и заодно не сливается с собственной синей
		# каймой значка.
		"ability": { "type": SPELL, "id": "bat_shuriken",
			"icon": "res://assets/skills/batman/throw.png", "combat": RANGED, "cd": 3.0,
			"icon_glow": Color(1.00, 0.82, 0.25, 1.0),
			"label": "БЭТ-СЮРИКЕН", "projectile": "batarang",
			"desc": "Батаранг уходит в сторону тапа, вращаясь на лету" },
		"unique": {},
	},

	# ── Эпические ─────────────────────────────────────────────────────────────
	"dracula": {
		"skills": [], "resists": [],
		# ПРИЗРАЧНАЯ ГОЛОВА, а не крыло: спелл превращает Дракулу именно в неё, и
		# кружок показывает то, что игрок увидит на экране.
		"ability": { "type": SPELL, "id": "invisibility",
			"icon": "res://assets/normaldo/dracula/state1_ghost.png",
			"combat": BUFF, "cd": 5.0,
			"duration": 2.0, "label": "НЕВИДИМОСТЬ",
			"desc": "На 2 секунды исчезаешь — препятствия пролетают сквозь" },
		"unique": { "id": "bum_feast",
			"icon": "res://assets/skills/dracula/blood_drop.png",
			"label": "ОТЖОР ЛЮДЕЙ", "short": "О",
			"desc": "Сбил человека — и сразу толстеешь на 3 пиццы. Откат 3 секунды" },
	},
	"glasses": {
		"skills": [], "resists": [],
		# Было «ускорение на 2 секунды». Сила там имелась, а читаемости не было:
		# на экране не происходило ничего, кроме того, что палец начинал
		# опережать голову. Рывок видно.
		"ability": { "type": SPELL, "id": "electric_dash",
			"icon": "res://assets/skills/glasses/can_hand.png", "combat": BUFF, "cd": 5.0,
			"duration": 0.24, "label": "ЭЛЕКТРО-РЫВОК",
			"desc": "Глотнул энергетик — и рывком в точку тапа, сквозь всё подряд" },
		"unique": { "id": "aerodynamics",
			"icon": "res://assets/skills/glasses/sunglasses.png", "label": "АЭРОДИНАМИКА", "short": "А",
			"desc": "Жир вообще не замедляет — на любом весе остаёшься шустрым" },
	},
	"wizard": {
		"skills": [], "resists": [],
		# ОДНА ПАЛОЧКА, а не три. В staff1 их нарисовано три в ряд — это лист
		# кадров, а не значок: в кружке диаметром 52 px они превращались в
		# частокол, по которому не понять даже, что это палочка. staff4 — та же
		# палочка одна и крупно.
		"ability": { "type": SPELL, "id": "wand_shot",
			"icon": "res://assets/skills/wizard/staff4.png", "icon_k": 1.20,
			"combat": RANGED, "cd": 3.0,
			"label": "ВЫСТРЕЛ ПАЛОЧКОЙ", "projectile": "magicball",
			# Маг не ломает предмет и не выдаёт добычу — он превращает угрозу в
			# СТАВКУ: ящик ещё надо поймать, и выплюнет он что попало. Откат за
			# это три секунды: превращённая угроза ценнее сломанной.
			"desc": "Во что попал — то стало мэджик боксом. Откат 3 секунды" },
		"unique": {},
	},

	# ── Легендарные ───────────────────────────────────────────────────────────
	"harry_potter": {
		"skills": [], "resists": [],
		"ability": { "type": SPELL, "id": "light_flash",
			"icon": "res://assets/skills/harry_potter/glasses_icon.png", "combat": RANGED, "cd": 10.0,
			"label": "ВСПЫШКА СВЕТА",
			"desc": "Вспышка обнуляет ВСЁ на экране разом. Откат самый долгий — 10 секунд" },
		"unique": {},
	},
	"pirate": {
		"skills": [], "resists": [],
		# ФЛАГ, а не штурвал. Штурвал у пирата лежит ещё и в резистах, и в ряду
		# кружков рядом стояли две одинаковые картинки. Пробовали развести их
		# размером, как перчатку Тайсона, — но у пирата есть чем развести
		# по-настоящему: чёрный флаг с черепом узнаётся мгновенно и говорит
		# «пират» лучше, чем второе колесо.
		#
		# Флаг ЧЁРНЫЙ — как и диск кружка, и на нём его попросту нет: виден один
		# белый череп, висящий в пустоте. Под низ кладётся свет — тот же приём,
		# что у вороны Пугала (см. halloween выше). Холодный, лунный: тёплый
		# янтарь уже занят вороной, и рядом два одинаковых пятна читались бы как
		# одна и та же способность.
		"ability": { "type": SPELL, "id": "helm_throw",
			"icon": "res://assets/skills/pirate/flag_icon.png", "icon_k": 1.10,
			"icon_glow": Color(0.18, 0.42, 0.92, 1.0),
			"combat": RANGED, "cd": 3.0,
			"label": "ШТУРВАЛ",
			"desc": "Штурвал прошивает всё на линии и не разбивается" },
		"unique": { "id": "treasure",
			"icon": "res://assets/skills/x3.png", "label": "СОКРОВИЩЕ", "short": "С",
			"desc": "Рейт на деньги ×3 — каждый доллар считается втройне" },
	},
	"joker": {
		"skills": [], "resists": [],
		# ОДНА КАРТА, а не пара. В card_pair две одинаковые карты, отражённые
		# друг в друга; в кружке это читалось как раскрытая книга, а не как
		# карта. Одна крупная карта узнаётся сразу.
		"ability": { "type": SPELL, "id": "card_deck",
			"icon": "res://assets/skills/joker/card_red1.png", "combat": RANGED, "cd": 5.0,
			"label": "КОЛОДА КАРТ",
			"desc": "Четыре карты крестом: бьют плохое, отскакивают от краёв и возвращаются" },
		"unique": {},
	},
	"spider_man": {
		"skills": [], "resists": [],
		"ability": { "type": SPELL, "id": "web_pull",
			"icon": "res://assets/skills/spider_man/hand_icon.png", "combat": RANGED, "cd": 2.0,
			"label": "РАСЧИСТКА", "projectile": "web",
			"desc": "Паутина ломает всё плохое на линии и утаскивает первую добычу" },
		"unique": { "id": "spider_sense",
			"icon": "res://assets/skills/spider_man/mask_icon.png", "label": "ПОВЫШЕННАЯ ЛОВКОСТЬ", "short": "Л",
			"desc": "Паук слушается мгновенно — увороты даются легко на любом жире" },
	},

	# ── Базовый ───────────────────────────────────────────────────────────────
	# У классики нет ни шляпы, ни оружия — её спелл обязан читаться одним
	# движением. «Размен» этим и берёт: во что попал, то и стало деньгами.
	# Откат 2 секунды, самый короткий в игре: у скина без пассивки и без резистов
	# на старте это единственное, чем он торгуется против остальных.
	"classic": {
		"skills": [], "resists": [],
		"ability": { "type": SPELL, "id": "dollar_shot", "combat": RANGED, "cd": 2.0,
			"icon": "res://assets/items/dollar.png",
			"label": "РАЗМЕН",
			"desc": "Выстрел в сторону тапа: во что попал — то стало долларом" },
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
	# Уровень берём у самого скина, а не у активного. Раньше для неактивных
	# подставлялась десятка, и карточка чужого скина показывала все резисты
	# открытыми — то есть обещала то, чего у игрока нет.
	return resists_at(skin_id, SaveData.get_skin_level_for(skin_id))

func resists_at(skin_id: String, level: int) -> Array:
	var cd := resist_cd(skin_id)
	var out : Array = []
	for tag in SkinProgression.immunities(skin_id, level):
		if String(tag) != "":
			out.append({ "item": String(tag), "cd": cd })
	return out

# ВСЕ резисты скина, включая ещё не открытые. Нужен карточке скина: игрок должен
# видеть, что его ждёт на 6-м и 8-м уровнях, а не пустое место. `unlocked`
# говорит, работает ли резист сейчас, `level` — на каком уровне он откроется.
func all_resists(skin_id: String) -> Array:
	var lvl : int = SaveData.get_skin_level_for(skin_id)
	var cd  : float = resist_cd(skin_id)
	var out : Array = []
	for lv in range(2, 11):
		var r : Dictionary = SkinProgression.reward_for(skin_id, lv)
		if r.get("kind", "") == "immunity":
			out.append({ "item": String(r.get("item", "")), "cd": cd,
				"level": lv, "unlocked": lvl >= lv })
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
