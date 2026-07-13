package com.acefuel.loyalty.ui.designsystem

import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.material3.Card
import androidx.compose.material3.CardColors
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.unit.dp
import com.acefuel.loyalty.ui.theme.nayara

// ============================================================================
// NayaraCard — the app's standard content/list card: white surface, large
// radius, and a soft shadow so it lifts cleanly off the grey canvas (the
// premium look; a flat filled Card disappears on a near-white background).
// Clickable and static variants; the clickable one animates its elevation on
// press for tactile feedback.
// ============================================================================

@Composable
private fun cardColors(): CardColors = CardDefaults.cardColors(
    containerColor = MaterialTheme.nayara.bgSurface,
    contentColor = MaterialTheme.nayara.textPrimary,
)

@Composable
fun NayaraCard(
    modifier: Modifier = Modifier,
    shape: Shape = MaterialTheme.shapes.large,
    content: @Composable ColumnScope.() -> Unit,
) {
    Card(
        modifier = modifier,
        shape = shape,
        colors = cardColors(),
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp),
        content = content,
    )
}

@Composable
fun NayaraCard(
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    shape: Shape = MaterialTheme.shapes.large,
    content: @Composable ColumnScope.() -> Unit,
) {
    Card(
        onClick = onClick,
        modifier = modifier,
        shape = shape,
        colors = cardColors(),
        elevation = CardDefaults.cardElevation(
            defaultElevation = 2.dp,
            pressedElevation = 6.dp,
            hoveredElevation = 4.dp,
        ),
        content = content,
    )
}
