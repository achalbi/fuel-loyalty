package com.acefuel.loyalty.ui.admin.shifts

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
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.Remove
import androidx.compose.material.icons.filled.WorkHistory
import androidx.compose.material3.Card
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ExtendedFloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedIconButton
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
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import com.acefuel.loyalty.core.di.LocalContainer
import com.acefuel.loyalty.ui.designsystem.ActiveChip
import com.acefuel.loyalty.ui.designsystem.ConfirmDialog
import com.acefuel.loyalty.ui.designsystem.EmptyState
import com.acefuel.loyalty.ui.designsystem.ErrorState
import com.acefuel.loyalty.ui.designsystem.FormField
import com.acefuel.loyalty.ui.designsystem.InlineErrorCard
import com.acefuel.loyalty.ui.designsystem.NayaraPullToRefresh
import com.acefuel.loyalty.ui.designsystem.NayaraSnackbarHost
import com.acefuel.loyalty.ui.designsystem.NayaraTopBar
import com.acefuel.loyalty.ui.designsystem.SkeletonList
import com.acefuel.loyalty.ui.designsystem.TimeField
import com.acefuel.loyalty.ui.designsystem.rememberHaptics
import com.acefuel.loyalty.ui.designsystem.showError
import com.acefuel.loyalty.ui.designsystem.showSuccess
import com.acefuel.loyalty.ui.theme.NayaraButton
import com.acefuel.loyalty.ui.theme.NayaraOutlinedButton
import com.acefuel.loyalty.ui.theme.nayara
import java.time.LocalTime
import java.time.format.DateTimeFormatter

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AdminShiftsScreen(onBack: () -> Unit) {
    val container = LocalContainer.current
    val repo = remember {
        ShiftsRepository(container.retrofit.create(ShiftsApi::class.java), container.json)
    }
    val vm: ShiftsViewModel = viewModel(factory = viewModelFactory { initializer { ShiftsViewModel(repo) } })
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
    LaunchedEffect(state.actionError) {
        state.actionError?.let {
            haptics.reject()
            snackbar.showError(it)
            vm.consumeActionError()
        }
    }

    Scaffold(
        topBar = { NayaraTopBar(title = "Shifts", onBack = onBack) },
        snackbarHost = { NayaraSnackbarHost(snackbar) },
        floatingActionButton = {
            ExtendedFloatingActionButton(onClick = vm::openCreate) {
                Icon(Icons.Filled.Add, contentDescription = null)
                Spacer(Modifier.width(8.dp))
                Text("New Shift")
            }
        },
    ) { innerPadding ->
        val bodyModifier = Modifier.fillMaxSize().padding(innerPadding)
        when {
            state.loading && state.templates.isEmpty() && state.error == null ->
                SkeletonList(bodyModifier.padding(16.dp), count = 6, showAvatar = false)

            state.templates.isEmpty() && state.error != null ->
                Box(bodyModifier, contentAlignment = Alignment.Center) {
                    ErrorState(message = state.error!!, onRetry = vm::load)
                }

            else -> NayaraPullToRefresh(
                isRefreshing = state.refreshing,
                onRefresh = vm::refresh,
                modifier = bodyModifier,
            ) {
                LazyColumn(
                    modifier = Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(start = 16.dp, top = 16.dp, end = 16.dp, bottom = 112.dp),
                    verticalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    if (state.templates.isEmpty()) {
                        item(key = "empty") {
                            EmptyState(
                                title = "No shifts yet",
                                message = "Shift templates define when each staff shift starts and how long it runs.",
                                icon = Icons.Filled.WorkHistory,
                                actionLabel = "Create your first shift",
                                onAction = vm::openCreate,
                            )
                        }
                    } else {
                        items(state.templates, key = { "shift-${it.id}" }) { template ->
                            ShiftCard(
                                template = template,
                                onEdit = { vm.openEdit(template) },
                                modifier = Modifier.animateItem(),
                            )
                        }
                    }
                }
            }
        }
    }

    val form = state.form
    if (form != null) {
        // Snapshot the just-opened form so we can tell "dirty" from "untouched".
        val initialForm = remember(form.id) { form }
        val dirty = form != initialForm
        GuardedSheet(dirty = dirty, onClose = vm::dismissForm) { requestClose ->
            ShiftFormContent(
                form = form,
                saving = state.saving,
                formError = state.formError,
                fieldErrors = state.formFieldErrors,
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
// List
// ---------------------------------------------------------------------------

@Composable
private fun ShiftCard(template: ShiftTemplateDto, onEdit: () -> Unit, modifier: Modifier = Modifier) {
    Card(modifier = modifier.fillMaxWidth()) {
        Column(
            modifier = Modifier.padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    template.name,
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold,
                    color = MaterialTheme.nayara.textPrimary,
                )
                ActiveChip(template.active)
            }
            LabeledValue("Starts At", template.startTimeLabel ?: template.startTime ?: "—")
            LabeledValue("Duration", template.durationLabel ?: "—")
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End) {
                TextButton(onClick = onEdit) {
                    Icon(Icons.Filled.Edit, contentDescription = null, modifier = Modifier.size(18.dp))
                    Spacer(Modifier.width(6.dp))
                    Text("Edit")
                }
            }
        }
    }
}

@Composable
private fun LabeledValue(label: String, value: String) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        Text(label, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.nayara.textSecondary)
        Text(
            value,
            style = MaterialTheme.typography.bodyMedium,
            fontWeight = FontWeight.SemiBold,
            color = MaterialTheme.nayara.textPrimary,
        )
    }
}

// ---------------------------------------------------------------------------
// Create / edit sheet content
// ---------------------------------------------------------------------------

@Composable
private fun ShiftFormContent(
    form: ShiftFormState,
    saving: Boolean,
    formError: String?,
    fieldErrors: Map<String, List<String>>,
    vm: ShiftsViewModel,
    onCancel: () -> Unit,
) {
    val haptics = rememberHaptics()
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .verticalScroll(rememberScrollState())
            .imePadding()
            .navigationBarsPadding()
            .padding(horizontal = 20.dp)
            .padding(bottom = 28.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        Text(
            if (form.isEditing) "Edit Shift" else "New Shift",
            style = MaterialTheme.typography.titleLarge,
            color = MaterialTheme.nayara.textPrimary,
        )

        FormField(
            value = form.name,
            onValueChange = vm::onNameChange,
            label = "Name",
            errors = fieldErrors["name"],
            helper = "Required · up to 80 characters",
        )

        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
            // Wire format stays "HH:MM" in the VM; the picker converts at the boundary.
            TimeField(
                label = "Shift Start Time",
                value = parseStartTime(form.startTime),
                onChange = { vm.onStartTimeChange(it.format(START_TIME_FORMAT)) },
                placeholder = "Pick a time",
                modifier = Modifier.fillMaxWidth(),
            )
            FieldError(fieldErrors["start_time"])
        }

        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Text("Shift Duration (hours)", style = MaterialTheme.typography.labelLarge)
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                OutlinedIconButton(onClick = {
                    haptics.tick()
                    vm.stepDuration(-0.25)
                }) {
                    Icon(Icons.Filled.Remove, contentDescription = "Decrease duration")
                }
                OutlinedTextField(
                    value = form.durationHours,
                    onValueChange = vm::onDurationChange,
                    singleLine = true,
                    isError = !fieldErrors["duration"].isNullOrEmpty(),
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
                    modifier = Modifier.weight(1f),
                )
                OutlinedIconButton(onClick = {
                    haptics.tick()
                    vm.stepDuration(0.25)
                }) {
                    Icon(Icons.Filled.Add, contentDescription = "Increase duration")
                }
            }
            FieldError(fieldErrors["duration"])
            Text(
                "Use hours like 6, 12, 24, or a custom value such as 7.5",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.nayara.textTertiary,
            )
        }

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text("Active", style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.nayara.textPrimary)
                Text(
                    "Inactive shifts stay in history but can't be assigned.",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.nayara.textTertiary,
                )
            }
            Switch(
                checked = form.active,
                onCheckedChange = {
                    haptics.tick()
                    vm.onActiveChange(it)
                },
            )
        }

        formError?.let { InlineErrorCard(it) }

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            NayaraOutlinedButton(onClick = onCancel, enabled = !saving, modifier = Modifier.weight(1f)) {
                Text("Cancel")
            }
            NayaraButton(onClick = vm::submitForm, loading = saving, modifier = Modifier.weight(1f)) {
                Text(if (form.isEditing) "Save" else "Create")
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

private val START_TIME_FORMAT: DateTimeFormatter = DateTimeFormatter.ofPattern("HH:mm")

/** "HH:MM" wire string → LocalTime for the picker; null when blank/malformed. */
private fun parseStartTime(value: String): LocalTime? {
    if (value.isBlank()) return null
    return runCatching { LocalTime.parse(value.trim(), START_TIME_FORMAT) }.getOrNull()
}
