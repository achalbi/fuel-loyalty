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
import com.acefuel.loyalty.core.theme.BrandPalette

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
    // Soft cool-grey canvas so white cards separate cleanly.
    background = NayaraPalette.SurfaceCanvas,
    onBackground = NayaraLightColors.textPrimary,
    surface = NayaraLightColors.bgSurface,
    onSurface = NayaraLightColors.textPrimary,
    surfaceVariant = NayaraPalette.Neutral100,
    onSurfaceVariant = NayaraLightColors.textSecondary,
    surfaceTint = NayaraLightColors.actionPrimary,
    // M3 surface-container roles set explicitly to clean neutrals — otherwise
    // Card/Sheet/Menu fall back to Material's baseline purple-tinted greys.
    surfaceContainerLowest = NayaraPalette.White,
    surfaceContainerLow = NayaraPalette.White,
    surfaceContainer = NayaraPalette.White,
    surfaceContainerHigh = NayaraPalette.White,
    surfaceContainerHighest = NayaraPalette.White,
    surfaceBright = NayaraPalette.White,
    surfaceDim = NayaraPalette.Neutral200,
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
    // Clean dark-slate container roles (no purple tint from the M3 baseline).
    surfaceContainerLowest = NayaraPalette.SurfaceDarkLowest,
    surfaceContainerLow = NayaraPalette.DarkSurface,
    surfaceContainer = NayaraPalette.SurfaceDarkContainer,
    surfaceContainerHigh = NayaraPalette.DarkRaised,
    surfaceContainerHighest = NayaraPalette.SurfaceDarkHighest,
    surfaceBright = NayaraPalette.DarkOverlay,
    surfaceDim = NayaraPalette.DarkCanvas,
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
// Compact scale: display/headline/title trimmed ~1 step to reduce header bulk;
// body & labels kept readable (a11y). Line-heights scaled with the font sizes.
val NayaraTypography = Typography(
    displayLarge = TextStyle(fontFamily = Manrope, fontSize = 34.sp, lineHeight = 40.sp, fontWeight = FontWeight.ExtraBold, letterSpacing = (-0.5).sp),
    displayMedium = TextStyle(fontFamily = Manrope, fontSize = 28.sp, lineHeight = 34.sp, fontWeight = FontWeight.ExtraBold, letterSpacing = (-0.25).sp),
    displaySmall = TextStyle(fontFamily = Manrope, fontSize = 25.sp, lineHeight = 30.sp, fontWeight = FontWeight.ExtraBold, letterSpacing = (-0.25).sp),
    headlineLarge = TextStyle(fontFamily = Manrope, fontSize = 25.sp, lineHeight = 31.sp, fontWeight = FontWeight.Bold),
    headlineMedium = TextStyle(fontFamily = Manrope, fontSize = 22.sp, lineHeight = 28.sp, fontWeight = FontWeight.Bold),
    headlineSmall = TextStyle(fontFamily = Manrope, fontSize = 19.sp, lineHeight = 25.sp, fontWeight = FontWeight.Bold),
    titleLarge = TextStyle(fontFamily = Manrope, fontSize = 18.sp, lineHeight = 24.sp, fontWeight = FontWeight.Bold),
    titleMedium = TextStyle(fontFamily = Manrope, fontSize = 16.sp, lineHeight = 22.sp, fontWeight = FontWeight.SemiBold),
    titleSmall = TextStyle(fontFamily = Manrope, fontSize = 14.sp, lineHeight = 19.sp, fontWeight = FontWeight.SemiBold),
    bodyLarge = TextStyle(fontFamily = Manrope, fontSize = 15.sp, lineHeight = 22.sp, fontWeight = FontWeight.Normal),
    bodyMedium = TextStyle(fontFamily = Manrope, fontSize = 14.sp, lineHeight = 19.sp, fontWeight = FontWeight.Normal),
    bodySmall = TextStyle(fontFamily = Manrope, fontSize = 13.sp, lineHeight = 17.sp, fontWeight = FontWeight.Normal),
    labelLarge = TextStyle(fontFamily = Manrope, fontSize = 14.sp, lineHeight = 18.sp, fontWeight = FontWeight.SemiBold, letterSpacing = 0.1.sp),
    labelMedium = TextStyle(fontFamily = Manrope, fontSize = 12.sp, lineHeight = 16.sp, fontWeight = FontWeight.SemiBold, letterSpacing = 0.3.sp),
    labelSmall = TextStyle(fontFamily = Manrope, fontSize = 11.sp, lineHeight = 14.sp, fontWeight = FontWeight.Medium, letterSpacing = 0.3.sp),
)

/**
 * Hero numerals for points balances, litres, ₹ — Manrope, always tabular
 * (fontFeatureSettings "tnum") so digit columns never jitter as values change.
 */
object NayaraNumerals {
    private const val TABULAR = "tnum"
    val Hero = TextStyle(fontFamily = Manrope, fontSize = 38.sp, lineHeight = 42.sp, fontWeight = FontWeight.ExtraBold, letterSpacing = (-0.75).sp, fontFeatureSettings = TABULAR)
    val Large = TextStyle(fontFamily = Manrope, fontSize = 24.sp, lineHeight = 28.sp, fontWeight = FontWeight.ExtraBold, letterSpacing = (-0.25).sp, fontFeatureSettings = TABULAR)
    val Default = TextStyle(fontFamily = Manrope, fontSize = 18.sp, lineHeight = 22.sp, fontWeight = FontWeight.Bold, fontFeatureSettings = TABULAR)
}

val NayaraShapes = Shapes(
    extraSmall = RoundedCornerShape(6.dp),   // tags
    small = RoundedCornerShape(9.dp),        // chips, small controls
    medium = RoundedCornerShape(12.dp),      // buttons, inputs
    large = RoundedCornerShape(14.dp),       // cards
    extraLarge = RoundedCornerShape(24.dp),  // sheets (top corners)
)

// Compact spacing: fine steps (≤ Md) unchanged; the larger paddings/gaps and
// the semantic aliases trimmed so the whole app reads denser. HitTarget stays
// 48 (accessibility minimum).
object NayaraSpacing {
    val None = 0.dp; val Xxs = 2.dp; val Xs = 4.dp; val Sm = 8.dp
    val Md = 12.dp; val Lg = 14.dp; val Xl = 16.dp; val Xxl = 20.dp
    val X3l = 26.dp; val X4l = 32.dp; val X5l = 44.dp; val X6l = 56.dp
    val ScreenMargin = 14.dp; val Gutter = 10.dp; val CardPadding = 14.dp; val SectionGap = 18.dp
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
    brandOverride: BrandPalette? = null,
    content: @Composable () -> Unit,
) {
    val nayaraColors = if (darkTheme) NayaraDarkColors else NayaraLightColors
    val base = if (darkTheme) DarkScheme else LightScheme
    // Admin-configured brand color overrides only the primary slots; every
    // other token (surfaces, text, status, reward) stays Nayara.
    val scheme = if (brandOverride == null) base else base.copy(
        primary = brandOverride.primary,
        onPrimary = brandOverride.contrast,
        primaryContainer = if (darkTheme) brandOverride.strong else brandOverride.accent,
        onPrimaryContainer = brandOverride.contrast,
        surfaceTint = brandOverride.primary,
    )
    CompositionLocalProvider(LocalNayaraColors provides nayaraColors) {
        MaterialTheme(
            colorScheme = scheme,
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
