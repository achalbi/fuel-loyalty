package com.acefuel.loyalty.core.theme

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb

/**
 * Derives the brand palette from the admin-set primary color, matching the web
 * app's CSS-variable math (docs/native-handoff/10):
 *   strong   = darken 14%      accent = lighten 18%
 *   soft     = primary @ ~0.16 alpha
 *   contrast = luminance >= 150 ? #081E0F : #F7FFF8
 *   dark-mode primary = lighten 16% first
 */
data class BrandPalette(
    val primary: Color,
    val strong: Color,
    val accent: Color,
    val soft: Color,
    val contrast: Color,
) {
    companion object {
        /** Nayara action primary (navy-700 from the Nayara ramp, docs/design/design-tokens.json). */
        val DEFAULT_HEX = "#1D63B0"

        fun from(hex: String?, dark: Boolean): BrandPalette {
            val base = parseHex(hex) ?: parseHex(DEFAULT_HEX)!!
            val primary = if (dark) base.lighten(0.16f) else base
            return BrandPalette(
                primary = primary,
                strong = primary.darken(0.14f),
                accent = primary.lighten(0.18f),
                soft = primary.copy(alpha = 0.16f),
                contrast = primary.contrastColor(),
            )
        }

        private fun parseHex(hex: String?): Color? {
            val cleaned = hex?.trim()?.removePrefix("#") ?: return null
            if (cleaned.length != 6) return null
            return runCatching {
                val value = cleaned.toLong(16)
                Color(
                    red = ((value shr 16) and 0xFF).toInt(),
                    green = ((value shr 8) and 0xFF).toInt(),
                    blue = (value and 0xFF).toInt(),
                )
            }.getOrNull()
        }
    }
}

private fun Color.darken(fraction: Float): Color = Color(
    red = (red * (1f - fraction)).coerceIn(0f, 1f),
    green = (green * (1f - fraction)).coerceIn(0f, 1f),
    blue = (blue * (1f - fraction)).coerceIn(0f, 1f),
    alpha = alpha,
)

private fun Color.lighten(fraction: Float): Color = Color(
    red = (red + (1f - red) * fraction).coerceIn(0f, 1f),
    green = (green + (1f - green) * fraction).coerceIn(0f, 1f),
    blue = (blue + (1f - blue) * fraction).coerceIn(0f, 1f),
    alpha = alpha,
)

private fun Color.contrastColor(): Color {
    val argb = toArgb()
    val r = (argb shr 16) and 0xFF
    val g = (argb shr 8) and 0xFF
    val b = argb and 0xFF
    val luminance = (r * 299 + g * 587 + b * 114) / 1000
    // Navy-tinted contrast pair (Nayara navy-950 / white).
    return if (luminance >= 150) Color(0xFF052B54) else Color(0xFFFFFFFF)
}
