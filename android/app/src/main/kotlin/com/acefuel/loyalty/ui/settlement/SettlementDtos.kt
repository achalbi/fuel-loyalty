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
    @SerialName("total_fuel_amount") val totalFuelAmount: Double = 0.0,
    @SerialName("total_lube_amount") val totalLubeAmount: Double = 0.0,
    @SerialName("total_discount_amount") val totalDiscountAmount: Double = 0.0,
    @SerialName("total_credit_amount") val totalCreditAmount: Double = 0.0,
    @SerialName("final_amount_to_settle") val finalAmountToSettle: Double = 0.0,
    @SerialName("counted_cash_amount") val countedCashAmount: Double = 0.0,
    @SerialName("shortage_amount") val shortageAmount: Double = 0.0,
    @SerialName("phonepe_pos_amount") val phonepePosAmount: Double = 0.0,
    @SerialName("phonepe_scanner_amount") val phonepeScannerAmount: Double = 0.0,
    val notes: String? = null,
    @SerialName("nozzle_readings") val nozzleReadings: List<NozzleReadingDto> = emptyList(),
    @SerialName("lube_lines") val lubeLines: List<LubeLineDto> = emptyList(),
    @SerialName("discount_lines") val discountLines: List<SettlementDiscountDto> = emptyList(),
    @SerialName("credit_lines") val creditLines: List<CreditLineDto> = emptyList(),
    @SerialName("cash_denominations") val cashDenominations: List<DenominationDto> = emptyList(),
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
    @SerialName("total_fuel_amount") val totalFuelAmount: Double = 0.0,
    @SerialName("final_amount_to_settle") val finalAmountToSettle: Double = 0.0,
    @SerialName("shortage_amount") val shortageAmount: Double = 0.0,
)

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

// ---- Create / update request (nested attributes; strings for precision) ----
@Serializable
data class SettlementEnvelope(@SerialName("settlement") val settlement: SettlementRequest)

@Serializable
data class SettlementRequest(
    @SerialName("fuel_pump_id") val fuelPumpId: Long? = null,
    @SerialName("business_date") val businessDate: String,
    @SerialName("shift_template_id") val shiftTemplateId: Long? = null,
    val status: String,
    @SerialName("phonepe_pos_amount") val phonepePosAmount: String? = null,
    @SerialName("phonepe_scanner_amount") val phonepeScannerAmount: String? = null,
    val notes: String? = null,
    @SerialName("nozzle_readings_attributes") val nozzleReadings: List<NozzleReadingRequest> = emptyList(),
    @SerialName("lube_lines_attributes") val lubeLines: List<LubeLineRequest> = emptyList(),
    @SerialName("discount_lines_attributes") val discountLines: List<DiscountLineRequest> = emptyList(),
    @SerialName("credit_lines_attributes") val creditLines: List<CreditLineRequest> = emptyList(),
    @SerialName("cash_denominations_attributes") val cashDenominations: List<DenominationRequest> = emptyList(),
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
