package com.acefuel.loyalty.ui.admin.crm

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.acefuel.loyalty.core.network.ApiResult
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

data class ReachOutUiState(
    val loading: Boolean = true,
    val response: ChurnResponse? = null,
    val error: String? = null,
)

/**
 * Drives the admin "Reach out" list — customers overdue past their usual visit
 * cadence. v1 uses the server's default period (no date pickers); [load] can be
 * re-run to retry after an error.
 */
class ReachOutViewModel(private val repository: CrmRepository) : ViewModel() {

    private val _state = MutableStateFlow(ReachOutUiState())
    val state: StateFlow<ReachOutUiState> = _state.asStateFlow()

    init { load() }

    fun load() {
        _state.update { it.copy(loading = true, error = null) }
        viewModelScope.launch {
            when (val result = repository.churn()) {
                is ApiResult.Success -> _state.update { it.copy(loading = false, response = result.data) }
                is ApiResult.Error -> _state.update { it.copy(loading = false, error = result.message) }
                is ApiResult.NetworkError ->
                    _state.update { it.copy(loading = false, error = "Couldn't reach the server. Try again.") }
            }
        }
    }
}
