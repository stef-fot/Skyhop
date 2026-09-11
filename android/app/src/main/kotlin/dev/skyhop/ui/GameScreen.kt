package dev.skyhop.ui

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawingPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.withFrameNanos
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shadow
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.LifecycleEventEffect
import androidx.lifecycle.viewmodel.compose.viewModel
import dev.skyhop.R
import dev.skyhop.core.GameEvent
import dev.skyhop.core.Phase

/** Only the values the overlay needs, so the overlay recomposes on score changes, not on every frame. */
private data class HudState(
    val phase: Phase,
    val score: Int,
    val best: Int,
    val isNewBest: Boolean,
    val canRestart: Boolean,
)

@Composable
fun GameScreen(viewModel: GameViewModel = viewModel(factory = GameViewModel.Factory)) {
    val haptics = LocalHapticFeedback.current

    // Game loop: one engine step per display frame, driven by the Compose frame clock.
    LaunchedEffect(viewModel) {
        var lastFrame = withFrameNanos { it }
        while (true) {
            withFrameNanos { now ->
                viewModel.onFrame((now - lastFrame) / 1_000_000_000f)
                lastFrame = now
            }
        }
    }

    LaunchedEffect(viewModel) {
        viewModel.events.collect { event ->
            when (event) {
                GameEvent.Score -> haptics.performHapticFeedback(HapticFeedbackType.TextHandleMove)
                GameEvent.Hit -> haptics.performHapticFeedback(HapticFeedbackType.LongPress)
                else -> Unit
            }
        }
    }

    // Pause automatically when the app goes to the background or a call comes in.
    LifecycleEventEffect(Lifecycle.Event.ON_PAUSE) { viewModel.onPause() }

    val hud by remember(viewModel) {
        derivedStateOf {
            val s = viewModel.state
            HudState(
                phase = s.phase,
                score = s.score,
                best = s.best,
                isNewBest = s.isNewBest,
                canRestart = s.phase == Phase.GameOver && s.gameOverTime >= viewModel.config.restartDelay,
            )
        }
    }

    KeepScreenOn(enabled = hud.phase == Phase.Playing)

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Palette.SkyTop)
            .onSizeChanged { viewModel.onResize(it.width, it.height) }
            .pointerInput(viewModel) {
                // React on finger down, not on release: games need the lowest possible latency.
                awaitEachGesture {
                    awaitFirstDown()
                    viewModel.onTap()
                }
            },
    ) {
        // viewModel.state is read inside the draw lambda only, so each frame is a pure redraw.
        Canvas(Modifier.fillMaxSize()) { drawGame(viewModel.state, viewModel.config) }
        Hud(hud)
    }
}

@Composable
private fun BoxScope.Hud(hud: HudState) {
    Box(Modifier.matchParentSize().safeDrawingPadding()) {
        when (hud.phase) {
            Phase.Ready -> ReadyOverlay(hud.best)
            Phase.Playing -> ScoreText(hud.score, Modifier.align(Alignment.TopCenter))
            Phase.Paused -> {
                ScoreText(hud.score, Modifier.align(Alignment.TopCenter))
                Column(Modifier.align(Alignment.Center), horizontalAlignment = Alignment.CenterHorizontally) {
                    Text(stringResource(R.string.paused), style = titleStyle(40.sp))
                    Spacer(Modifier.height(8.dp))
                    PulsingHint(stringResource(R.string.tap_to_resume))
                }
            }
            Phase.GameOver -> Unit
        }
        AnimatedVisibility(
            visible = hud.phase == Phase.GameOver,
            modifier = Modifier.align(Alignment.Center),
            enter = fadeIn(tween(250)) + scaleIn(tween(300), initialScale = 0.85f),
            exit = fadeOut(tween(150)),
        ) {
            GameOverCard(hud)
        }
    }
}

@Composable
private fun BoxScope.ReadyOverlay(best: Int) {
    Column(
        modifier = Modifier.matchParentSize(),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Spacer(Modifier.weight(0.14f))
        Text(stringResource(R.string.app_name), style = titleStyle(56.sp))
        if (best > 0) {
            Text(
                stringResource(R.string.best_score, best),
                style = hudStyle(18.sp).copy(color = Color.White.copy(alpha = 0.8f)),
            )
        }
        Spacer(Modifier.weight(0.5f))
        PulsingHint(stringResource(R.string.tap_to_fly))
        Spacer(Modifier.weight(0.36f))
    }
}

@Composable
private fun ScoreText(score: Int, modifier: Modifier = Modifier) {
    Text(
        text = score.toString(),
        modifier = modifier.padding(top = 32.dp),
        style = titleStyle(64.sp),
    )
}

@Composable
private fun PulsingHint(text: String) {
    val transition = rememberInfiniteTransition(label = "hint")
    val alpha by transition.animateFloat(
        initialValue = 1f,
        targetValue = 0.45f,
        animationSpec = infiniteRepeatable(tween(700), RepeatMode.Reverse),
        label = "hintAlpha",
    )
    Text(text, modifier = Modifier.alpha(alpha), style = hudStyle(22.sp))
}

@Composable
private fun GameOverCard(hud: HudState) {
    Surface(
        color = Palette.Card,
        shape = RoundedCornerShape(28.dp),
        shadowElevation = 12.dp,
        modifier = Modifier.widthIn(max = 320.dp),
    ) {
        Column(
            modifier = Modifier.padding(horizontal = 32.dp, vertical = 28.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Text(
                stringResource(R.string.game_over),
                color = Palette.CardInk,
                fontSize = 30.sp,
                fontWeight = FontWeight.Black,
            )
            Spacer(Modifier.height(20.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(40.dp)) {
                Stat(stringResource(R.string.score), hud.score)
                Stat(stringResource(R.string.best), hud.best)
            }
            if (hud.isNewBest) {
                Spacer(Modifier.height(16.dp))
                Surface(color = Palette.Badge, shape = RoundedCornerShape(50)) {
                    Text(
                        stringResource(R.string.new_best),
                        modifier = Modifier.padding(horizontal = 14.dp, vertical = 6.dp),
                        color = Color.White,
                        fontWeight = FontWeight.Bold,
                    )
                }
            }
            Spacer(Modifier.height(22.dp))
            Text(
                stringResource(R.string.tap_to_play_again),
                modifier = Modifier.alpha(if (hud.canRestart) 1f else 0f),
                color = Palette.CardMuted,
                fontWeight = FontWeight.SemiBold,
            )
        }
    }
}

@Composable
private fun Stat(label: String, value: Int) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Text(label, color = Palette.CardMuted, fontSize = 14.sp, fontWeight = FontWeight.SemiBold)
        Text(
            value.toString(),
            modifier = Modifier.width(80.dp),
            color = Palette.CardInk,
            textAlign = TextAlign.Center,
            style = TextStyle(fontSize = 40.sp, fontWeight = FontWeight.Black, fontFeatureSettings = "tnum"),
        )
    }
}

private val textShadow = Shadow(color = Color(0x59000000), offset = Offset(0f, 5f), blurRadius = 0f)

private fun titleStyle(size: androidx.compose.ui.unit.TextUnit) = TextStyle(
    color = Color.White,
    fontSize = size,
    fontWeight = FontWeight.Black,
    fontFeatureSettings = "tnum",
    textAlign = TextAlign.Center,
    shadow = textShadow,
)

private fun hudStyle(size: androidx.compose.ui.unit.TextUnit) = TextStyle(
    color = Color.White,
    fontSize = size,
    fontWeight = FontWeight.Bold,
    textAlign = TextAlign.Center,
    shadow = textShadow.copy(offset = Offset(0f, 3f)),
)

@Composable
private fun KeepScreenOn(enabled: Boolean) {
    val view = LocalView.current
    DisposableEffect(view, enabled) {
        view.keepScreenOn = enabled
        onDispose { view.keepScreenOn = false }
    }
}
