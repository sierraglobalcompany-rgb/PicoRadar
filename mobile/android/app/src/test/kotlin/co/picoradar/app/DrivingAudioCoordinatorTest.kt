package co.picoradar.app

import android.content.Context
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.media.AudioRouting
import android.media.MediaPlayer
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.TimeUnit
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.shadows.AudioDeviceInfoBuilder

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28])
class DrivingAudioCoordinatorTest {
    private val coordinators = mutableListOf<DrivingAudioCoordinator>()

    @After
    fun tearDown() {
        coordinators.forEach { it.destroy() }
        shadowOf(RuntimeEnvironment.getApplication().mainLooper).idle()
    }

    @Test
    @Config(sdk = [25])
    fun oldFocusCallbackCannotDamageReplacementOperation() {
        val coordinator = coordinator()
        val oldResult = RecordingResult()
        beginOperation(coordinator, operationId = 1L, result = oldResult)

        assertTrue(
            coordinator.callPrivate<Boolean>(
                "requestFocus",
                arrayOf(String::class.java, Long::class.javaPrimitiveType),
                "duck",
                1L,
            ),
        )
        val oldListener = coordinator.field<AudioManager.OnAudioFocusChangeListener>("legacyFocusListener")
        assertNotNull(oldListener)

        val replacementResult = RecordingResult()
        beginOperation(coordinator, operationId = 2L, result = replacementResult)
        oldListener.onAudioFocusChange(AudioManager.AUDIOFOCUS_LOSS)
        shadowOf(RuntimeEnvironment.getApplication().mainLooper).idle()

        assertEquals(emptyList<String>(), oldResult.errors)
        assertEquals(emptyList<String>(), replacementResult.errors)
        assertSame(replacementResult, coordinator.field<MethodChannel.Result>("activeResult"))
        assertEquals(2L, coordinator.field<Long>("activeOperationId"))
    }

    @Test
    fun oldPlayerRouteCheckCannotDamageReplacementPlayerInSameOperation() {
        val coordinator = coordinator()
        val result = RecordingResult()
        beginOperation(coordinator, operationId = 7L, result = result)

        val oldPlayer = MediaPlayer()
        val oldToken = beginPlayer(coordinator, operationId = 7L)
        coordinator.setField("mediaPlayer", oldPlayer)

        val replacementPlayer = MediaPlayer()
        val replacementToken = beginPlayer(coordinator, operationId = 7L)
        coordinator.setField("mediaPlayer", replacementPlayer)

        coordinator.callPrivateVoid(
            "validateSpeakerRoute",
            arrayOf(MediaPlayer::class.java, Long::class.javaPrimitiveType, Long::class.javaPrimitiveType),
            oldPlayer,
            7L,
            oldToken,
        )

        assertEquals(emptyList<String>(), result.errors)
        assertSame(replacementPlayer, coordinator.field<MediaPlayer>("mediaPlayer"))
        assertTrue(operationGuard(coordinator).isCurrentPlayer(7L, replacementToken, hasPendingResult = true))
    }

    @Test
    fun currentRoutingFailureCompletesOnceAndCleansUpListenerAndPlayer() {
        val coordinator = coordinator()
        val result = RecordingResult()
        beginOperation(coordinator, operationId = 11L, result = result)
        val player = MediaPlayer()
        val token = beginPlayer(coordinator, operationId = 11L)
        coordinator.setField("mediaPlayer", player)

        coordinator.callPrivateVoid(
            "installSpeakerRouteGuard",
            arrayOf(MediaPlayer::class.java, Long::class.javaPrimitiveType, Long::class.javaPrimitiveType),
            player,
            11L,
            token,
        )

        assertNotNull(coordinator.field<AudioRouting.OnRoutingChangedListener>("mediaRoutingListener"))

        coordinator.callPrivateVoid(
            "validateSpeakerRoute",
            arrayOf(MediaPlayer::class.java, Long::class.javaPrimitiveType, Long::class.javaPrimitiveType),
            player,
            11L,
            token,
        )
        coordinator.callPrivateVoid(
            "validateSpeakerRoute",
            arrayOf(MediaPlayer::class.java, Long::class.javaPrimitiveType, Long::class.javaPrimitiveType),
            player,
            11L,
            token,
        )

        assertEquals(listOf("speaker_route_unconfirmed"), result.errors)
        assertNull(coordinator.fieldNullable<MethodChannel.Result>("activeResult"))
        assertEquals(0L, coordinator.field<Long>("activeOperationId"))
        assertNull(coordinator.fieldNullable<MediaPlayer>("mediaPlayer"))
        assertNull(coordinator.fieldNullable<AudioRouting.OnRoutingChangedListener>("mediaRoutingListener"))
        assertFalse(operationGuard(coordinator).isCurrentPlayer(11L, token, hasPendingResult = true))
    }

    @Test
    fun timeoutCleansTemporariesAndAllowsNextOperation() {
        val coordinator = coordinator()
        val result = RecordingResult()
        val temporaryFile = File.createTempFile(
            "picoradar-timeout-",
            ".wav",
            RuntimeEnvironment.getApplication().cacheDir,
        )
        coordinator.field<MutableList<File>>("temporaryFiles").add(temporaryFile)
        beginOperation(coordinator, operationId = 17L, result = result)

        coordinator.callPrivateVoid("scheduleTimeout", arrayOf(Long::class.javaPrimitiveType), 17L)
        shadowOf(RuntimeEnvironment.getApplication().mainLooper).idleFor(12, TimeUnit.SECONDS)

        assertEquals(listOf("driving_audio_timeout"), result.errors)
        assertFalse(temporaryFile.exists())
        assertNull(coordinator.fieldNullable<MethodChannel.Result>("activeResult"))
        assertEquals(0L, coordinator.field<Long>("activeOperationId"))

        val nextResult = RecordingResult()
        beginOperation(coordinator, operationId = 18L, result = nextResult)

        assertSame(nextResult, coordinator.field<MethodChannel.Result>("activeResult"))
        assertEquals(18L, coordinator.field<Long>("activeOperationId"))
        assertTrue(operationGuard(coordinator).isActiveOperation(18L, hasPendingResult = true))
    }

    @Test
    fun exceptionPreparingSpeakerFileCompletesOnceAndCannotDamageNextOperation() {
        val coordinator = coordinator()
        val result = RecordingResult()
        beginOperation(coordinator, operationId = 23L, result = result)
        coordinator.setField("requestedSpeaker", builtInSpeakerDevice())
        coordinator.setField(
            "speakerQueue",
            ArrayDeque(listOf(File(RuntimeEnvironment.getApplication().cacheDir, "missing.wav"))),
        )

        coordinator.callPrivateVoid(
            "playNextSpeakerFile",
            arrayOf(Float::class.javaPrimitiveType, Long::class.javaPrimitiveType),
            1.0f,
            23L,
        )
        shadowOf(RuntimeEnvironment.getApplication().mainLooper).idleFor(12, TimeUnit.SECONDS)

        assertEquals(listOf("speaker_playback_failed"), result.errors)
        assertNull(coordinator.fieldNullable<MethodChannel.Result>("activeResult"))

        val nextResult = RecordingResult()
        beginOperation(coordinator, operationId = 24L, result = nextResult)
        coordinator.callPrivateVoid(
            "finishError",
            arrayOf(String::class.java, String::class.java, Long::class.javaPrimitiveType),
            "late",
            "late",
            23L,
        )
        shadowOf(RuntimeEnvironment.getApplication().mainLooper).idle()

        assertEquals(emptyList<String>(), nextResult.errors)
        assertSame(nextResult, coordinator.field<MethodChannel.Result>("activeResult"))
        assertEquals(24L, coordinator.field<Long>("activeOperationId"))
    }

    private fun coordinator(): DrivingAudioCoordinator {
        return DrivingAudioCoordinator(RuntimeEnvironment.getApplication()).also {
            coordinators.add(it)
        }
    }

    private fun beginOperation(coordinator: DrivingAudioCoordinator, operationId: Long, result: MethodChannel.Result) {
        operationGuard(coordinator).beginOperation(operationId)
        coordinator.setField("activeOperationId", operationId)
        coordinator.setField("activeResult", result)
    }

    private fun beginPlayer(coordinator: DrivingAudioCoordinator, operationId: Long): Long {
        return operationGuard(coordinator).beginPlayer(operationId, hasPendingResult = true)
    }

    private fun operationGuard(coordinator: DrivingAudioCoordinator): DrivingAudioOperationGuard {
        return coordinator.field("operationGuard")
    }

    private fun builtInSpeakerDevice(): AudioDeviceInfo {
        return AudioDeviceInfoBuilder.newBuilder()
            .setType(AudioDeviceInfo.TYPE_BUILTIN_SPEAKER)
            .build()
    }

    private inline fun <reified T> DrivingAudioCoordinator.field(name: String): T {
        val target = DrivingAudioCoordinator::class.java.getDeclaredField(name)
        target.isAccessible = true
        return target.get(this) as T
    }

    private inline fun <reified T> DrivingAudioCoordinator.fieldNullable(name: String): T? {
        val target = DrivingAudioCoordinator::class.java.getDeclaredField(name)
        target.isAccessible = true
        return target.get(this) as T?
    }

    private fun DrivingAudioCoordinator.setField(name: String, value: Any?) {
        val target = DrivingAudioCoordinator::class.java.getDeclaredField(name)
        target.isAccessible = true
        target.set(this, value)
    }

    private inline fun <reified T> DrivingAudioCoordinator.callPrivate(
        name: String,
        parameterTypes: Array<Class<*>?>,
        vararg args: Any?,
    ): T {
        val method = DrivingAudioCoordinator::class.java.getDeclaredMethod(name, *parameterTypes)
        method.isAccessible = true
        return method.invoke(this, *args) as T
    }

    private fun DrivingAudioCoordinator.callPrivateVoid(
        name: String,
        parameterTypes: Array<Class<*>?>,
        vararg args: Any?,
    ) {
        val method = DrivingAudioCoordinator::class.java.getDeclaredMethod(name, *parameterTypes)
        method.isAccessible = true
        method.invoke(this, *args)
    }

    private class RecordingResult : MethodChannel.Result {
        val errors = mutableListOf<String>()
        val successes = mutableListOf<Any?>()

        override fun success(result: Any?) {
            successes.add(result)
        }

        override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
            errors.add(errorCode)
        }

        override fun notImplemented() = Unit
    }
}
