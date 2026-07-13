package com.acefuel.loyalty.ui.designsystem

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.acefuel.loyalty.ui.theme.NayaraSpacing
import com.acefuel.loyalty.ui.theme.nayara

// ============================================================================
// Semantic chips & pills (DESIGN_BRIEF §7): read-only status badges with
// proper tone colors (not disabled AssistChips), the points pill, and the
// monospace plate chip.
// ============================================================================

enum class ChipTone { Success, Warning, Error, Info, Neutral, Brand }

/**
 * Read-only status badge — replaces the disabled-AssistChip hack (which dims
 * text and announces as a button to TalkBack).
 */
@Composable
fun StatusChip(
    label: String,
    tone: ChipTone,
    modifier: Modifier = Modifier,
    showDot: Boolean = true,
) {
    val nayara = MaterialTheme.nayara
    val (container, content, dot) = when (tone) {
        ChipTone.Success -> Triple(nayara.statusSuccessContainer, nayara.statusOnSuccessContainer, nayara.statusSuccess)
        ChipTone.Warning -> Triple(nayara.statusWarningContainer, nayara.statusOnWarningContainer, nayara.statusWarning)
        ChipTone.Error -> Triple(nayara.statusErrorContainer, nayara.statusOnErrorContainer, nayara.statusError)
        ChipTone.Info -> Triple(nayara.statusInfoContainer, nayara.statusOnInfoContainer, nayara.statusInfo)
        ChipTone.Neutral -> Triple(nayara.bgSurfaceSunken, nayara.textSecondary, nayara.textTertiary)
        ChipTone.Brand -> Triple(nayara.actionPrimaryContainer, nayara.actionOnPrimaryContainer, nayara.actionPrimary)
    }
    Row(
        modifier = modifier
            .clip(MaterialTheme.shapes.extraSmall)
            .background(container)
            .padding(horizontal = NayaraSpacing.Sm, vertical = NayaraSpacing.Xs),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (showDot) {
            Box(Modifier.size(6.dp).background(dot, CircleShape))
            Spacer(Modifier.width(NayaraSpacing.Xs + 2.dp))
        }
        Text(
            label,
            style = MaterialTheme.typography.labelMedium,
            color = content,
        )
    }
}

/** Convenience: Active/Inactive badge. */
@Composable
fun ActiveChip(active: Boolean, modifier: Modifier = Modifier) {
    StatusChip(
        label = if (active) "Active" else "Inactive",
        tone = if (active) ChipTone.Success else ChipTone.Neutral,
        modifier = modifier,
    )
}

/**
 * Vehicle plate chip (DESIGN_BRIEF §7): monospace on a sunken surface with a
 * hairline border, so registration numbers read like plates everywhere.
 */
@Composable
fun PlateChip(plate: String, modifier: Modifier = Modifier) {
    Box(
        modifier = modifier
            .clip(MaterialTheme.shapes.extraSmall)
            .background(MaterialTheme.nayara.bgSurfaceSunken)
            .border(1.dp, MaterialTheme.nayara.borderDefault, MaterialTheme.shapes.extraSmall)
            .padding(horizontal = NayaraSpacing.Sm, vertical = NayaraSpacing.Xs),
    ) {
        Text(
            plate.uppercase(),
            fontFamily = FontFamily.Monospace,
            fontSize = 15.sp,
            fontWeight = FontWeight.SemiBold,
            color = MaterialTheme.nayara.textPrimary,
        )
    }
}

/**
 * Points pill (DESIGN_BRIEF §7): a coin-badged pill on the reward container
 * token, for balances shown inline in lists and headers.
 */
@Composable
fun PointsPill(
    points: Int,
    modifier: Modifier = Modifier,
    icon: ImageVector? = null,
) {
    Row(
        modifier = modifier
            .clip(CircleShape)
            .background(MaterialTheme.nayara.rewardPointsContainer)
            .padding(horizontal = NayaraSpacing.Md, vertical = NayaraSpacing.Xs + 2.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            Modifier
                .size(16.dp)
                .background(MaterialTheme.nayara.rewardCoin, CircleShape),
            contentAlignment = Alignment.Center,
        ) {
            if (icon != null) {
                Icon(icon, contentDescription = null, tint = Color.White, modifier = Modifier.size(10.dp))
            } else {
                Text("★", fontSize = 9.sp, color = Color.White)
            }
        }
        Spacer(Modifier.width(NayaraSpacing.Sm))
        Text(
            "%,d pts".format(points),
            style = MaterialTheme.typography.labelLarge,
            color = MaterialTheme.nayara.rewardPointsText,
        )
    }
}
