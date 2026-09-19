package co.picoradar.app.alerts

import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import org.junit.Assert.*
import org.junit.Test

class AlertCodecTest {
    private val event = AlertEvent(7, "pico", 1000, 2000, "/pico", "generation")
    private fun bytes(state: AlertProjection): ByteArray = ByteArrayOutputStream().also { AlertCodec.write(state, it) }.toByteArray()

    @Test fun projectionRoundTripsIdentifiersTimesAndGenericRouteOnly() {
        val state = AlertProjection(listOf(event), "EXACT_ACCESS_REQUIRED")
        assertEquals(state, AlertCodec.read(ByteArrayInputStream(bytes(state))))
    }

    @Test fun truncatedCorruptAndDuplicateEntriesFailClosed() {
        val valid = bytes(AlertProjection(listOf(event)))
        for (data in listOf(valid.copyOf(5), byteArrayOf(0), valid + byteArrayOf(1),
            bytes(AlertProjection(listOf(event, event))))) {
            assertEquals("PROJECTION_CORRUPT", assertThrows(AlertFailure::class.java) {
                AlertCodec.read(ByteArrayInputStream(data))
            }.code)
        }
    }

    @Test fun persistedExternalRouteOrPrivateContextIsNeverAccepted() {
        for (route in listOf("https://example.test", "/pico?vehicleId=private", "/pico?plate=ABC123")) {
            assertThrows(AlertFailure::class.java) {
                AlertCodec.read(ByteArrayInputStream(bytes(AlertProjection(listOf(event.copy(route = route))))))
            }
        }
    }
}
