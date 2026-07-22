package com.acefuel.loyalty.ui.admin.crm

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.PhoneForwarded
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
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
import com.acefuel.loyalty.ui.theme.NayaraSpacing
import com.acefuel.loyalty.ui.theme.nayara

// ============================================================================
// Reach out — Phase 4 CRM. The admin's daily churn worklist: customers overdue
// past their usual visit cadence, ranked by conversion probability, each a tap
// away from their profile (where insight + outreach logging live).
// ============================================================================

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AdminReachOutScreen(onBack: () -> Unit, onOpenCustomer: (Long) -> Unit) {
    val container = LocalContainer.current
    val viewModel: ReachOutViewModel = viewModel(
        factory = viewModelFactory {
            initializer {
                ReachOutViewModel(CrmRepository(container.retrofit.create(CrmApi::class.java), container.json))
            }
        },
    )
    val state by viewModel.state.collectAsStateWithLifecycle()

    Scaffold(topBar = { NayaraTopBar(title = "Reach out", onBack = onBack) }) { padding ->
        Box(Modifier.fillMaxSize().padding(padding)) {
            when {
                state.loading ->
                    Box(Modifier.fillMaxSize(), Alignment.Center) { CircularProgressIndicator() }

                state.error != null ->
                    ErrorState(
                        message = state.error!!,
                        modifier = Modifier.fillMaxSize(),
                        onRetry = viewModel::load,
                    )

                state.response?.customers.isNullOrEmpty() ->
                    EmptyState(
                        title = "No one's overdue",
                        message = "Customers who lapse past their usual visit cadence show up here for follow-up.",
                        icon = Icons.AutoMirrored.Filled.PhoneForwarded,
                        modifier = Modifier.fillMaxSize(),
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
                        item(key = "period") { PeriodHeader(resp) }
                        items(resp.customers, key = { it.id }) { customer ->
                            ChurnCustomerCard(customer, onClick = { onOpenCustomer(customer.id) })
                        }
                        if (resp.hasMore) {
                            item(key = "more") {
                                Text(
                                    "Showing ${resp.customers.size} of ${resp.total} overdue customers",
                                    style = MaterialTheme.typography.labelSmall,
                                    color = MaterialTheme.nayara.textTertiary,
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun PeriodHeader(resp: ChurnResponse) {
    val period = periodRange(resp.period)
    val previous = periodRange(resp.previousPeriod)
    Column {
        Text(
            "${resp.total} overdue",
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.SemiBold,
            color = MaterialTheme.nayara.textPrimary,
        )
        if (period != null) {
            Text(
                "This period: $period",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.nayara.textSecondary,
            )
        }
        if (previous != null) {
            Text(
                "Compared with: $previous",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.nayara.textTertiary,
            )
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun ChurnCustomerCard(c: ChurnCustomerDto, onClick: () -> Unit) {
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
                    c.name,
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.SemiBold,
                    modifier = Modifier.weight(1f),
                )
                ProbabilityBadge(c.conversionProbability)
            }
            FlowRow(
                horizontalArrangement = Arrangement.spacedBy(NayaraSpacing.Sm),
                verticalArrangement = Arrangement.spacedBy(NayaraSpacing.Xs),
            ) {
                StatusChip(label = c.customerTypeLabel, tone = ChipTone.Neutral, showDot = false)
                StatusChip(label = c.cadenceLabel, tone = ChipTone.Info, showDot = false)
                c.daysOverdue?.takeIf { it > 0 }?.let {
                    StatusChip(label = "$it days overdue", tone = ChipTone.Warning, showDot = false)
                }
            }
            Text(
                "Last visit: ${c.lastVisitedOn ?: "—"} · ${c.visitCount} visits",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.nayara.textSecondary,
            )
            c.expectedNextVisitOn?.let {
                Text(
                    "Expected next: $it",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.nayara.textTertiary,
                )
            }
            c.contacts.lastContactedAt?.let {
                val outcome = c.contacts.lastOutcomeLabel ?: c.contacts.lastOutcome
                Text(
                    "Last contacted: $it" + (outcome?.let { o -> " · $o" } ?: ""),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.nayara.textTertiary,
                )
            }
        }
    }
}

/** Conversion probability badge: >=60 success, >=30 warning, else error. */
@Composable
private fun ProbabilityBadge(probability: Int) {
    val tone = when {
        probability >= 60 -> ChipTone.Success
        probability >= 30 -> ChipTone.Warning
        else -> ChipTone.Error
    }
    StatusChip(label = "$probability%", tone = tone, showDot = false)
}

private fun periodRange(period: ChurnPeriodDto): String? {
    val start = period.startDate
    val end = period.endDate
    return when {
        start != null && end != null -> "$start → $end"
        start != null -> start
        end != null -> end
        else -> null
    }
}
