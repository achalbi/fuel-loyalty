package com.acefuel.loyalty.ui.designsystem

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.animation.togetherWith
import androidx.compose.animation.core.tween
import androidx.compose.foundation.layout.Row
import androidx.compose.material3.LocalContentColor
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import com.acefuel.loyalty.ui.theme.NayaraMotion

// ============================================================================
// AnimatedCounter — per-digit rolling number (the Google Pay / fintech-app
// balance treatment). Digits that change slide up when the value increases and
// down when it decreases; unchanged digits stay put.
// ============================================================================

@Composable
fun AnimatedCounter(
    value: Int,
    modifier: Modifier = Modifier,
    style: TextStyle = MaterialTheme.typography.displayMedium,
    color: Color = LocalContentColor.current,
) {
    var previous by remember { mutableIntStateOf(value) }
    val increasing = value >= previous
    // Update after composition, not during it: writing state inline would
    // invalidate the same frame and flip `increasing` to true for decreases.
    SideEffect { previous = value }

    val text = value.toString()
    Row(modifier) {
        text.forEachIndexed { index, char ->
            // Key by position-from-the-right so each digit column keeps its
            // identity (and roll direction) as the number changes length.
            val place = text.length - index
            key(place) {
                AnimatedContent(
                    targetState = char,
                    transitionSpec = {
                        val duration = NayaraMotion.Base
                        if (increasing) {
                            (slideInVertically(tween(duration, easing = NayaraMotion.Emphasized)) { it } +
                                fadeIn(tween(duration))) togetherWith
                                (slideOutVertically(tween(duration, easing = NayaraMotion.Emphasized)) { -it } +
                                    fadeOut(tween(duration)))
                        } else {
                            (slideInVertically(tween(duration, easing = NayaraMotion.Emphasized)) { -it } +
                                fadeIn(tween(duration))) togetherWith
                                (slideOutVertically(tween(duration, easing = NayaraMotion.Emphasized)) { it } +
                                    fadeOut(tween(duration)))
                        }
                    },
                    label = "counter-digit-$place",
                ) { digit ->
                    Text(
                        text = digit.toString(),
                        style = style,
                        color = color,
                        fontFamily = FontFamily.Default,
                    )
                }
            }
        }
    }
}
