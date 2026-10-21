package co.picoradar.app.wallet

import java.io.File
import java.io.InputStream
import java.io.OutputStream
import kotlin.math.ceil

internal object WalletLimits {
    const val MAX_INPUT_BYTES = 25L * 1024 * 1024
    const val MAX_RENDER_WIDTH = 2048
    const val MAX_RENDER_HEIGHT = 4096
    const val MAX_RENDER_PIXELS = 4L * 1024 * 1024
    const val MAX_PNG_BYTES = 20L * 1024 * 1024
    private val captureName = Regex("scan-[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\\.jpg")
    private val sdkCaptureName = Regex("[0-9]+\\.jpg")

    fun ownedCapture(path: String, root: File): File {
        val file = File(path).canonicalFile
        require(file.parentFile == root.canonicalFile && captureName.matches(file.name)) {
            "invalid_arguments"
        }
        return file
    }

    fun ownedSdkCapture(path: String, cacheRoot: File): File {
        val file = File(path).canonicalFile
        val root = File(cacheRoot.canonicalFile, "mlkit_docscan_ui_client")
        require(file.parentFile == root && sdkCaptureName.matches(file.name)) {
            "invalid_result"
        }
        return file
    }

    fun scanPages(pages: Int) {
        require(pages in 1..2) { "invalid_arguments" }
    }

    fun validatePdfPages(pageCount: Int, dimensions: (Int) -> Pair<Int, Int>) {
        require(pageCount > 0) { "invalid_file" }
        for (index in 0 until pageCount) {
            val (width, height) = dimensions(index)
            require(width > 0 && height > 0) { "invalid_file" }
            // Metadata must admit some bounded raster; actual display widths
            // still pass through renderHeight before allocating any bitmap.
            renderHeight(width, height, 1)
        }
    }

    fun renderHeight(pageWidth: Int, pageHeight: Int, width: Int): Int {
        require(pageWidth > 0 && pageHeight > 0 && width in 1..MAX_RENDER_WIDTH) {
            "invalid_arguments"
        }
        val height = ceil(pageHeight.toDouble() * width / pageWidth)
        require(height in 1.0..MAX_RENDER_HEIGHT.toDouble() &&
            height * width <= MAX_RENDER_PIXELS) { "size_limit" }
        return height.toInt()
    }

    fun isWithin(file: File, root: File): Boolean =
        file.canonicalPath.startsWith(root.canonicalPath + File.separator)

    fun copyBounded(input: InputStream, output: OutputStream, limit: Long) {
        val buffer = ByteArray(8192)
        var total = 0L
        try {
            while (true) {
                val count = input.read(buffer)
                if (count < 0) break
                total += count
                require(total <= limit) { "size_limit" }
                output.write(buffer, 0, count)
            }
            require(total > 0) { "invalid_file" }
        } finally {
            buffer.fill(0)
        }
    }
}
