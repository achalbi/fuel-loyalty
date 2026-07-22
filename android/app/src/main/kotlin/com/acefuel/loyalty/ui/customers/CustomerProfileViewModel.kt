package com.acefuel.loyalty.ui.customers

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.acefuel.loyalty.core.data.StaffRepository
import com.acefuel.loyalty.core.network.ApiResult
import com.acefuel.loyalty.core.network.dto.CustomerProfileDto
import com.acefuel.loyalty.core.network.dto.CustomerUpdateRequest
import com.acefuel.loyalty.core.network.dto.LedgerEntryDto
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

enum class ProfileAction { Pause, Active, OptIn }

data class ProfileUiState(
    val loading: Boolean = true,
    val refreshing: Boolean = false,
    val profile: CustomerProfileDto? = null,
    /** Initial-load failure; full-area ErrorState when there is no profile. */
    val error: String? = null,
    /** One-shot failure while data is on screen — surfaced as a snackbar. */
    val transientError: String? = null,
    /** One-shot success message after pause/activate — success snackbar. */
    val actionMessage: String? = null,
    val ledger: List<LedgerEntryDto> = emptyList(),
    val ledgerPage: Int = 0,
    val ledgerTotal: Int = 0,
    val ledgerHasMore: Boolean = false,
    val ledgerLoading: Boolean = false,
    val actionInFlight: ProfileAction? = null,
)

class CustomerProfileViewModel(
    private val repository: StaffRepository,
    private val customerId: Long,
) : ViewModel() {

    private val _state = MutableStateFlow(ProfileUiState())
    val state: StateFlow<ProfileUiState> = _state.asStateFlow()

    init {
        load()
        loadMoreLedger()
    }

    fun load() {
        _state.update { it.copy(loading = true, error = null) }
        viewModelScope.launch {
            when (val result = repository.customerProfile(customerId)) {
                is ApiResult.Success -> _state.update { it.copy(loading = false, profile = result.data) }
                is ApiResult.Error -> _state.update { it.copy(loading = false, error = result.message) }
                is ApiResult.NetworkError ->
                    _state.update { it.copy(loading = false, error = "Couldn't reach the server. Try again.") }
            }
        }
    }

    /** Full retry after an initial-load failure: profile plus first ledger page. */
    fun retry() {
        load()
        if (_state.value.ledger.isEmpty()) loadMoreLedger()
    }

    fun refresh() {
        if (_state.value.refreshing) return
        _state.update { it.copy(refreshing = true) }
        viewModelScope.launch {
            when (val result = repository.customerProfile(customerId)) {
                is ApiResult.Success -> {
                    _state.update { it.copy(refreshing = false, profile = result.data) }
                    refreshLedger()
                }
                is ApiResult.Error ->
                    _state.update { it.copy(refreshing = false, transientError = result.message) }
                is ApiResult.NetworkError ->
                    _state.update {
                        it.copy(refreshing = false, transientError = "Couldn't reach the server. Try again.")
                    }
            }
        }
    }

    /** Reload the first ledger page after a successful profile refresh. */
    private suspend fun refreshLedger() {
        if (_state.value.ledgerLoading) return
        // Hold ledgerLoading for the whole reload so a concurrent "Load more"
        // (gated on !ledgerLoading) can't append a stale page over page 1.
        _state.update { it.copy(ledgerLoading = true) }
        val result = repository.customerLedger(customerId, 1)
        _state.update {
            when (result) {
                is ApiResult.Success -> it.copy(
                    ledgerLoading = false,
                    ledger = result.data.entries,
                    ledgerPage = result.data.page,
                    ledgerTotal = result.data.total,
                    ledgerHasMore = result.data.hasMore,
                )
                else -> it.copy(ledgerLoading = false) // keep the stale ledger
            }
        }
    }

    fun loadMoreLedger() {
        val current = _state.value
        if (current.ledgerLoading) return
        if (current.ledgerPage > 0 && !current.ledgerHasMore) return
        _state.update { it.copy(ledgerLoading = true) }
        viewModelScope.launch {
            when (val result = repository.customerLedger(customerId, current.ledgerPage + 1)) {
                is ApiResult.Success -> _state.update {
                    it.copy(
                        ledgerLoading = false,
                        ledger = it.ledger + result.data.entries,
                        ledgerPage = result.data.page,
                        ledgerTotal = result.data.total,
                        ledgerHasMore = result.data.hasMore,
                    )
                }
                is ApiResult.Error ->
                    _state.update { it.copy(ledgerLoading = false, transientError = result.message) }
                is ApiResult.NetworkError ->
                    _state.update {
                        it.copy(
                            ledgerLoading = false,
                            transientError = "Couldn't load more ledger entries. Try again.",
                        )
                    }
            }
        }
    }

    fun togglePaused() {
        val profile = _state.value.profile ?: return
        val pausing = !profile.rewardsPaused
        runAction(ProfileAction.Pause, if (pausing) "Rewards paused" else "Rewards resumed") {
            repository.setPaused(customerId, pausing)
        }
    }

    fun toggleActive() {
        val profile = _state.value.profile ?: return
        val deactivating = profile.active
        runAction(ProfileAction.Active, if (deactivating) "Customer marked inactive" else "Customer marked active") {
            repository.setActive(customerId, !profile.active)
        }
    }

    // F2 — channel opt-ins (set with the customer's consent).
    fun setWhatsappOptIn(enabled: Boolean) {
        _state.value.profile ?: return
        runAction(ProfileAction.OptIn, if (enabled) "WhatsApp offers on" else "WhatsApp offers off") {
            repository.updateCustomer(customerId, CustomerUpdateRequest(whatsappOptIn = enabled))
        }
    }

    fun setSmsOptIn(enabled: Boolean) {
        _state.value.profile ?: return
        runAction(ProfileAction.OptIn, if (enabled) "SMS offers on" else "SMS offers off") {
            repository.updateCustomer(customerId, CustomerUpdateRequest(smsOptIn = enabled))
        }
    }

    // One-shot consumers so each snackbar fires exactly once.
    fun consumeActionMessage() = _state.update { it.copy(actionMessage = null) }

    fun consumeTransientError() = _state.update { it.copy(transientError = null) }

    private fun runAction(
        kind: ProfileAction,
        successMessage: String,
        block: suspend () -> ApiResult<CustomerProfileDto>,
    ) {
        if (_state.value.actionInFlight != null) return
        _state.update { it.copy(actionInFlight = kind, transientError = null) }
        viewModelScope.launch {
            when (val result = block()) {
                is ApiResult.Success ->
                    _state.update { it.copy(actionInFlight = null, profile = result.data, actionMessage = successMessage) }
                is ApiResult.Error ->
                    _state.update { it.copy(actionInFlight = null, transientError = result.message) }
                is ApiResult.NetworkError ->
                    _state.update {
                        it.copy(actionInFlight = null, transientError = "Couldn't reach the server. Try again.")
                    }
            }
        }
    }
}
