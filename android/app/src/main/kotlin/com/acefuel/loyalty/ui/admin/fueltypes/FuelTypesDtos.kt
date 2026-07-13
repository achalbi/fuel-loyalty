package com.acefuel.loyalty.ui.admin.fueltypes

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

// ============================================================================
// Fuel Types admin DTOs.
// Backend: app/controllers/api/v1/admin/fuel_types_controller.rb
//          app/serializers/api/v1/admin/fuel_type_serializer.rb
// Timestamps are ISO-8601 strings; there are no decimals in this payload.
// ============================================================================

// ---- Responses ----

/** GET /api/v1/admin/fuel_types -> { fuel_types: [...] } */
@Serializable
data class FuelTypesIndexResponse(
    @SerialName("fuel_types") val fuelTypes: List<FuelTypeDto> = emptyList(),
)

/**
 * A single fuel type row. `code` is auto-generated from `name` on first save
 * and immutable afterwards (shown read-only in the UI).
 * POST/PATCH return a bare object of this shape (not wrapped).
 */
@Serializable
data class FuelTypeDto(
    val id: Long,
    val code: String,
    val name: String,
    val active: Boolean = true,
    @SerialName("created_at") val createdAt: String? = null,
    @SerialName("updated_at") val updatedAt: String? = null,
)

/** DELETE /api/v1/admin/fuel_types/:id -> { id, message } (on success). */
@Serializable
data class DeleteFuelTypeResponse(
    val id: Long? = null,
    val message: String? = null,
)

// ---- Requests (canonical nested envelope) ----

@Serializable
data class FuelTypeEnvelope(
    @SerialName("fuel_type") val fuelType: FuelTypeRequest,
)

/**
 * Create/update body. `code` is intentionally omitted — the backend rejects it
 * and derives it from `name`. `active` maps to the "Show in app" switch.
 */
@Serializable
data class FuelTypeRequest(
    val name: String,
    val active: Boolean,
)
