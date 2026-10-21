package co.picoradar.app.wallet

import com.google.android.gms.common.ConnectionResult
import com.google.android.gms.common.api.CommonStatusCodes

internal object WalletScannerErrors {
    fun services(status: Int): String = when (status) {
        ConnectionResult.SERVICE_MISSING -> "scanner_services_missing"
        ConnectionResult.SERVICE_VERSION_UPDATE_REQUIRED -> "scanner_services_update"
        ConnectionResult.SERVICE_DISABLED -> "scanner_services_disabled"
        ConnectionResult.SERVICE_UPDATING -> "scanner_services_updating"
        else -> "scanner_services_unavailable"
    }

    fun startStatus(status: Int?): String = when (status) {
        CommonStatusCodes.NETWORK_ERROR -> "scanner_network"
        CommonStatusCodes.TIMEOUT -> "scanner_timeout"
        else -> "scanner_start_failed"
    }
}
