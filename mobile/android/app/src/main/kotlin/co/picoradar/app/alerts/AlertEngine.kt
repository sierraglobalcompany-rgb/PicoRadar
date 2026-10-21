package co.picoradar.app.alerts

internal data class AlertProjection(val events: List<AlertEvent> = emptyList(), val failure: String? = null)
internal interface AlertStore {
    fun read(): AlertProjection
    fun write(value: AlertProjection)
}
internal interface AlertAlarms {
    fun requireAccess()
    fun schedule(event: AlertEvent)
    fun cancel(event: AlertEvent)
    fun missed(event: AlertEvent)
}

// All bridge, receiver and service callers share this monitor in the default app process.
internal class AlertEngine(
    private val store: AlertStore,
    private val alarms: AlertAlarms,
    private val now: () -> Long = System::currentTimeMillis,
) {
    private var volatileFailure: String? = null
    private var testState = "idle"

    private fun save(value: AlertProjection) {
        store.write(value.copy(failure = store.read().failure ?: volatileFailure ?: value.failure))
    }

    @Synchronized fun recoverInterrupted() {
        val state = store.read()
        val interrupted = state.events.filter { it.phase == AlertPhase.RINGING && it.expiresAt > now() }
        val dropped = state.events.filter { it.phase == AlertPhase.STAGED || it.expiresAt <= now() }
        if (dropped.isEmpty() && interrupted.isEmpty()) return
        save(state.copy(events = state.events - dropped.toSet() - interrupted.toSet() +
            interrupted.map { it.copy(phase = AlertPhase.MISSED) }))
        cancelAll(dropped)
        if (interrupted.isNotEmpty()) recordFailure("ALARM_INTERRUPTED")
        interrupted.forEach { alarms.cancel(it); alarms.missed(it.copy(phase = AlertPhase.MISSED)) }
    }

    @Synchronized fun reschedule(scope: String, events: List<AlertEvent>): List<Int> {
        AlertRules.requireScope(scope)
        if (events.any { it.scope != scope }) throw AlertFailure("INVALID_ARGUMENTS")
        if (events.size > AlertRules.MAX_EVENTS) throw AlertFailure("TOO_MANY_EVENTS")
        val state = store.read()
        val others = AlertRules.withoutScope(state.events, scope)
        if (events.map { it.id }.distinct().size != events.size ||
            events.any { item -> others.any { it.id == item.id } }) throw AlertFailure("ID_CONFLICT")
        val previous = state.events.filter { it.scope == scope }
        val retained = previous.filter { old ->
            old.expiresAt > now() && events.any { next ->
                next.id == old.id && next.at == old.originalAt && next.expiresAt == old.expiresAt && next.route == old.route
            } && (old.phase in setOf(AlertPhase.RINGING, AlertPhase.SNOOZED, AlertPhase.MISSED) ||
                AlertRules.canRing(old, now()))
        }
        val incoming = AlertRules.future(events, now()).filter { next -> retained.none { it.id == next.id } }
        if (others.count { it.scope != "test" } + retained.size + incoming.size > AlertRules.MAX_EVENTS)
            throw AlertFailure("TOO_MANY_EVENTS")
        if (incoming.isNotEmpty() || retained.any { it.phase != AlertPhase.MISSED }) alarms.requireAccess()
        // Revoke old tokens on disk before touching AlarmManager. Interrupted batches cannot ring.
        save(AlertProjection(others + retained))
        cancelAll(previous - retained.toSet())
        return install(others + retained, incoming) + retained.filter { it.phase != AlertPhase.MISSED }.map { it.id }
    }

    private fun install(others: List<AlertEvent>, events: List<AlertEvent>): List<Int> {
        if (events.isEmpty()) return emptyList()
        save(AlertProjection(others + events.map { it.copy(phase = AlertPhase.STAGED) }))
        try {
            events.forEach { alarms.requireAccess(); alarms.schedule(it) }
            alarms.requireAccess()
            val confirmed = AlertRules.future(events, now())
            cancelAll(events.filter { it !in confirmed })
            save(AlertProjection(others + confirmed))
            return confirmed.map { it.id }
        } catch (error: Exception) {
            val failure = failure(error, "SCHEDULE_FAILED")
            // Invalidate persisted tokens first; a platform cancellation failure still cannot ring.
            try { save(AlertProjection(others, failure.code)) }
            catch (_: Exception) { volatileFailure = "STORAGE_FAILED" }
            try { cancelAll(events) } catch (_: Exception) { volatileFailure = "CANCEL_FAILED" }
            throw failure
        }
    }

    @Synchronized fun cancel(scope: String) {
        AlertRules.requireScope(scope)
        val state = store.read()
        save(AlertProjection(AlertRules.withoutScope(state.events, scope)))
        cancelAll(state.events.filter { it.scope == scope })
    }

    @Synchronized fun pending(): List<Int> {
        var state = store.read()
        val expired = state.events.filter { it.expiresAt <= now() }
        if (expired.isNotEmpty()) {
            state = state.copy(events = state.events - expired.toSet())
            store.write(state)
            cancelAll(expired)
        }
        (state.failure ?: volatileFailure)?.let { throw AlertFailure(safeCode(it)) }
        val active = state.events.filter { it.scope != "test" && it.phase != AlertPhase.MISSED &&
            (it.phase == AlertPhase.RINGING || it in AlertRules.future(state.events, now()) || AlertRules.canRing(it, now())) }
        if (active.isNotEmpty()) alarms.requireAccess()
        return active.map { it.id }
    }

    @Synchronized fun restore(): List<Int> {
        recoverInterrupted()
        val state = store.read()
        val future = AlertRules.future(state.events, now()).filter { it.scope != "test" }
        val missed = state.events.filter { it.phase == AlertPhase.MISSED && it.expiresAt > now() }
        save(AlertProjection(missed))
        cancelAll(state.events - missed.toSet())
        if (future.isNotEmpty()) alarms.requireAccess()
        return install(missed, future)
    }

    @Synchronized fun claim(id: Int, token: String): AlertEvent? {
        val state = store.read()
        val event = state.events.find { it.id == id && it.token == token } ?: return null
        if (event.phase !in setOf(AlertPhase.SCHEDULED, AlertPhase.SNOOZED)) return null
        val others = state.events.filterNot { it == event }
        if (!AlertRules.canRing(event, now()) || others.any { it.phase == AlertPhase.RINGING }) {
            store.write(state.copy(events = others))
            return null
        }
        try { alarms.requireAccess() } catch (error: Exception) {
            val failure = failure(error, "PERMISSION_CHECK_FAILED")
            save(AlertProjection(others, failure.code))
            throw failure
        }
        val active = event.copy(phase = AlertPhase.RINGING)
        store.write(state.copy(events = others + active))
        return active
    }

    @Synchronized fun find(id: Int, token: String): AlertEvent? =
        store.read().events.find { it.id == id && it.token == token }

    @Synchronized fun stop(id: Int, token: String): Boolean {
        val state = store.read()
        val event = state.events.find { it.id == id && it.token == token } ?: return false
        store.write(state.copy(events = state.events - event))
        alarms.cancel(event)
        if (event.scope == "test" && testState != "failed") testState = "stopped"
        return true
    }

    @Synchronized fun finish(id: Int, token: String, reason: AlertEnd) {
        val state = store.read()
        val event = state.events.find { it.id == id && it.token == token && it.phase == AlertPhase.RINGING } ?: return
        if (reason == AlertEnd.STOP) { stop(id, token); return }
        val missed = event.copy(phase = AlertPhase.MISSED)
        save(state.copy(events = state.events - event + missed))
        if (event.scope == "test" && testState != "failed") testState = "missed"
        alarms.cancel(event)
        alarms.missed(missed)
    }

    @Synchronized fun playing(id: Int, token: String) {
        if (find(id, token)?.let { it.scope == "test" && it.phase == AlertPhase.RINGING } == true && testState != "failed")
            testState = "ringing"
    }

    @Synchronized fun status(): Map<String, String?> {
        val state = store.read()
        val code = (state.failure ?: volatileFailure)?.let { safeCode(it) }
        // Only this explicit observation consumes the failure, never background reconciliation.
        store.write(state.copy(failure = null))
        volatileFailure = null
        return mapOf("testState" to testState, "failureCode" to code)
    }

    @Synchronized fun snooze(id: Int, token: String): Boolean {
        val state = store.read()
        val event = state.events.find { it.id == id && it.token == token && it.phase == AlertPhase.RINGING }
            ?: return false
        val others = state.events - event
        // The current sound stops even if new permission or expiry checks fail.
        store.write(state.copy(events = others))
        alarms.cancel(event)
        val next = AlertRules.snooze(event, now()) ?: throw AlertFailure("EVENT_EXPIRED")
        alarms.requireAccess()
        install(others, listOf(next))
        if (event.scope == "test" && testState != "failed") testState = "snoozed"
        return true
    }

    @Synchronized fun test(): AlertEvent {
        alarms.requireAccess()
        val state = store.read()
        if (state.events.any { it.phase == AlertPhase.RINGING }) throw AlertFailure("ALARM_BUSY")
        val at = now()
        val event = AlertEvent(AlertRules.TEST_ID, "test", at, at + 1_200_000,
            "/pico", java.util.UUID.randomUUID().toString())
        state.events.filter { it.scope == "test" }.forEach { alarms.cancel(it) }
        save(state.copy(events = state.events.filterNot { it.scope == "test" } + event))
        testState = "starting"
        return event
    }

    @Synchronized fun recordFailure(code: String) {
        volatileFailure = volatileFailure ?: safeCode(code)
        if (testState in setOf("starting", "ringing", "snoozed")) testState = "failed"
        try {
            val state = store.read()
            volatileFailure = state.failure?.let { safeCode(it) } ?: volatileFailure
            store.write(state.copy(failure = volatileFailure))
        }
        catch (_: Exception) { volatileFailure = "STORAGE_FAILED" }
    }

    private fun cancelAll(events: List<AlertEvent>) {
        var failed = false
        events.forEach { try { alarms.cancel(it) } catch (_: Exception) { failed = true } }
        if (failed) { recordFailure("CANCEL_FAILED"); throw AlertFailure("CANCEL_FAILED") }
    }

    companion object {
        private val failureCodes = setOf("ACCESS_REVOKED", "EXACT_ACCESS_REQUIRED", "NOTIFICATIONS_REQUIRED",
            "PERMISSION_CHECK_FAILED", "PLAYBACK_FAILED", "AUDIO_FOCUS_DENIED", "AUDIO_FOCUS_LOST", "RING_FAILED",
            "TONE_UNAVAILABLE", "FOREGROUND_START_FAILED", "FOREGROUND_TIMEOUT", "ALARM_INTERRUPTED",
            "EVENT_EXPIRED", "ALARM_BUSY", "STORAGE_FAILED", "PROJECTION_CORRUPT", "TOO_MANY_EVENTS",
            "SCHEDULE_FAILED", "CANCEL_FAILED", "RESTORE_FAILED", "ALARM_OPERATION_FAILED", "INVALID_ARGUMENTS",
            "INVALID_SCOPE", "INVALID_ROUTE", "ID_CONFLICT", "BRIDGE_DISPOSED", "PLAYBACK_RELEASE_FAILED",
            "AUDIO_FOCUS_RELEASE_FAILED", "WAKE_RELEASE_FAILED", "ALARM_ACTION_FAILED", "ALARM_SCREEN_FAILED",
            "PRIVATE_NAVIGATION_FAILED", "UNLOCK_FAILED", "MISSED_NOTICE_FAILED")
        fun safeCode(code: String) = if (code in failureCodes) code else "ALARM_OPERATION_FAILED"
        fun failure(error: Exception, fallback: String): AlertFailure = when (error) {
            is AlertFailure -> AlertFailure(safeCode(error.code))
            is SecurityException -> AlertFailure("ACCESS_REVOKED")
            else -> AlertFailure(safeCode(fallback))
        }
    }
}
