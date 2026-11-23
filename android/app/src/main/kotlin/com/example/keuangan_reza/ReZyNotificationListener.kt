package com.example.keuangan_reza

import android.app.Notification
import android.content.ComponentName
import android.content.Context
import android.provider.Settings
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import org.json.JSONArray
import org.json.JSONObject

class ReZyNotificationListener : NotificationListenerService() {

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        if (sbn == null) return
        val pkg = sbn.packageName ?: return
        if (!ALLOWED_PACKAGES.contains(pkg)) return

        val extras = sbn.notification?.extras ?: return
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString()?.trim().orEmpty()
        // Prefer EXTRA_BIG_TEXT because banking/e-wallet apps often truncate EXTRA_TEXT.
        val bigText = extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString()?.trim().orEmpty()
        val shortText = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString()?.trim().orEmpty()
        val body = if (bigText.isNotEmpty()) bigText else shortText
        if (title.isEmpty() && body.isEmpty()) return

        enqueueAndDispatch(
            context = applicationContext,
            packageName = pkg,
            title = title,
            text = body,
            postedAt = sbn.postTime,
        )
    }

    companion object {
        private const val PREF_NAME = "rezylife_notif_queue"
        private const val KEY_ITEMS = "pending_items"
        private const val MAX_QUEUE = 100

        private val ALLOWED_PACKAGES = setOf(
            "id.co.bri.brimo",
            "com.gojek.app",
            "com.gopay.app",
            "com.gojek.gopay",
            "id.dana",
            "com.shopee.id",
            "com.shopeepay.id",
        )

        @Volatile
        var liveCallback: ((Map<String, Any>) -> Unit)? = null

        fun isAccessEnabled(context: Context): Boolean {
            val enabled = Settings.Secure.getString(
                context.contentResolver,
                "enabled_notification_listeners",
            ) ?: return false
            val expected = ComponentName(context, ReZyNotificationListener::class.java).flattenToString()
            return enabled.split(':').any { it.equals(expected, ignoreCase = true) }
        }

        @Synchronized
        fun enqueueAndDispatch(
            context: Context,
            packageName: String,
            title: String,
            text: String,
            postedAt: Long,
        ) {
            val payload = mapOf<String, Any>(
                "packageName" to packageName,
                "title" to title,
                "text" to text,
                "postedAt" to postedAt,
            )

            // Always persist first so background/killed-app notifications are never lost.
            val prefs = context.getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE)
            val existingRaw = prefs.getString(KEY_ITEMS, "[]") ?: "[]"
            val arr = try {
                JSONArray(existingRaw)
            } catch (_: Exception) {
                JSONArray()
            }

            val obj = JSONObject().apply {
                put("packageName", packageName)
                put("title", title)
                put("text", text)
                put("postedAt", postedAt)
            }
            arr.put(obj)

            // Keep queue bounded.
            val trimmed = if (arr.length() > MAX_QUEUE) {
                JSONArray().apply {
                    for (i in (arr.length() - MAX_QUEUE) until arr.length()) {
                        put(arr.get(i))
                    }
                }
            } else {
                arr
            }
            prefs.edit().putString(KEY_ITEMS, trimmed.toString()).apply()

            liveCallback?.invoke(payload)
        }

        @Synchronized
        fun drainPending(context: Context): List<Map<String, Any>> {
            val prefs = context.getSharedPreferences(PREF_NAME, Context.MODE_PRIVATE)
            val raw = prefs.getString(KEY_ITEMS, "[]") ?: "[]"
            if (raw == "[]") return emptyList()

            val result = mutableListOf<Map<String, Any>>()
            try {
                val arr = JSONArray(raw)
                for (i in 0 until arr.length()) {
                    val obj = arr.optJSONObject(i) ?: continue
                    result.add(
                        mapOf(
                            "packageName" to obj.optString("packageName", ""),
                            "title" to obj.optString("title", ""),
                            "text" to obj.optString("text", ""),
                            "postedAt" to obj.optLong("postedAt", System.currentTimeMillis()),
                        ),
                    )
                }
            } catch (_: Exception) {
                // Ignore malformed cache and reset cleanly.
            }
            prefs.edit().putString(KEY_ITEMS, "[]").apply()
            return result
        }
    }
}
