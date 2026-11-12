package fr.pedalons.karoo.browse.ui

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyListState
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import fr.pedalons.karoo.R
import fr.pedalons.karoo.api.DeviceRoute
import fr.pedalons.karoo.ui.components.DistanceAndElevation
import fr.pedalons.karoo.ui.components.ListEmptyText
import fr.pedalons.karoo.ui.components.NavArrow
import fr.pedalons.karoo.ui.components.ScreenTopBar
import fr.pedalons.karoo.ui.components.ScreenWithOverlay
import fr.pedalons.karoo.ui.components.SelectableRow
import io.hammerhead.karooext.models.UserProfile

@Composable
internal fun StandaloneRouteListScreen(
    routes: List<DeviceRoute>,
    userProfile: UserProfile?,
    selectedIndex: Int,
    listState: LazyListState,
    onSelectRoute: (DeviceRoute) -> Unit,
    onBack: () -> Unit,
) {
    ScreenWithOverlay(onBack = onBack) {
        Column(modifier = Modifier.fillMaxSize()) {
            ScreenTopBar(title = stringResource(R.string.nav_routes))

            if (routes.isEmpty()) {
                ListEmptyText(stringResource(R.string.no_routes))
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
                        SelectableRow(
                            isSelected = index == selectedIndex,
                            onClick = { onSelectRoute(route) },
                            contentPadding = 10.dp,
                        ) {
                            Column(modifier = Modifier.weight(1f)) {
                                Text(
                                    text = route.routeName,
                                    style = MaterialTheme.typography.bodyMedium,
                                    fontWeight = FontWeight.Medium,
                                    maxLines = 1,
                                    overflow = TextOverflow.Ellipsis,
                                )
                                DistanceAndElevation(
                                    route.distance,
                                    route.elevationGain,
                                    userProfile,
                                )
                            }
                            NavArrow()
                        }
                    }
                }
            }
        }
    }
}
