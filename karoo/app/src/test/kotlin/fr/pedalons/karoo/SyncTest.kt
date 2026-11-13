package fr.pedalons.karoo

import androidx.compose.ui.test.onAllNodesWithText
import fr.pedalons.karoo.auth.GpsConnectActivity
import fr.pedalons.karoo.support.AppTestBase
import fr.pedalons.karoo.support.Data
import fr.pedalons.karoo.support.Fixtures
import fr.pedalons.karoo.support.Reply
import fr.pedalons.karoo.support.ShadowKarooSystemService
import fr.pedalons.karoo.support.ok
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withTimeout
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * Sending a route to the Karoo, from the route detail screen and from a registered group row; and
 * where each route stands at Hammerhead according to the server (API-121).
 */
@RunWith(RobolectricTestRunner::class)
@Config(shadows = [ShadowKarooSystemService::class], qualifiers = "en-w256dp-h1200dp-300dpi")
class SyncTest : AppTestBase() {

    private val syncOk = """{"success":true,"externalRouteId":"ext"}"""

    private fun home(
        rides: List<String> = listOf(Data.twoEntryRide),
        routes: List<String> = Data.threeRoutes,
        groups: List<String>? = listOf(Fixtures.group("Fast"), Fixtures.group("Easy")),
    ) {
        backend.routes = { ok(Fixtures.routesJson(rides, routes, groups)) }
        signIn()
        launch()
        waitForHome()
    }

    private fun openRouteDetail(index: Int = 0) {
        next(2)
        select() // routes list (rides present)
        next(index)
        select()
        compose.waitForIdle()
    }

    private fun openRegistered() {
        select()
        assertNotShown("Pédalons")
    }

    private fun awaitSyncRequests(n: Int) =
        compose.waitUntil(10_000) { backend.syncRequests().size >= n }

    private fun count(text: String) = compose.onAllNodesWithText(text).fetchSemanticsNodes().size

    // === Trip stage (API-168) ===

    @Test
    fun stageRow_selectSyncsTheStagesOwnRoute() {
        backend.routes = {
            ok(
                Fixtures.routesJson(
                    groups = emptyList(),
                    stages =
                        listOf(
                            Fixtures.stage("Stage 1", routeSlug = "galibier", state = "OUTDATED"),
                        ),
                ),
            )
        }
        signIn()
        launch()
        waitForHome()
        select()
        assertShown("Stage 1", "Older version on the Karoo")

        select()

        waitForText("Route synced!")
        assertEquals(
            "/api/device/routes/team-a/galibier/sync",
            backend.syncRequests().single().path,
        )
    }

    // === Route detail ===

    @Test
    fun detail_selectSendsTheSyncRequestAndShowsSuccess() {
        home()
        openRouteDetail()
        assertShown("Sync to Karoo")

        select()

        waitForText("Route synced!")
        assertNotShown("Sync to Karoo", "Syncing…", "Sync failed")
        val req = backend.syncRequests().single()
        assertEquals("POST", req.method)
        assertEquals("/api/device/routes/team-a/s1/sync", req.path)
        assertEquals(mapOf("type" to "hammerhead"), req.query)
        assertEquals("stored-access", req.bearer)
        assertEquals("", req.body)
    }

    @Test
    fun detail_syncButtonTouchSyncsToo() {
        home()
        openRouteDetail(1)
        clickDescription("Sync")
        waitForText("Route synced!")
        assertEquals("/api/device/routes/team-a/s2/sync", backend.syncRequests().single().path)
    }

    @Test
    fun detail_whileSyncing_noText_andASecondSelectDoesNothing() {
        val gate = CompletableDeferred<Unit>()
        backend.sync = {
            gate.await()
            ok(syncOk)
        }
        home()
        openRouteDetail()

        select()
        awaitSyncRequests(1)
        compose.waitForIdle()
        // Only a spinner: neither the idle label nor a result.
        assertNotShown("Sync to Karoo", "Route synced!", "Sync failed")
        select()
        clickDescription("Sync")
        assertEquals(1, backend.syncRequests().size)

        gate.complete(Unit)
        waitForText("Route synced!")
        assertEquals(1, backend.syncRequests().size)
    }

    @Test
    fun detail_failure_thenRetrySucceeds() {
        var failing = true
        backend.sync = { if (failing) Reply(500, "boom") else ok(syncOk) }
        home()
        openRouteDetail()

        select()
        waitForText("Sync failed")
        assertNotShown("Route synced!")

        failing = false
        select()
        waitForText("Route synced!")
        assertEquals(2, backend.syncRequests().size)
    }

    @Test
    fun detail_syncedAgainAfterSuccessSendsANewRequest() {
        home()
        openRouteDetail()
        select()
        waitForText("Route synced!")
        select()
        compose.waitUntil(10_000) { backend.syncRequests().size == 2 }
        waitForText("Route synced!")
    }

    @Test
    fun detail_syncStateIsClearedByLeavingTheScreen() {
        home()
        openRouteDetail()
        select()
        waitForText("Route synced!")

        back()
        next()
        select() // second route
        assertShown("Sync to Karoo")
        assertNotShown("Route synced!")
        back()
        select()
        assertShown("Sync to Karoo")
    }

    @Test
    fun detail_successWithSuccessFalseIsStillShownAsSynced() {
        // CHARACTERIZATION: only the HTTP status counts; {"success":false} on a 200 shows « Route
        // synced! ».
        backend.sync = { ok("""{"success":false,"message":"nope"}""") }
        home()
        openRouteDetail()
        select()
        waitForText("Route synced!")
    }

    @Test
    fun detail_expiredAccessTokenFailsWithoutAnyRequest() {
        // CHARACTERIZATION: syncing never refreshes the token; an access token that expired since
        // the routes were loaded gives « Sync failed » and nothing is sent.
        home()
        openRouteDetail()
        signIn(access = "late", refresh = "late-r", expiresIn = -10)
        select()
        waitForText("Sync failed")
        assertTrue(backend.syncRequests().isEmpty())
    }

    @Test
    fun detail_401_failsButKeepsTheSession() {
        // CHARACTERIZATION: a 401 on sync is « Sync failed », not a sign-out.
        backend.sync = { Reply(401, "{}") }
        home()
        openRouteDetail()
        select()
        waitForText("Sync failed")
        assertEquals("stored-refresh", runBlocking { auth.getRefreshToken() })
        assertNotShown("Connect")
    }

    @Test
    fun detail_hammerheadUnlinked_startsTheGpsConnectFlow() {
        backend.sync = {
            Reply(400, """{"code":"GPS_SERVICE_NOT_CONNECTED","message":"No Hammerhead"}""")
        }
        home()
        openRouteDetail()
        select()

        waitForText("Sync failed")
        val intent = startedForResult()
        assertStartedClass(intent, GpsConnectActivity::class.java)
        assertEquals(
            "https://www.pedalons.fr",
            intent!!.getStringExtra(GpsConnectActivity.EXTRA_BASE_URL),
        )
    }

    @Test
    fun detail_otherErrorsDoNotStartTheGpsConnectFlow() {
        backend.sync = { Reply(400, """{"code":"ROUTE_TOO_BIG"}""") }
        home()
        openRouteDetail()
        select()
        waitForText("Sync failed")
        assertEquals(null, startedForResult())
    }

    @Test
    fun detail_afterTheGpsConnectFlowTheDetailStaysAsItWas() {
        // CHARACTERIZATION: completing the Hammerhead step after a failed sync neither retries the
        // sync nor reloads anything: the rider is left on « Sync failed ».
        backend.sync = { Reply(400, """{"code":"GPS_SERVICE_NOT_CONNECTED"}""") }
        home()
        openRouteDetail()
        select()
        waitForText("Sync failed")
        startedForResult()
        val routesBefore = backend.count("GET", "/api/device/routes")

        deliverResult(GpsConnectActivity.RESULT_SUCCESS)

        assertShown("Sync failed")
        assertEquals(routesBefore, backend.count("GET", "/api/device/routes"))
        assertEquals(1, backend.syncRequests().size)
    }

    @Test
    fun detail_aSyncLeftRunningBehindBackDoesNotMarkAnotherScreen() {
        val gates = mutableListOf<CompletableDeferred<Unit>>()
        backend.sync = {
            val g = CompletableDeferred<Unit>()
            gates += g
            g.await()
            ok(syncOk)
        }
        home()
        openRouteDetail(0)
        select()
        awaitSyncRequests(1)

        back()
        next()
        select() // another route's detail
        assertShown("Sync to Karoo")

        gates[0].complete(Unit) // the first sync ends while the second route is shown
        compose.waitForIdle()
        Thread.sleep(300)
        compose.waitForIdle()
        assertShown("Sync to Karoo")
        assertNotShown("Route synced!", "Sync failed")

        // That detail can sync on its own meanwhile.
        select()
        awaitSyncRequests(2)
        gates[1].complete(Unit)
        waitForText("Route synced!")
        assertEquals(listOf("s1", "s2"), backend.syncRequests().map { it.path.split("/")[5] })
    }

    /**
     * Waits for the sync handler to have answered (no fixed sleep), then lets the app's coroutine
     * consume the answer. [CompletableDeferred] is completed by the handler just before it replies.
     */
    private fun settleAfter(responded: CompletableDeferred<Unit>) {
        runBlocking { withTimeout(10_000) { responded.await() } }
        repeat(20) {
            compose.waitForIdle()
            Thread.yield()
        }
    }

    private fun gatedSync(
        gates: MutableList<CompletableDeferred<Unit>>,
        responded: List<CompletableDeferred<Unit>>,
    ) {
        backend.sync = { req ->
            val index = backend.syncRequests().size - 1
            val g = CompletableDeferred<Unit>()
            gates += g
            g.await()
            responded[index].complete(Unit)
            ok(syncOk)
        }
    }

    @Test
    fun detail_aStaleSyncIsIgnored_deterministic() {
        val gates = mutableListOf<CompletableDeferred<Unit>>()
        val responded = List(2) { CompletableDeferred<Unit>() }
        gatedSync(gates, responded)
        home()
        openRouteDetail(0)
        select()
        awaitSyncRequests(1)

        back()
        next()
        select() // another route's detail
        assertShown("Sync to Karoo")

        gates[0].complete(Unit)
        settleAfter(responded[0])
        assertShown("Sync to Karoo")
        assertNotShown("Route synced!", "Syncing…", "Sync failed")
    }

    @Test
    fun rideEntries_aStaleSyncIsIgnored_deterministic() {
        val gates = mutableListOf<CompletableDeferred<Unit>>()
        val responded = List(2) { CompletableDeferred<Unit>() }
        gatedSync(gates, responded)
        home()
        next()
        select() // rides list
        select() // the ride with two entries
        select() // first entry: route detail
        assertShown("Sync to Karoo")
        select()
        awaitSyncRequests(1)

        back() // the entries of the ride
        next()
        select() // second entry: another route detail
        assertShown("Sync to Karoo")

        gates[0].complete(Unit)
        settleAfter(responded[0])
        assertShown("Sync to Karoo")
        assertNotShown("Route synced!", "Syncing…", "Sync failed")
        assertEquals("r1", backend.syncRequests().single().path.split("/")[5])
    }

    // === Registered groups ===

    @Test
    fun registered_selectingARowSyncsItsRouteWithoutTheDetailScreen() {
        home()
        openRegistered()

        select()

        waitForText("Route synced!")
        assertEquals(
            "/api/device/routes/team-a/route-Fast/sync",
            backend.syncRequests().single().path,
        )
        assertEquals(mapOf("type" to "hammerhead"), backend.syncRequests().single().query)
        assertEquals(1, count("Route synced!"))
        assertShown("✓")
    }

    @Test
    fun registered_rowTouchSyncsToo() {
        home()
        openRegistered()
        click("Easy")
        waitForText("Route synced!")
        assertEquals(
            "/api/device/routes/team-a/route-Easy/sync",
            backend.syncRequests().single().path,
        )
    }

    @Test
    fun registered_statusShowsOnTheSelectedRowOnly() {
        val gate = CompletableDeferred<Unit>()
        backend.sync = {
            gate.await()
            ok(syncOk)
        }
        home(
            groups =
                listOf(
                    Fixtures.group("Fast", state = "SENT"),
                    Fixtures.group("Easy", state = "OUTDATED"),
                ),
        )
        openRegistered()
        next() // second row

        select()
        awaitSyncRequests(1)
        compose.waitForIdle()
        assertEquals(
            "/api/device/routes/team-a/route-Easy/sync",
            backend.syncRequests().single().path,
        )
        // Second row syncing, first row keeps the server's state.
        assertShown("Syncing…", "Already on the Karoo")
        assertNotShown("Older version on the Karoo")

        gate.complete(Unit)
        waitForText("Route synced!")
        assertEquals(1, count("Route synced!"))
        assertNotShown("Syncing…", "Older version on the Karoo")
        assertShown("Already on the Karoo")
    }

    @Test
    fun registered_whileSyncingOtherRowsAreIgnored() {
        val gate = CompletableDeferred<Unit>()
        backend.sync = {
            gate.await()
            ok(syncOk)
        }
        home()
        openRegistered()
        select()
        awaitSyncRequests(1)

        next()
        select()
        click("Easy")
        compose.waitForIdle()
        assertEquals(1, backend.syncRequests().size)
        gate.complete(Unit)
        waitForText("Route synced!")
    }

    @Test
    fun registered_failureShowsOnTheRowOnly() {
        backend.sync = { Reply(500, "boom") }
        home(
            groups =
                listOf(
                    Fixtures.group("Fast", state = "PENDING"),
                    Fixtures.group("Easy", state = "FAILING"),
                ),
        )
        openRegistered()

        select()

        waitForText("Sync failed")
        assertEquals(1, count("Sync failed"))
        // The other row keeps what the server says; the failed row replaces its own with the error.
        assertShown("Sending failed")
        assertNotShown("Update pending", "Route synced!")
    }

    @Test
    fun registered_afterASuccessTheRowSaysOnTheKarooEvenIfTheServerSaysOtherwise() {
        home(
            groups =
                listOf(
                    Fixtures.group("Fast", state = "OUTDATED"),
                    Fixtures.group("Easy", state = "PENDING"),
                ),
        )
        openRegistered()
        assertShown("Older version on the Karoo", "Update pending")

        select()
        waitForText("Route synced!")

        // Leaving and coming back clears the transient result; the route is still known as sent.
        back()
        select()
        assertShown("Already on the Karoo", "Update pending")
        assertNotShown("Older version on the Karoo", "Route synced!")
    }

    @Test
    fun registered_aFailedSyncDoesNotMarkTheRouteAsOnTheKaroo() {
        backend.sync = { Reply(500, "boom") }
        home(groups = listOf(Fixtures.group("Fast", state = "OUTDATED")))
        openRegistered()
        select()
        waitForText("Sync failed")
        back()
        select()
        assertShown("Older version on the Karoo")
        assertNotShown("Already on the Karoo")
    }

    @Test
    fun registered_syncedRoutesAreKeyedByRouteNotByRow() {
        // Two groups on the same route: syncing one marks both.
        home(
            groups =
                listOf(
                    Fixtures.group("Fast", routeSlug = "shared", state = "OUTDATED"),
                    Fixtures.group("Easy", routeSlug = "shared", state = "PENDING"),
                ),
        )
        openRegistered()
        select()
        waitForText("Route synced!")
        back()
        select()
        assertEquals(2, count("Already on the Karoo"))
    }

    @Test
    fun registered_aRouteSyncedFromTheDetailScreenIsOnTheKarooInTheList() {
        home(groups = listOf(Fixtures.group("Fast", routeSlug = "s2", state = "OUTDATED")))
        openRouteDetail(1) // s2
        select()
        waitForText("Route synced!")
        back()
        back()
        select()
        assertShown("Already on the Karoo")
        assertNotShown("Older version on the Karoo")
    }

    @Test
    fun registered_aRefreshThatChangesTheResponseForgetsTheSessionSyncs() {
        home(groups = listOf(Fixtures.group("Fast", state = "OUTDATED")))
        openRegistered()
        select()
        waitForText("Route synced!")
        back()

        // Home refresh: a new response (still OUTDATED at the server) replaces the local memory.
        backend.routes = {
            ok(
                Fixtures.routesJson(
                    listOf(Data.twoEntryRide),
                    Data.threeRoutes + Fixtures.route("s4", "New"),
                    listOf(Fixtures.group("Fast", state = "OUTDATED")),
                ),
            )
        }
        clickDescription("Loading…")
        waitForText("4 routes")
        select()
        assertShown("Older version on the Karoo")
        assertNotShown("Already on the Karoo")
    }

    @Test
    fun registered_aRefreshReturningTheSameResponseKeepsTheSessionSyncs() {
        // CHARACTERIZATION: the memory is reset when the response *changes* (the state holding it
        // is
        // compared by content), so a refresh that returns exactly the same data keeps it.
        home(groups = listOf(Fixtures.group("Fast", state = "OUTDATED")))
        openRegistered()
        select()
        waitForText("Route synced!")
        back()

        val before = backend.count("GET", "/api/device/routes")
        clickDescription("Loading…")
        compose.waitUntil(10_000) { backend.count("GET", "/api/device/routes") > before }
        waitForHome()
        compose.waitForIdle()
        select()
        assertShown("Already on the Karoo")
    }

    @Test
    fun registered_aSyncLeftRunningBehindBackDoesNotMarkARow() {
        val gate = CompletableDeferred<Unit>()
        backend.sync = {
            gate.await()
            ok(syncOk)
        }
        home(
            groups =
                listOf(
                    Fixtures.group("Fast", state = "OUTDATED"),
                    Fixtures.group("Easy", state = "OUTDATED"),
                ),
        )
        openRegistered()
        select()
        awaitSyncRequests(1)

        back()
        select() // the list again, a fresh screen
        assertNotShown("Syncing…")

        gate.complete(Unit)
        // The sync coroutine records the route and then applies (or not) its result in the same
        // step: the first row turning « Already on the Karoo » is the proof that it is over.
        waitForText("Already on the Karoo")
        compose.waitForIdle()
        // The result is not shown on any row of the new screen...
        assertNotShown("Route synced!", "Syncing…", "Sync failed")
        // ...but the route did reach the Karoo, and the first row says so.
        assertEquals(1, count("Already on the Karoo"))
        assertEquals(1, count("Older version on the Karoo"))
    }

    @Test
    fun registered_hammerheadUnlinked_startsTheGpsConnectFlow() {
        backend.sync = { Reply(400, """{"code":"GPS_SERVICE_NOT_CONNECTED"}""") }
        home()
        openRegistered()
        select()
        waitForText("Sync failed")
        assertStartedClass(startedForResult(), GpsConnectActivity::class.java)
    }

    @Test
    fun registered_emptyListShowsItsText() {
        home(groups = emptyList())
        select()
        assertNotShown("Pédalons")
        assertShown("No upcoming registration")
        select()
        next()
        select()
        assertTrue(backend.syncRequests().isEmpty())
    }

    // === What the server says about each route (API-121) ===

    private fun serverStateShows(state: String?, expected: String?) {
        home(groups = listOf(Fixtures.group("Fast", state = state)))
        openRegistered()
        val all =
            listOf(
                "Already on the Karoo",
                "Older version on the Karoo",
                "Update pending",
                "Sending failed",
                "Reconnect Hammerhead in Pédalons",
            )
        for (text in all) {
            if (text == expected) assertShown(text) else assertNotShown(text)
        }
        assertShown("Fast", "Sunday ride")
    }

    @Test fun serverState_sent() = serverStateShows("SENT", "Already on the Karoo")

    @Test fun serverState_outdated() = serverStateShows("OUTDATED", "Older version on the Karoo")

    @Test fun serverState_pending() = serverStateShows("PENDING", "Update pending")

    @Test fun serverState_failing() = serverStateShows("FAILING", "Sending failed")

    @Test
    fun serverState_reconnectRequired() =
        serverStateShows("RECONNECT_REQUIRED", "Reconnect Hammerhead in Pédalons")

    @Test fun serverState_absentFromAnOlderServer() = serverStateShows(null, null)

    @Test fun serverState_noHammerheadEntry() = serverStateShows("", null)

    @Test fun serverState_unknownValueIsIgnored() = serverStateShows("SOMETHING_NEW", null)
}
