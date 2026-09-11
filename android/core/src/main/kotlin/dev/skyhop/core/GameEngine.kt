package dev.skyhop.core

import kotlin.math.max
import kotlin.math.min
import kotlin.math.sin
import kotlin.random.Random

/**
 * Pure game logic with no dependency on Android. The UI calls [update] once per frame
 * and [tap] on touch, then draws [state].
 */
class GameEngine(
    val config: GameConfig = GameConfig(),
    private val random: Random = Random.Default,
    worldWidth: Float = DEFAULT_WORLD_WIDTH,
    best: Int = 0,
) {
    var state: GameState = GameState.initial(config, worldWidth, best)
        private set

    private var nextPipeId = 0L

    val canRestart: Boolean
        get() = state.phase == Phase.GameOver && state.gameOverTime >= config.restartDelay

    /** Restores a previously saved snapshot, useful for tests and for surviving process death. */
    fun restore(saved: GameState) {
        state = saved
        nextPipeId = (saved.pipes.maxOfOrNull { it.id } ?: -1L) + 1
    }

    fun resize(worldWidth: Float) {
        if (worldWidth > 0f && worldWidth.isFinite() && worldWidth != state.worldWidth) {
            state = state.copy(worldWidth = worldWidth)
        }
    }

    /** Called when the stored best score finishes loading. Never lowers the current best. */
    fun updateBest(best: Int) {
        if (best > state.best) state = state.copy(best = best)
    }

    fun tap(): List<GameEvent> = when (state.phase) {
        Phase.Ready, Phase.Paused -> {
            state = state.copy(phase = Phase.Playing)
            flap()
        }
        Phase.Playing -> flap()
        Phase.GameOver -> {
            if (canRestart) reset()
            emptyList()
        }
    }

    fun pause() {
        if (state.phase == Phase.Playing) state = state.copy(phase = Phase.Paused)
    }

    fun reset() {
        // Keep the scroll distance and clock so the background does not jump.
        state = GameState.initial(config, state.worldWidth, state.best)
            .copy(distance = state.distance, time = state.time)
    }

    fun update(deltaSeconds: Float): List<GameEvent> {
        // `!(x > 0)` also rejects NaN.
        if (!(deltaSeconds > 0f)) return emptyList()
        val dt = min(deltaSeconds, config.maxFrameTime)
        return when (state.phase) {
            Phase.Ready -> {
                stepReady(dt)
                emptyList()
            }
            Phase.Playing -> stepPlaying(dt)
            Phase.Paused -> emptyList()
            Phase.GameOver -> {
                stepGameOver(dt)
                emptyList()
            }
        }
    }

    fun rotationFor(velocity: Float): Float =
        ((velocity / config.maxFallSpeed) * 110f - 20f).coerceIn(-22f, 90f)

    private fun flap(): List<GameEvent> {
        state = state.copy(birdVelocity = config.flapVelocity)
        return listOf(GameEvent.Flap)
    }

    private fun stepReady(dt: Float) {
        val time = state.time + dt
        state = state.copy(
            time = time,
            distance = advance(state.distance, dt),
            birdY = config.startY + sin(time * BOB_SPEED) * BOB_AMPLITUDE,
            birdVelocity = 0f,
            birdRotation = 0f,
        )
    }

    private fun stepPlaying(dt: Float): List<GameEvent> {
        val events = mutableListOf<GameEvent>()

        var velocity = min(state.birdVelocity + config.gravity * dt, config.maxFallSpeed)
        var y = state.birdY + velocity * dt
        if (y < 0f) {
            y = 0f
            velocity = max(velocity, 0f)
        }

        val dx = config.scrollSpeed * dt
        val birdX = state.birdX(config)
        var score = state.score
        val moved = state.pipes.mapNotNull { pipe ->
            val x = pipe.x - dx
            if (x + config.pipeWidth < -config.pipeWidth) {
                null // far off the left edge
            } else if (!pipe.scored && x + config.pipeWidth / 2f < birdX) {
                score++
                events += GameEvent.Score
                pipe.copy(x = x, scored = true)
            } else {
                pipe.copy(x = x)
            }
        }

        state = state.copy(
            time = state.time + dt,
            distance = advance(state.distance, dt),
            birdY = y,
            birdVelocity = velocity,
            birdRotation = rotationFor(velocity),
            pipes = spawnPipes(moved),
            score = score,
        )

        if (hitsGround(y) || hitsPipe(birdX, y, state.pipes)) {
            events += crash()
        }
        return events
    }

    private fun stepGameOver(dt: Float) {
        val floor = config.groundTop - config.birdRadius
        var velocity = min(state.birdVelocity + config.gravity * dt, config.maxFallSpeed)
        var y = state.birdY + velocity * dt
        if (y >= floor) {
            y = floor
            velocity = 0f
        }
        state = state.copy(
            time = state.time + dt,
            gameOverTime = state.gameOverTime + dt,
            birdY = y,
            birdVelocity = velocity,
            // Only ever tilt further down while falling, so the bird nose dives and stays that way.
            birdRotation = max(state.birdRotation, rotationFor(velocity)),
        )
    }

    private fun crash(): List<GameEvent> {
        val isNewBest = state.score > state.best
        val floor = config.groundTop - config.birdRadius
        state = state.copy(
            phase = Phase.GameOver,
            gameOverTime = 0f,
            birdY = min(state.birdY, floor),
            best = max(state.best, state.score),
            isNewBest = isNewBest,
        )
        return if (isNewBest) listOf(GameEvent.Hit, GameEvent.NewBest) else listOf(GameEvent.Hit)
    }

    private fun hitsGround(y: Float): Boolean = y + config.birdRadius >= config.groundTop

    private fun hitsPipe(birdX: Float, y: Float, pipes: List<PipePair>): Boolean {
        val r = config.birdRadius * config.hitboxScale
        val halfGap = config.pipeGap / 2f
        return pipes.any { pipe ->
            val right = pipe.x + config.pipeWidth
            Collision.circleIntersectsRect(birdX, y, r, pipe.x, -10f, right, pipe.gapCenterY - halfGap) ||
                Collision.circleIntersectsRect(birdX, y, r, pipe.x, pipe.gapCenterY + halfGap, right, config.groundTop)
        }
    }

    /**
     * Pipes are placed at exact multiples of [GameConfig.pipeSpacing] so spacing never drifts
     * with frame rate. A new pipe is created while it is still off screen to the right.
     */
    private fun spawnPipes(current: List<PipePair>): List<PipePair> {
        val pipes = current.toMutableList()
        if (pipes.isEmpty()) {
            pipes += newPipe(state.worldWidth + config.firstPipeOffset, previousGap = null)
        }
        while (pipes.last().x + config.pipeSpacing < state.worldWidth + config.pipeWidth) {
            val last = pipes.last()
            pipes += newPipe(last.x + config.pipeSpacing, last.gapCenterY)
        }
        return pipes
    }

    private fun newPipe(x: Float, previousGap: Float?): PipePair {
        val low = if (previousGap == null) config.minGapCenter else max(config.minGapCenter, previousGap - config.maxGapShift)
        val high = if (previousGap == null) config.maxGapCenter else min(config.maxGapCenter, previousGap + config.maxGapShift)
        val center = low + random.nextFloat() * (high - low)
        return PipePair(id = nextPipeId++, x = x, gapCenterY = center)
    }

    private fun advance(distance: Float, dt: Float): Float =
        (distance + config.scrollSpeed * dt) % GameState.DISTANCE_PERIOD

    companion object {
        const val DEFAULT_WORLD_WIDTH = 0.46f // roughly a 9:19.5 phone in portrait
        private const val BOB_SPEED = 5f
        private const val BOB_AMPLITUDE = 0.012f
    }
}
