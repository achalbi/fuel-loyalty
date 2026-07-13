package com.acefuel.loyalty.ui.scanner

import android.graphics.Bitmap
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
    /** Downscaled captured frame, kept so the result card can show a thumbnail. */
    val capturedFrame: Bitmap? = null,
    /** One-shot provenance snackbar (e.g. server fell back to on-device OCR). */
    val infoMessage: String? = null,
)

class PlateScannerViewModel(private val repository: PlateScanRepository) : ViewModel() {

    private val _state = MutableStateFlow(PlateScanUiState())
    val state: StateFlow<PlateScanUiState> = _state.asStateFlow()

    // Last capture inputs, kept so "Try again" can re-run recognition without retaking.
    private var lastImage: String? = null
    private var lastOnDevicePlate: String? = null
    private var lastFrame: Bitmap? = null

    /**
     * Try the server recognizer first; fall back to the on-device ML Kit result
     * ([onDevicePlate]) when the server is unavailable or finds nothing.
     */
    fun recognize(imageDataUrl: String, onDevicePlate: String?, frame: Bitmap? = null) {
        lastImage = imageDataUrl
        lastOnDevicePlate = onDevicePlate
        lastFrame = frame
        _state.update { PlateScanUiState(recognizing = true, capturedFrame = frame) }
        viewModelScope.launch {
            when (val result = repository.recognize(imageDataUrl)) {
                is ApiResult.Success -> {
                    val d = result.data
                    if (d.found && !d.plate.isNullOrBlank()) {
                        _state.value = PlateScanUiState(
                            plate = d.plate, confidence = d.confidence, valid = d.valid,
                            provider = d.provider ?: "plate_recognizer",
                            capturedFrame = frame,
                        )
                    } else {
                        fallback(
                            onDevicePlate, frame,
                            serverMessage = "No clear vehicle number could be recognized. Please retake the photo.",
                            offline = false,
                        )
                    }
                }
                // The server answered (422/500/etc.) — the device is online, so
                // this is not an "offline — recognized on device" case.
                is ApiResult.Error -> fallback(onDevicePlate, frame, result.message, offline = false)
                is ApiResult.NetworkError -> fallback(
                    onDevicePlate, frame,
                    serverMessage = "Couldn't reach the server. Check the connection and try again.",
                    offline = true,
                )
            }
        }
    }

    /** Re-run server recognition on the last captured frame (no retake needed). */
    fun retry() {
        val image = lastImage ?: return
        recognize(image, lastOnDevicePlate, lastFrame)
    }

    private fun fallback(onDevicePlate: String?, frame: Bitmap?, serverMessage: String, offline: Boolean) {
        if (!onDevicePlate.isNullOrBlank()) {
            _state.value = PlateScanUiState(
                plate = onDevicePlate,
                valid = PlateText.isValid(onDevicePlate),
                provider = "on_device",
                capturedFrame = frame,
                infoMessage = if (offline) "Offline — recognized on device" else "Recognized on device",
            )
        } else {
            _state.value = PlateScanUiState(error = serverMessage, capturedFrame = frame)
        }
    }

    fun consumeInfoMessage() {
        _state.update { it.copy(infoMessage = null) }
    }

    fun reset() {
        lastImage = null
        lastOnDevicePlate = null
        lastFrame = null
        _state.value = PlateScanUiState()
    }
}
