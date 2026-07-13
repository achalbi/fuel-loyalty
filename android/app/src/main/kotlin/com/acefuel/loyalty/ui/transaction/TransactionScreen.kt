package com.acefuel.loyalty.ui.transaction

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.CameraAlt
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.RadioButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
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
import com.acefuel.loyalty.core.network.dto.NozzleDto
import com.acefuel.loyalty.ui.theme.NayaraButton
import com.acefuel.loyalty.ui.theme.NayaraOutlinedButton
import com.acefuel.loyalty.ui.theme.nayara

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TransactionScreen(
    onBack: () -> Unit,
    onViewCustomer: (Long) -> Unit,
    onScanPlate: () -> Unit = {},
    scannedPlate: String? = null,
) {
    val container = LocalContainer.current
    val viewModel: TransactionViewModel = viewModel(
        factory = viewModelFactory { initializer { TransactionViewModel(container.staffRepository) } },
    )
    val state by viewModel.state.collectAsStateWithLifecycle()

    // A plate returned from the scanner flows in here: switch to vehicle mode,
    // fill the number, and run the lookup.
    androidx.compose.runtime.LaunchedEffect(scannedPlate) {
        if (!scannedPlate.isNullOrBlank()) {
            viewModel.setMode(MODE_VEHICLE)
            viewModel.onVehicleNumberChange(scannedPlate)
            viewModel.lookup()
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("New Transaction") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                },
            )
        },
    ) { innerPadding ->
        val result = state.result
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 20.dp, vertical = 16.dp),
        ) {
            if (result != null) {
                SuccessCard(
                    message = result.message,
                    onViewCustomer = { onViewCustomer(result.customer.id) },
                    onAnother = { viewModel.startAnother() },
                )
                return@Column
            }

            // Step 1 — Find (mode tabs + lookup)
            Text("1. Find customer", style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.SemiBold)
            Spacer(Modifier.height(8.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                FilterChip(selected = state.lookupMode == MODE_VEHICLE, onClick = { viewModel.setMode(MODE_VEHICLE) }, label = { Text("Vehicle Number") })
                FilterChip(selected = state.lookupMode == MODE_PHONE, onClick = { viewModel.setMode(MODE_PHONE) }, label = { Text("Phone Number") })
            }
            Spacer(Modifier.height(12.dp))

            Row(verticalAlignment = Alignment.Bottom) {
                if (state.lookupMode == MODE_VEHICLE) {
                    OutlinedTextField(
                        value = state.vehicleNumber,
                        onValueChange = viewModel::onVehicleNumberChange,
                        label = { Text("Vehicle number") },
                        singleLine = true,
                        trailingIcon = {
                            IconButton(onClick = onScanPlate) {
                                Icon(Icons.Filled.CameraAlt, contentDescription = "Scan plate")
                            }
                        },
                        modifier = Modifier.weight(1f),
                    )
                } else {
                    OutlinedTextField(
                        value = state.phoneNumber,
                        onValueChange = viewModel::onPhoneNumberChange,
                        label = { Text("Phone number") },
                        prefix = { Text("+91 ") },
                        singleLine = true,
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Phone),
                        modifier = Modifier.weight(1f),
                    )
                }
                Spacer(Modifier.width(12.dp))
                NayaraButton(
                    onClick = { viewModel.lookup() },
                    enabled = if (state.lookupMode == MODE_VEHICLE) state.vehicleNumber.length >= 6 else state.phoneNumber.length == 10,
                    loading = state.lookupLoading,
                ) {
                    Text("Look Up")
                }
            }
            state.lookupError?.let {
                Spacer(Modifier.height(10.dp))
                Text(it, color = MaterialTheme.colorScheme.error)
            }

            // Step 2 — Review / select
            if (state.lookupMode == MODE_VEHICLE && state.matches.isNotEmpty()) {
                Spacer(Modifier.height(20.dp))
                Text("2. Matching customer", style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.SemiBold)
                state.matches.forEachIndexed { index, match ->
                    SelectableRow(
                        selected = state.selectedMatchIndex == index,
                        onSelect = { viewModel.selectMatch(index) },
                        title = match.customer.name ?: "Customer",
                        subtitle = "+91 ${match.customer.phoneNumber} · ${match.customer.totalPoints} pts · ${match.fuelType}",
                    )
                }
            }

            val phoneCustomer = state.phoneCustomer
            if (state.lookupMode == MODE_PHONE && phoneCustomer != null) {
                Spacer(Modifier.height(20.dp))
                Text("2. Select a vehicle", style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.SemiBold)
                Text("${phoneCustomer.name} · ${phoneCustomer.totalPoints} pts", style = MaterialTheme.typography.bodySmall)
                if (phoneCustomer.vehicles.isEmpty()) {
                    Text("No vehicles on file for this customer.", color = MaterialTheme.colorScheme.error)
                }
                phoneCustomer.vehicles.forEach { v ->
                    SelectableRow(
                        selected = state.selectedVehicleId == v.id,
                        onSelect = { viewModel.selectVehicle(v.id) },
                        title = v.vehicleNumber,
                        subtitle = "${v.fuelType} · ${v.vehicleKind}",
                    )
                }
            }

            // Inactive-customer blocker
            if (state.selectedCustomer != null && !state.customerActive) {
                Spacer(Modifier.height(12.dp))
                Blocker("This customer is inactive. Activate the customer before recording a transaction.")
            }

            // Step 3 — Fuel details
            if (state.selectedVehicle != null && state.customerActive) {
                Spacer(Modifier.height(20.dp))
                Text("3. Fuel details", style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.SemiBold)
                Spacer(Modifier.height(8.dp))
                OutlinedTextField(
                    value = state.fuelAmount,
                    onValueChange = viewModel::onFuelAmountChange,
                    label = { Text("Fuel amount") },
                    prefix = { Text("₹ ") },
                    singleLine = true,
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
                    modifier = Modifier.fillMaxWidth(),
                )
                Spacer(Modifier.height(12.dp))
                Text("Payment", style = MaterialTheme.typography.labelLarge)
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    FilterChip(selected = state.paymentMode == "cash", onClick = { viewModel.setPayment("cash") }, label = { Text("Cash") })
                    FilterChip(selected = state.paymentMode == "credit", onClick = { viewModel.setPayment("credit") }, label = { Text("Credit") })
                }

                Spacer(Modifier.height(12.dp))
                NozzleSection(state, viewModel::selectNozzle)

                state.createError?.let {
                    Spacer(Modifier.height(12.dp))
                    Text(it, color = MaterialTheme.colorScheme.error)
                }

                Spacer(Modifier.height(16.dp))
                NayaraButton(
                    onClick = { viewModel.create() },
                    enabled = state.canSave,
                    loading = state.creating,
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    Text("Save Transaction")
                }
            }
        }
    }
}

@Composable
private fun NozzleSection(state: TxnUiState, onSelect: (Long) -> Unit) {
    if (!state.pumpReady) {
        Blocker("Set up My Pump with at least one active nozzle before recording transactions.")
        return
    }
    val options = state.nozzleOptions()
    Text("Nozzle", style = MaterialTheme.typography.labelLarge)
    if (options.isEmpty()) {
        Blocker("No nozzle is assigned to your pump for this vehicle's fuel type.")
        return
    }
    options.forEach { nozzle: NozzleDto ->
        SelectableRow(
            selected = state.selectedNozzleId == nozzle.id,
            onSelect = { onSelect(nozzle.id) },
            title = nozzle.displayName,
            subtitle = nozzle.fuelType ?: nozzle.fuelTypeCode.orEmpty(),
        )
    }
}

@Composable
private fun SelectableRow(selected: Boolean, onSelect: () -> Unit, title: String, subtitle: String) {
    Card(
        modifier = Modifier.fillMaxWidth().padding(top = 8.dp).selectable(selected = selected, onClick = onSelect),
        colors = CardDefaults.cardColors(
            containerColor = if (selected) MaterialTheme.colorScheme.primaryContainer else MaterialTheme.colorScheme.surfaceVariant,
        ),
    ) {
        Row(Modifier.padding(12.dp), verticalAlignment = Alignment.CenterVertically) {
            RadioButton(selected = selected, onClick = onSelect)
            Spacer(Modifier.width(8.dp))
            Column {
                Text(title, fontWeight = FontWeight.SemiBold)
                Text(subtitle, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.nayara.textSecondary)
            }
        }
    }
}

@Composable
private fun Blocker(message: String) {
    // Prerequisite not met — warning tokens, not error (DESIGN_BRIEF §5.5).
    Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.nayara.statusWarningContainer), modifier = Modifier.fillMaxWidth()) {
        Text(message, Modifier.padding(14.dp), color = MaterialTheme.nayara.statusOnWarningContainer)
    }
}

@Composable
private fun SuccessCard(message: String, onViewCustomer: () -> Unit, onAnother: () -> Unit) {
    // Earn moment — success/green tokens (DESIGN_BRIEF principle 4).
    Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.nayara.statusSuccessContainer), modifier = Modifier.fillMaxWidth()) {
        Column(Modifier.padding(20.dp)) {
            Text("Transaction saved", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold, color = MaterialTheme.nayara.statusOnSuccessContainer)
            Spacer(Modifier.height(8.dp))
            Text(message, color = MaterialTheme.nayara.statusOnSuccessContainer)
        }
    }
    Spacer(Modifier.height(16.dp))
    NayaraButton(onClick = onViewCustomer, modifier = Modifier.fillMaxWidth()) { Text("View Customer") }
    Spacer(Modifier.height(8.dp))
    NayaraOutlinedButton(onClick = onAnother, modifier = Modifier.fillMaxWidth()) { Text("New Transaction") }
}
