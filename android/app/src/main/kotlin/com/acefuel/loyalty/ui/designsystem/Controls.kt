package com.acefuel.loyalty.ui.designsystem

import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.selection.selectableGroup
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.acefuel.loyalty.ui.theme.NayaraMotion
import com.acefuel.loyalty.ui.theme.NayaraPalette
import com.acefuel.loyalty.ui.theme.NayaraSpacing
import com.acefuel.loyalty.ui.theme.nayara
import kotlinx.coroutines.delay

// ============================================================================
// Controls — segmented picker, tier badge, banner, hold-to-confirm.
// DESIGN_BRIEF §5.3 / §5.6 / §7.
// ============================================================================

/**
 * Segmented control — the customer-lookup mode switch (Plate / Phone / Card)
 * and the ₹ / litres toggle on the award sheet.
 *
 * A segmented control rather than tabs because these change *what you type*,
 * not what you're looking at. Tabs would imply three separate result sets.
 */
@Composable
fun NayaraSegmentedControl(
    options: List<String>,
    selectedIndex: Int,
    onSelect: (Int) -> Unit,
    modifier: Modifier = Modifier,
) {
    val nayara = MaterialTheme.nayara
    val haptics = rememberHaptics()
    Row(
        modifier = modifier
            .fillMaxWidth()
            .clip(MaterialTheme.shapes.medium)
            .background(nayara.bgSurfaceSunken)
            .padding(4.dp)
            .selectableGroup(),
        horizontalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        options.forEachIndexed { index, label ->
            val selected = index == selectedIndex
            Box(
                Modifier
                    .weight(1f)
                    .height(40.dp)
                    .clip(MaterialTheme.shapes.small)
                    .background(if (selected) nayara.bgSurface else Color.Transparent)
                    .selectable(
                        selected = selected,
                        role = Role.RadioButton,
                    ) {
                        if (!selected) haptics.tick()
                        onSelect(index)
                    },
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    text = label,
                    style = MaterialTheme.typography.labelLarge.copy(fontWeight = FontWeight.Bold),
                    color = if (selected) nayara.actionPrimary else nayara.textSecondary,
                    textAlign = TextAlign.Center,
                )
            }
        }
    }
}

// ---------------------------------------------------------------------------
// Tier badge
// ---------------------------------------------------------------------------

enum class Tier { Member, Silver, Gold, Platinum }

/**
 * Tier is a **UI-layer concept only** — there is no tier column on `customers`.
 * Derive it from lifetime points client-side, or add it to the customer
 * serializer before you ship this. Don't let two clients invent different
 * thresholds.
 *
 * Only Gold+ carries the gradient sheen, so the sheen keeps meaning something.
 */
@Composable
fun TierBadge(tier: Tier, modifier: Modifier = Modifier) {
    val nayara = MaterialTheme.nayara
    val label = tier.name.uppercase()
    val content = when (tier) {
        Tier.Silver, Tier.Gold -> NayaraPalette.Neutral950
        else -> NayaraPalette.White
    }
    val background: Brush = when (tier) {
        Tier.Member -> Brush.horizontalGradient(listOf(nayara.tierMember, nayara.tierMember))
        Tier.Silver -> Brush.horizontalGradient(listOf(nayara.tierSilver, nayara.tierSilver))
        Tier.Gold -> Brush.horizontalGradient(listOf(nayara.rewardCoin, nayara.rewardPoints))
        Tier.Platinum -> Brush.horizontalGradient(listOf(nayara.tierPlatinum, nayara.tierPlatinum))
    }
    Row(
        modifier = modifier
            .height(24.dp)
            .clip(CircleShape)
            .background(background)
            .padding(horizontal = 9.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (tier == Tier.Gold) {
            Text("★", fontSize = 10.sp, color = content)
            Spacer(Modifier.width(4.dp))
        }
        Text(
            text = label,
            style = MaterialTheme.typography.labelSmall.copy(fontWeight = FontWeight.ExtraBold),
            color = content,
        )
    }
}

// ---------------------------------------------------------------------------
// Banner
// ---------------------------------------------------------------------------

enum class BannerTone { Info, Warning, Error, Success }

/**
 * Inline banner for conditions the user must see but doesn't have to act on
 * right now — "My Pump has no active nozzles", "cash reward value is
 * unconfigured", "OCR corrected this plate".
 *
 * Deliberately not a snackbar: snackbars are for undoable events and vanish.
 * A banner persists because the condition persists.
 */
@Composable
fun NayaraBanner(
    text: String,
    tone: BannerTone,
    modifier: Modifier = Modifier,
    glyph: String? = null,
) {
    val nayara = MaterialTheme.nayara
    val (container, content, defaultGlyph) = when (tone) {
        BannerTone.Info -> Triple(nayara.statusInfoContainer, nayara.statusOnInfoContainer, "ℹ")
        BannerTone.Warning -> Triple(nayara.statusWarningContainer, nayara.statusOnWarningContainer, "⚠")
        BannerTone.Error -> Triple(nayara.statusErrorContainer, nayara.statusOnErrorContainer, "✕")
        BannerTone.Success -> Triple(nayara.statusSuccessContainer, nayara.statusOnSuccessContainer, "✓")
    }
    Row(
        modifier = modifier
            .fillMaxWidth()
            .clip(MaterialTheme.shapes.medium)
            .background(container)
            .padding(horizontal = 14.dp, vertical = NayaraSpacing.Md),
        horizontalArrangement = Arrangement.spacedBy(NayaraSpacing.Sm),
        verticalAlignment = Alignment.Top,
    ) {
        Text(glyph ?: defaultGlyph, fontSize = 15.sp, color = content)
        Text(
            text = text,
            style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.SemiBold),
            color = content,
        )
    }
}

// ---------------------------------------------------------------------------
// Hold to confirm
// ---------------------------------------------------------------------------

/**
 * Press-and-hold confirmation — DESIGN_BRIEF §5.6.
 *
 * Redemption is irreversible (`PointsRedeemer` writes a negative ledger row and
 * there is no undo endpoint), and the attendant is tapping a wet phone on a
 * forecourt. A hold gate costs 700ms and removes the entire class of
 * accidental-redemption support tickets.
 *
 * Reduced-motion note: the fill sweep is the only feedback, so if you disable
 * animations you must substitute a progress ring — do not silently shorten the
 * hold to zero.
 */
@Composable
fun HoldToConfirmButton(
    label: String,
    onConfirmed: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    holdMillis: Int = 700,
    destructive: Boolean = false,
) {
    val nayara = MaterialTheme.nayara
    val haptics = rememberHaptics()
    var holding by remember { mutableStateOf(false) }

    val fill by animateFloatAsState(
        targetValue = if (holding) 1f else 0f,
        animationSpec = tween(
            durationMillis = if (holding) holdMillis else NayaraMotion.Fast,
            easing = LinearEasing,
        ),
        label = "holdFill",
    )

    LaunchedEffect(holding) {
        if (holding) {
            delay(holdMillis.toLong())
            // Still held after the full duration → commit.
            if (holding) {
                haptics.confirm()
                holding = false
                onConfirmed()
            }
        }
    }

    val container = when {
        !enabled -> nayara.actionDisabledBg
        destructive -> nayara.statusError
        else -> nayara.actionPrimary
    }
    val content = when {
        !enabled -> nayara.actionOnDisabled
        destructive -> NayaraPalette.White
        else -> nayara.actionOnPrimary
    }

    Box(
        modifier = modifier
            .fillMaxWidth()
            .height(52.dp)
            .clip(MaterialTheme.shapes.medium)
            .background(container)
            .pointerInput(enabled) {
                if (!enabled) return@pointerInput
                detectTapGestures(
                    onPress = {
                        holding = true
                        // Suspends until the finger lifts or the gesture cancels.
                        tryAwaitRelease()
                        holding = false
                    },
                )
            },
        contentAlignment = Alignment.Center,
    ) {
        // Sweep fill — sits under the label, clipped by the parent shape.
        Box(
            Modifier
                .fillMaxWidth(fill)
                .fillMaxHeight()
                .background(Color.White.copy(alpha = 0.25f)),
        )
        Text(
            text = label,
            style = MaterialTheme.typography.labelLarge.copy(
                fontWeight = FontWeight.Bold,
                fontSize = 15.sp,
            ),
            color = content,
        )
    }
}

/**
 * Small circular icon container used behind row/quick-action glyphs. Extracted
 * because it was being re-declared inline on four screens with three different
 * diameters.
 */
@Composable
fun IconCircle(
    glyph: String,
    container: Color,
    content: Color,
    modifier: Modifier = Modifier,
    diameter: Int = 44,
) {
    Box(
        modifier
            .size(diameter.dp)
            .clip(CircleShape)
            .background(container),
        contentAlignment = Alignment.Center,
    ) {
        Text(glyph, fontSize = (diameter * 0.4).sp, color = content)
    }
}

/** Fuel-type dot used in chips and legends — one color per fuel, everywhere. */
@Composable
fun FuelDot(fuelTypeCode: String, modifier: Modifier = Modifier) {
    val nayara = MaterialTheme.nayara
    val color = when (fuelTypeCode.lowercase()) {
        "petrol" -> nayara.fuelPetrol
        "diesel" -> nayara.fuelDiesel
        else -> nayara.fuelPremium // cng_lpg and any future premium grade
    }
    Box(
        modifier
            .size(8.dp)
            .clip(CircleShape)
            .background(color),
    )
}

/** Rounded-corner shape helper for the sheet's top-only radius. */
val SheetShape = RoundedCornerShape(topStart = 28.dp, topEnd = 28.dp)
