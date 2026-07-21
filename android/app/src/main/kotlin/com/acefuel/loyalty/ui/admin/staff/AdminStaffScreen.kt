package com.acefuel.loyalty.ui.admin.staff

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SheetValue
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Surface
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
import com.acefuel.loyalty.ui.designsystem.ActiveChip
import com.acefuel.loyalty.ui.designsystem.Avatar
import com.acefuel.loyalty.ui.designsystem.ConfirmDialog
import com.acefuel.loyalty.ui.designsystem.EmptyState
import com.acefuel.loyalty.ui.designsystem.ErrorState
import com.acefuel.loyalty.ui.designsystem.FormField
import com.acefuel.loyalty.ui.designsystem.InlineErrorCard
import com.acefuel.loyalty.ui.designsystem.NayaraCard
import com.acefuel.loyalty.ui.designsystem.NayaraPullToRefresh
import com.acefuel.loyalty.ui.designsystem.NayaraSnackbarHost
import com.acefuel.loyalty.ui.designsystem.NayaraTopBar
import com.acefuel.loyalty.ui.designsystem.PickerField
import com.acefuel.loyalty.ui.designsystem.SkeletonList
import com.acefuel.loyalty.ui.designsystem.SkeletonStatCard
import com.acefuel.loyalty.ui.designsystem.rememberHaptics
import com.acefuel.loyalty.ui.designsystem.showError
import com.acefuel.loyalty.ui.designsystem.showSuccess
import com.acefuel.loyalty.ui.theme.NayaraButton
import com.acefuel.loyalty.ui.theme.NayaraNumerals
import com.acefuel.loyalty.ui.theme.NayaraOutlinedButton
import com.acefuel.loyalty.ui.theme.NayaraSpacing
import com.acefuel.loyalty.ui.theme.nayara

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AdminStaffScreen(onBack: () -> Unit, onAssignPump: (Long) -> Unit) {
    val container = LocalContainer.current
    val repo = remember {
        AdminStaffRepository(container.retrofit.create(AdminStaffApi::class.java), container.json)
    }
    val vm: AdminStaffViewModel = viewModel(factory = viewModelFactory { initializer { AdminStaffViewModel(repo) } })
    val state by vm.state.collectAsStateWithLifecycle()

    val snackbar = remember { SnackbarHostState() }
    val haptics = rememberHaptics()
    var pendingDelete by remember { mutableStateOf<StaffMemberDto?>(null) }

    LaunchedEffect(state.notice) {
        state.notice?.let {
            haptics.confirm()
            snackbar.showSuccess(it)
            vm.dismissNotice()
        }
    }
    LaunchedEffect(state.actionError) {
        state.actionError?.let {
            haptics.reject()
            snackbar.showError(it)
            vm.dismissActionError()
        }
    }

    Scaffold(
        topBar = { NayaraTopBar(title = "Staff", onBack = onBack) },
        snackbarHost = { NayaraSnackbarHost(snackbar) },
    ) { innerPadding ->
        when {
            state.loading && state.staff.isEmpty() && state.error == null ->
                StaffSkeleton(Modifier.fillMaxSize().padding(innerPadding))

            state.error != null && state.staff.isEmpty() ->
                Box(
                    modifier = Modifier.fillMaxSize().padding(innerPadding),
                    contentAlignment = Alignment.Center,
                ) { ErrorState(message = state.error!!, onRetry = vm::load) }

            else -> NayaraPullToRefresh(
                isRefreshing = state.refreshing,
                onRefresh = vm::refresh,
                modifier = Modifier.fillMaxSize().padding(innerPadding),
            ) {
                LazyColumn(
                    modifier = Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(
                        start = NayaraSpacing.ScreenMargin,
                        end = NayaraSpacing.ScreenMargin,
                        top = NayaraSpacing.ScreenMargin,
                        bottom = NayaraSpacing.Xxl,
                    ),
                    verticalArrangement = Arrangement.spacedBy(NayaraSpacing.Md),
                ) {
                    item(key = "stats") { StatsRow(state.stats) }

                    item(key = "list-header") {
                        Text(
                            "Staff Members",
                            style = MaterialTheme.typography.titleSmall,
                            color = MaterialTheme.nayara.textSecondary,
                        )
                    }

                    if (state.staff.isEmpty()) {
                        item(key = "empty") {
                            EmptyState(
                                title = "No staff yet",
                                message = "Staff accounts appear here once they're created under Users.",
                            )
                        }
                    } else {
                        items(state.staff, key = { "staff-${it.id}" }) { staff ->
                            StaffCard(
                                staff = staff,
                                busy = state.deletingStaffId == staff.id,
                                onEdit = { vm.openEditProfile(staff) },
                                onAssign = { vm.openAssignShift(staff) },
                                onAssignPump = { onAssignPump(staff.id) },
                                onDelete = { pendingDelete = staff },
                                modifier = Modifier.animateItem(),
                            )
                        }
                    }
                }
            }
        }
    }

    pendingDelete?.let { staff ->
        ConfirmDialog(
            title = "Remove ${staff.name ?: "this staff member"}?",
            text = "Soft-deleting keeps their historical records but removes them from the staff list. " +
                "Deactivate the account first if they can still sign in.",
            confirmLabel = "Remove",
            destructive = true,
            onConfirm = {
                vm.softDelete(staff.id)
                pendingDelete = null
            },
            onDismiss = { pendingDelete = null },
        )
    }

    val editor = state.profileEditor
    if (editor != null) {
        // Snapshot the just-opened editor so we can tell "dirty" from "untouched".
        val initial = remember(editor.staffId) { editor }
        val dirty = editor.name != initial.name ||
            editor.employeeCode != initial.employeeCode ||
            editor.subtitle != initial.subtitle ||
            editor.active != initial.active
        GuardedSheet(dirty = dirty, onClose = vm::closeEditProfile) { requestClose ->
            ProfileEditorSheet(editor = editor, vm = vm, onCancel = requestClose)
        }
    }

    val assigner = state.shiftAssigner
    if (assigner != null) {
        val initial = remember(assigner.staffId) { assigner }
        val dirty = assigner.selectedTemplateId != initial.selectedTemplateId ||
            assigner.notes != initial.notes
        GuardedSheet(dirty = dirty, onClose = vm::closeAssignShift) { requestClose ->
            ShiftAssignerSheet(
                assigner = assigner,
                templates = state.shiftTemplates,
                vm = vm,
                onCancel = requestClose,
            )
        }
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
// Stat cards
// ---------------------------------------------------------------------------

@Composable
private fun StatsRow(stats: StaffStatsDto) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        StatCard(Modifier.weight(1f), stats.active, "Active", MaterialTheme.nayara.statusSuccessText)
        StatCard(Modifier.weight(1f), stats.inactive, "Inactive", MaterialTheme.nayara.statusErrorText)
        StatCard(Modifier.weight(1f), stats.unassigned, "Unassigned", MaterialTheme.nayara.statusWarningText)
    }
}

@Composable
private fun StatCard(modifier: Modifier, value: Int, label: String, valueColor: androidx.compose.ui.graphics.Color) {
    NayaraCard(modifier = modifier) {
        Column(
            modifier = Modifier.fillMaxWidth().padding(vertical = 14.dp, horizontal = 8.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Text("$value", style = NayaraNumerals.Large, color = valueColor)
            Text(
                label,
                style = MaterialTheme.typography.labelMedium,
                color = MaterialTheme.nayara.textSecondary,
            )
        }
    }
}

@Composable
private fun StaffSkeleton(modifier: Modifier = Modifier) {
    Column(modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            SkeletonStatCard(Modifier.weight(1f))
            SkeletonStatCard(Modifier.weight(1f))
            SkeletonStatCard(Modifier.weight(1f))
        }
        SkeletonList(count = 6)
    }
}

// ---------------------------------------------------------------------------
// Staff card
// ---------------------------------------------------------------------------

@Composable
private fun StaffCard(
    staff: StaffMemberDto,
    busy: Boolean,
    onEdit: () -> Unit,
    onAssign: () -> Unit,
    onAssignPump: () -> Unit,
    onDelete: () -> Unit,
    modifier: Modifier = Modifier,
) {
    NayaraCard(modifier = modifier.fillMaxWidth()) {
        Column(Modifier.padding(NayaraSpacing.Lg), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                Avatar(name = staff.name, size = 42.dp)
                Column(Modifier.weight(1f)) {
                    Text(
                        staff.name ?: "Staff member",
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.SemiBold,
                    )
                    val subtitle = staff.subtitle?.takeIf { it.isNotBlank() }
                    if (subtitle != null) {
                        Text(subtitle, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.nayara.textSecondary)
                    }
                }
                ActiveChip(staff.active)
            }

            AssignedShiftBlock(staff)

            Text(
                "Mobile: ${staff.displayPhoneNumber?.takeIf { it.isNotBlank() } ?: "Mobile not set"}",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.nayara.textSecondary,
            )
            Text(
                "Employee Code: ${staff.employeeCode?.takeIf { it.isNotBlank() } ?: "Not set"}",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.nayara.textSecondary,
            )

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                TextButton(onClick = onEdit, enabled = !busy) { Text("Edit profile") }
                TextButton(onClick = onAssign, enabled = !busy) { Text("Assign Shift") }
                TextButton(onClick = onAssignPump, enabled = !busy) { Text("Pump") }
                Spacer(Modifier.weight(1f))
                TextButton(onClick = onDelete, enabled = !busy) {
                    Text(
                        if (busy) "Removing…" else "Delete",
                        color = if (busy) MaterialTheme.nayara.textTertiary else MaterialTheme.colorScheme.error,
                    )
                }
            }
        }
    }
}

@Composable
private fun AssignedShiftBlock(staff: StaffMemberDto) {
    val template = staff.currentShiftTemplate
    val schedule = template?.let { scheduleText(it) }
    val cycle = staff.currentShiftCycle?.name?.takeIf { it.isNotBlank() }
    val meta = listOfNotNull(schedule, cycle).joinToString(" · ").takeIf { it.isNotBlank() }
    Surface(
        color = MaterialTheme.nayara.bgSurfaceSunken,
        shape = MaterialTheme.shapes.medium,
        modifier = Modifier.fillMaxWidth(),
    ) {
        Column(Modifier.padding(12.dp), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(
                "Assigned Shift",
                style = MaterialTheme.typography.labelMedium,
                color = MaterialTheme.nayara.textTertiary,
            )
            Text(
                template?.name?.takeIf { it.isNotBlank() } ?: "Unassigned",
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.SemiBold,
                color = if (template == null) MaterialTheme.nayara.textSecondary else MaterialTheme.nayara.textPrimary,
            )
            if (meta != null) {
                Text(meta, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.nayara.textSecondary)
            }
        }
    }
}

// ---------------------------------------------------------------------------
// Edit profile sheet
// ---------------------------------------------------------------------------

@Composable
private fun ProfileEditorSheet(
    editor: StaffProfileEditorState,
    vm: AdminStaffViewModel,
    onCancel: () -> Unit,
) {
    val haptics = rememberHaptics()
    val scroll = rememberScrollState()
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .verticalScroll(scroll)
            .imePadding()
            .navigationBarsPadding()
            .padding(horizontal = 20.dp)
            .padding(bottom = 28.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Text("Edit ${editor.staffLabel}", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)

        FormField(
            value = editor.name,
            onValueChange = vm::editorSetName,
            label = "Name",
            errors = editor.nameError?.let(::listOf),
        )
        FormField(
            value = editor.employeeCode,
            onValueChange = vm::editorSetEmployeeCode,
            label = "Employee Code (Optional)",
        )
        FormField(
            value = editor.subtitle,
            onValueChange = vm::editorSetSubtitle,
            label = "Subtitle (Optional)",
            helper = "${editor.subtitle.length}/120",
        )

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(Modifier.weight(1f)) {
                Text("Access Status", style = MaterialTheme.typography.bodyLarge)
                Text(
                    "Inactive users stay in history but cannot sign in until reactivated.",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.nayara.textSecondary,
                )
            }
            Switch(
                checked = editor.active,
                onCheckedChange = {
                    haptics.tick()
                    vm.editorSetActive(it)
                },
            )
        }

        editor.error?.let { InlineErrorCard(it) }

        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            NayaraOutlinedButton(
                onClick = onCancel,
                enabled = !editor.saving,
                modifier = Modifier.weight(1f),
            ) { Text("Cancel") }
            NayaraButton(
                onClick = { vm.saveProfile() },
                loading = editor.saving,
                enabled = !editor.saving,
                modifier = Modifier.weight(1f),
            ) { Text("Save Profile") }
        }
    }
}

// ---------------------------------------------------------------------------
// Assign shift sheet
// ---------------------------------------------------------------------------

@Composable
private fun ShiftAssignerSheet(
    assigner: ShiftAssignerState,
    templates: List<ShiftTemplateDto>,
    vm: AdminStaffViewModel,
    onCancel: () -> Unit,
) {
    val scroll = rememberScrollState()
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .verticalScroll(scroll)
            .imePadding()
            .navigationBarsPadding()
            .padding(horizontal = 20.dp)
            .padding(bottom = 28.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Text("Assign Shift", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
        Text(
            "Assign a shift to ${assigner.staffLabel}.",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.nayara.textSecondary,
        )

        if (templates.isEmpty()) {
            EmptyState(
                title = "No shifts yet",
                message = "Create a shift template under Shifts first, then assign it here.",
            )
            NayaraOutlinedButton(
                onClick = onCancel,
                modifier = Modifier.fillMaxWidth(),
            ) { Text("Close") }
        } else {
            ShiftDropdown(
                templates = templates,
                selectedId = assigner.selectedTemplateId,
                onSelect = { vm.assignerSelectTemplate(it) },
            )
            FormField(
                value = assigner.notes,
                onValueChange = vm::assignerSetNotes,
                label = "Assignment Notes (Optional)",
            )

            assigner.error?.let { InlineErrorCard(it) }

            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                NayaraOutlinedButton(
                    onClick = onCancel,
                    enabled = !assigner.saving,
                    modifier = Modifier.weight(1f),
                ) { Text("Cancel") }
                NayaraButton(
                    onClick = { vm.saveAssignment() },
                    loading = assigner.saving,
                    enabled = !assigner.saving && assigner.selectedTemplateId != null,
                    modifier = Modifier.weight(1f),
                ) { Text("Assign Shift") }
            }
        }
    }
}

@Composable
private fun ShiftDropdown(
    templates: List<ShiftTemplateDto>,
    selectedId: Long?,
    onSelect: (Long) -> Unit,
) {
    val haptics = rememberHaptics()
    var expanded by remember { mutableStateOf(false) }
    var fieldWidthPx by remember { mutableStateOf(0) }
    val fieldWidth = with(LocalDensity.current) { fieldWidthPx.toDp() }
    val selected = templates.firstOrNull { it.id == selectedId }
    Box(
        Modifier
            .fillMaxWidth()
            .onGloballyPositioned { fieldWidthPx = it.size.width },
    ) {
        PickerField(
            label = "Shift",
            value = selected?.let { templateLabel(it) } ?: "Choose a shift",
            onClick = { expanded = true },
        )
        // Anchor the menu to the field's full width so long labels don't clip.
        DropdownMenu(
            expanded = expanded,
            onDismissRequest = { expanded = false },
            modifier = Modifier.width(fieldWidth),
        ) {
            templates.forEach { template ->
                DropdownMenuItem(
                    text = { Text(templateLabel(template)) },
                    onClick = {
                        haptics.tick()
                        onSelect(template.id)
                        expanded = false
                    },
                )
            }
        }
    }
}

// ---------------------------------------------------------------------------
// Label helpers
// ---------------------------------------------------------------------------

/** Dropdown label: "{name} · {start} · {duration}" (cycle omitted — not on the template). */
private fun templateLabel(t: ShiftTemplateDto): String {
    val meta = scheduleText(t)
    return listOfNotNull(t.name.takeIf { it.isNotBlank() }, meta).joinToString(" · ").ifBlank { "Shift #${t.id}" }
}

/** "{start} · {duration}" using the serializer's labels, falling back to schedule_label. */
private fun scheduleText(t: ShiftTemplateDto): String? {
    t.scheduleLabel?.takeIf { it.isNotBlank() }?.let { return it }
    return listOfNotNull(
        t.startTimeLabel?.takeIf { it.isNotBlank() },
        t.durationLabel?.takeIf { it.isNotBlank() },
    ).joinToString(" · ").takeIf { it.isNotBlank() }
}
