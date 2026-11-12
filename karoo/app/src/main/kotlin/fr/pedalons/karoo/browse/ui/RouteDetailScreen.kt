package fr.pedalons.karoo.browse.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import fr.pedalons.karoo.R
import fr.pedalons.karoo.browse.NavState
import fr.pedalons.karoo.browse.SyncState
import fr.pedalons.karoo.ui.components.ScreenTopBar
import fr.pedalons.karoo.ui.components.ScreenWithOverlay
import fr.pedalons.karoo.ui.formatDateTime
import fr.pedalons.karoo.ui.formatDistance
import fr.pedalons.karoo.ui.formatElevation
import io.hammerhead.karooext.models.UserProfile

@Composable
internal fun RouteDetailScreen(
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
            ScreenTopBar(title = detail.routeName, ellipsize = true)

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
