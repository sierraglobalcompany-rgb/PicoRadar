package co.picoradar.app.alerts

import java.io.DataInputStream
import java.io.DataOutputStream
import java.io.InputStream
import java.io.OutputStream

internal object AlertCodec {
    private const val MAGIC = 0x50524131

    fun write(state: AlertProjection, output: OutputStream) {
        val stream = DataOutputStream(output)
        stream.writeInt(MAGIC)
        stream.writeInt(state.events.size)
        stream.writeUTF(state.failure.orEmpty())
        state.events.forEach {
            stream.writeInt(it.id)
            stream.writeUTF(it.scope)
            stream.writeLong(it.at)
            stream.writeLong(it.expiresAt)
            stream.writeUTF(it.route)
            stream.writeUTF(it.token)
            stream.writeInt(it.phase.ordinal)
        }
        stream.flush()
    }

    fun read(input: InputStream): AlertProjection {
        try {
            val stream = DataInputStream(input)
            if (stream.readInt() != MAGIC) throw AlertFailure("PROJECTION_CORRUPT")
            val count = stream.readInt()
            if (count !in 0..AlertRules.MAX_EVENTS + 1) throw AlertFailure("PROJECTION_CORRUPT")
            val failure = stream.readUTF().ifEmpty { null }
            if (failure != null && !Regex("[A-Z_]{1,64}").matches(failure)) throw AlertFailure("PROJECTION_CORRUPT")
            val events = (0 until count).map {
                val event = AlertEvent(stream.readInt(), stream.readUTF(), stream.readLong(),
                    stream.readLong(), stream.readUTF(), stream.readUTF(), AlertPhase.entries[stream.readInt()])
                if (event.scope !in setOf("pico", "obligations", "test") ||
                    (event.id <= 0 && !(event.id == AlertRules.TEST_ID && event.scope == "test")) ||
                    event.at < 0 || event.expiresAt <= event.at || AlertRules.route(event.route) != event.route ||
                    !Regex("[a-zA-Z0-9-]{1,64}").matches(event.token)) throw AlertFailure("PROJECTION_CORRUPT")
                event
            }
            if (events.map { it.id }.distinct().size != events.size || stream.read() != -1)
                throw AlertFailure("PROJECTION_CORRUPT")
            return AlertProjection(events, failure)
        } catch (_: Exception) { throw AlertFailure("PROJECTION_CORRUPT") }
    }
}
