package com.acefuel.loyalty.ui.admin.transactions

import com.acefuel.loyalty.core.network.ApiResult
import com.acefuel.loyalty.core.network.apiCall
import kotlinx.serialization.json.Json

/** Wraps [TransactionsApi] calls into [ApiResult] via the shared [apiCall] helper. */
class TransactionsRepository(
    private val api: TransactionsApi,
    private val json: Json,
) {
    suspend fun loadTransactions(
        range: String?,
        sort: String?,
        startDate: String?,
        endDate: String?,
        page: Int,
    ): ApiResult<AdminTransactionsResponse> =
        apiCall(json) { api.listTransactions(range, sort, startDate, endDate, page) }
}
