extends Node

# Notification planner — the brain that decides what gets scheduled when.
#
# Subscribes to durable-state signals (save, daily quests) and lifecycle
# notifications (focus-out, pause). Each replan:
#   1. Wipes the previous "notif_*" schedule from the Notifications facade.
#   2. Asks every enabled category planner for its candidate specs.
#   3. Pushes specs sitting inside quiet hours to the next safe slot.
#   4. Enforces the daily cap (max DAILY_CAP per local-date) by priority.
#   5. Re-schedules the surviving specs.
#
# Concept doc: Концепция/Пуш-уведомления.md
# Code review notes:
#   • Planners are pure functions of SaveData + QuestManager state — easy to
#     unit-test by stuffing fake state into the autoloads.
#   • `notif_*` is the only id prefix this planner emits, so cancel_category()
#     never wipes notifications scheduled by other systems.

const HOUR : int = 3600
const DAY  : int = 86400

# Max notifications fired on a single local-date. Specs beyond the cap are
# dropped lowest-priority-first.
const DAILY_CAP : int = 2

# Lower number = higher priority. Categories not listed default to 9 (worst).
const PRIORITY : Dictionary = {
	"F": 0,  # pending server rewards
	"E": 1,  # story / boss / endless unlock
	"G": 2,  # leaderboard
	"A": 3,  # re-engagement
	"B": 4,  # daily cycle
	"D": 5,  # slot machine
	"C": 5,  # skin progress
	"H": 6,  # content campaigns
}

var _replan_queued : bool = false

func _ready() -> void:
	# Replan whenever durable state changes — saves include progress, quests,
	# pending rewards, settings. _on_save fires often; we coalesce to one
	# replan per frame via _replan_queued.
	if SaveData.has_signal("data_changed"):
		SaveData.data_changed.connect(_request_replan)
	if QuestManager.has_signal("quests_updated"):
		QuestManager.quests_updated.connect(_request_replan)
	# Permission flips (grant or revoke) must rebuild the schedule too — when
	# granted we suddenly have room to add specs; when revoked we should
	# silently no-op until it's flipped back.
	if Notifications.has_signal("permission_changed"):
		Notifications.permission_changed.connect(func(_granted): _request_replan())
	# First plan after boot — deferred so other autoloads finish their _ready.
	call_deferred("_request_replan")

func _notification(what: int) -> void:
	# Focus-out / pause is the canonical "user just left the app" moment on
	# both iOS and Android. We stamp last_session_end_at and replan so the
	# re-engagement series fires off the most recent timestamp.
	if what == NOTIFICATION_APPLICATION_PAUSED \
			or what == NOTIFICATION_APPLICATION_FOCUS_OUT \
			or what == NOTIFICATION_WM_CLOSE_REQUEST:
		SaveData.last_session_end_at = int(Time.get_unix_time_from_system())
		SaveData._save()
		replan_all()

func _request_replan() -> void:
	if _replan_queued:
		return
	_replan_queued = true
	call_deferred("_replan_now")

func _replan_now() -> void:
	_replan_queued = false
	replan_all()

# Public entry point. Always recomputes from scratch — idempotent.
func replan_all() -> void:
	Notifications.cancel_category("notif_")
	if not SaveData.notif_enabled:
		return
	if not Notifications.has_permission():
		return
	var specs : Array = []
	var cats : Dictionary = SaveData.notif_categories
	if bool(cats.get("A", true)): specs.append_array(_plan_a())
	if bool(cats.get("B", true)): specs.append_array(_plan_b())
	if bool(cats.get("C", true)): specs.append_array(_plan_c())
	if bool(cats.get("D", true)): specs.append_array(_plan_d())
	if bool(cats.get("E", true)): specs.append_array(_plan_e())
	if bool(cats.get("F", true)): specs.append_array(_plan_f())
	if bool(cats.get("G", true)): specs.append_array(_plan_g())
	if bool(cats.get("H", true)): specs.append_array(_plan_h())

	var now := _now()
	specs = specs.filter(func(s): return int(s.fire_at) > now)
	for s in specs:
		s.fire_at = _push_out_of_quiet(int(s.fire_at))
	specs = _apply_daily_cap(specs)
	specs.sort_custom(func(a, b): return int(a.fire_at) < int(b.fire_at))
	for s in specs:
		Notifications.schedule(s.id, int(s.fire_at), str(s.title), str(s.body),
			s.get("payload", {}) as Dictionary)

# ── Quiet hours ──────────────────────────────────────────────────────────────

func _push_out_of_quiet(unix_ts: int) -> int:
	var start_h : int = int(SaveData.notif_quiet_start)
	var end_h   : int = int(SaveData.notif_quiet_end)
	if start_h == end_h:
		return unix_ts
	var ts := unix_ts
	# Cap iterations so a misconfigured window never spins forever.
	for _i in 48:
		var dt := Time.get_datetime_dict_from_unix_time(ts)
		var h := int(dt.hour)
		var in_quiet : bool
		if start_h < end_h:
			in_quiet = h >= start_h and h < end_h
		else:
			in_quiet = h >= start_h or h < end_h
		if not in_quiet:
			return ts
		ts += HOUR
	return ts

# ── Daily cap ────────────────────────────────────────────────────────────────

func _apply_daily_cap(specs: Array) -> Array:
	if specs.is_empty():
		return specs
	var sorted := specs.duplicate()
	sorted.sort_custom(func(a, b):
		var pa : int = int(PRIORITY.get(str(a.category), 9))
		var pb : int = int(PRIORITY.get(str(b.category), 9))
		if pa != pb:
			return pa < pb
		return int(a.fire_at) < int(b.fire_at)
	)
	var per_day : Dictionary = {}
	var kept    : Array = []
	for s in sorted:
		var date_key := Time.get_date_string_from_unix_time(int(s.fire_at))
		var c : int = int(per_day.get(date_key, 0))
		if c >= DAILY_CAP:
			continue
		per_day[date_key] = c + 1
		kept.append(s)
	return kept

# ── Spec helpers ─────────────────────────────────────────────────────────────

func _now() -> int:
	return int(Time.get_unix_time_from_system())

func _spec(id: String, fire_at: int, title: String, body: String,
		category: String, payload: Dictionary = {}) -> Dictionary:
	return {
		"id":       id,
		"category": category,
		"fire_at":  fire_at,
		"title":    title,
		"body":     body,
		"payload":  payload,
	}

# Returns a unix timestamp on the same local-date as `unix_ts`, set to
# `hour_local:00:00`. Used to anchor pings to a friendly hour-of-day.
func _on_day_at(unix_ts: int, hour_local: int) -> int:
	var dt := Time.get_datetime_dict_from_unix_time(unix_ts)
	dt.hour   = hour_local
	dt.minute = 0
	dt.second = 0
	return int(Time.get_unix_time_from_datetime_dict(dt))

# ── Category A — re-engagement ───────────────────────────────────────────────

func _plan_a() -> Array:
	var last_seen : int = int(SaveData.last_session_end_at)
	if last_seen <= 0:
		return []
	var specs : Array = []
	var name : String = str(SaveData.display_name)
	var skin : String = _skin_display_name()
	specs.append(_spec("notif_a1", _on_day_at(last_seen + DAY, 18),
		"Пицца стынет",
		_with_streak_hint("Нормальдо смотрит на сковородку и грустит."),
		"A"))
	specs.append(_spec("notif_a2", _on_day_at(last_seen + 3 * DAY, 18),
		"В канализации тихо…",
		"Слишком тихо. Ниндзи это нравится.",
		"A"))
	var a3_title : String
	if name != "":
		a3_title = "%s, твой скин просит апа" % name
	else:
		a3_title = "Твой скин просит апа"
	specs.append(_spec("notif_a3", _on_day_at(last_seen + 7 * DAY, 18),
		a3_title,
		"До нового уровня %s оставался один забег." % skin,
		"A"))
	specs.append(_spec("notif_a4", _on_day_at(last_seen + 14 * DAY, 18),
		"Учитель закрыл книгу",
		"Но не до конца. Заглянешь?",
		"A"))
	specs.append(_spec("notif_a5", _on_day_at(last_seen + 30 * DAY, 18),
		"Вернись — и я ничего не скажу",
		"На входе бонус «как давно не виделись».",
		"A"))
	return specs

func _with_streak_hint(base: String) -> String:
	var streak : int = int(QuestManager.streak_days)
	if streak >= 3:
		return base + " Стрик %d дней — не теряй." % streak
	return base

func _skin_display_name() -> String:
	if not Engine.has_singleton("SkinRegistry") and get_node_or_null("/root/SkinRegistry") == null:
		return "скин"
	var data = SkinRegistry.get_skin(str(SaveData.active_skin))
	if data is Dictionary:
		return str(data.get("name_ru", "скин"))
	return "скин"

# ── Category B — daily cycle ─────────────────────────────────────────────────

func _plan_b() -> Array:
	var now := _now()
	var specs : Array = []
	# B1 — fresh quests landed at midnight; nudge at 09:30 the next local day.
	specs.append(_spec("notif_b1", _on_day_at(now + DAY, 9) + 30 * 60,
		"Свежие задания дня",
		"Учитель прокатил три новых задачи. Логин-бонус ждёт у двери.",
		"B",
		{ "deep_link": "daily_quests" }))
	# B2 — 19:00 today if the player hasn't made any dent in the day yet.
	var t_b2 := _on_day_at(now, 19)
	if t_b2 > now and not _has_any_progress_today():
		specs.append(_spec("notif_b2", t_b2,
			"Сегодня ноль пицц",
			"Это можно поправить за один забег.",
			"B"))
	# B3 — 22:30 today if a streak is active and at risk.
	var streak : int = int(QuestManager.streak_days)
	if streak >= 2:
		var t_b3 := _on_day_at(now, 22) + 30 * 60
		if t_b3 > now:
			specs.append(_spec("notif_b3", t_b3,
				"Стрик %d дней висит на волоске" % streak,
				"Один забег — и стрик целый.",
				"B"))
	return specs

func _has_any_progress_today() -> bool:
	return int(QuestManager.pizzas_today) > 0 \
			or int(QuestManager.dollars_today) > 0 \
			or int(QuestManager.runs_today) > 0

# ── Category C — skin progress ───────────────────────────────────────────────
# Two mutually-exclusive states depending on where the player sits on the
# skin's XP track: pre-level-10 we nudge when the bar is almost full (C1);
# at level 10+ we switch to a mastery-shard nudge (C3). Numbers are picked so
# a notification only fires when the next milestone is within ~1 normal run.
const _C1_PROGRESS_THRESHOLD : float = 0.90
const _C3_PROGRESS_THRESHOLD : float = 0.66

func _plan_c() -> Array:
	var last_seen : int = int(SaveData.last_session_end_at)
	if last_seen <= 0:
		return []
	var specs    : Array = []
	var level    : int   = int(SaveData.skin_level)
	var progress : float = float(SaveData.xp_level_progress())

	if level < 10 and progress >= _C1_PROGRESS_THRESHOLD:
		var next_level := level + 1
		specs.append(_spec("notif_c1", last_seen + HOUR,
			"%s вот-вот возьмёт уровень %d" % [_skin_display_name(), next_level],
			"Один нормальный забег — и уровень в кармане.",
			"C"))
	elif level >= 10 and progress >= _C3_PROGRESS_THRESHOLD:
		specs.append(_spec("notif_c3", last_seen + 2 * HOUR,
			"Мастерство близко",
			"Ещё чуть-чуть, и тебе капнет жетон.",
			"C"))
	return specs

# ── Category D — slot machine ────────────────────────────────────────────────

func _plan_d() -> Array:
	if bool(QuestManager.slot_today):
		return []
	var now := _now()
	var t_d1 := _on_day_at(now, 12)
	if t_d1 <= now:
		# Today's window is already past — bump to tomorrow noon.
		t_d1 = _on_day_at(now + DAY, 12)
	return [_spec("notif_d1", t_d1,
		"Бесплатный спин валяется в автомате",
		"Прокрути и не возвращайся к работе.",
		"D",
		{ "deep_link": "slots" })]

# ── Category E — story / boss / endless ────────────────────────────────────
# E2 is special: one-shot per save, so we flip the SaveData flag the moment
# the spec lands on the schedule. Even if a later replan wipes the pending
# row before the OS fires it, we trade reliability for never double-pushing
# the same milestone — feels worse to nag than to miss once.
# Текст E1 по числу пройденных эпизодов: [заголовок, тело].
const E1_BY_EPISODE : Array = [
	["Нога Ниндзя зевает",   "Серьёзно, он уже зевает. Сделай ему больно."],
	["Крокодил не мигает",   "Второй эпизод ждёт. Он тоже ждёт, и он голоднее."],
	["Хозяин клуба звонит",  "Последний эпизод. Трубку он не положит."],
]

func _plan_e() -> Array:
	var specs     : Array = []
	var last_seen : int   = int(SaveData.last_session_end_at)

	# E2 — first time endless unlocks, congratulate ~30 min after exit so the
	# OS notification lands while the boss-fight afterglow is still fresh.
	if QuestManager.is_endless_unlocked() \
			and not bool(SaveData.notif_endless_announced):
		var fire_at : int = maxi(_now() + 30 * 60, last_seen + 30 * 60)
		specs.append(_spec("notif_e2", fire_at,
			"Бесконечный открыт",
			"Канализация теперь без конца. Проверь, на сколько хватит.",
			"E"))
		SaveData.notif_endless_announced = true
		SaveData._save()

	if last_seen > 0:
		# E1 — «босс всё ещё ждёт» для тех, кто не добил кампанию. Двухдневный
		# кулдаун держит ритм A2.
		#
		# Босса НАЗЫВАЕМ ПО ИМЕНИ — того, что стоит следующим. Кампания разбита
		# на эпизоды, и общий текст про ногу ниндзя врал бы всем, кто её уже
		# прошёл: игрок победил ниндзю неделю назад, а телефон пишет, что тот
		# зевает.
		if not QuestManager.is_endless_unlocked():
			var e1 : Array = E1_BY_EPISODE[clampi(int(SaveData.episodes_done), 0,
				E1_BY_EPISODE.size() - 1)]
			specs.append(_spec("notif_e1", _on_day_at(last_seen + 2 * DAY, 18),
				String(e1[0]), String(e1[1]), "E"))

		# E3 — story quest done but reward not collected from Книга учителя.
		var idx : int = _first_unclaimed_story_quest()
		if idx >= 0:
			var def : Dictionary = QuestManager.STORY_QUESTS[idx]
			var qtitle : String = str(def.get("title", "Глава"))
			specs.append(_spec("notif_e3", last_seen + DAY,
				"Учитель машет страницей",
				"Глава «%s» собрана — забирай награду." % qtitle,
				"E",
				{ "deep_link": "book_of_teacher", "story_idx": idx }))
	return specs

# Returns the index of the first story quest whose completion isn't yet
# claimed. -1 if everything is either incomplete or already collected.
func _first_unclaimed_story_quest() -> int:
	var quests   : Array = QuestManager.STORY_QUESTS
	var done     : Array = QuestManager.story_completed
	var claimed  : Array = QuestManager.story_claimed
	for i in quests.size():
		if i >= done.size() or i >= claimed.size():
			continue
		if bool(done[i]) and not bool(claimed[i]):
			return i
	return -1

# ── Category F — pending rewards from the server ─────────────────────────────

func _plan_f() -> Array:
	var rewards : Array = SaveData.pending_rewards
	var unclaimed : int = 0
	for r in rewards:
		if r is Dictionary and not bool(r.get("claimed", false)):
			unclaimed += 1
	if unclaimed <= 0:
		return []
	var now := _now()
	# Fire 6 h after the player last left if they haven't opened the rewards.
	var last_seen : int = int(SaveData.last_session_end_at)
	var fire_at : int = max(now + HOUR, last_seen + 6 * HOUR)
	return [_spec("notif_f1", fire_at,
		"Тебе пришёл подарок",
		"%d незабранных награды в канализации." % unclaimed,
		"F",
		{ "deep_link": "pending_rewards" })]

# ── Category G — leaderboard (stub: Sprint 4, needs Firestore wiring) ───────
func _plan_g() -> Array:
	return []

# ── Category H — manual content campaigns (remote-only, no local plan) ──────
func _plan_h() -> Array:
	return []
