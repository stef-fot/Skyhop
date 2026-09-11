import Foundation

public enum Phase: Equatable, Sendable {
    case ready, playing, paused, gameOver
}

public enum GameEvent: Equatable, Sendable {
    case flap, score, hit, newBest
}

public struct PipePair: Equatable, Identifiable, Sendable {
    public let id: Int
    /// Left edge of the pipe in world units.
    public var x: Double
    public var gapCenterY: Double
    public var scored: Bool

    public init(id: Int, x: Double, gapCenterY: Double, scored: Bool = false) {
        self.id = id
        self.x = x
        self.gapCenterY = gapCenterY
        self.scored = scored
    }
}

/// Immutable-by-convention snapshot of the game. The renderer only reads it.
public struct GameState: Equatable, Sendable {
    /// Every repeating background pattern uses a period that divides this value evenly.
    public static let distancePeriod = 60.0

    public var phase: Phase
    public var worldWidth: Double
    public var birdY: Double
    public var birdVelocity: Double
    /// Degrees, negative = nose up.
    public var birdRotation: Double
    public var pipes: [PipePair]
    public var score: Int
    public var best: Int
    public var isNewBest: Bool
    /// Scrolled distance, wrapped at `distancePeriod`.
    public var distance: Double
    /// Seconds since launch, drives the wing and idle animations.
    public var time: Double
    public var gameOverTime: Double

    public func birdX(_ config: GameConfig) -> Double { worldWidth * config.birdXRatio }

    public static func initial(config: GameConfig, worldWidth: Double, best: Int) -> GameState {
        GameState(
            phase: .ready, worldWidth: worldWidth, birdY: config.startY, birdVelocity: 0,
            birdRotation: 0, pipes: [], score: 0, best: best, isNewBest: false,
            distance: 0, time: 0, gameOverTime: 0
        )
    }
}
