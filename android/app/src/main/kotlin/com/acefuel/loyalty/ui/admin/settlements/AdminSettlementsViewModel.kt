package com.acefuel.loyalty.ui.admin.settlements

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.acefuel.loyalty.core.network.ApiResult
import com.acefuel.loyalty.ui.settlement.SettlementSummaryDto
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

data class AdminSettlementsUiState(
    val loading: Boolean = true,
    val settlements: List<SettlementSummaryDto> = emptyList(),
    val crossPumpTotals: CrossPumpTotalsDto? = null,
    val businessDate: String? = null,
    // Master-detail: a non-null selection shows the detail view.
    val selected: AdminSettlementDto? = null,
    val detailLoading: Boolean = false,
    val reconciling: Boolean = false,
    val error: String? = null,
    val message: String? = null,
)

class AdminSettlementsViewModel(private val repository: AdminSettlementsRepository) : ViewModel() {

    private val _state = MutableStateFlow(AdminSettlementsUiState())
    val state: StateFlow<AdminSettlementsUiState> = _state.asStateFlow()

    init { loadList() }

    fun onDate(value: String?) { _state.update { it.copy(businessDate = value?.ifBlank { null }) }; loadList() }
    fun consumeError() = _state.update { it.copy(error = null) }
    fun consumeMessage() = _state.update { it.copy(message = null) }

    fun loadList() {
        val date = _state.value.businessDate
        _state.update { it.copy(loading = true, error = null) }
        viewModelScope.launch {
            when (val result = repository.list(businessDate = date)) {
                is ApiResult.Success -> _state.update {
                    it.copy(loading = false, settlements = result.data.settlements, crossPumpTotals = result.data.crossPumpTotals)
                }
                is ApiResult.Error -> _state.update { it.copy(loading = false, error = result.message) }
                is ApiResult.NetworkError -> _state.update { it.copy(loading = false, error = "Couldn't reach the server. Try again.") }
            }
        }
    }

    fun open(id: Long) {
        _state.update { it.copy(detailLoading = true, error = null) }
        viewModelScope.launch {
            when (val result = repository.show(id)) {
                is ApiResult.Success -> _state.update { it.copy(detailLoading = false, selected = result.data) }
                is ApiResult.Error -> _state.update { it.copy(detailLoading = false, error = result.message) }
                is ApiResult.NetworkError -> _state.update { it.copy(detailLoading = false, error = "Couldn't reach the server. Try again.") }
            }
        }
    }

    fun closeDetail() = _state.update { it.copy(selected = null) }

    fun reconcile() {
        val id = _state.value.selected?.id ?: return
        _state.update { it.copy(reconciling = true, error = null) }
        viewModelScope.launch {
            when (val result = repository.reconcile(id)) {
                is ApiResult.Success -> {
                    _state.update { it.copy(reconciling = false, selected = result.data, message = "Settlement reconciled and locked.") }
                    loadList()
                }
                is ApiResult.Error -> _state.update { it.copy(reconciling = false, error = result.message) }
                is ApiResult.NetworkError -> _state.update { it.copy(reconciling = false, error = "Couldn't reach the server. Try again.") }
            }
        }
    }
}
