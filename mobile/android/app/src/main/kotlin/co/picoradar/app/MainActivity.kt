package co.picoradar.app

import android.content.Context
import android.net.Uri
import android.speech.tts.TextToSpeech
import android.view.WindowManager
import androidx.glance.appwidget.updateAll
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import java.util.Locale

class MainActivity : FlutterActivity() {
    private var tts: TextToSpeech? = null
    private var ttsReady = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        tts = TextToSpeech(this) { status ->
            ttsReady = status == TextToSpeech.SUCCESS
            if (ttsReady) {
                tts?.language = Locale("es", "CO")
            }
        }
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
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "co.picoradar.app/driving",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "speakDrivingAlert" -> {
                    val message = call.argument<String>("message").orEmpty()
                    if (ttsReady && message.isNotBlank()) {
                        tts?.speak(message, TextToSpeech.QUEUE_FLUSH, null, "driving-alert")
                    }
                    result.success(null)
                }
                "setKeepScreenOn" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    if (enabled) {
                        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    } else {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        tts?.stop()
        tts?.shutdown()
        tts = null
        super.onDestroy()
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
