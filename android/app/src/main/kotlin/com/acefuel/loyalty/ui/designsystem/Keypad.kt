package com.acefuel.loyalty.ui.designsystem

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.acefuel.loyalty.ui.theme.NayaraMotion
import com.acefuel.loyalty.ui.theme.NayaraNumerals
import com.acefuel.loyalty.ui.theme.NayaraSpacing
import com.acefuel.loyalty.ui.theme.nayara
import java.text.NumberFormat
import java.util.Locale

// ============================================================================
// Numeric keypad + amount entry — DESIGN_BRIEF §5.5.
//
// Recording a fuel amount is the hottest path in the staff app and today it is
// a plain text field behind the soft keyboard. A keypad-first sheet means the
// attendant never leaves the sheet, never fights an IME on a wet screen, and
// sees the reward *before* committing.
//
// The conversion line is not decoration — it makes PointsCalculator's rule
// visible at the point of entry:
//     points = floor(amount / rupees_per_reward_unit) * points_per_100
// ============================================================================

private val INR: NumberFormat = NumberFormat.getIntegerInstance(Locale("en", "IN"))

fun formatIndian(value: Long): String = INR.format(value)

/** Keys, in the order they are laid out. `null` renders an empty cell. */
private val KEY_ROWS = listOf(
    listOf("1", "2", "3"),
    listOf("4", "5", "6"),
    listOf("7", "8", "9"),
    listOf("00", "0", "⌫"),
)

/**
 * A 3×4 numeric keypad. Purely presentational: it emits key presses and holds
 * no state, so the caller owns the digit buffer and can enforce its own limits.
 *
 * @param onKey receives "0".."9", "00", or "DEL".
 */
@Composable
fun NayaraKeypad(
    onKey: (String) -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
) {
    Column(
        modifier = modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(NayaraSpacing.Sm),
    ) {
        KEY_ROWS.forEach { row ->
            Row(horizontalArrangement = Arrangement.spacedBy(NayaraSpacing.Sm)) {
                row.forEach { key ->
                    KeypadKey(
                        label = key,
                        utility = key == "00" || key == "⌫",
                        enabled = enabled,
                        onClick = { onKey(if (key == "⌫") "DEL" else key) },
                        modifier = Modifier.weight(1f),
                    )
                }
            }
        }
    }
}

@Composable
private fun KeypadKey(
    label: String,
    utility: Boolean,
    enabled: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val nayara = MaterialTheme.nayara
    val haptics = rememberHaptics()
    val interaction = remember { MutableInteractionSource() }
    val pressed by interaction.collectIsPressedAsState()
    val scale by animateFloatAsState(
        targetValue = if (pressed) 0.96f else 1f,
        animationSpec = NayaraMotion.pressSpring(),
        label = "keyScale",
    )

    Box(
        modifier = modifier
            .height(56.dp) // > 48dp hit target, gloved-hand friendly
            .scale(scale)
            .clip(MaterialTheme.shapes.medium)
            .background(if (utility) nayara.bgSurfaceSunken else nayara.bgSurface)
            .border(1.dp, nayara.borderSubtle, MaterialTheme.shapes.medium)
            .clickable(
                enabled = enabled,
                role = Role.Button,
                interactionSource = interaction,
                indication = null,
            ) {
                haptics.tick()
                onClick()
            },
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = label,
            style = if (utility) {
                MaterialTheme.typography.titleMedium
            } else {
                NayaraNumerals.Default.copy(fontSize = 22.sp, fontWeight = FontWeight.Bold)
            },
            color = if (utility) nayara.textSecondary else nayara.textPrimary,
        )
    }
}

/**
 * The amount read-out that sits above the keypad. ₹ symbol is deliberately in
 * text.tertiary — the number is the interface, the currency mark is chrome.
 */
@Composable
fun NayaraAmountDisplay(
    amount: Long,
    modifier: Modifier = Modifier,
    unit: String = "₹",
) {
    val nayara = MaterialTheme.nayara
    Row(
        modifier = modifier
            .fillMaxWidth()
            .padding(vertical = NayaraSpacing.Md),
        horizontalArrangement = Arrangement.Center,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(unit, style = NayaraNumerals.Hero, color = nayara.textTertiary)
        Spacer(Modifier.width(2.dp))
        Text(formatIndian(amount), style = NayaraNumerals.Hero, color = nayara.textPrimary)
    }
}

/**
 * The live conversion line: "₹2,050 at 2 pts / ₹100  →  +40 pts".
 *
 * Show this the moment the first digit lands. Points render in
 * status.successText — earn is green, always, everywhere.
 */
@Composable
fun NayaraConversionLine(
    amount: Long,
    pointsPerUnit: Int,
    rupeesPerUnit: Int,
    modifier: Modifier = Modifier,
) {
    val nayara = MaterialTheme.nayara
    val points = pointsForAmount(amount, pointsPerUnit, rupeesPerUnit)
    Row(
        modifier = modifier
            .fillMaxWidth()
            .clip(MaterialTheme.shapes.medium)
            .background(nayara.bgSurfaceSunken)
            .padding(horizontal = NayaraSpacing.Md, vertical = NayaraSpacing.Md),
        horizontalArrangement = Arrangement.Center,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = "₹${formatIndian(amount)} at $pointsPerUnit pts / ₹$rupeesPerUnit",
            style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.SemiBold),
            color = nayara.textSecondary,
        )
        Spacer(Modifier.width(NayaraSpacing.Sm))
        Text("→", color = nayara.textTertiary)
        Spacer(Modifier.width(NayaraSpacing.Sm))
        // AnimatedCounter rolls digits only — the sign and unit sit outside it
        // so they don't get animated on every keystroke.
        val earnStyle = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.ExtraBold)
        Text("+", style = earnStyle, color = nayara.statusSuccessText)
        AnimatedCounter(
            value = points,
            style = earnStyle,
            color = nayara.statusSuccessText,
        )
        Text(" pts", style = earnStyle, color = nayara.statusSuccessText)
    }
}

/**
 * Mirrors `PointsCalculator` on the server:
 *   floor(amount / rupees_per_reward_unit) * points_per_100
 *
 * Kept here so the sheet can show the reward before the round-trip, but the
 * server's value always wins — never persist this client-side number.
 */
fun pointsForAmount(amount: Long, pointsPerUnit: Int, rupeesPerUnit: Int): Int {
    if (rupeesPerUnit <= 0 || amount <= 0) return 0
    return ((amount / rupeesPerUnit) * pointsPerUnit).toInt()
}

/**
 * Digit-buffer helper for the keypad. Caps at [maxDigits] and collapses an
 * empty buffer back to zero, so the display never shows a blank.
 */
fun applyKey(current: String, key: String, maxDigits: Int = 6): String = when {
    key == "DEL" -> current.dropLast(1).ifEmpty { "0" }
    current == "0" && key == "00" -> "0"
    current == "0" -> key
    current.length + key.length > maxDigits -> current
    else -> current + key
}

/**
 * Stepper locked to the redemption increment the server enforces.
 *
 * `PointsRedeemer` rejects anything that isn't a positive multiple of
 * `redemption_increment`, at least `minimum_redeemable_points` and at most
 * `max_redeemable_points`. Today those come back as 422s *after* the attendant
 * has typed a number. A stepper makes an invalid amount unrepresentable — the
 * error can't happen rather than being reported.
 */
@Composable
fun NayaraPointsStepper(
    value: Int,
    onValueChange: (Int) -> Unit,
    minimum: Int,
    maximum: Int,
    increment: Int,
    modifier: Modifier = Modifier,
    cashValuePerPoint: Double? = null,
) {
    val nayara = MaterialTheme.nayara
    val haptics = rememberHaptics()
    val canDecrease = value - increment >= minimum
    val canIncrease = value + increment <= maximum

    Column(modifier = modifier.fillMaxWidth()) {
        Row(
            Modifier
                .fillMaxWidth()
                .clip(MaterialTheme.shapes.large)
                .background(nayara.bgSurface)
                .padding(NayaraSpacing.Md),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(NayaraSpacing.Md),
        ) {
            StepButton("−", canDecrease) {
                haptics.tick(); onValueChange(value - increment)
            }
            Column(
                Modifier.weight(1f),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                AnimatedCounter(
                    value = value,
                    style = NayaraNumerals.Large,
                    color = nayara.textPrimary,
                )
                if (cashValuePerPoint != null) {
                    Text(
                        text = "= ₹${formatIndian((value * cashValuePerPoint).toLong())} cash",
                        style = MaterialTheme.typography.bodySmall.copy(fontWeight = FontWeight.Bold),
                        color = nayara.textSecondary,
                    )
                }
            }
            StepButton("+", canIncrease) {
                haptics.tick(); onValueChange(value + increment)
            }
        }
        Spacer(Modifier.height(NayaraSpacing.Sm))
        Text(
            text = "Multiples of $increment · min $minimum · max ${formatIndian(maximum.toLong())}",
            style = MaterialTheme.typography.bodySmall,
            color = nayara.textTertiary,
            textAlign = TextAlign.Center,
            modifier = Modifier.fillMaxWidth(),
        )
    }
}

@Composable
private fun StepButton(label: String, enabled: Boolean, onClick: () -> Unit) {
    val nayara = MaterialTheme.nayara
    Box(
        Modifier
            .width(52.dp)
            .height(52.dp)
            .clip(MaterialTheme.shapes.medium)
            .background(if (enabled) nayara.actionSecondary else nayara.actionDisabledBg)
            .clickable(enabled = enabled, role = Role.Button, onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = label,
            fontSize = 22.sp,
            fontWeight = FontWeight.Bold,
            color = if (enabled) nayara.actionOnSecondary else nayara.actionOnDisabled,
        )
    }
}
