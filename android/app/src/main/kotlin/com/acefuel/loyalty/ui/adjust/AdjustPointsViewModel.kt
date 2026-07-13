package com.acefuel.loyalty.ui.adjust

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.acefuel.loyalty.core.data.StaffRepository
import com.acefuel.loyalty.core.network.ApiResult
import com.acefuel.loyalty.core.network.dto.StaffCustomerDto
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

enum class AdjustMode { Add, Deduct }

data class AdjustUiState(
    val customer: StaffCustomerDto? = null,
    val lookupLoading: Boolean = false,
    val lookupMessage: String? = null,
    val lookupRetryable: Boolean = false,
    val mode: AdjustMode = AdjustMode.Add,
    val pointsInput: String = "",
    val submitting: Boolean = false,
    val successMessage: String? = null,
    val errorMessage: String? = null,
) {
    val parsedPoints: Int? get() = pointsInput.toIntOrNull()

    /** Per-field validation: a deduction can never exceed the current balance. */
    val pointsError: String?
        get() {
            val points = parsedPoints ?: return null
            val c = customer ?: return null
            return if (mode == AdjustMode.Deduct && points > c.totalPoints) {
                "Cannot deduct more than the current balance (${c.totalPoints} pts)."
            } else {
                null
            }
        }

    val canSubmit: Boolean
        get() = customer != null && !submitting && (parsedPoints ?: 0) > 0 && pointsError == null
}

class AdjustPointsViewModel(private val repository: StaffRepository) : ViewModel() {

    private val _state = MutableStateFlow(AdjustUiState())
    val state: StateFlow<AdjustUiState> = _state.asStateFlow()

    fun lookup(phoneNumber: String) {
        _state.update {
            it.copy(
                lookupLoading = true, lookupMessage = null, lookupRetryable = false, customer = null,
                pointsInput = "", mode = AdjustMode.Add, successMessage = null, errorMessage = null,
            )
        }
        viewModelScope.launch {
            when (val result = repository.lookupCustomer(phoneNumber)) {
                is ApiResult.Success -> _state.update { it.copy(lookupLoading = false, customer = result.data) }
                is ApiResult.Error -> _state.update { it.copy(lookupLoading = false, lookupMessage = result.message) }
                is ApiResult.NetworkError -> _state.update {
                    it.copy(
                        lookupLoading = false,
                        lookupMessage = "Couldn't reach the server. Try again.",
                        lookupRetryable = true,
                    )
                }
            }
        }
    }

    fun setMode(mode: AdjustMode) {
        _state.update { it.copy(mode = mode, errorMessage = null) }
    }

    fun onPointsChange(input: String) {
        // Digits only — the Add/Deduct toggle carries the sign.
        _state.update { it.copy(pointsInput = input.filter(Char::isDigit).take(7), errorMessage = null) }
    }

    fun submit() {
        val current = _state.value
        val customer = current.customer ?: return
        val points = current.parsedPoints?.takeIf { it > 0 } ?: return
        val signed = if (current.mode == AdjustMode.Deduct) -points else points
        _state.update { it.copy(submitting = true, errorMessage = null, successMessage = null) }
        viewModelScope.launch {
            when (val result = repository.adjustPoints(customer.phoneNumber.orEmpty(), signed)) {
                is ApiResult.Success -> _state.update {
                    it.copy(
                        submitting = false,
                        customer = result.data.customer,
                        pointsInput = "",
                        successMessage = result.data.message,
                    )
                }
                is ApiResult.Error -> _state.update { it.copy(submitting = false, errorMessage = result.message) }
                is ApiResult.NetworkError -> _state.update {
                    it.copy(submitting = false, errorMessage = "Couldn't reach the server. Try again.")
                }
            }
        }
    }

    // One-shot consumers so the overlay/snackbar fire exactly once.
    fun consumeSuccessMessage() = _state.update { it.copy(successMessage = null) }

    fun consumeError() = _state.update { it.copy(errorMessage = null) }
}
