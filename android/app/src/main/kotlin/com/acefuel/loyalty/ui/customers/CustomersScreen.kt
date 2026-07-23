package com.acefuel.loyalty.ui.customers

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.PeopleOutline
import androidx.compose.material.icons.filled.SearchOff
import androidx.compose.material3.Icon
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
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
import com.acefuel.loyalty.core.network.dto.CustomerSummaryDto
import com.acefuel.loyalty.ui.designsystem.ActiveChip
import com.acefuel.loyalty.ui.designsystem.Avatar
import com.acefuel.loyalty.ui.designsystem.EmptyState
import com.acefuel.loyalty.ui.designsystem.ErrorState
import com.acefuel.loyalty.ui.designsystem.NayaraCard
import com.acefuel.loyalty.ui.designsystem.NayaraPullToRefresh
import com.acefuel.loyalty.ui.designsystem.NayaraSnackbarHost
import com.acefuel.loyalty.ui.designsystem.NayaraTopBar
import com.acefuel.loyalty.ui.designsystem.PointsPill
import com.acefuel.loyalty.ui.designsystem.SearchField
import com.acefuel.loyalty.ui.designsystem.SkeletonList
import com.acefuel.loyalty.ui.designsystem.rememberHaptics
import com.acefuel.loyalty.ui.designsystem.showError
import com.acefuel.loyalty.ui.theme.NayaraSpacing
import com.acefuel.loyalty.ui.theme.nayara

// E4: account-type filter chips (null value = all accounts).
private val CUSTOMER_TYPE_FILTERS: List<Pair<String?, String>> = listOf(
    null to "All",
    "drive_in" to "Drive-in",
    "otp" to "OTP / Fleet",
    "credit" to "Credit",
)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CustomersScreen(
    onBack: (() -> Unit)? = null,
    onOpenCustomer: (Long) -> Unit,
    // E2: when set, scope the list to customers active in this dashboard period.
    startDate: String? = null,
    endDate: String? = null,
) {
    val container = LocalContainer.current
    val viewModel: CustomersViewModel = viewModel(
        key = "customers-${startDate.orEmpty()}-${endDate.orEmpty()}",
        factory = viewModelFactory { initializer { CustomersViewModel(container.staffRepository, startDate, endDate) } },
    )
    val state by viewModel.state.collectAsStateWithLifecycle()
    val snackbar = remember { SnackbarHostState() }
    val haptics = rememberHaptics()

    // Failure with stale results still on screen -> snackbar, keep the list.
    // Failure with nothing to show falls through to the full-area ErrorState.
    LaunchedEffect(state.error) {
        val message = state.error ?: return@LaunchedEffect
        if (state.customers.isNotEmpty()) {
            haptics.reject()
            snackbar.showError(message)
            viewModel.consumeError()
        }
    }

    Scaffold(
        topBar = { NayaraTopBar(title = "Customers", onBack = onBack) },
        snackbarHost = { NayaraSnackbarHost(snackbar) },
    ) { innerPadding ->
        Column(modifier = Modifier.fillMaxSize().padding(innerPadding)) {
            SearchField(
                value = state.query,
                onValueChange = viewModel::onQueryChange,
                placeholder = "Search name, mobile, or vehicle",
                modifier = Modifier.padding(
                    horizontal = NayaraSpacing.ScreenMargin,
                    vertical = NayaraSpacing.Md,
                ),
            )

            // E4: account-type filter (server-side ?type=).
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .horizontalScroll(rememberScrollState())
                    .padding(horizontal = NayaraSpacing.ScreenMargin),
                horizontalArrangement = Arrangement.spacedBy(NayaraSpacing.Sm),
            ) {
                CUSTOMER_TYPE_FILTERS.forEach { (value, label) ->
                    FilterChip(
                        selected = state.typeFilter == value,
                        onClick = { viewModel.onTypeFilterChange(value) },
                        label = { Text(label) },
                    )
                }
            }
            Spacer(Modifier.height(NayaraSpacing.Sm))

            if (state.customers.isNotEmpty()) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .horizontalScroll(rememberScrollState())
                        .padding(horizontal = NayaraSpacing.ScreenMargin),
                    horizontalArrangement = Arrangement.spacedBy(NayaraSpacing.Xs),
                ) {
                    FilterChip(
                        selected = state.letterFilter == null,
                        onClick = { viewModel.onLetterFilterChange(null) },
                        label = { Text("All") },
                    )
                    state.customers
                        .mapNotNull { it.name?.trim()?.firstOrNull()?.uppercaseChar() }
                        .distinct()
                        .sorted()
                        .forEach { letter ->
                            FilterChip(
                                selected = state.letterFilter == letter,
                                onClick = { viewModel.onLetterFilterChange(letter) },
                                label = { Text(letter.toString()) },
                            )
                        }
                }
                Spacer(Modifier.height(NayaraSpacing.Sm))
            }

            NayaraPullToRefresh(
                isRefreshing = state.refreshing,
                onRefresh = viewModel::refresh,
                modifier = Modifier.weight(1f).fillMaxWidth(),
            ) {
                when {
                    // Include refreshing so a pull-to-refresh from the empty/error
                    // state shows skeletons, not a false "No customers yet".
                    (state.loading || state.refreshing) && state.customers.isEmpty() ->
                        SkeletonList(
                            count = 8,
                            modifier = Modifier.padding(horizontal = NayaraSpacing.ScreenMargin),
                        )
                    state.error != null && state.customers.isEmpty() ->
                        // Scrollable so the pull-to-refresh gesture still works here.
                        Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState())) {
                            ErrorState(state.error!!, onRetry = viewModel::retry)
                        }
                    state.visibleCustomers.isEmpty() ->
                        Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState())) {
                            if (state.query.isBlank() && state.letterFilter == null) {
                                EmptyState(
                                    title = "No customers yet",
                                    message = "Customers appear here after their first visit.",
                                    icon = Icons.Filled.PeopleOutline,
                                )
                            } else {
                                EmptyState(
                                    title = "No results",
                                    message = "No customers match",
                                    icon = Icons.Filled.SearchOff,
                                    actionLabel = "Clear search",
                                    onAction = { viewModel.onQueryChange("") },
                                )
                            }
                        }
                    else -> LazyColumn(
                        modifier = Modifier.fillMaxSize(),
                        verticalArrangement = Arrangement.spacedBy(NayaraSpacing.Md),
                        contentPadding = PaddingValues(
                            start = NayaraSpacing.ScreenMargin,
                            end = NayaraSpacing.ScreenMargin,
                            top = NayaraSpacing.Xs,
                            bottom = NayaraSpacing.Xxl,
                        ),
                    ) {
                        items(state.visibleCustomers, key = { it.id }) { customer ->
                            CustomerRow(
                                customer,
                                onClick = { onOpenCustomer(customer.id) },
                                modifier = Modifier.animateItem(),
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun CustomerRow(
    customer: CustomerSummaryDto,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    NayaraCard(onClick = onClick, modifier = modifier.fillMaxWidth()) {
        Row(modifier = Modifier.padding(NayaraSpacing.Lg), verticalAlignment = Alignment.Top) {
            Avatar(customer.name)
            Spacer(Modifier.width(NayaraSpacing.Md))
            Column(Modifier.weight(1f)) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(
                        customer.name ?: "Customer",
                        style = MaterialTheme.typography.titleSmall,
                        fontWeight = FontWeight.SemiBold,
                        modifier = Modifier.weight(1f, fill = false),
                    )
                    ActiveChip(customer.active)
                }
                customer.phoneNumber?.let { Text("+91 $it", style = MaterialTheme.typography.bodySmall) }
                customer.customerType?.takeIf { it != "drive_in" }?.let { type ->
                    val label = when (type) {
                        "otp" -> "OTP / Fleet"
                        "credit" -> "Credit"
                        else -> type
                    }
                    Text(
                        label,
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.nayara.accentDefault,
                    )
                }
                val vehicles = if (customer.vehicleNumbers.isEmpty()) {
                    "No vehicles on file"
                } else {
                    customer.vehicleNumbers.joinToString(", ")
                }
                Text(vehicles, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.nayara.textSecondary)
                Spacer(Modifier.height(NayaraSpacing.Sm))
                PointsPill(customer.totalPoints)
            }
            Spacer(Modifier.width(NayaraSpacing.Sm))
            Icon(
                Icons.AutoMirrored.Filled.KeyboardArrowRight,
                contentDescription = null,
                tint = MaterialTheme.nayara.textTertiary,
                modifier = Modifier
                    .align(Alignment.CenterVertically)
                    .size(20.dp),
            )
        }
    }
}
