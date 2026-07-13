package com.acefuel.loyalty.ui.admin.fueltypes

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.AssistChip
import androidx.compose.material3.AssistChipDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
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
import com.acefuel.loyalty.ui.theme.NayaraButton
import com.acefuel.loyalty.ui.theme.NayaraOutlinedButton
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

    var pendingDelete by remember { mutableStateOf<FuelTypeDto?>(null) }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Fuel Types") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                },
            )
        },
    ) { innerPadding ->
        when {
            state.loading && state.fuelTypes.isEmpty() && state.error == null ->
                Box(
                    modifier = Modifier.fillMaxSize().padding(innerPadding),
                    contentAlignment = Alignment.Center,
                ) { CircularProgressIndicator() }

            else -> LazyColumn(
                modifier = Modifier.fillMaxSize().padding(innerPadding),
                contentPadding = PaddingValues(16.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                item(key = "form") { FuelTypeForm(state.form, vm) }

                state.notice?.let { msg ->
                    item(key = "notice") { NoticeCard(msg, onDismiss = { vm.dismissNotice() }) }
                }
                state.actionError?.let { msg ->
                    item(key = "action-error") { ErrorCard(msg, onDismiss = { vm.dismissActionError() }) }
                }

                item(key = "list-header") {
                    Text(
                        "Fuel Types",
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.SemiBold,
                    )
                }

                when {
                    state.error != null && state.fuelTypes.isEmpty() ->
                        item(key = "load-error") {
                            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                                ErrorCard(state.error!!, onDismiss = null)
                                NayaraButton(onClick = vm::load, modifier = Modifier.fillMaxWidth()) {
                                    Text("Retry")
                                }
                            }
                        }

                    state.fuelTypes.isEmpty() ->
                        item(key = "empty") {
                            Text(
                                "No fuel types have been added yet.",
                                style = MaterialTheme.typography.bodyMedium,
                                color = MaterialTheme.nayara.textSecondary,
                            )
                        }

                    else -> items(state.fuelTypes, key = { "ft-${it.id}" }) { fuelType ->
                        FuelTypeCard(
                            fuelType = fuelType,
                            editing = state.form.editingId == fuelType.id,
                            deleting = state.deletingId == fuelType.id,
                            onEdit = { vm.startEdit(fuelType) },
                            onDelete = { pendingDelete = fuelType },
                        )
                    }
                }
            }
        }
    }

    pendingDelete?.let { fuelType ->
        AlertDialog(
            onDismissRequest = { pendingDelete = null },
            title = { Text("Remove ${fuelType.name}?") },
            text = {
                Text("Fuel types still used by vehicles or pump nozzles can't be removed.")
            },
            confirmButton = {
                TextButton(onClick = {
                    vm.deleteFuelType(fuelType.id)
                    pendingDelete = null
                }) { Text("Remove", color = MaterialTheme.colorScheme.error) }
            },
            dismissButton = {
                TextButton(onClick = { pendingDelete = null }) { Text("Cancel") }
            },
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun FuelTypeForm(form: FuelTypeFormState, vm: FuelTypesViewModel) {
    Card(Modifier.fillMaxWidth()) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Text(
                if (form.isEdit) "Edit Fuel Type" else "Add Fuel Type",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.SemiBold,
            )

            OutlinedTextField(
                value = form.name,
                onValueChange = vm::onNameChange,
                label = { Text("Fuel Type Name") },
                singleLine = true,
                isError = form.error != null,
                supportingText = {
                    Text(
                        if (form.isEdit && form.editingCode != null) {
                            "Internal code (${form.editingCode}) is fixed and can't be changed."
                        } else {
                            "The internal code is auto-generated on first save, then fixed."
                        },
                    )
                },
                modifier = Modifier.fillMaxWidth(),
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
                Switch(checked = form.showInApp, onCheckedChange = vm::onShowInAppChange)
            }

            form.error?.let {
                Text(it, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.error)
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

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun FuelTypeCard(
    fuelType: FuelTypeDto,
    editing: Boolean,
    deleting: Boolean,
    onEdit: () -> Unit,
    onDelete: () -> Unit,
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = if (editing) {
            CardDefaults.cardColors(containerColor = MaterialTheme.nayara.bgSurfaceSunken)
        } else {
            CardDefaults.cardColors()
        },
    ) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
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
                StatusChip(active = fuelType.active)
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
                TextButton(onClick = onEdit) { Text("Edit") }
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
private fun StatusChip(active: Boolean) {
    val container = if (active) MaterialTheme.nayara.statusSuccessContainer else MaterialTheme.nayara.bgSurfaceSunken
    val content = if (active) MaterialTheme.nayara.statusOnSuccessContainer else MaterialTheme.nayara.textSecondary
    AssistChip(
        onClick = {},
        enabled = false,
        label = { Text(if (active) "Active" else "Inactive") },
        colors = AssistChipDefaults.assistChipColors(
            disabledContainerColor = container,
            disabledLabelColor = content,
        ),
    )
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
