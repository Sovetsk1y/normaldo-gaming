extends Node

# ── NEW skin model (data only — gameplay code wires it up later) ───────────────
# Skins no longer have the old per-obstacle skills (dodge/transform/…). Instead,
# by rarity, each skin has:
#
#   • RESISTS — cooldown defences. A resist lets Normaldo BREAK the listed item(s)
#     instead of taking the hit, then goes on cooldown. UI: a round icon (top-left)
#     with the item inside; on trigger the ring sweeps like a clock and a
#     seconds-left number sits in the centre.
#       Common/Rare resist cd = 10 s · Epic/Legendary resist cd = 8 s.
#       A resist row may cover several items (`items` array) — one badge, the
#       primary `item` supplies the icon.
#
#   • ABILITY —
#       Classic/Common: РЫГАЛИТИ, cd 10 s, GREEN cloud.
#       Rare:           РЫГАЛИТИ, cd 8 s, a UNIQUE cloud colour.
#       Epic:           a special SPELL, cd 8 s (or a РЫГАЛИТИ variant).
#       Legendary:      a special SPELL, cd 20 s.
#       Some skins have NO active ability (e.g. Dracula) — then `ability` is {}.
#     РЫГАЛИТИ = double-tap fires a smoke cloud (ninja-foot smoke, tinted) the size
#     of a normal item, flying straight along the Normaldo→double-tap line.
#
#   • PASSIVE — always-on (kept under the `unique` key so the shop/HUD render it
#     without changes). {} if the skin has none.
#
# `skills` is kept (empty) only so the old consumers (normaldo._resolve_skills,
# hud) don't break — the old skill system is simply inactive now.

# ── Legacy skill-type constants (still referenced by normaldo.gd / hud.gd) ─────
const ADAPT     := "adapt"
const DODGE     := "dodge"
const COUNTER   := "counter"
const TRANSFORM := "transform"

# ── Ability types ─────────────────────────────────────────────────────────────
const RYAGALITY := "ryagality"   # double-tap belch cloud (incl. variants)
const SPELL     := "spell"       # epic/legendary special active

const CD_RYAG_CLASSIC: float = 3.0    # НОРМАЛЬДО — стартовый скин рыгает часто
const CD_RYAG_COMMON : float = 10.0
const CD_RYAG_RARE   : float = 8.0
const CD_SPELL_EPIC  : float = 8.0
const CD_SPELL_LEG   : float = 20.0
const CD_RESIST_CR   : float = 10.0   # common / rare resist cooldown
const CD_RESIST_EL   : float = 8.0    # epic / legendary resist cooldown

const CLOUD_GREEN : Color = Color(0.35, 1.0, 0.45)   # default РЫГАЛИТИ colour
const _RYAG_DESC  : String = "Двойной тап — могучая отрыжка летит в сторону тапа и сносит всё на пути"

# ── Level perks ───────────────────────────────────────────────────────────────
# Прокачка скина открывает не только жиры. Каждая запись в `levels` — это
# «что даёт уровень N», и она может нести любую комбинацию из:
#
#   fat_max    : int    — максимальный жир, доступный с этого уровня (0..3)
#   immune     : Array  — теги предметов, которые с этого уровня не действуют
#                         НАВСЕГДА (в отличие от резиста — без кулдауна)
#   pizza_mult : int    — множитель на каждую съеденную пиццу
#
# Денежная часть уровней (доллары/жетоны) живёт в save_data.SKIN_LEVEL_REWARDS —
# здесь только геймплейные перки.
#
# Скины без своей таблицы используют DEFAULT_LEVELS: жир 2 с ур.2, жир 3 с ур.5.
# `popup_desc` — короткая строка для попапа «УРОВЕНЬ N!», `desc` — длинная для
# панели «Описание» в магазине.
const DEFAULT_LEVELS : Dictionary = {
	2: { "id": "fat_2", "label": "ЖИР", "fat_max": 2,
		"desc": "Открывает третье жировое состояние — ещё один пропущенный удар.",
		"popup_desc": "Новое состояние и +1 жизнь" },
	5: { "id": "fat_3", "label": "УБЕР ЖИР", "fat_max": 3,
		"desc": "Открывает четвёртое жировое состояние — ещё один пропущенный удар.",
		"popup_desc": "Финальная стадия и +1 жизнь" },
}

# ── Per-skin data ─────────────────────────────────────────────────────────────
# resists: Array of { item, [items], cd }   ·   ability: РЫГАЛИТИ / SPELL / {}
# unique : passive dict  { id, label, short, desc }  — {} if none
# levels : override for DEFAULT_LEVELS (см. выше)
const DATA : Dictionary = {
	# ── Classic: дальний бой, РЫГАЛИТИ 3 s, перки на чётных уровнях ───────────
	"classic": {
		"skills": [], "resists": [],
		"ability": { "type": RYAGALITY, "cd": CD_RYAG_CLASSIC, "color": CLOUD_GREEN, "label": "РЫГАЛИТИ", "desc": _RYAG_DESC },
		"unique": {},
		"levels": {
			2:  { "id": "fat_4", "label": "ЧЕТЫРЕ ЖИРА", "fat_max": 3,
				"desc": "Открывает сразу все четыре жировых состояния — до «убера» включительно.",
				"popup_desc": "Все состояния и +2 жизни" },
			4:  { "id": "immune_banana", "label": "ИММУНИТЕТ К БАНАНУ", "immune": ["banana"],
				"desc": "Банановая кожура больше не тормозит — Нормальдо давит её на ходу.",
				"popup_desc": "Банан больше не тормозит" },
			6:  { "id": "immune_beer", "label": "ИММУНИТЕТ К ПИВУ", "immune": ["beer"],
				"desc": "Пиво больше не тормозит — сколько ни пей, шаг не сбивается.",
				"popup_desc": "Пиво больше не тормозит" },
			8:  { "id": "pizza_x2", "label": "ПОЕДАНИЕ ПИЦЦЫ ×2", "pizza_mult": 2,
				"desc": "Каждый кусок пиццы засчитывается вдвое — и в жир, и в опыт.",
				"popup_desc": "Каждый кусок считается вдвое" },
			10: { "id": "immune_loser_ticket", "label": "ИММУНИТЕТ К ЧЕКУ ЛУЗЕРА", "immune": ["loser_ticket"],
				"desc": "Чек лузера больше не обнуляет набранное за забег — рви его смело.",
				"popup_desc": "Чек больше не обнуляет забег" },
		},
	},
	"viking": {
		"skills": [], "resists": [ { "item": "trash", "cd": CD_RESIST_CR } ],
		"ability": { "type": RYAGALITY, "cd": CD_RYAG_COMMON, "color": CLOUD_GREEN, "label": "РЫГАЛИТИ", "desc": _RYAG_DESC },
		"unique": {},
	},
	"tyson": {
		"skills": [], "resists": [ { "item": "glove", "cd": CD_RESIST_CR } ],
		"ability": { "type": RYAGALITY, "cd": CD_RYAG_COMMON, "color": CLOUD_GREEN, "label": "РЫГАЛИТИ", "desc": _RYAG_DESC },
		"unique": {},
	},

	# ── Rare: 1 resist (10 s) + РЫГАЛИТИ 8 s, unique cloud colour ──────────────
	"batman": {
		"skills": [], "resists": [ { "item": "bum", "cd": CD_RESIST_CR } ],
		"ability": { "type": RYAGALITY, "cd": CD_RYAG_RARE, "color": Color(0.35, 0.55, 1.0), "label": "РЫГАЛИТИ", "desc": _RYAG_DESC },
		"unique": {},
	},
	"halloween": {
		"skills": [], "resists": [ { "item": "snake", "cd": CD_RESIST_CR } ],
		"ability": { "type": RYAGALITY, "cd": CD_RYAG_RARE, "color": Color(1.0, 0.55, 0.12), "label": "РЫГАЛИТИ", "desc": _RYAG_DESC },
		"unique": {},
	},
	"kuss": {
		"skills": [], "resists": [ { "item": "trash", "cd": CD_RESIST_CR } ],
		"ability": { "type": RYAGALITY, "cd": CD_RYAG_RARE, "color": Color(0.75, 0.40, 1.0), "label": "РЫГАЛИТИ", "desc": _RYAG_DESC },
		"unique": {},
	},
	"new_year": {
		"skills": [], "resists": [ { "item": "fire", "cd": CD_RESIST_CR } ],
		"ability": { "type": RYAGALITY, "cd": CD_RYAG_RARE, "color": Color(1.0, 0.30, 0.35), "label": "РЫГАЛИТИ", "desc": _RYAG_DESC },
		"unique": {},
	},

	# ── Epic ──────────────────────────────────────────────────────────────────
	# Dracula: 2 resists + passive, NO active ability.
	"dracula": {
		"skills": [],
		"resists": [ { "item": "fire", "cd": CD_RESIST_EL }, { "item": "bum", "cd": CD_RESIST_EL } ],
		"ability": {},
		"unique": { "id": "bum_feast", "label": "БОМЖ-ЖОР", "short": "Б",
			"desc": "Разбил бомжа резистом — и сразу толстеешь на 3 пиццы" },
	},
	# Очки: resist + passive + ДВОЙНОЙ РЫГАЛИТИ (fires two ryags in a row).
	"glasses": {
		"skills": [], "resists": [ { "item": "glove", "cd": CD_RESIST_EL } ],
		"ability": { "type": RYAGALITY, "cd": CD_SPELL_EPIC, "color": CLOUD_GREEN, "label": "ДВОЙНОЙ РЫГАЛИТИ",
			"desc": "Двойной тап рыгает дважды подряд — сносит сразу два препятствия" },
		"unique": { "id": "aerodynamics", "label": "АЭРОДИНАМИКА", "short": "А",
			"desc": "Лишний вес почти не мешает — на любом жире остаёшься шустрым" },
	},
	# Волшебник: resist (snake+banana) + ТРАНСФОРМУС, no passive.
	"wizard": {
		"skills": [], "resists": [ { "item": "snake", "items": ["snake", "banana"], "cd": CD_RESIST_EL } ],
		"ability": { "type": SPELL, "id": "transformus", "cd": CD_SPELL_EPIC, "label": "ТРАНСФОРМУС",
			"desc": "Выстрел магии в сторону тапа превращает задетое препятствие в доллар или пиццу" },
		"unique": {},
	},

	# ── Legendary: special SPELL cd 20 s ──────────────────────────────────────
	"harry_potter": {
		"skills": [], "resists": [ { "item": "snake", "items": ["snake", "bum"], "cd": CD_RESIST_EL } ],
		"ability": { "type": SPELL, "id": "expecto_patronum", "cd": CD_SPELL_LEG, "label": "ЭКСПЕКТО ПАТРОНУМ",
			"desc": "Яркая вспышка белого света начисто сметает все препятствия с экрана" },
		"unique": { "id": "second_chance", "label": "МАЛЬЧИК, КОТОРЫЙ ВЫЖИЛ", "short": "Ж",
			"desc": "Один раз за забег переживаешь смертельный удар" },
	},
	"pirate": {
		"skills": [], "resists": [ { "item": "bum", "items": ["bum", "stone"], "cd": CD_RESIST_EL } ],
		"ability": { "type": SPELL, "id": "helm_throw", "cd": CD_SPELL_LEG, "label": "БРОСОК ШТУРВАЛА",
			"desc": "Запускает штурвал — он прошивает все препятствия на линии и не разбивается" },
		"unique": { "id": "treasure", "label": "СОКРОВИЩЕ", "short": "С",
			"desc": "Каждый второй пойманный доллар внезапно даёт в 3 раза больше" },
	},
	# Spider-Man: resist (stone+trash+bum) + ПАУТИНА. Passive INVENTED (user req).
	"spider_man": {
		"skills": [], "resists": [ { "item": "stone", "items": ["stone", "trash", "bum"], "cd": CD_RESIST_EL } ],
		"ability": { "type": SPELL, "id": "web_shot", "cd": 50.0, "charges": 3, "label": "ВЫСТРЕЛ ПАУТИНОЙ",
			"desc": "3 заряда: выстрел белой паутиной уничтожает первое препятствие. Откат 50 c после третьего" },
		"unique": { "id": "spider_sense", "label": "ПАУЧЬЕ ЧУТЬЁ", "short": "П",
			"desc": "Паук слушается мгновенно — увороты даются легко даже на максимальном жире" },
	},
	"joker": {
		"skills": [], "resists": [ { "item": "snake", "items": ["snake", "trash"], "cd": CD_RESIST_EL } ],
		"ability": { "type": SPELL, "id": "royal_gambit", "cd": CD_SPELL_LEG, "label": "КОРОЛЕВСКИЙ ГАМБИТ",
			"desc": "Веер из трёх игральных карт летит по трём линиям и сносит препятствия" },
		"unique": { "id": "scars", "label": "ЗНАЕШЬ, ОТКУДА ЭТИ ШРАМЫ?", "short": "Ш",
			"desc": "Набрал новый жир — и 5 секунд тебя вообще нельзя задеть" },
	},
}

# ── Accessors ─────────────────────────────────────────────────────────────────
func get_skills(skin_id: String) -> Array:
	return DATA.get(skin_id, {}).get("skills", [])

func get_unique(skin_id: String) -> Dictionary:
	return DATA.get(skin_id, {}).get("unique", {})

func get_resists(skin_id: String) -> Array:
	return DATA.get(skin_id, {}).get("resists", [])

func get_ability(skin_id: String) -> Dictionary:
	return DATA.get(skin_id, {}).get("ability", {})

func get_passive(skin_id: String) -> Dictionary:
	return DATA.get(skin_id, {}).get("unique", {})

# ── Level perks ───────────────────────────────────────────────────────────────

# { level:int -> perk dict } for this skin (DEFAULT_LEVELS when it has no table).
func get_levels(skin_id: String) -> Dictionary:
	return DATA.get(skin_id, {}).get("levels", DEFAULT_LEVELS)

# The perk a single level grants, or {} if that level is money-only.
func get_level_perk(skin_id: String, level: int) -> Dictionary:
	return get_levels(skin_id).get(level, {})

# Everything unlocked at or below `level`, folded into one dict.
# fat_max ─ highest fat state the skin may eat its way up to
# immune  ─ { item_tag: true } permanent (cooldown-free) immunities
# pizza_mult ─ how much each eaten pizza counts for
func get_unlocked(skin_id: String, level: int) -> Dictionary:
	var out := { "fat_max": 1, "immune": {}, "pizza_mult": 1 }
	var levels := get_levels(skin_id)
	for lvl in levels:
		if int(lvl) > level:
			continue
		var perk : Dictionary = levels[lvl]
		out["fat_max"]    = maxi(int(out["fat_max"]),    int(perk.get("fat_max", 1)))
		out["pizza_mult"] = maxi(int(out["pizza_mult"]), int(perk.get("pizza_mult", 1)))
		for tag in perk.get("immune", []):
			out["immune"][str(tag)] = true
	return out

func max_fat_for_level(skin_id: String, level: int) -> int:
	return int(get_unlocked(skin_id, level)["fat_max"])

# Level at which `fat_idx` becomes eatable. Fat 0/1 are free from level 1;
# returns 99 if this skin never unlocks that state.
func fat_unlock_level(skin_id: String, fat_idx: int) -> int:
	if fat_idx <= 1:
		return 1
	var best := 99
	var levels := get_levels(skin_id)
	for lvl in levels:
		if int(levels[lvl].get("fat_max", 1)) >= fat_idx:
			best = mini(best, int(lvl))
	return best

# { level -> fat state it unlocks } — only the levels that raise the cap, so the
# shop can stamp "НОВЫЙ ЖИР!" on exactly those reward cards.
func fat_unlock_levels(skin_id: String) -> Dictionary:
	var out : Dictionary = {}
	var levels := get_levels(skin_id)
	var seen := 1
	for lvl in _sorted_levels(skin_id):
		var cap := int(levels[lvl].get("fat_max", 1))
		if cap > seen:
			out[lvl] = cap
			seen = cap
	return out

# What the «УРОВЕНЬ N!» popup should announce for this level-up.
# {} when the level is money-only. `fat_idx` >= 0 → draw that fat sprite.
func level_unlock_info(skin_id: String, level: int) -> Dictionary:
	var perk := get_level_perk(skin_id, level)
	if perk.is_empty():
		return {}
	var fats := fat_unlock_levels(skin_id)
	return {
		"title":   "+ " + str(perk.get("label", "")),
		"desc":    str(perk.get("popup_desc", perk.get("desc", ""))),
		"fat_idx": int(fats[level]) if fats.has(level) else -1,
	}

func _sorted_levels(skin_id: String) -> Array:
	var keys : Array = get_levels(skin_id).keys()
	keys.sort()
	return keys
