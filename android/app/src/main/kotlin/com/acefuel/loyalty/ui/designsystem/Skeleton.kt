package com.acefuel.loyalty.ui.designsystem

import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Card
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.acefuel.loyalty.ui.theme.NayaraSpacing
import com.acefuel.loyalty.ui.theme.nayara

// ============================================================================
// Skeleton loading (shimmer) — replaces spinners for content-shaped loading.
// Same pattern Facebook/LinkedIn/Google apps use: grey placeholder blocks with
// a light band sweeping across, so the layout doesn't jump when data lands.
// All blocks share one animation spec, so they sweep in sync.
// ============================================================================

private const val SHIMMER_DURATION_MS = 1200

/** Brush that sweeps a highlight band across skeleton blocks. */
@Composable
fun shimmerBrush(): Brush {
    val base = MaterialTheme.nayara.bgSurfaceSunken
    val highlight = MaterialTheme.nayara.bgSurfaceRaised
    val transition = rememberInfiniteTransition(label = "shimmer")
    val progress by transition.animateFloat(
        initialValue = 0f,
        targetValue = 1f,
        animationSpec = infiniteRepeatable(
            animation = tween(SHIMMER_DURATION_MS, easing = LinearEasing),
            repeatMode = RepeatMode.Restart,
        ),
        label = "shimmer-progress",
    )
    // Band travels from off-screen left to off-screen right.
    val bandWidth = 600f
    val start = -bandWidth + progress * (2000f + bandWidth)
    return Brush.linearGradient(
        colors = listOf(base, highlight, base),
        start = Offset(start, 0f),
        end = Offset(start + bandWidth, bandWidth / 3f),
    )
}

/** Rectangular skeleton block. */
@Composable
fun SkeletonBox(
    modifier: Modifier = Modifier,
    shape: Shape = MaterialTheme.shapes.small,
) {
    Box(modifier.clip(shape).background(shimmerBrush()))
}

/** Single line of skeleton "text". */
@Composable
fun SkeletonLine(
    modifier: Modifier = Modifier,
    height: Dp = 14.dp,
) {
    SkeletonBox(modifier.height(height), shape = MaterialTheme.shapes.extraSmall)
}

/** Circular skeleton (avatars, icons). */
@Composable
fun SkeletonCircle(size: Dp, modifier: Modifier = Modifier) {
    SkeletonBox(modifier.size(size), shape = CircleShape)
}

/** Skeleton for a standard list row: leading circle + two text lines. */
@Composable
fun SkeletonListItem(modifier: Modifier = Modifier, showAvatar: Boolean = true) {
    Card(modifier = modifier.fillMaxWidth()) {
        Row(
            modifier = Modifier.padding(NayaraSpacing.Lg),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            if (showAvatar) {
                SkeletonCircle(40.dp)
                Spacer(Modifier.width(NayaraSpacing.Md))
            }
            Column(Modifier.weight(1f)) {
                SkeletonLine(Modifier.fillMaxWidth(0.55f))
                Spacer(Modifier.height(NayaraSpacing.Sm))
                SkeletonLine(Modifier.fillMaxWidth(0.35f), height = 12.dp)
            }
            Spacer(Modifier.width(NayaraSpacing.Md))
            SkeletonLine(Modifier.width(48.dp))
        }
    }
}

/** Full-screen list skeleton: shows [count] shimmering rows. */
@Composable
fun SkeletonList(
    modifier: Modifier = Modifier,
    count: Int = 8,
    showAvatar: Boolean = true,
) {
    Column(
        modifier = modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(NayaraSpacing.Sm),
    ) {
        repeat(count) { SkeletonListItem(showAvatar = showAvatar) }
    }
}

/** Skeleton for a dashboard stat card. */
@Composable
fun SkeletonStatCard(modifier: Modifier = Modifier) {
    Card(modifier = modifier) {
        Column(Modifier.padding(NayaraSpacing.Lg)) {
            SkeletonLine(Modifier.fillMaxWidth(0.5f), height = 12.dp)
            Spacer(Modifier.height(NayaraSpacing.Md))
            SkeletonLine(Modifier.fillMaxWidth(0.35f), height = 24.dp)
        }
    }
}

/** Skeleton for a details/form card: a title and [lines] body lines. */
@Composable
fun SkeletonCard(modifier: Modifier = Modifier, lines: Int = 3) {
    Card(modifier = modifier.fillMaxWidth()) {
        Column(Modifier.padding(NayaraSpacing.Xl)) {
            SkeletonLine(Modifier.fillMaxWidth(0.4f), height = 18.dp)
            Spacer(Modifier.height(NayaraSpacing.Lg))
            repeat(lines) { i ->
                SkeletonLine(Modifier.fillMaxWidth(if (i % 2 == 0) 0.9f else 0.7f))
                if (i < lines - 1) Spacer(Modifier.height(NayaraSpacing.Md))
            }
        }
    }
}
