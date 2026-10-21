package co.picoradar.app.alerts

import org.junit.Assert.*
import org.junit.Test

class AlertSessionTest {
    @Test fun replacementInvalidatesOldCallbacksBeforeReleasingAndAssigningNext() {
        var releases = 0
        var staleGeneration = 0L
        lateinit var session: AlertSession
        session = AlertSession {
            releases++
            assertNull(session.event)
            assertFalse(session.isCurrent(staleGeneration))
        }
        val a = AlertEvent(1, "pico", 1, 900, "/pico", "a")
        staleGeneration = session.begin(a)
        val b = a.copy(id = 2, token = "b")
        val current = session.begin(b)
        assertEquals(1, releases)
        assertFalse(session.isCurrent(staleGeneration))
        assertTrue(session.isCurrent(current))
        assertEquals(b, session.event)
        assertEquals(b, session.clear())
        assertFalse(session.isCurrent(current))
        assertNull(session.clear())
        assertEquals(2, releases)
    }

    @Test fun oldMediaFocusDeadlineAndWatchdogCallbacksCannotStopNextSession() {
        var releases = 0
        val session = AlertSession { releases++ }
        val a = AlertEvent(1, "pico", 1, 900, "/pico", "a")
        val old = session.begin(a)
        val callbacks = (1..4).map { { if (session.isCurrent(old)) session.clear() } }
        val next = session.begin(a.copy(id = 2, token = "b"))
        callbacks.forEach { it() }
        assertTrue(session.isCurrent(next))
        assertEquals(1, releases)
    }
}
