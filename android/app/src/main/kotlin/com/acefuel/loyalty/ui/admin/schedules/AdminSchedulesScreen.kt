package com.acefuel.loyalty.ui.admin.schedules

import androidx.compose.foundation.background
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
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Add
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import com.acefuel.loyalty.core.di.LocalContainer
import com.acefuel.loyalty.ui.theme.NayaraButton
import com.acefuel.loyalty.ui.theme.NayaraOutlinedButton
import com.acefuel.loyalty.ui.theme.nayara

private val FREQUENCIES = listOf("once" to "Once", "daily" to "Daily", "weekly" to "Weekly", "monthly" to "Monthly")
private val WEEKDAYS = listOf("Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday")
private val HOURS = (0..23).map { it.toString().padStart(2, '0') }
private val MINUTES = (0..59).map { it.toString().padStart(2, '0') }
private val DAYS_OF_MONTH = (1..31).map { it.toString() }

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AdminSchedulesScreen(onBack: () -> Unit) {
    val container = LocalContainer.current
    val repo = remember {
        AdminSchedulesRepository(container.retrofit.create(AdminSchedulesApi::class.java), container.json)
    }
    val vm: AdminSchedulesViewModel = viewModel(factory = viewModelFactory { initializer { AdminSchedulesViewModel(repo) } })
    val state by vm.state.collectAsStateWithLifecycle()

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Notifications") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                },
            )
        },
    ) { innerPadding ->
        LazyColumn(
            modifier = Modifier.fillMaxSize().padding(innerPadding).padding(horizontal = 16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
            contentPadding = PaddingValues(vertical = 12.dp),
        ) {
            item(key = "send-card") { SendNowCard(state, vm) }
            item(key = "run-card") { RunSchedulerCard(state, vm) }
            item(key = "sched-header") { SchedulesHeader(state.schedules.size, onNew = vm::openCreate) }

            state.rowError?.let { item(key = "row-error") { FeedbackText(it, isError = true) } }
            state.rowMessage?.let { item(key = "row-msg") { FeedbackText(it, isError = false) } }

            when {
                state.loading && state.schedules.isEmpty() -> item(key = "sched-loading") {
                    Box(Modifier.fillMaxWidth().padding(24.dp), contentAlignment = Alignment.Center) {
                        CircularProgressIndicator()
                    }
                }
                state.loadError != null && state.schedules.isEmpty() -> item(key = "sched-load-error") {
                    ErrorCard(state.loadError!!)
                }
                state.schedules.isEmpty() -> item(key = "sched-empty") {
                    Text(
                        "No schedules yet",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.nayara.textSecondary,
                        modifier = Modifier.padding(vertical = 8.dp),
                    )
                }
                else -> items(state.schedules, key = { "sched-${it.id}" }) { schedule ->
                    ScheduleRow(
                        schedule = schedule,
                        busy = state.rowActionId == schedule.id,
                        onSend = { vm.sendRow(schedule.id) },
                        onEdit = { vm.openEdit(schedule) },
                        onDelete = { vm.requestDelete(schedule.id) },
                    )
                }
            }
        }
    }

    if (state.formOpen) {
        ScheduleFormSheet(state, vm)
    }

    if (state.pendingDeleteId != null) {
        val target = state.schedules.firstOrNull { it.id == state.pendingDeleteId }
        AlertDialog(
            onDismissRequest = vm::cancelDelete,
            title = { Text("Delete schedule?") },
            text = { Text("This removes \"${target?.title ?: "this schedule"}\" for good. This can't be undone.") },
            confirmButton = {
                TextButton(onClick = vm::confirmDelete) {
                    Text("Delete", color = MaterialTheme.colorScheme.error)
                }
            },
            dismissButton = { TextButton(onClick = vm::cancelDelete) { Text("Cancel") } },
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
            "Broadcast an instant push to every active device.",
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
        state.sendError?.let { FeedbackText(it, isError = true) }
        state.sendResult?.let { FeedbackText(it, isError = false) }
        NayaraButton(
            onClick = vm::sendNotification,
            loading = state.sending,
            enabled = state.sendTitle.isNotBlank() && state.sendMessage.isNotBlank(),
            modifier = Modifier.fillMaxWidth(),
        ) { Text("Send Now") }
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
        state.runError?.let { FeedbackText(it, isError = true) }
        state.runResult?.let { FeedbackText(it, isError = false) }
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
) {
    Card(Modifier.fillMaxWidth()) {
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
                Pill(
                    text = if (schedule.active) "Active" else "Paused",
                    bg = if (schedule.active) MaterialTheme.nayara.statusSuccessContainer else MaterialTheme.nayara.bgSurfaceSunken,
                    fg = if (schedule.active) MaterialTheme.nayara.statusOnSuccessContainer else MaterialTheme.nayara.textSecondary,
                )
            }
            Pill(
                text = schedule.frequency.replaceFirstChar { it.uppercase() },
                bg = MaterialTheme.nayara.statusInfoContainer,
                fg = MaterialTheme.nayara.statusOnInfoContainer,
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
// Create / Edit bottom sheet
// ---------------------------------------------------------------------------

@OptIn(ExperimentalMaterial3Api::class, ExperimentalLayoutApi::class)
@Composable
private fun ScheduleFormSheet(state: AdminSchedulesUiState, vm: AdminSchedulesViewModel) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    ModalBottomSheet(onDismissRequest = vm::closeForm, sheetState = sheetState) {
        val f = state.form
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 20.dp)
                .padding(bottom = 24.dp)
                .verticalScroll(rememberScrollState())
                .imePadding(),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Text(
                if (state.editing) "Edit Schedule" else "New Schedule",
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold,
            )
            OutlinedTextField(
                value = f.title,
                onValueChange = vm::onFormTitle,
                label = { Text("Title") },
                singleLine = true,
                supportingText = { Text("${f.title.length}/120") },
                modifier = Modifier.fillMaxWidth(),
            )
            OutlinedTextField(
                value = f.message,
                onValueChange = vm::onFormMessage,
                label = { Text("Message") },
                minLines = 2,
                supportingText = { Text("${f.message.length}/240") },
                modifier = Modifier.fillMaxWidth(),
            )

            Text("Frequency", style = MaterialTheme.typography.labelMedium, color = MaterialTheme.nayara.textSecondary)
            FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                FREQUENCIES.forEach { (value, label) ->
                    FilterChip(
                        selected = f.frequency == value,
                        onClick = { vm.onFormFrequency(value) },
                        label = { Text(label) },
                    )
                }
            }

            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                DropdownField("Hour (IST)", f.hour, HOURS, { it }, vm::onFormHour, Modifier.weight(1f))
                DropdownField("Minute", f.minute, MINUTES, { it }, vm::onFormMinute, Modifier.weight(1f))
            }
            Text("Times use India Standard Time (IST).", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.nayara.textTertiary)

            when (f.frequency) {
                "once" -> {
                    OutlinedTextField(
                        value = f.scheduledDate,
                        onValueChange = vm::onFormDate,
                        label = { Text("Send on") },
                        placeholder = { Text("YYYY-MM-DD") },
                        singleLine = true,
                        modifier = Modifier.fillMaxWidth(),
                    )
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
                Switch(checked = f.active, onCheckedChange = vm::onFormActive)
            }

            state.formError?.let { FeedbackText(it, isError = true) }

            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                NayaraOutlinedButton(onClick = vm::closeForm, enabled = !state.saving, modifier = Modifier.weight(1f)) {
                    Text("Cancel")
                }
                NayaraButton(onClick = vm::saveForm, loading = state.saving, modifier = Modifier.weight(1f)) {
                    Text(if (state.editing) "Save" else "Create")
                }
            }
        }
    }
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
    var expanded by remember { mutableStateOf(false) }
    Column(modifier) {
        Text(label, style = MaterialTheme.typography.labelMedium, color = MaterialTheme.nayara.textSecondary)
        Spacer(Modifier.height(4.dp))
        Box {
            OutlinedButton(onClick = { expanded = true }, modifier = Modifier.fillMaxWidth()) {
                Text(selectedLabel, modifier = Modifier.weight(1f), textAlign = TextAlign.Start)
                Text("▾")
            }
            DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
                options.forEach { opt ->
                    DropdownMenuItem(
                        text = { Text(optionLabel(opt)) },
                        onClick = {
                            onSelect(opt)
                            expanded = false
                        },
                    )
                }
            }
        }
    }
}

@Composable
private fun Pill(text: String, bg: androidx.compose.ui.graphics.Color, fg: androidx.compose.ui.graphics.Color) {
    Box(
        Modifier
            .clip(MaterialTheme.shapes.small)
            .background(bg)
            .padding(horizontal = 10.dp, vertical = 3.dp),
    ) {
        Text(text, style = MaterialTheme.typography.labelSmall, color = fg)
    }
}

@Composable
private fun FeedbackText(text: String, isError: Boolean) {
    Text(
        text,
        style = MaterialTheme.typography.bodySmall,
        color = if (isError) MaterialTheme.colorScheme.error else MaterialTheme.nayara.statusSuccessText,
    )
}

@Composable
private fun ErrorCard(text: String) {
    Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.errorContainer)) {
        Text(
            text,
            modifier = Modifier.padding(14.dp),
            color = MaterialTheme.colorScheme.onErrorContainer,
            style = MaterialTheme.typography.bodyMedium,
        )
    }
}

private fun formatDateTime(iso: String): String = runCatching {
    java.time.OffsetDateTime.parse(iso)
        .format(java.time.format.DateTimeFormatter.ofPattern("dd MMM yyyy · hh:mm a"))
}.getOrDefault(iso)
