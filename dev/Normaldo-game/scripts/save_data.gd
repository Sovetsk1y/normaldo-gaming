extends Node

const SAVE_PATH := "user://save.json"

# Total XP required to be AT each level (index = level - 1)
const LEVEL_XP := [0, 2400, 5600, 10400, 16800, 24800, 34800, 46800, 60800, 76800]

# Rewards on reaching each level (index = level number, index 0–1 unused)
const LEVEL_DOLLAR_REWARD := [0, 0, 200, 400, 600, 800, 1000, 1200, 1500, 2000, 4000]
const LEVEL_TOKEN_REWARD  := [0, 0,  1,   1,   2,   2,   2,   3,   3,   3,   5]

const MASTERY_XP_PER_TOKEN := 200

var dollars              : int    = 0
var tokens               : int    = 0
# Live fields — always reflect the currently active skin's progress
var skin_xp              : int    = 0
var skin_level           : int    = 1
var _mastery_tokens_given: int    = 0
var active_skin          : String = "classic"
var owned_skins          : Array  = ["classic"]
# Per-skin progress store: { skin_id: {xp, level, mastery} }
var skin_progress        : Dictionary = {}

# ── Каталог книги: что игрок уже видел ───────────────────────────────────────
# Ключ — id записи каталога (см. scripts/bestiary.gd), значение всегда true:
# нужен именно НАБОР, а словарь взят потому, что в JSON он и переживает
# сохранение, и проверяется за константу.
var seen_entries : Dictionary = {}

# Slot machine bonuses consumed at run start
var slot_xp_mult    : float = 1.0   # ×N XP for next run
var slot_luck_runs  : int   = 0     # ×2 XP for next N runs
var slot_extra_life : bool  = false # +1 life next run
var slot_pizza_storm: bool  = false # ×2 pizza spawn first 60 s next run

# ─── Leaderboard / Firebase identity ─────────────────────────────────────────
var user_id              : String = ""     # Firebase uid
var refresh_token        : String = ""     # for re-issuing idToken on cold start
var display_name         : String = ""     # auto-generated "Normaldo-XXXX" or user-chosen
var custom_display_name  : bool   = false  # true once the user has renamed
var recovery_code        : String = ""     # открытым текстом — показывается в настройках, хэш на сервере
# Рекорды недели по режимам: ключ — имя режима сервера («ep1»…«ep3», «endless»),
# значение — лучший результат. Раньше тут лежали `best_endless` и
# `total_endless`: рекорд и «гора пицц» одного-единственного режима. Режимов
# стало четыре, и каждый ведёт СВОЙ рекорд — см. `LeaderboardModes.Mode`.
var mode_best            : Dictionary = {}
# Последнее известное МЕСТО в таблице по каждому режиму. Нужно ради одной вещи:
# показать на экране смерти не только «ты 58-й», но и «поднялся на 4». Дельту
# сервер не считает — её знает только тот, кто помнит прошлое место, то есть
# клиент.
var mode_rank            : Dictionary = {}
var current_week_id      : String = ""
var pending_rewards      : Array  = []     # locally cached copy of server pending_rewards

# ─── Кампания: сколько эпизодов пройдено ─────────────────────────────────────
# Эпизоды отыгрываются ПО ОТДЕЛЬНОСТИ: прошёл первый — забег кончился, открылся
# второй. Здесь лежит номер последнего пройденного, 0…3; 3 означает «кампания
# пройдена», и ровно по этому числу открывается бесконечный режим.
var episodes_done        : int    = 0

# ── Сколько пиццы съедено ЗА ВСЮ ЖИЗНЬ ───────────────────────────────────────
# Копится по забегам и никогда не сбрасывается. Отдельное поле, а не сумма по
# скинам: в записи скина лежит его ЛУЧШИЙ забег, а не сумма, и восстановить
# прожитое из неё нельзя.
#
# У старых сейвов оно начинается с нуля — досчитать прошлое не из чего. Это
# честнее, чем показать выдуманное число.
var total_pizzas         : int    = 0

# ─── Скин, которым взят рекорд недели, по режимам ────────────────────────────
# Ключ — имя режима сервера, значение — id скина. Именно он показывается в
# таблице лидеров рядом с местом.
#
# ВЫБИРАЕМОЙ КАРТИНКИ ПРОФИЛЯ БОЛЬШЕ НЕТ. Раньше игрок ставил себе аватар сам
# (`chosen_avatar_skin` + `chosen_avatar_fat`), и в таблице стояло что угодно:
# скин, которым он не играл, в жире, которого не набирал. Аватар в таблице
# рекордов — это не украшение профиля, а СВИДЕТЕЛЬСТВО: им показывают, кем взят
# результат, и выбирать его отдельно нечего.
var record_skin : Dictionary = {}

# ─── Audio settings (0.0..1.0) ───────────────────────────────────────────────
var sfx_volume   : float = 1.0
var music_volume : float = 1.0

# ─── Push notifications ──────────────────────────────────────────────────────
# Master switch + per-category toggles (A..H mirror Концепция/Пуш-уведомления).
# `last_session_end_at` is stamped by NotifPlanner on focus-out so the
# re-engagement series knows when the player actually left the app.
# `notif_prompt_shown` flips true once we've asked for OS permission (or the
# player rejected the in-game prompt) — prevents asking again.
var notif_enabled       : bool       = true
var notif_categories    : Dictionary = {
	"A": true, "B": true, "C": true, "D": true,
	"E": true, "F": true, "G": true, "H": true,
}
var notif_quiet_start   : int  = 23
var notif_quiet_end     : int  = 9
var notif_prompt_shown  : bool = false
var last_session_end_at : int  = 0
# Last remote-push token (FCM/APNs) successfully registered server-side. Lets
# Notifications skip redundant registerPushToken calls when nothing changed.
var registered_push_token : String = ""
# Flips true the moment NotifPlanner schedules the endless-unlock celebration
# push (E2). Lets the planner ship that notification exactly once per save —
# subsequent replans see the flag and skip it.
var notif_endless_announced : bool = false

signal data_changed

func _ready() -> void:
	_load()
	apply_audio_volumes()
	# Local fallback so the menu shows a real nick from frame 1, even if the
	# Firebase sign-up hasn't completed yet (or there's no network). When the
	# leaderboard auth eventually finishes it can still overwrite this with
	# the server-side name if needed.
	if display_name.is_empty():
		display_name = _local_default_name()
		_save()

# Generates a local "Normaldo-XXXX" fallback. Uses a 4-char HEX hash from the
# current time + a random value so two cold installs don't collide visually.
func _local_default_name() -> String:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var seed_s := str(Time.get_unix_time_from_system()) + "-" + str(rng.randi())
	var hex := seed_s.sha256_text().to_upper()
	return "Normaldo-" + hex.substr(0, 4)

# Map a 0..1 slider value to a dB volume usable by AudioServer.
func _slider_to_db(v: float) -> float:
	if v <= 0.0:
		return -80.0
	return linear_to_db(clampf(v, 0.0, 1.0))

func apply_audio_volumes() -> void:
	var master_idx := AudioServer.get_bus_index("Master")
	var music_idx  := AudioServer.get_bus_index("Music")
	if master_idx >= 0:
		AudioServer.set_bus_volume_db(master_idx, _slider_to_db(sfx_volume))
	if music_idx >= 0:
		AudioServer.set_bus_volume_db(music_idx, _slider_to_db(music_volume))

func set_sfx_volume(v: float) -> void:
	sfx_volume = clampf(v, 0.0, 1.0)
	apply_audio_volumes()
	_save()

func set_music_volume(v: float) -> void:
	music_volume = clampf(v, 0.0, 1.0)
	apply_audio_volumes()
	_save()

# Returns the stored progress dict for a skin, creating defaults if absent.
func _skin_entry(id: String) -> Dictionary:
	if not skin_progress.has(id):
		skin_progress[id] = {"xp": 0, "level": 1, "mastery": 0, "runs": 0, "best": 0}
	return skin_progress[id]

# Flush live vars back into skin_progress before any save or skin switch.
func _flush_active() -> void:
	# ДОПИСЫВАЕМ в существующую запись, а не заменяем её целиком: в записи лежат
	# ещё и счётчики забегов, и полная замена молча стирала бы их при каждом
	# сохранении.
	var e := _skin_entry(active_skin)
	e["xp"]      = skin_xp
	e["level"]   = skin_level
	e["mastery"] = _mastery_tokens_given

# ── Статистика по скину ───────────────────────────────────────────────────────
# Сколько забегов сыграно этим скином и какой в нём рекорд по пиццам. Карточка
# скина показывает это строкой: коллекция без личной истории — просто список.

func note_run_finished(pizzas: int) -> void:
	var e := _skin_entry(active_skin)
	e["runs"] = int(e.get("runs", 0)) + 1
	e["best"] = maxi(int(e.get("best", 0)), maxi(pizzas, 0))
	total_pizzas += maxi(pizzas, 0)
	_save()

# Забегов ВСЕГО и лучший забег ВООБЩЕ — по всем скинам. Профиль показывает
# игрока целиком, а не текущий скин: «сыграно 240 забегов» это про него, а не
# про шляпу, в которой он сейчас.
func total_runs() -> int:
	var n := 0
	for id in skin_progress:
		n += int((skin_progress[id] as Dictionary).get("runs", 0))
	return n

func best_run() -> int:
	var b := 0
	for id in skin_progress:
		b = maxi(b, int((skin_progress[id] as Dictionary).get("best", 0)))
	return b

func get_skin_runs_for(id: String) -> int:
	if not skin_progress.has(id):
		return 0
	return int((skin_progress[id] as Dictionary).get("runs", 0))

func get_skin_best_for(id: String) -> int:
	if not skin_progress.has(id):
		return 0
	return int((skin_progress[id] as Dictionary).get("best", 0))

# Adds pizzas as XP. Returns Array of Dicts {level, dollars, tokens}.
# level == 0 means mastery token batch (no level-up, just tokens).
func add_xp(amount: int, source: String = "run_pizzas") -> Array:
	skin_xp += amount
	var rewards: Array = []
	if amount > 0:
		_emit_currency("xp", amount, source)

	while skin_level < 10:
		if skin_xp < LEVEL_XP[skin_level]:
			break
		skin_level += 1
		# Награда теперь СВОЯ у каждого скина (см. skin_progression.gd): дешёвые
		# платят меньше, а на чётных уровнях вместо денег приходят жир и
		# иммунитеты. Прежние общие массивы LEVEL_*_REWARD остались только для
		# совместимости старых сейвов и здесь больше не читаются.
		var rw : Dictionary = SkinProgression.reward_for(active_skin, skin_level)
		var d : int = int(rw.get("dollars", 0)) if rw.get("kind", "") == "money" else 0
		var t : int = int(rw.get("tokens",  0)) if rw.get("kind", "") == "money" else 0
		dollars += d
		tokens  += t
		_emit_skin_level_up(skin_level)
		if d > 0:
			_emit_currency("dollar", d, "skin_level_up")
		if t > 0:
			_emit_currency("token", t, "skin_level_up")
		rewards.append({"level": skin_level, "dollars": d, "tokens": t,
			"label": SkinProgression.reward_label(active_skin, skin_level)})

	if skin_level >= 10:
		var over  := skin_xp - LEVEL_XP[9]
		var total := over / MASTERY_XP_PER_TOKEN
		var new_t := total - _mastery_tokens_given
		if new_t > 0:
			tokens               += new_t
			_mastery_tokens_given += new_t
			_emit_currency("token", new_t, "skin_mastery")
			rewards.append({"level": 0, "dollars": 0, "tokens": new_t})

	_save()
	data_changed.emit()
	return rewards

func add_dollars(amount: int, source: String = "unknown") -> void:
	if amount == 0:
		return
	dollars += amount
	_emit_currency("dollar", amount, source)
	_save()
	data_changed.emit()

func add_tokens(amount: int, source: String = "unknown") -> void:
	if amount == 0:
		return
	tokens += amount
	_emit_currency("token", amount, source)
	_save()
	data_changed.emit()

# Fires currency_grant for positive amounts and currency_spend for negative;
# always logs the absolute value so dashboards don't have to know the sign.
func _emit_currency(currency: String, amount: int, source: String) -> void:
	if amount == 0 or not has_node("/root/Analytics"):
		return
	var ev := "currency_grant" if amount > 0 else "currency_spend"
	Analytics.event(ev, {
		"currency": currency,
		"amount":   int(absi(amount)),
		"source":   source,
	})

func _emit_skin_level_up(new_level: int) -> void:
	if not has_node("/root/Analytics"):
		return
	Analytics.event("skin_level_up", {
		"skin_id":   str(active_skin),
		"new_level": int(new_level),
	})

func owns_skin(id: String) -> bool:
	return id in owned_skins

func buy_skin(id: String) -> bool:
	if owns_skin(id):
		return false
	var skin  := SkinRegistry.get_skin(id)
	var price := skin.get("price", 0) as int
	if dollars < price:
		return false
	dollars -= price
	_emit_currency("dollar", -price, "skin_purchase")
	owned_skins.append(id)
	if has_node("/root/Analytics"):
		Analytics.event("skin_unlocked", {
			"skin_id":     str(id),
			"unlock_path": "purchase",
			"price":       int(price),
		})
	_save()
	data_changed.emit()
	return true

func set_active_skin(id: String) -> void:
	_flush_active()           # save current skin's progress before switching
	active_skin = id
	var p := _skin_entry(id)  # load the new skin's stored progress
	skin_xp               = p["xp"]
	skin_level            = p["level"]
	_mastery_tokens_given = p["mastery"]
	_save()
	data_changed.emit()

# Dev helper: wipe every owned skin except classic and switch back to it.
# Skin-XP entries are dropped along with ownership so re-buying a skin starts
# fresh. Triggered from the main-menu dev button.
func dev_reset_owned_skins() -> void:
	owned_skins = ["classic"]
	skin_progress.clear()
	active_skin = "classic"
	skin_xp                = 0
	skin_level             = 1
	_mastery_tokens_given  = 0
	record_skin.clear()
	_save()
	data_changed.emit()

func reset_skin_progress() -> void:
	skin_xp               = 0
	skin_level            = 1
	_mastery_tokens_given = 0
	_save()
	data_changed.emit()

# Read-only per-skin getters — needed so the shop card can show each skin's
# own XP/level without flipping the active skin. The active skin still uses
# the live `skin_xp` / `skin_level` vars (which can be ahead of the stored
# entry until the next `_flush_active`).
func get_skin_xp_for(id: String) -> int:
	if id == active_skin:
		return skin_xp
	if not skin_progress.has(id):
		return 0
	return int(skin_progress[id].get("xp", 0))

func get_skin_level_for(id: String) -> int:
	if id == active_skin:
		return skin_level
	if not skin_progress.has(id):
		return 1
	return int(skin_progress[id].get("level", 1))

# True if any owned skin is at mastery — used to surface the "chest ready"
# badge on the СКИНЫ menu button.
func has_ready_mastery_chest() -> bool:
	for id in owned_skins:
		if get_skin_level_for(id) >= 10:
			return true
	return false

func xp_level_progress_for(id: String) -> float:
	var lv := get_skin_level_for(id)
	var xp := get_skin_xp_for(id)
	if lv >= 10:
		var over := xp - LEVEL_XP[9]
		return float(over % MASTERY_XP_PER_TOKEN) / float(MASTERY_XP_PER_TOKEN)
	var from_xp = LEVEL_XP[lv - 1]
	var to_xp   = LEVEL_XP[lv]
	return clampf(float(xp - from_xp) / float(to_xp - from_xp), 0.0, 1.0)

# Сколько опыта осталось до следующего уровня КОНКРЕТНОГО скина. Карточке скина
# нужен остаток числом: полоса без числа отвечает «скоро», а игрок спрашивает
# «сколько ещё забегов».
func xp_to_next_level_for(id: String) -> int:
	var lv := get_skin_level_for(id)
	var xp := get_skin_xp_for(id)
	if lv >= 10:
		var over := xp - LEVEL_XP[9]
		return MASTERY_XP_PER_TOKEN - (over % MASTERY_XP_PER_TOKEN)
	return maxi(0, LEVEL_XP[lv] - xp)

# XP needed to reach the next level (or next mastery token)
func xp_to_next_level() -> int:
	if skin_level >= 10:
		var over := skin_xp - LEVEL_XP[9]
		return MASTERY_XP_PER_TOKEN - (over % MASTERY_XP_PER_TOKEN)
	return LEVEL_XP[skin_level] - skin_xp

# 0.0–1.0 fill fraction for the XP bar within the current level
func xp_level_progress() -> float:
	if skin_level >= 10:
		var over := skin_xp - LEVEL_XP[9]
		return float(over % MASTERY_XP_PER_TOKEN) / float(MASTERY_XP_PER_TOKEN)
	var from_xp = LEVEL_XP[skin_level - 1]
	var to_xp   = LEVEL_XP[skin_level]
	return clampf(float(skin_xp - from_xp) / float(to_xp - from_xp), 0.0, 1.0)

func consume_slot_bonuses() -> Dictionary:
	var result := {
		"xp_mult":     slot_xp_mult,
		"luck_runs":   slot_luck_runs,
		"extra_life":  slot_extra_life,
		"pizza_storm": slot_pizza_storm,
	}
	slot_xp_mult     = 1.0
	slot_luck_runs   = 0
	slot_extra_life  = false
	slot_pizza_storm = false
	_save()
	return result

# Пометить запись каталога встреченной. Возвращает true, если это ПЕРВАЯ
# встреча: сохраняться на каждый пролетевший банан незачем — сейв пишется
# только когда набор действительно изменился.
func mark_seen(id: String) -> bool:
	if id == "" or seen_entries.has(id):
		return false
	seen_entries[id] = true
	_save()
	return true

func _save() -> void:
	_flush_active()
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({
		"dollars":          dollars,
		"tokens":           tokens,
		"active_skin":      active_skin,
		"owned_skins":      owned_skins,
		"skin_progress":    skin_progress,
		"seen_entries":     seen_entries,
		"slot_xp_mult":     slot_xp_mult,
		"slot_luck_runs":   slot_luck_runs,
		"slot_extra_life":  slot_extra_life,
		"slot_pizza_storm": slot_pizza_storm,
		"user_id":             user_id,
		"refresh_token":       refresh_token,
		"display_name":        display_name,
		"custom_display_name": custom_display_name,
		"recovery_code":       recovery_code,
		"mode_best":           mode_best,
		"mode_rank":           mode_rank,
		"current_week_id":     current_week_id,
		"episodes_done":       episodes_done,
		"total_pizzas":        total_pizzas,
		"pending_rewards":     pending_rewards,
		"record_skin":         record_skin,
		"sfx_volume":          sfx_volume,
		"music_volume":        music_volume,
		"notif_enabled":       notif_enabled,
		"notif_categories":    notif_categories,
		"notif_quiet_start":   notif_quiet_start,
		"notif_quiet_end":     notif_quiet_end,
		"notif_prompt_shown":  notif_prompt_shown,
		"last_session_end_at": last_session_end_at,
		"notif_endless_announced": notif_endless_announced,
		"registered_push_token": registered_push_token,
	}))

func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var json  := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return
	var d: Dictionary = json.get_data()
	dollars     = int(d.get("dollars",    0))
	tokens      = int(d.get("tokens",     0))
	active_skin = str(d.get("active_skin", "classic"))

	var raw_owned = d.get("owned_skins", ["classic"])
	owned_skins = []
	for s in raw_owned:
		owned_skins.append(str(s))
	if not "classic" in owned_skins:
		owned_skins.append("classic")

	if d.has("seen_entries") and d["seen_entries"] is Dictionary:
		for k in (d["seen_entries"] as Dictionary):
			seen_entries[str(k)] = true

	if d.has("skin_progress"):
		# Current format: per-skin dictionary
		var raw_sp = d["skin_progress"]
		for k in raw_sp:
			var v = raw_sp[k]
			skin_progress[str(k)] = {
				"xp":      int(v.get("xp",      0)),
				"level":   int(v.get("level",   1)),
				"mastery": int(v.get("mastery", 0)),
				# Старые сейвы про забеги ничего не знают — начинаем с нуля.
				"runs":    int(v.get("runs",    0)),
				"best":    int(v.get("best",    0)),
			}
	elif d.has("skin_xp"):
		# Migrate old flat format: put saved values under the active skin
		skin_progress[active_skin] = {
			"xp":      int(d.get("skin_xp",              0)),
			"level":   int(d.get("skin_level",           1)),
			"mastery": int(d.get("mastery_tokens_given", 0)),
		}

	slot_xp_mult     = float(d.get("slot_xp_mult",     1.0))
	slot_luck_runs   = int(d.get("slot_luck_runs",   0))
	slot_extra_life  = bool(d.get("slot_extra_life",  false))
	slot_pizza_storm = bool(d.get("slot_pizza_storm", false))

	user_id             = str(d.get("user_id",             ""))
	refresh_token       = str(d.get("refresh_token",       ""))
	display_name        = str(d.get("display_name",        ""))
	custom_display_name = bool(d.get("custom_display_name", false))
	recovery_code       = str(d.get("recovery_code",       ""))
	# Старые сейвы несут `best_endless` — рекорд единственного тогдашнего
	# режима. Он и есть рекорд бесконечного: терять его при обновлении не за
	# что. «Гора пицц» (`total_endless`) не переносится — режима больше нет.
	mode_best           = (d.get("mode_best", {}) as Dictionary).duplicate()
	mode_rank           = (d.get("mode_rank", {}) as Dictionary).duplicate()
	if not mode_best.has("endless") and int(d.get("best_endless", 0)) > 0:
		mode_best["endless"] = int(d.get("best_endless", 0))
	current_week_id     = str(d.get("current_week_id",     ""))
	episodes_done       = int(d.get("episodes_done",       0))
	total_pizzas        = int(d.get("total_pizzas",        0))
	record_skin         = (d.get("record_skin", {}) as Dictionary).duplicate()
	sfx_volume          = float(d.get("sfx_volume",        1.0))
	music_volume        = float(d.get("music_volume",      1.0))
	notif_enabled       = bool(d.get("notif_enabled",       true))
	var raw_cats = d.get("notif_categories", null)
	if raw_cats is Dictionary:
		for k in raw_cats:
			notif_categories[str(k)] = bool(raw_cats[k])
	notif_quiet_start   = int(d.get("notif_quiet_start",    23))
	notif_quiet_end     = int(d.get("notif_quiet_end",       9))
	notif_prompt_shown  = bool(d.get("notif_prompt_shown",  false))
	last_session_end_at = int(d.get("last_session_end_at",  0))
	notif_endless_announced = bool(d.get("notif_endless_announced", false))
	registered_push_token = str(d.get("registered_push_token", ""))
	var raw_rewards = d.get("pending_rewards", [])
	pending_rewards = []
	for r in raw_rewards:
		pending_rewards.append(r)

	# Populate live vars from the active skin's stored entry
	var p := _skin_entry(active_skin)
	skin_xp               = p["xp"]
	skin_level            = p["level"]
	_mastery_tokens_given = p["mastery"]
