package co.picoradar.app

import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class DrivingAudioOperationGuardTest {
    @Test
    fun oldOperationCallbackCannotCompleteNewOperation() {
        val guard = DrivingAudioOperationGuard()

        guard.beginOperation(1L)
        guard.beginOperation(2L)

        assertFalse(guard.isActiveOperation(1L, hasPendingResult = true))
        assertTrue(guard.isActiveOperation(2L, hasPendingResult = true))
    }

    @Test
    fun oldPlayerCallbackCannotOwnReplacementPlayer() {
        val guard = DrivingAudioOperationGuard()

        guard.beginOperation(1L)
        val firstPlayer = guard.beginPlayer(1L, hasPendingResult = true)
        guard.beginOperation(2L)
        val secondPlayer = guard.beginPlayer(2L, hasPendingResult = true)

        assertNotEquals(firstPlayer, secondPlayer)
        assertFalse(guard.isCurrentPlayer(1L, firstPlayer, hasPendingResult = true))
        assertFalse(guard.isCurrentPlayer(2L, firstPlayer, hasPendingResult = true))
        assertTrue(guard.isCurrentPlayer(2L, secondPlayer, hasPendingResult = true))
    }

    @Test
    fun routeObservationRequiresCurrentPlayerAndPendingResult() {
        val guard = DrivingAudioOperationGuard()

        guard.beginOperation(7L)
        val player = guard.beginPlayer(7L, hasPendingResult = true)

        assertTrue(guard.isCurrentPlayer(7L, player, hasPendingResult = true))
        assertFalse(guard.isCurrentPlayer(7L, player, hasPendingResult = false))

        guard.clearCurrentPlayer()

        assertFalse(guard.isCurrentPlayer(7L, player, hasPendingResult = true))
    }

    @Test
    fun oldScheduledRouteCheckCannotInspectReplacementPlayerInSameOperation() {
        val guard = DrivingAudioOperationGuard()

        guard.beginOperation(9L)
        val firstPlayer = guard.beginPlayer(9L, hasPendingResult = true)
        val replacementPlayer = guard.beginPlayer(9L, hasPendingResult = true)

        assertNotEquals(firstPlayer, replacementPlayer)
        assertFalse(guard.isCurrentPlayer(9L, firstPlayer, hasPendingResult = true))
        assertTrue(guard.isCurrentPlayer(9L, replacementPlayer, hasPendingResult = true))
    }

    @Test
    fun routeChangeAfterInitialProbeStillRequiresCurrentPlayer() {
        val guard = DrivingAudioOperationGuard()

        guard.beginOperation(13L)
        val player = guard.beginPlayer(13L, hasPendingResult = true)

        assertTrue(guard.isCurrentPlayer(13L, player, hasPendingResult = true))

        guard.clearCurrentPlayer()

        assertFalse(guard.isCurrentPlayer(13L, player, hasPendingResult = true))
    }

    @Test
    fun timeoutCleanupDoesNotPoisonNextOperation() {
        val guard = DrivingAudioOperationGuard()

        guard.beginOperation(17L)
        val timedOutPlayer = guard.beginPlayer(17L, hasPendingResult = true)
        guard.clearOperation()
        guard.beginOperation(18L)
        val nextPlayer = guard.beginPlayer(18L, hasPendingResult = true)

        assertFalse(guard.isActiveOperation(17L, hasPendingResult = true))
        assertFalse(guard.isCurrentPlayer(17L, timedOutPlayer, hasPendingResult = true))
        assertTrue(guard.isActiveOperation(18L, hasPendingResult = true))
        assertTrue(guard.isCurrentPlayer(18L, nextPlayer, hasPendingResult = true))
    }

    @Test
    fun clearingOperationInvalidatesPendingPlayerCallbacks() {
        val guard = DrivingAudioOperationGuard()

        guard.beginOperation(11L)
        val player = guard.beginPlayer(11L, hasPendingResult = true)
        guard.clearOperation()

        assertFalse(guard.isActiveOperation(11L, hasPendingResult = true))
        assertFalse(guard.isCurrentPlayer(11L, player, hasPendingResult = true))
    }
}
