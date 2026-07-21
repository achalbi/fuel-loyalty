package com.acefuel.loyalty.ui.visitentry

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.acefuel.loyalty.core.data.StaffRepository
import com.acefuel.loyalty.core.network.ApiResult
import com.acefuel.loyalty.core.network.dto.FuelTypeOptionDto
import com.acefuel.loyalty.core.network.dto.PumpDto
import com.acefuel.loyalty.core.network.dto.VisitEntryRequest
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

data class VisitEntryUiState(
    val vehicleNumber: String = "",
    val litres: String = "",
    val discount: String = "",
    val fuelTypeCode: String? = null,
    // null => let the server default to the caller's My Pump.
    val fuelPumpId: Long? = null,
    val fleetOtp: Boolean = false,
    val driverName: String = "",
    val driverPhone: String = "",
    val transportName: String = "",
    val managerName: String = "",
    val managerPhone: String = "",
    val ownerName: String = "",
    val ownerPhone: String = "",
    val approxVehicles: String = "",
    val pumps: List<PumpDto> = emptyList(),
    val defaultPumpId: Long? = null,
    val fuelTypes: List<FuelTypeOptionDto> = emptyList(),
    val loadingOptions: Boolean = true,
    val submitting: Boolean = false,
    val error: String? = null,
    val success: String? = null,
) {
    val canSubmit: Boolean
        get() = vehicleNumber.isNotBlank() && litres.toDoubleOrNull()?.let { it > 0 } == true && !submitting
}

class VisitEntryViewModel(private val repository: StaffRepository) : ViewModel() {

    private val _state = MutableStateFlow(VisitEntryUiState())
    val state: StateFlow<VisitEntryUiState> = _state.asStateFlow()

    init { loadOptions() }

    private fun loadOptions() {
        _state.update { it.copy(loadingOptions = true) }
        viewModelScope.launch {
            when (val pump = repository.myPump()) {
                is ApiResult.Success -> _state.update {
                    it.copy(pumps = pump.data.pumps.filter { p -> p.active }, defaultPumpId = pump.data.fuelPumpId)
                }
                else -> Unit // pump override just won't be offered; the server still defaults it
            }
            when (val catalog = repository.catalog()) {
                is ApiResult.Success -> _state.update { it.copy(fuelTypes = catalog.data.fuelTypes) }
                else -> Unit
            }
            _state.update { it.copy(loadingOptions = false) }
        }
    }

    fun onVehicleNumber(value: String) = _state.update { it.copy(vehicleNumber = value) }
    fun onLitres(value: String) = _state.update { it.copy(litres = value) }
    fun onDiscount(value: String) = _state.update { it.copy(discount = value) }
    fun onFuelType(code: String?) = _state.update { it.copy(fuelTypeCode = code) }
    fun onPump(id: Long?) = _state.update { it.copy(fuelPumpId = id) }
    fun onFleetOtp(value: Boolean) = _state.update { it.copy(fleetOtp = value) }
    fun onDriverName(value: String) = _state.update { it.copy(driverName = value) }
    fun onDriverPhone(value: String) = _state.update { it.copy(driverPhone = value) }
    fun onTransportName(value: String) = _state.update { it.copy(transportName = value) }
    fun onManagerName(value: String) = _state.update { it.copy(managerName = value) }
    fun onManagerPhone(value: String) = _state.update { it.copy(managerPhone = value) }
    fun onOwnerName(value: String) = _state.update { it.copy(ownerName = value) }
    fun onOwnerPhone(value: String) = _state.update { it.copy(ownerPhone = value) }
    fun onApproxVehicles(value: String) = _state.update { it.copy(approxVehicles = value) }

    fun consumeError() = _state.update { it.copy(error = null) }
    fun consumeSuccess() = _state.update { it.copy(success = null) }

    fun submit() {
        val s = _state.value
        if (!s.canSubmit) return
        _state.update { it.copy(submitting = true, error = null) }
        viewModelScope.launch {
            val request = VisitEntryRequest(
                vehicleNumber = s.vehicleNumber.trim(),
                litres = s.litres.trim(),
                fuelPumpId = s.fuelPumpId,
                fuelTypeCode = s.fuelTypeCode,
                discountAmount = s.discount.trim().ifBlank { null },
                fleetOtp = s.fleetOtp,
                driverName = s.driverName.trim().ifBlank { null },
                driverPhoneNumber = s.driverPhone.trim().ifBlank { null },
                transportName = s.transportName.trim().ifBlank { null },
                managerName = s.managerName.trim().ifBlank { null },
                managerPhoneNumber = s.managerPhone.trim().ifBlank { null },
                ownerName = s.ownerName.trim().ifBlank { null },
                ownerPhoneNumber = s.ownerPhone.trim().ifBlank { null },
                approxVehicleCount = s.approxVehicles.trim().toIntOrNull(),
            )
            when (val result = repository.createVisitEntry(request)) {
                is ApiResult.Success -> {
                    val entry = result.data.visitEntry
                    // Keep the pump selection for the next capture; clear the rest.
                    _state.update {
                        VisitEntryUiState(
                            pumps = it.pumps,
                            defaultPumpId = it.defaultPumpId,
                            fuelTypes = it.fuelTypes,
                            fuelPumpId = it.fuelPumpId,
                            loadingOptions = false,
                            success = "Captured ${formatLitres(entry.litres)} L for ${entry.vehicleNumber}.",
                        )
                    }
                }
                is ApiResult.Error -> _state.update { it.copy(submitting = false, error = result.message) }
                is ApiResult.NetworkError ->
                    _state.update { it.copy(submitting = false, error = "Couldn't reach the server. Try again.") }
            }
        }
    }

    private fun formatLitres(value: Double): String =
        if (value % 1.0 == 0.0) value.toLong().toString() else value.toString()
}
