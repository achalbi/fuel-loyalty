package com.acefuel.loyalty.ui.admin.theme

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.acefuel.loyalty.core.network.ApiResult
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

/** Six-hex-digit body (no leading '#'), matching the server's `\A#[0-9A-F]{6}\z`. */
private val HEX_DIGITS = Regex("^[0-9A-Fa-f]{6}$")

/** Nayara navy-700 default (ThemeSetting::DEFAULT_PRIMARY_COLOR). */
const val DEFAULT_PRIMARY_HEX = "#1D63B0"

const val HEX_VALIDATION_ERROR = "must be a valid hex color"

fun isValidHexDigits(input: String): Boolean = HEX_DIGITS.matches(input)

/** Strips '#' and uppercases — the form's canonical field value. */
fun hexDigitsOf(hex: String): String = hex.removePrefix("#").uppercase()

data class AdminThemeUiState(
    val loading: Boolean = true,
    val refreshing: Boolean = false,
    val saving: Boolean = false,
    /** Six hex digits without '#', always uppercase; what the field shows. */
    val input: String = "",
    /** Last color persisted by the server, as "#RRGGBB". */
    val savedColor: String = DEFAULT_PRIMARY_HEX,
    val updatedAt: String? = null,
    val loadError: String? = null,
    val fieldError: String? = null,
    val saveError: String? = null,
    val successMessage: String? = null,
) {
    val inputValid: Boolean get() = isValidHexDigits(input)
    val normalizedInput: String get() = "#" + input.uppercase()
    val dirty: Boolean get() = normalizedInput != savedColor.uppercase()
    val canSave: Boolean get() = inputValid && !saving && dirty
}

class AdminThemeViewModel(private val repository: AdminThemeRepository) : ViewModel() {

    private val _state = MutableStateFlow(AdminThemeUiState())
    val state: StateFlow<AdminThemeUiState> = _state.asStateFlow()

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
                is ApiResult.Success -> _state.update {
                    // On refresh, don't overwrite an edited-but-unsaved hex —
                    // back-navigation already protects it; refresh must too.
                    val keepInput = refresh && it.dirty
                    it.copy(
                        loading = false,
                        refreshing = false,
                        savedColor = result.data.primaryColor,
                        updatedAt = result.data.updatedAt,
                        input = if (keepInput) it.input else hexDigitsOf(result.data.primaryColor),
                    )
                }
                is ApiResult.Error -> _state.update {
                    it.copy(loading = false, refreshing = false, loadError = result.message)
                }
                is ApiResult.NetworkError -> _state.update {
                    it.copy(loading = false, refreshing = false, loadError = "Couldn't reach the server. Try again.")
                }
            }
        }
    }

    /** One-shot consume once the success snackbar has been shown. */
    fun consumeMessage() = _state.update { it.copy(successMessage = null) }

    /** One-shot consume once the error snackbar has been shown. */
    fun consumeSaveError() = _state.update { it.copy(saveError = null) }

    fun onInputChange(raw: String) {
        val cleaned = raw.replace("#", "").uppercase().take(6)
        val error = if (cleaned.isNotEmpty() && !isValidHexDigits(cleaned)) HEX_VALIDATION_ERROR else null
        _state.update { it.copy(input = cleaned, fieldError = error, saveError = null, successMessage = null) }
    }

    /** Tap a preset swatch (value like "#1D63B0"). */
    fun onPresetSelected(hex: String) = onInputChange(hex)

    fun save() {
        val current = _state.value
        if (!current.inputValid) {
            _state.update { it.copy(fieldError = HEX_VALIDATION_ERROR) }
            return
        }
        _state.update { it.copy(saving = true, saveError = null, successMessage = null, fieldError = null) }
        viewModelScope.launch {
            when (val result = repository.update(current.normalizedInput)) {
                is ApiResult.Success -> _state.update {
                    it.copy(
                        saving = false,
                        savedColor = result.data.primaryColor,
                        updatedAt = result.data.updatedAt,
                        input = hexDigitsOf(result.data.primaryColor),
                        successMessage = result.data.message?.takeUnless(String::isBlank)
                            ?: "Theme color updated successfully.",
                    )
                }
                is ApiResult.Error -> _state.update { it.copy(saving = false, saveError = result.message) }
                is ApiResult.NetworkError -> _state.update {
                    it.copy(saving = false, saveError = "Couldn't reach the server. Try again.")
                }
            }
        }
    }
}
