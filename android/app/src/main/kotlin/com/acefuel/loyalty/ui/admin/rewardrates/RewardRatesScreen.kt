package com.acefuel.loyalty.ui.admin.rewardrates

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
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
import com.acefuel.loyalty.ui.theme.nayara

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AdminRewardRatesScreen(onBack: () -> Unit) {
    val container = LocalContainer.current
    val repo = remember {
        RewardRatesRepository(container.retrofit.create(RewardRatesApi::class.java), container.json)
    }
    val vm: RewardRatesViewModel = viewModel(factory = viewModelFactory { initializer { RewardRatesViewModel(repo) } })
    val state by vm.state.collectAsStateWithLifecycle()

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Reward Rates") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                },
            )
        },
    ) { innerPadding ->
        when {
            state.loading -> Box(
                modifier = Modifier.fillMaxSize().padding(innerPadding),
                contentAlignment = Alignment.Center,
            ) {
                CircularProgressIndicator()
            }

            state.loadError != null -> Column(
                modifier = Modifier.fillMaxSize().padding(innerPadding).padding(20.dp),
            ) {
                ErrorCard(state.loadError!!)
                Spacer(Modifier.height(16.dp))
                NayaraButton(onClick = vm::load, modifier = Modifier.fillMaxWidth()) { Text("Retry") }
            }

            else -> Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(innerPadding)
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = 20.dp, vertical = 16.dp),
                verticalArrangement = Arrangement.spacedBy(20.dp),
            ) {
                RewardSettingsForm(state, vm)
                VehicleOverridesForm(state, vm)
                FuelFallbackForm(state, vm)
                Spacer(Modifier.height(8.dp))
            }
        }
    }
}

// ---- (A) Reward settings ----

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun RewardSettingsForm(state: RewardRatesUiState, vm: RewardRatesViewModel) {
    SectionCard(
        title = "Reward Settings",
        subtitle = "Points are earned per rupee unit spent. Cash value and minimum redeemable points are optional.",
    ) {
        OutlinedTextField(
            value = state.rupeesPerRewardUnit,
            onValueChange = vm::onRupeesChange,
            label = { Text("Rupee Unit") },
            prefix = { Text("Rs. ") },
            singleLine = true,
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
            supportingText = { Text("Points are awarded for every Rs. spent on this unit (min 1).") },
            modifier = Modifier.fillMaxWidth(),
        )
        OutlinedTextField(
            value = state.minimumRedeemablePoints,
            onValueChange = vm::onMinRedeemChange,
            label = { Text("Minimum Redeemable Points") },
            singleLine = true,
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
            supportingText = { Text("Leave blank to keep using existing vehicle-type minimums.") },
            modifier = Modifier.fillMaxWidth(),
        )
        OutlinedTextField(
            value = state.cashValuePerPoint,
            onValueChange = vm::onCashChange,
            label = { Text("1 Point Cash Reward") },
            prefix = { Text("Rs. ") },
            singleLine = true,
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
            supportingText = { Text("Optional. Cash value of a single point.") },
            modifier = Modifier.fillMaxWidth(),
        )

        state.settingsError?.let { ErrorCard(it) }
        state.settingsMessage?.let { SuccessCard(it) }

        val rupees = state.rupeesPerRewardUnit.toIntOrNull()
        val minOk = state.minimumRedeemablePoints.isBlank() ||
            (state.minimumRedeemablePoints.toIntOrNull()?.let { it > 0 } == true)
        val cashOk = state.cashValuePerPoint.isBlank() || state.cashValuePerPoint.toDoubleOrNull() != null
        val canSave = rupees != null && rupees >= 1 && minOk && cashOk

        NayaraButton(
            onClick = vm::saveSettings,
            enabled = canSave,
            loading = state.savingSettings,
            modifier = Modifier.fillMaxWidth(),
        ) {
            Text("Save Reward Settings")
        }
    }
}

// ---- (B) Vehicle-type overrides ----

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun VehicleOverridesForm(state: RewardRatesUiState, vm: RewardRatesViewModel) {
    SectionCard(
        title = "Vehicle Type Reward Overrides",
        subtitle = "Points earned per rupee unit for each vehicle type. Leave blank to fall back to the fuel-type rate.",
    ) {
        if (state.vehicleTypes.isEmpty()) {
            Text(
                "No vehicle types are configured yet.",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.nayara.textSecondary,
            )
        } else {
            val suffix = state.rewardUnit?.let { "pts / Rs.$it" } ?: "pts"
            state.vehicleTypes.forEach { vt ->
                OutlinedTextField(
                    value = state.vehicleInputs[vt.code].orEmpty(),
                    onValueChange = { vm.onVehicleInputChange(vt.code, it) },
                    label = { Text(vt.label) },
                    suffix = { Text(suffix) },
                    singleLine = true,
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                    modifier = Modifier.fillMaxWidth(),
                )
            }

            state.vehicleError?.let { ErrorCard(it) }
            state.vehicleMessage?.let { SuccessCard(it) }

            NayaraButton(
                onClick = vm::saveVehicleRates,
                loading = state.savingVehicle,
                modifier = Modifier.fillMaxWidth(),
            ) {
                Text("Save Vehicle Type Reward Rates")
            }
        }
    }
}

// ---- (C) Fuel-type fallback ----

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun FuelFallbackForm(state: RewardRatesUiState, vm: RewardRatesViewModel) {
    val unit = state.rewardUnit
    SectionCard(
        title = "Fuel-Type Fallback Rates",
        subtitle = if (unit != null) "Points awarded for every Rs.$unit spent." else "Points awarded per rupee unit spent.",
    ) {
        if (state.fuelTypes.isEmpty()) {
            Text(
                "No fuel types are active yet.",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.nayara.textSecondary,
            )
        } else {
            state.fuelTypes.forEach { ft ->
                OutlinedTextField(
                    value = state.fuelInputs[ft.fuelType].orEmpty(),
                    onValueChange = { vm.onFuelInputChange(ft.fuelType, it) },
                    label = { Text(ft.label) },
                    suffix = { Text("pts") },
                    singleLine = true,
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                    modifier = Modifier.fillMaxWidth(),
                )
            }

            state.fuelError?.let { ErrorCard(it) }
            state.fuelMessage?.let { SuccessCard(it) }

            val canSave = state.fuelTypes.all { ft ->
                (state.fuelInputs[ft.fuelType] ?: "").toIntOrNull()?.let { it >= 0 } == true
            }
            NayaraButton(
                onClick = vm::saveFuelRates,
                enabled = canSave,
                loading = state.savingFuel,
                modifier = Modifier.fillMaxWidth(),
            ) {
                Text("Save Fuel Reward Rates")
            }
        }
    }
}

// ---- Shared building blocks ----

@Composable
private fun SectionCard(
    title: String,
    subtitle: String? = null,
    content: @Composable ColumnScope.() -> Unit,
) {
    Card(modifier = Modifier.fillMaxWidth()) {
        Column(
            modifier = Modifier.padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(title, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
                if (subtitle != null) {
                    Text(
                        subtitle,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.nayara.textSecondary,
                    )
                }
            }
            content()
        }
    }
}

@Composable
private fun ErrorCard(message: String) {
    Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.errorContainer)) {
        Text(
            message,
            modifier = Modifier.fillMaxWidth().padding(16.dp),
            color = MaterialTheme.colorScheme.onErrorContainer,
            style = MaterialTheme.typography.bodyMedium,
        )
    }
}

@Composable
private fun SuccessCard(message: String) {
    Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.primaryContainer)) {
        Text(
            message,
            modifier = Modifier.fillMaxWidth().padding(16.dp),
            color = MaterialTheme.colorScheme.onPrimaryContainer,
            style = MaterialTheme.typography.bodyMedium,
        )
    }
}
