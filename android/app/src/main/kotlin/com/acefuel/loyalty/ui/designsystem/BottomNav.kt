package com.acefuel.loyalty.ui.designsystem

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.acefuel.loyalty.ui.theme.NayaraMotion
import com.acefuel.loyalty.ui.theme.NayaraPalette
import com.acefuel.loyalty.ui.theme.nayara

// ============================================================================
// Bottom navigation + docked SCAN FAB — DESIGN_BRIEF §4a / §7 "Tab bar".
//
// The biggest IA gap in the app today: navigation is menu-card driven from
// HomeScreen, which buries the highest-frequency action (scan plate → resolve
// customer → award) behind two taps. A persistent tab bar with a center action
// keeps it permanently in thumb reach.
//
//   [ Home ]  [ Customers ]  ( SCAN )  [ Activity ]  [ Account ]
//
// Layout: 20dp overhang gutter + 64dp bar + system nav inset. The FAB lives in
// the outer Box so it overlaps the bar while staying inside the parent's
// bounds — a FAB placed with a negative offset would render but silently drop
// its touches outside the parent.
// ============================================================================

private val BarHeight = 64.dp
private val FabOverhang = 20.dp
private val FabSize = 64.dp

/** One destination in the bar. [selectedIcon] is drawn when active. */
data class NayaraNavItem(
    val route: String,
    val label: String,
    val icon: ImageVector,
    val selectedIcon: ImageVector = icon,
)

/**
 * The tab bar. Pass exactly four [items] — the center slot is reserved for the
 * scan FAB. Fewer or more will still lay out, but the FAB stops sitting on the
 * visual centre line.
 */
@Composable
fun NayaraBottomBar(
    items: List<NayaraNavItem>,
    currentRoute: String?,
    onSelect: (String) -> Unit,
    onScan: () -> Unit,
    modifier: Modifier = Modifier,
    scanIcon: ImageVector? = null,
    scanDescription: String = "Scan number plate",
) {
    val nayara = MaterialTheme.nayara
    Box(modifier = modifier.fillMaxWidth()) {
        Column(Modifier.fillMaxWidth()) {
            // Transparent gutter the FAB pokes into.
            Spacer(Modifier.height(FabOverhang))
            Row(
                Modifier
                    .fillMaxWidth()
                    // background sits before the padding+height so it also
                    // paints behind the system navigation inset.
                    .background(nayara.bgSurface)
                    .navigationBarsPadding()
                    .height(BarHeight),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                items.take(2).forEach { item ->
                    NavTab(item, item.route == currentRoute, { onSelect(item.route) }, Modifier.weight(1f))
                }
                Spacer(Modifier.weight(1f)) // reserved for the FAB
                items.drop(2).take(2).forEach { item ->
                    NavTab(item, item.route == currentRoute, { onSelect(item.route) }, Modifier.weight(1f))
                }
            }
        }

        NayaraScanFab(
            onClick = onScan,
            contentDescription = scanDescription,
            icon = scanIcon,
            modifier = Modifier.align(Alignment.TopCenter),
        )
    }
}

/**
 * Tab bar without a docked action — the admin shell's bar.
 *
 * Admin has no single highest-frequency action worth a permanent FAB (an admin
 * adjusts points rarely and scans plates never), so the center slot would be
 * dead weight. Tabs simply divide the width evenly. Any number of [items] lays
 * out; four is the design.
 *
 * The bar is otherwise identical to [NayaraBottomBar] — same 64dp height, same
 * NavTab, same nav-inset handling — so the two shells feel like one product.
 */
@Composable
fun NayaraTabBar(
    items: List<NayaraNavItem>,
    currentRoute: String?,
    onSelect: (String) -> Unit,
    modifier: Modifier = Modifier,
) {
    val nayara = MaterialTheme.nayara
    Row(
        modifier
            .fillMaxWidth()
            // background before padding+height so it also paints behind the
            // system navigation inset (same order as NayaraBottomBar).
            .background(nayara.bgSurface)
            .navigationBarsPadding()
            .height(BarHeight),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        items.forEach { item ->
            NavTab(item, item.route == currentRoute, { onSelect(item.route) }, Modifier.weight(1f))
        }
    }
}

@Composable
private fun NavTab(
    item: NayaraNavItem,
    selected: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val nayara = MaterialTheme.nayara
    val tint = if (selected) nayara.actionPrimary else nayara.textTertiary
    Column(
        modifier = modifier
            .selectable(
                selected = selected,
                role = Role.Tab,
                onClick = onClick,
                interactionSource = remember { MutableInteractionSource() },
                indication = null,
            )
            .padding(vertical = 6.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Icon(
            imageVector = if (selected) item.selectedIcon else item.icon,
            contentDescription = null, // the label below carries the a11y text
            tint = tint,
            modifier = Modifier.size(24.dp),
        )
        Spacer(Modifier.height(2.dp))
        Text(
            text = item.label,
            style = MaterialTheme.typography.labelSmall.copy(fontWeight = FontWeight.Bold),
            fontSize = 10.sp,
            color = tint,
        )
        Spacer(Modifier.height(2.dp))
        // 4dp active dot. Space is reserved in both states so the label never
        // shifts vertically when selection changes.
        Box(
            Modifier
                .size(4.dp)
                .clip(CircleShape)
                .background(if (selected) nayara.actionPrimary else Color.Transparent),
        )
    }
}

/**
 * The docked scan action. 64dp with a 3dp gradient.brandRibbon ring around a
 * solid bg.brand core — the one control allowed to carry the ribbon gradient
 * (the brief permits at most one gradient element per screen).
 */
@Composable
fun NayaraScanFab(
    onClick: () -> Unit,
    contentDescription: String,
    modifier: Modifier = Modifier,
    icon: ImageVector? = null,
) {
    val nayara = MaterialTheme.nayara
    val interaction = remember { MutableInteractionSource() }
    val pressed by interaction.collectIsPressedAsState()
    val scale by animateFloatAsState(
        targetValue = if (pressed) 0.95f else 1f,
        animationSpec = NayaraMotion.pressSpring(),
        label = "scanFabScale",
    )

    Box(
        modifier = modifier
            .size(FabSize)
            .scale(scale)
            .clip(CircleShape)
            .background(
                Brush.linearGradient(
                    listOf(NayaraPalette.Navy900, NayaraPalette.Cyan600, NayaraPalette.Green600),
                ),
            )
            .selectable(
                selected = false,
                role = Role.Button,
                onClick = onClick,
                interactionSource = interaction,
                indication = null,
            )
            .padding(3.dp)
            .clip(CircleShape)
            .background(nayara.bgBrand),
        contentAlignment = Alignment.Center,
    ) {
        if (icon != null) {
            Icon(
                imageVector = icon,
                contentDescription = contentDescription,
                tint = NayaraPalette.White,
                modifier = Modifier.size(28.dp),
            )
        } else {
            // Text glyph fallback so this compiles before a vector asset lands.
            Text(
                text = "▣",
                color = NayaraPalette.White,
                fontSize = 24.sp,
                fontWeight = FontWeight.Bold,
            )
        }
    }
}

/**
 * Sticky bottom action bar — DESIGN_BRIEF §5.4. One filled primary plus at
 * most one tonal secondary. Safe-area padded.
 */
@Composable
fun NayaraActionBar(
    modifier: Modifier = Modifier,
    content: @Composable RowScope.() -> Unit,
) {
    val nayara = MaterialTheme.nayara
    Row(
        modifier = modifier
            .fillMaxWidth()
            .background(nayara.bgSurface)
            .navigationBarsPadding()
            .padding(horizontal = 16.dp, vertical = 12.dp),
        horizontalArrangement = Arrangement.spacedBy(10.dp),
        verticalAlignment = Alignment.CenterVertically,
        content = content,
    )
}
