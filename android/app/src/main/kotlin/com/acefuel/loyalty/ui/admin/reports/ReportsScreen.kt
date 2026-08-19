package com.acefuel.loyalty.ui.admin.reports

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
import androidx.compose.material3.Card
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import com.acefuel.loyalty.core.di.LocalContainer
import com.acefuel.loyalty.ui.designsystem.NayaraTopBar
import com.acefuel.loyalty.ui.theme.NayaraSpacing

private fun money(v: Double?): String = if (v == null) "—" else "₹" + "%,.0f".format(v)

// Reward ₹ with no cash-per-point rate configured is a NULL that summed to 0, not
// a real zero — render "—" so it reads as "not set up", the same as the web table.
private fun rewardMoney(v: Double, configured: Boolean): String =
    if (!configured && v == 0.0) "—" else money(v)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AdminReportsScreen(onBack: () -> Unit, customerId: Long? = null) {
    val container = LocalContainer.current
    val viewModel: ReportsViewModel = viewModel(
        factory = viewModelFactory {
            initializer {
                ReportsViewModel(
                    ReportsRepository(container.retrofit.create(ReportsApi::class.java), container.json),
                    initialCustomerId = customerId,
                )
            }
        },
    )
    val state by viewModel.state.collectAsStateWithLifecycle()

    Scaffold(topBar = { NayaraTopBar(title = "Reports", onBack = onBack) }) { padding ->
        Column(Modifier.fillMaxSize().padding(padding).padding(horizontal = NayaraSpacing.ScreenMargin)) {
            ChipRow("By", ReportsUiState.DIMENSIONS, state.dimension, viewModel::onDimension)
            ChipRow("Grain", ReportsUiState.GRAINS, state.grain, viewModel::onGrain)
            // Scoped to one customer (E1 customer_id filter) — tap to clear.
            state.customerId?.let { id ->
                Row(
                    Modifier.fillMaxWidth().padding(vertical = NayaraSpacing.Xs),
                    horizontalArrangement = Arrangement.spacedBy(NayaraSpacing.Sm),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text("Customer", style = MaterialTheme.typography.labelMedium)
                    FilterChip(selected = true, onClick = { viewModel.onCustomer(null) }, label = { Text("#$id ✕") })
                }
            }
            state.response?.range?.let { r ->
                if (r.from != null) Text("${r.from} → ${r.to}", style = MaterialTheme.typography.bodySmall)
            }

            when {
                state.loading -> Box(Modifier.fillMaxSize(), Alignment.Center) { CircularProgressIndicator() }
                state.error != null -> Text(state.error!!, color = MaterialTheme.colorScheme.error, modifier = Modifier.padding(NayaraSpacing.Md))
                state.response?.rows.isNullOrEmpty() -> Text("No captures in this range.", modifier = Modifier.padding(NayaraSpacing.Md))
                else -> {
                    val resp = state.response!!
                    LazyColumn(verticalArrangement = Arrangement.spacedBy(NayaraSpacing.Sm), modifier = Modifier.padding(top = NayaraSpacing.Sm)) {
                        items(resp.rows) { row -> ReportRowCard(row, resp.rewardValueConfigured) }
                        item {
                            Card(Modifier.fillMaxWidth()) {
                                Row(Modifier.fillMaxWidth().padding(NayaraSpacing.CardPadding), horizontalArrangement = Arrangement.SpaceBetween) {
                                    Text("Total", fontWeight = FontWeight.Bold)
                                    Text("${resp.totals.litres} L · ${money(resp.totals.amount)}", fontWeight = FontWeight.Bold)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun ReportRowCard(row: ReportRowDto, rewardValueConfigured: Boolean) {
    Card(Modifier.fillMaxWidth()) {
        Column(Modifier.padding(NayaraSpacing.CardPadding)) {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                Text(row.label, fontWeight = FontWeight.SemiBold, modifier = Modifier.weight(1f))
                Text(row.period, style = MaterialTheme.typography.bodySmall)
            }
            // Six stats no longer fit a narrow screen — scroll rather than clip.
            Row(
                Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()).padding(top = NayaraSpacing.Xs),
                horizontalArrangement = Arrangement.spacedBy(NayaraSpacing.Md),
            ) {
                Stat("Litres", "${row.litres}")
                Stat("Amount", money(row.amount))
                Stat("Discount", money(row.discount))
                Stat("Reward", rewardMoney(row.gifts, rewardValueConfigured))
                Stat("Gifts", "${row.giftCount}")
                Stat("Visits", "${row.visits}")
            }
        }
    }
}

@Composable
private fun Stat(label: String, value: String) {
    Column {
        Text(label, style = MaterialTheme.typography.labelSmall)
        Text(value, style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.Medium)
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ChipRow(label: String, options: List<String>, selected: String, onSelect: (String) -> Unit) {
    Row(
        Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()).padding(vertical = NayaraSpacing.Xs),
        horizontalArrangement = Arrangement.spacedBy(NayaraSpacing.Sm),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(label, style = MaterialTheme.typography.labelMedium)
        options.forEach { option ->
            FilterChip(
                selected = option == selected,
                onClick = { onSelect(option) },
                label = { Text(option.replaceFirstChar { it.uppercase() }) },
            )
        }
    }
}
