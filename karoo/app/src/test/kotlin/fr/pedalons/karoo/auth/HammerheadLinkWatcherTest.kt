@file:OptIn(ExperimentalCoroutinesApi::class)

package fr.pedalons.karoo.auth

import fr.pedalons.karoo.api.PedalonsApiClient
import fr.pedalons.karoo.data.PedalonsRepository
import fr.pedalons.karoo.support.FakeTokenStore
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import java.io.IOException
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Test

/** The Hammerhead step follows /me: now, then every 5 s, through errors, until it is linked. */
class HammerheadLinkWatcherTest {

    private val notLinked = """{"connectedGpsServices":[]}"""
    private val linked = """{"connectedGpsServices":["HAMMERHEAD"]}"""

    private fun kotlinx.coroutines.test.TestScope.watcher(
        times: MutableList<Long>,
        tokens: FakeTokenStore = FakeTokenStore(),
        answer: (Int) -> Pair<HttpStatusCode, String>,
    ): HammerheadLinkWatcher {
        val engine = MockEngine {
            times += testScheduler.currentTime
            val (status, body) = answer(times.size)
            respond(body, status, headersOf(HttpHeaders.ContentType, "application/json"))
        }
        val api = PedalonsApiClient("https://api.example.test", engine)
        return HammerheadLinkWatcher(PedalonsRepository(api, Session(tokens, api)))
    }

    @Test
    fun alreadyLinked_returnsAtOnce() = runTest {
        val times = mutableListOf<Long>()
        watcher(times) { HttpStatusCode.OK to linked }.awaitLinked()
        assertEquals(listOf(0L), times)
        assertEquals(0L, testScheduler.currentTime)
    }

    @Test
    fun checksEveryFiveSeconds_untilLinked() = runTest {
        val times = mutableListOf<Long>()
        watcher(times) { n -> HttpStatusCode.OK to if (n < 3) notLinked else linked }.awaitLinked()
        assertEquals(listOf(0L, 5_000L, 10_000L), times)
    }

    @Test
    fun errors_justWait() = runTest {
        val times = mutableListOf<Long>()
        val tokens = FakeTokenStore()
        watcher(times, tokens) { n ->
                when (n) {
                    1 -> HttpStatusCode.Unauthorized to ""
                    2 -> HttpStatusCode.InternalServerError to "boom"
                    else -> HttpStatusCode.OK to linked
                }
            }
            .awaitLinked()
        assertEquals(listOf(0L, 5_000L, 10_000L), times)
        // The session is never cleared by the watcher.
        assertEquals("stored-access", tokens.access)
        assertEquals("stored-refresh", tokens.refresh)
    }

    @Test
    fun aTransportError_justWaits() = runTest {
        val times = mutableListOf<Long>()
        val engine = MockEngine {
            times += testScheduler.currentTime
            if (times.size == 1) throw IOException("offline")
            respond(
                linked,
                HttpStatusCode.OK,
                headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }
        val api = PedalonsApiClient("https://api.example.test", engine)
        HammerheadLinkWatcher(PedalonsRepository(api, Session(FakeTokenStore(), api))).awaitLinked()
        assertEquals(listOf(0L, 5_000L), times)
    }
}
