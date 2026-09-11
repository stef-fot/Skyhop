package dev.skyhop.core

/** Persistence abstraction so the engine and tests stay free of Android APIs. */
interface HighScoreStore {
    suspend fun best(): Int
    suspend fun save(score: Int)
}

class InMemoryHighScoreStore(private var value: Int = 0) : HighScoreStore {
    override suspend fun best(): Int = value
    override suspend fun save(score: Int) {
        if (score > value) value = score
    }
}
