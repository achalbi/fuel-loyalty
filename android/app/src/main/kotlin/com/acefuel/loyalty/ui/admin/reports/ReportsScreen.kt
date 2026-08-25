package com.acefuel.loyalty.ui.admin.reports

import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.FilterList
import androidx.compose.material3.AssistChip
import androidx.compose.material3.Badge
import androidx.compose.material3.BadgedBox
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import com.acefuel.loyalty.core.di.LocalContainer
import com.acefuel.loyalty.ui.designsystem.DateField
import com.acefuel.loyalty.ui.designsystem.FormField
import com.acefuel.loyalty.ui.designsystem.NayaraBottomSheet
import com.acefuel.loyalty.ui.designsystem.NayaraTopBar
import com.acefuel.loyalty.ui.theme.NayaraSpacing

private fun money(v: Double?): String = if (v == null) "—" else "₹" + "%,.0f".format(v)

/**
 * Reward ₹ is the cash value of points redemptions. With no cash-value-per-point
 * configured, every redemption stored a NULL ₹ and the zero is structural — so it
 * renders "—" rather than an asserted ₹0. A non-zero value always renders.
 */
private fun reward(v: Double, configured: Boolean): String =
    if (configured || v != 0.0) money(v) else "—"

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AdminReportsScreen(onBack: () -> Unit) {
    val container = LocalContainer.current
    val viewModel: ReportsViewModel = viewModel(
        factory = viewModelFactory {
            initializer {
                ReportsViewModel(ReportsRepository(container.retrofit.create(ReportsApi::class.java), container.json))
            }
        },
    )
    val state by viewModel.state.collectAsStateWithLifecycle()
    var filtersOpen by rememberSaveable { mutableStateOf(false) }

    Scaffold(
        topBar = {
            NayaraTopBar(
                title = "Reports",
                onBack = onBack,
                actions = {
                    IconButton(onClick = { filtersOpen = true }) {
                        BadgedBox(badge = { if (state.applied.isActive) Badge() }) {
                            Icon(Icons.Filled.FilterList, contentDescription = "Filters")
                        }
                    }
                },
            )
        },
    ) { padding ->
        Column(Modifier.fillMaxSize().padding(padding).padding(horizontal = NayaraSpacing.ScreenMargin)) {
            ChipRow("By", ReportsUiState.DIMENSIONS, state.dimension, viewModel::onDimension)
            ChipRow("Grain", ReportsUiState.GRAINS, state.grain, viewModel::onGrain)
            state.response?.range?.let { r ->
                if (r.from != null) Text("${r.from} → ${r.to}", style = MaterialTheme.typography.bodySmall)
            }
            // The server echoes back the NORMALIZED lookups it queried with, so the
            // chip for a plate typed "ka 01" reads "KA01" — what actually matched.
            ActiveFilterChips(state.response?.filters, viewModel::removeFilter)

            when {
                state.loading -> Box(Modifier.fillMaxSize(), Alignment.Center) { CircularProgressIndicator() }
                state.error != null -> Text(state.error!!, color = MaterialTheme.colorScheme.error, modifier = Modifier.padding(NayaraSpacing.Md))
                state.response?.rows.isNullOrEmpty() -> EmptyState(state.applied.isActive, viewModel::clearFilters)
                else -> {
                    val resp = state.response!!
                    LazyColumn(verticalArrangement = Arrangement.spacedBy(NayaraSpacing.Sm), modifier = Modifier.padding(top = NayaraSpacing.Sm)) {
                        items(resp.rows) { row -> ReportRowCard(row, resp.rewardValueConfigured) }
                        item { ReportTotalsCard(resp.totals, resp.rewardValueConfigured) }
                        // Mirrors the web page's hint: says WHY the column is blank
                        // instead of leaving an unexplained dash on every row.
                        if (!resp.rewardValueConfigured) {
                            item {
                                Text(
                                    "Reward shows \"—\" because no cash value per point is configured — " +
                                        "set one in reward settings for redemptions to carry a ₹ value.",
                                    style = MaterialTheme.typography.bodySmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                    modifier = Modifier.padding(vertical = NayaraSpacing.Xs),
                                )
                            }
                        }
                    }
                }
            }
        }
    }

    if (filtersOpen) {
        ReportFiltersSheet(
            draft = state.draft,
            onDraft = viewModel::onDraft,
            onApply = { viewModel.applyFilters(); filtersOpen = false },
            onClear = { viewModel.clearFilters(); filtersOpen = false },
            onDismiss = { filtersOpen = false },
        )
    }
}

/**
 * The date range and the four free-text lookups. Edited as a draft and only sent
 * on Apply — a report refetch per keystroke of a transporter's name would be one
 * request per letter.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ReportFiltersSheet(
    draft: ReportFilters,
    onDraft: ((ReportFilters) -> ReportFilters) -> Unit,
    onApply: () -> Unit,
    onClear: () -> Unit,
    onDismiss: () -> Unit,
) {
    NayaraBottomSheet(
        onDismissRequest = onDismiss,
        title = "Filters",
        subtitle = "Lookups combine — a row has to match every field you fill in.",
    ) {
        Column(
            Modifier.heightIn(max = 520.dp).verticalScroll(rememberScrollState()),
            verticalArrangement = Arrangement.spacedBy(NayaraSpacing.Sm),
        ) {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(NayaraSpacing.Sm)) {
                DateField(
                    label = "From",
                    value = draft.startDate,
                    onChange = { date -> onDraft { it.copy(startDate = date) } },
                    placeholder = "Any",
                    modifier = Modifier.weight(1f),
                )
                DateField(
                    label = "To",
                    value = draft.endDate,
                    onChange = { date -> onDraft { it.copy(endDate = date) } },
                    placeholder = "Any",
                    modifier = Modifier.weight(1f),
                )
            }
            // DateField can set a date but not unset one, and clearing the whole
            // sheet to undo a mis-tapped "From" would throw away the lookups too.
            if (draft.startDate != null || draft.endDate != null) {
                TextButton(onClick = { onDraft { it.copy(startDate = null, endDate = null) } }) {
                    Text("Any date")
                }
            }

            FormField(
                value = draft.transporter,
                onValueChange = { value -> onDraft { it.copy(transporter = value) } },
                label = "Transporter",
            )
            FormField(
                value = draft.driverName,
                onValueChange = { value -> onDraft { it.copy(driverName = value) } },
                label = "Driver name",
            )
            FormField(
                value = draft.driverPhone,
                onValueChange = { value -> onDraft { it.copy(driverPhone = value) } },
                label = "Driver mobile",
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Phone),
            )
            FormField(
                value = draft.vehicleNumber,
                onValueChange = { value -> onDraft { it.copy(vehicleNumber = value) } },
                label = "Vehicle number",
                keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Characters),
            )

            Spacer(Modifier.height(NayaraSpacing.Xs))
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(NayaraSpacing.Sm)) {
                OutlinedButton(onClick = onClear, modifier = Modifier.weight(1f)) { Text("Clear all") }
                Button(onClick = onApply, modifier = Modifier.weight(1f)) { Text("Apply") }
            }
        }
    }
}

/** One dismissible chip per lookup the last response was actually filtered by. */
@Composable
private fun ActiveFilterChips(
    filters: ReportFiltersDto?,
    onRemove: ((ReportFilters) -> ReportFilters) -> Unit,
) {
    if (filters == null) return
    val active = listOfNotNull(
        filters.transporter?.takeIf { it.isNotBlank() }
            ?.let { it to { f: ReportFilters -> f.copy(transporter = "") } },
        filters.driverName?.takeIf { it.isNotBlank() }
            ?.let { it to { f: ReportFilters -> f.copy(driverName = "") } },
        filters.driverPhone?.takeIf { it.isNotBlank() }
            ?.let { it to { f: ReportFilters -> f.copy(driverPhone = "") } },
        filters.vehicleNumber?.takeIf { it.isNotBlank() }
            ?.let { it to { f: ReportFilters -> f.copy(vehicleNumber = "") } },
    )
    if (active.isEmpty()) return

    Row(
        Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()).padding(vertical = NayaraSpacing.Xs),
        horizontalArrangement = Arrangement.spacedBy(NayaraSpacing.Sm),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        active.forEach { (label, remove) ->
            AssistChip(
                onClick = { onRemove(remove) },
                label = { Text(label) },
                trailingIcon = { Icon(Icons.Filled.Close, contentDescription = "Remove $label filter") },
            )
        }
    }
}

@Composable
private fun EmptyState(filtered: Boolean, onClear: () -> Unit) {
    Column(Modifier.padding(NayaraSpacing.Md), verticalArrangement = Arrangement.spacedBy(NayaraSpacing.Sm)) {
        Text(
            if (filtered) {
                "No captures match these filters. Try clearing one, or widening the date range."
            } else {
                "No captures in this range."
            },
        )
        if (filtered) TextButton(onClick = onClear) { Text("Clear filters") }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun ReportRowCard(row: ReportRowDto, rewardConfigured: Boolean) {
    Card(Modifier.fillMaxWidth()) {
        Column(Modifier.padding(NayaraSpacing.CardPadding)) {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                Text(row.label, fontWeight = FontWeight.SemiBold, modifier = Modifier.weight(1f))
                Text(row.period, style = MaterialTheme.typography.bodySmall)
            }
            // Six stats never fit one phone-width Row, and a plain Row would clip
            // the last of them off-screen with no scroll to reveal it.
            FlowRow(
                Modifier.fillMaxWidth().padding(top = NayaraSpacing.Xs),
                horizontalArrangement = Arrangement.spacedBy(NayaraSpacing.Md),
                verticalArrangement = Arrangement.spacedBy(NayaraSpacing.Xs),
            ) {
                Stat("Litres", "${row.litres}")
                Stat("Amount", money(row.amount))
                Stat("Discount", money(row.discount))
                // Two different units, deliberately apart: Reward ₹ is the cash
                // value of redemptions; Gifts counts physical campaign gifts.
                Stat("Reward", reward(row.gifts, rewardConfigured))
                Stat("Gifts", "${row.giftCount}")
                Stat("Visits", "${row.visits}")
            }
        }
    }
}

/** Same stat set as a row card, so the total lines up column-for-column with it. */
@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun ReportTotalsCard(totals: ReportTotalsDto, rewardConfigured: Boolean) {
    Card(Modifier.fillMaxWidth()) {
        Column(Modifier.padding(NayaraSpacing.CardPadding)) {
            Text("Total", fontWeight = FontWeight.Bold)
            FlowRow(
                Modifier.fillMaxWidth().padding(top = NayaraSpacing.Xs),
                horizontalArrangement = Arrangement.spacedBy(NayaraSpacing.Md),
                verticalArrangement = Arrangement.spacedBy(NayaraSpacing.Xs),
            ) {
                Stat("Litres", "${totals.litres}")
                Stat("Amount", money(totals.amount))
                Stat("Discount", money(totals.discount))
                Stat("Reward", reward(totals.gifts, rewardConfigured))
                Stat("Gifts", "${totals.giftCount}")
                Stat("Visits", "${totals.visits}")
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
