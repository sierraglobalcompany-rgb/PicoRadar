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
    private val session = AlertSession { releaseSound() }
    private val event get() = session.event
    private var player: MediaPlayer? = null
    private var focus: AudioFocusRequest? = null
    private var focusListener: AudioManager.OnAudioFocusChangeListener? = null
    private var wake: PowerManager.WakeLock? = null
    private var deadline = 0L
    private var activeStartId = 0
    private var watchdog: Runnable? = null
    private val attributes = AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_ALARM)
        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).build()

    override fun onCreate() {
        super.onCreate()
        runtime = AlertRuntime.get(this)
        runtime.ringingChanged = { watchdog?.let { handler.removeCallbacks(it); it.run() } }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val key = AlertPlatform.key(intent)
        if (key == null) { if (event == null) stopSelf(); return START_NOT_STICKY }
        if (intent?.action == AlertPlatform.STOP || intent?.action == AlertPlatform.SNOOZE) {
            val active = event
            if (active?.id == key.first && active.token == key.second) {
                // Invalidate callbacks before releasing audio or changing the projection.
                session.clear()
                stopForeground(STOP_FOREGROUND_REMOVE)
                try {
                    if (intent.action == AlertPlatform.SNOOZE) runtime.engine.snooze(active.id, active.token)
                    else runtime.engine.finish(active.id, active.token, AlertEnd.STOP)
                } catch (error: Exception) { runtime.report(error, "ALARM_ACTION_FAILED") }
                stopSelf()
            } else if (active == null) stopSelf()
            return START_NOT_STICKY
        }
        if (intent?.action != AlertPlatform.FIRE) { if (event == null) stopSelf(); return START_NOT_STICKY }
        try {
            val active = runtime.engine.claim(key.first, key.second)
            if (active == null) { if (event == null) stopSelf(); return START_NOT_STICKY }
            if (event != null) stopForeground(STOP_FOREGROUND_REMOVE)
            val generation = session.begin(active)
            activeStartId = startId
            val notification = runtime.platform.notification(active)
            if (Build.VERSION.SDK_INT >= 29) startForeground(active.id, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK)
            else startForeground(active.id, notification)
            val duration = AlertRules.ringMillis(active, System.currentTimeMillis())
            if (duration <= 0) throw AlertFailure("EVENT_EXPIRED")
            deadline = SystemClock.elapsedRealtime() + duration
            wake = getSystemService(PowerManager::class.java).newWakeLock(PowerManager.PARTIAL_WAKE_LOCK,
                "PicoRadar:OptionalAlarm").apply { acquire(duration + 1000) }
            val check = object : Runnable {
                override fun run() {
                    if (!session.isCurrent(generation)) return
                    try {
                        if (runtime.engine.find(active.id, active.token)?.phase != AlertPhase.RINGING) {
                            finishAlarm(AlertEnd.STOP); return
                        }
                        runtime.platform.requireAccess()
                        if (SystemClock.elapsedRealtime() >= deadline || System.currentTimeMillis() >= active.expiresAt)
                            finishAlarm(AlertEnd.CUTOFF)
                        else handler.postDelayed(this, 500)
                    } catch (error: Exception) { runtime.report(error, "ALARM_INTERRUPTED"); finishAlarm(AlertEnd.INTERRUPTED) }
                }
            }
            watchdog = check
            handler.postDelayed(check, minOf(duration, 500))
            handler.postDelayed({ if (session.isCurrent(generation)) finishAlarm(AlertEnd.CUTOFF) }, duration)
            startSound(generation)
        } catch (error: Exception) { runtime.report(error, "RING_FAILED"); finishAlarm(AlertEnd.INTERRUPTED) }
        return START_NOT_STICKY
    }

    @Suppress("DEPRECATION")
    private fun startSound(generation: Long) {
        val audio = getSystemService(AudioManager::class.java)
        val listener = AudioManager.OnAudioFocusChangeListener { change ->
            if (session.isCurrent(generation) && change in setOf(AudioManager.AUDIOFOCUS_LOSS,
                    AudioManager.AUDIOFOCUS_LOSS_TRANSIENT, AudioManager.AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK)) {
                runtime.engine.recordFailure("AUDIO_FOCUS_LOST")
                finishAlarm(AlertEnd.INTERRUPTED)
            }
        }
        focusListener = listener
        val granted = if (Build.VERSION.SDK_INT >= 26) {
            focus = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
                .setAudioAttributes(attributes).setAcceptsDelayedFocusGain(false)
                .setOnAudioFocusChangeListener(listener, handler).build()
            audio.requestAudioFocus(focus!!)
        } else audio.requestAudioFocus(listener, AudioManager.STREAM_ALARM, AudioManager.AUDIOFOCUS_GAIN_TRANSIENT)
        if (!session.isCurrent(generation)) return
        if (granted != AudioManager.AUDIOFOCUS_REQUEST_GRANTED) throw AlertFailure("AUDIO_FOCUS_DENIED")
        val tone = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM) ?: throw AlertFailure("TONE_UNAVAILABLE")
        val media = MediaPlayer()
        player = media
        media.setAudioAttributes(attributes)
        media.setDataSource(this, tone)
        media.isLooping = true
        media.setOnPreparedListener {
            if (!session.isCurrent(generation) || player !== it) return@setOnPreparedListener
            try {
                runtime.platform.requireAccess()
                val active = event ?: return@setOnPreparedListener
                if (runtime.engine.find(active.id, active.token)?.phase != AlertPhase.RINGING) finishAlarm(AlertEnd.STOP)
                else if (SystemClock.elapsedRealtime() >= deadline) finishAlarm(AlertEnd.CUTOFF)
                else { it.start(); runtime.engine.playing(active.id, active.token) }
            } catch (error: Exception) { runtime.report(error, "PLAYBACK_FAILED"); finishAlarm(AlertEnd.INTERRUPTED) }
        }
        media.setOnErrorListener { failed, _, _ ->
            if (session.isCurrent(generation) && player === failed) {
                runtime.engine.recordFailure("PLAYBACK_FAILED")
                finishAlarm(AlertEnd.INTERRUPTED)
            }
            true
        }
        media.prepareAsync()
    }

    private fun finishAlarm(reason: AlertEnd) {
        val active = session.clear()
        stopForeground(STOP_FOREGROUND_REMOVE)
        if (active != null) {
            try { runtime.engine.finish(active.id, active.token, reason) }
            catch (error: Exception) { runtime.report(error, "MISSED_NOTICE_FAILED") }
        }
        stopSelf()
    }

    @Suppress("DEPRECATION")
    private fun releaseSound() {
        handler.removeCallbacksAndMessages(null)
        watchdog = null
        val media = player
        player = null
        try { media?.release() } catch (error: Exception) { runtime.report(error, "PLAYBACK_RELEASE_FAILED") }
        val audio = getSystemService(AudioManager::class.java)
        try {
            if (Build.VERSION.SDK_INT >= 26) focus?.let { audio.abandonAudioFocusRequest(it) }
            else focusListener?.let { audio.abandonAudioFocus(it) }
        } catch (error: Exception) { runtime.report(error, "AUDIO_FOCUS_RELEASE_FAILED") }
        focus = null
        focusListener = null
        try { wake?.let { if (it.isHeld) it.release() } }
        catch (error: Exception) { runtime.report(error, "WAKE_RELEASE_FAILED") }
        wake = null
    }

    override fun onTimeout(startId: Int, fgsType: Int) {
        if (event == null || activeStartId != startId) return
        runtime.engine.recordFailure("FOREGROUND_TIMEOUT")
        finishAlarm(AlertEnd.INTERRUPTED)
    }

    override fun onDestroy() {
        runtime.ringingChanged = null
        if (event != null) runtime.engine.recordFailure("ALARM_INTERRUPTED")
        finishAlarm(AlertEnd.INTERRUPTED)
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
