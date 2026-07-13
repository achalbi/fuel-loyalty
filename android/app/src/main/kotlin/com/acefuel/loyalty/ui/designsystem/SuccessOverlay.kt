package com.acefuel.loyalty.ui.designsystem

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathMeasure
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.PointerEventPass
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.acefuel.loyalty.ui.theme.NayaraMotion
import com.acefuel.loyalty.ui.theme.NayaraSpacing
import com.acefuel.loyalty.ui.theme.nayara
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

// ============================================================================
// SuccessOverlay — the "payment done" moment (GPay/PhonePe pattern): scrim,
// spring-scaled circle, a checkmark that draws itself on, and a confirm
// haptic. Auto-dismisses via [onFinished] so callers can navigate/reset.
// No Lottie asset needed; the check is drawn with PathMeasure.
//
// The animation state is hoisted above AnimatedVisibility and keyed on
// [visible] so a re-show during the exit fade re-runs the ceremony cleanly
// (an effect keyed on Unit inside the content would not restart while the
// content is still composed for the exit transition).
// ============================================================================

@Composable
fun SuccessOverlay(
    visible: Boolean,
    title: String,
    modifier: Modifier = Modifier,
    subtitle: String? = null,
    autoDismissMillis: Long = 1600,
    onFinished: () -> Unit = {},
) {
    val haptics = rememberHaptics()
    val checkProgress = remember { Animatable(0f) }
    val badgeScale = remember { Animatable(0.4f) }
    val currentOnFinished by rememberUpdatedState(onFinished)

    LaunchedEffect(visible) {
        if (!visible) return@LaunchedEffect
        checkProgress.snapTo(0f)
        badgeScale.snapTo(0.4f)
        haptics.confirm()
        launch { badgeScale.animateTo(1f, NayaraMotion.celebrateSpring()) }
        checkProgress.animateTo(
            1f,
            tween(NayaraMotion.Slow, delayMillis = 120, easing = NayaraMotion.Emphasized),
        )
        delay(autoDismissMillis)
        currentOnFinished()
    }

    AnimatedVisibility(
        visible = visible,
        enter = fadeIn(tween(NayaraMotion.Fast)),
        exit = fadeOut(tween(NayaraMotion.Base)),
        modifier = modifier,
    ) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(MaterialTheme.nayara.overlayScrim)
                // Modality: swallow every pointer event so taps can't reach the
                // controls beneath the scrim while the ceremony is up.
                .pointerInput(Unit) {
                    awaitPointerEventScope {
                        while (true) {
                            awaitPointerEvent(PointerEventPass.Initial).changes
                                .forEach { it.consume() }
                        }
                    }
                },
            contentAlignment = Alignment.Center,
        ) {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                val circleColor = MaterialTheme.nayara.statusSuccess
                val checkColor = Color.White
                Box(
                    modifier = Modifier
                        .size(96.dp)
                        .graphicsLayer {
                            scaleX = badgeScale.value
                            scaleY = badgeScale.value
                        }
                        .background(circleColor, CircleShape)
                        .drawBehind {
                            val w = size.width
                            val full = Path().apply {
                                moveTo(w * 0.28f, w * 0.53f)
                                lineTo(w * 0.44f, w * 0.68f)
                                lineTo(w * 0.72f, w * 0.35f)
                            }
                            val measure = PathMeasure().apply { setPath(full, false) }
                            val partial = Path()
                            measure.getSegment(0f, measure.length * checkProgress.value, partial, true)
                            drawPath(
                                partial,
                                color = checkColor,
                                style = Stroke(width = w * 0.075f, cap = StrokeCap.Round, join = StrokeJoin.Round),
                            )
                        },
                )
                Spacer(Modifier.height(NayaraSpacing.Xl))
                Text(
                    title,
                    style = MaterialTheme.typography.titleLarge,
                    color = Color.White,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.padding(horizontal = NayaraSpacing.X3l),
                )
                if (subtitle != null) {
                    Spacer(Modifier.height(NayaraSpacing.Sm))
                    Text(
                        subtitle,
                        style = MaterialTheme.typography.bodyMedium,
                        color = Color.White.copy(alpha = 0.8f),
                        textAlign = TextAlign.Center,
                        modifier = Modifier.padding(horizontal = NayaraSpacing.X3l),
                    )
                }
            }
        }
    }
}
