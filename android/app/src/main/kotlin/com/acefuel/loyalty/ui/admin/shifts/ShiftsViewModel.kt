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

/** Create/edit form buffer. [id] is null while creating a brand-new template. */
data class ShiftFormState(
    val id: Long? = null,
    val name: String = "",
    val startTime: String = "",
    val durationHours: String = "8",
    val active: Boolean = true,
) {
    val isEditing: Boolean get() = id != null
}

data class AdminShiftsUiState(
    val loading: Boolean = false,
    val templates: List<ShiftTemplateDto> = emptyList(),
    val error: String? = null,
    /** Non-null while the create/edit sheet is open. */
    val form: ShiftFormState? = null,
    val saving: Boolean = false,
    val formError: String? = null,
)

class ShiftsViewModel(private val repository: ShiftsRepository) : ViewModel() {

    private val _state = MutableStateFlow(AdminShiftsUiState())
    val state: StateFlow<AdminShiftsUiState> = _state.asStateFlow()

    init {
        load()
    }

    fun load() {
        _state.update { it.copy(loading = true, error = null) }
        viewModelScope.launch {
            when (val result = repository.loadShiftTemplates()) {
                is ApiResult.Success ->
                    _state.update { it.copy(loading = false, templates = result.data) }
                is ApiResult.Error ->
                    _state.update { it.copy(loading = false, error = result.message) }
                is ApiResult.NetworkError ->
                    _state.update { it.copy(loading = false, error = "Couldn't reach the server. Try again.") }
            }
        }
    }

    fun openCreate() {
        _state.update { it.copy(form = ShiftFormState(), formError = null) }
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
            )
        }
    }

    fun dismissForm() {
        _state.update { it.copy(form = null, formError = null, saving = false) }
    }

    fun onNameChange(value: String) = updateForm { it.copy(name = value) }
    fun onStartTimeChange(value: String) = updateForm { it.copy(startTime = value) }
    fun onDurationChange(value: String) = updateForm { it.copy(durationHours = value) }
    fun onActiveChange(value: Boolean) = updateForm { it.copy(active = value) }

    /** Adjusts the duration by [deltaHours], snapping to the 0.25 step and clamping at the min. */
    fun stepDuration(deltaHours: Double) {
        val current = _state.value.form?.durationHours?.trim()?.toDoubleOrNull() ?: DEFAULT_HOURS
        val snapped = ((current + deltaHours) / STEP).roundToLong() * STEP
        updateForm { it.copy(durationHours = formatHours(maxOf(MIN_HOURS, snapped))) }
    }

    fun submitForm() {
        val form = _state.value.form ?: return

        val name = form.name.trim()
        when {
            name.isEmpty() -> {
                _state.update { it.copy(formError = "Enter a shift name.") }
                return
            }
            name.length > MAX_NAME -> {
                _state.update { it.copy(formError = "Name must be $MAX_NAME characters or fewer.") }
                return
            }
        }
        val startTime = form.startTime.trim()
        if (!START_TIME_REGEX.matches(startTime)) {
            _state.update { it.copy(formError = "Enter the start time as HH:MM (00:00–23:59).") }
            return
        }
        val hours = form.durationHours.trim().toDoubleOrNull()
        if (hours == null || hours < MIN_HOURS) {
            _state.update { it.copy(formError = "Enter a duration of at least ${formatHours(MIN_HOURS)} hours.") }
            return
        }

        _state.update { it.copy(saving = true, formError = null) }
        viewModelScope.launch {
            val result = if (form.id == null) {
                repository.createShiftTemplate(name, startTime, hours, form.active)
            } else {
                repository.updateShiftTemplate(form.id, name, startTime, hours, form.active)
            }
            when (result) {
                is ApiResult.Success -> {
                    _state.update { it.copy(saving = false, form = null, formError = null) }
                    load()
                }
                is ApiResult.Error ->
                    _state.update { it.copy(saving = false, formError = result.message) }
                is ApiResult.NetworkError ->
                    _state.update { it.copy(saving = false, formError = "Couldn't reach the server. Try again.") }
            }
        }
    }

    private fun updateForm(transform: (ShiftFormState) -> ShiftFormState) {
        _state.update { current ->
            val form = current.form ?: return@update current
            current.copy(form = transform(form))
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
