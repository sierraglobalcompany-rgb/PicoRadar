package co.picoradar.app.alerts

import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.os.SystemClock

class AlertRingingService : Service() {
    private lateinit var runtime: AlertRuntime
    private val handler = Handler(Looper.getMainLooper())
    private var event: AlertEvent? = null
    private var player: MediaPlayer? = null
    private var focus: AudioFocusRequest? = null
    private var wake: PowerManager.WakeLock? = null
    private var deadline = 0L
    private val cutoff = Runnable { finishAlarm() }
    private val attributes = AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_ALARM)
        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).build()
    private val focusListener = AudioManager.OnAudioFocusChangeListener { change ->
        if (event != null && (change == AudioManager.AUDIOFOCUS_LOSS || change == AudioManager.AUDIOFOCUS_LOSS_TRANSIENT ||
            change == AudioManager.AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK)) {
            runtime.engine.recordFailure("AUDIO_FOCUS_LOST")
            finishAlarm()
        }
    }
    private val watchdog = object : Runnable {
        override fun run() {
            val active = event ?: return
            try {
                runtime.platform.requireAccess()
                if (SystemClock.elapsedRealtime() >= deadline || System.currentTimeMillis() >= active.expiresAt ||
                    runtime.engine.find(active.id, active.token)?.phase != AlertPhase.RINGING) finishAlarm()
                else handler.postDelayed(this, 500)
            } catch (error: Exception) { runtime.report(error, "ALARM_INTERRUPTED"); finishAlarm() }
        }
    }

    override fun onCreate() {
        super.onCreate()
        runtime = AlertRuntime.get(this)
        runtime.ringingChanged = { handler.removeCallbacks(watchdog); watchdog.run() }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val key = AlertPlatform.key(intent)
        if (key == null) { if (event == null) stopSelf(); return START_NOT_STICKY }
        if (intent?.action == AlertPlatform.STOP || intent?.action == AlertPlatform.SNOOZE) {
            val active = event
            if (active?.id == key.first && active.token == key.second) {
                releaseSound()
                try {
                    if (intent.action == AlertPlatform.SNOOZE) runtime.engine.snooze(active.id, active.token)
                    else runtime.engine.stop(active.id, active.token)
                } catch (error: Exception) { runtime.report(error, "ALARM_ACTION_FAILED") }
                finishAlarm()
            } else if (active == null) stopSelf()
            return START_NOT_STICKY
        }
        if (intent?.action != AlertPlatform.FIRE) { if (event == null) stopSelf(); return START_NOT_STICKY }
        try {
            val active = runtime.engine.claim(key.first, key.second)
            if (active == null) { if (event == null) stopSelf(); return START_NOT_STICKY }
            event = active
            val notification = runtime.platform.notification(active)
            if (Build.VERSION.SDK_INT >= 29) startForeground(active.id, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK)
            else startForeground(active.id, notification)
            val duration = AlertRules.ringMillis(active, System.currentTimeMillis())
            if (duration <= 0) throw AlertFailure("EVENT_EXPIRED")
            deadline = SystemClock.elapsedRealtime() + duration
            wake = getSystemService(PowerManager::class.java).newWakeLock(PowerManager.PARTIAL_WAKE_LOCK,
                "PicoRadar:OptionalAlarm").apply { acquire(duration + 1000) }
            handler.postDelayed(watchdog, minOf(duration, 500))
            handler.postDelayed(cutoff, duration)
            startSound()
        } catch (error: Exception) { runtime.report(error, "RING_FAILED"); finishAlarm() }
        return START_NOT_STICKY
    }

    @Suppress("DEPRECATION")
    private fun startSound() {
        val audio = getSystemService(AudioManager::class.java)
        val granted = if (Build.VERSION.SDK_INT >= 26) {
            focus = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
                .setAudioAttributes(attributes).setAcceptsDelayedFocusGain(false)
                .setOnAudioFocusChangeListener(focusListener, handler).build()
            audio.requestAudioFocus(focus!!)
        } else audio.requestAudioFocus(focusListener, AudioManager.STREAM_ALARM, AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
        if (granted != AudioManager.AUDIOFOCUS_REQUEST_GRANTED) throw AlertFailure("AUDIO_FOCUS_DENIED")
        val tone = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM) ?: throw AlertFailure("TONE_UNAVAILABLE")
        val media = MediaPlayer()
        player = media
        media.setAudioAttributes(attributes)
        media.setDataSource(this, tone)
        media.isLooping = true
        media.setOnPreparedListener {
            if (player !== it || event == null) return@setOnPreparedListener
            try {
                runtime.platform.requireAccess()
                val active = event
                if (active == null || SystemClock.elapsedRealtime() >= deadline ||
                    runtime.engine.find(active.id, active.token)?.phase != AlertPhase.RINGING) finishAlarm() else it.start()
            } catch (error: Exception) { runtime.report(error, "PLAYBACK_FAILED"); finishAlarm() }
        }
        media.setOnErrorListener { _, _, _ ->
            runtime.engine.recordFailure("PLAYBACK_FAILED")
            finishAlarm()
            true
        }
        media.prepareAsync()
    }

    private fun finishAlarm() {
        val active = event
        event = null
        releaseSound()
        if (active != null) {
            try { runtime.engine.stop(active.id, active.token) }
            catch (error: Exception) { runtime.report(error, "CANCEL_FAILED") }
        }
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    @Suppress("DEPRECATION")
    private fun releaseSound() {
        handler.removeCallbacksAndMessages(null)
        val media = player
        player = null
        try { media?.release() } catch (error: Exception) { runtime.report(error, "PLAYBACK_RELEASE_FAILED") }
        val audio = getSystemService(AudioManager::class.java)
        try {
            if (Build.VERSION.SDK_INT >= 26) focus?.let { audio.abandonAudioFocusRequest(it) }
            else audio.abandonAudioFocus(focusListener)
        } catch (error: Exception) { runtime.report(error, "AUDIO_FOCUS_RELEASE_FAILED") }
        focus = null
        try { wake?.let { if (it.isHeld) it.release() } }
        catch (error: Exception) { runtime.report(error, "WAKE_RELEASE_FAILED") }
        wake = null
    }

    override fun onTimeout(startId: Int, fgsType: Int) {
        runtime.engine.recordFailure("FOREGROUND_TIMEOUT")
        finishAlarm()
    }

    override fun onDestroy() {
        runtime.ringingChanged = null
        finishAlarm()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
