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
    val loadError: String? = null,
    val schedules: List<ScheduleDto> = emptyList(),

    // Send Now (ad-hoc broadcast)
    val sendTitle: String = "",
    val sendMessage: String = "",
    val sending: Boolean = false,
    val sendError: String? = null,
    val sendResult: String? = null,

    // Run Scheduler
    val running: Boolean = false,
    val runError: String? = null,
    val runResult: String? = null,

    // Per-row (Send Now / Delete) feedback
    val rowActionId: Long? = null,
    val rowError: String? = null,
    val rowMessage: String? = null,
    val pendingDeleteId: Long? = null,

    // Create / Edit form
    val formOpen: Boolean = false,
    val editingId: Long? = null,
    val form: ScheduleForm = ScheduleForm(),
    val saving: Boolean = false,
    val formError: String? = null,
) {
    val editing: Boolean get() = editingId != null
}

class AdminSchedulesViewModel(private val repository: AdminSchedulesRepository) : ViewModel() {

    private val _state = MutableStateFlow(AdminSchedulesUiState())
    val state: StateFlow<AdminSchedulesUiState> = _state.asStateFlow()

    init {
        load()
    }

    fun load() {
        _state.update { it.copy(loading = true, loadError = null) }
        viewModelScope.launch {
            when (val result = repository.list()) {
                is ApiResult.Success -> _state.update { it.copy(loading = false, schedules = result.data) }
                is ApiResult.Error -> _state.update { it.copy(loading = false, loadError = result.friendly()) }
                is ApiResult.NetworkError -> _state.update {
                    it.copy(loading = false, loadError = NETWORK_ERROR)
                }
            }
        }
    }

    // ---- Ad-hoc Send Now ----

    fun onSendTitleChange(v: String) = _state.update {
        it.copy(sendTitle = v.take(TITLE_MAX), sendError = null, sendResult = null)
    }

    fun onSendMessageChange(v: String) = _state.update {
        it.copy(sendMessage = v.take(MESSAGE_MAX), sendError = null, sendResult = null)
    }

    fun sendNotification() {
        val s = _state.value
        val title = s.sendTitle.trim()
        val message = s.sendMessage.trim()
        if (title.isEmpty() || message.isEmpty()) {
            _state.update { it.copy(sendError = "Enter a title and a message before sending.") }
            return
        }
        _state.update { it.copy(sending = true, sendError = null, sendResult = null) }
        viewModelScope.launch {
            when (val result = repository.sendNotification(title, message)) {
                is ApiResult.Success -> _state.update {
                    it.copy(sending = false, sendResult = deliverySummary(result.data), sendTitle = "", sendMessage = "")
                }
                is ApiResult.Error -> _state.update { it.copy(sending = false, sendError = result.friendly()) }
                is ApiResult.NetworkError -> _state.update { it.copy(sending = false, sendError = NETWORK_ERROR) }
            }
        }
    }

    // ---- Run Scheduler ----

    fun runScheduler() {
        _state.update { it.copy(running = true, runError = null, runResult = null) }
        viewModelScope.launch {
            when (val result = repository.runScheduler()) {
                is ApiResult.Success -> _state.update { it.copy(running = false, runResult = runSummary(result.data)) }
                is ApiResult.Error -> _state.update { it.copy(running = false, runError = result.friendly()) }
                is ApiResult.NetworkError -> _state.update { it.copy(running = false, runError = NETWORK_ERROR) }
            }
            // A run may have flipped last_sent_at / active — refresh silently.
            reloadSilently()
        }
    }

    // ---- Per-row actions ----

    fun sendRow(id: Long) {
        _state.update { it.copy(rowActionId = id, rowError = null, rowMessage = null) }
        viewModelScope.launch {
            when (val result = repository.sendNow(id)) {
                is ApiResult.Success -> _state.update {
                    it.copy(
                        rowActionId = null,
                        rowMessage = deliverySummary(result.data.delivery),
                        schedules = it.schedules.map { s -> if (s.id == id) result.data.schedule else s },
                    )
                }
                is ApiResult.Error -> _state.update { it.copy(rowActionId = null, rowError = result.friendly()) }
                is ApiResult.NetworkError -> _state.update { it.copy(rowActionId = null, rowError = NETWORK_ERROR) }
            }
        }
    }

    fun requestDelete(id: Long) = _state.update { it.copy(pendingDeleteId = id) }

    fun cancelDelete() = _state.update { it.copy(pendingDeleteId = null) }

    fun confirmDelete() {
        val id = _state.value.pendingDeleteId ?: return
        _state.update { it.copy(pendingDeleteId = null, rowActionId = id, rowError = null, rowMessage = null) }
        viewModelScope.launch {
            when (val result = repository.delete(id)) {
                is ApiResult.Success -> _state.update {
                    it.copy(
                        rowActionId = null,
                        rowMessage = "Schedule deleted.",
                        schedules = it.schedules.filterNot { s -> s.id == id },
                    )
                }
                is ApiResult.Error -> _state.update { it.copy(rowActionId = null, rowError = result.friendly()) }
                is ApiResult.NetworkError -> _state.update { it.copy(rowActionId = null, rowError = NETWORK_ERROR) }
            }
        }
    }

    // ---- Create / Edit form ----

    fun openCreate() = _state.update {
        it.copy(formOpen = true, editingId = null, saving = false, formError = null, form = ScheduleForm())
    }

    fun openEdit(schedule: ScheduleDto) {
        val parts = (schedule.scheduledTime ?: "09:00").split(":")
        _state.update {
            it.copy(
                formOpen = true,
                editingId = schedule.id,
                saving = false,
                formError = null,
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

    fun closeForm() = _state.update { it.copy(formOpen = false, saving = false, formError = null) }

    fun onFormTitle(v: String) = updateForm { it.copy(title = v.take(TITLE_MAX)) }
    fun onFormMessage(v: String) = updateForm { it.copy(message = v.take(MESSAGE_MAX)) }
    fun onFormFrequency(v: String) = updateForm { it.copy(frequency = v) }
    fun onFormHour(v: String) = updateForm { it.copy(hour = v) }
    fun onFormMinute(v: String) = updateForm { it.copy(minute = v) }
    fun onFormDate(v: String) = updateForm { it.copy(scheduledDate = v.filter { c -> c.isDigit() || c == '-' }.take(10)) }
    fun onFormDayOfWeek(v: Int) = updateForm { it.copy(dayOfWeek = v) }
    fun onFormDayOfMonth(v: String) = updateForm { it.copy(dayOfMonth = v) }
    fun onFormActive(v: Boolean) = updateForm { it.copy(active = v) }

    private inline fun updateForm(block: (ScheduleForm) -> ScheduleForm) =
        _state.update { it.copy(form = block(it.form), formError = null) }

    fun saveForm() {
        val s = _state.value
        val f = s.form
        val title = f.title.trim()
        val message = f.message.trim()
        when {
            title.isEmpty() -> return _state.update { it.copy(formError = "Title can't be blank.") }
            message.isEmpty() -> return _state.update { it.copy(formError = "Message can't be blank.") }
            f.frequency == "once" && f.scheduledDate.isBlank() ->
                return _state.update { it.copy(formError = "Pick a date for a one-time schedule.") }
            f.frequency == "monthly" && (f.dayOfMonth.toIntOrNull() !in 1..31) ->
                return _state.update { it.copy(formError = "Day of month must be between 1 and 31.") }
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

        _state.update { it.copy(saving = true, formError = null) }
        viewModelScope.launch {
            val result = if (s.editingId != null) repository.update(s.editingId, request) else repository.create(request)
            when (result) {
                is ApiResult.Success -> {
                    _state.update {
                        it.copy(
                            saving = false,
                            formOpen = false,
                            rowMessage = if (s.editingId != null) "Schedule updated." else "Schedule created.",
                            rowError = null,
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
