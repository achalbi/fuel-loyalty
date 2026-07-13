package com.acefuel.loyalty.ui.admin.vehicletypes

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

// DTOs for /api/v1/admin/vehicle_types.
// Serializer fields mirror app/serializers/api/v1/admin/vehicle_type_serializer.rb.

/** A single vehicle type row as returned by index/create/update. */
@Serializable
data class VehicleTypeDto(
    val id: Long,
    val code: String,
    val name: String,
    @SerialName("short_name") val shortName: String,
    @SerialName("app_label") val appLabel: String,
    @SerialName("app_label_source") val appLabelSource: String,
    @SerialName("icon_name") val iconName: String,
    @SerialName("minimum_redeemable_points") val minimumRedeemablePoints: Int,
    // Read-only here; managed by the fuel-reward-rates endpoint. Nullable.
    @SerialName("reward_points_per_100") val rewardPointsPer100: Int? = null,
    val active: Boolean,
    @SerialName("created_at") val createdAt: String? = null,
    @SerialName("updated_at") val updatedAt: String? = null,
)

/** GET index response: { "vehicle_types": [ ... ] }. */
@Serializable
data class VehicleTypesListResponse(
    @SerialName("vehicle_types") val vehicleTypes: List<VehicleTypeDto> = emptyList(),
)

/**
 * Editable attributes for create/update. `code` is accepted on create only and is
 * immutable on update (send null there — omitted because Json.explicitNulls = false).
 * Blank `code` on create tells the server to generate one from the name.
 */
@Serializable
data class VehicleTypeRequest(
    val name: String,
    @SerialName("short_name") val shortName: String,
    @SerialName("app_label_source") val appLabelSource: String,
    val code: String? = null,
    @SerialName("icon_name") val iconName: String,
    @SerialName("minimum_redeemable_points") val minimumRedeemablePoints: Int,
    val active: Boolean,
)

/** Nested request envelope: { "vehicle_type": { ... } }. */
@Serializable
data class VehicleTypeEnvelope(
    @SerialName("vehicle_type") val vehicleType: VehicleTypeRequest,
)

/** DELETE success response: { "id": ..., "message": "Vehicle type removed successfully." }. */
@Serializable
data class VehicleTypeDeleteResponse(
    val id: Long,
    val message: String,
)
