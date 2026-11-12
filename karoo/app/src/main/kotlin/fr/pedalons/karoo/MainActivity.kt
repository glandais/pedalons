package fr.pedalons.karoo

import android.content.Intent
import android.os.Bundle
import android.view.KeyEvent
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.result.ActivityResultLauncher
import androidx.activity.result.contract.ActivityResultContracts
import androidx.activity.viewModels
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.lifecycle.lifecycleScope
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import fr.pedalons.karoo.auth.AuthActivity
import fr.pedalons.karoo.auth.AuthManager
import fr.pedalons.karoo.auth.GpsConnectActivity
import fr.pedalons.karoo.auth.Session
import fr.pedalons.karoo.browse.MainEffect
import fr.pedalons.karoo.browse.MainViewModel
import fr.pedalons.karoo.browse.ui.MainRoute
import fr.pedalons.karoo.data.PedalonsRepository
import fr.pedalons.karoo.system.KarooConnection
import kotlinx.coroutines.launch

/** Main activity for browsing and syncing routes. */
class MainActivity : ComponentActivity() {

    private val viewModel: MainViewModel by viewModels {
        viewModelFactory {
            initializer {
                val connection = KarooConnection(this@MainActivity, BuildConfig.PEDALONS_BASE_URL)
                val authManager = AuthManager(applicationContext)
                MainViewModel(
                    connect = {
                        val api = connection.connect()
                        PedalonsRepository(api, Session(authManager, api))
                    },
                    userProfiles = connection::userProfiles,
                    tokens = authManager,
                    closeables = arrayOf(connection),
                )
            }
        }
    }

    // Activity Result API launchers (registered in onCreate)
    private val authLauncher: ActivityResultLauncher<Intent> =
        registerForActivityResult(ActivityResultContracts.StartActivityForResult()) { result ->
            viewModel.onAuthResult(result.resultCode)
        }

    private val gpsConnectLauncher: ActivityResultLauncher<Intent> =
        registerForActivityResult(ActivityResultContracts.StartActivityForResult()) { result ->
            viewModel.onGpsConnectResult(result.resultCode)
        }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Not repeatOnLifecycle: an effect can arrive while the activity is stopped (behind the
        // sign-in), and must still be acted on.
        lifecycleScope.launch {
            viewModel.effects.collect {
                when (it) {
                    MainEffect.Finish -> finish()
                    MainEffect.StartGpsConnect -> startGpsConnectFlow()
                }
            }
        }

        setContent {
            val state by viewModel.state.collectAsState()
            MainRoute(
                state = state,
                onIntent = viewModel::onIntent,
                onConnect = ::startAuthFlow,
                onClose = ::finish,
            )
        }
    }

    private fun startAuthFlow() {
        viewModel.onAuthFlowStarted()
        authLauncher.launch(
            Intent(this, AuthActivity::class.java).apply {
                putExtra(AuthActivity.EXTRA_BASE_URL, BuildConfig.PEDALONS_BASE_URL)
            },
        )
    }

    private fun startGpsConnectFlow() {
        gpsConnectLauncher.launch(
            Intent(this, GpsConnectActivity::class.java).apply {
                putExtra(GpsConnectActivity.EXTRA_BASE_URL, BuildConfig.PEDALONS_BASE_URL)
            },
        )
    }

    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        val key = KarooKey.fromKeyCode(keyCode) ?: return super.onKeyDown(keyCode, event)
        viewModel.onKey(key)
        return true
    }
}
