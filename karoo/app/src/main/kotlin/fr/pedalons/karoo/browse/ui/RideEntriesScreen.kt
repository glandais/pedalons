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
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import fr.pedalons.karoo.api.DeviceRide
import fr.pedalons.karoo.api.DeviceRideEntry
import fr.pedalons.karoo.ui.components.DepartureLines
import fr.pedalons.karoo.ui.components.DistanceAndElevation
import fr.pedalons.karoo.ui.components.NavArrow
import fr.pedalons.karoo.ui.components.ScreenTopBar
import fr.pedalons.karoo.ui.components.ScreenWithOverlay
import fr.pedalons.karoo.ui.components.SelectableRow
import fr.pedalons.karoo.ui.groupLabel
import io.hammerhead.karooext.models.UserProfile

@Composable
internal fun RideEntriesScreen(
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
            ScreenTopBar(title = ride.rideName, ellipsize = true)

            LazyColumn(
                state = listState,
                modifier = Modifier.fillMaxSize(),
                contentPadding = PaddingValues(vertical = 8.dp),
            ) {
                itemsIndexed(ride.entries, key = { index, entry -> "$index-${entry.routeSlug}" }) {
                    index,
                    entry ->
                    SelectableRow(
                        isSelected = index == selectedIndex,
                        onClick = { onSelectEntry(entry) },
                        contentPadding = 10.dp,
                    ) {
                        Column(modifier = Modifier.weight(1f)) {
                            Text(
                                text =
                                    entry.groupName?.let { groupLabel(context, it) }
                                        ?: entry.routeName,
                                style = MaterialTheme.typography.bodyMedium,
                                fontWeight = FontWeight.Medium,
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis,
                            )
                            DepartureLines(ride.startOf(entry), ride.timezone)
                            DistanceAndElevation(entry.distance, entry.elevationGain, userProfile)
                        }
                        NavArrow()
                    }
                }
            }
        }
    }
}
