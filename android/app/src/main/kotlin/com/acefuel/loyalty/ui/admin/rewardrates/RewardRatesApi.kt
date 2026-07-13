package com.acefuel.loyalty.ui.admin.rewardrates

import retrofit2.http.Body
import retrofit2.http.GET
import retrofit2.http.PATCH

/** Retrofit interface for the admin reward-rate settings endpoint. */
interface RewardRatesApi {

    @GET("api/v1/admin/reward_rates")
    suspend fun getRewardRates(): RewardRatesResponse

    @PATCH("api/v1/admin/reward_rates")
    suspend fun updateRewardRates(@Body body: RewardRatesUpdateEnvelope): RewardRatesResponse
}
