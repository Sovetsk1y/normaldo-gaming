# NotifPluginAndroid — Android local-notification backend

Kotlin **Godot 4 Android plugin** that mirrors the iOS `NotifPluginIOS`
GDExtension so the `Notifications` GDScript autoload stays backend-agnostic.

## Why a Godot Android plugin and not a GDExtension

iOS schedules a notification with the OS in one synchronous call and the OS
delivers it later — the app need not be running. Android has no such handoff: a
scheduled notification fires via `AlarmManager`, which wakes a
**manifest-declared `BroadcastReceiver`** that the OS instantiates *by class
name from the APK*. A GDExtension `.so` is loaded only inside a live Godot
process, so when the app is killed there is nothing to run — it can never be
that receiver. Hence the Android backend is Java/Kotlin compiled into the APK
(`NotifAlarmReceiver`), which requires a Godot Android plugin + custom gradle
build. iOS stays a GDExtension; only Android diverges.

## Layout
- `src/main/java/com/normaldo/notif/NotifPluginAndroid.kt` — `GodotPlugin`
  subclass; the GDScript bridge (permission, signals, tap buffering). Plugin
  name `NotifPluginAndroid` doubles as the engine-singleton name.
- `NotifScheduler.kt` — stateless scheduling core (AlarmManager exact alarms,
  `SharedPreferences` id↔row table, notification building). Shared by the plugin
  and the receiver so the alarm `PendingIntent` is identical on arm/cancel.
- `NotifAlarmReceiver.kt` — posts the notification on alarm; re-arms future rows
  on `BOOT_COMPLETED`.
- `src/main/AndroidManifest.xml` — permissions, the receiver, and the
  `org.godotengine.plugin.v2.NotifPluginAndroid` meta-data that registers the
  plugin with the runtime.

## Contract (matches iOS)
`has_permission()`, `request_permission()`,
`schedule(id, fire_at, title, body, payload)`, `cancel(id)`,
`cancel_category(prefix)`, `cancel_all()`, `drain_pending_taps()`,
`get_push_token()`; signals `tap_buffered`, `permission_changed(granted)`,
`push_token(token)`. `fire_at` is unix seconds; payload round-trips
String/int/float/bool.

## Remote push (FCM)
`NormaldoFcmService` (FirebaseMessagingService) receives **data-only** FCM
messages and builds the notification via `NotifScheduler` (same display +
deep-link path as local). `FirebaseApp` is initialised programmatically from
constants in `NotifPluginAndroid.kt` — set `FIREBASE_APP_ID` + `FIREBASE_SENDER_ID`
(from the project's google-services.json) to enable it; until then FCM is inert
and local notifications work unaffected. firebase-messaging is `compileOnly` here
and pulled at runtime via the `.gdap` remote dependency.

## Build
```
JAVA_HOME=$(/usr/libexec/java_home -v 17) ./build.sh        # release AAR
```
Produces `build/outputs/aar/notif_plugin_android-release.aar` and copies it to
`res://android/plugins/NotifPluginAndroid.aar` next to its `.gdap`. The gradle
wrapper (8.2, from the Godot 4.2.2 android template) downloads gradle on first
run; no system gradle needed. SDK path is auto-written to `local.properties`
from `ANDROID_HOME` / `~/Library/Android/sdk`.

Versions track the Godot 4.2.2 template: AGP 8.2.0 · compileSdk 34 · minSdk 21 ·
Kotlin 1.9.20 · JDK 17. The `org.godotengine:godot:4.2.2.stable` dependency is
`compileOnly` (already in the host APK).

## Export
Custom gradle build must be enabled (`gradle_build/use_gradle_build=true`) and
the plugin enabled (`plugins/NotifPluginAndroid=true`) in the Android export
preset — both already set in `export_presets.cfg`. Requires the project's
Android build template installed (Project → Install Android Build Template).
