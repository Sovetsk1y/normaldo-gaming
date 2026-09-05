extends Node

# ─── Story quest definitions ──────────────────────────────────────────────────
# ── Книга учителя: главы ─────────────────────────────────────────────────────
# Главы идут ПО ИГРЕ, а не по темам: первый полёт, три эпизода кампании по
# порядку, бесконечный за ними и коллекция в конце. Раньше глав про эпизоды не
# было вовсе — вся кампания умещалась в одну «Канализацию», а бесконечный
# выдавался наградой за первого босса. Книга рассказывала про игру, которой уже
# нет.
#
# В главе не больше четырёх заданий: страница разворота вмещает ровно столько
# (см. dev/smoke_book.gd), а пятое ушло бы под сгиб.
const CHAPTERS : Array = [
	{ "title": "Глава 1 — Первый полёт",   "quests": [0, 1, 2] },
	{ "title": "Глава 2 — Канализация",    "quests": [3, 4, 5] },
	{ "title": "Глава 3 — Улица",          "quests": [6, 7, 8] },
	{ "title": "Глава 4 — Дорога в клуб",  "quests": [9, 10, 11, 12] },
	{ "title": "Глава 5 — Бесконечность",  "quests": [13, 14, 15, 16] },
	{ "title": "Глава 6 — Легенда",        "quests": [17, 18, 19, 20] },
]

const STORY_QUESTS : Array = [
	# ch1 — первый полёт
	{ "title": "Лети, Нормальдо!", "desc": "Запусти первый забег",              "cond": "run_started",       "reward_d": 200,  "reward_t": 0 },
	{ "title": "Первый укус",      "desc": "Съешь 100 пицц за один забег",      "cond": "pizzas_run:100",    "reward_d": 400,  "reward_t": 0 },
	{ "title": "Чуть пополнел",    "desc": "Достигни состояния Стройный",       "cond": "fat_reached:1",     "reward_d": 0,    "reward_t": 1 },
	# ch2 — эпизод 1, канализация, нога ниндзя
	{ "title": "Первая минута",    "desc": "Выживи 60 сек в кампании",          "cond": "campaign_time:60",  "reward_d": 500,  "reward_t": 0 },
	{ "title": "Не оглядывайся",   "desc": "Дойди до босса",                    "cond": "boss_reached",      "reward_d": 800,  "reward_t": 2 },
	{ "title": "Ногой об голову",  "desc": "Пройди эпизод 1 — победи Ногу Ниндзя", "cond": "episode_done:1", "reward_d": 0,    "reward_t": 2 },
	# ch3 — эпизод 2, улица, крокодил
	{ "title": "На скорости",      "desc": "Выживи 3 минуты в кампании",        "cond": "campaign_time:180", "reward_d": 0,    "reward_t": 1 },
	{ "title": "Жирнеем",          "desc": "Достигни состояния Жир",            "cond": "fat_reached:2",     "reward_d": 500,  "reward_t": 0 },
	{ "title": "Зубы на улице",    "desc": "Пройди эпизод 2 — победи Крокодила", "cond": "episode_done:2",   "reward_d": 1000, "reward_t": 2 },
	# ch4 — эпизод 3, двор перед клубом, хозяин клуба
	{ "title": "Растём",           "desc": "Прокачай скин до 2-го уровня",      "cond": "skin_level:2",      "reward_d": 0,    "reward_t": 1 },
	{ "title": "Пятёрочка",        "desc": "Прокачай скин до 5-го уровня",      "cond": "skin_level:5",      "reward_d": 0,    "reward_t": 2 },
	{ "title": "Убер-режим",       "desc": "Достигни Убер жир",                 "cond": "fat_reached:3",     "reward_d": 800,  "reward_t": 1 },
	{ "title": "Кто тут хозяин",   "desc": "Пройди эпизод 3 — победи Хозяина клуба", "cond": "episode_done:3", "reward_d": 1500, "reward_t": 3 },
	# ch5 — бесконечность
	# Первым в главе стоит то, что саму главу и открывает. Раньше бесконечный
	# выдавала победа над ПЕРВЫМ боссом, и глава про бесконечность начиналась с
	# задания «запусти бесконечный режим» — то есть с середины разговора.
	{ "title": "Кампания пройдена",    "desc": "Пройди все три эпизода",            "cond": "campaign_complete", "reward_d": 0,    "reward_t": 3, "reward_endless": true },
	{ "title": "Пробуй бесконечность", "desc": "Запусти бесконечный режим",         "cond": "endless_started",   "reward_d": 400,  "reward_t": 0 },
	{ "title": "Всё и сразу",          "desc": "Дойди до СУПЕР ХАРДА в бесконечном", "cond": "hardcore_reached", "reward_d": 1500, "reward_t": 3 },
	{ "title": "Выживший",             "desc": "Выживи 5 минут в бесконечном режиме", "cond": "endless_time:300", "reward_d": 1000, "reward_t": 2 },
	# ch6 — коллекция и мастерство
	{ "title": "Новый облик",      "desc": "Купи любой скин в магазине",        "cond": "skin_bought",       "reward_d": 0,    "reward_t": 1 },
	{ "title": "Дёргай ручку",     "desc": "Сыграй в автомат",                  "cond": "slot_played",       "reward_d": 200,  "reward_t": 0 },
	{ "title": "Три в ряд",        "desc": "Получи совпадение ×3 в автомате",   "cond": "slot_triple",       "reward_d": 0,    "reward_t": 2 },
	{ "title": "Мастер улиц",      "desc": "Достигни 10-го уровня скина",       "cond": "skin_level:10",     "reward_d": 3000, "reward_t": 5 },
]

# ─── Daily quest pools ────────────────────────────────────────────────────────
const DAILY_EASY : Array = [
	{ "title": "Утренний перекус", "desc": "Съешь 500 пицц за день",           "cond": "pizzas_today:500", "reward_d": 100, "reward_t": 0, "reward_xp": 0 },
	{ "title": "Карманные деньги", "desc": "Собери 30 $ за один забег",        "cond": "dollars_run:30",   "reward_d": 150, "reward_t": 0, "reward_xp": 0 },
	{ "title": "Запасной",         "desc": "Запусти бесконечный режим",         "cond": "endless_today",    "reward_d": 100, "reward_t": 0, "reward_xp": 0 },
	{ "title": "Автомат ждёт",     "desc": "Сделай 1 спин в автомате",         "cond": "slot_today",       "reward_d": 100, "reward_t": 0, "reward_xp": 0 },
	{ "title": "Прогулка",         "desc": "Сыграй эпизод",                    "cond": "campaign_today",   "reward_d": 100, "reward_t": 0, "reward_xp": 0 },
]

const DAILY_MEDIUM : Array = [
	{ "title": "Марафонец",    "desc": "Выживи 3 мин в бесконечном режиме",   "cond": "endless_secs:180",   "reward_d": 0,   "reward_t": 1, "reward_xp": 0 },
	{ "title": "Жирный день",  "desc": "Достигни Жир в кампании",             "cond": "campaign_fat",       "reward_d": 200, "reward_t": 0, "reward_xp": 0 },
	{ "title": "Кошелёк",      "desc": "Собери 150 $ за день",                "cond": "dollars_today:150",  "reward_d": 250, "reward_t": 0, "reward_xp": 0 },
	{ "title": "Большой пирог","desc": "Съешь 1000 пицц за день",             "cond": "pizzas_today:1000",  "reward_d": 200, "reward_t": 0, "reward_xp": 0 },
	{ "title": "Везунчик",     "desc": "Получи совпадение ×2 или выше",       "cond": "slot_match:2",       "reward_d": 0,   "reward_t": 2, "reward_xp": 0 },
	{ "title": "Двойной",      "desc": "Сыграй эпизод 5 раз",                 "cond": "campaigns_today:5",  "reward_d": 300, "reward_t": 0, "reward_xp": 0 },
]

const DAILY_HARD : Array = [
	{ "title": "Без царапины", "desc": "Пройди эпизод, не получив урона",     "cond": "campaign_nodmg:5",   "reward_d": 0,    "reward_t": 3, "reward_xp": 0 },
	{ "title": "Убер",         "desc": "Достигни Убер жир в одном заезде",   "cond": "fat_run:3",          "reward_d": 500,  "reward_t": 0, "reward_xp": 0 },
	{ "title": "До конца",     "desc": "Пройди кампанию полностью",            "cond": "campaign_complete",  "reward_d": 0,    "reward_t": 3, "reward_xp": 0 },
	{ "title": "Несгибаемый",  "desc": "Выживи 5 минут в бесконечном режиме", "cond": "endless_secs:300",   "reward_d": 700,  "reward_t": 0, "reward_xp": 0 },
	{ "title": "Пируэт",        "desc": "Съешь 5000 пицц за день",            "cond": "pizzas_today:5000",  "reward_d": 0,    "reward_t": 4, "reward_xp": 0 },
	{ "title": "Три в ряд",    "desc": "Получи совпадение ×3 в автомате",     "cond": "slot_match:3",       "reward_d": 500,  "reward_t": 0, "reward_xp": 0 },
	{ "title": "Коллектор",    "desc": "Собери 400 $ за день",                "cond": "dollars_today:400",  "reward_d": 1000, "reward_t": 0, "reward_xp": 0 },
	{ "title": "Долгий путь",  "desc": "Выживи 8 минут в бесконечном режиме", "cond": "endless_secs:480",   "reward_d": 0,    "reward_t": 4, "reward_xp": 0 },
]

signal quests_updated
signal daily_quest_completed(slot: int, title: String, desc: String)

const SAVE_PATH    := "user://quests.json"
const ENTRY_BONUS  := 50

# Per-tier cooldown (seconds) before a CLAIMED daily slot rolls a new quest.
# Used by `slot_cooldown_sec` / `slot_cooldown_remaining` and consumed by the
# quests screen to show "next easy/medium/hard in X:XX:XX".
const CD_EASY_SEC   : int = 60 * 60          # 1 hour
const CD_MEDIUM_SEC : int = 3 * 60 * 60      # 3 hours
const CD_HARD_SEC   : int = 6 * 60 * 60      # 6 hours

# ─── Persistent ───────────────────────────────────────────────────────────────
var story_completed  : Array  = []
var story_claimed    : Array  = []
var daily_date       : String = ""
# Daily-quest entries now also carry `claimed_at` — the unix-seconds timestamp
# of when the player tapped «Забрать». A new quest of the same tier is rolled
# only AFTER `now - claimed_at >= cooldown_for_tier`. Entries created before
# this change get `claimed_at = 0` on load, so they roll immediately.
var daily_quests     : Array  = []  # [{tier, idx, completed, claimed, claimed_at}]
var daily_bonus_avail: bool   = true
var streak_days      : int    = 0   # consecutive login days
var streak_date      : String = ""

# ─── Daily counters ───────────────────────────────────────────────────────────
var pizzas_today       : int   = 0
var dollars_today      : int   = 0
var runs_today         : int   = 0
var campaigns_today    : int   = 0
var endless_today      : bool  = false
var slot_today         : bool  = false
var campaign_fat_today : bool  = false
var slot_best_match    : int   = 0
var endless_best_secs  : float = 0.0
var campaign_best_phases : int = 0
var campaign_nodmg_best  : int = 0
var dollars_best_run   : int   = 0
var fat_best_run        : int   = 0

# ─── Run-level state ──────────────────────────────────────────────────────────
var _run_is_campaign  : bool  = false
var _run_is_endless   : bool  = false
var _run_fat_max      : int   = 0
var _run_dollars      : int   = 0
var _run_pizzas       : int   = 0
var _run_phase        : int   = 0
var _run_phase_nodmg  : bool  = true
var _run_phases_nodmg : int   = 0
var _run_complete     : bool  = false
var _run_endless_secs : float = 0.0
var _run_campaign_fat : bool  = false
var _run_campaign_secs : float = 0.0
var _story_campaign60_done  : bool = false
var _story_campaign180_done : bool = false

# Сюжетное задание, за которым числится награда «бесконечный режим». Сам режим
# открывается не им, а прогрессом эпизодов (см. `is_endless_unlocked`) — этот
# индекс нужен книге, чтобы подписать награду словами, и дев-сбросу.
const ENDLESS_UNLOCK_QUEST_IDX : int = 13  # "Кампания пройдена"

func _ready() -> void:
	story_completed.resize(STORY_QUESTS.size())
	story_completed.fill(false)
	story_claimed.resize(STORY_QUESTS.size())
	story_claimed.fill(false)
	_load()
	_check_day_reset()
	# Roll fresh quests for any slot whose per-tier cooldown elapsed while the
	# game was closed.
	check_cooldowns()
	SaveData.data_changed.connect(_on_save_data_changed)

# ── Когда открыт бесконечный режим ───────────────────────────────────────────
# КОГДА ПРОЙДЕНЫ ВСЕ ЭПИЗОДЫ. Раньше хватало победы над первым боссом — тогда
# кампания была одним неразрывным забегом, и «победил ниндзю» означало «дошёл
# до середины». Теперь эпизоды отыгрываются по отдельности, и бесконечный —
# это то, что открывается ПОСЛЕ кампании, а не в её первой трети.
#
# Считаем по `SaveData.episodes_done`, а не по галочке сюжетного задания:
# задание — награда за победу, а открытие режима — состояние прогресса, и
# смешивать их значит терять режим вместе со сбросом заданий.
const CAMPAIGN_EPISODES : int = 3

func is_endless_unlocked() -> bool:
	return SaveData.episodes_done >= CAMPAIGN_EPISODES

func is_endless_cond(cond_key: String) -> bool:
	return cond_key == "endless_today" \
		or cond_key == "endless_secs" \
		or cond_key == "endless_started" \
		or cond_key == "endless_time" \
		or cond_key == "hardcore_reached"

# ─── Day reset ────────────────────────────────────────────────────────────────
func _check_day_reset() -> void:
	var today := Time.get_date_string_from_system()
	if today == daily_date:
		return
	var yesterday := daily_date
	daily_date    = today
	daily_bonus_avail = true
	# streak tracking
	var yd := _date_from_str(yesterday)
	var td := _date_from_str(today)
	if yd != Vector3i.ZERO and _days_between(yd, td) == 1:
		streak_days += 1
	else:
		streak_days = 1
	streak_date = today
	# reset daily counters
	pizzas_today       = 0
	dollars_today      = 0
	runs_today         = 0
	campaigns_today    = 0
	endless_today      = false
	slot_today         = false
	campaign_fat_today = false
	slot_best_match    = 0
	endless_best_secs  = 0.0
	campaign_best_phases = 0
	campaign_nodmg_best  = 0
	dollars_best_run   = 0
	fat_best_run       = 0
	_roll_daily_quests()
	_save()

func _date_from_str(s: String) -> Vector3i:
	if s.length() < 10:
		return Vector3i.ZERO
	var parts := s.split("-")
	if parts.size() < 3:
		return Vector3i.ZERO
	return Vector3i(int(parts[0]), int(parts[1]), int(parts[2]))

func _days_between(a: Vector3i, b: Vector3i) -> int:
	# Approximate (good enough for streak detection)
	var da := a.x * 365 + a.y * 30 + a.z
	var db := b.x * 365 + b.y * 30 + b.z
	return db - da

func reroll_daily_quests() -> void:
	_roll_daily_quests()

func _eligible_daily_indices(pool: Array) -> Array:
	var allow_endless := is_endless_unlocked()
	var result : Array = []
	for i in pool.size():
		var cond_key = ((pool[i] as Dictionary).get("cond", "") as String).split(":")[0]
		if not allow_endless and is_endless_cond(cond_key):
			continue
		result.append(i)
	if result.is_empty():
		# Fallback — never leave a tier without picks
		result.append(0)
	return result

func _pick_daily_idx(pool: Array) -> int:
	var eligible := _eligible_daily_indices(pool)
	return eligible[randi() % eligible.size()]

func _roll_daily_quests() -> void:
	daily_quests = [
		_new_slot("easy",   _pick_daily_idx(DAILY_EASY)),
		_new_slot("medium", _pick_daily_idx(DAILY_MEDIUM)),
		_new_slot("hard",   _pick_daily_idx(DAILY_HARD)),
	]

func _new_slot(tier: String, idx: int) -> Dictionary:
	return {
		"tier":       tier,
		"idx":        idx,
		"completed":  false,
		"claimed":    false,
		"claimed_at": 0,
	}

# ─── Per-tier cooldowns ───────────────────────────────────────────────────────
func slot_cooldown_sec(slot: int) -> int:
	if slot < 0 or slot >= daily_quests.size():
		return 0
	match str(daily_quests[slot].get("tier", "easy")):
		"easy":   return CD_EASY_SEC
		"medium": return CD_MEDIUM_SEC
		_:        return CD_HARD_SEC

func slot_cooldown_remaining(slot: int) -> int:
	if slot < 0 or slot >= daily_quests.size():
		return 0
	var q : Dictionary = daily_quests[slot]
	if not bool(q.get("claimed", false)):
		return 0
	var claimed_at : int = int(q.get("claimed_at", 0))
	if claimed_at <= 0:
		return 0
	var now := int(Time.get_unix_time_from_system())
	var rem := claimed_at + slot_cooldown_sec(slot) - now
	return maxi(0, rem)

func is_slot_on_cooldown(slot: int) -> bool:
	return slot_cooldown_remaining(slot) > 0

# Walks every slot, replacing those whose cooldown has fully elapsed. Called
# at boot AND on demand (e.g. when the quests screen opens) so the rolls are
# in sync with wall-clock time even if the game was closed.
func check_cooldowns() -> bool:
	var changed := false
	for i in daily_quests.size():
		var q : Dictionary = daily_quests[i]
		if not bool(q.get("claimed", false)):
			continue
		if slot_cooldown_remaining(i) > 0:
			continue
		_replace_daily_quest(i)
		changed = true
	if changed:
		_save()
		quests_updated.emit()
	return changed

# ─── Badge status ─────────────────────────────────────────────────────────────
func has_daily_badge() -> bool:
	if daily_bonus_avail:
		return true
	for q in daily_quests:
		if q["completed"] and not q["claimed"]:
			return true
	return false

func has_story_badge() -> bool:
	for i in story_completed.size():
		if story_completed[i] and not story_claimed[i]:
			return true
	return false

# ─── Claim rewards ────────────────────────────────────────────────────────────
func claim_entry_bonus() -> void:
	if not daily_bonus_avail:
		return
	daily_bonus_avail = false
	SaveData.add_dollars(ENTRY_BONUS, "entry_bonus")
	Analytics.event("entry_bonus_claimed", { "amount": int(ENTRY_BONUS) })
	_save()
	quests_updated.emit()

func claim_daily(slot: int) -> Dictionary:
	if slot < 0 or slot >= daily_quests.size():
		return {}
	var q : Dictionary = daily_quests[slot]
	if not q["completed"] or q["claimed"]:
		return {}
	q["claimed"]    = true
	q["claimed_at"] = int(Time.get_unix_time_from_system())
	var def := _daily_def(slot)
	Analytics.event("quest_claimed", {
		"type":      "daily",
		"tier":      str(q.get("tier", "")),
		"cond":      str(def.get("cond", "")),
		"reward_d":  int(def.get("reward_d", 0)),
		"reward_t":  int(def.get("reward_t", 0)),
		"reward_xp": int(def.get("reward_xp", 0)),
	})
	_apply_reward(def)
	# NOTE: we no longer replace the quest immediately. The slot stays in a
	# "claimed / cooling down" state until slot_cooldown_remaining hits 0,
	# at which point check_cooldowns() rolls a fresh quest.
	_save()
	quests_updated.emit()
	return def

func _replace_daily_quest(slot: int) -> void:
	var tier : String = daily_quests[slot]["tier"]
	var pool : Array
	match tier:
		"easy":   pool = DAILY_EASY
		"medium": pool = DAILY_MEDIUM
		_:        pool = DAILY_HARD
	daily_quests[slot] = _new_slot(tier, randi() % pool.size())

func claim_story(idx: int) -> Dictionary:
	if idx < 0 or idx >= STORY_QUESTS.size():
		return {}
	if not story_completed[idx] or story_claimed[idx]:
		return {}
	story_claimed[idx] = true
	var def := STORY_QUESTS[idx] as Dictionary
	Analytics.event("quest_claimed", {
		"type":      "story",
		"idx":       int(idx),
		"cond":      str(def.get("cond", "")),
		"reward_d":  int(def.get("reward_d", 0)),
		"reward_t":  int(def.get("reward_t", 0)),
		"reward_xp": int(def.get("reward_xp", 0)),
	})
	_apply_reward(def)
	_save()
	quests_updated.emit()
	return def

func _apply_reward(def: Dictionary) -> void:
	var d := int(def.get("reward_d", 0))
	var t := int(def.get("reward_t", 0))
	var x := int(def.get("reward_xp", 0))
	if d > 0: SaveData.add_dollars(d, "quest_reward")
	if t > 0: SaveData.add_tokens(t, "quest_reward")
	if x > 0: SaveData.add_xp(x, "quest_reward")

func _daily_def(slot: int) -> Dictionary:
	var q   := daily_quests[slot] as Dictionary
	var idx := int(q["idx"])
	match q["tier"]:
		"easy":   return DAILY_EASY[idx]
		"medium": return DAILY_MEDIUM[idx]
		_:        return DAILY_HARD[idx]

# ─── Progress for UI ──────────────────────────────────────────────────────────

# Числовой прогресс слота: (сделано, нужно). Нужен полосе прогресса на карточке
# — по одному тексту «0 / 1000 пицц» полосу не нарисуешь, а взглядом игрок
# читает именно её. Разбор условия тот же, что и в daily_progress_text.
func daily_progress(slot: int) -> Vector2i:
	if slot < 0 or slot >= daily_quests.size():
		return Vector2i(0, 1)
	var q : Dictionary = daily_quests[slot]
	# Выполненное задание всегда показываем полным: у части условий («пройди
	# кампанию») промежуточного счётчика нет вовсе, и полоса застревала бы на нуле.
	if bool(q.get("completed", false)):
		return Vector2i(1, 1)
	var def   := _daily_def(slot)
	var parts := (def.get("cond", "") as String).split(":")
	var key   : String = parts[0]
	var need  : int    = int(parts[1]) if parts.size() > 1 else 1
	match key:
		"pizzas_today":      return Vector2i(mini(pizzas_today, need), need)
		"dollars_today":     return Vector2i(mini(dollars_today, need), need)
		"runs_today":        return Vector2i(mini(runs_today, need), need)
		"campaigns_today":   return Vector2i(mini(campaigns_today, 2), 2)
		"dollars_run":       return Vector2i(mini(dollars_best_run, need), need)
		"endless_secs":      return Vector2i(mini(int(endless_best_secs), need), need)
		"campaign_phases":   return Vector2i(mini(campaign_best_phases, 3), 3)
		"campaign_nodmg":    return Vector2i(mini(campaign_nodmg_best, 3), 3)
		"slot_match":        return Vector2i(mini(slot_best_match, need), need)
		"fat_run":           return Vector2i(mini(fat_best_run, 3), 3)
		"endless_today":     return Vector2i(1 if endless_today else 0, 1)
		"slot_today":        return Vector2i(1 if slot_today else 0, 1)
		"campaign_today":    return Vector2i(1 if campaigns_today > 0 else 0, 1)
		"campaign_fat":      return Vector2i(1 if campaign_fat_today else 0, 1)
		"campaign_complete": return Vector2i(0, 1)
	return Vector2i(0, 1)

# ─── Progress text for UI ─────────────────────────────────────────────────────
func daily_progress_text(slot: int) -> String:
	var def  := _daily_def(slot)
	var cond := def.get("cond", "") as String
	var parts := cond.split(":")
	var key   := parts[0]
	var need  := int(parts[1]) if parts.size() > 1 else 1
	match key:
		"pizzas_today":   return "%d / %d пицц"  % [mini(pizzas_today, need), need]
		"dollars_today":  return "%d / %d $"     % [mini(dollars_today, need), need]
		"runs_today":     return "%d / %d забегов"% [mini(runs_today, need), need]
		"campaigns_today":return "%d / 2 кампании"% mini(campaigns_today, 2)
		"dollars_run":    return "%d / %d $ (забег)" % [mini(dollars_best_run, need), need]
		"endless_secs":   var s := int(endless_best_secs); return "%d:%02d / %d:%02d" % [s/60, s%60, need/60, need%60]
		"campaign_phases":return "%d / 3 фазы" % mini(campaign_best_phases, 3)
		"campaign_nodmg": return "%d / 3 фазы без урона" % mini(campaign_nodmg_best, 3)
		"slot_match":     return "%d / %d совп." % [mini(slot_best_match, need), need]
		"fat_run":        var names := ["Худой","Стройный","Жирный","Убер"]; return names[mini(fat_best_run, 3)] + " / Убер"
		"endless_today":  return "1 / 1 бесконечность" if endless_today else "0 / 1 бесконечность"
		"slot_today":     return "1 / 1 спин" if slot_today else "0 / 1 спин"
		"campaign_today": return "1 / 1 кампания" if (campaigns_today > 0) else "0 / 1 кампания"
		"campaign_fat":   return ("Жир достигнут" if campaign_fat_today else "Жир не достигнут")
		"campaign_complete": return ("Завершена" if (daily_quests[slot]["completed"]) else "Не завершена")
	return ""

# ─── Event notifications ──────────────────────────────────────────────────────
func notify_run_started(is_campaign: bool, is_endless: bool) -> void:
	_check_day_reset()
	_run_is_campaign  = is_campaign
	_run_is_endless   = is_endless
	_run_fat_max      = 0
	_run_dollars      = 0
	_run_pizzas       = 0
	_run_phase        = 0
	_run_phase_nodmg  = true
	_run_phases_nodmg = 0
	_run_complete           = false
	_run_endless_secs       = 0.0
	_run_campaign_fat       = false
	_run_campaign_secs      = 0.0
	_story_campaign60_done  = story_completed[3]
	_story_campaign180_done = story_completed[4]
	runs_today += 1
	if is_campaign:
		campaigns_today += 1
	if is_endless:
		endless_today = true
		_check_story("endless_started")
	_check_story("run_started")
	_check_daily_all()
	_save()
	quests_updated.emit()

func notify_stats_changed(fat_state: int, total_pizzas: int, prev_fat: int) -> void:
	var delta      := maxi(0, total_pizzas - _run_pizzas)
	pizzas_today  += delta
	_run_pizzas    = total_pizzas
	if fat_state > _run_fat_max:
		_run_fat_max = fat_state
		if fat_state > fat_best_run:
			fat_best_run = fat_state
		_check_story("fat_reached:%d" % fat_state)
		if _run_is_campaign and fat_state >= 2:
			_run_campaign_fat = true
			campaign_fat_today = true
		_check_daily_all()
	if total_pizzas >= 10:
		_check_story("pizzas_run:10")
	_check_daily_cond("pizzas_today")
	quests_updated.emit()

func notify_pizza_eaten() -> void:
	pizzas_today += 1
	_run_pizzas  += 1
	if _run_pizzas >= 10:
		_check_story("pizzas_run:10")
	_check_daily_cond("pizzas_today")
	quests_updated.emit()

func notify_dollars_changed(total_run_dollars: int) -> void:
	var delta     := maxi(0, total_run_dollars - _run_dollars)
	_run_dollars   = total_run_dollars
	dollars_today += delta
	if total_run_dollars > dollars_best_run:
		dollars_best_run = total_run_dollars
	_check_daily_cond("dollars_today")
	_check_daily_cond("dollars_run")
	quests_updated.emit()

func notify_damage_taken() -> void:
	if _run_is_campaign:
		_run_phase_nodmg = false

func notify_campaign_time(secs: float) -> void:
	if not _run_is_campaign:
		return
	_run_campaign_secs = secs
	if not _story_campaign60_done and secs >= 60.0:
		_story_campaign60_done = true
		_check_story("campaign_time:60")
	if not _story_campaign180_done and secs >= 180.0:
		_story_campaign180_done = true
		_check_story("campaign_time:180")

func notify_campaign_phase(phase: int) -> void:
	if not _run_is_campaign:
		return
	if _run_phase_nodmg:
		_run_phases_nodmg += 1
		if _run_phases_nodmg > campaign_nodmg_best:
			campaign_nodmg_best = _run_phases_nodmg
	_run_phase_nodmg = true
	_run_phase = phase
	if phase > campaign_best_phases:
		campaign_best_phases = phase
	_check_daily_cond("campaign_phases")
	_check_daily_cond("campaign_nodmg")
	quests_updated.emit()

# Эпизод пройден. Условие с номером, а не отдельное на каждый: сюжетная ветка
# уже умеет «больше или равно» (см. `_check_story`), и пройденный третий эпизод
# закрывает задания за первый и второй, если игрок дошёл до них без книги.
func notify_episode_done(episode: int) -> void:
	if episode <= 0:
		return
	_check_story("episode_done:%d" % episode)
	quests_updated.emit()

# Дошёл до хвоста бесконечного.
func notify_hardcore() -> void:
	_check_story("hardcore_reached")
	quests_updated.emit()

func notify_campaign_complete() -> void:
	_run_complete = true
	_check_story("campaign_complete")
	_check_daily_cond("campaign_complete")
	quests_updated.emit()

func notify_boss_reached() -> void:
	_check_story("boss_reached")
	quests_updated.emit()

func notify_endless_time(secs: float) -> void:
	_run_endless_secs = secs
	if secs > endless_best_secs:
		endless_best_secs = secs
	_check_story("endless_time:300")
	_check_daily_cond("endless_secs")
	quests_updated.emit()

func notify_slot_spin(match_count: int) -> void:
	_check_day_reset()
	if not slot_today:
		slot_today = true
		_check_story("slot_played")
	if match_count > slot_best_match:
		slot_best_match = match_count
	if match_count >= 3:
		_check_story("slot_triple")
	_check_daily_cond("slot_today")
	_check_daily_cond("slot_match")
	_save()
	quests_updated.emit()

func notify_skin_bought() -> void:
	_check_story("skin_bought")
	_save()
	quests_updated.emit()

func _on_save_data_changed() -> void:
	var lvl := SaveData.skin_level
	_check_story("skin_level:2")
	_check_story("skin_level:5")
	_check_story("skin_level:10")
	quests_updated.emit()

# ─── Condition checking ───────────────────────────────────────────────────────
func _check_story(cond: String) -> void:
	for i in STORY_QUESTS.size():
		if story_completed[i]:
			continue
		if (STORY_QUESTS[i] as Dictionary).get("cond", "") == cond:
			_complete_story(i)
			break
	# range conditions (e.g. fat_reached:2 also satisfies fat_reached:1)
	var parts := cond.split(":")
	if parts.size() < 2:
		return
	var key := parts[0]
	var val := int(parts[1])
	for i in STORY_QUESTS.size():
		if story_completed[i]:
			continue
		var q    := STORY_QUESTS[i] as Dictionary
		var qp   := (q.get("cond", "") as String).split(":")
		if qp.size() < 2 or qp[0] != key:
			continue
		if val >= int(qp[1]):
			_complete_story(i)

func _complete_story(idx: int) -> void:
	if story_completed[idx]:
		return
	story_completed[idx] = true
	var def : Dictionary = STORY_QUESTS[idx]
	Analytics.event("quest_completed", {
		"type": "story",
		"idx":  int(idx),
		"cond": str(def.get("cond", "")),
	})
	# `reward_endless` — это ПОДПИСЬ награды в книге, а не сам замок: режим
	# открывается прогрессом эпизодов (см. `is_endless_unlocked`), и событие
	# `endless_unlocked` шлёт интерфейс в тот момент, когда открытие произошло
	# на самом деле.
	_save()
	quests_updated.emit()

func _check_daily_all() -> void:
	for i in daily_quests.size():
		_eval_daily(i)

func _check_daily_cond(key: String) -> void:
	for i in daily_quests.size():
		var def  := _daily_def(i)
		var cond := (def.get("cond", "") as String).split(":")[0]
		if cond == key:
			_eval_daily(i)

func _eval_daily(slot: int) -> void:
	var q := daily_quests[slot] as Dictionary
	if q["completed"]:
		return
	var def  := _daily_def(slot)
	var cond := def.get("cond", "") as String
	var parts := cond.split(":")
	var key  := parts[0]
	var need := int(parts[1]) if parts.size() > 1 else 1
	var done := false
	match key:
		"pizzas_today":    done = pizzas_today >= need
		"dollars_today":   done = dollars_today >= need
		"runs_today":      done = runs_today >= need
		"campaigns_today": done = campaigns_today >= need
		"endless_today":   done = endless_today
		"slot_today":      done = slot_today
		"campaign_today":  done = campaigns_today >= 1
		"campaign_fat":    done = campaign_fat_today
		"dollars_run":     done = dollars_best_run >= need
		"endless_secs":    done = endless_best_secs >= float(need)
		"campaign_phases": done = campaign_best_phases >= need
		"campaign_nodmg":  done = campaign_nodmg_best >= need
		"slot_match":      done = slot_best_match >= need
		"fat_run":         done = fat_best_run >= need
		"campaign_complete": done = _run_complete
	if done:
		q["completed"] = true
		Analytics.event("quest_completed", {
			"type": "daily",
			"tier": str(q.get("tier", "")),
			"cond": str(def.get("cond", "")),
		})
		daily_quest_completed.emit(slot, def.get("title", ""), def.get("desc", ""))
		_save()

# ─── Save / load ──────────────────────────────────────────────────────────────
# Dev helper: wipes story / daily quest progress so we can replay claim flows.
# Triggered from the main-menu dev button.
# Dev: clears just the "endless unlocked" flag (boss-defeat story quest)
# without wiping everything else. Useful for replaying the boss + unlock
# celebration without losing daily/skin progress.
func dev_reset_endless_unlock() -> void:
	# Прогресс эпизодов и есть замок бесконечного — сбрасываем именно его.
	SaveData.episodes_done = 0
	SaveData._save()
	if story_completed.size() > ENDLESS_UNLOCK_QUEST_IDX:
		story_completed[ENDLESS_UNLOCK_QUEST_IDX] = false
		story_claimed[ENDLESS_UNLOCK_QUEST_IDX]   = false
	_save()
	quests_updated.emit()

func dev_reset_all() -> void:
	story_completed.resize(STORY_QUESTS.size())
	story_completed.fill(false)
	story_claimed.resize(STORY_QUESTS.size())
	story_claimed.fill(false)
	daily_bonus_avail = true
	pizzas_today        = 0
	dollars_today       = 0
	runs_today          = 0
	campaigns_today     = 0
	endless_today       = false
	slot_today          = false
	campaign_fat_today  = false
	slot_best_match     = 0
	endless_best_secs   = 0.0
	campaign_best_phases= 0
	campaign_nodmg_best = 0
	dollars_best_run    = 0
	fat_best_run        = 0
	# Roll fresh quests for every slot so the dailies appear ready to play.
	_roll_daily_quests()
	_save()
	quests_updated.emit()

func _save() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not file:
		return
	file.store_string(JSON.stringify({
		"story_completed":   story_completed,
		"story_claimed":     story_claimed,
		"daily_date":        daily_date,
		"daily_quests":      daily_quests,
		"daily_bonus_avail": daily_bonus_avail,
		"streak_days":       streak_days,
		"streak_date":       streak_date,
		"pizzas_today":      pizzas_today,
		"dollars_today":     dollars_today,
		"runs_today":        runs_today,
		"campaigns_today":   campaigns_today,
		"endless_today":     endless_today,
		"slot_today":        slot_today,
		"campaign_fat_today":campaign_fat_today,
		"slot_best_match":   slot_best_match,
		"endless_best_secs": endless_best_secs,
		"campaign_best_phases": campaign_best_phases,
		"campaign_nodmg_best": campaign_nodmg_best,
		"dollars_best_run":  dollars_best_run,
		"fat_best_run":      fat_best_run,
	}))

func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var json  := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return
	var d : Dictionary = json.get_data()

	var sc = d.get("story_completed", [])
	for i in STORY_QUESTS.size():
		story_completed[i] = bool(sc[i]) if i < sc.size() else false
	var sk = d.get("story_claimed", [])
	for i in STORY_QUESTS.size():
		story_claimed[i] = bool(sk[i]) if i < sk.size() else false

	daily_date        = str(d.get("daily_date", ""))
	daily_bonus_avail = bool(d.get("daily_bonus_avail", true))
	streak_days       = int(d.get("streak_days", 0))
	streak_date       = str(d.get("streak_date", ""))

	var dq = d.get("daily_quests", [])
	if dq is Array and dq.size() == 3:
		daily_quests = []
		for item in dq:
			daily_quests.append({
				"tier":       str(item.get("tier", "easy")),
				"idx":        int(item.get("idx", 0)),
				"completed":  bool(item.get("completed", false)),
				"claimed":    bool(item.get("claimed", false)),
				"claimed_at": int(item.get("claimed_at", 0)),
			})
		# Shrinking a pool (e.g. dropping a quest from the design) can leave a
		# stale `idx` in the save that points past the new array end. Reroll
		# any out-of-range slot from its current tier pool so legacy saves
		# don't crash on startup.
		for i in daily_quests.size():
			var tier_str : String = str(daily_quests[i]["tier"])
			var pool : Array = DAILY_EASY
			match tier_str:
				"medium": pool = DAILY_MEDIUM
				"hard":   pool = DAILY_HARD
			var idx_i : int = int(daily_quests[i]["idx"])
			if idx_i < 0 or idx_i >= pool.size():
				daily_quests[i]["idx"]       = _pick_daily_idx(pool)
				daily_quests[i]["completed"] = false
				daily_quests[i]["claimed"]   = false
		# If endless is locked but a previously-rolled daily targets endless,
		# re-roll that single slot from the eligible pool.
		if not is_endless_unlocked():
			for i in daily_quests.size():
				var def := _daily_def(i)
				var cond_key = (def.get("cond", "") as String).split(":")[0]
				if is_endless_cond(cond_key):
					var pool : Array = DAILY_EASY
					match str(daily_quests[i]["tier"]):
						"medium": pool = DAILY_MEDIUM
						"hard":   pool = DAILY_HARD
					daily_quests[i]["idx"]       = _pick_daily_idx(pool)
					daily_quests[i]["completed"] = false
					daily_quests[i]["claimed"]   = false
	else:
		_roll_daily_quests()

	pizzas_today       = int(d.get("pizzas_today", 0))
	dollars_today      = int(d.get("dollars_today", 0))
	runs_today         = int(d.get("runs_today", 0))
	campaigns_today    = int(d.get("campaigns_today", 0))
	endless_today      = bool(d.get("endless_today", false))
	slot_today         = bool(d.get("slot_today", false))
	campaign_fat_today = bool(d.get("campaign_fat_today", false))
	slot_best_match    = int(d.get("slot_best_match", 0))
	endless_best_secs  = float(d.get("endless_best_secs", 0.0))
	campaign_best_phases = int(d.get("campaign_best_phases", 0))
	campaign_nodmg_best  = int(d.get("campaign_nodmg_best", 0))
	dollars_best_run   = int(d.get("dollars_best_run", 0))
	fat_best_run       = int(d.get("fat_best_run", 0))
