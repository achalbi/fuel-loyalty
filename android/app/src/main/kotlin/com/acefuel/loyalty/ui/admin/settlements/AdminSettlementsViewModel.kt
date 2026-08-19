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
    // Admin-12 — the "recorded by" filter and the per-FSM rollup for the listed
    // day. fsmOptions is server-supplied (it includes admins).
    val recordedById: Long? = null,
    val fsmOptions: List<FsmOptionDto> = emptyList(),
    val perFsmTotals: List<PerFsmTotalsDto> = emptyList(),
    // The server's account of which recorder these rows were narrowed to. Taken
    // from the response rather than from recordedById above so the totals card
    // is labelled for the data it is actually showing, never for a filter tap
    // whose reload has not landed yet.
    val filteredBy: SettlementFilterDto? = null,
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

    // No init load: AdminSettlementsScreen reloads on every ON_RESUME, which also
    // covers returning from the on-behalf form. Loading here too would double the
    // first request.

    fun onDate(value: String?) { _state.update { it.copy(businessDate = value?.ifBlank { null }) }; loadList() }
    fun onRecordedBy(userId: Long?) { _state.update { it.copy(recordedById = userId) }; loadList() }
    fun consumeError() = _state.update { it.copy(error = null) }
    fun consumeMessage() = _state.update { it.copy(message = null) }

    fun loadList() {
        val date = _state.value.businessDate
        val recordedById = _state.value.recordedById
        _state.update { it.copy(loading = true, error = null) }
        viewModelScope.launch {
            when (val result = repository.list(businessDate = date, recordedById = recordedById)) {
                is ApiResult.Success -> _state.update {
                    it.copy(
                        loading = false,
                        settlements = result.data.settlements,
                        crossPumpTotals = result.data.crossPumpTotals,
                        perFsmTotals = result.data.perFsmTotals,
                        filteredBy = result.data.filteredBy,
                        // Keep the last non-empty option list: filtering down to
                        // an FSM with no sheets must not empty the filter itself.
                        fsmOptions = result.data.fsmOptions.ifEmpty { it.fsmOptions },
                    )
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
