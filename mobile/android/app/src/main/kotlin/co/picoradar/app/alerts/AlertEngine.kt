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
}

// All bridge, receiver and service callers share this monitor in the default app process.
internal class AlertEngine(
    private val store: AlertStore,
    private val alarms: AlertAlarms,
    private val now: () -> Long = System::currentTimeMillis,
) {
    private var volatileFailure: String? = null

    @Synchronized fun recoverInterrupted() {
        val state = store.read()
        val dropped = state.events.filter { it.phase != AlertPhase.SCHEDULED || it.expiresAt <= now() }
        if (dropped.isEmpty()) return
        val interrupted = dropped.any { it.phase != AlertPhase.SCHEDULED }
        store.write(state.copy(events = state.events - dropped.toSet(),
            failure = state.failure ?: if (interrupted) "ALARM_INTERRUPTED" else null))
        cancelAll(dropped)
    }

    @Synchronized fun reschedule(scope: String, events: List<AlertEvent>): List<Int> {
        AlertRules.requireScope(scope)
        if (events.any { it.scope != scope }) throw AlertFailure("INVALID_ARGUMENTS")
        if (events.size > AlertRules.MAX_EVENTS) throw AlertFailure("TOO_MANY_EVENTS")
        val state = store.read()
        val others = AlertRules.withoutScope(state.events, scope)
        if (events.map { it.id }.distinct().size != events.size ||
            events.any { item -> others.any { it.id == item.id } }) throw AlertFailure("ID_CONFLICT")
        if (others.count { it.scope != "test" } + events.size > AlertRules.MAX_EVENTS) throw AlertFailure("TOO_MANY_EVENTS")
        if (events.isNotEmpty()) alarms.requireAccess()
        // Revoke old tokens on disk before touching AlarmManager. Interrupted batches cannot ring.
        store.write(AlertProjection(others))
        cancelAll(state.events.filter { it.scope == scope })
        return install(others, AlertRules.future(events, now()))
    }

    private fun install(others: List<AlertEvent>, events: List<AlertEvent>): List<Int> {
        if (events.isEmpty()) { volatileFailure = null; return emptyList() }
        store.write(AlertProjection(others + events.map { it.copy(phase = AlertPhase.STAGED) }))
        try {
            events.forEach { alarms.requireAccess(); alarms.schedule(it) }
            alarms.requireAccess()
            val confirmed = AlertRules.future(events, now())
            cancelAll(events.filter { it !in confirmed })
            store.write(AlertProjection(others + confirmed))
            volatileFailure = null
            return confirmed.map { it.id }
        } catch (error: Exception) {
            val failure = failure(error, "SCHEDULE_FAILED")
            // Invalidate persisted tokens first; a platform cancellation failure still cannot ring.
            try { store.write(AlertProjection(others, failure.code)) }
            catch (_: Exception) { volatileFailure = "STORAGE_FAILED" }
            try { cancelAll(events) } catch (_: Exception) { volatileFailure = "CANCEL_FAILED" }
            throw failure
        }
    }

    @Synchronized fun cancel(scope: String) {
        AlertRules.requireScope(scope)
        val state = store.read()
        store.write(AlertProjection(AlertRules.withoutScope(state.events, scope)))
        cancelAll(state.events.filter { it.scope == scope })
        volatileFailure = null
    }

    @Synchronized fun pending(): List<Int> {
        var state = store.read()
        val expired = state.events.filter { it.expiresAt <= now() }
        if (expired.isNotEmpty()) {
            state = state.copy(events = state.events - expired.toSet())
            store.write(state)
            cancelAll(expired)
        }
        (volatileFailure ?: state.failure)?.let { throw AlertFailure(it) }
        if (state.events.isNotEmpty()) alarms.requireAccess()
        return AlertRules.future(state.events, now()).filter { it.scope != "test" }.map { it.id }
    }

    @Synchronized fun restore(): List<Int> {
        val state = store.read()
        val future = AlertRules.future(state.events, now()).filter { it.scope != "test" }
        store.write(AlertProjection())
        cancelAll(state.events)
        if (future.isNotEmpty()) alarms.requireAccess()
        return install(emptyList(), future)
    }

    @Synchronized fun claim(id: Int, token: String): AlertEvent? {
        val state = store.read()
        val event = state.events.find { it.id == id && it.token == token } ?: return null
        if (event.phase != AlertPhase.SCHEDULED) return null
        val others = state.events.filterNot { it == event }
        if (!AlertRules.canRing(event, now()) || others.any { it.phase == AlertPhase.RINGING }) {
            store.write(state.copy(events = others))
            return null
        }
        try { alarms.requireAccess() } catch (error: Exception) {
            val failure = failure(error, "PERMISSION_CHECK_FAILED")
            store.write(AlertProjection(others, failure.code))
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
        return true
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
        store.write(state.copy(events = state.events.filterNot { it.scope == "test" } + event, failure = null))
        volatileFailure = null
        return event
    }

    @Synchronized fun recordFailure(code: String) {
        volatileFailure = code
        try { store.write(store.read().copy(failure = code)) }
        catch (_: Exception) { volatileFailure = "STORAGE_FAILED" }
    }

    private fun cancelAll(events: List<AlertEvent>) {
        var failed = false
        events.forEach { try { alarms.cancel(it) } catch (_: Exception) { failed = true } }
        if (failed) { recordFailure("CANCEL_FAILED"); throw AlertFailure("CANCEL_FAILED") }
    }

    companion object {
        fun failure(error: Exception, fallback: String): AlertFailure = when (error) {
            is AlertFailure -> error
            is SecurityException -> AlertFailure("ACCESS_REVOKED")
            else -> AlertFailure(fallback)
        }
    }
}
