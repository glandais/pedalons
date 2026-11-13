package fr.pedalons.karoo.browse

import fr.pedalons.karoo.api.DeviceRide
import fr.pedalons.karoo.api.DeviceRideEntry
import fr.pedalons.karoo.api.DeviceRoute
import fr.pedalons.karoo.api.RegisteredItem
import fr.pedalons.karoo.api.RoutesResponse

// The key of a route in the routes synced during the session (MainScreen).
internal fun routeKey(teamSlug: String, routeSlug: String): String = "$teamSlug/$routeSlug"

// Sync feedback state
enum class SyncState {
    IDLE,
    SYNCING,
    SUCCESS,
    ERROR,
}

// The entries of the home screen, in display order (see [homeEntries]).
enum class HomeEntry {
    REGISTERED,
    RIDES,
    ROUTES,
}

/**
 * « My next rides » always comes first; Rides and Routes follow, Routes first when there is no ride
 * to show.
 */
fun homeEntries(response: RoutesResponse): List<HomeEntry> =
    if (response.rides.isEmpty()) {
        listOf(HomeEntry.REGISTERED, HomeEntry.ROUTES, HomeEntry.RIDES)
    } else {
        listOf(HomeEntry.REGISTERED, HomeEntry.RIDES, HomeEntry.ROUTES)
    }

// Navigation state machine
sealed class NavState {
    object Home : NavState()

    // The ride groups and trip stages the user is registered in: selecting one syncs its route
    // directly.
    data class RegisteredGroupList(val items: List<RegisteredItem>) : NavState()

    data class RideList(val rides: List<DeviceRide>) : NavState()

    data class RideEntries(val ride: DeviceRide) : NavState()

    data class RouteList(val routes: List<DeviceRoute>) : NavState()

    data class RouteDetail(
        val teamSlug: String,
        val routeSlug: String,
        val routeName: String,
        val distance: Float,
        val elevationGain: Float,
        // Start of the ride entry's group (null for a standalone route).
        val startDateTime: String? = null,
        // The ride's zone, in which that start is displayed.
        val timezone: String? = null,
    ) : NavState() {
        companion object {
            /** The detail of one entry of a ride: it starts with its group, else with the ride. */
            fun of(ride: DeviceRide, entry: DeviceRideEntry) =
                RouteDetail(
                    teamSlug = ride.teamSlug,
                    routeSlug = entry.routeSlug,
                    routeName = entry.routeName,
                    distance = entry.distance,
                    elevationGain = entry.elevationGain,
                    startDateTime = ride.startOf(entry),
                    timezone = ride.timezone,
                )

            /** The detail of a standalone route: it has no start. */
            fun of(route: DeviceRoute) =
                RouteDetail(
                    teamSlug = route.teamSlug,
                    routeSlug = route.routeSlug,
                    routeName = route.routeName,
                    distance = route.distance,
                    elevationGain = route.elevationGain,
                )
        }
    }
}

/**
 * Where selecting a ride leads: straight to the detail when it has a single entry (bonus: skips the
 * entries screen), else to its entries.
 */
fun DeviceRide.openTarget(): NavState =
    if (entries.size == 1) NavState.RouteDetail.of(this, entries[0]) else NavState.RideEntries(this)
