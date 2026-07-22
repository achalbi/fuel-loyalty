package com.acefuel.loyalty.ui.admin.notifications

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.acefuel.loyalty.core.network.ApiResult
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

private const val NETWORK_MESSAGE = "Couldn't reach the server. Try again."

data class DeliveryHistoryUiState(
    val loading: Boolean = false,
    val refreshing: Boolean = false,
    val error: String? = null,
    val actionError: String? = null,
    val messages: List<NotificationMessageDto> = emptyList(),
    // Recipient detail sheet (per selected message).
    val selected: NotificationMessageDto? = null,
    val recipientsLoading: Boolean = false,
    val recipients: List<NotificationRecipientDto> = emptyList(),
    val recipientsError: String? = null,
)

class NotificationsHistoryViewModel(
    private val repository: NotificationsHistoryRepository,
) : ViewModel() {

    private val _state = MutableStateFlow(DeliveryHistoryUiState())
    val state: StateFlow<DeliveryHistoryUiState> = _state.asStateFlow()

    init {
        load()
    }

    fun load() = fetch(asRefresh = false)

    fun refresh() = fetch(asRefresh = true)

    private fun fetch(asRefresh: Boolean) {
        _state.update {
            if (asRefresh) it.copy(refreshing = true) else it.copy(loading = true, error = null)
        }
        viewModelScope.launch {
            when (val result = repository.list()) {
                is ApiResult.Success ->
                    _state.update { it.copy(loading = false, refreshing = false, error = null, messages = result.data) }
                is ApiResult.Error -> onFetchFailure(result.message)
                is ApiResult.NetworkError -> onFetchFailure(NETWORK_MESSAGE)
            }
        }
    }

    /** Empty screen keeps the full-area error; stale data stays with a snackbar. */
    private fun onFetchFailure(message: String) {
        _state.update {
            if (it.messages.isEmpty()) {
                it.copy(loading = false, refreshing = false, error = message)
            } else {
                it.copy(loading = false, refreshing = false, actionError = message)
            }
        }
    }

    fun consumeActionError() = _state.update { it.copy(actionError = null) }

    fun openRecipients(message: NotificationMessageDto) {
        _state.update {
            it.copy(
                selected = message,
                recipientsLoading = true,
                recipients = emptyList(),
                recipientsError = null,
            )
        }
        viewModelScope.launch {
            when (val result = repository.recipients(message.id)) {
                is ApiResult.Success -> _state.update {
                    if (it.selected?.id == message.id) it.copy(recipientsLoading = false, recipients = result.data) else it
                }
                is ApiResult.Error -> _state.update {
                    if (it.selected?.id == message.id) it.copy(recipientsLoading = false, recipientsError = result.message) else it
                }
                is ApiResult.NetworkError -> _state.update {
                    if (it.selected?.id == message.id) it.copy(recipientsLoading = false, recipientsError = NETWORK_MESSAGE) else it
                }
            }
        }
    }

    fun closeRecipients() = _state.update {
        it.copy(selected = null, recipientsLoading = false, recipients = emptyList(), recipientsError = null)
    }
}
