package com.acefuel.loyalty.ui.admin.campaigns

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
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
import androidx.compose.material3.OutlinedButton
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
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import com.acefuel.loyalty.core.di.LocalContainer
import com.acefuel.loyalty.ui.designsystem.NayaraSnackbarHost
import com.acefuel.loyalty.ui.designsystem.NayaraTopBar
import com.acefuel.loyalty.ui.designsystem.showError
import com.acefuel.loyalty.ui.designsystem.showSuccess
import com.acefuel.loyalty.ui.theme.NayaraButton
import com.acefuel.loyalty.ui.theme.NayaraSpacing

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AdminCampaignsScreen(onBack: () -> Unit) {
    val container = LocalContainer.current
    val viewModel: CampaignsViewModel = viewModel(
        factory = viewModelFactory {
            initializer {
                CampaignsViewModel(CampaignsRepository(container.retrofit.create(CampaignsApi::class.java), container.json))
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
                title = if (inDetail) "Campaign" else "Campaigns",
                onBack = { if (inDetail) viewModel.closeDetail() else onBack() },
            )
        },
        snackbarHost = { NayaraSnackbarHost(snackbar) },
    ) { padding ->
        Box(Modifier.fillMaxSize().padding(padding)) {
            when {
                inDetail -> DetailView(state, viewModel)
                state.loading -> Box(Modifier.fillMaxSize(), Alignment.Center) { CircularProgressIndicator() }
                state.campaigns.isEmpty() -> Text("No campaigns. Create one on the web console.", Modifier.padding(NayaraSpacing.Md))
                else -> LazyColumn(
                    Modifier.fillMaxSize().padding(horizontal = NayaraSpacing.ScreenMargin),
                    verticalArrangement = Arrangement.spacedBy(NayaraSpacing.Sm),
                ) {
                    items(state.campaigns) { campaign -> CampaignRow(campaign) { viewModel.open(campaign.id) } }
                }
            }
        }
    }
}

@Composable
private fun CampaignRow(campaign: CampaignDto, onClick: () -> Unit) {
    Card(onClick = onClick, modifier = Modifier.fillMaxWidth()) {
        Column(Modifier.padding(NayaraSpacing.CardPadding)) {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                Text(campaign.name, fontWeight = FontWeight.SemiBold, modifier = Modifier.weight(1f))
                AssistChip(onClick = onClick, label = { Text(campaign.status) })
            }
            Text(campaign.offerHeadline ?: campaign.rewardKind, style = MaterialTheme.typography.bodySmall)
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class, ExperimentalLayoutApi::class)
@Composable
private fun DetailView(state: CampaignsUiState, vm: CampaignsViewModel) {
    val campaign = state.selected ?: return
    LazyColumn(
        Modifier.fillMaxSize().padding(horizontal = NayaraSpacing.ScreenMargin),
        verticalArrangement = Arrangement.spacedBy(NayaraSpacing.Sm),
    ) {
        item {
            Column(Modifier.padding(vertical = NayaraSpacing.Sm)) {
                Text(campaign.name, style = MaterialTheme.typography.titleMedium)
                Text("${campaign.status} · ${campaign.offerHeadline ?: campaign.rewardKind}", style = MaterialTheme.typography.bodySmall)
            }
        }
        item {
            Card(Modifier.fillMaxWidth()) {
                Column(Modifier.padding(NayaraSpacing.CardPadding), verticalArrangement = Arrangement.spacedBy(NayaraSpacing.Xxs)) {
                    val threshold = buildString {
                        campaign.minPurchaseAmount?.let { append("₹${it.toInt()} ") }
                        campaign.minPurchaseLitres?.let { append("${it} L ") }
                        append("over ${campaign.period.replace('_', ' ')}")
                        campaign.periodDays?.let { append(" ($it days)") }
                    }
                    Text("Threshold: $threshold")
                    Text("Audience: ${campaign.targetType.replace('_', ' ')}" + (campaign.targetCustomerType?.let { " · $it" } ?: ""))
                    Text("Channels: ${campaign.channels.joinToString(", ") { it.uppercase() }}")
                    Text("Qualifications so far: ${campaign.qualificationCount}")
                }
            }
        }
        item {
            FlowRow(horizontalArrangement = Arrangement.spacedBy(NayaraSpacing.Sm), verticalArrangement = Arrangement.spacedBy(NayaraSpacing.Sm)) {
                OutlinedButton(onClick = vm::preview, enabled = !state.busy) { Text("Preview") }
                if (campaign.status == "active") {
                    NayaraButton(onClick = vm::run, enabled = !state.busy) { Text("Run now") }
                    OutlinedButton(onClick = vm::pause, enabled = !state.busy) { Text("Pause") }
                } else {
                    OutlinedButton(onClick = vm::activate, enabled = !state.busy) { Text("Activate") }
                }
            }
        }
        state.preview?.let { preview ->
            item {
                Card(Modifier.fillMaxWidth()) {
                    Column(Modifier.padding(NayaraSpacing.CardPadding)) {
                        Text("${preview.qualifyingCount} qualify now", fontWeight = FontWeight.SemiBold)
                        Text("Reachable: " + preview.reachable.entries.joinToString(" · ") { "${it.key.uppercase()} ${it.value}" },
                            style = MaterialTheme.typography.bodySmall)
                        preview.sample.take(5).forEach { s ->
                            Text("• ${s.name ?: "Customer"} — ₹${s.aggregatedAmount.toInt()}", style = MaterialTheme.typography.bodySmall)
                        }
                    }
                }
            }
        }
        item { HorizontalDivider(Modifier.padding(vertical = NayaraSpacing.Xs)) }
        item { Text("Edit campaign rules on the web console.", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant) }
    }
}
