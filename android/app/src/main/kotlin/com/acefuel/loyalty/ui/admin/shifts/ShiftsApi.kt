package com.acefuel.loyalty.ui.admin.shifts

import retrofit2.http.Body
import retrofit2.http.GET
import retrofit2.http.PATCH
import retrofit2.http.POST
import retrofit2.http.Path

/**
 * Admin shift-template endpoints. The shared OkHttp client attaches the bearer
 * token and the base URL already ends in "/", so paths are relative
 * "api/v1/...". Request bodies use the canonical nested envelope
 * ({"shift_template":{...}}).
 */
interface ShiftsApi {

    @GET("api/v1/admin/shift_templates")
    suspend fun listShiftTemplates(): ShiftTemplatesIndexResponse

    @POST("api/v1/admin/shift_templates")
    suspend fun createShiftTemplate(@Body body: ShiftTemplateEnvelope): ShiftTemplateDto

    @PATCH("api/v1/admin/shift_templates/{id}")
    suspend fun updateShiftTemplate(
        @Path("id") id: Long,
        @Body body: ShiftTemplateEnvelope,
    ): ShiftTemplateDto
}
