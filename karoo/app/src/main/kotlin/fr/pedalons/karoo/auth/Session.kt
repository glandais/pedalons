package fr.pedalons.karoo.auth

import fr.pedalons.karoo.api.ApiException
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
     * A usable access token, refreshing the stored one when it is expired, or why there is none:
     * [FreshToken.Refused] when the session is over (no refresh token, an access token missing
     * while its expiry is still in the future, or the server answering the refresh with a 4xx),
     * [FreshToken.Failed] when the refresh could not be had (no network, a 5xx): the tokens may
     * still be good, so a caller must not sign out on it (docs/LEDGER_*.md API-188). A cancellation
     * is never swallowed.
     */
    suspend fun freshToken(): FreshToken {
        tokens.validAccessToken()?.let {
            return FreshToken.Token(it)
        }
        return refreshLock.withLock {
            // A concurrent caller may have refreshed while this one waited for the lock.
            tokens.validAccessToken()?.let {
                return@withLock FreshToken.Token(it)
            }
            if (!tokens.needsRefresh()) return@withLock FreshToken.Refused
            val refresh = tokens.refreshToken() ?: return@withLock FreshToken.Refused
            api.refreshToken(refresh)
                .fold(
                    onSuccess = {
                        tokens.save(it)
                        FreshToken.Token(it.accessToken)
                    },
                    onFailure = {
                        when {
                            it is CancellationException -> throw it
                            it is ApiException && it.status in 400..499 -> FreshToken.Refused
                            else -> FreshToken.Failed(it)
                        }
                    },
                )
        }
    }
}

internal sealed interface FreshToken {
    data class Token(val value: String) : FreshToken

    /** The session is over: the tokens will never work again. */
    data object Refused : FreshToken

    /** The refresh could not be had; [cause] says whether the server answered. */
    data class Failed(val cause: Throwable) : FreshToken
}
