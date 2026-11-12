package fr.pedalons.karoo.browse

import fr.pedalons.karoo.api.DeviceRegisteredGroup
import fr.pedalons.karoo.api.DeviceRide
import fr.pedalons.karoo.api.DeviceRideEntry
import fr.pedalons.karoo.api.DeviceRoute
import fr.pedalons.karoo.api.RoutesResponse
import org.junit.Assert.assertEquals
import org.junit.Assert.assertSame
import org.junit.Test

/** The transitions of [BrowseState], without Android. */
class BrowseStateTest {

    private fun entry(slug: String) =
        DeviceRideEntry(routeSlug = slug, routeName = slug, distance = 1f, elevationGain = 1f)

    private fun ride(slug: String, vararg entries: String) =
        DeviceRide("team", slug, slug, null, entries.map { entry(it) })

    private fun route(slug: String) = DeviceRoute("team", slug, slug, 1f, 1f)

    private fun group(slug: String) =
        DeviceRegisteredGroup("team", "r", "R", "G", slug, slug, 1f, 1f, "2026-11-14T08:00:00Z")

    private val response =
        RoutesResponse(
            rides = listOf(ride("one", "a"), ride("many", "a", "b")),
            routes = listOf(route("r1"), route("r2"), route("r3")),
            registeredGroups = listOf(group("g1"), group("g2")),
        )

    private val home = BrowseState(response = response)

    private fun BrowseState.at(i: Int) = copy(selectedIndex = i)

    private val BrowseState.sel: Int
        get() = selectedIndex

    // === itemCount and move ===

    @Test
    fun itemCount_perScreen() {
        assertEquals(0, BrowseState().itemCount)
        assertEquals(3, home.itemCount)
        assertEquals(2, home.copy(current = NavState.RideList(response.rides)).itemCount)
        assertEquals(3, home.copy(current = NavState.RouteList(response.routes)).itemCount)
        assertEquals(2, home.copy(current = NavState.RideEntries(response.rides[1])).itemCount)
        assertEquals(0, home.copy(current = NavState.RouteDetail.of(response.routes[0])).itemCount)
    }

    @Test
    fun move_clampsAtBothEnds() {
        assertEquals(0, home.move(-1).sel)
        assertEquals(1, home.move(1).sel)
        assertEquals(2, home.at(2).move(1).sel)
    }

    @Test
    fun move_withNothingToSelect_resetsToZero() {
        assertEquals(0, BrowseState().at(3).move(1).sel)
        assertEquals(
            0,
            home.copy(current = NavState.RouteDetail.of(response.routes[0])).move(1).sel,
        )
    }

    // === back ===

    @Test
    fun back_atTheRoot_finishes() {
        val step = home.back()
        assertEquals(BrowseOutcome.Finish, step.outcome)
        assertSame(home, step.state)
    }

    @Test
    fun back_popsAndResetsSelectionAndSync_homeSelectionIsReset() {
        val inRoutes = home.at(2).select().state
        assertEquals(NavState.RouteList(response.routes), inRoutes.current)
        val syncing =
            inRoutes
                .at(1)
                .select()
                .state
                .sync(
                    "team",
                    "r2",
                    null,
                )
                .state
        val back = syncing.back()
        assertEquals(BrowseOutcome.None, back.outcome)
        assertEquals(NavState.RouteList(response.routes), back.state.current)
        assertEquals(0, back.state.sel)
        assertEquals(SyncState.IDLE, back.state.sync)
        assertEquals(null, back.state.syncTargetIndex)
        assertEquals(syncing.syncGeneration + 1, back.state.syncGeneration)
        val homeAgain = back.state.back().state
        assertEquals(NavState.Home, homeAgain.current)
        assertEquals(0, homeAgain.sel)
    }

    // === select ===

    @Test
    fun select_home_withoutResponse_isANoOp() {
        val s = BrowseState()
        assertSame(s, s.select().state)
    }

    @Test
    fun select_home_opensTheEntry() {
        // Rides present: registered, rides, routes.
        assertEquals(
            NavState.RegisteredGroupList(response.registeredGroups),
            home.select().state.current,
        )
        assertEquals(NavState.RideList(response.rides), home.at(1).select().state.current)
        assertEquals(NavState.RouteList(response.routes), home.at(2).select().state.current)
        assertEquals(listOf<NavState>(NavState.Home), home.select().state.stack)
    }

    @Test
    fun select_singleEntryRide_skipsToTheDetail() {
        val inRides = home.at(1).select().state
        val one = inRides.at(0).select().state.current
        assertEquals(NavState.RouteDetail.of(response.rides[0], response.rides[0].entries[0]), one)
        val many = inRides.at(1).select().state.current
        assertEquals(NavState.RideEntries(response.rides[1]), many)
        val detail = many.let { inRides.at(1).select().state }.at(1).select().state.current
        assertEquals(
            NavState.RouteDetail.of(response.rides[1], response.rides[1].entries[1]),
            detail,
        )
    }

    @Test
    fun select_outOfRange_isANoOp() {
        val rides = home.at(1).select().state.at(7)
        assertSame(rides, rides.select().state)
        val routes = home.at(2).select().state.at(9)
        assertSame(routes, routes.select().state)
    }

    @Test
    fun select_routeList_opensTheDetailWithoutStart() {
        val detail = home.at(2).select().state.at(1).select().state.current
        assertEquals(NavState.RouteDetail.of(response.routes[1]), detail)
    }

    @Test
    fun navigation_bumpsTheGenerationAndResetsSync() {
        val syncing = home.select().state.sync("team", "g1", 0).state
        assertEquals(SyncState.SYNCING, syncing.sync)
        val nav = syncing.copy(current = NavState.Home).at(2).select().state
        assertEquals(SyncState.IDLE, nav.sync)
        assertEquals(null, nav.syncTargetIndex)
        assertEquals(syncing.syncGeneration + 1, nav.syncGeneration)
    }

    // === sync ===

    @Test
    fun select_registeredGroup_syncsThatRow() {
        val groups = home.select().state.at(1)
        val step = groups.select()
        assertEquals(BrowseOutcome.StartSync("team", "g2", 2), step.outcome)
        assertEquals(SyncState.SYNCING, step.state.sync)
        assertEquals(1, step.state.syncTargetIndex)
        assertEquals(1, step.state.sel)
    }

    @Test
    fun select_routeDetail_syncsWithoutARow() {
        val detail = home.at(2).select().state.select().state
        val step = detail.select()
        assertEquals(BrowseOutcome.StartSync("team", "r1", detail.syncGeneration + 1), step.outcome)
        assertEquals(null, step.state.syncTargetIndex)
    }

    @Test
    fun requestSync_isIgnoredWhileSyncing_onAnyRow() {
        val first = home.sync("team", "g1", 0)
        val second = first.state.sync("team", "g2", 1)
        assertSame(first.state, second.state)
        assertEquals(BrowseOutcome.None, second.outcome)
    }

    @Test
    fun touchedRow_syncsThatRow_withoutMovingTheSelection() {
        val groups = home.select().state.at(0)
        val step = groups.sync("team", "g2", 1)
        assertEquals(1, step.state.syncTargetIndex)
        assertEquals(0, step.state.sel)
    }

    @Test
    fun touch_opensWithoutMovingTheSelectionFirst() {
        val step = home.at(2).openHomeEntry(HomeEntry.RIDES)
        assertEquals(NavState.RideList(response.rides), step.state.current)
        assertEquals(0, step.state.sel)
        assertEquals(
            NavState.RouteDetail.of(response.routes[2]),
            home.openRoute(response.routes[2]).state.current,
        )
        assertEquals(
            NavState.RideEntries(response.rides[1]),
            home.openRide(response.rides[1]).state.current,
        )
        assertEquals(
            NavState.RouteDetail.of(response.rides[1], response.rides[1].entries[0]),
            home.openRideEntry(response.rides[1], response.rides[1].entries[0]).state.current,
        )
        assertEquals(BrowseState(), BrowseState().openHomeEntry(HomeEntry.RIDES).state)
    }

    // === syncFinished ===

    @Test
    fun syncFinished_current_setsTheResultAndRecordsASuccess() {
        val syncing = home.sync("team", "g1", 0).state
        val done = syncing.syncFinished(syncing.syncGeneration, "team", "g1", SyncState.SUCCESS)
        assertEquals(SyncState.SUCCESS, done.sync)
        assertEquals(setOf("team/g1"), done.syncedRoutes)
    }

    @Test
    fun syncFinished_stale_isIgnoredButStillRecorded() {
        val syncing = home.select().state.sync("team", "g1", 0).state
        val moved = syncing.back().state
        val done = moved.syncFinished(syncing.syncGeneration, "team", "g1", SyncState.SUCCESS)
        assertEquals(SyncState.IDLE, done.sync)
        assertEquals(setOf("team/g1"), done.syncedRoutes)
    }

    @Test
    fun syncFinished_failure_isNotRecorded() {
        val syncing = home.sync("team", "g1", 0).state
        val done = syncing.syncFinished(syncing.syncGeneration, "team", "g1", SyncState.ERROR)
        assertEquals(SyncState.ERROR, done.sync)
        assertEquals(emptySet<String>(), done.syncedRoutes)
    }

    // === response, home ===

    @Test
    fun withResponse_resetsSyncedRoutes_onlyWhenTheContentChanges() {
        val synced = home.copy(syncedRoutes = setOf("team/g1"))
        assertEquals(setOf("team/g1"), synced.withResponse(response.copy()).syncedRoutes)
        val other = response.copy(routes = emptyList())
        assertEquals(emptySet<String>(), synced.withResponse(other).syncedRoutes)
        assertEquals(other, synced.withResponse(other).response)
    }

    @Test
    fun resetToHome_keepsTheSelectionWhenAlreadyHome_andLeavesSyncAlone() {
        val syncing = home.at(1).sync("team", "g1", 0).state
        val reset = syncing.resetToHome()
        assertEquals(1, reset.sel)
        assertEquals(syncing.sync, reset.sync)
        assertEquals(syncing.syncTargetIndex, reset.syncTargetIndex)
        assertEquals(syncing.syncGeneration, reset.syncGeneration)

        val deep = home.at(2).select().state.at(2)
        val fromDeep = deep.resetToHome()
        assertEquals(NavState.Home, fromDeep.current)
        assertEquals(emptyList<NavState>(), fromDeep.stack)
        assertEquals(0, fromDeep.sel)
    }

    @Test
    fun signedOut_dropsTheResponseAndGoesHome() {
        val out = home.at(2).select().state.signedOut()
        assertEquals(null, out.response)
        assertEquals(NavState.Home, out.current)
        assertEquals(emptyList<NavState>(), out.stack)
    }
}
