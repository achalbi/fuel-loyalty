package com.acefuel.loyalty.ui.scanner

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.acefuel.loyalty.core.network.ApiResult
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

data class PlateScanUiState(
    val recognizing: Boolean = false,
    val plate: String? = null,
    val confidence: Double? = null,
    val valid: Boolean = false,
    val provider: String? = null,
    val error: String? = null,
)

class PlateScannerViewModel(private val repository: PlateScanRepository) : ViewModel() {

    private val _state = MutableStateFlow(PlateScanUiState())
    val state: StateFlow<PlateScanUiState> = _state.asStateFlow()

    /**
     * Try the server recognizer first; fall back to the on-device ML Kit result
     * ([onDevicePlate]) when the server is unavailable or finds nothing.
     */
    fun recognize(imageDataUrl: String, onDevicePlate: String?) {
        _state.update { PlateScanUiState(recognizing = true) }
        viewModelScope.launch {
            when (val result = repository.recognize(imageDataUrl)) {
                is ApiResult.Success -> {
                    val d = result.data
                    if (d.found && !d.plate.isNullOrBlank()) {
                        _state.value = PlateScanUiState(
                            plate = d.plate, confidence = d.confidence, valid = d.valid,
                            provider = d.provider ?: "plate_recognizer",
                        )
                    } else {
                        fallback(onDevicePlate, "No clear vehicle number could be recognized. Please retake the photo.")
                    }
                }
                is ApiResult.Error -> fallback(onDevicePlate, result.message)
                is ApiResult.NetworkError -> fallback(onDevicePlate, "Couldn't reach the server; used on-device scan.")
            }
        }
    }

    private fun fallback(onDevicePlate: String?, serverMessage: String) {
        if (!onDevicePlate.isNullOrBlank()) {
            _state.value = PlateScanUiState(
                plate = onDevicePlate,
                valid = PlateText.isValid(onDevicePlate),
                provider = "on_device",
            )
        } else {
            _state.value = PlateScanUiState(error = serverMessage)
        }
    }

    fun reset() {
        _state.value = PlateScanUiState()
    }
}
