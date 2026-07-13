package com.acefuel.loyalty.ui.admin.dashboard

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.acefuel.loyalty.core.network.ApiResult
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

data class DashboardUiState(
    val loading: Boolean = false,
    val data: DashboardResponse? = null,
    val error: String? = null,
    /** null = the API's default rolling 30-day range. */
    val preset: String? = null,
    /** null = server default ("all"). */
    val segment: String? = null,
    val fuelType: String? = null,
)

class DashboardViewModel(private val repository: DashboardRepository) : ViewModel() {

    private val _state = MutableStateFlow(DashboardUiState())
    val state: StateFlow<DashboardUiState> = _state.asStateFlow()

    private var loadJob: Job? = null

    init {
        load()
    }

    /** Quick-range chip tapped. `preset` = null re-fetches the default range. */
    fun selectPreset(preset: String?) {
        if (preset == _state.value.preset && _state.value.data != null && _state.value.error == null) return
        _state.update { it.copy(preset = preset) }
        load()
    }

    fun selectSegment(segment: String?) {
        if (segment == _state.value.segment && _state.value.data != null && _state.value.error == null) return
        _state.update { it.copy(segment = segment) }
        load()
    }

    fun selectFuelType(fuelType: String?) {
        if (fuelType == _state.value.fuelType && _state.value.data != null && _state.value.error == null) return
        _state.update { it.copy(fuelType = fuelType) }
        load()
    }

    fun refresh() = load()

    private fun load() {
        val current = _state.value
        loadJob?.cancel()
        _state.update { it.copy(loading = true, error = null) }
        loadJob = viewModelScope.launch {
            val result = repository.loadDashboard(
                preset = current.preset,
                segment = current.segment,
                fuelType = current.fuelType,
            )
            when (result) {
                is ApiResult.Success ->
                    _state.update { it.copy(loading = false, data = result.data, error = null) }
                is ApiResult.Error ->
                    _state.update { it.copy(loading = false, error = result.message) }
                is ApiResult.NetworkError ->
                    _state.update { it.copy(loading = false, error = "Couldn't reach the server. Try again.") }
            }
        }
    }
}
