package com.acefuel.loyalty.ui.mypump

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.acefuel.loyalty.core.data.StaffRepository
import com.acefuel.loyalty.core.network.ApiResult
import com.acefuel.loyalty.core.network.dto.MyPumpDto
import com.acefuel.loyalty.core.network.dto.NozzleDto
import com.acefuel.loyalty.core.network.dto.PumpDto
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.time.LocalDate

data class MyPumpUiState(
    val assignmentDate: LocalDate = LocalDate.now(),
    val assignmentMode: String = "override",
    val loading: Boolean = true,
    val loadError: String? = null,
    val pumps: List<PumpDto> = emptyList(),
    val selectedPumpId: Long? = null,
    val selectedNozzleIds: Set<Long> = emptySet(),
    val saving: Boolean = false,
    val saveError: String? = null,
    val saved: Boolean = false,
) {
    /** Only active pumps can be assigned — the server rejects inactive ones. */
    val activePumps: List<PumpDto> get() = pumps.filter { it.active }

    /** Active nozzles on the chosen pump (the only valid selections). */
    val nozzlesForSelectedPump: List<NozzleDto>
        get() = pumps.firstOrNull { it.id == selectedPumpId }?.nozzles?.filter { it.active } ?: emptyList()

    val canSave: Boolean
        get() = selectedPumpId != null && selectedNozzleIds.isNotEmpty() && !saving
}

class MyPumpViewModel(
    private val repository: StaffRepository,
    // null = current user's self-service pump; non-null = an admin assigning
    // this staff member's pump via the admin endpoint (A10).
    private val staffMemberId: Long? = null,
) : ViewModel() {

    private val _state = MutableStateFlow(MyPumpUiState())
    val state: StateFlow<MyPumpUiState> = _state.asStateFlow()

    init {
        load()
    }

    fun load() {
        // Re-read the clock on every load so a screen left open overnight shows
        // (and saves against) the right day.
        val today = LocalDate.now()
        _state.update {
            if (staffMemberId == null) {
                it.copy(loading = true, loadError = null, assignmentDate = today)
            } else {
                it.copy(loading = true, loadError = null)
            }
        }
        viewModelScope.launch {
            val mode = _state.value.assignmentMode
            val result = if (staffMemberId != null) {
                repository.staffMemberPump(
                    staffMemberId = staffMemberId,
                    assignmentDate = _state.value.assignmentDate.takeIf { mode == "override" }?.toString(),
                    assignmentMode = mode,
                )
            } else {
                // S-MYPUMP — the self route always applies to today. No date is
                // transmitted: the server pins it, so a skewed device clock can't
                // write the override onto the wrong day.
                repository.myPump(assignmentMode = "override")
            }
            when (result) {
                is ApiResult.Success -> _state.update { it.applyLoaded(result.data) }
                is ApiResult.Error -> _state.update { it.copy(loading = false, loadError = result.message) }
                is ApiResult.NetworkError -> _state.update {
                    it.copy(loading = false, loadError = "Couldn't load pumps. Check your connection.")
                }
            }
        }
    }

    fun setAssignmentDate(date: LocalDate) {
        // Only the admin route (A10) picks a date — the self route is pinned to
        // today by the server (S-MYPUMP) and hides the picker.
        if (staffMemberId == null) return
        if (_state.value.assignmentDate == date) return
        _state.update { it.copy(assignmentDate = date, saved = false) }
        load()
    }

    fun setAssignmentMode(mode: String) {
        if (staffMemberId == null || mode !in setOf("default", "override")) return
        if (_state.value.assignmentMode == mode) return
        _state.update { it.copy(assignmentMode = mode, saved = false) }
        load()
    }

    fun selectPump(id: Long) {
        _state.update { s ->
            if (s.selectedPumpId == id) return@update s
            // Switching pumps drops the old nozzle selection — nozzles are
            // pump-specific and the server rejects cross-pump ids.
            s.copy(selectedPumpId = id, selectedNozzleIds = emptySet(), saveError = null, saved = false)
        }
    }

    fun toggleNozzle(id: Long) {
        _state.update { s ->
            val next = s.selectedNozzleIds.toMutableSet()
            if (!next.add(id)) next.remove(id)
            s.copy(selectedNozzleIds = next, saveError = null, saved = false)
        }
    }

    fun save() {
        val s = _state.value
        val pumpId = s.selectedPumpId ?: return
        if (s.saving || s.selectedNozzleIds.isEmpty()) return
        _state.update { it.copy(saving = true, saveError = null) }
        viewModelScope.launch {
            val nozzleIds = s.selectedNozzleIds.toList()
            val result = if (staffMemberId != null) {
                repository.updateStaffMemberPump(
                    staffMemberId = staffMemberId,
                    fuelPumpId = pumpId,
                    nozzleIds = nozzleIds,
                    assignmentDate = s.assignmentDate.takeIf { s.assignmentMode == "override" }?.toString(),
                    assignmentMode = s.assignmentMode,
                )
            } else {
                // Date deliberately omitted — the server pins the self assignment
                // to today (S-MYPUMP).
                repository.updateMyPump(pumpId, nozzleIds, assignmentMode = "override")
            }
            when (result) {
                is ApiResult.Success -> _state.update { it.applyLoaded(result.data).copy(saved = true) }
                is ApiResult.Error -> _state.update { it.copy(saving = false, saveError = result.message) }
                is ApiResult.NetworkError -> _state.update {
                    it.copy(saving = false, saveError = "Couldn't save. Check your connection and try again.")
                }
            }
        }
    }

    fun consumeSaveError() = _state.update { it.copy(saveError = null) }

    /** Fold a fresh /my_pump payload into state, prefilling the current assignment. */
    private fun MyPumpUiState.applyLoaded(data: MyPumpDto): MyPumpUiState {
        val selectedPump = data.pumps.firstOrNull { it.id == data.fuelPumpId && it.active }
        val validNozzleIds = selectedPump
            ?.nozzles
            ?.filter { it.active && it.id in data.assignedNozzleIds }
            ?.map { it.id }
            ?.toSet()
            ?: emptySet()
        // Trust the server's date over the device clock: the self route is pinned
        // server-side, so the device may disagree about what "today" is.
        val serverDate = data.assignmentDate?.let { runCatching { LocalDate.parse(it) }.getOrNull() }
        return copy(
            loading = false,
            saving = false,
            loadError = null,
            pumps = data.pumps,
            selectedPumpId = selectedPump?.id,
            selectedNozzleIds = validNozzleIds,
            assignmentMode = data.assignmentMode ?: assignmentMode,
            assignmentDate = serverDate ?: assignmentDate,
        )
    }
}
