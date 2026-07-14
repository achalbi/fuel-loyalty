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

data class MyPumpUiState(
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

class MyPumpViewModel(private val repository: StaffRepository) : ViewModel() {

    private val _state = MutableStateFlow(MyPumpUiState())
    val state: StateFlow<MyPumpUiState> = _state.asStateFlow()

    init {
        load()
    }

    fun load() {
        _state.update { it.copy(loading = true, loadError = null) }
        viewModelScope.launch {
            when (val r = repository.myPump()) {
                is ApiResult.Success -> _state.update { it.applyLoaded(r.data) }
                is ApiResult.Error -> _state.update { it.copy(loading = false, loadError = r.message) }
                is ApiResult.NetworkError -> _state.update {
                    it.copy(loading = false, loadError = "Couldn't load pumps. Check your connection.")
                }
            }
        }
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
            when (val r = repository.updateMyPump(pumpId, s.selectedNozzleIds.toList())) {
                is ApiResult.Success -> _state.update { it.applyLoaded(r.data).copy(saved = true) }
                is ApiResult.Error -> _state.update { it.copy(saving = false, saveError = r.message) }
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
        return copy(
            loading = false,
            saving = false,
            loadError = null,
            pumps = data.pumps,
            selectedPumpId = selectedPump?.id,
            selectedNozzleIds = validNozzleIds,
        )
    }
}
