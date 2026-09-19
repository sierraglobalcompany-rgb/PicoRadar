package co.picoradar.app.alerts

import android.content.Context
import android.util.AtomicFile
import java.io.File
import java.io.FileNotFoundException

internal class AlertProjectionStore(context: Context) : AlertStore {
    private val file = AtomicFile(File(context.noBackupFilesDir, "optional_alerts_v1.bin"))

    override fun read(): AlertProjection = try {
        file.openRead().use { AlertCodec.read(it) }
    } catch (_: FileNotFoundException) {
        if (file.baseFile.exists()) throw AlertFailure("STORAGE_FAILED")
        AlertProjection()
    } catch (error: AlertFailure) { throw error }
    catch (_: Exception) { throw AlertFailure("STORAGE_FAILED") }

    override fun write(value: AlertProjection) {
        val output = try { file.startWrite() } catch (_: Exception) { throw AlertFailure("STORAGE_FAILED") }
        try {
            AlertCodec.write(value, output)
            file.finishWrite(output)
        } catch (_: Exception) {
            file.failWrite(output)
            throw AlertFailure("STORAGE_FAILED")
        }
    }
}
