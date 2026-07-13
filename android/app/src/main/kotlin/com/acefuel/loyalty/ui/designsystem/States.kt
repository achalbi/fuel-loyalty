package com.acefuel.loyalty.ui.designsystem

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CloudOff
import androidx.compose.material.icons.filled.Inbox
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.acefuel.loyalty.R
import com.acefuel.loyalty.ui.theme.NayaraSpacing
import com.acefuel.loyalty.ui.theme.NayaraTonalButton
import com.acefuel.loyalty.ui.theme.nayara

// ============================================================================
// Screen states — the loading / error / empty triad every production app
// standardizes (Salesforce SLDS "empty state", Airbnb DLS "row of last
// resort"). Full-screen variants center in the content area; inline variants
// slot into an existing layout.
// ============================================================================

/** Full-screen (or full-area) error with an icon, message and retry action. */
@Composable
fun ErrorState(
    message: String,
    modifier: Modifier = Modifier,
    title: String = stringResource(R.string.ds_error_title),
    onRetry: (() -> Unit)? = null,
) {
    StateTemplate(
        icon = Icons.Filled.CloudOff,
        iconTint = MaterialTheme.nayara.statusError,
        iconBg = MaterialTheme.nayara.statusErrorContainer,
        title = title,
        message = message,
        modifier = modifier,
    ) {
        if (onRetry != null) {
            Spacer(Modifier.height(NayaraSpacing.Xl))
            NayaraTonalButton(onClick = onRetry) {
                Text(stringResource(R.string.ds_retry))
            }
        }
    }
}

/** Full-screen (or full-area) empty state with optional call to action. */
@Composable
fun EmptyState(
    title: String,
    modifier: Modifier = Modifier,
    message: String? = null,
    icon: ImageVector = Icons.Filled.Inbox,
    actionLabel: String? = null,
    onAction: (() -> Unit)? = null,
) {
    StateTemplate(
        icon = icon,
        iconTint = MaterialTheme.nayara.textTertiary,
        iconBg = MaterialTheme.nayara.bgSurfaceSunken,
        title = title,
        message = message,
        modifier = modifier,
    ) {
        if (actionLabel != null && onAction != null) {
            Spacer(Modifier.height(NayaraSpacing.Xl))
            NayaraTonalButton(onClick = onAction) { Text(actionLabel) }
        }
    }
}

@Composable
private fun StateTemplate(
    icon: ImageVector,
    iconTint: androidx.compose.ui.graphics.Color,
    iconBg: androidx.compose.ui.graphics.Color,
    title: String,
    message: String?,
    modifier: Modifier = Modifier,
    extra: @Composable () -> Unit = {},
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = NayaraSpacing.X3l, vertical = NayaraSpacing.X4l),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Box(
            modifier = Modifier
                .size(72.dp)
                .background(iconBg, CircleShape),
            contentAlignment = Alignment.Center,
        ) {
            Icon(icon, contentDescription = null, tint = iconTint, modifier = Modifier.size(32.dp))
        }
        Spacer(Modifier.height(NayaraSpacing.Xl))
        Text(
            title,
            style = MaterialTheme.typography.titleMedium,
            textAlign = TextAlign.Center,
        )
        if (message != null) {
            Spacer(Modifier.height(NayaraSpacing.Sm))
            Text(
                message,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.nayara.textSecondary,
                textAlign = TextAlign.Center,
            )
        }
        extra()
    }
}

/** Inline error card with optional retry — for errors inside a working screen. */
@Composable
fun InlineErrorCard(
    message: String,
    modifier: Modifier = Modifier,
    onRetry: (() -> Unit)? = null,
) {
    Card(
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.nayara.statusErrorContainer,
            contentColor = MaterialTheme.nayara.statusOnErrorContainer,
        ),
        modifier = modifier.fillMaxWidth(),
    ) {
        Row(
            modifier = Modifier.padding(
                start = NayaraSpacing.Lg,
                end = NayaraSpacing.Sm,
                top = NayaraSpacing.Sm,
                bottom = NayaraSpacing.Sm,
            ),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(
                Icons.Filled.CloudOff,
                contentDescription = null,
                tint = MaterialTheme.nayara.statusError,
                modifier = Modifier.size(20.dp),
            )
            Spacer(Modifier.width(NayaraSpacing.Md))
            Text(
                message,
                style = MaterialTheme.typography.bodyMedium,
                modifier = Modifier
                    .weight(1f)
                    .padding(vertical = NayaraSpacing.Sm),
            )
            if (onRetry != null) {
                TextButton(onClick = onRetry) {
                    Text(stringResource(R.string.ds_retry))
                }
            }
        }
    }
}
