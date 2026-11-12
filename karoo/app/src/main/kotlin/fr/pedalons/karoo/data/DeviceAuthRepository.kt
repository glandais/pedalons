package fr.pedalons.karoo.data

import fr.pedalons.karoo.api.AuthorizationPendingException
import fr.pedalons.karoo.api.DeviceCodeResponse
import fr.pedalons.karoo.api.PedalonsApiClient
import fr.pedalons.karoo.api.TokenExpiredException
import fr.pedalons.karoo.api.TokenResponse
import kotlinx.coroutines.CancellationException

internal sealed interface DeviceCodeResult {
    data class Issued(val code: DeviceCodeResponse) : DeviceCodeResult

    data class Failed(val message: String?) : DeviceCodeResult
}

internal sealed interface DevicePoll {
    data class Authorized(val token: TokenResponse) : DevicePoll

    data object Pending : DevicePoll

    data object Expired : DevicePoll

    data class Failed(val message: String?) : DevicePoll
}

/** The RFC 8628 calls of the sign-in, with their outcomes as values rather than exceptions. */
internal class DeviceAuthRepository(private val api: PedalonsApiClient) {

    suspend fun requestCode(): DeviceCodeResult =
        api.requestDeviceCode()
            .fold(
                onSuccess = { DeviceCodeResult.Issued(it) },
                onFailure = {
                    if (it is CancellationException) throw it
                    DeviceCodeResult.Failed(it.message)
                },
            )

    suspend fun poll(deviceCode: String): DevicePoll =
        api.pollForToken(deviceCode)
            .fold(
                onSuccess = { DevicePoll.Authorized(it) },
                onFailure = {
                    when (it) {
                        is CancellationException -> throw it
                        is AuthorizationPendingException -> DevicePoll.Pending
                        is TokenExpiredException -> DevicePoll.Expired
                        else -> DevicePoll.Failed(it.message)
                    }
                },
            )
}
