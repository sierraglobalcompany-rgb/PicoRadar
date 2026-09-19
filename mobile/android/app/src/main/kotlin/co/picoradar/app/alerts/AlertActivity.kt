package co.picoradar.app.alerts

import android.app.Activity
import android.app.KeyguardManager
import android.content.Intent
import android.graphics.Color
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.view.Gravity
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView

class AlertActivity : Activity() {
    private lateinit var runtime: AlertRuntime
    private var opening = false

    @Suppress("DEPRECATION")
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        runtime = AlertRuntime.get(this)
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        try {
            val event = current() ?: run { finish(); return }
            // Only the generic alarm controls can be displayed above the lock screen.
            if (event.phase == AlertPhase.RINGING && runtime.platform.fullScreenAllowed()) {
                if (Build.VERSION.SDK_INT >= 27) { setShowWhenLocked(true); setTurnScreenOn(true) }
                else window.addFlags(WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON)
            }
            render(event)
        } catch (error: Exception) { runtime.report(error, "ALARM_SCREEN_FAILED"); finish() }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        opening = false
        recreate()
    }

    private fun current(): AlertEvent? {
        val key = AlertPlatform.key(intent) ?: return null
        return runtime.engine.find(key.first, key.second)
    }

    private fun render(event: AlertEvent) {
        val dp = resources.displayMetrics.density
        val content = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding((24 * dp).toInt(), (48 * dp).toInt(), (24 * dp).toInt(), (48 * dp).toInt())
            setBackgroundColor(Color.WHITE)
        }
        content.addView(TextView(this).apply {
            text = if (event.scope == "test") "Prueba ficticia de PicoRadar" else "Alarma de PicoRadar"
            textSize = 24f
            setTextColor(Color.BLACK)
            gravity = Gravity.CENTER
        })
        if (event.phase == AlertPhase.RINGING) {
            addButton(content, "Detener") { action(event, AlertPlatform.STOP) }
            addButton(content, "Posponer 10 min") { action(event, AlertPlatform.SNOOZE) }
        }
        addButton(content, "Abrir PicoRadar") { unlockAndOpen(event) }
        setContentView(ScrollView(this).apply { isFillViewport = true; addView(content) })
    }

    private fun addButton(parent: LinearLayout, label: String, onClick: () -> Unit) {
        parent.addView(Button(this).apply {
            text = label
            minHeight = (56 * resources.displayMetrics.density).toInt()
            setOnClickListener { onClick() }
        }, LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT))
    }

    private fun action(event: AlertEvent, action: String) {
        try { startService(AlertPlatform.identity(Intent(this, AlertRingingService::class.java), event, action)) }
        catch (error: Exception) { runtime.report(error, "ALARM_ACTION_FAILED") }
        finish()
    }

    private fun unlockAndOpen(event: AlertEvent) {
        if (opening) return
        opening = true
        val keyguard = getSystemService(KeyguardManager::class.java)
        fun navigate() {
            if (isFinishing || isDestroyed) return
            if (keyguard.isDeviceLocked || keyguard.isKeyguardLocked) { opening = false; return }
            try {
                val current = current()
                // Expired/deleted events cannot reopen private context from a stale intent.
                if (current == null || current.expiresAt <= System.currentTimeMillis()) { finish(); return }
                startActivity(Intent().setClassName(this, "co.picoradar.app.MainActivity").apply {
                    action = Intent.ACTION_VIEW
                    data = Uri.parse("picoradar://${AlertRules.route(current.route)}")
                    addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                })
                action(event, AlertPlatform.STOP)
            } catch (error: Exception) { opening = false; runtime.report(error, "PRIVATE_NAVIGATION_FAILED") }
        }
        if (!keyguard.isKeyguardLocked && !keyguard.isDeviceLocked) navigate()
        else if (Build.VERSION.SDK_INT >= 26) {
            keyguard.requestDismissKeyguard(this, object : KeyguardManager.KeyguardDismissCallback() {
                override fun onDismissSucceeded() { navigate() }
                override fun onDismissCancelled() { opening = false }
                override fun onDismissError() { opening = false; runtime.engine.recordFailure("UNLOCK_FAILED") }
            })
        } else {
            @Suppress("DEPRECATION")
            val unlock = keyguard.createConfirmDeviceCredentialIntent("PicoRadar", "Desbloquea para abrir la app")
            if (unlock == null) { opening = false; return }
            @Suppress("DEPRECATION")
            startActivityForResult(unlock, 7412)
        }
    }

    @Deprecated("Android 7 credential unlock")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        opening = false
        if (requestCode == 7412 && resultCode == RESULT_OK) {
            try { current()?.let { unlockAndOpen(it) } }
            catch (error: Exception) { runtime.report(error, "PRIVATE_NAVIGATION_FAILED") }
        }
    }
}
