package fr.pedalons.karoo.auth

import android.os.Bundle
import android.widget.Toast
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import fr.pedalons.karoo.R
import fr.pedalons.karoo.api.PedalonsApiClient
import fr.pedalons.karoo.data.PedalonsRepository
import fr.pedalons.karoo.system.KarooConnection
import fr.pedalons.karoo.ui.theme.PedalonsKarooTheme

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
                    GpsConnectScreen(client, "$baseUrl/karoo/hammerhead")
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
    private fun GpsConnectScreen(api: PedalonsApiClient, resumeUrl: String) {
        val watcher =
            remember(api) {
                HammerheadLinkWatcher(PedalonsRepository(api, Session(AuthManager(this), api)))
            }
        // Follows the account until Hammerhead shows up; a failed read (network, token) just waits
        // for the next round. Started from the composition so that its delays follow the frame
        // clock.
        LaunchedEffect(watcher) {
            watcher.awaitLinked()
            Toast.makeText(
                    this@GpsConnectActivity,
                    R.string.gps_connect_success,
                    Toast.LENGTH_SHORT,
                )
                .show()
            setResult(RESULT_SUCCESS)
            finish()
        }

        GpsConnectContent(
            resumeUrl = resumeUrl,
            onLogout = {
                setResult(RESULT_LOGOUT)
                finish()
            },
        )
    }
}
