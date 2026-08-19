package com.acefuel.loyalty.ui.admin.settlements

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.AssistChip
import androidx.compose.material3.Card
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
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
import com.acefuel.loyalty.ui.designsystem.NayaraSnackbarHost
import com.acefuel.loyalty.ui.designsystem.NayaraTopBar
import com.acefuel.loyalty.ui.designsystem.showError
import com.acefuel.loyalty.ui.designsystem.showSuccess
import com.acefuel.loyalty.ui.settlement.SettlementSummaryDto
import com.acefuel.loyalty.ui.theme.NayaraButton
import com.acefuel.loyalty.ui.theme.NayaraSpacing

private fun money(v: Double?): String = if (v == null) "—" else "₹" + "%,.2f".format(v)

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
                state.loading -> Box(Modifier.fillMaxSize(), Alignment.Center) { CircularProgressIndicator() }
                else -> ListView(state, viewModel)
            }
        }
    }
}

@Composable
private fun ListView(state: AdminSettlementsUiState, vm: AdminSettlementsViewModel) {
    LazyColumn(
        Modifier.fillMaxSize().padding(horizontal = NayaraSpacing.ScreenMargin),
        verticalArrangement = Arrangement.spacedBy(NayaraSpacing.Sm),
    ) {
        state.crossPumpTotals?.let { totals ->
            item {
                Card(Modifier.fillMaxWidth().padding(top = NayaraSpacing.Sm)) {
                    Column(Modifier.padding(NayaraSpacing.CardPadding)) {
                        Text("Cross-pump totals", fontWeight = FontWeight.SemiBold)
                        Text("Fuel ${money(totals.totalFuelAmount)} · Final ${money(totals.finalAmountToSettle)} · Shortage ${money(totals.shortageAmount)}",
                            style = MaterialTheme.typography.bodySmall)
                    }
                }
            }
        }
        if (state.settlements.isEmpty()) {
            item { Text("No settlements yet.", Modifier.padding(NayaraSpacing.Md)) }
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
                Text("Status: ${s.status}${if (s.locked) " · locked" else ""} · FSM ${s.fsmName ?: "—"}", style = MaterialTheme.typography.bodySmall)
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
                        val actor = c.onBehalfOf?.let { "${c.changedBy ?: "—"} on behalf of $it" } ?: (c.changedBy ?: "—")
                        Text("$actor · ${c.createdAt ?: ""}", style = MaterialTheme.typography.labelSmall)
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
