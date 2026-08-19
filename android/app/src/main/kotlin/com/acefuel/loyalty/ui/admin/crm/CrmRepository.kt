package com.acefuel.loyalty.ui.admin.crm

import com.acefuel.loyalty.core.network.ApiResult
import com.acefuel.loyalty.core.network.apiCall
import kotlinx.serialization.json.Json

/** Wraps [CrmApi] into [ApiResult] via the shared [apiCall] helper. */
class CrmRepository(
    private val api: CrmApi,
    private val json: Json,
) {
    suspend fun insight(id: Long): ApiResult<InsightDto> =
        apiCall(json) { api.insight(id) }

    suspend fun contactLogs(id: Long): ApiResult<ContactLogListResponse> =
        apiCall(json) { api.contactLogs(id) }

    suspend fun createContactLog(id: Long, request: ContactLogRequest): ApiResult<ContactLogDto> =
        apiCall(json) { api.createContactLog(id, request) }

    suspend fun churn(
        startDate: String? = null,
        endDate: String? = null,
        preset: String? = null,
        page: Int? = null,
        perPage: Int? = null,
    ): ApiResult<ChurnResponse> =
        apiCall(json) { api.churn(startDate, endDate, preset, page, perPage) }

    suspend fun feedbacks(id: Long): ApiResult<FeedbackListResponse> =
        apiCall(json) { api.feedbacks(id) }

    suspend fun createFeedback(id: Long, request: FeedbackRequest): ApiResult<FeedbackDto> =
        apiCall(json) { api.createFeedback(id, request) }
}
