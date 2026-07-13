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
    val loadError: String? = null,

    // Shared display context (from the saved reward setting).
    val rewardUnit: Int? = null,
    val cashRewardConfigured: Boolean = false,
    val redemptionIncrement: Int? = null,

    // (A) Reward settings form.
    val rupeesPerRewardUnit: String = "",
    val minimumRedeemablePoints: String = "",
    val cashValuePerPoint: String = "",
    val savingSettings: Boolean = false,
    val settingsError: String? = null,
    val settingsMessage: String? = null,

    // (B) Vehicle-type overrides form.
    val vehicleTypes: List<VehicleTypeRewardRateDto> = emptyList(),
    val vehicleInputs: Map<String, String> = emptyMap(),
    val savingVehicle: Boolean = false,
    val vehicleError: String? = null,
    val vehicleMessage: String? = null,

    // (C) Fuel-type fallback form.
    val fuelTypes: List<FuelRewardRateDto> = emptyList(),
    val fuelInputs: Map<String, String> = emptyMap(),
    val savingFuel: Boolean = false,
    val fuelError: String? = null,
    val fuelMessage: String? = null,
)

class RewardRatesViewModel(private val repository: RewardRatesRepository) : ViewModel() {

    private val _state = MutableStateFlow(RewardRatesUiState())
    val state: StateFlow<RewardRatesUiState> = _state.asStateFlow()

    init {
        load()
    }

    fun load() {
        _state.update { it.copy(loading = true, loadError = null) }
        viewModelScope.launch {
            when (val result = repository.load()) {
                is ApiResult.Success -> _state.update { seedAll(it, result.data) }
                is ApiResult.Error -> _state.update { it.copy(loading = false, loadError = result.message) }
                is ApiResult.NetworkError -> _state.update {
                    it.copy(loading = false, loadError = "Couldn't reach the server. Try again.")
                }
            }
        }
    }

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

    private fun seedAll(s: RewardRatesUiState, data: RewardRatesResponse): RewardRatesUiState =
        seedFuel(seedVehicle(seedSettings(s.copy(loading = false, loadError = null), data), data), data)

    private fun seedShared(s: RewardRatesUiState, data: RewardRatesResponse): RewardRatesUiState =
        s.copy(
            rewardUnit = data.rewardSetting.rupeesPerRewardUnit,
            cashRewardConfigured = data.rewardSetting.cashRewardConfigured,
            redemptionIncrement = data.rewardSetting.redemptionIncrement,
        )

    private fun seedSettings(s: RewardRatesUiState, data: RewardRatesResponse): RewardRatesUiState {
        val rs = data.rewardSetting
        return seedShared(s, data).copy(
            rupeesPerRewardUnit = rs.rupeesPerRewardUnit?.toString().orEmpty(),
            minimumRedeemablePoints = rs.minimumRedeemablePoints?.toString().orEmpty(),
            cashValuePerPoint = rs.cashValuePerPoint?.let(::formatDecimal).orEmpty(),
        )
    }

    private fun seedVehicle(s: RewardRatesUiState, data: RewardRatesResponse): RewardRatesUiState =
        seedShared(s, data).copy(
            vehicleTypes = data.vehicleTypeRewardRates,
            vehicleInputs = data.vehicleTypeRewardRates.associate { it.code to it.rewardPointsPer100?.toString().orEmpty() },
        )

    private fun seedFuel(s: RewardRatesUiState, data: RewardRatesResponse): RewardRatesUiState =
        seedShared(s, data).copy(
            fuelTypes = data.fuelRewardRates,
            fuelInputs = data.fuelRewardRates.associate { it.fuelType to it.pointsPer100?.toString().orEmpty() },
        )

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
