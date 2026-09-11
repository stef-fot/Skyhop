package dev.skyhop.core

import org.junit.Test
import kotlin.random.Random
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class GameEngineTest {
    private val config = GameConfig()
    private val frame = 1f / 60f

    private fun engine(seed: Int = 1, width: Float = 0.46f, best: Int = 0) =
        GameEngine(config, Random(seed), width, best)

    /** Runs [seconds] of simulation at 60 fps without touching the screen. */
    private fun GameEngine.run(seconds: Float): List<GameEvent> {
        val events = mutableListOf<GameEvent>()
        repeat((seconds / frame).toInt()) { events += update(frame) }
        return events
    }

    @Test
    fun startsReadyWithNoPipes() {
        val e = engine()
        assertEquals(Phase.Ready, e.state.phase)
        e.run(2f)
        assertEquals(Phase.Ready, e.state.phase)
        assertTrue(e.state.pipes.isEmpty())
    }

    @Test
    fun readyStateBobsWithoutFalling() {
        val e = engine()
        e.run(3f)
        assertTrue(kotlin.math.abs(e.state.birdY - config.startY) <= 0.0121f)
        assertTrue(e.state.distance > 0f, "ground keeps scrolling on the title screen")
    }

    @Test
    fun firstTapStartsGameAndFlaps() {
        val e = engine()
        val events = e.tap()
        assertEquals(listOf(GameEvent.Flap), events)
        assertEquals(Phase.Playing, e.state.phase)
        assertEquals(config.flapVelocity, e.state.birdVelocity)
    }

    @Test
    fun gravityAcceleratesTheBird() {
        val e = engine()
        e.tap()
        val before = e.state.birdVelocity
        e.update(0.01f)
        assertEquals(before + config.gravity * 0.01f, e.state.birdVelocity, 1e-5f)
    }

    @Test
    fun fallSpeedIsCapped() {
        val e = engine()
        e.tap()
        e.restore(e.state.copy(birdY = 0.1f, birdVelocity = config.maxFallSpeed))
        e.update(frame)
        assertEquals(config.maxFallSpeed, e.state.birdVelocity)
    }

    @Test
    fun hugeFrameTimeIsClamped() {
        val a = engine(); a.tap(); a.update(5f)
        val b = engine(); b.tap(); b.update(config.maxFrameTime)
        assertEquals(b.state.birdY, a.state.birdY, 1e-6f)
    }

    @Test
    fun invalidFrameTimesAreIgnored() {
        val e = engine()
        e.tap()
        val before = e.state
        e.update(0f); e.update(-1f); e.update(Float.NaN)
        assertEquals(before, e.state)
    }

    @Test
    fun birdCannotLeaveTheTopOfTheScreen() {
        val e = engine()
        e.tap()
        e.restore(e.state.copy(birdY = 0.005f, birdVelocity = config.flapVelocity))
        e.update(frame)
        assertEquals(0f, e.state.birdY)
        assertTrue(e.state.birdVelocity >= 0f)
    }

    @Test
    fun hittingTheGroundEndsTheGame() {
        val e = engine()
        e.tap()
        val events = e.run(3f) // never flap again
        assertEquals(Phase.GameOver, e.state.phase)
        assertTrue(GameEvent.Hit in events)
        assertEquals(config.groundTop - config.birdRadius, e.state.birdY, 1e-5f)
    }

    @Test
    fun hittingAPipeEndsTheGame() {
        val e = engine()
        e.tap()
        val birdX = e.state.birdX(config)
        // PipePair right on the bird, gap far below it.
        val pipe = PipePair(id = 0, x = birdX - config.pipeWidth / 2f, gapCenterY = config.maxGapCenter)
        e.restore(e.state.copy(birdY = 0.15f, birdVelocity = 0f, pipes = listOf(pipe)))
        val events = e.update(frame)
        assertEquals(Phase.GameOver, e.state.phase)
        assertTrue(GameEvent.Hit in events)
    }

    @Test
    fun flyingThroughTheMiddleOfAGapIsSafe() {
        val e = engine()
        e.tap()
        val birdX = e.state.birdX(config)
        val pipe = PipePair(id = 0, x = birdX - config.pipeWidth / 2f, gapCenterY = 0.4f)
        e.restore(e.state.copy(birdY = 0.4f, birdVelocity = 0f, pipes = listOf(pipe)))
        e.update(frame)
        assertEquals(Phase.Playing, e.state.phase)
    }

    @Test
    fun passingAPipeScoresExactlyOnce() {
        val e = engine()
        e.tap()
        val birdX = e.state.birdX(config)
        val pipe = PipePair(id = 0, x = birdX - config.pipeWidth / 2f + 0.001f, gapCenterY = 0.4f)
        e.restore(e.state.copy(birdY = 0.4f, birdVelocity = 0f, pipes = listOf(pipe)))
        var scoreEvents = 0
        repeat(10) {
            e.restore(e.state.copy(birdY = 0.4f, birdVelocity = 0f)) // hover in the gap
            scoreEvents += e.update(frame).count { it == GameEvent.Score }
        }
        assertEquals(1, scoreEvents)
        assertEquals(1, e.state.score)
    }

    @Test
    fun pipesSpawnOffScreenWithConstantSpacing() {
        val e = engine()
        e.tap()
        val seenIds = mutableSetOf<Long>()
        repeat(600) {
            // Force Playing and keep the bird in a harmless spot so the world keeps scrolling.
            e.restore(e.state.copy(birdY = 0.4f, birdVelocity = 0f, phase = Phase.Playing))
            e.update(frame)
            val pipes = e.state.pipes
            pipes.zipWithNext { a, b -> assertEquals(config.pipeSpacing, b.x - a.x, 1e-3f) }
            pipes.filter { seenIds.add(it.id) }.forEach { fresh ->
                assertTrue(fresh.x >= e.state.worldWidth, "pipe ${fresh.id} popped in at x=${fresh.x}")
            }
        }
        assertTrue(seenIds.size >= 5)
    }

    @Test
    fun gapsStayInBoundsAndReachable() {
        for (seed in 0 until 20) {
            val e = engine(seed)
            e.tap()
            val seen = mutableMapOf<Long, PipePair>()
            repeat(3000) {
                // Force Playing so a collision never stops the level generator.
                e.restore(e.state.copy(birdY = 0.4f, birdVelocity = 0f, phase = Phase.Playing))
                e.update(frame)
                e.state.pipes.forEach { seen[it.id] = it }
            }
            val ordered = seen.values.sortedBy { it.id }
            assertTrue(ordered.size > 20)
            ordered.forEach {
                assertTrue(it.gapCenterY in config.minGapCenter..config.maxGapCenter)
            }
            ordered.zipWithNext { a, b ->
                assertTrue(kotlin.math.abs(b.gapCenterY - a.gapCenterY) <= config.maxGapShift + 1e-5f)
            }
        }
    }

    @Test
    fun crashUpdatesBestScore() {
        val e = engine(best = 2)
        e.tap()
        e.restore(e.state.copy(score = 5))
        val events = e.run(3f)
        assertEquals(5, e.state.best)
        assertTrue(e.state.isNewBest)
        assertTrue(GameEvent.NewBest in events)
    }

    @Test
    fun lowerScoreKeepsOldBest() {
        val e = engine(best = 10)
        e.tap()
        e.restore(e.state.copy(score = 3))
        val events = e.run(3f)
        assertEquals(10, e.state.best)
        assertFalse(e.state.isNewBest)
        assertFalse(GameEvent.NewBest in events)
    }

    @Test
    fun restartNeedsAShortDelay() {
        val e = engine()
        e.tap()
        e.run(3f) // crash into the ground
        e.restore(e.state.copy(gameOverTime = 0f))
        e.tap()
        assertEquals(Phase.GameOver, e.state.phase, "an immediate tap must not restart")
        e.run(config.restartDelay + 0.05f)
        e.tap()
        assertEquals(Phase.Ready, e.state.phase)
        assertEquals(0, e.state.score)
        assertTrue(e.state.pipes.isEmpty())
    }

    @Test
    fun pauseFreezesTheWorldAndTapResumes() {
        val e = engine()
        e.tap()
        e.run(0.2f)
        e.pause()
        val frozen = e.state
        e.run(1f)
        assertEquals(frozen, e.state)
        assertEquals(listOf(GameEvent.Flap), e.tap())
        assertEquals(Phase.Playing, e.state.phase)
    }

    @Test
    fun updateBestNeverLowersTheBest() {
        val e = engine(best = 7)
        e.updateBest(3)
        assertEquals(7, e.state.best)
        e.updateBest(9)
        assertEquals(9, e.state.best)
    }

    @Test
    fun rotationFollowsVelocity() {
        val e = engine()
        assertEquals(-22f, e.rotationFor(config.flapVelocity))
        assertEquals(90f, e.rotationFor(config.maxFallSpeed))
        assertTrue(e.rotationFor(0.2f) > e.rotationFor(0f))
    }

    @Test
    fun resizeIgnoresInvalidValues() {
        val e = engine(width = 0.5f)
        e.resize(0f); e.resize(-2f); e.resize(Float.NaN); e.resize(Float.POSITIVE_INFINITY)
        assertEquals(0.5f, e.state.worldWidth)
        e.resize(1.8f)
        assertEquals(1.8f, e.state.worldWidth)
    }

    /**
     * Playability test: a simple bot that flaps whenever it drops below the next gap.
     * If the level generator ever produced an impossible gap, this bot would crash.
     */
    @Test
    fun simpleBotSurvivesTwoMinutesOnAnyScreen() {
        for (width in listOf(0.42f, 0.46f, 0.75f, 1.6f)) {
            for (seed in 0 until 10) {
                val e = engine(seed, width)
                e.tap()
                repeat((120f / frame).toInt()) {
                    val s = e.state
                    val birdX = s.birdX(config)
                    val next = s.pipes.firstOrNull { it.x + config.pipeWidth > birdX - config.birdRadius }
                    val target = next?.gapCenterY ?: 0.45f
                    if (s.birdY > target + 0.03f && s.birdVelocity > 0f) e.tap()
                    e.update(frame)
                    assertEquals(Phase.Playing, e.state.phase, "bot crashed: width=$width seed=$seed score=${e.state.score}")
                }
                assertTrue(e.state.score >= 60, "expected steady progress, got ${e.state.score}")
            }
        }
    }
}
