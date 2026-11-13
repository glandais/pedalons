package fr.pedalons.karoo

import fr.pedalons.karoo.auth.AuthActivity
import fr.pedalons.karoo.auth.GpsConnectActivity
import fr.pedalons.karoo.support.AppTestBase
import fr.pedalons.karoo.support.Fixtures
import fr.pedalons.karoo.support.Reply
import fr.pedalons.karoo.support.ShadowKarooSystemService
import fr.pedalons.karoo.support.ok
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Ignore
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * What happens between launching the app and seeing the Home screen: sign-in state, the mandatory
 * Hammerhead step, token refresh (SEC-11), and what a failure at each step looks like.
 */
@RunWith(RobolectricTestRunner::class)
@Config(shadows = [ShadowKarooSystemService::class], qualifiers = "en-w256dp-h427dp-300dpi")
class StartupAndAuthFlowTest : AppTestBase() {

    // === Not signed in ===

    @Test
    fun notAuthenticated_showsTheConnectScreenAndTalksToNobody() {
        launch()
        waitForText("Connect")
        assertShown("Pédalons", "Scan the QR code with your phone to authenticate")
        assertNotShown("My next rides")
        assertTrue("no request before signing in", backend.requests.isEmpty())
    }

    @Test
    fun connectButton_startsTheDeviceCodeFlowAgainstTheProductionHost() {
        launch()
        waitForText("Connect")
        click("Connect")

        val intent = startedForResult()
        assertStartedClass(intent, AuthActivity::class.java)
        assertEquals(
            "https://www.pedalons.fr",
            intent!!.getStringExtra(AuthActivity.EXTRA_BASE_URL),
        )
    }

    @Test
    fun connectScreen_backKeyAndBackButtonFinish() {
        launch()
        waitForText("Connect")
        assertNotFinishing()
        back()
        assertFinishing()
    }

    @Test
    fun connectScreen_backButtonTouchFinishes() {
        launch()
        waitForText("Connect")
        clickDescription("Back")
        assertFinishing()
    }

    @Test
    fun connectScreen_otherKeysDoNothing() {
        launch()
        waitForText("Connect")
        next()
        previous()
        select()
        assertShown("Connect")
        assertNotFinishing()
    }

    @Test
    fun authSucceeded_loadsTheRoutes() {
        launch()
        waitForText("Connect")
        click("Connect")
        startedForResult()

        // AuthActivity stores the tokens, then reports success.
        signIn()
        deliverResult(AuthActivity.RESULT_SUCCESS)

        waitForHome()
        assertNotShown("Connect")
        assertTrue(backend.requests.any { it.path == "/api/device/routes" })
    }

    @Test
    fun authCancelled_staysOnTheConnectScreen() {
        launch()
        waitForText("Connect")
        click("Connect")
        deliverResult(AuthActivity.RESULT_CANCELLED)

        assertShown("Connect")
        assertNotFinishing()
        assertTrue(backend.requests.isEmpty())
    }

    // === Signed in: loading ===

    @Test
    fun signedIn_checksTheAccountThenLoadsRoutesWithTheBearer() {
        signIn(access = "tok-1")
        launch()
        waitForHome()

        // CHARACTERIZATION: the account check and the routes load race at startup (the effect
        // restarts), so their order varies from run to run: only their presence is pinned.
        val me = backend.requests.first { it.path == "/api/device/me" }
        assertEquals("GET", me.method)
        assertEquals("tok-1", me.bearer)

        val routes = backend.requests.filter { it.path == "/api/device/routes" }
        assertTrue("routes requested", routes.isNotEmpty())
        // The app does not send its position; it asks for the trip stages (API-168).
        assertTrue(routes.all { it.bearer == "tok-1" && it.query == mapOf("stages" to "true") })
        // Nothing else was needed: the access token was valid, so no refresh.
        assertTrue(backend.requests.none { it.isRefresh })
        assertTrue(backend.unexpected.isEmpty())
    }

    @Test
    fun whileTheRoutesLoad_theSkeletonIsShown() {
        signIn()
        val gate = CompletableDeferred<Unit>()
        backend.routes = {
            gate.await()
            ok(Fixtures.routesJson())
        }
        launch()

        // Skeleton: the app bar, no menu, no connect button.
        waitForText("Pédalons")
        compose.waitForIdle()
        assertNotShown("Connect", "My next rides", "An error occurred")

        gate.complete(Unit)
        waitForHome()
    }

    @Test
    fun hardwareKeysDoNothingOnTheSkeleton() {
        signIn()
        val gate = CompletableDeferred<Unit>()
        backend.routes = {
            gate.await()
            ok(Fixtures.routesJson())
        }
        launch()
        waitForText("Pédalons")
        next()
        select()
        assertNotShown("My next rides")
        gate.complete(Unit)
        waitForHome()
    }

    // === Hammerhead step ===

    @Test
    fun hammerheadNotConnected_startsTheGpsConnectFlowAndLoadsNothing() {
        signIn()
        backend.me = { ok("""{"connectedGpsServices":["GARMIN"]}""") }
        launch()

        compose.waitUntil(10_000) { backend.requests.any { it.path == "/api/device/me" } }
        compose.waitForIdle()
        val intent = startedForResult()
        assertStartedClass(intent, GpsConnectActivity::class.java)
        assertEquals(
            "https://www.pedalons.fr",
            intent!!.getStringExtra(GpsConnectActivity.EXTRA_BASE_URL),
        )
        // Behind it, the skeleton keeps waiting: no routes yet.
        assertTrue(backend.requests.none { it.path == "/api/device/routes" })
        assertNotShown("My next rides", "Connect")
    }

    @Test
    fun hammerheadStepCompleted_loadsTheRoutes() {
        signIn()
        backend.me = { ok("""{"connectedGpsServices":[]}""") }
        launch()
        compose.waitUntil(10_000) { backend.requests.any { it.path == "/api/device/me" } }
        compose.waitForIdle()
        startedForResult()

        deliverResult(GpsConnectActivity.RESULT_SUCCESS)

        waitForHome()
        assertTrue(backend.requests.any { it.path == "/api/device/routes" })
    }

    @Test
    fun hammerheadStepLogout_clearsTheTokensAndShowsConnect() {
        signIn()
        backend.me = { ok("""{"connectedGpsServices":[]}""") }
        launch()
        compose.waitUntil(10_000) { backend.requests.any { it.path == "/api/device/me" } }
        compose.waitForIdle()
        startedForResult()

        deliverResult(GpsConnectActivity.RESULT_LOGOUT)

        waitForText("Connect")
        assertNull(runBlocking { auth.getRefreshToken() })
        assertNull(runBlocking { auth.getValidAccessToken() })
    }

    @Test
    fun hammerheadStepLeftWithoutAnswer_closesTheApp() {
        signIn()
        backend.me = { ok("""{"connectedGpsServices":[]}""") }
        launch()
        compose.waitUntil(10_000) { backend.requests.any { it.path == "/api/device/me" } }
        compose.waitForIdle()
        startedForResult()

        deliverResult(0)

        assertFinishing()
    }

    private fun assertRoutesLoadedAfterFailedAccountCheck(reply: Reply) {
        backend.me = { reply }
        signIn()
        launch()
        waitForHome()
        assertTrue(backend.requests.any { it.path == "/api/device/routes" })
    }

    @Test
    fun accountCheckServerError_stillLoadsTheRoutes() =
        assertRoutesLoadedAfterFailedAccountCheck(Reply(500, "boom"))

    @Test
    fun accountCheck401_stillLoadsTheRoutes() =
        assertRoutesLoadedAfterFailedAccountCheck(Reply(401, "{}"))

    @Test
    fun accountCheckUnreadable_stillLoadsTheRoutes() =
        assertRoutesLoadedAfterFailedAccountCheck(Reply(200, "not json"))

    // === Tokens ===

    @Test
    fun expiredAccessToken_isRefreshedBeforeAnythingElse() {
        signIn(access = "old-access", refresh = "old-refresh", expiresIn = -10)
        launch()
        waitForHome()

        val first = backend.requests.first()
        assertEquals("POST", first.method)
        assertEquals("/api/device/oauth/token", first.path)
        assertEquals("""{"grantType":"refresh_token","refreshToken":"old-refresh"}""", first.body)
        assertNull("no bearer on a refresh", first.bearer)
        // Everything after it uses the new access token.
        val rest = backend.requests.drop(1)
        assertTrue(rest.isNotEmpty())
        assertTrue(
            backend.paths().toString(),
            rest.all { it.isRefresh || it.bearer == "refreshed" },
        )
        // CHARACTERIZATION: the startup effect restarts while its first refresh is in flight, so
        // the
        // same refresh token is sent several times at once (up to 4 observed) — with the rotation
        // of
        // SEC-11 the server may take the repeats for replays. The count is racy: only "at least
        // one".
        assertTrue(backend.paths().toString(), backend.requests.count { it.isRefresh } >= 1)
        assertTrue(backend.requests.filter { it.isRefresh }.all { it.body.contains("old-refresh") })
    }

    /** Requests of a cold start with an expired token, once the Home screen is shown and idle. */
    private fun coldStartCounts(): Triple<Int, Int, Int> {
        signIn(access = "old-access", refresh = "old-refresh", expiresIn = -10)
        launch()
        waitForHome()
        compose.waitForIdle()
        return Triple(
            backend.requests.count { it.isRefresh },
            backend.count("GET", "/api/device/me"),
            backend.count("GET", "/api/device/routes"),
        )
    }

    /**
     * CHARACTERIZATION: measured today on a cold start with an expired token: 4 refreshes (the same
     * refresh token replayed, SEC-11), 0 or 1 account check (racy) and 3 route loads. These are
     * ceilings: a refactor may lower them, never raise them. The target is in the @Ignore'd test
     * below; when it is reached, delete this one and un-ignore that one.
     */
    @Test
    fun coldStartWithAnExpiredToken_requestCountsNeverGetWorse() {
        val (refreshes, accountChecks, routeLoads) = coldStartCounts()
        assertTrue("refreshes: $refreshes", refreshes in 1..4)
        assertTrue("account checks: $accountChecks", accountChecks <= 1)
        assertTrue("route loads: $routeLoads", routeLoads in 1..3)
    }

    @Ignore("Target of the ViewModel refactor: no replayed refresh token, no duplicate load")
    @Test
    fun coldStartWithAnExpiredToken_targetIsOneOfEach() {
        val (refreshes, accountChecks, routeLoads) = coldStartCounts()
        assertEquals(1, refreshes)
        assertEquals(1, accountChecks)
        assertEquals(1, routeLoads)
    }

    @Test
    fun refresh_storesTheRotatedRefreshToken() {
        // SEC-11: the refresh token rotates at every refresh, the new one replaces the stored one.
        signIn(access = "old-access", refresh = "old-refresh", expiresIn = -10)
        launch()
        waitForHome()

        assertEquals("rotated", runBlocking { auth.getRefreshToken() })
        assertEquals("refreshed", runBlocking { auth.getValidAccessToken() })
    }

    @Test
    fun refreshAnswerWithoutRefreshToken_keepsTheStoredOne() {
        backend.refresh = { ok(Fixtures.tokenJson("refreshed", refresh = null)) }
        signIn(access = "old-access", refresh = "old-refresh", expiresIn = -10)
        launch()
        waitForHome()

        assertEquals("old-refresh", runBlocking { auth.getRefreshToken() })
        assertEquals("refreshed", runBlocking { auth.getValidAccessToken() })
    }

    @Test
    fun accessTokenExpiringWithinFiveMinutes_isRefreshed() {
        signIn(expiresIn = 299)
        launch()
        waitForHome()
        assertTrue(backend.requests.first().isRefresh)
    }

    @Test
    fun accessTokenValidForMoreThanFiveMinutes_isNotRefreshed() {
        signIn(expiresIn = 400)
        launch()
        waitForHome()
        assertTrue(backend.requests.none { it.isRefresh })
    }

    @Test
    fun refreshFailing_signsOut() {
        backend.refresh = { Reply(400, """{"code":"INVALID_GRANT"}""") }
        signIn(expiresIn = -10)
        launch()

        waitForText("Connect")
        assertNull(runBlocking { auth.getRefreshToken() })
        assertNull(runBlocking { auth.getValidAccessToken() })
        // CHARACTERIZATION: the refresh is attempted again by the routes load after the account
        // check gave up, so the server sees at least two refreshes with the same token.
        assertTrue(backend.requests.count { it.isRefresh } >= 1)
        assertTrue(backend.requests.none { it.path == "/api/device/routes" })
        assertTrue(backend.requests.none { it.path == "/api/device/me" })
    }

    @Test
    fun routes401_signsOut() {
        backend.routes = { Reply(401, "{}") }
        signIn()
        launch()

        waitForText("Connect")
        assertNull(runBlocking { auth.getRefreshToken() })
    }

    // === Errors ===

    @Test
    fun routesServerError_showsTheErrorScreen_andRetryRecovers() {
        var failing = true
        backend.routes = {
            if (failing) Reply(500, "boom") else ok(Fixtures.routesJson())
        }
        signIn()
        launch()

        waitForText("An error occurred")
        assertShown("Loading…")
        assertNotShown("My next rides", "Connect")

        failing = false
        click("Loading…")
        waitForHome()
        assertNotShown("An error occurred")
        // The session is kept.
        assertEquals("stored-refresh", runBlocking { auth.getRefreshToken() })
    }

    @Test
    fun routesNetworkFailure_showsTheErrorScreen() {
        backend.routes = { throw java.io.IOException("offline") }
        signIn()
        launch()
        waitForText("An error occurred")
    }

    @Test
    fun routesUnreadablePayload_showsTheErrorScreen() {
        backend.routes = { ok("""{"unexpected":true}""") }
        signIn()
        launch()
        waitForText("An error occurred")
    }

    @Test
    fun retryFailingAgain_staysOnTheErrorScreen() {
        backend.routes = { Reply(500, "boom") }
        signIn()
        launch()
        waitForText("An error occurred")
        val before = backend.requests.count { it.path == "/api/device/routes" }

        click("Loading…")
        compose.waitUntil(10_000) {
            backend.requests.count { it.path == "/api/device/routes" } > before
        }
        waitForText("An error occurred")
    }

    @Test
    fun retry_doesNotRecheckTheAccountNorRefresh() {
        var failing = true
        backend.routes = { if (failing) Reply(500, "boom") else ok(Fixtures.routesJson()) }
        signIn()
        launch()
        waitForText("An error occurred")
        val meBefore = backend.count("GET", "/api/device/me")
        failing = false
        click("Loading…")
        waitForHome()
        assertEquals(meBefore, backend.count("GET", "/api/device/me"))
    }

    @Test
    fun errorScreen_backFinishes() {
        backend.routes = { Reply(500, "boom") }
        signIn()
        launch()
        waitForText("An error occurred")
        back()
        assertFinishing()
    }

    @Test
    fun errorScreen_otherKeysDoNothing() {
        backend.routes = { Reply(500, "boom") }
        signIn()
        launch()
        waitForText("An error occurred")
        next()
        select()
        previous()
        assertShown("An error occurred")
        assertNotFinishing()
    }

    // === Home actions ===

    @Test
    fun refreshButton_reloadsTheRoutes() {
        signIn()
        launch()
        waitForHome()
        assertShown("1 ride")

        backend.routes = {
            ok(
                Fixtures.routesJson(
                    rides =
                        listOf(
                            fr.pedalons.karoo.support.Data.twoEntryRide,
                            fr.pedalons.karoo.support.Data.singleEntryRide,
                        ),
                ),
            )
        }
        // CHARACTERIZATION: the refresh icon's content description is the « Loading… » string.
        clickDescription("Loading…")

        waitForText("2 rides")
        assertNotShown("1 ride")
    }

    @Test
    fun refreshButton_failureShowsTheErrorScreen() {
        signIn()
        launch()
        waitForHome()

        backend.routes = { Reply(500, "boom") }
        clickDescription("Loading…")
        waitForText("An error occurred")
    }

    @Test
    fun refreshButton_401_showsTheErrorScreenAndKeepsTheTokens() {
        signIn()
        launch()
        waitForHome()

        backend.routes = { Reply(401, "{}") }
        clickDescription("Loading…")

        // CHARACTERIZATION: unlike the first load, a 401 on a manual refresh does not sign out: the
        // rider gets the generic error screen with the tokens still stored.
        waitForText("An error occurred")
        assertEquals("stored-refresh", runBlocking { auth.getRefreshToken() })
    }

    @Test
    fun disconnect_clearsTheTokensAndShowsConnect() {
        signIn()
        launch()
        waitForHome()
        val before = backend.requests.size

        clickDescription("Settings")
        click("Disconnect")

        waitForText("Connect")
        assertNull(runBlocking { auth.getRefreshToken() })
        assertNull(runBlocking { auth.getValidAccessToken() })
        // Signing out is local: nothing is sent to the server.
        assertEquals(before, backend.requests.size)
        assertNotShown("My next rides")
    }

    @Test
    fun homeBack_finishes() {
        signIn()
        launch()
        waitForHome()
        back()
        assertFinishing()
    }
}
