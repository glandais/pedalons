package fr.pedalons.karoo.api

import de.jonasfranz.ktor.client.karoo.Karoo
import io.hammerhead.karooext.KarooSystemService
import io.ktor.client.HttpClient
import io.ktor.client.call.body
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
class PedalonsApiClient(
    private val baseUrl: String,
    karooSystemService: KarooSystemService,
) {
    private val json = Json {
        ignoreUnknownKeys = true
        isLenient = true
    }

    private val client =
        HttpClient(Karoo(karooSystemService)) {
            install(ContentNegotiation) {
                json(json)
            }
            defaultRequest {
                contentType(ContentType.Application.Json)
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
