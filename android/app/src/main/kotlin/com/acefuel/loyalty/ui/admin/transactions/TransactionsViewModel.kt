package com.acefuel.loyalty.ui.admin.transactions

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.acefuel.loyalty.core.network.ApiResult
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

private const val NETWORK_MESSAGE = "Couldn't reach the server. Try again."

/** Quick range chips. Values match the backend RANGE_OPTIONS. */
val RANGE_OPTIONS = listOf("all" to "All", "today" to "Today")

/** Sort menu options. Keys match the backend SORT_OPTIONS. */
val SORT_OPTIONS = listOf(
    "time_desc" to "Time (latest first)",
    "time_asc" to "Time (oldest first)",
    "amount_desc" to "Amount (high to low)",
    "amount_asc" to "Amount (low to high)",
)

data class TransactionsUiState(
    val loading: Boolean = false,
    /** Pull-to-refresh in progress (rows stay visible). */
    val refreshing: Boolean = false,
    /** Full-area failure — only set when there are no rows to keep on screen. */
    val error: String? = null,
    /** One-shot failure with stale rows kept on screen; consumed by the snackbar. */
    val errorMessage: String? = null,
    val transactions: List<AdminTransactionDto> = emptyList(),
    val range: String = "all",
    val sort: String = "time_desc",
    val page: Int = 1,
    val perPage: Int = 10,
    val total: Int = 0,
    val hasMore: Boolean = false,
    val expandedId: Long? = null,
) {
    /** 1-indexed position of the first row on this page ("Showing X…"). */
    val showingFrom: Int get() = if (total == 0) 0 else (page - 1) * perPage + 1

    /** 1-indexed position of the last row on this page ("…–Y of N"). */
    val showingTo: Int get() = if (total == 0) 0 else minOf(page * perPage, total)

    val canPrev: Boolean get() = page > 1
    val canNext: Boolean get() = hasMore

    val sortLabel: String get() = SORT_OPTIONS.firstOrNull { it.first == sort }?.second ?: sort
}

class TransactionsViewModel(private val repository: TransactionsRepository) : ViewModel() {

    private val _state = MutableStateFlow(TransactionsUiState())
    val state: StateFlow<TransactionsUiState> = _state.asStateFlow()

    private var loadJob: Job? = null

    // Navigation state (page/range/sort/counters) matching the rows currently
    // on screen. A failed load that keeps stale rows rolls back to this so the
    // "Showing X–Y" caption and Prev/Next never desync from what's displayed.
    private var lastGood: TransactionsUiState? = null

    init {
        load()
    }

    fun load() = load(asRefresh = false)

    /** Pull-to-refresh: keeps rows visible; falls back to a full load when the list is empty. */
    fun refresh() = load(asRefresh = _state.value.transactions.isNotEmpty())

    private fun load(asRefresh: Boolean) {
        loadJob?.cancel()
        _state.update { it.copy(loading = !asRefresh, refreshing = asRefresh, error = null) }
        val s = _state.value
        loadJob = viewModelScope.launch {
            when (val result = repository.loadTransactions(s.range, s.sort, null, null, s.page)) {
                is ApiResult.Success -> _state.update {
                    it.copy(
                        loading = false,
                        refreshing = false,
                        error = null,
                        transactions = result.data.transactions,
                        page = result.data.page,
                        perPage = result.data.perPage,
                        total = result.data.total,
                        hasMore = result.data.hasMore,
                    ).also { committed -> lastGood = committed }
                }
                is ApiResult.Error -> fail(result.message)
                is ApiResult.NetworkError -> fail(NETWORK_MESSAGE)
            }
        }
    }

    /** Stale rows on screen -> one-shot snackbar + rollback; empty screen -> full-area error. */
    private fun fail(message: String) = _state.update {
        if (it.transactions.isNotEmpty()) {
            val good = lastGood
            val reverted = if (good != null) {
                it.copy(page = good.page, range = good.range, sort = good.sort, perPage = good.perPage, total = good.total, hasMore = good.hasMore)
            } else {
                it
            }
            reverted.copy(loading = false, refreshing = false, errorMessage = message)
        } else {
            it.copy(loading = false, refreshing = false, error = message)
        }
    }

    fun consumeErrorMessage() = _state.update { it.copy(errorMessage = null) }

    fun setRange(range: String) {
        if (_state.value.range == range) return
        _state.update { it.copy(range = range, page = 1, expandedId = null) }
        load()
    }

    fun setSort(sort: String) {
        if (_state.value.sort == sort) return
        _state.update { it.copy(sort = sort, page = 1, expandedId = null) }
        load()
    }

    fun nextPage() {
        if (!_state.value.hasMore) return
        _state.update { it.copy(page = it.page + 1, expandedId = null) }
        load()
    }

    fun prevPage() {
        if (_state.value.page <= 1) return
        _state.update { it.copy(page = it.page - 1, expandedId = null) }
        load()
    }

    fun toggleExpanded(id: Long) {
        _state.update { it.copy(expandedId = if (it.expandedId == id) null else id) }
    }
}
