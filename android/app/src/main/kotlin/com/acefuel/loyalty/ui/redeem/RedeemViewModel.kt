package com.acefuel.loyalty.ui.redeem

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

data class RedeemUiState(
    val customer: StaffCustomerDto? = null,
    val lookupLoading: Boolean = false,
    val lookupMessage: String? = null,
    val selectedPoints: Int? = null,
    val redeeming: Boolean = false,
    val successMessage: String? = null,
    val redeemError: String? = null,
) {
    /** Amounts selectable in the picker: min..max stepping by the increment. */
    val pointOptions: List<Int>
        get() {
            val c = customer ?: return emptyList()
            if (c.maxRedeemablePoints < c.minimumRedeemablePoints) return emptyList()
            val step = c.redemptionIncrement.coerceAtLeast(1)
            return generateSequence(c.minimumRedeemablePoints) { it + step }
                .takeWhile { it <= c.maxRedeemablePoints }
                .toList()
        }

    val canRedeem: Boolean
        get() = customer != null && !redeeming && selectedPoints != null && selectedPoints in pointOptions
}

class RedeemViewModel(private val repository: StaffRepository) : ViewModel() {

    private val _state = MutableStateFlow(RedeemUiState())
    val state: StateFlow<RedeemUiState> = _state.asStateFlow()

    fun lookup(phoneNumber: String) {
        _state.update {
            it.copy(
                lookupLoading = true, lookupMessage = null, customer = null,
                selectedPoints = null, successMessage = null, redeemError = null,
            )
        }
        viewModelScope.launch {
            when (val result = repository.lookupCustomer(phoneNumber)) {
                is ApiResult.Success ->
                    _state.update { it.copy(lookupLoading = false, customer = result.data) }
                is ApiResult.Error ->
                    _state.update { it.copy(lookupLoading = false, lookupMessage = result.message) }
                is ApiResult.NetworkError ->
                    _state.update {
                        it.copy(lookupLoading = false, lookupMessage = "Couldn't reach the server. Try again.")
                    }
            }
        }
    }

    fun selectPoints(points: Int) {
        _state.update { it.copy(selectedPoints = points, redeemError = null, successMessage = null) }
    }

    fun redeem() {
        val current = _state.value
        val customer = current.customer ?: return
        val points = current.selectedPoints ?: return
        _state.update { it.copy(redeeming = true, redeemError = null, successMessage = null) }
        viewModelScope.launch {
            when (val result = repository.redeem(customer.phoneNumber.orEmpty(), points)) {
                is ApiResult.Success -> _state.update {
                    it.copy(
                        redeeming = false,
                        customer = result.data.customer,
                        selectedPoints = null,
                        successMessage = result.data.message,
                    )
                }
                is ApiResult.Error -> _state.update {
                    it.copy(redeeming = false, redeemError = result.message)
                }
                is ApiResult.NetworkError -> _state.update {
                    it.copy(redeeming = false, redeemError = "Couldn't reach the server. Try again.")
                }
            }
        }
    }
}
