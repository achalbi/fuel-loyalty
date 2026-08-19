package com.acefuel.loyalty.ui.admin.settlements

import com.acefuel.loyalty.ui.settlement.NozzleReadingDto
import com.acefuel.loyalty.ui.settlement.SettlementDiscountDto
import com.acefuel.loyalty.ui.settlement.SettlementSummaryDto
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonObject

// D9 admin settlement console DTOs. Backend:
//   app/controllers/api/v1/admin/settlements_controller.rb
//   app/serializers/api/v1/staff/settlement_serializer.rb
//   app/serializers/api/v1/admin/settlement_change_serializer.rb
@Serializable
data class AdminSettlementListResponse(
    val settlements: List<SettlementSummaryDto> = emptyList(),
    val total: Int = 0,
    @SerialName("cross_pump_totals") val crossPumpTotals: CrossPumpTotalsDto? = null,
    // Admin-12 — the listed day split per FSM, plus the option list for the
    // "recorded by" filter. The options come from the settlements themselves so
    // they include admins; an admin-recorded sheet would otherwise be
    // unreachable by every value of the filter.
    @SerialName("per_fsm_totals") val perFsmTotals: List<PerFsmTotalsDto> = emptyList(),
    @SerialName("fsm_options") val fsmOptions: List<FsmOptionDto> = emptyList(),
    // Which recorder the rows were narrowed to, or null when the list is every
    // FSM's. crossPumpTotals spans every pump but only this FSM, so the card
    // that renders it has to say so.
    @SerialName("filtered_by") val filteredBy: SettlementFilterDto? = null,
)

/** Non-null iff a `recorded_by_id` filter was applied; fsmName is null if no user matched the id. */
@Serializable
data class SettlementFilterDto(
    @SerialName("recorded_by_id") val recordedById: Long? = null,
    @SerialName("fsm_name") val fsmName: String? = null,
) {
    /** " · Priya only" / " · one FSM only" — the same qualifier the web heading appends. */
    fun labelSuffix(): String = " · ${fsmName ?: "one FSM"} only"
}

@Serializable
data class PerFsmTotalsDto(
    @SerialName("recorded_by_id") val recordedByUserId: Long? = null,
    @SerialName("fsm_name") val fsmName: String? = null,
    @SerialName("settlement_count") val settlementCount: Int = 0,
    // Same ₹ field set as the cross-pump card — both come from
    // DailySettlement::FINANCIAL_TOTAL_FIELDS.
    val totals: CrossPumpTotalsDto = CrossPumpTotalsDto(),
)

@Serializable
data class FsmOptionDto(val id: Long, val name: String)

@Serializable
data class CrossPumpTotalsDto(
    @SerialName("total_fuel_amount") val totalFuelAmount: Double = 0.0,
    @SerialName("total_lube_amount") val totalLubeAmount: Double = 0.0,
    @SerialName("total_discount_amount") val totalDiscountAmount: Double = 0.0,
    @SerialName("total_credit_amount") val totalCreditAmount: Double = 0.0,
    @SerialName("final_amount_to_settle") val finalAmountToSettle: Double = 0.0,
    @SerialName("counted_cash_amount") val countedCashAmount: Double = 0.0,
    @SerialName("shortage_amount") val shortageAmount: Double = 0.0,
)

// The admin show payload = the full settlement serializer + a changes[] array.
@Serializable
data class AdminSettlementDto(
    val id: Long,
    @SerialName("business_date") val businessDate: String,
    val status: String,
    val locked: Boolean = false,
    @SerialName("fuel_pump") val fuelPump: String? = null,
    @SerialName("fsm_name") val fsmName: String? = null,
    // Staff feedback item 3 — the admin who typed the sheet, when one did. The
    // sheet is still the FSM's above. Branch on enteredByUserId to decide
    // whether to show it, not on enteredOnBehalf: an admin who enters a sheet
    // under their own name reads false there but is exactly the case that must
    // stay visible, because reconcile is still permitted on it.
    @SerialName("entered_by_id") val enteredByUserId: Long? = null,
    @SerialName("entered_by_name") val enteredByName: String? = null,
    @SerialName("entered_on_behalf") val enteredOnBehalf: Boolean = false,
    @SerialName("total_fuel_amount") val totalFuelAmount: Double = 0.0,
    @SerialName("total_discount_amount") val totalDiscountAmount: Double = 0.0,
    @SerialName("total_credit_amount") val totalCreditAmount: Double = 0.0,
    @SerialName("final_amount_to_settle") val finalAmountToSettle: Double = 0.0,
    @SerialName("counted_cash_amount") val countedCashAmount: Double = 0.0,
    @SerialName("shortage_amount") val shortageAmount: Double = 0.0,
    @SerialName("nozzle_readings") val nozzleReadings: List<NozzleReadingDto> = emptyList(),
    @SerialName("discount_lines") val discountLines: List<SettlementDiscountDto> = emptyList(),
    val changes: List<SettlementChangeDto> = emptyList(),
)

/** "R. Kumar · entered by Admin Boss" — the same line the web show page renders. */
fun AdminSettlementDto.attributionLabel(): String {
    val fsm = fsmName ?: "—"
    if (enteredByUserId == null) return fsm
    val enterer = enteredByName ?: "an admin"
    return if (enteredOnBehalf) "$fsm · entered by $enterer" else "$fsm · entered by $enterer (as admin)"
}

@Serializable
data class SettlementChangeDto(
    val id: Long,
    @SerialName("changed_by") val changedBy: String? = null,
    // The FSM an admin entered the edit for; null when the admin acted as himself.
    @SerialName("on_behalf_of") val onBehalfOf: String? = null,
    @SerialName("change_reason") val changeReason: String,
    @SerialName("recomputed_points") val recomputedPoints: Boolean = false,
    @SerialName("field_diffs") val fieldDiffs: JsonObject? = null,
    @SerialName("created_at") val createdAt: String? = null,
)
