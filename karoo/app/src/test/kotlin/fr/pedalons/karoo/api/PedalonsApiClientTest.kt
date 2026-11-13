package fr.pedalons.karoo.api

import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.MockRequestHandleScope
import io.ktor.client.engine.mock.respond
import io.ktor.client.request.HttpRequestData
import io.ktor.client.request.HttpResponseData
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpMethod
import io.ktor.http.HttpStatusCode
import io.ktor.http.content.OutgoingContent
import io.ktor.http.content.TextContent
import io.ktor.http.headersOf
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test

/**
 * Contract of [PedalonsApiClient] with the Pédalons API: what goes out on the wire (method, URL,
 * headers, JSON body) and how every answer maps to a [Result]. Written against the HTTP surface
 * only, so it survives any refactor of the client's internals.
 */
class PedalonsApiClientTest {

    private val base = "https://api.example.test"

    private class Harness(
        val client: PedalonsApiClient,
        val engine: MockEngine,
    ) {
        val requests: List<HttpRequestData>
            get() = engine.requestHistory

        val only: HttpRequestData
            get() {
                assertEquals("exactly one request expected", 1, requests.size)
                return requests.single()
            }
    }

    private fun harness(handler: MockRequestHandleScope.(HttpRequestData) -> HttpResponseData) =
        MockEngine { request ->
            handler(request)
        }
        .let { Harness(PedalonsApiClient("https://api.example.test", it), it) }

    private fun MockRequestHandleScope.json(
        body: String,
        status: HttpStatusCode = HttpStatusCode.OK,
    ): HttpResponseData =
        respond(body, status, headersOf(HttpHeaders.ContentType, "application/json"))

    private fun HttpRequestData.bodyText(): String =
        when (val b = body) {
            is TextContent -> b.text
            is OutgoingContent.ByteArrayContent -> b.bytes().decodeToString()
            is OutgoingContent.NoContent -> ""
            else -> fail("unexpected body type ${b::class}").let { "" }
        }

    private fun <T> Result<T>.failure(): Throwable {
        assertTrue("expected a failure but got $this", isFailure)
        return exceptionOrNull()!!
    }

    private val tokenJson =
        """{"accessToken":"acc","tokenType":"Bearer","expiresIn":3600,"refreshToken":"ref"}"""

    // === requestDeviceCode ===

    private val deviceCodeJson =
        """{"deviceCode":"dc","userCode":"ABC123","verificationUri":"https://x/karoo",
           "verificationUriComplete":"https://x/karoo?code=ABC123","expiresIn":600,"interval":5}"""

    @Test
    fun requestDeviceCode_postsClientIdKaroo() = runBlocking {
        // API-65: the clientId must be serialized even though it is the only property, otherwise
        // the backend received `{}` and listed the Karoo as « Autre ».
        val h = harness { json(deviceCodeJson) }
        val result = h.client.requestDeviceCode()

        val request = h.only
        assertEquals(HttpMethod.Post, request.method)
        assertEquals("$base/api/device/oauth/device", request.url.toString())
        assertEquals("""{"clientId":"karoo"}""", request.bodyText())
        assertNull(
            "no bearer on the unauthenticated flow",
            request.headers[HttpHeaders.Authorization],
        )
        assertTrue(request.body.contentType.toString().startsWith("application/json"))

        val response = result.getOrThrow()
        assertEquals("dc", response.deviceCode)
        assertEquals("ABC123", response.userCode)
        assertEquals("https://x/karoo?code=ABC123", response.verificationUriComplete)
        assertEquals(600, response.expiresIn)
        assertEquals(5, response.interval)
    }

    @Test
    fun requestDeviceCode_nonSuccessCarriesTheBody() = runBlocking {
        val h = harness {
            json("""{"code":"X","message":"nope"}""", HttpStatusCode.InternalServerError)
        }
        val error = h.client.requestDeviceCode().failure()
        assertTrue(error is ApiException)
        assertEquals("""{"code":"X","message":"nope"}""", error.message)
    }

    @Test
    fun requestDeviceCode_400IsAnApiExceptionWithTheRawBody() = runBlocking {
        val h = harness { json("""{"code":"BAD"}""", HttpStatusCode.BadRequest) }
        val error = h.client.requestDeviceCode().failure()
        assertTrue(error is ApiException)
        assertEquals("""{"code":"BAD"}""", error.message)
    }

    // === pollForToken ===

    @Test
    fun pollForToken_postsDeviceCodeGrant() = runBlocking {
        val h = harness { json(tokenJson) }
        val token = h.client.pollForToken("dev-code").getOrThrow()

        val request = h.only
        assertEquals(HttpMethod.Post, request.method)
        assertEquals("$base/api/device/oauth/token", request.url.toString())
        assertEquals(
            """{"grantType":"urn:ietf:params:oauth:grant-type:device_code","deviceCode":"dev-code"}""",
            request.bodyText(),
        )
        assertNull(request.headers[HttpHeaders.Authorization])
        assertEquals("acc", token.accessToken)
        assertEquals("Bearer", token.tokenType)
        assertEquals(3600, token.expiresIn)
        assertEquals("ref", token.refreshToken)
    }

    @Test
    fun pollForToken_authorizationPending() = runBlocking {
        val h = harness {
            json("""{"code":"AUTHORIZATION_PENDING","message":"wait"}""", HttpStatusCode.BadRequest)
        }
        assertTrue(h.client.pollForToken("d").failure() is AuthorizationPendingException)
    }

    @Test
    fun pollForToken_tokenExpired() = runBlocking {
        val h = harness { json("""{"code":"TOKEN_EXPIRED"}""", HttpStatusCode.BadRequest) }
        assertTrue(h.client.pollForToken("d").failure() is TokenExpiredException)
    }

    @Test
    fun pollForToken_otherBadRequestCarriesTheMessage() = runBlocking {
        val h = harness {
            json("""{"code":"WHATEVER","message":"Access denied"}""", HttpStatusCode.BadRequest)
        }
        val error = h.client.pollForToken("d").failure()
        assertTrue(error is ApiException)
        assertEquals("Access denied", error.message)
    }

    @Test
    fun pollForToken_badRequestWithoutMessageFallsBackToBadRequest() = runBlocking {
        val h = harness { json("""{"code":"WHATEVER"}""", HttpStatusCode.BadRequest) }
        val error = h.client.pollForToken("d").failure()
        assertTrue(error is ApiException)
        assertEquals("Bad request", error.message)
    }

    @Test
    fun pollForToken_other4xxAnd5xxCarryTheRawBody() = runBlocking {
        for (status in
            listOf(
                HttpStatusCode.Unauthorized,
                HttpStatusCode.Forbidden,
                HttpStatusCode.InternalServerError,
            )) {
            val h = harness { json("""{"code":"AUTHORIZATION_PENDING"}""", status) }
            val error = h.client.pollForToken("d").failure()
            // Only 400 maps the error code: any other status is a raw ApiException.
            assertTrue("$status", error is ApiException)
            assertEquals("""{"code":"AUTHORIZATION_PENDING"}""", error.message)
        }
    }

    @Test
    fun pollForToken_other2xxIsNotASuccess() = runBlocking {
        // CHARACTERIZATION: only an exact 200 yields a token here (refreshToken accepts any 2xx).
        val h = harness { json(tokenJson, HttpStatusCode.Created) }
        val error = h.client.pollForToken("d").failure()
        assertTrue(error is ApiException)
        assertEquals(tokenJson, error.message)
    }

    // === refreshToken ===

    @Test
    fun refreshToken_postsRefreshGrant() = runBlocking {
        val h = harness { json(tokenJson) }
        val token = h.client.refreshToken("old-refresh").getOrThrow()

        val request = h.only
        assertEquals(HttpMethod.Post, request.method)
        assertEquals("$base/api/device/oauth/token", request.url.toString())
        assertEquals(
            """{"grantType":"refresh_token","refreshToken":"old-refresh"}""",
            request.bodyText(),
        )
        assertNull(request.headers[HttpHeaders.Authorization])
        assertEquals("ref", token.refreshToken)
    }

    @Test
    fun refreshToken_answerWithoutRefreshTokenParsesWithNull() = runBlocking {
        val h = harness { json("""{"accessToken":"acc2","tokenType":"Bearer","expiresIn":60}""") }
        val token = h.client.refreshToken("r").getOrThrow()
        assertEquals("acc2", token.accessToken)
        assertNull(token.refreshToken)
    }

    @Test
    fun refreshToken_failuresAreApiExceptionsWithTheBody() = runBlocking {
        for (status in
            listOf(
                HttpStatusCode.BadRequest,
                HttpStatusCode.Unauthorized,
                HttpStatusCode.InternalServerError,
            )) {
            val h = harness { json("""{"code":"TOKEN_EXPIRED","message":"m"}""", status) }
            val error = h.client.refreshToken("r").failure()
            // No special mapping here, not even for 401 or TOKEN_EXPIRED.
            assertTrue("$status", error is ApiException)
            assertEquals("""{"code":"TOKEN_EXPIRED","message":"m"}""", error.message)
        }
    }

    // === getUserStatus ===

    @Test
    fun getUserStatus_getsMeWithBearer() = runBlocking {
        val h = harness { json("""{"connectedGpsServices":["GARMIN","HAMMERHEAD"]}""") }
        val status = h.client.getUserStatus("tok").getOrThrow()

        val request = h.only
        assertEquals(HttpMethod.Get, request.method)
        assertEquals("$base/api/device/me", request.url.toString())
        assertEquals("Bearer tok", request.headers[HttpHeaders.Authorization])
        assertEquals(listOf("GARMIN", "HAMMERHEAD"), status.connectedGpsServices)
        assertTrue(status.isHammerheadConnected())
    }

    @Test
    fun getUserStatus_401IsUnauthorized() = runBlocking {
        val h = harness { json("{}", HttpStatusCode.Unauthorized) }
        assertTrue(h.client.getUserStatus("t").failure() is UnauthorizedException)
    }

    @Test
    fun getUserStatus_otherErrorsCarryTheBody() = runBlocking {
        for (status in
            listOf(
                HttpStatusCode.BadRequest,
                HttpStatusCode.Forbidden,
                HttpStatusCode.InternalServerError,
            )) {
            val h = harness { json("boom", status) }
            val error = h.client.getUserStatus("t").failure()
            assertTrue("$status", error is ApiException)
            assertEquals("boom", error.message)
        }
    }

    // === getRoutes ===

    private val routesJson =
        """{"rides":[{"teamSlug":"t","rideSlug":"r","rideName":"Ride","startDateTime":"2026-11-14T08:00:00Z",
             "entries":[{"routeSlug":"rs","routeName":"Route","groupName":"G1","distance":42000.5,
             "elevationGain":600.0,"startLat":45.1,"startLon":5.2,"startDateTime":"2026-11-14T08:30:00Z"}]}],
           "routes":[{"teamSlug":"t","routeSlug":"s","routeName":"Solo","distance":1000,"elevationGain":10}],
           "registeredGroups":[{"teamSlug":"t","rideSlug":"r","rideName":"Ride","groupName":"G1","routeSlug":"rs",
             "routeName":"Route","distance":42000,"elevationGain":600,"startDateTime":"2026-11-14T08:30:00Z",
             "timezone":"Europe/Paris","syncStatuses":[{"serviceType":"HAMMERHEAD","state":"SENT"}]}]}"""

    @Test
    fun getRoutes_withoutPositionAsksForTheStagesOnly() = runBlocking {
        val h = harness { json(routesJson) }
        val routes = h.client.getRoutes("tok").getOrThrow()

        val request = h.only
        assertEquals(HttpMethod.Get, request.method)
        // `stages=true` is what makes the server add `registeredStages` (docs/LEDGER_*.md
        // API-168), `details=true` what a registered row says beside its route (API-194): a
        // device that sends neither keeps the response without them.
        assertEquals("$base/api/device/routes?stages=true&details=true", request.url.toString())
        assertEquals("Bearer tok", request.headers[HttpHeaders.Authorization])

        assertEquals(1, routes.rides.size)
        assertEquals("Ride", routes.rides[0].rideName)
        assertEquals(42000.5f, routes.rides[0].entries[0].distance)
        assertEquals(45.1, routes.rides[0].entries[0].startLat!!, 0.0)
        assertEquals("Solo", routes.routes[0].routeName)
        assertEquals("Europe/Paris", routes.registeredGroups[0].timezone)
        assertEquals(RouteSyncState.SENT, routes.registeredGroups[0].hammerheadSyncState())
    }

    @Test
    fun getRoutes_withPositionSendsLatLonQuery() = runBlocking {
        val h = harness { json(routesJson) }
        h.client.getRoutes("tok", lat = 45.5, lon = 5.25).getOrThrow()
        assertEquals("45.5", h.only.url.parameters["lat"])
        assertEquals("5.25", h.only.url.parameters["lon"])
    }

    @Test
    fun getRoutes_halfAPositionSendsNoPosition() = runBlocking {
        val h = harness { json(routesJson) }
        h.client.getRoutes("tok", lat = 45.5, lon = null).getOrThrow()
        assertEquals(setOf("stages", "details"), h.only.url.parameters.names())
    }

    @Test
    fun getRoutes_readsTheRegisteredStages() = runBlocking {
        val h = harness {
            json(
                """{"rides":[],"routes":[],"registeredGroups":[],
                   "registeredStages":[{"teamSlug":"t","tripSlug":"alps","tripName":"Alps crossing",
                     "stageName":"Stage 1","routeSlug":"rs","routeName":"Galibier","distance":82500,
                     "elevationGain":2100,"startDateTime":"2026-11-14T07:00:00Z","timezone":"Europe/Paris",
                     "startPlaceName":"Bourg-d'Oisans","endPlaceName":"Valloire",
                     "syncStatuses":[{"serviceType":"HAMMERHEAD","state":"OUTDATED"}]},
                    {"teamSlug":"t","tripSlug":"alps","tripName":"Alps crossing","stageName":"Stage 2",
                     "routeSlug":"rs2","routeName":"Iseran","distance":64000,"elevationGain":1800,
                     "startDateTime":"2026-11-15T07:00:00Z","timezone":"Europe/Paris","syncStatuses":[]}]}""",
            )
        }
        val routes = h.client.getRoutes("tok").getOrThrow()

        val stage = routes.registeredStages[0]
        assertEquals("alps", stage.tripSlug)
        assertEquals("Stage 1", stage.stageName)
        assertEquals("rs", stage.routeSlug)
        assertEquals(82500f, stage.distance)
        assertEquals("Bourg-d'Oisans", stage.startPlaceName)
        assertEquals("Valloire", stage.endPlaceName)
        assertEquals(RouteSyncState.OUTDATED, stage.hammerheadSyncState())
        // A stage that names no place, and whose route Hammerhead does not hold.
        assertEquals(null, routes.registeredStages[1].startPlaceName)
        assertEquals(null, routes.registeredStages[1].hammerheadSyncState())
    }

    @Test
    fun getRoutes_anOlderServerSendsNoStage() = runBlocking {
        val h = harness { json(routesJson) }
        assertTrue(h.client.getRoutes("tok").getOrThrow().registeredStages.isEmpty())
    }

    @Test
    fun getRoutes_401IsUnauthorized() = runBlocking {
        val h = harness { json("{}", HttpStatusCode.Unauthorized) }
        assertTrue(h.client.getRoutes("t").failure() is UnauthorizedException)
    }

    @Test
    fun getRoutes_otherErrorsCarryTheBody() = runBlocking {
        for (status in
            listOf(
                HttpStatusCode.BadRequest,
                HttpStatusCode.NotFound,
                HttpStatusCode.InternalServerError,
            )) {
            val h = harness { json("oops", status) }
            val error = h.client.getRoutes("t").failure()
            assertTrue("$status", error is ApiException)
            assertEquals("oops", error.message)
        }
    }

    @Test
    fun getRoutes_olderBackendWithoutRegisteredGroupsParses() = runBlocking {
        val h = harness { json("""{"rides":[],"routes":[]}""") }
        val routes = h.client.getRoutes("t").getOrThrow()
        assertTrue(routes.registeredGroups.isEmpty())
    }

    @Test
    fun getRoutes_unknownExtraFieldsAreIgnored() = runBlocking {
        val h = harness {
            json(
                """{"rides":[],"routes":[{"teamSlug":"t","routeSlug":"s","routeName":"n","distance":1,
                       "elevationGain":2,"somethingNew":{"a":1}}],"futureField":[1,2,3]}""",
            )
        }
        val routes = h.client.getRoutes("t").getOrThrow()
        assertEquals("n", routes.routes.single().routeName)
    }

    @Test
    fun getRoutes_syncStatusesAbsentOrNullMeansUnknown() = runBlocking {
        fun group(extra: String) =
            """{"teamSlug":"t","rideSlug":"r","rideName":"R","groupName":"G","routeSlug":"rs","routeName":"N",
               "distance":1,"elevationGain":1,"startDateTime":"2026-11-14T08:00:00Z"$extra}"""
        for (extra in listOf("", ""","syncStatuses":null""")) {
            val h = harness {
                json("""{"rides":[],"routes":[],"registeredGroups":[${group(extra)}]}""")
            }
            val g = h.client.getRoutes("t").getOrThrow().registeredGroups.single()
            assertNull(g.syncStatuses)
            assertNull(g.hammerheadSyncState())
            assertNull(g.timezone)
        }
    }

    @Test
    fun getRoutes_unknownSyncStateDoesNotBreakTheResponse() = runBlocking {
        val h = harness {
            json(
                """{"rides":[],"routes":[],"registeredGroups":[{"teamSlug":"t","rideSlug":"r","rideName":"R",
                       "groupName":"G","routeSlug":"rs","routeName":"N","distance":1,"elevationGain":1,
                       "startDateTime":"2026-11-14T08:00:00Z",
                       "syncStatuses":[{"serviceType":"HAMMERHEAD","state":"SOMETHING_NEW"}]}]}""",
            )
        }
        val g = h.client.getRoutes("t").getOrThrow().registeredGroups.single()
        assertEquals("SOMETHING_NEW", g.syncStatuses!!.single().state)
        assertNull(g.hammerheadSyncState())
    }

    @Test
    fun getRoutes_entryWithoutStartDateTimeFallsBackToTheRide() = runBlocking {
        val h = harness {
            json(
                """{"rides":[{"teamSlug":"t","rideSlug":"r","rideName":"R","startDateTime":"2026-11-14T08:00:00Z",
                       "entries":[{"routeSlug":"a","routeName":"A","distance":1,"elevationGain":1}]}],"routes":[]}""",
            )
        }
        val ride = h.client.getRoutes("t").getOrThrow().rides.single()
        val entry = ride.entries.single()
        assertNull(entry.startDateTime)
        assertNull(entry.groupName)
        assertEquals("2026-11-14T08:00:00Z", ride.startOf(entry))
    }

    @Test
    fun getRoutes_rideWithoutStartDateTimeParses() = runBlocking {
        val h = harness {
            json(
                """{"rides":[{"teamSlug":"t","rideSlug":"r","rideName":"R","entries":[]}],"routes":[]}""",
            )
        }
        assertNull(h.client.getRoutes("t").getOrThrow().rides.single().startDateTime)
    }

    @Test
    fun getRoutes_missingRequiredFieldIsAFailure() = runBlocking {
        val h = harness { json("""{"rides":[]}""") }
        assertTrue(h.client.getRoutes("t").isFailure)
    }

    // === syncRoute ===

    @Test
    fun syncRoute_postsToTheHammerheadSyncUrlWithBearerAndNoBody() = runBlocking {
        val h = harness { json("""{"success":true,"message":"ok","externalRouteId":"ext-1"}""") }
        val sync = h.client.syncRoute("tok", "team-a", "route-b").getOrThrow()

        val request = h.only
        assertEquals(HttpMethod.Post, request.method)
        assertEquals(
            "$base/api/device/routes/team-a/route-b/sync?type=hammerhead",
            request.url.toString(),
        )
        assertEquals("hammerhead", request.url.parameters["type"])
        assertEquals("Bearer tok", request.headers[HttpHeaders.Authorization])
        assertEquals("", request.bodyText())
        assertTrue(sync.success)
        assertEquals("ok", sync.message)
        assertEquals("ext-1", sync.externalRouteId)
    }

    @Test
    fun syncRoute_minimalAnswerParses() = runBlocking {
        val h = harness { json("""{"success":false}""") }
        val sync = h.client.syncRoute("t", "a", "b").getOrThrow()
        // CHARACTERIZATION: a 200 with success=false is still a successful Result at this layer.
        assertFalse(sync.success)
        assertNull(sync.message)
        assertNull(sync.externalRouteId)
    }

    @Test
    fun syncRoute_401IsUnauthorized() = runBlocking {
        val h = harness { json("{}", HttpStatusCode.Unauthorized) }
        assertTrue(h.client.syncRoute("t", "a", "b").failure() is UnauthorizedException)
    }

    @Test
    fun syncRoute_errorCarriesTheBody() = runBlocking {
        val body = """{"code":"GPS_SERVICE_NOT_CONNECTED","message":"no hammerhead"}"""
        val h = harness { json(body, HttpStatusCode.BadRequest) }
        val error = h.client.syncRoute("t", "a", "b").failure()
        assertTrue(error is ApiException)
        assertEquals(body, error.message)
    }

    // === transport ===

    @Test
    fun networkFailureIsAFailureResult() = runBlocking {
        val engine = MockEngine { throw java.io.IOException("offline") }
        val client = PedalonsApiClient(base, engine)
        val error = client.getRoutes("t").failure()
        assertEquals("offline", error.message)
        assertNotNull(error)
    }

    @Test
    fun getRequestsAcceptJson() = runBlocking {
        val h = harness { json(routesJson) }
        h.client.getRoutes("t").getOrThrow()
        // The JSON plugin announces Accept, and defaultRequest sets the content type even on a GET.
        assertEquals("application/json", h.only.headers[HttpHeaders.Accept])
        assertEquals("application/json", h.only.headers[HttpHeaders.ContentType])
    }
}
