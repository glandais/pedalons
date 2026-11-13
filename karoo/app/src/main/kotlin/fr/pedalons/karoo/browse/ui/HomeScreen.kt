package fr.pedalons.karoo.browse.ui

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyListState
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import fr.pedalons.karoo.R
import fr.pedalons.karoo.api.DeviceRegisteredGroup
import fr.pedalons.karoo.api.DeviceRegisteredStage
import fr.pedalons.karoo.api.RoutesResponse
import fr.pedalons.karoo.browse.HomeEntry
import fr.pedalons.karoo.browse.homeEntries
import fr.pedalons.karoo.browse.nextRegistered
import fr.pedalons.karoo.ui.FormatClock
import fr.pedalons.karoo.ui.components.NavArrow
import fr.pedalons.karoo.ui.components.ScreenTopBar
import fr.pedalons.karoo.ui.components.ScreenWithOverlay
import fr.pedalons.karoo.ui.components.SelectableRow
import fr.pedalons.karoo.ui.formatDeparture

@Composable
internal fun HomeScreen(
    response: RoutesResponse,
    selectedIndex: Int,
    listState: LazyListState,
    onSelect: (HomeEntry) -> Unit,
    onBack: () -> Unit,
    onRefresh: () -> Unit,
    onDisconnect: () -> Unit,
) {
    var showMenu by remember { mutableStateOf(false) }
    val context = LocalContext.current

    ScreenWithOverlay(onBack = onBack) {
        Column(modifier = Modifier.fillMaxSize()) {
            ScreenTopBar(
                title = stringResource(R.string.app_name),
                actions = {
                    IconButton(onClick = onRefresh) {
                        Icon(
                            imageVector = Icons.Filled.Refresh,
                            contentDescription = stringResource(R.string.refresh),
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
                            HomeEntry.REGISTERED -> response.registrationCount()
                            HomeEntry.RIDES -> response.rides.size
                            HomeEntry.ROUTES -> response.routes.size
                        }
                    // « Ma prochaine sortie », on the entry that leads to it: what is next and
                    // when.
                    val next =
                        if (entry == HomeEntry.REGISTERED) {
                            response.nextRegistered(FormatClock.now())
                        } else {
                            null
                        }
                    HomeMenuItem(
                        detail =
                            next?.let { item ->
                                val name =
                                    when (item) {
                                        is DeviceRegisteredGroup -> item.rideName
                                        is DeviceRegisteredStage -> item.stageName
                                    }
                                listOfNotNull(
                                    name,
                                    formatDeparture(context, item.startDateTime, item.timezone),
                                )
                            } ?: emptyList(),
                        title =
                            stringResource(
                                when (entry) {
                                    HomeEntry.REGISTERED -> R.string.nav_registered
                                    HomeEntry.RIDES -> R.string.nav_rides
                                    HomeEntry.ROUTES -> R.string.nav_routes
                                },
                            ),
                        subtitle =
                            pluralStringResource(
                                when (entry) {
                                    HomeEntry.REGISTERED -> R.plurals.registered_count
                                    HomeEntry.RIDES -> R.plurals.rides_count
                                    HomeEntry.ROUTES -> R.plurals.routes_count
                                },
                                count,
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
    detail: List<String>,
    title: String,
    subtitle: String,
    isSelected: Boolean,
    isEmpty: Boolean,
    emptyText: String,
    onClick: () -> Unit,
) {
    SelectableRow(isSelected = isSelected, onClick = onClick, contentPadding = 16.dp) {
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = title,
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold,
            )
            detail.forEachIndexed { index, line ->
                Text(
                    text = line,
                    style = MaterialTheme.typography.bodySmall,
                    fontWeight = if (index == 0) FontWeight.Medium else FontWeight.Normal,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
            Text(
                text = if (isEmpty) emptyText else subtitle,
                style = MaterialTheme.typography.bodySmall,
                color =
                    if (isEmpty) MaterialTheme.colorScheme.onSurfaceVariant
                    else MaterialTheme.colorScheme.primary,
            )
        }
        NavArrow()
    }
}
