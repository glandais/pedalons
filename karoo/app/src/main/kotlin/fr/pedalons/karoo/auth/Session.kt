package fr.pedalons.karoo.auth

import fr.pedalons.karoo.api.PedalonsApiClient
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

/**
 * The token policy: which access token a call may use, and when an expired one is refreshed. The
 * refresh token rotates at every refresh (docs/LEDGER_*.md SEC-11), so the answer is always saved
 * before the new access token is handed out, and two refreshes must never run at once: the second
 * would replay the token the first just spent. The [Mutex] enforces that for one Session, so there
 * is one Session per activity (and per view model), not one per call.
 */
internal class Session(private val tokens: TokenStore, private val api: PedalonsApiClient) {

    private val refreshLock = Mutex()

    /** The stored access token while it is usable; never refreshes (what a sync relies on). */
    suspend fun currentAccessToken(): String? = tokens.validAccessToken()

    /**
     * A usable access token, refreshing the stored one when it is expired. Null when there is none
     * and none can be had: no refresh token, a refused refresh, or an access token missing while
     * its expiry is still in the future. A cancellation is never swallowed.
     */
    suspend fun freshAccessToken(): String? {
        tokens.validAccessToken()?.let {
            return it
        }
        return refreshLock.withLock {
            // A concurrent caller may have refreshed while this one waited for the lock.
            tokens.validAccessToken()?.let {
                return@withLock it
            }
            if (!tokens.needsRefresh()) return@withLock null
            val refresh = tokens.refreshToken() ?: return@withLock null
            api.refreshToken(refresh)
                .fold(
                    onSuccess = {
                        tokens.save(it)
                        it.accessToken
                    },
                    onFailure = {
                        if (it is CancellationException) throw it
                        null
                    },
                )
        }
    }
}
