package com.acefuel.loyalty.ui.customers

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.acefuel.loyalty.core.data.StaffRepository
import com.acefuel.loyalty.core.network.ApiResult
import com.acefuel.loyalty.core.network.dto.CustomerSummaryDto
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

data class CustomersUiState(
    val query: String = "",
    val loading: Boolean = false,
    val refreshing: Boolean = false,
    val customers: List<CustomerSummaryDto> = emptyList(),
    val error: String? = null,
)

class CustomersViewModel(private val repository: StaffRepository) : ViewModel() {

    private val _state = MutableStateFlow(CustomersUiState())
    val state: StateFlow<CustomersUiState> = _state.asStateFlow()

    private var searchJob: Job? = null

    // Monotonic id per request; a response only lands if it is still the
    // newest, so a slow stale query can't overwrite fresher results.
    private var searchEpoch = 0

    init {
        search("")
    }

    fun onQueryChange(query: String) {
        _state.update { it.copy(query = query) }
        searchJob?.cancel()
        searchJob = viewModelScope.launch {
            delay(300) // debounce
            search(query)
        }
    }

    fun refresh() = search(_state.value.query, asRefresh = true)

    fun retry() = search(_state.value.query)

    fun consumeError() = _state.update { it.copy(error = null) }

    private fun search(query: String, asRefresh: Boolean = false) {
        val epoch = ++searchEpoch
        _state.update { it.copy(loading = !asRefresh, refreshing = asRefresh, error = null) }
        viewModelScope.launch {
            val result = repository.customers(query)
            if (epoch != searchEpoch) return@launch // superseded by a newer search
            when (result) {
                is ApiResult.Success ->
                    _state.update { it.copy(loading = false, refreshing = false, customers = result.data) }
                is ApiResult.Error ->
                    _state.update { it.copy(loading = false, refreshing = false, error = result.message) }
                is ApiResult.NetworkError ->
                    _state.update {
                        it.copy(loading = false, refreshing = false, error = "Couldn't reach the server. Try again.")
                    }
            }
        }
    }
}
