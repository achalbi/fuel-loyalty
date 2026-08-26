package com.acefuel.loyalty.ui.admin.settlements

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.acefuel.loyalty.core.network.ApiResult
import com.acefuel.loyalty.ui.settlement.SettlementSummaryDto
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.time.LocalDate

/** The named ranges the filter bar offers; [from]/[to] are resolved against today. */
enum class SettlementRangePreset(val label: String) {
    Today("Today"),
    Yesterday("Yesterday"),
    Last7("Last 7 days"),
    Last30("Last 30 days"),
    ThisMonth("This month"),
    LastMonth("Last month"),
    ;

    fun from(today: LocalDate): LocalDate = when (this) {
        Today -> today
        Yesterday -> today.minusDays(1)
        Last7 -> today.minusDays(6)
        Last30 -> today.minusDays(29)
        ThisMonth -> today.withDayOfMonth(1)
        LastMonth -> today.minusMonths(1).withDayOfMonth(1)
    }

    fun to(today: LocalDate): LocalDate = when (this) {
        Yesterday -> today.minusDays(1)
        LastMonth -> today.withDayOfMonth(1).minusDays(1)
        ThisMonth -> today.withDayOfMonth(today.lengthOfMonth())
        else -> today
    }
}

data class AdminSettlementsUiState(
    val loading: Boolean = true,
    val settlements: List<SettlementSummaryDto> = emptyList(),
    val crossPumpTotals: CrossPumpTotalsDto? = null,
    // Filters. A null end is an open one — "everything since the 1st" is as
    // ordinary a question as a closed range.
    val from: LocalDate? = null,
    val to: LocalDate? = null,
    val query: String = "",
    val status: String? = null,
    // Master-detail: a non-null selection shows the detail view.
    val selected: AdminSettlementDto? = null,
    val detailLoading: Boolean = false,
    val reconciling: Boolean = false,
    val error: String? = null,
    val message: String? = null,
) {
    val filtered: Boolean get() = from != null || to != null || query.isNotBlank() || status != null
}

class AdminSettlementsViewModel(private val repository: AdminSettlementsRepository) : ViewModel() {

    private val _state = MutableStateFlow(AdminSettlementsUiState())
    val state: StateFlow<AdminSettlementsUiState> = _state.asStateFlow()

    private var searchJob: Job? = null

    // Monotonic id per request; a response only lands if it is still the newest,
    // so a slow stale query can't overwrite fresher results.
    private var epoch = 0

    init { loadList() }

    fun onQuery(value: String) {
        _state.update { it.copy(query = value) }
        searchJob?.cancel()
        searchJob = viewModelScope.launch {
            delay(300) // debounce
            loadList()
        }
    }

    fun onFrom(value: LocalDate?) = applyFilter { it.copy(from = value) }

    fun onTo(value: LocalDate?) = applyFilter { it.copy(to = value) }

    /** Tapping the chip already in force clears it — a filter you cannot undo is a trap. */
    fun onStatus(value: String?) = applyFilter { state ->
        state.copy(status = if (state.status == value) null else value)
    }

    fun onPreset(preset: SettlementRangePreset, today: LocalDate = LocalDate.now()) =
        applyFilter { it.copy(from = preset.from(today), to = preset.to(today)) }

    fun clearRange() = applyFilter { it.copy(from = null, to = null) }

    fun clearFilters() = applyFilter { it.copy(from = null, to = null, query = "", status = null) }

    fun consumeError() = _state.update { it.copy(error = null) }
    fun consumeMessage() = _state.update { it.copy(message = null) }

    private fun applyFilter(change: (AdminSettlementsUiState) -> AdminSettlementsUiState) {
        _state.update(change)
        searchJob?.cancel()
        loadList()
    }

    fun loadList() {
        val filters = _state.value
        val request = ++epoch
        _state.update { it.copy(loading = true, error = null) }
        viewModelScope.launch {
            val result = repository.list(
                from = filters.from?.toString(),
                to = filters.to?.toString(),
                status = filters.status,
                query = filters.query.trim().ifBlank { null },
            )
            if (request != epoch) return@launch
            when (result) {
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
