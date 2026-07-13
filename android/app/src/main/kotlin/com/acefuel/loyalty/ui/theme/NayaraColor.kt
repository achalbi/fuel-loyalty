package com.acefuel.loyalty.ui.theme

import androidx.compose.runtime.Immutable
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Color

// ============================================================================
// Nayara fuel-loyalty color tokens — GENERATED from docs/design/design-tokens.json
// Brand anchors (pixel-verified from the official Nayara Energy logo):
//   navy #10447C · cyan #0080A0 · green #18945C · sky #249ADF (nayaraenergy.com)
// ============================================================================

object NayaraPalette {
    // navy
    val Navy50 = Color(0xFFF1FBFF)
    val Navy100 = Color(0xFFE0F2FF)
    val Navy200 = Color(0xFFC0E1FF)
    val Navy300 = Color(0xFF9BCBFF)
    val Navy400 = Color(0xFF70AEF9)
    val Navy500 = Color(0xFF4C94E9)
    val Navy600 = Color(0xFF327BCE)
    val Navy700 = Color(0xFF1D63B0)
    val Navy800 = Color(0xFF0F4F93)
    val Navy900 = Color(0xFF10447C)
    val Navy950 = Color(0xFF052B54)
    // cyan
    val Cyan50 = Color(0xFFF0FDFF)
    val Cyan100 = Color(0xFFDEF4FD)
    val Cyan200 = Color(0xFFBDE6F5)
    val Cyan300 = Color(0xFF96D2E8)
    val Cyan400 = Color(0xFF66B7D4)
    val Cyan500 = Color(0xFF39A0C1)
    val Cyan600 = Color(0xFF0080A0)
    val Cyan700 = Color(0xFF006F8C)
    val Cyan800 = Color(0xFF005973)
    val Cyan900 = Color(0xFF00465C)
    val Cyan950 = Color(0xFF003141)
    // green
    val Green50 = Color(0xFFF0FEF5)
    val Green100 = Color(0xFFDFF7E7)
    val Green200 = Color(0xFFBEEBCE)
    val Green300 = Color(0xFF97D9B1)
    val Green400 = Color(0xFF67C18E)
    val Green500 = Color(0xFF39AA71)
    val Green600 = Color(0xFF18945C)
    val Green700 = Color(0xFF007845)
    val Green800 = Color(0xFF006235)
    val Green900 = Color(0xFF004D28)
    val Green950 = Color(0xFF00361B)
    // sky
    val Sky50 = Color(0xFFEFFCFF)
    val Sky100 = Color(0xFFDCF4FF)
    val Sky200 = Color(0xFFB9E4FF)
    val Sky300 = Color(0xFF8FD0FF)
    val Sky400 = Color(0xFF5CB4F0)
    val Sky500 = Color(0xFF249ADF)
    val Sky600 = Color(0xFF0082C6)
    val Sky700 = Color(0xFF006AA8)
    val Sky800 = Color(0xFF00558C)
    val Sky900 = Color(0xFF004370)
    val Sky950 = Color(0xFF002F50)
    // amber
    val Amber50 = Color(0xFFFFF8E8)
    val Amber100 = Color(0xFFFFECCF)
    val Amber200 = Color(0xFFFFD6A1)
    val Amber300 = Color(0xFFF8BA69)
    val Amber400 = Color(0xFFF5A524)
    val Amber500 = Color(0xFFCD7E00)
    val Amber600 = Color(0xFFAD6900)
    val Amber700 = Color(0xFF8E5400)
    val Amber800 = Color(0xFF744300)
    val Amber900 = Color(0xFF5D3300)
    val Amber950 = Color(0xFF432200)
    // red
    val Red50 = Color(0xFFFFF3F1)
    val Red100 = Color(0xFFFFE5E2)
    val Red200 = Color(0xFFFFCBC6)
    val Red300 = Color(0xFFFFA8A1)
    val Red400 = Color(0xFFFF746F)
    val Red500 = Color(0xFFFA484B)
    val Red600 = Color(0xFFDF2935)
    val Red700 = Color(0xFFBC001F)
    val Red800 = Color(0xFF9C0012)
    val Red900 = Color(0xFF7E000B)
    val Red950 = Color(0xFF5A0006)
    // neutral
    val Neutral50 = Color(0xFFF9FAFC)
    val Neutral100 = Color(0xFFF1F3F5)
    val Neutral200 = Color(0xFFE2E5E9)
    val Neutral300 = Color(0xFFD0D4D9)
    val Neutral400 = Color(0xFFA7ACB2)
    val Neutral500 = Color(0xFF838990)
    val Neutral600 = Color(0xFF636A71)
    val Neutral700 = Color(0xFF4D535B)
    val Neutral800 = Color(0xFF373E46)
    val Neutral900 = Color(0xFF232932)
    val Neutral950 = Color(0xFF111820)
    val DarkCanvas = Color(0xFF080F18)
    val DarkSurface = Color(0xFF0F1822)
    val DarkRaised = Color(0xFF18212D)
    val DarkOverlay = Color(0xFF242F3C)
    val White = Color(0xFFFFFFFF)
    val Black = Color(0xFF000000)
}

/** Full semantic color set. Access via [LocalNayaraColors] / MaterialTheme wrapper. */
@Immutable
data class NayaraColors(
    val bgCanvas: Color,
    val bgSurface: Color,
    val bgSurfaceRaised: Color,
    val bgSurfaceSunken: Color,
    val bgBrand: Color,
    val bgBrandSubtle: Color,
    val bgInverse: Color,
    val textPrimary: Color,
    val textSecondary: Color,
    val textTertiary: Color,
    val textDisabled: Color,
    val textInverse: Color,
    val textOnBrand: Color,
    val textBrand: Color,
    val textLink: Color,
    val borderSubtle: Color,
    val borderDefault: Color,
    val borderStrong: Color,
    val borderFocus: Color,
    val actionPrimary: Color,
    val actionPrimaryHover: Color,
    val actionPrimaryPressed: Color,
    val actionOnPrimary: Color,
    val actionPrimaryContainer: Color,
    val actionOnPrimaryContainer: Color,
    val actionSecondary: Color,
    val actionOnSecondary: Color,
    val actionDisabledBg: Color,
    val actionOnDisabled: Color,
    val accentDefault: Color,
    val accentOnAccent: Color,
    val accentContainer: Color,
    val accentOnContainer: Color,
    val statusSuccess: Color,
    val statusSuccessText: Color,
    val statusSuccessContainer: Color,
    val statusOnSuccessContainer: Color,
    val statusWarning: Color,
    val statusWarningText: Color,
    val statusWarningContainer: Color,
    val statusOnWarningContainer: Color,
    val statusError: Color,
    val statusErrorText: Color,
    val statusErrorContainer: Color,
    val statusOnErrorContainer: Color,
    val statusInfo: Color,
    val statusInfoContainer: Color,
    val statusOnInfoContainer: Color,
    val rewardPoints: Color,
    val rewardPointsText: Color,
    val rewardPointsContainer: Color,
    val rewardCoin: Color,
    val fuelPetrol: Color,
    val fuelDiesel: Color,
    val fuelPremium: Color,
    val tierMember: Color,
    val tierSilver: Color,
    val tierGold: Color,
    val tierPlatinum: Color,
    val overlayScrim: Color,
    val overlayHover: Color,
    val overlayPressed: Color,
)

val NayaraLightColors = NayaraColors(
    bgCanvas = Color(0xFFF9FAFC),
    bgSurface = Color(0xFFFFFFFF),
    bgSurfaceRaised = Color(0xFFFFFFFF),
    bgSurfaceSunken = Color(0xFFF1F3F5),
    bgBrand = Color(0xFF10447C),
    bgBrandSubtle = Color(0xFFF1FBFF),
    bgInverse = Color(0xFF111820),
    textPrimary = Color(0xFF111820),
    textSecondary = Color(0xFF636A71),
    textTertiary = Color(0xFF838990),
    textDisabled = Color(0xFFA7ACB2),
    textInverse = Color(0xFFFFFFFF),
    textOnBrand = Color(0xFFFFFFFF),
    textBrand = Color(0xFF1D63B0),
    textLink = Color(0xFF006AA8),
    borderSubtle = Color(0xFFF1F3F5),
    borderDefault = Color(0xFFE2E5E9),
    borderStrong = Color(0xFFD0D4D9),
    borderFocus = Color(0xFF249ADF),
    actionPrimary = Color(0xFF1D63B0),
    actionPrimaryHover = Color(0xFF0F4F93),
    actionPrimaryPressed = Color(0xFF10447C),
    actionOnPrimary = Color(0xFFFFFFFF),
    actionPrimaryContainer = Color(0xFFE0F2FF),
    actionOnPrimaryContainer = Color(0xFF10447C),
    actionSecondary = Color(0xFFF1FBFF),
    actionOnSecondary = Color(0xFF0F4F93),
    actionDisabledBg = Color(0xFFE2E5E9),
    actionOnDisabled = Color(0xFFA7ACB2),
    accentDefault = Color(0xFF0080A0),
    accentOnAccent = Color(0xFFFFFFFF),
    accentContainer = Color(0xFFDEF4FD),
    accentOnContainer = Color(0xFF00465C),
    statusSuccess = Color(0xFF18945C),
    statusSuccessText = Color(0xFF007845),
    statusSuccessContainer = Color(0xFFDFF7E7),
    statusOnSuccessContainer = Color(0xFF004D28),
    statusWarning = Color(0xFFCD7E00),
    statusWarningText = Color(0xFF744300),
    statusWarningContainer = Color(0xFFFFECCF),
    statusOnWarningContainer = Color(0xFF5D3300),
    statusError = Color(0xFFDF2935),
    statusErrorText = Color(0xFFDF2935),
    statusErrorContainer = Color(0xFFFFE5E2),
    statusOnErrorContainer = Color(0xFF7E000B),
    statusInfo = Color(0xFF0082C6),
    statusInfoContainer = Color(0xFFDCF4FF),
    statusOnInfoContainer = Color(0xFF004370),
    rewardPoints = Color(0xFFCD7E00),
    rewardPointsText = Color(0xFF744300),
    rewardPointsContainer = Color(0xFFFFF8E8),
    rewardCoin = Color(0xFFF5A524),
    fuelPetrol = Color(0xFF18945C),
    fuelDiesel = Color(0xFF1D63B0),
    fuelPremium = Color(0xFFAD6900),
    tierMember = Color(0xFF249ADF),
    tierSilver = Color(0xFFA7ACB2),
    tierGold = Color(0xFFF5A524),
    tierPlatinum = Color(0xFF373E46),
    overlayScrim = Color(8, 15, 24, 153),
    overlayHover = Color(17, 24, 32, 10),
    overlayPressed = Color(17, 24, 32, 20),
)

val NayaraDarkColors = NayaraColors(
    bgCanvas = Color(0xFF080F18),
    bgSurface = Color(0xFF0F1822),
    bgSurfaceRaised = Color(0xFF18212D),
    bgSurfaceSunken = Color(0xFF050A10),
    bgBrand = Color(0xFF10447C),
    bgBrandSubtle = Color(0xFF0D2038),
    bgInverse = Color(0xFFF9FAFC),
    textPrimary = Color(0xFFF4F7FC),
    textSecondary = Color(0xFFD0D4D9),
    textTertiary = Color(0xFFA7ACB2),
    textDisabled = Color(0xFF636A71),
    textInverse = Color(0xFF111820),
    textOnBrand = Color(0xFFFFFFFF),
    textBrand = Color(0xFF8FD0FF),
    textLink = Color(0xFF8FD0FF),
    borderSubtle = Color(0xFF18212D),
    borderDefault = Color(0xFF242F3C),
    borderStrong = Color(0xFF37424F),
    borderFocus = Color(0xFF5CB4F0),
    actionPrimary = Color(0xFF8FD0FF),
    actionPrimaryHover = Color(0xFFB9E4FF),
    actionPrimaryPressed = Color(0xFF5CB4F0),
    actionOnPrimary = Color(0xFF052B54),
    actionPrimaryContainer = Color(0xFF0F4F93),
    actionOnPrimaryContainer = Color(0xFFE0F2FF),
    actionSecondary = Color(0xFF14283F),
    actionOnSecondary = Color(0xFFB9E4FF),
    actionDisabledBg = Color(0xFF1B2531),
    actionOnDisabled = Color(0xFF636A71),
    accentDefault = Color(0xFF96D2E8),
    accentOnAccent = Color(0xFF003141),
    accentContainer = Color(0xFF00465C),
    accentOnContainer = Color(0xFFDEF4FD),
    statusSuccess = Color(0xFF97D9B1),
    statusSuccessText = Color(0xFF97D9B1),
    statusSuccessContainer = Color(0xFF004D28),
    statusOnSuccessContainer = Color(0xFFDFF7E7),
    statusWarning = Color(0xFFF8BA69),
    statusWarningText = Color(0xFFF8BA69),
    statusWarningContainer = Color(0xFF5D3300),
    statusOnWarningContainer = Color(0xFFFFECCF),
    statusError = Color(0xFFFFA8A1),
    statusErrorText = Color(0xFFFFA8A1),
    statusErrorContainer = Color(0xFF7E000B),
    statusOnErrorContainer = Color(0xFFFFE5E2),
    statusInfo = Color(0xFF8FD0FF),
    statusInfoContainer = Color(0xFF004370),
    statusOnInfoContainer = Color(0xFFDCF4FF),
    rewardPoints = Color(0xFFF8BA69),
    rewardPointsText = Color(0xFFF8BA69),
    rewardPointsContainer = Color(0xFF2B1C05),
    rewardCoin = Color(0xFFF5A524),
    fuelPetrol = Color(0xFF67C18E),
    fuelDiesel = Color(0xFF5CB4F0),
    fuelPremium = Color(0xFFF5A524),
    tierMember = Color(0xFF5CB4F0),
    tierSilver = Color(0xFFD0D4D9),
    tierGold = Color(0xFFF8BA69),
    tierPlatinum = Color(0xFFE2E5E9),
    overlayScrim = Color(0, 0, 0, 178),
    overlayHover = Color(244, 247, 252, 15),
    overlayPressed = Color(244, 247, 252, 26),
)

val LocalNayaraColors = staticCompositionLocalOf { NayaraLightColors }
