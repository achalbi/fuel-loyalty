package com.acefuel.loyalty.ui.admin.transactions

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import com.acefuel.loyalty.core.di.LocalContainer
import com.acefuel.loyalty.ui.designsystem.EmptyState
import com.acefuel.loyalty.ui.designsystem.ErrorState
import com.acefuel.loyalty.ui.designsystem.NayaraCard
import com.acefuel.loyalty.ui.designsystem.NayaraPullToRefresh
import com.acefuel.loyalty.ui.designsystem.NayaraSnackbarHost
import com.acefuel.loyalty.ui.designsystem.PickerField
import com.acefuel.loyalty.ui.designsystem.SkeletonList
import com.acefuel.loyalty.ui.designsystem.rememberHaptics
import com.acefuel.loyalty.ui.designsystem.showError
import com.acefuel.loyalty.ui.theme.NayaraMotion
import com.acefuel.loyalty.ui.theme.NayaraNumerals
import com.acefuel.loyalty.ui.theme.NayaraOutlinedButton
import com.acefuel.loyalty.ui.theme.NayaraSpacing
import com.acefuel.loyalty.ui.theme.nayara
import java.time.OffsetDateTime
import java.time.format.DateTimeFormatter

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AdminTransactionsScreen(onBack: () -> Unit) {
    val container = LocalContainer.current
    val repo = remember {
        TransactionsRepository(container.retrofit.create(TransactionsApi::class.java), container.json)
    }
    val vm: TransactionsViewModel = viewModel(factory = viewModelFactory { initializer { TransactionsViewModel(repo) } })
    val state by vm.state.collectAsStateWithLifecycle()
    val haptics = rememberHaptics()
    val snackbar = remember { SnackbarHostState() }
    val listState = rememberLazyListState()

    // Failure with stale rows kept on screen -> one-shot error snackbar.
    LaunchedEffect(state.errorMessage) {
        state.errorMessage?.let {
            haptics.reject()
            snackbar.showError(it)
            vm.consumeErrorMessage()
        }
    }

    // Page change jumps back to the top of the new page.
    LaunchedEffect(state.page) {
        listState.animateScrollToItem(0)
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Transactions") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                },
            )
        },
        snackbarHost = { NayaraSnackbarHost(snackbar) },
    ) { innerPadding ->
        Column(Modifier.fillMaxSize().padding(innerPadding)) {
            // Paging / re-filter with rows still on screen.
            if (state.loading && state.transactions.isNotEmpty()) {
                LinearProgressIndicator(Modifier.fillMaxWidth())
            }
            NayaraPullToRefresh(
                isRefreshing = state.refreshing,
                onRefresh = vm::refresh,
                modifier = Modifier.weight(1f),
            ) {
                LazyColumn(
                    state = listState,
                    modifier = Modifier.fillMaxSize().padding(horizontal = NayaraSpacing.ScreenMargin),
                    verticalArrangement = Arrangement.spacedBy(NayaraSpacing.Md),
                    contentPadding = PaddingValues(top = NayaraSpacing.Md, bottom = NayaraSpacing.Xxl),
                ) {
                    item(key = "filters") { FilterSection(state, vm) }

                    when {
                        state.loading && state.transactions.isEmpty() ->
                            item(key = "skeleton") { SkeletonList(count = 8, showAvatar = false) }
                        state.error != null && state.transactions.isEmpty() ->
                            item(key = "error") {
                                ErrorState(state.error ?: "Something went wrong.", onRetry = vm::load)
                            }
                        state.transactions.isEmpty() ->
                            item(key = "empty") {
                                EmptyState(
                                    title = "No transactions found",
                                    message = if (state.range == "today") {
                                        "No fuel transactions have been recorded today."
                                    } else {
                                        "No fuel transactions have been recorded yet."
                                    },
                                    actionLabel = if (state.range != "all") "Show all" else null,
                                    onAction = if (state.range != "all") ({ vm.setRange("all") }) else null,
                                )
                            }
                        else -> {
                            items(state.transactions, key = { "txn-${it.id}" }) { txn ->
                                TransactionCard(
                                    txn = txn,
                                    expanded = state.expandedId == txn.id,
                                    onClick = { vm.toggleExpanded(txn.id) },
                                    modifier = Modifier.animateItem(),
                                )
                            }
                            item(key = "pagination") { PaginationRow(state, vm) }
                        }
                    }
                }
            }
        }
    }
}

// ============================================================================
// Filters (range chips + sort dropdown)
// ============================================================================

@Composable
private fun FilterSection(state: TransactionsUiState, vm: TransactionsViewModel) {
    val haptics = rememberHaptics()
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Text("Range", style = MaterialTheme.typography.labelMedium, color = MaterialTheme.nayara.textSecondary)
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            RANGE_OPTIONS.forEach { (value, label) ->
                FilterChip(
                    selected = state.range == value,
                    onClick = {
                        haptics.tick()
                        vm.setRange(value)
                    },
                    label = { Text(label) },
                )
            }
        }
        Text("Sort", style = MaterialTheme.typography.labelMedium, color = MaterialTheme.nayara.textSecondary)
        SortDropdown(
            selectedLabel = state.sortLabel,
            onSelect = {
                haptics.tick()
                vm.setSort(it)
            },
        )
    }
}

/** Tap-to-open dropdown on the stable [DropdownMenu] API (no experimental ExposedDropdown). */
@Composable
private fun SortDropdown(selectedLabel: String, onSelect: (String) -> Unit) {
    var expanded by remember { mutableStateOf(false) }
    Box(Modifier.fillMaxWidth()) {
        PickerField(
            label = "Sort by",
            value = selectedLabel,
            onClick = { expanded = true },
            modifier = Modifier.fillMaxWidth(),
        )
        DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
            SORT_OPTIONS.forEach { (value, text) ->
                DropdownMenuItem(text = { Text(text) }, onClick = { onSelect(value); expanded = false })
            }
        }
    }
}

// ============================================================================
// Transaction row (tap to expand full detail)
// ============================================================================

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun TransactionCard(
    txn: AdminTransactionDto,
    expanded: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    NayaraCard(onClick = onClick, modifier = modifier.fillMaxWidth()) {
        Column(Modifier.padding(NayaraSpacing.Lg)) {
            Row(
                Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.Top,
            ) {
                Column(Modifier.weight(1f).padding(end = 8.dp)) {
                    Text(
                        txn.customerName.ifBlank { "Customer" },
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.SemiBold,
                    )
                    Text(
                        txn.vehicleNumber,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.nayara.textSecondary,
                    )
                }
                Column(horizontalAlignment = Alignment.End) {
                    Text(
                        formatAmount(txn.fuelAmount),
                        style = NayaraNumerals.Default,
                        color = MaterialTheme.nayara.textPrimary,
                    )
                    Text(
                        paymentModeLabel(txn.paymentMode),
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.nayara.textTertiary,
                    )
                }
            }

            Spacer(Modifier.height(6.dp))
            Row(
                Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    formatDateTime(txn.createdAt),
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.nayara.textTertiary,
                )
                val chevronRotation by animateFloatAsState(
                    targetValue = if (expanded) 180f else 0f,
                    animationSpec = tween(NayaraMotion.Base, easing = NayaraMotion.Standard),
                    label = "chevron",
                )
                Icon(
                    imageVector = Icons.Filled.KeyboardArrowDown,
                    contentDescription = if (expanded) "Collapse" else "Expand",
                    tint = MaterialTheme.nayara.textTertiary,
                    modifier = Modifier.rotate(chevronRotation),
                )
            }

            AnimatedVisibility(visible = expanded) {
                Column {
                    Spacer(Modifier.height(10.dp))
                    HorizontalDivider(color = MaterialTheme.nayara.borderDefault)
                    Spacer(Modifier.height(10.dp))
                    DetailRow("Customer", txn.customerName.ifBlank { "—" })
                    DetailRow("Phone", txn.phoneNumber?.let { "+91 $it" } ?: "Not on file")
                    DetailRow("Vehicle", txn.vehicleNumber)
                    DetailRow("Fuel Type", txn.fuelType ?: "—")
                    DetailRow("Vehicle Type", txn.vehicleKind ?: "—")
                    DetailRow("Fuel Amount", formatAmount(txn.fuelAmount))
                    DetailRow("Payment Mode", paymentModeLabel(txn.paymentMode))
                    DetailRow("Pump", txn.pump ?: "Not recorded")
                    DetailRow("Nozzle", txn.nozzle ?: "Not recorded")
                    DetailRow("Handled By", txn.handledBy ?: "—")
                    DetailRow("Recorded", formatDateTime(txn.createdAt))
                }
            }
        }
    }
}

@Composable
private fun DetailRow(label: String, value: String) {
    Row(
        Modifier.fillMaxWidth().padding(vertical = 4.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.Top,
    ) {
        Text(
            label,
            style = MaterialTheme.typography.labelMedium,
            color = MaterialTheme.nayara.textTertiary,
            modifier = Modifier.padding(end = 12.dp),
        )
        Text(
            value,
            style = MaterialTheme.typography.bodyMedium,
            fontWeight = FontWeight.Medium,
            modifier = Modifier.weight(1f, fill = false),
        )
    }
}

// ============================================================================
// Pagination
// ============================================================================

@Composable
private fun PaginationRow(state: TransactionsUiState, vm: TransactionsViewModel) {
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Text(
            "Showing ${state.showingFrom}–${state.showingTo} of ${state.total}",
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.nayara.textTertiary,
        )
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            NayaraOutlinedButton(onClick = { vm.prevPage() }, enabled = state.canPrev && !state.loading) { Text("Previous") }
            Text("Page ${state.page}", style = MaterialTheme.typography.labelMedium)
            NayaraOutlinedButton(onClick = { vm.nextPage() }, enabled = state.canNext && !state.loading) { Text("Next") }
        }
    }
}

// ============================================================================
// Formatting helpers
// ============================================================================

private val DATE_TIME_FMT: DateTimeFormatter = DateTimeFormatter.ofPattern("dd MMM yyyy · hh:mm a")

private fun formatAmount(amount: Double): String = "₹%.2f".format(amount)

private fun paymentModeLabel(mode: String?): String =
    mode?.takeIf { it.isNotBlank() }
        ?.replace('_', ' ')
        ?.replaceFirstChar { it.uppercase() }
        ?: "—"

private fun formatDateTime(iso: String?): String = iso?.let { s ->
    runCatching { OffsetDateTime.parse(s).format(DATE_TIME_FMT) }
        .recoverCatching { java.time.LocalDateTime.parse(s).format(DATE_TIME_FMT) }
        .getOrDefault(s)
} ?: "—"
