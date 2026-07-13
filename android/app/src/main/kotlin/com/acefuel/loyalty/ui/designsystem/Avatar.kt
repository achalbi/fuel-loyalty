package com.acefuel.loyalty.ui.designsystem

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.acefuel.loyalty.ui.theme.NayaraPalette

// ============================================================================
// Avatar — initials on a deterministic per-person color (Google Contacts /
// Salesforce pattern). Same name always gets the same hue, so people become
// recognizable at a glance in lists.
// ============================================================================

private data class AvatarTone(val container: Color, val content: Color)

private val AvatarTones = listOf(
    AvatarTone(NayaraPalette.Navy100, NayaraPalette.Navy800),
    AvatarTone(NayaraPalette.Cyan100, NayaraPalette.Cyan800),
    AvatarTone(NayaraPalette.Green100, NayaraPalette.Green800),
    AvatarTone(NayaraPalette.Sky100, NayaraPalette.Sky800),
    AvatarTone(NayaraPalette.Amber100, NayaraPalette.Amber800),
    AvatarTone(NayaraPalette.Red100, NayaraPalette.Red800),
    AvatarTone(NayaraPalette.Neutral200, NayaraPalette.Neutral800),
)

/** First letters of the first two words, uppercased ("Ravi Kumar" -> "RK"). */
fun initialsOf(name: String?): String {
    val words = name.orEmpty().trim().split(Regex("\\s+")).filter { it.isNotBlank() }
    return when {
        words.isEmpty() -> "?"
        words.size == 1 -> words[0].take(2).uppercase()
        else -> "${words[0].first()}${words[1].first()}".uppercase()
    }
}

@Composable
fun Avatar(
    name: String?,
    modifier: Modifier = Modifier,
    size: Dp = 40.dp,
    keySalt: String = "",
) {
    val key = (name.orEmpty() + keySalt)
    // floorMod (not abs % size): Int.MIN_VALUE.absoluteValue is still negative.
    val tone = AvatarTones[Math.floorMod(key.hashCode(), AvatarTones.size)]
    Box(
        modifier = modifier
            .size(size)
            .background(tone.container, CircleShape),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = initialsOf(name),
            color = tone.content,
            fontWeight = FontWeight.SemiBold,
            fontSize = (size.value * 0.38f).sp,
            style = MaterialTheme.typography.labelLarge,
        )
    }
}
