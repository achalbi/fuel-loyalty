package com.acefuel.loyalty.ui.customers

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
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
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Agriculture
import androidx.compose.material.icons.filled.DirectionsBus
import androidx.compose.material.icons.filled.DirectionsCar
import androidx.compose.material.icons.filled.LocalShipping
import androidx.compose.material.icons.filled.TwoWheeler
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import com.acefuel.loyalty.core.di.LocalContainer
import com.acefuel.loyalty.core.network.dto.CustomerProfileDto
import com.acefuel.loyalty.core.network.dto.LedgerEntryDto
import com.acefuel.loyalty.core.network.dto.StaffVehicleDto
import com.acefuel.loyalty.core.network.dto.TransactionSummaryDto
import com.acefuel.loyalty.ui.designsystem.AnimatedCounter
import com.acefuel.loyalty.ui.designsystem.Avatar
import com.acefuel.loyalty.ui.designsystem.ConfirmDialog
import com.acefuel.loyalty.ui.designsystem.ErrorState
import com.acefuel.loyalty.ui.designsystem.FuelDot
import com.acefuel.loyalty.ui.designsystem.NayaraCard
import com.acefuel.loyalty.ui.designsystem.NayaraPullToRefresh
import com.acefuel.loyalty.ui.designsystem.NayaraSnackbarHost
import com.acefuel.loyalty.ui.designsystem.NayaraTopBar
import com.acefuel.loyalty.ui.designsystem.PlateChip
import com.acefuel.loyalty.ui.designsystem.SkeletonCard
import com.acefuel.loyalty.ui.designsystem.SkeletonList
import com.acefuel.loyalty.ui.designsystem.rememberHaptics
import com.acefuel.loyalty.ui.designsystem.showError
import com.acefuel.loyalty.ui.designsystem.showSuccess
import com.acefuel.loyalty.ui.theme.NayaraHeroCard
import com.acefuel.loyalty.ui.theme.NayaraNumerals
import com.acefuel.loyalty.ui.theme.NayaraOutlinedButton
import com.acefuel.loyalty.ui.theme.NayaraPalette
import com.acefuel.loyalty.ui.theme.NayaraSpacing
import com.acefuel.loyalty.ui.theme.nayara

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CustomerProfileScreen(customerId: Long, onBack: () -> Unit) {
    val container = LocalContainer.current
    val viewModel: CustomerProfileViewModel = viewModel(
        key = "profile-$customerId",
        factory = viewModelFactory { initializer { CustomerProfileViewModel(container.staffRepository, customerId) } },
    )
    val state by viewModel.state.collectAsStateWithLifecycle()
    val snackbar = remember { SnackbarHostState() }
    val haptics = rememberHaptics()
    var pendingConfirm by remember { mutableStateOf<ProfileAction?>(null) }

    LaunchedEffect(state.actionMessage) {
        val message = state.actionMessage ?: return@LaunchedEffect
        haptics.confirm()
        snackbar.showSuccess(message)
        viewModel.consumeActionMessage()
    }
    LaunchedEffect(state.transientError) {
        val message = state.transientError ?: return@LaunchedEffect
        haptics.reject()
        snackbar.showError(message)
        viewModel.consumeTransientError()
    }

    Scaffold(
        topBar = { NayaraTopBar(title = state.profile?.name ?: "Customer", onBack = onBack) },
        snackbarHost = { NayaraSnackbarHost(snackbar) },
    ) { innerPadding ->
        val profile = state.profile
        when {
            state.loading && profile == null ->
                Column(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(innerPadding)
                        .padding(horizontal = NayaraSpacing.ScreenMargin, vertical = NayaraSpacing.Md),
                    verticalArrangement = Arrangement.spacedBy(NayaraSpacing.Md),
                ) {
                    SkeletonCard(lines = 3)
                    SkeletonList(count = 5, showAvatar = false)
                }
            profile == null ->
                ErrorState(
                    message = state.error ?: "Customer not found.",
                    modifier = Modifier.fillMaxSize().padding(innerPadding),
                    onRetry = viewModel::retry,
                )
            else -> {
                NayaraPullToRefresh(
                    isRefreshing = state.refreshing,
                    onRefresh = viewModel::refresh,
                    modifier = Modifier.fillMaxSize().padding(innerPadding),
                ) {
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
                        item { HeroCard(profile) }
                        item {
                            ActionRow(
                                p = profile,
                                inFlight = state.actionInFlight,
                                onTogglePaused = {
                                    // Pausing is disruptive -> confirm; resuming acts directly.
                                    if (profile.rewardsPaused) viewModel.togglePaused()
                                    else pendingConfirm = ProfileAction.Pause
                                },
                                onToggleActive = {
                                    if (profile.active) pendingConfirm = ProfileAction.Active
                                    else viewModel.toggleActive()
                                },
                            )
                        }

                        item { SectionHeader("Vehicles (${profile.vehicles.size})") }
                        if (profile.vehicles.isEmpty()) {
                            item { EmptyNote("No vehicles registered yet.") }
                        } else {
                            items(profile.vehicles, key = { "veh-${it.id}" }) {
                                VehicleCard(it, modifier = Modifier.animateItem())
                            }
                        }

                        item { SectionHeader("Recent Transactions") }
                        if (profile.recentTransactions.isEmpty()) {
                            item { EmptyNote("No transactions recorded yet.") }
                        } else {
                            items(profile.recentTransactions, key = { "txn-${it.id}" }) {
                                TransactionCard(it, modifier = Modifier.animateItem())
                            }
                        }

                        item { SectionHeader("Points Ledger") }
                        if (state.ledger.isEmpty() && !state.ledgerLoading) {
                            item { EmptyNote("No ledger entries yet.") }
                        } else {
                            items(state.ledger, key = { "ledger-${it.id}" }) {
                                LedgerRow(it, modifier = Modifier.animateItem())
                            }
                            item {
                                if (state.ledgerHasMore) {
                                    TextButton(onClick = { viewModel.loadMoreLedger() }, enabled = !state.ledgerLoading) {
                                        Text(if (state.ledgerLoading) "Loading…" else "Load more")
                                    }
                                }
                                Text(
                                    "Showing ${state.ledger.size} of ${state.ledgerTotal} entries",
                                    style = MaterialTheme.typography.labelSmall,
                                    color = MaterialTheme.nayara.textTertiary,
                                )
                            }
                        }
                    }
                }

                when (pendingConfirm) {
                    ProfileAction.Pause -> ConfirmDialog(
                        title = "Pause rewards?",
                        text = "${profile.name ?: "This customer"} will stop earning and redeeming points " +
                            "until rewards are resumed.",
                        confirmLabel = "Pause",
                        destructive = true,
                        onConfirm = {
                            pendingConfirm = null
                            viewModel.togglePaused()
                        },
                        onDismiss = { pendingConfirm = null },
                    )
                    ProfileAction.Active -> ConfirmDialog(
                        title = "Mark inactive?",
                        text = "${profile.name ?: "This customer"} will no longer appear as an active " +
                            "loyalty member. You can mark them active again later.",
                        confirmLabel = "Mark Inactive",
                        destructive = true,
                        onConfirm = {
                            pendingConfirm = null
                            viewModel.toggleActive()
                        },
                        onDismiss = { pendingConfirm = null },
                    )
                    null -> Unit
                }
            }
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun HeroCard(p: CustomerProfileDto) {
    // Content on the brand gradient stays white by design (not theme tokens).
    NayaraHeroCard(modifier = Modifier.fillMaxWidth()) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Avatar(p.name, size = 44.dp)
            Spacer(Modifier.width(12.dp))
            Column {
                Text(
                    p.name ?: "Customer",
                    color = NayaraPalette.White,
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold,
                )
                p.phoneNumber?.let { Text("+91 $it", color = NayaraPalette.Navy100, style = MaterialTheme.typography.bodySmall) }
            }
        }
        Spacer(Modifier.height(16.dp))
        Text("Current Points", color = NayaraPalette.Navy200, style = MaterialTheme.typography.labelLarge)
        AnimatedCounter(
            value = p.totalPoints,
            style = NayaraNumerals.Hero,
            color = NayaraPalette.White,
        )
        Spacer(Modifier.height(12.dp))
        FlowRow(
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            InfoChip("${p.visitsCount} visits")
            InfoChip("${p.vehicles.size} vehicles")
            InfoChip("Joined ${formatMonthYear(p.joinedAt)}")
            if (p.rewardsPaused) InfoChip("Rewards Paused")
            p.maxRedeemableCashReward?.let { InfoChip("Cash ₹%.2f".format(it)) }
        }
        // Extra room below the pills so they don't hug the card's bottom edge
        // (the hero card's own content padding alone reads as too tight here).
        Spacer(Modifier.height(8.dp))
    }
}

@Composable
private fun InfoChip(text: String) {
    Card(colors = CardDefaults.cardColors(containerColor = NayaraPalette.White.copy(alpha = 0.16f))) {
        Text(text, modifier = Modifier.padding(horizontal = 10.dp, vertical = 4.dp), style = MaterialTheme.typography.labelMedium, color = NayaraPalette.White)
    }
}

@Composable
private fun ActionRow(
    p: CustomerProfileDto,
    inFlight: ProfileAction?,
    onTogglePaused: () -> Unit,
    onToggleActive: () -> Unit,
) {
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        NayaraOutlinedButton(onClick = onTogglePaused, enabled = inFlight == null, modifier = Modifier.weight(1f)) {
            ButtonLabel(
                if (p.rewardsPaused) "Resume Rewards" else "Pause Rewards",
                loading = inFlight == ProfileAction.Pause,
            )
        }
        NayaraOutlinedButton(onClick = onToggleActive, enabled = inFlight == null, modifier = Modifier.weight(1f)) {
            ButtonLabel(
                if (p.active) "Mark Inactive" else "Mark Active",
                loading = inFlight == ProfileAction.Active,
            )
        }
    }
}

@Composable
private fun ButtonLabel(text: String, loading: Boolean) {
    if (loading) {
        CircularProgressIndicator(modifier = Modifier.size(18.dp), strokeWidth = 2.dp)
        Spacer(Modifier.width(8.dp))
    }
    Text(text)
}

@Composable
private fun SectionHeader(text: String) {
    Text(
        text,
        style = MaterialTheme.typography.titleSmall,
        color = MaterialTheme.nayara.textSecondary,
        modifier = Modifier.padding(top = NayaraSpacing.Sm),
    )
}

@Composable
private fun EmptyNote(text: String) {
    Text(text, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.nayara.textSecondary)
}

@Composable
private fun VehicleCard(v: StaffVehicleDto, modifier: Modifier = Modifier) {
    NayaraCard(modifier = modifier.fillMaxWidth()) {
        Row(
            modifier = Modifier.padding(NayaraSpacing.Lg),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            // Leading kind icon anchors the row so the plate + fuel line no longer
            // float alone in an empty full-width card.
            Box(
                modifier = Modifier
                    .size(44.dp)
                    .clip(CircleShape)
                    .background(MaterialTheme.nayara.bgSurfaceSunken),
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    vehicleKindIcon(v),
                    contentDescription = null,
                    tint = MaterialTheme.nayara.textSecondary,
                    modifier = Modifier.size(24.dp),
                )
            }
            Spacer(Modifier.width(NayaraSpacing.Md))
            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(NayaraSpacing.Xs),
            ) {
                PlateChip(v.vehicleNumber)
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(NayaraSpacing.Xs),
                ) {
                    FuelDot(v.fuelTypeCode ?: v.fuelType ?: "")
                    Text(
                        "${v.fuelType ?: "—"} · ${v.vehicleKind ?: "—"}",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.nayara.textSecondary,
                    )
                }
                if (v.commercial && !v.commercialContactName.isNullOrBlank()) {
                    Text("Contact: ${v.commercialContactName}", style = MaterialTheme.typography.bodySmall)
                }
            }
        }
    }
}

/** Maps a vehicle's kind (code or label) to a representative glyph. */
private fun vehicleKindIcon(v: StaffVehicleDto): ImageVector {
    val key = (v.vehicleKindCode ?: v.vehicleKind ?: "").lowercase()
    return when {
        "two" in key || "2w" in key || "bike" in key || "motor" in key || "scooter" in key -> Icons.Filled.TwoWheeler
        "truck" in key || "lorry" in key || "hcv" in key || "hgv" in key || "lcv" in key -> Icons.Filled.LocalShipping
        "bus" in key -> Icons.Filled.DirectionsBus
        "tractor" in key || "agri" in key -> Icons.Filled.Agriculture
        else -> Icons.Filled.DirectionsCar
    }
}

@Composable
private fun TransactionCard(t: TransactionSummaryDto, modifier: Modifier = Modifier) {
    NayaraCard(modifier = modifier.fillMaxWidth()) {
        Column(
            modifier = Modifier.padding(NayaraSpacing.Lg),
            verticalArrangement = Arrangement.spacedBy(NayaraSpacing.Xxs),
        ) {
            Row(
                Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    t.vehicleNumber ?: "Vehicle not linked",
                    fontWeight = FontWeight.SemiBold,
                    modifier = Modifier.weight(1f, fill = false),
                )
                Text("₹%.2f".format(t.fuelAmount), style = NayaraNumerals.Default)
            }
            t.handledBy?.let { Text("Handled by $it", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.nayara.textSecondary) }
            val pumpNozzle = listOfNotNull(t.pump, t.nozzle).joinToString(" · ")
            if (pumpNozzle.isNotBlank()) Text(pumpNozzle, style = MaterialTheme.typography.bodySmall)
            t.pointsEarned?.let {
                Text(
                    "Reward Points: ${if (it >= 0) "+$it" else "$it"}",
                    style = MaterialTheme.typography.bodySmall,
                    color = if (it >= 0) MaterialTheme.nayara.statusSuccessText else MaterialTheme.nayara.textPrimary,
                )
            }
            Text(formatDateTime(t.createdAt), style = MaterialTheme.typography.labelSmall, color = MaterialTheme.nayara.textTertiary)
        }
    }
}

@Composable
private fun LedgerRow(e: LedgerEntryDto, modifier: Modifier = Modifier) {
    NayaraCard(modifier = modifier.fillMaxWidth()) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = NayaraSpacing.Lg, vertical = NayaraSpacing.Md),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(Modifier.weight(1f)) {
                Text(e.label, style = MaterialTheme.typography.bodyMedium)
                Text(formatDateTime(e.createdAt), style = MaterialTheme.typography.labelSmall, color = MaterialTheme.nayara.textTertiary)
            }
            Spacer(Modifier.width(NayaraSpacing.Md))
            Text(
                if (e.points >= 0) "+${e.points}" else "${e.points}",
                style = NayaraNumerals.Default,
                color = if (e.points >= 0) MaterialTheme.nayara.statusSuccessText else MaterialTheme.nayara.textPrimary,
            )
        }
    }
}

private fun formatMonthYear(iso: String): String = runCatching {
    java.time.OffsetDateTime.parse(iso).format(java.time.format.DateTimeFormatter.ofPattern("MMM yyyy"))
}.getOrDefault(iso)

private fun formatDateTime(iso: String): String = runCatching {
    java.time.OffsetDateTime.parse(iso).format(java.time.format.DateTimeFormatter.ofPattern("dd MMM yyyy · hh:mm a"))
}.getOrDefault(iso)
