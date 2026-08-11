extends Node

# Rarity constants
const CLASSIC   := 0
const COMMON    := 1
const RARE      := 2
const EPIC      := 3
const LEGENDARY := 4

# Combat class — how the skin fights. Purely descriptive for now: the shop
# detail screen shows it under the ability list so the player knows whether the
# skin wants to keep its distance or trade hits. "" = unset (nothing rendered).
const RANGED := "ranged"
const MELEE  := "melee"
const COMBAT_NAMES : Dictionary = { RANGED: "Дальний бой", MELEE: "Ближний бой" }
const COMBAT_DESCS : Dictionary = {
	RANGED: "Работает на дистанции: активка летит в сторону тапа и сносит предмет до того, как он доедет.",
	MELEE:  "Работает вплотную: держит удар и ломает предметы в упор.",
}

# Ordered list of all skins.
# tex_dir: folder under res://assets/normaldo/<id>/ containing state1..4 + state1_eat..4_eat
# audio_dir: folder under res://assets/audio/skins/<id>/  containing eat1, eat2, hit, fat (optional)
# "" tex_dir means classic (uses legacy normaldo1-4 naming)
const SKINS : Array = [
	{
		"id":        "classic",
		"name_ru":   "НОРМАЛЬДО",
		"rarity":    CLASSIC,
		"combat":    RANGED,
		"price":     0,
		"tex_dir":   "",
		"audio_dir": "",
	},
	{
		"id":        "viking",
		"name_ru":   "ВИКИНГ",
		"rarity":    COMMON,
		"price":     999,
		"tex_dir":   "res://assets/normaldo/viking/",
		"audio_dir": "res://assets/audio/skins/viking/",
	},
	{
		"id":        "tyson",
		"name_ru":   "ТАЙСОН",
		"rarity":    COMMON,
		"price":     999,
		"tex_dir":   "res://assets/normaldo/tyson/",
		"audio_dir": "res://assets/audio/skins/tyson/",
	},
	{
		"id":        "batman",
		"name_ru":   "БЭТМЕН",
		"rarity":    RARE,
		"price":     2999,
		"tex_dir":   "res://assets/normaldo/batman/",
		"audio_dir": "res://assets/audio/skins/batman/",
	},
	{
		"id":        "halloween",
		"name_ru":   "ТЫКВА",
		"rarity":    RARE,
		"price":     2999,
		"tex_dir":   "res://assets/normaldo/halloween/",
		"audio_dir": "res://assets/audio/skins/halloween/",
	},
	{
		"id":        "kuss",
		"name_ru":   "КУСС",
		"rarity":    RARE,
		"price":     2999,
		"tex_dir":   "res://assets/normaldo/kuss/",
		"audio_dir": "res://assets/audio/skins/kuss/",
	},
	{
		"id":        "new_year",
		"name_ru":   "САНТА",
		"rarity":    RARE,
		"price":     2999,
		"tex_dir":   "res://assets/normaldo/new_year/",
		"audio_dir": "res://assets/audio/skins/new_year/",
	},
	{
		"id":        "dracula",
		"name_ru":   "ДРАКУЛА",
		"rarity":    EPIC,
		"price":     4999,
		"tex_dir":   "res://assets/normaldo/dracula/",
		"audio_dir": "res://assets/audio/skins/dracula/",
	},
	{
		"id":        "glasses",
		"name_ru":   "ОЧКИ",
		"rarity":    EPIC,
		"price":     4999,
		"tex_dir":   "res://assets/normaldo/glasses/",
		"audio_dir": "res://assets/audio/skins/glasses/",
	},
	{
		"id":        "wizard",
		"name_ru":   "ВОЛШЕБНИК",
		"rarity":    EPIC,
		"price":     4999,
		"tex_dir":   "res://assets/normaldo/wizard/",
		"audio_dir": "res://assets/audio/skins/wizard/",
	},
	{
		"id":        "harry_potter",
		"name_ru":   "ГАРРИ",
		"rarity":    LEGENDARY,
		"price":     9999,
		"tex_dir":   "res://assets/normaldo/harry_potter/",
		"audio_dir": "res://assets/audio/skins/harry_potter/",
	},
	{
		"id":        "pirate",
		"name_ru":   "ПИРАТ",
		"rarity":    LEGENDARY,
		"price":     9999,
		"tex_dir":   "res://assets/normaldo/pirate/",
		"audio_dir": "res://assets/audio/skins/pirate/",
	},
	{
		"id":        "spider_man",
		"name_ru":   "СПАЙДЕР",
		"rarity":    LEGENDARY,
		"price":     9999,
		"tex_dir":   "res://assets/normaldo/spider_man/",
		"audio_dir": "res://assets/audio/skins/spider_man/",
	},
	{
		"id":        "joker",
		"name_ru":   "ДЖОКЕР",
		"rarity":    LEGENDARY,
		"price":     9999,
		"tex_dir":   "res://assets/normaldo/joker/",
		"audio_dir": "res://assets/audio/skins/joker/",
	},
]

const RARITY_NAMES : Array = ["Классик", "Обычный", "Редкий", "Эпический", "Легендарный"]
const RARITY_COLORS : Array = [
	Color(0.70, 0.70, 0.70),
	Color(0.60, 0.85, 0.55),
	Color(0.30, 0.62, 1.00),
	Color(0.72, 0.30, 1.00),
	Color(1.00, 0.80, 0.15),
]

const _CLASSIC_AVATAR_TEX : Array = [
	preload("res://assets/normaldo/normaldo1.png"),
	preload("res://assets/normaldo/normaldo2.png"),
	preload("res://assets/normaldo/normaldo3.png"),
	preload("res://assets/normaldo/normaldo4.png"),
]

# Returns the head/body texture for a skin at a given fat state (0..3).
# Falls back to classic if the skin's tex_dir doesn't have the asset.
func get_avatar_texture(skin_id: String, fat_state: int) -> Texture2D:
	var idx := clampi(fat_state, 0, 3)
	var data := get_skin(skin_id)
	var tex_dir : String = data.get("tex_dir", "")
	if tex_dir.is_empty():
		return _CLASSIC_AVATAR_TEX[idx]
	var tex = load("%sstate%d.png" % [tex_dir, idx + 1])
	if tex == null:
		return _CLASSIC_AVATAR_TEX[idx]
	return tex

# Russian name of the skin's combat class, or "" when the skin doesn't declare one.
func get_combat_name(id: String) -> String:
	var c : String = get_skin(id).get("combat", "")
	return COMBAT_NAMES.get(c, "")

func get_combat_desc(id: String) -> String:
	var c : String = get_skin(id).get("combat", "")
	return COMBAT_DESCS.get(c, "")

func get_skin(id: String) -> Dictionary:
	for s in SKINS:
		if s["id"] == id:
			return s
	return SKINS[0]

func get_skin_index(id: String) -> int:
	for i in SKINS.size():
		if SKINS[i]["id"] == id:
			return i
	return 0
