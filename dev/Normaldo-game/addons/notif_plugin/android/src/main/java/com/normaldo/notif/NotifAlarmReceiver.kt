package com.normaldo.notif

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * The component the OS invokes when a scheduled alarm fires or the device
 * reboots. Declared in the plugin manifest so Android can instantiate it by
 * class name even when the game process is dead — the whole reason the Android
 * backend can't be a GDExtension `.so`.
 */
class NotifAlarmReceiver : BroadcastReceiver() {

    companion object {
        const val ACTION_FIRE = "com.normaldo.notif.FIRE"
    }

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED -> {
                // Alarms don't survive a reboot — re-arm every future row.
                NotifScheduler.rearmAll(context)
            }
            else -> {
                val id = intent.getStringExtra(NotifScheduler.EXTRA_ID) ?: return
                val title = intent.getStringExtra(NotifScheduler.EXTRA_TITLE) ?: ""
                val body = intent.getStringExtra(NotifScheduler.EXTRA_BODY) ?: ""
                val payloadJson = intent.getStringExtra(NotifScheduler.EXTRA_PAYLOAD) ?: "{}"
                NotifScheduler.postNotification(context, id, title, body, payloadJson)
            }
        }
    }
}
