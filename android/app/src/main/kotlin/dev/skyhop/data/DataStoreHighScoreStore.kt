package dev.skyhop.data

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.emptyPreferences
import androidx.datastore.preferences.core.intPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import dev.skyhop.core.HighScoreStore
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.first
import java.io.IOException

private val Context.gameDataStore: DataStore<Preferences> by preferencesDataStore(name = "skyhop")

class DataStoreHighScoreStore(context: Context) : HighScoreStore {
    private val dataStore = context.applicationContext.gameDataStore

    override suspend fun best(): Int =
        dataStore.data
            .catch { error -> if (error is IOException) emit(emptyPreferences()) else throw error }
            .first()[BEST_SCORE] ?: 0

    override suspend fun save(score: Int) {
        dataStore.edit { prefs ->
            if (score > (prefs[BEST_SCORE] ?: 0)) prefs[BEST_SCORE] = score
        }
    }

    private companion object {
        val BEST_SCORE = intPreferencesKey("best_score")
    }
}
