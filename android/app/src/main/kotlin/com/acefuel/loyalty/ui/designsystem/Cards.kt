package com.acefuel.loyalty.ui.designsystem

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.acefuel.loyalty.ui.theme.NayaraMotion
import com.acefuel.loyalty.ui.theme.NayaraNumerals
import com.acefuel.loyalty.ui.theme.NayaraSpacing
import com.acefuel.loyalty.ui.theme.nayara

// ============================================================================
// Composite cards built on the existing `NayaraCard` (ui/designsystem/NayaraCard.kt).
//
// NOTE: NayaraCard applies a 2dp elevation in both light and dark. The token
// set sets every shadow to `none` in dark mode and separates surfaces with a
// 1dp border instead, because M3 elevation in dark reads as a muddy grey wash.
// Worth folding that branch into NayaraCard itself — see COMPONENT_RECOMMENDATION §6.
// ============================================================================

/** Uppercase section label with an optional trailing text action. */
@Composable
fun SectionHeader(
    title: String,
    modifier: Modifier = Modifier,
    actionLabel: String? = null,
    onAction: (() -> Unit)? = null,
) {
    val nayara = MaterialTheme.nayara
    Row(
        modifier = modifier
            .fillMaxWidth()
            .padding(top = NayaraSpacing.Xxl, bottom = NayaraSpacing.Sm),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        Text(
            text = title.uppercase(),
            style = MaterialTheme.typography.labelMedium.copy(fontWeight = FontWeight.ExtraBold),
            color = nayara.textTertiary,
        )
        if (actionLabel != null && onAction != null) {
            TextButton(onClick = onAction, contentPadding = PaddingValues(0.dp)) {
                Text(
                    text = actionLabel,
                    style = MaterialTheme.typography.labelLarge,
                    color = nayara.textLink,
                )
            }
        }
    }
}

enum class MetricDirection { Up, Down, Flat }

/**
 * Admin dashboard metric — `GET /api/v1/admin/dashboard` already returns
 * `display_value`, `change_pct` and `direction` for each of its 8 summary
 * cards. Pass `display_value` straight through; the server has already done
 * the ₹/lakh formatting.
 *
 * Note the deliberate asymmetry: "up" is only green when up is *good*. Points
 * redeemed rising is not a regression — pass [invertSentiment] for metrics
 * where a rise should not read as a win.
 */
@Composable
fun MetricCard(
    label: String,
    value: String,
    modifier: Modifier = Modifier,
    changeLabel: String? = null,
    direction: MetricDirection = MetricDirection.Flat,
    invertSentiment: Boolean = false,
    onClick: (() -> Unit)? = null,
) {
    val nayara = MaterialTheme.nayara
    val good = when (direction) {
        MetricDirection.Up -> !invertSentiment
        MetricDirection.Down -> invertSentiment
        MetricDirection.Flat -> false
    }
    val deltaColor = when {
        direction == MetricDirection.Flat -> nayara.textTertiary
        good -> nayara.statusSuccessText
        else -> nayara.statusError
    }
    val arrow = when (direction) {
        MetricDirection.Up -> "▲"
        MetricDirection.Down -> "▼"
        MetricDirection.Flat -> "—"
    }

    val inner: @Composable () -> Unit = {
        Column(Modifier.padding(14.dp)) {
            Text(
                text = label.uppercase(),
                style = MaterialTheme.typography.labelMedium.copy(fontWeight = FontWeight.Bold),
                color = nayara.textTertiary,
            )
            Spacer(Modifier.height(NayaraSpacing.Xs))
            Text(
                text = value,
                style = NayaraNumerals.Large.copy(fontSize = 24.sp),
                color = nayara.textPrimary,
            )
            if (changeLabel != null) {
                Spacer(Modifier.height(NayaraSpacing.Xs))
                Text(
                    text = "$arrow $changeLabel",
                    style = MaterialTheme.typography.labelMedium.copy(fontWeight = FontWeight.ExtraBold),
                    color = deltaColor,
                )
            }
        }
    }

    if (onClick != null) {
        NayaraCard(onClick = onClick, modifier = modifier) { inner() }
    } else {
        NayaraCard(modifier = modifier) { inner() }
    }
}

/**
 * Home quick action — icon in an action.primaryContainer circle above a short
 * label. Press scales to 0.97 on pressSpring.
 */
@Composable
fun QuickAction(
    label: String,
    icon: ImageVector,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val nayara = MaterialTheme.nayara
    val haptics = rememberHaptics()
    val interaction = remember { MutableInteractionSource() }
    val pressed by interaction.collectIsPressedAsState()
    val scale by animateFloatAsState(
        targetValue = if (pressed) 0.97f else 1f,
        animationSpec = NayaraMotion.pressSpring(),
        label = "quickScale",
    )

    Column(
        modifier = modifier
            .scale(scale)
            .clip(MaterialTheme.shapes.medium)
            .background(nayara.bgSurface)
            .clickable(
                role = Role.Button,
                interactionSource = interaction,
                indication = null,
            ) { haptics.tick(); onClick() }
            .padding(vertical = NayaraSpacing.Md, horizontal = NayaraSpacing.Xs),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Box(
            Modifier
                .size(44.dp)
                .clip(CircleShape)
                .background(nayara.actionPrimaryContainer),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                tint = nayara.actionOnPrimaryContainer,
                modifier = Modifier.size(22.dp),
            )
        }
        Spacer(Modifier.height(NayaraSpacing.Sm))
        Text(
            text = label,
            style = MaterialTheme.typography.labelMedium.copy(fontWeight = FontWeight.Bold),
            color = nayara.textSecondary,
        )
    }
}

/**
 * Redemption tile.
 *
 * A locked card stays tappable on purpose. Greying it out and swallowing the
 * tap tells the customer nothing; "760 pts short" tells them exactly what to
 * do next. [shortfall] drives that copy.
 */
@Composable
fun RewardCard(
    cashLabel: String,
    pointsCost: Int,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    shortfall: Int = 0,
) {
    val nayara = MaterialTheme.nayara
    val locked = shortfall > 0
    Box(modifier = modifier) {
        NayaraCard(
            onClick = onClick,
            modifier = Modifier.alpha(if (locked) 0.42f else 1f),
        ) {
            Column(Modifier.padding(16.dp)) {
                Text(
                    text = cashLabel,
                    style = NayaraNumerals.Large.copy(fontSize = 22.sp),
                    color = nayara.textPrimary,
                )
                Spacer(Modifier.height(NayaraSpacing.Xs))
                Text(
                    text = if (locked) {
                        "${formatIndian(shortfall.toLong())} pts short"
                    } else {
                        "${formatIndian(pointsCost.toLong())} pts"
                    },
                    style = MaterialTheme.typography.labelLarge.copy(fontWeight = FontWeight.ExtraBold),
                    color = nayara.rewardPointsText,
                )
            }
        }
        if (locked) {
            Text(
                text = "🔒",
                fontSize = 13.sp,
                modifier = Modifier
                    .align(Alignment.TopEnd)
                    .padding(10.dp),
            )
        }
    }
}

/**
 * Horizontal progress / tier bar. [gold] swaps the fill to the gold-shine
 * gradient — reserved for Gold-adjacent progress only, so the sheen keeps
 * meaning something.
 */
@Composable
fun NayaraProgress(
    fraction: Float,
    modifier: Modifier = Modifier,
    gold: Boolean = false,
    trackColor: Color? = null,
) {
    val nayara = MaterialTheme.nayara
    val animated by animateFloatAsState(
        targetValue = fraction.coerceIn(0f, 1f),
        animationSpec = tween(
            durationMillis = NayaraMotion.Slow,
            easing = NayaraMotion.Emphasized,
        ),
        label = "progress",
    )
    Box(
        modifier
            .fillMaxWidth()
            .height(8.dp)
            .clip(CircleShape)
            .background(trackColor ?: nayara.borderSubtle),
    ) {
        Box(
            Modifier
                .fillMaxWidth(animated)
                .height(8.dp)
                .clip(CircleShape)
                .background(
                    if (gold) {
                        Brush.horizontalGradient(listOf(nayara.rewardCoin, nayara.rewardPoints))
                    } else {
                        SolidColor(nayara.accentDefault)
                    },
                ),
        )
    }
}
