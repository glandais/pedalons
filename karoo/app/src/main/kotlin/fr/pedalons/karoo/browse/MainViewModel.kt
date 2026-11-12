package fr.pedalons.karoo.browse

import androidx.lifecycle.ViewModel
import fr.pedalons.karoo.KarooKey
import fr.pedalons.karoo.api.DeviceRide
import fr.pedalons.karoo.api.DeviceRideEntry
import fr.pedalons.karoo.api.DeviceRoute
import fr.pedalons.karoo.auth.GpsConnectActivity
import fr.pedalons.karoo.auth.TokenStore
import fr.pedalons.karoo.data.HammerheadStatus
import fr.pedalons.karoo.data.PedalonsRepository
import fr.pedalons.karoo.data.RoutesResult
import fr.pedalons.karoo.data.SyncResult
import io.hammerhead.karooext.models.UserProfile
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.receiveAsFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

/** What the user asks of the main screen by touch (the keys go through [MainViewModel.onKey]). */
internal sealed interface MainIntent {
    data class OpenHomeEntry(val entry: HomeEntry) : MainIntent

    data class OpenRide(val ride: DeviceRide) : MainIntent

    data class OpenRideEntry(val ride: DeviceRide, val entry: DeviceRideEntry) : MainIntent

    data class OpenRoute(val route: DeviceRoute) : MainIntent

    /** [row] is the row of the registered groups list, null from the route detail. */
    data class Sync(val teamSlug: String, val routeSlug: String, val row: Int?) : MainIntent

    data object Back : MainIntent

    data object Refresh : MainIntent

    data object Retry : MainIntent

    data object Disconnect : MainIntent
}

/** What the activity must do, once. */
internal enum class MainEffect {
    Finish,
    StartGpsConnect,
}

/**
 * The state and the orchestration of the main screen: startup (Hammerhead check, first load),
 * loads, syncs, sign-in and sign-out. All state writes happen on the main thread (the scope's
 * dispatcher); the rules of navigation and sync live in the pure [BrowseState].
 */
internal class MainViewModel(
    private val connect: suspend () -> PedalonsRepository,
    private val userProfiles: () -> Flow<UserProfile>,
    private val tokens: TokenStore,
    private val scope: CoroutineScope =
        CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate),
    vararg closeables: AutoCloseable,
) : ViewModel(scope, *closeables) {

    private val _state = MutableStateFlow(MainUiState())
    val state: StateFlow<MainUiState> = _state.asStateFlow()

    private val channel = Channel<MainEffect>(Channel.BUFFERED)
    val effects: Flow<MainEffect> = channel.receiveAsFlow()

    private lateinit var repo: PedalonsRepository
    private var sessionJob: Job? = null
    private var awaitingHammerhead = false
    private var authFlowPending = false

    init {
        scope.launch {
            repo = connect()
            _state.update { it.copy(karooReady = true) }
            // Listen for user profile updates to get preferred units
            launch { userProfiles().collect { p -> _state.update { it.copy(userProfile = p) } } }
            tokens.isAuthenticated.distinctUntilChanged().collect {
                if (it) onSignedIn() else onSignedOut()
            }
        }
    }

    // === Keys and touch ===

    fun onKey(key: KarooKey) {
        // Keys are swallowed while connecting.
        if (!_state.value.karooReady) return
        val browse = _state.value.browse
        when (key) {
            KarooKey.NEXT -> setBrowse(browse.move(1))
            KarooKey.PREVIOUS -> setBrowse(browse.move(-1))
            KarooKey.SELECT -> apply(browse.select())
            KarooKey.BACK -> apply(browse.back())
        }
    }

    fun onIntent(intent: MainIntent) {
        val browse = _state.value.browse
        when (intent) {
            is MainIntent.OpenHomeEntry -> apply(browse.openHomeEntry(intent.entry))
            is MainIntent.OpenRide -> apply(browse.openRide(intent.ride))
            is MainIntent.OpenRideEntry -> apply(browse.openRideEntry(intent.ride, intent.entry))
            is MainIntent.OpenRoute -> apply(browse.openRoute(intent.route))
            is MainIntent.Sync -> apply(browse.sync(intent.teamSlug, intent.routeSlug, intent.row))
            MainIntent.Back -> apply(browse.back())
            MainIntent.Refresh -> refresh()
            MainIntent.Retry -> retry()
            MainIntent.Disconnect -> signOut()
        }
    }

    // === Activity results ===

    /**
     * The sign-in screen is opening. The tokens it saves must not start the session behind it: the
     * session starts once, from [onAuthResult], when the rider is back.
     */
    fun onAuthFlowStarted() {
        authFlowPending = true
    }

    fun onAuthResult(resultCode: Int) {
        authFlowPending = false
        // Signed in (the tokens were saved): check the account and load, once. Otherwise there is
        // nothing to do, the sign-in emission to come starts the session.
        if (_state.value.auth == AuthStatus.SIGNED_IN) startSession()
    }

    // Hammerhead is mandatory (docs/LEDGER_*.md API-63): only a connected account goes on to the
    // routes. Leaving the step without one either signs the Karoo out or closes the app.
    fun onGpsConnectResult(resultCode: Int) {
        when (resultCode) {
            GpsConnectActivity.RESULT_SUCCESS -> {
                // Opened after a failed sync rather than by the startup check: nothing to resume.
                if (awaitingHammerhead) {
                    awaitingHammerhead = false
                    sessionJob = scope.launch { loadInitial() }
                }
            }
            GpsConnectActivity.RESULT_LOGOUT -> {
                awaitingHammerhead = false
                signOut()
            }
            else -> channel.trySend(MainEffect.Finish)
        }
    }

    // === Session ===

    private fun onSignedIn() {
        // One write, so the Empty screen never shows between the sign-in and the load.
        _state.update { it.copy(auth = AuthStatus.SIGNED_IN, isLoading = true) }
        if (!authFlowPending) startSession()
    }

    private fun onSignedOut() {
        _state.update {
            it.copy(
                auth = AuthStatus.SIGNED_OUT,
                isLoading = false,
                loadFailed = false,
                browse = it.browse.withResponse(null),
            )
        }
        awaitingHammerhead = false
        sessionJob?.cancel()
    }

    private fun startSession() {
        if (sessionJob?.isActive == true) return
        sessionJob = scope.launch {
            _state.update { it.copy(isLoading = true) }
            when (repo.hammerheadStatus()) {
                // Not linked sends the rider to the mandatory step; the load waits for it.
                HammerheadStatus.NOT_LINKED -> {
                    awaitingHammerhead = true
                    channel.send(MainEffect.StartGpsConnect)
                }
                // Unknown (no token, a failed read) goes on.
                HammerheadStatus.LINKED,
                HammerheadStatus.UNKNOWN -> loadInitial()
            }
        }
    }

    // The first load of a session: a refused token signs the Karoo out (the isAuthenticated
    // collector takes it from there), any other failure shows the error.
    private suspend fun loadInitial() {
        when (val result = repo.loadRoutes()) {
            is RoutesResult.Loaded ->
                _state.update {
                    it.copy(
                        browse = it.browse.withResponse(result.response),
                        isLoading = false,
                        loadFailed = false,
                    )
                }
            RoutesResult.Unauthorized -> {
                _state.update { it.copy(isLoading = false) }
                // Its own coroutine: the sign-out this triggers cancels the session job, which
                // must not cut the clear.
                scope.launch { tokens.clear() }
            }
            is RoutesResult.Failed ->
                _state.update { it.copy(loadFailed = result.message != null, isLoading = false) }
        }
    }

    /** The Home icon: a manual reload that goes back to Home. A refused token keeps the tokens. */
    private fun refresh() {
        _state.update { it.copy(isLoading = true) }
        scope.launch {
            when (val result = repo.loadRoutes()) {
                is RoutesResult.Loaded ->
                    _state.update {
                        it.copy(
                            browse = it.browse.withResponse(result.response).resetToHome(),
                            isLoading = false,
                            loadFailed = false,
                        )
                    }
                else -> manualFailure(result)
            }
        }
    }

    /** The error screen: reload where we are. A refused token keeps the tokens. */
    private fun retry() {
        _state.update { it.copy(isLoading = true, loadFailed = false) }
        scope.launch {
            when (val result = repo.loadRoutes()) {
                is RoutesResult.Loaded ->
                    _state.update {
                        it.copy(browse = it.browse.withResponse(result.response), isLoading = false)
                    }
                else -> manualFailure(result)
            }
        }
    }

    private fun manualFailure(result: RoutesResult) {
        val failed =
            when (result) {
                RoutesResult.Unauthorized -> true
                is RoutesResult.Failed -> result.message != null
                is RoutesResult.Loaded -> false
            }
        _state.update { it.copy(loadFailed = failed, isLoading = false) }
    }

    /** Clears the tokens and the routes. Nothing is sent to the server. */
    private fun signOut() {
        scope.launch {
            tokens.clear()
            _state.update { it.copy(browse = it.browse.signedOut()) }
        }
    }

    // === Browse steps ===

    private fun setBrowse(browse: BrowseState) {
        _state.value = _state.value.copy(browse = browse)
    }

    private fun apply(step: BrowseStep) {
        setBrowse(step.state)
        when (val outcome = step.outcome) {
            BrowseOutcome.None -> Unit
            BrowseOutcome.Finish -> channel.trySend(MainEffect.Finish)
            is BrowseOutcome.StartSync -> launchSync(outcome)
        }
    }

    // Not cancelled by navigation: the generation keeps a late result off another screen.
    private fun launchSync(sync: BrowseOutcome.StartSync) {
        scope.launch {
            val result = repo.syncRoute(sync.teamSlug, sync.routeSlug)
            if (result is SyncResult.HammerheadNotLinked) channel.send(MainEffect.StartGpsConnect)
            val state = if (result is SyncResult.Synced) SyncState.SUCCESS else SyncState.ERROR
            _state.update {
                it.copy(
                    browse =
                        it.browse.syncFinished(
                            sync.generation,
                            sync.teamSlug,
                            sync.routeSlug,
                            state,
                        ),
                )
            }
        }
    }
}
