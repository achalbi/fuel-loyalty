package com.acefuel.loyalty.ui.admin.schedules

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.History
import androidx.compose.material.icons.filled.Schedule
import androidx.compose.material3.Card
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SheetValue
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import com.acefuel.loyalty.core.di.LocalContainer
import com.acefuel.loyalty.ui.designsystem.ChipTone
import com.acefuel.loyalty.ui.designsystem.ConfirmDialog
import com.acefuel.loyalty.ui.designsystem.DateField
import com.acefuel.loyalty.ui.designsystem.EmptyState
import com.acefuel.loyalty.ui.designsystem.FormField
import com.acefuel.loyalty.ui.designsystem.InlineErrorCard
import com.acefuel.loyalty.ui.designsystem.NayaraPullToRefresh
import com.acefuel.loyalty.ui.designsystem.NayaraSnackbarHost
import com.acefuel.loyalty.ui.designsystem.NayaraTopBar
import com.acefuel.loyalty.ui.designsystem.PickerField
import com.acefuel.loyalty.ui.designsystem.SkeletonList
import com.acefuel.loyalty.ui.designsystem.StatusChip
import com.acefuel.loyalty.ui.designsystem.TimeField
import com.acefuel.loyalty.ui.designsystem.rememberHaptics
import com.acefuel.loyalty.ui.designsystem.showError
import com.acefuel.loyalty.ui.designsystem.showSuccess
import com.acefuel.loyalty.ui.theme.NayaraButton
import com.acefuel.loyalty.ui.theme.NayaraOutlinedButton
import com.acefuel.loyalty.ui.theme.NayaraSpacing
import com.acefuel.loyalty.ui.theme.nayara
import java.time.LocalDate
import java.time.LocalTime

private val FREQUENCIES = listOf("once" to "Once", "daily" to "Daily", "weekly" to "Weekly", "monthly" to "Monthly")
private val WEEKDAYS = listOf("Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday")
private val DAYS_OF_MONTH = (1..31).map { it.toString() }

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AdminSchedulesScreen(onBack: () -> Unit, onOpenHistory: () -> Unit = {}) {
    val container = LocalContainer.current
    val repo = remember {
        AdminSchedulesRepository(container.retrofit.create(AdminSchedulesApi::class.java), container.json)
    }
    val vm: AdminSchedulesViewModel = viewModel(factory = viewModelFactory { initializer { AdminSchedulesViewModel(repo) } })
    val state by vm.state.collectAsStateWithLifecycle()

    val snackbar = remember { SnackbarHostState() }
    val haptics = rememberHaptics()

    LaunchedEffect(state.successMessage) {
        state.successMessage?.let {
            haptics.confirm()
            snackbar.showSuccess(it)
            vm.consumeSuccessMessage()
        }
    }
    LaunchedEffect(state.errorMessage) {
        state.errorMessage?.let {
            haptics.reject()
            snackbar.showError(it)
            vm.consumeErrorMessage()
        }
    }

    Scaffold(
        topBar = {
            NayaraTopBar(
                title = "Notifications",
                onBack = onBack,
                actions = {
                    IconButton(onClick = onOpenHistory) {
                        Icon(Icons.Filled.History, contentDescription = "Delivery history")
                    }
                },
            )
        },
        snackbarHost = { NayaraSnackbarHost(snackbar) },
    ) { innerPadding ->
        NayaraPullToRefresh(
            isRefreshing = state.refreshing,
            onRefresh = vm::refresh,
            modifier = Modifier.fillMaxSize().padding(innerPadding),
        ) {
            LazyColumn(
                modifier = Modifier.fillMaxSize().padding(horizontal = 16.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp),
                contentPadding = PaddingValues(top = 12.dp, bottom = 24.dp),
            ) {
                item(key = "send-card") { SendNowCard(state, vm) }
                item(key = "run-card") { RunSchedulerCard(state, vm) }
                item(key = "sched-header") { SchedulesHeader(state.schedules.size, onNew = vm::openCreate) }

                when {
                    state.loading && state.schedules.isEmpty() && state.loadError == null ->
                        item(key = "sched-loading") { SkeletonList(count = 3, showAvatar = false) }

                    state.loadError != null && state.schedules.isEmpty() ->
                        item(key = "sched-load-error") {
                            InlineErrorCard(state.loadError!!, onRetry = vm::load)
                        }

                    state.schedules.isEmpty() -> item(key = "sched-empty") {
                        EmptyState(
                            title = "No schedules yet",
                            message = "Schedules send a push notification automatically at the time you choose.",
                            icon = Icons.Filled.Schedule,
                            actionLabel = "Create a schedule",
                            onAction = vm::openCreate,
                        )
                    }

                    else -> items(state.schedules, key = { "sched-${it.id}" }) { schedule ->
                        ScheduleRow(
                            schedule = schedule,
                            busy = state.rowActionId == schedule.id,
                            onSend = { vm.sendRow(schedule.id) },
                            onEdit = { vm.openEdit(schedule) },
                            onDelete = { vm.requestDelete(schedule.id) },
                            modifier = Modifier.animateItem(),
                        )
                    }
                }
            }
        }
    }

    if (state.formOpen) {
        // Snapshot the just-opened form so we can tell "dirty" from "untouched".
        val initialForm = remember(state.editingId) { state.form }
        val dirty = state.form != initialForm
        GuardedSheet(dirty = dirty, onClose = vm::closeForm) { requestClose ->
            ScheduleFormContent(state, vm, onCancel = requestClose)
        }
    }

    if (state.pendingDeleteId != null) {
        val target = state.schedules.firstOrNull { it.id == state.pendingDeleteId }
        ConfirmDialog(
            title = "Delete schedule?",
            text = "This removes \"${target?.title ?: "this schedule"}\" for good. This can't be undone.",
            confirmLabel = "Delete",
            destructive = true,
            onConfirm = vm::confirmDelete,
            onDismiss = vm::cancelDelete,
        )
    }
}

// ---------------------------------------------------------------------------
// Dismiss-guarded bottom sheet
// ---------------------------------------------------------------------------

/**
 * ModalBottomSheet that blocks swipe/scrim dismissal while [dirty] and asks
 * for confirmation instead, so half-filled forms aren't lost by accident.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun GuardedSheet(
    dirty: Boolean,
    onClose: () -> Unit,
    content: @Composable ColumnScope.(requestClose: () -> Unit) -> Unit,
) {
    val dirtyState = rememberUpdatedState(dirty)
    var confirmDiscard by remember { mutableStateOf(false) }
    val sheetState = rememberModalBottomSheetState(
        skipPartiallyExpanded = true,
        confirmValueChange = { value ->
            if (value == SheetValue.Hidden && dirtyState.value) {
                confirmDiscard = true
                false
            } else {
                true
            }
        },
    )
    // Route onDismissRequest through the dirty check too: the system back
    // gesture calls it directly, bypassing confirmValueChange.
    ModalBottomSheet(
        onDismissRequest = { if (dirtyState.value) confirmDiscard = true else onClose() },
        sheetState = sheetState,
    ) {
        content { if (dirtyState.value) confirmDiscard = true else onClose() }
    }
    if (confirmDiscard) {
        ConfirmDialog(
            title = "Discard changes?",
            text = "You have unsaved changes. Close without saving?",
            confirmLabel = "Discard",
            destructive = true,
            onConfirm = {
                confirmDiscard = false
                onClose()
            },
            onDismiss = { confirmDiscard = false },
        )
    }
}

// ---------------------------------------------------------------------------
// Sections
// ---------------------------------------------------------------------------

@Composable
private fun SendNowCard(state: AdminSchedulesUiState, vm: AdminSchedulesViewModel) {
    SectionCard("Send Now") {
        Text(
            "Send an instant notification to a chosen audience over the selected channels.",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.nayara.textSecondary,
        )
        OutlinedTextField(
            value = state.sendTitle,
            onValueChange = vm::onSendTitleChange,
            label = { Text("Title") },
            singleLine = true,
            supportingText = { Text("${state.sendTitle.length}/120") },
            modifier = Modifier.fillMaxWidth(),
        )
        OutlinedTextField(
            value = state.sendMessage,
            onValueChange = vm::onSendMessageChange,
            label = { Text("Message") },
            minLines = 2,
            supportingText = { Text("${state.sendMessage.length}/240") },
            modifier = Modifier.fillMaxWidth(),
        )

        Text("Channels", style = MaterialTheme.typography.labelMedium)
        ChipRow(listOf("push", "whatsapp", "sms"), state.sendChannels) { vm.toggleSendChannel(it) }

        Text("Audience", style = MaterialTheme.typography.labelMedium)
        ChipRow(listOf("all", "customer_type"), listOf(state.sendTargetType)) { vm.onSendTargetType(it) }
        if (state.sendTargetType == "customer_type") {
            ChipRow(listOf("otp", "credit", "drive_in"), listOf(state.sendCustomerType)) { vm.onSendCustomerType(it) }
        }

        NayaraButton(
            onClick = vm::sendNotification,
            loading = state.sending,
            enabled = state.sendTitle.isNotBlank() && state.sendMessage.isNotBlank(),
            modifier = Modifier.fillMaxWidth(),
        ) { Text("Send Now") }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun ChipRow(options: List<String>, selected: List<String>, onToggle: (String) -> Unit) {
    FlowRow(horizontalArrangement = Arrangement.spacedBy(NayaraSpacing.Sm)) {
        options.forEach { option ->
            FilterChip(
                selected = selected.contains(option),
                onClick = { onToggle(option) },
                label = { Text(option.replace('_', ' ').replaceFirstChar { it.uppercase() }) },
            )
        }
    }
}

@Composable
private fun RunSchedulerCard(state: AdminSchedulesUiState, vm: AdminSchedulesViewModel) {
    SectionCard("Run Scheduler") {
        Text(
            "Trigger the scheduled-send sweep now. In production an external cron calls this every minute.",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.nayara.textSecondary,
        )
        NayaraButton(
            onClick = vm::runScheduler,
            loading = state.running,
            modifier = Modifier.fillMaxWidth(),
        ) { Text("Run Scheduler") }
    }
}

@Composable
private fun SchedulesHeader(count: Int, onNew: () -> Unit) {
    Row(
        modifier = Modifier.fillMaxWidth().padding(top = 4.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            "Saved Schedules ($count)",
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.SemiBold,
            color = MaterialTheme.nayara.textPrimary,
        )
        NayaraButton(onClick = onNew) {
            Icon(Icons.Filled.Add, contentDescription = null, modifier = Modifier.size(18.dp))
            Spacer(Modifier.width(6.dp))
            Text("New")
        }
    }
}

@Composable
private fun ScheduleRow(
    schedule: ScheduleDto,
    busy: Boolean,
    onSend: () -> Unit,
    onEdit: () -> Unit,
    onDelete: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Card(modifier.fillMaxWidth()) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    schedule.title.ifBlank { "Untitled" },
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.SemiBold,
                    modifier = Modifier.weight(1f),
                )
                Spacer(Modifier.width(8.dp))
                StatusChip(
                    label = if (schedule.active) "Active" else "Paused",
                    tone = if (schedule.active) ChipTone.Success else ChipTone.Neutral,
                )
            }
            StatusChip(
                label = schedule.frequency.replaceFirstChar { it.uppercase() },
                tone = ChipTone.Info,
                showDot = false,
            )
            Text(schedule.message, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.nayara.textSecondary)
            schedule.scheduleSummary?.takeIf { it.isNotBlank() }?.let {
                Text("Schedule: $it", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.nayara.textTertiary)
            }
            Text(
                "Last sent: ${schedule.lastSentAt?.let(::formatDateTime) ?: "Never"}",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.nayara.textTertiary,
            )
            Spacer(Modifier.height(2.dp))
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                NayaraButton(onClick = onSend, loading = busy, modifier = Modifier.weight(1f)) { Text("Send Now") }
                TextButton(onClick = onEdit, enabled = !busy) { Text("Edit") }
                TextButton(onClick = onDelete, enabled = !busy) {
                    Text("Delete", color = MaterialTheme.colorScheme.error)
                }
            }
        }
    }
}

// ---------------------------------------------------------------------------
// Create / Edit sheet content
// ---------------------------------------------------------------------------

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun ScheduleFormContent(
    state: AdminSchedulesUiState,
    vm: AdminSchedulesViewModel,
    onCancel: () -> Unit,
) {
    val haptics = rememberHaptics()
    val f = state.form
    val errors = state.formFieldErrors
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .verticalScroll(rememberScrollState())
            .imePadding()
            .navigationBarsPadding()
            .padding(horizontal = 20.dp)
            .padding(bottom = 24.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Text(
            if (state.editing) "Edit Schedule" else "New Schedule",
            style = MaterialTheme.typography.titleLarge,
            fontWeight = FontWeight.Bold,
        )
        FormField(
            value = f.title,
            onValueChange = vm::onFormTitle,
            label = "Title",
            errors = errors["title"],
            helper = "${f.title.length}/120",
        )
        // Multiline, so not FormField (which is single line).
        OutlinedTextField(
            value = f.message,
            onValueChange = vm::onFormMessage,
            label = { Text("Message") },
            minLines = 2,
            isError = !errors["message"].isNullOrEmpty(),
            supportingText = {
                val messageErrors = errors["message"]
                if (!messageErrors.isNullOrEmpty()) {
                    Text(messageErrors.joinToString(" "), color = MaterialTheme.colorScheme.error)
                } else {
                    Text("${f.message.length}/240")
                }
            },
            modifier = Modifier.fillMaxWidth(),
        )

        Text("Frequency", style = MaterialTheme.typography.labelMedium, color = MaterialTheme.nayara.textSecondary)
        FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            FREQUENCIES.forEach { (value, label) ->
                FilterChip(
                    selected = f.frequency == value,
                    onClick = {
                        haptics.tick()
                        vm.onFormFrequency(value)
                    },
                    label = { Text(label) },
                )
            }
        }

        // Wire format stays "HH"/"MM" strings in the VM; convert at the boundary.
        TimeField(
            label = "Time (IST)",
            value = formTime(f),
            onChange = { vm.onFormTime(it.hour.toString(), it.minute.toString()) },
            modifier = Modifier.fillMaxWidth(),
        )
        Text("Times use India Standard Time (IST).", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.nayara.textTertiary)

        when (f.frequency) {
            "once" -> {
                DateField(
                    label = "Send on",
                    value = f.scheduledDate.takeIf { it.isNotBlank() }
                        ?.let { runCatching { LocalDate.parse(it) }.getOrNull() },
                    onChange = { vm.onFormDate(it.toString()) }, // LocalDate.toString() == yyyy-MM-dd
                    placeholder = "Pick a date",
                    modifier = Modifier.fillMaxWidth(),
                )
                FieldError(errors["scheduled_date"])
                Text(
                    "One-time schedules auto-disable after the first successful run.",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.nayara.textTertiary,
                )
            }
            "weekly" -> DropdownField(
                label = "Day of week",
                selectedLabel = WEEKDAYS[f.dayOfWeek.coerceIn(0, 6)],
                options = (0..6).toList(),
                optionLabel = { WEEKDAYS[it] },
                onSelect = vm::onFormDayOfWeek,
                modifier = Modifier.fillMaxWidth(),
            )
            "monthly" -> {
                DropdownField(
                    label = "Day of month",
                    selectedLabel = f.dayOfMonth,
                    options = DAYS_OF_MONTH,
                    optionLabel = { it },
                    onSelect = vm::onFormDayOfMonth,
                    modifier = Modifier.fillMaxWidth(),
                )
                FieldError(errors["day_of_month"])
                Text(
                    "If the chosen day doesn't exist in a month, it sends on that month's last day.",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.nayara.textTertiary,
                )
            }
        }

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text("Active", style = MaterialTheme.typography.bodyLarge)
            Switch(
                checked = f.active,
                onCheckedChange = {
                    haptics.tick()
                    vm.onFormActive(it)
                },
            )
        }

        state.formError?.let { InlineErrorCard(it) }

        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            NayaraOutlinedButton(onClick = onCancel, enabled = !state.saving, modifier = Modifier.weight(1f)) {
                Text("Cancel")
            }
            NayaraButton(onClick = vm::saveForm, loading = state.saving, modifier = Modifier.weight(1f)) {
                Text(if (state.editing) "Save" else "Create")
            }
        }
    }
}

/** "09"/"30" strings → LocalTime for the picker; null if the stored strings are malformed. */
private fun formTime(f: ScheduleForm): LocalTime? {
    val h = f.hour.toIntOrNull() ?: return null
    val m = f.minute.toIntOrNull() ?: return null
    return runCatching { LocalTime.of(h, m) }.getOrNull()
}

// ---------------------------------------------------------------------------
// Small building blocks
// ---------------------------------------------------------------------------

@Composable
private fun SectionCard(title: String, content: @Composable ColumnScope.() -> Unit) {
    Card(Modifier.fillMaxWidth()) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Text(
                title,
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.SemiBold,
                color = MaterialTheme.nayara.textPrimary,
            )
            content()
        }
    }
}

@Composable
private fun <T> DropdownField(
    label: String,
    selectedLabel: String,
    options: List<T>,
    optionLabel: (T) -> String,
    onSelect: (T) -> Unit,
    modifier: Modifier = Modifier,
) {
    val haptics = rememberHaptics()
    var expanded by remember { mutableStateOf(false) }
    var fieldWidthPx by remember { mutableStateOf(0) }
    val fieldWidth = with(LocalDensity.current) { fieldWidthPx.toDp() }
    Box(modifier.onGloballyPositioned { fieldWidthPx = it.size.width }) {
        PickerField(
            label = label,
            value = selectedLabel,
            onClick = { expanded = true },
        )
        // Anchor the menu to the field's full width so it lines up underneath.
        DropdownMenu(
            expanded = expanded,
            onDismissRequest = { expanded = false },
            modifier = Modifier.width(fieldWidth),
        ) {
            options.forEach { opt ->
                DropdownMenuItem(
                    text = { Text(optionLabel(opt)) },
                    onClick = {
                        haptics.tick()
                        onSelect(opt)
                        expanded = false
                    },
                )
            }
        }
    }
}

@Composable
private fun FieldError(errors: List<String>?) {
    if (!errors.isNullOrEmpty()) {
        Text(
            errors.joinToString(" "),
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.error,
        )
    }
}

private fun formatDateTime(iso: String): String = runCatching {
    java.time.OffsetDateTime.parse(iso)
        .format(java.time.format.DateTimeFormatter.ofPattern("dd MMM yyyy · hh:mm a"))
}.getOrDefault(iso)
