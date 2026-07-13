package com.acefuel.loyalty.ui.admin.cycles

import retrofit2.http.Body
import retrofit2.http.DELETE
import retrofit2.http.GET
import retrofit2.http.PATCH
import retrofit2.http.POST
import retrofit2.http.Path

/**
 * Shift Cycles admin endpoints. The shared OkHttp client attaches the bearer
 * token; the base URL already ends in "/", so paths are relative "api/v1/...".
 *
 * Request bodies use the canonical nested envelope ({"shift_cycle":{...}}).
 * activate/deactivate are member PATCH routes that carry no meaningful body, so
 * they are sent with an empty JSON object ([EmptyBody]) — PATCH must have a body.
 *
 * Backend: app/controllers/api/v1/admin/shift_cycles_controller.rb
 *          app/serializers/api/v1/admin/shift_cycle_serializer.rb
 *          app/controllers/api/v1/admin/shift_templates_controller.rb
 *          app/serializers/api/v1/admin/shift_template_serializer.rb
 */
interface CyclesApi {

    @GET("api/v1/admin/shift_cycles")
    suspend fun listCycles(): ShiftCyclesResponse

    @POST("api/v1/admin/shift_cycles")
    suspend fun createCycle(@Body body: ShiftCycleEnvelope): ShiftCycleDto

    @PATCH("api/v1/admin/shift_cycles/{id}")
    suspend fun updateCycle(@Path("id") id: Long, @Body body: ShiftCycleEnvelope): ShiftCycleDto

    /** 204 No Content on success (nullable body), 409 delete_restricted otherwise. */
    @DELETE("api/v1/admin/shift_cycles/{id}")
    suspend fun deleteCycle(@Path("id") id: Long): DeleteResponse?

    @PATCH("api/v1/admin/shift_cycles/{id}/activate")
    suspend fun activateCycle(@Path("id") id: Long, @Body body: EmptyBody): ShiftCycleDto

    @PATCH("api/v1/admin/shift_cycles/{id}/deactivate")
    suspend fun deactivateCycle(@Path("id") id: Long, @Body body: EmptyBody): ShiftCycleDto

    @GET("api/v1/admin/shift_templates")
    suspend fun listTemplates(): ShiftTemplatesResponse
}
