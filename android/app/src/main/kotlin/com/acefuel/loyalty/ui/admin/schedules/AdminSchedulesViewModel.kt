package com.acefuel.loyalty.ui.admin.schedules

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.acefuel.loyalty.core.network.ApiResult
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

/** Editable state for the create/edit schedule form. */
data class ScheduleForm(
    val title: String = "",
    val message: String = "",
    val frequency: String = "daily",
    val hour: String = "09",
    val minute: String = "00",
    val scheduledDate: String = "", // yyyy-MM-dd, only for "once"
    val dayOfWeek: Int = 1, // Sunday=0 … Saturday=6, only for "weekly"
    val dayOfMonth: String = "1", // 1..31, only for "monthly"
    val active: Boolean = true,
)

data class AdminSchedulesUiState(
    val loading: Boolean = true,
    val refreshing: Boolean = false,
    val loadError: String? = null,
    val schedules: List<ScheduleDto> = emptyList(),

    // Send Now (ad-hoc broadcast)
    val sendTitle: String = "",
    val sendMessage: String = "",
    val sending: Boolean = false,

    // Run Scheduler
    val running: Boolean = false,

    // One-shot snackbar feedback (send/run/row/save results); the screen
    // consumes these after showing.
    val successMessage: String? = null,
    val errorMessage: String? = null,

    // Per-row busy marker + pending delete confirmation
    val rowActionId: Long? = null,
    val pendingDeleteId: Long? = null,

    // Create / Edit form
    val formOpen: Boolean = false,
    val editingId: Long? = null,
    val form: ScheduleForm = ScheduleForm(),
    val saving: Boolean = false,
    val formError: String? = null, // server/base message shown inline in the sheet
    val formFieldErrors: Map<String, List<String>> = emptyMap(),
) {
    val editing: Boolean get() = editingId != null
}

class AdminSchedulesViewModel(private val repository: AdminSchedulesRepository) : ViewModel() {

    private val _state = MutableStateFlow(AdminSchedulesUiState())
    val state: StateFlow<AdminSchedulesUiState> = _state.asStateFlow()

    init {
        load()
    }

    fun load() = fetch(asRefresh = false)

    fun refresh() = fetch(asRefresh = true)

    private fun fetch(asRefresh: Boolean) {
        _state.update {
            if (asRefresh) it.copy(refreshing = true) else it.copy(loading = true, loadError = null)
        }
        viewModelScope.launch {
            when (val result = repository.list()) {
                is ApiResult.Success -> _state.update {
                    it.copy(loading = false, refreshing = false, loadError = null, schedules = result.data)
                }
                is ApiResult.Error -> onFetchFailure(result.friendly())
                is ApiResult.NetworkError -> onFetchFailure(NETWORK_ERROR)
            }
        }
    }

    /** Empty list keeps the inline load error; stale data stays visible with a snackbar. */
    private fun onFetchFailure(message: String) {
        _state.update {
            if (it.schedules.isEmpty()) {
                it.copy(loading = false, refreshing = false, loadError = message)
            } else {
                it.copy(loading = false, refreshing = false, errorMessage = message)
            }
        }
    }

    fun consumeSuccessMessage() = _state.update { it.copy(successMessage = null) }

    fun consumeErrorMessage() = _state.update { it.copy(errorMessage = null) }

    // ---- Ad-hoc Send Now ----

    fun onSendTitleChange(v: String) = _state.update { it.copy(sendTitle = v.take(TITLE_MAX)) }

    fun onSendMessageChange(v: String) = _state.update { it.copy(sendMessage = v.take(MESSAGE_MAX)) }

    fun sendNotification() {
        val s = _state.value
        val title = s.sendTitle.trim()
        val message = s.sendMessage.trim()
        if (title.isEmpty() || message.isEmpty()) {
            _state.update { it.copy(errorMessage = "Enter a title and a message before sending.") }
            return
        }
        _state.update { it.copy(sending = true) }
        viewModelScope.launch {
            when (val result = repository.sendNotification(title, message)) {
                is ApiResult.Success -> _state.update {
                    it.copy(sending = false, successMessage = deliverySummary(result.data), sendTitle = "", sendMessage = "")
                }
                is ApiResult.Error -> _state.update { it.copy(sending = false, errorMessage = result.friendly()) }
                is ApiResult.NetworkError -> _state.update { it.copy(sending = false, errorMessage = NETWORK_ERROR) }
            }
        }
    }

    // ---- Run Scheduler ----

    fun runScheduler() {
        _state.update { it.copy(running = true) }
        viewModelScope.launch {
            when (val result = repository.runScheduler()) {
                is ApiResult.Success -> _state.update { it.copy(running = false, successMessage = runSummary(result.data)) }
                is ApiResult.Error -> _state.update { it.copy(running = false, errorMessage = result.friendly()) }
                is ApiResult.NetworkError -> _state.update { it.copy(running = false, errorMessage = NETWORK_ERROR) }
            }
            // A run may have flipped last_sent_at / active — refresh silently.
            reloadSilently()
        }
    }

    // ---- Per-row actions ----

    fun sendRow(id: Long) {
        _state.update { it.copy(rowActionId = id) }
        viewModelScope.launch {
            when (val result = repository.sendNow(id)) {
                is ApiResult.Success -> _state.update {
                    it.copy(
                        rowActionId = null,
                        successMessage = deliverySummary(result.data.delivery),
                        schedules = it.schedules.map { s -> if (s.id == id) result.data.schedule else s },
                    )
                }
                is ApiResult.Error -> _state.update { it.copy(rowActionId = null, errorMessage = result.friendly()) }
                is ApiResult.NetworkError -> _state.update { it.copy(rowActionId = null, errorMessage = NETWORK_ERROR) }
            }
        }
    }

    fun requestDelete(id: Long) = _state.update { it.copy(pendingDeleteId = id) }

    fun cancelDelete() = _state.update { it.copy(pendingDeleteId = null) }

    fun confirmDelete() {
        val id = _state.value.pendingDeleteId ?: return
        _state.update { it.copy(pendingDeleteId = null, rowActionId = id) }
        viewModelScope.launch {
            when (val result = repository.delete(id)) {
                is ApiResult.Success -> _state.update {
                    it.copy(
                        rowActionId = null,
                        successMessage = "Schedule deleted.",
                        schedules = it.schedules.filterNot { s -> s.id == id },
                    )
                }
                is ApiResult.Error -> _state.update { it.copy(rowActionId = null, errorMessage = result.friendly()) }
                is ApiResult.NetworkError -> _state.update { it.copy(rowActionId = null, errorMessage = NETWORK_ERROR) }
            }
        }
    }

    // ---- Create / Edit form ----

    fun openCreate() = _state.update {
        it.copy(
            formOpen = true,
            editingId = null,
            saving = false,
            formError = null,
            formFieldErrors = emptyMap(),
            form = ScheduleForm(),
        )
    }

    fun openEdit(schedule: ScheduleDto) {
        val parts = (schedule.scheduledTime ?: "09:00").split(":")
        _state.update {
            it.copy(
                formOpen = true,
                editingId = schedule.id,
                saving = false,
                formError = null,
                formFieldErrors = emptyMap(),
                form = ScheduleForm(
                    title = schedule.title,
                    message = schedule.message,
                    frequency = schedule.frequency.ifBlank { "daily" },
                    hour = (parts.getOrNull(0) ?: "09").padStart(2, '0'),
                    minute = (parts.getOrNull(1) ?: "00").padStart(2, '0'),
                    scheduledDate = schedule.scheduledDate.orEmpty(),
                    dayOfWeek = schedule.dayOfWeek ?: 1,
                    dayOfMonth = (schedule.dayOfMonth ?: 1).toString(),
                    active = schedule.active,
                ),
            )
        }
    }

    fun closeForm() = _state.update {
        it.copy(formOpen = false, saving = false, formError = null, formFieldErrors = emptyMap())
    }

    fun onFormTitle(v: String) = updateForm("title") { it.copy(title = v.take(TITLE_MAX)) }
    fun onFormMessage(v: String) = updateForm("message") { it.copy(message = v.take(MESSAGE_MAX)) }

    // Frequency swaps the conditional fields, so drop their stale errors too.
    fun onFormFrequency(v: String) = _state.update {
        it.copy(
            form = it.form.copy(frequency = v),
            formError = null,
            formFieldErrors = it.formFieldErrors - "scheduled_date" - "day_of_month",
        )
    }

    /** The wire format stays "HH":"MM" strings; the screen's TimeField converts at the boundary. */
    fun onFormTime(hour: String, minute: String) = updateForm(null) {
        it.copy(hour = hour.padStart(2, '0'), minute = minute.padStart(2, '0'))
    }

    fun onFormDate(v: String) = updateForm("scheduled_date") { it.copy(scheduledDate = v) }
    fun onFormDayOfWeek(v: Int) = updateForm(null) { it.copy(dayOfWeek = v) }
    fun onFormDayOfMonth(v: String) = updateForm("day_of_month") { it.copy(dayOfMonth = v) }
    fun onFormActive(v: Boolean) = updateForm(null) { it.copy(active = v) }

    /** Applies [block] and clears the field's own validation error (if [key] is set). */
    private inline fun updateForm(key: String?, block: (ScheduleForm) -> ScheduleForm) =
        _state.update {
            it.copy(
                form = block(it.form),
                formError = null,
                formFieldErrors = if (key != null) it.formFieldErrors - key else it.formFieldErrors,
            )
        }

    fun saveForm() {
        val s = _state.value
        val f = s.form
        val title = f.title.trim()
        val message = f.message.trim()

        val fieldErrors = buildMap<String, List<String>> {
            if (title.isEmpty()) put("title", listOf("Title can't be blank."))
            if (message.isEmpty()) put("message", listOf("Message can't be blank."))
            if (f.frequency == "once" && f.scheduledDate.isBlank()) {
                put("scheduled_date", listOf("Pick a date for a one-time schedule."))
            }
            if (f.frequency == "monthly" && f.dayOfMonth.toIntOrNull() !in 1..31) {
                put("day_of_month", listOf("Day of month must be between 1 and 31."))
            }
        }
        if (fieldErrors.isNotEmpty()) {
            _state.update { it.copy(formFieldErrors = fieldErrors, formError = null) }
            return
        }

        val request = ScheduleRequest(
            title = title,
            message = message,
            frequency = f.frequency,
            scheduledTime = "${f.hour}:${f.minute}",
            scheduledDate = if (f.frequency == "once") f.scheduledDate.trim() else null,
            dayOfWeek = if (f.frequency == "weekly") f.dayOfWeek else null,
            dayOfMonth = if (f.frequency == "monthly") f.dayOfMonth.toIntOrNull() else null,
            active = f.active,
        )

        _state.update { it.copy(saving = true, formError = null, formFieldErrors = emptyMap()) }
        viewModelScope.launch {
            val result = if (s.editingId != null) repository.update(s.editingId, request) else repository.create(request)
            when (result) {
                is ApiResult.Success -> {
                    _state.update {
                        it.copy(
                            saving = false,
                            formOpen = false,
                            successMessage = if (s.editingId != null) "Schedule updated." else "Schedule created.",
                        )
                    }
                    reloadSilently()
                }
                is ApiResult.Error -> _state.update { it.copy(saving = false, formError = result.friendly()) }
                is ApiResult.NetworkError -> _state.update { it.copy(saving = false, formError = NETWORK_ERROR) }
            }
        }
    }

    private suspend fun reloadSilently() {
        when (val result = repository.list()) {
            is ApiResult.Success -> _state.update { it.copy(schedules = result.data) }
            else -> Unit // keep what we have; the mutating call already succeeded
        }
    }

    private companion object {
        const val NETWORK_ERROR = "Couldn't reach the server. Try again."
        const val TITLE_MAX = 120
        const val MESSAGE_MAX = 240
    }
}

// ---- Friendly-message helpers ----

/** FCM-unconfigured 422 → plain-language guidance; everything else keeps the server string. */
private fun ApiResult.Error.friendly(): String =
    if (code == "configuration_error") {
        "Push notifications aren't set up yet, so nothing was sent. A developer needs to configure Firebase (FCM) first."
    } else {
        message
    }

private fun deliverySummary(d: DeliveryResultDto): String = when {
    d.requested == 0 -> "No active device tokens are registered, so nothing was sent."
    else -> buildString {
        append("Sent to ${d.sent} of ${d.requested} device${plural(d.requested)}.")
        if (d.failed > 0) append(" ${d.failed} failed.")
        if (d.invalidated > 0) append(" ${d.invalidated} stale token${plural(d.invalidated)} removed.")
    }
}

private fun runSummary(r: RunResultDto): String = when {
    r.skipped -> r.message ?: "Another scheduler run is already in progress."
    r.due == 0 -> "No schedules were due right now. Checked ${r.checked}."
    else -> "${r.sent} sent, ${r.failed} failed (of ${r.due} due, ${r.checked} checked)."
}

private fun plural(n: Int): String = if (n == 1) "" else "s"
