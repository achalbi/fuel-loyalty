package com.acefuel.loyalty.ui.admin.cycles

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.DateRange
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDialog
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ExposedDropdownMenuBox
import androidx.compose.material3.ExposedDropdownMenuDefaults
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.MenuAnchorType
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.rememberDatePickerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import com.acefuel.loyalty.core.di.LocalContainer
import com.acefuel.loyalty.ui.theme.NayaraButton
import com.acefuel.loyalty.ui.theme.NayaraOutlinedButton
import com.acefuel.loyalty.ui.theme.NayaraTonalButton
import com.acefuel.loyalty.ui.theme.nayara
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneOffset
import java.time.format.DateTimeFormatter

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AdminCyclesScreen(onBack: () -> Unit) {
    val container = LocalContainer.current
    val repo = remember {
        CyclesRepository(container.retrofit.create(CyclesApi::class.java), container.json)
    }
    val vm: CyclesViewModel = viewModel(factory = viewModelFactory { initializer { CyclesViewModel(repo) } })
    val state by vm.state.collectAsStateWithLifecycle()

    val editor = state.editor
    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        when {
                            editor == null -> "Shift Cycles"
                            editor.isCreate -> "New Cycle"
                            else -> "Edit Cycle"
                        },
                    )
                },
                navigationIcon = {
                    IconButton(onClick = { if (editor != null) vm.closeEditor() else onBack() }) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                },
            )
        },
        floatingActionButton = {
            if (editor == null && !(state.loading && state.cycles.isEmpty())) {
                FloatingActionButton(onClick = { vm.openCreate() }) {
                    Icon(Icons.Filled.Add, contentDescription = "New shift cycle")
                }
            }
        },
    ) { padding ->
        Box(Modifier.fillMaxSize().padding(padding)) {
            when {
                editor != null -> CycleEditor(editor, state.activeTemplates, state.templates, vm)
                state.loading && state.cycles.isEmpty() ->
                    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        CircularProgressIndicator()
                    }
                else -> CycleList(state, vm)
            }
        }
    }
}

@Composable
private fun CycleList(state: CyclesUiState, vm: CyclesViewModel) {
    var pendingDelete by remember { mutableStateOf<ShiftCycleDto?>(null) }

    LazyColumn(
        modifier = Modifier.fillMaxSize().padding(horizontal = 16.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
        contentPadding = PaddingValues(vertical = 12.dp),
    ) {
        state.error?.let { item(key = "err") { InfoCard(it, isError = true, onDismiss = null) } }
        state.actionError?.let { item(key = "aerr") { InfoCard(it, isError = true, onDismiss = { vm.dismissActionError() }) } }
        state.notice?.let { item(key = "notice") { InfoCard(it, isError = false, onDismiss = { vm.dismissNotice() }) } }

        if (state.cycles.isEmpty() && state.error == null) {
            item(key = "empty") { EmptyNote("No shift cycles yet. Tap + to create one.") }
        } else {
            items(state.cycles, key = { "cycle-${it.id}" }) { cycle ->
                CycleCard(
                    cycle = cycle,
                    busy = state.togglingId == cycle.id || state.deletingId == cycle.id,
                    onEdit = { vm.openEdit(cycle) },
                    onToggleActive = { vm.setActive(cycle.id, !cycle.active) },
                    onDelete = { pendingDelete = cycle },
                )
            }
        }
    }

    pendingDelete?.let { cycle ->
        AlertDialog(
            onDismissRequest = { pendingDelete = null },
            title = { Text("Delete shift cycle") },
            text = { Text("Delete this unused shift cycle?") },
            confirmButton = {
                TextButton(onClick = { pendingDelete = null; vm.deleteCycle(cycle.id) }) { Text("Delete") }
            },
            dismissButton = {
                TextButton(onClick = { pendingDelete = null }) { Text("Cancel") }
            },
        )
    }
}

@Composable
private fun CycleCard(
    cycle: ShiftCycleDto,
    busy: Boolean,
    onEdit: () -> Unit,
    onToggleActive: () -> Unit,
    onDelete: () -> Unit,
) {
    Card(modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(cycle.name, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
                StatusBadge(cycle.active)
            }

            LabeledLine("Cycle Starts", cycle.startsAtLabel?.takeIf { it.isNotBlank() } ?: cycle.startsOn ?: "—")
            LabeledLine("Flow", "Each shift uses its saved duration")
            cycle.cycleDurationLabel?.takeIf { it.isNotBlank() }?.let { LabeledLine("Full Cycle", it) }
            LabeledLine(
                "Sequence",
                cycle.sequenceLabel?.takeIf { it.isNotBlank() }
                    ?: cycle.steps.joinToString(" → ") { it.shiftTemplateName ?: "—" }.ifBlank { "—" },
            )

            Spacer(Modifier.height(2.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.fillMaxWidth()) {
                NayaraOutlinedButton(onClick = onEdit, enabled = !busy, modifier = Modifier.weight(1f)) {
                    Text("Edit")
                }
                NayaraOutlinedButton(onClick = onToggleActive, enabled = !busy, modifier = Modifier.weight(1f)) {
                    Text(if (cycle.active) "Deactivate" else "Activate")
                }
            }
            if (cycle.deletable) {
                NayaraOutlinedButton(onClick = onDelete, enabled = !busy, modifier = Modifier.fillMaxWidth()) {
                    Text("Delete", color = MaterialTheme.nayara.statusError)
                }
            } else {
                Text(
                    "This cycle has staff assignment history — deactivate it instead of deleting it.",
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.nayara.textTertiary,
                )
            }
        }
    }
}

@Composable
private fun StatusBadge(active: Boolean) {
    val nayara = MaterialTheme.nayara
    val bg = if (active) nayara.statusSuccessContainer else nayara.bgSurfaceSunken
    val fg = if (active) nayara.statusOnSuccessContainer else nayara.textSecondary
    Box(
        modifier = Modifier
            .clip(RoundedCornerShape(50))
            .background(bg)
            .padding(horizontal = 10.dp, vertical = 3.dp),
    ) {
        Text(if (active) "Active" else "Inactive", style = MaterialTheme.typography.labelMedium, color = fg)
    }
}

@Composable
private fun LabeledLine(label: String, value: String) {
    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
        Text(label, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.nayara.textSecondary)
        Text(
            value,
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.nayara.textPrimary,
            fontWeight = FontWeight.Medium,
            modifier = Modifier.padding(start = 12.dp),
        )
    }
}

@Composable
private fun InfoCard(message: String, isError: Boolean, onDismiss: (() -> Unit)?) {
    val container = if (isError) MaterialTheme.colorScheme.errorContainer else MaterialTheme.nayara.statusSuccessContainer
    val onContainer = if (isError) MaterialTheme.colorScheme.onErrorContainer else MaterialTheme.nayara.statusOnSuccessContainer
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = container),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth().padding(start = 14.dp, top = 4.dp, bottom = 4.dp, end = 4.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(message, color = onContainer, style = MaterialTheme.typography.bodyMedium, modifier = Modifier.weight(1f))
            if (onDismiss != null) {
                IconButton(onClick = onDismiss) {
                    Icon(Icons.Filled.Close, contentDescription = "Dismiss", tint = onContainer)
                }
            }
        }
    }
}

@Composable
private fun EmptyNote(text: String) {
    Text(
        text,
        style = MaterialTheme.typography.bodyMedium,
        color = MaterialTheme.nayara.textSecondary,
        modifier = Modifier.padding(vertical = 24.dp),
    )
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun CycleEditor(
    editor: CycleEditorState,
    activeTemplates: List<ShiftTemplateDto>,
    allTemplates: List<ShiftTemplateDto>,
    vm: CyclesViewModel,
) {
    var showDatePicker by remember { mutableStateOf(false) }

    Column(
        modifier = Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        OutlinedTextField(
            value = editor.name,
            onValueChange = vm::editorSetName,
            label = { Text("Cycle Name") },
            singleLine = true,
            supportingText = { Text("Required · up to 80 characters") },
            modifier = Modifier.fillMaxWidth(),
        )

        Column {
            Text("Cycle Starts On", style = MaterialTheme.typography.labelLarge, color = MaterialTheme.nayara.textSecondary)
            Spacer(Modifier.height(6.dp))
            NayaraOutlinedButton(onClick = { showDatePicker = true }, modifier = Modifier.fillMaxWidth()) {
                Icon(Icons.Filled.DateRange, contentDescription = null)
                Spacer(Modifier.width(8.dp))
                Text(if (editor.startsOn.isBlank()) "Choose start date" else displayDate(editor.startsOn))
            }
        }

        Text("Shift Order In The Cycle", style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.SemiBold)
        if (activeTemplates.isEmpty()) {
            EmptyNote("No shift templates are available yet — add one before building a cycle.")
        }
        editor.steps.forEachIndexed { index, row ->
            StepPicker(
                index = index,
                row = row,
                options = optionsFor(row, activeTemplates, allTemplates),
                canRemove = editor.steps.size > 1,
                onSelect = { vm.editorSetStep(row.key, it) },
                onRemove = { vm.editorRemoveStep(row.key) },
            )
        }
        if (editor.canAddStep) {
            NayaraTonalButton(onClick = { vm.editorAddStep() }, modifier = Modifier.fillMaxWidth()) {
                Icon(Icons.Filled.Add, contentDescription = null)
                Spacer(Modifier.width(8.dp))
                Text("Add Another Shift")
            }
        }

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text("Active", style = MaterialTheme.typography.titleSmall)
                Text(
                    "Available for staff assignments",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.nayara.textSecondary,
                )
            }
            Switch(checked = editor.active, onCheckedChange = vm::editorSetActive)
        }

        editor.error?.let { InfoCard(it, isError = true, onDismiss = null) }

        Row(horizontalArrangement = Arrangement.spacedBy(10.dp), modifier = Modifier.fillMaxWidth()) {
            NayaraOutlinedButton(onClick = { vm.closeEditor() }, enabled = !editor.saving, modifier = Modifier.weight(1f)) {
                Text("Cancel")
            }
            NayaraButton(
                onClick = { vm.saveEditor() },
                enabled = !editor.saving,
                loading = editor.saving,
                modifier = Modifier.weight(1f),
            ) {
                Text(if (editor.isCreate) "Create Cycle" else "Save Changes")
            }
        }
    }

    if (showDatePicker) {
        val dpState = rememberDatePickerState(initialSelectedDateMillis = isoToMillis(editor.startsOn))
        DatePickerDialog(
            onDismissRequest = { showDatePicker = false },
            confirmButton = {
                TextButton(onClick = {
                    dpState.selectedDateMillis?.let { vm.editorSetStartsOn(millisToIso(it)) }
                    showDatePicker = false
                }) { Text("OK") }
            },
            dismissButton = {
                TextButton(onClick = { showDatePicker = false }) { Text("Cancel") }
            },
        ) {
            DatePicker(state = dpState)
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun StepPicker(
    index: Int,
    row: StepRow,
    options: List<ShiftTemplateDto>,
    canRemove: Boolean,
    onSelect: (Long?) -> Unit,
    onRemove: () -> Unit,
) {
    var expanded by remember { mutableStateOf(false) }
    val selectedLabel = options.firstOrNull { it.id == row.templateId }?.menuLabel ?: "Leave this step empty"

    Row(modifier = Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        ExposedDropdownMenuBox(
            expanded = expanded,
            onExpandedChange = { expanded = it },
            modifier = Modifier.weight(1f),
        ) {
            OutlinedTextField(
                value = selectedLabel,
                onValueChange = {},
                readOnly = true,
                label = { Text("Step ${stepLetter(index)}") },
                trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = expanded) },
                modifier = Modifier
                    .menuAnchor(MenuAnchorType.PrimaryNotEditable)
                    .fillMaxWidth(),
            )
            ExposedDropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
                DropdownMenuItem(
                    text = { Text("Leave this step empty") },
                    onClick = { onSelect(null); expanded = false },
                )
                options.forEach { template ->
                    DropdownMenuItem(
                        text = { Text(template.menuLabel) },
                        onClick = { onSelect(template.id); expanded = false },
                    )
                }
            }
        }
        if (canRemove) {
            IconButton(onClick = onRemove) {
                Icon(Icons.Filled.Close, contentDescription = "Remove step")
            }
        }
    }
}

/** Selectable templates for a step: active ones, plus the row's current pick if it
 *  happens to be inactive (so an existing selection stays visible while editing). */
private fun optionsFor(
    row: StepRow,
    active: List<ShiftTemplateDto>,
    all: List<ShiftTemplateDto>,
): List<ShiftTemplateDto> {
    val selected = row.templateId ?: return active
    if (active.any { it.id == selected }) return active
    val extra = all.firstOrNull { it.id == selected } ?: return active
    return active + extra
}

private fun stepLetter(index: Int): String = ('A' + (index % 26)).toString()

private fun isoToMillis(iso: String): Long? = runCatching {
    LocalDate.parse(iso).atStartOfDay(ZoneOffset.UTC).toInstant().toEpochMilli()
}.getOrNull()

private fun millisToIso(millis: Long): String =
    Instant.ofEpochMilli(millis).atZone(ZoneOffset.UTC).toLocalDate().toString()

private fun displayDate(iso: String): String = runCatching {
    LocalDate.parse(iso).format(DateTimeFormatter.ofPattern("dd MMM yyyy"))
}.getOrDefault(iso)
