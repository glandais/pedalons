package fr.pedalons.karoo

import fr.pedalons.karoo.api.DeviceRide
import fr.pedalons.karoo.api.DeviceRoute
import fr.pedalons.karoo.api.RoutesResponse
import fr.pedalons.karoo.browse.HomeEntry
import fr.pedalons.karoo.browse.homeEntries
import org.junit.Assert.assertEquals
import org.junit.Test

class HomeEntriesTest {

    private val ride = DeviceRide("t", "r", "Ride", null, emptyList())
    private val route = DeviceRoute("t", "s", "Solo", 1f, 1f)

    @Test
    fun registeredFirstThenRidesThenRoutesWhenThereIsARide() {
        assertEquals(
            listOf(HomeEntry.REGISTERED, HomeEntry.RIDES, HomeEntry.ROUTES),
            homeEntries(RoutesResponse(listOf(ride), listOf(route))),
        )
    }

    @Test
    fun routesBeforeRidesWhenThereIsNoRide() {
        assertEquals(
            listOf(HomeEntry.REGISTERED, HomeEntry.ROUTES, HomeEntry.RIDES),
            homeEntries(RoutesResponse(emptyList(), listOf(route))),
        )
    }

    @Test
    fun noRideNoRouteStillListsThreeEntries() {
        assertEquals(
            listOf(HomeEntry.REGISTERED, HomeEntry.ROUTES, HomeEntry.RIDES),
            homeEntries(RoutesResponse(emptyList(), emptyList())),
        )
    }

    @Test
    fun orderIgnoresRoutesAndRegisteredGroups() {
        assertEquals(
            listOf(HomeEntry.REGISTERED, HomeEntry.RIDES, HomeEntry.ROUTES),
            homeEntries(RoutesResponse(listOf(ride), emptyList())),
        )
    }
}
