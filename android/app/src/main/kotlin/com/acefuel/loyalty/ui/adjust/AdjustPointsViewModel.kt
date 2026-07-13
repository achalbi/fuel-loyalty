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

data class AdjustUiState(
    val customer: StaffCustomerDto? = null,
    val lookupLoading: Boolean = false,
    val lookupMessage: String? = null,
    val submitting: Boolean = false,
    val successMessage: String? = null,
    val errorMessage: String? = null,
)

class AdjustPointsViewModel(private val repository: StaffRepository) : ViewModel() {

    private val _state = MutableStateFlow(AdjustUiState())
    val state: StateFlow<AdjustUiState> = _state.asStateFlow()

    fun lookup(phoneNumber: String) {
        _state.update {
            it.copy(
                lookupLoading = true, lookupMessage = null, customer = null,
                successMessage = null, errorMessage = null,
            )
        }
        viewModelScope.launch {
            when (val result = repository.lookupCustomer(phoneNumber)) {
                is ApiResult.Success -> _state.update { it.copy(lookupLoading = false, customer = result.data) }
                is ApiResult.Error -> _state.update { it.copy(lookupLoading = false, lookupMessage = result.message) }
                is ApiResult.NetworkError -> _state.update {
                    it.copy(lookupLoading = false, lookupMessage = "Couldn't reach the server. Try again.")
                }
            }
        }
    }

    fun adjust(points: Int) {
        val customer = _state.value.customer ?: return
        _state.update { it.copy(submitting = true, errorMessage = null, successMessage = null) }
        viewModelScope.launch {
            when (val result = repository.adjustPoints(customer.phoneNumber.orEmpty(), points)) {
                is ApiResult.Success -> _state.update {
                    it.copy(submitting = false, customer = result.data.customer, successMessage = result.data.message)
                }
                is ApiResult.Error -> _state.update { it.copy(submitting = false, errorMessage = result.message) }
                is ApiResult.NetworkError -> _state.update {
                    it.copy(submitting = false, errorMessage = "Couldn't reach the server. Try again.")
                }
            }
        }
    }
}
