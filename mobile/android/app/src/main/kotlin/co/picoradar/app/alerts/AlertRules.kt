package co.picoradar.app.alerts

import java.net.URI
import java.util.UUID

internal enum class AlertPhase { STAGED, SCHEDULED, RINGING }

internal data class AlertEvent(
    val id: Int,
    val scope: String,
    val at: Long,
    val expiresAt: Long,
    val route: String,
    val token: String,
    val phase: AlertPhase = AlertPhase.SCHEDULED,
)

internal class AlertFailure(val code: String) : Exception("PicoRadar alarm operation failed: $code")

internal object AlertRules {
    const val MAX_EVENTS = 128
    const val MAX_RING_MS = 120_000L
    const val SNOOZE_MS = 600_000L
    const val TEST_ID = -1
    private val routes = setOf("/pico", "/garage", "/apps/module/soat",
        "/apps/module/tecnomecanica", "/apps/module/seguro_asistencia", "/apps/module/impuestos")

    fun requireScope(value: String): String {
        if (value != "pico" && value != "obligations") throw AlertFailure("INVALID_SCOPE")
        return value
    }

    // Persist only the module destination. Vehicle context stays in the authoritative Drift DB.
    fun route(value: String): String {
        val uri = try { URI(value) } catch (_: Exception) { throw AlertFailure("INVALID_ROUTE") }
        if (value.length > 1024 || uri.scheme != null || uri.rawAuthority != null ||
            uri.rawFragment != null || uri.rawPath !in routes ||
            uri.rawQuery?.split('&')?.any { it.substringBefore('=') !in setOf("vehicleId", "source", "jurisdictionId") } == true) {
            throw AlertFailure("INVALID_ROUTE")
        }
        return uri.rawPath
    }

    fun parse(scope: String, raw: Any?, now: Long): List<AlertEvent> {
        requireScope(scope)
        val items = raw as? List<*> ?: throw AlertFailure("INVALID_ARGUMENTS")
        if (items.size > MAX_EVENTS) throw AlertFailure("TOO_MANY_EVENTS")
        val events = items.map { item ->
            val map = item as? Map<*, *> ?: throw AlertFailure("INVALID_ARGUMENTS")
            if (map.keys != setOf("id", "at", "expiresAt", "route")) throw AlertFailure("INVALID_ARGUMENTS")
            val id = integer(map["id"])
            val at = integer(map["at"])
            val expiry = integer(map["expiresAt"])
            if (id !in 1..Int.MAX_VALUE.toLong() || at < 0 || expiry <= at) throw AlertFailure("INVALID_ARGUMENTS")
            AlertEvent(id.toInt(), scope, at, expiry,
                route(map["route"] as? String ?: throw AlertFailure("INVALID_ROUTE")), UUID.randomUUID().toString())
        }
        if (events.map { it.id }.distinct().size != events.size) throw AlertFailure("ID_CONFLICT")
        return future(events, now)
    }

    private fun integer(value: Any?): Long = when (value) {
        is Int -> value.toLong()
        is Long -> value
        else -> throw AlertFailure("INVALID_ARGUMENTS")
    }

    fun future(events: List<AlertEvent>, now: Long) = events.filter {
        it.phase == AlertPhase.SCHEDULED && it.at > now && it.expiresAt > it.at
    }

    fun canRing(event: AlertEvent, now: Long): Boolean = event.phase == AlertPhase.SCHEDULED &&
        now >= event.at && now < event.expiresAt && now - event.at <= MAX_RING_MS

    fun ringMillis(event: AlertEvent, now: Long) =
        if (now >= event.expiresAt) 0L else minOf(MAX_RING_MS, event.expiresAt - now)

    fun snooze(event: AlertEvent, now: Long): AlertEvent? {
        if (now > Long.MAX_VALUE - SNOOZE_MS || now + SNOOZE_MS >= event.expiresAt) return null
        return event.copy(at = now + SNOOZE_MS, token = UUID.randomUUID().toString(), phase = AlertPhase.SCHEDULED)
    }

    fun withoutScope(events: List<AlertEvent>, scope: String) = events.filter { it.scope != scope }
}
