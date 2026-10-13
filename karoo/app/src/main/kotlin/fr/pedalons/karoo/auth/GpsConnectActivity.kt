package fr.pedalons.karoo.auth

import android.os.Bundle
import android.widget.Toast
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import fr.pedalons.karoo.R
import fr.pedalons.karoo.api.PedalonsApiClient
import fr.pedalons.karoo.api.UnauthorizedException
import fr.pedalons.karoo.ui.theme.PedalonsKarooTheme
import io.hammerhead.karooext.KarooSystemService
import kotlinx.coroutines.delay

/**
 * The mandatory last step of the onboarding (docs/LEDGER_*.md API-63, plan
 * docs/plans/2026-10-02-karoo-onboarding.md): the account has no Hammerhead, through which routes
 * reach the Karoo. The rider finishes on the phone, already on that step after authorizing the
 * Karoo; this screen follows `/api/device/me` and moves on by itself. Its QR is only a fallback,
 * for a phone whose page was closed: it opens the Hammerhead step alone, never the profile. The
 * only way out without Hammerhead is signing the Karoo out.
 */
class GpsConnectActivity : ComponentActivity() {

    companion object {
        const val EXTRA_BASE_URL = "base_url"
        const val RESULT_SUCCESS = 1
        const val RESULT_LOGOUT = 2
        const val RESULT_ERROR = -1

        /** How often the account is re-read — the device code's own polling interval. */
        const val POLL_INTERVAL_MS = 5_000L
    }

    private var apiClient: PedalonsApiClient? = null
    private lateinit var authManager: AuthManager
    private lateinit var karooSystem: KarooSystemService
    private var baseUrl: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        baseUrl =
            intent.getStringExtra(EXTRA_BASE_URL)
                ?: run {
                    setResult(RESULT_ERROR)
                    finish()
                    return
                }

        authManager = AuthManager(this)
        karooSystem = KarooSystemService(applicationContext)

        setContent {
            var isConnected by remember { mutableStateOf(false) }

            LaunchedEffect(Unit) {
                karooSystem.connect {}
                // Poll for connection status
                while (!karooSystem.connected) {
                    delay(100)
                }
                apiClient = PedalonsApiClient(baseUrl!!, karooSystem)
                isConnected = true
            }

            PedalonsKarooTheme {
                if (isConnected && apiClient != null) {
                    GpsConnectScreen(
                        apiClient = apiClient!!,
                        authManager = authManager,
                        resumeUrl = "$baseUrl/karoo/hammerhead",
                        onSuccess = {
                            setResult(RESULT_SUCCESS)
                            finish()
                        },
                        onLogout = {
                            setResult(RESULT_LOGOUT)
                            finish()
                        },
                    )
                } else {
                    // Show loading while connecting to Karoo System Service
                    Surface(
                        modifier = Modifier.fillMaxSize(),
                        color = MaterialTheme.colorScheme.background,
                    ) {
                        Box(
                            modifier = Modifier.fillMaxSize(),
                            contentAlignment = Alignment.Center,
                        ) {
                            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                                CircularProgressIndicator()
                                Spacer(modifier = Modifier.height(16.dp))
                                Text(stringResource(R.string.connecting))
                            }
                        }
                    }
                }
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        apiClient?.close()
        if (::karooSystem.isInitialized) {
            karooSystem.disconnect()
        }
    }
}

@Composable
private fun GpsConnectScreen(
    apiClient: PedalonsApiClient,
    authManager: AuthManager,
    resumeUrl: String,
    onSuccess: () -> Unit,
    onLogout: () -> Unit,
) {
    val context = LocalContext.current

    val qrBitmap = remember(resumeUrl) { generateQrCode(resumeUrl) }

    // Follows the account until Hammerhead shows up; a failed read (network, token) just waits for
    // the next round.
    LaunchedEffect(Unit) {
        while (true) {
            var connected = false
            checkHammerheadConnection(
                apiClient = apiClient,
                authManager = authManager,
                onSuccess = { connected = true },
                onNotConnected = {},
                onError = {},
            )
            if (connected) {
                Toast.makeText(context, R.string.gps_connect_success, Toast.LENGTH_SHORT).show()
                onSuccess()
                return@LaunchedEffect
            }
            delay(GpsConnectActivity.POLL_INTERVAL_MS)
        }
    }

    Surface(
        modifier = Modifier.fillMaxSize(),
        color = MaterialTheme.colorScheme.background,
    ) {
        Column(
            modifier = Modifier.fillMaxSize().padding(16.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.SpaceEvenly,
        ) {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Text(
                    text = stringResource(R.string.gps_connect_title),
                    style = MaterialTheme.typography.headlineSmall,
                    fontWeight = FontWeight.Bold,
                    textAlign = TextAlign.Center,
                )
                Spacer(modifier = Modifier.height(8.dp))
                Text(
                    text = stringResource(R.string.gps_connect_subtitle),
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    textAlign = TextAlign.Center,
                )
            }

            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.Center,
            ) {
                CircularProgressIndicator(modifier = Modifier.size(16.dp), strokeWidth = 2.dp)
                Spacer(modifier = Modifier.width(8.dp))
                Text(
                    text = stringResource(R.string.gps_connect_waiting),
                    style = MaterialTheme.typography.bodySmall,
                )
            }

            // Fallback for a phone whose page was closed.
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                qrBitmap?.let { bitmap ->
                    Image(
                        bitmap = bitmap.asImageBitmap(),
                        contentDescription = "QR Code",
                        modifier = Modifier.size(110.dp),
                    )
                }
                Spacer(modifier = Modifier.height(4.dp))
                Text(
                    text = stringResource(R.string.gps_connect_scan),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    textAlign = TextAlign.Center,
                )
            }

            OutlinedButton(
                onClick = onLogout,
                modifier = Modifier.fillMaxWidth(0.8f),
                colors =
                    ButtonDefaults.outlinedButtonColors(
                        contentColor = MaterialTheme.colorScheme.onSurfaceVariant,
                    ),
            ) {
                Text(stringResource(R.string.disconnect))
            }
        }
    }
}

private suspend fun checkHammerheadConnection(
    apiClient: PedalonsApiClient,
    authManager: AuthManager,
    onSuccess: () -> Unit,
    onNotConnected: () -> Unit,
    onError: () -> Unit,
) {
    // Get access token, refresh if needed
    var accessToken = authManager.getValidAccessToken()
    if (accessToken == null && authManager.needsRefresh()) {
        val refreshToken = authManager.getRefreshToken()
        if (refreshToken != null) {
            apiClient
                .refreshToken(refreshToken)
                .onSuccess { tokenResponse ->
                    // The refresh token rotates: keep the new one (docs/LEDGER_*.md SEC-11).
                    authManager.saveTokens(tokenResponse)
                    accessToken = tokenResponse.accessToken
                }
                .onFailure {
                    onError()
                    return
                }
        }
    }

    if (accessToken == null) {
        onError()
        return
    }

    apiClient
        .getUserStatus(accessToken)
        .onSuccess { status ->
            if (status.isHammerheadConnected()) {
                onSuccess()
            } else {
                onNotConnected()
            }
        }
        .onFailure { error ->
            if (error is UnauthorizedException) {
                onError()
            } else {
                onError()
            }
        }
}
