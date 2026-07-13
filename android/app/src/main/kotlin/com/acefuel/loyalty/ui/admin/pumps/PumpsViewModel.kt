package com.acefuel.loyalty.ui.admin.pumps

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.acefuel.loyalty.core.network.ApiResult
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

private const val NETWORK_MESSAGE = "Couldn't reach the server. Try again."

/** One editable nozzle row inside the pump form. [key] is a stable local id. */
data class NozzleFormRow(
    val key: Long,
    val id: Long? = null,
    val fuelTypeCode: String = "",
    val fuelTypeName: String = "",
    val active: Boolean = true,
)

/** Non-null on [PumpsUiState] while the create/edit form is open. */
data class PumpEditorState(
    val pumpId: Long? = null,
    val titleName: String = "",
    val active: Boolean = true,
    val nozzles: List<NozzleFormRow> = emptyList(),
    val removedNozzleIds: List<Long> = emptyList(),
    val saving: Boolean = false,
    val error: String? = null,
) {
    val isCreate: Boolean get() = pumpId == null
}

data class PumpsUiState(
    val loading: Boolean = true,
    val error: String? = null,
    val pumps: List<FuelPumpDto> = emptyList(),
    val fuelTypes: List<FuelTypeDto> = emptyList(),
    val nozzleFeatureEnabled: Boolean = false,
    val featureToggleInFlight: Boolean = false,
    val deletingPumpId: Long? = null,
    val notice: String? = null,
    val actionError: String? = null,
    val editor: PumpEditorState? = null,
) {
    val activeFuelTypes: List<FuelTypeDto> get() = fuelTypes.filter { it.active }
}

class PumpsViewModel(private val repository: PumpsRepository) : ViewModel() {

    private val _state = MutableStateFlow(PumpsUiState())
    val state: StateFlow<PumpsUiState> = _state.asStateFlow()

    private var keySeq = 0L

    init {
        load()
    }

    fun load() {
        _state.update { it.copy(loading = true, error = null) }
        viewModelScope.launch {
            val typesResult = repository.loadFuelTypes()
            val fuelTypes = (typesResult as? ApiResult.Success)?.data ?: _state.value.fuelTypes
            when (val pumpsResult = repository.loadPumps()) {
                is ApiResult.Success -> _state.update {
                    it.copy(
                        loading = false,
                        error = null,
                        pumps = pumpsResult.data.fuelPumps,
                        nozzleFeatureEnabled = pumpsResult.data.rewardSetting.nozzleFeatureEnabled,
                        fuelTypes = fuelTypes,
                    )
                }
                is ApiResult.Error -> _state.update {
                    it.copy(loading = false, error = pumpsResult.message, fuelTypes = fuelTypes)
                }
                is ApiResult.NetworkError -> _state.update {
                    it.copy(loading = false, error = NETWORK_MESSAGE, fuelTypes = fuelTypes)
                }
            }
        }
    }

    fun refresh() = load()

    fun dismissNotice() = _state.update { it.copy(notice = null) }

    fun dismissActionError() = _state.update { it.copy(actionError = null) }

    // --- feature toggle -----------------------------------------------------

    fun onFeatureToggle(enabled: Boolean) {
        if (_state.value.featureToggleInFlight) return
        _state.update { it.copy(featureToggleInFlight = true, actionError = null, notice = null) }
        viewModelScope.launch {
            when (val result = repository.setFeatureEnabled(enabled)) {
                is ApiResult.Success -> _state.update {
                    it.copy(
                        featureToggleInFlight = false,
                        nozzleFeatureEnabled = result.data.rewardSetting.nozzleFeatureEnabled,
                        notice = result.data.message ?: "Pump transaction settings updated successfully.",
                    )
                }
                is ApiResult.Error -> _state.update {
                    it.copy(featureToggleInFlight = false, actionError = result.message)
                }
                is ApiResult.NetworkError -> _state.update {
                    it.copy(featureToggleInFlight = false, actionError = NETWORK_MESSAGE)
                }
            }
        }
    }

    // --- editor lifecycle ---------------------------------------------------

    fun openCreate() {
        val nextNumber = (_state.value.pumps.maxOfOrNull { it.sequenceNumber } ?: 0) + 1
        val first = _state.value.activeFuelTypes.firstOrNull()
        _state.update {
            it.copy(
                actionError = null,
                notice = null,
                editor = PumpEditorState(
                    pumpId = null,
                    titleName = "Pump $nextNumber",
                    active = true,
                    nozzles = listOf(
                        NozzleFormRow(
                            key = nextKey(),
                            fuelTypeCode = first?.code.orEmpty(),
                            fuelTypeName = first?.name.orEmpty(),
                            active = true,
                        ),
                    ),
                ),
            )
        }
    }

    fun openEdit(pump: FuelPumpDto) {
        _state.update {
            it.copy(
                actionError = null,
                notice = null,
                editor = PumpEditorState(
                    pumpId = pump.id,
                    titleName = pump.displayName,
                    active = pump.active,
                    nozzles = pump.nozzles.map { nozzle ->
                        NozzleFormRow(
                            key = nextKey(),
                            id = nozzle.id,
                            fuelTypeCode = nozzle.fuelTypeCode,
                            fuelTypeName = nozzle.fuelTypeName,
                            active = nozzle.active,
                        )
                    },
                ),
            )
        }
    }

    fun closeEditor() = _state.update { it.copy(editor = null) }

    fun editorSetActive(active: Boolean) = updateEditor { it.copy(active = active) }

    fun editorAddNozzle() {
        val first = _state.value.activeFuelTypes.firstOrNull()
        updateEditor { editor ->
            editor.copy(
                error = null,
                nozzles = editor.nozzles + NozzleFormRow(
                    key = nextKey(),
                    fuelTypeCode = first?.code.orEmpty(),
                    fuelTypeName = first?.name.orEmpty(),
                    active = true,
                ),
            )
        }
    }

    fun editorRemoveNozzle(key: Long) {
        updateEditor { editor ->
            val row = editor.nozzles.firstOrNull { it.key == key } ?: return@updateEditor editor
            editor.copy(
                error = null,
                nozzles = editor.nozzles.filterNot { it.key == key },
                removedNozzleIds = if (row.id != null) editor.removedNozzleIds + row.id else editor.removedNozzleIds,
            )
        }
    }

    fun editorSetNozzleFuelType(key: Long, code: String) {
        val name = _state.value.fuelTypes.firstOrNull { it.code == code }?.name ?: code
        updateEditor { editor ->
            editor.copy(
                nozzles = editor.nozzles.map {
                    if (it.key == key) it.copy(fuelTypeCode = code, fuelTypeName = name) else it
                },
            )
        }
    }

    fun editorSetNozzleActive(key: Long, active: Boolean) {
        updateEditor { editor ->
            editor.copy(nozzles = editor.nozzles.map { if (it.key == key) it.copy(active = active) else it })
        }
    }

    fun saveEditor() {
        val editor = _state.value.editor ?: return
        if (editor.saving) return
        if (editor.nozzles.isEmpty()) {
            updateEditor { it.copy(error = "Add at least one nozzle before saving.") }
            return
        }
        if (editor.nozzles.any { it.fuelTypeCode.isBlank() }) {
            updateEditor { it.copy(error = "Choose a fuel type for every nozzle.") }
            return
        }

        val attrs = editor.nozzles.map {
            NozzleAttributesRequest(id = it.id, fuelTypeCode = it.fuelTypeCode, active = it.active)
        } + editor.removedNozzleIds.map {
            NozzleAttributesRequest(id = it, destroy = true)
        }

        updateEditor { it.copy(saving = true, error = null) }
        viewModelScope.launch {
            val result = if (editor.isCreate) {
                repository.createPump(editor.active, attrs)
            } else {
                repository.updatePump(editor.pumpId!!, editor.active, attrs)
            }
            when (result) {
                is ApiResult.Success -> {
                    _state.update {
                        it.copy(
                            editor = null,
                            notice = if (editor.isCreate) "Pump added successfully." else "Pump updated successfully.",
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

    fun deletePump(id: Long) {
        if (_state.value.deletingPumpId != null) return
        _state.update { it.copy(deletingPumpId = id, actionError = null, notice = null) }
        viewModelScope.launch {
            when (val result = repository.deletePump(id)) {
                is ApiResult.Success -> {
                    _state.update {
                        it.copy(deletingPumpId = null, notice = result.data.message ?: "Pump removed successfully.")
                    }
                    load()
                }
                is ApiResult.Error -> _state.update { it.copy(deletingPumpId = null, actionError = result.message) }
                is ApiResult.NetworkError -> _state.update {
                    it.copy(deletingPumpId = null, actionError = NETWORK_MESSAGE)
                }
            }
        }
    }

    private fun updateEditor(transform: (PumpEditorState) -> PumpEditorState) {
        _state.update { s -> s.editor?.let { s.copy(editor = transform(it)) } ?: s }
    }

    private fun nextKey(): Long = keySeq++
}
