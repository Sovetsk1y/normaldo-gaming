/**************************************************************************/
/*  notif_plugin.h                                                        */
/*                                                                        */
/*  iOS module plugin that bridges UNUserNotificationCenter to Godot's    */
/*  `Notifications` autoload. Registered as the engine singleton          */
/*  "NotifPluginIOS" during `godot_ios_plugins_initialize()`. The         */
/*  GDScript side (notifications.gd) prefers this singleton when present  */
/*  and falls back to the stub backend otherwise.                         */
/**************************************************************************/

#ifndef NOTIF_PLUGIN_H
#define NOTIF_PLUGIN_H

#include "core/object/class_db.h"
#include "core/object/object.h"
#include "core/variant/array.h"
#include "core/variant/dictionary.h"
#include "core/string/ustring.h"

class NotifPluginIOS : public Object {
	GDCLASS(NotifPluginIOS, Object);

	static NotifPluginIOS *instance;

	// Strongly-held ObjC delegate. Stored as `void *` to keep this header
	// pure C++ — the .mm file casts to NotifPluginDelegate on access.
	void *delegate_objc = nullptr;

	// Cached UNAuthorizationStatus translated to a plain bool. Refreshed at
	// startup and after every `request_permission` so `has_permission()`
	// stays synchronous for GDScript callers.
	bool cached_permission = false;

	// FIFO of taps queued before someone drained the buffer. Each entry is
	// a Dictionary `{ "id": String, "payload": Dictionary }`. The plugin
	// emits `tap_buffered` after every append so the GDScript autoload can
	// drain without polling.
	Array pending_taps;

protected:
	static void _bind_methods();

public:
	static NotifPluginIOS *get_singleton();

	// Synchronous permission check against the last cached value. Real OS
	// state is refreshed asynchronously inside `request_permission` and at
	// startup — callers should treat this as best-effort.
	bool has_permission() const;

	// Asks iOS for alert + sound + badge auth. Emits `permission_changed`
	// once the system dialog resolves.
	void request_permission();

	// Schedules a local notification. `fire_at` is unix seconds.
	void schedule(const String &id, int fire_at, const String &title,
			const String &body, const Dictionary &payload);

	void cancel(const String &id);
	void cancel_category(const String &prefix);
	void cancel_all();

	// Returns a freshly-fetched snapshot of every pending notification the
	// OS still has scheduled for this app. Each row is a Dictionary with
	// `id`, `fire_at`, `title`, `body`.
	//
	// iOS's `getPendingNotificationRequestsWithCompletionHandler:` is
	// async, so we issue a one-second semaphore wait. Cold-paths only — GD
	// side caches this rather than polling.
	Array list_pending();

	// Drains the buffered taps queue (cold-start + races) and returns the
	// dictionaries to GDScript. Buffer is cleared on every drain.
	Array drain_pending_taps();

	// Called from the ObjC delegate when iOS fires didReceiveResponse.
	void on_tap(const String &id, const Dictionary &payload);

	// Called from the ObjC delegate when `getNotificationSettings` or
	// `requestAuthorization` resolves.
	void on_permission_result(bool granted);

	NotifPluginIOS();
	~NotifPluginIOS();
};

// C entry points called from `dummy.cpp` so we don't pull ObjC++ symbols
// into the registration site.
void register_notif_plugin();
void unregister_notif_plugin();

#endif // NOTIF_PLUGIN_H
