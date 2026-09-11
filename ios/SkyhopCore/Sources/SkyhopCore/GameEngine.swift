import Foundation

/// Pure game logic with no dependency on UIKit or SwiftUI. The UI calls `update(deltaTime:)`
/// once per display frame and `tap()` on touch, then draws `state`.
public struct GameEngine {
    public static let defaultWorldWidth = 0.46 // roughly a 9:19.5 phone in portrait
    private static let bobSpeed = 5.0
    private static let bobAmplitude = 0.012

    public let config: GameConfig
    public private(set) var state: GameState
    private let random: () -> Double
    private var nextPipeId = 0

    /// - Parameter random: returns a value in `0..<1`. Injectable so tests are deterministic.
    public init(
        config: GameConfig = GameConfig(),
        worldWidth: Double = GameEngine.defaultWorldWidth,
        best: Int = 0,
        random: @escaping () -> Double = { Double.random(in: 0..<1) }
    ) {
        self.config = config
        self.random = random
        self.state = .initial(config: config, worldWidth: worldWidth, best: best)
    }

    public var canRestart: Bool {
        state.phase == .gameOver && state.gameOverTime >= config.restartDelay
    }

    /// Restores a previously saved snapshot (tests, state restoration).
    public mutating func restore(_ saved: GameState) {
        state = saved
        nextPipeId = (saved.pipes.map(\.id).max() ?? -1) + 1
    }

    public mutating func resize(worldWidth: Double) {
        guard worldWidth > 0, worldWidth.isFinite, worldWidth != state.worldWidth else { return }
        state.worldWidth = worldWidth
    }

    /// Called when the stored best score is loaded. Never lowers the current best.
    public mutating func updateBest(_ best: Int) {
        if best > state.best { state.best = best }
    }

    @discardableResult
    public mutating func tap() -> [GameEvent] {
        switch state.phase {
        case .ready, .paused:
            state.phase = .playing
            return flap()
        case .playing:
            return flap()
        case .gameOver:
            if canRestart { reset() }
            return []
        }
    }

    public mutating func pause() {
        if state.phase == .playing { state.phase = .paused }
    }

    public mutating func reset() {
        var fresh = GameState.initial(config: config, worldWidth: state.worldWidth, best: state.best)
        // Keep the scroll distance and clock so the background does not jump.
        fresh.distance = state.distance
        fresh.time = state.time
        state = fresh
    }

    @discardableResult
    public mutating func update(deltaTime: Double) -> [GameEvent] {
        // `!(x > 0)` also rejects NaN.
        guard deltaTime > 0 else { return [] }
        let dt = min(deltaTime, config.maxFrameTime)
        switch state.phase {
        case .ready:
            stepReady(dt)
            return []
        case .playing:
            return stepPlaying(dt)
        case .paused:
            return []
        case .gameOver:
            stepGameOver(dt)
            return []
        }
    }

    public func rotation(forVelocity velocity: Double) -> Double {
        min(max((velocity / config.maxFallSpeed) * 110 - 20, -22), 90)
    }

    // MARK: - Steps

    private mutating func flap() -> [GameEvent] {
        state.birdVelocity = config.flapVelocity
        return [.flap]
    }

    private mutating func stepReady(_ dt: Double) {
        state.time += dt
        state.distance = advance(state.distance, dt)
        state.birdY = config.startY + sin(state.time * Self.bobSpeed) * Self.bobAmplitude
        state.birdVelocity = 0
        state.birdRotation = 0
    }

    private mutating func stepPlaying(_ dt: Double) -> [GameEvent] {
        var events: [GameEvent] = []

        var velocity = min(state.birdVelocity + config.gravity * dt, config.maxFallSpeed)
        var y = state.birdY + velocity * dt
        if y < 0 {
            y = 0
            velocity = max(velocity, 0)
        }

        let dx = config.scrollSpeed * dt
        let birdX = state.birdX(config)
        var score = state.score
        var moved: [PipePair] = []
        moved.reserveCapacity(state.pipes.count + 1)
        for var pipe in state.pipes {
            pipe.x -= dx
            if pipe.x + config.pipeWidth < -config.pipeWidth { continue } // far off the left edge
            if !pipe.scored && pipe.x + config.pipeWidth / 2 < birdX {
                pipe.scored = true
                score += 1
                events.append(.score)
            }
            moved.append(pipe)
        }

        state.time += dt
        state.distance = advance(state.distance, dt)
        state.birdY = y
        state.birdVelocity = velocity
        state.birdRotation = rotation(forVelocity: velocity)
        state.pipes = spawnPipes(moved)
        state.score = score

        if hitsGround(y) || hitsPipe(birdX: birdX, y: y, pipes: state.pipes) {
            events += crash()
        }
        return events
    }

    private mutating func stepGameOver(_ dt: Double) {
        let floor = config.groundTop - config.birdRadius
        var velocity = min(state.birdVelocity + config.gravity * dt, config.maxFallSpeed)
        var y = state.birdY + velocity * dt
        if y >= floor {
            y = floor
            velocity = 0
        }
        state.time += dt
        state.gameOverTime += dt
        state.birdY = y
        state.birdVelocity = velocity
        // Only ever tilt further down while falling, so the bird nose dives and stays that way.
        state.birdRotation = max(state.birdRotation, rotation(forVelocity: velocity))
    }

    private mutating func crash() -> [GameEvent] {
        let isNewBest = state.score > state.best
        state.phase = .gameOver
        state.gameOverTime = 0
        state.birdY = min(state.birdY, config.groundTop - config.birdRadius)
        state.best = max(state.best, state.score)
        state.isNewBest = isNewBest
        return isNewBest ? [.hit, .newBest] : [.hit]
    }

    // MARK: - Collision & level generation

    private func hitsGround(_ y: Double) -> Bool { y + config.birdRadius >= config.groundTop }

    private func hitsPipe(birdX: Double, y: Double, pipes: [PipePair]) -> Bool {
        let r = config.birdRadius * config.hitboxScale
        let halfGap = config.pipeGap / 2
        return pipes.contains { pipe in
            let right = pipe.x + config.pipeWidth
            return Collision.circleIntersectsRect(
                cx: birdX, cy: y, radius: r,
                left: pipe.x, top: -10, right: right, bottom: pipe.gapCenterY - halfGap
            ) || Collision.circleIntersectsRect(
                cx: birdX, cy: y, radius: r,
                left: pipe.x, top: pipe.gapCenterY + halfGap, right: right, bottom: config.groundTop
            )
        }
    }

    /// Pipes sit at exact multiples of `pipeSpacing`, so spacing never drifts with frame rate.
    /// A new pipe is created while it is still off screen to the right.
    private mutating func spawnPipes(_ current: [PipePair]) -> [PipePair] {
        var pipes = current
        if pipes.isEmpty {
            pipes.append(newPipe(x: state.worldWidth + config.firstPipeOffset, previousGap: nil))
        }
        while let last = pipes.last, last.x + config.pipeSpacing < state.worldWidth + config.pipeWidth {
            pipes.append(newPipe(x: last.x + config.pipeSpacing, previousGap: last.gapCenterY))
        }
        return pipes
    }

    private mutating func newPipe(x: Double, previousGap: Double?) -> PipePair {
        let low = previousGap.map { max(config.minGapCenter, $0 - config.maxGapShift) } ?? config.minGapCenter
        let high = previousGap.map { min(config.maxGapCenter, $0 + config.maxGapShift) } ?? config.maxGapCenter
        let center = low + random() * (high - low)
        defer { nextPipeId += 1 }
        return PipePair(id: nextPipeId, x: x, gapCenterY: center)
    }

    private func advance(_ distance: Double, _ dt: Double) -> Double {
        (distance + config.scrollSpeed * dt).truncatingRemainder(dividingBy: GameState.distancePeriod)
    }
}
