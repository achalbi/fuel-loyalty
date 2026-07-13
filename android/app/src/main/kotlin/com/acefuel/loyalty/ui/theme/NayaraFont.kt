package com.acefuel.loyalty.ui.theme

import androidx.compose.ui.text.ExperimentalTextApi
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontVariation
import androidx.compose.ui.text.font.FontWeight
import com.acefuel.loyalty.R

// ============================================================================
// Manrope — the brand display/UI typeface (DESIGN_BRIEF §11). Bundled as a
// single variable TTF (res/font/manrope_variable.ttf, OFL-1.1); each weight is
// pinned via FontVariation on the `wght` axis. minSdk 26 supports variable
// fonts in Compose.
// ============================================================================

@OptIn(ExperimentalTextApi::class)
private fun manropeWeight(weight: FontWeight) = Font(
    R.font.manrope_variable,
    weight = weight,
    variationSettings = FontVariation.Settings(FontVariation.weight(weight.weight)),
)

val Manrope = FontFamily(
    manropeWeight(FontWeight.Normal),
    manropeWeight(FontWeight.Medium),
    manropeWeight(FontWeight.SemiBold),
    manropeWeight(FontWeight.Bold),
    manropeWeight(FontWeight.ExtraBold),
)
