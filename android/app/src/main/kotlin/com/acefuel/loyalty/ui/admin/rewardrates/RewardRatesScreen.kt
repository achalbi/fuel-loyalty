package com.acefuel.loyalty.ui.admin.rewardrates

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import com.acefuel.loyalty.core.di.LocalContainer
import com.acefuel.loyalty.ui.designsystem.ChipTone
import com.acefuel.loyalty.ui.designsystem.ErrorState
import com.acefuel.loyalty.ui.designsystem.FormField
import com.acefuel.loyalty.ui.designsystem.InlineErrorCard
import com.acefuel.loyalty.ui.designsystem.NayaraCard
import com.acefuel.loyalty.ui.designsystem.NayaraPullToRefresh
import com.acefuel.loyalty.ui.designsystem.NayaraSnackbarHost
import com.acefuel.loyalty.ui.designsystem.NayaraTopBar
import com.acefuel.loyalty.ui.designsystem.SkeletonCard
import com.acefuel.loyalty.ui.designsystem.StatusChip
import com.acefuel.loyalty.ui.designsystem.rememberHaptics
import com.acefuel.loyalty.ui.designsystem.showSuccess
import com.acefuel.loyalty.ui.theme.NayaraButton
import com.acefuel.loyalty.ui.theme.NayaraSpacing
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

    val snackbar = remember { SnackbarHostState() }
    val haptics = rememberHaptics()

    // Show first, consume after: consuming inside the effect nulls the key it
    // is launched on, which would cancel the still-suspended showSnackbar.
    LaunchedEffect(state.settingsMessage) {
        val msg = state.settingsMessage ?: return@LaunchedEffect
        haptics.confirm()
        snackbar.showSuccess(msg)
        vm.consumeSettingsMessage()
    }
    LaunchedEffect(state.vehicleMessage) {
        val msg = state.vehicleMessage ?: return@LaunchedEffect
        haptics.confirm()
        snackbar.showSuccess(msg)
        vm.consumeVehicleMessage()
    }
    LaunchedEffect(state.fuelMessage) {
        val msg = state.fuelMessage ?: return@LaunchedEffect
        haptics.confirm()
        snackbar.showSuccess(msg)
        vm.consumeFuelMessage()
    }

    Scaffold(
        topBar = { NayaraTopBar(title = "Reward Rates", onBack = onBack) },
        snackbarHost = { NayaraSnackbarHost(snackbar) },
    ) { innerPadding ->
        when {
            state.loading -> Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(innerPadding)
                    .padding(horizontal = NayaraSpacing.ScreenMargin, vertical = NayaraSpacing.Lg),
                verticalArrangement = Arrangement.spacedBy(NayaraSpacing.Xl),
            ) {
                SkeletonCard(lines = 4)
                SkeletonCard(lines = 3)
                SkeletonCard(lines = 3)
            }

            state.loadError != null -> Box(
                modifier = Modifier.fillMaxSize().padding(innerPadding),
                contentAlignment = Alignment.Center,
            ) {
                ErrorState(state.loadError!!, onRetry = vm::load)
            }

            else -> NayaraPullToRefresh(
                isRefreshing = state.refreshing,
                onRefresh = vm::refresh,
                modifier = Modifier.fillMaxSize().padding(innerPadding),
            ) {
                Column(
                    modifier = Modifier
                        .fillMaxSize()
                        .verticalScroll(rememberScrollState())
                        .padding(horizontal = NayaraSpacing.ScreenMargin, vertical = NayaraSpacing.Lg),
                    verticalArrangement = Arrangement.spacedBy(NayaraSpacing.Xl),
                ) {
                    RewardSettingsForm(state, vm)
                    VehicleOverridesForm(state, vm)
                    FuelFallbackForm(state, vm)
                    Spacer(Modifier.height(8.dp))
                }
            }
        }
    }
}

// ---- (A) Reward settings ----

@Composable
private fun RewardSettingsForm(state: RewardRatesUiState, vm: RewardRatesViewModel) {
    val rupeesErrors = if (state.rupeesPerRewardUnit.toIntOrNull()?.let { it >= 1 } != true) {
        listOf("Enter a whole number of at least 1.")
    } else {
        null
    }
    val minErrors = if (
        state.minimumRedeemablePoints.isNotBlank() &&
        state.minimumRedeemablePoints.toIntOrNull()?.let { it > 0 } != true
    ) {
        listOf("Must be a positive whole number.")
    } else {
        null
    }
    val cashErrors = if (state.cashValuePerPoint.isNotBlank() && state.cashValuePerPoint.toDoubleOrNull() == null) {
        listOf("Enter a valid amount.")
    } else {
        null
    }

    SectionCard(
        title = "Reward Settings",
        subtitle = "Points are earned per rupee unit spent. Cash value and minimum redeemable points are optional.",
        dirty = state.settingsDirty,
    ) {
        FormField(
            value = state.rupeesPerRewardUnit,
            onValueChange = vm::onRupeesChange,
            label = "Rupee Unit",
            prefix = { Text("Rs. ") },
            errors = rupeesErrors,
            helper = "Points are awarded for every Rs. spent on this unit (min 1).",
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number, imeAction = ImeAction.Next),
        )
        FormField(
            value = state.minimumRedeemablePoints,
            onValueChange = vm::onMinRedeemChange,
            label = "Minimum Redeemable Points",
            errors = minErrors,
            helper = "Leave blank to keep using existing vehicle-type minimums.",
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number, imeAction = ImeAction.Next),
        )
        FormField(
            value = state.cashValuePerPoint,
            onValueChange = vm::onCashChange,
            label = "1 Point Cash Reward",
            prefix = { Text("Rs. ") },
            errors = cashErrors,
            helper = "Optional. Cash value of a single point.",
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal, imeAction = ImeAction.Done),
        )

        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier.fillMaxWidth().padding(vertical = 8.dp),
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    "Pause All Rewards",
                    style = MaterialTheme.typography.bodyLarge,
                    fontWeight = FontWeight.SemiBold,
                )
                Text(
                    if (state.rewardsPaused) {
                        "No points are awarded to anyone while this is on."
                    } else {
                        "Rewards are active for all customers."
                    },
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            Switch(checked = state.rewardsPaused, onCheckedChange = vm::onRewardsPausedChange)
        }

        state.settingsError?.let { InlineErrorCard(it) }

        NayaraButton(
            onClick = vm::saveSettings,
            enabled = rupeesErrors == null && minErrors == null && cashErrors == null && !state.savingSettings,
            loading = state.savingSettings,
            modifier = Modifier.fillMaxWidth(),
        ) {
            Text("Save Reward Settings")
        }
    }
}

// ---- (B) Vehicle-type overrides ----

@Composable
private fun VehicleOverridesForm(state: RewardRatesUiState, vm: RewardRatesViewModel) {
    SectionCard(
        title = "Vehicle Type Reward Overrides",
        subtitle = "Points earned per rupee unit for each vehicle type. Leave blank to fall back to the fuel-type rate.",
        dirty = state.vehicleDirty,
    ) {
        if (state.vehicleTypes.isEmpty()) {
            Text(
                "No vehicle types are configured yet.",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.nayara.textSecondary,
            )
        } else {
            val suffix = state.rewardUnit?.let { "pts / Rs.$it" } ?: "pts"
            state.vehicleTypes.forEachIndexed { index, vt ->
                FormField(
                    value = state.vehicleInputs[vt.code].orEmpty(),
                    onValueChange = { vm.onVehicleInputChange(vt.code, it) },
                    label = vt.label,
                    trailingIcon = { SuffixLabel(suffix) },
                    keyboardOptions = KeyboardOptions(
                        keyboardType = KeyboardType.Number,
                        imeAction = if (index == state.vehicleTypes.lastIndex) ImeAction.Done else ImeAction.Next,
                    ),
                )
            }

            state.vehicleError?.let { InlineErrorCard(it) }

            NayaraButton(
                onClick = vm::saveVehicleRates,
                enabled = state.vehicleDirty && !state.savingVehicle,
                loading = state.savingVehicle,
                modifier = Modifier.fillMaxWidth(),
            ) {
                Text("Save Vehicle Type Reward Rates")
            }
        }
    }
}

// ---- (C) Fuel-type fallback ----

@Composable
private fun FuelFallbackForm(state: RewardRatesUiState, vm: RewardRatesViewModel) {
    val unit = state.rewardUnit
    SectionCard(
        title = "Fuel-Type Fallback Rates",
        subtitle = if (unit != null) "Points awarded for every Rs.$unit spent." else "Points awarded per rupee unit spent.",
        dirty = state.fuelDirty,
    ) {
        if (state.fuelTypes.isEmpty()) {
            Text(
                "No fuel types are active yet.",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.nayara.textSecondary,
            )
        } else {
            state.fuelTypes.forEachIndexed { index, ft ->
                val value = state.fuelInputs[ft.fuelType].orEmpty()
                FormField(
                    value = value,
                    onValueChange = { vm.onFuelInputChange(ft.fuelType, it) },
                    label = ft.label,
                    trailingIcon = { SuffixLabel("pts") },
                    errors = if (value.isBlank()) listOf("Required.") else null,
                    keyboardOptions = KeyboardOptions(
                        keyboardType = KeyboardType.Number,
                        imeAction = if (index == state.fuelTypes.lastIndex) ImeAction.Done else ImeAction.Next,
                    ),
                )
            }

            state.fuelError?.let { InlineErrorCard(it) }

            val canSave = state.fuelTypes.all { ft ->
                (state.fuelInputs[ft.fuelType] ?: "").toIntOrNull()?.let { it >= 0 } == true
            }
            NayaraButton(
                onClick = vm::saveFuelRates,
                enabled = canSave && !state.savingFuel,
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
private fun SuffixLabel(text: String) {
    Text(
        text,
        style = MaterialTheme.typography.labelMedium,
        color = MaterialTheme.nayara.textSecondary,
        modifier = Modifier.padding(end = 12.dp),
    )
}

@Composable
private fun SectionCard(
    title: String,
    subtitle: String? = null,
    dirty: Boolean = false,
    content: @Composable ColumnScope.() -> Unit,
) {
    NayaraCard(modifier = Modifier.fillMaxWidth(), shape = MaterialTheme.shapes.large) {
        Column(
            modifier = Modifier.padding(NayaraSpacing.CardPadding),
            verticalArrangement = Arrangement.spacedBy(NayaraSpacing.Md),
        ) {
            Column(verticalArrangement = Arrangement.spacedBy(NayaraSpacing.Xs)) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(
                        title,
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.SemiBold,
                        modifier = Modifier.weight(1f),
                    )
                    if (dirty) {
                        StatusChip(label = "Unsaved changes", tone = ChipTone.Warning)
                    }
                }
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
