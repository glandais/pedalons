package fr.pedalons.karoo.auth

import android.content.Intent
import fr.pedalons.karoo.support.AppTestBase
import fr.pedalons.karoo.support.Reply
import fr.pedalons.karoo.support.ShadowKarooSystemService
import fr.pedalons.karoo.support.ok
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.shadows.ShadowToast

/** The mandatory Hammerhead step (API-63): it follows /api/device/me until Hammerhead shows up. */
@RunWith(RobolectricTestRunner::class)
@Config(shadows = [ShadowKarooSystemService::class], qualifiers = "en-w256dp-h427dp-300dpi")
class GpsConnectActivityTest : AppTestBase() {

    private lateinit var gps: GpsConnectActivity

    private fun start(withBaseUrl: Boolean = true) {
        val intent = Intent(context, GpsConnectActivity::class.java)
        if (withBaseUrl)
            intent.putExtra(GpsConnectActivity.EXTRA_BASE_URL, "https://www.pedalons.fr")
        gps = launchActivity(intent, expectFinish = !withBaseUrl)
    }

    private fun result() = shadowOf(gps).resultCode

    private fun meRequests() = backend.requests.filter { it.path == "/api/device/me" }

    private val notConnected = """{"connectedGpsServices":[]}"""

    @Test
    fun withoutABaseUrl_theActivityClosesWithAnError() {
        start(withBaseUrl = false)
        assertTrue(gps.isFinishing)
        assertEquals(GpsConnectActivity.RESULT_ERROR, result())
    }

    @Test
    fun showsTheLastStep() {
        signIn()
        backend.me = { ok(notConnected) }
        start()
        waitForText("Last step: link Hammerhead")
        assertShown(
            "Your routes reach the Karoo through Hammerhead. Finish linking it on your phone.",
            "Waiting for Hammerhead…",
            "Page closed on the phone? Scan to resume",
            "Sign out",
        )
        assertTrue(hasDescription("QR Code"))
        compose.waitUntil(10_000) { meRequests().isNotEmpty() }
        assertEquals("stored-access", meRequests().first().bearer)
        assertTrue(!gps.isFinishing)
    }

    @Test
    fun hammerheadAlreadyLinked_toastsAndFinishesWithSuccess() {
        signIn()
        start()
        compose.waitUntil(10_000) { gps.isFinishing }
        assertEquals(GpsConnectActivity.RESULT_SUCCESS, result())
        assertEquals("Hammerhead linked", ShadowToast.getTextOfLatestToast())
    }

    @Test
    fun disconnect_finishesWithLogout_andTouchesNoToken() {
        signIn()
        backend.me = { ok(notConnected) }
        start()
        waitForText("Sign out")
        click("Sign out")
        assertTrue(gps.isFinishing)
        assertEquals(GpsConnectActivity.RESULT_LOGOUT, result())
        // Clearing the tokens is MainActivity's job on RESULT_LOGOUT.
        assertEquals("stored-refresh", runBlocking { auth.getRefreshToken() })
    }

    @Test
    fun notYetLinked_keepsPollingEveryFiveSeconds_thenSucceeds() {
        signIn()
        var linked = false
        backend.me = {
            ok(if (linked) """{"connectedGpsServices":["HAMMERHEAD"]}""" else notConnected)
        }
        start()
        waitForText("Waiting for Hammerhead…")
        compose.waitUntil(10_000) { meRequests().size >= 1 }
        assertTrue(!gps.isFinishing)

        linked = true
        assertEquals(GpsConnectActivity.RESULT_SUCCESS, advanceUntilFinishing())
        assertTrue(meRequests().size >= 2)
    }

    /** CHARACTERIZATION: the account is re-read every 5 s (virtual time), not faster. */
    @Test
    fun notYetLinked_rereadsTheAccountEveryFiveSeconds() {
        signIn()
        backend.me = { ok(notConnected) }
        start()
        compose.waitUntil(10_000) { meRequests().size == 1 }
        compose.mainClock.autoAdvance = false

        compose.mainClock.advanceTimeBy(4_900)
        Thread.sleep(150)
        assertEquals("no second read before 5 s", 1, meRequests().size)

        advanceAndSettle(200)
        assertEquals(2, meRequests().size)
        advanceAndSettle(4_800)
        assertEquals(2, meRequests().size)
        advanceAndSettle(300)
        assertEquals(3, meRequests().size)
    }

    private fun advanceAndSettle(ms: Long) {
        compose.mainClock.advanceTimeBy(ms)
        Thread.sleep(150)
        compose.mainClock.advanceTimeByFrame()
    }

    private fun advanceUntilFinishing(): Int {
        compose.mainClock.autoAdvance = false
        var spins = 0
        while (!gps.isFinishing && spins++ < 100) advanceAndSettle(1_000)
        assertTrue(gps.isFinishing)
        return result()
    }

    @Test
    fun notSignedIn_justKeepsWaitingWithoutAnyRequest() {
        start()
        waitForText("Waiting for Hammerhead…")
        compose.waitForIdle()
        Thread.sleep(500)
        compose.waitForIdle()
        assertTrue(backend.requests.isEmpty())
        assertTrue(!gps.isFinishing)
    }

    @Test
    fun accountReadFailing_justKeepsWaiting() {
        signIn()
        backend.me = { Reply(500, "boom") }
        start()
        waitForText("Waiting for Hammerhead…")
        compose.waitUntil(10_000) { meRequests().isNotEmpty() }
        compose.waitForIdle()
        assertTrue(!gps.isFinishing)
        assertShown("Waiting for Hammerhead…")
    }

    @Test
    fun accountRead401_justKeepsWaiting() {
        signIn()
        backend.me = { Reply(401, "{}") }
        start()
        compose.waitUntil(10_000) { meRequests().isNotEmpty() }
        compose.waitForIdle()
        assertTrue(!gps.isFinishing)
        assertEquals("stored-refresh", runBlocking { auth.getRefreshToken() })
    }

    @Test
    fun expiredAccessToken_isRefreshedAndTheRotatedTokenStored() {
        signIn(access = "old", refresh = "old-r", expiresIn = -10)
        start()
        compose.waitUntil(10_000) { gps.isFinishing }

        val first = backend.requests.first()
        assertTrue(first.isRefresh)
        assertEquals("""{"grantType":"refresh_token","refreshToken":"old-r"}""", first.body)
        assertEquals("refreshed", meRequests().first().bearer)
        assertEquals("rotated", runBlocking { auth.getRefreshToken() })
        assertEquals(GpsConnectActivity.RESULT_SUCCESS, result())
    }

    @Test
    fun refreshFailing_justKeepsWaiting() {
        backend.refresh = { Reply(400, """{"code":"INVALID_GRANT"}""") }
        signIn(expiresIn = -10)
        start()
        compose.waitUntil(10_000) { backend.requests.any { it.isRefresh } }
        compose.waitForIdle()
        assertTrue(meRequests().isEmpty())
        assertTrue(!gps.isFinishing)
        // Unlike the main flow, this screen never clears the session itself.
        assertEquals("stored-refresh", runBlocking { auth.getRefreshToken() })
    }

    @Test
    fun theQrIsAFallbackToTheHammerheadStepOnly() {
        signIn()
        backend.me = { ok(notConnected) }
        start()
        waitForText("Page closed on the phone? Scan to resume")
        assertTrue(hasDescription("QR Code"))
        // The Hammerhead step alone, never the profile or the bare /karoo page.
        assertEquals("https://www.pedalons.fr/karoo/hammerhead", decodeShownQr())
    }
}
