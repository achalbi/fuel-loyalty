package com.acefuel.loyalty.ui.admin.campaigns

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.acefuel.loyalty.core.network.ApiResult
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

data class CampaignsUiState(
    val loading: Boolean = true,
    val campaigns: List<CampaignDto> = emptyList(),
    val selected: CampaignDto? = null,
    val preview: CampaignPreviewResponse? = null,
    val busy: Boolean = false,
    val error: String? = null,
    val message: String? = null,
)

class CampaignsViewModel(private val repository: CampaignsRepository) : ViewModel() {

    private val _state = MutableStateFlow(CampaignsUiState())
    val state: StateFlow<CampaignsUiState> = _state.asStateFlow()

    init { loadList() }

    fun consumeError() = _state.update { it.copy(error = null) }
    fun consumeMessage() = _state.update { it.copy(message = null) }
    fun closeDetail() = _state.update { it.copy(selected = null, preview = null) }

    fun loadList() {
        _state.update { it.copy(loading = true, error = null) }
        viewModelScope.launch {
            when (val result = repository.list()) {
                is ApiResult.Success -> _state.update { it.copy(loading = false, campaigns = result.data.campaigns) }
                is ApiResult.Error -> _state.update { it.copy(loading = false, error = result.message) }
                is ApiResult.NetworkError -> _state.update { it.copy(loading = false, error = networkError) }
            }
        }
    }

    fun open(id: Long) {
        _state.update { it.copy(busy = true, error = null, preview = null) }
        viewModelScope.launch {
            when (val result = repository.show(id)) {
                is ApiResult.Success -> _state.update { it.copy(busy = false, selected = result.data) }
                is ApiResult.Error -> _state.update { it.copy(busy = false, error = result.message) }
                is ApiResult.NetworkError -> _state.update { it.copy(busy = false, error = networkError) }
            }
        }
    }

    fun preview() = withSelected { id -> whenResult(repository.preview(id)) { data -> _state.update { it.copy(busy = false, preview = data) } } }

    fun run() = withSelected { id ->
        whenResult(repository.run(id)) { data ->
            _state.update { it.copy(busy = false, message = "Ran — ${data.qualified} qualified, ${data.rewarded} rewarded.") }
        }
    }

    fun activate() = withSelected { id -> whenResult(repository.activate(id)) { data -> onStatusChanged(data, "Activated.") } }

    fun pause() = withSelected { id -> whenResult(repository.pause(id)) { data -> onStatusChanged(data, "Paused.") } }

    private fun onStatusChanged(campaign: CampaignDto, message: String) {
        _state.update { state ->
            state.copy(busy = false, selected = campaign, message = message,
                campaigns = state.campaigns.map { if (it.id == campaign.id) campaign else it })
        }
    }

    private inline fun withSelected(crossinline action: suspend (Long) -> Unit) {
        val id = _state.value.selected?.id ?: return
        _state.update { it.copy(busy = true, error = null) }
        viewModelScope.launch { action(id) }
    }

    private inline fun <T> whenResult(result: ApiResult<T>, onSuccess: (T) -> Unit) {
        when (result) {
            is ApiResult.Success -> onSuccess(result.data)
            is ApiResult.Error -> _state.update { it.copy(busy = false, error = result.message) }
            is ApiResult.NetworkError -> _state.update { it.copy(busy = false, error = networkError) }
        }
    }

    private val networkError get() = "Couldn't reach the server. Try again."
}
