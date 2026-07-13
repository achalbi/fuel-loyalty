package com.acefuel.loyalty.ui.admin.shifts

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.acefuel.loyalty.core.network.ApiResult
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlin.math.roundToLong

private const val NETWORK_MESSAGE = "Couldn't reach the server. Try again."

/** Create/edit form buffer. [id] is null while creating a brand-new template. */
data class ShiftFormState(
    val id: Long? = null,
    val name: String = "",
    val startTime: String = "", // wire "HH:MM"; the screen's TimeField converts at the boundary
    val durationHours: String = "8",
    val active: Boolean = true,
) {
    val isEditing: Boolean get() = id != null
}

data class AdminShiftsUiState(
    val loading: Boolean = false,
    val refreshing: Boolean = false,
    val templates: List<ShiftTemplateDto> = emptyList(),
    val error: String? = null,
    // One-shot snackbar messages; the screen consumes them after showing.
    val successMessage: String? = null,
    val actionError: String? = null,
    /** Non-null while the create/edit sheet is open. */
    val form: ShiftFormState? = null,
    val saving: Boolean = false,
    val formError: String? = null, // server/base message shown inline in the sheet
    val formFieldErrors: Map<String, List<String>> = emptyMap(),
)

class ShiftsViewModel(private val repository: ShiftsRepository) : ViewModel() {

    private val _state = MutableStateFlow(AdminShiftsUiState())
    val state: StateFlow<AdminShiftsUiState> = _state.asStateFlow()

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
            when (val result = repository.loadShiftTemplates()) {
                is ApiResult.Success ->
                    _state.update { it.copy(loading = false, refreshing = false, error = null, templates = result.data) }
                is ApiResult.Error -> onFetchFailure(result.message)
                is ApiResult.NetworkError -> onFetchFailure(NETWORK_MESSAGE)
            }
        }
    }

    /** Empty screen keeps the full-area error; stale data stays visible with a snackbar. */
    private fun onFetchFailure(message: String) {
        _state.update {
            if (it.templates.isEmpty()) {
                it.copy(loading = false, refreshing = false, error = message)
            } else {
                it.copy(loading = false, refreshing = false, actionError = message)
            }
        }
    }

    fun consumeSuccessMessage() = _state.update { it.copy(successMessage = null) }

    fun consumeActionError() = _state.update { it.copy(actionError = null) }

    fun openCreate() {
        _state.update { it.copy(form = ShiftFormState(), formError = null, formFieldErrors = emptyMap()) }
    }

    fun openEdit(template: ShiftTemplateDto) {
        _state.update {
            it.copy(
                form = ShiftFormState(
                    id = template.id,
                    name = template.name,
                    startTime = template.startTime.orEmpty(),
                    durationHours = hoursFromMinutes(template.durationMinutes),
                    active = template.active,
                ),
                formError = null,
                formFieldErrors = emptyMap(),
            )
        }
    }

    fun dismissForm() {
        _state.update { it.copy(form = null, formError = null, formFieldErrors = emptyMap(), saving = false) }
    }

    fun onNameChange(value: String) = updateForm("name") { it.copy(name = value) }
    fun onStartTimeChange(value: String) = updateForm("start_time") { it.copy(startTime = value) }
    fun onDurationChange(value: String) = updateForm("duration") { it.copy(durationHours = value) }
    fun onActiveChange(value: Boolean) = updateForm(null) { it.copy(active = value) }

    /** Adjusts the duration by [deltaHours], snapping to the 0.25 step and clamping at the min. */
    fun stepDuration(deltaHours: Double) {
        val current = _state.value.form?.durationHours?.trim()?.toDoubleOrNull() ?: DEFAULT_HOURS
        val snapped = ((current + deltaHours) / STEP).roundToLong() * STEP
        updateForm("duration") { it.copy(durationHours = formatHours(maxOf(MIN_HOURS, snapped))) }
    }

    fun submitForm() {
        val form = _state.value.form ?: return

        val name = form.name.trim()
        val startTime = form.startTime.trim()
        val hours = form.durationHours.trim().toDoubleOrNull()

        val fieldErrors = buildMap<String, List<String>> {
            when {
                name.isEmpty() -> put("name", listOf("Enter a shift name."))
                name.length > MAX_NAME -> put("name", listOf("Name must be $MAX_NAME characters or fewer."))
            }
            if (!START_TIME_REGEX.matches(startTime)) {
                put("start_time", listOf("Pick the shift start time."))
            }
            if (hours == null || hours < MIN_HOURS) {
                put("duration", listOf("Enter a duration of at least ${formatHours(MIN_HOURS)} hours."))
            }
        }
        if (fieldErrors.isNotEmpty()) {
            _state.update { it.copy(formFieldErrors = fieldErrors, formError = null) }
            return
        }

        _state.update { it.copy(saving = true, formError = null, formFieldErrors = emptyMap()) }
        viewModelScope.launch {
            val result = if (form.id == null) {
                repository.createShiftTemplate(name, startTime, hours!!, form.active)
            } else {
                repository.updateShiftTemplate(form.id, name, startTime, hours!!, form.active)
            }
            when (result) {
                is ApiResult.Success -> {
                    _state.update {
                        it.copy(
                            saving = false,
                            form = null,
                            formError = null,
                            successMessage = if (form.id != null) "Shift updated." else "Shift created.",
                        )
                    }
                    load()
                }
                is ApiResult.Error ->
                    _state.update { it.copy(saving = false, formError = result.message) }
                is ApiResult.NetworkError ->
                    _state.update { it.copy(saving = false, formError = NETWORK_MESSAGE) }
            }
        }
    }

    /** Applies [transform] and clears the field's own validation error (if [key] is set). */
    private fun updateForm(key: String?, transform: (ShiftFormState) -> ShiftFormState) {
        _state.update { current ->
            val form = current.form ?: return@update current
            current.copy(
                form = transform(form),
                formFieldErrors = if (key != null) current.formFieldErrors - key else current.formFieldErrors,
            )
        }
    }

    private companion object {
        const val MAX_NAME = 80
        const val MIN_HOURS = 0.5
        const val STEP = 0.25
        const val DEFAULT_HOURS = 8.0
        val START_TIME_REGEX = Regex("^([01]\\d|2[0-3]):[0-5]\\d$")

        fun hoursFromMinutes(minutes: Int): String =
            if (minutes <= 0) formatHours(DEFAULT_HOURS) else formatHours(minutes / 60.0)

        /** Renders hours without a trailing ".0" (8.0 -> "8", 7.5 -> "7.5", 8.25 -> "8.25"). */
        fun formatHours(value: Double): String {
            val rounded = (value * 100).roundToLong() / 100.0
            return if (rounded % 1.0 == 0.0) {
                rounded.toLong().toString()
            } else {
                rounded.toString().trimEnd('0').trimEnd('.')
            }
        }
    }
}
