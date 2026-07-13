package com.acefuel.loyalty.ui.admin.cycles

import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
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
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.EventRepeat
import androidx.compose.material3.CircularProgressIndicator
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
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import com.acefuel.loyalty.core.di.LocalContainer
import com.acefuel.loyalty.ui.designsystem.ActiveChip
import com.acefuel.loyalty.ui.designsystem.ConfirmDialog
import com.acefuel.loyalty.ui.designsystem.DateField
import com.acefuel.loyalty.ui.designsystem.EmptyState
import com.acefuel.loyalty.ui.designsystem.ErrorState
import com.acefuel.loyalty.ui.designsystem.FormField
import com.acefuel.loyalty.ui.designsystem.InlineErrorCard
import com.acefuel.loyalty.ui.designsystem.NayaraCard
import com.acefuel.loyalty.ui.designsystem.NayaraPullToRefresh
import com.acefuel.loyalty.ui.designsystem.NayaraSnackbarHost
import com.acefuel.loyalty.ui.designsystem.NayaraTopBar
import com.acefuel.loyalty.ui.designsystem.SkeletonList
import com.acefuel.loyalty.ui.designsystem.rememberHaptics
import com.acefuel.loyalty.ui.designsystem.showError
import com.acefuel.loyalty.ui.designsystem.showSuccess
import com.acefuel.loyalty.ui.theme.NayaraButton
import com.acefuel.loyalty.ui.theme.NayaraMotion
import com.acefuel.loyalty.ui.theme.NayaraOutlinedButton
import com.acefuel.loyalty.ui.theme.NayaraSpacing
import com.acefuel.loyalty.ui.theme.NayaraTonalButton
import com.acefuel.loyalty.ui.theme.nayara
import java.time.LocalDate

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AdminCyclesScreen(onBack: () -> Unit) {
    val container = LocalContainer.current
    val repo = remember {
        CyclesRepository(container.retrofit.create(CyclesApi::class.java), container.json)
    }
    val vm: CyclesViewModel = viewModel(factory = viewModelFactory { initializer { CyclesViewModel(repo) } })
    val state by vm.state.collectAsStateWithLifecycle()

    val snackbar = remember { SnackbarHostState() }
    val haptics = rememberHaptics()

    val editor = state.editor
    // Keeps the editor content on screen while its exit animation runs.
    var lastEditor by remember { mutableStateOf<CycleEditorState?>(null) }
    if (editor != null) lastEditor = editor

    var showDiscardConfirm by remember { mutableStateOf(false) }
    val requestCloseEditor: () -> Unit = {
        if (state.editor?.dirty == true) showDiscardConfirm = true else vm.closeEditor()
    }

    BackHandler(enabled = editor != null) { requestCloseEditor() }

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
    // Load failures with stale data on screen surface as a snackbar; the
    // full-area ErrorState handles the nothing-to-show case below.
    LaunchedEffect(state.error) {
        val msg = state.error ?: return@LaunchedEffect
        if (state.cycles.isNotEmpty()) {
            haptics.reject()
            snackbar.showError(msg)
            vm.consumeError()
        }
    }

    Scaffold(
        topBar = {
            NayaraTopBar(
                title = when {
                    editor == null -> "Shift Cycles"
                    editor.isCreate -> "New Cycle"
                    else -> "Edit Cycle"
                },
                onBack = { if (editor != null) requestCloseEditor() else onBack() },
            )
        },
        snackbarHost = { NayaraSnackbarHost(snackbar) },
        floatingActionButton = {
            if (editor == null && !(state.loading && state.cycles.isEmpty())) {
                FloatingActionButton(onClick = { vm.openCreate() }) {
                    Icon(Icons.Filled.Add, contentDescription = "New shift cycle")
                }
            }
        },
    ) { padding ->
        Box(Modifier.fillMaxSize().padding(padding)) {
            AnimatedContent(
                targetState = editor != null,
                transitionSpec = {
                    fadeIn(tween(NayaraMotion.Base, easing = NayaraMotion.Enter)) togetherWith
                        fadeOut(tween(NayaraMotion.Fast, easing = NayaraMotion.Exit))
                },
                label = "cycles-list-editor",
            ) { editing ->
                if (editing) {
                    lastEditor?.let {
                        CycleEditor(it, state.activeTemplates, state.templates, vm, onCancel = requestCloseEditor)
                    }
                } else {
                    when {
                        state.loading && state.cycles.isEmpty() ->
                            SkeletonList(Modifier.padding(NayaraSpacing.ScreenMargin), count = 5, showAvatar = false)
                        state.error != null && state.cycles.isEmpty() ->
                            Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                                ErrorState(state.error!!, onRetry = vm::load)
                            }
                        else -> NayaraPullToRefresh(
                            isRefreshing = state.refreshing,
                            onRefresh = vm::refresh,
                            modifier = Modifier.fillMaxSize(),
                        ) {
                            CycleList(state, vm)
                        }
                    }
                }
            }
        }
    }

    if (showDiscardConfirm) {
        ConfirmDialog(
            title = "Discard changes?",
            text = "You have unsaved changes in this cycle. Discard them?",
            confirmLabel = "Discard",
            destructive = true,
            onConfirm = {
                showDiscardConfirm = false
                vm.closeEditor()
            },
            onDismiss = { showDiscardConfirm = false },
        )
    }
}

@Composable
private fun CycleList(state: CyclesUiState, vm: CyclesViewModel) {
    var pendingDelete by remember { mutableStateOf<ShiftCycleDto?>(null) }

    LazyColumn(
        modifier = Modifier.fillMaxSize().padding(horizontal = NayaraSpacing.ScreenMargin),
        verticalArrangement = Arrangement.spacedBy(NayaraSpacing.Md),
        contentPadding = PaddingValues(top = NayaraSpacing.Md, bottom = 96.dp),
    ) {
        if (state.cycles.isEmpty()) {
            item(key = "empty") {
                EmptyState(
                    title = "No shift cycles yet",
                    message = "Tap + to create one.",
                    icon = Icons.Filled.EventRepeat,
                )
            }
        } else {
            items(state.cycles, key = { "cycle-${it.id}" }) { cycle ->
                CycleCard(
                    cycle = cycle,
                    toggling = state.togglingId == cycle.id,
                    deleting = state.deletingId == cycle.id,
                    onEdit = { vm.openEdit(cycle) },
                    onToggleActive = { vm.setActive(cycle.id, !cycle.active) },
                    onDelete = { pendingDelete = cycle },
                    modifier = Modifier.animateItem(),
                )
            }
        }
    }

    pendingDelete?.let { cycle ->
        ConfirmDialog(
            title = "Delete shift cycle",
            text = "Delete \"${cycle.name}\"? This can't be undone.",
            confirmLabel = "Delete",
            destructive = true,
            onConfirm = {
                pendingDelete = null
                vm.deleteCycle(cycle.id)
            },
            onDismiss = { pendingDelete = null },
        )
    }
}

@Composable
private fun CycleCard(
    cycle: ShiftCycleDto,
    toggling: Boolean,
    deleting: Boolean,
    onEdit: () -> Unit,
    onToggleActive: () -> Unit,
    onDelete: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val busy = toggling || deleting
    NayaraCard(modifier = modifier.fillMaxWidth(), shape = MaterialTheme.shapes.large) {
        Column(modifier = Modifier.padding(NayaraSpacing.Lg), verticalArrangement = Arrangement.spacedBy(NayaraSpacing.Sm)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(cycle.name, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
                ActiveChip(active = cycle.active)
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
                    if (toggling) {
                        CircularProgressIndicator(Modifier.size(16.dp), strokeWidth = 2.dp)
                    } else {
                        Text(if (cycle.active) "Deactivate" else "Activate")
                    }
                }
            }
            if (cycle.deletable) {
                NayaraOutlinedButton(onClick = onDelete, enabled = !busy, modifier = Modifier.fillMaxWidth()) {
                    if (deleting) {
                        CircularProgressIndicator(Modifier.size(16.dp), strokeWidth = 2.dp)
                    } else {
                        Text("Delete", color = MaterialTheme.nayara.statusError)
                    }
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

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun CycleEditor(
    editor: CycleEditorState,
    activeTemplates: List<ShiftTemplateDto>,
    allTemplates: List<ShiftTemplateDto>,
    vm: CyclesViewModel,
    onCancel: () -> Unit,
) {
    val haptics = rememberHaptics()

    Column(
        modifier = Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        FormField(
            value = editor.name,
            onValueChange = vm::editorSetName,
            label = "Cycle Name",
            errors = editor.nameError?.let(::listOf),
            helper = "Required · up to 80 characters",
        )

        DateField(
            label = "Cycle Starts On",
            value = runCatching { LocalDate.parse(editor.startsOn) }.getOrNull(),
            onChange = { vm.editorSetStartsOn(it.toString()) },
            placeholder = "Choose start date",
        )

        Text("Shift Order In The Cycle", style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.SemiBold)
        if (activeTemplates.isEmpty()) {
            Text(
                "No shift templates are available yet — add one before building a cycle.",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.nayara.textSecondary,
            )
        }
        editor.steps.forEachIndexed { index, row ->
            StepPicker(
                index = index,
                row = row,
                options = optionsFor(row, activeTemplates, allTemplates),
                canRemove = editor.steps.size > 1,
                onSelect = {
                    haptics.tick()
                    vm.editorSetStep(row.key, it)
                },
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
            Switch(
                checked = editor.active,
                onCheckedChange = {
                    haptics.tick()
                    vm.editorSetActive(it)
                },
            )
        }

        editor.error?.let { InlineErrorCard(it) }

        Row(horizontalArrangement = Arrangement.spacedBy(10.dp), modifier = Modifier.fillMaxWidth()) {
            NayaraOutlinedButton(onClick = onCancel, enabled = !editor.saving, modifier = Modifier.weight(1f)) {
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
