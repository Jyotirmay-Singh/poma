package dev.poma.poma

import android.Manifest
import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.database.sqlite.SQLiteDatabase
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.SystemClock
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject
import java.io.File

/** OS alarms wake a short native receiver. They never need a Dart engine. */
object PomaAlerts {
    private const val CHANNEL = "poma_timer_completion_v1"
    private const val OPEN = "dev.poma.poma.OPEN_TIMER"
    private const val PREFS = "poma_local_alerts"
    @Volatile private var channel: MethodChannel? = null
    private var alertDatabase: SQLiteDatabase? = null
    private var alertDatabasePath: String? = null

    fun bootCount(context: Context): Int? = try {
        Settings.Global.getInt(context.contentResolver, Settings.Global.BOOT_COUNT).takeIf { it >= 0 }
    } catch (_: Settings.SettingNotFoundException) { null }

    private fun prefs(context: Context) = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
    private fun manager(context: Context) = context.getSystemService(NotificationManager::class.java)
    private fun alarms(context: Context) = context.getSystemService(AlarmManager::class.java)
    private fun persist(context: Context, key: String, value: String) {
        check(prefs(context).edit().putString(key, value).commit()) { "Alert journal unavailable" }
    }

    fun attach(context: Context, messenger: BinaryMessenger) {
        channel = MethodChannel(messenger, "dev.poma.poma/local_alerts").also { bridge ->
            bridge.setMethodCallHandler { call, result ->
                // SQLite can wait for a sqflite transaction whose next response
                // needs Android's main looper. Never hold that looper here.
                AlertWorkQueue.execute {
                try {
                    when (call.method) {
                        "configure" -> {
                            val path = requireNotNull(call.argument<String>("databasePath"))
                            require(File(path).canonicalPath.startsWith(File(context.applicationInfo.dataDir).canonicalPath + File.separator))
                            persist(context, "database", path)
                            // Open once before Dart starts optional summary reads.
                            // Reopening for every state/receipt read runs Android's
                            // journal configuration against concurrent transactions.
                            requireNotNull(database(context))
                            createChannel(context)
                            result.success(null)
                        }
                        "synchronize" -> result.success(synchronize(context,
                            JSONObject(requireNotNull(call.argument<String>("state"))),
                            call.argument<Boolean>("permitted") == true))
                        "responses" -> {
                            val queue = JSONObject(prefs(context).getString("responses", "{}")!!)
                            result.success(queue.keys().asSequence().map { key ->
                                val item = queue.getJSONObject(key)
                                mapOf("runId" to item.getString("runId"),
                                    "generation" to item.getLong("generation"), "action" to item.getString("action"))
                            }.toList())
                        }
                        "clearForReset" -> {
                            // SQLite's reset marker is committed before this idempotent cleanup.
                            val saved = requireNotNull(state(context))
                            check(saved.optJSONObject("current") == null)
                            synchronize(context, JSONObject().put("enabled", false))
                            manager(context).cancelAll()
                            persist(context, "responses", "{}")
                            persist(context, "registered", "[]")
                            result.success(null)
                        }
                        "acknowledgeResponse" -> {
                            val queue = JSONObject(prefs(context).getString("responses", "{}")!!)
                            queue.remove(call.argument<String>("key"))
                            persist(context, "responses", queue.toString())
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                } catch (_: Exception) {
                    result.error("local_alert_failed", "Completion alert could not be updated", null)
                }
                }
            }
        }
    }

    @Synchronized
    private fun database(context: Context): SQLiteDatabase? {
        val path = prefs(context).getString("database", null) ?: return null
        if (!File(path).exists()) return null // A receiver must never create/reset app data.
        alertDatabase?.let { cached ->
            if (cached.isOpen && alertDatabasePath == path) return cached
            cached.close()
        }
        return SQLiteDatabase.openDatabase(path, null, SQLiteDatabase.OPEN_READWRITE,
            android.database.DatabaseErrorHandler {
                // The platform's default corruption handler can delete the file.
                // Preserve it for Poma's explicit unreadable-data recovery path.
                throw android.database.sqlite.SQLiteDatabaseCorruptException("Unreadable alert database")
            }).also {
                alertDatabase = it
                alertDatabasePath = path
            }
    }

    private fun state(context: Context): JSONObject? = database(context)?.let { state(it) }
    private fun state(db: SQLiteDatabase): JSONObject? =
        db.rawQuery("SELECT value FROM notification_state WHERE id=1", null).use { cursor ->
            if (cursor.moveToFirst()) JSONObject(cursor.getString(0)) else null
        }

    private fun matches(request: JSONObject?, run: String, generation: Long): Boolean =
        request != null && AlertPolicy.matches(run, generation,
            request.getString("runId"), request.getLong("generation"))

    private fun remaining(context: Context, request: JSONObject): Long = AlertPolicy.remaining(
        bootCount(context), if (request.isNull("bootCount")) null else request.getInt("bootCount"),
        SystemClock.elapsedRealtimeNanos() / 1000L, request.getLong("elapsedDeadlineMicros"),
        System.currentTimeMillis() * 1000L, request.getLong("deadlineUtcMicros"),
        request.getLong("maximumRemainingMicros"))

    private fun alarmIntent(context: Context, request: JSONObject, create: Boolean): PendingIntent? {
        val intent = Intent(context, PomaAlarmReceiver::class.java)
            .setData(Uri.parse("poma-alert://completion/${request.getString("runId")}/${request.getLong("generation")}"))
            .putExtra("runId", request.getString("runId"))
            .putExtra("generation", request.getLong("generation"))
        return PendingIntent.getBroadcast(context, request.getInt("notificationId"), intent,
            PendingIntent.FLAG_IMMUTABLE or if (create) PendingIntent.FLAG_UPDATE_CURRENT else PendingIntent.FLAG_NO_CREATE)
    }

    private fun createChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= 26) {
            val value = NotificationChannel(CHANNEL, context.getString(R.string.alert_channel), NotificationManager.IMPORTANCE_DEFAULT)
            value.description = context.getString(R.string.alert_channel_description)
            value.setSound(RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION),
                AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_NOTIFICATION).build())
            // Existing channels preserve the person's sound/importance/DND choices.
            manager(context).createNotificationChannel(value)
        }
    }

    private fun permitted(context: Context): Boolean {
        if (Build.VERSION.SDK_INT >= 33 && context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS)
            != PackageManager.PERMISSION_GRANTED) return false
        if (!manager(context).areNotificationsEnabled()) return false
        return Build.VERSION.SDK_INT < 26 || manager(context).getNotificationChannel(CHANNEL)?.importance != NotificationManager.IMPORTANCE_NONE
    }

    private fun receipt(context: Context, key: String, claim: Boolean): Boolean = database(context)?.let { db ->
        if (!claim) {
            db.rawQuery("SELECT 1 FROM notification_receipts WHERE key=?", arrayOf(key)).use { it.moveToFirst() }
        } else {
            val values = android.content.ContentValues().apply {
                put("key", key); put("created_at", System.currentTimeMillis())
            }
            db.insertWithOnConflict("notification_receipts", null, values, SQLiteDatabase.CONFLICT_IGNORE) != -1L
        }
    } ?: false

    private fun deliveryKey(request: JSONObject) = "delivery:${request.getString("runId")}:${request.getLong("generation")}"

    @Synchronized
    fun synchronize(context: Context, desired: JSONObject, allowed: Boolean = true): String {
        createChannel(context)
        val current = desired.optJSONObject("current")
        val registered = JSONArray(prefs(context).getString("registered", "[]")!!)
        for (index in 0 until registered.length()) {
            val old = registered.getJSONObject(index)
            alarmIntent(context, old, false)?.let { alarms(context).cancel(it); it.cancel() }
            if (!matches(current, old.getString("runId"), old.getLong("generation"))) {
                manager(context).cancel(old.getInt("notificationId"))
            }
        }
        val retired = desired.optJSONArray("retiredIds") ?: JSONArray()
        for (index in 0 until retired.length()) {
            if (current?.optInt("notificationId") != retired.getInt(index)) manager(context).cancel(retired.getInt(index))
        }
        persist(context, "registered", "[]")
        if (!desired.optBoolean("enabled", true)) return "disabled"
        if (!allowed || !permitted(context)) {
            current?.let { manager(context).cancel(it.getInt("notificationId")) }
            return "denied"
        }
        if (current == null) return "ready"
        // Only committed outbox identities may be registered, even if Dart's
        // view was captured before an interrupted/failed save.
        val committed = state(context)?.optJSONObject("current")
        check(matches(committed, current.getString("runId"), current.getLong("generation")))
        if (remaining(context, current) <= 0 || receipt(context, deliveryKey(current), false)) return "ready"
        persist(context, "registered", JSONArray().put(current).toString()) // journal BEFORE OS call
        val pending = requireNotNull(alarmIntent(context, current, true))
        val at = SystemClock.elapsedRealtime() + (remaining(context, current).coerceAtLeast(1) + 999) / 1000
        val exact = Build.VERSION.SDK_INT < 31 || alarms(context).canScheduleExactAlarms()
        if (exact) {
            try {
                alarms(context).setExactAndAllowWhileIdle(AlarmManager.ELAPSED_REALTIME_WAKEUP, at, pending)
                return "ready"
            } catch (_: SecurityException) { /* access can change after the check */ }
        }
        alarms(context).setAndAllowWhileIdle(AlarmManager.ELAPSED_REALTIME_WAKEUP, at, pending)
        return "delayed"
    }

    @Synchronized
    fun deliver(context: Context, intent: Intent) {
        val saved = state(context) ?: return
        val request = saved.optJSONObject("current") ?: return
        if (!saved.getBoolean("enabled") || !matches(request, intent.getStringExtra("runId") ?: "",
                intent.getLongExtra("generation", -1)) || !permitted(context)) return
        if (remaining(context, request) > 0) { synchronize(context, saved); return }
        database(context)?.let { db ->
        db.beginTransaction()
        try {
        // Serialize validation/posting against SQLite timer transitions. A
        // concurrent pause/reset either commits first (reject here) or cancels
        // this posted notification after its own transaction commits.
        val latest = state(db) ?: return
        if (!latest.getBoolean("enabled") || !matches(latest.optJSONObject("current"),
                request.getString("runId"), request.getLong("generation"))) return
        val values = android.content.ContentValues().apply {
            put("key", deliveryKey(request)); put("created_at", System.currentTimeMillis())
        }
        if (db.insertWithOnConflict("notification_receipts", null, values, SQLiteDatabase.CONFLICT_IGNORE) == -1L) return
        createChannel(context)
        val open = Intent(context, MainActivity::class.java).setAction(OPEN)
            .setData(Uri.parse("poma-alert://open/${request.getString("runId")}/${request.getLong("generation")}"))
            .putExtra("runId", request.getString("runId")).putExtra("generation", request.getLong("generation"))
        val openPending = PendingIntent.getActivity(context, request.getInt("notificationId"), open,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val dismiss = Intent(context, PomaDismissReceiver::class.java)
            .setData(Uri.parse("poma-alert://dismiss/${request.getString("runId")}/${request.getLong("generation")}"))
            .putExtra("runId", request.getString("runId")).putExtra("generation", request.getLong("generation"))
        val dismissPending = PendingIntent.getBroadcast(context, request.getInt("notificationId"), dismiss,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(context, CHANNEL) else Notification.Builder(context)
        builder.setSmallIcon(dev.poma.poma.R.drawable.ic_stat_poma)
            .setContentTitle(context.getString(if (request.getString("phase") == "focus") R.string.alert_focus_complete else R.string.alert_break_complete))
            .setContentText(context.getString(R.string.alert_body))
            .setCategory(Notification.CATEGORY_REMINDER).setVisibility(Notification.VISIBILITY_PRIVATE)
            .setOnlyAlertOnce(true).setAutoCancel(true).setContentIntent(openPending)
            .setDeleteIntent(dismissPending)
            .addAction(Notification.Action.Builder(null, context.getString(R.string.alert_open), openPending).build())
            .addAction(Notification.Action.Builder(null, context.getString(R.string.alert_dismiss), dismissPending).build())
        if (Build.VERSION.SDK_INT < 26) builder.setDefaults(Notification.DEFAULT_SOUND or Notification.DEFAULT_VIBRATE)
        manager(context).notify(request.getInt("notificationId"), builder.build())
        alarmIntent(context, request, false)?.cancel()
        db.setTransactionSuccessful()
        } finally { db.endTransaction() }
        }
    }

    @Synchronized
    private fun queueResponse(context: Context, run: String, generation: Long, action: String) {
        val saved = state(context) ?: return
        if (!matches(saved.optJSONObject("current"), run, generation) &&
            !matches(saved.optJSONObject("previous"), run, generation)) return
        val queue = JSONObject(prefs(context).getString("responses", "{}")!!)
        queue.put("action:$run:$generation:$action", JSONObject().put("runId", run)
            .put("generation", generation).put("action", action))
        persist(context, "responses", queue.toString())
        notifyChanged()
    }

    fun captureOpen(context: Context, intent: Intent?) {
        if (intent?.action != OPEN) return
        val run = intent.getStringExtra("runId") ?: ""
        val generation = intent.getLongExtra("generation", -1)
        intent.action = Intent.ACTION_MAIN // Activity recreation must not enqueue again.
        AlertWorkQueue.execute {
            try { queueResponse(context, run, generation, "open") }
            catch (_: Exception) { /* preserve the journal for next app entry */ }
        }
    }

    fun dismiss(context: Context, intent: Intent) {
        val saved = state(context) ?: return
        val current = saved.optJSONObject("current")
        val previous = saved.optJSONObject("previous")
        val run = intent.getStringExtra("runId") ?: ""
        val generation = intent.getLongExtra("generation", -1)
        val request = if (matches(current, run, generation)) current else if (matches(previous, run, generation)) previous else null
        if (request != null && (current == null || matches(current, run, generation))) {
            manager(context).cancel(request.getInt("notificationId"))
        }
        queueResponse(context, run, generation, "dismiss")
    }

    fun restore(context: Context) {
        state(context)?.let { synchronize(context, it) }
        notifyChanged()
    }

    private fun notifyChanged() {
        // Flutter channel invocations belong on the platform thread; database
        // work and SharedPreferences journals stay on the serial worker.
        Handler(Looper.getMainLooper()).post { channel?.invokeMethod("changed", null) }
    }

    fun detach() {
        channel?.setMethodCallHandler(null)
        channel = null
    }
}

class PomaAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val app = context.applicationContext
        val copy = Intent(intent)
        finishAlertWork { PomaAlerts.deliver(app, copy) }
    }
}
class PomaDismissReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val app = context.applicationContext
        val copy = Intent(intent)
        finishAlertWork { PomaAlerts.dismiss(app, copy) }
    }
}
class PomaRestoreReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val app = context.applicationContext
        finishAlertWork { PomaAlerts.restore(app) }
    }
}

private fun BroadcastReceiver.finishAlertWork(work: () -> Unit) {
    val pending = goAsync()
    AlertWorkQueue.execute {
        try { work() } catch (_: Exception) { /* repair on unlock/next app entry */ }
        finally { pending.finish() }
    }
}
