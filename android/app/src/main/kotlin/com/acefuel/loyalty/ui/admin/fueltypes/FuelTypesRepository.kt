package com.acefuel.loyalty.ui.admin.fueltypes

import com.acefuel.loyalty.core.network.ApiResult
import com.acefuel.loyalty.core.network.apiCall
import kotlinx.serialization.json.Json

/** Wraps [FuelTypesApi] calls into [ApiResult] via the shared [apiCall] helper. */
class FuelTypesRepository(
    private val api: FuelTypesApi,
    private val json: Json,
) {
    suspend fun loadFuelTypes(): ApiResult<List<FuelTypeDto>> =
        apiCall(json) { api.listFuelTypes().fuelTypes }

    suspend fun createFuelType(name: String, active: Boolean): ApiResult<FuelTypeDto> =
        apiCall(json) { api.createFuelType(FuelTypeEnvelope(FuelTypeRequest(name = name, active = active))) }

    suspend fun updateFuelType(id: Long, name: String, active: Boolean): ApiResult<FuelTypeDto> =
        apiCall(json) { api.updateFuelType(id, FuelTypeEnvelope(FuelTypeRequest(name = name, active = active))) }

    suspend fun deleteFuelType(id: Long): ApiResult<DeleteFuelTypeResponse> =
        apiCall(json) { api.deleteFuelType(id) }
}
