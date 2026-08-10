extends Node

# Firebase / GA4 analytics via the Measurement Protocol — pure HTTP, no native
# SDK required. Credentials come from scripts/secrets.gd, which is untracked;
# copy scripts/secrets.gd.example to create it. Until both values are set the
# singleton no-ops so dev builds don't spam the network.
#
# Debug mode (DEBUG_ENDPOINT) returns validation errors in the response body
# but does NOT actually record events — flip USE_DEBUG_ENDPOINT during wiring,
# then turn it off before shipping.

const SECRETS_PATH        : String = "res://scripts/secrets.gd"
const USE_DEBUG_ENDPOINT  : bool   = false

const ENDPOINT       := "https://www.google-analytics.com/mp/collect"
const DEBUG_ENDPOINT := "https://www.google-analytics.com/debug/mp/collect"

const FLUSH_INTERVAL_SEC : float = 30.0    # bumped down during setup; raise to 30 once verified
const BATCH_SIZE         : int   = 20
const MAX_QUEUE          : int   = 200
const VERBOSE            : bool  = false   # log every flush result; switch to false after setup is confirmed

const CONFIG_PATH := "user://analytics.cfg"

var _measurement_id : String = ""
var _api_secret : String = ""
var _client_id : String = ""
var _session_id : String = ""
var _enabled   : bool   = false
var _http      : HTTPRequest
var _queue     : Array  = []
var _in_flight : bool   = false
var _flush_t   : float  = 0.0
var _session_t : float  = 0.0

# Filled lazily from ProjectSettings — avoids repeated lookups inside event().
var _app_version : String = ""
var _platform    : String = ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	if ResourceLoader.exists(SECRETS_PATH):
		var secrets := load(SECRETS_PATH)
		_measurement_id = secrets.GA4_MEASUREMENT_ID
		_api_secret     = secrets.GA4_API_SECRET

	_enabled = _measurement_id != "" and _api_secret != ""
	if not _enabled:
		push_warning("[analytics] disabled — copy scripts/secrets.gd.example to scripts/secrets.gd and fill it in")
		set_process(false)
		return

	_app_version = str(ProjectSettings.get_setting("application/config/version", ""))
	if _app_version == "":
		# Fall back to the engine version string so events at least carry a
		# meaningful build hint until application/config/version is set.
		_app_version = "godot-%s" % Engine.get_version_info().get("string", "unknown")
	_platform    = OS.get_name().to_lower()

	_client_id  = _load_or_make_client_id()
	_session_id = _make_uuid()

	_http = HTTPRequest.new()
	# accept_gzip=false dodges a Godot 4 macOS quirk where the gzipped GA4
	# response can surface as RESULT_CANT_CONNECT instead of a normal 200.
	_http.accept_gzip = false
	_http.use_threads = true
	_http.timeout     = 10.0
	add_child(_http)
	_http.request_completed.connect(_on_request_done)

	# Note: "session_start" and "screen_view" are RESERVED by GA4 (auto-emitted
	# by the native SDK). MP rejects them — prefix our own with "app_".
	event("app_session_start", {})

func _process(delta: float) -> void:
	_session_t += delta
	_flush_t   += delta
	if _flush_t >= FLUSH_INTERVAL_SEC or _queue.size() >= BATCH_SIZE:
		flush()

# ── Public API ────────────────────────────────────────────────────────────────

func event(name: String, params: Dictionary = {}) -> void:
	if not _enabled:
		return
	# GA4 limits: event name ≤ 40 chars, param key ≤ 40, string value ≤ 100.
	# We don't truncate here — callers should keep payloads tight; oversize
	# fields would be rejected by the server.
	var enriched := params.duplicate()
	enriched["app_version"] = _app_version
	enriched["platform"]    = _platform
	enriched["session_id"]  = _session_id
	enriched["engagement_time_msec"] = 1   # required by GA4 for active session
	_queue.append({ "name": name, "params": enriched })
	if _queue.size() > MAX_QUEUE:
		# Drop the oldest events first — the most recent ones tend to be the
		# most valuable for debugging the current session.
		_queue = _queue.slice(_queue.size() - MAX_QUEUE)

func flush() -> void:
	if not _enabled or _in_flight or _queue.is_empty():
		return
	var take : int = mini(BATCH_SIZE, _queue.size())
	var batch : Array = _queue.slice(0, take)
	var payload := {
		"client_id":            _client_id,
		"non_personalized_ads": true,
		"events":               batch,
	}
	var base := DEBUG_ENDPOINT if USE_DEBUG_ENDPOINT else ENDPOINT
	var url  := "%s?measurement_id=%s&api_secret=%s" % [base, _measurement_id, _api_secret]
	var body_str := JSON.stringify(payload)
	if VERBOSE:
		print("[analytics] → POST %s events=%d body=%s" % [base, batch.size(), body_str])
	var err := _http.request(url, ["Content-Type: application/json"],
			HTTPClient.METHOD_POST, body_str)
	if err != OK:
		print("[analytics] request() failed: %d" % err)
		return
	# Pop only after a successful enqueue so a failed dispatch keeps the events
	# in the queue for the next flush attempt.
	_queue   = _queue.slice(take)
	_in_flight = true
	_flush_t   = 0.0

func _on_request_done(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_in_flight = false
	var txt := body.get_string_from_utf8()
	if result != HTTPRequest.RESULT_SUCCESS or code >= 400:
		# Only log failures during explicit setup/debug — otherwise the console
		# fills up on networks that can't reach Google at all (regional blocks,
		# offline mode, etc). Production runs silently swallow failures.
		if VERBOSE or USE_DEBUG_ENDPOINT:
			print("[analytics] ← FAIL result=%d code=%d body=%s" % [result, code, txt])
		return
	if VERBOSE:
		print("[analytics] ← OK code=%d body=%s" % [code, txt])
	# If more events queued up while we were in flight, kick the next batch.
	if _queue.size() >= BATCH_SIZE:
		flush()

# ── Lifecycle ────────────────────────────────────────────────────────────────

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_APPLICATION_PAUSED:
			event("app_session_end", { "duration_sec": int(_session_t) })
			flush()

# ── Identity ─────────────────────────────────────────────────────────────────

func _load_or_make_client_id() -> String:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) == OK:
		var existing := str(cfg.get_value("identity", "client_id", ""))
		if existing != "":
			return existing
	var fresh := _make_uuid()
	cfg.set_value("identity", "client_id", fresh)
	cfg.save(CONFIG_PATH)
	return fresh

# RFC 4122 v4 UUID built from randi() — fine for analytics identity (not
# cryptographic). 16 bytes, version + variant bits, formatted as 8-4-4-4-12.
func _make_uuid() -> String:
	var bytes : Array = []
	for i in 16:
		bytes.append(randi() & 0xFF)
	bytes[6] = (bytes[6] & 0x0F) | 0x40
	bytes[8] = (bytes[8] & 0x3F) | 0x80
	var hex := ""
	for b in bytes:
		hex += "%02x" % b
	return "%s-%s-%s-%s-%s" % [
		hex.substr(0, 8),
		hex.substr(8, 4),
		hex.substr(12, 4),
		hex.substr(16, 4),
		hex.substr(20, 12),
	]
