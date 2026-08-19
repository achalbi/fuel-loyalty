package com.acefuel.loyalty.ui.admin.crm

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.acefuel.loyalty.core.network.ApiResult
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

/**
 * Item 4 — the six optional thresholds, held as raw text because that is what the
 * fields produce and what the wire takes. Blank means "not asked for"; the server
 * is the one that parses and validates, so a half-typed "12." never has to be
 * special-cased here.
 */
data class SegmentFilters(
    val minVisits: String = "",
    val minLitres: String = "",
    val minDiscount: String = "",
    val minContacts: String = "",
    val minPointsEarned: String = "",
    val minPointsBalance: String = "",
    // null = all time; otherwise one of the dashboard presets.
    val preset: String? = null,
) {
    val appliedCount: Int
        get() = listOf(minVisits, minLitres, minDiscount, minContacts, minPointsEarned, minPointsBalance)
            .count { it.isNotBlank() }
}

data class CustomerSegmentsUiState(
    val filters: SegmentFilters = SegmentFilters(),
    val loading: Boolean = true,
    val response: CustomerCohortResponse? = null,
    val error: String? = null,
)

/**
 * Drives the admin-only "Segments" screen. Deliberately explicit: editing a
 * threshold only changes the draft, and [load] is what hits the network — a
 * cohort query is expensive enough on the server that debouncing every keystroke
 * into it would be the wrong trade.
 */
class CustomerSegmentsViewModel(private val repository: CrmRepository) : ViewModel() {

    private val _state = MutableStateFlow(CustomerSegmentsUiState())
    val state: StateFlow<CustomerSegmentsUiState> = _state.asStateFlow()

    // Monotonic id per request, so a slow earlier cohort cannot overwrite a
    // fresher one (same guard CustomersViewModel uses for search).
    private var epoch = 0

    init { load() }

    fun onFiltersChange(filters: SegmentFilters) = _state.update { it.copy(filters = filters) }

    fun clear() {
        _state.update { it.copy(filters = SegmentFilters()) }
        load()
    }

    fun load(page: Int? = null) {
        val current = ++epoch
        val filters = _state.value.filters
        _state.update { it.copy(loading = true, error = null) }
        viewModelScope.launch {
            val result = repository.customerCohort(
                preset = filters.preset,
                minVisits = filters.minVisits.ifBlank { null },
                minLitres = filters.minLitres.ifBlank { null },
                minDiscount = filters.minDiscount.ifBlank { null },
                minContacts = filters.minContacts.ifBlank { null },
                minPointsEarned = filters.minPointsEarned.ifBlank { null },
                minPointsBalance = filters.minPointsBalance.ifBlank { null },
                page = page,
            )
            if (current != epoch) return@launch // superseded

            when (result) {
                is ApiResult.Success -> _state.update { it.copy(loading = false, response = result.data) }
                is ApiResult.Error -> _state.update { it.copy(loading = false, error = result.message) }
                is ApiResult.NetworkError ->
                    _state.update { it.copy(loading = false, error = "Couldn't reach the server. Try again.") }
            }
        }
    }
}
