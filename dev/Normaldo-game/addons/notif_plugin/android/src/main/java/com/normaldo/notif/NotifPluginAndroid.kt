package com.normaldo.notif

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import com.google.firebase.FirebaseApp
import com.google.firebase.FirebaseOptions
import com.google.firebase.messaging.FirebaseMessaging
import org.godotengine.godot.Dictionary
import org.godotengine.godot.Godot
import org.godotengine.godot.plugin.GodotPlugin
import org.godotengine.godot.plugin.SignalInfo
import org.godotengine.godot.plugin.UsedByGodot
import org.json.JSONObject

/**
 * Android local-notification backend. Mirrors the iOS `NotifPluginIOS`
 * GDExtension method/signal contract so the `Notifications` GDScript autoload
 * stays backend-agnostic.
 *
 * Why a Godot Android plugin (Kotlin) and not a GDExtension `.so`: a scheduled
 * notification has to fire when the game process is dead. Android delivers that
 * via AlarmManager → a manifest-declared BroadcastReceiver ([NotifAlarmReceiver]);
 * the OS instantiates that receiver by class name from the APK manifest, which a
 * GDExtension `.so` (loaded only inside a live Godot process) can never be.
 * See addons/notif_plugin/android/README.md.
 *
 * The plugin name doubles as the engine-singleton name, so GDScript reaches it
 * through `Engine.get_singleton("NotifPluginAndroid")`. All scheduling work is
 * delegated to [NotifScheduler]; this class only owns the GDScript bridge
 * (permission, signals, tap buffering).
 */
class NotifPluginAndroid(godot: Godot) : GodotPlugin(godot) {

    companion object {
        const val SIGNAL_TAP = "tap_buffered"
        const val SIGNAL_PERMISSION = "permission_changed"
        const val SIGNAL_PUSH_TOKEN = "push_token"
        private const val REQ_POST_NOTIFICATIONS = 0x4E0F

        // FCM/FirebaseApp config — initialised programmatically so the project
        // needs no google-services gradle plugin or google-services.json baked
        // into the Godot Android build. apiKey/projectId match leaderboard_client.gd;
        // appId + senderId come from the Firebase Android app registration
        // (google-services.json: `mobilesdk_app_id` and `project_number`).
        private const val FIREBASE_API_KEY    = "AIzaSyDceNn25Gc21B40bIxK4Q4El-rGjpFyQVc"
        private const val FIREBASE_PROJECT_ID = "normaldo-game"
        // FCM intentionally DISABLED for the untested open-test release: empty
        // appId/senderId make initFirebase() a no-op (no token, no service),
        // local notifications keep working. To re-enable, restore these values:
        //   FIREBASE_APP_ID    = "1:264104354816:android:a422534b76cfb55bf8a4e5"
        //   FIREBASE_SENDER_ID = "264104354816"
        // then rebuild the AAR (./build.sh).
        private const val FIREBASE_APP_ID     = ""
        private const val FIREBASE_SENDER_ID  = ""
    }

    // Cold-start / warm taps parked here until GDScript drains them.
    private val pendingTaps = ArrayList<Dictionary>()
    private val seenIntents = HashSet<Int>()
    private var lastEmittedToken = ""

    override fun getPluginName(): String = "NotifPluginAndroid"

    override fun getPluginSignals(): MutableSet<SignalInfo> = mutableSetOf(
        SignalInfo(SIGNAL_TAP),
        SignalInfo(SIGNAL_PERMISSION, Boolean::class.javaObjectType),
        SignalInfo(SIGNAL_PUSH_TOKEN, String::class.java),
    )

    override fun onGodotMainLoopStarted() {
        val ctx = activity ?: return
        NotifScheduler.ensureChannel(ctx)
        captureLaunchTap()
        initFirebase(ctx)
        fetchPushToken(ctx)
    }

    override fun onMainResume() {
        captureLaunchTap()
        // FirebaseMessagingService.onNewToken may have refreshed the token while
        // backgrounded; re-emit if it changed.
        activity?.let { emitTokenIfChanged(NotifScheduler.fcmToken(it)) }
    }

    // ── Remote push (FCM) ─────────────────────────────────────────────────────

    @UsedByGodot
    fun get_push_token(): String = activity?.let { NotifScheduler.fcmToken(it) } ?: ""

    private fun initFirebase(ctx: Context) {
        if (FirebaseApp.getApps(ctx).isNotEmpty()) return
        if (FIREBASE_APP_ID.isEmpty() || FIREBASE_SENDER_ID.isEmpty()) return // not configured yet
        val opts = FirebaseOptions.Builder()
            .setApiKey(FIREBASE_API_KEY)
            .setApplicationId(FIREBASE_APP_ID)
            .setProjectId(FIREBASE_PROJECT_ID)
            .setGcmSenderId(FIREBASE_SENDER_ID)
            .build()
        FirebaseApp.initializeApp(ctx, opts)
    }

    private fun fetchPushToken(ctx: Context) {
        if (FirebaseApp.getApps(ctx).isEmpty()) return
        FirebaseMessaging.getInstance().token.addOnCompleteListener { task ->
            if (task.isSuccessful) {
                val token = task.result ?: return@addOnCompleteListener
                NotifScheduler.saveFcmToken(ctx, token)
                emitTokenIfChanged(token)
            }
        }
    }

    private fun emitTokenIfChanged(token: String) {
        if (token.isNotEmpty() && token != lastEmittedToken) {
            lastEmittedToken = token
            emitSignal(SIGNAL_PUSH_TOKEN, token)
        }
    }

    // ── Permission ──────────────────────────────────────────────────────────

    @UsedByGodot
    fun has_permission(): Boolean {
        val ctx = activity ?: return false
        return NotificationManagerCompat.from(ctx).areNotificationsEnabled()
    }

    @UsedByGodot
    fun request_permission() {
        val act = activity ?: return
        // POST_NOTIFICATIONS is a runtime permission only on API 33+. Below that,
        // notifications are allowed by default and we just confirm state.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            ContextCompat.checkSelfPermission(act, Manifest.permission.POST_NOTIFICATIONS)
            != PackageManager.PERMISSION_GRANTED
        ) {
            ActivityCompat.requestPermissions(
                act, arrayOf(Manifest.permission.POST_NOTIFICATIONS), REQ_POST_NOTIFICATIONS
            )
        } else {
            emitSignal(SIGNAL_PERMISSION, has_permission())
        }
    }

    override fun onMainRequestPermissionsResult(
        requestCode: Int, permissions: Array<String?>?, grantResults: IntArray?
    ) {
        if (requestCode == REQ_POST_NOTIFICATIONS) {
            val granted = grantResults?.firstOrNull() == PackageManager.PERMISSION_GRANTED
            emitSignal(SIGNAL_PERMISSION, granted)
        }
    }

    // ── Scheduling (delegated to NotifScheduler) ──────────────────────────────

    /** `fire_at` is unix seconds; payload round-trips String/int/float/bool. */
    @UsedByGodot
    fun schedule(id: String, fire_at: Int, title: String, body: String, payload: Dictionary) {
        val ctx = activity ?: return
        NotifScheduler.schedule(ctx, id, fire_at.toLong(), title, body, payloadToJson(payload))
    }

    @UsedByGodot
    fun cancel(id: String) {
        activity?.let { NotifScheduler.cancel(it, id) }
    }

    @UsedByGodot
    fun cancel_category(prefix: String) {
        activity?.let { NotifScheduler.cancelCategory(it, prefix) }
    }

    @UsedByGodot
    fun cancel_all() {
        activity?.let { NotifScheduler.cancelAll(it) }
    }

    // ── Taps ──────────────────────────────────────────────────────────────────

    @UsedByGodot
    fun drain_pending_taps(): Array<Dictionary> {
        val out = pendingTaps.toTypedArray()
        pendingTaps.clear()
        return out
    }

    private fun captureLaunchTap() {
        val act = activity ?: return
        val intent = act.intent ?: return
        val id = intent.getStringExtra(NotifScheduler.EXTRA_ID) ?: return
        // Guard against re-reading the same intent on every resume.
        val token = System.identityHashCode(intent)
        if (id.isEmpty() || seenIntents.contains(token)) return
        seenIntents.add(token)
        val payloadJson = intent.getStringExtra(NotifScheduler.EXTRA_PAYLOAD) ?: "{}"
        val tap = Dictionary()
        tap["id"] = id
        tap["payload"] = jsonToDictionary(payloadJson)
        pendingTaps.add(tap)
        emitSignal(SIGNAL_TAP)
        // Clear so a later resume / drain doesn't double-fire the same tap.
        intent.removeExtra(NotifScheduler.EXTRA_ID)
    }

    // ── Payload marshalling ───────────────────────────────────────────────────

    private fun payloadToJson(payload: Dictionary): String {
        val obj = JSONObject()
        for ((k, v) in payload) {
            when (v) {
                is String, is Int, is Long, is Boolean, is Double, is Float -> obj.put(k, v)
                else -> {} // drop unsupported types, matching the iOS .mm filter
            }
        }
        return obj.toString()
    }

    private fun jsonToDictionary(json: String): Dictionary {
        val dict = Dictionary()
        try {
            val obj = JSONObject(json)
            for (key in obj.keys()) dict[key] = obj.get(key)
        } catch (_: Exception) {
        }
        return dict
    }
}
