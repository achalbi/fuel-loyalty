package com.acefuel.loyalty.ui.admin.notifications

import retrofit2.http.GET
import retrofit2.http.Path

/**
 * Read-only notification delivery history (F2/F3). The send + schedule flows
 * live in ui/admin/schedules; this surfaces the persistent per-recipient log.
 */
interface NotificationsHistoryApi {

    @GET("api/v1/admin/notifications")
    suspend fun list(): NotificationsListResponse

    @GET("api/v1/admin/notifications/{id}/recipients")
    suspend fun recipients(@Path("id") id: Long): RecipientsResponse
}
