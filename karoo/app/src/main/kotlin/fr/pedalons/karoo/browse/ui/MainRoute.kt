package fr.pedalons.karoo.browse.ui

import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Modifier
import fr.pedalons.karoo.browse.MainIntent
import fr.pedalons.karoo.browse.MainScreenKind
import fr.pedalons.karoo.browse.MainUiState
import fr.pedalons.karoo.browse.NavState
import fr.pedalons.karoo.ui.theme.PedalonsKarooTheme

/**
 * The main screen: renders [state] and turns touches into [onIntent]. [onConnect] starts the
 * sign-in and [onClose] closes the app.
 */
@Composable
internal fun MainRoute(
    state: MainUiState,
    onIntent: (MainIntent) -> Unit,
    onConnect: () -> Unit,
    onClose: () -> Unit,
) {
    PedalonsKarooTheme {
        if (!state.karooReady) {
            // Show skeleton screen while connecting to Karoo System Service
            SkeletonScreen(onBack = onClose)
        } else {
            MainContent(state, onIntent, onConnect, onClose)
        }
    }
}

@Composable
private fun MainContent(
    state: MainUiState,
    onIntent: (MainIntent) -> Unit,
    onConnect: () -> Unit,
    onClose: () -> Unit,
) {
    val browse = state.browse
    // One list state for every list screen: the selection scrolls it.
    val listState = rememberLazyListState()

    // Auto-scroll when selection changes
    val itemCount = browse.itemCount
    val selectedIndex = browse.selectedIndex
    LaunchedEffect(selectedIndex) {
        if (itemCount > 0 && selectedIndex in 0 until itemCount) {
            listState.animateScrollToItem(selectedIndex)
        }
    }

    Surface(
        modifier = Modifier.fillMaxSize(),
        color = MaterialTheme.colorScheme.background,
    ) {
        val response = browse.response
        when (state.screen()) {
            MainScreenKind.CONNECT -> ConnectScreen(onConnect = onConnect, onBack = onClose)
            MainScreenKind.ERROR ->
                ErrorScreen(onRetry = { onIntent(MainIntent.Retry) }, onBack = onClose)
            MainScreenKind.SKELETON -> SkeletonScreen(onBack = onClose)
            MainScreenKind.EMPTY -> EmptyScreen(onBack = onClose)
            MainScreenKind.CONTENT -> {
                if (response != null) {
                    val back = { onIntent(MainIntent.Back) }
                    when (val nav = browse.current) {
                        is NavState.Home ->
                            HomeScreen(
                                response = response,
                                selectedIndex = selectedIndex,
                                listState = listState,
                                onSelect = { onIntent(MainIntent.OpenHomeEntry(it)) },
                                onBack = back,
                                onRefresh = { onIntent(MainIntent.Refresh) },
                                onDisconnect = { onIntent(MainIntent.Disconnect) },
                            )
                        is NavState.RegisteredGroupList ->
                            RegisteredGroupListScreen(
                                items = nav.items,
                                userProfile = state.userProfile,
                                selectedIndex = selectedIndex,
                                listState = listState,
                                syncState = browse.sync,
                                syncTargetIndex = browse.syncTargetIndex,
                                syncedRoutes = browse.syncedRoutes,
                                onSelectItem = { index, item ->
                                    // A cancelled ride has no control (KIT §9).
                                    if (!item.isCancelled) {
                                        onIntent(
                                            MainIntent.Sync(item.teamSlug, item.routeSlug, index),
                                        )
                                    }
                                },
                                onBack = back,
                            )
                        is NavState.RideList ->
                            RideListScreen(
                                rides = nav.rides,
                                selectedIndex = selectedIndex,
                                listState = listState,
                                onSelectRide = { onIntent(MainIntent.OpenRide(it)) },
                                onBack = back,
                            )
                        is NavState.RideEntries ->
                            RideEntriesScreen(
                                ride = nav.ride,
                                userProfile = state.userProfile,
                                selectedIndex = selectedIndex,
                                listState = listState,
                                onSelectEntry = {
                                    onIntent(MainIntent.OpenRideEntry(nav.ride, it))
                                },
                                onBack = back,
                            )
                        is NavState.RouteList ->
                            StandaloneRouteListScreen(
                                routes = nav.routes,
                                userProfile = state.userProfile,
                                selectedIndex = selectedIndex,
                                listState = listState,
                                onSelectRoute = { onIntent(MainIntent.OpenRoute(it)) },
                                onBack = back,
                            )
                        is NavState.RouteDetail ->
                            RouteDetailScreen(
                                detail = nav,
                                userProfile = state.userProfile,
                                syncState = browse.sync,
                                onSync = {
                                    onIntent(MainIntent.Sync(nav.teamSlug, nav.routeSlug, null))
                                },
                                onBack = back,
                            )
                    }
                }
            }
        }
    }
}
