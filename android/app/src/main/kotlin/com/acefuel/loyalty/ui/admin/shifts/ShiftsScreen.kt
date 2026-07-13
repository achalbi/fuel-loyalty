package com.acefuel.loyalty.ui.admin.shifts

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
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.Remove
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ExtendedFloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedIconButton
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
import androidx.compose.runtime.remember
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
import com.acefuel.loyalty.ui.theme.NayaraButton
import com.acefuel.loyalty.ui.theme.NayaraOutlinedButton
import com.acefuel.loyalty.ui.theme.nayara

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AdminShiftsScreen(onBack: () -> Unit) {
    val container = LocalContainer.current
    val repo = remember {
        ShiftsRepository(container.retrofit.create(ShiftsApi::class.java), container.json)
    }
    val vm: ShiftsViewModel = viewModel(factory = viewModelFactory { initializer { ShiftsViewModel(repo) } })
    val state by vm.state.collectAsStateWithLifecycle()

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Shifts") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                },
            )
        },
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
            state.loading && state.templates.isEmpty() ->
                Box(bodyModifier, contentAlignment = Alignment.Center) { CircularProgressIndicator() }

            state.templates.isEmpty() && state.error != null ->
                Box(bodyModifier.padding(24.dp)) { ErrorCard(state.error!!, onRetry = vm::load) }

            state.templates.isEmpty() ->
                Box(bodyModifier.padding(24.dp), contentAlignment = Alignment.Center) {
                    Text(
                        "No shift templates created yet.",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.nayara.textSecondary,
                    )
                }

            else -> LazyColumn(
                modifier = bodyModifier,
                contentPadding = PaddingValues(start = 16.dp, top = 16.dp, end = 16.dp, bottom = 96.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                state.error?.let { err -> item(key = "error") { ErrorCard(err, onRetry = vm::load) } }
                items(state.templates, key = { "shift-${it.id}" }) { template ->
                    ShiftCard(template, onEdit = { vm.openEdit(template) })
                }
            }
        }
    }

    val form = state.form
    if (form != null) {
        ShiftFormSheet(
            form = form,
            saving = state.saving,
            formError = state.formError,
            vm = vm,
        )
    }
}

@Composable
private fun ShiftCard(template: ShiftTemplateDto, onEdit: () -> Unit) {
    Card(modifier = Modifier.fillMaxWidth()) {
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
                StatusPill(template.active)
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

@Composable
private fun StatusPill(active: Boolean) {
    val container = if (active) MaterialTheme.nayara.statusSuccessContainer else MaterialTheme.colorScheme.surfaceVariant
    val content = if (active) MaterialTheme.nayara.statusOnSuccessContainer else MaterialTheme.colorScheme.onSurfaceVariant
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
private fun ErrorCard(message: String, onRetry: () -> Unit) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.errorContainer,
            contentColor = MaterialTheme.colorScheme.onErrorContainer,
        ),
    ) {
        Column(
            modifier = Modifier.padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Text(message, style = MaterialTheme.typography.bodyMedium)
            TextButton(onClick = onRetry) { Text("Retry") }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ShiftFormSheet(
    form: ShiftFormState,
    saving: Boolean,
    formError: String?,
    vm: ShiftsViewModel,
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    ModalBottomSheet(onDismissRequest = vm::dismissForm, sheetState = sheetState) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 20.dp)
                .padding(bottom = 28.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            Text(
                if (form.isEditing) "Edit Shift" else "New Shift",
                style = MaterialTheme.typography.titleLarge,
                color = MaterialTheme.nayara.textPrimary,
            )

            OutlinedTextField(
                value = form.name,
                onValueChange = vm::onNameChange,
                label = { Text("Name") },
                singleLine = true,
                supportingText = { Text("Required · up to 80 characters") },
                modifier = Modifier.fillMaxWidth(),
            )

            OutlinedTextField(
                value = form.startTime,
                onValueChange = vm::onStartTimeChange,
                label = { Text("Shift Start Time") },
                placeholder = { Text("HH:MM") },
                singleLine = true,
                supportingText = { Text("24-hour clock, e.g. 06:00 or 14:30") },
                modifier = Modifier.fillMaxWidth(),
            )

            Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Text("Shift Duration (hours)", style = MaterialTheme.typography.labelLarge)
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    OutlinedIconButton(onClick = { vm.stepDuration(-0.25) }) {
                        Icon(Icons.Filled.Remove, contentDescription = "Decrease duration")
                    }
                    OutlinedTextField(
                        value = form.durationHours,
                        onValueChange = vm::onDurationChange,
                        singleLine = true,
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
                        modifier = Modifier.weight(1f),
                    )
                    OutlinedIconButton(onClick = { vm.stepDuration(0.25) }) {
                        Icon(Icons.Filled.Add, contentDescription = "Increase duration")
                    }
                }
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
                Switch(checked = form.active, onCheckedChange = vm::onActiveChange)
            }

            formError?.let {
                Text(it, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.error)
            }

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                NayaraOutlinedButton(onClick = vm::dismissForm, enabled = !saving, modifier = Modifier.weight(1f)) {
                    Text("Cancel")
                }
                NayaraButton(onClick = vm::submitForm, loading = saving, modifier = Modifier.weight(1f)) {
                    Text(if (form.isEditing) "Save" else "Create")
                }
            }
        }
    }
}
