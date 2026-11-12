package fr.pedalons.karoo.ui.components

import androidx.compose.foundation.Image
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.focusProperties
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import fr.pedalons.karoo.R

@Composable
internal fun BackButton(
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Image(
        painter = painterResource(id = R.drawable.back),
        contentDescription = stringResource(R.string.back),
        modifier =
            modifier.size(54.dp).focusProperties { canFocus = false }.clickable(onClick = onClick),
    )
}

@Composable
internal fun SyncButton(
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Image(
        painter = painterResource(id = R.drawable.sync),
        contentDescription = stringResource(R.string.sync),
        modifier =
            modifier.size(54.dp).focusProperties { canFocus = false }.clickable(onClick = onClick),
    )
}

@Composable
internal fun ScreenWithOverlay(
    onBack: () -> Unit,
    showSync: Boolean = false,
    onSync: (() -> Unit)? = null,
    content: @Composable BoxScope.() -> Unit,
) {
    Box(modifier = Modifier.fillMaxSize()) {
        content()

        BackButton(
            onClick = onBack,
            modifier = Modifier.align(Alignment.BottomStart).padding(bottom = 10.dp),
        )

        if (showSync && onSync != null) {
            SyncButton(
                onClick = onSync,
                modifier = Modifier.align(Alignment.BottomEnd).padding(bottom = 10.dp),
            )
        }
    }
}

/**
 * The bold top bar every screen shows. [ellipsize] keeps a long title on one line (ride and route
 * names).
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun ScreenTopBar(
    title: String,
    ellipsize: Boolean = false,
    actions: @Composable RowScope.() -> Unit = {},
) {
    TopAppBar(
        title = {
            Text(
                text = title,
                fontWeight = FontWeight.Bold,
                maxLines = if (ellipsize) 1 else Int.MAX_VALUE,
                overflow = if (ellipsize) TextOverflow.Ellipsis else TextOverflow.Clip,
            )
        },
        actions = actions,
        colors =
            TopAppBarDefaults.topAppBarColors(
                containerColor = MaterialTheme.colorScheme.surface,
            ),
    )
}
