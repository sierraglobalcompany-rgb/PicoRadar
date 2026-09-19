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
        val missed = mutableListOf<AlertEvent>()
        var denied = false
        var failId: Int? = null
        override fun requireAccess() { if (denied) throw AlertFailure("EXACT_ACCESS_REQUIRED") }
        override fun schedule(event: AlertEvent) {
            if (event.id == failId) throw AlertFailure("SCHEDULE_FAILED")
            scheduled[event.id] = event
        }
        override fun cancel(event: AlertEvent) { scheduled.remove(event.id) }
        override fun missed(event: AlertEvent) { missed.add(event) }
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
        assertEquals(listOf(9, 10), store.state.events.filter { it.phase != AlertPhase.MISSED }.map { it.id })
        assertEquals(listOf(7), alarms.missed.map { it.id })
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

    @Test fun aggregateCapacityRejectsWholeReplacementAndPreservesBothScopes() {
        val store = MemoryStore(); val alarms = FakeAlarms(); val engine = AlertEngine(store, alarms) { now }
        engine.reschedule("obligations", (1..100).map { event(it, "obligations") })
        engine.reschedule("pico", (101..128).map { event(it) })
        val before = store.state
        val scheduledBefore = alarms.scheduled.toMap()
        assertEquals("TOO_MANY_EVENTS", assertThrows(AlertFailure::class.java) {
            engine.reschedule("pico", (201..229).map { event(it) })
        }.code)
        assertEquals(before, store.state)
        assertEquals(scheduledBefore, alarms.scheduled)
        assertEquals(128, engine.pending().size)
    }

    @Test fun testUsesSeparateSlotAndOversizedEngineBatchHasTypedError() {
        val store = MemoryStore(); val alarms = FakeAlarms(); val engine = AlertEngine(store, alarms) { now }
        engine.reschedule("obligations", (1..127).map { event(it, "obligations") })
        engine.test()
        assertEquals(listOf(128), engine.reschedule("pico", listOf(event(128))))
        assertEquals("TOO_MANY_EVENTS", assertThrows(AlertFailure::class.java) {
            engine.reschedule("pico", (201..329).map { event(it) })
        }.code)
        assertEquals(129, store.state.events.size)
    }

    @Test fun ownerSurvivesRestoreClaimAndSnooze() {
        var clock = now
        val store = MemoryStore(); val alarms = FakeAlarms(); val engine = AlertEngine(store, alarms) { clock }
        val route = AlertRules.route("/apps/module/soat?vehicleId=owner_2&source=obligation_reminder")
        engine.reschedule("obligations", listOf(event(7, "obligations").copy(route = route)))
        engine.restore()
        clock += 1000
        val ringing = engine.claim(7, "token-7")!!
        assertEquals("/apps/module/soat?vehicleId=owner_2", ringing.route)
        engine.snooze(ringing.id, ringing.token)
        assertEquals(ringing.route, alarms.scheduled[7]?.route)
    }

    @Test fun reconcileRetainsRingingAndSnoozeButOwnerEditCancels() {
        var clock = now
        val store = MemoryStore(); val alarms = FakeAlarms(); val engine = AlertEngine(store, alarms) { clock }
        val original = event(7)
        engine.reschedule("pico", listOf(original))
        clock += 1000
        engine.claim(7, original.token)
        assertEquals(listOf(7), engine.reschedule("pico", listOf(original.copy(token = "new"))))
        assertEquals(AlertPhase.RINGING, engine.find(7, original.token)?.phase)
        engine.snooze(7, original.token)
        val snoozed = store.state.events.single()
        clock += 1000
        assertEquals(listOf(7), engine.reschedule("pico", listOf(original)))
        assertEquals(snoozed, store.state.events.single())
        assertEquals(listOf(7), engine.pending())
        engine.reschedule("pico", listOf(original.copy(route = "/pico?vehicleId=other")))
        assertTrue(store.state.events.isEmpty())
    }

    @Test fun reconcilePreservesDueTokenButNeverInstallsUnmatchedPast() {
        var clock = now
        val store = MemoryStore(); val alarms = FakeAlarms(); val engine = AlertEngine(store, alarms) { clock }
        val original = event(7)
        engine.reschedule("pico", listOf(original))
        clock += 1000
        assertEquals(listOf(7), engine.reschedule("pico", listOf(original.copy(token = "new"), event(8, at = clock - 1))))
        assertNotNull(engine.claim(7, original.token))
        assertNull(engine.find(8, "token-8"))
    }

    @Test fun successfulWritesDoNotEraseUnobservedAsyncFailure() {
        val store = MemoryStore(); val alarms = FakeAlarms(); val engine = AlertEngine(store, alarms) { now }
        engine.recordFailure("PLAYBACK_FAILED")
        engine.reschedule("pico", listOf(event(7)))
        engine.cancel("pico")
        engine.test()
        assertEquals("PLAYBACK_FAILED", assertThrows(AlertFailure::class.java) { engine.pending() }.code)
    }

    @Test fun cutoffAndInterruptionCreateOneMissedNoticeWithoutReplay() {
        for (reason in listOf(AlertEnd.CUTOFF, AlertEnd.INTERRUPTED)) {
            var clock = now
            val store = MemoryStore(); val alarms = FakeAlarms(); val engine = AlertEngine(store, alarms) { clock }
            val original = event(7)
            engine.reschedule("pico", listOf(original)); clock += 1000; engine.claim(7, original.token)
            engine.finish(7, original.token, reason)
            engine.finish(7, original.token, reason)
            assertEquals(listOf(7), alarms.missed.map { it.id })
            assertEquals(AlertPhase.MISSED, engine.find(7, original.token)?.phase)
            assertNull(engine.claim(7, original.token))
            assertTrue(engine.reschedule("pico", listOf(original)).isEmpty())
            assertTrue(engine.pending().isEmpty())
            assertTrue(engine.restore().isEmpty())
            assertEquals(1, alarms.missed.size)
            assertEquals(AlertPhase.MISSED, engine.find(7, original.token)?.phase)
        }
    }

    @Test fun explicitStopSnoozeAndCancelledGenerationNeverPostMissed() {
        for (action in listOf("stop", "snooze", "cancel")) {
            var clock = now
            val store = MemoryStore(); val alarms = FakeAlarms(); val engine = AlertEngine(store, alarms) { clock }
            engine.reschedule("pico", listOf(event(7))); clock += 1000; engine.claim(7, "token-7")
            when (action) {
                "stop" -> engine.finish(7, "token-7", AlertEnd.STOP)
                "snooze" -> engine.snooze(7, "token-7")
                else -> engine.cancel("pico")
            }
            engine.finish(7, "token-7", AlertEnd.INTERRUPTED)
            assertTrue(alarms.missed.isEmpty())
            if (action == "snooze") assertEquals(now + 1000, store.state.events.single().originalAt)
        }
    }

    @Test fun explicitStatusObservesFailureAndTestAcknowledgementIsNotPlayback() {
        val store = MemoryStore(); val alarms = FakeAlarms(); val engine = AlertEngine(store, alarms) { now }
        assertEquals("idle", engine.status()["testState"])
        val test = engine.test()
        assertEquals("starting", engine.status()["testState"])
        engine.claim(test.id, test.token)
        engine.playing(test.id, test.token)
        assertEquals("ringing", engine.status()["testState"])
        engine.recordFailure("PLAYBACK_FAILED")
        engine.finish(test.id, test.token, AlertEnd.INTERRUPTED)
        engine.reschedule("pico", listOf(event(7)))
        assertEquals(mapOf("testState" to "failed", "failureCode" to "PLAYBACK_FAILED"), engine.status())
        assertNull(engine.status()["failureCode"])
        assertEquals(listOf(7), engine.pending())
        engine.recordFailure("unsafe route or display data")
        assertEquals("ALARM_OPERATION_FAILED", engine.status()["failureCode"])
    }

    @Test fun pendingDoesNotConsumeFailureAndItSurvivesProcessRecreation() {
        val store = MemoryStore(); val alarms = FakeAlarms(); val engine = AlertEngine(store, alarms) { now }
        engine.recordFailure("PLAYBACK_FAILED")
        engine.reschedule("pico", listOf(event(7)))
        val restarted = AlertEngine(store, alarms) { now }
        restarted.restore()
        repeat(2) { assertEquals("PLAYBACK_FAILED", assertThrows(AlertFailure::class.java) { restarted.pending() }.code) }
        assertEquals("PLAYBACK_FAILED", restarted.status()["failureCode"])
        assertEquals(listOf(7), restarted.pending())
    }

    @Test fun storedFailureCannotBeOverwrittenByLaterFailureBeforeObservation() {
        val store = MemoryStore(); val alarms = FakeAlarms(); val engine = AlertEngine(store, alarms) { now }
        engine.recordFailure("PLAYBACK_FAILED")
        val restarted = AlertEngine(store, alarms) { now }
        alarms.failId = 7
        assertThrows(AlertFailure::class.java) { restarted.reschedule("pico", listOf(event(7))) }
        restarted.recordFailure("SCHEDULE_FAILED")
        assertEquals("PLAYBACK_FAILED", restarted.status()["failureCode"])
    }

    @Test fun deleteDateEditAndExpiryCancelSnoozedIdentityButOrdinaryReconcileNeverMovesIt() {
        for (change in listOf("delete", "date", "expiry")) {
            var clock = now
            val store = MemoryStore(); val alarms = FakeAlarms(); val engine = AlertEngine(store, alarms) { clock }
            val original = event(7)
            engine.reschedule("pico", listOf(original)); clock += 1000; engine.claim(7, original.token)
            engine.snooze(7, original.token)
            val snoozed = store.state.events.single()
            clock += 20_000
            engine.reschedule("pico", listOf(original.copy(token = "unused")))
            assertEquals(snoozed, alarms.scheduled[7])
            when (change) {
                "delete" -> engine.reschedule("pico", emptyList())
                "date" -> engine.reschedule("pico", listOf(original.copy(at = clock + 1000, originalAt = clock + 1000)))
                else -> { clock = original.expiresAt; engine.reschedule("pico", listOf(original)) }
            }
            assertNull(engine.find(7, snoozed.token))
            assertNull(engine.claim(7, snoozed.token))
        }
    }

    @Test fun sharedSnoozeFixtureKeepsOriginalTargetAndRebootRestoresOnlyFutureSnooze() {
        var clock = now - 1
        val store = MemoryStore(); val alarms = FakeAlarms(); val engine = AlertEngine(store, alarms) { clock }
        val original = event(7, at = now)
        engine.reschedule("pico", listOf(original))
        clock = now; engine.claim(7, original.token)
        clock = now + 10_000; engine.snooze(7, original.token)
        val snoozed = store.state.events.single()
        assertEquals(now + 610_000, snoozed.at)
        assertEquals(now, snoozed.originalAt)
        clock = now + 20_000
        assertEquals(listOf(7), engine.reschedule("pico", listOf(original.copy(token = "new"))))
        assertEquals(snoozed, store.state.events.single())
        engine.restore()
        assertEquals(snoozed, alarms.scheduled[7])
        clock = snoozed.at
        assertNotNull(engine.claim(7, snoozed.token))
        engine.finish(7, snoozed.token, AlertEnd.CUTOFF)
        engine.restore()
        assertTrue(alarms.scheduled.isEmpty())
    }

    @Test fun failedStatusPersistenceDoesNotConsumeTheError() {
        val store = MemoryStore(); val alarms = FakeAlarms(); val engine = AlertEngine(store, alarms) { now }
        engine.recordFailure("PLAYBACK_FAILED")
        store.failWrite = true
        assertThrows(AlertFailure::class.java) { engine.status() }
        store.failWrite = false
        assertEquals("PLAYBACK_FAILED", engine.status()["failureCode"])
    }

    @Test fun interruptedRecoveryPostsOnceAndDoesNotBlockAnotherRing() {
        val store = MemoryStore(); val alarms = FakeAlarms(); val engine = AlertEngine(store, alarms) { now }
        store.state = AlertProjection(listOf(event(7, at = now).copy(phase = AlertPhase.RINGING)))
        engine.recoverInterrupted()
        engine.recoverInterrupted()
        engine.restore()
        assertEquals(listOf(7), alarms.missed.map { it.id })
        assertEquals("ALARM_INTERRUPTED", engine.status()["failureCode"])
        assertTrue(engine.pending().isEmpty())
        assertNotNull(engine.claim(engine.test().id, store.state.events.last().token))
    }
}
