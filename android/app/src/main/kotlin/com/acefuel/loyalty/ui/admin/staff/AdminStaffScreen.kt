package com.acefuel.loyalty.ui.admin.staff

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.ArrowDropDown
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
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

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AdminStaffScreen(onBack: () -> Unit) {
    val container = LocalContainer.current
    val repo = remember {
        AdminStaffRepository(container.retrofit.create(AdminStaffApi::class.java), container.json)
    }
    val vm: AdminStaffViewModel = viewModel(factory = viewModelFactory { initializer { AdminStaffViewModel(repo) } })
    val state by vm.state.collectAsStateWithLifecycle()

    var pendingDelete by remember { mutableStateOf<StaffMemberDto?>(null) }
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Staff") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                },
            )
        },
    ) { innerPadding ->
        when {
            state.loading && state.staff.isEmpty() && state.error == null ->
                Box(
                    modifier = Modifier.fillMaxSize().padding(innerPadding),
                    contentAlignment = Alignment.Center,
                ) { CircularProgressIndicator() }

            else -> LazyColumn(
                modifier = Modifier.fillMaxSize().padding(innerPadding),
                contentPadding = PaddingValues(16.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                item(key = "stats") { StatsRow(state.stats) }

                state.notice?.let { msg ->
                    item(key = "notice") { NoticeCard(msg, onDismiss = { vm.dismissNotice() }) }
                }
                state.actionError?.let { msg ->
                    item(key = "action-error") { ErrorCard(msg, onDismiss = { vm.dismissActionError() }) }
                }

                item(key = "list-header") {
                    Text(
                        "Staff Members",
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.SemiBold,
                    )
                }

                when {
                    state.error != null && state.staff.isEmpty() ->
                        item(key = "load-error") { ErrorCard(state.error!!, onDismiss = null) }

                    state.staff.isEmpty() ->
                        item(key = "empty") {
                            Text(
                                "No staff accounts available yet.",
                                style = MaterialTheme.typography.bodyMedium,
                                color = MaterialTheme.nayara.textSecondary,
                            )
                        }

                    else -> items(state.staff, key = { "staff-${it.id}" }) { staff ->
                        StaffCard(
                            staff = staff,
                            deleting = state.deletingStaffId == staff.id,
                            onEdit = { vm.openEditProfile(staff) },
                            onAssign = { vm.openAssignShift(staff) },
                            onDelete = { pendingDelete = staff },
                        )
                    }
                }
            }
        }
    }

    pendingDelete?.let { staff ->
        AlertDialog(
            onDismissRequest = { pendingDelete = null },
            title = { Text("Remove ${staff.name ?: "this staff member"}?") },
            text = {
                Text(
                    "Soft-deleting keeps their historical records but removes them from the staff list. " +
                        "Deactivate the account first if they can still sign in.",
                )
            },
            confirmButton = {
                TextButton(onClick = {
                    vm.softDelete(staff.id)
                    pendingDelete = null
                }) { Text("Remove", color = MaterialTheme.colorScheme.error) }
            },
            dismissButton = {
                TextButton(onClick = { pendingDelete = null }) { Text("Cancel") }
            },
        )
    }

    val editor = state.profileEditor
    if (editor != null) {
        ModalBottomSheet(onDismissRequest = { vm.closeEditProfile() }, sheetState = sheetState) {
            ProfileEditorSheet(editor = editor, vm = vm)
        }
    }

    val assigner = state.shiftAssigner
    if (assigner != null) {
        ModalBottomSheet(onDismissRequest = { vm.closeAssignShift() }, sheetState = sheetState) {
            ShiftAssignerSheet(assigner = assigner, templates = state.shiftTemplates, vm = vm)
        }
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
    Card(modifier = modifier) {
        Column(
            modifier = Modifier.fillMaxWidth().padding(vertical = 14.dp, horizontal = 8.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Text("$value", style = MaterialTheme.typography.headlineMedium, color = valueColor)
            Text(
                label,
                style = MaterialTheme.typography.labelMedium,
                color = MaterialTheme.nayara.textSecondary,
            )
        }
    }
}

// ---------------------------------------------------------------------------
// Staff card
// ---------------------------------------------------------------------------

@Composable
private fun StaffCard(
    staff: StaffMemberDto,
    deleting: Boolean,
    onEdit: () -> Unit,
    onAssign: () -> Unit,
    onDelete: () -> Unit,
) {
    Card(Modifier.fillMaxWidth()) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                Avatar(staff.avatarInitial ?: staff.name?.firstOrNull()?.uppercase() ?: "?")
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
                StatusPill(staff.active)
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
                TextButton(onClick = onEdit) { Text("Edit profile") }
                TextButton(onClick = onAssign) { Text("Assign Shift") }
                Spacer(Modifier.weight(1f))
                TextButton(onClick = onDelete, enabled = !deleting) {
                    Text(
                        if (deleting) "Removing…" else "Delete",
                        color = if (deleting) MaterialTheme.nayara.textTertiary else MaterialTheme.colorScheme.error,
                    )
                }
            }
        }
    }
}

@Composable
private fun Avatar(initial: String) {
    Box(
        modifier = Modifier
            .size(42.dp)
            .clip(CircleShape)
            .background(MaterialTheme.nayara.actionPrimaryContainer),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            initial,
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.Bold,
            color = MaterialTheme.nayara.actionOnPrimaryContainer,
        )
    }
}

@Composable
private fun StatusPill(active: Boolean) {
    val container = if (active) MaterialTheme.nayara.statusSuccessContainer else MaterialTheme.nayara.bgSurfaceSunken
    val content = if (active) MaterialTheme.nayara.statusOnSuccessContainer else MaterialTheme.nayara.textSecondary
    Surface(color = container, shape = MaterialTheme.shapes.small) {
        Text(
            if (active) "Active" else "Inactive",
            modifier = Modifier.padding(horizontal = 10.dp, vertical = 4.dp),
            style = MaterialTheme.typography.labelMedium,
            color = content,
        )
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
private fun ProfileEditorSheet(editor: StaffProfileEditorState, vm: AdminStaffViewModel) {
    val scroll = rememberScrollState()
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .verticalScroll(scroll)
            .padding(horizontal = 20.dp)
            .padding(bottom = 28.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Text("Edit ${editor.staffLabel}", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)

        OutlinedTextField(
            value = editor.name,
            onValueChange = vm::editorSetName,
            label = { Text("Name") },
            singleLine = true,
            isError = editor.name.isBlank(),
            modifier = Modifier.fillMaxWidth(),
        )
        OutlinedTextField(
            value = editor.employeeCode,
            onValueChange = vm::editorSetEmployeeCode,
            label = { Text("Employee Code (Optional)") },
            singleLine = true,
            modifier = Modifier.fillMaxWidth(),
        )
        OutlinedTextField(
            value = editor.subtitle,
            onValueChange = vm::editorSetSubtitle,
            label = { Text("Subtitle (Optional)") },
            supportingText = { Text("${editor.subtitle.length}/120") },
            modifier = Modifier.fillMaxWidth(),
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
            Switch(checked = editor.active, onCheckedChange = { vm.editorSetActive(it) })
        }

        editor.error?.let {
            Text(it, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.error)
        }

        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            NayaraOutlinedButton(
                onClick = { vm.closeEditProfile() },
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
) {
    val scroll = rememberScrollState()
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .verticalScroll(scroll)
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
            Text("No shifts yet", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
            Text(
                "Create a shift template under Shifts first, then assign it here.",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.nayara.textSecondary,
            )
            NayaraOutlinedButton(
                onClick = { vm.closeAssignShift() },
                modifier = Modifier.fillMaxWidth(),
            ) { Text("Close") }
        } else {
            Text("Shift", style = MaterialTheme.typography.labelMedium, color = MaterialTheme.nayara.textSecondary)
            ShiftDropdown(
                templates = templates,
                selectedId = assigner.selectedTemplateId,
                onSelect = { vm.assignerSelectTemplate(it) },
            )
            OutlinedTextField(
                value = assigner.notes,
                onValueChange = vm::assignerSetNotes,
                label = { Text("Assignment Notes (Optional)") },
                modifier = Modifier.fillMaxWidth(),
            )

            assigner.error?.let {
                Text(it, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.error)
            }

            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                NayaraOutlinedButton(
                    onClick = { vm.closeAssignShift() },
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
    var expanded by remember { mutableStateOf(false) }
    val selected = templates.firstOrNull { it.id == selectedId }
    val label = selected?.let { templateLabel(it) } ?: "Choose the shift this staff member should load under"
    Box(Modifier.fillMaxWidth()) {
        OutlinedButton(onClick = { expanded = true }, modifier = Modifier.fillMaxWidth()) {
            Text(
                label,
                modifier = Modifier.weight(1f),
                textAlign = TextAlign.Start,
                color = if (selected == null) MaterialTheme.nayara.textTertiary else MaterialTheme.nayara.textPrimary,
            )
            Icon(Icons.Filled.ArrowDropDown, contentDescription = null)
        }
        DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
            templates.forEach { template ->
                DropdownMenuItem(
                    text = { Text(templateLabel(template)) },
                    onClick = {
                        onSelect(template.id)
                        expanded = false
                    },
                )
            }
        }
    }
}

// ---------------------------------------------------------------------------
// Notice / error cards
// ---------------------------------------------------------------------------

@Composable
private fun NoticeCard(message: String, onDismiss: () -> Unit) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.nayara.statusSuccessContainer),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth().padding(start = 14.dp, top = 4.dp, bottom = 4.dp, end = 4.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                message,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.nayara.statusOnSuccessContainer,
                modifier = Modifier.weight(1f).padding(vertical = 8.dp),
            )
            TextButton(onClick = onDismiss) {
                Text("Dismiss", color = MaterialTheme.nayara.statusOnSuccessContainer)
            }
        }
    }
}

@Composable
private fun ErrorCard(message: String, onDismiss: (() -> Unit)?) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.errorContainer),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth().padding(start = 14.dp, top = 4.dp, bottom = 4.dp, end = 4.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                message,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onErrorContainer,
                modifier = Modifier.weight(1f).padding(vertical = 8.dp),
            )
            if (onDismiss != null) {
                TextButton(onClick = onDismiss) {
                    Text("Dismiss", color = MaterialTheme.colorScheme.onErrorContainer)
                }
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
