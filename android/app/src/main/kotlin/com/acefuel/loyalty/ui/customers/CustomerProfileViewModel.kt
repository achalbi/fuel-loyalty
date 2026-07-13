package com.acefuel.loyalty.ui.customers

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.acefuel.loyalty.core.data.StaffRepository
import com.acefuel.loyalty.core.network.ApiResult
import com.acefuel.loyalty.core.network.dto.CustomerProfileDto
import com.acefuel.loyalty.core.network.dto.LedgerEntryDto
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

data class ProfileUiState(
    val loading: Boolean = true,
    val profile: CustomerProfileDto? = null,
    val error: String? = null,
    val ledger: List<LedgerEntryDto> = emptyList(),
    val ledgerPage: Int = 0,
    val ledgerTotal: Int = 0,
    val ledgerHasMore: Boolean = false,
    val ledgerLoading: Boolean = false,
    val actionInFlight: Boolean = false,
)

class CustomerProfileViewModel(
    private val repository: StaffRepository,
    private val customerId: Long,
) : ViewModel() {

    private val _state = MutableStateFlow(ProfileUiState())
    val state: StateFlow<ProfileUiState> = _state.asStateFlow()

    init {
        load()
        loadMoreLedger()
    }

    private fun load() {
        _state.update { it.copy(loading = true, error = null) }
        viewModelScope.launch {
            when (val result = repository.customerProfile(customerId)) {
                is ApiResult.Success -> _state.update { it.copy(loading = false, profile = result.data) }
                is ApiResult.Error -> _state.update { it.copy(loading = false, error = result.message) }
                is ApiResult.NetworkError ->
                    _state.update { it.copy(loading = false, error = "Couldn't reach the server. Try again.") }
            }
        }
    }

    fun loadMoreLedger() {
        val current = _state.value
        if (current.ledgerLoading) return
        if (current.ledgerPage > 0 && !current.ledgerHasMore) return
        _state.update { it.copy(ledgerLoading = true) }
        viewModelScope.launch {
            when (val result = repository.customerLedger(customerId, current.ledgerPage + 1)) {
                is ApiResult.Success -> _state.update {
                    it.copy(
                        ledgerLoading = false,
                        ledger = it.ledger + result.data.entries,
                        ledgerPage = result.data.page,
                        ledgerTotal = result.data.total,
                        ledgerHasMore = result.data.hasMore,
                    )
                }
                else -> _state.update { it.copy(ledgerLoading = false) }
            }
        }
    }

    fun togglePaused() {
        val profile = _state.value.profile ?: return
        runAction { repository.setPaused(customerId, !profile.rewardsPaused) }
    }

    fun toggleActive() {
        val profile = _state.value.profile ?: return
        runAction { repository.setActive(customerId, !profile.active) }
    }

    private fun runAction(block: suspend () -> ApiResult<CustomerProfileDto>) {
        _state.update { it.copy(actionInFlight = true, error = null) }
        viewModelScope.launch {
            when (val result = block()) {
                is ApiResult.Success ->
                    _state.update { it.copy(actionInFlight = false, profile = result.data) }
                is ApiResult.Error ->
                    _state.update { it.copy(actionInFlight = false, error = result.message) }
                is ApiResult.NetworkError ->
                    _state.update { it.copy(actionInFlight = false, error = "Couldn't reach the server. Try again.") }
            }
        }
    }
}
