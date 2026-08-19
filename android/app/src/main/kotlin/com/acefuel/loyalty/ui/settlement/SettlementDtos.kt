package com.acefuel.loyalty.ui.settlement

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

// ============================================================================
// Daily Settlement DTOs (D1–D10). Backend:
//   app/controllers/api/v1/staff/settlements_controller.rb
//   app/serializers/api/v1/staff/settlement_serializer.rb
//   app/serializers/api/v1/staff/settlement_draft_serializer.rb
// Money/litres come back as JSON numbers (Double); request bodies send them as
// Strings to preserve precision (mirrors VisitEntryRequest). Every derived ₹ is
// recomputed server-side — the client never sends unit_price/amount for nozzles
// or lubes.
// ============================================================================

// ---- GET /settlements/new — the hydrated draft ----
@Serializable
data class SettlementDraftResponse(
    @SerialName("business_date") val businessDate: String,
    @SerialName("shift_template_id") val shiftTemplateId: Long? = null,
    @SerialName("fuel_pump") val fuelPump: SettlementPumpDto? = null,
    @SerialName("fsm_name") val fsmName: String? = null,
    @SerialName("existing_settlement_id") val existingSettlementId: Long? = null,
    @SerialName("nozzle_readings") val nozzleReadings: List<DraftNozzleDto> = emptyList(),
    @SerialName("discount_lines") val discountLines: List<SettlementDiscountDto> = emptyList(),
    @SerialName("lube_products") val lubeProducts: List<LubeProductDto> = emptyList(),
    val denominations: List<Int> = emptyList(),
    @SerialName("default_digital_receipt_labels") val defaultDigitalReceiptLabels: List<String> = emptyList(),
)

@Serializable
data class SettlementPumpDto(val id: Long, @SerialName("display_name") val displayName: String)

@Serializable
data class DraftNozzleDto(
    @SerialName("fuel_pump_nozzle_id") val fuelPumpNozzleId: Long,
    @SerialName("display_name") val displayName: String? = null,
    @SerialName("fuel_type_code") val fuelTypeCode: String? = null,
    @SerialName("fuel_type") val fuelType: String? = null,
    @SerialName("opening_reading") val openingReading: Double? = null,
    @SerialName("opening_source") val openingSource: String? = null,
    @SerialName("unit_price") val unitPrice: Double? = null,
)

@Serializable
data class LubeProductDto(
    @SerialName("product_id") val productId: Long,
    val name: String,
    @SerialName("unit_price") val unitPrice: Double? = null,
)

// ---- Detail / summary ----
@Serializable
data class SettlementDetailDto(
    val id: Long,
    @SerialName("business_date") val businessDate: String,
    val status: String,
    val locked: Boolean = false,
    @SerialName("fuel_pump_id") val fuelPumpId: Long? = null,
    @SerialName("fuel_pump") val fuelPump: String? = null,
    @SerialName("shift_template_id") val shiftTemplateId: Long? = null,
    @SerialName("fsm_name") val fsmName: String? = null,
    @SerialName("entered_by_id") val enteredByUserId: Long? = null,
    @SerialName("entered_by_name") val enteredByName: String? = null,
    @SerialName("entered_on_behalf") val enteredOnBehalf: Boolean = false,
    @SerialName("total_fuel_amount") val totalFuelAmount: Double = 0.0,
    @SerialName("total_lube_amount") val totalLubeAmount: Double = 0.0,
    @SerialName("total_discount_amount") val totalDiscountAmount: Double = 0.0,
    @SerialName("total_credit_amount") val totalCreditAmount: Double = 0.0,
    @SerialName("total_digital_receipt_amount") val totalDigitalReceiptAmount: Double = 0.0,
    @SerialName("total_expense_amount") val totalExpenseAmount: Double = 0.0,
    @SerialName("final_amount_to_settle") val finalAmountToSettle: Double = 0.0,
    @SerialName("counted_cash_amount") val countedCashAmount: Double = 0.0,
    @SerialName("shortage_amount") val shortageAmount: Double = 0.0,
    val notes: String? = null,
    @SerialName("nozzle_readings") val nozzleReadings: List<NozzleReadingDto> = emptyList(),
    @SerialName("lube_lines") val lubeLines: List<LubeLineDto> = emptyList(),
    @SerialName("discount_lines") val discountLines: List<SettlementDiscountDto> = emptyList(),
    @SerialName("credit_lines") val creditLines: List<CreditLineDto> = emptyList(),
    @SerialName("cash_denominations") val cashDenominations: List<DenominationDto> = emptyList(),
    @SerialName("digital_receipts") val digitalReceipts: List<DigitalReceiptDto> = emptyList(),
    @SerialName("expense_lines") val expenseLines: List<ExpenseLineDto> = emptyList(),
    @SerialName("stock_receipts") val stockReceipts: List<StockReceiptDto> = emptyList(),
    @SerialName("rate_comparisons") val rateComparisons: List<RateComparisonDto> = emptyList(),
)

@Serializable
data class SettlementSummaryDto(
    val id: Long,
    @SerialName("business_date") val businessDate: String,
    val status: String,
    val locked: Boolean = false,
    @SerialName("fuel_pump") val fuelPump: String? = null,
    // Admin-12 — who recorded the sheet. fsmName is a display snapshot taken at
    // capture and can repeat between users; recordedByUserId is what the admin
    // console groups and filters by. Both default so the staff list (which
    // shares this row type) is unaffected.
    @SerialName("fsm_name") val fsmName: String? = null,
    @SerialName("recorded_by_id") val recordedByUserId: Long? = null,
    // Staff feedback item 3 — the admin who TYPED the sheet, when one did. The
    // sheet still belongs to fsmName above and the money still rolls up under
    // recordedByUserId; this only says who filled it in. Null on the ordinary
    // FSM-recorded sheet.
    @SerialName("entered_by_id") val enteredByUserId: Long? = null,
    @SerialName("entered_by_name") val enteredByName: String? = null,
    // True only when the enterer and the FSM are different people. Do NOT use it
    // to decide whether to show the enterer — an admin who enters a sheet under
    // their OWN name reads false here but must still be visible, because entry
    // and reconciliation sitting with one person is the case the trail exists
    // for. Branch on enteredByUserId; use this only to word it.
    @SerialName("entered_on_behalf") val enteredOnBehalf: Boolean = false,
    @SerialName("total_fuel_amount") val totalFuelAmount: Double = 0.0,
    @SerialName("final_amount_to_settle") val finalAmountToSettle: Double = 0.0,
    @SerialName("shortage_amount") val shortageAmount: Double = 0.0,
) {
    /** "R. Kumar · entered by Admin Boss", or just the FSM when they typed it. */
    fun attributionLabel(): String {
        val fsm = fsmName ?: "—"
        if (enteredByUserId == null) return fsm
        val enterer = enteredByName ?: "an admin"
        return if (enteredOnBehalf) "$fsm · entered by $enterer" else "$fsm · entered by $enterer (as admin)"
    }
}

@Serializable
data class SettlementListResponse(
    val settlements: List<SettlementSummaryDto> = emptyList(),
    val total: Int = 0,
)

@Serializable
data class NozzleReadingDto(
    val id: Long? = null,
    @SerialName("fuel_pump_nozzle_id") val fuelPumpNozzleId: Long,
    @SerialName("display_name") val displayName: String? = null,
    @SerialName("fuel_type_code") val fuelTypeCode: String? = null,
    @SerialName("opening_reading") val openingReading: Double? = null,
    @SerialName("closing_reading") val closingReading: Double? = null,
    @SerialName("testing_litres") val testingLitres: Double? = null,
    val rollover: Boolean = false,
    @SerialName("net_litres_sold") val netLitresSold: Double? = null,
    @SerialName("unit_price") val unitPrice: Double? = null,
    val amount: Double? = null,
)

@Serializable
data class LubeLineDto(
    val id: Long? = null,
    @SerialName("product_id") val productId: Long,
    @SerialName("product_name") val productName: String? = null,
    val quantity: Int = 0,
    @SerialName("unit_price") val unitPrice: Double? = null,
    val amount: Double? = null,
)

@Serializable
data class SettlementDiscountDto(
    val id: Long? = null,
    @SerialName("visit_entry_id") val visitEntryId: Long? = null,
    @SerialName("transport_name") val transportName: String? = null,
    val litres: Double = 0.0,
    @SerialName("discount_amount") val discountAmount: Double = 0.0,
    @SerialName("driver_name") val driverName: String? = null,
)

@Serializable
data class CreditLineDto(
    val id: Long? = null,
    @SerialName("credit_type") val creditType: String = "fleet_otp",
    val litres: Double = 0.0,
    val amount: Double = 0.0,
    val reference: String? = null,
)

/** A digital-payment means and its ₹ total (PhonePe POS, PAYTM, …). */
@Serializable
data class DigitalReceiptDto(
    val id: Long? = null,
    val label: String,
    val amount: Double = 0.0,
)

/** Cash taken out of the day's takings — a salary advance or similar. */
@Serializable
data class ExpenseLineDto(
    val id: Long? = null,
    val description: String,
    val amount: Double = 0.0,
)

@Serializable
data class DigitalReceiptRequest(
    val id: Long? = null,
    val label: String,
    val amount: String? = null,
)

@Serializable
data class ExpenseLineRequest(
    val id: Long? = null,
    val description: String,
    val amount: String? = null,
)

@Serializable
data class DenominationDto(
    val id: Long? = null,
    val denomination: Int,
    val quantity: Int = 0,
    val amount: Double? = null,
)

@Serializable
data class StockReceiptDto(
    val id: Long? = null,
    @SerialName("fuel_type_code") val fuelTypeCode: String? = null,
    @SerialName("litres_received") val litresReceived: Double = 0.0,
)

@Serializable
data class RateComparisonDto(
    val id: Long? = null,
    @SerialName("fuel_type_code") val fuelTypeCode: String? = null,
    @SerialName("competitor_name") val competitorName: String? = null,
    @SerialName("competitor_price") val competitorPrice: Double? = null,
    @SerialName("own_price") val ownPrice: Double? = null,
)

// ============================================================================
// Record on behalf of a named FSM (staff feedback item 3, final part).
// GET  /api/v1/admin/settlements/new   — the picker, and once an FSM is named,
//                                        the very same draft the FSM would see
//                                        but hydrated against THEIR pump.
// POST /api/v1/admin/settlements       — the audited create.
// Backend: app/controllers/api/v1/admin/settlements_controller.rb
// ============================================================================

@Serializable
data class OnBehalfDraftResponse(
    // The PICKER list: active operators of BOTH roles. Not the same list as the
    // admin index's `fsm_options`, which is the backward-looking FILTER built
    // from settlements already on the books.
    @SerialName("fsm_options") val fsmOptions: List<FsmCandidateDto> = emptyList(),
    // Always the calling admin — who the sheet will record as the enterer.
    @SerialName("entered_by") val enteredBy: UserRefDto? = null,
    // Both null until recorded_by_id is supplied: the nozzles, the auto-popped
    // opening readings and the pulled discounts all depend on whose pump it is.
    @SerialName("recorded_for") val recordedFor: UserRefDto? = null,
    val draft: SettlementDraftResponse? = null,
)

@Serializable
data class FsmCandidateDto(
    val id: Long,
    val name: String,
    val role: String? = null,
    // The operator's STANDING assignment — a label for the picker row only. The
    // pump a sheet is actually built against is draft.fuelPump, which honours a
    // dated override; the two can differ, and draft.fuelPump is the truth.
    @SerialName("default_fuel_pump_id") val defaultFuelPumpId: Long? = null,
    @SerialName("default_fuel_pump") val defaultFuelPump: String? = null,
)

@Serializable
data class UserRefDto(val id: Long, val name: String)

/**
 * The on-behalf create body. `recorded_by_id` and `change_reason` are REQUIRED
 * and sit at the top level, outside the settlement object: attribution is
 * applied server-side from the resolved FSM and the authenticated admin, so a
 * client cannot post itself into recorded_by_id/entered_by_id.
 */
@Serializable
data class OnBehalfSettlementEnvelope(
    @SerialName("recorded_by_id") val recordedById: Long,
    @SerialName("change_reason") val changeReason: String,
    @SerialName("settlement") val settlement: SettlementRequest,
)

// ---- Create / update request (nested attributes; strings for precision) ----
@Serializable
data class SettlementEnvelope(@SerialName("settlement") val settlement: SettlementRequest)

@Serializable
data class SettlementRequest(
    @SerialName("fuel_pump_id") val fuelPumpId: Long? = null,
    @SerialName("business_date") val businessDate: String,
    @SerialName("shift_template_id") val shiftTemplateId: Long? = null,
    val status: String,
    val notes: String? = null,
    @SerialName("nozzle_readings_attributes") val nozzleReadings: List<NozzleReadingRequest> = emptyList(),
    @SerialName("lube_lines_attributes") val lubeLines: List<LubeLineRequest> = emptyList(),
    @SerialName("discount_lines_attributes") val discountLines: List<DiscountLineRequest> = emptyList(),
    @SerialName("credit_lines_attributes") val creditLines: List<CreditLineRequest> = emptyList(),
    @SerialName("cash_denominations_attributes") val cashDenominations: List<DenominationRequest> = emptyList(),
    @SerialName("digital_receipts_attributes") val digitalReceipts: List<DigitalReceiptRequest> = emptyList(),
    @SerialName("expense_lines_attributes") val expenseLines: List<ExpenseLineRequest> = emptyList(),
    @SerialName("stock_receipts_attributes") val stockReceipts: List<StockReceiptRequest> = emptyList(),
    @SerialName("rate_comparisons_attributes") val rateComparisons: List<RateComparisonRequest> = emptyList(),
)

@Serializable
data class NozzleReadingRequest(
    val id: Long? = null,
    @SerialName("fuel_pump_nozzle_id") val fuelPumpNozzleId: Long,
    @SerialName("opening_reading") val openingReading: String? = null,
    @SerialName("closing_reading") val closingReading: String? = null,
    @SerialName("testing_litres") val testingLitres: String? = null,
    val rollover: Boolean = false,
    @SerialName("opening_source") val openingSource: String? = null,
)

@Serializable
data class LubeLineRequest(
    val id: Long? = null,
    @SerialName("product_id") val productId: Long,
    val quantity: Int = 0,
    @SerialName("opening_stock") val openingStock: Int? = null,
    @SerialName("closing_stock") val closingStock: Int? = null,
)

@Serializable
data class DiscountLineRequest(
    val id: Long? = null,
    @SerialName("visit_entry_id") val visitEntryId: Long? = null,
    @SerialName("transport_name") val transportName: String? = null,
    val litres: String? = null,
    @SerialName("discount_amount") val discountAmount: String? = null,
)

@Serializable
data class CreditLineRequest(
    val id: Long? = null,
    @SerialName("credit_type") val creditType: String = "fleet_otp",
    val litres: String? = null,
    val amount: String? = null,
    val reference: String? = null,
)

@Serializable
data class DenominationRequest(
    val id: Long? = null,
    val denomination: Int,
    val quantity: Int = 0,
)

@Serializable
data class StockReceiptRequest(
    val id: Long? = null,
    @SerialName("fuel_type_code") val fuelTypeCode: String,
    @SerialName("litres_received") val litresReceived: String? = null,
)

@Serializable
data class RateComparisonRequest(
    val id: Long? = null,
    @SerialName("fuel_type_code") val fuelTypeCode: String,
    @SerialName("competitor_name") val competitorName: String? = null,
    @SerialName("competitor_price") val competitorPrice: String? = null,
    @SerialName("own_price") val ownPrice: String? = null,
)
