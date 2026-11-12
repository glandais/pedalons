package fr.pedalons.karoo.browse.ui

import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyListState
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import fr.pedalons.karoo.R
import fr.pedalons.karoo.api.DeviceRegisteredGroup
import fr.pedalons.karoo.api.RouteSyncState
import fr.pedalons.karoo.browse.SyncState
import fr.pedalons.karoo.browse.routeKey
import fr.pedalons.karoo.ui.components.DistanceAndElevation
import fr.pedalons.karoo.ui.components.ListEmptyText
import fr.pedalons.karoo.ui.components.ScreenTopBar
import fr.pedalons.karoo.ui.components.ScreenWithOverlay
import fr.pedalons.karoo.ui.components.SelectableRow
import fr.pedalons.karoo.ui.formatDateTime
import io.hammerhead.karooext.models.UserProfile

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
@Composable
internal fun RegisteredGroupListScreen(
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
            ScreenTopBar(title = stringResource(R.string.nav_registered))

            if (groups.isEmpty()) {
                ListEmptyText(stringResource(R.string.no_registered))
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
                        val rowSyncState = if (index == syncTargetIndex) syncState else null

                        SelectableRow(
                            isSelected = index == selectedIndex,
                            onClick = { onSelectGroup(index, group) },
                            contentPadding = 10.dp,
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
                                DistanceAndElevation(
                                    group.distance,
                                    group.elevationGain,
                                    userProfile,
                                )
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
