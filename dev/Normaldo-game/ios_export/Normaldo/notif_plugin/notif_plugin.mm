/**************************************************************************/
/*  notif_plugin.mm                                                       */
/*                                                                        */
/*  ObjC++ implementation of the NotifPluginIOS module. See               */
/*  notif_plugin.h for the public API and rationale.                      */
/**************************************************************************/

#import "notif_plugin.h"

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <UserNotifications/UserNotifications.h>

#include "core/config/engine.h"

// ─── ObjC delegate ───────────────────────────────────────────────────────────
// Forwards UNUserNotificationCenter callbacks into the C++ singleton.

@interface NotifPluginDelegate : NSObject <UNUserNotificationCenterDelegate>
@end

@implementation NotifPluginDelegate

// Foreground presentation — show as a banner with sound when the app is open,
// matching iOS 14+ defaults so the player still notices a tap-worthy ping.
- (void)userNotificationCenter:(UNUserNotificationCenter *)center
		willPresentNotification:(UNNotification *)notification
		withCompletionHandler:(void (^)(UNNotificationPresentationOptions))completionHandler {
	if (@available(iOS 14.0, *)) {
		completionHandler(UNNotificationPresentationOptionBanner | UNNotificationPresentationOptionSound | UNNotificationPresentationOptionList);
	} else {
		completionHandler(UNNotificationPresentationOptionAlert | UNNotificationPresentationOptionSound);
	}
}

// User tap — extract identifier + userInfo, bridge into Godot.
- (void)userNotificationCenter:(UNUserNotificationCenter *)center
		didReceiveNotificationResponse:(UNNotificationResponse *)response
		withCompletionHandler:(void (^)(void))completionHandler {
	NotifPluginIOS *plugin = NotifPluginIOS::get_singleton();
	if (plugin == nullptr) {
		completionHandler();
		return;
	}
	NSString *idStr = response.notification.request.identifier;
	NSDictionary *userInfo = response.notification.request.content.userInfo;

	String godot_id = String::utf8([idStr UTF8String]);
	Dictionary payload;
	for (NSString *key in userInfo) {
		id value = userInfo[key];
		String k = String::utf8([key UTF8String]);
		if ([value isKindOfClass:[NSString class]]) {
			payload[k] = String::utf8([(NSString *)value UTF8String]);
		} else if ([value isKindOfClass:[NSNumber class]]) {
			// Bridge integers vs floats by checking the underlying type tag.
			const char *t = [(NSNumber *)value objCType];
			if (t && (*t == 'i' || *t == 'l' || *t == 'q' || *t == 's' || *t == 'c')) {
				payload[k] = (int64_t)[(NSNumber *)value longLongValue];
			} else {
				payload[k] = (double)[(NSNumber *)value doubleValue];
			}
		}
		// Other types (NSArray, NSDictionary, NSData) are dropped — none of
		// our planner specs use them and supporting them would balloon the
		// bridging code without payoff.
	}

	plugin->on_tap(godot_id, payload);
	completionHandler();
}

@end

// ─── C++ singleton ───────────────────────────────────────────────────────────

NotifPluginIOS *NotifPluginIOS::instance = nullptr;

NotifPluginIOS *NotifPluginIOS::get_singleton() {
	return instance;
}

void NotifPluginIOS::_bind_methods() {
	ClassDB::bind_method(D_METHOD("has_permission"), &NotifPluginIOS::has_permission);
	ClassDB::bind_method(D_METHOD("request_permission"), &NotifPluginIOS::request_permission);
	ClassDB::bind_method(D_METHOD("schedule", "id", "fire_at", "title", "body", "payload"), &NotifPluginIOS::schedule);
	ClassDB::bind_method(D_METHOD("cancel", "id"), &NotifPluginIOS::cancel);
	ClassDB::bind_method(D_METHOD("cancel_category", "prefix"), &NotifPluginIOS::cancel_category);
	ClassDB::bind_method(D_METHOD("cancel_all"), &NotifPluginIOS::cancel_all);
	ClassDB::bind_method(D_METHOD("list_pending"), &NotifPluginIOS::list_pending);
	ClassDB::bind_method(D_METHOD("drain_pending_taps"), &NotifPluginIOS::drain_pending_taps);

	ADD_SIGNAL(MethodInfo("permission_changed", PropertyInfo(Variant::BOOL, "granted")));
	ADD_SIGNAL(MethodInfo("tap_buffered"));
}

NotifPluginIOS::NotifPluginIOS() {
	ERR_FAIL_COND(instance != nullptr);
	instance = this;

	NotifPluginDelegate *delegate = [[NotifPluginDelegate alloc] init];
	[UNUserNotificationCenter currentNotificationCenter].delegate = delegate;
	delegate_objc = (__bridge_retained void *)delegate;

	// Prime the cached permission state so GDScript sees the right value
	// before the user is ever asked. Falls back to "not granted" if the
	// async query is slow; refreshed once the system dialog resolves.
	[[UNUserNotificationCenter currentNotificationCenter] getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings *settings) {
		bool granted = (settings.authorizationStatus == UNAuthorizationStatusAuthorized
				|| settings.authorizationStatus == UNAuthorizationStatusProvisional);
		// Hop to main so we touch Godot data on the engine thread.
		dispatch_async(dispatch_get_main_queue(), ^{
			if (NotifPluginIOS::get_singleton()) {
				NotifPluginIOS::get_singleton()->cached_permission = granted;
			}
		});
	}];
}

NotifPluginIOS::~NotifPluginIOS() {
	if (delegate_objc) {
		NotifPluginDelegate *delegate = (__bridge_transfer NotifPluginDelegate *)delegate_objc;
		if ([UNUserNotificationCenter currentNotificationCenter].delegate == delegate) {
			[UNUserNotificationCenter currentNotificationCenter].delegate = nil;
		}
		delegate_objc = nullptr;
	}
	if (instance == this) {
		instance = nullptr;
	}
}

bool NotifPluginIOS::has_permission() const {
	return cached_permission;
}

void NotifPluginIOS::request_permission() {
	UNAuthorizationOptions options = UNAuthorizationOptionAlert | UNAuthorizationOptionSound | UNAuthorizationOptionBadge;
	[[UNUserNotificationCenter currentNotificationCenter] requestAuthorizationWithOptions:options
			completionHandler:^(BOOL granted, NSError * _Nullable error) {
		dispatch_async(dispatch_get_main_queue(), ^{
			NotifPluginIOS *self_ref = NotifPluginIOS::get_singleton();
			if (self_ref) {
				self_ref->on_permission_result((bool)granted);
			}
		});
	}];
}

void NotifPluginIOS::on_permission_result(bool granted) {
	cached_permission = granted;
	emit_signal("permission_changed", granted);
}

void NotifPluginIOS::schedule(const String &id, int fire_at, const String &title,
		const String &body, const Dictionary &payload) {
	NSString *idStr = [NSString stringWithUTF8String:id.utf8().get_data()];
	NSString *titleStr = [NSString stringWithUTF8String:title.utf8().get_data()];
	NSString *bodyStr = [NSString stringWithUTF8String:body.utf8().get_data()];

	UNMutableNotificationContent *content = [[UNMutableNotificationContent alloc] init];
	content.title = titleStr;
	content.body = bodyStr;
	content.sound = [UNNotificationSound defaultSound];

	// Mirror the Godot payload as userInfo so the tap delegate can echo it
	// back. Only String / int / float survive the round-trip — see the
	// matching dispatch in NotifPluginDelegate.didReceive…
	NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
	Array keys = payload.keys();
	for (int i = 0; i < keys.size(); i++) {
		const Variant &k = keys[i];
		if (k.get_type() != Variant::STRING) {
			continue;
		}
		String key_str = (String)k;
		const Variant &v = payload[k];
		NSString *nsKey = [NSString stringWithUTF8String:key_str.utf8().get_data()];
		switch (v.get_type()) {
			case Variant::STRING: {
				String s = (String)v;
				userInfo[nsKey] = [NSString stringWithUTF8String:s.utf8().get_data()];
			} break;
			case Variant::INT: {
				userInfo[nsKey] = @((int64_t)v);
			} break;
			case Variant::FLOAT: {
				userInfo[nsKey] = @((double)v);
			} break;
			case Variant::BOOL: {
				userInfo[nsKey] = @((bool)v);
			} break;
			default:
				break;
		}
	}
	content.userInfo = userInfo;

	// Calendar trigger over time-interval so the OS survives reboots — the
	// fire time is anchored to a wall-clock moment, not to "X seconds from
	// now". Components below seconds are stripped per the planner's design.
	NSDate *date = [NSDate dateWithTimeIntervalSince1970:(NSTimeInterval)fire_at];
	NSCalendar *cal = [NSCalendar currentCalendar];
	NSDateComponents *comps = [cal components:(NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay
			| NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond)
			fromDate:date];
	UNCalendarNotificationTrigger *trigger = [UNCalendarNotificationTrigger triggerWithDateMatchingComponents:comps repeats:NO];

	UNNotificationRequest *request = [UNNotificationRequest requestWithIdentifier:idStr
			content:content
			trigger:trigger];
	[[UNUserNotificationCenter currentNotificationCenter] addNotificationRequest:request
			withCompletionHandler:^(NSError * _Nullable error) {
		if (error != nil) {
			NSLog(@"[NotifPluginIOS] schedule error: %@", error);
		}
	}];
}

void NotifPluginIOS::cancel(const String &id) {
	NSString *idStr = [NSString stringWithUTF8String:id.utf8().get_data()];
	[[UNUserNotificationCenter currentNotificationCenter] removePendingNotificationRequestsWithIdentifiers:@[idStr]];
}

void NotifPluginIOS::cancel_category(const String &prefix) {
	NSString *prefixStr = [NSString stringWithUTF8String:prefix.utf8().get_data()];
	[[UNUserNotificationCenter currentNotificationCenter] getPendingNotificationRequestsWithCompletionHandler:^(NSArray<UNNotificationRequest *> *requests) {
		NSMutableArray<NSString *> *to_remove = [NSMutableArray array];
		for (UNNotificationRequest *r in requests) {
			if ([r.identifier hasPrefix:prefixStr]) {
				[to_remove addObject:r.identifier];
			}
		}
		if (to_remove.count > 0) {
			[[UNUserNotificationCenter currentNotificationCenter] removePendingNotificationRequestsWithIdentifiers:to_remove];
		}
	}];
}

void NotifPluginIOS::cancel_all() {
	[[UNUserNotificationCenter currentNotificationCenter] removeAllPendingNotificationRequests];
}

Array NotifPluginIOS::list_pending() {
	// Sync wrap of an async query — UNUserNotificationCenter only exposes
	// the request list via callback. A 1s wait is plenty in practice; if it
	// times out we just return whatever's been filled in so far (empty).
	__block Array result;
	dispatch_semaphore_t sem = dispatch_semaphore_create(0);
	[[UNUserNotificationCenter currentNotificationCenter] getPendingNotificationRequestsWithCompletionHandler:^(NSArray<UNNotificationRequest *> *requests) {
		for (UNNotificationRequest *r in requests) {
			Dictionary row;
			row["id"] = String::utf8([r.identifier UTF8String]);
			row["title"] = String::utf8([r.content.title UTF8String]);
			row["body"] = String::utf8([r.content.body UTF8String]);
			int64_t fire_at = 0;
			if ([r.trigger isKindOfClass:[UNCalendarNotificationTrigger class]]) {
				UNCalendarNotificationTrigger *t = (UNCalendarNotificationTrigger *)r.trigger;
				NSDate *next = [t nextTriggerDate];
				if (next) {
					fire_at = (int64_t)[next timeIntervalSince1970];
				}
			}
			row["fire_at"] = fire_at;
			result.append(row);
		}
		dispatch_semaphore_signal(sem);
	}];
	dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * 1));
	return result;
}

void NotifPluginIOS::on_tap(const String &id, const Dictionary &payload) {
	Dictionary tap;
	tap["id"] = id;
	tap["payload"] = payload;
	pending_taps.append(tap);
	emit_signal("tap_buffered");
}

Array NotifPluginIOS::drain_pending_taps() {
	Array out = pending_taps;
	pending_taps.clear();
	return out;
}

// ─── Engine registration ─────────────────────────────────────────────────────

void register_notif_plugin() {
	ClassDB::register_class<NotifPluginIOS>();
	NotifPluginIOS *plugin = memnew(NotifPluginIOS);
	Engine::get_singleton()->add_singleton(Engine::Singleton("NotifPluginIOS", plugin));
}

void unregister_notif_plugin() {
	NotifPluginIOS *plugin = NotifPluginIOS::get_singleton();
	if (plugin) {
		Engine::get_singleton()->remove_singleton("NotifPluginIOS");
		memdelete(plugin);
	}
}
