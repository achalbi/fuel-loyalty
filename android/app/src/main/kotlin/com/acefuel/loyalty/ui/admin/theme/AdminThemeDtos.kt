package com.acefuel.loyalty.ui.admin.theme

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * Response for GET/PATCH /api/v1/admin/theme_settings.
 *
 * GET returns { primary_color, updated_at }; PATCH returns the same plus a
 * human-facing [message] ("Theme color updated successfully."). One DTO covers
 * both since the Json is configured with ignoreUnknownKeys + explicitNulls=false.
 */
@Serializable
data class ThemeSettingsDto(
    @SerialName("primary_color") val primaryColor: String,
    @SerialName("updated_at") val updatedAt: String? = null,
    val message: String? = null,
)

/** Canonical nested request body: { "theme_setting": { "primary_color": "#RRGGBB" } }. */
@Serializable
data class ThemeSettingRequest(
    @SerialName("primary_color") val primaryColor: String,
)

@Serializable
data class ThemeSettingEnvelope(
    @SerialName("theme_setting") val themeSetting: ThemeSettingRequest,
)
