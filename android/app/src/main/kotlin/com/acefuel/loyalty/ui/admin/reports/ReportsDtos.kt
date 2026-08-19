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
    // False when the operator never configured a cash value per point: every
    // redemption then stored a NULL ₹, so `gifts` must render "—", not "₹0".
    // Defaults true so an older server (which omits the field) keeps its behaviour.
    @SerialName("reward_value_configured") val rewardValueConfigured: Boolean = true,
    val rows: List<ReportRowDto> = emptyList(),
    val totals: ReportTotalsDto = ReportTotalsDto(),
)

@Serializable
data class ReportRange(val from: String? = null, val to: String? = null)

// `gifts` is the ₹ value of points redemptions ("Reward ₹"); `gift_count` is the
// number of physical campaign gifts handed over — per-customer only, 0 elsewhere.
@Serializable
data class ReportRowDto(
    val key: String,
    val label: String,
    val period: String,
    val litres: Double = 0.0,
    val amount: Double? = null,
    val discount: Double = 0.0,
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
