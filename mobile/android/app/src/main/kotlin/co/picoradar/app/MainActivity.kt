package co.picoradar.app

import android.content.Context
import android.net.Uri
import androidx.glance.appwidget.updateAll
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "co.picoradar.app/widget",
        ).setMethodCallHandler { call, result ->
            if (call.method != "updatePicoWidget") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            val prefs = getSharedPreferences("picoradar_widget", Context.MODE_PRIVATE)
            prefs.edit()
                .putBoolean("configured", call.argument<Boolean>("configured") ?: false)
                .putBoolean("hasVehicle", call.argument<Boolean>("hasVehicle") ?: false)
                .putString("plate", call.argument<String>("plate").orEmpty())
                .putString("vehicleLabel", call.argument<String>("vehicleLabel").orEmpty())
                .putString("jurisdictionName", call.argument<String>("jurisdictionName").orEmpty())
                .apply()

            CoroutineScope(Dispatchers.Main).launch {
                PicoRadarWidget().updateAll(this@MainActivity)
            }
            result.success(null)
        }
    }

    companion object {
        fun picoIntent(context: Context) =
            android.content.Intent(context, MainActivity::class.java).apply {
                action = android.content.Intent.ACTION_VIEW
                data = Uri.parse("picoradar:///pico")
                addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
            }
    }
}
