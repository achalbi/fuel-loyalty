package com.acefuel.loyalty.ui.loyalty

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.acefuel.loyalty.core.data.LoyaltyRepository
import com.acefuel.loyalty.core.network.ApiResult
import com.acefuel.loyalty.core.network.dto.LoyaltyResponse
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

sealed interface LoyaltyUiState {
    data object Idle : LoyaltyUiState
    data object Loading : LoyaltyUiState
    data class Success(
        val data: LoyaltyResponse,
        val offline: Boolean = false,
        val fetchedAtMillis: Long? = null,
    ) : LoyaltyUiState
    data class Error(val message: String) : LoyaltyUiState
}

class LoyaltyViewModel(private val repository: LoyaltyRepository) : ViewModel() {

    private val _state = MutableStateFlow<LoyaltyUiState>(LoyaltyUiState.Idle)
    val state: StateFlow<LoyaltyUiState> = _state.asStateFlow()

    fun lookup(phoneNumber: String) {
        _state.value = LoyaltyUiState.Loading
        viewModelScope.launch {
            _state.value = when (val result = repository.lookup(phoneNumber)) {
                is ApiResult.Success -> LoyaltyUiState.Success(result.data)
                is ApiResult.Error -> LoyaltyUiState.Error(result.message)
                is ApiResult.NetworkError -> {
                    // Offline: fall back to the last cached balance if we have one.
                    val cached = repository.cachedFor(phoneNumber)
                    if (cached != null) {
                        LoyaltyUiState.Success(cached.data, offline = true, fetchedAtMillis = cached.fetchedAtMillis)
                    } else {
                        LoyaltyUiState.Error("Couldn't reach the server. Check your connection and try again.")
                    }
                }
            }
        }
    }

    fun reset() {
        _state.value = LoyaltyUiState.Idle
    }
}
