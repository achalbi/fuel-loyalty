package com.acefuel.loyalty.ui.admin.fueltypes

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.LocalGasStation
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
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
import com.acefuel.loyalty.ui.designsystem.EmptyState
import com.acefuel.loyalty.ui.designsystem.InlineErrorCard
import com.acefuel.loyalty.ui.designsystem.FormField
import com.acefuel.loyalty.ui.designsystem.NayaraCard
import com.acefuel.loyalty.ui.designsystem.NayaraPullToRefresh
import com.acefuel.loyalty.ui.designsystem.NayaraSnackbarHost
import com.acefuel.loyalty.ui.designsystem.NayaraTopBar
import com.acefuel.loyalty.ui.designsystem.SkeletonCard
import com.acefuel.loyalty.ui.designsystem.SkeletonList
import com.acefuel.loyalty.ui.designsystem.rememberHaptics
import com.acefuel.loyalty.ui.designsystem.showError
import com.acefuel.loyalty.ui.designsystem.showSuccess
import com.acefuel.loyalty.ui.theme.NayaraButton
import com.acefuel.loyalty.ui.theme.NayaraOutlinedButton
import com.acefuel.loyalty.ui.theme.NayaraSpacing
import com.acefuel.loyalty.ui.theme.nayara

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AdminFuelTypesScreen(onBack: () -> Unit) {
    val container = LocalContainer.current
    val repo = remember {
        FuelTypesRepository(container.retrofit.create(FuelTypesApi::class.java), container.json)
    }
    val vm: FuelTypesViewModel = viewModel(factory = viewModelFactory { initializer { FuelTypesViewModel(repo) } })
    val state by vm.state.collectAsStateWithLifecycle()

    val snackbar = remember { SnackbarHostState() }
    val haptics = rememberHaptics()
    val listState = rememberLazyListState()

    var pendingDelete by remember { mutableStateOf<FuelTypeDto?>(null) }

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
        if (state.fuelTypes.isNotEmpty()) {
            haptics.reject()
            snackbar.showError(msg)
            vm.consumeError()
        }
    }
    // Bring the top form into view when an Edit action engages it.
    LaunchedEffect(state.form.editingId) {
        if (state.form.editingId != null) listState.animateScrollToItem(0)
    }

    Scaffold(
        topBar = { NayaraTopBar(title = "Fuel Types", onBack = onBack) },
        snackbarHost = { NayaraSnackbarHost(snackbar) },
    ) { innerPadding ->
        when {
            state.loading && state.fuelTypes.isEmpty() && state.error == null ->
                Column(
                    modifier = Modifier.fillMaxSize().padding(innerPadding).padding(NayaraSpacing.ScreenMargin),
                    verticalArrangement = Arrangement.spacedBy(NayaraSpacing.Md),
                ) {
                    SkeletonCard(lines = 2)
                    SkeletonList(count = 5, showAvatar = false)
                }

            else -> NayaraPullToRefresh(
                isRefreshing = state.refreshing,
                onRefresh = vm::refresh,
                modifier = Modifier.fillMaxSize().padding(innerPadding),
            ) {
                LazyColumn(
                    state = listState,
                    modifier = Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(NayaraSpacing.ScreenMargin),
                    verticalArrangement = Arrangement.spacedBy(NayaraSpacing.Md),
                ) {
                    item(key = "form") { FuelTypeForm(state.form, vm) }

                    // Load failed with nothing to show: keep the form usable and
                    // offer retry inline instead of a full-screen error.
                    if (state.error != null && state.fuelTypes.isEmpty()) {
                        item(key = "load-error") {
                            InlineErrorCard(state.error!!, onRetry = vm::load)
                        }
                    }

                    item(key = "list-header") {
                        Text(
                            "Fuel Types",
                            style = MaterialTheme.typography.titleSmall,
                            color = MaterialTheme.nayara.textSecondary,
                        )
                    }

                    if (state.fuelTypes.isEmpty()) {
                        item(key = "empty") {
                            EmptyState(
                                title = "No fuel types yet",
                                message = "Add one with the form above.",
                                icon = Icons.Filled.LocalGasStation,
                            )
                        }
                    } else {
                        items(state.fuelTypes, key = { "ft-${it.id}" }) { fuelType ->
                            FuelTypeCard(
                                fuelType = fuelType,
                                editing = state.form.editingId == fuelType.id,
                                deleting = state.deletingId == fuelType.id,
                                onEdit = { vm.startEdit(fuelType) },
                                onDelete = { pendingDelete = fuelType },
                                modifier = Modifier.animateItem(),
                            )
                        }
                    }
                }
            }
        }
    }

    pendingDelete?.let { fuelType ->
        ConfirmDialog(
            title = "Remove ${fuelType.name}?",
            text = "Fuel types still used by vehicles or pump nozzles can't be removed.",
            confirmLabel = "Remove",
            destructive = true,
            onConfirm = {
                pendingDelete = null
                vm.deleteFuelType(fuelType.id)
            },
            onDismiss = { pendingDelete = null },
        )
    }
}

@Composable
private fun FuelTypeForm(form: FuelTypeFormState, vm: FuelTypesViewModel) {
    val haptics = rememberHaptics()
    NayaraCard(modifier = Modifier.fillMaxWidth(), shape = MaterialTheme.shapes.large) {
        Column(Modifier.padding(NayaraSpacing.Lg), verticalArrangement = Arrangement.spacedBy(NayaraSpacing.Md)) {
            Text(
                if (form.isEdit) "Edit Fuel Type" else "Add Fuel Type",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.SemiBold,
            )

            FormField(
                value = form.name,
                onValueChange = vm::onNameChange,
                label = "Fuel Type Name",
                errors = form.error?.let(::listOf),
                helper = if (form.isEdit && form.editingCode != null) {
                    "Internal code (${form.editingCode}) is fixed and can't be changed."
                } else {
                    "The internal code is auto-generated on first save, then fixed."
                },
            )

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Column(Modifier.weight(1f)) {
                    Text("Show in app", style = MaterialTheme.typography.bodyLarge)
                    Text(
                        "Available for new vehicle and nozzle selections.",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.nayara.textSecondary,
                    )
                }
                Switch(
                    checked = form.showInApp,
                    onCheckedChange = {
                        haptics.tick()
                        vm.onShowInAppChange(it)
                    },
                )
            }

            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                if (form.isEdit) {
                    NayaraOutlinedButton(
                        onClick = { vm.cancelEdit() },
                        enabled = !form.saving,
                        modifier = Modifier.weight(1f),
                    ) { Text("Cancel") }
                }
                NayaraButton(
                    onClick = { vm.submitForm() },
                    loading = form.saving,
                    enabled = !form.saving && form.name.isNotBlank(),
                    modifier = Modifier.weight(1f),
                ) {
                    Text(if (form.isEdit) "Save Changes" else "Add Fuel Type")
                }
            }
        }
    }
}

@Composable
private fun FuelTypeCard(
    fuelType: FuelTypeDto,
    editing: Boolean,
    deleting: Boolean,
    onEdit: () -> Unit,
    onDelete: () -> Unit,
    modifier: Modifier = Modifier,
) {
    // The row being edited sinks into a flat tonal surface; every other row
    // lifts off the canvas with the standard soft-shadow card.
    val body: @Composable ColumnScope.() -> Unit = {
        Column(Modifier.padding(NayaraSpacing.Lg), verticalArrangement = Arrangement.spacedBy(NayaraSpacing.Sm)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    fuelType.name,
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold,
                    modifier = Modifier.weight(1f),
                )
                ActiveChip(active = fuelType.active)
            }
            Text(
                "Code: ${fuelType.code}",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.nayara.textSecondary,
            )
            Text(
                if (fuelType.active) "Shown in app." else "Hidden from new selections.",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.nayara.textTertiary,
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
    if (editing) {
        Card(
            modifier = modifier.fillMaxWidth(),
            colors = CardDefaults.cardColors(containerColor = MaterialTheme.nayara.bgSurfaceSunken),
            content = body,
        )
    } else {
        NayaraCard(modifier = modifier.fillMaxWidth(), shape = MaterialTheme.shapes.large, content = body)
    }
}
