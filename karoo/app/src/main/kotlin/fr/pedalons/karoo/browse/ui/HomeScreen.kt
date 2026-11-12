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
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import fr.pedalons.karoo.R
import fr.pedalons.karoo.api.RoutesResponse
import fr.pedalons.karoo.browse.HomeEntry
import fr.pedalons.karoo.browse.homeEntries
import fr.pedalons.karoo.ui.components.NavArrow
import fr.pedalons.karoo.ui.components.ScreenTopBar
import fr.pedalons.karoo.ui.components.ScreenWithOverlay
import fr.pedalons.karoo.ui.components.SelectableRow

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

    ScreenWithOverlay(onBack = onBack) {
        Column(modifier = Modifier.fillMaxSize()) {
            ScreenTopBar(
                title = stringResource(R.string.app_name),
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
    SelectableRow(isSelected = isSelected, onClick = onClick, contentPadding = 16.dp) {
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
        NavArrow()
    }
}
