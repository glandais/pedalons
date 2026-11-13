package fr.pedalons.karoo.api

import de.jonasfranz.ktor.client.karoo.Karoo
import io.hammerhead.karooext.KarooSystemService
import io.ktor.client.HttpClient
import io.ktor.client.HttpClientConfig
import io.ktor.client.call.body
import io.ktor.client.engine.HttpClientEngine
import io.ktor.client.engine.HttpClientEngineFactory
import io.ktor.client.plugins.contentnegotiation.ContentNegotiation
import io.ktor.client.plugins.defaultRequest
import io.ktor.client.request.bearerAuth
import io.ktor.client.request.get
import io.ktor.client.request.parameter
import io.ktor.client.request.post
import io.ktor.client.request.setBody
import io.ktor.client.statement.bodyAsText
import io.ktor.http.ContentType
import io.ktor.http.contentType
import io.ktor.http.isSuccess
import io.ktor.serialization.kotlinx.json.json
import kotlinx.serialization.json.Json

/**
 * HTTP client for Pédalons API using Ktor with Karoo engine. The Karoo engine routes HTTP requests
 * through the Karoo System Service, which handles network connectivity on Karoo devices.
 */
class PedalonsApiClient
private constructor(
    private val baseUrl: String,
    private val client: HttpClient,
) {
    constructor(
        baseUrl: String,
        karooSystemService: KarooSystemService,
    ) : this(
        baseUrl,
        // Test seam: lets the JVM tests answer every request of every client the app builds.
        // Null in production, which keeps the Karoo engine.
        engineFactoryForTests?.invoke(karooSystemService)?.let { buildClient(it) }
            ?: buildClient(Karoo(karooSystemService)),
    )

    /** Test seam: a client on any Ktor engine (e.g. ktor-client-mock). */
    internal constructor(
        baseUrl: String,
        engine: HttpClientEngine,
    ) : this(baseUrl, buildClient(engine))

    companion object {
        private val json = Json {
            ignoreUnknownKeys = true
            isLenient = true
        }

        /**
         * Test seam, null in production: when set, the public constructor builds its client on the
         * engine this returns instead of the Karoo one.
         */
        @Volatile
        internal var engineFactoryForTests: ((KarooSystemService) -> HttpClientEngine)? = null

        private fun buildClient(engine: HttpClientEngine): HttpClient =
            HttpClient(engine) { configure() }

        private fun buildClient(factory: HttpClientEngineFactory<*>): HttpClient =
            HttpClient(factory) { configure() }

        private fun HttpClientConfig<*>.configure() {
            install(ContentNegotiation) {
                json(json)
            }
            defaultRequest {
                contentType(ContentType.Application.Json)
            }
        }
    }

    // === Device Code Flow ===

    suspend fun requestDeviceCode(): Result<DeviceCodeResponse> = runCatching {
        val response =
            client.post("$baseUrl/api/device/oauth/device") {
                setBody(DeviceCodeRequest(clientId = "karoo"))
            }
        if (response.status.isSuccess()) {
            response.body<DeviceCodeResponse>()
        } else {
            throw ApiException(response.bodyAsText())
        }
    }

    suspend fun pollForToken(deviceCode: String): Result<TokenResponse> = runCatching {
        val response =
            client.post("$baseUrl/api/device/oauth/token") {
                setBody(
                    TokenRequest(
                        grantType = TokenRequest.GRANT_TYPE_DEVICE_CODE,
                        deviceCode = deviceCode,
                    ),
                )
            }
        when (response.status.value) {
            200 -> response.body<TokenResponse>()
            400 -> {
                val error = response.body<ErrorResponse>()
                when (error.code) {
                    "AUTHORIZATION_PENDING" -> throw AuthorizationPendingException()
                    "TOKEN_EXPIRED" -> throw TokenExpiredException()
                    else -> throw ApiException(error.message ?: "Bad request")
                }
            }
            else -> throw ApiException(response.bodyAsText())
        }
    }

    suspend fun refreshToken(refreshToken: String): Result<TokenResponse> = runCatching {
        val response =
            client.post("$baseUrl/api/device/oauth/token") {
                setBody(
                    TokenRequest(
                        grantType = TokenRequest.GRANT_TYPE_REFRESH,
                        refreshToken = refreshToken,
                    ),
                )
            }
        if (response.status.isSuccess()) {
            response.body<TokenResponse>()
        } else {
            throw ApiException(response.bodyAsText())
        }
    }

    // === User Status ===

    suspend fun getUserStatus(accessToken: String): Result<UserStatusResponse> = runCatching {
        val response =
            client.get("$baseUrl/api/device/me") {
                bearerAuth(accessToken)
            }
        if (response.status.isSuccess()) {
            response.body<UserStatusResponse>()
        } else if (response.status.value == 401) {
            throw UnauthorizedException()
        } else {
            throw ApiException(response.bodyAsText())
        }
    }

    // === Routes ===

    suspend fun getRoutes(
        accessToken: String,
        lat: Double? = null,
        lon: Double? = null,
    ): Result<RoutesResponse> = runCatching {
        val response =
            client.get("$baseUrl/api/device/routes") {
                bearerAuth(accessToken)
                // Asks for `registeredStages`: a device that does not send it gets the response
                // without them (docs/LEDGER_*.md API-168).
                parameter("stages", true)
                // And for what a registered row says beside its route — team, start place, status,
                // estimated arrival — and the groups of a cancelled ride (API-194).
                parameter("details", true)
                if (lat != null && lon != null) {
                    parameter("lat", lat)
                    parameter("lon", lon)
                }
            }
        if (response.status.isSuccess()) {
            response.body<RoutesResponse>()
        } else if (response.status.value == 401) {
            throw UnauthorizedException()
        } else {
            throw ApiException(response.bodyAsText())
        }
    }

    suspend fun syncRoute(
        accessToken: String,
        teamSlug: String,
        routeSlug: String,
    ): Result<SyncResponse> = runCatching {
        val response =
            client.post("$baseUrl/api/device/routes/$teamSlug/$routeSlug/sync?type=hammerhead") {
                bearerAuth(accessToken)
            }
        if (response.status.isSuccess()) {
            response.body<SyncResponse>()
        } else if (response.status.value == 401) {
            throw UnauthorizedException()
        } else {
            throw ApiException(response.bodyAsText())
        }
    }

    fun close() {
        client.close()
    }
}

// Exceptions
class ApiException(message: String) : Exception(message)

class AuthorizationPendingException : Exception("Authorization pending")

class TokenExpiredException : Exception("Token expired")

class UnauthorizedException : Exception("Unauthorized")
