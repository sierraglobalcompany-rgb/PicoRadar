package co.picoradar.app.wallet

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.view.WindowManager
import com.google.android.gms.common.ConnectionResult
import com.google.android.gms.common.GoogleApiAvailability
import com.google.mlkit.vision.documentscanner.GmsDocumentScannerOptions
import com.google.mlkit.vision.documentscanner.GmsDocumentScanning
import com.google.mlkit.vision.documentscanner.GmsDocumentScanningResult
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File
import java.io.IOException
import java.util.UUID
import java.util.concurrent.Executors
import java.util.concurrent.Future

class WalletBridge(private val activity: Activity, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "co.picoradar.app/wallet")
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private val pdf = DocumentPdfClient(activity.applicationContext)
    private val scannerIo = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private val captureRoot = File(activity.noBackupFilesDir, "wallet_capture")
    private var scanResult: MethodChannel.Result? = null
    private var scanPageLimit = 2
    @Volatile private var disposed = false
    // A new Activity must not erase captures already handed to a live workflow.
    private val orphanCleanup: Future<*> = synchronized(WalletBridge::class.java) {
        processCleanup ?: scannerIo.submit {
            val files = listFiles(captureRoot).filter { file ->
                try {
                    WalletLimits.ownedCapture(file.path, captureRoot)
                    true
                } catch (_: IllegalArgumentException) {
                    false
                }
            }
            deleteCreated(files)
            cleanupSdkCache()
        }.also { processCleanup = it }
    }

    init {
        channel.setMethodCallHandler(::handle)
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        if (disposed) {
            result.error("cancelled", "Wallet activity unavailable.", null)
            return
        }
        when (call.method) {
            "scan" -> {
                try {
                    scan(call.argument<Int>("maxPages") ?: 2, result)
                } catch (error: Exception) {
                    if (scanResult === result) scanResult = null
                    fail(result, error)
                }
            }
            "setSecure" -> {
                val enabled = call.argument<Boolean>("enabled")
                if (enabled == null) {
                    result.error("invalid_arguments", "Expected secure flag.", null)
                } else {
                    if (enabled) activity.window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    else activity.window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    result.success(null)
                }
            }
            "noBackupDirectory" -> async(result) {
                withContext(Dispatchers.IO) { awaitCleanup() }
                activity.noBackupFilesDir.absolutePath
            }
            "deleteScanTemps" -> async(result) {
                val paths = call.argument<List<String>>("paths")
                    ?: throw WalletNativeException("invalid_arguments")
                withContext(Dispatchers.IO) { deleteScanTemps(paths) }
                null
            }
            "openPdf" -> async(result) { pdf.open(requiredString(call, "path")) }
            "renderPdfPage" -> async(result) {
                pdf.render(requiredString(call, "id"),
                    call.argument<Int>("page") ?: throw WalletNativeException("invalid_arguments"),
                    call.argument<Int>("width") ?: throw WalletNativeException("invalid_arguments"))
            }
            "closePdf" -> async(result) { pdf.close(requiredString(call, "id")); null }
            else -> result.notImplemented()
        }
    }

    private fun async(result: MethodChannel.Result, action: suspend () -> Any?) {
        scope.launch {
            try {
                result.success(action())
            } catch (error: Exception) {
                fail(result, error)
            }
        }
    }

    @Suppress("DEPRECATION")
    private fun scan(maxPages: Int, result: MethodChannel.Result) {
        WalletLimits.scanPages(maxPages)
        if (scanResult != null) {
            result.error("busy", "Scanner already active.", null)
            return
        }
        if (GoogleApiAvailability.getInstance().isGooglePlayServicesAvailable(activity) != ConnectionResult.SUCCESS) {
            result.error("unsupported", "Document scanner unavailable.", null)
            return
        }
        scanResult = result
        scanPageLimit = maxPages
        val options = GmsDocumentScannerOptions.Builder()
            .setScannerMode(GmsDocumentScannerOptions.SCANNER_MODE_BASE)
            .setPageLimit(maxPages)
            .setGalleryImportAllowed(true)
            .setResultFormats(GmsDocumentScannerOptions.RESULT_FORMAT_JPEG)
            .build()
        GmsDocumentScanning.getClient(options).getStartScanIntent(activity)
            .addOnSuccessListener { sender ->
                if (!disposed && scanResult === result) {
                    try {
                        activity.startIntentSenderForResult(sender, SCAN_REQUEST, null, 0, 0, 0)
                    } catch (error: Exception) {
                        scanResult = null
                        fail(result, error)
                    }
                }
            }
            .addOnFailureListener {
                if (scanResult === result) {
                    scanResult = null
                    result.error("unsupported", "Document scanner unavailable.", null)
                }
            }
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != SCAN_REQUEST) return false
        val waiting = scanResult
        val sources: List<Uri>
        try {
            sources = GmsDocumentScanningResult.fromActivityResultIntent(data)?.pages?.map { it.imageUri }.orEmpty()
        } catch (error: Exception) {
            scannerIo.execute {
                var failure = error
                try { cleanupSdkCache() }
                catch (cleanupError: Exception) { failure = cleanupError }
                main.post {
                    if (waiting != null && scanResult === waiting) {
                        scanResult = null
                        fail(waiting, failure)
                    }
                }
            }
            return true
        }
        val limit = scanPageLimit
        scannerIo.execute {
            val created = mutableListOf<File>()
            try {
                awaitCleanup()
                if (resultCode == Activity.RESULT_CANCELED) {
                    cleanupSources(sources)
                    main.post {
                        if (waiting != null && scanResult === waiting) {
                            scanResult = null
                            waiting.success(null)
                        }
                    }
                    return@execute
                }
                require(resultCode == Activity.RESULT_OK && sources.isNotEmpty() && sources.size <= limit) {
                    "invalid_result"
                }
                check(captureRoot.isDirectory || captureRoot.mkdirs()) { "storage_failed" }
                for (source in sources) {
                    // The SDK's result must resolve to an app-private path. Do not grant
                    // arbitrary content providers, shared files, or remote URLs to Dart.
                    val original = scannerSource(source)
                    val target = File(captureRoot, "scan-${UUID.randomUUID()}.jpg")
                    created.add(target)
                    original.inputStream().use { input ->
                        target.outputStream().use { output ->
                            WalletLimits.copyBounded(input, output, WalletLimits.MAX_INPUT_BYTES)
                        }
                    }
                }
                cleanupSources(sources)
                main.post {
                    if (disposed || waiting == null || scanResult !== waiting) {
                        scannerIo.execute { deleteCreated(created) }
                    } else {
                        scanResult = null
                        // Ownership transfers to Dart for immediate encrypted staging, even
                        // when authentication was revoked while the scanner was foreground.
                        waiting.success(created.mapIndexed { index, file ->
                            mapOf("path" to file.absolutePath,
                                "originalName" to "scan-${index + 1}.jpg", "mimeType" to "image/jpeg")
                        })
                    }
                }
            } catch (error: Exception) {
                var failure = error
                try { deleteCreated(created); cleanupSources(sources) }
                catch (cleanupError: Exception) { failure = cleanupError }
                main.post {
                    if (scanResult === waiting) {
                        scanResult = null
                        waiting?.let { fail(it, failure) }
                    }
                }
            }
        }
        return true
    }

    private fun scannerSource(uri: Uri): File {
        require(uri.scheme == "file") { "invalid_result" }
        val file = WalletLimits.ownedSdkCapture(
            uri.path ?: throw WalletNativeException("invalid_result"), activity.cacheDir)
        require(file.isFile && file.length() in 1..WalletLimits.MAX_INPUT_BYTES) { "size_limit" }
        return file
    }

    private fun cleanupSources(sources: List<Uri>) {
        var failed = false
        for (source in sources) {
            // Invalid/outside sources are rejected, never deleted.
            if (source.scheme != "file") continue
            val file = try { WalletLimits.ownedSdkCapture(source.path ?: continue, activity.cacheDir) }
                catch (_: IllegalArgumentException) { continue }
            if (file.exists() && !file.delete()) failed = true
        }
        cleanupSdkCache()
        if (failed) throw IOException("cleanup_failed")
    }

    private fun cleanupSdkCache() {
        // Verified against pinned ML Kit 16.0.0 ResultHelper: numeric .jpg files
        // in this direct child directory. Do not recursively erase app caches.
        val root = File(activity.cacheDir, "mlkit_docscan_ui_client")
        val files = listFiles(root).mapNotNull { file ->
            try { WalletLimits.ownedSdkCapture(file.path, activity.cacheDir) }
            catch (_: IllegalArgumentException) { null }
        }
        deleteCreated(files)
    }

    private fun listFiles(root: File): Array<File> = if (!root.exists()) emptyArray()
        else root.listFiles() ?: throw IOException("cleanup_failed")

    private fun deleteScanTemps(paths: List<String>) {
        require(paths.size <= 100) { "invalid_arguments" }
        val files = paths.map { WalletLimits.ownedCapture(it, captureRoot) }
        deleteCreated(files)
    }

    private fun awaitCleanup() {
        try { orphanCleanup.get() }
        catch (_: java.util.concurrent.ExecutionException) { throw IOException("cleanup_failed") }
    }

    private fun deleteCreated(files: List<File>) {
        var failed = false
        files.forEach { file -> if (file.exists() && !file.delete()) failed = true }
        if (failed) throw IOException("cleanup_failed")
    }

    fun dispose() {
        disposed = true
        channel.setMethodCallHandler(null)
        scanResult?.error("cancelled", "Wallet activity closed.", null)
        scanResult = null
        pdf.dispose()
        scope.cancel()
        // Keep cleanup work alive until a pending SDK result copy has finished.
        scannerIo.execute { main.post { scannerIo.shutdown() } }
    }

    fun onBackground() {
        pdf.onBackground()
    }

    private fun requiredString(call: MethodCall, name: String): String =
        call.argument<String>(name)?.takeIf { it.isNotEmpty() }
            ?: throw WalletNativeException("invalid_arguments")

    private fun fail(result: MethodChannel.Result, error: Exception) {
        val code = when (error) {
            is WalletNativeException -> error.code
            is CancellationException -> "cancelled"
            is IllegalArgumentException -> error.message.takeIf { it in ERROR_CODES } ?: "invalid_arguments"
            is IOException -> if (error.message == "cleanup_failed") "cleanup_failed" else "storage_failed"
            else -> "platform_failed"
        }
        result.error(code, "Wallet operation could not complete.", null)
    }

    companion object {
        private const val SCAN_REQUEST = 1515
        private var processCleanup: Future<*>? = null
        private val ERROR_CODES = setOf("invalid_arguments", "size_limit", "invalid_file", "invalid_result")
    }
}
