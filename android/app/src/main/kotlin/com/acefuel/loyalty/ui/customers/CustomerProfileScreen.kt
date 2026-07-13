package com.acefuel.loyalty.ui.customers

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
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
import com.acefuel.loyalty.core.network.dto.CustomerProfileDto
import com.acefuel.loyalty.core.network.dto.LedgerEntryDto
import com.acefuel.loyalty.core.network.dto.StaffVehicleDto
import com.acefuel.loyalty.core.network.dto.TransactionSummaryDto
import com.acefuel.loyalty.ui.theme.NayaraHeroCard
import com.acefuel.loyalty.ui.theme.NayaraOutlinedButton
import com.acefuel.loyalty.ui.theme.NayaraPalette
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

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(state.profile?.name ?: "Customer") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                },
            )
        },
    ) { innerPadding ->
        val profile = state.profile
        when {
            state.loading && profile == null ->
                Column(Modifier.fillMaxSize().padding(innerPadding), horizontalAlignment = Alignment.CenterHorizontally) {
                    Spacer(Modifier.height(48.dp)); CircularProgressIndicator()
                }
            profile == null ->
                Text(
                    state.error ?: "Customer not found.",
                    modifier = Modifier.padding(innerPadding).padding(24.dp),
                    color = MaterialTheme.colorScheme.error,
                )
            else -> LazyColumn(
                modifier = Modifier.fillMaxSize().padding(innerPadding).padding(horizontal = 16.dp),
                verticalArrangement = Arrangement.spacedBy(10.dp),
                contentPadding = androidx.compose.foundation.layout.PaddingValues(vertical = 12.dp),
            ) {
                item { HeroCard(profile) }
                item { ActionRow(profile, state.actionInFlight, viewModel) }
                state.error?.let { item { Text(it, color = MaterialTheme.colorScheme.error) } }

                item { SectionHeader("Vehicles (${profile.vehicles.size})") }
                if (profile.vehicles.isEmpty()) {
                    item { EmptyNote("No vehicles registered yet.") }
                } else {
                    items(profile.vehicles, key = { "veh-${it.id}" }) { VehicleCard(it) }
                }

                item { SectionHeader("Recent Transactions") }
                if (profile.recentTransactions.isEmpty()) {
                    item { EmptyNote("No transactions recorded yet.") }
                } else {
                    items(profile.recentTransactions, key = { "txn-${it.id}" }) { TransactionCard(it) }
                }

                item { SectionHeader("Points Ledger") }
                if (state.ledger.isEmpty() && !state.ledgerLoading) {
                    item { EmptyNote("No ledger entries yet.") }
                } else {
                    items(state.ledger, key = { "ledger-${it.id}" }) { LedgerRow(it) }
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
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun HeroCard(p: CustomerProfileDto) {
    NayaraHeroCard(modifier = Modifier.fillMaxWidth()) {
        Text("Current Points", color = NayaraPalette.Navy200, style = MaterialTheme.typography.labelLarge)
        Text("${p.totalPoints}", color = NayaraPalette.White, style = MaterialTheme.typography.displaySmall, fontWeight = FontWeight.Bold)
        p.phoneNumber?.let { Text("+91 $it", color = NayaraPalette.Navy100, style = MaterialTheme.typography.bodySmall) }
        Spacer(Modifier.height(12.dp))
        FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            InfoChip("${p.visitsCount} visits")
            InfoChip("${p.vehicles.size} vehicles")
            InfoChip("Joined ${formatMonthYear(p.joinedAt)}")
            if (p.rewardsPaused) InfoChip("Rewards Paused")
            p.maxRedeemableCashReward?.let { InfoChip("Cash ₹%.2f".format(it)) }
        }
    }
}

@Composable
private fun InfoChip(text: String) {
    Card(colors = CardDefaults.cardColors(containerColor = NayaraPalette.White.copy(alpha = 0.16f))) {
        Text(text, modifier = Modifier.padding(horizontal = 10.dp, vertical = 4.dp), style = MaterialTheme.typography.labelMedium, color = NayaraPalette.White)
    }
}

@Composable
private fun ActionRow(p: CustomerProfileDto, inFlight: Boolean, vm: CustomerProfileViewModel) {
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        NayaraOutlinedButton(onClick = { vm.togglePaused() }, enabled = !inFlight, modifier = Modifier.weight(1f)) {
            Text(if (p.rewardsPaused) "Resume Rewards" else "Pause Rewards")
        }
        NayaraOutlinedButton(onClick = { vm.toggleActive() }, enabled = !inFlight, modifier = Modifier.weight(1f)) {
            Text(if (p.active) "Mark Inactive" else "Mark Active")
        }
    }
}

@Composable
private fun SectionHeader(text: String) {
    Text(text, style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.SemiBold, modifier = Modifier.padding(top = 8.dp))
}

@Composable
private fun EmptyNote(text: String) {
    Text(text, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.nayara.textSecondary)
}

@Composable
private fun VehicleCard(v: StaffVehicleDto) {
    Card(Modifier.fillMaxWidth()) {
        Column(Modifier.padding(14.dp)) {
            Text(v.vehicleNumber, fontWeight = FontWeight.SemiBold)
            Text("${v.fuelType ?: "—"} · ${v.vehicleKind ?: "—"}", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.nayara.textSecondary)
            if (v.commercial && !v.commercialContactName.isNullOrBlank()) {
                Text("Contact: ${v.commercialContactName}", style = MaterialTheme.typography.bodySmall)
            }
        }
    }
}

@Composable
private fun TransactionCard(t: TransactionSummaryDto) {
    Card(Modifier.fillMaxWidth()) {
        Column(Modifier.padding(14.dp)) {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                Text(t.vehicleNumber ?: "Vehicle not linked", fontWeight = FontWeight.SemiBold)
                Text("₹%.2f".format(t.fuelAmount))
            }
            t.handledBy?.let { Text("Handled by $it", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.7f)) }
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
private fun LedgerRow(e: LedgerEntryDto) {
    Row(Modifier.fillMaxWidth().padding(vertical = 4.dp), horizontalArrangement = Arrangement.SpaceBetween) {
        Column {
            Text(e.label, style = MaterialTheme.typography.bodyMedium)
            Text(formatDateTime(e.createdAt), style = MaterialTheme.typography.labelSmall, color = MaterialTheme.nayara.textTertiary)
        }
        Text(
            if (e.points >= 0) "+${e.points}" else "${e.points}",
            fontWeight = FontWeight.Bold,
            color = if (e.points >= 0) MaterialTheme.nayara.statusSuccessText else MaterialTheme.nayara.textPrimary,
        )
    }
}

private fun formatMonthYear(iso: String): String = runCatching {
    java.time.OffsetDateTime.parse(iso).format(java.time.format.DateTimeFormatter.ofPattern("MMM yyyy"))
}.getOrDefault(iso)

private fun formatDateTime(iso: String): String = runCatching {
    java.time.OffsetDateTime.parse(iso).format(java.time.format.DateTimeFormatter.ofPattern("dd MMM yyyy · hh:mm a"))
}.getOrDefault(iso)
