package com.acefuel.loyalty.ui.settlement

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Card
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import com.acefuel.loyalty.core.di.LocalContainer
import com.acefuel.loyalty.ui.designsystem.BannerTone
import com.acefuel.loyalty.ui.designsystem.DateField
import com.acefuel.loyalty.ui.designsystem.FormField
import com.acefuel.loyalty.ui.designsystem.LabeledDropdown
import com.acefuel.loyalty.ui.designsystem.NayaraBanner
import com.acefuel.loyalty.ui.designsystem.NayaraSegmentedControl
import com.acefuel.loyalty.ui.designsystem.NayaraSnackbarHost
import com.acefuel.loyalty.ui.designsystem.NayaraTopBar
import com.acefuel.loyalty.ui.designsystem.showError
import com.acefuel.loyalty.ui.designsystem.showSuccess
import com.acefuel.loyalty.ui.theme.NayaraButton
import com.acefuel.loyalty.ui.theme.NayaraSpacing
import java.time.LocalDate
import java.time.format.DateTimeFormatter

private fun money(v: Double): String = "₹" + "%,.2f".format(v)
private val decimalKeyboard = KeyboardOptions(keyboardType = KeyboardType.Decimal)
private val numberKeyboard = KeyboardOptions(keyboardType = KeyboardType.Number)

// Credit-line types, mirroring SettlementCreditLine::CREDIT_TYPE_LABELS on the
// server (wire value to display label), in the order staff asked for.
private val CREDIT_TYPES = listOf(
    "drive_in" to "Drive-In",
    "credit" to "Credit",
    "fleet_otp" to "Fleet/OTP",
)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettlementScreen(
    onBack: () -> Unit,
    fuelPumpId: Long? = null,
    businessDate: String? = null,
) {
    val container = LocalContainer.current
    val viewModel: SettlementViewModel = viewModel(
        factory = viewModelFactory {
            initializer {
                SettlementViewModel(
                    SettlementRepository(container.retrofit.create(SettlementApi::class.java), container.json),
                    container.staffRepository,
                    fuelPumpId,
                    businessDate,
                )
            }
        },
    )
    val state by viewModel.state.collectAsStateWithLifecycle()
    val snackbar = remember { SnackbarHostState() }

    LaunchedEffect(state.savedMessage) {
        state.savedMessage?.let { snackbar.showSuccess(it); viewModel.consumeSaved() }
    }
    LaunchedEffect(state.error) {
        state.error?.let { snackbar.showError(it); viewModel.consumeError() }
    }

    Scaffold(
        topBar = { NayaraTopBar(title = "Daily Settlement", onBack = onBack) },
        snackbarHost = { NayaraSnackbarHost(snackbar) },
        bottomBar = { if (!state.loading) SettlementBottomBar(state, viewModel) },
    ) { padding ->
        if (state.loading) {
            Box(Modifier.fillMaxSize().padding(padding), contentAlignment = Alignment.Center) {
                CircularProgressIndicator()
            }
            return@Scaffold
        }

        Column(
            Modifier
                .fillMaxSize()
                .padding(padding)
                .verticalScroll(rememberScrollState())
                .padding(NayaraSpacing.ScreenMargin),
            verticalArrangement = Arrangement.spacedBy(NayaraSpacing.Md),
        ) {
            Text("${state.pumpName ?: "Pump"} · ${state.businessDate}", style = MaterialTheme.typography.titleMedium)
            state.fsmName?.let { Text("FSM: $it", style = MaterialTheme.typography.bodySmall) }
            if (state.locked) Text("Locked — read only.", color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodySmall)

            // Shown even when locked: the chooser doesn't edit the sheet, it is
            // how the FSM gets off a locked one to the day they still owe.
            DraftChooser(state, viewModel)

            SectionHeader("Nozzle readings")
            state.noNozzlesReason?.let { NayaraBanner(it, BannerTone.Warning) }
            state.nozzles.forEachIndexed { i, row ->
                NozzleCard(state, row, i, viewModel)
            }

            if (state.lubes.isNotEmpty()) {
                SectionHeader("Lubricants")
                state.lubes.forEachIndexed { i, row ->
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(NayaraSpacing.Sm)) {
                        Column(Modifier.weight(1f)) {
                            Text(row.name, style = MaterialTheme.typography.bodyMedium)
                            Text(money(row.unitPrice) + " each", style = MaterialTheme.typography.bodySmall)
                        }
                        FormField(row.qty, { viewModel.onLubeQty(i, it) }, "Qty", Modifier.width(96.dp), enabled = !state.locked, keyboardOptions = numberKeyboard)
                    }
                }
            }

            // Pulled from today's visit entries, plus any the FSM missed at
            // capture and adds here (staff feedback item 11).
            SectionHeader("Discounts")
            if (state.discounts.isEmpty() && state.addedDiscounts.isEmpty()) {
                Text("No same-day discounts captured for this pump.", style = MaterialTheme.typography.bodySmall)
            }
            state.discounts.forEach { d ->
                Text(
                    // The plate is on the web sheet's discount row and is one of
                    // the things a past sheet is searched by (rule 17), so it
                    // belongs on the line the FSM checks before submitting.
                    "• ${d.transport ?: d.driver ?: "—"}${d.vehicle?.takeIf { it.isNotBlank() }?.let { " · $it" } ?: ""} — ${trim(d.litres)} L → ${money(d.discount)}",
                    style = MaterialTheme.typography.bodyMedium,
                )
            }
            state.addedDiscounts.forEachIndexed { i, d ->
                Row(horizontalArrangement = Arrangement.spacedBy(NayaraSpacing.Sm)) {
                    FormField(d.transport, { viewModel.onAddedDiscountTransport(i, it) }, "Transport or customer", Modifier.weight(1.4f), enabled = !state.locked)
                    FormField(d.litres, { viewModel.onAddedDiscountLitres(i, it) }, "Litres", Modifier.weight(1f), enabled = !state.locked, keyboardOptions = decimalKeyboard)
                    FormField(d.discount, { viewModel.onAddedDiscountAmount(i, it) }, "Discount ₹", Modifier.weight(1f), enabled = !state.locked, keyboardOptions = decimalKeyboard)
                }
            }
            if (!state.locked) OutlinedButton(onClick = viewModel::addDiscount) { Text("Add discount") }

            // Free-form means (staff feedback item 10): PhonePe POS and Scanner
            // are seeded, anything else the FSM types in.
            SectionHeader("Digital receipts")
            state.receipts.forEachIndexed { i, r ->
                Row(horizontalArrangement = Arrangement.spacedBy(NayaraSpacing.Sm)) {
                    FormField(r.label, { viewModel.onReceiptLabel(i, it) }, "Means", Modifier.weight(1.4f), enabled = !state.locked)
                    FormField(r.amount, { viewModel.onReceiptAmount(i, it) }, "Amount ₹", Modifier.weight(1f), enabled = !state.locked, keyboardOptions = decimalKeyboard)
                }
            }
            if (!state.locked) OutlinedButton(onClick = viewModel::addReceipt) { Text("Add means") }

            // Cash taken out of the day's takings (staff feedback item 12).
            SectionHeader("Cash taken out")
            state.expenses.forEachIndexed { i, e ->
                Row(horizontalArrangement = Arrangement.spacedBy(NayaraSpacing.Sm)) {
                    FormField(e.description, { viewModel.onExpenseDescription(i, it) }, "What for", Modifier.weight(1.4f), enabled = !state.locked)
                    FormField(e.amount, { viewModel.onExpenseAmount(i, it) }, "Amount ₹", Modifier.weight(1f), enabled = !state.locked, keyboardOptions = decimalKeyboard)
                }
            }
            if (!state.locked) OutlinedButton(onClick = viewModel::addExpense) { Text("Add line") }

            SectionHeader("Credit lines")
            state.credits.forEachIndexed { i, c ->
                // Type mirrors the three customer account types (staff feedback
                // item 9) — a segmented control so all three are one tap away.
                NayaraSegmentedControl(
                    options = CREDIT_TYPES.map { it.second },
                    selectedIndex = CREDIT_TYPES.indexOfFirst { it.first == c.type }.coerceAtLeast(0),
                    onSelect = { index -> if (!state.locked) viewModel.onCreditType(i, CREDIT_TYPES[index].first) },
                )
                Row(horizontalArrangement = Arrangement.spacedBy(NayaraSpacing.Sm)) {
                    FormField(c.amount, { viewModel.onCreditAmount(i, it) }, "Amount ₹", Modifier.weight(1f), enabled = !state.locked, keyboardOptions = decimalKeyboard)
                    FormField(c.litres, { viewModel.onCreditLitres(i, it) }, "Litres", Modifier.weight(1f), enabled = !state.locked, keyboardOptions = decimalKeyboard)
                }
                FormField(c.reference, { viewModel.onCreditRef(i, it) }, "Reference", enabled = !state.locked)
            }
            if (!state.locked) OutlinedButton(onClick = viewModel::addCredit) { Text("Add credit line") }

            SectionHeader("Cash count")
            state.denoms.forEachIndexed { i, row ->
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(NayaraSpacing.Sm)) {
                    Text("₹${row.denomination}", Modifier.width(64.dp))
                    FormField(row.qty, { viewModel.onDenomQty(i, it) }, "Qty", Modifier.weight(1f), enabled = !state.locked, keyboardOptions = numberKeyboard)
                    Text(money((row.qty.toIntOrNull() ?: 0).toDouble() * row.denomination), Modifier.width(96.dp))
                }
            }

            if (state.stock.isNotEmpty()) {
                SectionHeader("Stock received")
                state.stock.forEachIndexed { i, row ->
                    FormField(row.litres, { viewModel.onStockLitres(i, it) }, "${row.fuelTypeCode.uppercase()} litres received", enabled = !state.locked, keyboardOptions = decimalKeyboard)
                }
            }

            if (state.rates.isNotEmpty()) {
                SectionHeader("Rate comparison")
                state.rates.forEachIndexed { i, row ->
                    FormField(row.competitor, { viewModel.onCompetitor(i, it) },
                        "${row.fuelTypeCode.uppercase()} JIO-BP ₹ (ours ${trim(row.ownPrice)})",
                        enabled = !state.locked, keyboardOptions = decimalKeyboard)
                }
            }

            FormField(state.notes, viewModel::onNotes, "Notes", enabled = !state.locked)
            Spacer(Modifier.width(NayaraSpacing.Xl))
        }
    }
}

/**
 * Pump + business-date chooser, mirroring the web draft chooser. The server
 * resolves the pump from the caller's assignment ON the business date, so an
 * FSM with no assignment for that day gets a draft with no nozzle rows — this
 * is how they name the pump they worked and reload. Applied only on tap:
 * reloading discards anything already typed.
 */
@Composable
private fun DraftChooser(state: SettlementUiState, vm: SettlementViewModel) {
    Column(verticalArrangement = Arrangement.spacedBy(NayaraSpacing.Sm)) {
        Row(horizontalArrangement = Arrangement.spacedBy(NayaraSpacing.Sm)) {
            LabeledDropdown(
                label = "Pump",
                selectedLabel = state.pumps.firstOrNull { it.id == state.pumpChoice }?.displayName
                    ?: state.pumpName ?: "Select pump",
                options = state.pumps.map { it.id to it.displayName },
                modifier = Modifier.weight(1f),
                enabled = state.pumps.isNotEmpty(),
                onSelect = vm::onPumpChoice,
            )
            DateField(
                label = "Business date",
                value = parseIsoDate(state.dateChoice),
                onChange = { vm.onDateChoice(it.toString()) },
                modifier = Modifier.weight(1f),
            )
        }
        if (state.draftChoiceChanged) {
            OutlinedButton(onClick = vm::loadChosenDraft) { Text("Load draft") }
        }
    }
}

@Composable
private fun NozzleCard(state: SettlementUiState, row: NozzleRow, i: Int, vm: SettlementViewModel) {
    Card(Modifier.fillMaxWidth()) {
        Column(Modifier.padding(NayaraSpacing.CardPadding), verticalArrangement = Arrangement.spacedBy(NayaraSpacing.Sm)) {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                Text("${row.label} · ${row.fuelType}", fontWeight = FontWeight.SemiBold)
                Text(money(row.unitPrice) + "/L", style = MaterialTheme.typography.bodySmall)
            }
            // The opening is auto-filled from the last settled sheet but stays
            // typeable: days can pass with nobody filing a sheet while the pump
            // keeps selling, and the auto-filled figure is then behind the meter.
            // The helper line says where that figure came from so the FSM can
            // tell yesterday's reading from a stale one.
            Row(horizontalArrangement = Arrangement.spacedBy(NayaraSpacing.Sm)) {
                FormField(
                    row.opening, { vm.onOpening(i, it) }, "Opening", Modifier.weight(1f),
                    helper = openingHelper(row, state.businessDate),
                    enabled = !state.locked, keyboardOptions = decimalKeyboard
                )
                FormField(row.closing, { vm.onClosing(i, it) }, "Closing", Modifier.weight(1f), enabled = !state.locked, keyboardOptions = decimalKeyboard)
            }
            // Undo is worth a control of its own here: without it a mistyped
            // meter reading costs the FSM the whole sheet to get back.
            if (!state.locked && row.openingOverridden) {
                TextButton(onClick = { vm.resetOpening(i) }) { Text("Undo opening edit") }
            }
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(NayaraSpacing.Sm)) {
                FormField(row.testing, { vm.onTesting(i, it) }, "Testing", Modifier.weight(1f), enabled = !state.locked, keyboardOptions = decimalKeyboard)
                Text("Rollover", style = MaterialTheme.typography.bodySmall)
                Switch(checked = row.rollover, onCheckedChange = { vm.onRollover(i, it) }, enabled = !state.locked)
            }
            val net = state.nozzleNet(row)
            Text("Net ${trim(net)} L → ${money(net * row.unitPrice)}", style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.Medium)
        }
    }
}

@Composable
private fun SettlementBottomBar(state: SettlementUiState, vm: SettlementViewModel) {
    Surface(tonalElevation = 3.dp) {
        Column(Modifier.fillMaxWidth().padding(NayaraSpacing.Md), verticalArrangement = Arrangement.spacedBy(NayaraSpacing.Sm)) {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                TotalCell("Final", money(state.finalToSettle))
                TotalCell("Counted", money(state.countedCash))
                TotalCell("Shortage", money(state.shortage))
            }
            if (!state.locked) {
                HorizontalDivider()
                Row(horizontalArrangement = Arrangement.spacedBy(NayaraSpacing.Sm)) {
                    OutlinedButton(onClick = { vm.submit("draft") }, enabled = !state.submitting, modifier = Modifier.weight(1f)) { Text("Save draft") }
                    NayaraButton(onClick = { vm.submit("submitted") }, enabled = state.canSubmit, loading = state.submitting, modifier = Modifier.weight(1f)) { Text("Submit") }
                }
            }
        }
    }
}

@Composable
private fun TotalCell(label: String, value: String) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Text(label, style = MaterialTheme.typography.labelSmall)
        Text(value, fontWeight = FontWeight.Bold)
    }
}

@Composable
private fun SectionHeader(text: String) {
    HorizontalDivider()
    Text(text, style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.SemiBold)
}

private val DAY_MONTH = DateTimeFormatter.ofPattern("d MMM")

private fun openingHelper(row: NozzleRow, businessDate: String): String? {
    val prior = row.priorClosing ?: return null
    val settledOn = row.priorClosingDate?.let(::parseIsoDate)
    val note = StringBuilder("Last settled ${trim(prior)}")
    if (settledOn != null) note.append(" on ${settledOn.format(DAY_MONTH)}")
    val gap = unsettledDays(settledOn, parseIsoDate(businessDate))
    if (gap > 0) note.append(" · $gap ${if (gap == 1L) "day" else "days"} not settled")
    return note.toString()
}

// Whole days between the sheet that figure came from and this one. Zero when
// they are consecutive; anything more is time the pump sold through unrecorded.
private fun unsettledDays(settledOn: LocalDate?, businessDate: LocalDate?): Long {
    if (settledOn == null || businessDate == null) return 0
    return (businessDate.toEpochDay() - settledOn.toEpochDay() - 1).coerceAtLeast(0)
}

private fun parseIsoDate(value: String): LocalDate? =
    runCatching { LocalDate.parse(value) }.getOrNull()

private fun trim(v: Double): String = if (v % 1.0 == 0.0) v.toLong().toString() else "%.3f".format(v).trimEnd('0').trimEnd('.')
