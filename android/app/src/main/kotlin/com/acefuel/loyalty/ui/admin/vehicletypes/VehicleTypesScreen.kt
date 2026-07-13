package com.acefuel.loyalty.ui.admin.vehicletypes

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
import androidx.compose.material.icons.filled.Agriculture
import androidx.compose.material.icons.filled.DirectionsBus
import androidx.compose.material.icons.filled.DirectionsCar
import androidx.compose.material.icons.filled.LocalShipping
import androidx.compose.material.icons.filled.LocalTaxi
import androidx.compose.material.icons.filled.Remove
import androidx.compose.material.icons.filled.TwoWheeler
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilledIconButton
import androidx.compose.material3.FilterChip
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.RadioButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.SnackbarResult
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import com.acefuel.loyalty.core.di.LocalContainer
import com.acefuel.loyalty.ui.designsystem.ChipTone
import com.acefuel.loyalty.ui.designsystem.ConfirmDialog
import com.acefuel.loyalty.ui.designsystem.EmptyState
import com.acefuel.loyalty.ui.designsystem.ErrorState
import com.acefuel.loyalty.ui.designsystem.FormField
import com.acefuel.loyalty.ui.designsystem.InlineErrorCard
import com.acefuel.loyalty.ui.designsystem.NayaraCard
import com.acefuel.loyalty.ui.designsystem.NayaraPullToRefresh
import com.acefuel.loyalty.ui.designsystem.NayaraSnackbarHost
import com.acefuel.loyalty.ui.designsystem.NayaraTopBar
import com.acefuel.loyalty.ui.designsystem.SkeletonList
import com.acefuel.loyalty.ui.designsystem.StatusChip
import com.acefuel.loyalty.ui.designsystem.rememberHaptics
import com.acefuel.loyalty.ui.designsystem.showError
import com.acefuel.loyalty.ui.designsystem.showSuccess
import com.acefuel.loyalty.ui.theme.NayaraButton
import com.acefuel.loyalty.ui.theme.NayaraNumerals
import com.acefuel.loyalty.ui.theme.NayaraOutlinedButton
import com.acefuel.loyalty.ui.theme.NayaraSpacing
import com.acefuel.loyalty.ui.theme.nayara
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AdminVehicleTypesScreen(onBack: () -> Unit) {
    val container = LocalContainer.current
    val repo = remember {
        VehicleTypesRepository(
            container.retrofit.create(VehicleTypesApi::class.java),
            container.json,
        )
    }
    val vm: VehicleTypesViewModel =
        viewModel(factory = viewModelFactory { initializer { VehicleTypesViewModel(repo) } })
    val state by vm.state.collectAsStateWithLifecycle()

    val snackbar = remember { SnackbarHostState() }
    val haptics = rememberHaptics()
    val scope = rememberCoroutineScope()

    var pendingDelete by remember { mutableStateOf<VehicleTypeDto?>(null) }
    var showDiscardConfirm by remember { mutableStateOf(false) }
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)

    // Show first, consume after: consuming inside the effect nulls the key it
    // is launched on, which would cancel the still-suspended showSnackbar.
    LaunchedEffect(state.notice) {
        val msg = state.notice ?: return@LaunchedEffect
        haptics.confirm()
        snackbar.showSuccess(msg)
        vm.consumeNotice()
    }
    LaunchedEffect(state.actionError) {
        val msg = state.actionError ?: return@LaunchedEffect
        haptics.reject()
        snackbar.showError(msg)
        vm.consumeActionError()
    }
    LaunchedEffect(state.error) {
        val msg = state.error ?: return@LaunchedEffect
        if (state.items.isNotEmpty()) {
            haptics.reject()
            snackbar.showError(msg)
            vm.consumeError()
        }
    }
    // Optimistic delete: offer Undo, which re-creates the row server-side.
    // `deleted` is captured before consuming, so it survives the state reset.
    LaunchedEffect(state.deletedForUndo) {
        val deleted = state.deletedForUndo ?: return@LaunchedEffect
        haptics.confirm()
        val result = snackbar.showSuccess("Vehicle type deleted.", actionLabel = "Undo")
        vm.consumeDeleted()
        if (result == SnackbarResult.ActionPerformed) vm.undoDelete(deleted)
    }

    Scaffold(
        topBar = { NayaraTopBar(title = "Vehicle Types", onBack = onBack) },
        snackbarHost = { NayaraSnackbarHost(snackbar) },
        floatingActionButton = {
            if (!(state.loading && state.items.isEmpty())) {
                FloatingActionButton(onClick = { vm.openCreate() }) {
                    Icon(Icons.Filled.Add, contentDescription = "Add vehicle type")
                }
            }
        },
    ) { innerPadding ->
        Box(Modifier.fillMaxSize().padding(innerPadding)) {
            when {
                state.loading && state.items.isEmpty() ->
                    SkeletonList(Modifier.padding(NayaraSpacing.ScreenMargin), count = 6)

                state.error != null && state.items.isEmpty() ->
                    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        ErrorState(state.error!!, onRetry = vm::load)
                    }

                else -> NayaraPullToRefresh(
                    isRefreshing = state.refreshing,
                    onRefresh = vm::refresh,
                    modifier = Modifier.fillMaxSize(),
                ) {
                    LazyColumn(
                        modifier = Modifier.fillMaxSize().padding(horizontal = NayaraSpacing.ScreenMargin),
                        verticalArrangement = Arrangement.spacedBy(NayaraSpacing.Md),
                        contentPadding = PaddingValues(top = NayaraSpacing.Md, bottom = 96.dp),
                    ) {
                        if (state.items.isEmpty()) {
                            item(key = "empty") {
                                EmptyState(
                                    title = "No vehicle types yet",
                                    message = "Tap + to add one.",
                                    icon = Icons.Filled.DirectionsCar,
                                )
                            }
                        } else {
                            items(state.items, key = { "vt-${it.id}" }) { item ->
                                VehicleTypeRow(
                                    item = item,
                                    deleting = state.deletingId == item.id,
                                    onEdit = { vm.openEdit(item) },
                                    onDelete = { pendingDelete = item },
                                    modifier = Modifier.animateItem(),
                                )
                            }
                        }
                    }
                }
            }
        }
    }

    pendingDelete?.let { item ->
        ConfirmDialog(
            title = "Delete ${item.name}?",
            text = "This removes the vehicle type from new selections. Types still in use may be rejected by the server.",
            confirmLabel = "Delete",
            destructive = true,
            onConfirm = {
                pendingDelete = null
                vm.delete(item)
            },
            onDismiss = { pendingDelete = null },
        )
    }

    if (state.editorOpen) {
        ModalBottomSheet(
            onDismissRequest = {
                if (state.editorDirty) showDiscardConfirm = true else vm.closeEditor()
            },
            sheetState = sheetState,
        ) {
            VehicleTypeEditor(
                state = state,
                vm = vm,
                onCancel = { if (state.editorDirty) showDiscardConfirm = true else vm.closeEditor() },
            )
        }
    }

    if (showDiscardConfirm) {
        ConfirmDialog(
            title = "Discard changes?",
            text = "You have unsaved changes to this vehicle type. Discard them?",
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
}

@Composable
private fun VehicleTypeRow(
    item: VehicleTypeDto,
    deleting: Boolean,
    onEdit: () -> Unit,
    onDelete: () -> Unit,
    modifier: Modifier = Modifier,
) {
    NayaraCard(modifier = modifier.fillMaxWidth(), shape = MaterialTheme.shapes.large) {
        Row(Modifier.fillMaxWidth().padding(NayaraSpacing.Lg)) {
            Icon(
                imageVector = iconFor(item.iconName),
                contentDescription = null,
                tint = MaterialTheme.nayara.textBrand,
                modifier = Modifier.size(32.dp),
            )
            Spacer(Modifier.width(14.dp))
            Column(Modifier.weight(1f)) {
                Row(
                    Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(
                        item.name,
                        style = MaterialTheme.typography.titleSmall,
                        fontWeight = FontWeight.SemiBold,
                        modifier = Modifier.weight(1f),
                    )
                    StatusChip(
                        label = if (item.active) "Shown" else "Hidden",
                        tone = if (item.active) ChipTone.Success else ChipTone.Neutral,
                    )
                }
                Spacer(Modifier.height(4.dp))
                MetaLine("Short name: ${item.shortName}")
                MetaLine("App label: ${appLabelSourceLabel(item.appLabelSource)}")
                MetaLine("Icon: ${VehicleTypeIcons.labelFor(item.iconName)}")
                MetaLine("Minimum redeemable: ${item.minimumRedeemablePoints} points")
                item.rewardPointsPer100?.let { MetaLine("Reward override: $it pts / ₹100") }
                Text(
                    "Code: ${item.code}",
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.nayara.textTertiary,
                    modifier = Modifier.padding(top = 2.dp),
                )
                Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
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
        }
    }
}

@Composable
private fun MetaLine(text: String) {
    Text(
        text,
        style = MaterialTheme.typography.bodySmall,
        color = MaterialTheme.nayara.textSecondary,
    )
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun VehicleTypeEditor(
    state: VehicleTypesUiState,
    vm: VehicleTypesViewModel,
    onCancel: () -> Unit,
) {
    val haptics = rememberHaptics()
    val form = state.form
    Column(
        Modifier
            .fillMaxWidth()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 20.dp)
            .padding(bottom = 28.dp)
            .imePadding()
            .navigationBarsPadding(),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Text(
            if (state.isEditing) "Edit Vehicle Type" else "New Vehicle Type",
            style = MaterialTheme.typography.titleLarge,
            fontWeight = FontWeight.SemiBold,
        )

        FormField(
            value = form.name,
            onValueChange = vm::onNameChange,
            label = "Vehicle Type Name *",
            errors = state.nameError?.let(::listOf),
            keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Words),
        )

        FormField(
            value = form.shortName,
            onValueChange = vm::onShortNameChange,
            label = "Short Name",
            helper = "e.g. LMV",
        )

        // App label source ---------------------------------------------------
        Text("App Label", style = MaterialTheme.typography.titleMedium)
        AppLabelOption(
            selected = form.appLabelSource == "name",
            label = "Use Vehicle Type Name",
            onSelect = {
                haptics.tick()
                vm.onAppLabelSourceChange("name")
            },
        )
        AppLabelOption(
            selected = form.appLabelSource == "short_name",
            label = "Use Short Name",
            onSelect = {
                haptics.tick()
                vm.onAppLabelSourceChange("short_name")
            },
        )

        // Code (create only) --------------------------------------------------
        if (!state.isEditing) {
            FormField(
                value = form.code,
                onValueChange = vm::onCodeChange,
                label = "Code",
                helper = "Leave blank to generate from name. Once created, the code stays fixed.",
            )
        }

        // Icon picker ---------------------------------------------------------
        Text("Icon", style = MaterialTheme.typography.titleMedium)
        FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            VehicleTypeIcons.OPTIONS.forEach { (value, label) ->
                FilterChip(
                    selected = form.iconName == value,
                    onClick = {
                        haptics.tick()
                        vm.onIconChange(value)
                    },
                    leadingIcon = {
                        Icon(iconFor(value), contentDescription = null, modifier = Modifier.size(18.dp))
                    },
                    label = { Text(label) },
                )
            }
        }

        // Minimum redeemable points ------------------------------------------
        Text("Minimum Redeemable Points *", style = MaterialTheme.typography.titleMedium)
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(16.dp)) {
            FilledIconButton(
                onClick = {
                    haptics.tick()
                    vm.decrementMinimum()
                },
                enabled = form.minimumRedeemablePoints > 100,
            ) {
                Icon(Icons.Filled.Remove, contentDescription = "Decrease")
            }
            Text(
                "${form.minimumRedeemablePoints}",
                style = NayaraNumerals.Large,
                color = MaterialTheme.nayara.textPrimary,
            )
            FilledIconButton(onClick = {
                haptics.tick()
                vm.incrementMinimum()
            }) {
                Icon(Icons.Filled.Add, contentDescription = "Increase")
            }
        }
        Text(
            "In multiples of 100.",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.nayara.textTertiary,
        )

        // Show in app ---------------------------------------------------------
        Row(
            Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text("Show in app", style = MaterialTheme.typography.titleMedium)
            Switch(
                checked = form.active,
                onCheckedChange = {
                    haptics.tick()
                    vm.onActiveChange(it)
                },
            )
        }

        state.formError?.let { InlineErrorCard(it) }

        Spacer(Modifier.height(4.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            NayaraOutlinedButton(
                onClick = onCancel,
                enabled = !state.saving,
                modifier = Modifier.weight(1f),
            ) { Text("Cancel") }
            NayaraButton(
                onClick = { vm.save() },
                enabled = form.name.isNotBlank(),
                loading = state.saving,
                modifier = Modifier.weight(1f),
            ) { Text(if (state.isEditing) "Save Changes" else "Create") }
        }
    }
}

@Composable
private fun AppLabelOption(selected: Boolean, label: String, onSelect: () -> Unit) {
    Row(
        Modifier.fillMaxWidth().clickable(onClick = onSelect),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        RadioButton(selected = selected, onClick = onSelect)
        Text(label, style = MaterialTheme.typography.bodyLarge)
    }
}

private fun appLabelSourceLabel(source: String): String =
    if (source == "name") "Vehicle Type Name" else "Short Name"

private fun iconFor(iconName: String): ImageVector = when (iconName) {
    "ti-bike" -> Icons.Filled.TwoWheeler
    "custom-tuk-tuk" -> Icons.Filled.LocalTaxi
    "ti-car" -> Icons.Filled.DirectionsCar
    "custom-pickup-truck" -> Icons.Filled.LocalShipping
    "ti-truck" -> Icons.Filled.LocalShipping
    "custom-big-truck" -> Icons.Filled.LocalShipping
    "ti-bus" -> Icons.Filled.DirectionsBus
    "ti-tractor" -> Icons.Filled.Agriculture
    else -> Icons.Filled.DirectionsCar
}
