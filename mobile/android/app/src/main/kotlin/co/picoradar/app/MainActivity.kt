package co.picoradar.app

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.os.SystemClock
import android.speech.tts.TextToSpeech
import android.util.Log
import android.view.WindowManager
import androidx.glance.appwidget.updateAll
import co.picoradar.app.wallet.WalletBridge
import co.picoradar.app.alerts.AlertsBridge
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import java.util.Locale

class MainActivity : FlutterFragmentActivity() {
    private val startupAtNs = SystemClock.elapsedRealtimeNanos()
    private var tts: TextToSpeech? = null
    private var ttsReady = false
    private var walletBridge: WalletBridge? = null
    private var alertsBridge: AlertsBridge? = null

    private fun logStartup(marker: String, extra: String = "") {
        val nowNs = SystemClock.elapsedRealtimeNanos()
        Log.i(
            "P01_STARTUP",
            "$marker elapsed_us=${(nowNs - startupAtNs) / 1000}" +
                " uptime_us=${nowNs / 1000} epoch_ms=${System.currentTimeMillis()}$extra",
        )
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        logStartup("NATIVE_ACTIVITY_ENTRY")
        super.onCreate(savedInstanceState)
        logStartup("NATIVE_ACTIVITY_CREATED")
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        val pluginsAtNs = SystemClock.elapsedRealtimeNanos()
        logStartup("PLUGIN_REGISTRATION_BEGIN")
        super.configureFlutterEngine(flutterEngine)
        alertsBridge?.dispose()
        alertsBridge = AlertsBridge(this, flutterEngine.dartExecutor.binaryMessenger)
        walletBridge = WalletBridge(this, flutterEngine.dartExecutor.binaryMessenger)
        logStartup(
            "PLUGIN_REGISTRATION_END",
            " duration_us=${(SystemClock.elapsedRealtimeNanos() - pluginsAtNs) / 1000}",
        )
        val ttsAtNs = SystemClock.elapsedRealtimeNanos()
        logStartup("TTS_INIT_BEGIN")
        tts = TextToSpeech(this) { status ->
            ttsReady = status == TextToSpeech.SUCCESS
            if (ttsReady) {
                tts?.language = Locale("es", "CO")
            }
            logStartup(
                "TTS_INIT_CALLBACK",
                " ready=$ttsReady duration_us=${(SystemClock.elapsedRealtimeNanos() - ttsAtNs) / 1000}",
            )
        }
        logStartup("TTS_INIT_RETURNED")
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
                "stopDrivingFeedback" -> {
                    tts?.stop()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onResume() {
        logStartup("NATIVE_ACTIVITY_RESUME")
        super.onResume()
    }

    override fun onDestroy() {
        alertsBridge?.dispose()
        alertsBridge = null
        walletBridge?.dispose()
        walletBridge = null
        tts?.stop()
        tts?.shutdown()
        tts = null
        super.onDestroy()
    }

    override fun onStop() {
        walletBridge?.onBackground()
        super.onStop()
    }

    @Deprecated("Forwarding scanner result to its native bridge")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        walletBridge?.onActivityResult(requestCode, resultCode, data)
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
