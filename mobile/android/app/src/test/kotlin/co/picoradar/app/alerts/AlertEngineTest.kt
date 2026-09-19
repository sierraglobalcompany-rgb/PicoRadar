package co.picoradar.app.alerts

import org.junit.Assert.*
import org.junit.Test

class AlertEngineTest {
    private val now = 1_000_000L
    private fun event(id: Int, scope: String = "pico", at: Long = now + 1000) =
        AlertEvent(id, scope, at, now + 900_000, "/pico", "token-$id")
    private class MemoryStore : AlertStore {
        var state = AlertProjection()
        var failWrite = false
        override fun read() = state
        override fun write(value: AlertProjection) {
            if (failWrite) throw AlertFailure("STORAGE_FAILED")
            state = value
        }
    }
    private class FakeAlarms : AlertAlarms {
        val scheduled = mutableMapOf<Int, AlertEvent>()
        var denied = false
        var failId: Int? = null
        override fun requireAccess() { if (denied) throw AlertFailure("EXACT_ACCESS_REQUIRED") }
        override fun schedule(event: AlertEvent) {
            if (event.id == failId) throw AlertFailure("SCHEDULE_FAILED")
            scheduled[event.id] = event
        }
        override fun cancel(event: AlertEvent) { scheduled.remove(event.id) }
    }

    @Test fun replaceAndCancelOnlyOwnScope() {
        val store = MemoryStore(); val alarms = FakeAlarms(); val engine = AlertEngine(store, alarms) { now }
        engine.reschedule("obligations", listOf(event(8, "obligations")))
        assertEquals(listOf(7), engine.reschedule("pico", listOf(event(7))))
        engine.cancel("pico")
        assertEquals(listOf(8), engine.pending())
        assertEquals(setOf(8), alarms.scheduled.keys)
    }

    @Test fun failedBatchDoesNotReportOrLeavePartialSuccess() {
        val store = MemoryStore(); val alarms = FakeAlarms(); val engine = AlertEngine(store, alarms) { now }
        engine.reschedule("obligations", listOf(event(8, "obligations")))
        alarms.failId = 9
        assertEquals("SCHEDULE_FAILED", assertThrows(AlertFailure::class.java) {
            engine.reschedule("pico", listOf(event(7), event(9)))
        }.code)
        assertEquals(listOf(8), store.state.events.map { it.id })
        assertEquals(setOf(8), alarms.scheduled.keys)
    }

    @Test fun deniedAccessDoesNotCancelAnotherCategoryOrDowngrade() {
        val store = MemoryStore(); val alarms = FakeAlarms(); val engine = AlertEngine(store, alarms) { now }
        engine.reschedule("obligations", listOf(event(8, "obligations")))
        alarms.denied = true
        assertThrows(AlertFailure::class.java) { engine.reschedule("pico", listOf(event(7))) }
        assertEquals(setOf(8), alarms.scheduled.keys)
        assertThrows(AlertFailure::class.java) { engine.pending() }
        engine.cancel("obligations")
        assertTrue(alarms.scheduled.isEmpty())
    }

    @Test fun storageFailurePreventsAnyPlatformScheduling() {
        val store = MemoryStore(); val alarms = FakeAlarms(); val engine = AlertEngine(store, alarms) { now }
        store.failWrite = true
        assertThrows(AlertFailure::class.java) { engine.reschedule("pico", listOf(event(7))) }
        assertTrue(alarms.scheduled.isEmpty())
    }

    @Test fun idCollisionBetweenCategoriesFailsBeforeMutation() {
        val store = MemoryStore(); val alarms = FakeAlarms(); val engine = AlertEngine(store, alarms) { now }
        engine.reschedule("obligations", listOf(event(8, "obligations")))
        assertEquals("ID_CONFLICT", assertThrows(AlertFailure::class.java) {
            engine.reschedule("pico", listOf(event(8)))
        }.code)
        assertEquals("obligations", alarms.scheduled[8]?.scope)
    }

    @Test fun staleCallbacksAndDuplicateDeliveryAreIgnored() {
        var clock = now
        val store = MemoryStore(); val alarms = FakeAlarms(); val engine = AlertEngine(store, alarms) { clock }
        val old = event(7)
        val replacement = old.copy(token = "replacement")
        engine.reschedule("pico", listOf(old))
        engine.reschedule("pico", listOf(replacement))
        clock += 1000
        assertNull(engine.claim(old.id, old.token))
        assertNotNull(engine.claim(replacement.id, replacement.token))
        assertNull(engine.claim(replacement.id, replacement.token))
    }

    @Test fun restoringDropsMissedRingingAndStagedEventsWithoutBurst() {
        val store = MemoryStore(); val alarms = FakeAlarms(); val engine = AlertEngine(store, alarms) { now }
        store.state = AlertProjection(listOf(event(1, at = now - 1), event(2),
            event(3).copy(phase = AlertPhase.RINGING), event(4).copy(phase = AlertPhase.STAGED)))
        assertEquals(listOf(2), engine.restore())
        assertEquals(setOf(2), alarms.scheduled.keys)
    }

    @Test fun onlyOneClaimCanRingAndStopIsGenerationSpecific() {
        var clock = now
        val store = MemoryStore(); val alarms = FakeAlarms(); val engine = AlertEngine(store, alarms) { clock }
        engine.reschedule("pico", listOf(event(7), event(9)))
        clock += 1000
        assertNotNull(engine.claim(7, "token-7"))
        assertNull(engine.claim(9, "token-9"))
        assertFalse(engine.stop(7, "old"))
        assertTrue(engine.stop(7, "token-7"))
        assertTrue(store.state.events.isEmpty())
    }

    @Test fun pendingPrunesExpiredProjectionWithoutKeepingHistory() {
        val store = MemoryStore(); val alarms = FakeAlarms(); val engine = AlertEngine(store, alarms) { now }
        store.state = AlertProjection(listOf(event(7, at = now - 1000).copy(expiresAt = now)))
        assertTrue(engine.pending().isEmpty())
        assertTrue(store.state.events.isEmpty())
    }

    @Test fun processDeathDoesNotLeaveAnImmortalRingingLockOrRestoreStagedWork() {
        val store = MemoryStore(); val alarms = FakeAlarms(); val engine = AlertEngine(store, alarms) { now }
        store.state = AlertProjection(listOf(event(7).copy(phase = AlertPhase.RINGING),
            event(8).copy(phase = AlertPhase.STAGED), event(9), event(10, at = now - 1)))
        engine.recoverInterrupted()
        assertEquals(listOf(9, 10), store.state.events.map { it.id })
        assertEquals("ALARM_INTERRUPTED", store.state.failure)
        assertNotNull(engine.claim(10, "token-10"))
    }

    @Test fun snoozeFailureStopsOldEventAndReportsExpiry() {
        var clock = now
        val store = MemoryStore(); val alarms = FakeAlarms(); val engine = AlertEngine(store, alarms) { clock }
        engine.reschedule("pico", listOf(event(7).copy(expiresAt = now + 5000)))
        clock += 1000
        engine.claim(7, "token-7")
        assertEquals("EVENT_EXPIRED", assertThrows(AlertFailure::class.java) { engine.snooze(7, "token-7") }.code)
        assertTrue(store.state.events.isEmpty())
    }

    @Test fun testIsExplicitFictionalAndCannotOverwriteCoordinatorIds() {
        val store = MemoryStore(); val alarms = FakeAlarms(); val engine = AlertEngine(store, alarms) { now }
        engine.reschedule("pico", listOf(event(7)))
        val test = engine.test()
        assertEquals("test", test.scope)
        assertEquals(-1, test.id)
        assertEquals(listOf(7), engine.pending())
        assertNotNull(engine.claim(test.id, test.token))
        assertEquals("ALARM_BUSY", assertThrows(AlertFailure::class.java) { engine.test() }.code)
    }

    @Test fun aSlowProjectionWriteCannotConfirmEventsNowInThePast() {
        var clock = now
        val memory = MemoryStore()
        val store = object : AlertStore {
            override fun read() = memory.read()
            override fun write(value: AlertProjection) {
                memory.write(value)
                if (value.events.any { it.phase == AlertPhase.STAGED }) clock += 5000
            }
        }
        val alarms = FakeAlarms(); val engine = AlertEngine(store, alarms) { clock }
        assertTrue(engine.reschedule("pico", listOf(event(7))).isEmpty())
        assertTrue(alarms.scheduled.isEmpty())
    }

    @Test fun cancellationWaitsForAnInProgressWriteAndWins() {
        val entered = java.util.concurrent.CountDownLatch(1)
        val resume = java.util.concurrent.CountDownLatch(1)
        val memory = MemoryStore()
        val store = object : AlertStore {
            override fun read() = memory.read()
            override fun write(value: AlertProjection) {
                if (value.events.any { it.phase == AlertPhase.STAGED }) {
                    entered.countDown()
                    check(resume.await(5, java.util.concurrent.TimeUnit.SECONDS))
                }
                memory.write(value)
            }
        }
        val alarms = FakeAlarms(); val engine = AlertEngine(store, alarms) { now }
        val failure = java.util.concurrent.atomic.AtomicReference<Throwable?>()
        val schedule = Thread { try { engine.reschedule("pico", listOf(event(7))) } catch (e: Throwable) { failure.set(e) } }
        schedule.start()
        assertTrue(entered.await(5, java.util.concurrent.TimeUnit.SECONDS))
        val cancel = Thread { try { engine.cancel("pico") } catch (e: Throwable) { failure.set(e) } }
        cancel.start()
        resume.countDown()
        schedule.join(5000); cancel.join(5000)
        assertFalse(schedule.isAlive); assertFalse(cancel.isAlive)
        assertNull(failure.get())
        assertTrue(engine.pending().isEmpty())
        assertTrue(alarms.scheduled.isEmpty())
    }
}
