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
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.LifecycleEventEffect
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import com.acefuel.loyalty.core.di.LocalContainer
import com.acefuel.loyalty.ui.designsystem.DateField
import com.acefuel.loyalty.ui.designsystem.NayaraSnackbarHost
import com.acefuel.loyalty.ui.designsystem.NayaraTopBar
import com.acefuel.loyalty.ui.designsystem.showError
import com.acefuel.loyalty.ui.designsystem.showSuccess
import com.acefuel.loyalty.ui.settlement.SettlementSummaryDto
import com.acefuel.loyalty.ui.theme.NayaraButton
import com.acefuel.loyalty.ui.theme.NayaraSpacing
import java.time.LocalDate

private fun money(v: Double?): String = if (v == null) "—" else "₹" + "%,.2f".format(v)

/**
 * D9 admin settlement console. [onRecordOnBehalf] opens the audited "record on
 * behalf of a named FSM" flow (staff feedback item 3) — the FSM's own D1–D10
 * form, not a second copy of it. Capturing one's OWN sheet stays the FSM's job,
 * so there is deliberately no plain "new settlement" here.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AdminSettlementsScreen(onBack: () -> Unit, onRecordOnBehalf: () -> Unit = {}) {
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

    // This view model is scoped to the SETTLEMENTS back-stack entry, so it
    // survives the push/pop of the on-behalf form. Reloading once per resume is
    // what makes a sheet the admin just recorded appear when they come back —
    // otherwise the list still shows the pre-save state and reads as a failure.
    LifecycleEventEffect(Lifecycle.Event.ON_RESUME) { viewModel.loadList() }

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
            if (inDetail) {
                DetailView(state, viewModel)
            } else {
                // The filter bar stays put while the list reloads, so tapping a
                // chip doesn't make the controls disappear under a spinner.
                Column(Modifier.fillMaxSize().padding(horizontal = NayaraSpacing.ScreenMargin)) {
                    FilterBar(state, viewModel)
                    NayaraButton(
                        onClick = onRecordOnBehalf,
                        modifier = Modifier.fillMaxWidth().padding(bottom = NayaraSpacing.Xs),
                    ) { Text("Record on behalf of an FSM") }
                    // weight(1f), not fillMaxSize(): the list takes what the
                    // filter bar leaves rather than the whole column height.
                    if (state.loading) {
                        Box(Modifier.fillMaxWidth().weight(1f), Alignment.Center) { CircularProgressIndicator() }
                    } else {
                        ListView(state, viewModel, Modifier.weight(1f))
                    }
                }
            }
        }
    }
}

/**
 * Admin-12 — read the settlements of one FSM for one day. The FSM options come
 * from the server (see User.settlement_recorders) and deliberately include
 * admins: admin-recorded sheets exist in the data and would otherwise be
 * unreachable by every value of this filter.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun FilterBar(state: AdminSettlementsUiState, vm: AdminSettlementsViewModel) {
    Column(
        Modifier.fillMaxWidth().padding(vertical = NayaraSpacing.Xs),
        verticalArrangement = Arrangement.spacedBy(NayaraSpacing.Xs),
    ) {
        Row(
            Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(NayaraSpacing.Sm),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            DateField(
                label = "Date",
                value = state.businessDate?.let { runCatching { LocalDate.parse(it) }.getOrNull() },
                onChange = { vm.onDate(it.toString()) },
                modifier = Modifier.weight(1f),
                placeholder = "All dates",
            )
            if (state.businessDate != null) {
                TextButton(onClick = { vm.onDate(null) }) { Text("Clear") }
            }
        }
        if (state.fsmOptions.isNotEmpty()) {
            Row(
                Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()),
                horizontalArrangement = Arrangement.spacedBy(NayaraSpacing.Sm),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text("FSM", style = MaterialTheme.typography.labelMedium)
                FilterChip(
                    selected = state.recordedById == null,
                    onClick = { vm.onRecordedBy(null) },
                    label = { Text("All") },
                )
                state.fsmOptions.forEach { option ->
                    FilterChip(
                        selected = state.recordedById == option.id,
                        onClick = { vm.onRecordedBy(if (state.recordedById == option.id) null else option.id) },
                        label = { Text(option.name) },
                    )
                }
            }
        }
    }
}

@Composable
private fun ListView(state: AdminSettlementsUiState, vm: AdminSettlementsViewModel, modifier: Modifier = Modifier) {
    LazyColumn(
        modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(NayaraSpacing.Sm),
    ) {
        state.crossPumpTotals?.let { totals ->
            item {
                Card(Modifier.fillMaxWidth().padding(top = NayaraSpacing.Sm)) {
                    Column(Modifier.padding(NayaraSpacing.CardPadding)) {
                        // "Cross-pump" is every pump but only the FSM the server
                        // says it filtered to, so qualify the label the way the
                        // web heading does — unqualified, it reads as the whole
                        // day's takings when it is one operator's money.
                        Text(
                            "Cross-pump totals" + (state.filteredBy?.labelSuffix() ?: ""),
                            fontWeight = FontWeight.SemiBold,
                        )
                        Text("Fuel ${money(totals.totalFuelAmount)} · Final ${money(totals.finalAmountToSettle)} · Shortage ${money(totals.shortageAmount)}",
                            style = MaterialTheme.typography.bodySmall)
                    }
                }
            }
        }
        // Admin-12 — the listed settlements rolled up per FSM, so the day reads
        // as a report per user without opening each sheet.
        if (state.perFsmTotals.isNotEmpty()) {
            item {
                Card(Modifier.fillMaxWidth()) {
                    Column(Modifier.padding(NayaraSpacing.CardPadding), verticalArrangement = Arrangement.spacedBy(NayaraSpacing.Xxs)) {
                        Text("Per-FSM totals", fontWeight = FontWeight.SemiBold)
                        state.perFsmTotals.forEach { row ->
                            Text("${row.fsmName ?: "—"} · ${row.settlementCount} sheet(s)", style = MaterialTheme.typography.bodyMedium)
                            Text("Fuel ${money(row.totals.totalFuelAmount)} · Final ${money(row.totals.finalAmountToSettle)} · Shortage ${money(row.totals.shortageAmount)}",
                                style = MaterialTheme.typography.bodySmall)
                        }
                    }
                }
            }
        }
        if (state.settlements.isEmpty()) {
            item { Text("No settlements match.", Modifier.padding(NayaraSpacing.Md)) }
        } else {
            items(state.settlements) { s -> SettlementRow(s) { vm.open(s.id) } }
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
            // Whose sheet this is — the admin console is a read-across-users
            // view, so the recorder belongs on the row (staff feedback item 3).
            // `attributionLabel` adds "· entered by ‹admin›" when an admin typed
            // it, so an on-behalf sheet never reads as the FSM's own entry.
            Text("Recorded by ${s.attributionLabel()}", style = MaterialTheme.typography.bodySmall)
            Text("Final ${money(s.finalAmountToSettle)} · Shortage ${money(s.shortageAmount)}", style = MaterialTheme.typography.bodySmall)
        }
    }
}

@Composable
private fun DetailView(state: AdminSettlementsUiState, vm: AdminSettlementsViewModel) {
    val s = state.selected ?: return
    LazyColumn(
        Modifier.fillMaxSize().padding(horizontal = NayaraSpacing.ScreenMargin),
        verticalArrangement = Arrangement.spacedBy(NayaraSpacing.Sm),
    ) {
        item {
            Column(Modifier.padding(vertical = NayaraSpacing.Sm)) {
                Text("${s.fuelPump ?: "Pump"} · ${s.businessDate}", style = MaterialTheme.typography.titleMedium)
                Text("Status: ${s.status}${if (s.locked) " · locked" else ""} · recorded by ${s.attributionLabel()}", style = MaterialTheme.typography.bodySmall)
            }
        }
        item {
            Card(Modifier.fillMaxWidth()) {
                Column(Modifier.padding(NayaraSpacing.CardPadding), verticalArrangement = Arrangement.spacedBy(NayaraSpacing.Xxs)) {
                    Text("Fuel ${money(s.totalFuelAmount)}")
                    Text("Discounts ${money(s.totalDiscountAmount)} · Credit ${money(s.totalCreditAmount)}")
                    Text("Final to settle ${money(s.finalAmountToSettle)}", fontWeight = FontWeight.SemiBold)
                    Text("Counted ${money(s.countedCashAmount)} · Shortage ${money(s.shortageAmount)}")
                }
            }
        }
        if (s.nozzleReadings.isNotEmpty()) {
            item { Text("Nozzle readings", fontWeight = FontWeight.SemiBold) }
            items(s.nozzleReadings) { r ->
                Text("${r.displayName ?: "Nozzle"} ${r.fuelTypeCode?.uppercase() ?: ""}: ${r.netLitresSold ?: 0.0} L → ${money(r.amount)}",
                    style = MaterialTheme.typography.bodyMedium)
            }
        }
        item { HorizontalDivider(Modifier.padding(vertical = NayaraSpacing.Xs)) }
        item { Text("Audit trail", fontWeight = FontWeight.SemiBold) }
        if (s.changes.isEmpty()) {
            item { Text("No edits recorded.", style = MaterialTheme.typography.bodySmall) }
        } else {
            items(s.changes) { c ->
                Card(Modifier.fillMaxWidth()) {
                    Column(Modifier.padding(NayaraSpacing.CardPadding)) {
                        Text(c.changeReason, fontWeight = FontWeight.Medium)
                        Text("${c.changedBy ?: "—"} · ${c.createdAt ?: ""}", style = MaterialTheme.typography.labelSmall)
                        val fields = c.fieldDiffs?.keys?.joinToString(", ").orEmpty()
                        if (fields.isNotBlank()) Text("Changed: $fields", style = MaterialTheme.typography.bodySmall)
                        if (c.recomputedPoints) Text("Points recomputed", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.primary)
                    }
                }
            }
        }
        if (s.status != "reconciled") {
            item {
                NayaraButton(onClick = vm::reconcile, enabled = !state.reconciling, loading = state.reconciling, modifier = Modifier.fillMaxWidth().padding(top = NayaraSpacing.Sm)) {
                    Text("Reconcile & lock")
                }
            }
        }
        item { Box(Modifier.padding(NayaraSpacing.Xl)) }
    }
}
