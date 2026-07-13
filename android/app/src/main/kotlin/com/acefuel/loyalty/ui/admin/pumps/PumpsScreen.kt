package com.acefuel.loyalty.ui.admin.pumps

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
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.ArrowDropDown
import androidx.compose.material.icons.filled.Delete
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
fun AdminPumpsScreen(onBack: () -> Unit) {
    val container = LocalContainer.current
    val repo = remember {
        PumpsRepository(container.retrofit.create(PumpsApi::class.java), container.json)
    }
    val vm: PumpsViewModel = viewModel(factory = viewModelFactory { initializer { PumpsViewModel(repo) } })
    val state by vm.state.collectAsStateWithLifecycle()

    var pendingDelete by remember { mutableStateOf<FuelPumpDto?>(null) }
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Pumps") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                },
            )
        },
    ) { innerPadding ->
        when {
            state.loading && state.pumps.isEmpty() && state.error == null ->
                Box(
                    modifier = Modifier.fillMaxSize().padding(innerPadding),
                    contentAlignment = Alignment.Center,
                ) { CircularProgressIndicator() }

            else -> LazyColumn(
                modifier = Modifier.fillMaxSize().padding(innerPadding),
                contentPadding = PaddingValues(16.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                item(key = "feature-settings") { FeatureSettingsCard(state, vm) }

                state.notice?.let { msg ->
                    item(key = "notice") { NoticeCard(msg, onDismiss = { vm.dismissNotice() }) }
                }
                state.actionError?.let { msg ->
                    item(key = "action-error") { ErrorCard(msg, onDismiss = { vm.dismissActionError() }) }
                }

                item(key = "add-pump") {
                    NayaraButton(onClick = { vm.openCreate() }, modifier = Modifier.fillMaxWidth()) {
                        Icon(Icons.Filled.Add, contentDescription = null)
                        Spacer(Modifier.width(8.dp))
                        Text("Add Pump")
                    }
                }

                item(key = "list-header") {
                    Text("Configured Pumps", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
                }

                when {
                    state.error != null && state.pumps.isEmpty() ->
                        item(key = "load-error") { ErrorCard(state.error!!, onDismiss = null) }

                    state.pumps.isEmpty() ->
                        item(key = "empty") {
                            Text(
                                "No pumps have been added yet.",
                                style = MaterialTheme.typography.bodyMedium,
                                color = MaterialTheme.nayara.textSecondary,
                            )
                        }

                    else -> items(state.pumps, key = { "pump-${it.id}" }) { pump ->
                        PumpCard(
                            pump = pump,
                            deleting = state.deletingPumpId == pump.id,
                            onEdit = { vm.openEdit(pump) },
                            onDelete = { pendingDelete = pump },
                        )
                    }
                }
            }
        }
    }

    pendingDelete?.let { pump ->
        AlertDialog(
            onDismissRequest = { pendingDelete = null },
            title = { Text("Remove ${pump.displayName}?") },
            text = { Text("Pumps still referenced by transactions can't be removed.") },
            confirmButton = {
                TextButton(onClick = {
                    vm.deletePump(pump.id)
                    pendingDelete = null
                }) { Text("Remove", color = MaterialTheme.colorScheme.error) }
            },
            dismissButton = {
                TextButton(onClick = { pendingDelete = null }) { Text("Cancel") }
            },
        )
    }

    val editor = state.editor
    if (editor != null) {
        ModalBottomSheet(onDismissRequest = { vm.closeEditor() }, sheetState = sheetState) {
            PumpEditorSheet(editor = editor, uiState = state, vm = vm)
        }
    }
}

@Composable
private fun FeatureSettingsCard(state: PumpsUiState, vm: PumpsViewModel) {
    Card(Modifier.fillMaxWidth()) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Text(
                "Transaction Pump Settings",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.SemiBold,
            )
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    "Enable nozzle selection",
                    style = MaterialTheme.typography.bodyLarge,
                    modifier = Modifier.weight(1f),
                )
                Switch(
                    checked = state.nozzleFeatureEnabled,
                    onCheckedChange = { vm.onFeatureToggle(it) },
                    enabled = !state.featureToggleInFlight,
                )
            }
            Text(
                "When enabled, staff use My Pump and assigned nozzles. When disabled, staff choose the pump directly in New Transaction.",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.nayara.textSecondary,
            )
        }
    }
}

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
                modifier = Modifier.weight(1f),
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

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun PumpCard(pump: FuelPumpDto, deleting: Boolean, onEdit: () -> Unit, onDelete: () -> Unit) {
    Card(Modifier.fillMaxWidth()) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(pump.displayName, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
                Row {
                    TextButton(onClick = onEdit) { Text("Edit") }
                    TextButton(onClick = onDelete, enabled = !deleting) {
                        Text(
                            if (deleting) "Removing…" else "Delete",
                            color = if (deleting) MaterialTheme.nayara.textTertiary else MaterialTheme.colorScheme.error,
                        )
                    }
                }
            }
            Text(
                "${pump.nozzles.size} nozzles configured · ${pump.activeNozzlesCount} active · " +
                    if (pump.active) "Shown in app" else "Hidden",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.nayara.textSecondary,
            )
            if (pump.nozzles.isNotEmpty()) {
                FlowRow(
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                    verticalArrangement = Arrangement.spacedBy(6.dp),
                ) {
                    pump.nozzles.forEach { NozzleBadge(it) }
                }
            }
        }
    }
}

@Composable
private fun NozzleBadge(nozzle: NozzleDto) {
    val label = buildString {
        append(nozzle.displayName)
        append(" • ")
        append(nozzle.fuelTypeName)
        if (!nozzle.active) append(" • Inactive")
    }
    val container = if (nozzle.active) MaterialTheme.nayara.bgSurfaceSunken else MaterialTheme.nayara.statusWarningContainer
    val content = if (nozzle.active) MaterialTheme.nayara.textSecondary else MaterialTheme.nayara.statusOnWarningContainer
    Surface(color = container, shape = MaterialTheme.shapes.small) {
        Text(
            label,
            modifier = Modifier.padding(horizontal = 10.dp, vertical = 4.dp),
            style = MaterialTheme.typography.labelMedium,
            color = content,
        )
    }
}

@Composable
private fun PumpEditorSheet(editor: PumpEditorState, uiState: PumpsUiState, vm: PumpsViewModel) {
    val scroll = rememberScrollState()
    val activeOptions = uiState.activeFuelTypes.map { it.code to it.name }
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .verticalScroll(scroll)
            .padding(horizontal = 20.dp)
            .padding(bottom = 28.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Text(
            if (editor.isCreate) "New Pump" else "Edit ${editor.titleName}",
            style = MaterialTheme.typography.titleLarge,
            fontWeight = FontWeight.Bold,
        )

        Surface(
            color = MaterialTheme.nayara.statusInfoContainer,
            shape = MaterialTheme.shapes.medium,
            modifier = Modifier.fillMaxWidth(),
        ) {
            Text(
                if (editor.isCreate) {
                    "This pump will be saved as ${editor.titleName}. Nozzles are numbered automatically."
                } else {
                    "Nozzles are numbered automatically. At least one nozzle is required."
                },
                modifier = Modifier.padding(12.dp),
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.nayara.statusOnInfoContainer,
            )
        }

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(Modifier.weight(1f)) {
                Text("Show in app", style = MaterialTheme.typography.bodyLarge)
                Text(
                    "Visible to staff in New Transaction.",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.nayara.textSecondary,
                )
            }
            Switch(checked = editor.active, onCheckedChange = { vm.editorSetActive(it) })
        }

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text("Nozzles", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
            TextButton(onClick = { vm.editorAddNozzle() }) {
                Icon(Icons.Filled.Add, contentDescription = null)
                Spacer(Modifier.width(4.dp))
                Text("Add Nozzle")
            }
        }

        if (uiState.activeFuelTypes.isEmpty()) {
            Text(
                "No active fuel types are available. Add one under Fuel Types first.",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.nayara.statusWarningText,
            )
        }

        editor.nozzles.forEachIndexed { index, row ->
            NozzleEditorRow(
                index = index,
                row = row,
                activeOptions = activeOptions,
                onSelectFuelType = { vm.editorSetNozzleFuelType(row.key, it) },
                onActiveChange = { vm.editorSetNozzleActive(row.key, it) },
                onRemove = { vm.editorRemoveNozzle(row.key) },
            )
        }

        editor.error?.let {
            Text(it, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.error)
        }

        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            NayaraOutlinedButton(
                onClick = { vm.closeEditor() },
                enabled = !editor.saving,
                modifier = Modifier.weight(1f),
            ) { Text("Cancel") }
            NayaraButton(
                onClick = { vm.saveEditor() },
                loading = editor.saving,
                enabled = !editor.saving,
                modifier = Modifier.weight(1f),
            ) { Text("Save Pump") }
        }
    }
}

@Composable
private fun NozzleEditorRow(
    index: Int,
    row: NozzleFormRow,
    activeOptions: List<Pair<String, String>>,
    onSelectFuelType: (String) -> Unit,
    onActiveChange: (Boolean) -> Unit,
    onRemove: () -> Unit,
) {
    // Keep an in-use inactive fuel type visible in this row even though it is
    // no longer offered for new selections (matches the web settings screen).
    val options = if (row.fuelTypeCode.isNotBlank() && activeOptions.none { it.first == row.fuelTypeCode }) {
        listOf(row.fuelTypeCode to row.fuelTypeName.ifBlank { row.fuelTypeCode }) + activeOptions
    } else {
        activeOptions
    }
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.nayara.bgSurfaceSunken),
    ) {
        Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text("Nozzle ${index + 1}", style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.SemiBold)
                IconButton(onClick = onRemove) {
                    Icon(Icons.Filled.Delete, contentDescription = "Remove nozzle", tint = MaterialTheme.colorScheme.error)
                }
            }
            Text("Fuel Type", style = MaterialTheme.typography.labelMedium, color = MaterialTheme.nayara.textSecondary)
            FuelTypeDropdown(options = options, selectedCode = row.fuelTypeCode, onSelect = onSelectFuelType)
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text("Active nozzle", style = MaterialTheme.typography.bodyMedium)
                Switch(checked = row.active, onCheckedChange = onActiveChange)
            }
        }
    }
}

@Composable
private fun FuelTypeDropdown(options: List<Pair<String, String>>, selectedCode: String, onSelect: (String) -> Unit) {
    var expanded by remember { mutableStateOf(false) }
    val selectedLabel = options.firstOrNull { it.first == selectedCode }?.second
        ?: selectedCode.ifBlank { "Select fuel type" }
    Box(Modifier.fillMaxWidth()) {
        OutlinedButton(onClick = { expanded = true }, modifier = Modifier.fillMaxWidth()) {
            Text(selectedLabel, modifier = Modifier.weight(1f), textAlign = TextAlign.Start)
            Icon(Icons.Filled.ArrowDropDown, contentDescription = null)
        }
        DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
            if (options.isEmpty()) {
                DropdownMenuItem(text = { Text("No active fuel types") }, onClick = { expanded = false }, enabled = false)
            }
            options.forEach { (code, name) ->
                DropdownMenuItem(text = { Text(name) }, onClick = {
                    onSelect(code)
                    expanded = false
                })
            }
        }
    }
}
