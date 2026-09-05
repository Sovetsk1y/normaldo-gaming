extends Node

# Firebase-backed leaderboard client.
# Public API is async (await-style) and returns a Dictionary:
#   { "ok": bool, "data"|"error": ... }

const API_KEY        := "AIzaSyDceNn25Gc21B40bIxK4Q4El-rGjpFyQVc"
const PROJECT_ID     := "normaldo-game"
const REGION         := "europe-west1"
const AUTH_BASE      := "https://identitytoolkit.googleapis.com/v1"
const SECURETOKEN    := "https://securetoken.googleapis.com/v1/token"
const FUNCTIONS_BASE := "https://europe-west1-normaldo-game.cloudfunctions.net"

# Refresh idToken this many seconds before it expires.
const REFRESH_MARGIN_SECONDS : float = 300.0
const HTTP_TIMEOUT_SECONDS   : float = 12.0

enum State { IDLE, AUTHENTICATING, READY, ERROR }

signal state_changed(new_state: int)
signal authenticated(user_id: String, display_name: String)
signal pending_rewards_loaded(rewards: Array)

var _id_token         : String = ""
var _token_expires_at : float  = 0.0
var _state            : int    = State.IDLE
var _auth_started     : bool   = false

# ─── Bootstrap ───────────────────────────────────────────────────────────────

func _ready() -> void:
	_bootstrap_auth()

func _bootstrap_auth() -> void:
	if _auth_started:
		return
	_auth_started = true
	_set_state(State.AUTHENTICATING)
	if SaveData.user_id != "" and SaveData.refresh_token != "":
		await _refresh_id_token()
	else:
		await _sign_up_anonymously()
	if _state == State.READY:
		# Sync user data after auth
		await _init_or_sync_user()

func is_ready() -> bool:
	return _state == State.READY

func get_state() -> int:
	return _state

func get_user_id() -> String:
	return SaveData.user_id

func get_display_name() -> String:
	return SaveData.display_name

func get_recovery_code() -> String:
	return SaveData.recovery_code

# ─── Auth flows ──────────────────────────────────────────────────────────────

func _sign_up_anonymously() -> void:
	Logger.info("LBClient", "_sign_up_anonymously: starting")
	var url := "%s/accounts:signUp?key=%s" % [AUTH_BASE, API_KEY]
	var resp := await _http_json(url, [], "{}")
	if not resp.ok:
		Logger.err("LBClient", "signUp failed: %s" % str(resp.error))
		_fail("signUp", resp.error)
		return
	Logger.info("LBClient", "signUp ok: uid=%s" % str(resp.data.get("localId", "")))
	var data : Dictionary = resp.data
	_id_token             = str(data.get("idToken", ""))
	_token_expires_at     = Time.get_unix_time_from_system() + float(data.get("expiresIn", 3600))
	SaveData.user_id      = str(data.get("localId", ""))
	SaveData.refresh_token= str(data.get("refreshToken", ""))
	if SaveData.display_name == "":
		SaveData.display_name = _generate_display_name(SaveData.user_id)
	if SaveData.recovery_code == "":
		SaveData.recovery_code = _generate_recovery_code()
	SaveData._save()
	_set_state(State.READY)

func _refresh_id_token() -> void:
	var body := "grant_type=refresh_token&refresh_token=" + SaveData.refresh_token
	var headers := PackedStringArray(["Content-Type: application/x-www-form-urlencoded"])
	var url := "%s?key=%s" % [SECURETOKEN, API_KEY]
	var resp := await _http_json(url, headers, body)
	if not resp.ok:
		# Refresh failed — drop tokens and sign up anew on next session
		SaveData.refresh_token = ""
		SaveData.user_id       = ""
		SaveData._save()
		await _sign_up_anonymously()
		return
	var data : Dictionary = resp.data
	_id_token             = str(data.get("id_token", ""))
	SaveData.refresh_token = str(data.get("refresh_token", SaveData.refresh_token))
	_token_expires_at     = Time.get_unix_time_from_system() + float(data.get("expires_in", 3600))
	SaveData._save()
	_set_state(State.READY)

func _init_or_sync_user() -> void:
	Logger.info("LBClient", "_init_or_sync_user: starting, display_name=%s" % SaveData.display_name)
	var recovery_hash := _sha256_hex(SaveData.recovery_code) if SaveData.recovery_code != "" else ""
	var resp := await _call_function("initUser", {
		"display_name":       SaveData.display_name,
		"recovery_code_hash": recovery_hash,
	})
	Logger.info_dict("LBClient", "initUser response", resp)
	if not resp.ok:
		Logger.warn("LBClient", "initUser failed: %s" % str(resp.error))
		return
	var data : Dictionary = resp.data
	# Sync identity & avatar from server (server is source of truth here)
	var server_name := str(data.get("display_name", ""))
	if server_name != "":
		SaveData.display_name = server_name
	SaveData.mode_best       = (data.get("mode_best", {}) as Dictionary).duplicate()
	SaveData.current_week_id = str(data.get("week_id", ""))
	var rewards := data.get("pending_rewards", []) as Array
	SaveData.pending_rewards = rewards
	SaveData._save()
	authenticated.emit(SaveData.user_id, SaveData.display_name)
	pending_rewards_loaded.emit(rewards)

# ─── Public API ──────────────────────────────────────────────────────────────

# Результат забега уходит В ТАБЛИЦУ СВОЕГО РЕЖИМА. Раньше режим был один и
# аргумента не требовалось; теперь их четыре, и без явного `mode` рекорд эпизода
# лёг бы в таблицу бесконечного — то есть в чужой зачёт, где дистанция другая.
# Дошёл ли ДО СЕРВЕРА последний отправленный результат. Нужно не клиенту, а
# экрану лидеров: он писал «результат забега уже засчитан» всегда, а это
# обещание, которое некому выполнить, если отправка упала по той же причине, по
# которой не пришла таблица. Утешать игрока враньём хуже, чем не утешать.
#   -1 — ничего ещё не отправляли, 0 — не дошло, 1 — дошло.
var _last_submit : int = -1

func last_submit_ok() -> int:
	return _last_submit

func submit_score(mode: int, score: int, run_seconds: float) -> Dictionary:
	if not is_ready():
		await _await_ready()
	# Скин — ТОТ, КОТОРЫМ ИГРАЛИ, и жир ПЕРВЫЙ. Аватар в таблице рекордов это
	# свидетельство, а не украшение: он говорит, кем взят результат. Жир к
	# результату отношения не имеет и берётся первым у всех — иначе строки
	# таблицы отличались бы толщиной, а не именами.
	var avatar_skin := SaveData.active_skin
	var avatar_fat  := 0
	var resp := await _call_function("submitScore", {
		"mode":        _mode_name(mode),
		"score":       score,
		"run_seconds": run_seconds,
		"avatar_skin": avatar_skin,
		"avatar_fat":  avatar_fat,
	})
	if resp.ok:
		var data : Dictionary = resp.data
		if data.has("mode_best"):
			SaveData.mode_best = (data.get("mode_best", {}) as Dictionary).duplicate()
		# Запоминаем, каким скином взят рекорд этого режима: строка таблицы
		# рисуется по нему, и после смены скина она обязана остаться прежней.
		if int(data.get("best", 0)) > 0:
			SaveData.record_skin[_mode_name(mode)] = avatar_skin
		SaveData.current_week_id = str(data.get("week_id", SaveData.current_week_id))
		SaveData._save()
	_last_submit = 1 if resp.ok else 0
	return resp

func fetch_leaderboard(mode: int, limit: int = 100) -> Dictionary:
	if not is_ready():
		await _await_ready()
	return await _call_function("getLeaderboard", {
		"metric": _mode_name(mode),
		"limit":  limit,
	})

func fetch_window(mode: int, radius: int = 5) -> Dictionary:
	if not is_ready():
		await _await_ready()
	return await _call_function("getWindow", {
		"metric": _mode_name(mode),
		"radius": radius,
	})

# `updateAvatar` больше не зовётся: выбираемой картинки профиля нет, а скин
# рекорда уходит на сервер вместе с самим рекордом (см. `submit_score`).
# Серверная функция оставлена — старые строки таблицы, записанные до этой
# правки, ею и правились.

func set_display_name(new_name: String) -> Dictionary:
	if not is_ready():
		await _await_ready()
	var resp := await _call_function("setDisplayName", {"display_name": new_name})
	if resp.ok:
		SaveData.display_name = str(resp.data.get("display_name", new_name))
		SaveData.custom_display_name = true
		SaveData._save()
	return resp

func send_test_push() -> Dictionary:
	# Dev-only: asks the server to push a test remote notification back to this
	# device (sendTestPush targets request.auth.uid when no uid is passed).
	if not is_ready():
		await _await_ready()
	return await _call_function("sendTestPush", {})

func register_push_token(token: String, platform: String) -> Dictionary:
	# Persists the device's push token server-side (users/{uid}) so Cloud
	# Functions can target this player. Needs auth — waits for it like the other
	# calls. `platform` is "android" (FCM) or "ios" (APNs).
	if not is_ready():
		await _await_ready()
	return await _call_function("registerPushToken", {
		"token":    token,
		"platform": platform,
	})

func claim_reward(index: int) -> Dictionary:
	if not is_ready():
		await _await_ready()
	var resp := await _call_function("claimReward", {"index": index})
	if resp.ok and index >= 0 and index < SaveData.pending_rewards.size():
		var r : Dictionary = SaveData.pending_rewards[index]
		r["claimed"] = true
		SaveData.pending_rewards[index] = r
		SaveData._save()
	return resp

func restore_account(recovery_code: String) -> Dictionary:
	Logger.info("LBClient", "restore_account: entered, code_len=%d" % recovery_code.length())
	var hash := _sha256_hex(recovery_code)
	Logger.info("LBClient", "restore_account: hash=%s..." % hash.substr(0, 12))
	# Send with auth when available so the server can clean up the device's
	# previous anon identity. Falls back to unauth on cold install.
	var resp : Dictionary
	if _id_token != "":
		resp = await _call_function("restoreAccount", {"recovery_code_hash": hash})
	else:
		resp = await _call_function_unauth("restoreAccount", {"recovery_code_hash": hash})
	Logger.info_dict("LBClient", "restoreAccount CF response", resp)
	if not resp.ok:
		return resp
	var custom_token := str(resp.data.get("custom_token", ""))
	if custom_token == "":
		Logger.err("LBClient", "restoreAccount returned no custom_token")
		return {"ok": false, "error": "no custom_token in response"}
	# Sign in with custom token
	var sign_in_url := "%s/accounts:signInWithCustomToken?key=%s" % [AUTH_BASE, API_KEY]
	var body := JSON.stringify({"token": custom_token, "returnSecureToken": true})
	Logger.info("LBClient", "restore_account: signing in with custom token")
	var sign_in := await _http_json(sign_in_url, [], body)
	Logger.info_dict("LBClient", "signInWithCustomToken response", sign_in)
	if not sign_in.ok:
		Logger.err("LBClient", "signInWithCustomToken failed: %s" % str(sign_in.error))
		return {"ok": false, "error": sign_in.error}
	var sd : Dictionary = sign_in.data
	_id_token             = str(sd.get("idToken", ""))
	_token_expires_at     = Time.get_unix_time_from_system() + float(sd.get("expiresIn", 3600))
	SaveData.user_id      = str(sd.get("localId", ""))
	SaveData.refresh_token= str(sd.get("refreshToken", ""))
	SaveData.recovery_code = recovery_code
	SaveData._save()
	Logger.info("LBClient", "restore_account: signed in as uid=%s" % SaveData.user_id)
	_set_state(State.READY)
	await _init_or_sync_user()
	Logger.info("LBClient", "restore_account: completed successfully")
	return {"ok": true}

# ─── Internals ───────────────────────────────────────────────────────────────

func _mode_name(mode: int) -> String:
	return LeaderboardModes.mode_key(mode)

func _set_state(s: int) -> void:
	if _state == s: return
	_state = s
	state_changed.emit(s)

# Последняя причина отказа — словами. Держим её, потому что экран лидеров без
# неё показывал одну строку «сервер не ответил» на пять разных бед: нет сети,
# не поднялась авторизация, функция не развёрнута, сервер отказал, сервер
# ответил не-JSON. По такой строке нельзя ни починить, ни даже понять, к кому
# идти.
var _last_error : String = ""

func last_error() -> String:
	return _last_error

func _fail(op: String, err) -> void:
	_last_error = "%s: %s" % [op, str(err)]
	push_error("[LeaderboardClient] %s failed: %s" % [op, str(err)])
	_set_state(State.ERROR)

# Причина отказа вызова, годная для показа человеку. Коды HTTP переводятся в то,
# что они на самом деле означают для этого клиента.
func explain(resp: Dictionary) -> String:
	var status : int = int(resp.get("status", 0))
	var err : String = str(resp.get("error", ""))
	if status == 404:
		return "функция не развёрнута на сервере (404)"
	if status == 401 or status == 403:
		return "сервер отказал в доступе (%d)" % status
	if status >= 500:
		return "сервер ответил ошибкой (%d)" % status
	if err.begins_with("http_result="):
		return "нет связи с сервером (%s)" % err
	if err.begins_with("request enqueue failed"):
		return "запрос не ушёл (%s)" % err
	if status > 0:
		return "%d: %s" % [status, err]
	return err

func _await_ready() -> void:
	if _state == State.READY: return
	if _state == State.ERROR:
		# Try again
		_auth_started = false
		_bootstrap_auth()
	while _state != State.READY:
		await state_changed
		if _state == State.ERROR:
			return

func _ensure_fresh_token() -> void:
	var now := Time.get_unix_time_from_system()
	if now >= _token_expires_at - REFRESH_MARGIN_SECONDS and SaveData.refresh_token != "":
		await _refresh_id_token()

func _call_function(name: String, data: Dictionary) -> Dictionary:
	await _ensure_fresh_token()
	var url := "%s/%s" % [FUNCTIONS_BASE, name]
	var headers := PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer " + _id_token,
	])
	var body := JSON.stringify({"data": data})
	var resp := await _http_json(url, headers, body)
	if not resp.ok:
		_last_error = "%s: %s" % [name, explain(resp)]
		return resp
	# Callable wraps payload as { result: {...} } or { error: {...} }
	var raw : Dictionary = resp.data
	if raw.has("error"):
		_last_error = "%s: %s" % [name, str(raw["error"])]
		return {"ok": false, "error": raw["error"], "status": resp.get("status", 0)}
	return {"ok": true, "data": raw.get("result", {})}

func _call_function_unauth(name: String, data: Dictionary) -> Dictionary:
	var url := "%s/%s" % [FUNCTIONS_BASE, name]
	var headers := PackedStringArray(["Content-Type: application/json"])
	var body := JSON.stringify({"data": data})
	var resp := await _http_json(url, headers, body)
	if not resp.ok:
		return resp
	var raw : Dictionary = resp.data
	if raw.has("error"):
		return {"ok": false, "error": raw["error"], "status": resp.get("status", 0)}
	return {"ok": true, "data": raw.get("result", {})}

func _http_json(url: String, headers: PackedStringArray, body: String) -> Dictionary:
	var http := HTTPRequest.new()
	http.timeout = HTTP_TIMEOUT_SECONDS
	add_child(http)
	var method := HTTPClient.METHOD_POST
	var err := http.request(url, headers, method, body)
	if err != OK:
		http.queue_free()
		return {"ok": false, "error": "request enqueue failed: %d" % err}
	var result : Array = await http.request_completed
	http.queue_free()
	# result: [http_result_code, response_code, headers, body_bytes]
	var http_result    : int = result[0]
	var response_code  : int = result[1]
	var body_bytes : PackedByteArray = result[3]
	if http_result != HTTPRequest.RESULT_SUCCESS:
		return {"ok": false, "error": "http_result=%d" % http_result}
	var body_str := body_bytes.get_string_from_utf8()
	var parsed = JSON.parse_string(body_str)
	if response_code != 200:
		return {"ok": false, "error": parsed if parsed != null else body_str, "status": response_code}
	if parsed == null:
		return {"ok": false, "error": "non-JSON response: " + body_str, "status": response_code}
	return {"ok": true, "data": parsed, "status": response_code}

# ─── Helpers ─────────────────────────────────────────────────────────────────

func _generate_display_name(uid: String) -> String:
	var hex := _sha256_hex(uid).to_upper()
	return "Normaldo-" + hex.substr(0, 4)

func _generate_recovery_code() -> String:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var hex := "0123456789ABCDEF"
	var parts : Array = []
	for g in 3:
		var part := ""
		for c in 4:
			part += hex[rng.randi() % 16]
		parts.append(part)
	return "NORM-" + "-".join(parts)

func _sha256_hex(s: String) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(s.to_utf8_buffer())
	return ctx.finish().hex_encode()
