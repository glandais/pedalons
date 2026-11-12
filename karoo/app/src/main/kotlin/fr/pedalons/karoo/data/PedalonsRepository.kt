package fr.pedalons.karoo.data

import fr.pedalons.karoo.api.PedalonsApiClient
import fr.pedalons.karoo.api.RoutesResponse
import fr.pedalons.karoo.api.UnauthorizedException
import fr.pedalons.karoo.auth.Session
import kotlinx.coroutines.CancellationException

internal sealed interface RoutesResult {
    data class Loaded(val response: RoutesResponse) : RoutesResult

    data object Unauthorized : RoutesResult

    /** The message stays nullable on purpose: a null message is not shown as an error. */
    data class Failed(val message: String?) : RoutesResult
}

internal enum class HammerheadStatus {
    LINKED,
    NOT_LINKED,
    UNKNOWN,
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

    suspend fun loadRoutes(): RoutesResult {
        val token = session.freshAccessToken() ?: return RoutesResult.Unauthorized
        return api.getRoutes(token)
            .fold(
                onSuccess = { RoutesResult.Loaded(it) },
                onFailure = {
                    when (it) {
                        is CancellationException -> throw it
                        is UnauthorizedException -> RoutesResult.Unauthorized
                        else -> RoutesResult.Failed(it.message)
                    }
                },
            )
    }

    suspend fun hammerheadStatus(): HammerheadStatus {
        val token = session.freshAccessToken() ?: return HammerheadStatus.UNKNOWN
        return api.getUserStatus(token)
            .fold(
                onSuccess = {
                    if (it.isHammerheadConnected()) {
                        HammerheadStatus.LINKED
                    } else {
                        HammerheadStatus.NOT_LINKED
                    }
                },
                onFailure = {
                    if (it is CancellationException) throw it
                    HammerheadStatus.UNKNOWN
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
