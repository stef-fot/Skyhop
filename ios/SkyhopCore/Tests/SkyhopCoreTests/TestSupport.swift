import Foundation
@testable import SkyhopCore

/// SplitMix64: tiny deterministic generator so every test run sees the same levels.
final class SeededRandom {
    private var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E37_79B9_7F4A_7C15 }

    func next() -> Double {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        z ^= z >> 31
        return Double(z >> 11) / Double(1 << 53)
    }
}

extension GameEngine {
    static func seeded(_ seed: UInt64 = 1, width: Double = 0.46, best: Int = 0) -> GameEngine {
        let rng = SeededRandom(seed: seed)
        return GameEngine(worldWidth: width, best: best, random: { rng.next() })
    }

    /// Runs `seconds` of simulation at 60 fps without touching the screen.
    @discardableResult
    mutating func run(seconds: Double) -> [GameEvent] {
        var events: [GameEvent] = []
        for _ in 0..<Int(seconds * 60) { events += update(deltaTime: 1.0 / 60.0) }
        return events
    }
}
