package com.acefuel.loyalty.ui.admin.settlements

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.material3.AssistChip
import androidx.compose.material3.Card
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import com.acefuel.loyalty.core.di.LocalContainer
import com.acefuel.loyalty.ui.designsystem.ChipTone
import com.acefuel.loyalty.ui.designsystem.DateField
import com.acefuel.loyalty.ui.designsystem.NayaraSnackbarHost
import com.acefuel.loyalty.ui.designsystem.NayaraTopBar
import com.acefuel.loyalty.ui.designsystem.SearchField
import com.acefuel.loyalty.ui.designsystem.SectionHeader
import com.acefuel.loyalty.ui.designsystem.StatusChip
import com.acefuel.loyalty.ui.designsystem.showError
import com.acefuel.loyalty.ui.designsystem.showSuccess
import com.acefuel.loyalty.ui.settlement.NozzleReadingDto
import com.acefuel.loyalty.ui.settlement.SettlementSummaryDto
import com.acefuel.loyalty.ui.theme.NayaraButton
import com.acefuel.loyalty.ui.theme.NayaraSpacing
import com.acefuel.loyalty.ui.theme.nayara
import java.time.LocalDate
import java.time.format.DateTimeFormatter

private const val BLANK = "—"

private fun money(v: Double?): String = if (v == null) BLANK else "₹" + "%,.2f".format(v)

/** Litres/readings the way they were typed: 3 dp, trailing zeros dropped. */
private fun litres(v: Double?): String =
    if (v == null) BLANK else "%.3f".format(v).trimEnd('0').trimEnd('.')

private fun price(v: Double?): String = if (v == null) BLANK else "%.2f".format(v)

// D1 — an opening the FSM typed over is the one figure on the sheet that did
// not come from the previous one, and across a stretch of unsettled days it is
// the figure a reviewer most needs to question. The web sheet keeps the
// provenance in a tooltip; a phone has nowhere to hide it, so it is spelled out
// under the row.
private const val CORRECTED_OPENING = "corrected"
private val DAY_MONTH = DateTimeFormatter.ofPattern("d MMM")

private fun correctedOpeningNote(r: NozzleReadingDto): String {
    val prior = r.priorClosingReading ?: return "Corrected by hand."
    val settledOn = r.priorClosingDate?.let { runCatching { LocalDate.parse(it) }.getOrNull() }
    return "Corrected by hand — last settled ${litres(prior)}" +
        (settledOn?.let { " on ${it.format(DAY_MONTH)}" } ?: "")
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AdminSettlementsScreen(onBack: () -> Unit) {
    val container = LocalContainer.current
    val viewModel: AdminSettlementsViewModel = viewModel(
        factory = viewModelFactory {
            initializer {
                AdminSettlementsViewModel(
                    AdminSettlementsRepository(container.retrofit.create(AdminSettlementsApi::class.java), container.json),
                )
            }
        },
    )
    val state by viewModel.state.collectAsStateWithLifecycle()
    val snackbar = remember { SnackbarHostState() }
    val inDetail = state.selected != null

    LaunchedEffect(state.error) { state.error?.let { snackbar.showError(it); viewModel.consumeError() } }
    LaunchedEffect(state.message) { state.message?.let { snackbar.showSuccess(it); viewModel.consumeMessage() } }

    BackHandler(enabled = inDetail) { viewModel.closeDetail() }

    Scaffold(
        topBar = {
            NayaraTopBar(
                title = if (inDetail) "Settlement" else "Settlements",
                onBack = { if (inDetail) viewModel.closeDetail() else onBack() },
            )
        },
        snackbarHost = { NayaraSnackbarHost(snackbar) },
    ) { padding ->
        Box(Modifier.fillMaxSize().padding(padding)) {
            when {
                inDetail -> DetailView(state, viewModel)
                else -> ListView(state, viewModel)
            }
        }
    }
}

// ============================================================================
// List — filters first. This screen is where an admin looks up a past day, and
// "which day was that?" is exactly what they do not remember: the range, the
// status and the free-text cut all have to be reachable without leaving it.
// ============================================================================

@Composable
private fun ListView(state: AdminSettlementsUiState, vm: AdminSettlementsViewModel) {
    LazyColumn(
        Modifier.fillMaxSize().padding(horizontal = NayaraSpacing.ScreenMargin),
        verticalArrangement = Arrangement.spacedBy(NayaraSpacing.Sm),
    ) {
        item { FilterBar(state, vm) }

        state.crossPumpTotals?.let { totals ->
            item {
                Card(Modifier.fillMaxWidth()) {
                    Column(Modifier.padding(NayaraSpacing.CardPadding)) {
                        Text("Cross-pump totals", fontWeight = FontWeight.SemiBold)
                        Text(
                            "Fuel ${money(totals.totalFuelAmount)} · Final ${money(totals.finalAmountToSettle)} · Shortage ${money(totals.shortageAmount)}",
                            style = MaterialTheme.typography.bodySmall,
                        )
                    }
                }
            }
        }

        when {
            state.loading -> item {
                Box(Modifier.fillMaxWidth().padding(NayaraSpacing.X4l), Alignment.Center) { CircularProgressIndicator() }
            }
            state.settlements.isEmpty() -> item {
                Text(
                    if (state.filtered) "No settlements match these filters." else "No settlements yet.",
                    Modifier.padding(NayaraSpacing.Md),
                    color = MaterialTheme.nayara.textSecondary,
                )
            }
            else -> {
                item {
                    Text(
                        "${state.settlements.size} settlement${if (state.settlements.size == 1) "" else "s"}",
                        style = MaterialTheme.typography.labelMedium,
                        color = MaterialTheme.nayara.textTertiary,
                    )
                }
                items(state.settlements) { s -> SettlementRow(s) { vm.open(s.id) } }
            }
        }
        item { Box(Modifier.padding(NayaraSpacing.Xl)) }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun FilterBar(state: AdminSettlementsUiState, vm: AdminSettlementsViewModel) {
    Column(
        Modifier.fillMaxWidth().padding(top = NayaraSpacing.Sm),
        verticalArrangement = Arrangement.spacedBy(NayaraSpacing.Sm),
    ) {
        SearchField(
            value = state.query,
            onValueChange = vm::onQuery,
            placeholder = "FSM, transporter, vehicle, driver, mobile, pump",
        )
        Row(horizontalArrangement = Arrangement.spacedBy(NayaraSpacing.Sm)) {
            DateField(
                label = "From",
                value = state.from,
                onChange = vm::onFrom,
                modifier = Modifier.weight(1f),
                placeholder = "Any",
            )
            DateField(
                label = "To",
                value = state.to,
                onChange = vm::onTo,
                modifier = Modifier.weight(1f),
                placeholder = "Any",
            )
        }
        Row(
            Modifier.horizontalScroll(rememberScrollState()),
            horizontalArrangement = Arrangement.spacedBy(NayaraSpacing.Xs),
        ) {
            val today = LocalDate.now()
            FilterChip(
                selected = state.from == null && state.to == null,
                onClick = vm::clearRange,
                label = { Text("Any date") },
            )
            SettlementRangePreset.entries.forEach { preset ->
                FilterChip(
                    selected = state.from == preset.from(today) && state.to == preset.to(today),
                    onClick = { vm.onPreset(preset) },
                    label = { Text(preset.label) },
                )
            }
        }
        Row(
            Modifier.horizontalScroll(rememberScrollState()),
            horizontalArrangement = Arrangement.spacedBy(NayaraSpacing.Xs),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            listOf("draft", "submitted", "reconciled").forEach { status ->
                FilterChip(
                    selected = state.status == status,
                    onClick = { vm.onStatus(status) },
                    label = { Text(status.replaceFirstChar { it.uppercase() }) },
                )
            }
            if (state.filtered) {
                TextButton(onClick = vm::clearFilters) { Text("Clear") }
            }
        }
    }
}

@Composable
private fun SettlementRow(s: SettlementSummaryDto, onClick: () -> Unit) {
    Card(onClick = onClick, modifier = Modifier.fillMaxWidth()) {
        Column(Modifier.padding(NayaraSpacing.CardPadding)) {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                Text("${s.fuelPump ?: "Pump"} · ${s.businessDate}", fontWeight = FontWeight.SemiBold)
                AssistChip(onClick = onClick, label = { Text(s.status) })
            }
            Text(
                listOfNotNull(
                    s.fsmName?.ifBlank { null },
                    "Final ${money(s.finalAmountToSettle)}",
                    "Shortage ${money(s.shortageAmount)}",
                ).joinToString(" · "),
                style = MaterialTheme.typography.bodySmall,
            )
        }
    }
}

// ============================================================================
// Detail — the sheet as the FSM filled it in, section for section, read-only.
// A digest cannot be checked against the paper it came from, so every section
// of the entry form appears here in the entry order, and an empty one says so
// rather than vanishing.
// ============================================================================

@Composable
private fun DetailView(state: AdminSettlementsUiState, vm: AdminSettlementsViewModel) {
    val s = state.selected ?: return
    LazyColumn(
        Modifier.fillMaxSize().padding(horizontal = NayaraSpacing.ScreenMargin),
        verticalArrangement = Arrangement.spacedBy(NayaraSpacing.Xxs),
    ) {
        item {
            Column(Modifier.padding(vertical = NayaraSpacing.Sm)) {
                Text("${s.fuelPump ?: "Pump"} · ${s.businessDate}", style = MaterialTheme.typography.titleMedium)
                Text(
                    "Status: ${s.status}${if (s.locked) " · locked" else ""} · FSM ${s.fsmName ?: BLANK}",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.nayara.textSecondary,
                )
            }
        }

        // 1 — Nozzle readings (D1)
        item { SectionHeader("Nozzle readings") }
        if (s.nozzleReadings.isEmpty()) {
            item { EmptySection("No nozzle readings recorded.") }
        } else {
            items(s.nozzleReadings) { r ->
                SheetCard(
                    title = listOfNotNull(r.displayName, r.fuelTypeCode?.uppercase()).joinToString(" · ").ifBlank { "Nozzle" },
                ) {
                    SheetRow(
                        "Opening", litres(r.openingReading),
                        flag = if (r.openingSource == CORRECTED_OPENING) "edited" else null,
                    )
                    if (r.openingSource == CORRECTED_OPENING) SheetNote(correctedOpeningNote(r))
                    SheetRow("Closing", litres(r.closingReading))
                    SheetRow("Testing", litres(r.testingLitres))
                    if (r.rollover) SheetRow("Rollover", "Yes")
                    SheetRow("Net litres", litres(r.netLitresSold))
                    SheetRow("₹/L", money(r.unitPrice))
                    SheetRow("Amount", money(r.amount), emphasis = true)
                }
            }
        }

        // 2 — Lubricants (D2)
        item { SectionHeader("Lubricants & oils") }
        if (s.lubeLines.isEmpty()) {
            item { EmptySection("No lubricants sold.") }
        } else {
            items(s.lubeLines) { l ->
                SheetCard(title = l.productName ?: "Lubricant") {
                    SheetRow("Qty × ₹ each", "${l.quantity} × ${money(l.unitPrice)}")
                    SheetRow("Amount", money(l.amount), emphasis = true)
                    if (l.openingStock != null || l.closingStock != null) {
                        SheetRow("Stock open → close", "${l.openingStock ?: BLANK} → ${l.closingStock ?: BLANK}")
                    }
                }
            }
        }

        // 3 — Discounts (D3)
        item { SectionHeader("Discounts") }
        if (s.discountLines.isEmpty()) {
            item { EmptySection("No same-day discounts captured for this pump.") }
        } else {
            items(s.discountLines) { d ->
                SheetCard(title = d.transportName?.ifBlank { null } ?: d.driverName?.ifBlank { null } ?: BLANK) {
                    // Searchable by rule 17, so it has to be readable here too.
                    if (!d.vehicleNumber.isNullOrBlank()) SheetRow("Vehicle", d.vehicleNumber)
                    if (!d.driverName.isNullOrBlank()) SheetRow("Driver", d.driverName)
                    if (!d.driverPhoneNumber.isNullOrBlank()) SheetRow("Driver mobile", d.driverPhoneNumber)
                    SheetRow("Litres", litres(d.litres))
                    SheetRow("Discount", money(d.discountAmount), emphasis = true)
                    if (d.visitEntryId == null) SheetRow("Source", "Added at settlement")
                }
            }
        }

        // 4 — Digital receipts (D4)
        item { SectionHeader("Digital receipts") }
        if (s.digitalReceipts.isEmpty()) {
            item { EmptySection("No digital receipts recorded.") }
        } else {
            items(s.digitalReceipts) { r -> SheetLineRow(r.label, money(r.amount)) }
        }

        // 5 — Credit lines (D5)
        item { SectionHeader("Credit lines") }
        if (s.creditLines.isEmpty()) {
            item { EmptySection("No credit lines recorded.") }
        } else {
            items(s.creditLines) { c ->
                SheetCard(title = c.creditTypeLabel?.ifBlank { null } ?: c.creditType.replace('_', ' ').replaceFirstChar { it.uppercase() }) {
                    SheetRow("Litres", litres(c.litres))
                    SheetRow("Amount", money(c.amount), emphasis = true)
                    if (!c.reference.isNullOrBlank()) SheetRow("Reference", c.reference)
                }
            }
        }

        // 6 — Cash taken out
        item { SectionHeader("Cash taken out") }
        if (s.expenseLines.isEmpty()) {
            item { EmptySection("Nothing taken out.") }
        } else {
            items(s.expenseLines) { e -> SheetLineRow(e.description, money(e.amount)) }
        }

        // 7 — Totals (D6)
        item { SectionHeader("Final amount") }
        item {
            SheetCard(title = null) {
                SheetRow("Fuel", money(s.totalFuelAmount))
                SheetRow("Lubes", money(s.totalLubeAmount))
                SheetRow("− Discounts", money(s.totalDiscountAmount))
                SheetRow("− Credit", money(s.totalCreditAmount))
                SheetRow("− Digital", money(s.totalDigitalReceiptAmount))
                SheetRow("− Cash out", money(s.totalExpenseAmount))
                SheetRow("Final to settle", money(s.finalAmountToSettle), emphasis = true)
            }
        }

        // 8 — Cash count (D7)
        item { SectionHeader("Cash count") }
        if (s.cashDenominations.isEmpty()) {
            item { EmptySection("No cash counted.") }
        } else {
            items(s.cashDenominations) { d -> SheetLineRow("₹${d.denomination} × ${d.quantity}", money(d.amount)) }
        }
        item {
            SheetCard(title = null) {
                SheetRow("Counted cash", money(s.countedCashAmount))
                SheetRow("Shortage (final − counted)", money(s.shortageAmount), emphasis = true, alarm = s.shortageAmount > 0.0)
            }
        }

        // 9 — Stock / decantation / rate comparison (D8, D10)
        item { SectionHeader("Stock received") }
        if (s.stockReceipts.isEmpty()) {
            item { EmptySection("No stock received.") }
        } else {
            items(s.stockReceipts) { r -> SheetLineRow(r.fuelTypeCode?.uppercase() ?: BLANK, "${litres(r.litresReceived)} L") }
        }

        item { SectionHeader("Decantation") }
        if (s.decantations.isEmpty()) {
            item { EmptySection("No decantation recorded.") }
        } else {
            items(s.decantations) { d ->
                SheetLineRow(
                    listOfNotNull(d.fuelTypeCode?.uppercase(), d.tankLabel?.ifBlank { null }).joinToString(" ").ifBlank { BLANK },
                    "${litres(d.openingKl)} → ${litres(d.closingKl)} KL",
                )
            }
        }

        item { SectionHeader("Rate comparison") }
        if (s.rateComparisons.isEmpty()) {
            item { EmptySection("No rate comparison recorded.") }
        } else {
            items(s.rateComparisons) { r ->
                SheetLineRow(
                    r.fuelTypeCode?.uppercase() ?: BLANK,
                    "ours ${price(r.ownPrice)} vs ${r.competitorName ?: "competitor"} ${price(r.competitorPrice)}",
                )
            }
        }

        // 10 — Notes
        item { SectionHeader("Notes") }
        item {
            Text(
                s.notes?.ifBlank { null } ?: "None.",
                style = MaterialTheme.typography.bodyMedium,
                color = if (s.notes.isNullOrBlank()) MaterialTheme.nayara.textTertiary else MaterialTheme.nayara.textPrimary,
            )
        }

        item { HorizontalDivider(Modifier.padding(vertical = NayaraSpacing.Md)) }
        item { SectionHeader("Audit trail") }
        if (s.changes.isEmpty()) {
            item { EmptySection("No edits recorded.") }
        } else {
            items(s.changes) { c ->
                Card(Modifier.fillMaxWidth()) {
                    Column(Modifier.padding(NayaraSpacing.CardPadding)) {
                        Text(c.changeReason, fontWeight = FontWeight.Medium)
                        val actor = c.onBehalfOf?.let { "${c.changedBy ?: BLANK} on behalf of $it" } ?: (c.changedBy ?: BLANK)
                        Text("$actor · ${c.createdAt ?: ""}", style = MaterialTheme.typography.labelSmall)
                        val fields = c.fieldDiffs?.keys?.joinToString(", ").orEmpty()
                        if (fields.isNotBlank()) Text("Changed: $fields", style = MaterialTheme.typography.bodySmall)
                        if (c.recomputedPoints) {
                            Text("Points recomputed", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.primary)
                        }
                    }
                }
            }
        }

        if (s.status != "reconciled") {
            item {
                NayaraButton(
                    onClick = vm::reconcile,
                    enabled = !state.reconciling,
                    loading = state.reconciling,
                    modifier = Modifier.fillMaxWidth().padding(top = NayaraSpacing.Md),
                ) { Text("Reconcile & lock") }
            }
        }
        item { Box(Modifier.padding(NayaraSpacing.Xl)) }
    }
}

/** One line item rendered as a plain label/value pair — the phone's answer to a table row. */
@Composable
private fun SheetLineRow(label: String, value: String) {
    Row(
        Modifier.fillMaxWidth().padding(vertical = NayaraSpacing.Xs),
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        Text(label, style = MaterialTheme.typography.bodyMedium, modifier = Modifier.weight(1f))
        Text(value, style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.Medium)
    }
}

@Composable
private fun SheetCard(title: String?, content: @Composable () -> Unit) {
    Card(Modifier.fillMaxWidth().padding(vertical = NayaraSpacing.Xxs)) {
        Column(Modifier.padding(NayaraSpacing.CardPadding)) {
            if (title != null) {
                Text(title, fontWeight = FontWeight.SemiBold, style = MaterialTheme.typography.bodyMedium)
                Box(Modifier.padding(top = NayaraSpacing.Xxs))
            }
            content()
        }
    }
}

@Composable
private fun SheetRow(label: String, value: String, emphasis: Boolean = false, alarm: Boolean = false, flag: String? = null) {
    Row(
        Modifier.fillMaxWidth().padding(vertical = 1.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(label, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.nayara.textSecondary)
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(NayaraSpacing.Xs),
        ) {
            if (flag != null) StatusChip(flag, ChipTone.Warning, showDot = false)
            Text(
                value,
                style = MaterialTheme.typography.bodySmall,
                fontWeight = if (emphasis) FontWeight.Bold else FontWeight.Normal,
                color = if (alarm) MaterialTheme.nayara.statusErrorText else MaterialTheme.nayara.textPrimary,
            )
        }
    }
}

/** A caption under a sheet row, for context the row's own value can't carry. */
@Composable
private fun SheetNote(text: String) {
    Text(
        text,
        style = MaterialTheme.typography.labelSmall,
        color = MaterialTheme.nayara.statusWarningText,
        modifier = Modifier.fillMaxWidth().padding(bottom = 1.dp),
    )
}

@Composable
private fun EmptySection(message: String) {
    Text(
        message,
        style = MaterialTheme.typography.bodySmall,
        color = MaterialTheme.nayara.textTertiary,
        modifier = Modifier.padding(vertical = NayaraSpacing.Xs),
    )
}
