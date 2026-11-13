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
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import fr.pedalons.karoo.R
import fr.pedalons.karoo.api.DeviceRide
import fr.pedalons.karoo.ui.components.DepartureLines
import fr.pedalons.karoo.ui.components.ListEmptyText
import fr.pedalons.karoo.ui.components.NavArrow
import fr.pedalons.karoo.ui.components.ScreenTopBar
import fr.pedalons.karoo.ui.components.ScreenWithOverlay
import fr.pedalons.karoo.ui.components.SelectableRow

@Composable
internal fun RideListScreen(
    rides: List<DeviceRide>,
    selectedIndex: Int,
    listState: LazyListState,
    onSelectRide: (DeviceRide) -> Unit,
    onBack: () -> Unit,
) {
    ScreenWithOverlay(onBack = onBack) {
        Column(modifier = Modifier.fillMaxSize()) {
            ScreenTopBar(title = stringResource(R.string.nav_rides))

            if (rides.isEmpty()) {
                ListEmptyText(stringResource(R.string.no_rides))
            } else {
                LazyColumn(
                    state = listState,
                    modifier = Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(vertical = 8.dp),
                ) {
                    itemsIndexed(rides, key = { _, ride -> "${ride.teamSlug}/${ride.rideSlug}" }) {
                        index,
                        ride ->
                        SelectableRow(
                            isSelected = index == selectedIndex,
                            onClick = { onSelectRide(ride) },
                            contentPadding = 10.dp,
                        ) {
                            Column(modifier = Modifier.weight(1f)) {
                                Text(
                                    text = ride.rideName,
                                    style = MaterialTheme.typography.bodyMedium,
                                    fontWeight = FontWeight.Medium,
                                    maxLines = 1,
                                    overflow = TextOverflow.Ellipsis,
                                )
                                DepartureLines(ride.startDateTime, ride.timezone)
                                Text(
                                    text =
                                        pluralStringResource(
                                            R.plurals.routes_count,
                                            ride.entries.size,
                                            ride.entries.size,
                                        ),
                                    style = MaterialTheme.typography.bodySmall,
                                    color = MaterialTheme.colorScheme.primary,
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
