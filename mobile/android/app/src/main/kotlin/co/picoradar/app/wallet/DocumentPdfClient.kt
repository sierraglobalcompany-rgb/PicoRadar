package co.picoradar.app.wallet

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.os.Bundle
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.Message
import android.os.Messenger
import android.os.ParcelFileDescriptor
import android.system.Os
import android.system.OsConstants
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeout
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.IOException
import java.util.UUID

internal class WalletNativeException(val code: String) : Exception(code)

/** All public methods run on the main dispatcher, with one outstanding operation. */
internal class DocumentPdfClient(private val context: Context) {
    private var bound = false
    private var remote: Messenger? = null
    private var connecting: CompletableDeferred<Messenger>? = null
    private var pending: CompletableDeferred<Bundle>? = null
    private var sequence = 0
    private var documentId: String? = null
    private var busy = false
    private var disposed = false
    private var generation = 0
    private var operationGeneration = 0
    private val reply = Messenger(Handler(Looper.getMainLooper()) { message ->
        if (message.arg1 == sequence) pending?.complete(message.data)
        true
    })
    private val connection = object : ServiceConnection {
        override fun onServiceConnected(name: ComponentName, binder: IBinder) {
            remote = Messenger(binder)
            connecting?.complete(remote!!)
        }
        override fun onServiceDisconnected(name: ComponentName) = lostConnection()
        override fun onBindingDied(name: ComponentName) = lostConnection()
        override fun onNullBinding(name: ComponentName) = lostConnection()
    }

    suspend fun open(path: String): Map<String, Any> = exclusive {
        if (documentId != null) throw WalletNativeException("busy")
        var input: ParcelFileDescriptor? = null
        try {
            withContext(Dispatchers.IO) { input = privatePdfDescriptor(path) }
            val response = request(DocumentPdfService.OPEN, Bundle().apply {
                putParcelable("input", input)
            })
            val id = response.getString("id") ?: throw WalletNativeException("invalid_result")
            val pages = response.getInt("pageCount")
            if (pages <= 0) throw WalletNativeException("invalid_result")
            documentId = id
            mapOf("id" to id, "pageCount" to pages)
        } finally {
            input?.close()
        }
    }

    suspend fun render(id: String, page: Int, width: Int): ByteArray = exclusive {
        if (id != documentId) throw WalletNativeException("invalid_session")
        if (page < 0 || width !in 1..WalletLimits.MAX_RENDER_WIDTH) {
            throw WalletNativeException("invalid_arguments")
        }
        var output: ParcelFileDescriptor? = null
        try {
            withContext(Dispatchers.IO) { output = ephemeralOutput() }
            val descriptor = checkNotNull(output)
            request(DocumentPdfService.RENDER, Bundle().apply {
                putString("id", id)
                putInt("page", page)
                putInt("width", width)
                putParcelable("output", descriptor)
            })
            withContext(Dispatchers.IO) {
                require(descriptor.statSize in 1..WalletLimits.MAX_PNG_BYTES) { "size_limit" }
                Os.lseek(descriptor.fileDescriptor, 0, OsConstants.SEEK_SET)
                ParcelFileDescriptor.AutoCloseInputStream(ParcelFileDescriptor.dup(descriptor.fileDescriptor)).use { stream ->
                    ByteArrayOutputStream().use { bytes ->
                        WalletLimits.copyBounded(stream, bytes, WalletLimits.MAX_PNG_BYTES)
                        bytes.toByteArray()
                    }
                }
            }
        } finally {
            output?.close()
        }
    }

    suspend fun close(id: String) {
        if (documentId != null && id != documentId) throw WalletNativeException("invalid_session")
        // Revocation/route disposal must interrupt an in-flight render, never wait behind it.
        if (busy) {
            reset("cancelled")
            return
        }
        exclusive {
            try {
                if (remote != null) request(DocumentPdfService.CLOSE, Bundle().apply { putString("id", id) })
            } finally {
                reset("closed")
            }
        }
    }

    fun dispose() {
        disposed = true
        reset("cancelled")
    }

    fun onBackground() {
        reset("cancelled")
    }

    private suspend fun <T> exclusive(action: suspend () -> T): T {
        if (disposed) throw WalletNativeException("cancelled")
        if (busy) throw WalletNativeException("busy")
        busy = true
        operationGeneration = generation
        try {
            val value = action()
            if (operationGeneration != generation) {
                if (value is ByteArray) value.fill(0)
                throw WalletNativeException("cancelled")
            }
            return value
        } finally {
            busy = false
        }
    }

    private suspend fun request(operation: Int, data: Bundle): Bundle {
        if (operationGeneration != generation || disposed) throw WalletNativeException("cancelled")
        try {
            return withTimeout(20_000) {
                val service = connect()
                val response = CompletableDeferred<Bundle>()
                pending = response
                sequence++
                service.send(Message.obtain(null, operation, sequence, 0).apply {
                    this.data = data
                    replyTo = reply
                })
                val result = response.await()
                result.getString("error")?.let { throw WalletNativeException(it) }
                result
            }
        } catch (error: Exception) {
            reset("pdf_unavailable")
            throw error
        } finally {
            pending = null
        }
    }

    private suspend fun connect(): Messenger {
        if (disposed) throw WalletNativeException("cancelled")
        remote?.let { return it }
        val ready = CompletableDeferred<Messenger>()
        connecting = ready
        bound = context.bindService(Intent(context, DocumentPdfService::class.java), connection, Context.BIND_AUTO_CREATE)
        if (!bound) throw WalletNativeException("unsupported")
        return ready.await()
    }

    private fun lostConnection() = reset("pdf_unavailable")

    private fun reset(code: String) {
        generation++
        pending?.completeExceptionally(WalletNativeException(code))
        connecting?.completeExceptionally(WalletNativeException(code))
        pending = null
        connecting = null
        remote = null
        documentId = null
        if (bound) {
            bound = false
            context.unbindService(connection)
        }
    }

    private fun privatePdfDescriptor(path: String): ParcelFileDescriptor {
        val source = File(path).canonicalFile
        val allowed = listOf(context.cacheDir, context.filesDir, context.noBackupFilesDir,
            context.getDir("flutter", Context.MODE_PRIVATE))
        require(File(path).isAbsolute && allowed.any { WalletLimits.isWithin(source, it) }) {
            "invalid_file"
        }
        require(source.isFile && source.length() in 1..WalletLimits.MAX_INPUT_BYTES) { "size_limit" }
        val temporary = temporaryFile()
        var reader: ParcelFileDescriptor? = null
        var writer: ParcelFileDescriptor? = null
        try {
            reader = ParcelFileDescriptor.open(temporary, ParcelFileDescriptor.MODE_READ_ONLY)
            writer = ParcelFileDescriptor.open(temporary, ParcelFileDescriptor.MODE_WRITE_ONLY)
            // Remove the name before any plaintext is copied, including crash paths.
            if (!temporary.delete()) throw IOException("cleanup_failed")
            source.inputStream().use { input ->
                ParcelFileDescriptor.AutoCloseOutputStream(writer).use { output ->
                    WalletLimits.copyBounded(input, output, WalletLimits.MAX_INPUT_BYTES)
                }
            }
            return reader
        } catch (error: Exception) {
            reader?.close()
            throw error
        } finally {
            writer?.close()
            if (temporary.exists() && !temporary.delete()) throw IOException("cleanup_failed")
        }
    }

    private fun ephemeralOutput(): ParcelFileDescriptor {
        val temporary = temporaryFile()
        val descriptor = ParcelFileDescriptor.open(temporary, ParcelFileDescriptor.MODE_READ_WRITE)
        if (!temporary.delete()) {
            descriptor.close()
            throw IOException("cleanup_failed")
        }
        return descriptor
    }

    private fun temporaryFile(): File {
        val root = File(context.noBackupFilesDir, "wallet_pdf_ephemeral")
        check(root.isDirectory || root.mkdirs()) { "storage_failed" }
        val file = File(root, "${UUID.randomUUID()}.tmp")
        check(file.createNewFile()) { "storage_failed" }
        return file
    }
}
