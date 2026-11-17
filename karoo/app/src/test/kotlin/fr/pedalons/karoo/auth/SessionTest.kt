package fr.pedalons.karoo.auth

import fr.pedalons.karoo.api.PedalonsApiClient
import fr.pedalons.karoo.support.FakeTokenStore
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** The token policy of [Session], against a mocked token endpoint and an in-memory store. */
class SessionTest {

    private val rotated =
        """{"accessToken":"new-access","tokenType":"Bearer","expiresIn":3600,"refreshToken":"rotated"}"""

    private fun engine(
        status: HttpStatusCode = HttpStatusCode.OK,
        body: String = rotated,
        gate: CompletableDeferred<Unit>? = null,
        entered: CompletableDeferred<Unit>? = null,
    ) = MockEngine {
        entered?.complete(Unit)
        gate?.await()
        respond(body, status, headersOf(HttpHeaders.ContentType, "application/json"))
    }

    private fun session(store: FakeTokenStore, engine: MockEngine) =
        Session(store, PedalonsApiClient("https://api.example.test", engine))

    @Test
    fun aValidToken_makesNoRequest() = runBlocking {
        val engine = engine()
        val session = session(FakeTokenStore(), engine)
        assertEquals(FreshToken.Token("stored-access"), session.freshToken())
        assertTrue(engine.requestHistory.isEmpty())
    }

    @Test
    fun anExpiredToken_sendsOneRefresh_savesAndReturnsTheRotatedToken() = runBlocking {
        val engine = engine()
        val store = FakeTokenStore(expired = true)
        val session = session(store, engine)
        assertEquals(FreshToken.Token("new-access"), session.freshToken())
        assertEquals(1, engine.requestHistory.size)
        assertEquals("/api/device/oauth/token", engine.requestHistory.single().url.encodedPath)
        assertEquals(1, store.saves)
        assertEquals("rotated", store.refresh)
        assertEquals("new-access", store.access)
    }

    @Test
    fun aRefusedRefresh_isRefused_andLeavesTheStoreAlone() = runBlocking {
        val engine = engine(HttpStatusCode.BadRequest, """{"code":"INVALID_GRANT"}""")
        val store = FakeTokenStore(expired = true)
        assertEquals(FreshToken.Refused, session(store, engine).freshToken())
        assertEquals(1, engine.requestHistory.size)
        assertEquals(0, store.saves)
        assertEquals("stored-refresh", store.refresh)
        assertEquals("stored-access", store.access)
    }

    @Test
    fun aRefreshThatCouldNotBeHad_isAFailure_notARefusal() = runBlocking {
        // API-188: a 5xx or no network leaves the tokens good; only a 4xx ends the session.
        val store = FakeTokenStore(expired = true)
        val server = session(store, engine(HttpStatusCode.BadGateway, "<html>")).freshToken()
        assertTrue("$server", server is FreshToken.Failed)
        val offline =
            Session(
                    store,
                    PedalonsApiClient(
                        "https://api.example.test",
                        MockEngine {
                            throw java.io.IOException("offline")
                        },
                    ),
                )
                .freshToken()
        assertTrue("$offline", offline is FreshToken.Failed)
        assertEquals(0, store.saves)
        assertEquals("stored-refresh", store.refresh)
    }

    @Test
    fun noRefreshToken_isRefused_withoutARequest() = runBlocking {
        val engine = engine()
        val session = session(FakeTokenStore(refresh = null, expired = true), engine)
        assertEquals(FreshToken.Refused, session.freshToken())
        assertTrue(engine.requestHistory.isEmpty())
    }

    @Test
    fun accessMissingButNotExpired_isRefused_withoutARequest() = runBlocking {
        val engine = engine()
        val session = session(FakeTokenStore(access = null, expired = false), engine)
        assertEquals(FreshToken.Refused, session.freshToken())
        assertTrue(engine.requestHistory.isEmpty())
    }

    @Test
    fun twoConcurrentCallers_shareOneRefresh() = runBlocking {
        val gate = CompletableDeferred<Unit>()
        val entered = CompletableDeferred<Unit>()
        val engine = engine(gate = gate, entered = entered)
        val store = FakeTokenStore(expired = true)
        val session = session(store, engine)

        val callers = List(2) { async { session.freshToken() } }
        entered.await()
        gate.complete(Unit)

        assertEquals(List(2) { FreshToken.Token("new-access") }, callers.awaitAll())
        assertEquals(1, engine.requestHistory.size)
        assertEquals(1, store.saves)
    }

    @Test
    fun currentAccessToken_neverRefreshes() = runBlocking {
        val engine = engine()
        val session = session(FakeTokenStore(expired = true), engine)
        assertNull(session.currentAccessToken())
        assertTrue(engine.requestHistory.isEmpty())
        assertEquals("stored-access", session(FakeTokenStore(), engine).currentAccessToken())
    }

    @Test
    fun cancellingDuringARefresh_throwsCancellation_andSavesNothing() = runBlocking {
        val entered = CompletableDeferred<Unit>()
        val engine = engine(gate = CompletableDeferred(), entered = entered)
        val store = FakeTokenStore(expired = true)
        val session = session(store, engine)

        var thrown: Throwable? = null
        val job = launch {
            try {
                session.freshToken()
            } catch (e: CancellationException) {
                thrown = e
                throw e
            }
        }
        entered.await()
        job.cancel()
        job.join()

        assertTrue("expected a CancellationException, got $thrown", thrown is CancellationException)
        assertEquals(0, store.saves)
    }
}
