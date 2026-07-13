package com.acefuel.loyalty.ui.admin.dashboard

import androidx.compose.foundation.background
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.rememberScrollState
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import com.acefuel.loyalty.core.di.LocalContainer
import com.acefuel.loyalty.ui.theme.NayaraHeroCard
import com.acefuel.loyalty.ui.theme.nayara
import kotlin.math.abs

/** Quick-range chips. `null` value = the API's default rolling 30-day window. */
private val PRESET_CHIPS: List<Pair<String?, String>> = listOf(
    null to "Last 30 days",
    "today" to "Today",
    "this_week" to "This week",
    "this_month" to "This month",
    "last_month" to "Last month",
)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AdminDashboardScreen(onBack: () -> Unit) {
    val container = LocalContainer.current
    val repo = remember {
        DashboardRepository(container.retrofit.create(DashboardApi::class.java), container.json)
    }
    val vm: DashboardViewModel = viewModel(factory = viewModelFactory { initializer { DashboardViewModel(repo) } })
    val state by vm.state.collectAsStateWithLifecycle()

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Dashboard") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                },
            )
        },
    ) { innerPadding ->
        Column(modifier = Modifier.fillMaxSize().padding(innerPadding)) {
            // Pinned quick-range chip row — always tappable, even while loading.
            Column(
                modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp),
                verticalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                Text("Quick range", style = MaterialTheme.typography.labelMedium, color = MaterialTheme.nayara.textSecondary)
                ChipRow(
                    options = PRESET_CHIPS,
                    labelOf = { it.second },
                    selectedOf = { it.first == state.preset },
                    onSelect = { vm.selectPreset(it.first) },
                )
            }

            val data = state.data
            when {
                state.loading && data == null ->
                    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        CircularProgressIndicator()
                    }

                state.error != null && data == null ->
                    Box(Modifier.fillMaxSize().padding(16.dp), contentAlignment = Alignment.TopCenter) {
                        ErrorCard(state.error!!)
                    }

                data == null ->
                    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        Text("No dashboard data available.", color = MaterialTheme.nayara.textSecondary)
                    }

                else -> {
                    val activeSegment = data.filters.segment ?: state.segment ?: "all"
                    val activeFuel = data.filters.fuelType ?: state.fuelType ?: "all"
                    val kpiRows = data.summary.chunked(2)

                    LazyColumn(
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = PaddingValues(16.dp),
                        verticalArrangement = Arrangement.spacedBy(12.dp),
                    ) {
                        item(key = "hero") { HeroHeader(data, loading = state.loading) }

                        if (data.filters.segments.isNotEmpty()) {
                            item(key = "segments") {
                                ChipSection(
                                    title = "Customer segment",
                                    options = data.filters.segments,
                                    labelOf = { it.label },
                                    selectedOf = { it.value == activeSegment },
                                    onSelect = { vm.selectSegment(it.value) },
                                )
                            }
                        }

                        if (data.filters.fuelTypes.size > 1) {
                            item(key = "fuels") {
                                ChipSection(
                                    title = "Fuel type",
                                    options = data.filters.fuelTypes,
                                    labelOf = { it.label },
                                    selectedOf = { it.value == activeFuel },
                                    onSelect = { vm.selectFuelType(it.value) },
                                )
                            }
                        }

                        state.error?.let { message ->
                            item(key = "refresh-error") { ErrorCard(message) }
                        }

                        itemsIndexed(kpiRows, key = { index, _ -> "kpi-row-$index" }) { _, row ->
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.spacedBy(12.dp),
                            ) {
                                row.forEach { card -> KpiCard(card, Modifier.weight(1f)) }
                                if (row.size == 1) Spacer(Modifier.weight(1f))
                            }
                        }

                        item(key = "chart-day") {
                            BarChartCard("Transactions by day of week", data.charts.transactionsByDay)
                        }
                        item(key = "chart-repeat") {
                            BarChartCard("New vs repeat customers", data.charts.repeatVsNew)
                        }
                        item(key = "chart-hour") {
                            BarChartCard("Transactions by hour", data.charts.transactionsByHour)
                        }

                        item(key = "rewards") { RewardsCard(data.rewards) }
                    }
                }
            }
        }
    }
}

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

@Composable
private fun HeroHeader(data: DashboardResponse, loading: Boolean) {
    NayaraHeroCard {
        Text("Analytics overview", style = MaterialTheme.typography.labelLarge)
        Spacer(Modifier.height(4.dp))
        Text(
            data.meta.rangeLabel ?: "Recent activity",
            style = MaterialTheme.typography.titleLarge,
            fontWeight = FontWeight.SemiBold,
        )
        Spacer(Modifier.height(6.dp))
        val subtitle = buildList {
            data.meta.segmentLabel?.let { add(it) }
            data.meta.fuelTypeLabel?.let { add(it) }
        }.joinToString(" • ")
        if (subtitle.isNotBlank()) {
            Text(subtitle, style = MaterialTheme.typography.bodySmall)
        }
        if (loading) {
            Spacer(Modifier.height(10.dp))
            CircularProgressIndicator(modifier = Modifier.size(18.dp), strokeWidth = 2.dp)
        }
    }
}

// ---------------------------------------------------------------------------
// Chip helpers
// ---------------------------------------------------------------------------

@Composable
private fun ChipSection(
    title: String,
    options: List<FilterOptionDto>,
    labelOf: (FilterOptionDto) -> String,
    selectedOf: (FilterOptionDto) -> Boolean,
    onSelect: (FilterOptionDto) -> Unit,
) {
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Text(title, style = MaterialTheme.typography.labelMedium, color = MaterialTheme.nayara.textSecondary)
        ChipRow(options = options, labelOf = labelOf, selectedOf = selectedOf, onSelect = onSelect)
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun <T> ChipRow(
    options: List<T>,
    labelOf: (T) -> String,
    selectedOf: (T) -> Boolean,
    onSelect: (T) -> Unit,
) {
    Row(
        modifier = Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        options.forEach { option ->
            FilterChip(
                selected = selectedOf(option),
                onClick = { onSelect(option) },
                label = { Text(labelOf(option)) },
            )
        }
    }
}

// ---------------------------------------------------------------------------
// KPI cards
// ---------------------------------------------------------------------------

@Composable
private fun KpiCard(card: KpiCardDto, modifier: Modifier = Modifier) {
    Card(
        modifier = modifier,
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.nayara.bgSurface),
    ) {
        Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(
                kpiLabel(card.key),
                style = MaterialTheme.typography.labelMedium,
                color = MaterialTheme.nayara.textSecondary,
            )
            Text(
                card.displayValue.ifBlank { formatNumber(card.value) },
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.Bold,
                color = MaterialTheme.nayara.textPrimary,
            )
            ChangeNote(card.changePct, card.direction)
            card.breakdown?.takeIf { it.isNotEmpty() }?.let { breakdown ->
                Spacer(Modifier.height(2.dp))
                breakdown.forEach { entry ->
                    Text(
                        "${entry.label}: ${entry.displayValue.ifBlank { formatNumber(entry.value) }}",
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.nayara.textTertiary,
                    )
                }
            }
        }
    }
}

@Composable
private fun ChangeNote(changePct: Double?, direction: String?) {
    if (changePct == null) {
        Text(
            "No prior data",
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.nayara.textTertiary,
        )
        return
    }
    when (direction) {
        "up" -> Text(
            "▲ ${formatNumber(abs(changePct))}% vs prev",
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.nayara.statusSuccessText,
        )
        "down" -> Text(
            "▼ ${formatNumber(abs(changePct))}% vs prev",
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.nayara.statusError,
        )
        else -> Text(
            "No change vs prev",
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.nayara.textTertiary,
        )
    }
}

// ---------------------------------------------------------------------------
// Bar chart (Box widths ∝ value — no chart lib)
// ---------------------------------------------------------------------------

@Composable
private fun BarChartCard(title: String, series: BarSeriesDto) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.nayara.bgSurface),
    ) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Text(title, style = MaterialTheme.typography.titleMedium, color = MaterialTheme.nayara.textPrimary)

            val hasData = series.labels.isNotEmpty() && series.values.any { it > 0.0 }
            if (!hasData) {
                Text(
                    "No data for this range.",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.nayara.textSecondary,
                )
            } else {
                val maxValue = series.values.maxOrNull()?.takeIf { it > 0.0 } ?: 1.0
                series.labels.forEachIndexed { index, label ->
                    val value = series.values.getOrNull(index) ?: 0.0
                    val fraction = (value / maxValue).toFloat().coerceIn(0f, 1f)
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        Text(
                            label,
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.nayara.textSecondary,
                            modifier = Modifier.width(52.dp),
                        )
                        Box(
                            modifier = Modifier
                                .weight(1f)
                                .height(16.dp)
                                .clip(MaterialTheme.shapes.small)
                                .background(MaterialTheme.nayara.bgSurfaceSunken),
                        ) {
                            if (fraction > 0f) {
                                Box(
                                    modifier = Modifier
                                        .fillMaxWidth(fraction)
                                        .fillMaxHeight()
                                        .clip(MaterialTheme.shapes.small)
                                        .background(MaterialTheme.nayara.actionPrimary),
                                )
                            }
                        }
                        Text(
                            formatNumber(value),
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.nayara.textPrimary,
                            modifier = Modifier.width(40.dp),
                        )
                    }
                }
            }
        }
    }
}

// ---------------------------------------------------------------------------
// Rewards summary
// ---------------------------------------------------------------------------

@Composable
private fun RewardsCard(rewards: RewardsSummaryDto) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.nayara.bgSurface),
    ) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Text("Rewards", style = MaterialTheme.typography.titleMedium, color = MaterialTheme.nayara.textPrimary)
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                RewardStat("Redemption rate", "${formatNumber(rewards.redemptionRate)}%", Modifier.weight(1f))
                RewardStat("Points issued", formatNumber(rewards.issuedPoints.toDouble()), Modifier.weight(1f))
                RewardStat("Points redeemed", formatNumber(rewards.redeemedPoints.toDouble()), Modifier.weight(1f))
            }
            rewards.note?.takeIf { it.isNotBlank() }?.let { note ->
                Text(note, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.nayara.textTertiary)
            }
        }
    }
}

@Composable
private fun RewardStat(label: String, value: String, modifier: Modifier = Modifier) {
    Column(modifier = modifier, verticalArrangement = Arrangement.spacedBy(2.dp)) {
        Text(
            value,
            style = MaterialTheme.typography.titleLarge,
            fontWeight = FontWeight.Bold,
            color = MaterialTheme.nayara.rewardPointsText,
        )
        Text(label, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.nayara.textSecondary)
    }
}

// ---------------------------------------------------------------------------
// Error card
// ---------------------------------------------------------------------------

@Composable
private fun ErrorCard(message: String) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.errorContainer),
    ) {
        Text(
            message,
            modifier = Modifier.padding(16.dp),
            color = MaterialTheme.colorScheme.onErrorContainer,
            style = MaterialTheme.typography.bodyMedium,
        )
    }
}

// ---------------------------------------------------------------------------
// Formatting helpers
// ---------------------------------------------------------------------------

private fun kpiLabel(key: String): String = when (key) {
    "total_customers" -> "Total customers"
    "active_customers" -> "Active customers"
    "total_transactions" -> "Transactions"
    "total_revenue" -> "Revenue"
    "points_issued" -> "Points issued"
    "points_redeemed" -> "Points redeemed"
    "avg_spend_per_visit" -> "Avg spend / visit"
    "visits_per_customer" -> "Visits / customer"
    else -> key.replace('_', ' ').replaceFirstChar { it.uppercase() }
}

/** Render whole numbers without a trailing ".0"; keep one decimal otherwise. */
private fun formatNumber(value: Double): String =
    if (value % 1.0 == 0.0) value.toLong().toString() else String.format("%.1f", value)
