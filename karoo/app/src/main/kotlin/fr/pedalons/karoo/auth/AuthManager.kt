package fr.pedalons.karoo.auth

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.longPreferencesKey
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import fr.pedalons.karoo.api.TokenResponse
import java.time.Clock
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map

private val Context.authDataStore: DataStore<Preferences> by
    preferencesDataStore(name = "pedalons_auth")

private const val REFRESH_MARGIN_MS = 5 * 60 * 1000L

/** An access token is usable while it has more than 5 minutes left. */
internal fun isUsable(expiresAt: Long, nowMillis: Long): Boolean =
    nowMillis < expiresAt - REFRESH_MARGIN_MS

/**
 * Keeps the authentication tokens in a DataStore: plain app-private storage, not encrypted. It only
 * stores and reads them; refreshing an expired access token is [Session]'s job.
 */
class AuthManager(
    private val context: Context,
    private val clock: Clock = Clock.systemUTC(),
) : TokenStore {

    private object Keys {
        val ACCESS_TOKEN = stringPreferencesKey("access_token")
        val REFRESH_TOKEN = stringPreferencesKey("refresh_token")
        val EXPIRES_AT = longPreferencesKey("expires_at")
    }

    /**
     * Stores tokens from a successful authentication or refresh. The refresh token rotates at every
     * refresh (docs/LEDGER_*.md SEC-11): the one in the answer replaces the stored one, which the
     * server would take for a replayed copy a minute later. An answer without one — a refresh that
     * raced another — keeps the stored token.
     */
    suspend fun saveTokens(tokenResponse: TokenResponse) {
        val expiresAt = clock.millis() + (tokenResponse.expiresIn * 1000L)
        context.authDataStore.edit { prefs ->
            prefs[Keys.ACCESS_TOKEN] = tokenResponse.accessToken
            tokenResponse.refreshToken?.let { prefs[Keys.REFRESH_TOKEN] = it }
            prefs[Keys.EXPIRES_AT] = expiresAt
        }
    }

    /** Clears all stored tokens. */
    suspend fun clearTokens() {
        context.authDataStore.edit { prefs ->
            prefs.remove(Keys.ACCESS_TOKEN)
            prefs.remove(Keys.REFRESH_TOKEN)
            prefs.remove(Keys.EXPIRES_AT)
        }
    }

    /** Gets the current access token if it has more than 5 minutes left. */
    suspend fun getValidAccessToken(): String? {
        val prefs = context.authDataStore.data.first()
        val accessToken = prefs[Keys.ACCESS_TOKEN] ?: return null
        val expiresAt = prefs[Keys.EXPIRES_AT] ?: return null
        return if (isUsable(expiresAt, clock.millis())) accessToken else null
    }

    /** Gets the refresh token if available. */
    suspend fun getRefreshToken(): String? {
        return context.authDataStore.data.first()[Keys.REFRESH_TOKEN]
    }

    /** Flow indicating whether the user is authenticated. */
    override val isAuthenticated: Flow<Boolean> =
        context.authDataStore.data.map { prefs ->
            val hasAccessToken = prefs[Keys.ACCESS_TOKEN] != null
            val hasRefreshToken = prefs[Keys.REFRESH_TOKEN] != null
            hasAccessToken && hasRefreshToken
        }

    /** Checks if token needs refresh (expired or expiring soon). */
    override suspend fun needsRefresh(): Boolean {
        val prefs = context.authDataStore.data.first()
        val expiresAt = prefs[Keys.EXPIRES_AT] ?: return true
        return !isUsable(expiresAt, clock.millis())
    }

    override suspend fun validAccessToken(): String? = getValidAccessToken()

    override suspend fun refreshToken(): String? = getRefreshToken()

    override suspend fun save(t: TokenResponse) = saveTokens(t)

    override suspend fun clear() = clearTokens()
}
