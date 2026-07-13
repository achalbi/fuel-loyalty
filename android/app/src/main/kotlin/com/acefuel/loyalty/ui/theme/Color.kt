package com.acefuel.loyalty.ui.theme

// Legacy warm/green palette — retired in the Nayara token migration (2026-07).
// Kept as deprecated aliases so stray references keep compiling.
// Use NayaraPalette primitives / MaterialTheme.nayara semantics instead (docs/design/).

@Deprecated("Green is no longer the brand primary; use NayaraPalette.Green600 for success/earn")
val BrandGreen = NayaraPalette.Green600

@Deprecated("Use NayaraPalette.Green800")
val BrandGreenDark = NayaraPalette.Green800

@Deprecated("Use NayaraPalette.Green300")
val BrandGreenLight = NayaraPalette.Green300

@Deprecated("Use MaterialTheme.nayara.bgCanvas")
val LightBackground = NayaraPalette.Neutral50

@Deprecated("Use MaterialTheme.nayara.bgSurface")
val LightSurface = NayaraPalette.White

@Deprecated("Use MaterialTheme.nayara.textPrimary")
val LightOnSurface = NayaraPalette.Neutral950

@Deprecated("Use MaterialTheme.nayara.bgCanvas (dark)")
val DarkBackground = NayaraPalette.DarkCanvas

@Deprecated("Use MaterialTheme.nayara.bgSurface (dark)")
val DarkSurface = NayaraPalette.DarkSurface

@Deprecated("Use MaterialTheme.nayara.textPrimary (dark)")
val DarkOnSurface = NayaraDarkColors.textPrimary
