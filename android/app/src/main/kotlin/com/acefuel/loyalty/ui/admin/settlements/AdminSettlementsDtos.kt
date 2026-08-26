package com.acefuel.loyalty.ui.admin.settlements

import com.acefuel.loyalty.ui.settlement.CreditLineDto
import com.acefuel.loyalty.ui.settlement.DecantationDto
import com.acefuel.loyalty.ui.settlement.DenominationDto
import com.acefuel.loyalty.ui.settlement.DigitalReceiptDto
import com.acefuel.loyalty.ui.settlement.ExpenseLineDto
import com.acefuel.loyalty.ui.settlement.LubeLineDto
import com.acefuel.loyalty.ui.settlement.NozzleReadingDto
import com.acefuel.loyalty.ui.settlement.RateComparisonDto
import com.acefuel.loyalty.ui.settlement.SettlementDiscountDto
import com.acefuel.loyalty.ui.settlement.SettlementSummaryDto
import com.acefuel.loyalty.ui.settlement.StockReceiptDto
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
)

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
// Every child line is carried, not just the ones a summary would need: the
// console reprints the sheet the FSM filled in, and a section left out of the
// DTO is a section the reviewer silently never sees.
@Serializable
data class AdminSettlementDto(
    val id: Long,
    @SerialName("business_date") val businessDate: String,
    val status: String,
    val locked: Boolean = false,
    @SerialName("fuel_pump") val fuelPump: String? = null,
    @SerialName("fsm_name") val fsmName: String? = null,
    val notes: String? = null,
    @SerialName("total_fuel_amount") val totalFuelAmount: Double = 0.0,
    @SerialName("total_lube_amount") val totalLubeAmount: Double = 0.0,
    @SerialName("total_discount_amount") val totalDiscountAmount: Double = 0.0,
    @SerialName("total_credit_amount") val totalCreditAmount: Double = 0.0,
    @SerialName("total_digital_receipt_amount") val totalDigitalReceiptAmount: Double = 0.0,
    @SerialName("total_expense_amount") val totalExpenseAmount: Double = 0.0,
    @SerialName("final_amount_to_settle") val finalAmountToSettle: Double = 0.0,
    @SerialName("counted_cash_amount") val countedCashAmount: Double = 0.0,
    @SerialName("shortage_amount") val shortageAmount: Double = 0.0,
    @SerialName("nozzle_readings") val nozzleReadings: List<NozzleReadingDto> = emptyList(),
    @SerialName("lube_lines") val lubeLines: List<LubeLineDto> = emptyList(),
    @SerialName("discount_lines") val discountLines: List<SettlementDiscountDto> = emptyList(),
    @SerialName("credit_lines") val creditLines: List<CreditLineDto> = emptyList(),
    @SerialName("digital_receipts") val digitalReceipts: List<DigitalReceiptDto> = emptyList(),
    @SerialName("expense_lines") val expenseLines: List<ExpenseLineDto> = emptyList(),
    @SerialName("cash_denominations") val cashDenominations: List<DenominationDto> = emptyList(),
    @SerialName("stock_receipts") val stockReceipts: List<StockReceiptDto> = emptyList(),
    val decantations: List<DecantationDto> = emptyList(),
    @SerialName("rate_comparisons") val rateComparisons: List<RateComparisonDto> = emptyList(),
    val changes: List<SettlementChangeDto> = emptyList(),
)

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
