package com.acefuel.loyalty.ui.admin.crm

import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.SearchOff
import androidx.compose.material.icons.filled.Tune
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
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
import com.acefuel.loyalty.ui.designsystem.ChipTone
import com.acefuel.loyalty.ui.designsystem.EmptyState
import com.acefuel.loyalty.ui.designsystem.ErrorState
import com.acefuel.loyalty.ui.designsystem.NayaraCard
import com.acefuel.loyalty.ui.designsystem.NayaraTopBar
import com.acefuel.loyalty.ui.designsystem.StatusChip
import com.acefuel.loyalty.ui.theme.NayaraButton
import com.acefuel.loyalty.ui.theme.NayaraOutlinedButton
import com.acefuel.loyalty.ui.theme.NayaraSpacing
import com.acefuel.loyalty.ui.theme.nayara

// ============================================================================
// Segments — staff feedback item 4. "As an Admin, I should be able to see
// customers who have visited us x number of times, who have filled x number of
// litres, whom I have contacted x number of times, whom we have given x amount
// of discount, who has accumulated x number of reward points."
//
// ADMIN-ONLY, AND A SEPARATE SCREEN ON PURPOSE. The customer list itself
// (CustomersScreen) is shared verbatim with staff — AdminShell renders the very
// same composable. Hanging these controls off that screen would either show
// staff filters they must not have, or have them call an endpoint that 403s.
// So the cohort lives here, behind the Customers tab's "Segments" action, which
// only the admin shell passes in.
//
// The period presets mirror the dashboard's, and the figures are computed
// server-side (Admin::Crm::CustomerMetrics) so the app can never disagree with
// the web console about what "5 visits" means.
// ============================================================================

private val PERIOD_PRESETS: List<Pair<String?, String>> = listOf(
    null to "All time",
    "today" to "Today",
    "this_week" to "This week",
    "this_month" to "This month",
    "last_month" to "Last month",
)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AdminCustomerSegmentsScreen(onBack: () -> Unit, onOpenCustomer: (Long) -> Unit) {
    val container = LocalContainer.current
    val viewModel: CustomerSegmentsViewModel = viewModel(
        factory = viewModelFactory {
            initializer {
                CustomerSegmentsViewModel(CrmRepository(container.retrofit.create(CrmApi::class.java), container.json))
            }
        },
    )
    val state by viewModel.state.collectAsStateWithLifecycle()
    // Collapsed by default: the useful default view is "everyone, newest first",
    // and six numeric fields permanently open would bury the results.
    var filtersOpen by remember { mutableStateOf(false) }

    Scaffold(
        topBar = {
            NayaraTopBar(
                title = "Segments",
                onBack = onBack,
                actions = {
                    TextButton(onClick = { filtersOpen = !filtersOpen }) {
                        Text(if (filtersOpen) "Hide filters" else "Filters")
                    }
                },
            )
        },
    ) { padding ->
        Column(Modifier.fillMaxSize().padding(padding)) {
            if (filtersOpen) {
                // Capped and scrollable: six fields plus the preset chips are
                // taller than a small phone, and the results below must keep a
                // usable share of the screen rather than being squeezed to zero.
                FilterPanel(
                    filters = state.filters,
                    onChange = viewModel::onFiltersChange,
                    onApply = { viewModel.load() },
                    onClear = viewModel::clear,
                    modifier = Modifier
                        .heightIn(max = 380.dp)
                        .verticalScroll(rememberScrollState()),
                )
            }

            Box(Modifier.weight(1f).fillMaxWidth()) {
                when {
                    state.loading && state.response == null ->
                        Box(Modifier.fillMaxSize(), Alignment.Center) { CircularProgressIndicator() }

                    state.error != null ->
                        ErrorState(
                            message = state.error!!,
                            modifier = Modifier.fillMaxSize(),
                            onRetry = { viewModel.load() },
                        )

                    state.response?.customers.isNullOrEmpty() ->
                        EmptyState(
                            title = "No customers in this cohort",
                            message = "Nobody clears every threshold you set. Loosen one and apply again.",
                            icon = Icons.Filled.SearchOff,
                            modifier = Modifier.fillMaxSize(),
                            actionLabel = if (state.filters.appliedCount > 0) "Clear filters" else null,
                            onAction = if (state.filters.appliedCount > 0) viewModel::clear else null,
                        )

                    else -> {
                        val resp = state.response!!
                        LazyColumn(
                            modifier = Modifier.fillMaxSize(),
                            verticalArrangement = Arrangement.spacedBy(NayaraSpacing.Md),
                            contentPadding = PaddingValues(
                                start = NayaraSpacing.ScreenMargin,
                                end = NayaraSpacing.ScreenMargin,
                                top = NayaraSpacing.Md,
                                bottom = NayaraSpacing.Xxl,
                            ),
                        ) {
                            item(key = "summary") { CohortSummary(resp, state.filters) }
                            items(resp.customers, key = { it.id }) { customer ->
                                CohortCustomerCard(customer, onClick = { onOpenCustomer(customer.id) })
                            }
                            // Paging is server-side (OFFSET/LIMIT): a cohort over the
                            // whole customer base is not something to pull down whole.
                            //
                            // BOTH buttons whenever either direction exists, each
                            // enabled on its own condition — the web pager does the
                            // same. Rendering "Next" and only falling back to
                            // "Previous" in an else branch stranded the admin on page
                            // 2 of 5: forward was offered, backward was not drawn at
                            // all, and the only way back was leaving the screen.
                            if (resp.page > 1 || resp.hasMore) {
                                item(key = "pager") {
                                    Row(
                                        modifier = Modifier.fillMaxWidth(),
                                        horizontalArrangement = Arrangement.spacedBy(NayaraSpacing.Md),
                                    ) {
                                        NayaraOutlinedButton(
                                            onClick = { viewModel.load(page = resp.page - 1) },
                                            modifier = Modifier.weight(1f),
                                            enabled = resp.page > 1,
                                        ) { Text("Previous") }
                                        NayaraOutlinedButton(
                                            onClick = { viewModel.load(page = resp.page + 1) },
                                            modifier = Modifier.weight(1f),
                                            enabled = resp.hasMore,
                                        ) { Text("Next ${resp.perPage} of ${resp.total}") }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun FilterPanel(
    filters: SegmentFilters,
    onChange: (SegmentFilters) -> Unit,
    onApply: () -> Unit,
    onClear: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = NayaraSpacing.ScreenMargin, vertical = NayaraSpacing.Sm),
        verticalArrangement = Arrangement.spacedBy(NayaraSpacing.Sm),
    ) {
        // "Active in period", not "date range": picking a period narrows the list
        // to customers who actually fuelled in it, and that gate AND-combines with
        // every threshold below — including the lifetime points balance. Same
        // wording as the web console's period banner.
        Text(
            "Active in period",
            style = MaterialTheme.typography.labelMedium,
            color = MaterialTheme.nayara.textSecondary,
        )
        Row(
            modifier = Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()),
            horizontalArrangement = Arrangement.spacedBy(NayaraSpacing.Sm),
        ) {
            PERIOD_PRESETS.forEach { (value, label) ->
                FilterChip(
                    selected = filters.preset == value,
                    onClick = { onChange(filters.copy(preset = value)) },
                    label = { Text(label) },
                )
            }
        }

        // Whole numbers for counts, decimals for litres and rupees.
        ThresholdField("Visited at least", "times", filters.minVisits, KeyboardType.Number) {
            onChange(filters.copy(minVisits = it))
        }
        ThresholdField("Filled at least", "litres", filters.minLitres, KeyboardType.Decimal) {
            onChange(filters.copy(minLitres = it))
        }
        ThresholdField("Discount given at least", "₹", filters.minDiscount, KeyboardType.Decimal) {
            onChange(filters.copy(minDiscount = it))
        }
        ThresholdField("Contacted at least", "times", filters.minContacts, KeyboardType.Number) {
            onChange(filters.copy(minContacts = it))
        }
        ThresholdField("Points earned at least", "points in period", filters.minPointsEarned, KeyboardType.Number) {
            onChange(filters.copy(minPointsEarned = it))
        }
        // The other half of the client's decision: the lifetime balance is a
        // different cohort from what was earned in the window, never windowed —
        // though with a period selected the LIST is still only customers active in
        // it, which is why the caption spells that out rather than leaving the
        // admin to wonder where the dormant big balances went.
        ThresholdField("Points balance at least", "points (lifetime)", filters.minPointsBalance, KeyboardType.Number) {
            onChange(filters.copy(minPointsBalance = it))
        }
        if (filters.preset != null) {
            Text(
                "The balance is lifetime, but a period still lists only customers active in it. Pick \"All time\" for dormant balances.",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.nayara.textTertiary,
            )
        }

        Row(horizontalArrangement = Arrangement.spacedBy(NayaraSpacing.Md)) {
            NayaraOutlinedButton(onClick = onClear, modifier = Modifier.weight(1f)) { Text("Clear") }
            NayaraButton(onClick = onApply, modifier = Modifier.weight(1f)) { Text("Apply") }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ThresholdField(
    label: String,
    unit: String,
    value: String,
    keyboardType: KeyboardType,
    onValueChange: (String) -> Unit,
) {
    OutlinedTextField(
        value = value,
        // Strip anything that is not a digit or a decimal point up front — the
        // server drops unparseable values anyway, but silently returning the full
        // list because someone typed a stray letter would look like a bug.
        onValueChange = { entered -> onValueChange(entered.filter { it.isDigit() || it == '.' }) },
        label = { Text(label) },
        suffix = { Text(unit) },
        singleLine = true,
        keyboardOptions = KeyboardOptions(keyboardType = keyboardType),
        modifier = Modifier.fillMaxWidth(),
    )
}

@Composable
private fun CohortSummary(resp: CustomerCohortResponse, filters: SegmentFilters) {
    Column {
        Text(
            "${resp.total} customers",
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.SemiBold,
            color = MaterialTheme.nayara.textPrimary,
        )
        val period = listOfNotNull(resp.period.startDate, resp.period.endDate)
        Text(
            if (period.size == 2) "Active between ${period[0]} and ${period[1]}" else "All time",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.nayara.textSecondary,
        )
        if (filters.appliedCount > 0) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(
                    Icons.Filled.Tune,
                    contentDescription = null,
                    tint = MaterialTheme.nayara.textTertiary,
                )
                Text(
                    "${filters.appliedCount} threshold${if (filters.appliedCount == 1) "" else "s"} applied",
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.nayara.textTertiary,
                )
            }
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun CohortCustomerCard(customer: CohortCustomerDto, onClick: () -> Unit) {
    NayaraCard(onClick = onClick, modifier = Modifier.fillMaxWidth()) {
        Column(
            Modifier.padding(NayaraSpacing.Lg),
            verticalArrangement = Arrangement.spacedBy(NayaraSpacing.Xs),
        ) {
            Row(
                Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    customer.name,
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.SemiBold,
                    modifier = Modifier.weight(1f),
                )
                StatusChip(
                    label = if (customer.active) "Active" else "Inactive",
                    tone = if (customer.active) ChipTone.Success else ChipTone.Neutral,
                    showDot = false,
                )
            }
            Text(
                "+91 ${customer.phoneNumber} · ${customer.customerTypeLabel}",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.nayara.textSecondary,
            )
            if (customer.vehicleNumbers.isNotEmpty()) {
                Text(
                    customer.vehicleNumbers.joinToString(", "),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.nayara.textTertiary,
                )
            }
            FlowRow(
                horizontalArrangement = Arrangement.spacedBy(NayaraSpacing.Sm),
                verticalArrangement = Arrangement.spacedBy(NayaraSpacing.Xs),
            ) {
                val metrics = customer.metrics
                StatusChip(label = "${metrics.visitCount} visits", tone = ChipTone.Info, showDot = false)
                StatusChip(label = "%.2f L".format(metrics.litresTotal), tone = ChipTone.Neutral, showDot = false)
                StatusChip(label = "₹%.2f off".format(metrics.discountTotal), tone = ChipTone.Neutral, showDot = false)
                StatusChip(label = "${metrics.contactCount} contacts", tone = ChipTone.Neutral, showDot = false)
                StatusChip(label = "${metrics.pointsEarned} earned", tone = ChipTone.Neutral, showDot = false)
                StatusChip(label = "${metrics.pointsBalance} pts", tone = ChipTone.Warning, showDot = false)
            }
        }
    }
}
