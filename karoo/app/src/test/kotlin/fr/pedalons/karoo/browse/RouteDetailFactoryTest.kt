package fr.pedalons.karoo.browse

import fr.pedalons.karoo.api.DeviceRide
import fr.pedalons.karoo.api.DeviceRideEntry
import fr.pedalons.karoo.api.DeviceRoute
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class RouteDetailFactoryTest {

    private fun entry(start: String? = null, slug: String = "r1") =
        DeviceRideEntry(
            routeSlug = slug,
            routeName = "Col de Porte",
            distance = 42_000f,
            elevationGain = 600f,
            startDateTime = start,
        )

    private fun ride(start: String?, vararg entries: DeviceRideEntry) =
        DeviceRide("team-a", "ride", "Sortie", start, entries.toList())

    @Test
    fun of_ride_takes_the_entry_start_first() {
        val e = entry("2026-11-14T08:30:00Z")
        val detail = NavState.RouteDetail.of(ride("2026-11-14T07:00:00Z", e), e)
        assertEquals(
            NavState.RouteDetail(
                "team-a",
                "r1",
                "Col de Porte",
                42_000f,
                600f,
                "2026-11-14T08:30:00Z",
            ),
            detail,
        )
    }

    @Test
    fun of_ride_falls_back_to_the_ride_start_then_to_null() {
        val e = entry()
        assertEquals(
            "2026-11-14T07:00:00Z",
            NavState.RouteDetail.of(ride("2026-11-14T07:00:00Z", e), e).startDateTime,
        )
        assertNull(NavState.RouteDetail.of(ride(null, e), e).startDateTime)
    }

    @Test
    fun of_route_has_no_start() {
        val detail = NavState.RouteDetail.of(DeviceRoute("team-b", "s", "Solo", 10f, 20f))
        assertEquals(NavState.RouteDetail("team-b", "s", "Solo", 10f, 20f, null), detail)
    }

    @Test
    fun openTarget_skips_the_entries_screen_for_a_single_entry() {
        val e = entry()
        val ride = ride(null, e)
        assertEquals(NavState.RouteDetail.of(ride, e), ride.openTarget())
    }

    @Test
    fun openTarget_lists_the_entries_otherwise() {
        val two = ride(null, entry(slug = "a"), entry(slug = "b"))
        assertEquals(NavState.RideEntries(two), two.openTarget())
        assertTrue(ride(null).openTarget() is NavState.RideEntries)
    }
}
