package com.acefuel.loyalty.ui.admin.reports

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

// E1 — reports payload. Backend:
//   app/controllers/api/v1/admin/reports_controller.rb
//   app/services/admin/reports/ledger_report.rb
// amount is null when no catalog price exists for the fuel (blank, not ₹0).
@Serializable
data class ReportResponse(
    val dimension: String,
    val grain: String,
    val range: ReportRange = ReportRange(),
    val filters: ReportFiltersDto = ReportFiltersDto(),
    val rows: List<ReportRowDto> = emptyList(),
    val totals: ReportTotalsDto = ReportTotalsDto(),
    /**
     * False until an operator sets a cash value per point. Every redemption then
     * stored `cash_reward_amount = NULL`, so a zero Reward ₹ is structural rather
     * than real and MUST render "—" — a "₹0" there would be a lie. Defaults to
     * FALSE, so a server old enough to omit the key degrades to the honest blank
     * rather than to an asserted ₹0; a genuinely non-zero reward still renders.
     */
    @SerialName("reward_value_configured") val rewardValueConfigured: Boolean = false,
)

@Serializable
data class ReportRange(val from: String? = null, val to: String? = null)

/**
 * The lookups the server actually queried with, already normalized — a plate
 * typed "ka 01 aa" comes back as "KA01AA". Echoed into the filter sheet so the
 * operator sees what was searched rather than what they typed.
 */
@Serializable
data class ReportFiltersDto(
    val transporter: String? = null,
    @SerialName("driver_name") val driverName: String? = null,
    @SerialName("driver_phone") val driverPhone: String? = null,
    @SerialName("vehicle_number") val vehicleNumber: String? = null,
)

@Serializable
data class ReportRowDto(
    val key: String,
    val label: String,
    val period: String,
    val litres: Double = 0.0,
    val amount: Double? = null,
    val discount: Double = 0.0,
    // `gifts` is ₹ — the cash value of points redemptions, labelled "Reward ₹" on
    // every surface (the key stays `gifts` so older clients don't break).
    // `gift_count` is a COUNT of physical campaign gifts handed over, and is
    // attributable per customer only, so it reads 0 on the other groupings.
    val gifts: Double = 0.0,
    @SerialName("gift_count") val giftCount: Int = 0,
    val visits: Int = 0,
)

@Serializable
data class ReportTotalsDto(
    val litres: Double = 0.0,
    val amount: Double = 0.0,
    val discount: Double = 0.0,
    val gifts: Double = 0.0,
    @SerialName("gift_count") val giftCount: Int = 0,
    val visits: Int = 0,
)
