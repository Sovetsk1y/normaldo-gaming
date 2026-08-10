/**************************************************************************/
/*  notif_plugin.h                                                        */
/*                                                                        */
/*  GDExtension class that bridges UNUserNotificationCenter into Godot.   */
/*  Registered as the `NotifPluginIOS` engine singleton at SCENE level    */
/*  (see notif_plugin_gdext.cpp). GDScript looks it up via                */
/*  Engine.get_singleton("NotifPluginIOS").                               */
/**************************************************************************/

#ifndef NOTIF_PLUGIN_H
#define NOTIF_PLUGIN_H

#include <godot_cpp/classes/object.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/string.hpp>

namespace godot {

class NotifPluginIOS : public Object {
	GDCLASS(NotifPluginIOS, Object)

	static NotifPluginIOS *instance;

	// Strongly-held ObjC delegate. void* keeps this header pure C++ — the
	// .mm file casts to NotifPluginDelegate on access.
	void *delegate_objc = nullptr;

	// Cached UNAuthorizationStatus translated to a plain bool. Refreshed at
	// startup and after every `request_permission` so `has_permission()`
	// stays synchronous for GDScript callers.
	bool cached_permission = false;

	// FIFO of taps queued before someone drained the buffer. Each entry is
	// a Dictionary { "id": String, "payload": Dictionary }. The plugin emits
	// `tap_buffered` after every append so the GDScript autoload can drain
	// without polling.
	Array pending_taps;

	// APNs device token (hex), captured via the swizzled app-delegate callback.
	// Empty until iOS hands it back after registerForRemoteNotifications.
	String push_token;

protected:
	static void _bind_methods();

public:
	static NotifPluginIOS *get_singleton();

	bool has_permission() const;
	void request_permission();

	void schedule(const String &id, int fire_at, const String &title,
			const String &body, const Dictionary &payload);

	void cancel(const String &id);
	void cancel_category(const String &prefix);
	void cancel_all();

	// Synchronous one-second wait against
	// getPendingNotificationRequestsWithCompletionHandler. Cold-paths only —
	// GDScript caches the result rather than polling.
	Array list_pending();

	Array drain_pending_taps();

	// APNs remote-push device token (hex), or "" until iOS registers it.
	String get_push_token() const;

	// Called from the swizzled app-delegate callback with the APNs token.
	void on_push_token(const String &token);

	// Called from the ObjC delegate when iOS fires didReceiveResponse.
	void on_tap(const String &id, const Dictionary &payload);

	// Called from the ObjC delegate when getNotificationSettings or
	// requestAuthorization resolves.
	void on_permission_result(bool granted);

	NotifPluginIOS();
	~NotifPluginIOS();
};

} // namespace godot

#endif // NOTIF_PLUGIN_H
