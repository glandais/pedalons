package fr.pedalons.karoo.support

import android.os.Bundle
import io.hammerhead.karooext.KarooSystemService
import io.hammerhead.karooext.aidl.IHandler
import io.hammerhead.karooext.aidl.IKarooSystem
import io.hammerhead.karooext.internal.KarooSystemListener
import io.hammerhead.karooext.models.UserProfile
import java.util.concurrent.ConcurrentHashMap
import kotlinx.serialization.json.Json
import org.robolectric.annotation.Implementation
import org.robolectric.annotation.Implements

/**
 * Stands in for the Karoo System Service, which only exists on a Hammerhead device: always
 * connected at once, and consumers registered through `addConsumer` can be fed from the test
 * ([emitUserProfile]). The real class still runs its constructor; only the service-bound methods
 * are replaced.
 */
@Implements(KarooSystemService::class)
class ShadowKarooSystemService {

    @Implementation
    fun connect(onConnection: ((Boolean) -> Unit)?) {
        onConnection?.invoke(true)
    }

    @Implementation fun getConnected(): Boolean = true

    @Implementation fun disconnect() {}

    @Implementation
    fun addConsumer(listener: KarooSystemListener): String {
        listener.register(controller)
        return listener.id
    }

    @Implementation
    fun removeConsumer(id: String) {
        handlers.remove(id)
    }

    companion object {
        private val handlers = ConcurrentHashMap<String, IHandler>()

        private val controller =
            object : IKarooSystem.Stub() {
                override fun libVersion(): String = "test"

                override fun info(): Bundle = Bundle()

                override fun dispatchEffect(effect: Bundle?) {}

                override fun addEventConsumer(id: String, params: Bundle?, handler: IHandler) {
                    handlers[id] = handler
                }

                override fun removeEventConsumer(id: String) {
                    handlers.remove(id)
                }
            }

        private val json = Json {
            encodeDefaults = true
            ignoreUnknownKeys = true
        }

        /** Delivers a user profile (preferred units) to whoever listens for it. */
        fun emitUserProfile(profile: UserProfile) {
            val bundle =
                Bundle().apply {
                    putString("value", json.encodeToString(UserProfile.serializer(), profile))
                }
            handlers.values.toList().forEach { it.onNext(bundle) }
        }

        fun reset() {
            handlers.clear()
        }
    }
}
