# NotifPluginIOS — Xcode integration

Godot iOS Module Plugin that wires `UNUserNotificationCenter` to the
`Notifications` autoload. Concept: `Концепция/Пуш-уведомления.md`.

The plugin sits as ObjC++ source inside the existing Xcode-project export
(`ios_export/Normaldo.xcodeproj`). It does **not** ship as an .xcframework —
it links straight into the app target alongside `dummy.cpp`.

## One-time Xcode setup

1. **Add the source files to the target.**
   - Open `ios_export/Normaldo.xcodeproj`.
   - Drag the entire `notif_plugin/` folder onto the **Normaldo** group in the
     Project Navigator.
   - In the dialog: keep "Create groups" (not folder references), check the
     **Normaldo** target so both `notif_plugin.h` and `notif_plugin.mm` are
     added to *Compile Sources*.

2. **Point the compiler at Godot's headers.**
   - Select the **Normaldo** target → *Build Settings* → search for
     `Header Search Paths`.
   - Add an entry pointing to your Godot 4.2 source root, e.g.
     `/path/to/godot` (recursive **off**).
   - That makes `#include "core/object/object.h"` resolve.

3. **Link UserNotifications.framework.**
   - Target → *General* → *Frameworks, Libraries, and Embedded Content* →
     `+` → `UserNotifications.framework`. *Embed* is *Do Not Embed*.

4. **Verify ObjC ARC.**
   - The `.mm` uses bridged casts (`__bridge_retained`, `__bridge_transfer`)
     so ARC must be on. *Build Settings* → search `Objective-C Automatic
     Reference Counting` → must be **YES** for `notif_plugin.mm` (the
     target-wide default is fine).

## What `dummy.cpp` already does

`godot_ios_plugins_initialize()` (called once by libgodot at startup) now
delegates to `register_notif_plugin()`. The plugin self-registers with
`Engine::add_singleton("NotifPluginIOS", instance)`; from there GDScript
picks it up via `Engine.get_singleton("NotifPluginIOS")` (see
`scripts/notifications.gd::_ready`).

## Permissions & Info.plist

Local notifications need **no** Info.plist entry — Apple allows them without
declaration. Only **remote** push (future FCM) requires
`UIBackgroundModes:remote-notification` and the entitlement.

## Build & run

`Build` (⌘B) once. If headers resolve and UserNotifications links you're
done — first run will surface the system permission dialog the first time
the GDScript prompt fires (`_show_notif_permission_modal`).

## Sanity check on device

1. Launch the build, play a single run.
2. Settings → УВЕДОМЛЕНИЯ → tap *DEV · СИМУЛИРОВАТЬ КЛИК ПО БЛИЖАЙШЕМУ ПУШУ*.
3. Modal closes → app routes you to the deep-link target (Slots / Книга
   учителя / pending rewards). Same flow as a real OS tap will use.

For real-OS test: set `notif_quiet_start = notif_quiet_end = 0` in
`SaveData` (or use the settings UI to widen the window), let the app go to
background, lock the device, wait. The next eligible schedule fires.

## Cold-start verification

1. Schedule a tap-eligible notif (e.g. D1 — bump `slot_today` to false in
   SaveData and replan).
2. Background the app **and force-quit** from the app switcher.
3. Tap the notification banner when it arrives.
4. App relaunches, lands on main menu, then auto-opens the deep-link target.

If routing fires but the wrong screen opens, look for
`[Notifications] Unknown deep_link:` in the Xcode console — the route map
in `hud.gd::_route_deep_link_if_ready` is the source of truth.

## Future: Android

When the Android plugin lands, it'll register its own singleton (e.g.
`NotifPluginAndroid`) and `notifications.gd::_ready` should `or`-chain the
lookup. The signal contract (`tap_buffered` + `permission_changed`) and
method names (`schedule` / `cancel` / etc.) stay identical so the GDScript
side doesn't have to branch per platform.
