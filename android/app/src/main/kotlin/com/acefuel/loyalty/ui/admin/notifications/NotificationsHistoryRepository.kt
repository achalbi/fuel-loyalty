package com.acefuel.loyalty.ui.admin.notifications

import com.acefuel.loyalty.core.network.ApiResult
import com.acefuel.loyalty.core.network.apiCall
import kotlinx.serialization.json.Json

/** Wraps [NotificationsHistoryApi] calls into [ApiResult] via [apiCall]. */
class NotificationsHistoryRepository(
    private val api: NotificationsHistoryApi,
    private val json: Json,
) {
    suspend fun list(): ApiResult<List<NotificationMessageDto>> =
        apiCall(json) { api.list().notifications }

    suspend fun recipients(id: Long): ApiResult<List<NotificationRecipientDto>> =
        apiCall(json) { api.recipients(id).recipients }
}
