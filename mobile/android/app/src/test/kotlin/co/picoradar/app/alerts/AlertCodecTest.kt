package co.picoradar.app.alerts

import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import org.junit.Assert.*
import org.junit.Test

class AlertCodecTest {
    private val event = AlertEvent(7, "pico", 1000, 2000, "/pico", "generation")
    private fun bytes(state: AlertProjection): ByteArray = ByteArrayOutputStream().also { AlertCodec.write(state, it) }.toByteArray()

    @Test fun projectionRoundTripsOpaqueOwnerWithoutOtherContext() {
        val state = AlertProjection(listOf(event.copy(route = "/pico?vehicleId=owner_2")), "EXACT_ACCESS_REQUIRED")
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
        for (route in listOf("https://example.test", "/pico?vehicleId=owner%20name", "/pico?plate=ABC123",
            "/pico?vehicleId=owner&source=obligation_reminder")) {
            assertThrows(AlertFailure::class.java) {
                AlertCodec.read(ByteArrayInputStream(bytes(AlertProjection(listOf(event.copy(route = route))))))
            }
        }
    }

    @Test fun extraProjectionSlotIsOnlyForFictionalTest() {
        val normal = (1..128).map { event.copy(id = it) }
        val valid = AlertProjection(normal + event.copy(id = -1, scope = "test"))
        assertEquals(valid, AlertCodec.read(ByteArrayInputStream(bytes(valid))))
        assertThrows(AlertFailure::class.java) {
            AlertCodec.read(ByteArrayInputStream(bytes(AlertProjection(normal + event.copy(id = 129)))))
        }
    }

    @Test fun snoozePersistsOriginalTargetAndLegacyScheduledProjectionStillReads() {
        val snoozed = event.copy(at = 1500, phase = AlertPhase.SNOOZED)
        assertEquals(snoozed, AlertCodec.read(ByteArrayInputStream(bytes(AlertProjection(listOf(snoozed))))).events.single())
        val legacy = ByteArrayOutputStream()
        java.io.DataOutputStream(legacy).apply {
            writeInt(0x50524131); writeInt(1); writeUTF("")
            writeInt(event.id); writeUTF(event.scope); writeLong(event.at); writeLong(event.expiresAt)
            writeUTF(event.route); writeUTF(event.token); writeInt(AlertPhase.SCHEDULED.ordinal)
        }
        assertEquals(event, AlertCodec.read(ByteArrayInputStream(legacy.toByteArray())).events.single())
    }
}
