extends Node

# Rarity constants
const CLASSIC   := 0
const COMMON    := 1
const RARE      := 2
const EPIC      := 3
const LEGENDARY := 4

# Ordered list of all skins.
# tex_dir: folder under res://assets/normaldo/<id>/ containing state1..4 + state1_eat..4_eat
# audio_dir: folder under res://assets/audio/skins/<id>/  containing eat1, eat2, hit, fat (optional)
# "" tex_dir means classic (uses legacy normaldo1-4 naming)
# ── Короткая подпись скина ────────────────────────────────────────────────────
# Одна-две строки в голос игры. Нужны карточке скина: центральная колонка иначе
# пустует, а скины — коллекционные, и без подписи это просто головы в шапках.
#
# ЧЕРНОВИК: тон и шутки правь смело, длину держи в пределах ~90 символов —
# дальше строка не влезает в колонку карточки.
const LORE : Dictionary = {
	"classic":      "Тот самый. Ничего лишнего — только голова и голод.",
	"viking":       "Приплыл за пиццей. Остался за добавкой.",
	"tyson":        "Бьёт первым. Разговаривает потом. Обычно не разговаривает.",
	"batman":       "Этому городу нужен герой. Городу досталась голова.",
	"halloween":    "Улыбку вырезали ножом. Улыбается всё равно.",
	"kuss":         "Лопатка в руке, кепка набок. Кухня закрыта.",
	"new_year":     "Подарки роздал. Ужин оставил себе.",
	"dracula":      "Пять веков на диете. Сорвался на пепперони.",
	"glasses":      "Считает калории. Себе не верит.",
	"wizard":       "Учился двадцать лет. Умеет останавливать время и жевать.",
	"harry_potter": "Мальчик, который выжил. И проголодался.",
	"pirate":       "Карту потерял. Пиццу нашёл.",
	"spider_man":   "С большой силой приходит большой аппетит.",
	"joker":        "Почему так серьёзно? Пицца же остывает.",
}

func lore_for(id: String) -> String:
	return String(LORE.get(id, ""))

const SKINS : Array = [
	{
		"id":        "classic",
		"name_ru":   "НОРМАЛЬДО",
		"rarity":    CLASSIC,
		"price":     0,
		"tex_dir":   "",
		"audio_dir": "",
	},
	{
		"id":        "viking",
		"name_ru":   "ВИКИНГ",
		"rarity":    COMMON,
		"price":     5000,
		"tex_dir":   "res://assets/normaldo/viking/",
		"audio_dir": "res://assets/audio/skins/viking/",
	},
	{
		"id":        "tyson",
		"name_ru":   "ТАЙСОН",
		"rarity":    COMMON,
		"price":     5000,
		"tex_dir":   "res://assets/normaldo/tyson/",
		"audio_dir": "res://assets/audio/skins/tyson/",
	},
	{
		"id":        "batman",
		"name_ru":   "БЭТМЕН",
		"rarity":    RARE,
		"price":     5000,
		"tex_dir":   "res://assets/normaldo/batman/",
		"audio_dir": "res://assets/audio/skins/batman/",
	},
	{
		"id":        "halloween",
		"name_ru":   "ПУГАЛО",
		"rarity":    RARE,
		"price":     5000,
		"tex_dir":   "res://assets/normaldo/halloween/",
		"audio_dir": "res://assets/audio/skins/halloween/",
	},
	{
		"id":        "kuss",
		"name_ru":   "КУСС",
		"rarity":    RARE,
		"price":     5000,
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
		"price":     7000,
		"tex_dir":   "res://assets/normaldo/dracula/",
		"audio_dir": "res://assets/audio/skins/dracula/",
	},
	{
		"id":        "glasses",
		"name_ru":   "ОЧКИ",
		"rarity":    EPIC,
		"price":     7000,
		"tex_dir":   "res://assets/normaldo/glasses/",
		"audio_dir": "res://assets/audio/skins/glasses/",
	},
	{
		"id":        "wizard",
		"name_ru":   "ВОЛШЕБНИК",
		"rarity":    EPIC,
		"price":     7000,
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

# Цены выставлены по ТЗ на скины (10.08.2026): обычные 5000, эпические 7000,
# легендарные 9999. «Нормальдо» и «Санта» в ТЗ отсутствуют — их цены прежние.
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
