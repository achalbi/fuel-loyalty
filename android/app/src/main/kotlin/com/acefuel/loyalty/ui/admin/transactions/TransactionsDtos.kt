package com.acefuel.loyalty.ui.admin.transactions

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

// ============================================================================
// Admin transactions DTOs.
// Backend serializer: app/serializers/api/v1/admin/transaction_serializer.rb
//
// Field notes (mirrors the web admin transactions screen exactly):
//   - fuel_amount is a decimal -> Double.
//   - payment_mode is the enum string value ("cash" | "credit").
//   - pump / nozzle / handled_by are nullable (helper fallbacks return nil).
//   - vehicle_number / fuel_type / vehicle_kind carry their own "…not linked /
//     unavailable" fallback strings from the serializer.
//   - phone_number is returned raw (no "+91" prefix).
//   - created_at is an ISO-8601 timestamp string.
// ============================================================================

@Serializable
data class AdminTransactionDto(
    val id: Long,
    @SerialName("customer_name") val customerName: String = "",
    @SerialName("vehicle_number") val vehicleNumber: String = "",
    @SerialName("fuel_type") val fuelType: String? = null,
    @SerialName("vehicle_kind") val vehicleKind: String? = null,
    val pump: String? = null,
    val nozzle: String? = null,
    @SerialName("fuel_amount") val fuelAmount: Double = 0.0,
    @SerialName("payment_mode") val paymentMode: String? = null,
    @SerialName("handled_by") val handledBy: String? = null,
    @SerialName("phone_number") val phoneNumber: String? = null,
    @SerialName("created_at") val createdAt: String? = null,
)

/** GET /api/v1/admin/transactions -> paged list (10/page). */
@Serializable
data class AdminTransactionsResponse(
    val transactions: List<AdminTransactionDto> = emptyList(),
    val page: Int = 1,
    @SerialName("per_page") val perPage: Int = 10,
    val total: Int = 0,
    @SerialName("has_more") val hasMore: Boolean = false,
)
