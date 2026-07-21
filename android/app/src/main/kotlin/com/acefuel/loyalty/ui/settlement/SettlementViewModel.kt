package com.acefuel.loyalty.ui.settlement

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.acefuel.loyalty.core.network.ApiResult
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

// Editable row models — the client mirrors the server's line items but never
// computes the authoritative ₹; Settlement::Calculator recomputes on submit.
data class NozzleRow(
    val nozzleId: Long,
    val label: String,
    val fuelType: String,
    val unitPrice: Double,
    val opening: String,
    val openingReadonly: Boolean,
    val openingSource: String?,
    val closing: String = "",
    val testing: String = "0",
    val rollover: Boolean = false,
    val existingId: Long? = null,
)

data class LubeRow(val productId: Long, val name: String, val unitPrice: Double, val qty: String = "0", val existingId: Long? = null)
data class DiscountRow(val visitEntryId: Long?, val transport: String?, val litres: Double, val discount: Double, val driver: String?, val existingId: Long? = null)
data class CreditRow(val type: String = "fleet_otp", val litres: String = "", val amount: String = "", val reference: String = "", val existingId: Long? = null)
data class DenomRow(val denomination: Int, val qty: String = "0", val existingId: Long? = null)
data class StockRow(val fuelTypeCode: String, val litres: String = "", val existingId: Long? = null)
data class RateRow(val fuelTypeCode: String, val ownPrice: Double, val competitor: String = "", val existingId: Long? = null)

data class SettlementUiState(
    val loading: Boolean = true,
    val submitting: Boolean = false,
    val settlementId: Long? = null,
    val locked: Boolean = false,
    val businessDate: String = "",
    val fuelPumpId: Long? = null,
    val pumpName: String? = null,
    val fsmName: String? = null,
    val nozzles: List<NozzleRow> = emptyList(),
    val lubes: List<LubeRow> = emptyList(),
    val discounts: List<DiscountRow> = emptyList(),
    val credits: List<CreditRow> = listOf(CreditRow()),
    val denoms: List<DenomRow> = emptyList(),
    val stock: List<StockRow> = emptyList(),
    val rates: List<RateRow> = emptyList(),
    val phonepePos: String = "",
    val phonepeScanner: String = "",
    val notes: String = "",
    val error: String? = null,
    val savedMessage: String? = null,
) {
    private fun d(s: String) = s.trim().toDoubleOrNull() ?: 0.0

    fun nozzleNet(row: NozzleRow): Double {
        val closing = d(row.closing)
        if (row.closing.isBlank()) return 0.0
        val net = if (row.rollover) closing - d(row.testing) else closing - d(row.opening) - d(row.testing)
        return if (net > 0) net else 0.0
    }

    val totalFuel: Double get() = nozzles.sumOf { nozzleNet(it) * it.unitPrice }
    val totalLube: Double get() = lubes.sumOf { (it.qty.toIntOrNull() ?: 0) * it.unitPrice }
    val totalDiscount: Double get() = discounts.sumOf { it.discount }
    val totalCredit: Double get() = credits.sumOf { d(it.amount) }
    val totalPhonepe: Double get() = d(phonepePos) + d(phonepeScanner)
    val countedCash: Double get() = denoms.sumOf { (it.qty.toIntOrNull() ?: 0).toDouble() * it.denomination }
    val finalToSettle: Double get() = totalFuel + totalLube - (totalDiscount + totalCredit + totalPhonepe)
    val shortage: Double get() = finalToSettle - countedCash

    val canSubmit: Boolean get() = !submitting && !loading && !locked && nozzles.any { it.closing.isNotBlank() }
}

class SettlementViewModel(
    private val repository: SettlementRepository,
    private val fuelPumpId: Long?,
    private val businessDate: String?,
) : ViewModel() {

    private val _state = MutableStateFlow(SettlementUiState())
    val state: StateFlow<SettlementUiState> = _state.asStateFlow()

    init { load() }

    private fun load() {
        _state.update { it.copy(loading = true, error = null) }
        viewModelScope.launch {
            when (val draft = repository.newDraft(fuelPumpId, businessDate)) {
                is ApiResult.Success -> {
                    val existing = draft.data.existingSettlementId
                    if (existing != null) loadExisting(existing) else hydrateDraft(draft.data)
                }
                is ApiResult.Error -> _state.update { it.copy(loading = false, error = draft.message) }
                is ApiResult.NetworkError -> _state.update { it.copy(loading = false, error = "Couldn't reach the server. Try again.") }
            }
        }
    }

    private fun hydrateDraft(draft: SettlementDraftResponse) {
        _state.update {
            SettlementUiState(
                loading = false,
                businessDate = draft.businessDate,
                fuelPumpId = draft.fuelPump?.id,
                pumpName = draft.fuelPump?.displayName,
                fsmName = draft.fsmName,
                nozzles = draft.nozzleReadings.map { n ->
                    NozzleRow(
                        nozzleId = n.fuelPumpNozzleId,
                        label = n.displayName ?: "Nozzle",
                        fuelType = n.fuelType ?: n.fuelTypeCode?.uppercase() ?: "",
                        unitPrice = n.unitPrice ?: 0.0,
                        opening = n.openingReading?.let(::trimNum) ?: "",
                        openingReadonly = n.openingSource == "prior_settlement",
                        openingSource = n.openingSource,
                    )
                },
                lubes = draft.lubeProducts.map { LubeRow(it.productId, it.name, it.unitPrice ?: 0.0) },
                discounts = draft.discountLines.map { DiscountRow(it.visitEntryId, it.transportName, it.litres, it.discountAmount, it.driverName) },
                denoms = draft.denominations.map { DenomRow(it) },
                stock = fuelCodes(draft).map { StockRow(it) },
                rates = fuelRates(draft),
            )
        }
    }

    private fun loadExisting(id: Long) {
        viewModelScope.launch {
            when (val res = repository.show(id)) {
                is ApiResult.Success -> hydrateDetail(res.data)
                is ApiResult.Error -> _state.update { it.copy(loading = false, error = res.message) }
                is ApiResult.NetworkError -> _state.update { it.copy(loading = false, error = "Couldn't reach the server. Try again.") }
            }
        }
    }

    private fun hydrateDetail(d: SettlementDetailDto) {
        _state.update {
            SettlementUiState(
                loading = false,
                settlementId = d.id,
                locked = d.locked,
                businessDate = d.businessDate,
                fuelPumpId = d.fuelPumpId,
                pumpName = d.fuelPump,
                fsmName = d.fsmName,
                phonepePos = trimNum(d.phonepePosAmount),
                phonepeScanner = trimNum(d.phonepeScannerAmount),
                notes = d.notes ?: "",
                nozzles = d.nozzleReadings.map { n ->
                    NozzleRow(
                        nozzleId = n.fuelPumpNozzleId, label = n.displayName ?: "Nozzle",
                        fuelType = n.fuelTypeCode?.uppercase() ?: "", unitPrice = n.unitPrice ?: 0.0,
                        opening = n.openingReading?.let(::trimNum) ?: "", openingReadonly = false,
                        openingSource = null, closing = n.closingReading?.let(::trimNum) ?: "",
                        testing = n.testingLitres?.let(::trimNum) ?: "0", rollover = n.rollover, existingId = n.id,
                    )
                },
                lubes = d.lubeLines.map { LubeRow(it.productId, it.productName ?: "", it.unitPrice ?: 0.0, it.quantity.toString(), it.id) },
                discounts = d.discountLines.map { DiscountRow(it.visitEntryId, it.transportName, it.litres, it.discountAmount, it.driverName, it.id) },
                credits = d.creditLines.map { CreditRow(it.creditType, trimNum(it.litres), trimNum(it.amount), it.reference ?: "", it.id) }.ifEmpty { listOf(CreditRow()) },
                denoms = d.cashDenominations.map { DenomRow(it.denomination, it.quantity.toString(), it.id) },
                stock = d.stockReceipts.map { StockRow(it.fuelTypeCode ?: "", trimNum(it.litresReceived), it.id) },
                rates = d.rateComparisons.map { RateRow(it.fuelTypeCode ?: "", it.ownPrice ?: 0.0, it.competitorPrice?.let(::trimNum) ?: "", it.id) },
            )
        }
    }

    private fun fuelCodes(draft: SettlementDraftResponse): List<String> =
        draft.nozzleReadings.mapNotNull { it.fuelTypeCode }.distinct()

    private fun fuelRates(draft: SettlementDraftResponse): List<RateRow> =
        draft.nozzleReadings
            .filter { it.fuelTypeCode != null }
            .distinctBy { it.fuelTypeCode }
            .map { RateRow(it.fuelTypeCode!!, it.unitPrice ?: 0.0) }

    // ---- field edits ----
    private fun editNozzle(i: Int, f: (NozzleRow) -> NozzleRow) =
        _state.update { it.copy(nozzles = it.nozzles.mapIndexed { idx, r -> if (idx == i) f(r) else r }) }

    fun onOpening(i: Int, v: String) = editNozzle(i) { it.copy(opening = v) }
    fun onClosing(i: Int, v: String) = editNozzle(i) { it.copy(closing = v) }
    fun onTesting(i: Int, v: String) = editNozzle(i) { it.copy(testing = v) }
    fun onRollover(i: Int, v: Boolean) = editNozzle(i) { it.copy(rollover = v) }

    fun onLubeQty(i: Int, v: String) =
        _state.update { it.copy(lubes = it.lubes.mapIndexed { idx, r -> if (idx == i) r.copy(qty = v) else r }) }

    fun onDenomQty(i: Int, v: String) =
        _state.update { it.copy(denoms = it.denoms.mapIndexed { idx, r -> if (idx == i) r.copy(qty = v) else r }) }

    fun onStockLitres(i: Int, v: String) =
        _state.update { it.copy(stock = it.stock.mapIndexed { idx, r -> if (idx == i) r.copy(litres = v) else r }) }

    fun onCompetitor(i: Int, v: String) =
        _state.update { it.copy(rates = it.rates.mapIndexed { idx, r -> if (idx == i) r.copy(competitor = v) else r }) }

    private fun editCredit(i: Int, f: (CreditRow) -> CreditRow) =
        _state.update { it.copy(credits = it.credits.mapIndexed { idx, r -> if (idx == i) f(r) else r }) }

    fun onCreditType(i: Int, v: String) = editCredit(i) { it.copy(type = v) }
    fun onCreditLitres(i: Int, v: String) = editCredit(i) { it.copy(litres = v) }
    fun onCreditAmount(i: Int, v: String) = editCredit(i) { it.copy(amount = v) }
    fun onCreditRef(i: Int, v: String) = editCredit(i) { it.copy(reference = v) }
    fun addCredit() = _state.update { it.copy(credits = it.credits + CreditRow()) }

    fun onPhonepePos(v: String) = _state.update { it.copy(phonepePos = v) }
    fun onPhonepeScanner(v: String) = _state.update { it.copy(phonepeScanner = v) }
    fun onNotes(v: String) = _state.update { it.copy(notes = v) }

    fun consumeError() = _state.update { it.copy(error = null) }
    fun consumeSaved() = _state.update { it.copy(savedMessage = null) }

    fun submit(status: String) {
        val s = _state.value
        if (s.locked || s.submitting) return
        _state.update { it.copy(submitting = true, error = null) }
        viewModelScope.launch {
            val request = buildRequest(s, status)
            val result = if (s.settlementId != null) repository.update(s.settlementId, request) else repository.create(request)
            when (result) {
                is ApiResult.Success -> _state.update {
                    it.copy(submitting = false, settlementId = result.data.id, locked = result.data.locked,
                        savedMessage = "Settlement ${result.data.status} — final ₹${format(result.data.finalAmountToSettle)}.")
                }
                is ApiResult.Error -> _state.update { it.copy(submitting = false, error = result.message) }
                is ApiResult.NetworkError -> _state.update { it.copy(submitting = false, error = "Couldn't reach the server. Try again.") }
            }
        }
    }

    private fun buildRequest(s: SettlementUiState, status: String) = SettlementRequest(
        fuelPumpId = s.fuelPumpId,
        businessDate = s.businessDate,
        status = status,
        phonepePosAmount = s.phonepePos.ifBlank { "0" },
        phonepeScannerAmount = s.phonepeScanner.ifBlank { "0" },
        notes = s.notes.ifBlank { null },
        nozzleReadings = s.nozzles.map {
            NozzleReadingRequest(
                id = it.existingId, fuelPumpNozzleId = it.nozzleId,
                openingReading = it.opening.ifBlank { null }, closingReading = it.closing.ifBlank { null },
                testingLitres = it.testing.ifBlank { "0" }, rollover = it.rollover, openingSource = it.openingSource,
            )
        },
        lubeLines = s.lubes.filter { (it.qty.toIntOrNull() ?: 0) > 0 || it.existingId != null }
            .map { LubeLineRequest(id = it.existingId, productId = it.productId, quantity = it.qty.toIntOrNull() ?: 0) },
        discountLines = s.discounts.map {
            DiscountLineRequest(id = it.existingId, visitEntryId = it.visitEntryId, transportName = it.transport,
                litres = it.litres.toString(), discountAmount = it.discount.toString())
        },
        creditLines = s.credits.filter { it.amount.isNotBlank() || it.litres.isNotBlank() || it.existingId != null }
            .map { CreditLineRequest(id = it.existingId, creditType = it.type, litres = it.litres.ifBlank { null }, amount = it.amount.ifBlank { null }, reference = it.reference.ifBlank { null }) },
        cashDenominations = s.denoms.map { DenominationRequest(id = it.existingId, denomination = it.denomination, quantity = it.qty.toIntOrNull() ?: 0) },
        stockReceipts = s.stock.filter { it.litres.isNotBlank() || it.existingId != null }
            .map { StockReceiptRequest(id = it.existingId, fuelTypeCode = it.fuelTypeCode, litresReceived = it.litres.ifBlank { "0" }) },
        rateComparisons = s.rates.filter { it.competitor.isNotBlank() || it.existingId != null }
            .map { RateComparisonRequest(id = it.existingId, fuelTypeCode = it.fuelTypeCode, competitorPrice = it.competitor.ifBlank { null }, ownPrice = it.ownPrice.toString()) },
    )

    private fun trimNum(value: Double): String = if (value % 1.0 == 0.0) value.toLong().toString() else value.toString()
    private fun format(value: Double): String = "%,.2f".format(value)
}
