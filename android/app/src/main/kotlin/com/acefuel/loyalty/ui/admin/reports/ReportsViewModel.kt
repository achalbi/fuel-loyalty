package com.acefuel.loyalty.ui.admin.reports

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.acefuel.loyalty.core.network.ApiResult
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

data class ReportsUiState(
    val dimension: String = "vehicle",
    val grain: String = "month",
    // Set to pull a single customer's report (E1 customer_id filter); null = all.
    val customerId: Long? = null,
    val loading: Boolean = true,
    val response: ReportResponse? = null,
    val error: String? = null,
) {
    companion object {
        val DIMENSIONS = listOf("vehicle", "transporter", "driver", "customer")
        val GRAINS = listOf("day", "week", "month", "year")
    }
}

class ReportsViewModel(
    private val repository: ReportsRepository,
    initialCustomerId: Long? = null,
) : ViewModel() {

    private val _state = MutableStateFlow(ReportsUiState(customerId = initialCustomerId))
    val state: StateFlow<ReportsUiState> = _state.asStateFlow()

    init { load() }

    fun onDimension(value: String) { _state.update { it.copy(dimension = value) }; load() }
    fun onGrain(value: String) { _state.update { it.copy(grain = value) }; load() }
    fun onCustomer(value: Long?) { _state.update { it.copy(customerId = value) }; load() }
    fun consumeError() = _state.update { it.copy(error = null) }

    fun load() {
        val s = _state.value
        _state.update { it.copy(loading = true, error = null) }
        viewModelScope.launch {
            when (val result = repository.report(s.dimension, s.grain, customerId = s.customerId)) {
                is ApiResult.Success -> _state.update { it.copy(loading = false, response = result.data) }
                is ApiResult.Error -> _state.update { it.copy(loading = false, error = result.message) }
                is ApiResult.NetworkError -> _state.update { it.copy(loading = false, error = "Couldn't reach the server. Try again.") }
            }
        }
    }
}
