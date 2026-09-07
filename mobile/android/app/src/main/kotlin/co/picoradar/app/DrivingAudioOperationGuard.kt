package co.picoradar.app

internal class DrivingAudioOperationGuard {
    private var activeOperationId = 0L
    private var activePlayerToken = 0L
    private var playerSerial = 0L

    fun beginOperation(operationId: Long) {
        activeOperationId = operationId
        activePlayerToken = 0L
    }

    fun clearOperation() {
        activeOperationId = 0L
        activePlayerToken = 0L
    }

    fun isActiveOperation(operationId: Long, hasPendingResult: Boolean): Boolean {
        return operationId != 0L && operationId == activeOperationId && hasPendingResult
    }

    fun beginPlayer(operationId: Long, hasPendingResult: Boolean): Long {
        if (!isActiveOperation(operationId, hasPendingResult)) return 0L
        playerSerial += 1
        activePlayerToken = playerSerial
        return activePlayerToken
    }

    fun isCurrentPlayer(
        operationId: Long,
        playerToken: Long,
        hasPendingResult: Boolean,
    ): Boolean {
        return playerToken != 0L &&
            playerToken == activePlayerToken &&
            isActiveOperation(operationId, hasPendingResult)
    }

    fun clearCurrentPlayer() {
        activePlayerToken = 0L
    }
}
