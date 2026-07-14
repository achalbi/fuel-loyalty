package com.acefuel.loyalty.ui.designsystem

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.selection.toggleable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.acefuel.loyalty.ui.theme.NayaraNumerals
import com.acefuel.loyalty.ui.theme.NayaraSpacing
import com.acefuel.loyalty.ui.theme.nayara

// ============================================================================
// LedgerRow — the single row anatomy used on Home "recent activity", the
// Activity log, and the customer profile. DESIGN_BRIEF §5.2 / §5.7.
//
// Consistency over novelty: one row component, three placements. The entry
// types map exactly to PointsLedger#entry_type (earn / redeem / expire /
// adjust) so nothing is invented at the UI layer.
// ============================================================================

enum class LedgerEntryType { Earn, Redeem, Adjust, Expire }

/**
 * @param pending renders the offline-queue treatment: dashed warning border,
 *   dimmed value, "Queued" marker. Resolve it with a 220ms flash on sync.
 */
@Composable
fun LedgerRow(
    title: String,
    points: Int,
    type: LedgerEntryType,
    modifier: Modifier = Modifier,
    plate: String? = null,
    subtitle: String? = null,
    trailingSubtitle: String? = null,
    pending: Boolean = false,
    onClick: (() -> Unit)? = null,
) {
    val nayara = MaterialTheme.nayara
    val (container, onContainer, glyph) = when (type) {
        LedgerEntryType.Earn ->
            Triple(nayara.statusSuccessContainer, nayara.statusOnSuccessContainer, "↑")
        LedgerEntryType.Redeem ->
            Triple(nayara.rewardPointsContainer, nayara.rewardPointsText, "🎁")
        LedgerEntryType.Adjust ->
            Triple(nayara.actionPrimaryContainer, nayara.actionOnPrimaryContainer, "⚙")
        LedgerEntryType.Expire ->
            Triple(nayara.bgSurfaceSunken, nayara.textTertiary, "⌛")
    }

    // Earn is the only additive event, so it's the only one that gets green.
    // A positive adjustment is a correction, not a reward — it stays neutral.
    val valueColor = if (type == LedgerEntryType.Earn) nayara.statusSuccessText else nayara.textPrimary
    val sign = if (points > 0) "+" else if (points < 0) "−" else ""
    val valueText = sign + formatIndian(kotlin.math.abs(points).toLong())

    val base = Modifier
        .fillMaxWidth()
        .then(
            if (pending) {
                Modifier
                    .clip(MaterialTheme.shapes.medium)
                    .border(1.dp, nayara.statusWarning, MaterialTheme.shapes.medium)
                    .padding(NayaraSpacing.Sm)
            } else {
                Modifier
            },
        )
        .then(if (onClick != null) Modifier.clickable(onClick = onClick) else Modifier)
        .heightIn(min = 72.dp)
        .padding(vertical = NayaraSpacing.Sm)

    Row(
        modifier = modifier.then(base),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(NayaraSpacing.Md),
    ) {
        Box(
            Modifier
                .size(44.dp)
                .clip(CircleShape)
                .background(container)
                .alpha(if (pending) 0.6f else 1f),
            contentAlignment = Alignment.Center,
        ) {
            Text(glyph, fontSize = 18.sp, color = onContainer)
        }

        Column(Modifier.weight(1f)) {
            Text(
                text = title,
                style = MaterialTheme.typography.bodyLarge.copy(fontWeight = FontWeight.Bold),
                color = nayara.textPrimary,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            Spacer(Modifier.height(3.dp))
            Row(verticalAlignment = Alignment.CenterVertically) {
                if (plate != null) {
                    PlateChip(plate)
                    Spacer(Modifier.width(NayaraSpacing.Sm))
                }
                if (pending) {
                    PendingDot()
                } else if (subtitle != null) {
                    Text(
                        text = subtitle,
                        style = MaterialTheme.typography.bodySmall,
                        color = nayara.textSecondary,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                }
            }
        }

        Column(horizontalAlignment = Alignment.End) {
            Text(
                text = valueText,
                style = NayaraNumerals.Default.copy(fontSize = 17.sp, fontWeight = FontWeight.ExtraBold),
                color = valueColor,
                textAlign = TextAlign.End,
                modifier = Modifier
                    .alpha(if (pending) 0.6f else 1f)
                    // Screen readers should hear "plus forty points", not "+40".
                    .clearAndSetSemantics {
                        contentDescription = "${if (points >= 0) "plus" else "minus"} " +
                            "${kotlin.math.abs(points)} points"
                    },
            )
            if (trailingSubtitle != null && !pending) {
                Spacer(Modifier.height(2.dp))
                Text(
                    text = trailingSubtitle,
                    style = MaterialTheme.typography.labelSmall.copy(fontWeight = FontWeight.Bold),
                    color = nayara.textTertiary,
                )
            }
        }
    }
}

@Composable
private fun PendingDot() {
    val nayara = MaterialTheme.nayara
    Row(verticalAlignment = Alignment.CenterVertically) {
        Box(
            Modifier
                .size(6.dp)
                .clip(CircleShape)
                .background(nayara.statusWarning),
        )
        Spacer(Modifier.width(NayaraSpacing.Xs))
        Text(
            text = "Queued",
            style = MaterialTheme.typography.bodySmall.copy(fontWeight = FontWeight.Bold),
            color = nayara.statusWarningText,
        )
    }
}

/** Sticky day header for the grouped activity log. */
@Composable
fun DayHeader(label: String, modifier: Modifier = Modifier) {
    val nayara = MaterialTheme.nayara
    Text(
        text = label.uppercase(),
        style = MaterialTheme.typography.labelSmall.copy(fontWeight = FontWeight.ExtraBold),
        color = nayara.textTertiary,
        modifier = modifier
            .fillMaxWidth()
            .background(nayara.bgCanvas)
            .padding(top = NayaraSpacing.Md, bottom = NayaraSpacing.Xs),
    )
}

/**
 * Generic tappable list row for settings / catalogs / admin menus — 56dp,
 * leading icon, optional trailing value, chevron.
 */
@Composable
fun NayaraListRow(
    title: String,
    modifier: Modifier = Modifier,
    subtitle: String? = null,
    leadingIcon: ImageVector? = null,
    leadingTint: Color? = null,
    trailing: String? = null,
    onClick: (() -> Unit)? = null,
) {
    val nayara = MaterialTheme.nayara
    Row(
        modifier = modifier
            .fillMaxWidth()
            .then(if (onClick != null) Modifier.clickable(onClick = onClick) else Modifier)
            .heightIn(min = 56.dp)
            .padding(vertical = NayaraSpacing.Sm),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(NayaraSpacing.Md),
    ) {
        if (leadingIcon != null) {
            Icon(
                imageVector = leadingIcon,
                contentDescription = null,
                tint = leadingTint ?: nayara.textSecondary,
                modifier = Modifier.size(24.dp),
            )
        }
        Column(Modifier.weight(1f)) {
            Text(
                text = title,
                style = MaterialTheme.typography.bodyLarge.copy(fontWeight = FontWeight.SemiBold),
                color = nayara.textPrimary,
            )
            if (subtitle != null) {
                Text(
                    text = subtitle,
                    style = MaterialTheme.typography.bodySmall,
                    color = nayara.textSecondary,
                )
            }
        }
        if (trailing != null) {
            Text(
                text = trailing,
                style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.Bold),
                color = nayara.textSecondary,
            )
        }
        if (onClick != null) {
            Text("›", fontSize = 20.sp, color = nayara.textTertiary)
        }
    }
}

/**
 * Settings row with a trailing Material3 [Switch]. Same 56dp anatomy as
 * [NayaraListRow]; the whole row is one toggle target (tap anywhere flips it).
 */
@Composable
fun NayaraSwitchRow(
    title: String,
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit,
    modifier: Modifier = Modifier,
    subtitle: String? = null,
    leadingIcon: ImageVector? = null,
    leadingTint: Color? = null,
) {
    val nayara = MaterialTheme.nayara
    Row(
        modifier = modifier
            .fillMaxWidth()
            .toggleable(value = checked, role = Role.Switch, onValueChange = onCheckedChange)
            .heightIn(min = 56.dp)
            .padding(vertical = NayaraSpacing.Sm),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(NayaraSpacing.Md),
    ) {
        if (leadingIcon != null) {
            Icon(
                imageVector = leadingIcon,
                contentDescription = null,
                tint = leadingTint ?: nayara.textSecondary,
                modifier = Modifier.size(24.dp),
            )
        }
        Column(Modifier.weight(1f)) {
            Text(
                text = title,
                style = MaterialTheme.typography.bodyLarge.copy(fontWeight = FontWeight.SemiBold),
                color = nayara.textPrimary,
            )
            if (subtitle != null) {
                Text(
                    text = subtitle,
                    style = MaterialTheme.typography.bodySmall,
                    color = nayara.textSecondary,
                )
            }
        }
        // The row owns the toggle semantics; the Switch is decorative (onCheckedChange = null).
        Switch(checked = checked, onCheckedChange = null)
    }
}
