package co.picoradar.app.wallet

import android.app.Service
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.pdf.PdfRenderer
import android.os.Bundle
import android.os.Handler
import android.os.HandlerThread
import android.os.IBinder
import android.os.Message
import android.os.Messenger
import android.os.ParcelFileDescriptor
import android.os.RemoteException
import java.io.FilterOutputStream
import java.io.OutputStream
import java.util.UUID

/** No filesystem paths or URLs cross this boundary, only narrowly granted FDs. */
class DocumentPdfService : Service() {
    private lateinit var worker: HandlerThread
    private lateinit var handler: Handler
    private lateinit var messenger: Messenger
    private var renderer: PdfRenderer? = null
    private var documentId: String? = null

    override fun onCreate() {
        super.onCreate()
        worker = HandlerThread("wallet-pdf")
        worker.start()
        handler = Handler(worker.looper) { message ->
            handle(message)
            true
        }
        messenger = Messenger(handler)
    }

    override fun onBind(intent: Intent): IBinder = messenger.binder

    @Suppress("DEPRECATION")
    private fun handle(message: Message) {
        val data = message.data
        data.classLoader = ParcelFileDescriptor::class.java.classLoader
        val input = data.getParcelable<ParcelFileDescriptor>("input")
        val output = data.getParcelable<ParcelFileDescriptor>("output")
        val response = Bundle()
        var ownsInput = true
        var openedHere = false
        try {
            when (message.what) {
                OPEN -> {
                    require(renderer == null) { "busy" }
                    require(input != null && input.statSize in 1..WalletLimits.MAX_INPUT_BYTES) {
                        "invalid_file"
                    }
                    // PdfRenderer takes ownership only when construction succeeds.
                    val opened = PdfRenderer(input)
                    ownsInput = false
                    renderer = opened
                    openedHere = true
                    val pageCount = opened.pageCount
                    WalletLimits.validatePdfPages(pageCount) { index ->
                        opened.openPage(index).use { page ->
                            require(page.index == index && opened.pageCount == pageCount) {
                                "invalid_file"
                            }
                            page.width to page.height
                        }
                    }
                    documentId = UUID.randomUUID().toString()
                    response.putString("id", documentId)
                    response.putInt("pageCount", pageCount)
                }
                RENDER -> {
                    val active = renderer
                    require(active != null && documentId == data.getString("id")) { "invalid_session" }
                    val pageIndex = data.getInt("page", -1)
                    require(pageIndex in 0 until active.pageCount && output != null) { "invalid_arguments" }
                    active.openPage(pageIndex).use { page ->
                        val width = data.getInt("width")
                        val height = WalletLimits.renderHeight(page.width, page.height, width)
                        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
                        try {
                            bitmap.eraseColor(Color.WHITE)
                            page.render(bitmap, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
                            // Write PNG to the one ephemeral FD, not through Binder's 1 MB buffer.
                            ParcelFileDescriptor.AutoCloseOutputStream(output).use { stream ->
                                check(bitmap.compress(Bitmap.CompressFormat.PNG, 100,
                                    LimitedOutputStream(stream, WalletLimits.MAX_PNG_BYTES))) {
                                    "render_failed"
                                }
                            }
                        } finally {
                            bitmap.eraseColor(Color.TRANSPARENT)
                            bitmap.recycle()
                        }
                    }
                }
                CLOSE -> {
                    // Closing an already-closed session is harmless; never close a different one.
                    require(documentId == null || documentId == data.getString("id")) { "invalid_session" }
                    closeRenderer()
                }
                else -> throw IllegalArgumentException("unsupported")
            }
        } catch (error: Exception) {
            if (openedHere) closeRenderer()
            response.putString("error", when (error) {
                is SecurityException -> "protected_pdf"
                is IllegalArgumentException -> error.message.takeIf { it in ERROR_CODES } ?: "invalid_pdf"
                else -> "pdf_failed"
            })
        } finally {
            if (ownsInput) input?.close()
            // AutoCloseOutputStream may have closed it already; PFD close is idempotent.
            output?.close()
        }
        try {
            message.replyTo?.send(Message.obtain(null, message.what, message.arg1, 0).apply {
                this.data = response
            })
        } catch (_: RemoteException) {
            // The only client died: release plaintext descriptors immediately.
            closeRenderer()
            stopSelf()
        }
    }

    private fun closeRenderer() {
        val active = renderer
        renderer = null
        documentId = null
        active?.close()
    }

    override fun onDestroy() {
        super.onDestroy()
        // Dedicated isolated UID: also terminate a renderer hung in native PDF
        // parsing. The kernel closes its remaining unlinked file descriptors.
        android.os.Process.killProcess(android.os.Process.myPid())
    }

    companion object {
        internal const val OPEN = 1
        internal const val RENDER = 2
        internal const val CLOSE = 3
        private val ERROR_CODES = setOf(
            "busy", "invalid_file", "invalid_session", "invalid_arguments", "size_limit", "unsupported",
        )
    }
}

private class LimitedOutputStream(output: OutputStream, private val limit: Long) : FilterOutputStream(output) {
    private var count = 0L
    override fun write(value: Int) {
        require(++count <= limit) { "size_limit" }
        out.write(value)
    }
    override fun write(bytes: ByteArray, offset: Int, length: Int) {
        require(count + length <= limit) { "size_limit" }
        count += length
        out.write(bytes, offset, length)
    }
}
