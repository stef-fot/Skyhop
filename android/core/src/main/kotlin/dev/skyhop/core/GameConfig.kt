package dev.skyhop.core

/**
 * Tunable game constants.
 *
 * Everything is expressed in world units: the world is always 1.0 tall and its width
 * depends on the screen aspect ratio (width / height). Because physics never deals with
 * pixels, the game feels identical on every screen size and density.
 * The y axis points down, matching Compose and SwiftUI canvases.
 */
data class GameConfig(
    val groundHeight: Float = 0.12f,
    val birdRadius: Float = 0.026f,
    /** Horizontal bird position as a fraction of the world width. */
    val birdXRatio: Float = 0.3f,
    val startY: Float = 0.42f,
    /** Units per second squared. */
    val gravity: Float = 2.6f,
    /** Instant vertical velocity applied on every flap (negative = up). */
    val flapVelocity: Float = -0.78f,
    val maxFallSpeed: Float = 1.3f,
    val pipeWidth: Float = 0.13f,
    val pipeGap: Float = 0.25f,
    /** Distance between the left edges of two consecutive pipes. */
    val pipeSpacing: Float = 0.44f,
    /** How far beyond the right edge the first pipe appears. */
    val firstPipeOffset: Float = 0.2f,
    val scrollSpeed: Float = 0.28f,
    /** Minimum distance between a gap and the top of the screen or the ground. */
    val gapMargin: Float = 0.08f,
    /** Maximum vertical jump between two consecutive gaps, keeps every level beatable. */
    val maxGapShift: Float = 0.22f,
    /** The collision circle is slightly smaller than the drawn bird, which feels fairer. */
    val hitboxScale: Float = 0.85f,
    /** Frame time is clamped so a hiccup (or resuming the app) never teleports the bird. */
    val maxFrameTime: Float = 1f / 30f,
    /** Seconds after a crash before a tap restarts, prevents accidental instant restarts. */
    val restartDelay: Float = 0.6f,
) {
    val groundTop: Float get() = 1f - groundHeight
    val minGapCenter: Float get() = gapMargin + pipeGap / 2f
    val maxGapCenter: Float get() = groundTop - gapMargin - pipeGap / 2f
}
