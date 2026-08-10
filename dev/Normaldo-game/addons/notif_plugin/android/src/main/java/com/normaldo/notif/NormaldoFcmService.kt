package com.normaldo.notif

import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import org.json.JSONObject

/**
 * Receives FCM messages. The server sends **data-only** payloads (no
 * `notification` block) so this fires even when the app is backgrounded, and we
 * build the notification ourselves through [NotifScheduler] — same display +
 * deep-link path as a local notification.
 *
 * Registered in the plugin manifest. Runs in its own process lifecycle, so it
 * talks to the plugin only through persisted state (the FCM token) and the
 * shared scheduler.
 */
class NormaldoFcmService : FirebaseMessagingService() {

    override fun onNewToken(token: String) {
        // The plugin reads this back via NotifScheduler.fcmToken() and surfaces
        // it to GDScript (which registers it server-side).
        NotifScheduler.saveFcmToken(applicationContext, token)
    }

    override fun onMessageReceived(message: RemoteMessage) {
        val d = message.data
        val id = d["id"] ?: "remote_${System.currentTimeMillis()}"
        val title = d["title"] ?: "Normaldo"
        val body = d["body"] ?: ""
        // Everything except the reserved display keys becomes the tap payload
        // (deep_link, category, …).
        val payload = JSONObject()
        for ((k, v) in d) {
            if (k != "id" && k != "title" && k != "body") payload.put(k, v)
        }
        NotifScheduler.postNotification(applicationContext, id, title, body, payload.toString())
    }
}
