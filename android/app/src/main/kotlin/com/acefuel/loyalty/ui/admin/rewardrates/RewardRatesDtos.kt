package com.acefuel.loyalty.ui.admin.rewardrates

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

// ============================================================================
// Reward Rates DTOs — mirror of Api::V1::Admin::RewardRatesSerializer.
// GET/PATCH /api/v1/admin/reward_rates.
//
// Responses use the flat serializer shape (arrays for the per-type rows).
// Requests use the canonical nested envelope keyed by the resource group; the
// server dispatches by which group is present:
//   reward_setting > vehicle_type_reward_rates > fuel_reward_rates
// Optional numeric inputs are sent as strings so a blank value clears the
// stored value (Rails normalizes blank -> nil), matching the web forms.
// ============================================================================

// ---- Responses ----

@Serializable
data class RewardRatesResponse(
    @SerialName("reward_setting") val rewardSetting: RewardSettingDto = RewardSettingDto(),
    @SerialName("vehicle_type_reward_rates") val vehicleTypeRewardRates: List<VehicleTypeRewardRateDto> = emptyList(),
    @SerialName("fuel_reward_rates") val fuelRewardRates: List<FuelRewardRateDto> = emptyList(),
    // Present only on PATCH responses.
    val message: String? = null,
)

@Serializable
data class RewardSettingDto(
    @SerialName("rupees_per_reward_unit") val rupeesPerRewardUnit: Int? = null,
    @SerialName("cash_value_per_point") val cashValuePerPoint: Double? = null,
    @SerialName("minimum_redeemable_points") val minimumRedeemablePoints: Int? = null,
    @SerialName("rewards_paused") val rewardsPaused: Boolean = false,
    @SerialName("cash_reward_configured") val cashRewardConfigured: Boolean = false,
    @SerialName("redemption_increment") val redemptionIncrement: Int? = null,
)

/** Per-vehicle-type earn override. [rewardPointsPer100] is null when no override is set. */
@Serializable
data class VehicleTypeRewardRateDto(
    val id: Long,
    val code: String,
    val name: String,
    val label: String,
    @SerialName("reward_points_per_100") val rewardPointsPer100: Int? = null,
)

/** Per-fuel-type fallback rate. [id] is null for rows not yet persisted. */
@Serializable
data class FuelRewardRateDto(
    val id: Long? = null,
    @SerialName("fuel_type") val fuelType: String,
    val label: String,
    @SerialName("points_per_100") val pointsPer100: Int? = null,
)

// ---- Requests (nested envelopes) ----

/**
 * PATCH body. Only one group is set per request; the shared Json omits nulls
 * (explicitNulls = false), so the server dispatches to the intended branch.
 */
@Serializable
data class RewardRatesUpdateEnvelope(
    @SerialName("reward_setting") val rewardSetting: RewardSettingUpdate? = null,
    @SerialName("vehicle_type_reward_rates") val vehicleTypeRewardRates: Map<String, VehicleTypeRateUpdate>? = null,
    @SerialName("fuel_reward_rates") val fuelRewardRates: Map<String, FuelRateUpdate>? = null,
)

@Serializable
data class RewardSettingUpdate(
    @SerialName("rupees_per_reward_unit") val rupeesPerRewardUnit: String,
    @SerialName("minimum_redeemable_points") val minimumRedeemablePoints: String,
    @SerialName("cash_value_per_point") val cashValuePerPoint: String,
    @SerialName("rewards_paused") val rewardsPaused: Boolean,
)

@Serializable
data class VehicleTypeRateUpdate(
    @SerialName("reward_points_per_100") val rewardPointsPer100: String,
)

@Serializable
data class FuelRateUpdate(
    @SerialName("points_per_100") val pointsPer100: String,
)
