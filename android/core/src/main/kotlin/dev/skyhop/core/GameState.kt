package dev.skyhop.core

enum class Phase { Ready, Playing, Paused, GameOver }

enum class GameEvent { Flap, Score, Hit, NewBest }

data class PipePair(
    val id: Long,
    /** Left edge of the pipe in world units. */
    val x: Float,
    val gapCenterY: Float,
    val scored: Boolean = false,
)

/** Immutable snapshot of the game. The renderer only reads this, it never mutates anything. */
data class GameState(
    val phase: Phase,
    val worldWidth: Float,
    val birdY: Float,
    val birdVelocity: Float,
    /** Degrees, negative = nose up. */
    val birdRotation: Float,
    val pipes: List<PipePair>,
    val score: Int,
    val best: Int,
    val isNewBest: Boolean,
    /** Scrolled distance, wrapped at [DISTANCE_PERIOD]. Drives ground and parallax animation. */
    val distance: Float,
    /** Seconds since launch, drives the wing and idle animations. */
    val time: Float,
    val gameOverTime: Float,
) {
    fun birdX(config: GameConfig): Float = worldWidth * config.birdXRatio

    companion object {
        /** Every repeating background pattern uses a period that divides this value evenly. */
        const val DISTANCE_PERIOD = 60f

        fun initial(config: GameConfig, worldWidth: Float, best: Int) = GameState(
            phase = Phase.Ready,
            worldWidth = worldWidth,
            birdY = config.startY,
            birdVelocity = 0f,
            birdRotation = 0f,
            pipes = emptyList(),
            score = 0,
            best = best,
            isNewBest = false,
            distance = 0f,
            time = 0f,
            gameOverTime = 0f,
        )
    }
}
