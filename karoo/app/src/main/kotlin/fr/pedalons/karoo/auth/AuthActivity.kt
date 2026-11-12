package fr.pedalons.karoo.auth

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import fr.pedalons.karoo.api.PedalonsApiClient
import fr.pedalons.karoo.data.DeviceAuthRepository
import fr.pedalons.karoo.system.KarooConnection
import fr.pedalons.karoo.ui.theme.PedalonsKarooTheme
import java.time.Clock

/**
 * Activity for device code authentication flow. Displays QR code and user code, polls for
 * authentication completion.
 */
class AuthActivity : ComponentActivity() {

    companion object {
        const val EXTRA_BASE_URL = "base_url"
        const val RESULT_SUCCESS = 1
        const val RESULT_CANCELLED = 0
        const val RESULT_ERROR = -1
    }

    private var connection: KarooConnection? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val baseUrl =
            intent.getStringExtra(EXTRA_BASE_URL)
                ?: run {
                    setResult(RESULT_ERROR)
                    finish()
                    return
                }

        val connection = KarooConnection(this, baseUrl).also { this.connection = it }

        setContent {
            val api by produceState<PedalonsApiClient?>(null) { value = connection.connect() }

            PedalonsKarooTheme {
                val client = api
                if (client != null) {
                    AuthScreen(
                        api = client,
                        onSuccess = {
                            setResult(RESULT_SUCCESS)
                            finish()
                        },
                        onCancel = {
                            setResult(RESULT_CANCELLED)
                            finish()
                        },
                    )
                } else {
                    // Show loading while connecting to Karoo System Service
                    ConnectingScreen()
                }
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        connection?.close()
    }

    @Composable
    private fun AuthScreen(api: PedalonsApiClient, onSuccess: () -> Unit, onCancel: () -> Unit) {
        val login =
            remember(api) {
                DeviceCodeLogin(DeviceAuthRepository(api), AuthManager(this), Clock.systemUTC())
            }
        // Started from the composition so that its delays follow the frame clock.
        LaunchedEffect(login) { if (login.run()) onSuccess() }

        val state by login.state.collectAsState()
        Surface(
            modifier = Modifier.fillMaxSize(),
            color = MaterialTheme.colorScheme.background,
        ) {
            when (val currentState = state) {
                is AuthState.Loading -> LoadingContent()
                is AuthState.ShowingCode -> CodeContent(currentState.deviceCodeResponse)
                is AuthState.Success -> SuccessContent()
                is AuthState.Error -> ErrorContent(currentState.message, onCancel)
                is AuthState.Expired -> ExpiredContent(onCancel)
            }
        }
    }
}
