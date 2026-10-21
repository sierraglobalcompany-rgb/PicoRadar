package co.picoradar.app.wallet

import com.google.android.gms.common.ConnectionResult
import com.google.android.gms.common.api.CommonStatusCodes
import org.junit.Assert.assertEquals
import org.junit.Test

class WalletScannerErrorsTest {
    @Test fun serviceFailuresRemainDistinctAndFinite() {
        assertEquals("scanner_services_missing", WalletScannerErrors.services(ConnectionResult.SERVICE_MISSING))
        assertEquals("scanner_services_update", WalletScannerErrors.services(ConnectionResult.SERVICE_VERSION_UPDATE_REQUIRED))
        assertEquals("scanner_services_disabled", WalletScannerErrors.services(ConnectionResult.SERVICE_DISABLED))
        assertEquals("scanner_services_updating", WalletScannerErrors.services(ConnectionResult.SERVICE_UPDATING))
        assertEquals("scanner_services_unavailable", WalletScannerErrors.services(-999))
    }

    @Test fun startStatusDoesNotExposeExceptionMessagesOrUnknownNumbers() {
        assertEquals("scanner_network", WalletScannerErrors.startStatus(CommonStatusCodes.NETWORK_ERROR))
        assertEquals("scanner_timeout", WalletScannerErrors.startStatus(CommonStatusCodes.TIMEOUT))
        assertEquals("scanner_start_failed", WalletScannerErrors.startStatus(-999))
        assertEquals("scanner_start_failed", WalletScannerErrors.startStatus(null))
    }
}
