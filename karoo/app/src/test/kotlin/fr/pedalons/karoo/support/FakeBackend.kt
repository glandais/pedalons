package fr.pedalons.karoo.support

import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.client.request.HttpRequestData
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.content.OutgoingContent
import io.ktor.http.content.TextContent
import io.ktor.http.headersOf
import java.util.concurrent.CopyOnWriteArrayList

/** One request as the app sent it. */
data class RecordedRequest(
    val method: String,
    val path: String,
    val query: Map<String, String>,
    val bearer: String?,
    val body: String,
) {
    val isRefresh: Boolean
        get() = path == "/api/device/oauth/token" && body.contains("\"refresh_token\"")

    val isDevicePoll: Boolean
        get() = path == "/api/device/oauth/token" && body.contains("device_code")

    override fun toString(): String = "$method $path${if (query.isEmpty()) "" else query}"
}

data class Reply(val status: Int = 200, val body: String = "{}")

fun ok(body: String) = Reply(200, body)

/**
 * The Pédalons API as the Karoo sees it: every endpoint is a replaceable (suspending, so a test can
 * hold an answer back) lambda, every request is recorded. An endpoint not scripted answers with a
 * sensible success; a request to an unknown URL answers 404 and is recorded in [unexpected].
 */
class FakeBackend {
    val requests = CopyOnWriteArrayList<RecordedRequest>()
    val unexpected = CopyOnWriteArrayList<RecordedRequest>()

    var deviceCode: suspend (RecordedRequest) -> Reply = { ok(Fixtures.deviceCodeJson()) }
    var devicePoll: suspend (RecordedRequest) -> Reply = { ok(Fixtures.tokenJson()) }
    var refresh: suspend (RecordedRequest) -> Reply = {
        ok(Fixtures.tokenJson("refreshed", "rotated"))
    }
    var me: suspend (RecordedRequest) -> Reply = {
        ok("""{"connectedGpsServices":["HAMMERHEAD"]}""")
    }
    var routes: suspend (RecordedRequest) -> Reply = { ok(Fixtures.routesJson()) }
    var sync: suspend (RecordedRequest) -> Reply = { ok("""{"success":true}""") }

    /** Requests of the given kind, in order. */
    fun paths(): List<String> = requests.map { it.toString() }

    fun count(method: String, path: String) = requests.count {
        it.method == method && it.path == path
    }

    fun syncRequests() = requests.filter { it.method == "POST" && it.path.endsWith("/sync") }

    fun engine(): MockEngine = MockEngine { request ->
        val recorded = request.record()
        requests += recorded
        val reply =
            when {
                recorded.method == "POST" && recorded.path == "/api/device/oauth/device" ->
                    deviceCode(recorded)
                recorded.method == "POST" && recorded.path == "/api/device/oauth/token" ->
                    if (recorded.isRefresh) refresh(recorded) else devicePoll(recorded)
                recorded.method == "GET" && recorded.path == "/api/device/me" -> me(recorded)
                recorded.method == "GET" && recorded.path == "/api/device/routes" ->
                    routes(recorded)
                recorded.method == "POST" &&
                    recorded.path.startsWith("/api/device/routes/") &&
                    recorded.path.endsWith("/sync") -> sync(recorded)
                else -> {
                    unexpected += recorded
                    Reply(404, "unexpected request")
                }
            }
        respond(
            reply.body,
            HttpStatusCode.fromValue(reply.status),
            headersOf(HttpHeaders.ContentType, "application/json"),
        )
    }

    private fun HttpRequestData.record(): RecordedRequest {
        val text =
            when (val b = body) {
                is TextContent -> b.text
                is OutgoingContent.ByteArrayContent -> b.bytes().decodeToString()
                else -> ""
            }
        return RecordedRequest(
            method = method.value,
            path = url.encodedPath,
            query = url.parameters.entries().associate { it.key to it.value.first() },
            bearer = headers[HttpHeaders.Authorization]?.removePrefix("Bearer "),
            body = text,
        )
    }
}
