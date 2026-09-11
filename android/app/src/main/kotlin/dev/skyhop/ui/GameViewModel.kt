package dev.skyhop.ui

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider.AndroidViewModelFactory.Companion.APPLICATION_KEY
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import dev.skyhop.core.GameConfig
import dev.skyhop.core.GameEngine
import dev.skyhop.core.GameEvent
import dev.skyhop.core.GameState
import dev.skyhop.core.HighScoreStore
import dev.skyhop.data.DataStoreHighScoreStore
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.launch

/**
 * Thin adapter between the pure [GameEngine] and Compose.
 *
 * The state is exposed as Compose `State` rather than a StateFlow on purpose: it changes
 * every frame, and reading it only inside the Canvas draw lambda means Compose skips
 * composition and layout entirely and just redraws.
 */
class GameViewModel(private val highScores: HighScoreStore) : ViewModel() {

    private val engine = GameEngine()
    val config: GameConfig get() = engine.config

    var state: GameState by mutableStateOf(engine.state)
        private set

    private val _events = MutableSharedFlow<GameEvent>(extraBufferCapacity = 16)
    /** One-off events for haptics and sound. */
    val events: SharedFlow<GameEvent> = _events.asSharedFlow()

    init {
        viewModelScope.launch {
            engine.updateBest(highScores.best())
            publish(emptyList())
        }
    }

    fun onFrame(deltaSeconds: Float) = publish(engine.update(deltaSeconds))

    fun onTap() = publish(engine.tap())

    fun onPause() {
        engine.pause()
        publish(emptyList())
    }

    fun onResize(widthPx: Int, heightPx: Int) {
        if (widthPx <= 0 || heightPx <= 0) return
        engine.resize(widthPx.toFloat() / heightPx.toFloat())
        publish(emptyList())
    }

    private fun publish(events: List<GameEvent>) {
        state = engine.state
        for (event in events) {
            if (event == GameEvent.NewBest) {
                val best = engine.state.best
                viewModelScope.launch { highScores.save(best) }
            }
            _events.tryEmit(event)
        }
    }

    companion object {
        val Factory = viewModelFactory {
            initializer {
                val application = checkNotNull(this[APPLICATION_KEY])
                GameViewModel(DataStoreHighScoreStore(application))
            }
        }
    }
}
