package fr.pedalons.karoo.ui.components

import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.focusProperties
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import fr.pedalons.karoo.R
import fr.pedalons.karoo.ui.dayBoxParts
import fr.pedalons.karoo.ui.formatDepartureTime
import fr.pedalons.karoo.ui.formatDistance
import fr.pedalons.karoo.ui.formatElevationGain
import fr.pedalons.karoo.ui.formatRelativeDay
import fr.pedalons.karoo.ui.formatZoneMention
import fr.pedalons.karoo.ui.theme.TripAccent
import io.hammerhead.karooext.models.UserProfile

/**
 * A row of a key-driven list: the selected one is outlined and tinted. The clickable stays on the
 * Surface so that the row's text is one merged node.
 */
@Composable
internal fun SelectableRow(
    isSelected: Boolean,
    onClick: () -> Unit,
    contentPadding: Dp,
    content: @Composable RowScope.() -> Unit,
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
            modifier = Modifier.fillMaxWidth().padding(contentPadding),
            verticalAlignment = Alignment.CenterVertically,
            content = content,
        )
    }
}

/** The « › » at the end of a row that opens something. */
@Composable
internal fun NavArrow() {
    Text(
        text = stringResource(R.string.nav_arrow),
        style = MaterialTheme.typography.headlineMedium,
        color = MaterialTheme.colorScheme.primary,
    )
}

@Composable
internal fun ListEmptyText(text: String) {
    Box(
        modifier = Modifier.fillMaxSize(),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = text,
            style = MaterialTheme.typography.bodyLarge,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

/**
 * The day box (docs/BRANDING.md §7.8): weekday, day, month — and the year outside the current one —
 * in the ride's [zone]. On a row it is the only date; « Départ 09:30 » beside it says the hour. A
 * trip takes its own colour ([trip]). Nothing without a start.
 */
@Composable
internal fun DayBox(isoDateTime: String?, zone: String?, trip: Boolean = false) {
    val parts = dayBoxParts(LocalContext.current, isoDateTime, zone) ?: return
    val accent = if (trip) TripAccent else MaterialTheme.colorScheme.primary
    Surface(color = MaterialTheme.colorScheme.surface, shape = MaterialTheme.shapes.small) {
        Column(
            modifier = Modifier.width(44.dp).padding(vertical = 4.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Text(
                text = parts.weekday,
                style = MaterialTheme.typography.labelSmall,
                fontWeight = FontWeight.SemiBold,
                color = accent,
                maxLines = 1,
            )
            Text(
                text = parts.day,
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.Bold,
                maxLines = 1,
            )
            Text(text = parts.month, style = MaterialTheme.typography.labelSmall, maxLines = 1)
            if (parts.year != null) {
                Text(text = parts.year, style = MaterialTheme.typography.labelSmall, maxLines = 1)
            }
        }
    }
}

/** A small rounded label: a state badge, or the « Demain » pill. */
@Composable
internal fun Pill(text: String, color: Color) {
    Surface(color = color.copy(alpha = 0.2f), shape = MaterialTheme.shapes.small) {
        Text(
            text = text,
            style = MaterialTheme.typography.labelSmall,
            fontWeight = FontWeight.Bold,
            color = color,
            maxLines = 1,
            modifier = Modifier.padding(horizontal = 6.dp, vertical = 1.dp),
        )
    }
}

/**
 * When a row leaves — the departure is primary information, never a statistic among others (ledger
 * BRAND-8): « Départ 09:30 » in bold, in the ride's [zone], the « Aujourd'hui » / « Demain » pill
 * above it unless [relativeDay] is off (a cancelled or past ride never carries it), then « heure de
 * Tokyo (ven. 01:00 chez vous) » when the Karoo is not at that zone's offset. Nothing without a
 * start.
 */
@Composable
internal fun DepartureLines(isoDateTime: String?, zone: String?, relativeDay: Boolean = true) {
    val context = LocalContext.current
    val time = formatDepartureTime(context, isoDateTime, zone) ?: return
    // On its own line: beside « Départ 09:30 » it is cut on a 256 dp wide screen.
    val day = if (relativeDay) formatRelativeDay(context, isoDateTime, zone) else null
    if (day != null) Pill(day, MaterialTheme.colorScheme.primary)
    Text(
        text = stringResource(R.string.departure_time, time),
        style = MaterialTheme.typography.bodyMedium,
        fontWeight = FontWeight.Bold,
        maxLines = 1,
    )
    val mention = formatZoneMention(context, isoDateTime, zone)
    if (mention != null) {
        Text(
            text = mention,
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

@Composable
internal fun DistanceAndElevation(distance: Float, elevation: Float, profile: UserProfile?) {
    val context = LocalContext.current
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(
            text = formatDistance(context, distance, profile),
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.primary,
        )
        Text(
            text = formatElevationGain(context, elevation, profile),
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.secondary,
        )
    }
}
