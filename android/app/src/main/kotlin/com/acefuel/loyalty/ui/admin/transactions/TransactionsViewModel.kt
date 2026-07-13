package com.acefuel.loyalty.ui.admin.transactions

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.acefuel.loyalty.core.network.ApiResult
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
    val error: String? = null,
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

    init {
        load()
    }

    fun load() {
        _state.update { it.copy(loading = true, error = null) }
        val s = _state.value
        viewModelScope.launch {
            when (val result = repository.loadTransactions(s.range, s.sort, null, null, s.page)) {
                is ApiResult.Success -> _state.update {
                    it.copy(
                        loading = false,
                        error = null,
                        transactions = result.data.transactions,
                        page = result.data.page,
                        perPage = result.data.perPage,
                        total = result.data.total,
                        hasMore = result.data.hasMore,
                    )
                }
                is ApiResult.Error -> _state.update { it.copy(loading = false, error = result.message) }
                is ApiResult.NetworkError -> _state.update { it.copy(loading = false, error = NETWORK_MESSAGE) }
            }
        }
    }

    fun refresh() = load()

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
