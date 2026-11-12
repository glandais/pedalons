@file:OptIn(ExperimentalCoroutinesApi::class)

package fr.pedalons.karoo.auth

import fr.pedalons.karoo.api.PedalonsApiClient
import fr.pedalons.karoo.data.DeviceAuthRepository
import fr.pedalons.karoo.support.FakeTokenStore
import fr.pedalons.karoo.support.Fixtures
import fr.pedalons.karoo.support.TestClock
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.MockRequestHandleScope
import io.ktor.client.engine.mock.respond
import io.ktor.client.request.HttpRequestData
import io.ktor.client.request.HttpResponseData
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import java.io.IOException
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** The RFC 8628 loop on virtual time: what it asks, when, and where it stops. */
class DeviceCodeLoginTest {

    private class Rig(val login: DeviceCodeLogin, val tokens: FakeTokenStore) {
        val pollTimes = mutableListOf<Long>()
    }

    private fun TestScope.rig(
        deviceCode: suspend MockRequestHandleScope.() -> HttpResponseData,
        poll: suspend MockRequestHandleScope.(pollNumber: Int) -> HttpResponseData,
    ): Rig {
        lateinit var rig: Rig
        val engine = MockEngine { request: HttpRequestData ->
            if (request.url.encodedPath.endsWith("/device")) {
                deviceCode()
            } else {
                rig.pollTimes += testScheduler.currentTime
                poll(rig.pollTimes.size)
            }
        }
        val tokens = FakeTokenStore(access = null, refresh = null, expired = true)
        val repo = DeviceAuthRepository(PedalonsApiClient("https://api.example.test", engine))
        rig = Rig(DeviceCodeLogin(repo, tokens, TestClock(testScheduler)), tokens)
        return rig
    }

    private fun MockRequestHandleScope.json(
        body: String,
        status: HttpStatusCode = HttpStatusCode.OK,
    ) = respond(body, status, headersOf(HttpHeaders.ContentType, "application/json"))

    private fun MockRequestHandleScope.pending() =
        json("""{"code":"AUTHORIZATION_PENDING"}""", HttpStatusCode.BadRequest)

    private fun MockRequestHandleScope.code(expiresIn: Int = 600, interval: Int = 2) =
        json(Fixtures.deviceCodeJson(expiresIn = expiresIn, interval = interval))

    @Test
    fun polls_onceAnInterval_notBefore_thenSavesTheTokens_andHoldsSuccessForASecond() = runTest {
        val rig =
            rig({ code() }) { n ->
                if (n < 3) pending() else json(Fixtures.tokenJson("tok", "ref"))
            }
        assertEquals(AuthState.Loading, rig.login.state.value)

        assertTrue(rig.login.run())

        assertEquals(listOf(2_000L, 4_000L, 6_000L), rig.pollTimes)
        // The third poll succeeded at 6 s; success stays one more second.
        assertEquals(7_000L, testScheduler.currentTime)
        assertEquals(AuthState.Success, rig.login.state.value)
        assertEquals("tok", rig.tokens.access)
        assertEquals("ref", rig.tokens.refresh)
    }

    @Test
    fun showsTheCode_whileItPolls() = runTest {
        val rig = rig({ code() }) { json(Fixtures.tokenJson()) }
        rig.login.run()
        // Success replaced it, but the code was issued first: one device-code request, one poll.
        assertEquals(1, rig.pollTimes.size)
    }

    @Test
    fun expiresInZero_expiresWithoutPolling() = runTest {
        val rig = rig({ code(expiresIn = 0) }) { pending() }
        assertFalse(rig.login.run())
        assertTrue(rig.pollTimes.isEmpty())
        assertEquals(AuthState.Expired, rig.login.state.value)
    }

    @Test
    fun theLoopEndsExpired_whenTheCodeRunsOut() = runTest {
        val rig = rig({ code(expiresIn = 5, interval = 2) }) { pending() }
        assertFalse(rig.login.run())
        // Polled at 2 s and 4 s (both before 5 s), then at 6 s the time is up: no more request
        // after the third delay's poll.
        assertEquals(listOf(2_000L, 4_000L, 6_000L), rig.pollTimes)
        assertEquals(AuthState.Expired, rig.login.state.value)
    }

    @Test
    fun anExpiredAnswer_stops() = runTest {
        val rig =
            rig({ code() }) { json("""{"code":"TOKEN_EXPIRED"}""", HttpStatusCode.BadRequest) }
        assertFalse(rig.login.run())
        assertEquals(1, rig.pollTimes.size)
        assertEquals(AuthState.Expired, rig.login.state.value)
    }

    @Test
    fun aFailure_stopsWithItsMessage() = runTest {
        val rig =
            rig({ code() }) {
                json("""{"code":"X","message":"denied"}""", HttpStatusCode.BadRequest)
            }
        assertFalse(rig.login.run())
        assertEquals(AuthState.Error("denied"), rig.login.state.value)
    }

    @Test
    fun theFallbackMessages() = runTest {
        val noCode = rig({ throw IOException() }) { pending() }
        assertFalse(noCode.login.run())
        assertEquals(AuthState.Error("Failed to start authentication"), noCode.login.state.value)

        val noPoll = rig({ code() }) { throw IOException() }
        assertFalse(noPoll.login.run())
        assertEquals(AuthState.Error("Unknown error"), noPoll.login.state.value)
    }

    @Test
    fun aCodeRequestFailure_showsItsMessage() = runTest {
        val rig = rig({ json("down", HttpStatusCode.ServiceUnavailable) }) { pending() }
        assertFalse(rig.login.run())
        assertEquals(AuthState.Error("down"), rig.login.state.value)
        assertTrue(rig.pollTimes.isEmpty())
    }
}
