package co.picoradar.app.alerts

import java.net.URI
import java.net.URLDecoder
import java.util.UUID

internal enum class AlertPhase { STAGED, SCHEDULED, RINGING, SNOOZED, MISSED }

internal data class AlertEvent(
    val id: Int,
    val scope: String,
    val at: Long,
    val expiresAt: Long,
    val route: String,
    val token: String,
    val phase: AlertPhase = AlertPhase.SCHEDULED,
    val originalAt: Long = at,
)

internal class AlertFailure(val code: String) : Exception("PicoRadar alarm operation failed: $code")
internal data class AlertDestination(val path: String, val vehicleId: String?)

internal object AlertRules {
    const val MAX_EVENTS = 128
    const val MAX_RING_MS = 120_000L
    const val SNOOZE_MS = 600_000L
    const val TEST_ID = -1
    const val ELIGIBILITY_MS = 900_000L
    private val routes = setOf("/pico", "/garage", "/apps/module/soat",
        "/apps/module/tecnomecanica", "/apps/module/seguro_asistencia", "/apps/module/impuestos")

    fun requireScope(value: String): String {
        if (value != "pico" && value != "obligations") throw AlertFailure("INVALID_SCOPE")
        return value
    }

    // The only persisted query value is an opaque local owner ID, never vehicle display data.
    fun route(value: String): String {
        val destination = destination(value)
        return URI(null, null, destination.path,
            destination.vehicleId?.let { "vehicleId=$it" }, null).toASCIIString()
    }

    fun destination(value: String): AlertDestination {
        val uri = try { URI(value) } catch (_: Exception) { throw AlertFailure("INVALID_ROUTE") }
        if (value.length > 1024 || uri.scheme != null || uri.rawAuthority != null ||
            uri.rawFragment != null || uri.rawPath !in routes) {
            throw AlertFailure("INVALID_ROUTE")
        }
        val parameters = mutableMapOf<String, String>()
        uri.rawQuery?.split('&')?.forEach { part ->
            val pair = part.split('=', limit = 2)
            if (pair.size != 2) throw AlertFailure("INVALID_ROUTE")
            val key = decode(pair[0])
            val content = decode(pair[1])
            if (parameters.containsKey(key)) throw AlertFailure("INVALID_ROUTE")
            val valid = when (key) {
                "vehicleId", "jurisdictionId" -> Regex("[A-Za-z0-9_-]{1,64}").matches(content)
                "source" -> content == "obligation_reminder"
                else -> false
            }
            if (!valid) throw AlertFailure("INVALID_ROUTE")
            parameters[key] = content
        }
        return AlertDestination(uri.rawPath, parameters["vehicleId"])
    }

    private fun decode(value: String): String = try { URLDecoder.decode(value, "UTF-8") }
        catch (_: Exception) { throw AlertFailure("INVALID_ROUTE") }

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
            if (id !in 1..Int.MAX_VALUE.toLong() || at < 0 || expiry <= at || expiry - at > ELIGIBILITY_MS)
                throw AlertFailure("INVALID_ARGUMENTS")
            AlertEvent(id.toInt(), scope, at, expiry,
                route(map["route"] as? String ?: throw AlertFailure("INVALID_ROUTE")), UUID.randomUUID().toString())
        }
        if (events.map { it.id }.distinct().size != events.size) throw AlertFailure("ID_CONFLICT")
        return events.filter { it.expiresAt > now }
    }

    private fun integer(value: Any?): Long = when (value) {
        is Int -> value.toLong()
        is Long -> value
        else -> throw AlertFailure("INVALID_ARGUMENTS")
    }

    fun future(events: List<AlertEvent>, now: Long) = events.filter {
        it.phase in setOf(AlertPhase.SCHEDULED, AlertPhase.SNOOZED) && it.at > now && it.expiresAt > it.at
    }

    fun canRing(event: AlertEvent, now: Long): Boolean = event.phase in setOf(AlertPhase.SCHEDULED, AlertPhase.SNOOZED) &&
        now >= event.at && now < event.expiresAt && now - event.at <= MAX_RING_MS

    fun ringMillis(event: AlertEvent, now: Long) =
        if (now >= event.expiresAt) 0L else minOf(MAX_RING_MS, event.expiresAt - now)

    fun snooze(event: AlertEvent, now: Long): AlertEvent? {
        if (now > Long.MAX_VALUE - SNOOZE_MS || now + SNOOZE_MS >= event.expiresAt) return null
        return event.copy(at = now + SNOOZE_MS, token = UUID.randomUUID().toString(), phase = AlertPhase.SNOOZED)
    }

    fun withoutScope(events: List<AlertEvent>, scope: String) = events.filter { it.scope != scope }
}
