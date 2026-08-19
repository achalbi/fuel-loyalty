package com.acefuel.loyalty.ui.settlement

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Card
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
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
import com.acefuel.loyalty.ui.designsystem.DateField
import com.acefuel.loyalty.ui.designsystem.FormField
import com.acefuel.loyalty.ui.designsystem.NayaraSegmentedControl
import com.acefuel.loyalty.ui.designsystem.NayaraSnackbarHost
import com.acefuel.loyalty.ui.designsystem.NayaraTopBar
import com.acefuel.loyalty.ui.designsystem.showError
import com.acefuel.loyalty.ui.designsystem.showSuccess
import com.acefuel.loyalty.ui.theme.NayaraButton
import com.acefuel.loyalty.ui.theme.NayaraSpacing
import java.time.LocalDate

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

/**
 * D1–D10 shift-end settlement, shared by two flows.
 *
 * [onBehalf] false is the FSM capturing their own sheet. True is the admin
 * "record on behalf of a named FSM who could not" flow (staff feedback item 3):
 * the same form, preceded by an FSM picker and followed by a mandatory reason,
 * posted to the audited admin create. It is deliberately the same composable —
 * a second copy of this form would drift line by line.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettlementScreen(
    onBack: () -> Unit,
    fuelPumpId: Long? = null,
    businessDate: String? = null,
    onBehalf: Boolean = false,
) {
    val container = LocalContainer.current
    val viewModel: SettlementViewModel = viewModel(
        factory = viewModelFactory {
            initializer {
                SettlementViewModel(
                    SettlementRepository(container.retrofit.create(SettlementApi::class.java), container.json),
                    fuelPumpId,
                    businessDate,
                    onBehalf,
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
        topBar = {
            NayaraTopBar(
                title = if (onBehalf) "Record for an FSM" else "Daily Settlement",
                onBack = onBack,
            )
        },
        snackbarHost = { NayaraSnackbarHost(snackbar) },
        bottomBar = { if (!state.loading) SettlementBottomBar(state, viewModel, onBack) },
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
            // Step 1 of the on-behalf flow. Nothing below it can be pre-filled
            // until an FSM is named: the nozzles, the auto-popped opening
            // readings and the pulled discounts all come from THEIR pump.
            val header = state.onBehalf
            if (header != null) OnBehalfHeader(header, viewModel)
            if (header != null && !header.formReady) return@Column

            Text("${state.pumpName ?: "Pump"} · ${state.businessDate}", style = MaterialTheme.typography.titleMedium)
            // Name the enterer as well as the FSM whenever there is one, so a
            // sheet an admin typed never reads as the FSM's own entry.
            state.fsmName?.let { fsm ->
                val entered = state.enteredByName?.let { " · entered by $it" }.orEmpty()
                Text("FSM: $fsm$entered", style = MaterialTheme.typography.bodySmall)
            }
            if (state.locked) Text("Locked — read only.", color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodySmall)
            // The draft is built against the FSM's own pump; without one there
            // are no nozzles to read and the create would be refused.
            if (header != null && state.fuelPumpId == null) {
                Text(
                    "${header.recordedForName ?: "This operator"} has no pump assignment, so there are " +
                        "no nozzles to read. Assign them a pump before recording their sheet.",
                    color = MaterialTheme.colorScheme.error,
                    style = MaterialTheme.typography.bodySmall,
                )
            }

            SectionHeader("Nozzle readings")
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
                        FormField(row.qty, { viewModel.onLubeQty(i, it) }, "Qty", Modifier.width(96.dp), enabled = state.editable, keyboardOptions = numberKeyboard)
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
                Text("• ${d.transport ?: d.driver ?: "—"} — ${trim(d.litres)} L → ${money(d.discount)}", style = MaterialTheme.typography.bodyMedium)
            }
            state.addedDiscounts.forEachIndexed { i, d ->
                Row(horizontalArrangement = Arrangement.spacedBy(NayaraSpacing.Sm)) {
                    FormField(d.transport, { viewModel.onAddedDiscountTransport(i, it) }, "Transport or customer", Modifier.weight(1.4f), enabled = state.editable)
                    FormField(d.litres, { viewModel.onAddedDiscountLitres(i, it) }, "Litres", Modifier.weight(1f), enabled = state.editable, keyboardOptions = decimalKeyboard)
                    FormField(d.discount, { viewModel.onAddedDiscountAmount(i, it) }, "Discount ₹", Modifier.weight(1f), enabled = state.editable, keyboardOptions = decimalKeyboard)
                }
            }
            if (state.editable) OutlinedButton(onClick = viewModel::addDiscount) { Text("Add discount") }

            // Free-form means (staff feedback item 10): PhonePe POS and Scanner
            // are seeded, anything else the FSM types in.
            SectionHeader("Digital receipts")
            state.receipts.forEachIndexed { i, r ->
                Row(horizontalArrangement = Arrangement.spacedBy(NayaraSpacing.Sm)) {
                    FormField(r.label, { viewModel.onReceiptLabel(i, it) }, "Means", Modifier.weight(1.4f), enabled = state.editable)
                    FormField(r.amount, { viewModel.onReceiptAmount(i, it) }, "Amount ₹", Modifier.weight(1f), enabled = state.editable, keyboardOptions = decimalKeyboard)
                }
            }
            if (state.editable) OutlinedButton(onClick = viewModel::addReceipt) { Text("Add means") }

            // Cash taken out of the day's takings (staff feedback item 12).
            SectionHeader("Cash taken out")
            state.expenses.forEachIndexed { i, e ->
                Row(horizontalArrangement = Arrangement.spacedBy(NayaraSpacing.Sm)) {
                    FormField(e.description, { viewModel.onExpenseDescription(i, it) }, "What for", Modifier.weight(1.4f), enabled = state.editable)
                    FormField(e.amount, { viewModel.onExpenseAmount(i, it) }, "Amount ₹", Modifier.weight(1f), enabled = state.editable, keyboardOptions = decimalKeyboard)
                }
            }
            if (state.editable) OutlinedButton(onClick = viewModel::addExpense) { Text("Add line") }

            SectionHeader("Credit lines")
            state.credits.forEachIndexed { i, c ->
                // Type mirrors the three customer account types (staff feedback
                // item 9) — a segmented control so all three are one tap away.
                NayaraSegmentedControl(
                    options = CREDIT_TYPES.map { it.second },
                    selectedIndex = CREDIT_TYPES.indexOfFirst { it.first == c.type }.coerceAtLeast(0),
                    onSelect = { index -> if (state.editable) viewModel.onCreditType(i, CREDIT_TYPES[index].first) },
                )
                Row(horizontalArrangement = Arrangement.spacedBy(NayaraSpacing.Sm)) {
                    FormField(c.amount, { viewModel.onCreditAmount(i, it) }, "Amount ₹", Modifier.weight(1f), enabled = state.editable, keyboardOptions = decimalKeyboard)
                    FormField(c.litres, { viewModel.onCreditLitres(i, it) }, "Litres", Modifier.weight(1f), enabled = state.editable, keyboardOptions = decimalKeyboard)
                }
                FormField(c.reference, { viewModel.onCreditRef(i, it) }, "Reference", enabled = state.editable)
            }
            if (state.editable) OutlinedButton(onClick = viewModel::addCredit) { Text("Add credit line") }

            SectionHeader("Cash count")
            state.denoms.forEachIndexed { i, row ->
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(NayaraSpacing.Sm)) {
                    Text("₹${row.denomination}", Modifier.width(64.dp))
                    FormField(row.qty, { viewModel.onDenomQty(i, it) }, "Qty", Modifier.weight(1f), enabled = state.editable, keyboardOptions = numberKeyboard)
                    Text(money((row.qty.toIntOrNull() ?: 0).toDouble() * row.denomination), Modifier.width(96.dp))
                }
            }

            if (state.stock.isNotEmpty()) {
                SectionHeader("Stock received")
                state.stock.forEachIndexed { i, row ->
                    FormField(row.litres, { viewModel.onStockLitres(i, it) }, "${row.fuelTypeCode.uppercase()} litres received", enabled = state.editable, keyboardOptions = decimalKeyboard)
                }
            }

            if (state.rates.isNotEmpty()) {
                SectionHeader("Rate comparison")
                state.rates.forEachIndexed { i, row ->
                    FormField(row.competitor, { viewModel.onCompetitor(i, it) },
                        "${row.fuelTypeCode.uppercase()} JIO-BP ₹ (ours ${trim(row.ownPrice)})",
                        enabled = state.editable, keyboardOptions = decimalKeyboard)
                }
            }

            FormField(state.notes, viewModel::onNotes, "Notes", enabled = state.editable)

            // Mandatory on the on-behalf path — it is written into the audit
            // trail with the create, and the server refuses an unexplained
            // admin write into someone else's record.
            header?.let {
                SectionHeader("Why you are recording this")
                FormField(
                    it.reason, viewModel::onChangeReason,
                    "Reason (required)",
                    enabled = state.editable,
                    singleLine = false,
                    helper = "Permanent in the audit trail — e.g. \"on sick leave; readings dictated at the counter\".",
                )
            }
            Spacer(Modifier.width(NayaraSpacing.Xl))
        }
    }
}

/**
 * Step 1 of "record on behalf of a named FSM", plus the standing banner once one
 * is picked. The picker is a state of this screen rather than a screen of its
 * own because the sheet below it cannot be hydrated until the question it asks
 * is answered.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun OnBehalfHeader(header: OnBehalfState, vm: SettlementViewModel) {
    Card(Modifier.fillMaxWidth()) {
        Column(Modifier.padding(NayaraSpacing.CardPadding), verticalArrangement = Arrangement.spacedBy(NayaraSpacing.Sm)) {
            if (header.fsmChosen) {
                Text("Recording for ${header.recordedForName ?: "—"}", fontWeight = FontWeight.SemiBold)
                Text(
                    "This sheet belongs to them and their day's money counts as theirs. " +
                        "You are logged only as the person who entered it" +
                        (header.enteredByName?.let { " ($it)" } ?: "") + ".",
                    style = MaterialTheme.typography.bodySmall,
                )
            } else {
                Text("Who could not settle?", fontWeight = FontWeight.SemiBold)
                Text(
                    "Pick the FSM this sheet is for. Every reading and price is pre-filled " +
                        "from THEIR pump, not yours, and the sheet stays recorded against them.",
                    style = MaterialTheme.typography.bodySmall,
                )
            }

            // Date first: the pick re-hydrates against it, so changing it after
            // choosing an FSM reloads their sheet for the new day.
            DateField(
                label = "Business date",
                value = header.businessDate?.let { runCatching { LocalDate.parse(it) }.getOrNull() },
                onChange = { vm.onOnBehalfDate(it.toString()) },
                enabled = !header.saved,
                placeholder = "Yesterday",
            )

            // The slot is already settled. Creating would collide with the
            // (pump, date, shift) unique index, and correcting the sheet that is
            // there belongs in the settlements console, where the edit is
            // itself audited — so offer another day or another operator, not a
            // second sheet.
            if (header.slotTaken) {
                Text(
                    "${header.recordedForName ?: "That operator"} already has a settlement for that pump and date. " +
                        "Open it from the settlements list to correct it.",
                    color = MaterialTheme.colorScheme.error,
                    style = MaterialTheme.typography.bodySmall,
                )
            }

            if (!header.saved && header.candidates.isNotEmpty()) {
                Row(
                    Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()),
                    horizontalArrangement = Arrangement.spacedBy(NayaraSpacing.Sm),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    // Admins are on this list as well as staff: an admin does
                    // stand a shift on a small site, and sheets recorded by one
                    // already exist in the data.
                    header.candidates.forEach { candidate ->
                        FilterChip(
                            selected = header.recordedForId == candidate.id,
                            onClick = { vm.onPickFsm(candidate.id) },
                            label = { Text(candidate.name) },
                        )
                    }
                }
            }

            if (header.saved) {
                Text(
                    "Filed. Open it from the settlements list if it needs correcting — " +
                        "that edit is audited too.",
                    style = MaterialTheme.typography.bodySmall,
                )
            }
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
            Row(horizontalArrangement = Arrangement.spacedBy(NayaraSpacing.Sm)) {
                FormField(row.opening, { vm.onOpening(i, it) }, "Yesterday", Modifier.weight(1f), enabled = state.editable && !row.openingReadonly, keyboardOptions = decimalKeyboard)
                FormField(row.closing, { vm.onClosing(i, it) }, "Today", Modifier.weight(1f), enabled = state.editable, keyboardOptions = decimalKeyboard)
            }
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(NayaraSpacing.Sm)) {
                FormField(row.testing, { vm.onTesting(i, it) }, "Testing", Modifier.weight(1f), enabled = state.editable, keyboardOptions = decimalKeyboard)
                Text("Rollover", style = MaterialTheme.typography.bodySmall)
                Switch(checked = row.rollover, onCheckedChange = { vm.onRollover(i, it) }, enabled = state.editable)
            }
            val net = state.nozzleNet(row)
            Text("Net ${trim(net)} L → ${money(net * row.unitPrice)}", style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.Medium)
        }
    }
}

@Composable
private fun SettlementBottomBar(state: SettlementUiState, vm: SettlementViewModel, onBack: () -> Unit) {
    val header = state.onBehalf
    // Nothing to total, and nothing to save, until an FSM is named.
    if (header != null && !header.formReady && !header.saved) return
    Surface(tonalElevation = 3.dp) {
        Column(Modifier.fillMaxWidth().padding(NayaraSpacing.Md), verticalArrangement = Arrangement.spacedBy(NayaraSpacing.Sm)) {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                TotalCell("Final", money(state.finalToSettle))
                TotalCell("Counted", money(state.countedCash))
                TotalCell("Shortage", money(state.shortage))
            }
            if (header?.saved == true) {
                // A second POST would hit the unique index and a PATCH would go
                // to the unaudited staff endpoint, so the flow ends here.
                HorizontalDivider()
                NayaraButton(onClick = onBack, modifier = Modifier.fillMaxWidth()) { Text("Done") }
            } else if (state.editable) {
                HorizontalDivider()
                Row(horizontalArrangement = Arrangement.spacedBy(NayaraSpacing.Sm)) {
                    // The FSM cannot act, so an on-behalf sheet is submitted
                    // rather than parked in `draft` awaiting a submission that
                    // is not coming; draft stays for a sheet filled in across
                    // two sittings at the counter.
                    OutlinedButton(
                        onClick = { vm.submit("draft") },
                        enabled = state.canSave,
                        modifier = Modifier.weight(1f),
                    ) { Text("Save draft") }
                    NayaraButton(
                        onClick = { vm.submit("submitted") },
                        enabled = state.canSubmit,
                        loading = state.submitting,
                        modifier = Modifier.weight(1f),
                    ) { Text(if (header != null) "Record & submit" else "Submit") }
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

private fun trim(v: Double): String = if (v % 1.0 == 0.0) v.toLong().toString() else "%.3f".format(v).trimEnd('0').trimEnd('.')
