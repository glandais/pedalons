package fr.pedalons.karoo

import androidx.compose.ui.test.onAllNodesWithText
import fr.pedalons.karoo.support.AppTestBase
import fr.pedalons.karoo.support.Data
import fr.pedalons.karoo.support.Fixtures
import fr.pedalons.karoo.support.ShadowKarooSystemService
import fr.pedalons.karoo.support.ok
import io.hammerhead.karooext.models.UserProfile
import io.hammerhead.karooext.models.UserProfile.PreferredUnit.UnitType
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * The screens and the Karoo keys that move between them. The selected row is only visible as a
 * highlight, so selection is observed by pressing Select and seeing what opens.
 */
@RunWith(RobolectricTestRunner::class)
@Config(shadows = [ShadowKarooSystemService::class], qualifiers = "en-w256dp-h1200dp-300dpi")
class NavigationTest : AppTestBase() {

    private fun home(
        rides: List<String> = listOf(Data.twoEntryRide),
        routes: List<String> = listOf(Fixtures.route("s1", "Solo loop")),
        groups: List<String>? = listOf(Fixtures.group("Fast"), Fixtures.group("Easy")),
    ) {
        backend.routes = { ok(Fixtures.routesJson(rides, routes, groups)) }
        signIn()
        launch()
        waitForHome()
    }

    // === Home ===

    @Test
    fun home_listsTheThreeEntriesWithTheirCounts() {
        home(rides = listOf(Data.twoEntryRide, Data.singleEntryRide), routes = Data.threeRoutes)
        assertShown(
            "Pédalons",
            "My next rides",
            "2 registrations",
            "Rides",
            "2 rides",
            "Routes",
            "3 routes",
        )
        assertTrue(
            hasDescription("Loading…") && hasDescription("Settings"),
        ) // refresh and menu icons
    }

    @Test
    fun home_ridesBeforeRoutesWhenThereIsARide() {
        home()
        assertTrue(topOf("My next rides") < topOf("Rides"))
        assertTrue(topOf("Rides") < topOf("Routes"))
    }

    @Test
    fun home_routesBeforeRidesWhenThereIsNoRide() {
        home(rides = emptyList())
        assertTrue(topOf("My next rides") < topOf("Routes"))
        assertTrue(topOf("Routes") < topOf("Rides"))
        assertShown("No upcoming rides", "1 routes")
    }

    @Test
    fun home_emptyEntriesShowTheirEmptyText() {
        home(rides = emptyList(), routes = emptyList(), groups = emptyList())
        assertShown("No upcoming registration", "No upcoming rides", "No routes available")
        assertNotShown("0 registrations", "0 rides", "0 routes")
    }

    @Test
    fun home_olderServerWithoutRegisteredGroups() {
        home(groups = null)
        assertShown("No upcoming registration")
    }

    // === Opening each entry ===

    @Test
    fun home_firstEntryOpensTheRegisteredGroups() {
        home()
        select()
        assertNotShown("Pédalons")
        assertShown(
            "My next rides",
            "Fast",
            "Easy",
            "Sunday ride",
            "11/14/26 09:30",
            "42.0 km",
            "↑600m",
        )
    }

    @Test
    fun home_secondEntryOpensTheRides() {
        home()
        next()
        select()
        assertNotShown("Pédalons")
        assertShown("Rides", "Sunday ride", "2 routes")
    }

    @Test
    fun home_thirdEntryOpensTheRoutes() {
        home()
        next(2)
        select()
        assertNotShown("Pédalons")
        assertShown("Routes", "Solo loop")
    }

    @Test
    fun home_withoutRidesTheSecondEntryIsTheRoutes() {
        home(rides = emptyList())
        next()
        select()
        assertShown("Routes", "Solo loop")
    }

    @Test
    fun home_touchOpensAnEntry() {
        home()
        click("Routes")
        assertShown("Solo loop")
        assertNotShown("Pédalons")
    }

    @Test
    fun home_selectionIsClampedAtTheEnds() {
        home()
        next(10) // far past the last entry: stays on the last one
        select()
        assertShown("Solo loop") // the Routes list is the third entry
        back()

        // Back to Home, selection reset to the first entry.
        waitForHome()
        previous(10) // far before the first one: stays on the first one
        select()
        assertShown("Fast")
    }

    @Test
    fun home_selectionResetsToTheFirstEntryAfterBack() {
        // CHARACTERIZATION: coming back to Home does not remember the entry just left.
        home()
        next(2)
        select()
        assertShown("Solo loop")
        back()
        select()
        assertShown("Fast", "Easy")
    }

    @Test
    fun home_selectingAnEmptyEntryStillOpensItsEmptyList() {
        home(rides = emptyList(), routes = emptyList(), groups = emptyList())
        select() // registered
        assertNotShown("Pédalons")
        assertShown("No upcoming registration")
        back()
        next()
        select() // routes (no ride)
        assertShown("No routes available")
        assertNotShown("Pédalons")
        back()
        next(2)
        select() // rides
        assertShown("No upcoming rides")
        assertNotShown("Pédalons")
    }

    @Test
    fun emptyLists_ignoreSelectionKeys() {
        home(routes = emptyList())
        next(2)
        select()
        assertShown("No routes available")
        next(3)
        previous(5)
        select()
        assertShown("No routes available")
        assertNotShown("Pédalons")
        assertTrue(backend.syncRequests().isEmpty())
    }

    // === Rides ===

    @Test
    fun rideList_showsNameStartAndRouteCount() {
        home(rides = listOf(Data.twoEntryRide, Data.singleEntryRide))
        next()
        select()
        assertShown(
            "Sunday ride",
            "11/14/26 09:00",
            "2 routes",
            "Saturday spin",
            "11/15/26 08:00",
            "1 routes",
        )
    }

    @Test
    fun rideList_rideWithoutStartHasNoDateLine() {
        home(
            rides =
                listOf(
                    Fixtures.ride(
                        "ride-9",
                        "Undated",
                        listOf(Fixtures.entry("x", "X")),
                        start = null,
                    ),
                ),
        )
        next()
        select()
        assertShown("Undated", "1 routes")
        assertNotShown("11/14/26 09:00")
    }

    @Test
    fun rideWithSeveralEntries_opensItsEntries() {
        home()
        next()
        select()
        select()
        // Title is the ride; rows are the groups (or the route name without a group).
        assertShown("Sunday ride", "Fast", "Easy", "42.0 km", "↑600m", "25.0 km", "↑200m")
        // A group's own start wins over the ride's; without one the ride's start is used.
        assertShown("11/14/26 09:30", "11/14/26 09:00")
    }

    @Test
    fun rideEntries_rowIsTheRouteNameWhenThereIsNoGroup() {
        val ride =
            Fixtures.ride(
                "ride-5",
                "No groups",
                listOf(Fixtures.entry("a", "Alpha"), Fixtures.entry("b", "Beta")),
            )
        home(rides = listOf(ride))
        next()
        select()
        select()
        assertShown("No groups", "Alpha", "Beta")
    }

    @Test
    fun rideWithASingleEntry_goesStraightToTheRouteDetail() {
        home(rides = listOf(Data.singleEntryRide))
        next()
        select()
        select()
        // Detail: title and body both carry the route name.
        compose.onAllNodesWithTextCount("Canal loop", 2)
        assertShown("Sync to Karoo", "15.0 km", "↑50m", "11/15/26 08:00")
    }

    @Test
    fun rideEntries_opensTheRouteDetailOfTheSelectedEntry() {
        home()
        next()
        select()
        select()
        next()
        select()
        compose.onAllNodesWithTextCount("Chartreuse", 2)
        assertShown("25.0 km", "↑200m", "11/14/26 09:00", "Sync to Karoo")
    }

    @Test
    fun routeDetail_ofAGroupedEntryShowsTheGroupStart() {
        home()
        next()
        select()
        select()
        select()
        compose.onAllNodesWithTextCount("Col de Porte", 2)
        assertShown("11/14/26 09:30", "42.0 km", "↑600m")
    }

    // === Routes ===

    @Test
    fun routeList_showsDistanceAndElevation() {
        home(routes = Data.threeRoutes)
        next(2)
        select()
        assertShown(
            "Solo loop",
            "30.0 km",
            "↑300m",
            "Lake tour",
            "50.0 km",
            "↑450m",
            "Hill climb",
            "20.0 km",
            "↑1200m",
        )
    }

    @Test
    fun routeList_selectionIsClampedAtBothEnds() {
        home(routes = Data.threeRoutes)
        next(2)
        select()
        next(10)
        select()
        compose.onAllNodesWithTextCount("Hill climb", 2)
        back()
        previous(10)
        select()
        compose.onAllNodesWithTextCount("Solo loop", 2)
    }

    @Test
    fun routeList_nextAndPreviousMoveOneAtATime() {
        home(routes = Data.threeRoutes)
        next(2)
        select()
        next()
        select()
        compose.onAllNodesWithTextCount("Lake tour", 2)
        back()
        // Selection restarts at the first row after coming back.
        next(2)
        previous()
        select()
        compose.onAllNodesWithTextCount("Lake tour", 2)
    }

    @Test
    fun routeDetail_ofAStandaloneRouteHasNoDateLine() {
        home(routes = Data.threeRoutes)
        next(2)
        select()
        select()
        compose.onAllNodesWithTextCount("Solo loop", 2)
        assertShown("30.0 km", "↑300m", "Sync to Karoo")
        assertNotShown("11/14/26 09:00")
    }

    // === Back stack ===

    @Test
    fun back_unwindsTheWholeStackThenFinishes() {
        home()
        next()
        select() // ride list
        select() // ride entries
        select() // route detail
        compose.onAllNodesWithTextCount("Col de Porte", 2)

        back() // entries
        assertShown("Fast", "Easy")
        assertNotShown("Sync to Karoo")
        back() // ride list
        assertShown("Sunday ride", "2 routes")
        assertNotShown("Fast")
        back() // home
        assertShown("Pédalons", "My next rides")
        assertNotFinishing()
        back() // out
        assertFinishing()
    }

    @Test
    fun back_fromASingleEntryDetailReturnsToTheRideList() {
        home(rides = listOf(Data.singleEntryRide))
        next()
        select()
        select()
        back()
        assertShown("Saturday spin", "1 routes")
        assertNotShown("Sync to Karoo")
        back()
        assertShown("Pédalons")
    }

    @Test
    fun backButton_touchGoesBackOneLevel() {
        home()
        next(2)
        select()
        assertShown("Solo loop")
        clickDescription("Back")
        assertShown("Pédalons", "My next rides")
        clickDescription("Back")
        assertFinishing()
    }

    // === Units from the Karoo profile ===

    @Test
    fun imperialProfile_switchesDistanceAndElevationUnits() {
        home(routes = Data.threeRoutes)
        ShadowKarooSystemService.emitUserProfile(profile(UnitType.IMPERIAL, UnitType.IMPERIAL))
        compose.waitForIdle()
        next(2)
        select()
        assertShown("18.6 mi", "↑984ft", "31.1 mi", "12.4 mi", "↑3937ft")
        assertNotShown("30.0 km")
    }

    @Test
    fun unitsAreIndependentForDistanceAndElevation() {
        home(routes = Data.threeRoutes)
        ShadowKarooSystemService.emitUserProfile(profile(UnitType.IMPERIAL, UnitType.METRIC))
        compose.waitForIdle()
        next(2)
        select()
        assertShown("18.6 mi", "↑300m")
    }

    @Test
    fun metricProfile_keepsKilometres() {
        home(routes = Data.threeRoutes)
        ShadowKarooSystemService.emitUserProfile(profile(UnitType.METRIC, UnitType.METRIC))
        compose.waitForIdle()
        next(2)
        select()
        assertShown("30.0 km", "↑300m")
    }

    private fun profile(distance: UnitType, elevation: UnitType) =
        UserProfile(
            weight = 70f,
            preferredUnit =
                UserProfile.PreferredUnit(distance, elevation, UnitType.METRIC, UnitType.METRIC),
            maxHr = 190,
            restingHr = 50,
            heartRateZones = emptyList(),
            ftp = 250,
            powerZones = emptyList(),
        )

    private fun androidx.compose.ui.test.junit4.ComposeTestRule.onAllNodesWithTextCount(
        text: String,
        atLeast: Int,
    ) {
        val n = onAllNodesWithText(text).fetchSemanticsNodes().size
        assertTrue("\"$text\" shown $n time(s), expected at least $atLeast", n >= atLeast)
    }
}
