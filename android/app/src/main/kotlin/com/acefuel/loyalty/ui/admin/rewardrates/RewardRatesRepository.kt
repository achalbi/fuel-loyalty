package com.acefuel.loyalty.ui.admin.rewardrates

import com.acefuel.loyalty.core.network.ApiResult
import com.acefuel.loyalty.core.network.apiCall
import kotlinx.serialization.json.Json

/**
 * Reward-rate settings: a single load plus three independent save flows, one per
 * param group. Each save wraps its group in the shared envelope so the server
 * dispatches to the matching branch.
 */
class RewardRatesRepository(
    private val api: RewardRatesApi,
    private val json: Json,
) {
    suspend fun load(): ApiResult<RewardRatesResponse> =
        apiCall(json) { api.getRewardRates() }

    suspend fun saveRewardSetting(update: RewardSettingUpdate): ApiResult<RewardRatesResponse> =
        apiCall(json) { api.updateRewardRates(RewardRatesUpdateEnvelope(rewardSetting = update)) }

    suspend fun saveVehicleTypeRates(rates: Map<String, VehicleTypeRateUpdate>): ApiResult<RewardRatesResponse> =
        apiCall(json) { api.updateRewardRates(RewardRatesUpdateEnvelope(vehicleTypeRewardRates = rates)) }

    suspend fun saveFuelRates(rates: Map<String, FuelRateUpdate>): ApiResult<RewardRatesResponse> =
        apiCall(json) { api.updateRewardRates(RewardRatesUpdateEnvelope(fuelRewardRates = rates)) }
}
