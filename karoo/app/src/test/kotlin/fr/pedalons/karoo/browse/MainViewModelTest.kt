@file:OptIn(ExperimentalCoroutinesApi::class)

package fr.pedalons.karoo.browse

import fr.pedalons.karoo.KarooKey
import fr.pedalons.karoo.api.PedalonsApiClient
import fr.pedalons.karoo.auth.AuthActivity
import fr.pedalons.karoo.auth.GpsConnectActivity
import fr.pedalons.karoo.auth.Session
import fr.pedalons.karoo.data.PedalonsRepository
import fr.pedalons.karoo.support.FakeTokenStore
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.emptyFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/** Startup, loads and results of [MainViewModel], on a virtual clock and a mocked network. */
class MainViewModelTest {

    private val routesJson =
        """{"rides":[],"routes":[{"teamSlug":"t","routeSlug":"r","routeName":"R","distance":1,"elevationGain":1}]}"""
    private val refreshed =
        """{"accessToken":"new","tokenType":"Bearer","expiresIn":3600,"refreshToken":"rot"}"""

    private class Backend {
        val requests = mutableListOf<String>()
        var me = """{"connectedGpsServices":["HAMMERHEAD"]}"""
        var routesStatus = HttpStatusCode.OK
    }

    private inner class Rig(
        val tokens: FakeTokenStore,
        val backend: Backend,
        val vm: MainViewModel,
        val scope: CoroutineScope,
        val connectGate: CompletableDeferred<Unit>,
    ) {
        val effects = mutableListOf<MainEffect>()
        val state
            get() = vm.state.value
    }

    private fun TestScope.rig(
        tokens: FakeTokenStore = FakeTokenStore(),
        gate: CompletableDeferred<Unit> = CompletableDeferred<Unit>().also { it.complete(Unit) },
        configure: Backend.() -> Unit = {},
    ): Rig {
        val backend = Backend().apply(configure)
        val engine = MockEngine { request ->
            backend.requests += "${request.method.value} ${request.url.encodedPath}"
            val json = HttpHeaders.ContentType to listOf("application/json")
            when (request.url.encodedPath) {
                "/api/device/oauth/token" ->
                    respond(refreshed, HttpStatusCode.OK, headersOf(json.first, json.second))
                "/api/device/me" ->
                    respond(backend.me, HttpStatusCode.OK, headersOf(json.first, json.second))
                else ->
                    respond(
                        if (backend.routesStatus == HttpStatusCode.OK) routesJson else "",
                        backend.routesStatus,
                        headersOf(json.first, json.second),
                    )
            }
        }
        val scope = CoroutineScope(SupervisorJob() + StandardTestDispatcher(testScheduler))
        val vm =
            MainViewModel(
                connect = {
                    gate.await()
                    val api = PedalonsApiClient("https://api.example.test", engine)
                    PedalonsRepository(api, Session(tokens, api))
                },
                userProfiles = { emptyFlow() },
                tokens = tokens,
                scope = scope,
            )
        return Rig(tokens, backend, vm, scope, gate)
    }

    // The mocked network answers on its own threads, which the virtual clock cannot see: wait in
    // real time for [until], or for a quiet period when it is a "nothing happens" check.
    private fun TestScope.settle(until: (() -> Boolean)? = null) {
        repeat(if (until == null) 10 else 300) {
            advanceUntilIdle()
            if (until?.invoke() == true) return
            Thread.sleep(10)
        }
        if (until != null) throw AssertionError("did not settle")
    }

    private fun Rig.start() {
        scope.launch { vm.effects.collect { effects += it } }
    }

    private fun Rig.content() = state.screen() == MainScreenKind.CONTENT

    @Test
    fun coldStart_withAnExpiredToken_refreshesThenChecksThenLoads_onceEach() = runTest {
        val rig = rig(FakeTokenStore(expired = true))
        rig.start()
        settle { rig.content() }
        assertEquals(
            listOf("POST /api/device/oauth/token", "GET /api/device/me", "GET /api/device/routes"),
            rig.backend.requests,
        )
        rig.scope.cancel()
    }

    @Test
    fun notLinked_sendsStartGpsConnect_staysLoading_thenGpsSuccessLoads() = runTest {
        val rig = rig { me = """{"connectedGpsServices":[]}""" }
        rig.start()
        settle { rig.effects.isNotEmpty() }
        settle()
        assertEquals(listOf(MainEffect.StartGpsConnect), rig.effects)
        assertTrue(rig.state.isLoading)
        assertTrue(rig.backend.requests.none { it.endsWith("/routes") })

        rig.vm.onGpsConnectResult(GpsConnectActivity.RESULT_SUCCESS)
        settle { rig.content() }
        rig.scope.cancel()
    }

    @Test
    fun gpsConnect_cancelled_finishes() = runTest {
        val rig = rig { me = """{"connectedGpsServices":[]}""" }
        rig.start()
        settle { rig.effects.isNotEmpty() }
        rig.vm.onGpsConnectResult(GpsConnectActivity.RESULT_ERROR)
        settle { rig.effects.size == 2 }
        assertEquals(listOf(MainEffect.StartGpsConnect, MainEffect.Finish), rig.effects)
        rig.scope.cancel()
    }

    @Test
    fun gpsConnect_successNotAwaited_doesNotReload() = runTest {
        val rig = rig()
        rig.start()
        settle { rig.content() }
        val before = rig.backend.requests.size
        rig.vm.onGpsConnectResult(GpsConnectActivity.RESULT_SUCCESS)
        settle()
        assertEquals(before, rig.backend.requests.size)
        rig.scope.cancel()
    }

    @Test
    fun initialLoad_401_clearsTheTokens_andSignsOut() = runTest {
        val rig = rig { routesStatus = HttpStatusCode.Unauthorized }
        rig.start()
        settle { rig.state.screen() == MainScreenKind.CONNECT }
        assertEquals(null, rig.tokens.access)
        rig.scope.cancel()
    }

    @Test
    fun manualRefresh_401_keepsTheTokens_andShowsTheError() = runTest {
        val rig = rig()
        rig.start()
        settle { rig.content() }
        rig.backend.routesStatus = HttpStatusCode.Unauthorized
        rig.vm.onIntent(MainIntent.Refresh)
        assertTrue(rig.state.isLoading)
        settle { rig.state.screen() == MainScreenKind.ERROR }
        assertEquals("stored-access", rig.tokens.access)
        rig.scope.cancel()
    }

    @Test
    fun retry_afterAFailure_loadsAgain() = runTest {
        val rig = rig { routesStatus = HttpStatusCode.InternalServerError }
        rig.start()
        settle { rig.state.screen() == MainScreenKind.ERROR }
        rig.backend.routesStatus = HttpStatusCode.OK
        rig.vm.onIntent(MainIntent.Retry)
        settle { rig.content() }
        rig.scope.cancel()
    }

    @Test
    fun keysBeforeTheKarooIsReady_areIgnored() = runTest {
        val gate = CompletableDeferred<Unit>()
        val rig = rig(gate = gate)
        rig.start()
        settle()
        rig.vm.onKey(KarooKey.BACK)
        settle()
        assertTrue(rig.effects.isEmpty())

        gate.complete(Unit)
        settle { rig.content() }
        rig.vm.onKey(KarooKey.BACK)
        settle { rig.effects.isNotEmpty() }
        assertEquals(listOf(MainEffect.Finish), rig.effects)
        rig.scope.cancel()
    }

    @Test
    fun authSuccess_whileSignedOut_waitsForTheSignInEmission() = runTest {
        val rig = rig(FakeTokenStore(access = null, refresh = null))
        rig.start()
        settle { rig.state.screen() == MainScreenKind.CONNECT }
        rig.vm.onAuthResult(AuthActivity.RESULT_SUCCESS)
        settle()
        assertTrue(rig.backend.requests.isEmpty())
        rig.scope.cancel()
    }

    @Test
    fun signIn_runsTheSessionOnce_whateverTheOrderOfTokensAndResult() = runTest {
        val tokens = FakeTokenStore(access = null, refresh = null)
        val rig = rig(tokens) { me = """{"connectedGpsServices":[]}""" }
        rig.start()
        settle { rig.state.screen() == MainScreenKind.CONNECT }
        rig.vm.onAuthFlowStarted()
        // The sign-in screen saves the tokens, then holds its success screen before the result.
        tokens.save(
            fr.pedalons.karoo.api.TokenResponse(
                accessToken = "a",
                tokenType = "Bearer",
                expiresIn = 3600,
                refreshToken = "r",
            ),
        )
        settle()
        assertTrue(rig.backend.requests.isEmpty())
        rig.vm.onAuthResult(AuthActivity.RESULT_SUCCESS)
        settle { rig.backend.requests.size >= 1 }
        settle()
        assertEquals(1, rig.backend.requests.count { it == "GET /api/device/me" })
        assertEquals(0, rig.backend.requests.count { it == "GET /api/device/routes" })
        assertEquals(1, rig.effects.count { it == MainEffect.StartGpsConnect })
        rig.scope.cancel()
    }

    @Test
    fun signIn_withHammerheadLinked_loadsRoutesOnce() = runTest {
        val tokens = FakeTokenStore(access = null, refresh = null)
        val rig = rig(tokens)
        rig.start()
        settle { rig.state.screen() == MainScreenKind.CONNECT }
        rig.vm.onAuthFlowStarted()
        tokens.save(
            fr.pedalons.karoo.api.TokenResponse(
                accessToken = "a",
                tokenType = "Bearer",
                expiresIn = 3600,
                refreshToken = "r",
            ),
        )
        settle()
        rig.vm.onAuthResult(AuthActivity.RESULT_SUCCESS)
        settle { rig.content() }
        settle()
        assertEquals(1, rig.backend.requests.count { it == "GET /api/device/me" })
        assertEquals(1, rig.backend.requests.count { it == "GET /api/device/routes" })
        assertTrue(rig.effects.count { it == MainEffect.StartGpsConnect } <= 1)
        rig.scope.cancel()
    }

    @Test
    fun disconnect_clearsTheTokens_andSendsNothing() = runTest {
        val rig = rig()
        rig.start()
        settle { rig.content() }
        val before = rig.backend.requests.size
        rig.vm.onIntent(MainIntent.Disconnect)
        settle { rig.state.screen() == MainScreenKind.CONNECT }
        assertEquals(before, rig.backend.requests.size)
        assertEquals(null, rig.tokens.access)
        rig.scope.cancel()
    }
}
