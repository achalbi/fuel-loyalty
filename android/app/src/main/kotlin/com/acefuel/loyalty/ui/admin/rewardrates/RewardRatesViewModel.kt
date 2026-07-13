package com.acefuel.loyalty.ui.admin.rewardrates

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.acefuel.loyalty.core.network.ApiResult
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

data class RewardRatesUiState(
    val loading: Boolean = true,
    val refreshing: Boolean = false,
    val loadError: String? = null,

    // Shared display context (from the saved reward setting).
    val rewardUnit: Int? = null,
    val cashRewardConfigured: Boolean = false,
    val redemptionIncrement: Int? = null,

    // (A) Reward settings form.
    val rupeesPerRewardUnit: String = "",
    val minimumRedeemablePoints: String = "",
    val cashValuePerPoint: String = "",
    val savedRupeesPerRewardUnit: String = "",
    val savedMinimumRedeemablePoints: String = "",
    val savedCashValuePerPoint: String = "",
    val savingSettings: Boolean = false,
    val settingsError: String? = null,
    val settingsMessage: String? = null,

    // (B) Vehicle-type overrides form.
    val vehicleTypes: List<VehicleTypeRewardRateDto> = emptyList(),
    val vehicleInputs: Map<String, String> = emptyMap(),
    val savedVehicleInputs: Map<String, String> = emptyMap(),
    val savingVehicle: Boolean = false,
    val vehicleError: String? = null,
    val vehicleMessage: String? = null,

    // (C) Fuel-type fallback form.
    val fuelTypes: List<FuelRewardRateDto> = emptyList(),
    val fuelInputs: Map<String, String> = emptyMap(),
    val savedFuelInputs: Map<String, String> = emptyMap(),
    val savingFuel: Boolean = false,
    val fuelError: String? = null,
    val fuelMessage: String? = null,
) {
    // Per-section unsaved-changes tracking (drives the "Unsaved changes" chip).
    val settingsDirty: Boolean
        get() = rupeesPerRewardUnit != savedRupeesPerRewardUnit ||
            minimumRedeemablePoints != savedMinimumRedeemablePoints ||
            cashValuePerPoint != savedCashValuePerPoint
    val vehicleDirty: Boolean get() = vehicleInputs != savedVehicleInputs
    val fuelDirty: Boolean get() = fuelInputs != savedFuelInputs
}

class RewardRatesViewModel(private val repository: RewardRatesRepository) : ViewModel() {

    private val _state = MutableStateFlow(RewardRatesUiState())
    val state: StateFlow<RewardRatesUiState> = _state.asStateFlow()

    init {
        load()
    }

    fun load() = fetch(refresh = false)

    fun refresh() = fetch(refresh = true)

    private fun fetch(refresh: Boolean) {
        if (refresh) {
            if (_state.value.refreshing) return
            _state.update { it.copy(refreshing = true) }
        } else {
            _state.update { it.copy(loading = true, loadError = null) }
        }
        viewModelScope.launch {
            when (val result = repository.load()) {
                // On refresh, keep sections the user has edited — reseeding
                // would silently discard their unsaved input.
                is ApiResult.Success -> _state.update { seedAll(it, result.data, preserveDirty = refresh) }
                is ApiResult.Error -> _state.update {
                    it.copy(loading = false, refreshing = false, loadError = result.message)
                }
                is ApiResult.NetworkError -> _state.update {
                    it.copy(loading = false, refreshing = false, loadError = "Couldn't reach the server. Try again.")
                }
            }
        }
    }

    // ---- One-shot success message consumption (snackbar feedback) ----

    fun consumeSettingsMessage() = _state.update { it.copy(settingsMessage = null) }

    fun consumeVehicleMessage() = _state.update { it.copy(vehicleMessage = null) }

    fun consumeFuelMessage() = _state.update { it.copy(fuelMessage = null) }

    // ---- Field edits ----

    fun onRupeesChange(v: String) = _state.update {
        it.copy(rupeesPerRewardUnit = v.filter(Char::isDigit).take(9), settingsMessage = null, settingsError = null)
    }

    fun onMinRedeemChange(v: String) = _state.update {
        it.copy(minimumRedeemablePoints = v.filter(Char::isDigit).take(9), settingsMessage = null, settingsError = null)
    }

    fun onCashChange(v: String) = _state.update {
        it.copy(cashValuePerPoint = sanitizeDecimal(v), settingsMessage = null, settingsError = null)
    }

    fun onVehicleInputChange(code: String, v: String) = _state.update {
        it.copy(
            vehicleInputs = it.vehicleInputs + (code to v.filter(Char::isDigit).take(9)),
            vehicleMessage = null,
            vehicleError = null,
        )
    }

    fun onFuelInputChange(code: String, v: String) = _state.update {
        it.copy(
            fuelInputs = it.fuelInputs + (code to v.filter(Char::isDigit).take(9)),
            fuelMessage = null,
            fuelError = null,
        )
    }

    // ---- Saves ----

    fun saveSettings() {
        val s = _state.value
        _state.update { it.copy(savingSettings = true, settingsError = null, settingsMessage = null) }
        viewModelScope.launch {
            val update = RewardSettingUpdate(
                rupeesPerRewardUnit = s.rupeesPerRewardUnit.trim(),
                minimumRedeemablePoints = s.minimumRedeemablePoints.trim(),
                cashValuePerPoint = s.cashValuePerPoint.trim(),
            )
            when (val result = repository.saveRewardSetting(update)) {
                is ApiResult.Success -> _state.update {
                    seedSettings(it.copy(savingSettings = false, settingsMessage = result.data.message), result.data)
                }
                is ApiResult.Error -> _state.update { it.copy(savingSettings = false, settingsError = result.message) }
                is ApiResult.NetworkError -> _state.update {
                    it.copy(savingSettings = false, settingsError = "Couldn't reach the server. Try again.")
                }
            }
        }
    }

    fun saveVehicleRates() {
        val s = _state.value
        _state.update { it.copy(savingVehicle = true, vehicleError = null, vehicleMessage = null) }
        viewModelScope.launch {
            val rates = s.vehicleTypes.associate { vt ->
                vt.code to VehicleTypeRateUpdate((s.vehicleInputs[vt.code] ?: "").trim())
            }
            when (val result = repository.saveVehicleTypeRates(rates)) {
                is ApiResult.Success -> _state.update {
                    seedVehicle(it.copy(savingVehicle = false, vehicleMessage = result.data.message), result.data)
                }
                is ApiResult.Error -> _state.update { it.copy(savingVehicle = false, vehicleError = result.message) }
                is ApiResult.NetworkError -> _state.update {
                    it.copy(savingVehicle = false, vehicleError = "Couldn't reach the server. Try again.")
                }
            }
        }
    }

    fun saveFuelRates() {
        val s = _state.value
        _state.update { it.copy(savingFuel = true, fuelError = null, fuelMessage = null) }
        viewModelScope.launch {
            val rates = s.fuelTypes.associate { ft ->
                ft.fuelType to FuelRateUpdate((s.fuelInputs[ft.fuelType] ?: "").trim())
            }
            when (val result = repository.saveFuelRates(rates)) {
                is ApiResult.Success -> _state.update {
                    seedFuel(it.copy(savingFuel = false, fuelMessage = result.data.message), result.data)
                }
                is ApiResult.Error -> _state.update { it.copy(savingFuel = false, fuelError = result.message) }
                is ApiResult.NetworkError -> _state.update {
                    it.copy(savingFuel = false, fuelError = "Couldn't reach the server. Try again.")
                }
            }
        }
    }

    // ---- Seeding helpers (inputs reflect the server's normalized values) ----

    private fun seedAll(
        s: RewardRatesUiState,
        data: RewardRatesResponse,
        preserveDirty: Boolean = false,
    ): RewardRatesUiState {
        var next = s.copy(loading = false, refreshing = false, loadError = null)
        if (!(preserveDirty && s.settingsDirty)) next = seedSettings(next, data)
        if (!(preserveDirty && s.vehicleDirty)) next = seedVehicle(next, data)
        if (!(preserveDirty && s.fuelDirty)) next = seedFuel(next, data)
        // Reference/shared data (unit, increment, type lists) always refreshes.
        return seedShared(next, data)
    }

    private fun seedShared(s: RewardRatesUiState, data: RewardRatesResponse): RewardRatesUiState =
        s.copy(
            rewardUnit = data.rewardSetting.rupeesPerRewardUnit,
            cashRewardConfigured = data.rewardSetting.cashRewardConfigured,
            redemptionIncrement = data.rewardSetting.redemptionIncrement,
        )

    private fun seedSettings(s: RewardRatesUiState, data: RewardRatesResponse): RewardRatesUiState {
        val rs = data.rewardSetting
        val rupees = rs.rupeesPerRewardUnit?.toString().orEmpty()
        val minimum = rs.minimumRedeemablePoints?.toString().orEmpty()
        val cash = rs.cashValuePerPoint?.let(::formatDecimal).orEmpty()
        return seedShared(s, data).copy(
            rupeesPerRewardUnit = rupees,
            minimumRedeemablePoints = minimum,
            cashValuePerPoint = cash,
            savedRupeesPerRewardUnit = rupees,
            savedMinimumRedeemablePoints = minimum,
            savedCashValuePerPoint = cash,
        )
    }

    private fun seedVehicle(s: RewardRatesUiState, data: RewardRatesResponse): RewardRatesUiState {
        val inputs = data.vehicleTypeRewardRates.associate { it.code to it.rewardPointsPer100?.toString().orEmpty() }
        return seedShared(s, data).copy(
            vehicleTypes = data.vehicleTypeRewardRates,
            vehicleInputs = inputs,
            savedVehicleInputs = inputs,
        )
    }

    private fun seedFuel(s: RewardRatesUiState, data: RewardRatesResponse): RewardRatesUiState {
        val inputs = data.fuelRewardRates.associate { it.fuelType to it.pointsPer100?.toString().orEmpty() }
        return seedShared(s, data).copy(
            fuelTypes = data.fuelRewardRates,
            fuelInputs = inputs,
            savedFuelInputs = inputs,
        )
    }

    private fun sanitizeDecimal(input: String): String {
        val sb = StringBuilder()
        var dotSeen = false
        for (c in input) {
            when {
                c.isDigit() -> sb.append(c)
                c == '.' && !dotSeen -> {
                    sb.append(c)
                    dotSeen = true
                }
            }
        }
        return sb.toString().take(12)
    }

    private fun formatDecimal(d: Double): String =
        if (d % 1.0 == 0.0) d.toLong().toString() else d.toString()
}
