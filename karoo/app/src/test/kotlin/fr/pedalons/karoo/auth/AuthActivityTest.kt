package fr.pedalons.karoo.auth

import android.content.Intent
import fr.pedalons.karoo.support.AppTestBase
import fr.pedalons.karoo.support.Fixtures
import fr.pedalons.karoo.support.Reply
import fr.pedalons.karoo.support.ShadowKarooSystemService
import fr.pedalons.karoo.support.ok
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config

/**
 * The device code sign-in (RFC 8628), seen from the Karoo: what is shown, what is polled, what is
 * stored.
 */
@RunWith(RobolectricTestRunner::class)
@Config(shadows = [ShadowKarooSystemService::class], qualifiers = "en-w256dp-h427dp-300dpi")
class AuthActivityTest : AppTestBase() {

    private lateinit var authActivity: AuthActivity

    private fun start(withBaseUrl: Boolean = true) {
        val intent = Intent(context, AuthActivity::class.java)
        if (withBaseUrl) intent.putExtra(AuthActivity.EXTRA_BASE_URL, "https://www.pedalons.fr")
        authActivity = launchActivity(intent, expectFinish = !withBaseUrl)
    }

    private fun result() = shadowOf(authActivity).resultCode

    private fun pollRequests() = backend.requests.filter { it.isDevicePoll }

    @Test
    fun withoutABaseUrl_theActivityClosesWithAnError() {
        start(withBaseUrl = false)
        assertTrue(authActivity.isFinishing)
        assertEquals(AuthActivity.RESULT_ERROR, result())
        assertTrue(backend.requests.isEmpty())
    }

    @Test
    fun asksForACodeAsTheKaroo_thenShowsItWithItsQr() {
        start()
        waitForText("ABC123")

        val req = backend.requests.first()
        assertEquals("POST", req.method)
        assertEquals("/api/device/oauth/device", req.path)
        // API-65: the client id is sent, or the Karoo is listed as « Autre ».
        assertEquals("""{"clientId":"karoo"}""", req.body)

        assertShown(
            "Connect to Pédalons",
            "On the phone: authorize this Karoo, then link Hammerhead",
            "Go to pedalons.fr/karoo",
            "Or enter this code:",
            "ABC123",
            "Waiting for authentication…",
        )
        assertTrue(hasDescription("QR Code"))
        assertTrue("the activity stays open", !authActivity.isFinishing)
    }

    @Test
    fun pending_thenAuthorized_storesTheTokensAndFinishesWithSuccess() {
        var polls = 0
        backend.devicePoll = {
            polls++
            if (polls < 2) Reply(400, """{"code":"AUTHORIZATION_PENDING"}""")
            else ok(Fixtures.tokenJson("device-access", "device-refresh"))
        }
        start()

        waitForText("Connected", 20_000)
        assertEquals("device-refresh", runBlocking { AuthManager(context).getRefreshToken() })
        assertEquals("device-access", runBlocking { AuthManager(context).getValidAccessToken() })
        assertEquals(2, pollRequests().size)
        assertTrue(pollRequests().all { it.body.contains("\"deviceCode\":\"device-code-1\"") })
        assertTrue(pollRequests().all { it.bearer == null })

        compose.waitUntil(10_000) { authActivity.isFinishing }
        assertEquals(AuthActivity.RESULT_SUCCESS, result())
    }

    @Test
    fun tokenExpired_showsTheExpiredScreen_andCloseCancels() {
        backend.devicePoll = { Reply(400, """{"code":"TOKEN_EXPIRED"}""") }
        start()

        waitForText("Code expired. Please try again.", 20_000)
        assertNull(runBlocking { AuthManager(context).getRefreshToken() })
        assertTrue(!authActivity.isFinishing)

        click("Close")
        assertTrue(authActivity.isFinishing)
        assertEquals(AuthActivity.RESULT_CANCELLED, result())
    }

    @Test
    fun otherError_showsItsMessage_andCloseCancels() {
        backend.devicePoll = {
            Reply(400, """{"code":"ACCESS_DENIED","message":"Access denied"}""")
        }
        start()

        waitForText("Authentication failed", 20_000)
        assertShown("Access denied")
        assertEquals(1, pollRequests().size) // polling stops
        assertNull(runBlocking { AuthManager(context).getRefreshToken() })

        click("Close")
        assertTrue(authActivity.isFinishing)
        assertEquals(AuthActivity.RESULT_CANCELLED, result())
    }

    @Test
    fun serverErrorWhilePolling_isAnError() {
        backend.devicePoll = { Reply(500, "kaput") }
        start()
        waitForText("Authentication failed", 20_000)
        assertShown("kaput")
    }

    @Test
    fun deviceCodeRequestFailing_showsTheBodyAsTheError() {
        backend.deviceCode = { Reply(503, "maintenance") }
        start()
        waitForText("Authentication failed")
        assertShown("maintenance")
        assertTrue(pollRequests().isEmpty())
        click("Close")
        assertEquals(AuthActivity.RESULT_CANCELLED, result())
    }

    @Test
    fun codeAlreadyPastItsLifetime_expiresWithoutPolling() {
        // The polling loop runs while the code is valid; a 0 s lifetime ends it at once.
        backend.deviceCode = { ok(Fixtures.deviceCodeJson(expiresIn = 0)) }
        start()
        waitForText("Code expired. Please try again.")
        assertTrue(pollRequests().isEmpty())
    }

    @Test
    fun theQrEncodesTheCompleteVerificationUri() {
        backend.deviceCode = {
            ok(
                Fixtures.deviceCodeJson(
                    uri = "https://www.pedalons.fr/karoo?code=XYZ789",
                    userCode = "XYZ789",
                ),
            )
        }
        start()
        waitForText("XYZ789")
        // The visible code and the QR are built from the same answer.
        assertShown("XYZ789")
        assertTrue(hasDescription("QR Code"))
        // verificationUriComplete (code included), not the bare verificationUri.
        assertEquals("https://www.pedalons.fr/karoo?code=XYZ789", decodeShownQr())
    }

    // === Timing, on the virtual clock (compose.mainClock) ===

    @Test
    fun devicePolling_followsTheServerInterval() {
        backend.deviceCode = { ok(Fixtures.deviceCodeJson(interval = 5)) }
        backend.devicePoll = { Reply(400, """{"code":"AUTHORIZATION_PENDING"}""") }
        start()
        waitForText("ABC123")
        compose.mainClock.autoAdvance = false

        compose.mainClock.advanceTimeBy(4_900)
        assertEquals("no poll before the interval", 0, pollRequests().size)

        advanceAndSettle(200)
        assertEquals(1, pollRequests().size)

        advanceAndSettle(4_800)
        assertEquals("not yet the second one", 1, pollRequests().size)
        advanceAndSettle(300)
        assertEquals(2, pollRequests().size)
    }

    @Test
    fun connectedScreen_staysOneSecondBeforeFinishing() {
        start()
        waitForText("ABC123")
        compose.mainClock.autoAdvance = false
        advanceAndSettle(1_100) // the default interval is 1 s
        var spins = 0
        while (!hasText("Connected") && spins++ < 100) advanceAndSettle(0)
        assertShown("Connected")

        compose.mainClock.advanceTimeBy(900)
        assertShown("Connected")
        assertTrue("still showing the success", !authActivity.isFinishing)

        advanceAndSettle(200)
        assertTrue(authActivity.isFinishing)
        assertEquals(AuthActivity.RESULT_SUCCESS, result())
    }

    /** Advances the virtual clock, then lets the real network coroutines (MockEngine) answer. */
    private fun advanceAndSettle(ms: Long) {
        compose.mainClock.advanceTimeBy(ms)
        Thread.sleep(150)
        compose.mainClock.advanceTimeByFrame()
    }
}
