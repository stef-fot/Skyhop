import Foundation
import Observation
import SkyhopCore

/// Only what the overlay needs. It changes a few times per game, not every frame,
/// so the text overlay is not re-evaluated 120 times per second.
struct HudState: Equatable {
    var phase: Phase
    var score: Int
    var best: Int
    var isNewBest: Bool
    var canRestart: Bool
}

@MainActor
@Observable
final class GameViewModel {
    /// Full snapshot for the canvas, updated every frame.
    private(set) var state: GameState
    private(set) var hud: HudState
    /// Incremented on every crash, drives the haptic feedback.
    private(set) var hitCount = 0

    let config: GameConfig
    @ObservationIgnored private var engine: GameEngine
    private let store: HighScoreStore

    init(store: HighScoreStore = UserDefaultsHighScoreStore()) {
        var engine = GameEngine()
        engine.updateBest(store.best())
        self.engine = engine
        self.store = store
        self.config = engine.config
        self.state = engine.state
        self.hud = HudState(phase: engine.state.phase, score: 0, best: engine.state.best, isNewBest: false, canRestart: false)
    }

    func tick(_ deltaTime: Double) { handle(engine.update(deltaTime: deltaTime)) }

    func tap() { handle(engine.tap()) }

    func pause() {
        engine.pause()
        handle([])
    }

    func resize(to size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        engine.resize(worldWidth: size.width / size.height)
        handle([])
    }

    private func handle(_ events: [GameEvent]) {
        state = engine.state
        let newHud = HudState(
            phase: state.phase,
            score: state.score,
            best: state.best,
            isNewBest: state.isNewBest,
            canRestart: engine.canRestart
        )
        if newHud != hud { hud = newHud }

        for event in events {
            switch event {
            case .newBest: store.save(state.best)
            case .hit: hitCount += 1
            case .flap, .score: break
            }
        }
    }
}
