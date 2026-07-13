package com.acefuel.loyalty.ui.admin.vehicletypes

import com.acefuel.loyalty.core.network.ApiResult
import com.acefuel.loyalty.core.network.apiCall
import kotlinx.serialization.json.Json

/** Wraps [VehicleTypesApi] calls into [ApiResult] via the shared [apiCall] helper. */
class VehicleTypesRepository(
    private val api: VehicleTypesApi,
    private val json: Json,
) {
    suspend fun list(): ApiResult<List<VehicleTypeDto>> =
        apiCall(json) { api.list().vehicleTypes }

    suspend fun create(request: VehicleTypeRequest): ApiResult<VehicleTypeDto> =
        apiCall(json) { api.create(VehicleTypeEnvelope(request)) }

    suspend fun update(id: Long, request: VehicleTypeRequest): ApiResult<VehicleTypeDto> =
        apiCall(json) { api.update(id, VehicleTypeEnvelope(request)) }

    suspend fun delete(id: Long): ApiResult<VehicleTypeDeleteResponse> =
        apiCall(json) { api.delete(id) }
}
