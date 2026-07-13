package com.acefuel.loyalty.ui.admin.vehicletypes

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.acefuel.loyalty.core.network.ApiResult
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

/** Icon choices mirror VehicleType::ICON_OPTIONS (label + value). */
object VehicleTypeIcons {
    val OPTIONS: List<Pair<String, String>> = listOf(
        "ti-bike" to "Bike",
        "custom-tuk-tuk" to "Auto Rickshaw / 3 Wheeler",
        "ti-car" to "Car",
        "custom-pickup-truck" to "Pickup Truck",
        "ti-truck" to "Truck",
        "custom-big-truck" to "Big Truck",
        "ti-bus" to "Bus",
        "ti-tractor" to "Tractor",
    )

    fun labelFor(value: String): String =
        OPTIONS.firstOrNull { it.first == value }?.second ?: value
}

private const val DEFAULT_APP_LABEL_SOURCE = "short_name"
private const val DEFAULT_ICON_NAME = "ti-car"
private const val MINIMUM_REDEEMABLE_STEP = 100

/** Editable form backing the create/edit sheet. */
data class VehicleTypeForm(
    val name: String = "",
    val shortName: String = "",
    val appLabelSource: String = DEFAULT_APP_LABEL_SOURCE,
    val code: String = "",
    val iconName: String = DEFAULT_ICON_NAME,
    val minimumRedeemablePoints: Int = MINIMUM_REDEEMABLE_STEP,
    val active: Boolean = true,
)

data class VehicleTypesUiState(
    val loading: Boolean = false,
    val refreshing: Boolean = false,
    val items: List<VehicleTypeDto> = emptyList(),
    // Load failures only; mutations report through [actionError].
    val error: String? = null,
    val actionError: String? = null,
    val notice: String? = null,
    val editorOpen: Boolean = false,
    val editingId: Long? = null,
    val form: VehicleTypeForm = VehicleTypeForm(),
    /** Form values captured when the sheet opened, used to detect unsaved changes. */
    val initialForm: VehicleTypeForm? = null,
    val saving: Boolean = false,
    val formError: String? = null,
    val nameError: String? = null,
    val deletingId: Long? = null,
    /** Row just deleted on the server; drives the Undo snackbar. */
    val deletedForUndo: VehicleTypeDto? = null,
) {
    val isEditing: Boolean get() = editingId != null
    val editorDirty: Boolean get() = initialForm != null && form != initialForm
}

private const val NETWORK_MESSAGE = "Couldn't reach the server. Try again."

class VehicleTypesViewModel(
    private val repository: VehicleTypesRepository,
) : ViewModel() {

    private val _state = MutableStateFlow(VehicleTypesUiState())
    val state: StateFlow<VehicleTypesUiState> = _state.asStateFlow()

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
            when (val result = repository.list()) {
                is ApiResult.Success ->
                    _state.update { it.copy(loading = false, refreshing = false, error = null, items = result.data) }
                is ApiResult.Error ->
                    _state.update { it.copy(loading = false, refreshing = false, error = result.message) }
                is ApiResult.NetworkError ->
                    _state.update { it.copy(loading = false, refreshing = false, error = NETWORK_MESSAGE) }
            }
        }
    }

    // --- editor open/close ---------------------------------------------------

    fun openCreate() {
        _state.update {
            it.copy(
                editorOpen = true,
                editingId = null,
                form = VehicleTypeForm(),
                initialForm = VehicleTypeForm(),
                formError = null,
                nameError = null,
            )
        }
    }

    fun openEdit(item: VehicleTypeDto) {
        val form = VehicleTypeForm(
            name = item.name,
            shortName = item.shortName,
            appLabelSource = item.appLabelSource,
            code = item.code,
            iconName = item.iconName,
            minimumRedeemablePoints = item.minimumRedeemablePoints,
            active = item.active,
        )
        _state.update {
            it.copy(
                editorOpen = true,
                editingId = item.id,
                formError = null,
                nameError = null,
                form = form,
                initialForm = form,
            )
        }
    }

    fun closeEditor() {
        _state.update { it.copy(editorOpen = false, formError = null, nameError = null, initialForm = null) }
    }

    // --- one-shot message consumption -----------------------------------------

    fun consumeError() = _state.update { it.copy(error = null) }

    fun consumeActionError() = _state.update { it.copy(actionError = null) }

    fun consumeNotice() = _state.update { it.copy(notice = null) }

    fun consumeDeleted() = _state.update { it.copy(deletedForUndo = null) }

    // --- form field updates --------------------------------------------------

    private fun updateForm(transform: (VehicleTypeForm) -> VehicleTypeForm) {
        _state.update { it.copy(form = transform(it.form)) }
    }

    fun onNameChange(value: String) {
        _state.update { it.copy(form = it.form.copy(name = value), nameError = null) }
    }

    fun onShortNameChange(value: String) = updateForm { it.copy(shortName = value) }
    fun onAppLabelSourceChange(value: String) = updateForm { it.copy(appLabelSource = value) }
    fun onCodeChange(value: String) = updateForm { it.copy(code = value) }
    fun onIconChange(value: String) = updateForm { it.copy(iconName = value) }
    fun onActiveChange(value: Boolean) = updateForm { it.copy(active = value) }

    fun incrementMinimum() = updateForm {
        it.copy(minimumRedeemablePoints = it.minimumRedeemablePoints + MINIMUM_REDEEMABLE_STEP)
    }

    fun decrementMinimum() = updateForm {
        it.copy(
            minimumRedeemablePoints =
                (it.minimumRedeemablePoints - MINIMUM_REDEEMABLE_STEP).coerceAtLeast(MINIMUM_REDEEMABLE_STEP),
        )
    }

    // --- persistence ---------------------------------------------------------

    fun save() {
        val current = _state.value
        val form = current.form
        if (form.name.isBlank()) {
            _state.update { it.copy(nameError = "Vehicle type name is required.") }
            return
        }

        val editingId = current.editingId
        val request = VehicleTypeRequest(
            name = form.name.trim(),
            shortName = form.shortName.trim(),
            appLabelSource = form.appLabelSource,
            // code is create-only; blank -> null so the server generates it.
            code = if (editingId == null) form.code.trim().ifBlank { null } else null,
            iconName = form.iconName,
            minimumRedeemablePoints = form.minimumRedeemablePoints,
            active = form.active,
        )

        _state.update { it.copy(saving = true, formError = null, nameError = null) }
        viewModelScope.launch {
            val result =
                if (editingId == null) repository.create(request)
                else repository.update(editingId, request)
            when (result) {
                is ApiResult.Success -> {
                    _state.update {
                        it.copy(
                            saving = false,
                            editorOpen = false,
                            formError = null,
                            initialForm = null,
                            notice = if (editingId == null) "Vehicle type created." else "Vehicle type updated.",
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

    fun delete(item: VehicleTypeDto) {
        if (_state.value.deletingId != null) return
        val index = _state.value.items.indexOfFirst { it.id == item.id }
        // Optimistic removal; the row is restored if the server rejects it.
        _state.update { s ->
            s.copy(deletingId = item.id, actionError = null, items = s.items.filterNot { it.id == item.id })
        }
        viewModelScope.launch {
            when (val result = repository.delete(item.id)) {
                is ApiResult.Success ->
                    _state.update { it.copy(deletingId = null, deletedForUndo = item) }
                is ApiResult.Error -> restoreAfterFailedDelete(item, index, result.message)
                is ApiResult.NetworkError -> restoreAfterFailedDelete(item, index, NETWORK_MESSAGE)
            }
        }
    }

    /** Re-creates a just-deleted vehicle type with its previous attributes. */
    fun undoDelete(item: VehicleTypeDto) {
        val request = VehicleTypeRequest(
            name = item.name,
            shortName = item.shortName,
            appLabelSource = item.appLabelSource,
            code = item.code,
            iconName = item.iconName,
            minimumRedeemablePoints = item.minimumRedeemablePoints,
            active = item.active,
        )
        viewModelScope.launch {
            when (val result = repository.create(request)) {
                is ApiResult.Success -> {
                    _state.update { it.copy(notice = "Vehicle type restored.") }
                    load()
                }
                is ApiResult.Error -> _state.update { it.copy(actionError = result.message) }
                is ApiResult.NetworkError -> _state.update { it.copy(actionError = NETWORK_MESSAGE) }
            }
        }
    }

    private fun restoreAfterFailedDelete(item: VehicleTypeDto, index: Int, message: String) {
        _state.update { s ->
            // Only re-insert if the row isn't already present — a refresh that
            // landed between the optimistic remove and the failure may have
            // restored it, and a duplicate id crashes the keyed LazyColumn.
            if (s.items.any { it.id == item.id }) {
                return@update s.copy(deletingId = null, actionError = message)
            }
            val restored = s.items.toMutableList().apply {
                add(index.coerceIn(0, size), item)
            }
            s.copy(deletingId = null, actionError = message, items = restored)
        }
    }
}
