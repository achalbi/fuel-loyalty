package com.acefuel.loyalty.ui.admin.staff

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.acefuel.loyalty.core.network.ApiResult
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

private const val NETWORK_MESSAGE = "Couldn't reach the server. Try again."

/** Non-null on [AdminStaffUiState] while the Edit-profile form is open. */
data class StaffProfileEditorState(
    val staffId: Long,
    val staffLabel: String,
    val name: String,
    val employeeCode: String,
    val subtitle: String,
    val active: Boolean,
    val saving: Boolean = false,
    val error: String? = null,
)

/** Non-null on [AdminStaffUiState] while the Assign-shift form is open. */
data class ShiftAssignerState(
    val staffId: Long,
    val staffLabel: String,
    val selectedTemplateId: Long? = null,
    val notes: String = "",
    val saving: Boolean = false,
    val error: String? = null,
)

data class AdminStaffUiState(
    val loading: Boolean = true,
    val error: String? = null,
    val staff: List<StaffMemberDto> = emptyList(),
    val stats: StaffStatsDto = StaffStatsDto(),
    val shiftTemplates: List<ShiftTemplateDto> = emptyList(),
    val notice: String? = null,
    val actionError: String? = null,
    val deletingStaffId: Long? = null,
    val profileEditor: StaffProfileEditorState? = null,
    val shiftAssigner: ShiftAssignerState? = null,
)

class AdminStaffViewModel(private val repository: AdminStaffRepository) : ViewModel() {

    private val _state = MutableStateFlow(AdminStaffUiState())
    val state: StateFlow<AdminStaffUiState> = _state.asStateFlow()

    init {
        load()
    }

    fun load() {
        _state.update { it.copy(loading = true, error = null) }
        viewModelScope.launch {
            // Shift templates power the Assign-shift dropdown; a failure here is
            // non-fatal (the assign sheet just shows the "No shifts yet" state).
            val templatesResult = repository.loadShiftTemplates()
            val templates = (templatesResult as? ApiResult.Success)?.data ?: _state.value.shiftTemplates
            when (val result = repository.loadStaff()) {
                is ApiResult.Success -> _state.update {
                    it.copy(
                        loading = false,
                        error = null,
                        staff = result.data.staffMembers,
                        stats = result.data.stats,
                        shiftTemplates = templates,
                    )
                }
                is ApiResult.Error -> _state.update {
                    it.copy(loading = false, error = result.message, shiftTemplates = templates)
                }
                is ApiResult.NetworkError -> _state.update {
                    it.copy(loading = false, error = NETWORK_MESSAGE, shiftTemplates = templates)
                }
            }
        }
    }

    fun refresh() = load()

    fun dismissNotice() = _state.update { it.copy(notice = null) }

    fun dismissActionError() = _state.update { it.copy(actionError = null) }

    // --- Edit profile -------------------------------------------------------

    fun openEditProfile(staff: StaffMemberDto) {
        _state.update {
            it.copy(
                notice = null,
                actionError = null,
                shiftAssigner = null,
                profileEditor = StaffProfileEditorState(
                    staffId = staff.id,
                    staffLabel = staff.name ?: "Staff member",
                    name = staff.name.orEmpty(),
                    employeeCode = staff.employeeCode.orEmpty(),
                    subtitle = staff.subtitle.orEmpty(),
                    active = staff.active,
                ),
            )
        }
    }

    fun closeEditProfile() = _state.update { it.copy(profileEditor = null) }

    fun editorSetName(value: String) = updateEditor { it.copy(name = value, error = null) }

    fun editorSetEmployeeCode(value: String) = updateEditor { it.copy(employeeCode = value) }

    fun editorSetSubtitle(value: String) =
        updateEditor { if (value.length <= 120) it.copy(subtitle = value) else it }

    fun editorSetActive(value: Boolean) = updateEditor { it.copy(active = value) }

    fun saveProfile() {
        val editor = _state.value.profileEditor ?: return
        if (editor.saving) return
        if (editor.name.isBlank()) {
            updateEditor { it.copy(error = "Name is required.") }
            return
        }
        updateEditor { it.copy(saving = true, error = null) }
        viewModelScope.launch {
            val result = repository.updateProfile(
                id = editor.staffId,
                name = editor.name.trim(),
                employeeCode = editor.employeeCode.trim(),
                subtitle = editor.subtitle.trim(),
                active = editor.active,
            )
            when (result) {
                is ApiResult.Success -> {
                    _state.update { it.copy(profileEditor = null, notice = "Staff profile updated successfully.") }
                    load()
                }
                is ApiResult.Error -> updateEditor { it.copy(saving = false, error = result.message) }
                is ApiResult.NetworkError -> updateEditor { it.copy(saving = false, error = NETWORK_MESSAGE) }
            }
        }
    }

    // --- Assign shift -------------------------------------------------------

    fun openAssignShift(staff: StaffMemberDto) {
        _state.update {
            it.copy(
                notice = null,
                actionError = null,
                profileEditor = null,
                shiftAssigner = ShiftAssignerState(
                    staffId = staff.id,
                    staffLabel = staff.name ?: "Staff member",
                    selectedTemplateId = staff.currentShiftTemplate?.id,
                ),
            )
        }
    }

    fun closeAssignShift() = _state.update { it.copy(shiftAssigner = null) }

    fun assignerSelectTemplate(templateId: Long) =
        updateAssigner { it.copy(selectedTemplateId = templateId, error = null) }

    fun assignerSetNotes(value: String) = updateAssigner { it.copy(notes = value) }

    fun saveAssignment() {
        val assigner = _state.value.shiftAssigner ?: return
        if (assigner.saving) return
        val templateId = assigner.selectedTemplateId
        if (templateId == null) {
            updateAssigner { it.copy(error = "Choose a shift to assign.") }
            return
        }
        updateAssigner { it.copy(saving = true, error = null) }
        viewModelScope.launch {
            when (val result = repository.assignShift(assigner.staffId, templateId, assigner.notes.trim().ifBlank { null })) {
                is ApiResult.Success -> {
                    _state.update { it.copy(shiftAssigner = null, notice = "Shift assigned successfully.") }
                    load()
                }
                is ApiResult.Error -> updateAssigner { it.copy(saving = false, error = result.message) }
                is ApiResult.NetworkError -> updateAssigner { it.copy(saving = false, error = NETWORK_MESSAGE) }
            }
        }
    }

    // --- Soft delete --------------------------------------------------------

    fun softDelete(id: Long) {
        if (_state.value.deletingStaffId != null) return
        _state.update { it.copy(deletingStaffId = id, actionError = null, notice = null) }
        viewModelScope.launch {
            when (val result = repository.softDelete(id)) {
                is ApiResult.Success -> {
                    _state.update {
                        it.copy(deletingStaffId = null, notice = "Staff member removed. Historical records are kept.")
                    }
                    load()
                }
                is ApiResult.Error -> _state.update { it.copy(deletingStaffId = null, actionError = result.message) }
                is ApiResult.NetworkError -> _state.update { it.copy(deletingStaffId = null, actionError = NETWORK_MESSAGE) }
            }
        }
    }

    private fun updateEditor(transform: (StaffProfileEditorState) -> StaffProfileEditorState) {
        _state.update { s -> s.profileEditor?.let { s.copy(profileEditor = transform(it)) } ?: s }
    }

    private fun updateAssigner(transform: (ShiftAssignerState) -> ShiftAssignerState) {
        _state.update { s -> s.shiftAssigner?.let { s.copy(shiftAssigner = transform(it)) } ?: s }
    }
}
