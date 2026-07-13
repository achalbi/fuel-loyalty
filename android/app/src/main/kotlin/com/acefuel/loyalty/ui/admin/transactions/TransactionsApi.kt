package com.acefuel.loyalty.ui.admin.transactions

import retrofit2.http.GET
import retrofit2.http.Query

/**
 * Admin transactions endpoint (read-only). The shared OkHttp client attaches the
 * bearer token; the base URL already ends in "/", so the path is relative
 * "api/v1/...".
 *
 * This feature is a paginated, read-only list — there are no request bodies and
 * therefore no nested envelopes. All filters are flat query params, matching the
 * backend controller.
 *
 * Backend: app/controllers/api/v1/admin/transactions_controller.rb
 *          app/serializers/api/v1/admin/transaction_serializer.rb
 */
interface TransactionsApi {

    /**
     * range=(all|today); sort=(time_desc|time_asc|amount_desc|amount_asc);
     * start_date/end_date as ISO "yyyy-MM-dd" (override range when present);
     * 10 per page. Unknown/blank values fall back to the controller defaults.
     */
    @GET("api/v1/admin/transactions")
    suspend fun listTransactions(
        @Query("range") range: String?,
        @Query("sort") sort: String?,
        @Query("start_date") startDate: String?,
        @Query("end_date") endDate: String?,
        @Query("page") page: Int,
    ): AdminTransactionsResponse
}
