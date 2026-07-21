package com.acefuel.loyalty.ui.visitentry

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
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
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.foundation.text.KeyboardOptions
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import com.acefuel.loyalty.core.di.LocalContainer
import com.acefuel.loyalty.ui.designsystem.FormField
import com.acefuel.loyalty.ui.designsystem.NayaraSnackbarHost
import com.acefuel.loyalty.ui.designsystem.NayaraTopBar
import com.acefuel.loyalty.ui.designsystem.PickerField
import com.acefuel.loyalty.ui.designsystem.rememberHaptics
import com.acefuel.loyalty.ui.designsystem.showError
import com.acefuel.loyalty.ui.designsystem.showSuccess
import com.acefuel.loyalty.ui.theme.NayaraButton
import com.acefuel.loyalty.ui.theme.NayaraSpacing
import com.acefuel.loyalty.ui.theme.nayara

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun VisitEntryScreen(onBack: () -> Unit) {
    val container = LocalContainer.current
    val viewModel: VisitEntryViewModel = viewModel(
        factory = viewModelFactory { initializer { VisitEntryViewModel(container.staffRepository) } },
    )
    val state by viewModel.state.collectAsStateWithLifecycle()
    val snackbar = remember { SnackbarHostState() }
    val haptics = rememberHaptics()

    LaunchedEffect(state.success) {
        val message = state.success ?: return@LaunchedEffect
        haptics.confirm()
        snackbar.showSuccess(message)
        viewModel.consumeSuccess()
    }
    LaunchedEffect(state.error) {
        val message = state.error ?: return@LaunchedEffect
        haptics.reject()
        snackbar.showError(message)
        viewModel.consumeError()
    }

    Scaffold(
        topBar = { NayaraTopBar(title = "Capture Visit", onBack = onBack) },
        snackbarHost = { NayaraSnackbarHost(snackbar) },
    ) { innerPadding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = NayaraSpacing.ScreenMargin, vertical = NayaraSpacing.Md),
            verticalArrangement = Arrangement.spacedBy(NayaraSpacing.Md),
        ) {
            Text(
                "Litres are the source of truth — the ₹ value is settled later from the catalog price.",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.nayara.textSecondary,
            )

            FormField(
                value = state.vehicleNumber,
                onValueChange = viewModel::onVehicleNumber,
                label = "Vehicle Number",
                helper = "A registered plate auto-links the customer.",
                keyboardOptions = KeyboardOptions(
                    capitalization = KeyboardCapitalization.Characters,
                    imeAction = ImeAction.Next,
                ),
            )

            Row(horizontalArrangement = Arrangement.spacedBy(NayaraSpacing.Md)) {
                FormField(
                    value = state.litres,
                    onValueChange = viewModel::onLitres,
                    label = "Litres",
                    modifier = Modifier.weight(1f),
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal, imeAction = ImeAction.Next),
                )
                FuelPicker(state, viewModel, modifier = Modifier.weight(1f))
            }

            PumpPicker(state, viewModel)

            FormField(
                value = state.discount,
                onValueChange = viewModel::onDiscount,
                label = "Discount (₹)",
                helper = "Promised at the pump; flows to settlement.",
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal, imeAction = ImeAction.Next),
            )

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text("Fleet / OTP visit", style = MaterialTheme.typography.bodyLarge)
                Switch(checked = state.fleetOtp, onCheckedChange = viewModel::onFleetOtp)
            }

            SectionLabel("Driver")
            FormField(state.driverName, viewModel::onDriverName, "Driver name")
            FormField(
                state.driverPhone, viewModel::onDriverPhone, "Driver mobile",
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Phone, imeAction = ImeAction.Next),
            )

            HorizontalDivider()
            SectionLabel("Fleet / Transport (optional)")
            Row(horizontalArrangement = Arrangement.spacedBy(NayaraSpacing.Md)) {
                FormField(state.transportName, viewModel::onTransportName, "Transport name", modifier = Modifier.weight(1.4f))
                FormField(
                    state.approxVehicles, viewModel::onApproxVehicles, "Approx #",
                    modifier = Modifier.weight(1f),
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number, imeAction = ImeAction.Next),
                )
            }
            FormField(state.managerName, viewModel::onManagerName, "Manager name")
            FormField(
                state.managerPhone, viewModel::onManagerPhone, "Manager mobile",
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Phone, imeAction = ImeAction.Next),
            )
            FormField(state.ownerName, viewModel::onOwnerName, "Owner name")
            FormField(
                state.ownerPhone, viewModel::onOwnerPhone, "Owner mobile",
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Phone, imeAction = ImeAction.Done),
            )

            NayaraButton(
                onClick = viewModel::submit,
                enabled = state.canSubmit,
                loading = state.submitting,
                modifier = Modifier.fillMaxWidth(),
            ) {
                Text("Capture Visit")
            }
            Spacer(Modifier.width(NayaraSpacing.Md))
        }
    }
}

@Composable
private fun SectionLabel(text: String) {
    Text(
        text,
        style = MaterialTheme.typography.titleSmall,
        fontWeight = FontWeight.SemiBold,
        color = MaterialTheme.nayara.textSecondary,
    )
}

@Composable
private fun FuelPicker(state: VisitEntryUiState, viewModel: VisitEntryViewModel, modifier: Modifier = Modifier) {
    var open by remember { mutableStateOf(false) }
    val label = state.fuelTypes.firstOrNull { it.code == state.fuelTypeCode }?.label ?: "—"
    Box(modifier) {
        PickerField(label = "Fuel", value = label, onClick = { open = true })
        DropdownMenu(expanded = open, onDismissRequest = { open = false }) {
            DropdownMenuItem(text = { Text("—") }, onClick = { viewModel.onFuelType(null); open = false })
            state.fuelTypes.forEach { fuel ->
                DropdownMenuItem(
                    text = { Text(fuel.label) },
                    onClick = { viewModel.onFuelType(fuel.code); open = false },
                )
            }
        }
    }
}

@Composable
private fun PumpPicker(state: VisitEntryUiState, viewModel: VisitEntryViewModel) {
    var open by remember { mutableStateOf(false) }
    val selected = state.pumps.firstOrNull { it.id == state.fuelPumpId }
    val label = selected?.displayName ?: "My Pump (default)"
    Box(Modifier.fillMaxWidth()) {
        PickerField(label = "Pump", value = label, onClick = { open = true })
        DropdownMenu(expanded = open, onDismissRequest = { open = false }) {
            DropdownMenuItem(
                text = { Text("My Pump (default)") },
                onClick = { viewModel.onPump(null); open = false },
            )
            state.pumps.forEach { pump ->
                DropdownMenuItem(
                    text = { Text(pump.displayName) },
                    onClick = { viewModel.onPump(pump.id); open = false },
                )
            }
        }
    }
}
