package co.picoradar.app.alerts

import android.Manifest
import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build

internal class AlertPlatform(private val context: Context) : AlertAlarms {
    private val alarms = context.getSystemService(AlarmManager::class.java)
    private val notifications = context.getSystemService(NotificationManager::class.java)

    fun capabilities(): Map<String, Boolean> {
        val enabled = notifications.areNotificationsEnabled() &&
            (Build.VERSION.SDK_INT < 33 || context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED) &&
            (Build.VERSION.SDK_INT < 26 || notifications.getNotificationChannel(CHANNEL)?.importance != NotificationManager.IMPORTANCE_NONE)
        return mapOf("supported" to true, "notifications" to enabled,
            "exact" to (Build.VERSION.SDK_INT < 31 || alarms.canScheduleExactAlarms()),
            "fullScreen" to fullScreenAllowed())
    }

    fun fullScreenAllowed(): Boolean = when {
        Build.VERSION.SDK_INT >= 34 -> notifications.canUseFullScreenIntent()
        Build.VERSION.SDK_INT >= 29 -> context.checkSelfPermission(Manifest.permission.USE_FULL_SCREEN_INTENT) == PackageManager.PERMISSION_GRANTED
        else -> true
    }

    override fun requireAccess() {
        val flags = capabilities()
        if (flags["notifications"] != true) throw AlertFailure("NOTIFICATIONS_REQUIRED")
        if (flags["exact"] != true) throw AlertFailure("EXACT_ACCESS_REQUIRED")
    }

    override fun schedule(event: AlertEvent) {
        requireAccess()
        alarms.setAlarmClock(AlarmManager.AlarmClockInfo(event.at, activityIntent(event)),
            PendingIntent.getBroadcast(context, event.id, identity(Intent(context, AlertReceiver::class.java), event, FIRE), FLAGS))
    }

    override fun cancel(event: AlertEvent) {
        val pending = PendingIntent.getBroadcast(context, event.id,
            identity(Intent(context, AlertReceiver::class.java), event, FIRE),
            PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE)
        if (pending != null) { alarms.cancel(pending); pending.cancel() }
    }

    fun notification(event: AlertEvent): Notification {
        if (Build.VERSION.SDK_INT >= 26) {
            val channel = NotificationChannel(CHANNEL, "Alarmas opcionales", NotificationManager.IMPORTANCE_HIGH)
            channel.description = "Alarmas activadas por ti"
            channel.setSound(null, null)
            channel.enableVibration(false)
            channel.lockscreenVisibility = Notification.VISIBILITY_PRIVATE
            notifications.createNotificationChannel(channel)
        }
        val title = if (event.scope == "test") "Prueba ficticia de PicoRadar" else "Alarma de PicoRadar"
        val public = builder().setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle(title).setContentText("Recordatorio local")
            .addAction(Notification.Action.Builder(null, "Detener", actionIntent(event, STOP)).build())
            .addAction(Notification.Action.Builder(null, "Posponer 10 min", actionIntent(event, SNOOZE)).build())
            .setVisibility(Notification.VISIBILITY_PUBLIC).build()
        val builder = builder().setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle(title).setContentText("Recordatorio local")
            .setCategory(Notification.CATEGORY_ALARM).setPriority(Notification.PRIORITY_MAX)
            .setVisibility(Notification.VISIBILITY_PRIVATE).setPublicVersion(public)
            .setOngoing(true).setOnlyAlertOnce(true).setContentIntent(activityIntent(event))
            .addAction(Notification.Action.Builder(null, "Detener", actionIntent(event, STOP)).build())
            .addAction(Notification.Action.Builder(null, "Posponer 10 min", actionIntent(event, SNOOZE)).build())
        if (Build.VERSION.SDK_INT >= 26) builder.setTimeoutAfter(AlertRules.ringMillis(event, System.currentTimeMillis()))
        if (fullScreenAllowed()) builder.setFullScreenIntent(activityIntent(event), true)
        return builder.build()
    }

    @Suppress("DEPRECATION")
    private fun builder(): Notification.Builder = if (Build.VERSION.SDK_INT >= 26)
        Notification.Builder(context, CHANNEL) else Notification.Builder(context)

    private fun activityIntent(event: AlertEvent): PendingIntent = PendingIntent.getActivity(context, event.id,
        identity(Intent(context, AlertActivity::class.java), event, SHOW)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP), FLAGS)

    private fun actionIntent(event: AlertEvent, action: String): PendingIntent = PendingIntent.getService(
        context, event.id, identity(Intent(context, AlertRingingService::class.java), event, action), FLAGS)

    fun start(event: AlertEvent) {
        val intent = identity(Intent(context, AlertRingingService::class.java), event, FIRE)
        if (Build.VERSION.SDK_INT >= 26) context.startForegroundService(intent) else context.startService(intent)
    }

    companion object {
        const val CHANNEL = "picoradar_optional_alarms_v1"
        const val FIRE = "co.picoradar.app.alerts.FIRE"
        const val SHOW = "co.picoradar.app.alerts.SHOW"
        const val STOP = "co.picoradar.app.alerts.STOP"
        const val SNOOZE = "co.picoradar.app.alerts.SNOOZE"
        private const val FLAGS = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE

        fun identity(intent: Intent, event: AlertEvent, action: String): Intent = intent.apply {
            this.action = action
            data = Uri.Builder().scheme("picoradar-alert").authority("local")
                .appendPath(event.scope).appendPath(event.id.toString()).appendPath(event.token).build()
        }

        fun key(intent: Intent?): Pair<Int, String>? {
            val uri = intent?.data ?: return null
            if (uri.scheme != "picoradar-alert" || uri.authority != "local" || uri.pathSegments.size != 3) return null
            val id = uri.pathSegments[1].toIntOrNull() ?: return null
            return id to uri.pathSegments[2]
        }
    }
}
