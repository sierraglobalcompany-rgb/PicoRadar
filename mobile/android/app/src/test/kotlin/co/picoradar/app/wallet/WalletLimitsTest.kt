package co.picoradar.app.wallet

import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.File
import org.junit.Assert.*
import org.junit.Test

class WalletLimitsTest {
    @Test fun validatesEveryPdfPageWithoutCappingLegacyDocuments() {
        val visited = mutableListOf<Int>()
        WalletLimits.validatePdfPages(350) { index ->
            visited.add(index)
            600 to 900
        }
        assertEquals((0 until 350).toList(), visited)
    }

    @Test fun invalidLaterPdfPageRejectsWholeDocument() {
        assertThrows(IllegalArgumentException::class.java) {
            WalletLimits.validatePdfPages(151) { index ->
                if (index == 150) 0 to 900 else 600 to 900
            }
        }
        assertThrows(java.io.IOException::class.java) {
            WalletLimits.validatePdfPages(3) { index ->
                if (index == 2) throw java.io.IOException("Unreadable page")
                600 to 900
            }
        }
    }

    @Test fun pdfMetadataMustAdmitABoundedRaster() {
        assertThrows(IllegalArgumentException::class.java) {
            WalletLimits.validatePdfPages(0) { 600 to 900 }
        }
        assertThrows(IllegalArgumentException::class.java) {
            WalletLimits.validatePdfPages(1) { 1 to Int.MAX_VALUE }
        }
        // Large logical coordinates do not imply large raster allocations.
        WalletLimits.validatePdfPages(1) { Int.MAX_VALUE to Int.MAX_VALUE }
    }

    @Test fun sdkCleanupOnlyAcceptsPinnedSdkTimestampJpegs() {
        val cache = File(System.getProperty("java.io.tmpdir"), "wallet-cache")
        val own = File(cache, "mlkit_docscan_ui_client/123456789.jpg")
        assertEquals(own.canonicalFile, WalletLimits.ownedSdkCapture(own.path, cache))
        for (path in listOf(File(cache, "123456789.jpg"),
            File(cache, "mlkit_docscan_ui_client/import.jpg"),
            File(cache, "mlkit_docscan_ui_client/nested/123456789.jpg"),
            File(cache, "mlkit_docscan_ui_client/../123456789.jpg"))) {
            assertThrows(IllegalArgumentException::class.java) { WalletLimits.ownedSdkCapture(path.path, cache) }
        }
    }

    @Test fun scanCleanupCannotDeleteImportedOrEncryptedFiles() {
        val root = File(System.getProperty("java.io.tmpdir"), "wallet-capture")
        val name = "scan-12345678-1234-1234-1234-123456789abc.jpg"
        assertEquals(File(root, name).canonicalFile, WalletLimits.ownedCapture(File(root, name).path, root))
        for (path in listOf(File(root, "import.jpg"), File(root, "encrypted.prcf"),
            File(root.parentFile, name), File(root, "nested/$name"))) {
            assertThrows(IllegalArgumentException::class.java) { WalletLimits.ownedCapture(path.path, root) }
        }
    }

    @Test fun scanCannotRequestMoreThanFrontAndBack() {
        WalletLimits.scanPages(1)
        WalletLimits.scanPages(2)
        assertThrows(IllegalArgumentException::class.java) { WalletLimits.scanPages(3) }
        assertThrows(IllegalArgumentException::class.java) { WalletLimits.scanPages(0) }
    }

    @Test fun renderPreservesAspectAndRejectsMemoryBombs() {
        assertEquals(1500, WalletLimits.renderHeight(600, 900, 1000))
        assertThrows(IllegalArgumentException::class.java) { WalletLimits.renderHeight(1, Int.MAX_VALUE, 2048) }
        assertThrows(IllegalArgumentException::class.java) { WalletLimits.renderHeight(0, 100, 100) }
        assertThrows(IllegalArgumentException::class.java) { WalletLimits.renderHeight(100, 100, 2049) }
    }

    @Test fun copyStopsBeforeWritingBytesBeyondLimit() {
        val output = ByteArrayOutputStream()
        assertThrows(IllegalArgumentException::class.java) {
            WalletLimits.copyBounded(ByteArrayInputStream(ByteArray(12)), output, 10)
        }
        assertTrue(output.size() <= 10)
        val valid = ByteArrayOutputStream()
        WalletLimits.copyBounded(ByteArrayInputStream(byteArrayOf(1, 2)), valid, 2)
        assertArrayEquals(byteArrayOf(1, 2), valid.toByteArray())
    }

    @Test fun canonicalContainmentRejectsSiblingAndTraversal() {
        val root = File(System.getProperty("java.io.tmpdir"), "wallet-test-root")
        assertTrue(WalletLimits.isWithin(File(root, "preview.pdf"), root))
        assertFalse(WalletLimits.isWithin(File(root.path + "-other/preview.pdf"), root))
        assertFalse(WalletLimits.isWithin(File(root, "../secret.pdf"), root))
        assertFalse(WalletLimits.isWithin(root, root))
    }
}
