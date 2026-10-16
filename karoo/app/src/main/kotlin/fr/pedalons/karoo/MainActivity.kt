package fr.pedalons.karoo

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.text.format.DateFormat
import android.view.KeyEvent
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.result.ActivityResultLauncher
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyListState
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.focusProperties
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import fr.pedalons.karoo.api.DeviceRegisteredGroup
import fr.pedalons.karoo.api.DeviceRide
import fr.pedalons.karoo.api.DeviceRideEntry
import fr.pedalons.karoo.api.DeviceRoute
import fr.pedalons.karoo.api.PedalonsApiClient
import fr.pedalons.karoo.api.RouteSyncState
import fr.pedalons.karoo.api.RoutesResponse
import fr.pedalons.karoo.api.UnauthorizedException
import fr.pedalons.karoo.auth.AuthActivity
import fr.pedalons.karoo.auth.AuthManager
import fr.pedalons.karoo.auth.GpsConnectActivity
import fr.pedalons.karoo.ui.theme.PedalonsKarooTheme
import io.hammerhead.karooext.KarooSystemService
import io.hammerhead.karooext.models.UserProfile
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

// Conversion constants
private const val METERS_PER_MILE = 1609.344
private const val METERS_PER_FOOT = 0.3048
private const val METERS_PER_KM = 1000.0

// The key of a route in the routes synced during the session ([MainScreen]).
private fun routeKey(teamSlug: String, routeSlug: String): String = "$teamSlug/$routeSlug"

// Sync feedback state
enum class SyncState {
    IDLE,
    SYNCING,
    SUCCESS,
    ERROR,
}

// The entries of the home screen, in display order (see [homeEntries]).
enum class HomeEntry {
    REGISTERED,
    RIDES,
    ROUTES,
}

/**
 * « My next rides » always comes first; Rides and Routes follow, Routes first when there is no ride
 * to show.
 */
fun homeEntries(response: RoutesResponse): List<HomeEntry> =
    if (response.rides.isEmpty()) {
        listOf(HomeEntry.REGISTERED, HomeEntry.ROUTES, HomeEntry.RIDES)
    } else {
        listOf(HomeEntry.REGISTERED, HomeEntry.RIDES, HomeEntry.ROUTES)
    }

// Navigation state machine
sealed class NavState {
    object Home : NavState()

    // The groups the user is registered in: selecting one syncs its route directly.
    data class RegisteredGroupList(val groups: List<DeviceRegisteredGroup>) : NavState()

    data class RideList(val rides: List<DeviceRide>) : NavState()

    data class RideEntries(val ride: DeviceRide) : NavState()

    data class RouteList(val routes: List<DeviceRoute>) : NavState()

    data class RouteDetail(
        val teamSlug: String,
        val routeSlug: String,
        val routeName: String,
        val distance: Float,
        val elevationGain: Float,
        // Start of the ride entry's group (null for a standalone route).
        val startDateTime: String? = null,
    ) : NavState()
}

/** Main activity for browsing and syncing routes. */
class MainActivity : ComponentActivity() {

    companion object {
        private const val BASE_URL = "https://www.pedalons.fr"
    }

    private var apiClient: PedalonsApiClient? = null
    private lateinit var authManager: AuthManager
    private lateinit var karooSystem: KarooSystemService
    private var userProfileConsumerId: String? = null

    // Activity Result API launchers (registered in onCreate)
    private val authLauncher: ActivityResultLauncher<Intent> =
        registerForActivityResult(ActivityResultContracts.StartActivityForResult()) { result ->
            if (result.resultCode == AuthActivity.RESULT_SUCCESS) {
                onAuthSuccess?.invoke()
            }
        }

    // Hammerhead is mandatory (docs/LEDGER_*.md API-63): only a connected account goes on to the
    // routes. Leaving the step without one either signs the Karoo out or closes the app.
    private val gpsConnectLauncher: ActivityResultLauncher<Intent> =
        registerForActivityResult(ActivityResultContracts.StartActivityForResult()) { result ->
            when (result.resultCode) {
                GpsConnectActivity.RESULT_SUCCESS -> onGpsConnectComplete?.invoke()
                GpsConnectActivity.RESULT_LOGOUT -> onGpsConnectLogout?.invoke()
                else -> finish()
            }
        }

    // Navigation state accessible from key events
    internal var onNavigationChanged: ((Int) -> Unit)? = null
    internal var onSelectRequested: (() -> Unit)? = null
    internal var onBackRequested: (() -> Unit)? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        authManager = AuthManager(this)
        karooSystem = KarooSystemService(applicationContext)

        setContent {
            var isConnected by remember { mutableStateOf(false) }
            var userProfile by remember { mutableStateOf<UserProfile?>(null) }

            LaunchedEffect(Unit) {
                karooSystem.connect {}
                // Poll for connection status
                while (!karooSystem.connected) {
                    delay(100)
                }
                apiClient = PedalonsApiClient(BASE_URL, karooSystem)

                // Listen for user profile updates to get preferred units
                userProfileConsumerId =
                    karooSystem.addConsumer<UserProfile> { profile ->
                        userProfile = profile
                    }

                isConnected = true
            }

            PedalonsKarooTheme {
                if (isConnected && apiClient != null) {
                    MainScreen(
                        apiClient = apiClient!!,
                        authManager = authManager,
                        userProfile = userProfile,
                        activity = this@MainActivity,
                        onConnect = { startAuthFlow() },
                    )
                } else {
                    // Show skeleton screen while connecting to Karoo System Service
                    SkeletonScreen(onBack = { finish() })
                }
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        apiClient?.close()
        if (::karooSystem.isInitialized) {
            userProfileConsumerId?.let { karooSystem.removeConsumer(it) }
            karooSystem.disconnect()
        }
    }

    private fun startAuthFlow() {
        val intent =
            Intent(this, AuthActivity::class.java).apply {
                putExtra(AuthActivity.EXTRA_BASE_URL, BASE_URL)
            }
        authLauncher.launch(intent)
    }

    internal fun startGpsConnectFlow() {
        val intent =
            Intent(this, GpsConnectActivity::class.java).apply {
                putExtra(GpsConnectActivity.EXTRA_BASE_URL, BASE_URL)
            }
        gpsConnectLauncher.launch(intent)
    }

    // Callbacks for activity results
    internal var onAuthSuccess: (() -> Unit)? = null
    internal var onGpsConnectComplete: (() -> Unit)? = null
    internal var onGpsConnectLogout: (() -> Unit)? = null

    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        when (keyCode) {
            KeyEvent.KEYCODE_NAVIGATE_NEXT -> {
                onNavigationChanged?.invoke(1) // delta +1
                return true
            }
            KeyEvent.KEYCODE_NAVIGATE_PREVIOUS -> {
                onNavigationChanged?.invoke(-1) // delta -1
                return true
            }
            KeyEvent.KEYCODE_NAVIGATE_IN -> {
                onSelectRequested?.invoke()
                return true
            }
            KeyEvent.KEYCODE_BACK -> {
                onBackRequested?.invoke()
                return true
            }
        }
        return super.onKeyDown(keyCode, event)
    }
}

@Composable
private fun MainScreen(
    apiClient: PedalonsApiClient,
    authManager: AuthManager,
    userProfile: UserProfile?,
    activity: MainActivity,
    onConnect: () -> Unit,
) {
    // Collect auth state
    val isAuthenticated by authManager.isAuthenticated.collectAsState(initial = null)
    var routesResponse by remember { mutableStateOf<RoutesResponse?>(null) }
    var isLoading by remember { mutableStateOf(true) }
    var error by remember { mutableStateOf<String?>(null) }
    var syncState by remember { mutableStateOf(SyncState.IDLE) }
    // Which row of the registered groups list [syncState] is about (null elsewhere).
    var syncTargetIndex by remember { mutableStateOf<Int?>(null) }
    // Bumped by every sync and every navigation: a sync only writes its result while it is still
    // the current one, so one left running behind a Back press cannot mark another row.
    var syncGeneration by remember { mutableStateOf(0) }
    // The routes ("teamSlug/routeSlug") synced from this Karoo since [routesResponse] was loaded:
    // the server's Hammerhead state in that response predates them, so the registered groups list
    // shows them as on the Karoo rather than the stale state (docs/LEDGER_*.md API-121). An
    // immutable set in a State, read through the delegate: the key callbacks registered once below
    // must see the current one. Reset with every new response, whose states then supersede it.
    var syncedRoutes by remember { mutableStateOf(emptySet<String>()) }
    LaunchedEffect(routesResponse) { syncedRoutes = emptySet() }

    // Navigation state
    var navState by remember { mutableStateOf<NavState>(NavState.Home) }
    var selectedIndex by remember { mutableStateOf(0) }
    val navStack = remember { mutableListOf<NavState>() }

    var gpsCheckPending by remember { mutableStateOf(false) }
    var gpsCheckDone by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()
    val listState = rememberLazyListState()

    // Navigation helpers
    val navigateTo: (NavState) -> Unit = { target ->
        navStack.add(navState)
        navState = target
        selectedIndex = 0
        syncState = SyncState.IDLE
        syncTargetIndex = null
        syncGeneration++
    }
    val navigateBack: () -> Unit = {
        if (navStack.isNotEmpty()) {
            navState = navStack.removeAt(navStack.lastIndex)
            selectedIndex = 0
            syncState = SyncState.IDLE
            syncTargetIndex = null
            syncGeneration++
        } else {
            activity.finish()
        }
    }

    // Item count for the current nav state. A function, not a value: the key callbacks below are
    // registered once and must read the current state, not the one of the first composition.
    fun currentItemCount(): Int =
        when (val state = navState) {
            is NavState.Home -> routesResponse?.let { homeEntries(it).size } ?: 0
            is NavState.RegisteredGroupList -> state.groups.size
            is NavState.RideList -> state.rides.size
            is NavState.RideEntries -> state.ride.entries.size
            is NavState.RouteList -> state.routes.size
            is NavState.RouteDetail -> 0
        }
    val itemCount = currentItemCount()

    // Syncs a route to Hammerhead, the one action shared by the route detail screen and the
    // registered groups list ([targetIndex] is the row of that list, null from the detail screen).
    val launchSync: (String, String, Int?) -> Unit = { teamSlug, routeSlug, targetIndex ->
        if (syncState != SyncState.SYNCING) {
            val generation = ++syncGeneration
            syncTargetIndex = targetIndex
            syncState = SyncState.SYNCING
            scope.launch {
                val result =
                    syncRoute(apiClient, authManager, teamSlug, routeSlug) {
                        activity.startGpsConnectFlow()
                    }
                // Keyed by route, not by row: recorded even when the rider has moved on, since
                // the route did reach the Karoo whichever screen is shown now.
                if (result == SyncState.SUCCESS) {
                    syncedRoutes = syncedRoutes + routeKey(teamSlug, routeSlug)
                }
                if (generation == syncGeneration) {
                    syncState = result
                }
            }
        }
    }

    val openHomeEntry: (RoutesResponse, HomeEntry) -> Unit = { response, entry ->
        when (entry) {
            HomeEntry.REGISTERED ->
                navigateTo(NavState.RegisteredGroupList(response.registeredGroups))
            HomeEntry.RIDES -> navigateTo(NavState.RideList(response.rides))
            HomeEntry.ROUTES -> navigateTo(NavState.RouteList(response.routes))
        }
    }

    // Register navigation callbacks with Activity
    LaunchedEffect(Unit) {
        activity.onNavigationChanged = { delta ->
            val newIndex =
                (selectedIndex + delta).coerceIn(0, (currentItemCount() - 1).coerceAtLeast(0))
            selectedIndex = newIndex
        }
        activity.onSelectRequested = {
            when (val state = navState) {
                is NavState.Home -> {
                    val response = routesResponse
                    if (response != null) {
                        homeEntries(response).getOrNull(selectedIndex)?.let {
                            openHomeEntry(response, it)
                        }
                    }
                }
                is NavState.RegisteredGroupList -> {
                    state.groups.getOrNull(selectedIndex)?.let { group ->
                        launchSync(group.teamSlug, group.routeSlug, selectedIndex)
                    }
                }
                is NavState.RideList -> {
                    if (selectedIndex in state.rides.indices) {
                        val ride = state.rides[selectedIndex]
                        if (ride.entries.size == 1) {
                            // Bonus: skip entries screen if single entry
                            val entry = ride.entries[0]
                            navigateTo(
                                NavState.RouteDetail(
                                    teamSlug = ride.teamSlug,
                                    routeSlug = entry.routeSlug,
                                    routeName = entry.routeName,
                                    distance = entry.distance,
                                    elevationGain = entry.elevationGain,
                                    startDateTime = ride.startOf(entry),
                                ),
                            )
                        } else {
                            navigateTo(NavState.RideEntries(ride))
                        }
                    }
                }
                is NavState.RideEntries -> {
                    if (selectedIndex in state.ride.entries.indices) {
                        val entry = state.ride.entries[selectedIndex]
                        navigateTo(
                            NavState.RouteDetail(
                                teamSlug = state.ride.teamSlug,
                                routeSlug = entry.routeSlug,
                                routeName = entry.routeName,
                                distance = entry.distance,
                                elevationGain = entry.elevationGain,
                                startDateTime = state.ride.startOf(entry),
                            ),
                        )
                    }
                }
                is NavState.RouteList -> {
                    if (selectedIndex in state.routes.indices) {
                        val route = state.routes[selectedIndex]
                        navigateTo(
                            NavState.RouteDetail(
                                teamSlug = route.teamSlug,
                                routeSlug = route.routeSlug,
                                routeName = route.routeName,
                                distance = route.distance,
                                elevationGain = route.elevationGain,
                            ),
                        )
                    }
                }
                is NavState.RouteDetail -> {
                    launchSync(state.teamSlug, state.routeSlug, null)
                }
            }
        }
        activity.onBackRequested = {
            navigateBack()
        }
        activity.onAuthSuccess = {
            gpsCheckPending = true
        }
        activity.onGpsConnectComplete = {
            gpsCheckDone = true
            gpsCheckPending = false
        }
        activity.onGpsConnectLogout = {
            gpsCheckDone = false
            gpsCheckPending = false
            scope.launch {
                authManager.clearTokens()
                routesResponse = null
                navState = NavState.Home
                navStack.clear()
            }
        }
    }

    // Update item count for key navigation when navState changes
    LaunchedEffect(navState) {
        selectedIndex = 0
    }

    // Auto-scroll when selection changes
    LaunchedEffect(selectedIndex) {
        if (itemCount > 0 && selectedIndex in 0 until itemCount) {
            listState.animateScrollToItem(selectedIndex)
        }
    }

    // Check GPS connection after fresh auth
    LaunchedEffect(gpsCheckPending, isAuthenticated) {
        if (gpsCheckPending && isAuthenticated == true) {
            isLoading = true
            checkAndPromptGpsConnection(apiClient, authManager, activity) { shouldLoadRoutes ->
                if (shouldLoadRoutes) {
                    gpsCheckDone = true
                    gpsCheckPending = false
                }
            }
        }
    }

    // Load routes when authenticated and GPS check is done
    LaunchedEffect(isAuthenticated, gpsCheckDone, gpsCheckPending) {
        if (isAuthenticated == null) return@LaunchedEffect

        if (isAuthenticated == true) {
            if (gpsCheckPending) return@LaunchedEffect

            if (!gpsCheckDone) {
                isLoading = true
                checkAndPromptGpsConnection(apiClient, authManager, activity) { shouldLoadRoutes ->
                    if (shouldLoadRoutes) {
                        gpsCheckDone = true
                        scope.launch {
                            loadRoutesResponse(apiClient, authManager) { result ->
                                result
                                    .onSuccess {
                                        routesResponse = it
                                        isLoading = false
                                        error = null
                                    }
                                    .onFailure { e ->
                                        if (e is UnauthorizedException) {
                                            scope.launch { authManager.clearTokens() }
                                        } else {
                                            error = e.message
                                        }
                                        isLoading = false
                                    }
                            }
                        }
                    }
                }
                return@LaunchedEffect
            }

            isLoading = true
            loadRoutesResponse(apiClient, authManager) { result ->
                result
                    .onSuccess {
                        routesResponse = it
                        isLoading = false
                        error = null
                    }
                    .onFailure { e ->
                        if (e is UnauthorizedException) {
                            scope.launch { authManager.clearTokens() }
                        } else {
                            error = e.message
                        }
                        isLoading = false
                    }
            }
        } else {
            isLoading = false
            routesResponse = null
            error = null
            gpsCheckDone = false
        }
    }

    Surface(
        modifier = Modifier.fillMaxSize(),
        color = MaterialTheme.colorScheme.background,
    ) {
        when {
            isAuthenticated == false -> {
                ConnectScreen(onConnect = onConnect, onBack = { activity.finish() })
            }
            error != null && !isLoading -> {
                ErrorScreen(
                    onRetry = {
                        isLoading = true
                        error = null
                        scope.launch {
                            loadRoutesResponse(apiClient, authManager) { result ->
                                result
                                    .onSuccess {
                                        routesResponse = it
                                        isLoading = false
                                    }
                                    .onFailure { e ->
                                        error = e.message
                                        isLoading = false
                                    }
                            }
                        }
                    },
                    onBack = { activity.finish() },
                )
            }
            isLoading || isAuthenticated == null -> {
                SkeletonScreen(onBack = { activity.finish() })
            }
            else -> {
                val response = routesResponse
                if (response == null) {
                    EmptyScreen(onBack = { activity.finish() })
                } else {
                    NavigationContent(
                        navState = navState,
                        selectedIndex = selectedIndex,
                        listState = listState,
                        response = response,
                        userProfile = userProfile,
                        syncState = syncState,
                        syncTargetIndex = syncTargetIndex,
                        syncedRoutes = syncedRoutes,
                        onNavigateTo = navigateTo,
                        onOpenHomeEntry = { openHomeEntry(response, it) },
                        onBack = navigateBack,
                        onSync = launchSync,
                        onRefresh = {
                            isLoading = true
                            scope.launch {
                                loadRoutesResponse(apiClient, authManager) { result ->
                                    result
                                        .onSuccess {
                                            routesResponse = it
                                            navState = NavState.Home
                                            navStack.clear()
                                            isLoading = false
                                            error = null
                                        }
                                        .onFailure { e ->
                                            error = e.message
                                            isLoading = false
                                        }
                                }
                            }
                        },
                        onDisconnect = {
                            scope.launch {
                                authManager.clearTokens()
                                routesResponse = null
                                navState = NavState.Home
                                navStack.clear()
                            }
                        },
                    )
                }
            }
        }
    }
}

@Composable
private fun NavigationContent(
    navState: NavState,
    selectedIndex: Int,
    listState: LazyListState,
    response: RoutesResponse,
    userProfile: UserProfile?,
    syncState: SyncState,
    syncTargetIndex: Int?,
    syncedRoutes: Set<String>,
    onNavigateTo: (NavState) -> Unit,
    onOpenHomeEntry: (HomeEntry) -> Unit,
    onBack: () -> Unit,
    onSync: (String, String, Int?) -> Unit,
    onRefresh: () -> Unit,
    onDisconnect: () -> Unit,
) {
    when (navState) {
        is NavState.Home -> {
            HomeScreen(
                response = response,
                selectedIndex = selectedIndex,
                listState = listState,
                onSelect = onOpenHomeEntry,
                onBack = onBack,
                onRefresh = onRefresh,
                onDisconnect = onDisconnect,
            )
        }
        is NavState.RegisteredGroupList -> {
            RegisteredGroupListScreen(
                groups = navState.groups,
                userProfile = userProfile,
                selectedIndex = selectedIndex,
                listState = listState,
                syncState = syncState,
                syncTargetIndex = syncTargetIndex,
                syncedRoutes = syncedRoutes,
                onSelectGroup = { index, group ->
                    onSync(group.teamSlug, group.routeSlug, index)
                },
                onBack = onBack,
            )
        }
        is NavState.RideList -> {
            RideListScreen(
                rides = navState.rides,
                selectedIndex = selectedIndex,
                listState = listState,
                onSelectRide = { ride ->
                    if (ride.entries.size == 1) {
                        val entry = ride.entries[0]
                        onNavigateTo(
                            NavState.RouteDetail(
                                teamSlug = ride.teamSlug,
                                routeSlug = entry.routeSlug,
                                routeName = entry.routeName,
                                distance = entry.distance,
                                elevationGain = entry.elevationGain,
                                startDateTime = ride.startOf(entry),
                            ),
                        )
                    } else {
                        onNavigateTo(NavState.RideEntries(ride))
                    }
                },
                onBack = onBack,
            )
        }
        is NavState.RideEntries -> {
            RideEntriesScreen(
                ride = navState.ride,
                userProfile = userProfile,
                selectedIndex = selectedIndex,
                listState = listState,
                onSelectEntry = { entry ->
                    onNavigateTo(
                        NavState.RouteDetail(
                            teamSlug = navState.ride.teamSlug,
                            routeSlug = entry.routeSlug,
                            routeName = entry.routeName,
                            distance = entry.distance,
                            elevationGain = entry.elevationGain,
                            startDateTime = navState.ride.startOf(entry),
                        ),
                    )
                },
                onBack = onBack,
            )
        }
        is NavState.RouteList -> {
            StandaloneRouteListScreen(
                routes = navState.routes,
                userProfile = userProfile,
                selectedIndex = selectedIndex,
                listState = listState,
                onSelectRoute = { route ->
                    onNavigateTo(
                        NavState.RouteDetail(
                            teamSlug = route.teamSlug,
                            routeSlug = route.routeSlug,
                            routeName = route.routeName,
                            distance = route.distance,
                            elevationGain = route.elevationGain,
                        ),
                    )
                },
                onBack = onBack,
            )
        }
        is NavState.RouteDetail -> {
            RouteDetailScreen(
                detail = navState,
                userProfile = userProfile,
                syncState = syncState,
                onSync = { onSync(navState.teamSlug, navState.routeSlug, null) },
                onBack = onBack,
            )
        }
    }
}

// === Home Screen ===

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun HomeScreen(
    response: RoutesResponse,
    selectedIndex: Int,
    listState: LazyListState,
    onSelect: (HomeEntry) -> Unit,
    onBack: () -> Unit,
    onRefresh: () -> Unit,
    onDisconnect: () -> Unit,
) {
    var showMenu by remember { mutableStateOf(false) }

    ScreenWithOverlay(onBack = onBack) {
        Column(modifier = Modifier.fillMaxSize()) {
            TopAppBar(
                title = {
                    Text(
                        text = stringResource(R.string.app_name),
                        fontWeight = FontWeight.Bold,
                    )
                },
                actions = {
                    IconButton(onClick = onRefresh) {
                        Icon(
                            imageVector = Icons.Filled.Refresh,
                            contentDescription = stringResource(R.string.loading),
                        )
                    }
                    Box {
                        IconButton(onClick = { showMenu = true }) {
                            Icon(
                                imageVector = Icons.Filled.MoreVert,
                                contentDescription = stringResource(R.string.settings),
                            )
                        }
                        DropdownMenu(
                            expanded = showMenu,
                            onDismissRequest = { showMenu = false },
                        ) {
                            DropdownMenuItem(
                                text = { Text(stringResource(R.string.disconnect)) },
                                onClick = {
                                    showMenu = false
                                    onDisconnect()
                                },
                            )
                        }
                    }
                },
                colors =
                    TopAppBarDefaults.topAppBarColors(
                        containerColor = MaterialTheme.colorScheme.surface,
                    ),
            )

            LazyColumn(
                state = listState,
                modifier = Modifier.fillMaxSize(),
                contentPadding = PaddingValues(vertical = 8.dp),
            ) {
                itemsIndexed(homeEntries(response), key = { _, entry -> entry.name }) { index, entry
                    ->
                    val count =
                        when (entry) {
                            HomeEntry.REGISTERED -> response.registeredGroups.size
                            HomeEntry.RIDES -> response.rides.size
                            HomeEntry.ROUTES -> response.routes.size
                        }
                    HomeMenuItem(
                        title =
                            stringResource(
                                when (entry) {
                                    HomeEntry.REGISTERED -> R.string.nav_registered
                                    HomeEntry.RIDES -> R.string.nav_rides
                                    HomeEntry.ROUTES -> R.string.nav_routes
                                },
                            ),
                        subtitle =
                            stringResource(
                                when (entry) {
                                    HomeEntry.REGISTERED -> R.string.registered_count
                                    HomeEntry.RIDES -> R.string.rides_count
                                    HomeEntry.ROUTES -> R.string.routes_count
                                },
                                count,
                            ),
                        isSelected = selectedIndex == index,
                        isEmpty = count == 0,
                        emptyText =
                            stringResource(
                                when (entry) {
                                    HomeEntry.REGISTERED -> R.string.no_registered
                                    HomeEntry.RIDES -> R.string.no_rides
                                    HomeEntry.ROUTES -> R.string.no_routes
                                },
                            ),
                        onClick = { onSelect(entry) },
                    )
                }
            }
        }
    }
}

@Composable
private fun HomeMenuItem(
    title: String,
    subtitle: String,
    isSelected: Boolean,
    isEmpty: Boolean,
    emptyText: String,
    onClick: () -> Unit,
) {
    val borderModifier =
        if (isSelected) {
            Modifier.border(
                width = 2.dp,
                color = MaterialTheme.colorScheme.primary,
                shape = MaterialTheme.shapes.medium,
            )
        } else {
            Modifier
        }

    Surface(
        modifier =
            Modifier.fillMaxWidth()
                .padding(horizontal = 8.dp, vertical = 4.dp)
                .then(borderModifier)
                .focusProperties { canFocus = false }
                .clickable(onClick = onClick),
        color =
            if (isSelected) MaterialTheme.colorScheme.primaryContainer
            else MaterialTheme.colorScheme.surfaceVariant,
        shape = MaterialTheme.shapes.medium,
    ) {
        Row(
            modifier = Modifier.fillMaxWidth().padding(16.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = title,
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold,
                )
                Text(
                    text = if (isEmpty) emptyText else subtitle,
                    style = MaterialTheme.typography.bodySmall,
                    color =
                        if (isEmpty) MaterialTheme.colorScheme.onSurfaceVariant
                        else MaterialTheme.colorScheme.primary,
                )
            }
            Text(
                text = stringResource(R.string.nav_arrow),
                style = MaterialTheme.typography.headlineMedium,
                color = MaterialTheme.colorScheme.primary,
            )
        }
    }
}

// === Registered Group List Screen ===

/**
 * Where a registered group's route stands at Hammerhead, as sent by the server. Nothing when the
 * state is unknown (older server) or Hammerhead does not hold the route.
 */
@Composable
private fun HammerheadSyncStatusText(state: RouteSyncState?) {
    val (textRes, color) =
        when (state) {
            RouteSyncState.SENT -> R.string.route_on_karoo to MaterialTheme.colorScheme.primary
            RouteSyncState.OUTDATED ->
                R.string.route_outdated_on_karoo to MaterialTheme.colorScheme.onSurfaceVariant
            RouteSyncState.PENDING ->
                R.string.route_update_pending to MaterialTheme.colorScheme.onSurfaceVariant
            RouteSyncState.FAILING ->
                R.string.route_sending_failed to MaterialTheme.colorScheme.error
            RouteSyncState.RECONNECT_REQUIRED ->
                R.string.route_reconnect_hammerhead to MaterialTheme.colorScheme.error
            null -> return
        }
    Text(
        text = stringResource(textRes),
        style = MaterialTheme.typography.bodySmall,
        color = color,
    )
}

/**
 * The groups the user is registered in. A row is the action itself: selecting it syncs the group's
 * route to Hammerhead, its status shown on the row, without going through the route detail screen.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun RegisteredGroupListScreen(
    groups: List<DeviceRegisteredGroup>,
    userProfile: UserProfile?,
    selectedIndex: Int,
    listState: LazyListState,
    syncState: SyncState,
    syncTargetIndex: Int?,
    syncedRoutes: Set<String>,
    onSelectGroup: (Int, DeviceRegisteredGroup) -> Unit,
    onBack: () -> Unit,
) {
    val context = LocalContext.current

    ScreenWithOverlay(onBack = onBack) {
        Column(modifier = Modifier.fillMaxSize()) {
            TopAppBar(
                title = {
                    Text(
                        text = stringResource(R.string.nav_registered),
                        fontWeight = FontWeight.Bold,
                    )
                },
                colors =
                    TopAppBarDefaults.topAppBarColors(
                        containerColor = MaterialTheme.colorScheme.surface,
                    ),
            )

            if (groups.isEmpty()) {
                Box(
                    modifier = Modifier.fillMaxSize(),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        text = stringResource(R.string.no_registered),
                        style = MaterialTheme.typography.bodyLarge,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            } else {
                LazyColumn(
                    state = listState,
                    modifier = Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(vertical = 8.dp),
                ) {
                    itemsIndexed(
                        groups,
                        key = { index, group ->
                            "$index-${group.teamSlug}/${group.rideSlug}/${group.groupName}"
                        },
                    ) { index, group ->
                        val isSelected = index == selectedIndex
                        val rowSyncState = if (index == syncTargetIndex) syncState else null
                        val borderModifier =
                            if (isSelected) {
                                Modifier.border(
                                    width = 2.dp,
                                    color = MaterialTheme.colorScheme.primary,
                                    shape = MaterialTheme.shapes.medium,
                                )
                            } else {
                                Modifier
                            }

                        Surface(
                            modifier =
                                Modifier.fillMaxWidth()
                                    .padding(horizontal = 8.dp, vertical = 4.dp)
                                    .then(borderModifier)
                                    .focusProperties { canFocus = false }
                                    .clickable { onSelectGroup(index, group) },
                            color =
                                if (isSelected) MaterialTheme.colorScheme.primaryContainer
                                else MaterialTheme.colorScheme.surfaceVariant,
                            shape = MaterialTheme.shapes.medium,
                        ) {
                            Row(
                                modifier = Modifier.fillMaxWidth().padding(10.dp),
                                verticalAlignment = Alignment.CenterVertically,
                            ) {
                                Column(modifier = Modifier.weight(1f)) {
                                    Text(
                                        text = group.groupName,
                                        style = MaterialTheme.typography.bodyMedium,
                                        fontWeight = FontWeight.Medium,
                                        maxLines = 1,
                                        overflow = TextOverflow.Ellipsis,
                                    )
                                    Text(
                                        text = group.rideName,
                                        style = MaterialTheme.typography.bodySmall,
                                        maxLines = 1,
                                        overflow = TextOverflow.Ellipsis,
                                    )
                                    val startStr = formatDateTime(context, group.startDateTime)
                                    if (startStr != null) {
                                        Text(
                                            text = startStr,
                                            style = MaterialTheme.typography.bodySmall,
                                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                                        )
                                    }
                                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                        Text(
                                            text =
                                                formatDistance(
                                                    context,
                                                    group.distance,
                                                    userProfile,
                                                ),
                                            style = MaterialTheme.typography.bodySmall,
                                            color = MaterialTheme.colorScheme.primary,
                                        )
                                        Text(
                                            text =
                                                formatElevation(
                                                    context,
                                                    group.elevationGain,
                                                    userProfile,
                                                ),
                                            style = MaterialTheme.typography.bodySmall,
                                            color = MaterialTheme.colorScheme.secondary,
                                        )
                                    }
                                    when (rowSyncState) {
                                        SyncState.SYNCING ->
                                            Text(
                                                text = stringResource(R.string.route_syncing),
                                                style = MaterialTheme.typography.bodySmall,
                                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                                            )
                                        SyncState.SUCCESS ->
                                            Text(
                                                text = stringResource(R.string.route_synced),
                                                style = MaterialTheme.typography.bodySmall,
                                                color = MaterialTheme.colorScheme.primary,
                                                fontWeight = FontWeight.Bold,
                                            )
                                        SyncState.ERROR ->
                                            Text(
                                                text = stringResource(R.string.route_sync_error),
                                                style = MaterialTheme.typography.bodySmall,
                                                color = MaterialTheme.colorScheme.error,
                                            )
                                        // No sync of this row in progress or just done: where the
                                        // route already stands at Hammerhead, so the rider does
                                        // not send it twice (docs/LEDGER_*.md API-121). Syncing
                                        // stays available — it updates without a duplicate.
                                        // A route synced from here since the list was loaded is
                                        // on the Karoo, whatever the older server state says.
                                        SyncState.IDLE,
                                        null ->
                                            HammerheadSyncStatusText(
                                                if (
                                                    routeKey(group.teamSlug, group.routeSlug) in
                                                        syncedRoutes
                                                ) {
                                                    RouteSyncState.SENT
                                                } else {
                                                    group.hammerheadSyncState()
                                                },
                                            )
                                    }
                                }
                                when (rowSyncState) {
                                    SyncState.SYNCING ->
                                        CircularProgressIndicator(
                                            modifier = Modifier.size(28.dp),
                                            strokeWidth = 3.dp,
                                            color = MaterialTheme.colorScheme.primary,
                                        )
                                    SyncState.SUCCESS ->
                                        Text(
                                            text = stringResource(R.string.success_checkmark),
                                            style = MaterialTheme.typography.headlineMedium,
                                            color = MaterialTheme.colorScheme.primary,
                                        )
                                    else ->
                                        Image(
                                            painter = painterResource(id = R.drawable.sync),
                                            contentDescription = stringResource(R.string.sync),
                                            modifier = Modifier.size(32.dp),
                                        )
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

// === Ride List Screen ===

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun RideListScreen(
    rides: List<DeviceRide>,
    selectedIndex: Int,
    listState: LazyListState,
    onSelectRide: (DeviceRide) -> Unit,
    onBack: () -> Unit,
) {
    val context = LocalContext.current

    ScreenWithOverlay(onBack = onBack) {
        Column(modifier = Modifier.fillMaxSize()) {
            TopAppBar(
                title = {
                    Text(
                        text = stringResource(R.string.nav_rides),
                        fontWeight = FontWeight.Bold,
                    )
                },
                colors =
                    TopAppBarDefaults.topAppBarColors(
                        containerColor = MaterialTheme.colorScheme.surface,
                    ),
            )

            if (rides.isEmpty()) {
                Box(
                    modifier = Modifier.fillMaxSize(),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        text = stringResource(R.string.no_rides),
                        style = MaterialTheme.typography.bodyLarge,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            } else {
                LazyColumn(
                    state = listState,
                    modifier = Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(vertical = 8.dp),
                ) {
                    itemsIndexed(rides, key = { _, ride -> "${ride.teamSlug}/${ride.rideSlug}" }) {
                        index,
                        ride ->
                        val isSelected = index == selectedIndex
                        val borderModifier =
                            if (isSelected) {
                                Modifier.border(
                                    width = 2.dp,
                                    color = MaterialTheme.colorScheme.primary,
                                    shape = MaterialTheme.shapes.medium,
                                )
                            } else {
                                Modifier
                            }

                        Surface(
                            modifier =
                                Modifier.fillMaxWidth()
                                    .padding(horizontal = 8.dp, vertical = 4.dp)
                                    .then(borderModifier)
                                    .focusProperties { canFocus = false }
                                    .clickable { onSelectRide(ride) },
                            color =
                                if (isSelected) MaterialTheme.colorScheme.primaryContainer
                                else MaterialTheme.colorScheme.surfaceVariant,
                            shape = MaterialTheme.shapes.medium,
                        ) {
                            Row(
                                modifier = Modifier.fillMaxWidth().padding(10.dp),
                                verticalAlignment = Alignment.CenterVertically,
                            ) {
                                Column(modifier = Modifier.weight(1f)) {
                                    Text(
                                        text = ride.rideName,
                                        style = MaterialTheme.typography.bodyMedium,
                                        fontWeight = FontWeight.Medium,
                                        maxLines = 1,
                                        overflow = TextOverflow.Ellipsis,
                                    )
                                    val dateStr = formatDateTime(context, ride.startDateTime)
                                    if (dateStr != null) {
                                        Text(
                                            text = dateStr,
                                            style = MaterialTheme.typography.bodySmall,
                                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                                        )
                                    }
                                    Text(
                                        text =
                                            stringResource(
                                                R.string.routes_count,
                                                ride.entries.size,
                                            ),
                                        style = MaterialTheme.typography.bodySmall,
                                        color = MaterialTheme.colorScheme.primary,
                                    )
                                }
                                Text(
                                    text = stringResource(R.string.nav_arrow),
                                    style = MaterialTheme.typography.headlineMedium,
                                    color = MaterialTheme.colorScheme.primary,
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

// === Ride Entries Screen ===

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun RideEntriesScreen(
    ride: DeviceRide,
    userProfile: UserProfile?,
    selectedIndex: Int,
    listState: LazyListState,
    onSelectEntry: (DeviceRideEntry) -> Unit,
    onBack: () -> Unit,
) {
    val context = LocalContext.current

    ScreenWithOverlay(onBack = onBack) {
        Column(modifier = Modifier.fillMaxSize()) {
            TopAppBar(
                title = {
                    Text(
                        text = ride.rideName,
                        fontWeight = FontWeight.Bold,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                },
                colors =
                    TopAppBarDefaults.topAppBarColors(
                        containerColor = MaterialTheme.colorScheme.surface,
                    ),
            )

            LazyColumn(
                state = listState,
                modifier = Modifier.fillMaxSize(),
                contentPadding = PaddingValues(vertical = 8.dp),
            ) {
                itemsIndexed(ride.entries, key = { index, entry -> "$index-${entry.routeSlug}" }) {
                    index,
                    entry ->
                    val isSelected = index == selectedIndex
                    val borderModifier =
                        if (isSelected) {
                            Modifier.border(
                                width = 2.dp,
                                color = MaterialTheme.colorScheme.primary,
                                shape = MaterialTheme.shapes.medium,
                            )
                        } else {
                            Modifier
                        }

                    Surface(
                        modifier =
                            Modifier.fillMaxWidth()
                                .padding(horizontal = 8.dp, vertical = 4.dp)
                                .then(borderModifier)
                                .focusProperties { canFocus = false }
                                .clickable { onSelectEntry(entry) },
                        color =
                            if (isSelected) MaterialTheme.colorScheme.primaryContainer
                            else MaterialTheme.colorScheme.surfaceVariant,
                        shape = MaterialTheme.shapes.medium,
                    ) {
                        Row(
                            modifier = Modifier.fillMaxWidth().padding(10.dp),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Column(modifier = Modifier.weight(1f)) {
                                Text(
                                    text = entry.groupName ?: entry.routeName,
                                    style = MaterialTheme.typography.bodyMedium,
                                    fontWeight = FontWeight.Medium,
                                    maxLines = 1,
                                    overflow = TextOverflow.Ellipsis,
                                )
                                val startStr = formatDateTime(context, ride.startOf(entry))
                                if (startStr != null) {
                                    Text(
                                        text = startStr,
                                        style = MaterialTheme.typography.bodySmall,
                                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                                    )
                                }
                                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                    Text(
                                        text = formatDistance(context, entry.distance, userProfile),
                                        style = MaterialTheme.typography.bodySmall,
                                        color = MaterialTheme.colorScheme.primary,
                                    )
                                    Text(
                                        text =
                                            formatElevation(
                                                context,
                                                entry.elevationGain,
                                                userProfile,
                                            ),
                                        style = MaterialTheme.typography.bodySmall,
                                        color = MaterialTheme.colorScheme.secondary,
                                    )
                                }
                            }
                            Text(
                                text = stringResource(R.string.nav_arrow),
                                style = MaterialTheme.typography.headlineMedium,
                                color = MaterialTheme.colorScheme.primary,
                            )
                        }
                    }
                }
            }
        }
    }
}

// === Standalone Route List Screen ===

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun StandaloneRouteListScreen(
    routes: List<DeviceRoute>,
    userProfile: UserProfile?,
    selectedIndex: Int,
    listState: LazyListState,
    onSelectRoute: (DeviceRoute) -> Unit,
    onBack: () -> Unit,
) {
    val context = LocalContext.current

    ScreenWithOverlay(onBack = onBack) {
        Column(modifier = Modifier.fillMaxSize()) {
            TopAppBar(
                title = {
                    Text(
                        text = stringResource(R.string.nav_routes),
                        fontWeight = FontWeight.Bold,
                    )
                },
                colors =
                    TopAppBarDefaults.topAppBarColors(
                        containerColor = MaterialTheme.colorScheme.surface,
                    ),
            )

            if (routes.isEmpty()) {
                Box(
                    modifier = Modifier.fillMaxSize(),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        text = stringResource(R.string.no_routes),
                        style = MaterialTheme.typography.bodyLarge,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
            } else {
                LazyColumn(
                    state = listState,
                    modifier = Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(vertical = 8.dp),
                ) {
                    itemsIndexed(
                        routes,
                        key = { _, route -> "${route.teamSlug}/${route.routeSlug}" },
                    ) { index, route ->
                        val isSelected = index == selectedIndex
                        val borderModifier =
                            if (isSelected) {
                                Modifier.border(
                                    width = 2.dp,
                                    color = MaterialTheme.colorScheme.primary,
                                    shape = MaterialTheme.shapes.medium,
                                )
                            } else {
                                Modifier
                            }

                        Surface(
                            modifier =
                                Modifier.fillMaxWidth()
                                    .padding(horizontal = 8.dp, vertical = 4.dp)
                                    .then(borderModifier)
                                    .focusProperties { canFocus = false }
                                    .clickable { onSelectRoute(route) },
                            color =
                                if (isSelected) MaterialTheme.colorScheme.primaryContainer
                                else MaterialTheme.colorScheme.surfaceVariant,
                            shape = MaterialTheme.shapes.medium,
                        ) {
                            Row(
                                modifier = Modifier.fillMaxWidth().padding(10.dp),
                                verticalAlignment = Alignment.CenterVertically,
                            ) {
                                Column(modifier = Modifier.weight(1f)) {
                                    Text(
                                        text = route.routeName,
                                        style = MaterialTheme.typography.bodyMedium,
                                        fontWeight = FontWeight.Medium,
                                        maxLines = 1,
                                        overflow = TextOverflow.Ellipsis,
                                    )
                                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                        Text(
                                            text =
                                                formatDistance(
                                                    context,
                                                    route.distance,
                                                    userProfile,
                                                ),
                                            style = MaterialTheme.typography.bodySmall,
                                            color = MaterialTheme.colorScheme.primary,
                                        )
                                        Text(
                                            text =
                                                formatElevation(
                                                    context,
                                                    route.elevationGain,
                                                    userProfile,
                                                ),
                                            style = MaterialTheme.typography.bodySmall,
                                            color = MaterialTheme.colorScheme.secondary,
                                        )
                                    }
                                }
                                Text(
                                    text = stringResource(R.string.nav_arrow),
                                    style = MaterialTheme.typography.headlineMedium,
                                    color = MaterialTheme.colorScheme.primary,
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

// === Route Detail Screen ===

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun RouteDetailScreen(
    detail: NavState.RouteDetail,
    userProfile: UserProfile?,
    syncState: SyncState,
    onSync: () -> Unit,
    onBack: () -> Unit,
) {
    val context = LocalContext.current

    ScreenWithOverlay(
        onBack = onBack,
        showSync = true,
        onSync = onSync,
    ) {
        Column(modifier = Modifier.fillMaxSize()) {
            TopAppBar(
                title = {
                    Text(
                        text = detail.routeName,
                        fontWeight = FontWeight.Bold,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                },
                colors =
                    TopAppBarDefaults.topAppBarColors(
                        containerColor = MaterialTheme.colorScheme.surface,
                    ),
            )

            Box(
                modifier = Modifier.fillMaxSize(),
                contentAlignment = Alignment.Center,
            ) {
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    modifier = Modifier.padding(24.dp),
                ) {
                    Text(
                        text = detail.routeName,
                        style = MaterialTheme.typography.headlineSmall,
                        fontWeight = FontWeight.Bold,
                        maxLines = 2,
                        overflow = TextOverflow.Ellipsis,
                    )
                    val startStr = formatDateTime(context, detail.startDateTime)
                    if (startStr != null) {
                        Spacer(modifier = Modifier.height(8.dp))
                        Text(
                            text = startStr,
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }
                    Spacer(modifier = Modifier.height(16.dp))
                    Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                        Text(
                            text = formatDistance(context, detail.distance, userProfile),
                            style = MaterialTheme.typography.titleMedium,
                            color = MaterialTheme.colorScheme.primary,
                        )
                        Text(
                            text = formatElevation(context, detail.elevationGain, userProfile),
                            style = MaterialTheme.typography.titleMedium,
                            color = MaterialTheme.colorScheme.secondary,
                        )
                    }
                    Spacer(modifier = Modifier.height(24.dp))
                    when (syncState) {
                        SyncState.SYNCING -> {
                            CircularProgressIndicator(
                                modifier = Modifier.size(32.dp),
                                strokeWidth = 3.dp,
                                color = MaterialTheme.colorScheme.primary,
                            )
                        }
                        SyncState.SUCCESS -> {
                            Text(
                                text = stringResource(R.string.route_synced),
                                style = MaterialTheme.typography.bodyMedium,
                                color = MaterialTheme.colorScheme.primary,
                                fontWeight = FontWeight.Bold,
                            )
                        }
                        SyncState.ERROR -> {
                            Text(
                                text = stringResource(R.string.route_sync_error),
                                style = MaterialTheme.typography.bodyMedium,
                                color = MaterialTheme.colorScheme.error,
                            )
                        }
                        SyncState.IDLE -> {
                            Text(
                                text = stringResource(R.string.route_detail_sync),
                                style = MaterialTheme.typography.bodyMedium,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                        }
                    }
                }
            }
        }
    }
}

// === Shared Screens ===

@Composable
private fun ConnectScreen(onConnect: () -> Unit, onBack: () -> Unit) {
    ScreenWithOverlay(onBack = onBack) {
        Box(
            modifier = Modifier.fillMaxSize(),
            contentAlignment = Alignment.Center,
        ) {
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                modifier = Modifier.padding(24.dp),
            ) {
                Text(
                    text = stringResource(R.string.app_name),
                    style = MaterialTheme.typography.displaySmall,
                    fontWeight = FontWeight.Bold,
                )
                Spacer(modifier = Modifier.height(16.dp))
                Text(
                    text = stringResource(R.string.auth_connect_subtitle),
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                Spacer(modifier = Modifier.height(32.dp))
                Button(
                    onClick = onConnect,
                    modifier = Modifier.fillMaxWidth(0.7f),
                ) {
                    Text(
                        text = stringResource(R.string.auth_connect_button),
                        style = MaterialTheme.typography.labelLarge,
                    )
                }
            }
        }
    }
}

@Composable
private fun ErrorScreen(onRetry: () -> Unit, onBack: () -> Unit) {
    ScreenWithOverlay(onBack = onBack) {
        Box(
            modifier = Modifier.fillMaxSize(),
            contentAlignment = Alignment.Center,
        ) {
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                modifier = Modifier.padding(24.dp),
            ) {
                Text(
                    text = stringResource(R.string.error_unknown),
                    style = MaterialTheme.typography.headlineSmall,
                    color = MaterialTheme.colorScheme.error,
                )
                Spacer(modifier = Modifier.height(24.dp))
                Button(onClick = onRetry) {
                    Text(stringResource(R.string.loading))
                }
            }
        }
    }
}

@Composable
private fun EmptyScreen(onBack: () -> Unit) {
    ScreenWithOverlay(onBack = onBack) {
        Box(
            modifier = Modifier.fillMaxSize(),
            contentAlignment = Alignment.Center,
        ) {
            Text(
                text = stringResource(R.string.routes_empty),
                style = MaterialTheme.typography.bodyLarge,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}

@Composable
private fun BackButton(
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Image(
        painter = painterResource(id = R.drawable.back),
        contentDescription = stringResource(R.string.back),
        modifier =
            modifier.size(54.dp).focusProperties { canFocus = false }.clickable(onClick = onClick),
    )
}

@Composable
private fun SyncButton(
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Image(
        painter = painterResource(id = R.drawable.sync),
        contentDescription = stringResource(R.string.sync),
        modifier =
            modifier.size(54.dp).focusProperties { canFocus = false }.clickable(onClick = onClick),
    )
}

@Composable
private fun ScreenWithOverlay(
    onBack: () -> Unit,
    showSync: Boolean = false,
    onSync: (() -> Unit)? = null,
    content: @Composable BoxScope.() -> Unit,
) {
    Box(modifier = Modifier.fillMaxSize()) {
        content()

        BackButton(
            onClick = onBack,
            modifier = Modifier.align(Alignment.BottomStart).padding(bottom = 10.dp),
        )

        if (showSync && onSync != null) {
            SyncButton(
                onClick = onSync,
                modifier = Modifier.align(Alignment.BottomEnd).padding(bottom = 10.dp),
            )
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun SkeletonScreen(onBack: () -> Unit) {
    ScreenWithOverlay(onBack = onBack, showSync = false) {
        Column(modifier = Modifier.fillMaxSize()) {
            TopAppBar(
                title = {
                    Text(
                        text = stringResource(R.string.app_name),
                        fontWeight = FontWeight.Bold,
                    )
                },
                actions = {
                    CircularProgressIndicator(
                        modifier = Modifier.size(24.dp).padding(end = 12.dp),
                        strokeWidth = 2.dp,
                        color = MaterialTheme.colorScheme.primary,
                    )
                },
                colors =
                    TopAppBarDefaults.topAppBarColors(
                        containerColor = MaterialTheme.colorScheme.surface,
                    ),
            )

            LazyColumn(
                modifier = Modifier.fillMaxSize(),
                contentPadding = PaddingValues(vertical = 8.dp),
            ) {
                items(3) {
                    ItemSkeleton()
                }
            }
        }
    }
}

@Composable
private fun ItemSkeleton() {
    Surface(
        modifier = Modifier.fillMaxWidth().padding(horizontal = 8.dp, vertical = 4.dp),
        color = MaterialTheme.colorScheme.surfaceVariant,
        shape = MaterialTheme.shapes.medium,
    ) {
        Row(
            modifier = Modifier.fillMaxWidth().padding(10.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Box(
                    modifier =
                        Modifier.fillMaxWidth(0.7f)
                            .height(16.dp)
                            .background(
                                MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.2f),
                                MaterialTheme.shapes.small,
                            ),
                )
                Spacer(modifier = Modifier.height(6.dp))
                Box(
                    modifier =
                        Modifier.fillMaxWidth(0.5f)
                            .height(12.dp)
                            .background(
                                MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.15f),
                                MaterialTheme.shapes.small,
                            ),
                )
            }
        }
    }
}

// === Formatting utilities ===

/**
 * Formats a UTC instant as a short local date and time in the device's zone — on every screen, as
 * the Garmin app does and as the API contract describes for `startDateTime`.
 */
private fun formatDateTime(context: Context, isoDateTime: String?): String? {
    if (isoDateTime.isNullOrBlank()) return null

    return try {
        val instant = Instant.parse(isoDateTime)
        val localDateTime = instant.atZone(ZoneId.systemDefault()).toLocalDateTime()

        val dateFormatter = DateTimeFormatter.ofLocalizedDate(FormatStyle.SHORT)
        val timeFormatter =
            if (DateFormat.is24HourFormat(context)) {
                DateTimeFormatter.ofPattern("HH:mm")
            } else {
                DateTimeFormatter.ofPattern("h:mm a")
            }

        "${localDateTime.format(dateFormatter)} ${localDateTime.format(timeFormatter)}"
    } catch (_: Exception) {
        null
    }
}

private fun formatDistance(
    context: Context,
    distanceMeters: Float,
    userProfile: UserProfile?,
): String {
    val isImperial =
        userProfile?.preferredUnit?.distance == UserProfile.PreferredUnit.UnitType.IMPERIAL
    return if (isImperial) {
        val miles = distanceMeters / METERS_PER_MILE
        context.getString(R.string.distance_format_mi, miles)
    } else {
        val km = distanceMeters / METERS_PER_KM
        context.getString(R.string.distance_format_km, km)
    }
}

private fun formatElevation(
    context: Context,
    elevationMeters: Float,
    userProfile: UserProfile?,
): String {
    val isImperial =
        userProfile?.preferredUnit?.elevation == UserProfile.PreferredUnit.UnitType.IMPERIAL
    return if (isImperial) {
        val feet = (elevationMeters / METERS_PER_FOOT).toInt()
        context.getString(R.string.elevation_format_ft, feet)
    } else {
        context.getString(R.string.elevation_format_m, elevationMeters.toInt())
    }
}

// === Data loading ===

private suspend fun loadRoutesResponse(
    apiClient: PedalonsApiClient,
    authManager: AuthManager,
    onResult: (Result<RoutesResponse>) -> Unit,
) {
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
                    onResult(Result.failure(UnauthorizedException()))
                    return
                }
        }
    }

    if (accessToken == null) {
        onResult(Result.failure(UnauthorizedException()))
        return
    }

    apiClient.getRoutes(accessToken).let { onResult(it) }
}

private suspend fun syncRoute(
    apiClient: PedalonsApiClient,
    authManager: AuthManager,
    teamSlug: String,
    routeSlug: String,
    onHammerheadMissing: () -> Unit,
): SyncState {
    val accessToken = authManager.getValidAccessToken() ?: return SyncState.ERROR

    return apiClient
        .syncRoute(accessToken, teamSlug, routeSlug)
        .fold(
            onSuccess = { SyncState.SUCCESS },
            onFailure = { error ->
                // Hammerhead was unlinked since launch (from the profile): back to the
                // mandatory step rather than a bare « sync failed » (docs/LEDGER_*.md API-63).
                if (error.message?.contains("GPS_SERVICE_NOT_CONNECTED") == true) {
                    onHammerheadMissing()
                }
                SyncState.ERROR
            },
        )
}

private suspend fun checkAndPromptGpsConnection(
    apiClient: PedalonsApiClient,
    authManager: AuthManager,
    activity: MainActivity,
    onResult: (Boolean) -> Unit,
) {
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
                    onResult(true)
                    return
                }
        }
    }

    if (accessToken == null) {
        onResult(true)
        return
    }

    apiClient
        .getUserStatus(accessToken)
        .onSuccess { status ->
            if (status.isHammerheadConnected()) {
                onResult(true)
            } else {
                activity.startGpsConnectFlow()
                onResult(false)
            }
        }
        .onFailure {
            onResult(true)
        }
}
