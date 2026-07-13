package com.acefuel.loyalty.ui.theme

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.LocalContentColor
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.unit.dp

// ============================================================================
// Shared Nayara components (specs: docs/design/DESIGN_BRIEF.md §7)
// Buttons: 52dp min height, radius 14 (shapes.medium), inline loading spinner.
// ============================================================================

/** Primary filled button (tokens: action.primary / size.buttonLg / radius.md). */
@Composable
fun NayaraButton(
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    loading: Boolean = false,
    content: @Composable RowScope.() -> Unit,
) {
    Button(
        onClick = onClick,
        enabled = enabled && !loading,
        shape = MaterialTheme.shapes.medium,
        modifier = modifier.heightIn(min = 52.dp),
    ) {
        if (loading) {
            CircularProgressIndicator(
                modifier = Modifier.size(20.dp),
                strokeWidth = 2.dp,
                color = LocalContentColor.current,
            )
        } else {
            content()
        }
    }
}

/** Tonal secondary button (tokens: action.secondary / action.onSecondary). */
@Composable
fun NayaraTonalButton(
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    content: @Composable RowScope.() -> Unit,
) {
    FilledTonalButton(
        onClick = onClick,
        enabled = enabled,
        shape = MaterialTheme.shapes.medium,
        colors = ButtonDefaults.filledTonalButtonColors(
            containerColor = MaterialTheme.nayara.actionSecondary,
            contentColor = MaterialTheme.nayara.actionOnSecondary,
        ),
        modifier = modifier.heightIn(min = 52.dp),
    ) {
        content()
    }
}

/** Outlined tertiary button. */
@Composable
fun NayaraOutlinedButton(
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    content: @Composable RowScope.() -> Unit,
) {
    OutlinedButton(
        onClick = onClick,
        enabled = enabled,
        shape = MaterialTheme.shapes.medium,
        modifier = modifier.heightIn(min = 52.dp),
    ) {
        content()
    }
}

/**
 * Brand hero card: navy gradient with the Nayara ribbon strip along the top
 * (tokens: gradient.heroCard + gradient.brandRibbon). Content color is white
 * in both light and dark mode.
 */
@Composable
fun NayaraHeroCard(
    modifier: Modifier = Modifier,
    content: @Composable ColumnScope.() -> Unit,
) {
    Box(
        modifier = modifier
            .fillMaxWidth()
            .clip(MaterialTheme.shapes.large)
            .background(
                Brush.linearGradient(
                    listOf(NayaraPalette.Navy950, NayaraPalette.Navy900, NayaraPalette.Cyan900),
                ),
            ),
    ) {
        Row(
            Modifier
                .fillMaxWidth()
                .height(3.dp)
                .align(Alignment.TopCenter),
        ) {
            Box(Modifier.weight(1f).fillMaxHeight().background(NayaraPalette.Navy700))
            Box(Modifier.weight(1f).fillMaxHeight().background(NayaraPalette.Cyan600))
            Box(Modifier.weight(1f).fillMaxHeight().background(NayaraPalette.Green600))
        }
        CompositionLocalProvider(LocalContentColor provides NayaraPalette.White) {
            Column(Modifier.fillMaxWidth().padding(20.dp), content = content)
        }
    }
}
