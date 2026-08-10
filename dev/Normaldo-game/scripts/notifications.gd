extends Node

# Push-notification facade. Single API in front of the native backends —
# NotifPluginIOS (GDExtension) and NotifPluginAndroid (Godot Android plugin) —
# which share one method/signal contract. On desktop (no backend) it degrades
# to a logging stub so the planner stays testable without a device. Concept
# doc: Концепция/Пуш-уведомления.md.

signal permission_changed(granted: bool)
signal notification_opened(payload: Dictionary)

const _TAG : String = "Notifications"

# Native notification backend singleton — `NotifPluginIOS` (GDExtension) on iOS
# or `NotifPluginAndroid` (Godot Android plugin) on Android. Resolved on _ready;
# null on desktop. Both expose the same method/signal contract, so every method
# below forwards identically; otherwise the stub state below is used.
var _native : Object = null

# Stub state — used on platforms without a native backend.
var _has_permission : bool       = true
var _pending        : Dictionary = {}  # id → { fire_at, title, body, payload }
# Buffer for "cold-start" taps: when the OS launches the app from a killed
# state via notification, the native plugin parses the launch options and
# parks the payload here before HUD has a chance to subscribe to
# `notification_opened`. HUD calls `consume_launch_payload()` in _ready so the
# tap fires through the normal router after the menu is live.
var _launch_payload : Dictionary = {}

func _ready() -> void:
	# Pick up whichever native backend registered itself as an engine singleton:
	# NotifPluginIOS (GDExtension, registered in notif_plugin_gdext.cpp) or
	# NotifPluginAndroid (Godot Android plugin, getPluginName()). Both share the
	# same method/signal contract, so the rest of this file is backend-agnostic.
	for backend in ["NotifPluginIOS", "NotifPluginAndroid"]:
		if Engine.has_singleton(backend):
			_native = Engine.get_singleton(backend)
			if _native.has_signal("tap_buffered"):
				_native.tap_buffered.connect(_drain_plugin_buffer)
			if _native.has_signal("permission_changed"):
				_native.permission_changed.connect(_on_plugin_permission_changed)
			# Remote-push token (FCM on Android / APNs on iOS) — arrives async, so
			# listen for it and also try whatever is already cached.
			if _native.has_signal("push_token"):
				_native.push_token.connect(_on_push_token)
			if _native.has_method("get_push_token"):
				_register_push_token(str(_native.get_push_token()))
			if _has_logger():
				Logger.info(_TAG, "native backend bound: %s" % backend)
			# Drain anything the backend buffered while the scene tree was
			# booting — cold-start taps land here.
			call_deferred("_drain_plugin_buffer")
			break

func _on_push_token(token: String) -> void:
	_register_push_token(token)

# Register the device's remote-push token server-side (users/{uid}) so Cloud
# Functions can target this player. Deduped against the last registered token in
# SaveData so repeated boots don't spam the backend.
func _register_push_token(token: String) -> void:
	if token == "" or _native == null:
		return
	if token == SaveData.registered_push_token:
		return
	var platform := _push_platform()
	if platform == "":
		return
	var resp : Dictionary = await LeaderboardClient.register_push_token(token, platform)
	if bool(resp.get("ok", false)):
		SaveData.registered_push_token = token
		SaveData._save()
		if _has_logger():
			Logger.info(_TAG, "push token registered (%s)" % platform)
	elif _has_logger():
		Logger.warn(_TAG, "push token registration failed: %s" % str(resp.get("error", "")))

func _push_platform() -> String:
	match OS.get_name():
		"Android": return "android"
		"iOS":     return "ios"
		_:         return ""

func _drain_plugin_buffer() -> void:
	if _native == null:
		return
	var taps : Array = _native.drain_pending_taps()
	for tap in taps:
		if not (tap is Dictionary):
			continue
		var entry : Dictionary = {
			"id":      str((tap as Dictionary).get("id", "")),
			"payload": (tap as Dictionary).get("payload", {}),
		}
		# Route live if HUD is already listening; otherwise buffer for the
		# first `consume_launch_payload` call (HUD does that in _ready).
		if notification_opened.get_connections().size() > 0:
			notification_opened.emit(entry)
			if _has_analytics():
				Analytics.event("notif_opened", {
					"notif_id":   entry.id,
					"category":   category_of(str(entry.id)),
					"cold_start": false,
				})
		else:
			_launch_payload = entry

func _on_plugin_permission_changed(granted: bool) -> void:
	_has_permission = granted
	permission_changed.emit(granted)
	if _has_analytics():
		Analytics.event("notif_permission", {
			"status": "granted" if granted else "denied",
		})

func has_permission() -> bool:
	if _native != null:
		return bool(_native.has_permission())
	# Stub assumes granted so the planner can run on desktop.
	return _has_permission

# Ask the OS for permission. The system dialog runs once per install; the
# response is mirrored to permission_changed. The stub auto-grants.
func request_permission() -> void:
	if _native != null:
		_native.request_permission()
		# Plugin will emit permission_changed asynchronously; we don't
		# pre-flip _has_permission to avoid lying to the planner.
		return
	_has_permission = true
	permission_changed.emit(true)
	if _has_analytics():
		Analytics.event("notif_permission", { "status": "granted" })

# Schedule a single local notification. `id` should be stable so a replan can
# cancel + re-add the same row idempotently. Fire-at is unix seconds.
func schedule(id: String, fire_at: int, title: String, body: String, payload: Dictionary = {}) -> void:
	# Shadow-copy of every spec is kept regardless of backend so dev tooling
	# (simulate_open) and the planner's "do I already have this id" checks
	# can answer without round-tripping through the native plugin.
	_pending[id] = {
		"fire_at": fire_at,
		"title":   title,
		"body":    body,
		"payload": payload,
	}
	if _native != null:
		_native.schedule(id, fire_at, title, body, payload)
	if _has_logger():
		Logger.info(_TAG, "schedule id=%s fire_at=%d title=%s" % [id, fire_at, title])
	if _has_analytics():
		Analytics.event("notif_scheduled", {
			"notif_id":   id,
			"category":   category_of(id),
			"fire_at":    fire_at,
			"lead_secs":  fire_at - int(Time.get_unix_time_from_system()),
		})

func cancel(id: String) -> void:
	_pending.erase(id)
	if _native != null:
		_native.cancel(id)
	if _has_logger():
		Logger.info(_TAG, "cancel id=%s" % id)

# Cancel every pending notif whose id begins with `prefix`. The planner uses
# this to wipe its own slate before a replan.
func cancel_category(prefix: String) -> void:
	var removed : Array = []
	for id in _pending.keys():
		if str(id).begins_with(prefix):
			removed.append(id)
	for id in removed:
		_pending.erase(id)
	if _native != null:
		_native.cancel_category(prefix)
	if _has_logger():
		Logger.info(_TAG, "cancel_category prefix=%s removed=%d" % [prefix, removed.size()])

func cancel_all() -> void:
	var n := _pending.size()
	_pending.clear()
	if _native != null:
		_native.cancel_all()
	if _has_logger():
		Logger.info(_TAG, "cancel_all removed=%d" % n)

# Snapshot of scheduled rows, sorted by fire_at. Always reads from the
# shadow `_pending` so dev tooling has the full payload (the iOS OS list
# doesn't round-trip the schedule call's payload back to us in a recoverable
# form). Slightly stale if the OS already fired/cancelled rows in the
# background, but those edge cases don't matter for dev simulation.
func list_pending() -> Array:
	var out : Array = []
	for id in _pending:
		var s : Dictionary = _pending[id]
		out.append({
			"id":      id,
			"fire_at": s.fire_at,
			"title":   s.title,
			"body":    s.body,
			"payload": s.payload,
		})
	out.sort_custom(func(a, b): return int(a.fire_at) < int(b.fire_at))
	return out

# Convention: ids are formatted as `notif_<lower-category-letter><suffix>`,
# e.g. "notif_a1", "notif_b3". `category_of("notif_a1")` returns "A".
func category_of(id: String) -> String:
	if id.length() < 7 or not id.begins_with("notif_"):
		return ""
	return id.substr(6, 1).to_upper()

# Native-plugin entry point for cold-start taps. Called from
# `application:didFinishLaunchingWithOptions:` (iOS) /
# `Activity.getIntent().getExtras()` (Android). The plugin can fire this at
# any time — before HUD subscribes, or after. If a subscriber is already
# connected we drain right away; otherwise the payload waits in the buffer
# for the next `consume_launch_payload()` call (HUD does this on _ready).
func set_launch_payload(id: String, payload: Dictionary = {}) -> void:
	if id == "":
		return
	_launch_payload = { "id": id, "payload": payload }
	if _has_logger():
		Logger.info(_TAG, "launch_payload set id=%s" % id)
	if notification_opened.get_connections().size() > 0:
		consume_launch_payload()

# Called by HUD once after it subscribes to `notification_opened`. Emits the
# stored launch payload (if any) so the deep-link router treats a cold-start
# tap identically to a warm tap. Idempotent — second call is a no-op.
func consume_launch_payload() -> void:
	if _launch_payload.is_empty():
		return
	var p : Dictionary = _launch_payload
	_launch_payload = {}
	notification_opened.emit(p)
	if _has_analytics():
		Analytics.event("notif_opened", {
			"notif_id":   p.get("id", ""),
			"category":   category_of(str(p.get("id", ""))),
			"cold_start": true,
		})
	if _has_logger():
		Logger.info(_TAG, "launch_payload consumed id=%s" % p.get("id", ""))

# Test-mode entry: pretend the user just tapped the notification with `id`,
# emitting `notification_opened` with the stored payload. Useful for dev hooks
# until the native plugin can deliver real taps.
func simulate_open(id: String) -> void:
	if not _pending.has(id):
		return
	var s : Dictionary = _pending[id]
	notification_opened.emit({ "id": id, "payload": s.get("payload", {}) })
	if _has_analytics():
		Analytics.event("notif_opened", {
			"notif_id": id,
			"category": category_of(id),
		})

func _has_logger() -> bool:
	return get_node_or_null("/root/Logger") != null

func _has_analytics() -> bool:
	return get_node_or_null("/root/Analytics") != null
