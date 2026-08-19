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
data class ReceiptRow(val label: String = "", val amount: String = "", val existingId: Long? = null)

/**
 * A discount the FSM enters during settlement because it was missed at capture
 * (staff feedback item 11). Distinct from [DiscountRow], which is pulled from a
 * visit entry and is read-only here.
 */
data class ManualDiscountRow(
    val transport: String = "",
    val litres: String = "",
    val discount: String = "",
    val existingId: Long? = null,
)
data class ExpenseRow(val description: String = "", val amount: String = "", val existingId: Long? = null)
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
    val addedDiscounts: List<ManualDiscountRow> = emptyList(),
    val receipts: List<ReceiptRow> = emptyList(),
    val expenses: List<ExpenseRow> = emptyList(),
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
    val totalDiscount: Double get() = discounts.sumOf { it.discount } + addedDiscounts.sumOf { d(it.discount) }
    val totalCredit: Double get() = credits.sumOf { d(it.amount) }
    val totalReceipts: Double get() = receipts.sumOf { d(it.amount) }
    val totalExpenses: Double get() = expenses.sumOf { d(it.amount) }
    val countedCash: Double get() = denoms.sumOf { (it.qty.toIntOrNull() ?: 0).toDouble() * it.denomination }
    val finalToSettle: Double get() = totalFuel + totalLube - (totalDiscount + totalCredit + totalReceipts + totalExpenses)
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
                    if (existing != null) {
                        // Saved settlements only carry the rows that survived (the
                        // server drops zero-quantity lube/denomination lines), so
                        // pass the draft's full grids through to fill the gaps.
                        loadExisting(
                            existing,
                            lubeCatalog = draft.data.lubeProducts.map { LubeRow(it.productId, it.name, it.unitPrice ?: 0.0) },
                            denominations = draft.data.denominations,
                            defaultReceiptLabels = draft.data.defaultDigitalReceiptLabels,
                        )
                    } else {
                        hydrateDraft(draft.data)
                    }
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
                receipts = draft.defaultDigitalReceiptLabels.map { ReceiptRow(label = it) } + ReceiptRow(),
                expenses = listOf(ExpenseRow()),
                stock = fuelCodes(draft).map { StockRow(it) },
                rates = fuelRates(draft),
            )
        }
    }

    private fun loadExisting(
        id: Long,
        lubeCatalog: List<LubeRow>,
        denominations: List<Int>,
        defaultReceiptLabels: List<String>,
    ) {
        viewModelScope.launch {
            when (val res = repository.show(id)) {
                is ApiResult.Success -> hydrateDetail(res.data, lubeCatalog, denominations, defaultReceiptLabels)
                is ApiResult.Error -> _state.update { it.copy(loading = false, error = res.message) }
                is ApiResult.NetworkError -> _state.update { it.copy(loading = false, error = "Couldn't reach the server. Try again.") }
            }
        }
    }

    /**
     * Rebuild the form from a saved settlement. `lubeCatalog` and `denominations`
     * are the full grids the form should show; the saved rows are merged onto
     * them so a lube or denomination left at zero (and therefore not persisted)
     * still has a row to type into.
     */
    private fun hydrateDetail(
        d: SettlementDetailDto,
        lubeCatalog: List<LubeRow>,
        denominations: List<Int>,
        defaultReceiptLabels: List<String>,
    ) {
        val savedLubes = d.lubeLines.associateBy { it.productId }
        val savedDenoms = d.cashDenominations.associateBy { it.denomination }
        _state.update {
            SettlementUiState(
                loading = false,
                settlementId = d.id,
                locked = d.locked,
                businessDate = d.businessDate,
                fuelPumpId = d.fuelPumpId,
                pumpName = d.fuelPump,
                fsmName = d.fsmName,
                receipts = mergeReceipts(d, defaultReceiptLabels),
                expenses = d.expenseLines.map { ExpenseRow(it.description, trimNum(it.amount), it.id) } + ExpenseRow(),
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
                lubes = mergeLubes(lubeCatalog, d, savedLubes),
                discounts = d.discountLines.filter { it.visitEntryId != null }
                    .map { DiscountRow(it.visitEntryId, it.transportName, it.litres, it.discountAmount, it.driverName, it.id) },
                addedDiscounts = d.discountLines.filter { it.visitEntryId == null }
                    .map { ManualDiscountRow(it.transportName ?: "", trimNum(it.litres), trimNum(it.discountAmount), it.id) },
                credits = d.creditLines.map { CreditRow(it.creditType, trimNum(it.litres), trimNum(it.amount), it.reference ?: "", it.id) }.ifEmpty { listOf(CreditRow()) },
                denoms = mergeDenoms(denominations, savedDenoms),
                stock = d.stockReceipts.map { StockRow(it.fuelTypeCode ?: "", trimNum(it.litresReceived), it.id) },
                rates = d.rateComparisons.map { RateRow(it.fuelTypeCode ?: "", it.ownPrice ?: 0.0, it.competitorPrice?.let(::trimNum) ?: "", it.id) },
            )
        }
    }

    /**
     * The catalog's lubes, each stamped with its saved row (id + quantity) when
     * one exists. A lube the FSM sold none of has no persisted row, so it keeps
     * its zero and no id. Anything saved but no longer in the catalog is kept so
     * the figure stays visible and editable.
     */
    private fun mergeLubes(
        catalog: List<LubeRow>,
        d: SettlementDetailDto,
        saved: Map<Long, LubeLineDto>,
    ): List<LubeRow> {
        val merged = catalog.map { row ->
            val line = saved[row.productId] ?: return@map row
            row.copy(qty = line.quantity.toString(), existingId = line.id)
        }
        val catalogIds = catalog.map { it.productId }.toSet()
        val orphans = d.lubeLines.filterNot { catalogIds.contains(it.productId) }
            .map { LubeRow(it.productId, it.productName ?: "", it.unitPrice ?: 0.0, it.quantity.toString(), it.id) }
        return merged + orphans
    }

    /**
     * Saved means first (so their ids come back), then any default label that
     * wasn't used, then one spare blank row to type a new means into.
     */
    private fun mergeReceipts(d: SettlementDetailDto, defaultLabels: List<String>): List<ReceiptRow> {
        val saved = d.digitalReceipts.map { ReceiptRow(it.label, trimNum(it.amount), it.id) }
        val savedLabels = saved.map { it.label.lowercase() }.toSet()
        val unused = defaultLabels.filterNot { savedLabels.contains(it.lowercase()) }.map { ReceiptRow(label = it) }
        return saved + unused + ReceiptRow()
    }

    /** Same idea for the cash grid: every denomination keeps a row to count into. */
    private fun mergeDenoms(denominations: List<Int>, saved: Map<Int, DenominationDto>): List<DenomRow> =
        denominations.map { denom ->
            val line = saved[denom]
            DenomRow(denom, line?.quantity?.toString() ?: "0", line?.id)
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

    fun onAddedDiscountTransport(i: Int, v: String) = editAddedDiscount(i) { it.copy(transport = v) }
    fun onAddedDiscountLitres(i: Int, v: String) = editAddedDiscount(i) { it.copy(litres = v) }
    fun onAddedDiscountAmount(i: Int, v: String) = editAddedDiscount(i) { it.copy(discount = v) }
    fun addDiscount() = _state.update { it.copy(addedDiscounts = it.addedDiscounts + ManualDiscountRow()) }

    private fun editAddedDiscount(i: Int, f: (ManualDiscountRow) -> ManualDiscountRow) =
        _state.update { it.copy(addedDiscounts = it.addedDiscounts.mapIndexed { idx, r -> if (idx == i) f(r) else r }) }

    fun onReceiptLabel(i: Int, v: String) = editReceipt(i) { it.copy(label = v) }
    fun onReceiptAmount(i: Int, v: String) = editReceipt(i) { it.copy(amount = v) }
    fun addReceipt() = _state.update { it.copy(receipts = it.receipts + ReceiptRow()) }

    fun onExpenseDescription(i: Int, v: String) = editExpense(i) { it.copy(description = v) }
    fun onExpenseAmount(i: Int, v: String) = editExpense(i) { it.copy(amount = v) }
    fun addExpense() = _state.update { it.copy(expenses = it.expenses + ExpenseRow()) }

    private fun editReceipt(i: Int, f: (ReceiptRow) -> ReceiptRow) =
        _state.update { it.copy(receipts = it.receipts.mapIndexed { idx, r -> if (idx == i) f(r) else r }) }

    private fun editExpense(i: Int, f: (ExpenseRow) -> ExpenseRow) =
        _state.update { it.copy(expenses = it.expenses.mapIndexed { idx, r -> if (idx == i) f(r) else r }) }
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
                is ApiResult.Success -> {
                    // Re-read the saved settlement into the form. Without this the
                    // child rows keep the null ids they were created with, so a
                    // second submit posts them as new nested records and every
                    // reading, lube, credit and denomination is duplicated —
                    // doubling the settlement's totals.
                    hydrateDetail(
                        result.data,
                        lubeCatalog = s.lubes.map { LubeRow(it.productId, it.name, it.unitPrice) },
                        denominations = s.denoms.map { it.denomination },
                        defaultReceiptLabels = s.receipts.mapNotNull { it.label.ifBlank { null } },
                    )
                    _state.update {
                        it.copy(
                            submitting = false,
                            savedMessage = "Settlement ${result.data.status} — final ₹${format(result.data.finalAmountToSettle)}.",
                        )
                    }
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
        // Blank rows are the form's spare slots, not payments — drop them unless
        // they were already saved (in which case the row is being cleared).
        digitalReceipts = s.receipts.filter { it.label.isNotBlank() || it.existingId != null }
            .map { DigitalReceiptRequest(id = it.existingId, label = it.label, amount = it.amount.ifBlank { "0" }) },
        expenseLines = s.expenses.filter { it.description.isNotBlank() || it.existingId != null }
            .map { ExpenseLineRequest(id = it.existingId, description = it.description, amount = it.amount.ifBlank { "0" }) },
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
        } + s.addedDiscounts.filter { it.discount.isNotBlank() || it.existingId != null }.map {
            DiscountLineRequest(id = it.existingId, visitEntryId = null, transportName = it.transport.ifBlank { null },
                litres = it.litres.ifBlank { "0" }, discountAmount = it.discount.ifBlank { "0" })
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
