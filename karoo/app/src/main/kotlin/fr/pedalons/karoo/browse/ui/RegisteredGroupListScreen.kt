package fr.pedalons.karoo.browse.ui

import android.content.Context
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
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
import fr.pedalons.karoo.api.DeviceRegisteredStage
import fr.pedalons.karoo.api.RegisteredItem
import fr.pedalons.karoo.api.RouteSyncState
import fr.pedalons.karoo.browse.ItemPhase
import fr.pedalons.karoo.browse.SyncState
import fr.pedalons.karoo.browse.phase
import fr.pedalons.karoo.browse.routeKey
import fr.pedalons.karoo.ui.FormatClock
import fr.pedalons.karoo.ui.components.DayBox
import fr.pedalons.karoo.ui.components.DepartureLines
import fr.pedalons.karoo.ui.components.DistanceAndElevation
import fr.pedalons.karoo.ui.components.ListEmptyText
import fr.pedalons.karoo.ui.components.Pill
import fr.pedalons.karoo.ui.components.ScreenTopBar
import fr.pedalons.karoo.ui.components.ScreenWithOverlay
import fr.pedalons.karoo.ui.components.SelectableRow
import fr.pedalons.karoo.ui.groupLabel
import io.hammerhead.karooext.models.UserProfile

/** « Groupe B · Place de la Mairie », or the group alone when the ride names no start place. */
private fun groupAndPlace(context: Context, group: DeviceRegisteredGroup): String {
    val name = groupLabel(context, group.groupName)
    val place = group.startPlaceName?.takeIf { it.isNotBlank() }
    return if (place != null) context.getString(R.string.group_and_place, name, place) else name
}

/**
 * The one state badge of a row, an exception only (KIT §9, R1): « Annulé », « En cours », «
 * Terminée » — nothing for a ride that is simply to come.
 */
@Composable
private fun StateBadge(cancelled: Boolean, phase: ItemPhase) {
    when {
        cancelled -> Pill(stringResource(R.string.badge_cancelled), MaterialTheme.colorScheme.error)
        phase == ItemPhase.UNDER_WAY ->
            Pill(stringResource(R.string.badge_under_way), MaterialTheme.colorScheme.primary)
        phase == ItemPhase.FINISHED ->
            Pill(
                stringResource(R.string.badge_finished),
                MaterialTheme.colorScheme.onSurfaceVariant,
            )
    }
}

/** « Bourg-d'Oisans → Valloire », or the one place the stage names; null when it names none. */
private fun stagePlaces(context: Context, stage: DeviceRegisteredStage): String? {
    val start = stage.startPlaceName?.takeIf { it.isNotBlank() }
    val end = stage.endPlaceName?.takeIf { it.isNotBlank() }
    return if (start != null && end != null) {
        context.getString(R.string.places_span, start, end)
    } else {
        start ?: end
    }
}

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
 * The ride groups and the trip stages the user is registered in, by departure. A row is the action
 * itself: selecting it syncs its route to Hammerhead, its status shown on the row, without going
 * through the route detail screen.
 *
 * A stage row is the app's stage card in a list (KIT §9): the stage, its trip, when it leaves, then
 * « start → end » — never the name of its route (docs/LEDGER_*.md API-168).
 */
@Composable
internal fun RegisteredGroupListScreen(
    items: List<RegisteredItem>,
    userProfile: UserProfile?,
    selectedIndex: Int,
    listState: LazyListState,
    syncState: SyncState,
    syncTargetIndex: Int?,
    syncedRoutes: Set<String>,
    onSelectItem: (Int, RegisteredItem) -> Unit,
    onBack: () -> Unit,
) {
    val context = LocalContext.current

    ScreenWithOverlay(onBack = onBack) {
        Column(modifier = Modifier.fillMaxSize()) {
            ScreenTopBar(title = stringResource(R.string.nav_registered))

            val severalTeams = items.map { it.teamSlug }.distinct().size > 1

            if (items.isEmpty()) {
                ListEmptyText(stringResource(R.string.no_registered))
            } else {
                LazyColumn(
                    state = listState,
                    modifier = Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(vertical = 8.dp),
                ) {
                    itemsIndexed(
                        items,
                        key = { index, item ->
                            when (item) {
                                is DeviceRegisteredGroup ->
                                    "$index-${item.teamSlug}/${item.rideSlug}/${item.groupName}"
                                is DeviceRegisteredStage ->
                                    "$index-${item.teamSlug}/${item.tripSlug}/${item.stageName}"
                            }
                        },
                    ) { index, item ->
                        // The row of the app's « Ma prochaine sortie » (KIT §9, R11): the ride,
                        // its departure, then « Groupe B · Place de la Mairie »; a stage gives its
                        // title, its trip, then « start → end ».
                        val (title, subtitle) =
                            when (item) {
                                is DeviceRegisteredGroup ->
                                    item.rideName to groupAndPlace(context, item)
                                is DeviceRegisteredStage -> item.stageName to item.tripName
                            }
                        val phase = item.phase(FormatClock.now())
                        val cancelled = item.isCancelled
                        val rowSyncState = if (index == syncTargetIndex) syncState else null

                        SelectableRow(
                            isSelected = index == selectedIndex,
                            onClick = { onSelectItem(index, item) },
                            contentPadding = 10.dp,
                        ) {
                            DayBox(
                                item.startDateTime,
                                item.timezone,
                                trip = item is DeviceRegisteredStage,
                            )
                            Spacer(modifier = Modifier.width(8.dp))
                            Column(modifier = Modifier.weight(1f)) {
                                // Out of a team's own pages a card names its team — here, only
                                // when the rows come from more than one.
                                val team = item.teamName
                                if (severalTeams && team != null) {
                                    Text(
                                        text = team,
                                        style = MaterialTheme.typography.labelSmall,
                                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                                        maxLines = 1,
                                        overflow = TextOverflow.Ellipsis,
                                    )
                                }
                                Text(
                                    text = title,
                                    style = MaterialTheme.typography.bodyMedium,
                                    fontWeight = FontWeight.Medium,
                                    maxLines = 1,
                                    overflow = TextOverflow.Ellipsis,
                                )
                                StateBadge(cancelled, phase)
                                DepartureLines(
                                    item.startDateTime,
                                    item.timezone,
                                    relativeDay = !cancelled && phase == ItemPhase.UPCOMING,
                                )
                                Text(
                                    text = subtitle,
                                    style = MaterialTheme.typography.bodySmall,
                                    maxLines = 1,
                                    overflow = TextOverflow.Ellipsis,
                                )
                                if (item is DeviceRegisteredStage) {
                                    val places = stagePlaces(context, item)
                                    if (places != null) {
                                        Text(
                                            text = places,
                                            style = MaterialTheme.typography.bodySmall,
                                            maxLines = 1,
                                            overflow = TextOverflow.Ellipsis,
                                        )
                                    }
                                }
                                DistanceAndElevation(
                                    item.distance,
                                    item.elevationGain,
                                    userProfile,
                                )
                                // A cancelled ride has no control and nothing to load.
                                if (!cancelled)
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
                                                    routeKey(item.teamSlug, item.routeSlug) in
                                                        syncedRoutes
                                                ) {
                                                    RouteSyncState.SENT
                                                } else {
                                                    item.hammerheadSyncState()
                                                },
                                            )
                                    }
                            }
                            if (!cancelled)
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
