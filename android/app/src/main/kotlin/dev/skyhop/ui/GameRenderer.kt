package dev.skyhop.ui

import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.clipRect
import androidx.compose.ui.graphics.drawscope.rotate
import dev.skyhop.core.GameConfig
import dev.skyhop.core.GameState
import dev.skyhop.core.Phase
import kotlin.math.PI
import kotlin.math.ceil
import kotlin.math.sin
import kotlin.random.Random

/*
 * Renders a GameState onto a Compose canvas. One world unit equals the canvas height in pixels.
 * Every repeating pattern uses (parallax factor * 60) as a multiple of its period so the
 * scroll never jumps when GameState.distance wraps around.
 */

private class Star(val xFraction: Float, val y: Float, val radius: Float, val phase: Float)

private val stars: List<Star> = Random(7).let { rnd ->
    List(36) { Star(rnd.nextFloat(), rnd.nextFloat() * 0.38f, 0.0018f + rnd.nextFloat() * 0.0022f, rnd.nextFloat() * 6f) }
}

val SkyBrush = Brush.verticalGradient(
    0f to Palette.SkyTop,
    0.55f to Palette.SkyMid,
    1f to Palette.SkyBottom,
)

fun DrawScope.drawGame(state: GameState, config: GameConfig) {
    val unit = size.height
    if (unit <= 0f) return
    drawRect(SkyBrush)
    drawStars(unit, state)
    drawClouds(unit, state)
    drawHills(unit, state, config, factor = 0.25f, period = 1.0f, height = 0.10f, amplitude = 0.035f, color = Palette.HillFar)
    drawHills(unit, state, config, factor = 0.5f, period = 0.75f, height = 0.05f, amplitude = 0.03f, color = Palette.HillNear)
    state.pipes.forEach { drawPipe(it.x, it.gapCenterY, unit, config) }
    drawGround(unit, state, config)
    drawBird(unit, state, config)
}

private fun DrawScope.drawStars(unit: Float, state: GameState) {
    stars.forEach { star ->
        val twinkle = 0.55f + 0.45f * sin(state.time * 1.7f + star.phase)
        drawCircle(
            color = Palette.Star.copy(alpha = twinkle),
            radius = star.radius * unit,
            center = Offset(star.xFraction * size.width, star.y * unit),
        )
    }
}

private fun DrawScope.drawClouds(unit: Float, state: GameState) {
    val period = 1.2f
    val offset = (state.distance * 0.2f) % period
    val count = ceil(size.width / unit / period).toInt() + 1
    for (i in -1..count) {
        val base = i * period - offset
        cloud(unit, base + 0.25f, 0.2f, 0.05f)
        cloud(unit, base + 0.85f, 0.33f, 0.035f)
    }
}

private fun DrawScope.cloud(unit: Float, x: Float, y: Float, r: Float) {
    drawCircle(Palette.Cloud, r * unit, Offset(x * unit, y * unit))
    drawCircle(Palette.Cloud, r * 0.8f * unit, Offset((x - r * 1.1f) * unit, (y + r * 0.25f) * unit))
    drawCircle(Palette.Cloud, r * 0.75f * unit, Offset((x + r * 1.1f) * unit, (y + r * 0.3f) * unit))
}

private fun DrawScope.drawHills(
    unit: Float, state: GameState, config: GameConfig,
    factor: Float, period: Float, height: Float, amplitude: Float, color: Color,
) {
    val offset = (state.distance * factor) % period
    val base = config.groundTop - height
    val step = 6f // pixels between path points
    val path = Path().apply {
        moveTo(0f, config.groundTop * unit)
        var px = 0f
        while (px <= size.width + step) {
            val worldX = px / unit + offset
            val wave = 0.5f + 0.5f * sin(worldX / period * 2f * PI.toFloat())
            lineTo(px, (base - amplitude * wave) * unit)
            px += step
        }
        lineTo(size.width + step, config.groundTop * unit)
        close()
    }
    drawPath(path, color)
}

private fun DrawScope.drawPipe(x: Float, gapCenter: Float, unit: Float, config: GameConfig) {
    val left = x * unit
    val width = config.pipeWidth * unit
    val gapTop = (gapCenter - config.pipeGap / 2f) * unit
    val gapBottom = (gapCenter + config.pipeGap / 2f) * unit
    val groundTop = config.groundTop * unit

    val body = Brush.horizontalGradient(
        0f to Palette.PipeLight, 0.35f to Palette.PipeMid, 1f to Palette.PipeDark,
        startX = left, endX = left + width,
    )
    drawRect(body, Offset(left, 0f), Size(width, gapTop))
    drawRect(body, Offset(left, gapBottom), Size(width, groundTop - gapBottom))

    val capHeight = 0.035f * unit
    val overhang = width * 0.08f
    val capBrush = Brush.horizontalGradient(
        0f to Palette.PipeLight, 0.35f to Palette.PipeMid, 1f to Palette.PipeDark,
        startX = left - overhang, endX = left + width + overhang,
    )
    val capSize = Size(width + overhang * 2, capHeight)
    val corner = CornerRadius(capHeight * 0.25f)
    drawRoundRect(capBrush, Offset(left - overhang, gapTop - capHeight), capSize, corner)
    drawRoundRect(capBrush, Offset(left - overhang, gapBottom), capSize, corner)
}

private fun DrawScope.drawGround(unit: Float, state: GameState, config: GameConfig) {
    val top = config.groundTop * unit
    drawRect(Palette.Ground, Offset(0f, top), Size(size.width, size.height - top))

    val band = 0.022f * unit
    drawRect(Palette.Grass, Offset(0f, top), Size(size.width, band))
    val stripe = 0.06f
    val offset = state.distance % stripe
    clipRect(0f, top, size.width, top + band) {
        var x = -offset - stripe
        while (x * unit < size.width) {
            val path = Path().apply {
                moveTo(x * unit, top + band)
                lineTo((x + 0.03f) * unit, top + band)
                lineTo((x + 0.045f) * unit, top)
                lineTo((x + 0.015f) * unit, top)
                close()
            }
            drawPath(path, Palette.GrassLight)
            x += stripe
        }
    }
    drawRect(Palette.GroundShade, Offset(0f, top + band), Size(size.width, 0.008f * unit))
}

private fun DrawScope.drawBird(unit: Float, state: GameState, config: GameConfig) {
    val cx = state.birdX(config) * unit
    val cy = state.birdY * unit
    val r = config.birdRadius * unit
    val flap = if (state.phase == Phase.GameOver) 0f else sin(state.time * 22f)

    rotate(degrees = state.birdRotation, pivot = Offset(cx, cy)) {
        drawCircle(Palette.BirdBody, r, Offset(cx, cy))
        drawOval(Palette.BirdBelly, Offset(cx - r * 0.55f, cy + r * 0.05f), Size(r * 1.1f, r * 0.75f))

        val wingHeight = r * (0.6f + 0.25f * flap)
        drawOval(
            Palette.BirdWing,
            Offset(cx - r * 1.0f, cy - wingHeight / 2f + r * 0.12f * flap),
            Size(r * 1.05f, wingHeight),
        )

        drawCircle(Color.White, r * 0.36f, Offset(cx + r * 0.38f, cy - r * 0.32f))
        drawCircle(Palette.Pupil, r * 0.16f, Offset(cx + r * 0.5f, cy - r * 0.3f))

        val beak = Path().apply {
            moveTo(cx + r * 0.7f, cy - r * 0.05f)
            lineTo(cx + r * 1.4f, cy + r * 0.17f)
            lineTo(cx + r * 0.7f, cy + r * 0.42f)
            close()
        }
        drawPath(beak, Palette.Beak)
    }
}
