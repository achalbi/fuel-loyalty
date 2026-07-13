package com.acefuel.loyalty.ui.admin.attendance

import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.togetherWith
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
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyItemScope
import androidx.compose.foundation.lazy.LazyListScope
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Add
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
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
import com.acefuel.loyalty.ui.designsystem.ChipTone
import com.acefuel.loyalty.ui.designsystem.ConfirmDialog
import com.acefuel.loyalty.ui.designsystem.DateField
import com.acefuel.loyalty.ui.designsystem.EmptyState
import com.acefuel.loyalty.ui.designsystem.ErrorState
import com.acefuel.loyalty.ui.designsystem.InlineErrorCard
import com.acefuel.loyalty.ui.designsystem.NayaraCard
import com.acefuel.loyalty.ui.designsystem.NayaraPullToRefresh
import com.acefuel.loyalty.ui.designsystem.NayaraSnackbarHost
import com.acefuel.loyalty.ui.designsystem.PickerField
import com.acefuel.loyalty.ui.designsystem.SkeletonCard
import com.acefuel.loyalty.ui.designsystem.SkeletonList
import com.acefuel.loyalty.ui.designsystem.StatusChip
import com.acefuel.loyalty.ui.designsystem.TimeField
import com.acefuel.loyalty.ui.designsystem.rememberHaptics
import com.acefuel.loyalty.ui.designsystem.showError
import com.acefuel.loyalty.ui.designsystem.showSuccess
import com.acefuel.loyalty.ui.theme.NayaraButton
import com.acefuel.loyalty.ui.theme.NayaraMotion
import com.acefuel.loyalty.ui.theme.NayaraOutlinedButton
import com.acefuel.loyalty.ui.theme.NayaraSpacing
import com.acefuel.loyalty.ui.theme.nayara
import java.time.LocalDate
import java.time.LocalTime
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

private fun statusTone(status: String): ChipTone = when (status) {
    "present", "late" -> ChipTone.Success
    "absent" -> ChipTone.Error
    "half_day" -> ChipTone.Warning
    "leave" -> ChipTone.Info
    else -> ChipTone.Neutral
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AdminAttendanceScreen(onBack: () -> Unit) {
    val container = LocalContainer.current
    val repo = remember {
        AttendanceRepository(container.retrofit.create(AttendanceApi::class.java), container.json)
    }
    val vm: AttendanceViewModel = viewModel(factory = viewModelFactory { initializer { AttendanceViewModel(repo) } })
    val state by vm.state.collectAsStateWithLifecycle()
    val haptics = rememberHaptics()

    val snackbarHostState = remember { SnackbarHostState() }
    LaunchedEffect(state.actionMessage) {
        state.actionMessage?.let {
            haptics.confirm()
            snackbarHostState.showSuccess(it)
            vm.consumeActionMessage()
        }
    }
    LaunchedEffect(state.actionError) {
        state.actionError?.let {
            haptics.reject()
            snackbarHostState.showError(it)
            vm.consumeActionError()
        }
    }

    // Leaving the planner with unsaved entries requires an explicit discard.
    var confirmDiscard by remember { mutableStateOf(false) }
    val leaveCurrentMode: () -> Unit = {
        if (state.mode == AttendanceScreenMode.PLANNER && state.plannerDirty) {
            confirmDiscard = true
        } else {
            vm.backToList()
        }
    }
    BackHandler(enabled = state.mode != AttendanceScreenMode.LIST) { leaveCurrentMode() }

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
                    IconButton(onClick = { if (state.mode == AttendanceScreenMode.LIST) onBack() else leaveCurrentMode() }) {
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
        snackbarHost = { NayaraSnackbarHost(snackbarHostState) },
        bottomBar = {
            // Pinned save bar — always reachable while editing the roster.
            if (state.mode == AttendanceScreenMode.PLANNER && state.staffLoaded && state.draftEntries.isNotEmpty()) {
                Surface(shadowElevation = 8.dp) {
                    NayaraButton(
                        onClick = { vm.save() },
                        enabled = !state.saving,
                        loading = state.saving,
                        modifier = Modifier
                            .fillMaxWidth()
                            .navigationBarsPadding()
                            .padding(16.dp),
                    ) { Text("Save Attendance") }
                }
            }
        },
    ) { innerPadding ->
        Box(Modifier.fillMaxSize().padding(innerPadding)) {
            AnimatedContent(
                targetState = state.mode,
                transitionSpec = {
                    val forward = targetState.ordinal > initialState.ordinal
                    val enter = slideInHorizontally(
                        animationSpec = tween(NayaraMotion.Base, easing = NayaraMotion.Emphasized),
                        initialOffsetX = { if (forward) it / 4 else -it / 4 },
                    ) + fadeIn(tween(NayaraMotion.Base))
                    val exit = slideOutHorizontally(
                        animationSpec = tween(NayaraMotion.Base, easing = NayaraMotion.Emphasized),
                        targetOffsetX = { if (forward) -it / 4 else it / 4 },
                    ) + fadeOut(tween(NayaraMotion.Base))
                    enter togetherWith exit
                },
                label = "attendance-mode",
            ) { mode ->
                when (mode) {
                    AttendanceScreenMode.LIST -> ListContent(state, vm)
                    AttendanceScreenMode.DETAIL -> DetailContent(state, vm)
                    AttendanceScreenMode.PLANNER -> PlannerContent(state, vm)
                }
            }
        }
    }

    if (confirmDiscard) {
        ConfirmDialog(
            title = "Discard changes?",
            text = "Your attendance entries have not been saved. Leave the planner and discard them?",
            confirmLabel = "Discard",
            onConfirm = { confirmDiscard = false; vm.backToList() },
            onDismiss = { confirmDiscard = false },
            destructive = true,
        )
    }
}

// ============================================================================
// LIST
// ============================================================================

@Composable
private fun ListContent(state: AttendanceUiState, vm: AttendanceViewModel) {
    val haptics = rememberHaptics()

    NayaraPullToRefresh(
        isRefreshing = state.refreshing,
        onRefresh = vm::refresh,
        modifier = Modifier.fillMaxSize(),
    ) {
        LazyColumn(
            modifier = Modifier.fillMaxSize().padding(horizontal = NayaraSpacing.ScreenMargin),
            verticalArrangement = Arrangement.spacedBy(NayaraSpacing.Md),
            contentPadding = PaddingValues(top = NayaraSpacing.Md, bottom = NayaraSpacing.Xl),
        ) {
            item(key = "filters") {
                Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    Text("Record State", style = MaterialTheme.typography.labelMedium, color = MaterialTheme.nayara.textSecondary)
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        listOf("all" to "All", "valid" to "Valid", "invalid" to "Invalid").forEach { (value, label) ->
                            FilterChip(
                                selected = state.filter == value,
                                onClick = {
                                    haptics.tick()
                                    vm.setFilter(value)
                                },
                                label = { Text(label) },
                            )
                        }
                    }
                    Text("Attendance Date", style = MaterialTheme.typography.labelMedium, color = MaterialTheme.nayara.textSecondary)
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        DateField(
                            label = "From",
                            value = parseIsoDate(state.startDate),
                            onChange = { vm.setStartDate(it.toString()) },
                            modifier = Modifier.weight(1f),
                            placeholder = "Any",
                        )
                        DateField(
                            label = "To",
                            value = parseIsoDate(state.endDate),
                            onChange = { vm.setEndDate(it.toString()) },
                            modifier = Modifier.weight(1f),
                            placeholder = "Any",
                        )
                    }
                    if (state.startDate != null || state.endDate != null) {
                        TextButton(onClick = { vm.clearDates() }) { Text("Clear dates") }
                    }
                }
            }

            when {
                state.listLoading && state.runs.isEmpty() ->
                    item(key = "skeleton") { SkeletonList(count = 6, showAvatar = false) }
                state.listError != null && state.runs.isEmpty() ->
                    item(key = "error") {
                        ErrorState(state.listError ?: "Something went wrong.", onRetry = { vm.reloadList() })
                    }
                state.runs.isEmpty() && !state.listLoading -> {
                    val filtersActive = state.filter != "all" || state.startDate != null || state.endDate != null
                    item(key = "empty") {
                        EmptyState(
                            title = "No attendance found",
                            message = if (filtersActive) {
                                "Nothing matches the current filters. Try another filter or start a new attendance run."
                            } else {
                                "Start a new attendance run to see recorded shift windows here."
                            },
                            actionLabel = if (filtersActive) "Show all" else null,
                            onAction = if (filtersActive) ({ vm.resetFilters() }) else null,
                        )
                    }
                }
                else -> {
                    items(state.runs, key = { "run-${it.id}" }) { run ->
                        RunCard(run, onClick = { vm.openRun(run.id) }, modifier = Modifier.animateItem())
                    }
                    item(key = "pagination") { PaginationRow(state, vm) }
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun RunCard(run: AttendanceRunDto, onClick: () -> Unit, modifier: Modifier = Modifier) {
    NayaraCard(onClick = onClick, modifier = modifier.fillMaxWidth()) {
        Column(Modifier.padding(NayaraSpacing.Lg)) {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.Top) {
                Column(Modifier.weight(1f)) {
                    Text(run.shiftName ?: "Shift", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
                    Text(
                        "${fmtDateTime(run.startsAt)} to ${fmtDateTime(run.endsAt)}",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.nayara.textSecondary,
                    )
                }
                RecordStateChip(run.stale)
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
private fun RecordStateChip(stale: Boolean) {
    if (stale) {
        StatusChip(label = "Invalid", tone = ChipTone.Error)
    } else {
        StatusChip(label = "Valid", tone = ChipTone.Success)
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
        run == null && state.detailLoading -> DetailSkeleton()
        run == null && state.detailError != null ->
            ErrorState(
                state.detailError ?: "Attendance record not found.",
                modifier = Modifier.padding(16.dp),
                onRetry = { vm.retryDetail() },
            )
        run == null -> Box(Modifier.fillMaxSize()) {} // transient (exit animation after delete)
        else -> LazyColumn(
            modifier = Modifier.fillMaxSize().padding(horizontal = NayaraSpacing.ScreenMargin),
            verticalArrangement = Arrangement.spacedBy(NayaraSpacing.Md),
            contentPadding = PaddingValues(top = NayaraSpacing.Md, bottom = NayaraSpacing.Xl),
        ) {
            item(key = "d-summary") {
                NayaraCard(modifier = Modifier.fillMaxWidth()) {
                    Column(Modifier.padding(NayaraSpacing.Lg), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.Top) {
                            Text(run.shiftName ?: "Shift", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.SemiBold)
                            RecordStateChip(run.stale)
                        }
                        LabelValue("Window", "${fmtDateTime(run.startsAt)} to ${fmtTime(run.endsAt)}")
                        LabelValue("Recorded By", run.recordedBy?.displayName ?: "—")
                        run.notes?.takeIf { it.isNotBlank() }?.let { LabelValue("Run Notes", it) }
                    }
                }
            }

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
                items(run.entries, key = { "entry-${it.id ?: it.scheduledUser?.id ?: 0}" }) { entry ->
                    DetailEntryCard(entry, modifier = Modifier.animateItem())
                }
            }
        }
    }

    if (confirmInvalidate) {
        ConfirmDialog(
            title = "Invalidate attendance?",
            text = "Mark this attendance record invalid? It stays on record but is not counted as valid.",
            confirmLabel = "Invalidate",
            onConfirm = { confirmInvalidate = false; vm.invalidateSelected() },
            onDismiss = { confirmInvalidate = false },
        )
    }
    if (confirmDelete) {
        ConfirmDialog(
            title = "Delete record?",
            text = "Delete this invalid attendance record? This cannot be undone.",
            confirmLabel = "Delete",
            onConfirm = { confirmDelete = false; vm.deleteSelected() },
            onDismiss = { confirmDelete = false },
            destructive = true,
        )
    }
}

@Composable
private fun DetailSkeleton() {
    Column(
        modifier = Modifier.fillMaxSize().padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        SkeletonCard(lines = 3)
        SkeletonList(count = 4, showAvatar = false)
    }
}

@Composable
private fun DetailEntryCard(entry: AttendanceEntryDto, modifier: Modifier = Modifier) {
    NayaraCard(modifier = modifier.fillMaxWidth()) {
        Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                Text(
                    entry.scheduledUser?.displayName ?: entry.workerName ?: "Staff",
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.SemiBold,
                )
                StatusChip(label = statusLabel(entry.status), tone = statusTone(entry.status))
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

@Composable
private fun PlannerContent(state: AttendanceUiState, vm: AttendanceViewModel) {
    var confirmMarkAll by remember { mutableStateOf(false) }

    LazyColumn(
        modifier = Modifier.fillMaxSize().padding(horizontal = NayaraSpacing.ScreenMargin),
        verticalArrangement = Arrangement.spacedBy(NayaraSpacing.Md),
        contentPadding = PaddingValues(top = NayaraSpacing.Md, bottom = NayaraSpacing.Xl),
    ) {
        item(key = "p-intro") {
            Text(
                "Select a shift window, load the assigned staff, and record the shift attendance in one place.",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.nayara.textSecondary,
            )
        }

        item(key = "p-form") {
            when {
                state.templatesLoading -> SkeletonCard(lines = 3)
                state.templatesError != null ->
                    InlineErrorCard(state.templatesError ?: "Something went wrong.", onRetry = { vm.loadShiftTemplates() })
                else -> NayaraCard(modifier = Modifier.fillMaxWidth()) {
                    Column(Modifier.padding(NayaraSpacing.Lg), verticalArrangement = Arrangement.spacedBy(NayaraSpacing.Md)) {
                        LabeledDropdown(
                            label = "Shift",
                            selectedLabel = state.selectedShift?.let { shiftOptionLabel(it) } ?: "Select a shift",
                            options = state.shiftTemplates.map { it.id to shiftOptionLabel(it) },
                            onSelect = { vm.selectShift(it) },
                        )
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            DateField(
                                label = "Start Date",
                                value = state.plannerDate,
                                onChange = { vm.setPlannerDate(it) },
                                modifier = Modifier.weight(1f),
                                placeholder = "Select date",
                            )
                            TimeField(
                                label = "Start Time",
                                value = LocalTime.of(state.startHour, state.startMinute),
                                onChange = { vm.setStartTime(it.hour, it.minute) },
                                modifier = Modifier.weight(1f),
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

        state.plannerError?.let {
            item(key = "p-error") { InlineErrorCard(it, onRetry = { vm.loadStaff() }) }
        }

        if (state.plannerBaseErrors.isNotEmpty()) {
            item(key = "p-base-errors") { InlineErrorCard(state.plannerBaseErrors.joinToString(" ")) }
        }

        when {
            state.staffLoaded && state.draftEntries.isNotEmpty() -> {
                item(key = "p-window") {
                    NayaraCard(modifier = Modifier.fillMaxWidth()) {
                        Column(Modifier.padding(NayaraSpacing.Lg), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                            Text(state.plannerShiftName ?: "Shift", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
                            LabelValue("Window", "${fmtDateTime(state.windowStart)} to ${fmtTime(state.windowEnd)}")
                            LabelValue("Loaded Staff", "${state.draftEntries.size}")
                        }
                    }
                }
                item(key = "p-entries-header") {
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                        SectionHeader("Attendance Entries")
                        NayaraOutlinedButton(onClick = { confirmMarkAll = true }, enabled = !state.saving) { Text("Mark All Present") }
                    }
                }
                itemsIndexedDraft(state.draftEntries) { index, entry ->
                    DraftEntryCard(
                        entry = entry,
                        modifier = Modifier.animateItem(),
                        onStatus = { vm.updateEntryStatus(index, it) },
                        onNotes = { vm.updateEntryNotes(index, it) },
                        onExternal = { vm.updateEntryExternalReplacement(index, it) },
                        onCheckIn = { vm.setEntryCheckTime(index, true, it.hour, it.minute) },
                        onCheckOut = { vm.setEntryCheckTime(index, false, it.hour, it.minute) },
                        onClearCheckIn = { vm.clearEntryCheckTime(index, true) },
                        onClearCheckOut = { vm.clearEntryCheckTime(index, false) },
                    )
                }
                item(key = "p-run-notes") {
                    NayaraCard(modifier = Modifier.fillMaxWidth()) {
                        Column(Modifier.padding(NayaraSpacing.Lg), verticalArrangement = Arrangement.spacedBy(NayaraSpacing.Md)) {
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
                state.saveError?.let { item(key = "p-save-error") { InlineErrorCard(it) } }
            }
            state.selectedShiftId != null && state.plannerBaseErrors.isEmpty() && state.windowStart != null && state.draftEntries.isEmpty() && !state.plannerLoading ->
                item(key = "p-no-staff") {
                    EmptyState(
                        title = "No staff assigned yet",
                        message = "This shift does not have any active staff assignments for the selected date. Assign staff first, then come back to attendance.",
                    )
                }
            state.selectedShiftId == null && !state.templatesLoading ->
                item(key = "p-start") {
                    EmptyState(
                        title = "Start by selecting a shift",
                        message = "Choose the shift and start time above, and the staff roster for that window will load here.",
                    )
                }
        }
    }

    if (confirmMarkAll) {
        ConfirmDialog(
            title = "Mark all present?",
            text = "Set every staff row's status to Present? Statuses you've already changed will be overwritten.",
            confirmLabel = "Mark All",
            onConfirm = { confirmMarkAll = false; vm.markAllPresent() },
            onDismiss = { confirmMarkAll = false },
        )
    }
}

@Composable
private fun DraftEntryCard(
    entry: DraftEntry,
    modifier: Modifier = Modifier,
    onStatus: (String) -> Unit,
    onNotes: (String) -> Unit,
    onExternal: (String) -> Unit,
    onCheckIn: (LocalTime) -> Unit,
    onCheckOut: (LocalTime) -> Unit,
    onClearCheckIn: () -> Unit,
    onClearCheckOut: () -> Unit,
) {
    NayaraCard(modifier = modifier.fillMaxWidth()) {
        Column(Modifier.padding(NayaraSpacing.Lg), verticalArrangement = Arrangement.spacedBy(NayaraSpacing.Md)) {
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
                CheckTimeField("Check In", entry.checkInAt, Modifier.weight(1f), onCheckIn, onClearCheckIn)
                CheckTimeField("Check Out", entry.checkOutAt, Modifier.weight(1f), onCheckOut, onClearCheckOut)
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
    onChange: (LocalTime) -> Unit,
    onClear: () -> Unit,
) {
    Column(modifier, verticalArrangement = Arrangement.spacedBy(2.dp)) {
        TimeField(
            label = label,
            value = parseDateTime(iso)?.toLocalTime(),
            onChange = onChange,
            placeholder = "Not recorded",
        )
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
 * ExposedDropdown APIs). The field is a designsystem [PickerField]; the menu
 * anchors to the wrapping [Box].
 */
@Composable
private fun <T> LabeledDropdown(
    label: String,
    selectedLabel: String,
    options: List<Pair<T, String>>,
    modifier: Modifier = Modifier,
    onSelect: (T) -> Unit,
) {
    val haptics = rememberHaptics()
    var expanded by remember { mutableStateOf(false) }
    Box(modifier) {
        PickerField(
            label = label,
            value = selectedLabel,
            onClick = { expanded = true },
            modifier = Modifier.fillMaxWidth(),
        )
        DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
            options.forEach { (value, text) ->
                DropdownMenuItem(
                    text = { Text(text) },
                    onClick = {
                        haptics.tick()
                        onSelect(value)
                        expanded = false
                    },
                )
            }
        }
    }
}

@Composable
private fun SectionHeader(text: String) {
    Text(
        text,
        style = MaterialTheme.typography.titleSmall,
        fontWeight = FontWeight.SemiBold,
        color = MaterialTheme.nayara.textSecondary,
        modifier = Modifier.padding(top = 4.dp),
    )
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

/** Container/content colors for the detail screen's status-count tiles. */
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
private fun LazyListScope.itemsIndexedDraft(
    entries: List<DraftEntry>,
    content: @Composable LazyItemScope.(Int, DraftEntry) -> Unit,
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

private fun parseDateTime(iso: String?): java.time.LocalDateTime? = iso?.let { raw ->
    runCatching { java.time.OffsetDateTime.parse(raw).toLocalDateTime() }
        .recoverCatching { java.time.LocalDateTime.parse(raw) }
        .getOrNull()
}

private fun fmtDateTime(iso: String?): String = parseDateTime(iso)?.format(DATE_TIME_FMT) ?: (iso ?: "—")

private fun fmtTime(iso: String?): String = parseDateTime(iso)?.toLocalTime()?.format(TIME_FMT) ?: "Not recorded"

private fun parseIsoDate(iso: String?): LocalDate? = iso?.let {
    runCatching { LocalDate.parse(it) }.getOrNull()
}
