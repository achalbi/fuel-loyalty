package com.acefuel.loyalty.ui.admin.campaigns

import com.acefuel.loyalty.core.network.ApiResult
import com.acefuel.loyalty.core.network.apiCall
import kotlinx.serialization.json.Json

/** Wraps [CampaignsApi] into [ApiResult] via the shared [apiCall] helper. */
class CampaignsRepository(
    private val api: CampaignsApi,
    private val json: Json,
) {
    suspend fun list(status: String? = null): ApiResult<CampaignListResponse> =
        apiCall(json) { api.list(status) }

    suspend fun show(id: Long): ApiResult<CampaignDto> = apiCall(json) { api.show(id) }

    suspend fun preview(id: Long): ApiResult<CampaignPreviewResponse> = apiCall(json) { api.preview(id) }

    suspend fun run(id: Long, notify: Boolean = true): ApiResult<CampaignRunResponse> = apiCall(json) { api.run(id, notify) }

    suspend fun activate(id: Long): ApiResult<CampaignDto> = apiCall(json) { api.activate(id) }

    suspend fun pause(id: Long): ApiResult<CampaignDto> = apiCall(json) { api.pause(id) }
}
