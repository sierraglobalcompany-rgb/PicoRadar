package co.picoradar.app.alerts

import android.Manifest
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

class AlertsBridge(private val activity: FlutterFragmentActivity, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "co.picoradar.app/alerts")
    private val runtime = AlertRuntime.get(activity)
    @Volatile private var disposed = false

    init {
        channel.setMethodCallHandler { call, result ->
            if (disposed) result.error("BRIDGE_DISPOSED", "Alarm bridge is unavailable", null)
            else if (call.method in setOf("capabilities", "requestPermissions", "requestFullScreen", "openNotificationSettings", "test")) {
                try {
                    when (call.method) {
                        "capabilities" -> result.success(runtime.platform.capabilities())
                        "requestPermissions" -> { requestPermissions(); result.success(runtime.platform.capabilities()) }
                        "requestFullScreen" -> { requestFullScreen(); result.success(runtime.platform.capabilities()) }
                        "openNotificationSettings" -> { openNotificationSettings(); result.success(null) }
                        "test" -> {
                            runtime.platform.requireAccess()
                            val event = runtime.engine.test()
                            try { runtime.platform.start(event) }
                            catch (error: Exception) {
                                runtime.report(error, "FOREGROUND_START_FAILED")
                                runtime.engine.stop(event.id, event.token)
                                throw error
                            }
                            result.success(null)
                        }
                    }
                } catch (error: Exception) { fail(result, error) }
            } else if (call.method in setOf("reschedule", "pending", "cancel", "status")) {
                runtime.worker.execute {
                    try {
                        if (disposed) throw AlertFailure("BRIDGE_DISPOSED")
                        val value: Any? = when (call.method) {
                            "status" -> runtime.engine.status()
                            "pending" -> runtime.engine.pending()
                            "reschedule" -> {
                                val scope = call.argument<String>("scope") ?: throw AlertFailure("INVALID_SCOPE")
                                val events = AlertRules.parse(scope, call.argument<Any>("events"), System.currentTimeMillis())
                                runtime.engine.reschedule(scope, events)
                            }
                            else -> {
                                runtime.engine.cancel(call.argument<String>("scope") ?: throw AlertFailure("INVALID_SCOPE"))
                                null
                            }
                        }
                        runtime.changed()
                        runtime.main.post { result.success(value) }
                    } catch (error: Exception) {
                        runtime.changed()
                        val failure = runtime.report(error, "ALARM_OPERATION_FAILED")
                        runtime.main.post { result.error(failure.code, failure.message, null) }
                    }
                }
            } else result.notImplemented()
        }
    }

    private fun requestPermissions() {
        val flags = runtime.platform.capabilities()
        if (flags["exact"] != true && Build.VERSION.SDK_INT >= 31) {
            activity.startActivity(Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM, Uri.parse("package:${activity.packageName}")))
        } else if (flags["notifications"] != true) {
            if (Build.VERSION.SDK_INT >= 33 && activity.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != android.content.pm.PackageManager.PERMISSION_GRANTED) {
                activity.requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 7411)
            } else {
                openNotificationSettings()
            }
        }
    }

    private fun openNotificationSettings() {
        val intent = if (Build.VERSION.SDK_INT >= 26) Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
            .putExtra(Settings.EXTRA_APP_PACKAGE, activity.packageName)
        else Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:${activity.packageName}"))
        activity.startActivity(intent)
    }

    private fun requestFullScreen() {
        if (!runtime.platform.fullScreenAllowed() && Build.VERSION.SDK_INT >= 34) {
            activity.startActivity(Intent(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT, Uri.parse("package:${activity.packageName}")))
        }
    }

    private fun fail(result: MethodChannel.Result, error: Exception) {
        val failure = runtime.report(error, "ALARM_OPERATION_FAILED")
        result.error(failure.code, failure.message, null)
    }

    fun dispose() {
        disposed = true
        channel.setMethodCallHandler(null)
    }
}
