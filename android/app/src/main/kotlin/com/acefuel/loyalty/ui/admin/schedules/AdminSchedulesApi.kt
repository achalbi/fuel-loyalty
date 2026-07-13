package com.acefuel.loyalty.ui.admin.schedules

import retrofit2.http.Body
import retrofit2.http.DELETE
import retrofit2.http.GET
import retrofit2.http.PATCH
import retrofit2.http.POST
import retrofit2.http.Path

/**
 * Retrofit interface for the admin push-notification endpoints.
 *
 * Mirrors Api::V1::Admin::SchedulesController + NotificationsController:
 *  - schedules index/create/update/destroy + member `send_now`
 *  - collection `schedules/run` (lease-guarded cron sweep)
 *  - ad-hoc `notifications/send`
 *
 * Write bodies use the canonical nested envelope (`notification_schedule[…]`,
 * `notification[…]`); the shared client attaches the bearer token.
 */
interface AdminSchedulesApi {

    @GET("api/v1/admin/schedules")
    suspend fun listSchedules(): SchedulesListResponse

    @POST("api/v1/admin/schedules")
    suspend fun createSchedule(@Body body: ScheduleEnvelope): ScheduleDto

    @PATCH("api/v1/admin/schedules/{id}")
    suspend fun updateSchedule(@Path("id") id: Long, @Body body: ScheduleEnvelope): ScheduleDto

    @DELETE("api/v1/admin/schedules/{id}")
    suspend fun deleteSchedule(@Path("id") id: Long)

    @POST("api/v1/admin/schedules/{id}/send_now")
    suspend fun sendNow(@Path("id") id: Long): SendNowResponse

    @POST("api/v1/admin/schedules/run")
    suspend fun runScheduler(): RunResultDto

    @POST("api/v1/admin/notifications/send")
    suspend fun sendNotification(@Body body: NotificationEnvelope): DeliveryResultDto
}
