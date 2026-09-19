package co.picoradar.app.alerts

internal enum class AlertEnd { STOP, CUTOFF, INTERRUPTED }

// Main-thread resource ownership. Invalidate callbacks before releasing focus/player/wake.
internal class AlertSession(private val release: () -> Unit) {
    var event: AlertEvent? = null
        private set
    var generation = 0L
        private set

    fun begin(next: AlertEvent): Long {
        clear()
        generation++
        event = next
        return generation
    }

    fun clear(): AlertEvent? {
        val previous = event
        generation++
        event = null
        if (previous != null) release()
        return previous
    }

    fun isCurrent(value: Long) = event != null && generation == value
}
