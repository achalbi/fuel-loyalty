package com.acefuel.loyalty.ui.admin.theme

import com.acefuel.loyalty.core.network.ApiResult
import com.acefuel.loyalty.core.network.apiCall
import kotlinx.serialization.json.Json

/**
 * Thin data layer over [AdminThemeApi]. Every method funnels through [apiCall]
 * so callers get a uniform [ApiResult] (Success / Error / NetworkError).
 */
class AdminThemeRepository(
    private val api: AdminThemeApi,
    private val json: Json,
) {
    /** Current admin-configured primary color. */
    suspend fun load(): ApiResult<ThemeSettingsDto> = apiCall(json) { api.getThemeSettings() }

    /** Persist a new primary color; [hex] must already be normalized to "#RRGGBB". */
    suspend fun update(hex: String): ApiResult<ThemeSettingsDto> = apiCall(json) {
        api.updateThemeSettings(ThemeSettingEnvelope(ThemeSettingRequest(hex)))
    }
}
