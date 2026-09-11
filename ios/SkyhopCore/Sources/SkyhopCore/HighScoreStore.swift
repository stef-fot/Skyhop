import Foundation

/// Persistence abstraction so the view model can be tested without touching disk.
public protocol HighScoreStore: AnyObject {
    func best() -> Int
    func save(_ score: Int)
}

public final class UserDefaultsHighScoreStore: HighScoreStore {
    private let defaults: UserDefaults
    private let key: String

    public init(defaults: UserDefaults = .standard, key: String = "best_score") {
        self.defaults = defaults
        self.key = key
    }

    public func best() -> Int { defaults.integer(forKey: key) }

    public func save(_ score: Int) {
        if score > best() { defaults.set(score, forKey: key) }
    }
}

public final class InMemoryHighScoreStore: HighScoreStore {
    private var value: Int
    public init(_ value: Int = 0) { self.value = value }
    public func best() -> Int { value }
    public func save(_ score: Int) { value = max(value, score) }
}
