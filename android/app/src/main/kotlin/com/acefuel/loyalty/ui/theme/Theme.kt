package com.acefuel.loyalty.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.runtime.Composable
import com.acefuel.loyalty.core.theme.BrandPalette

/**
 * App theme, backed by the Nayara token set (docs/design/design-tokens.json).
 *
 * The admin-configurable seed keeps working: pass the server hex via
 * [primaryHex]. When unset or equal to [BrandPalette.DEFAULT_HEX] the full
 * static Nayara scheme is used; otherwise only the M3 primary slots are
 * derived from the admin color while every other token stays Nayara.
 */
@Composable
fun AceFuelLoyaltyTheme(
    primaryHex: String? = null,
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit,
) {
    val override = primaryHex
        ?.takeUnless { it.equals(BrandPalette.DEFAULT_HEX, ignoreCase = true) }
        ?.let { BrandPalette.from(it, darkTheme) }
    NayaraTheme(darkTheme = darkTheme, brandOverride = override, content = content)
}
