package com.acefuel.loyalty.ui.admin.attendance

import retrofit2.http.Body
import retrofit2.http.DELETE
import retrofit2.http.GET
import retrofit2.http.PATCH
import retrofit2.http.POST
import retrofit2.http.Path
import retrofit2.http.Query

/**
 * Attendance admin endpoints. The shared OkHttp client attaches the bearer
 * token; the base URL already ends in "/", so paths are relative "api/v1/...".
 * The create body uses the canonical nested envelope ({"attendance_run":{...}}).
 */
interface AttendanceApi {

    /** filter=(all|valid|invalid); date range as ISO "yyyy-MM-dd"; 6 per page. */
    @GET("api/v1/admin/attendance_runs")
    suspend fun listRuns(
        @Query("filter") filter: String?,
        @Query("start_date") startDate: String?,
        @Query("end_date") endDate: String?,
        @Query("page") page: Int,
    ): AttendanceRunsIndexResponse

    /** Planner preview: auto-computed window + rostered staff rows (or base errors). */
    @GET("api/v1/admin/attendance_runs/new")
    suspend fun planner(
        @Query("shift_template_id") shiftTemplateId: Long,
        @Query("starts_at") startsAt: String?,
    ): AttendancePlannerResponse

    @POST("api/v1/admin/attendance_runs")
    suspend fun createRun(@Body body: AttendanceRunEnvelope): AttendanceRunDto

    @GET("api/v1/admin/attendance_runs/{id}")
    suspend fun showRun(@Path("id") id: Long): AttendanceRunDto

    @PATCH("api/v1/admin/attendance_runs/{id}/invalidate")
    suspend fun invalidateRun(@Path("id") id: Long): AttendanceRunDto

    @PATCH("api/v1/admin/attendance_runs/{id}/mark_valid")
    suspend fun markValidRun(@Path("id") id: Long): AttendanceRunDto

    @DELETE("api/v1/admin/attendance_runs/{id}")
    suspend fun deleteRun(@Path("id") id: Long): AttendanceMessageResponse

    @GET("api/v1/admin/shift_templates")
    suspend fun listShiftTemplates(): ShiftTemplatesResponse
}
