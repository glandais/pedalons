package fr.pedalons.karoo.data

import fr.pedalons.karoo.api.ApiException
import fr.pedalons.karoo.api.PedalonsApiClient
import fr.pedalons.karoo.api.RoutesResponse
import fr.pedalons.karoo.api.UnauthorizedException
import fr.pedalons.karoo.auth.FreshToken
import fr.pedalons.karoo.auth.Session
import kotlinx.coroutines.CancellationException

/**
 * Why a load failed, as the error screen says it: the Karoo could not reach the server, or the
 * server answered with something else than what was asked (a 5xx, an unreadable body).
 */
internal enum class LoadError {
    NETWORK,
    SERVER;

    companion object {
        /** The server answered ([ApiException]) or nothing came back at all. */
        fun of(cause: Throwable): LoadError = if (cause is ApiException) SERVER else NETWORK
    }
}

internal sealed interface RoutesResult {
    data class Loaded(val response: RoutesResponse) : RoutesResult

    /** The session is over (a 401, a refused refresh, no token): the Karoo signs out. */
    data object Unauthorized : RoutesResult

    data class Failed(val error: LoadError) : RoutesResult
}

internal sealed interface HammerheadStatus {
    data object Linked : HammerheadStatus

    data object NotLinked : HammerheadStatus

    /** The session is over, as [RoutesResult.Unauthorized]. */
    data object Unauthorized : HammerheadStatus

    /** The account could not be read: nothing says Hammerhead is linked. */
    data class Failed(val error: LoadError) : HammerheadStatus
}

internal sealed interface SyncResult {
    data object Synced : SyncResult

    data object HammerheadNotLinked : SyncResult

    data object Failed : SyncResult
}

/** The authenticated calls of the app, their failures mapped to values. */
internal class PedalonsRepository(
    private val api: PedalonsApiClient,
    private val session: Session,
) {

    suspend fun loadRoutes(): RoutesResult =
        authenticated(
            call = { api.getRoutes(it) },
            onSuccess = { RoutesResult.Loaded(it) },
            unauthorized = RoutesResult.Unauthorized,
            failed = { RoutesResult.Failed(it) },
        )

    suspend fun hammerheadStatus(): HammerheadStatus =
        authenticated(
            call = { api.getUserStatus(it) },
            onSuccess = {
                if (it.isHammerheadConnected()) HammerheadStatus.Linked
                else HammerheadStatus.NotLinked
            },
            unauthorized = HammerheadStatus.Unauthorized,
            failed = { HammerheadStatus.Failed(it) },
        )

    /**
     * One rule for every call made with a fresh token (docs/LEDGER_*.md API-188): a 401 or a
     * refused refresh ends the session, a refresh that could not be had and any other failure are a
     * [LoadError] that leaves the tokens alone.
     */
    private suspend fun <T, R> authenticated(
        call: suspend (String) -> Result<T>,
        onSuccess: (T) -> R,
        unauthorized: R,
        failed: (LoadError) -> R,
    ): R {
        val token =
            when (val fresh = session.freshToken()) {
                is FreshToken.Token -> fresh.value
                FreshToken.Refused -> return unauthorized
                is FreshToken.Failed -> return failed(LoadError.of(fresh.cause))
            }
        return call(token)
            .fold(
                onSuccess = onSuccess,
                onFailure = {
                    when (it) {
                        is CancellationException -> throw it
                        is UnauthorizedException -> unauthorized
                        else -> failed(LoadError.of(it))
                    }
                },
            )
    }

    /**
     * Syncing never refreshes the token. Any 2xx answer is [SyncResult.Synced], even
     * `{"success":false}` (pinned by the characterization tests).
     */
    suspend fun syncRoute(teamSlug: String, routeSlug: String): SyncResult {
        val token = session.currentAccessToken() ?: return SyncResult.Failed
        return api.syncRoute(token, teamSlug, routeSlug)
            .fold(
                onSuccess = { SyncResult.Synced },
                onFailure = {
                    if (it is CancellationException) throw it
                    // Hammerhead was unlinked since launch (from the profile): back to the
                    // mandatory step rather than a bare « sync failed » (docs/LEDGER_*.md API-63).
                    // Kept for parity: a substring of the raw error body, wherever the code sits
                    // in it. The owner may switch to parsing ErrorResponse.code.
                    if (it.message?.contains(GPS_SERVICE_NOT_CONNECTED) == true) {
                        SyncResult.HammerheadNotLinked
                    } else {
                        SyncResult.Failed
                    }
                },
            )
    }

    private companion object {
        const val GPS_SERVICE_NOT_CONNECTED = "GPS_SERVICE_NOT_CONNECTED"
    }
}
