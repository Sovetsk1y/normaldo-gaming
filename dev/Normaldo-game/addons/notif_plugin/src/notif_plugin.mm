/**************************************************************************/
/*  notif_plugin.mm                                                       */
/*                                                                        */
/*  ObjC++ implementation of the NotifPluginIOS GDExtension class. See    */
/*  notif_plugin.h for the public API and notif_plugin_gdext.cpp for the  */
/*  singleton lifecycle.                                                  */
/**************************************************************************/

#import "notif_plugin.h"

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <UserNotifications/UserNotifications.h>
#import <objc/runtime.h>

#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/error_macros.hpp>
#include <godot_cpp/variant/variant.hpp>

using namespace godot;

// ─── ObjC delegate ───────────────────────────────────────────────────────────
// Forwards UNUserNotificationCenter callbacks into the C++ singleton.

@interface NotifPluginDelegate : NSObject <UNUserNotificationCenterDelegate>
@end

@implementation NotifPluginDelegate

// Foreground presentation — banner + sound when the app is open, matching
// iOS 14+ defaults so a tap-worthy ping is still noticeable.
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

// ─── APNs token capture via app-delegate swizzling ───────────────────────────
// GDExtension gets no UIApplicationDelegate forwarding, so to receive the APNs
// device token we install our own implementation of
// application:didRegisterForRemoteNotificationsWithDeviceToken: onto the live
// app-delegate's class (chaining to any original). This is the same mechanism
// Firebase's iOS SDK uses. Only the token path is swizzled — display + taps of
// the resulting alert pushes already flow through NotifPluginDelegate above.

typedef void (*DidRegisterIMP)(id, SEL, UIApplication *, NSData *);
typedef void (*DidFailIMP)(id, SEL, UIApplication *, NSError *);
static DidRegisterIMP s_orig_did_register = nullptr;
static DidFailIMP s_orig_did_fail = nullptr;

static void normaldo_did_register_apns(id self_, SEL _cmd, UIApplication *app, NSData *deviceToken) {
	const unsigned char *bytes = (const unsigned char *)deviceToken.bytes;
	NSMutableString *hex = [NSMutableString stringWithCapacity:deviceToken.length * 2];
	for (NSUInteger i = 0; i < deviceToken.length; i++) {
		[hex appendFormat:@"%02x", bytes[i]];
	}
	String tok = String::utf8([hex UTF8String]);
	dispatch_async(dispatch_get_main_queue(), ^{
		if (NotifPluginIOS::get_singleton()) {
			NotifPluginIOS::get_singleton()->on_push_token(tok);
		}
	});
	if (s_orig_did_register) {
		s_orig_did_register(self_, _cmd, app, deviceToken);
	}
}

static void normaldo_did_fail_apns(id self_, SEL _cmd, UIApplication *app, NSError *error) {
	NSLog(@"[NotifPluginIOS] APNs registration failed: %@", error);
	if (s_orig_did_fail) {
		s_orig_did_fail(self_, _cmd, app, error);
	}
}

static void normaldo_install_apns_swizzle() {
	id<UIApplicationDelegate> appDelegate = [UIApplication sharedApplication].delegate;
	if (appDelegate == nil) {
		return;
	}
	Class cls = object_getClass(appDelegate);

	SEL regSel = @selector(application:didRegisterForRemoteNotificationsWithDeviceToken:);
	Method regExisting = class_getInstanceMethod(cls, regSel);
	if (regExisting != NULL) {
		s_orig_did_register = (DidRegisterIMP)method_getImplementation(regExisting);
		method_setImplementation(regExisting, (IMP)normaldo_did_register_apns);
	} else {
		class_addMethod(cls, regSel, (IMP)normaldo_did_register_apns, "v@:@@");
	}

	SEL failSel = @selector(application:didFailToRegisterForRemoteNotificationsWithError:);
	Method failExisting = class_getInstanceMethod(cls, failSel);
	if (failExisting != NULL) {
		s_orig_did_fail = (DidFailIMP)method_getImplementation(failExisting);
		method_setImplementation(failExisting, (IMP)normaldo_did_fail_apns);
	} else {
		class_addMethod(cls, failSel, (IMP)normaldo_did_fail_apns, "v@:@@");
	}
}

static void normaldo_register_for_remote() {
	dispatch_async(dispatch_get_main_queue(), ^{
		[[UIApplication sharedApplication] registerForRemoteNotifications];
	});
}

// ─── C++ singleton ───────────────────────────────────────────────────────────

namespace godot {

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
	ClassDB::bind_method(D_METHOD("get_push_token"), &NotifPluginIOS::get_push_token);

	ADD_SIGNAL(MethodInfo("permission_changed", PropertyInfo(Variant::BOOL, "granted")));
	ADD_SIGNAL(MethodInfo("tap_buffered"));
	ADD_SIGNAL(MethodInfo("push_token", PropertyInfo(Variant::STRING, "token")));
}

NotifPluginIOS::NotifPluginIOS() {
	ERR_FAIL_COND(instance != nullptr);
	instance = this;

	NotifPluginDelegate *delegate = [[NotifPluginDelegate alloc] init];
	[UNUserNotificationCenter currentNotificationCenter].delegate = delegate;
	delegate_objc = (__bridge_retained void *)delegate;

	// Hook the app delegate so the APNs device token reaches us.
	normaldo_install_apns_swizzle();

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
		// Already authorised from a previous launch — re-register for remote
		// notifications so iOS re-issues the APNs token (it can rotate).
		if (granted) {
			normaldo_register_for_remote();
		}
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
	// Permission just granted → register with APNs so the swizzled callback
	// delivers the device token.
	if (granted) {
		normaldo_register_for_remote();
	}
}

String NotifPluginIOS::get_push_token() const {
	return push_token;
}

void NotifPluginIOS::on_push_token(const String &token) {
	push_token = token;
	emit_signal("push_token", token);
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
	// back. Only String / int / float / bool survive the round-trip — see
	// the matching dispatch in NotifPluginDelegate.didReceive…
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

	// Calendar trigger so the OS survives reboots — the fire time is
	// anchored to a wall-clock moment, not "X seconds from now".
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
	// the request list via callback. A 1s wait is plenty in practice; on
	// timeout we just return whatever's been filled in so far.
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

} // namespace godot
