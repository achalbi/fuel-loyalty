package com.acefuel.loyalty.ui.admin.attendance

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.clickable
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
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Add
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDialog
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TimePicker
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.rememberDatePickerState
import androidx.compose.material3.rememberTimePickerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import com.acefuel.loyalty.core.di.LocalContainer
import com.acefuel.loyalty.ui.theme.NayaraButton
import com.acefuel.loyalty.ui.theme.NayaraOutlinedButton
import com.acefuel.loyalty.ui.theme.nayara
import java.time.Instant
import java.time.LocalTime
import java.time.ZoneOffset
import java.time.format.DateTimeFormatter

// Canonical status order + labels (Rails AttendanceEntry.statuses / humanize).
private val STATUS_OPTIONS = listOf(
    "present" to "Present",
    "absent" to "Absent",
    "late" to "Late",
    "half_day" to "Half Day",
    "leave" to "Leave",
    "off" to "Off",
)

private fun statusLabel(status: String): String =
    STATUS_OPTIONS.firstOrNull { it.first == status }?.second
        ?: status.replace('_', ' ').replaceFirstChar { it.uppercase() }

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AdminAttendanceScreen(onBack: () -> Unit) {
    val container = LocalContainer.current
    val repo = remember {
        AttendanceRepository(container.retrofit.create(AttendanceApi::class.java), container.json)
    }
    val vm: AttendanceViewModel = viewModel(factory = viewModelFactory { initializer { AttendanceViewModel(repo) } })
    val state by vm.state.collectAsStateWithLifecycle()

    val snackbarHostState = remember { SnackbarHostState() }
    LaunchedEffect(state.actionMessage) {
        state.actionMessage?.let {
            snackbarHostState.showSnackbar(it)
            vm.consumeActionMessage()
        }
    }

    BackHandler(enabled = state.mode != AttendanceScreenMode.LIST) { vm.backToList() }

    val title = when (state.mode) {
        AttendanceScreenMode.LIST -> "Attendance"
        AttendanceScreenMode.DETAIL -> "Attendance Details"
        AttendanceScreenMode.PLANNER -> "New Attendance"
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(title) },
                navigationIcon = {
                    IconButton(onClick = { if (state.mode == AttendanceScreenMode.LIST) onBack() else vm.backToList() }) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                },
                actions = {
                    if (state.mode == AttendanceScreenMode.LIST) {
                        IconButton(onClick = { vm.openPlanner() }) {
                            Icon(Icons.Filled.Add, contentDescription = "New attendance")
                        }
                    }
                },
            )
        },
        snackbarHost = { SnackbarHost(snackbarHostState) },
    ) { innerPadding ->
        Box(Modifier.fillMaxSize().padding(innerPadding)) {
            when (state.mode) {
                AttendanceScreenMode.LIST -> ListContent(state, vm)
                AttendanceScreenMode.DETAIL -> DetailContent(state, vm)
                AttendanceScreenMode.PLANNER -> PlannerContent(state, vm)
            }
        }
    }
}

// ============================================================================
// LIST
// ============================================================================

@Composable
private fun ListContent(state: AttendanceUiState, vm: AttendanceViewModel) {
    var datePickerFor by remember { mutableStateOf<String?>(null) } // "start" | "end"

    LazyColumn(
        modifier = Modifier.fillMaxSize().padding(horizontal = 16.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
        contentPadding = PaddingValues(vertical = 12.dp),
    ) {
        item(key = "filters") {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Text("Record State", style = MaterialTheme.typography.labelMedium, color = MaterialTheme.nayara.textSecondary)
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    listOf("all" to "All", "valid" to "Valid", "invalid" to "Invalid").forEach { (value, label) ->
                        FilterChip(
                            selected = state.filter == value,
                            onClick = { vm.setFilter(value) },
                            label = { Text(label) },
                        )
                    }
                }
                Text("Attendance Date", style = MaterialTheme.typography.labelMedium, color = MaterialTheme.nayara.textSecondary)
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    PickerField(
                        label = "From",
                        value = state.startDate ?: "Any",
                        modifier = Modifier.weight(1f),
                        onClick = { datePickerFor = "start" },
                    )
                    PickerField(
                        label = "To",
                        value = state.endDate ?: "Any",
                        modifier = Modifier.weight(1f),
                        onClick = { datePickerFor = "end" },
                    )
                }
                if (state.startDate != null || state.endDate != null) {
                    TextButton(onClick = { vm.setStartDate(null); vm.setEndDate(null) }) { Text("Clear dates") }
                }
            }
        }

        when {
            state.listLoading && state.runs.isEmpty() ->
                item(key = "loading") { CenteredSpinner() }
            state.listError != null ->
                item(key = "error") { ErrorCard(state.listError) }
            state.runs.isEmpty() ->
                item(key = "empty") {
                    EmptyCard(
                        title = "No attendance found for the current filters",
                        body = "Try another filter or start a new attendance run to see recorded shift windows here.",
                    )
                }
            else -> {
                items(state.runs, key = { "run-${it.id}" }) { run -> RunCard(run, onClick = { vm.openRun(run.id) }) }
                item(key = "pagination") { PaginationRow(state, vm) }
            }
        }
    }

    if (datePickerFor != null) {
        val initial = if (datePickerFor == "start") isoDateToMillis(state.startDate) else isoDateToMillis(state.endDate)
        DatePickerModal(
            initialMillis = initial,
            onConfirm = { millis ->
                val iso = millisToIsoDate(millis)
                if (datePickerFor == "start") vm.setStartDate(iso) else vm.setEndDate(iso)
                datePickerFor = null
            },
            onDismiss = { datePickerFor = null },
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun RunCard(run: AttendanceRunDto, onClick: () -> Unit) {
    Card(modifier = Modifier.fillMaxWidth(), onClick = onClick) {
        Column(Modifier.padding(16.dp)) {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.Top) {
                Column(Modifier.weight(1f)) {
                    Text(run.shiftName ?: "Shift", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
                    Text(
                        "${fmtDateTime(run.startsAt)} to ${fmtDateTime(run.endsAt)}",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.nayara.textSecondary,
                    )
                }
                if (run.stale) {
                    TagLabel("Invalid", MaterialTheme.nayara.statusErrorContainer, MaterialTheme.nayara.statusOnErrorContainer)
                } else {
                    TagLabel("Valid", MaterialTheme.nayara.statusSuccessContainer, MaterialTheme.nayara.statusOnSuccessContainer)
                }
            }
            Spacer(Modifier.height(8.dp))
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                LabelValue("Staff", "${run.entryCount}")
                LabelValue("Recorded By", run.recordedBy?.displayName ?: "—")
                LabelValue("Saved", fmtDateTime(run.createdAt))
            }
            val summary = STATUS_OPTIONS.mapNotNull { (key, label) ->
                val count = run.statusCounts[key] ?: 0
                if (count > 0) "$label $count" else null
            }.joinToString(" · ")
            if (summary.isNotBlank()) {
                Spacer(Modifier.height(8.dp))
                Text(summary, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.nayara.textBrand)
            }
        }
    }
}

@Composable
private fun PaginationRow(state: AttendanceUiState, vm: AttendanceViewModel) {
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Text(
            "Showing ${state.showingFrom}-${state.showingTo} of ${state.total} attendance records",
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.nayara.textTertiary,
        )
        if (state.totalPages > 1) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                NayaraOutlinedButton(onClick = { vm.goToPage(state.page - 1) }, enabled = state.page > 1) { Text("Previous") }
                Text("Page ${state.page} of ${state.totalPages}", style = MaterialTheme.typography.labelMedium)
                NayaraOutlinedButton(onClick = { vm.goToPage(state.page + 1) }, enabled = state.page < state.totalPages) { Text("Next") }
            }
        }
    }
}

// ============================================================================
// DETAIL
// ============================================================================

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun DetailContent(state: AttendanceUiState, vm: AttendanceViewModel) {
    var confirmInvalidate by remember { mutableStateOf(false) }
    var confirmDelete by remember { mutableStateOf(false) }
    val run = state.selectedRun

    when {
        state.detailLoading && run == null -> CenteredSpinner()
        run == null -> ErrorCard(state.detailError ?: "Attendance record not found.", Modifier.padding(16.dp))
        else -> LazyColumn(
            modifier = Modifier.fillMaxSize().padding(horizontal = 16.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
            contentPadding = PaddingValues(vertical = 12.dp),
        ) {
            item(key = "d-summary") {
                Card(Modifier.fillMaxWidth()) {
                    Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.Top) {
                            Text(run.shiftName ?: "Shift", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.SemiBold)
                            if (run.stale) {
                                TagLabel("Invalid", MaterialTheme.nayara.statusErrorContainer, MaterialTheme.nayara.statusOnErrorContainer)
                            } else {
                                TagLabel("Valid", MaterialTheme.nayara.statusSuccessContainer, MaterialTheme.nayara.statusOnSuccessContainer)
                            }
                        }
                        LabelValue("Window", "${fmtDateTime(run.startsAt)} to ${fmtTime(run.endsAt)}")
                        LabelValue("Recorded By", run.recordedBy?.displayName ?: "—")
                        run.notes?.takeIf { it.isNotBlank() }?.let { LabelValue("Run Notes", it) }
                    }
                }
            }

            state.detailError?.let { item(key = "d-error") { ErrorCard(it) } }

            item(key = "d-actions") {
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    if (run.stale) {
                        NayaraButton(
                            onClick = { vm.markSelectedValid() },
                            enabled = !state.detailActionInFlight,
                            loading = state.detailActionInFlight,
                            modifier = Modifier.weight(1f),
                        ) { Text("Mark Valid") }
                        NayaraOutlinedButton(
                            onClick = { confirmDelete = true },
                            enabled = !state.detailActionInFlight,
                            modifier = Modifier.weight(1f),
                        ) { Text("Delete") }
                    } else {
                        NayaraOutlinedButton(
                            onClick = { confirmInvalidate = true },
                            enabled = !state.detailActionInFlight,
                            modifier = Modifier.weight(1f),
                        ) { Text("Invalidate") }
                    }
                }
            }

            item(key = "d-counts-header") { SectionHeader("Status Counts") }
            item(key = "d-counts") {
                FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    STATUS_OPTIONS.forEach { (key, label) ->
                        val (container, content) = statusColors(key)
                        Surface(color = container, contentColor = content, shape = MaterialTheme.shapes.small) {
                            Column(Modifier.padding(horizontal = 14.dp, vertical = 8.dp)) {
                                Text(label, style = MaterialTheme.typography.labelSmall)
                                Text("${run.statusCounts[key] ?: 0}", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
                            }
                        }
                    }
                }
            }

            item(key = "d-entries-header") { SectionHeader("Entries (${run.entries.size})") }
            if (run.entries.isEmpty()) {
                item(key = "d-entries-empty") { EmptyNote("No staff rows on this record.") }
            } else {
                items(run.entries, key = { "entry-${it.id ?: it.scheduledUser?.id ?: 0}" }) { entry -> DetailEntryCard(entry) }
            }
        }
    }

    if (confirmInvalidate) {
        ConfirmDialog(
            title = "Invalidate attendance?",
            message = "Mark this attendance record invalid? It stays on record but is not counted as valid.",
            confirmLabel = "Invalidate",
            onConfirm = { confirmInvalidate = false; vm.invalidateSelected() },
            onDismiss = { confirmInvalidate = false },
        )
    }
    if (confirmDelete) {
        ConfirmDialog(
            title = "Delete record?",
            message = "Delete this invalid attendance record? This cannot be undone.",
            confirmLabel = "Delete",
            onConfirm = { confirmDelete = false; vm.deleteSelected() },
            onDismiss = { confirmDelete = false },
        )
    }
}

@Composable
private fun DetailEntryCard(entry: AttendanceEntryDto) {
    val (container, content) = statusColors(entry.status)
    Card(Modifier.fillMaxWidth()) {
        Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                Text(
                    entry.scheduledUser?.displayName ?: entry.workerName ?: "Staff",
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.SemiBold,
                )
                TagLabel(statusLabel(entry.status), container, content)
            }
            LabelValue("Actual staff", entry.workerName ?: "—")
            LabelValue("Check in", fmtTime(entry.checkInAt))
            LabelValue("Check out", fmtTime(entry.checkOutAt))
            entry.notes?.takeIf { it.isNotBlank() }?.let { LabelValue("Notes", it) }
        }
    }
}

// ============================================================================
// PLANNER
// ============================================================================

private sealed interface TimeEdit {
    data object StartTime : TimeEdit
    data class CheckIn(val index: Int) : TimeEdit
    data class CheckOut(val index: Int) : TimeEdit
}

@Composable
private fun PlannerContent(state: AttendanceUiState, vm: AttendanceViewModel) {
    var showDatePicker by remember { mutableStateOf(false) }
    var timeEdit by remember { mutableStateOf<TimeEdit?>(null) }

    LazyColumn(
        modifier = Modifier.fillMaxSize().padding(horizontal = 16.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
        contentPadding = PaddingValues(vertical = 12.dp),
    ) {
        item(key = "p-intro") {
            Text(
                "Select a shift window, load the assigned staff, and record the shift attendance in one place.",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.nayara.textSecondary,
            )
        }

        item(key = "p-form") {
            Card(Modifier.fillMaxWidth()) {
                Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    if (state.templatesLoading) {
                        CenteredSpinner()
                    } else if (state.templatesError != null) {
                        ErrorCard(state.templatesError)
                        NayaraOutlinedButton(onClick = { vm.loadShiftTemplates() }) { Text("Retry") }
                    } else {
                        LabeledDropdown(
                            label = "Shift",
                            selectedLabel = state.selectedShift?.let { shiftOptionLabel(it) } ?: "Select a shift",
                            options = state.shiftTemplates.map { it.id to shiftOptionLabel(it) },
                            onSelect = { vm.selectShift(it) },
                        )
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            PickerField(
                                label = "Start Date",
                                value = fmtMillisDate(state.startMillis),
                                modifier = Modifier.weight(1f),
                                onClick = { showDatePicker = true },
                            )
                            PickerField(
                                label = "Start Time",
                                value = fmtHourMinute(state.startHour, state.startMinute),
                                modifier = Modifier.weight(1f),
                                onClick = { timeEdit = TimeEdit.StartTime },
                            )
                        }
                        NayaraButton(
                            onClick = { vm.loadStaff() },
                            enabled = state.selectedShiftId != null && !state.plannerLoading,
                            loading = state.plannerLoading,
                            modifier = Modifier.fillMaxWidth(),
                        ) { Text("Load Staff") }
                    }
                }
            }
        }

        state.plannerError?.let { item(key = "p-error") { ErrorCard(it) } }

        if (state.plannerBaseErrors.isNotEmpty()) {
            item(key = "p-base-errors") { ErrorCard(state.plannerBaseErrors.joinToString(" ")) }
        }

        when {
            state.staffLoaded && state.draftEntries.isNotEmpty() -> {
                item(key = "p-window") {
                    Card(Modifier.fillMaxWidth()) {
                        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                            Text(state.plannerShiftName ?: "Shift", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
                            LabelValue("Window", "${fmtDateTime(state.windowStart)} to ${fmtTime(state.windowEnd)}")
                            LabelValue("Loaded Staff", "${state.draftEntries.size}")
                        }
                    }
                }
                item(key = "p-entries-header") {
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                        SectionHeader("Attendance Entries")
                        NayaraOutlinedButton(onClick = { vm.markAllPresent() }, enabled = !state.saving) { Text("Mark All Present") }
                    }
                }
                itemsIndexedDraft(state.draftEntries) { index, entry ->
                    DraftEntryCard(
                        entry = entry,
                        onStatus = { vm.updateEntryStatus(index, it) },
                        onNotes = { vm.updateEntryNotes(index, it) },
                        onExternal = { vm.updateEntryExternalReplacement(index, it) },
                        onEditCheckIn = { timeEdit = TimeEdit.CheckIn(index) },
                        onEditCheckOut = { timeEdit = TimeEdit.CheckOut(index) },
                        onClearCheckIn = { vm.clearEntryCheckTime(index, true) },
                        onClearCheckOut = { vm.clearEntryCheckTime(index, false) },
                    )
                }
                item(key = "p-run-notes") {
                    Card(Modifier.fillMaxWidth()) {
                        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                            Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.SpaceBetween) {
                                Column(Modifier.weight(1f).padding(end = 8.dp)) {
                                    Text("Mark as invalid record", style = MaterialTheme.typography.bodyMedium)
                                    Text(
                                        "Keeps it on record but not counted as a valid entry.",
                                        style = MaterialTheme.typography.labelSmall,
                                        color = MaterialTheme.nayara.textTertiary,
                                    )
                                }
                                Switch(checked = state.markInvalid, onCheckedChange = { vm.setMarkInvalid(it) })
                            }
                            OutlinedTextField(
                                value = state.runNotes,
                                onValueChange = { vm.setRunNotes(it) },
                                label = { Text("Run Notes") },
                                modifier = Modifier.fillMaxWidth(),
                                minLines = 2,
                            )
                        }
                    }
                }
                state.saveError?.let { item(key = "p-save-error") { ErrorCard(it) } }
                item(key = "p-save") {
                    NayaraButton(
                        onClick = { vm.save() },
                        enabled = !state.saving,
                        loading = state.saving,
                        modifier = Modifier.fillMaxWidth(),
                    ) { Text("Save Attendance") }
                }
            }
            state.selectedShiftId != null && state.plannerBaseErrors.isEmpty() && state.windowStart != null && state.draftEntries.isEmpty() && !state.plannerLoading ->
                item(key = "p-no-staff") {
                    EmptyCard(
                        title = "No staff assigned yet",
                        body = "This shift does not have any active staff assignments for the selected date. Assign staff first, then come back to attendance.",
                    )
                }
            state.selectedShiftId == null ->
                item(key = "p-start") {
                    EmptyCard(
                        title = "Start by selecting a shift",
                        body = "Choose the shift and start time above, and the staff roster for that window will load here.",
                    )
                }
        }
    }

    if (showDatePicker) {
        DatePickerModal(
            initialMillis = state.startMillis,
            onConfirm = { millis -> millis?.let { vm.setStartDate(it) }; showDatePicker = false },
            onDismiss = { showDatePicker = false },
        )
    }

    timeEdit?.let { target ->
        val (initialHour, initialMinute, dialogTitle) = when (target) {
            is TimeEdit.StartTime -> Triple(state.startHour, state.startMinute, "Start Time")
            is TimeEdit.CheckIn -> {
                val hm = isoToHourMinute(state.draftEntries.getOrNull(target.index)?.checkInAt)
                Triple(hm?.first ?: state.startHour, hm?.second ?: state.startMinute, "Check In")
            }
            is TimeEdit.CheckOut -> {
                val hm = isoToHourMinute(state.draftEntries.getOrNull(target.index)?.checkOutAt)
                Triple(hm?.first ?: state.startHour, hm?.second ?: state.startMinute, "Check Out")
            }
        }
        TimePickerModal(
            title = dialogTitle,
            initialHour = initialHour,
            initialMinute = initialMinute,
            onConfirm = { hour, minute ->
                when (target) {
                    is TimeEdit.StartTime -> vm.setStartTime(hour, minute)
                    is TimeEdit.CheckIn -> vm.setEntryCheckTime(target.index, true, hour, minute)
                    is TimeEdit.CheckOut -> vm.setEntryCheckTime(target.index, false, hour, minute)
                }
                timeEdit = null
            },
            onDismiss = { timeEdit = null },
        )
    }
}

@Composable
private fun DraftEntryCard(
    entry: DraftEntry,
    onStatus: (String) -> Unit,
    onNotes: (String) -> Unit,
    onExternal: (String) -> Unit,
    onEditCheckIn: () -> Unit,
    onEditCheckOut: () -> Unit,
    onClearCheckIn: () -> Unit,
    onClearCheckOut: () -> Unit,
) {
    Card(Modifier.fillMaxWidth()) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Column {
                Text(entry.name, style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.SemiBold)
                Text(entry.phone ?: "Mobile not set", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.nayara.textSecondary)
            }
            LabeledDropdown(
                label = "Status",
                selectedLabel = statusLabel(entry.status),
                options = STATUS_OPTIONS.map { it.first to it.second },
                onSelect = onStatus,
            )
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                CheckTimeField("Check In", entry.checkInAt, Modifier.weight(1f), onEditCheckIn, onClearCheckIn)
                CheckTimeField("Check Out", entry.checkOutAt, Modifier.weight(1f), onEditCheckOut, onClearCheckOut)
            }
            if (entry.status == "absent") {
                OutlinedTextField(
                    value = entry.externalReplacementName,
                    onValueChange = onExternal,
                    label = { Text("External Replacement") },
                    placeholder = { Text("Temp cover name") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth(),
                )
            }
            OutlinedTextField(
                value = entry.notes,
                onValueChange = onNotes,
                label = { Text("Notes") },
                placeholder = { Text("Optional note for this row") },
                modifier = Modifier.fillMaxWidth(),
                minLines = 1,
            )
        }
    }
}

@Composable
private fun CheckTimeField(
    label: String,
    iso: String?,
    modifier: Modifier = Modifier,
    onEdit: () -> Unit,
    onClear: () -> Unit,
) {
    Column(modifier, verticalArrangement = Arrangement.spacedBy(2.dp)) {
        PickerField(label = label, value = fmtTime(iso), onClick = onEdit)
        if (iso != null) {
            TextButton(onClick = onClear, contentPadding = PaddingValues(horizontal = 4.dp, vertical = 0.dp)) {
                Text("Clear", style = MaterialTheme.typography.labelSmall)
            }
        }
    }
}

private fun shiftOptionLabel(t: ShiftTemplateDto): String =
    listOfNotNull(t.name, t.startTimeLabel, t.durationLabel).joinToString(" · ")

// ============================================================================
// Shared building blocks
// ============================================================================

/**
 * A tap-to-open dropdown built on the stable [DropdownMenu] (no experimental
 * ExposedDropdown APIs). The field is a read-only picker; the menu anchors to
 * the wrapping [Box].
 */
@Composable
private fun <T> LabeledDropdown(
    label: String,
    selectedLabel: String,
    options: List<Pair<T, String>>,
    modifier: Modifier = Modifier,
    onSelect: (T) -> Unit,
) {
    var expanded by remember { mutableStateOf(false) }
    Box(modifier) {
        PickerField(label = label, value = selectedLabel, modifier = Modifier.fillMaxWidth()) { expanded = true }
        DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
            options.forEach { (value, text) ->
                DropdownMenuItem(text = { Text(text) }, onClick = { onSelect(value); expanded = false })
            }
        }
    }
}

/** Read-only text field that behaves as a button (a transparent overlay captures taps). */
@Composable
private fun PickerField(label: String, value: String, modifier: Modifier = Modifier, onClick: () -> Unit) {
    Box(modifier) {
        OutlinedTextField(
            value = value,
            onValueChange = {},
            readOnly = true,
            singleLine = true,
            label = { Text(label) },
            modifier = Modifier.fillMaxWidth(),
        )
        Box(Modifier.matchParentSize().clickable(onClick = onClick))
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun DatePickerModal(initialMillis: Long?, onConfirm: (Long?) -> Unit, onDismiss: () -> Unit) {
    val pickerState = rememberDatePickerState(initialSelectedDateMillis = initialMillis)
    DatePickerDialog(
        onDismissRequest = onDismiss,
        confirmButton = { TextButton(onClick = { onConfirm(pickerState.selectedDateMillis) }) { Text("OK") } },
        dismissButton = { TextButton(onClick = onDismiss) { Text("Cancel") } },
    ) {
        DatePicker(state = pickerState)
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun TimePickerModal(
    title: String,
    initialHour: Int,
    initialMinute: Int,
    onConfirm: (Int, Int) -> Unit,
    onDismiss: () -> Unit,
) {
    val pickerState = rememberTimePickerState(initialHour = initialHour, initialMinute = initialMinute, is24Hour = false)
    AlertDialog(
        onDismissRequest = onDismiss,
        confirmButton = { TextButton(onClick = { onConfirm(pickerState.hour, pickerState.minute) }) { Text("OK") } },
        dismissButton = { TextButton(onClick = onDismiss) { Text("Cancel") } },
        title = { Text(title) },
        text = { Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) { TimePicker(state = pickerState) } },
    )
}

@Composable
private fun ConfirmDialog(
    title: String,
    message: String,
    confirmLabel: String,
    onConfirm: () -> Unit,
    onDismiss: () -> Unit,
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        confirmButton = { TextButton(onClick = onConfirm) { Text(confirmLabel) } },
        dismissButton = { TextButton(onClick = onDismiss) { Text("Cancel") } },
        title = { Text(title) },
        text = { Text(message) },
    )
}

@Composable
private fun SectionHeader(text: String) {
    Text(text, style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.SemiBold, modifier = Modifier.padding(top = 4.dp))
}

@Composable
private fun EmptyNote(text: String) {
    Text(text, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.nayara.textSecondary)
}

@Composable
private fun LabelValue(label: String, value: String) {
    Column {
        Text(label, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.nayara.textTertiary)
        Text(value, style = MaterialTheme.typography.bodyMedium)
    }
}

@Composable
private fun TagLabel(text: String, container: Color, content: Color) {
    Surface(color = container, contentColor = content, shape = MaterialTheme.shapes.small) {
        Text(
            text,
            style = MaterialTheme.typography.labelMedium,
            fontWeight = FontWeight.Medium,
            modifier = Modifier.padding(horizontal = 10.dp, vertical = 4.dp),
        )
    }
}

@Composable
private fun CenteredSpinner() {
    Box(Modifier.fillMaxWidth().padding(32.dp), contentAlignment = Alignment.Center) { CircularProgressIndicator() }
}

@Composable
private fun ErrorCard(message: String?, modifier: Modifier = Modifier) {
    Card(
        modifier = modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.errorContainer,
            contentColor = MaterialTheme.colorScheme.onErrorContainer,
        ),
    ) {
        Text(message ?: "Something went wrong.", modifier = Modifier.padding(16.dp), style = MaterialTheme.typography.bodyMedium)
    }
}

@Composable
private fun EmptyCard(title: String, body: String) {
    Card(Modifier.fillMaxWidth()) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text(title, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
            Text(body, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.nayara.textSecondary)
        }
    }
}

@Composable
private fun statusColors(status: String): Pair<Color, Color> {
    val n = MaterialTheme.nayara
    return when (status) {
        "present", "late" -> n.statusSuccessContainer to n.statusOnSuccessContainer
        "absent" -> n.statusErrorContainer to n.statusOnErrorContainer
        "half_day" -> n.statusWarningContainer to n.statusOnWarningContainer
        "leave" -> n.statusInfoContainer to n.statusOnInfoContainer
        else -> n.bgSurfaceSunken to n.textSecondary
    }
}

// ---- LazyColumn helper: indexed items for the draft list (stable per-user keys) ----
private fun androidx.compose.foundation.lazy.LazyListScope.itemsIndexedDraft(
    entries: List<DraftEntry>,
    content: @Composable (Int, DraftEntry) -> Unit,
) {
    entries.forEachIndexed { index, entry ->
        item(key = "draft-${entry.scheduledUserId}") { content(index, entry) }
    }
}

// ============================================================================
// Date / time formatting helpers
// ============================================================================

private val DATE_TIME_FMT: DateTimeFormatter = DateTimeFormatter.ofPattern("dd MMM · hh:mm a")
private val TIME_FMT: DateTimeFormatter = DateTimeFormatter.ofPattern("hh:mm a")
private val DATE_FMT: DateTimeFormatter = DateTimeFormatter.ofPattern("dd MMM yyyy")

private fun parseDateTime(iso: String?): java.time.LocalDateTime? = iso?.let { raw ->
    runCatching { java.time.OffsetDateTime.parse(raw).toLocalDateTime() }
        .recoverCatching { java.time.LocalDateTime.parse(raw) }
        .getOrNull()
}

private fun fmtDateTime(iso: String?): String = parseDateTime(iso)?.format(DATE_TIME_FMT) ?: (iso ?: "—")

private fun fmtTime(iso: String?): String = parseDateTime(iso)?.toLocalTime()?.format(TIME_FMT) ?: "Not recorded"

private fun fmtHourMinute(hour: Int, minute: Int): String = LocalTime.of(hour, minute).format(TIME_FMT)

private fun fmtMillisDate(millis: Long?): String = millis?.let {
    Instant.ofEpochMilli(it).atZone(ZoneOffset.UTC).toLocalDate().format(DATE_FMT)
} ?: "Select date"

private fun isoToHourMinute(iso: String?): Pair<Int, Int>? =
    parseDateTime(iso)?.toLocalTime()?.let { it.hour to it.minute }

private fun millisToIsoDate(millis: Long?): String? = millis?.let {
    Instant.ofEpochMilli(it).atZone(ZoneOffset.UTC).toLocalDate().toString()
}

private fun isoDateToMillis(iso: String?): Long? = iso?.let {
    runCatching {
        java.time.LocalDate.parse(it).atStartOfDay(ZoneOffset.UTC).toInstant().toEpochMilli()
    }.getOrNull()
}
