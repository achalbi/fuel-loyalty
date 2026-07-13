package com.acefuel.loyalty.ui.designsystem

import android.os.Build
import android.view.HapticFeedbackConstants
import android.view.View
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.platform.LocalView

// ============================================================================
// Semantic haptics — the physical feedback layer Google Pay / GPay-class apps
// put on money movements and scan results. Uses view-level constants (works on
// every Compose version; API-gated where constants are API 30+).
// ============================================================================

class Haptics internal constructor(private val view: View) {

    /** Positive completion: payment recorded, points redeemed, scan matched. */
    fun confirm() {
        view.performHapticFeedback(
            if (Build.VERSION.SDK_INT >= 30) HapticFeedbackConstants.CONFIRM
            else HapticFeedbackConstants.KEYBOARD_TAP,
        )
    }

    /** Negative outcome: validation failed, request rejected. */
    fun reject() {
        view.performHapticFeedback(
            if (Build.VERSION.SDK_INT >= 30) HapticFeedbackConstants.REJECT
            else HapticFeedbackConstants.LONG_PRESS,
        )
    }

    /** Light tick: selection change, stepper increment, filter toggled. */
    fun tick() {
        view.performHapticFeedback(HapticFeedbackConstants.CLOCK_TICK)
    }
}

/** Remembered semantic haptics bound to the current view. */
@Composable
fun rememberHaptics(): Haptics {
    val view = LocalView.current
    return remember(view) { Haptics(view) }
}
