package com.acefuel.loyalty.ui.admin.theme

import retrofit2.http.Body
import retrofit2.http.GET
import retrofit2.http.PATCH

/**
 * Retrofit surface for the admin theme-settings singleton. Token auth is added
 * by the shared OkHttp client; this interface is created from the shared
 * Retrofit via `retrofit.create(AdminThemeApi::class.java)`.
 */
interface AdminThemeApi {

    @GET("api/v1/admin/theme_settings")
    suspend fun getThemeSettings(): ThemeSettingsDto

    @PATCH("api/v1/admin/theme_settings")
    suspend fun updateThemeSettings(@Body body: ThemeSettingEnvelope): ThemeSettingsDto
}
