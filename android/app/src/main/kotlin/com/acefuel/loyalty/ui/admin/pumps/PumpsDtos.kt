package com.acefuel.loyalty.ui.admin.pumps

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

// ============================================================================
// Fuel Pumps admin DTOs.
// Backend: app/controllers/api/v1/admin/fuel_pumps_controller.rb
//          app/serializers/api/v1/admin/fuel_pump_serializer.rb
//          app/controllers/api/v1/admin/fuel_types_controller.rb
//          app/serializers/api/v1/admin/fuel_type_serializer.rb
// Timestamps are ISO-8601 strings; there are no decimals in this payload.
// ============================================================================

// ---- Responses ----

/** GET /api/v1/admin/fuel_pumps -> { fuel_pumps: [...], reward_setting: {...} } */
@Serializable
data class PumpsIndexResponse(
    @SerialName("fuel_pumps") val fuelPumps: List<FuelPumpDto> = emptyList(),
    @SerialName("reward_setting") val rewardSetting: RewardSettingDto = RewardSettingDto(),
)

@Serializable
data class FuelPumpDto(
    val id: Long,
    @SerialName("display_name") val displayName: String,
    @SerialName("sequence_number") val sequenceNumber: Int = 0,
    val active: Boolean = true,
    @SerialName("active_nozzles_count") val activeNozzlesCount: Int = 0,
    val nozzles: List<NozzleDto> = emptyList(),
    @SerialName("created_at") val createdAt: String? = null,
    @SerialName("updated_at") val updatedAt: String? = null,
)

@Serializable
data class NozzleDto(
    val id: Long,
    @SerialName("display_name") val displayName: String,
    @SerialName("sequence_number") val sequenceNumber: Int = 0,
    @SerialName("fuel_type_code") val fuelTypeCode: String,
    @SerialName("fuel_type_name") val fuelTypeName: String,
    val active: Boolean = true,
)

@Serializable
data class RewardSettingDto(
    @SerialName("nozzle_feature_enabled") val nozzleFeatureEnabled: Boolean = false,
)

/** PATCH /api/v1/admin/fuel_pumps/feature_settings -> { message, reward_setting } */
@Serializable
data class FeatureSettingsResponse(
    val message: String? = null,
    @SerialName("reward_setting") val rewardSetting: RewardSettingDto = RewardSettingDto(),
)

/** GET /api/v1/admin/fuel_types -> { fuel_types: [...] } (dropdown source). */
@Serializable
data class FuelTypesResponse(
    @SerialName("fuel_types") val fuelTypes: List<FuelTypeDto> = emptyList(),
)

@Serializable
data class FuelTypeDto(
    val id: Long,
    val code: String,
    val name: String,
    val active: Boolean = true,
    @SerialName("created_at") val createdAt: String? = null,
    @SerialName("updated_at") val updatedAt: String? = null,
)

/** DELETE /api/v1/admin/fuel_pumps/:id -> { message }. */
@Serializable
data class MessageResponse(
    val message: String? = null,
)

// ---- Requests (canonical nested envelopes) ----

@Serializable
data class FuelPumpEnvelope(
    @SerialName("fuel_pump") val fuelPump: FuelPumpRequest,
)

@Serializable
data class FuelPumpRequest(
    val active: Boolean,
    @SerialName("nozzles_attributes") val nozzlesAttributes: List<NozzleAttributesRequest>,
)

/**
 * A single accepts_nested_attributes_for row. [id] is omitted for brand-new
 * nozzles (explicitNulls=false drops nulls), sent for existing rows, and paired
 * with [destroy]=true to remove an existing nozzle.
 */
@Serializable
data class NozzleAttributesRequest(
    val id: Long? = null,
    @SerialName("fuel_type_code") val fuelTypeCode: String? = null,
    val active: Boolean? = null,
    @SerialName("_destroy") val destroy: Boolean? = null,
)

@Serializable
data class FeatureSettingsEnvelope(
    @SerialName("reward_setting") val rewardSetting: FeatureSettingsRequest,
)

@Serializable
data class FeatureSettingsRequest(
    @SerialName("nozzle_feature_enabled") val nozzleFeatureEnabled: Boolean,
)
