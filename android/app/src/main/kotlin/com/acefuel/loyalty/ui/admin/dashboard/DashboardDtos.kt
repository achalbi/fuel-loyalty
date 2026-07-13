package com.acefuel.loyalty.ui.admin.dashboard

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * Tolerant DTOs for GET /api/v1/admin/dashboard
 * (Admin::Dashboard::OverviewReport#as_json). The payload is rich; we model only
 * the fields the screen renders and lean on the shared Json { ignoreUnknownKeys }
 * config plus defaults so extra keys / missing sections never break decoding.
 */
@Serializable
data class DashboardResponse(
    val filters: DashboardFiltersDto = DashboardFiltersDto(),
    val summary: List<KpiCardDto> = emptyList(),
    val charts: DashboardChartsDto = DashboardChartsDto(),
    val rewards: RewardsSummaryDto = RewardsSummaryDto(),
    val meta: DashboardMetaDto = DashboardMetaDto(),
)

@Serializable
data class DashboardFiltersDto(
    @SerialName("start_date") val startDate: String? = null,
    @SerialName("end_date") val endDate: String? = null,
    val preset: String? = null,
    val presets: List<PresetOptionDto> = emptyList(),
    val segment: String? = null,
    val segments: List<FilterOptionDto> = emptyList(),
    @SerialName("fuel_type") val fuelType: String? = null,
    @SerialName("fuel_types") val fuelTypes: List<FilterOptionDto> = emptyList(),
)

@Serializable
data class PresetOptionDto(
    val value: String = "",
    val label: String = "",
    @SerialName("start_date") val startDate: String? = null,
    @SerialName("end_date") val endDate: String? = null,
)

@Serializable
data class FilterOptionDto(
    val value: String = "",
    val label: String = "",
)

/** One summary KPI card. `value` may be an int or decimal server-side -> Double. */
@Serializable
data class KpiCardDto(
    val key: String = "",
    val value: Double = 0.0,
    @SerialName("display_value") val displayValue: String = "",
    @SerialName("change_pct") val changePct: Double? = null,
    @SerialName("previous_value") val previousValue: Double? = null,
    val direction: String? = null,
    val breakdown: List<KpiBreakdownDto>? = null,
)

@Serializable
data class KpiBreakdownDto(
    val key: String = "",
    val label: String = "",
    val value: Double = 0.0,
    @SerialName("display_value") val displayValue: String = "",
)

/**
 * Only the simple {labels, values} series we render as horizontal bars. Other
 * chart keys in the payload (trend line series, top-customer tables, ...) are
 * ignored on decode.
 */
@Serializable
data class DashboardChartsDto(
    @SerialName("transactions_by_hour") val transactionsByHour: BarSeriesDto = BarSeriesDto(),
    @SerialName("transactions_by_day") val transactionsByDay: BarSeriesDto = BarSeriesDto(),
    @SerialName("repeat_vs_new") val repeatVsNew: BarSeriesDto = BarSeriesDto(),
    @SerialName("visits_distribution") val visitsDistribution: BarSeriesDto = BarSeriesDto(),
)

@Serializable
data class BarSeriesDto(
    val labels: List<String> = emptyList(),
    val values: List<Double> = emptyList(),
)

@Serializable
data class RewardsSummaryDto(
    @SerialName("redemption_rate") val redemptionRate: Double = 0.0,
    @SerialName("issued_points") val issuedPoints: Long = 0,
    @SerialName("redeemed_points") val redeemedPoints: Long = 0,
    val note: String? = null,
)

@Serializable
data class DashboardMetaDto(
    @SerialName("range_label") val rangeLabel: String? = null,
    @SerialName("segment_label") val segmentLabel: String? = null,
    @SerialName("fuel_type_label") val fuelTypeLabel: String? = null,
    @SerialName("generated_at") val generatedAt: String? = null,
)
