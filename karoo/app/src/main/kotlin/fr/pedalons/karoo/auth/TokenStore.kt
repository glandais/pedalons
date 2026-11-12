package fr.pedalons.karoo.auth

import fr.pedalons.karoo.api.TokenResponse
import kotlinx.coroutines.flow.Flow

/**
 * Where the device's tokens live. An interface only because the real store ([AuthManager]) needs a
 * Context: the plain-JVM tests of [Session] and the repositories use an in-memory one.
 */
interface TokenStore {

    /** Whether an access token and a refresh token are both stored. */
    val isAuthenticated: Flow<Boolean>

    /** The access token if it has more than 5 minutes left, null otherwise. */
    suspend fun validAccessToken(): String?

    /** True when there is no expiry on record or the access token has 5 minutes or less left. */
    suspend fun needsRefresh(): Boolean

    suspend fun refreshToken(): String?

    /**
     * Stores the tokens of a sign-in or a refresh. An answer without a refresh token keeps the
     * stored one (docs/LEDGER_*.md SEC-11).
     */
    suspend fun save(t: TokenResponse)

    suspend fun clear()
}
