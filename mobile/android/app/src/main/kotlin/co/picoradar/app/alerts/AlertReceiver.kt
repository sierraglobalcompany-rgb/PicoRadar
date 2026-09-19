package co.picoradar.app.alerts

import android.app.AlarmManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class AlertReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val runtime = AlertRuntime.get(context)
        if (intent.action == AlertPlatform.DISMISS) {
            val key = AlertPlatform.key(intent) ?: return
            try {
                if (runtime.engine.find(key.first, key.second)?.phase == AlertPhase.MISSED)
                    runtime.engine.stop(key.first, key.second)
            } catch (error: Exception) { runtime.report(error, "CANCEL_FAILED") }
            return
        }
        if (intent.action == AlertPlatform.FIRE) {
            val key = AlertPlatform.key(intent) ?: return
            try {
                val event = runtime.engine.find(key.first, key.second) ?: return
                if (!AlertRules.canRing(event, System.currentTimeMillis())) {
                    if (event.phase !in setOf(AlertPhase.RINGING, AlertPhase.MISSED)) runtime.engine.stop(event.id, event.token)
                    return
                }
                runtime.platform.requireAccess()
                runtime.platform.start(event)
            } catch (error: Exception) {
                try { runtime.engine.stop(key.first, key.second) }
                catch (cleanup: Exception) { runtime.report(cleanup, "CANCEL_FAILED") }
                runtime.report(error, "FOREGROUND_START_FAILED")
            }
            return
        }
        if (intent.action !in setOf(Intent.ACTION_BOOT_COMPLETED, Intent.ACTION_MY_PACKAGE_REPLACED,
                Intent.ACTION_TIME_CHANGED, Intent.ACTION_TIMEZONE_CHANGED, AlarmManager.ACTION_SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED)) return
        val pending = goAsync()
        runtime.worker.execute {
            try { runtime.engine.restore(); runtime.changed() }
            catch (error: Exception) { runtime.report(error, "RESTORE_FAILED"); runtime.changed() }
            finally { pending.finish() }
        }
    }
}
