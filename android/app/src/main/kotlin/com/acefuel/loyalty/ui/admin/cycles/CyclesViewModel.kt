package com.acefuel.loyalty.ui.admin.cycles

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.acefuel.loyalty.core.network.ApiResult
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.time.LocalDate

private const val NETWORK_MESSAGE = "Couldn't reach the server. Try again."

/** Max shift steps allowed per cycle (handoff 7.5). */
const val MAX_CYCLE_STEPS = 12

/** Step slots visible when a brand-new cycle form is opened (handoff 7.5). */
private const val INITIAL_STEP_SLOTS = 3

/** One step-picker row inside the cycle form. [key] is a stable local id; a null
 *  [templateId] means "Leave this step empty" (dropped on save). */
data class StepRow(
    val key: Long,
    val templateId: Long? = null,
)

/** Values captured when the editor opens, used to detect unsaved changes. */
data class CycleEditorSnapshot(
    val name: String,
    val startsOn: String,
    val active: Boolean,
    val stepTemplateIds: List<Long?>,
)

/** Non-null on [CyclesUiState] while the create/edit form is open. */
data class CycleEditorState(
    val cycleId: Long? = null,
    val name: String = "",
    val startsOn: String = "",
    val active: Boolean = true,
    val steps: List<StepRow> = emptyList(),
    val saving: Boolean = false,
    val error: String? = null,
    val nameError: String? = null,
    val initial: CycleEditorSnapshot? = null,
) {
    val isCreate: Boolean get() = cycleId == null
    val canAddStep: Boolean get() = steps.size < MAX_CYCLE_STEPS
    val selectedCount: Int get() = steps.count { it.templateId != null }
    val dirty: Boolean
        get() = initial != null && (
            name != initial.name ||
                startsOn != initial.startsOn ||
                active != initial.active ||
                steps.map { it.templateId } != initial.stepTemplateIds
            )
}

data class CyclesUiState(
    val loading: Boolean = true,
    val refreshing: Boolean = false,
    val error: String? = null,
    val cycles: List<ShiftCycleDto> = emptyList(),
    val templates: List<ShiftTemplateDto> = emptyList(),
    val notice: String? = null,
    val actionError: String? = null,
    val deletingId: Long? = null,
    val togglingId: Long? = null,
    val editor: CycleEditorState? = null,
) {
    /** Templates offered in the step pickers (only active ones are selectable). */
    val activeTemplates: List<ShiftTemplateDto> get() = templates.filter { it.active }
}

class CyclesViewModel(private val repository: CyclesRepository) : ViewModel() {

    private val _state = MutableStateFlow(CyclesUiState())
    val state: StateFlow<CyclesUiState> = _state.asStateFlow()

    private var keySeq = 0L

    init {
        load()
    }

    fun load() = fetch(refresh = false)

    fun refresh() = fetch(refresh = true)

    private fun fetch(refresh: Boolean) {
        if (refresh) {
            if (_state.value.refreshing) return
            _state.update { it.copy(refreshing = true) }
        } else {
            _state.update { it.copy(loading = true, error = null) }
        }
        viewModelScope.launch {
            val templatesResult = repository.loadTemplates()
            val templates = (templatesResult as? ApiResult.Success)?.data ?: _state.value.templates
            when (val cyclesResult = repository.loadCycles()) {
                is ApiResult.Success -> _state.update {
                    it.copy(loading = false, refreshing = false, error = null, cycles = cyclesResult.data, templates = templates)
                }
                is ApiResult.Error -> _state.update {
                    it.copy(loading = false, refreshing = false, error = cyclesResult.message, templates = templates)
                }
                is ApiResult.NetworkError -> _state.update {
                    it.copy(loading = false, refreshing = false, error = NETWORK_MESSAGE, templates = templates)
                }
            }
        }
    }

    fun dismissNotice() = _state.update { it.copy(notice = null) }

    fun dismissActionError() = _state.update { it.copy(actionError = null) }

    /** One-shot consume of a load error once it has been surfaced over stale data. */
    fun consumeError() = _state.update { it.copy(error = null) }

    // --- editor lifecycle ---------------------------------------------------

    fun openCreate() {
        val steps = List(INITIAL_STEP_SLOTS) { StepRow(key = nextKey()) }
        _state.update {
            it.copy(
                actionError = null,
                notice = null,
                editor = CycleEditorState(
                    cycleId = null,
                    name = "",
                    startsOn = LocalDate.now().toString(),
                    active = true,
                    steps = steps,
                    initial = CycleEditorSnapshot(
                        name = "",
                        startsOn = LocalDate.now().toString(),
                        active = true,
                        stepTemplateIds = steps.map { row -> row.templateId },
                    ),
                ),
            )
        }
    }

    fun openEdit(cycle: ShiftCycleDto) {
        val rows = cycle.steps
            .sortedBy { it.position }
            .map { StepRow(key = nextKey(), templateId = it.shiftTemplateId) }
            .ifEmpty { listOf(StepRow(key = nextKey())) }
        _state.update {
            it.copy(
                actionError = null,
                notice = null,
                editor = CycleEditorState(
                    cycleId = cycle.id,
                    name = cycle.name,
                    startsOn = cycle.startsOn.orEmpty(),
                    active = cycle.active,
                    steps = rows,
                    initial = CycleEditorSnapshot(
                        name = cycle.name,
                        startsOn = cycle.startsOn.orEmpty(),
                        active = cycle.active,
                        stepTemplateIds = rows.map { row -> row.templateId },
                    ),
                ),
            )
        }
    }

    fun closeEditor() = _state.update { it.copy(editor = null) }

    fun editorSetName(name: String) = updateEditor { it.copy(name = name.take(80), error = null, nameError = null) }

    fun editorSetStartsOn(isoDate: String) = updateEditor { it.copy(startsOn = isoDate, error = null) }

    fun editorSetActive(active: Boolean) = updateEditor { it.copy(active = active) }

    fun editorSetStep(key: Long, templateId: Long?) = updateEditor { editor ->
        editor.copy(
            error = null,
            steps = editor.steps.map { if (it.key == key) it.copy(templateId = templateId) else it },
        )
    }

    fun editorAddStep() = updateEditor { editor ->
        if (!editor.canAddStep) editor
        else editor.copy(error = null, steps = editor.steps + StepRow(key = nextKey()))
    }

    fun editorRemoveStep(key: Long) = updateEditor { editor ->
        if (editor.steps.size <= 1) editor
        else editor.copy(error = null, steps = editor.steps.filterNot { it.key == key })
    }

    fun saveEditor() {
        val editor = _state.value.editor ?: return
        if (editor.saving) return

        if (editor.name.isBlank()) {
            updateEditor { it.copy(nameError = "Enter a name for the cycle.") }
            return
        }
        if (editor.startsOn.isBlank()) {
            updateEditor { it.copy(error = "Choose the date this cycle starts.") }
            return
        }
        val stepIds = editor.steps.mapNotNull { it.templateId }
        if (stepIds.isEmpty()) {
            updateEditor { it.copy(error = "Choose at least one shift in the cycle.") }
            return
        }

        updateEditor { it.copy(saving = true, error = null) }
        viewModelScope.launch {
            val result = if (editor.isCreate) {
                repository.createCycle(editor.name.trim(), editor.startsOn, editor.active, stepIds)
            } else {
                repository.updateCycle(editor.cycleId!!, editor.name.trim(), editor.startsOn, editor.active, stepIds)
            }
            when (result) {
                is ApiResult.Success -> {
                    _state.update {
                        it.copy(
                            editor = null,
                            notice = if (editor.isCreate) "Shift cycle created." else "Shift cycle updated.",
                        )
                    }
                    load()
                }
                is ApiResult.Error -> updateEditor { it.copy(saving = false, error = result.message) }
                is ApiResult.NetworkError -> updateEditor { it.copy(saving = false, error = NETWORK_MESSAGE) }
            }
        }
    }

    // --- delete -------------------------------------------------------------

    fun deleteCycle(id: Long) {
        if (_state.value.deletingId != null) return
        _state.update { it.copy(deletingId = id, actionError = null, notice = null) }
        viewModelScope.launch {
            when (val result = repository.deleteCycle(id)) {
                is ApiResult.Success -> {
                    _state.update { it.copy(deletingId = null, notice = "Shift cycle deleted.") }
                    load()
                }
                is ApiResult.Error -> _state.update { it.copy(deletingId = null, actionError = result.message) }
                is ApiResult.NetworkError -> _state.update { it.copy(deletingId = null, actionError = NETWORK_MESSAGE) }
            }
        }
    }

    // --- activate / deactivate ---------------------------------------------

    fun setActive(id: Long, active: Boolean) {
        if (_state.value.togglingId != null) return
        _state.update { it.copy(togglingId = id, actionError = null, notice = null) }
        viewModelScope.launch {
            val result = if (active) repository.activateCycle(id) else repository.deactivateCycle(id)
            when (result) {
                is ApiResult.Success -> {
                    _state.update { state ->
                        state.copy(
                            togglingId = null,
                            notice = if (active) "Shift cycle activated." else "Shift cycle deactivated.",
                            cycles = state.cycles.map { if (it.id == id) result.data else it },
                        )
                    }
                }
                is ApiResult.Error -> _state.update { it.copy(togglingId = null, actionError = result.message) }
                is ApiResult.NetworkError -> _state.update { it.copy(togglingId = null, actionError = NETWORK_MESSAGE) }
            }
        }
    }

    private fun updateEditor(transform: (CycleEditorState) -> CycleEditorState) {
        _state.update { s -> s.editor?.let { s.copy(editor = transform(it)) } ?: s }
    }

    private fun nextKey(): Long = keySeq++
}
