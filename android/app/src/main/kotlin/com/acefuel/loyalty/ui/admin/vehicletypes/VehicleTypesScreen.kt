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
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Agriculture
import androidx.compose.material.icons.filled.DirectionsBus
import androidx.compose.material.icons.filled.DirectionsCar
import androidx.compose.material.icons.filled.LocalShipping
import androidx.compose.material.icons.filled.LocalTaxi
import androidx.compose.material.icons.filled.Remove
import androidx.compose.material.icons.filled.TwoWheeler
import androidx.compose.material3.AssistChip
import androidx.compose.material3.AssistChipDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilledIconButton
import androidx.compose.material3.FilterChip
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.RadioButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.foundation.text.KeyboardOptions
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

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Vehicle Types") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                },
            )
        },
        floatingActionButton = {
            FloatingActionButton(onClick = { vm.openCreate() }) {
                Icon(Icons.Filled.Add, contentDescription = "Add vehicle type")
            }
        },
    ) { innerPadding ->
        Box(Modifier.fillMaxSize().padding(innerPadding)) {
            when {
                state.loading && state.items.isEmpty() ->
                    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        CircularProgressIndicator()
                    }
                else -> LazyColumn(
                    modifier = Modifier.fillMaxSize().padding(horizontal = 16.dp),
                    verticalArrangement = Arrangement.spacedBy(10.dp),
                    contentPadding = PaddingValues(top = 12.dp, bottom = 96.dp),
                ) {
                    state.error?.let { message ->
                        item(key = "error-banner") { ErrorBanner(message, onDismiss = vm::dismissError) }
                    }

                    if (state.items.isEmpty() && !state.loading) {
                        item(key = "empty") {
                            Text(
                                "No vehicle types yet. Tap + to add one.",
                                style = MaterialTheme.typography.bodyMedium,
                                color = MaterialTheme.nayara.textSecondary,
                                modifier = Modifier.padding(8.dp),
                            )
                        }
                    } else {
                        items(state.items, key = { "vt-${it.id}" }) { item ->
                            VehicleTypeRow(
                                item = item,
                                deleting = state.deletingId == item.id,
                                onEdit = { vm.openEdit(item) },
                                onDelete = { vm.delete(item.id) },
                            )
                        }
                    }
                }
            }
        }
    }

    if (state.editorOpen) {
        val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
        ModalBottomSheet(onDismissRequest = { vm.closeEditor() }, sheetState = sheetState) {
            VehicleTypeEditor(state = state, vm = vm)
        }
    }
}

@Composable
private fun ErrorBanner(message: String, onDismiss: () -> Unit) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = androidx.compose.material3.CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.errorContainer,
        ),
    ) {
        Row(
            Modifier.fillMaxWidth().padding(14.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Text(
                message,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onErrorContainer,
                modifier = Modifier.weight(1f),
            )
            TextButton(onClick = onDismiss) { Text("Dismiss") }
        }
    }
}

@Composable
private fun VehicleTypeRow(
    item: VehicleTypeDto,
    deleting: Boolean,
    onEdit: () -> Unit,
    onDelete: () -> Unit,
) {
    Card(Modifier.fillMaxWidth()) {
        Row(Modifier.fillMaxWidth().padding(16.dp)) {
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
                    AssistChip(
                        onClick = {},
                        enabled = false,
                        label = { Text(if (item.active) "Shown" else "Hidden") },
                        colors = if (item.active) {
                            AssistChipDefaults.assistChipColors(
                                disabledLabelColor = MaterialTheme.nayara.statusSuccessText,
                            )
                        } else {
                            AssistChipDefaults.assistChipColors(
                                disabledLabelColor = MaterialTheme.nayara.textTertiary,
                            )
                        },
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
                            Text("Delete", color = MaterialTheme.colorScheme.error)
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
private fun VehicleTypeEditor(state: VehicleTypesUiState, vm: VehicleTypesViewModel) {
    val form = state.form
    Column(
        Modifier
            .fillMaxWidth()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 20.dp)
            .padding(bottom = 28.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Text(
            if (state.isEditing) "Edit Vehicle Type" else "New Vehicle Type",
            style = MaterialTheme.typography.titleLarge,
            fontWeight = FontWeight.SemiBold,
        )

        OutlinedTextField(
            value = form.name,
            onValueChange = vm::onNameChange,
            label = { Text("Vehicle Type Name *") },
            singleLine = true,
            keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Words),
            modifier = Modifier.fillMaxWidth(),
        )

        OutlinedTextField(
            value = form.shortName,
            onValueChange = vm::onShortNameChange,
            label = { Text("Short Name") },
            placeholder = { Text("LMV") },
            singleLine = true,
            modifier = Modifier.fillMaxWidth(),
        )

        // App label source ---------------------------------------------------
        Text("App Label", style = MaterialTheme.typography.titleMedium)
        AppLabelOption(
            selected = form.appLabelSource == "name",
            label = "Use Vehicle Type Name",
            onSelect = { vm.onAppLabelSourceChange("name") },
        )
        AppLabelOption(
            selected = form.appLabelSource == "short_name",
            label = "Use Short Name",
            onSelect = { vm.onAppLabelSourceChange("short_name") },
        )

        // Code (create only) --------------------------------------------------
        if (!state.isEditing) {
            OutlinedTextField(
                value = form.code,
                onValueChange = vm::onCodeChange,
                label = { Text("Code") },
                singleLine = true,
                supportingText = {
                    Text("Leave blank to generate from name. Once created, the code stays fixed.")
                },
                modifier = Modifier.fillMaxWidth(),
            )
        }

        // Icon picker ---------------------------------------------------------
        Text("Icon", style = MaterialTheme.typography.titleMedium)
        FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            VehicleTypeIcons.OPTIONS.forEach { (value, label) ->
                FilterChip(
                    selected = form.iconName == value,
                    onClick = { vm.onIconChange(value) },
                    label = { Text(label) },
                )
            }
        }

        // Minimum redeemable points ------------------------------------------
        Text("Minimum Redeemable Points *", style = MaterialTheme.typography.titleMedium)
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(16.dp)) {
            FilledIconButton(
                onClick = vm::decrementMinimum,
                enabled = form.minimumRedeemablePoints > 100,
            ) {
                Icon(Icons.Filled.Remove, contentDescription = "Decrease")
            }
            Text(
                "${form.minimumRedeemablePoints}",
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.SemiBold,
            )
            FilledIconButton(onClick = vm::incrementMinimum) {
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
            Switch(checked = form.active, onCheckedChange = vm::onActiveChange)
        }

        state.formError?.let {
            Text(it, color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodyMedium)
        }

        Spacer(Modifier.height(4.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            NayaraOutlinedButton(
                onClick = { vm.closeEditor() },
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
