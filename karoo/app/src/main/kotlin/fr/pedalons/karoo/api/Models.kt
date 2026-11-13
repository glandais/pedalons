package fr.pedalons.karoo.api

import java.time.Instant
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

// Device Code Flow
// No default value: kotlinx.serialization leaves out a property equal to its default, so the
// backend received `{}`, recorded the pairing as `device` and listed the Karoo as « Autre »
// (docs/LEDGER_*.md API-65).
@Serializable data class DeviceCodeRequest(@SerialName("clientId") val clientId: String)

@Serializable
data class DeviceCodeResponse(
    @SerialName("deviceCode") val deviceCode: String,
    @SerialName("userCode") val userCode: String,
    @SerialName("verificationUri") val verificationUri: String,
    @SerialName("verificationUriComplete") val verificationUriComplete: String,
    @SerialName("expiresIn") val expiresIn: Int,
    @SerialName("interval") val interval: Int,
)

@Serializable
data class TokenRequest(
    @SerialName("grantType") val grantType: String,
    @SerialName("deviceCode") val deviceCode: String? = null,
    @SerialName("refreshToken") val refreshToken: String? = null,
) {
    companion object {
        const val GRANT_TYPE_DEVICE_CODE = "urn:ietf:params:oauth:grant-type:device_code"
        const val GRANT_TYPE_REFRESH = "refresh_token"
    }
}

@Serializable
data class TokenResponse(
    @SerialName("accessToken") val accessToken: String,
    @SerialName("tokenType") val tokenType: String,
    @SerialName("expiresIn") val expiresIn: Int,
    @SerialName("refreshToken") val refreshToken: String? = null,
)

// Routes response with rides and standalone routes
@Serializable
data class RoutesResponse(
    @SerialName("rides") val rides: List<DeviceRide>,
    @SerialName("routes") val routes: List<DeviceRoute>,
    // The groups the user is registered in, soonest first (API 11.4.0); absent from older servers.
    @SerialName("registeredGroups") val registeredGroups: List<DeviceRegisteredGroup> = emptyList(),
    // The stages of the trips the user is registered for, soonest first (API 14.10.0, sent because
    // the request carries `stages=true`); absent from older servers (docs/LEDGER_*.md API-168).
    @SerialName("registeredStages") val registeredStages: List<DeviceRegisteredStage> = emptyList(),
) {
    /**
     * What « My next rides » lists: the groups and the trip stages the user is registered in, by
     * departure. Without stages it is the server's own order of the groups, untouched.
     */
    fun registeredItems(): List<RegisteredItem> =
        if (registeredStages.isEmpty()) {
            registeredGroups
        } else {
            (registeredGroups + registeredStages).sortedBy {
                runCatching { Instant.parse(it.startDateTime) }.getOrDefault(Instant.MAX)
            }
        }

    /** How many registrations that is: one per ride group, one per trip whatever its stages. */
    fun registrationCount(): Int =
        registeredGroups.size + registeredStages.distinctBy { it.teamSlug to it.tripSlug }.size
}

/**
 * A row of « My next rides »: a ride group or a trip stage the user is registered in, with the
 * route to load — selecting it syncs that route straight away.
 */
sealed interface RegisteredItem {
    val teamSlug: String
    val routeSlug: String
    val distance: Float
    val elevationGain: Float

    // The departure as a UTC instant.
    val startDateTime: String

    // The IANA zone the departure is displayed in.
    val timezone: String?

    // Where the route stands at each of the user's GPS services that hold it (docs/LEDGER_*.md
    // API-121). Null when the server predates the field: that means « unknown », not « not sent ».
    val syncStatuses: List<DeviceRouteSyncStatus>?

    // What the row says beside its route (docs/LEDGER_*.md API-194, sent for a group because the
    // request carries `details=true`); all absent from an older server.
    val teamName: String?

    // Where it leaves from, when the ride or the stage names a place.
    val startPlaceName: String?

    // PUBLISHED or CANCELLED, as a plain string: a status added later must not break the parse.
    val status: String?

    // When it is expected to arrive, as a UTC instant.
    val endDateTime: String?

    /** A cancelled ride or trip: shown as such, with no control (KIT §9). */
    val isCancelled: Boolean
        get() = status == STATUS_CANCELLED

    /**
     * Where the route stands at Hammerhead, the Karoo's own service: null when unknown (older
     * server), when Hammerhead does not hold the route, or for a state this build does not know.
     */
    fun hammerheadSyncState(): RouteSyncState? =
        syncStatuses
            ?.firstOrNull { it.serviceType == GPS_SERVICE_HAMMERHEAD }
            ?.let { RouteSyncState.parse(it.state) }
}

/**
 * A ride group the user is registered in, with the route to load: selecting it syncs that route
 * straight away, without the route detail screen.
 */
@Serializable
data class DeviceRegisteredGroup(
    @SerialName("teamSlug") override val teamSlug: String,
    @SerialName("rideSlug") val rideSlug: String,
    @SerialName("rideName") val rideName: String,
    @SerialName("groupName") val groupName: String,
    @SerialName("routeSlug") override val routeSlug: String,
    @SerialName("routeName") val routeName: String,
    @SerialName("distance") override val distance: Float,
    @SerialName("elevationGain") override val elevationGain: Float,
    // The group's start as a UTC instant.
    @SerialName("startDateTime") override val startDateTime: String,
    // The ride's IANA zone, in which the start is displayed.
    @SerialName("timezone") override val timezone: String? = null,
    @SerialName("syncStatuses") override val syncStatuses: List<DeviceRouteSyncStatus>? = null,
    @SerialName("teamName") override val teamName: String? = null,
    @SerialName("startPlaceName") override val startPlaceName: String? = null,
    @SerialName("status") override val status: String? = null,
    @SerialName("endDateTime") override val endDateTime: String? = null,
) : RegisteredItem

/**
 * A stage of a trip the user is registered for, with its own route (docs/LEDGER_*.md API-168): the
 * counterpart of [DeviceRegisteredGroup] for trips.
 */
@Serializable
data class DeviceRegisteredStage(
    @SerialName("teamSlug") override val teamSlug: String,
    @SerialName("tripSlug") val tripSlug: String,
    @SerialName("tripName") val tripName: String,
    @SerialName("stageName") val stageName: String,
    @SerialName("routeSlug") override val routeSlug: String,
    @SerialName("routeName") val routeName: String,
    @SerialName("distance") override val distance: Float,
    @SerialName("elevationGain") override val elevationGain: Float,
    @SerialName("startDateTime") override val startDateTime: String,
    @SerialName("timezone") override val timezone: String? = null,
    // Where the stage leaves from and ends, when it names its places.
    @SerialName("startPlaceName") override val startPlaceName: String? = null,
    @SerialName("endPlaceName") val endPlaceName: String? = null,
    @SerialName("syncStatuses") override val syncStatuses: List<DeviceRouteSyncStatus>? = null,
    @SerialName("teamName") override val teamName: String? = null,
    @SerialName("status") override val status: String? = null,
    @SerialName("endDateTime") override val endDateTime: String? = null,
) : RegisteredItem

/**
 * Where a route stands at one GPS service. Plain strings, parsed by [RouteSyncState.parse]: a value
 * added to the contract later must not make the whole routes response unreadable.
 */
@Serializable
data class DeviceRouteSyncStatus(
    @SerialName("serviceType") val serviceType: String,
    @SerialName("state") val state: String,
)

enum class RouteSyncState {
    // At the service, up to date.
    SENT,
    // At the service in an older version, and nothing will update it: sync it again.
    OUTDATED,
    // To be sent or updated shortly.
    PENDING,
    // The last attempt failed (retried a few times, then waits for the route to change).
    FAILING,
    // The connection to the service must be renewed in Pédalons.
    RECONNECT_REQUIRED;

    companion object {
        fun parse(value: String): RouteSyncState? = entries.firstOrNull { it.name == value }
    }
}

const val GPS_SERVICE_HAMMERHEAD = "HAMMERHEAD"

const val STATUS_CANCELLED = "CANCELLED"

@Serializable
data class DeviceRide(
    @SerialName("teamSlug") val teamSlug: String,
    @SerialName("rideSlug") val rideSlug: String,
    @SerialName("rideName") val rideName: String,
    @SerialName("startDateTime") val startDateTime: String? = null,
    @SerialName("entries") val entries: List<DeviceRideEntry>,
    // The ride's IANA zone, in which its starts are displayed; absent from older servers.
    @SerialName("timezone") val timezone: String? = null,
) {
    /**
     * When [entry] starts: its group's start (docs/LEDGER_*.md API-84), or the ride's start for a
     * server that predates it.
     */
    fun startOf(entry: DeviceRideEntry): String? = entry.startDateTime ?: startDateTime
}

@Serializable
data class DeviceRideEntry(
    @SerialName("routeSlug") val routeSlug: String,
    @SerialName("routeName") val routeName: String,
    @SerialName("groupName") val groupName: String? = null,
    @SerialName("distance") val distance: Float,
    @SerialName("elevationGain") val elevationGain: Float,
    @SerialName("startLat") val startLat: Double? = null,
    @SerialName("startLon") val startLon: Double? = null,
    // The group's start time as a UTC instant (API-84); absent from servers before 10.14.0.
    @SerialName("startDateTime") val startDateTime: String? = null,
)

@Serializable
data class DeviceRoute(
    @SerialName("teamSlug") val teamSlug: String,
    @SerialName("routeSlug") val routeSlug: String,
    @SerialName("routeName") val routeName: String,
    @SerialName("distance") val distance: Float,
    @SerialName("elevationGain") val elevationGain: Float,
    @SerialName("startLat") val startLat: Double? = null,
    @SerialName("startLon") val startLon: Double? = null,
)

@Serializable
data class SyncResponse(
    @SerialName("success") val success: Boolean,
    @SerialName("message") val message: String? = null,
    @SerialName("externalRouteId") val externalRouteId: String? = null,
)

// User Status
@Serializable
data class UserStatusResponse(
    @SerialName("connectedGpsServices") val connectedGpsServices: List<String>,
) {
    fun isHammerheadConnected(): Boolean = connectedGpsServices.contains(GPS_SERVICE_HAMMERHEAD)
}

// Error
@Serializable
data class ErrorResponse(
    @SerialName("code") val code: String? = null,
    @SerialName("message") val message: String? = null,
)
