package com.acefuel.loyalty.ui.admin.campaigns

import retrofit2.http.GET
import retrofit2.http.PATCH
import retrofit2.http.POST
import retrofit2.http.Path
import retrofit2.http.Query

/** F1 admin campaign endpoints (view + operate). Bearer token attached by the client. */
interface CampaignsApi {
    @GET("api/v1/admin/campaigns")
    suspend fun list(@Query("status") status: String? = null): CampaignListResponse

    @GET("api/v1/admin/campaigns/{id}")
    suspend fun show(@Path("id") id: Long): CampaignDto

    @POST("api/v1/admin/campaigns/{id}/preview")
    suspend fun preview(@Path("id") id: Long): CampaignPreviewResponse

    @POST("api/v1/admin/campaigns/{id}/run")
    suspend fun run(@Path("id") id: Long, @Query("notify") notify: Boolean = true): CampaignRunResponse

    @PATCH("api/v1/admin/campaigns/{id}/activate")
    suspend fun activate(@Path("id") id: Long): CampaignDto

    @PATCH("api/v1/admin/campaigns/{id}/pause")
    suspend fun pause(@Path("id") id: Long): CampaignDto
}
