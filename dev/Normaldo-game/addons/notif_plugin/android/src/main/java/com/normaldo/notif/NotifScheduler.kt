package com.normaldo.notif

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import org.json.JSONObject

/**
 * Stateless scheduling core shared by [NotifPluginAndroid] (schedule/cancel
 * from the game) and [NotifAlarmReceiver] (post on alarm, re-arm on boot).
 *
 * Centralised on purpose: the alarm [PendingIntent] must be byte-for-byte
 * identical between arming and cancelling, otherwise `cancel()` silently fails
 * to match. Keeping one builder here guarantees that.
 */
object NotifScheduler {

    const val CHANNEL_ID = "normaldo_default"
    const val CHANNEL_NAME = "Normaldo"
    const val PREFS = "normaldo_notifs"
    // Separate store for the FCM token — must NOT live in PREFS, whose keys are
    // iterated as notification ids by cancelAll/rearmAll.
    const val PUSH_PREFS = "normaldo_push"

    fun saveFcmToken(ctx: Context, token: String) {
        ctx.getSharedPreferences(PUSH_PREFS, Context.MODE_PRIVATE)
            .edit().putString("fcm_token", token).apply()
    }

    fun fcmToken(ctx: Context): String =
        ctx.getSharedPreferences(PUSH_PREFS, Context.MODE_PRIVATE)
            .getString("fcm_token", "") ?: ""

    const val EXTRA_ID = "notif_id"
    const val EXTRA_TITLE = "notif_title"
    const val EXTRA_BODY = "notif_body"
    const val EXTRA_PAYLOAD = "notif_payload" // JSON string

    fun prefs(ctx: Context) = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun ensureChannel(ctx: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val mgr = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (mgr.getNotificationChannel(CHANNEL_ID) == null) {
            mgr.createNotificationChannel(
                NotificationChannel(CHANNEL_ID, CHANNEL_NAME, NotificationManager.IMPORTANCE_HIGH)
            )
        }
    }

    /** Persists the row and arms the OS alarm. `fireAtSecs` is unix seconds. */
    fun schedule(ctx: Context, id: String, fireAtSecs: Long, title: String, body: String, payloadJson: String) {
        ensureChannel(ctx)
        val row = JSONObject().apply {
            put("fire_at", fireAtSecs)
            put("title", title)
            put("body", body)
            put("payload", payloadJson)
        }
        prefs(ctx).edit().putString(id, row.toString()).apply()
        arm(ctx, id, fireAtSecs, title, body, payloadJson)
    }

    fun cancel(ctx: Context, id: String) {
        disarm(ctx, id)
        prefs(ctx).edit().remove(id).apply()
    }

    fun cancelCategory(ctx: Context, prefix: String) {
        val p = prefs(ctx)
        val editor = p.edit()
        for (key in p.all.keys.toList()) {
            if (key.startsWith(prefix)) {
                disarm(ctx, key)
                editor.remove(key)
            }
        }
        editor.apply()
    }

    fun cancelAll(ctx: Context) {
        val p = prefs(ctx)
        for (key in p.all.keys.toList()) disarm(ctx, key)
        p.edit().clear().apply()
    }

    /** Re-arm every still-future row after a reboot (BOOT_COMPLETED). Past-due
     *  rows are dropped — a stale nudge fired hours late is noise. */
    fun rearmAll(ctx: Context) {
        val p = prefs(ctx)
        val nowSecs = System.currentTimeMillis() / 1000L
        val editor = p.edit()
        for ((id, raw) in p.all) {
            try {
                val row = JSONObject(raw as String)
                val fireAt = row.getLong("fire_at")
                if (fireAt <= nowSecs) {
                    editor.remove(id)
                } else {
                    arm(ctx, id, fireAt, row.getString("title"), row.getString("body"), row.getString("payload"))
                }
            } catch (_: Exception) {
                editor.remove(id)
            }
        }
        editor.apply()
    }

    /** Build + post the notification (called from the receiver at fire time)
     *  and clear the now-spent row from prefs. */
    fun postNotification(ctx: Context, id: String, title: String, body: String, payloadJson: String) {
        ensureChannel(ctx)
        val notif: Notification = NotificationCompat.Builder(ctx, CHANNEL_ID)
            .setSmallIcon(ctx.applicationInfo.icon)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setContentIntent(launchPendingIntent(ctx, id, payloadJson))
            .build()
        // areNotificationsEnabled() guards against posting when the user denied
        // POST_NOTIFICATIONS (33+) — notify() would no-op + log otherwise.
        if (NotificationManagerCompat.from(ctx).areNotificationsEnabled()) {
            NotificationManagerCompat.from(ctx).notify(id.hashCode(), notif)
        }
        prefs(ctx).edit().remove(id).apply()
    }

    // ── PendingIntents ────────────────────────────────────────────────────────

    private fun arm(ctx: Context, id: String, fireAtSecs: Long, title: String, body: String, payloadJson: String) {
        val am = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pi = alarmPendingIntent(ctx, id, title, body, payloadJson)
        val triggerAtMs = fireAtSecs * 1000L
        // Exact alarms for iOS parity; degrade to inexact-idle if the OS
        // withholds SCHEDULE_EXACT_ALARM (API 31+) so delivery still happens.
        val canExact = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) am.canScheduleExactAlarms() else true
        if (canExact) {
            am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMs, pi)
        } else {
            am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMs, pi)
        }
    }

    private fun disarm(ctx: Context, id: String) {
        val am = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        am.cancel(alarmPendingIntent(ctx, id, "", "", "{}"))
    }

    private fun alarmPendingIntent(ctx: Context, id: String, title: String, body: String, payloadJson: String): PendingIntent {
        val intent = Intent(ctx, NotifAlarmReceiver::class.java).apply {
            action = NotifAlarmReceiver.ACTION_FIRE
            // Distinct data per id so PendingIntents stay individually addressable.
            data = Uri.parse("normaldo://notif/$id")
            putExtra(EXTRA_ID, id)
            putExtra(EXTRA_TITLE, title)
            putExtra(EXTRA_BODY, body)
            putExtra(EXTRA_PAYLOAD, payloadJson)
        }
        return PendingIntent.getBroadcast(ctx, id.hashCode(), intent, mutabilityFlags(PendingIntent.FLAG_UPDATE_CURRENT))
    }

    /** Launch intent for a tap: reopens the app's launcher activity carrying the
     *  notif id + payload so the plugin can buffer a tap on resume. */
    private fun launchPendingIntent(ctx: Context, id: String, payloadJson: String): PendingIntent {
        val launch = ctx.packageManager.getLaunchIntentForPackage(ctx.packageName)?.apply {
            addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
            putExtra(EXTRA_ID, id)
            putExtra(EXTRA_PAYLOAD, payloadJson)
        } ?: Intent()
        return PendingIntent.getActivity(ctx, ("tap_$id").hashCode(), launch, mutabilityFlags(PendingIntent.FLAG_UPDATE_CURRENT))
    }

    private fun mutabilityFlags(base: Int): Int {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) base or PendingIntent.FLAG_IMMUTABLE else base
    }
}
