package com.acefuel.loyalty.ui.admin.reports

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.acefuel.loyalty.core.network.ApiResult
import java.time.LocalDate
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

/**
 * Grouping and grain are chips (one tap = one report, so they reload straight
 * away). The date range and the four free-text lookups are edited as a DRAFT
 * and only sent on "Apply" — refetching per keystroke would fire a request per
 * letter of a transporter's name.
 */
data class ReportsUiState(
    val dimension: String = "vehicle",
    val grain: String = "month",
    val draft: ReportFilters = ReportFilters(),
    val applied: ReportFilters = ReportFilters(),
    val loading: Boolean = true,
    val response: ReportResponse? = null,
    val error: String? = null,
) {
    companion object {
        val DIMENSIONS = listOf("vehicle", "transporter", "driver", "customer")
        val GRAINS = listOf("day", "week", "month", "year")
    }
}

/** The filter values the operator types/picks, before and after applying. */
data class ReportFilters(
    val startDate: LocalDate? = null,
    val endDate: LocalDate? = null,
    val transporter: String = "",
    val driverName: String = "",
    val driverPhone: String = "",
    val vehicleNumber: String = "",
) {
    val isActive: Boolean
        get() = startDate != null || endDate != null ||
            listOf(transporter, driverName, driverPhone, vehicleNumber).any { it.isNotBlank() }
}

class ReportsViewModel(private val repository: ReportsRepository) : ViewModel() {

    private val _state = MutableStateFlow(ReportsUiState())
    val state: StateFlow<ReportsUiState> = _state.asStateFlow()

    init { load() }

    fun onDimension(value: String) { _state.update { it.copy(dimension = value) }; load() }
    fun onGrain(value: String) { _state.update { it.copy(grain = value) }; load() }

    fun onDraft(change: (ReportFilters) -> ReportFilters) =
        _state.update { it.copy(draft = change(it.draft)) }

    /** Commit the draft lookups and refetch. */
    fun applyFilters() {
        _state.update { it.copy(applied = it.draft) }
        load()
    }

    /**
     * Drop ONE lookup — the X on its summary chip. Applied to the draft as well
     * as the applied set, so re-opening the sheet doesn't show the value the
     * operator just removed still sitting in its field.
     */
    fun removeFilter(change: (ReportFilters) -> ReportFilters) {
        _state.update { it.copy(draft = change(it.draft), applied = change(it.applied)) }
        load()
    }

    /** Drop every lookup (grouping and grain are deliberately kept) and refetch. */
    fun clearFilters() {
        _state.update { it.copy(draft = ReportFilters(), applied = ReportFilters()) }
        load()
    }

    fun consumeError() = _state.update { it.copy(error = null) }

    fun load() {
        val s = _state.value
        val f = s.applied
        _state.update { it.copy(loading = true, error = null) }
        viewModelScope.launch {
            val result = repository.report(
                dimension = s.dimension,
                grain = s.grain,
                startDate = f.startDate?.toString(),
                endDate = f.endDate?.toString(),
                transporter = f.transporter.ifBlank { null },
                driverName = f.driverName.ifBlank { null },
                driverPhone = f.driverPhone.ifBlank { null },
                vehicleNumber = f.vehicleNumber.ifBlank { null },
            )
            when (result) {
                is ApiResult.Success -> _state.update { it.copy(loading = false, response = result.data) }
                is ApiResult.Error -> _state.update { it.copy(loading = false, error = result.message) }
                is ApiResult.NetworkError -> _state.update { it.copy(loading = false, error = "Couldn't reach the server. Try again.") }
            }
        }
    }
}
