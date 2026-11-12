package fr.pedalons.karoo.auth

import fr.pedalons.karoo.api.DeviceCodeResponse
import fr.pedalons.karoo.data.DeviceAuthRepository
import fr.pedalons.karoo.data.DeviceCodeResult
import fr.pedalons.karoo.data.DevicePoll
import java.time.Clock
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

internal sealed interface AuthState {
    data object Loading : AuthState

    data class ShowingCode(val deviceCodeResponse: DeviceCodeResponse) : AuthState

    data object Success : AuthState

    data class Error(val message: String) : AuthState

    data object Expired : AuthState
}

/**
 * The device code flow (RFC 8628): asks for a code, shows it through [state] and polls at the
 * server's interval until the rider authorizes it, the code expires or the server refuses. [run]
 * must run in the composition's coroutine context (a `LaunchedEffect`), so that its delays follow
 * the frame clock.
 */
internal class DeviceCodeLogin(
    private val repo: DeviceAuthRepository,
    private val tokens: TokenStore,
    private val clock: Clock,
) {
    private val _state = MutableStateFlow<AuthState>(AuthState.Loading)
    val state: StateFlow<AuthState> = _state.asStateFlow()

    /** True once signed in (tokens saved, success shown for a second); false when it ended. */
    suspend fun run(): Boolean {
        val code =
            when (val result = repo.requestCode()) {
                is DeviceCodeResult.Failed -> {
                    _state.value =
                        AuthState.Error(result.message ?: "Failed to start authentication")
                    return false
                }
                is DeviceCodeResult.Issued -> result.code
            }
        _state.value = AuthState.ShowingCode(code)

        val intervalMs = (code.interval * 1000).toLong()
        val expiresAt = clock.millis() + (code.expiresIn * 1000)

        while (clock.millis() < expiresAt) {
            delay(intervalMs)

            when (val poll = repo.poll(code.deviceCode)) {
                is DevicePoll.Authorized -> {
                    tokens.save(poll.token)
                    _state.value = AuthState.Success
                    delay(1000) // Show success briefly
                    return true
                }
                DevicePoll.Pending -> {
                    // Continue polling
                }
                DevicePoll.Expired -> {
                    _state.value = AuthState.Expired
                    return false
                }
                is DevicePoll.Failed -> {
                    _state.value = AuthState.Error(poll.message ?: "Unknown error")
                    return false
                }
            }
        }

        // Timeout
        _state.value = AuthState.Expired
        return false
    }
}
