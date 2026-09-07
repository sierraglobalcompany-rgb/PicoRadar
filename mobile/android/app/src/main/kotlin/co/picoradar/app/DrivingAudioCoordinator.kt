package co.picoradar.app

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioDeviceInfo
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.media.AudioRouting
import android.media.ToneGenerator
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.RandomAccessFile
import java.util.Locale
import kotlin.math.PI
import kotlin.math.sin

class DrivingAudioCoordinator(private val context: Context) {
    private val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    private val handler = Handler(Looper.getMainLooper())
    private val attributes = AudioAttributes.Builder()
        .setUsage(AudioAttributes.USAGE_ASSISTANCE_NAVIGATION_GUIDANCE)
        .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
        .build()
    private var tts: TextToSpeech? = null
    private var ttsReady = false
    private var initializationFailed = false
    private var activeResult: MethodChannel.Result? = null
    private var activeOperationId = 0L
    private var operationSerial = 0L
    private val operationGuard = DrivingAudioOperationGuard()
    private var activeTimeout: Runnable? = null
    private var activeUtteranceId: String? = null
    private var focusRequest: AudioFocusRequest? = null
    private var legacyFocusListener: AudioManager.OnAudioFocusChangeListener? = null
    private var toneGenerator: ToneGenerator? = null
    private var mediaPlayer: MediaPlayer? = null
    private var mediaRoutingListener: AudioRouting.OnRoutingChangedListener? = null
    private val temporaryFiles = mutableListOf<File>()
    private var speakerQueue = ArrayDeque<File>()
    private var requestedSpeaker: AudioDeviceInfo? = null
    private var speakerVolume = 1.0f

    init {
        tts = TextToSpeech(context) { status ->
            ttsReady = status == TextToSpeech.SUCCESS
            initializationFailed = !ttsReady
            if (ttsReady) {
                tts?.language = Locale("es", "CO")
                tts?.setAudioAttributes(attributes)
                installTtsCallbacks()
            }
        }
    }

    fun play(call: io.flutter.plugin.common.MethodCall, result: MethodChannel.Result) {
        val message = call.argument<String>("message")?.trim().orEmpty()
        val playSound = call.argument<Boolean>("playSound") ?: false
        val output = call.argument<String>("output") ?: "automatic"
        val musicBehavior = call.argument<String>("musicBehavior") ?: "duck"
        val volume = (call.argument<Double>("volume") ?: 0.8).coerceIn(0.0, 1.0)

        if (!playSound && message.isEmpty()) {
            result.error("empty_alert", "La alerta no contiene voz ni tono.", null)
            return
        }
        if (message.isNotEmpty() && (!ttsReady || initializationFailed)) {
            result.error("tts_unavailable", "La voz de navegación no está disponible.", null)
            return
        }

        stopInternal(completePending = true)
        operationSerial += 1
        val operationId = operationSerial
        activeOperationId = operationId
        operationGuard.beginOperation(operationId)
        if (!requestFocus(musicBehavior, operationId)) {
            activeOperationId = 0L
            operationGuard.clearOperation()
            result.error("audio_focus_denied", "Android no concedió el foco de audio.", null)
            return
        }
        activeResult = result
        scheduleTimeout(operationId)

        try {
            if (volume == 0.0) {
                finishSuccess(operationId)
            } else if (output == "phoneSpeaker") {
                playOnPhoneSpeaker(message, playSound, volume.toFloat(), operationId)
            } else {
                playAutomatically(message, playSound, volume.toFloat(), operationId)
            }
        } catch (_: Exception) {
            finishError("driving_audio_failed", "No se pudo reproducir el aviso.", operationId)
        }
    }

    fun stop() {
        stopInternal(completePending = true)
    }

    fun destroy() {
        stopInternal(completePending = true)
        tts?.shutdown()
        tts = null
        ttsReady = false
    }

    private fun playAutomatically(
        message: String,
        playSound: Boolean,
        volume: Float,
        operationId: Long,
    ) {
        val speak = speak@{
            if (!isActiveOperation(operationId)) return@speak
            if (message.isEmpty()) {
                finishSuccess(operationId)
            } else {
                val utteranceId = "driving-alert-${System.nanoTime()}"
                activeUtteranceId = utteranceId
                val params = Bundle().apply {
                    putFloat(TextToSpeech.Engine.KEY_PARAM_VOLUME, volume)
                }
                val status = tts?.speak(message, TextToSpeech.QUEUE_FLUSH, params, utteranceId)
                if (status != TextToSpeech.SUCCESS) {
                    finishError("tts_enqueue_failed", "No se pudo iniciar la voz de navegación.", operationId)
                }
            }
        }
        if (playSound) {
            toneGenerator = ToneGenerator(AudioManager.STREAM_MUSIC, (volume * 100).toInt())
            if (!toneGenerator!!.startTone(ToneGenerator.TONE_PROP_BEEP, 180)) {
                finishError("tone_failed", "No se pudo reproducir el tono de alerta.", operationId)
                return
            }
            handler.postDelayed(speak, 220)
        } else {
            speak()
        }
    }

    private fun playOnPhoneSpeaker(
        message: String,
        playSound: Boolean,
        volume: Float,
        operationId: Long,
    ) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) {
            finishError(
                "speaker_output_unsupported",
                "Esta versión de Android no permite confirmar el altavoz.",
                operationId,
            )
            return
        }
        requestedSpeaker = audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS)
            .firstOrNull { it.type == AudioDeviceInfo.TYPE_BUILTIN_SPEAKER }
        if (requestedSpeaker == null) {
            finishError("speaker_output_unavailable", "No se encontró el altavoz integrado.", operationId)
            return
        }

        speakerQueue = ArrayDeque()
        speakerVolume = volume
        speakerQueue.add(createToneFile("route-probe", volume = 0.0, silenceMs = 160, toneMs = 0))
        if (playSound) {
            speakerQueue.add(createToneFile("alert-tone", volume.toDouble(), silenceMs = 30, toneMs = 180))
        }
        if (message.isEmpty()) {
            playNextSpeakerFile(volume, operationId)
            return
        }

        val speechFile = File.createTempFile("picoradar-driving-voice-", ".wav", context.cacheDir)
        temporaryFiles.add(speechFile)
        val utteranceId = "synth-${System.nanoTime()}"
        activeUtteranceId = utteranceId
        val status = tts?.synthesizeToFile(message, Bundle(), speechFile, utteranceId)
        if (status != TextToSpeech.SUCCESS) {
            finishError("tts_synthesis_failed", "No se pudo preparar la voz para el altavoz.", operationId)
        } else {
            speakerQueue.add(speechFile)
        }
    }

    private fun playNextSpeakerFile(volume: Float, operationId: Long) {
        if (!isActiveOperation(operationId)) return
        val file = speakerQueue.removeFirstOrNull()
        if (file == null) {
            finishSuccess(operationId)
            return
        }
        val speaker = requestedSpeaker
        if (speaker == null) {
            finishError("speaker_output_unavailable", "No se encontró el altavoz integrado.", operationId)
            return
        }
        try {
            val player = MediaPlayer()
            val playerToken = operationGuard.beginPlayer(operationId, activeResult != null)
            mediaPlayer = player
            player.setAudioAttributes(attributes)
            player.setDataSource(file.absolutePath)
            if (!player.setPreferredDevice(speaker)) {
                releaseCurrentMediaPlayer(stop = false)
                finishError("speaker_route_unconfirmed", "No se pudo aplicar esta salida.", operationId)
                return
            }
            player.setVolume(volume, volume)
            player.setOnCompletionListener { completedPlayer ->
                if (!isCurrentSpeakerPlayer(completedPlayer, operationId, playerToken)) {
                    return@setOnCompletionListener
                }
                releaseCurrentMediaPlayer(stop = false)
                if (isActiveOperation(operationId)) {
                    playNextSpeakerFile(volume, operationId)
                }
            }
            player.setOnErrorListener { failedPlayer, _, _ ->
                if (!isCurrentSpeakerPlayer(failedPlayer, operationId, playerToken)) {
                    return@setOnErrorListener true
                }
                releaseCurrentMediaPlayer(stop = false)
                finishError(
                    "speaker_playback_failed",
                    "Falló la reproducción por el altavoz.",
                    operationId,
                )
                true
            }
            installSpeakerRouteGuard(player, operationId, playerToken)
            player.prepare()
            player.start()
            handler.postDelayed({
                validateSpeakerRoute(player, operationId, playerToken)
            }, if (file.name.startsWith("route-probe")) 60 else 20)
        } catch (_: Exception) {
            releaseCurrentMediaPlayer(stop = false)
            finishError("speaker_playback_failed", "Falló la reproducción por el altavoz.", operationId)
            return
        }
    }

    private fun installTtsCallbacks() {
        tts?.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
            override fun onStart(utteranceId: String?) = Unit

            override fun onDone(utteranceId: String?) {
                handler.post {
                    if (utteranceId != activeUtteranceId) return@post
                    val operationId = activeOperationId
                    if (utteranceId?.startsWith("synth-") == true) {
                        playNextSpeakerFile(speakerVolume, operationId)
                    } else {
                        finishSuccess(operationId)
                    }
                }
            }

            @Deprecated("Deprecated by Android")
            override fun onError(utteranceId: String?) {
                handler.post {
                    if (utteranceId == activeUtteranceId) {
                        finishError(
                            "tts_playback_failed",
                            "La voz de navegación falló.",
                            activeOperationId,
                        )
                    }
                }
            }

            override fun onError(utteranceId: String?, errorCode: Int) = onError(utteranceId)
        })
    }

    private fun requestFocus(musicBehavior: String, operationId: Long): Boolean {
        val gain = if (musicBehavior == "pause") {
            AudioManager.AUDIOFOCUS_GAIN_TRANSIENT
        } else {
            AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK
        }
        val listener = AudioManager.OnAudioFocusChangeListener { change ->
            if (change == AudioManager.AUDIOFOCUS_LOSS ||
                change == AudioManager.AUDIOFOCUS_LOSS_TRANSIENT
            ) {
                handler.post {
                    finishError(
                        "audio_focus_lost",
                        "El aviso cedió el audio a otra aplicación.",
                        operationId,
                    )
                }
            }
        }
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val request = AudioFocusRequest.Builder(gain)
                .setAudioAttributes(attributes)
                .setOnAudioFocusChangeListener(listener)
                .setAcceptsDelayedFocusGain(false)
                .build()
            focusRequest = request
            audioManager.requestAudioFocus(request) == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
        } else {
            legacyFocusListener = listener
            @Suppress("DEPRECATION")
            audioManager.requestAudioFocus(listener, AudioManager.STREAM_MUSIC, gain) ==
                AudioManager.AUDIOFOCUS_REQUEST_GRANTED
        }
    }

    private fun abandonFocus() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            focusRequest?.let(audioManager::abandonAudioFocusRequest)
        } else {
            @Suppress("DEPRECATION")
            legacyFocusListener?.let(audioManager::abandonAudioFocus)
        }
        focusRequest = null
        legacyFocusListener = null
    }

    private fun isActiveOperation(operationId: Long): Boolean {
        return operationId == activeOperationId &&
            operationGuard.isActiveOperation(operationId, activeResult != null)
    }

    private fun isCurrentSpeakerPlayer(
        player: MediaPlayer,
        operationId: Long,
        playerToken: Long,
    ): Boolean {
        return mediaPlayer === player &&
            operationGuard.isCurrentPlayer(operationId, playerToken, activeResult != null)
    }

    private fun installSpeakerRouteGuard(
        player: MediaPlayer,
        operationId: Long,
        playerToken: Long,
    ) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return
        val listener = AudioRouting.OnRoutingChangedListener { routing ->
            handler.post {
                if (routing !== player) return@post
                validateSpeakerRoute(player, operationId, playerToken)
            }
        }
        mediaRoutingListener = listener
        player.addOnRoutingChangedListener(listener, handler)
    }

    private fun validateSpeakerRoute(
        player: MediaPlayer,
        operationId: Long,
        playerToken: Long,
    ) {
        if (!isCurrentSpeakerPlayer(player, operationId, playerToken)) return
        val routed = player.routedDevice
        if (routed?.type != AudioDeviceInfo.TYPE_BUILTIN_SPEAKER) {
            finishError("speaker_route_unconfirmed", "No se pudo aplicar esta salida.", operationId)
        }
    }

    private fun scheduleTimeout(operationId: Long) {
        val timeout = Runnable {
            finishError("driving_audio_timeout", "El aviso de audio tardó demasiado.", operationId)
        }
        activeTimeout = timeout
        handler.postDelayed(timeout, 12_000)
    }

    private fun cancelTimeout() {
        activeTimeout?.let(handler::removeCallbacks)
        activeTimeout = null
    }

    private fun finishSuccess(operationId: Long) {
        if (!isActiveOperation(operationId)) return
        val result = activeResult ?: return
        activeResult = null
        activeOperationId = 0L
        operationGuard.clearOperation()
        cancelTimeout()
        stopPlaybackOnly()
        abandonFocus()
        result.success(null)
    }

    private fun finishError(code: String, message: String, operationId: Long) {
        if (!isActiveOperation(operationId)) return
        val result = activeResult ?: return
        activeResult = null
        activeOperationId = 0L
        operationGuard.clearOperation()
        cancelTimeout()
        stopPlaybackOnly()
        abandonFocus()
        result.error(code, message, null)
    }

    private fun stopInternal(completePending: Boolean) {
        val result = activeResult
        activeResult = null
        activeOperationId = 0L
        operationGuard.clearOperation()
        cancelTimeout()
        stopPlaybackOnly()
        abandonFocus()
        if (completePending) result?.success(null)
    }

    private fun stopPlaybackOnly() {
        handler.removeCallbacksAndMessages(null)
        tts?.stop()
        toneGenerator?.stopTone()
        toneGenerator?.release()
        toneGenerator = null
        releaseCurrentMediaPlayer(stop = true)
        activeUtteranceId = null
        speakerQueue.clear()
        temporaryFiles.forEach { it.delete() }
        temporaryFiles.clear()
        requestedSpeaker = null
        speakerVolume = 1.0f
    }

    private fun releaseCurrentMediaPlayer(stop: Boolean) {
        val player = mediaPlayer
        val listener = mediaRoutingListener
        mediaPlayer = null
        mediaRoutingListener = null
        operationGuard.clearCurrentPlayer()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && listener != null) {
            player?.removeOnRoutingChangedListener(listener)
        }
        if (stop) {
            try {
                player?.stop()
            } catch (_: Exception) {
                // Player may already be unprepared or completed.
            }
        }
        player?.release()
    }

    private fun createToneFile(
        prefix: String,
        volume: Double,
        silenceMs: Int,
        toneMs: Int,
    ): File {
        val sampleRate = 8_000
        val sampleCount = sampleRate * (silenceMs + toneMs) / 1_000
        val silenceSamples = sampleRate * silenceMs / 1_000
        val file = File.createTempFile(prefix, ".wav", context.cacheDir)
        temporaryFiles.add(file)
        RandomAccessFile(file, "rw").use { output ->
            val dataSize = sampleCount * 2
            output.writeBytes("RIFF")
            output.writeIntLE(36 + dataSize)
            output.writeBytes("WAVEfmt ")
            output.writeIntLE(16)
            output.writeShortLE(1)
            output.writeShortLE(1)
            output.writeIntLE(sampleRate)
            output.writeIntLE(sampleRate * 2)
            output.writeShortLE(2)
            output.writeShortLE(16)
            output.writeBytes("data")
            output.writeIntLE(dataSize)
            repeat(sampleCount) { index ->
                val sample = if (index < silenceSamples || toneMs == 0) {
                    0
                } else {
                    (sin(2 * PI * 880 * (index - silenceSamples) / sampleRate) *
                        Short.MAX_VALUE * volume).toInt()
                }
                output.writeShortLE(sample)
            }
        }
        return file
    }
}

private fun RandomAccessFile.writeIntLE(value: Int) {
    write(byteArrayOf(value.toByte(), (value shr 8).toByte(), (value shr 16).toByte(), (value shr 24).toByte()))
}

private fun RandomAccessFile.writeShortLE(value: Int) {
    write(byteArrayOf(value.toByte(), (value shr 8).toByte()))
}
