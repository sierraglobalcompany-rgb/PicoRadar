package co.picoradar.app.alerts

import android.content.Context
import android.os.Handler
import android.os.Looper
import java.util.concurrent.Executors

internal class AlertRuntime private constructor(context: Context) {
    val platform = AlertPlatform(context)
    val engine = AlertEngine(AlertProjectionStore(context), platform)
    val worker = Executors.newSingleThreadExecutor()
    val main = Handler(Looper.getMainLooper())
    var ringingChanged: (() -> Unit)? = null

    init {
        try { engine.recoverInterrupted() }
        catch (error: Exception) { report(error, "RESTORE_FAILED") }
    }

    fun changed() { main.post { ringingChanged?.invoke() } }
    fun report(error: Exception, fallback: String): AlertFailure {
        val failure = AlertEngine.failure(error, fallback)
        engine.recordFailure(failure.code)
        return failure
    }

    companion object {
        @Volatile private var instance: AlertRuntime? = null
        fun get(context: Context): AlertRuntime = instance ?: synchronized(this) {
            instance ?: AlertRuntime(context.applicationContext).also { instance = it }
        }
    }
}
