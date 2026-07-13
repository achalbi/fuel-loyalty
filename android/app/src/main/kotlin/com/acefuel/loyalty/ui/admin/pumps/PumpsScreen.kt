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
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.LocalGasStation
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
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.onSizeChanged
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
import com.acefuel.loyalty.ui.designsystem.EmptyState
import com.acefuel.loyalty.ui.designsystem.InlineErrorCard
import com.acefuel.loyalty.ui.designsystem.NayaraCard
import com.acefuel.loyalty.ui.designsystem.NayaraPullToRefresh
import com.acefuel.loyalty.ui.designsystem.NayaraSnackbarHost
import com.acefuel.loyalty.ui.designsystem.NayaraTopBar
import com.acefuel.loyalty.ui.designsystem.PickerField
import com.acefuel.loyalty.ui.designsystem.SkeletonCard
import com.acefuel.loyalty.ui.designsystem.SkeletonList
import com.acefuel.loyalty.ui.designsystem.StatusChip
import com.acefuel.loyalty.ui.designsystem.rememberHaptics
import com.acefuel.loyalty.ui.designsystem.showError
import com.acefuel.loyalty.ui.designsystem.showSuccess
import com.acefuel.loyalty.ui.theme.NayaraButton
import com.acefuel.loyalty.ui.theme.NayaraOutlinedButton
import com.acefuel.loyalty.ui.theme.NayaraSpacing
import com.acefuel.loyalty.ui.theme.nayara
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AdminPumpsScreen(onBack: () -> Unit) {
    val container = LocalContainer.current
    val repo = remember {
        PumpsRepository(container.retrofit.create(PumpsApi::class.java), container.json)
    }
    val vm: PumpsViewModel = viewModel(factory = viewModelFactory { initializer { PumpsViewModel(repo) } })
    val state by vm.state.collectAsStateWithLifecycle()

    val snackbar = remember { SnackbarHostState() }
    val haptics = rememberHaptics()
    val scope = rememberCoroutineScope()

    var pendingDelete by remember { mutableStateOf<FuelPumpDto?>(null) }
    var showDiscardConfirm by remember { mutableStateOf(false) }
    var showDestroyConfirm by remember { mutableStateOf(false) }
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)

    // Show first, consume after: consuming inside the effect nulls the key it
    // is launched on, which would cancel the still-suspended showSnackbar.
    LaunchedEffect(state.notice) {
        val msg = state.notice ?: return@LaunchedEffect
        haptics.confirm()
        snackbar.showSuccess(msg)
        vm.dismissNotice()
    }
    LaunchedEffect(state.actionError) {
        val msg = state.actionError ?: return@LaunchedEffect
        haptics.reject()
        snackbar.showError(msg)
        vm.dismissActionError()
    }
    LaunchedEffect(state.error) {
        val msg = state.error ?: return@LaunchedEffect
        if (state.pumps.isNotEmpty()) {
            haptics.reject()
            snackbar.showError(msg)
            vm.consumeError()
        }
    }

    Scaffold(
        topBar = { NayaraTopBar(title = "Pumps", onBack = onBack) },
        snackbarHost = { NayaraSnackbarHost(snackbar) },
    ) { innerPadding ->
        when {
            state.loading && state.pumps.isEmpty() && state.error == null ->
                Column(
                    modifier = Modifier.fillMaxSize().padding(innerPadding).padding(NayaraSpacing.ScreenMargin),
                    verticalArrangement = Arrangement.spacedBy(NayaraSpacing.Md),
                ) {
                    SkeletonCard(lines = 2)
                    SkeletonList(count = 4, showAvatar = false)
                }

            else -> NayaraPullToRefresh(
                isRefreshing = state.refreshing,
                onRefresh = vm::refresh,
                modifier = Modifier.fillMaxSize().padding(innerPadding),
            ) {
                LazyColumn(
                    modifier = Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(NayaraSpacing.ScreenMargin),
                    verticalArrangement = Arrangement.spacedBy(NayaraSpacing.Md),
                ) {
                    // Load failed with nothing to show: keep the feature toggle
                    // and Add Pump usable; offer retry inline.
                    if (state.error != null && state.pumps.isEmpty()) {
                        item(key = "load-error") {
                            InlineErrorCard(state.error!!, onRetry = vm::load)
                        }
                    }

                    item(key = "feature-settings") { FeatureSettingsCard(state, vm) }

                    item(key = "add-pump") {
                        NayaraButton(onClick = { vm.openCreate() }, modifier = Modifier.fillMaxWidth()) {
                            Icon(Icons.Filled.Add, contentDescription = null)
                            Spacer(Modifier.width(8.dp))
                            Text("Add Pump")
                        }
                    }

                    item(key = "list-header") {
                        Text("Configured Pumps", style = MaterialTheme.typography.titleSmall, color = MaterialTheme.nayara.textSecondary)
                    }

                    if (state.pumps.isEmpty()) {
                        item(key = "empty") {
                            EmptyState(
                                title = "No pumps yet",
                                message = "Add one to start assigning nozzles.",
                                icon = Icons.Filled.LocalGasStation,
                            )
                        }
                    } else {
                        items(state.pumps, key = { "pump-${it.id}" }) { pump ->
                            PumpCard(
                                pump = pump,
                                deleting = state.deletingPumpId == pump.id,
                                onEdit = { vm.openEdit(pump) },
                                onDelete = { pendingDelete = pump },
                                modifier = Modifier.animateItem(),
                            )
                        }
                    }
                }
            }
        }
    }

    pendingDelete?.let { pump ->
        ConfirmDialog(
            title = "Remove ${pump.displayName}?",
            text = "Pumps still referenced by transactions can't be removed.",
            confirmLabel = "Remove",
            destructive = true,
            onConfirm = {
                pendingDelete = null
                vm.deletePump(pump.id)
            },
            onDismiss = { pendingDelete = null },
        )
    }

    val editor = state.editor
    if (editor != null) {
        ModalBottomSheet(
            onDismissRequest = {
                if (editor.dirty) showDiscardConfirm = true else vm.closeEditor()
            },
            sheetState = sheetState,
        ) {
            PumpEditorSheet(
                editor = editor,
                uiState = state,
                vm = vm,
                onCancel = { if (editor.dirty) showDiscardConfirm = true else vm.closeEditor() },
                onSave = {
                    if (editor.removedNozzleIds.isNotEmpty()) showDestroyConfirm = true else vm.saveEditor()
                },
            )
        }
    }

    if (showDiscardConfirm) {
        ConfirmDialog(
            title = "Discard changes?",
            text = "You have unsaved changes to this pump. Discard them?",
            confirmLabel = "Discard",
            destructive = true,
            onConfirm = {
                showDiscardConfirm = false
                vm.closeEditor()
            },
            onDismiss = {
                showDiscardConfirm = false
                // The sheet may have swiped away before the dialog — bring it back.
                scope.launch { sheetState.show() }
            },
        )
    }

    if (showDestroyConfirm) {
        val count = state.editor?.removedNozzleIds?.size ?: 0
        ConfirmDialog(
            title = "Delete removed nozzles?",
            text = "Saving will permanently delete $count removed nozzle${if (count == 1) "" else "s"}.",
            confirmLabel = "Save & Delete",
            destructive = true,
            onConfirm = {
                showDestroyConfirm = false
                vm.saveEditor()
            },
            onDismiss = { showDestroyConfirm = false },
        )
    }
}

@Composable
private fun FeatureSettingsCard(state: PumpsUiState, vm: PumpsViewModel) {
    val haptics = rememberHaptics()
    NayaraCard(modifier = Modifier.fillMaxWidth(), shape = MaterialTheme.shapes.large) {
        Column(Modifier.padding(NayaraSpacing.Lg), verticalArrangement = Arrangement.spacedBy(NayaraSpacing.Sm)) {
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
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    if (state.featureToggleInFlight) {
                        CircularProgressIndicator(Modifier.size(16.dp), strokeWidth = 2.dp)
                    }
                    Switch(
                        checked = state.nozzleFeatureEnabled,
                        onCheckedChange = {
                            haptics.tick()
                            vm.onFeatureToggle(it)
                        },
                        enabled = !state.featureToggleInFlight,
                    )
                }
            }
            Text(
                "When enabled, staff use My Pump and assigned nozzles. When disabled, staff choose the pump directly in New Transaction.",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.nayara.textSecondary,
            )
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun PumpCard(
    pump: FuelPumpDto,
    deleting: Boolean,
    onEdit: () -> Unit,
    onDelete: () -> Unit,
    modifier: Modifier = Modifier,
) {
    NayaraCard(modifier = modifier.fillMaxWidth(), shape = MaterialTheme.shapes.large) {
        Column(Modifier.padding(NayaraSpacing.Lg), verticalArrangement = Arrangement.spacedBy(NayaraSpacing.Sm)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(pump.displayName, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
                Row {
                    TextButton(onClick = onEdit, enabled = !deleting) { Text("Edit") }
                    TextButton(onClick = onDelete, enabled = !deleting) {
                        if (deleting) {
                            CircularProgressIndicator(Modifier.size(16.dp), strokeWidth = 2.dp)
                        } else {
                            Text("Delete", color = MaterialTheme.nayara.statusError)
                        }
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
                    pump.nozzles.forEach { nozzle ->
                        StatusChip(
                            label = "${nozzle.displayName} • ${nozzle.fuelTypeName}" +
                                if (!nozzle.active) " • Inactive" else "",
                            tone = if (nozzle.active) ChipTone.Neutral else ChipTone.Warning,
                            showDot = !nozzle.active,
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun PumpEditorSheet(
    editor: PumpEditorState,
    uiState: PumpsUiState,
    vm: PumpsViewModel,
    onCancel: () -> Unit,
    onSave: () -> Unit,
) {
    val haptics = rememberHaptics()
    val scroll = rememberScrollState()
    val activeOptions = uiState.activeFuelTypes.map { it.code to it.name }
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .verticalScroll(scroll)
            .padding(horizontal = 20.dp)
            .padding(bottom = 28.dp)
            .imePadding()
            .navigationBarsPadding(),
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
            Switch(
                checked = editor.active,
                onCheckedChange = {
                    haptics.tick()
                    vm.editorSetActive(it)
                },
            )
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

        // Removing a nozzle only queues a hard destroy — make that explicit.
        if (editor.removedNozzleIds.isNotEmpty()) {
            Text(
                "Removing a nozzle deletes it on save.",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.nayara.statusWarningText,
                fontWeight = FontWeight.Medium,
            )
        }

        editor.nozzles.forEachIndexed { index, row ->
            NozzleEditorRow(
                index = index,
                row = row,
                activeOptions = activeOptions,
                onSelectFuelType = {
                    haptics.tick()
                    vm.editorSetNozzleFuelType(row.key, it)
                },
                onActiveChange = {
                    haptics.tick()
                    vm.editorSetNozzleActive(row.key, it)
                },
                onRemove = { vm.editorRemoveNozzle(row.key) },
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
                onClick = onSave,
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
            FuelTypePicker(options = options, selectedCode = row.fuelTypeCode, onSelect = onSelectFuelType)
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
private fun FuelTypePicker(options: List<Pair<String, String>>, selectedCode: String, onSelect: (String) -> Unit) {
    var expanded by remember { mutableStateOf(false) }
    var anchorWidthPx by remember { mutableIntStateOf(0) }
    val anchorWidth = with(LocalDensity.current) { anchorWidthPx.toDp() }
    val selectedLabel = options.firstOrNull { it.first == selectedCode }?.second
        ?: selectedCode.ifBlank { "Select fuel type" }
    Box(Modifier.fillMaxWidth().onSizeChanged { anchorWidthPx = it.width }) {
        PickerField(
            label = "Fuel Type",
            value = selectedLabel,
            onClick = { expanded = true },
        )
        DropdownMenu(
            expanded = expanded,
            onDismissRequest = { expanded = false },
            modifier = Modifier.width(anchorWidth),
        ) {
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
