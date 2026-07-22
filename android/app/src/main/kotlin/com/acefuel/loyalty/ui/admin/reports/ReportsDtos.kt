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
    val rows: List<ReportRowDto> = emptyList(),
    val totals: ReportTotalsDto = ReportTotalsDto(),
)

@Serializable
data class ReportRange(val from: String? = null, val to: String? = null)

@Serializable
data class ReportRowDto(
    val key: String,
    val label: String,
    val period: String,
    val litres: Double = 0.0,
    val amount: Double? = null,
    val discount: Double = 0.0,
    val gifts: Double = 0.0,
    val visits: Int = 0,
)

@Serializable
data class ReportTotalsDto(
    val litres: Double = 0.0,
    val amount: Double = 0.0,
    val discount: Double = 0.0,
    val gifts: Double = 0.0,
    val visits: Int = 0,
)
