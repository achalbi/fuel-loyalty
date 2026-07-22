@file:OptIn(ExperimentalMaterial3Api::class, ExperimentalLayoutApi::class)

package com.acefuel.loyalty.ui.admin.notifications

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
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.NotificationsNone
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
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
import com.acefuel.loyalty.ui.designsystem.ChipTone
import com.acefuel.loyalty.ui.designsystem.EmptyState
import com.acefuel.loyalty.ui.designsystem.ErrorState
import com.acefuel.loyalty.ui.designsystem.NayaraCard
import com.acefuel.loyalty.ui.designsystem.NayaraPullToRefresh
import com.acefuel.loyalty.ui.designsystem.NayaraSnackbarHost
import com.acefuel.loyalty.ui.designsystem.NayaraTopBar
import com.acefuel.loyalty.ui.designsystem.SkeletonList
import com.acefuel.loyalty.ui.designsystem.StatusChip
import com.acefuel.loyalty.ui.designsystem.showError
import com.acefuel.loyalty.ui.theme.NayaraSpacing
import com.acefuel.loyalty.ui.theme.nayara

@Composable
fun NotificationsHistoryScreen(onBack: () -> Unit) {
    val container = LocalContainer.current
    val repo = remember {
        NotificationsHistoryRepository(
            container.retrofit.create(NotificationsHistoryApi::class.java),
            container.json,
        )
    }
    val vm: NotificationsHistoryViewModel =
        viewModel(factory = viewModelFactory { initializer { NotificationsHistoryViewModel(repo) } })
    val state by vm.state.collectAsStateWithLifecycle()

    val snackbar = remember { SnackbarHostState() }
    LaunchedEffect(state.actionError) {
        state.actionError?.let {
            snackbar.showError(it)
            vm.consumeActionError()
        }
    }

    Scaffold(
        topBar = { NayaraTopBar(title = "Delivery history", onBack = onBack) },
        snackbarHost = { NayaraSnackbarHost(snackbar) },
    ) { innerPadding ->
        Box(Modifier.fillMaxSize().padding(innerPadding)) {
            when {
                state.loading && state.messages.isEmpty() && state.error == null ->
                    SkeletonList(Modifier.padding(horizontal = 16.dp, vertical = 8.dp), count = 6)

                state.error != null && state.messages.isEmpty() ->
                    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        ErrorState(message = state.error!!, onRetry = vm::load)
                    }

                else -> NayaraPullToRefresh(
                    isRefreshing = state.refreshing,
                    onRefresh = vm::refresh,
                    modifier = Modifier.fillMaxSize(),
                ) {
                    LazyColumn(
                        modifier = Modifier.fillMaxSize(),
                        contentPadding = PaddingValues(16.dp),
                        verticalArrangement = Arrangement.spacedBy(12.dp),
                    ) {
                        if (state.messages.isEmpty()) {
                            item(key = "empty") {
                                EmptyState(
                                    title = "No notifications sent yet",
                                    message = "Sends and scheduled runs show up here with their per-channel delivery counts.",
                                    icon = Icons.Filled.NotificationsNone,
                                )
                            }
                        } else {
                            items(state.messages, key = { "n-${it.id}" }) { message ->
                                MessageRow(
                                    message = message,
                                    onClick = { vm.openRecipients(message) },
                                    modifier = Modifier.animateItem(),
                                )
                            }
                        }
                    }
                }
            }
        }
    }

    state.selected?.let { message ->
        val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
        ModalBottomSheet(onDismissRequest = vm::closeRecipients, sheetState = sheetState) {
            RecipientsSheet(state = state, message = message)
        }
    }
}

// ---------------------------------------------------------------------------
// List row
// ---------------------------------------------------------------------------

@Composable
private fun MessageRow(
    message: NotificationMessageDto,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    NayaraCard(onClick = onClick, modifier = modifier.fillMaxWidth()) {
        Column(
            Modifier.padding(NayaraSpacing.Lg),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Text(
                message.title.ifBlank { "(no title)" },
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.SemiBold,
            )
            message.body?.takeIf { it.isNotBlank() }?.let {
                Text(
                    it,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.nayara.textSecondary,
                    maxLines = 2,
                )
            }

            // Per-channel delivery tallies (the persistent log).
            if (message.delivery.isEmpty()) {
                Text(
                    "No deliveries recorded.",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.nayara.textTertiary,
                )
            } else {
                Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                    message.delivery.forEach { (channel, statuses) ->
                        Text(
                            deliveryLine(channel, statuses),
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.nayara.textSecondary,
                        )
                    }
                }
            }

            FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                message.category?.takeIf { it.isNotBlank() }?.let {
                    StatusChip(label = it.replaceFirstChar(Char::uppercase), tone = ChipTone.Info, showDot = false)
                }
                message.channels.forEach { channel ->
                    StatusChip(label = channelLabel(channel), tone = ChipTone.Neutral, showDot = false)
                }
            }

            Text(
                buildString {
                    append(message.recipientCount)
                    append(if (message.recipientCount == 1) " recipient" else " recipients")
                    append(" · ")
                    append(audienceLabel(message))
                    message.createdAt?.let { append(" · "); append(formatWhen(it)) }
                    message.createdBy?.takeIf { it.isNotBlank() }?.let { append(" · by "); append(it) }
                },
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.nayara.textTertiary,
            )
        }
    }
}

// ---------------------------------------------------------------------------
// Recipient detail sheet
// ---------------------------------------------------------------------------

@Composable
private fun RecipientsSheet(state: DeliveryHistoryUiState, message: NotificationMessageDto) {
    Column(
        Modifier
            .fillMaxWidth()
            .navigationBarsPadding()
            .padding(horizontal = 20.dp)
            .padding(bottom = 16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Text(
            message.title.ifBlank { "(no title)" },
            style = MaterialTheme.typography.titleLarge,
            fontWeight = FontWeight.Bold,
        )
        Text(
            "Recipients",
            style = MaterialTheme.typography.labelLarge,
            color = MaterialTheme.nayara.textSecondary,
        )

        when {
            state.recipientsLoading ->
                Box(Modifier.fillMaxWidth().padding(24.dp), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator(Modifier.size(28.dp))
                }

            state.recipientsError != null ->
                Text(state.recipientsError, color = MaterialTheme.colorScheme.error)

            state.recipients.isEmpty() ->
                Text(
                    "No per-recipient rows were logged for this send.",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.nayara.textSecondary,
                )

            else -> LazyColumn(
                modifier = Modifier.heightIn(max = 460.dp),
                verticalArrangement = Arrangement.spacedBy(0.dp),
            ) {
                itemsIndexed(state.recipients) { index, recipient ->
                    if (index > 0) HorizontalDivider(color = MaterialTheme.nayara.borderSubtle)
                    RecipientRow(recipient)
                }
            }
        }
    }
}

@Composable
private fun RecipientRow(recipient: NotificationRecipientDto) {
    Row(
        Modifier.fillMaxWidth().padding(vertical = 10.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(
                recipient.customerName?.takeIf { it.isNotBlank() }
                    ?: recipient.customerId?.let { "Customer #$it" }
                    ?: "Anonymous",
                style = MaterialTheme.typography.bodyLarge,
            )
            Text(
                buildString {
                    append(channelLabel(recipient.channel))
                    recipient.sentAt?.let { append(" · "); append(formatWhen(it)) }
                },
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.nayara.textTertiary,
            )
            recipient.error?.takeIf { it.isNotBlank() }?.let {
                Text(it, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.error)
            }
        }
        StatusChip(
            label = recipient.status.replaceFirstChar(Char::uppercase),
            tone = statusTone(recipient.status),
            showDot = false,
        )
    }
}

// ---------------------------------------------------------------------------
// Formatting helpers
// ---------------------------------------------------------------------------

private fun channelLabel(channel: String): String = when (channel.lowercase()) {
    "push" -> "Push"
    "whatsapp" -> "WhatsApp"
    "sms" -> "SMS"
    else -> channel.replaceFirstChar(Char::uppercase)
}

/** "Push · 12 sent, 3 skipped" — statuses ordered sent → skipped → failed → rest. */
private fun deliveryLine(channel: String, statuses: Map<String, Int>): String {
    val order = listOf("sent", "delivered", "skipped", "failed")
    val parts = statuses.entries
        .sortedBy { order.indexOf(it.key.lowercase()).let { i -> if (i < 0) order.size else i } }
        .map { "${it.value} ${it.key}" }
    return "${channelLabel(channel)} · ${parts.joinToString(", ")}"
}

private fun audienceLabel(message: NotificationMessageDto): String = when (message.targetType) {
    "all", null -> "Everyone"
    "customer_type" -> message.targetCustomerType?.replaceFirstChar(Char::uppercase)?.let { "$it customers" } ?: "By type"
    "individual" -> "One customer"
    "selected" -> "Selected"
    else -> message.targetType.replaceFirstChar(Char::uppercase)
}

private fun statusTone(status: String): ChipTone = when (status.lowercase()) {
    "sent", "delivered" -> ChipTone.Success
    "failed", "error" -> ChipTone.Error
    "skipped" -> ChipTone.Neutral
    else -> ChipTone.Info
}

private fun formatWhen(iso: String): String = runCatching {
    java.time.OffsetDateTime.parse(iso)
        .format(java.time.format.DateTimeFormatter.ofPattern("dd MMM yyyy · hh:mm a"))
}.getOrDefault(iso)
