import XCTest
@testable import SkyhopCore

final class GameEngineTests: XCTestCase {
    private let config = GameConfig()
    private let frame = 1.0 / 60.0

    func testStartsReadyWithNoPipes() {
        var e = GameEngine.seeded()
        XCTAssertEqual(e.state.phase, .ready)
        e.run(seconds: 2)
        XCTAssertEqual(e.state.phase, .ready)
        XCTAssertTrue(e.state.pipes.isEmpty)
    }

    func testReadyStateBobsWithoutFalling() {
        var e = GameEngine.seeded()
        e.run(seconds: 3)
        XCTAssertLessThanOrEqual(abs(e.state.birdY - config.startY), 0.0121)
        XCTAssertGreaterThan(e.state.distance, 0, "ground keeps scrolling on the title screen")
    }

    func testFirstTapStartsGameAndFlaps() {
        var e = GameEngine.seeded()
        XCTAssertEqual(e.tap(), [.flap])
        XCTAssertEqual(e.state.phase, .playing)
        XCTAssertEqual(e.state.birdVelocity, config.flapVelocity)
    }

    func testGravityAcceleratesTheBird() {
        var e = GameEngine.seeded()
        e.tap()
        let before = e.state.birdVelocity
        e.update(deltaTime: 0.01)
        XCTAssertEqual(e.state.birdVelocity, before + config.gravity * 0.01, accuracy: 1e-9)
    }

    func testFallSpeedIsCapped() {
        var e = GameEngine.seeded()
        e.tap()
        var s = e.state
        s.birdY = 0.1
        s.birdVelocity = config.maxFallSpeed
        e.restore(s)
        e.update(deltaTime: frame)
        XCTAssertEqual(e.state.birdVelocity, config.maxFallSpeed)
    }

    func testHugeFrameTimeIsClamped() {
        var a = GameEngine.seeded(); a.tap(); a.update(deltaTime: 5)
        var b = GameEngine.seeded(); b.tap(); b.update(deltaTime: config.maxFrameTime)
        XCTAssertEqual(a.state.birdY, b.state.birdY, accuracy: 1e-12)
    }

    func testInvalidFrameTimesAreIgnored() {
        var e = GameEngine.seeded()
        e.tap()
        let before = e.state
        e.update(deltaTime: 0)
        e.update(deltaTime: -1)
        e.update(deltaTime: .nan)
        XCTAssertEqual(e.state, before)
    }

    func testBirdCannotLeaveTheTopOfTheScreen() {
        var e = GameEngine.seeded()
        e.tap()
        var s = e.state
        s.birdY = 0.005
        e.restore(s)
        e.update(deltaTime: frame)
        XCTAssertEqual(e.state.birdY, 0)
        XCTAssertGreaterThanOrEqual(e.state.birdVelocity, 0)
    }

    func testHittingTheGroundEndsTheGame() {
        var e = GameEngine.seeded()
        e.tap()
        let events = e.run(seconds: 3)
        XCTAssertEqual(e.state.phase, .gameOver)
        XCTAssertTrue(events.contains(.hit))
        XCTAssertEqual(e.state.birdY, config.groundTop - config.birdRadius, accuracy: 1e-9)
    }

    func testHittingAPipeEndsTheGame() {
        var e = GameEngine.seeded()
        e.tap()
        var s = e.state
        let birdX = s.birdX(config)
        s.pipes = [PipePair(id: 0, x: birdX - config.pipeWidth / 2, gapCenterY: config.maxGapCenter)]
        s.birdY = 0.15
        s.birdVelocity = 0
        e.restore(s)
        XCTAssertTrue(e.update(deltaTime: frame).contains(.hit))
        XCTAssertEqual(e.state.phase, .gameOver)
    }

    func testFlyingThroughTheMiddleOfAGapIsSafe() {
        var e = GameEngine.seeded()
        e.tap()
        var s = e.state
        s.pipes = [PipePair(id: 0, x: s.birdX(config) - config.pipeWidth / 2, gapCenterY: 0.4)]
        s.birdY = 0.4
        s.birdVelocity = 0
        e.restore(s)
        e.update(deltaTime: frame)
        XCTAssertEqual(e.state.phase, .playing)
    }

    func testPassingAPipeScoresExactlyOnce() {
        var e = GameEngine.seeded()
        e.tap()
        var s = e.state
        s.pipes = [PipePair(id: 0, x: s.birdX(config) - config.pipeWidth / 2 + 0.001, gapCenterY: 0.4)]
        e.restore(s)
        var scoreEvents = 0
        for _ in 0..<10 {
            var hover = e.state
            hover.birdY = 0.4
            hover.birdVelocity = 0
            e.restore(hover)
            scoreEvents += e.update(deltaTime: frame).filter { $0 == .score }.count
        }
        XCTAssertEqual(scoreEvents, 1)
        XCTAssertEqual(e.state.score, 1)
    }

    func testPipesSpawnOffScreenWithConstantSpacing() {
        var e = GameEngine.seeded()
        e.tap()
        var seen = Set<Int>()
        for _ in 0..<600 {
            var s = e.state
            s.phase = .playing
            s.birdY = 0.4
            s.birdVelocity = 0
            e.restore(s)
            e.update(deltaTime: frame)
            let pipes = e.state.pipes
            for (a, b) in zip(pipes, pipes.dropFirst()) {
                XCTAssertEqual(b.x - a.x, config.pipeSpacing, accuracy: 1e-6)
            }
            for pipe in pipes where seen.insert(pipe.id).inserted {
                XCTAssertGreaterThanOrEqual(pipe.x, e.state.worldWidth, "pipe \(pipe.id) popped in on screen")
            }
        }
        XCTAssertGreaterThanOrEqual(seen.count, 5)
    }

    func testGapsStayInBoundsAndReachable() {
        for seed in 0..<20 {
            var e = GameEngine.seeded(UInt64(seed))
            e.tap()
            var seen: [Int: PipePair] = [:]
            for _ in 0..<3000 {
                var s = e.state
                s.phase = .playing // a collision must never stop the generator in this test
                s.birdY = 0.4
                s.birdVelocity = 0
                e.restore(s)
                e.update(deltaTime: frame)
                for pipe in e.state.pipes { seen[pipe.id] = pipe }
            }
            let ordered = seen.values.sorted { $0.id < $1.id }
            XCTAssertGreaterThan(ordered.count, 20)
            for pipe in ordered {
                XCTAssertTrue((config.minGapCenter...config.maxGapCenter).contains(pipe.gapCenterY))
            }
            for (a, b) in zip(ordered, ordered.dropFirst()) {
                XCTAssertLessThanOrEqual(abs(b.gapCenterY - a.gapCenterY), config.maxGapShift + 1e-9)
            }
        }
    }

    func testCrashUpdatesBestScore() {
        var e = GameEngine.seeded(best: 2)
        e.tap()
        var s = e.state
        s.score = 5
        e.restore(s)
        let events = e.run(seconds: 3)
        XCTAssertEqual(e.state.best, 5)
        XCTAssertTrue(e.state.isNewBest)
        XCTAssertTrue(events.contains(.newBest))
    }

    func testLowerScoreKeepsOldBest() {
        var e = GameEngine.seeded(best: 10)
        e.tap()
        var s = e.state
        s.score = 3
        e.restore(s)
        let events = e.run(seconds: 3)
        XCTAssertEqual(e.state.best, 10)
        XCTAssertFalse(e.state.isNewBest)
        XCTAssertFalse(events.contains(.newBest))
    }

    func testRestartNeedsAShortDelay() {
        var e = GameEngine.seeded()
        e.tap()
        e.run(seconds: 3)
        var s = e.state
        s.gameOverTime = 0
        e.restore(s)
        e.tap()
        XCTAssertEqual(e.state.phase, .gameOver, "an immediate tap must not restart")
        e.run(seconds: config.restartDelay + 0.05)
        e.tap()
        XCTAssertEqual(e.state.phase, .ready)
        XCTAssertEqual(e.state.score, 0)
        XCTAssertTrue(e.state.pipes.isEmpty)
    }

    func testPauseFreezesTheWorldAndTapResumes() {
        var e = GameEngine.seeded()
        e.tap()
        e.run(seconds: 0.2)
        e.pause()
        let frozen = e.state
        e.run(seconds: 1)
        XCTAssertEqual(e.state, frozen)
        XCTAssertEqual(e.tap(), [.flap])
        XCTAssertEqual(e.state.phase, .playing)
    }

    func testUpdateBestNeverLowersTheBest() {
        var e = GameEngine.seeded(best: 7)
        e.updateBest(3)
        XCTAssertEqual(e.state.best, 7)
        e.updateBest(9)
        XCTAssertEqual(e.state.best, 9)
    }

    func testRotationFollowsVelocity() {
        let e = GameEngine.seeded()
        XCTAssertEqual(e.rotation(forVelocity: config.flapVelocity), -22)
        XCTAssertEqual(e.rotation(forVelocity: config.maxFallSpeed), 90)
        XCTAssertGreaterThan(e.rotation(forVelocity: 0.2), e.rotation(forVelocity: 0))
    }

    func testResizeIgnoresInvalidValues() {
        var e = GameEngine.seeded(width: 0.5)
        e.resize(worldWidth: 0)
        e.resize(worldWidth: -2)
        e.resize(worldWidth: .nan)
        e.resize(worldWidth: .infinity)
        XCTAssertEqual(e.state.worldWidth, 0.5)
        e.resize(worldWidth: 1.8)
        XCTAssertEqual(e.state.worldWidth, 1.8)
    }

    func testHighScoreStoresOnlyKeepHigherScores() {
        let memory = InMemoryHighScoreStore(5)
        memory.save(3)
        XCTAssertEqual(memory.best(), 5)
        memory.save(8)
        XCTAssertEqual(memory.best(), 8)

        let suite = "skyhop-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = UserDefaultsHighScoreStore(defaults: defaults)
        XCTAssertEqual(store.best(), 0)
        store.save(12)
        store.save(4)
        XCTAssertEqual(store.best(), 12)
    }

    /// Playability test: a simple bot that flaps whenever it drops below the next gap.
    /// If the level generator ever produced an impossible gap, this bot would crash.
    func testSimpleBotSurvivesTwoMinutesOnAnyScreen() {
        for width in [0.42, 0.46, 0.75, 1.6] {
            for seed in 0..<10 {
                var e = GameEngine.seeded(UInt64(seed), width: width)
                e.tap()
                for _ in 0..<Int(120 / frame) {
                    let s = e.state
                    let birdX = s.birdX(config)
                    let next = s.pipes.first { $0.x + config.pipeWidth > birdX - config.birdRadius }
                    let target = next?.gapCenterY ?? 0.45
                    if s.birdY > target + 0.03 && s.birdVelocity > 0 { e.tap() }
                    e.update(deltaTime: frame)
                    if e.state.phase != .playing {
                        XCTFail("bot crashed: width=\(width) seed=\(seed) score=\(e.state.score)")
                        return
                    }
                }
                XCTAssertGreaterThanOrEqual(e.state.score, 60)
            }
        }
    }
}
