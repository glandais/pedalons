package fr.pedalons.karoo.data

import fr.pedalons.karoo.api.PedalonsApiClient
import fr.pedalons.karoo.auth.Session
import fr.pedalons.karoo.support.FakeTokenStore
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.MockRequestHandleScope
import io.ktor.client.engine.mock.respond
import io.ktor.client.request.HttpRequestData
import io.ktor.client.request.HttpResponseData
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import java.io.IOException
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/** Every mapping of [PedalonsRepository]: what an answer becomes, and when no request is sent. */
class PedalonsRepositoryTest {

    private val routesJson = """{"rides":[],"routes":[]}"""

    private class Rig(val repo: PedalonsRepository, val engine: MockEngine)

    private fun rig(
        store: FakeTokenStore = FakeTokenStore(),
        handler: suspend MockRequestHandleScope.(HttpRequestData) -> HttpResponseData,
    ): Rig {
        val engine = MockEngine { handler(it) }
        val api = PedalonsApiClient("https://api.example.test", engine)
        return Rig(PedalonsRepository(api, Session(store, api)), engine)
    }

    private fun MockRequestHandleScope.answer(
        body: String,
        status: HttpStatusCode = HttpStatusCode.OK,
    ) = respond(body, status, headersOf(HttpHeaders.ContentType, "application/json"))

    private val signedOut
        get() = FakeTokenStore(access = null, refresh = null, expired = true)

    // === loadRoutes ===

    @Test
    fun loadRoutes_loaded_withTheStoredToken() = runBlocking {
        val rig = rig { answer(routesJson) }
        assertTrue(rig.repo.loadRoutes() is RoutesResult.Loaded)
        assertEquals(
            "Bearer stored-access",
            rig.engine.requestHistory.single().headers["Authorization"],
        )
    }

    @Test
    fun loadRoutes_noToken_isUnauthorized_withoutARequest() = runBlocking {
        val rig = rig(signedOut) { answer("{}") }
        assertEquals(RoutesResult.Unauthorized, rig.repo.loadRoutes())
        assertTrue(rig.engine.requestHistory.isEmpty())
    }

    @Test
    fun loadRoutes_401_isUnauthorized() = runBlocking {
        val rig = rig { answer("", HttpStatusCode.Unauthorized) }
        assertEquals(RoutesResult.Unauthorized, rig.repo.loadRoutes())
    }

    @Test
    fun loadRoutes_serverError_isFailedWithTheBody() = runBlocking {
        val rig = rig { answer("boom", HttpStatusCode.InternalServerError) }
        assertEquals(RoutesResult.Failed("boom"), rig.repo.loadRoutes())
    }

    @Test
    fun loadRoutes_ioException_isFailedWithItsMessage() = runBlocking {
        val rig = rig { throw IOException("offline") }
        assertEquals(RoutesResult.Failed("offline"), rig.repo.loadRoutes())
    }

    @Test
    fun loadRoutes_aFailureWithoutMessage_keepsTheMessageNull() = runBlocking {
        val rig = rig { throw IOException() }
        assertEquals(RoutesResult.Failed(null), rig.repo.loadRoutes())
    }

    @Test
    fun loadRoutes_refreshesAnExpiredToken_thenLoads() = runBlocking {
        val store = FakeTokenStore(expired = true)
        val rig =
            rig(store) {
                if (it.url.encodedPath.endsWith("/token")) {
                    answer(
                        """{"accessToken":"n","tokenType":"Bearer","expiresIn":3600,"refreshToken":"r2"}""",
                    )
                } else {
                    answer(routesJson)
                }
            }
        assertTrue(rig.repo.loadRoutes() is RoutesResult.Loaded)
        assertEquals(2, rig.engine.requestHistory.size)
        assertEquals("r2", store.refresh)
    }

    @Test
    fun loadRoutes_aRefusedRefresh_isUnauthorized() = runBlocking {
        val rig = rig(FakeTokenStore(expired = true)) { answer("{}", HttpStatusCode.BadRequest) }
        assertEquals(RoutesResult.Unauthorized, rig.repo.loadRoutes())
        assertEquals(1, rig.engine.requestHistory.size)
    }

    // === hammerheadStatus ===

    @Test
    fun hammerhead_linked() = runBlocking {
        val rig = rig { answer("""{"connectedGpsServices":["HAMMERHEAD"]}""") }
        assertEquals(HammerheadStatus.LINKED, rig.repo.hammerheadStatus())
    }

    @Test
    fun hammerhead_notLinked() = runBlocking {
        val rig = rig { answer("""{"connectedGpsServices":["GARMIN"]}""") }
        assertEquals(HammerheadStatus.NOT_LINKED, rig.repo.hammerheadStatus())
    }

    @Test
    fun hammerhead_noToken_isUnknown_withoutARequest() = runBlocking {
        val rig = rig(signedOut) { answer("{}") }
        assertEquals(HammerheadStatus.UNKNOWN, rig.repo.hammerheadStatus())
        assertTrue(rig.engine.requestHistory.isEmpty())
    }

    @Test
    fun hammerhead_401_500_andUnreadable_areUnknown() = runBlocking {
        assertEquals(
            HammerheadStatus.UNKNOWN,
            rig { answer("", HttpStatusCode.Unauthorized) }.repo.hammerheadStatus(),
        )
        assertEquals(
            HammerheadStatus.UNKNOWN,
            rig { answer("oops", HttpStatusCode.InternalServerError) }.repo.hammerheadStatus(),
        )
        assertEquals(HammerheadStatus.UNKNOWN, rig { answer("not json") }.repo.hammerheadStatus())
    }

    // === syncRoute ===

    @Test
    fun sync_success_isSynced_andPostsToTheRouteWithTheStoredToken() = runBlocking {
        val rig = rig { answer("""{"success":true}""") }
        assertEquals(SyncResult.Synced, rig.repo.syncRoute("team", "route"))
        val request = rig.engine.requestHistory.single()
        assertEquals("/api/device/routes/team/route/sync", request.url.encodedPath)
        assertEquals("Bearer stored-access", request.headers["Authorization"])
    }

    @Test
    fun sync_successFalse_isStillSynced() = runBlocking {
        val rig = rig { answer("""{"success":false,"message":"nope"}""") }
        assertEquals(SyncResult.Synced, rig.repo.syncRoute("t", "r"))
    }

    @Test
    fun sync_neverRefreshes_noValidToken_isFailed_withoutARequest() = runBlocking {
        val rig = rig(FakeTokenStore(expired = true)) { answer("{}") }
        assertEquals(SyncResult.Failed, rig.repo.syncRoute("t", "r"))
        assertTrue(rig.engine.requestHistory.isEmpty())
    }

    @Test
    fun sync_gpsServiceNotConnected_inAJsonField() = runBlocking {
        val body = """{"code":"GPS_SERVICE_NOT_CONNECTED","message":"x"}"""
        val rig = rig { answer(body, HttpStatusCode.BadRequest) }
        assertEquals(SyncResult.HammerheadNotLinked, rig.repo.syncRoute("t", "r"))
    }

    @Test
    fun sync_gpsServiceNotConnected_insideTheMessage() = runBlocking {
        val body = """{"code":"OTHER","message":"failed: GPS_SERVICE_NOT_CONNECTED for you"}"""
        val rig = rig { answer(body, HttpStatusCode.BadRequest) }
        assertEquals(SyncResult.HammerheadNotLinked, rig.repo.syncRoute("t", "r"))
    }

    @Test
    fun sync_gpsServiceNotConnected_inANonJson500Body() = runBlocking {
        val rig = rig {
            answer("error GPS_SERVICE_NOT_CONNECTED", HttpStatusCode.InternalServerError)
        }
        assertEquals(SyncResult.HammerheadNotLinked, rig.repo.syncRoute("t", "r"))
    }

    @Test
    fun sync_otherFailures_areFailed() = runBlocking {
        assertEquals(
            SyncResult.Failed,
            rig { answer("boom", HttpStatusCode.InternalServerError) }.repo.syncRoute("t", "r"),
        )
        assertEquals(
            SyncResult.Failed,
            rig { answer("", HttpStatusCode.Unauthorized) }.repo.syncRoute("t", "r"),
        )
        assertEquals(
            SyncResult.Failed,
            rig { throw IOException("offline") }.repo.syncRoute("t", "r"),
        )
    }
}
