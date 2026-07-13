package com.acefuel.loyalty.ui.admin.attendance

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.acefuel.loyalty.core.network.ApiResult
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.time.LocalDate

private const val NETWORK_MESSAGE = "Couldn't reach the server. Try again."

/** Which sub-view of the single Attendance screen is currently visible. */
enum class AttendanceScreenMode { LIST, DETAIL, PLANNER }

/** One editable planner row, backed by a rostered staff member. */
data class DraftEntry(
    val scheduledUserId: Long,
    val name: String,
    val phone: String?,
    val status: String = "present",
    val checkInAt: String? = null,
    val checkOutAt: String? = null,
    val externalReplacementName: String = "",
    val notes: String = "",
)

data class AttendanceUiState(
    val mode: AttendanceScreenMode = AttendanceScreenMode.LIST,
    /** One-shot success message -> success snackbar. */
    val actionMessage: String? = null,
    /** One-shot failure with content kept on screen -> error snackbar. */
    val actionError: String? = null,

    // --- list ---
    val listLoading: Boolean = false,
    /** Pull-to-refresh in progress (rows stay visible). */
    val refreshing: Boolean = false,
    val listError: String? = null,
    val runs: List<AttendanceRunDto> = emptyList(),
    val filter: String = "all",
    val startDate: String? = null,
    val endDate: String? = null,
    val page: Int = 1,
    val totalPages: Int = 1,
    val total: Int = 0,
    val showingFrom: Int = 0,
    val showingTo: Int = 0,

    // --- detail ---
    val detailLoading: Boolean = false,
    val detailError: String? = null,
    val selectedRunId: Long? = null,
    val selectedRun: AttendanceRunDto? = null,
    val detailActionInFlight: Boolean = false,

    // --- planner ---
    val shiftTemplates: List<ShiftTemplateDto> = emptyList(),
    val templatesLoading: Boolean = false,
    val templatesError: String? = null,
    val selectedShiftId: Long? = null,
    val plannerDate: LocalDate? = null,
    val startHour: Int = 9,
    val startMinute: Int = 0,
    val plannerLoading: Boolean = false,
    val plannerError: String? = null,
    val plannerBaseErrors: List<String> = emptyList(),
    val plannerShiftName: String? = null,
    val plannerShiftTemplateId: Long? = null,
    val windowStart: String? = null,
    val windowEnd: String? = null,
    val draftEntries: List<DraftEntry> = emptyList(),
    val staffLoaded: Boolean = false,
    val runNotes: String = "",
    val markInvalid: Boolean = false,
    // True once the operator actually edits the roster — a freshly loaded,
    // untouched roster must not trip the discard-changes guard.
    val plannerTouched: Boolean = false,
    val saving: Boolean = false,
    val saveError: String? = null,
) {
    val selectedShift: ShiftTemplateDto?
        get() = shiftTemplates.firstOrNull { it.id == selectedShiftId }

    /** Leaving the planner after a real edit would silently lose work. */
    val plannerDirty: Boolean
        get() = plannerTouched
}

class AttendanceViewModel(private val repository: AttendanceRepository) : ViewModel() {

    private val _state = MutableStateFlow(AttendanceUiState())
    val state: StateFlow<AttendanceUiState> = _state.asStateFlow()

    private var listJob: Job? = null
    private var detailJob: Job? = null
    private var templatesJob: Job? = null
    private var plannerJob: Job? = null

    // List navigation state matching the rows on screen; a failed reload that
    // keeps stale rows rolls back to this so filter chips / page counter agree.
    private var lastGoodList: AttendanceUiState? = null

    init {
        reloadList()
    }

    // ------------------------------------------------------------------ list

    /** Pull-to-refresh: keeps rows visible; falls back to a full load when the list is empty. */
    fun refresh() = reloadList(asRefresh = _state.value.runs.isNotEmpty())

    fun reloadList(asRefresh: Boolean = false) {
        listJob?.cancel()
        _state.update { it.copy(listLoading = !asRefresh, refreshing = asRefresh, listError = null) }
        val s = _state.value
        listJob = viewModelScope.launch {
            when (val result = repository.loadRuns(s.filter, s.startDate, s.endDate, s.page)) {
                is ApiResult.Success -> _state.update {
                    it.copy(
                        listLoading = false,
                        refreshing = false,
                        runs = result.data.attendanceRuns,
                        filter = result.data.filter,
                        startDate = result.data.startDate,
                        endDate = result.data.endDate,
                        page = result.data.page,
                        totalPages = result.data.totalPages,
                        total = result.data.total,
                        showingFrom = result.data.showingFrom,
                        showingTo = result.data.showingTo,
                    ).also { committed -> lastGoodList = committed }
                }
                is ApiResult.Error -> failList(result.message)
                is ApiResult.NetworkError -> failList(NETWORK_MESSAGE)
            }
        }
    }

    /** Stale rows on screen -> one-shot snackbar + rollback; empty screen -> full-area error. */
    private fun failList(message: String) = _state.update {
        if (it.runs.isNotEmpty()) {
            // Revert the optimistic filter/date/page to match the rows still on
            // screen, so the chips and page counter don't lie about the data.
            val good = lastGoodList
            val reverted = if (good != null) {
                it.copy(
                    filter = good.filter, startDate = good.startDate, endDate = good.endDate,
                    page = good.page, totalPages = good.totalPages, total = good.total,
                    showingFrom = good.showingFrom, showingTo = good.showingTo,
                )
            } else {
                it
            }
            reverted.copy(listLoading = false, refreshing = false, actionError = message)
        } else {
            it.copy(listLoading = false, refreshing = false, listError = message)
        }
    }

    fun setFilter(filter: String) {
        if (_state.value.filter == filter) return
        _state.update { it.copy(filter = filter, page = 1) }
        reloadList()
    }

    fun setStartDate(iso: String?) {
        _state.update { it.copy(startDate = iso, page = 1) }
        reloadList()
    }

    fun setEndDate(iso: String?) {
        _state.update { it.copy(endDate = iso, page = 1) }
        reloadList()
    }

    /** Clears both bounds with a single reload (used to fire two). */
    fun clearDates() {
        if (_state.value.startDate == null && _state.value.endDate == null) return
        _state.update { it.copy(startDate = null, endDate = null, page = 1) }
        reloadList()
    }

    /** Empty-state "Show all": drops every filter with a single reload. */
    fun resetFilters() {
        _state.update { it.copy(filter = "all", startDate = null, endDate = null, page = 1) }
        reloadList()
    }

    fun goToPage(page: Int) {
        val target = page.coerceIn(1, _state.value.totalPages)
        if (target == _state.value.page) return
        _state.update { it.copy(page = target) }
        reloadList()
    }

    fun consumeActionMessage() = _state.update { it.copy(actionMessage = null) }

    fun consumeActionError() = _state.update { it.copy(actionError = null) }

    // ---------------------------------------------------------------- detail

    fun openRun(id: Long) {
        detailJob?.cancel()
        _state.update {
            it.copy(
                mode = AttendanceScreenMode.DETAIL,
                detailLoading = true,
                detailError = null,
                selectedRunId = id,
                selectedRun = null,
            )
        }
        detailJob = viewModelScope.launch {
            when (val result = repository.showRun(id)) {
                is ApiResult.Success -> _state.update { it.copy(detailLoading = false, selectedRun = result.data) }
                is ApiResult.Error -> _state.update { it.copy(detailLoading = false, detailError = result.message) }
                is ApiResult.NetworkError -> _state.update {
                    it.copy(detailLoading = false, detailError = NETWORK_MESSAGE)
                }
            }
        }
    }

    fun retryDetail() {
        _state.value.selectedRunId?.let { openRun(it) }
    }

    fun invalidateSelected() = mutateSelected { repository.invalidateRun(it) }

    fun markSelectedValid() = mutateSelected { repository.markValidRun(it) }

    private fun mutateSelected(block: suspend (Long) -> ApiResult<AttendanceRunDto>) {
        val run = _state.value.selectedRun ?: return
        _state.update { it.copy(detailActionInFlight = true) }
        viewModelScope.launch {
            when (val result = block(run.id)) {
                is ApiResult.Success -> _state.update {
                    it.copy(detailActionInFlight = false, selectedRun = result.data)
                }
                is ApiResult.Error -> _state.update { it.copy(detailActionInFlight = false, actionError = result.message) }
                is ApiResult.NetworkError -> _state.update {
                    it.copy(detailActionInFlight = false, actionError = NETWORK_MESSAGE)
                }
            }
        }
    }

    fun deleteSelected() {
        val run = _state.value.selectedRun ?: return
        _state.update { it.copy(detailActionInFlight = true) }
        viewModelScope.launch {
            when (val result = repository.deleteRun(run.id)) {
                is ApiResult.Success -> {
                    _state.update {
                        it.copy(
                            detailActionInFlight = false,
                            mode = AttendanceScreenMode.LIST,
                            selectedRun = null,
                            selectedRunId = null,
                            page = 1,
                            actionMessage = result.data.message ?: "Invalid attendance record deleted.",
                        )
                    }
                    reloadList()
                }
                is ApiResult.Error -> _state.update { it.copy(detailActionInFlight = false, actionError = result.message) }
                is ApiResult.NetworkError -> _state.update {
                    it.copy(detailActionInFlight = false, actionError = NETWORK_MESSAGE)
                }
            }
        }
    }

    // --------------------------------------------------------------- planner

    fun openPlanner() {
        _state.update {
            it.copy(
                mode = AttendanceScreenMode.PLANNER,
                selectedShiftId = null,
                plannerDate = LocalDate.now(),
                startHour = 9,
                startMinute = 0,
                plannerError = null,
                plannerBaseErrors = emptyList(),
                plannerShiftName = null,
                plannerShiftTemplateId = null,
                windowStart = null,
                windowEnd = null,
                draftEntries = emptyList(),
                staffLoaded = false,
                runNotes = "",
                markInvalid = false,
                plannerTouched = false,
                saveError = null,
            )
        }
        if (_state.value.shiftTemplates.isEmpty()) loadShiftTemplates()
    }

    fun backToList() {
        _state.update {
            it.copy(mode = AttendanceScreenMode.LIST, detailError = null, plannerError = null, saveError = null)
        }
    }

    fun loadShiftTemplates() {
        templatesJob?.cancel()
        _state.update { it.copy(templatesLoading = true, templatesError = null) }
        templatesJob = viewModelScope.launch {
            when (val result = repository.loadShiftTemplates()) {
                is ApiResult.Success -> _state.update {
                    it.copy(templatesLoading = false, shiftTemplates = result.data.filter { t -> t.active })
                }
                is ApiResult.Error -> _state.update { it.copy(templatesLoading = false, templatesError = result.message) }
                is ApiResult.NetworkError -> _state.update {
                    it.copy(templatesLoading = false, templatesError = NETWORK_MESSAGE)
                }
            }
        }
    }

    fun selectShift(id: Long) {
        val shift = _state.value.shiftTemplates.firstOrNull { it.id == id }
        val parsed = shift?.startTime?.let { parseClockTime(it) }
        _state.update {
            it.copy(
                selectedShiftId = id,
                startHour = parsed?.first ?: it.startHour,
                startMinute = parsed?.second ?: it.startMinute,
                // a fresh selection invalidates any previously loaded roster
                staffLoaded = false,
                draftEntries = emptyList(),
                plannerTouched = false,
                plannerBaseErrors = emptyList(),
                windowStart = null,
                windowEnd = null,
            )
        }
    }

    fun setPlannerDate(date: LocalDate) = _state.update { it.copy(plannerDate = date) }

    fun setStartTime(hour: Int, minute: Int) = _state.update { it.copy(startHour = hour, startMinute = minute) }

    fun loadStaff() {
        val shiftId = _state.value.selectedShiftId ?: return
        plannerJob?.cancel()
        _state.update { it.copy(plannerLoading = true, plannerError = null, plannerBaseErrors = emptyList()) }
        plannerJob = viewModelScope.launch {
            when (val result = repository.loadPlanner(shiftId, composeStartsAt())) {
                is ApiResult.Success -> {
                    val data = result.data
                    val entries = data.entries.mapNotNull { e ->
                        val user = e.scheduledUser ?: return@mapNotNull null
                        DraftEntry(
                            scheduledUserId = user.id,
                            name = user.displayName ?: user.name ?: "Staff #${user.id}",
                            phone = user.displayPhoneNumber,
                            status = e.status,
                            checkInAt = e.checkInAt ?: data.startsAt,
                            checkOutAt = e.checkOutAt ?: data.endsAt,
                            externalReplacementName = e.externalReplacementName ?: "",
                            notes = e.notes ?: "",
                        )
                    }
                    _state.update {
                        it.copy(
                            plannerLoading = false,
                            plannerBaseErrors = data.errors,
                            plannerShiftName = data.shiftTemplate?.name,
                            plannerShiftTemplateId = data.shiftTemplate?.id ?: shiftId,
                            windowStart = data.startsAt,
                            windowEnd = data.endsAt,
                            draftEntries = entries,
                            staffLoaded = data.errors.isEmpty() && entries.isNotEmpty(),
                            plannerTouched = false, // freshly loaded roster is untouched
                            saveError = null,
                        )
                    }
                }
                is ApiResult.Error -> _state.update {
                    it.copy(plannerLoading = false, plannerError = result.message, staffLoaded = false, draftEntries = emptyList())
                }
                is ApiResult.NetworkError -> _state.update {
                    it.copy(
                        plannerLoading = false,
                        plannerError = NETWORK_MESSAGE,
                        staffLoaded = false,
                        draftEntries = emptyList(),
                    )
                }
            }
        }
    }

    fun markAllPresent() = _state.update { s ->
        s.copy(draftEntries = s.draftEntries.map { it.copy(status = "present") }, plannerTouched = true)
    }

    fun updateEntryStatus(index: Int, status: String) = updateEntry(index) { it.copy(status = status) }

    fun updateEntryNotes(index: Int, notes: String) = updateEntry(index) { it.copy(notes = notes) }

    fun updateEntryExternalReplacement(index: Int, name: String) =
        updateEntry(index) { it.copy(externalReplacementName = name) }

    fun setEntryCheckTime(index: Int, isCheckIn: Boolean, hour: Int, minute: Int) {
        val iso = runDate().atTime(hour, minute).toString() // yyyy-MM-ddTHH:mm (app time zone)
        updateEntry(index) { if (isCheckIn) it.copy(checkInAt = iso) else it.copy(checkOutAt = iso) }
    }

    fun clearEntryCheckTime(index: Int, isCheckIn: Boolean) =
        updateEntry(index) { if (isCheckIn) it.copy(checkInAt = null) else it.copy(checkOutAt = null) }

    private inline fun updateEntry(index: Int, transform: (DraftEntry) -> DraftEntry) = _state.update { s ->
        if (index !in s.draftEntries.indices) return@update s
        s.copy(
            draftEntries = s.draftEntries.toMutableList().also { it[index] = transform(it[index]) },
            plannerTouched = true,
        )
    }

    fun setRunNotes(notes: String) = _state.update { it.copy(runNotes = notes, plannerTouched = true) }

    fun setMarkInvalid(value: Boolean) = _state.update { it.copy(markInvalid = value, plannerTouched = true) }

    fun save() {
        val s = _state.value
        if (s.saving) return
        val shiftTemplateId = s.plannerShiftTemplateId
        val start = s.windowStart
        val end = s.windowEnd
        if (shiftTemplateId == null || start == null || end == null || s.draftEntries.isEmpty()) return

        val attributes = s.draftEntries.map { d ->
            val absent = d.status == "absent"
            AttendanceEntryAttributes(
                scheduledUserId = d.scheduledUserId,
                // Leave actual blank for absentees so worker_name can honor an external
                // replacement (or fall back to "Not covered"); otherwise the worker is
                // the scheduled staff member (Rails sync_actual_user default).
                actualUserId = if (absent) null else d.scheduledUserId,
                externalReplacementName = if (absent) d.externalReplacementName.trim().ifBlank { null } else null,
                status = d.status,
                checkInAt = d.checkInAt,
                checkOutAt = d.checkOutAt,
                notes = d.notes.trim().ifBlank { null },
            )
        }

        val request = AttendanceRunRequest(
            shiftTemplateId = shiftTemplateId,
            startsAt = start,
            endsAt = end,
            stale = s.markInvalid,
            notes = s.runNotes.trim().ifBlank { null },
            attendanceEntriesAttributes = attributes,
        )

        _state.update { it.copy(saving = true, saveError = null) }
        viewModelScope.launch {
            when (val result = repository.createRun(request)) {
                is ApiResult.Success -> {
                    _state.update {
                        it.copy(
                            saving = false,
                            mode = AttendanceScreenMode.LIST,
                            filter = "all",
                            page = 1,
                            actionMessage = "Attendance recorded for ${result.data.shiftName ?: "shift"}.",
                        )
                    }
                    reloadList()
                }
                is ApiResult.Error -> _state.update { it.copy(saving = false, saveError = result.message) }
                is ApiResult.NetworkError -> _state.update {
                    it.copy(saving = false, saveError = NETWORK_MESSAGE)
                }
            }
        }
    }

    // ----------------------------------------------------------------- utils

    private fun composeStartsAt(): String? {
        val date = _state.value.plannerDate ?: return null
        return date.atTime(_state.value.startHour, _state.value.startMinute).toString()
    }

    private fun runDate(): LocalDate {
        val start = _state.value.windowStart
        return parseIsoDateTimeToDate(start) ?: LocalDate.now()
    }
}

/** Parses a "HH:mm" or "HH:mm:ss" clock string into (hour, minute), or null. */
private fun parseClockTime(value: String): Pair<Int, Int>? = runCatching {
    val parts = value.trim().split(":")
    val hour = parts[0].toInt()
    val minute = parts.getOrNull(1)?.toInt() ?: 0
    if (hour in 0..23 && minute in 0..59) hour to minute else null
}.getOrNull()

private fun parseIsoDateTimeToDate(iso: String?): LocalDate? = iso?.let { raw ->
    runCatching { java.time.OffsetDateTime.parse(raw).toLocalDate() }
        .recoverCatching { java.time.LocalDateTime.parse(raw).toLocalDate() }
        .recoverCatching { LocalDate.parse(raw.substring(0, 10)) }
        .getOrNull()
}
