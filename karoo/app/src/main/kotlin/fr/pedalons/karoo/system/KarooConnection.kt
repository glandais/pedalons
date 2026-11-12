package fr.pedalons.karoo.system

import android.content.Context
import fr.pedalons.karoo.api.PedalonsApiClient
import io.hammerhead.karooext.KarooSystemService
import io.hammerhead.karooext.models.UserProfile
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.callbackFlow

/**
 * The link of one activity to the Karoo System Service, and the HTTP client built on it. Each
 * activity owns one: [connect] before anything else, [close] in `onDestroy`.
 */
class KarooConnection(context: Context, private val baseUrl: String) : AutoCloseable {

    private val service = KarooSystemService(context.applicationContext)
    private var started = false
    private var client: PedalonsApiClient? = null

    /**
     * Connects to the system service and returns the API client riding on it, built once, after the
     * connection, through the public constructor (the `engineFactoryForTests` seam is there).
     */
    suspend fun connect(): PedalonsApiClient {
        client?.let {
            return it
        }
        if (!started) {
            started = true
            service.connect {}
        }
        // Polled rather than driven by the callback: only a real device can tell when the
        // callback fires, so the loop that has always shipped stays.
        while (!service.connected) {
            delay(100)
        }
        return client ?: PedalonsApiClient(baseUrl, service).also { client = it }
    }

    /** The user profile (preferred units), now and at every change. Collect after [connect]. */
    fun userProfiles(): Flow<UserProfile> = callbackFlow {
        val id = service.addConsumer<UserProfile> { trySend(it) }
        awaitClose { service.removeConsumer(id) }
    }

    override fun close() {
        client?.close()
        service.disconnect()
    }
}
