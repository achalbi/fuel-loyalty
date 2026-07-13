package com.acefuel.loyalty.ui.theme

import androidx.compose.animation.core.CubicBezierEasing
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.spring
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Shapes
import androidx.compose.material3.Typography
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.ReadOnlyComposable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

// ============================================================================
// NayaraTheme — Material 3 theme wired to the Nayara token set.
// Source of truth: docs/design/design-tokens.json
// Drop-in: replaces (or wraps) AceFuelLoyaltyTheme. Keep BrandPalette for the
// admin-configurable seed if needed; default seed becomes Nayara navy #10447C.
// ============================================================================

private val LightScheme = lightColorScheme(
    primary = NayaraLightColors.actionPrimary,            // navy-700 #1D63B0
    onPrimary = NayaraLightColors.actionOnPrimary,
    primaryContainer = NayaraLightColors.actionPrimaryContainer,
    onPrimaryContainer = NayaraLightColors.actionOnPrimaryContainer,
    inversePrimary = NayaraPalette.Sky300,
    secondary = NayaraLightColors.accentDefault,           // cyan-600 #0080A0
    onSecondary = NayaraLightColors.accentOnAccent,
    secondaryContainer = NayaraLightColors.accentContainer,
    onSecondaryContainer = NayaraLightColors.accentOnContainer,
    tertiary = NayaraLightColors.statusSuccess,            // green-600 #18945C
    onTertiary = NayaraPalette.White,
    tertiaryContainer = NayaraLightColors.statusSuccessContainer,
    onTertiaryContainer = NayaraLightColors.statusOnSuccessContainer,
    background = NayaraLightColors.bgCanvas,
    onBackground = NayaraLightColors.textPrimary,
    surface = NayaraLightColors.bgSurface,
    onSurface = NayaraLightColors.textPrimary,
    surfaceVariant = NayaraPalette.Neutral100,
    onSurfaceVariant = NayaraLightColors.textSecondary,
    surfaceTint = NayaraLightColors.actionPrimary,
    inverseSurface = NayaraLightColors.bgInverse,
    inverseOnSurface = NayaraPalette.Neutral50,
    error = NayaraLightColors.statusError,
    onError = NayaraPalette.White,
    errorContainer = NayaraLightColors.statusErrorContainer,
    onErrorContainer = NayaraLightColors.statusOnErrorContainer,
    outline = NayaraLightColors.borderStrong,
    outlineVariant = NayaraLightColors.borderDefault,
    scrim = NayaraPalette.Black,
)

private val DarkScheme = darkColorScheme(
    primary = NayaraDarkColors.actionPrimary,              // sky-300 #8FD0FF
    onPrimary = NayaraDarkColors.actionOnPrimary,          // navy-950
    primaryContainer = NayaraDarkColors.actionPrimaryContainer,
    onPrimaryContainer = NayaraDarkColors.actionOnPrimaryContainer,
    inversePrimary = NayaraPalette.Navy700,
    secondary = NayaraDarkColors.accentDefault,
    onSecondary = NayaraDarkColors.accentOnAccent,
    secondaryContainer = NayaraDarkColors.accentContainer,
    onSecondaryContainer = NayaraDarkColors.accentOnContainer,
    tertiary = NayaraDarkColors.statusSuccess,
    onTertiary = NayaraPalette.Green950,
    tertiaryContainer = NayaraDarkColors.statusSuccessContainer,
    onTertiaryContainer = NayaraDarkColors.statusOnSuccessContainer,
    background = NayaraDarkColors.bgCanvas,
    onBackground = NayaraDarkColors.textPrimary,
    surface = NayaraDarkColors.bgSurface,
    onSurface = NayaraDarkColors.textPrimary,
    surfaceVariant = NayaraDarkColors.bgSurfaceRaised,
    onSurfaceVariant = NayaraDarkColors.textSecondary,
    surfaceTint = NayaraDarkColors.actionPrimary,
    inverseSurface = NayaraDarkColors.bgInverse,
    inverseOnSurface = NayaraPalette.Neutral950,
    error = NayaraDarkColors.statusError,
    onError = NayaraPalette.Red950,
    errorContainer = NayaraDarkColors.statusErrorContainer,
    onErrorContainer = NayaraDarkColors.statusOnErrorContainer,
    outline = NayaraDarkColors.borderStrong,
    outlineVariant = NayaraDarkColors.borderDefault,
    scrim = NayaraPalette.Black,
)

// ---------------------------------------------------------------------------
// Typography — Manrope for display/numerals (bundle in res/font), system for
// body. Numeric styles must render with tabular figures for points/₹ amounts.
// ---------------------------------------------------------------------------
val NayaraTypography = Typography(
    displayLarge = TextStyle(fontSize = 40.sp, lineHeight = 46.sp, fontWeight = FontWeight.ExtraBold, letterSpacing = (-0.5).sp),
    displayMedium = TextStyle(fontSize = 32.sp, lineHeight = 38.sp, fontWeight = FontWeight.ExtraBold, letterSpacing = (-0.25).sp),
    headlineMedium = TextStyle(fontSize = 24.sp, lineHeight = 30.sp, fontWeight = FontWeight.Bold),
    titleLarge = TextStyle(fontSize = 20.sp, lineHeight = 26.sp, fontWeight = FontWeight.Bold),
    titleMedium = TextStyle(fontSize = 17.sp, lineHeight = 24.sp, fontWeight = FontWeight.SemiBold),
    bodyLarge = TextStyle(fontSize = 16.sp, lineHeight = 24.sp, fontWeight = FontWeight.Normal),
    bodyMedium = TextStyle(fontSize = 14.sp, lineHeight = 20.sp, fontWeight = FontWeight.Normal),
    bodySmall = TextStyle(fontSize = 13.sp, lineHeight = 18.sp, fontWeight = FontWeight.Normal),
    labelLarge = TextStyle(fontSize = 14.sp, lineHeight = 20.sp, fontWeight = FontWeight.SemiBold, letterSpacing = 0.1.sp),
    labelMedium = TextStyle(fontSize = 12.sp, lineHeight = 16.sp, fontWeight = FontWeight.SemiBold, letterSpacing = 0.3.sp),
    labelSmall = TextStyle(fontSize = 11.sp, lineHeight = 14.sp, fontWeight = FontWeight.Medium, letterSpacing = 0.3.sp),
)

/** Hero numerals for points balances, litres, ₹ — always tabular. */
object NayaraNumerals {
    val Hero = TextStyle(fontSize = 44.sp, lineHeight = 48.sp, fontWeight = FontWeight.ExtraBold, letterSpacing = (-0.5).sp)
    val Large = TextStyle(fontSize = 28.sp, lineHeight = 32.sp, fontWeight = FontWeight.ExtraBold, letterSpacing = (-0.25).sp)
    val Default = TextStyle(fontSize = 20.sp, lineHeight = 24.sp, fontWeight = FontWeight.Bold)
}

val NayaraShapes = Shapes(
    extraSmall = RoundedCornerShape(6.dp),   // tags
    small = RoundedCornerShape(10.dp),       // chips, small controls
    medium = RoundedCornerShape(14.dp),      // buttons, inputs
    large = RoundedCornerShape(18.dp),       // cards
    extraLarge = RoundedCornerShape(28.dp),  // sheets (top corners)
)

object NayaraSpacing {
    val None = 0.dp; val Xxs = 2.dp; val Xs = 4.dp; val Sm = 8.dp
    val Md = 12.dp; val Lg = 16.dp; val Xl = 20.dp; val Xxl = 24.dp
    val X3l = 32.dp; val X4l = 40.dp; val X5l = 48.dp; val X6l = 64.dp
    val ScreenMargin = 16.dp; val Gutter = 12.dp; val CardPadding = 20.dp; val SectionGap = 28.dp
    val HitTarget = 48.dp
}

object NayaraMotion {
    const val Instant = 80; const val Fast = 140; const val Base = 220
    const val Gentle = 320; const val Slow = 480
    val Standard = CubicBezierEasing(0.2f, 0f, 0f, 1f)
    val Emphasized = CubicBezierEasing(0.05f, 0.7f, 0.1f, 1f)
    val Enter = CubicBezierEasing(0f, 0f, 0f, 1f)
    val Exit = CubicBezierEasing(0.3f, 0f, 1f, 1f)
    fun <T> pressSpring() = spring<T>(dampingRatio = 0.9f, stiffness = Spring.StiffnessMedium)
    fun <T> celebrateSpring() = spring<T>(dampingRatio = 0.55f, stiffness = Spring.StiffnessMediumLow)
}

@Composable
fun NayaraTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit,
) {
    val nayaraColors = if (darkTheme) NayaraDarkColors else NayaraLightColors
    CompositionLocalProvider(LocalNayaraColors provides nayaraColors) {
        MaterialTheme(
            colorScheme = if (darkTheme) DarkScheme else LightScheme,
            typography = NayaraTypography,
            shapes = NayaraShapes,
            content = content,
        )
    }
}

/** Convenience accessor: `MaterialTheme.nayara.rewardPoints` etc. */
val MaterialTheme.nayara: NayaraColors
    @Composable @ReadOnlyComposable
    get() = LocalNayaraColors.current
