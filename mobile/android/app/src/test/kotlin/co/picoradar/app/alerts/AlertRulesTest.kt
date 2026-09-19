package co.picoradar.app.alerts

import org.junit.Assert.*
import org.junit.Test

class AlertRulesTest {
    private val now = 1_000_000L
    private fun event(id: Int = 7, scope: String = "pico", at: Long = now + 1000,
        expires: Long = now + 900_000) = AlertEvent(id, scope, at, expires, "/pico", "generation")

    @Test fun rebootAndClockChangeRestoreFutureOnly() {
        val events = listOf(event(at = now - 1), event(8, at = now), event(9),
            event(10, expires = now), event(11).copy(phase = AlertPhase.RINGING))
        assertEquals(listOf(9), AlertRules.future(events, now).map { it.id })
    }

    @Test fun lateOrExpiredCallbacksNeverRing() {
        assertFalse(AlertRules.canRing(event(at = now - 120_001), now))
        assertFalse(AlertRules.canRing(event(at = now - 1, expires = now), now))
        assertFalse(AlertRules.canRing(event(), now))
        assertTrue(AlertRules.canRing(event(at = now), now))
        assertFalse(AlertRules.canRing(event(at = now).copy(phase = AlertPhase.STAGED), now))
    }

    @Test fun snoozeUsesTenMinutesButCannotCrossExpiry() {
        assertEquals(now + 600_000, AlertRules.snooze(event(), now)?.at)
        assertNull(AlertRules.snooze(event(expires = now + 600_000), now))
        assertNull(AlertRules.snooze(event(), Long.MAX_VALUE - 10))
    }

    @Test fun ringDurationIsBoundedByExpiryAndTwoMinutes() {
        assertEquals(120_000L, AlertRules.ringMillis(event(), now))
        assertEquals(500L, AlertRules.ringMillis(event(expires = now + 500), now))
        assertEquals(0L, AlertRules.ringMillis(event(expires = now), now))
    }

    @Test fun scopeCancellationPreservesOtherCategory() {
        val events = listOf(event(), event(8, "obligations"))
        assertEquals(listOf(8), AlertRules.withoutScope(events, "pico").map { it.id })
        assertThrows(AlertFailure::class.java) { AlertRules.requireScope("all") }
    }

    @Test fun routesRejectExternalAndPrivatePayloadsAndStripLocalContext() {
        assertEquals("/apps/module/soat", AlertRules.route("/apps/module/soat?vehicleId=local-id&source=obligation_reminder"))
        for (route in listOf("https://host/pico", "//host/pico", "/pico?plate=ABC123",
            "/apps/module/documentos", "/pico#secret", "/pico/../garage")) {
            assertThrows(AlertFailure::class.java) { AlertRules.route(route) }
        }
    }

    @Test fun wireNumbersMustBeIntegralAndIdsMustFitCoordinatorContract() {
        fun args(id: Any, at: Any = now + 1000) = mapOf("id" to id, "at" to at,
            "expiresAt" to now + 900_000, "route" to "/pico")
        assertEquals(7, AlertRules.parse("pico", listOf(args(7L)), now).single().id)
        for (bad in listOf(0L, -1L, Int.MAX_VALUE.toLong() + 1, 1.5, "7")) {
            assertThrows(AlertFailure::class.java) { AlertRules.parse("pico", listOf(args(bad)), now) }
        }
        assertThrows(AlertFailure::class.java) { AlertRules.parse("pico", listOf(args(7, 1.5)), now) }
        assertThrows(AlertFailure::class.java) { AlertRules.parse("pico", listOf(args(7), args(7)), now) }
        assertTrue(AlertRules.parse("pico", listOf(args(7, now - 1)), now).isEmpty())
    }
}
