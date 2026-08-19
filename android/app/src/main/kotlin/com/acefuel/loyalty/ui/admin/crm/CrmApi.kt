package com.acefuel.loyalty.ui.admin.crm

import retrofit2.http.Body
import retrofit2.http.GET
import retrofit2.http.POST
import retrofit2.http.Path
import retrofit2.http.Query

/**
 * Phase 4 CRM intelligence endpoints. Bearer token attached by the shared client.
 * Insight, contact logs and churn are admin-scoped; feedbacks live under the
 * staff namespace (the staff token works, and so does an admin one).
 */
interface CrmApi {
    /**
     * Item 4 — the admin cohort: customers over a visit / litres / discount /
     * contact / points threshold. Admin-only (staff tokens get a 403), which is
     * why it lives here and not on AceFuelApi.
     *
     * Thresholds are sent as strings so a decimal litres or rupee figure survives
     * exactly as typed; the server parses them and drops anything blank or
     * unparseable rather than erroring.
     */
    @GET("api/v1/admin/customers")
    suspend fun customerCohort(
        @Query("q") query: String? = null,
        @Query("status") status: String? = null,
        @Query("type") customerType: String? = null,
        @Query("preset") preset: String? = null,
        @Query("start_date") startDate: String? = null,
        @Query("end_date") endDate: String? = null,
        @Query("min_visits") minVisits: String? = null,
        @Query("min_litres") minLitres: String? = null,
        @Query("min_discount") minDiscount: String? = null,
        @Query("min_contacts") minContacts: String? = null,
        @Query("min_points_earned") minPointsEarned: String? = null,
        @Query("min_points_balance") minPointsBalance: String? = null,
        @Query("page") page: Int? = null,
        @Query("per_page") perPage: Int? = null,
    ): CustomerCohortResponse

    @GET("api/v1/admin/customers/{id}/insight")
    suspend fun insight(@Path("id") id: Long): InsightDto

    @GET("api/v1/admin/customers/{id}/contact_logs")
    suspend fun contactLogs(@Path("id") id: Long): ContactLogListResponse

    @POST("api/v1/admin/customers/{id}/contact_logs")
    suspend fun createContactLog(
        @Path("id") id: Long,
        @Body body: ContactLogRequest,
    ): ContactLogDto

    @GET("api/v1/admin/dashboard/churn")
    suspend fun churn(
        @Query("start_date") startDate: String? = null,
        @Query("end_date") endDate: String? = null,
        @Query("preset") preset: String? = null,
        @Query("page") page: Int? = null,
        @Query("per_page") perPage: Int? = null,
    ): ChurnResponse

    @GET("api/v1/staff/customers/{id}/feedbacks")
    suspend fun feedbacks(@Path("id") id: Long): FeedbackListResponse

    @POST("api/v1/staff/customers/{id}/feedbacks")
    suspend fun createFeedback(
        @Path("id") id: Long,
        @Body body: FeedbackRequest,
    ): FeedbackDto
}
