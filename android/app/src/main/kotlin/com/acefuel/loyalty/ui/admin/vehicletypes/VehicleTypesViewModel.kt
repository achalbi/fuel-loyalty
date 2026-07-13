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
    val items: List<VehicleTypeDto> = emptyList(),
    val error: String? = null,
    val editorOpen: Boolean = false,
    val editingId: Long? = null,
    val form: VehicleTypeForm = VehicleTypeForm(),
    val saving: Boolean = false,
    val formError: String? = null,
    val deletingId: Long? = null,
) {
    val isEditing: Boolean get() = editingId != null
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

    fun refresh() = load()

    private fun load() {
        _state.update { it.copy(loading = true, error = null) }
        viewModelScope.launch {
            when (val result = repository.list()) {
                is ApiResult.Success ->
                    _state.update { it.copy(loading = false, items = result.data) }
                is ApiResult.Error ->
                    _state.update { it.copy(loading = false, error = result.message) }
                is ApiResult.NetworkError ->
                    _state.update { it.copy(loading = false, error = NETWORK_MESSAGE) }
            }
        }
    }

    // --- editor open/close ---------------------------------------------------

    fun openCreate() {
        _state.update {
            it.copy(editorOpen = true, editingId = null, form = VehicleTypeForm(), formError = null)
        }
    }

    fun openEdit(item: VehicleTypeDto) {
        _state.update {
            it.copy(
                editorOpen = true,
                editingId = item.id,
                formError = null,
                form = VehicleTypeForm(
                    name = item.name,
                    shortName = item.shortName,
                    appLabelSource = item.appLabelSource,
                    code = item.code,
                    iconName = item.iconName,
                    minimumRedeemablePoints = item.minimumRedeemablePoints,
                    active = item.active,
                ),
            )
        }
    }

    fun closeEditor() {
        _state.update { it.copy(editorOpen = false, formError = null) }
    }

    fun dismissError() {
        _state.update { it.copy(error = null) }
    }

    // --- form field updates --------------------------------------------------

    private fun updateForm(transform: (VehicleTypeForm) -> VehicleTypeForm) {
        _state.update { it.copy(form = transform(it.form)) }
    }

    fun onNameChange(value: String) = updateForm { it.copy(name = value) }
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
            _state.update { it.copy(formError = "Vehicle type name is required.") }
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

        _state.update { it.copy(saving = true, formError = null) }
        viewModelScope.launch {
            val result =
                if (editingId == null) repository.create(request)
                else repository.update(editingId, request)
            when (result) {
                is ApiResult.Success -> {
                    _state.update { it.copy(saving = false, editorOpen = false, formError = null) }
                    load()
                }
                is ApiResult.Error ->
                    _state.update { it.copy(saving = false, formError = result.message) }
                is ApiResult.NetworkError ->
                    _state.update { it.copy(saving = false, formError = NETWORK_MESSAGE) }
            }
        }
    }

    fun delete(id: Long) {
        _state.update { it.copy(deletingId = id, error = null) }
        viewModelScope.launch {
            when (val result = repository.delete(id)) {
                is ApiResult.Success ->
                    _state.update {
                        it.copy(deletingId = null, items = it.items.filterNot { row -> row.id == id })
                    }
                is ApiResult.Error ->
                    _state.update { it.copy(deletingId = null, error = result.message) }
                is ApiResult.NetworkError ->
                    _state.update { it.copy(deletingId = null, error = NETWORK_MESSAGE) }
            }
        }
    }
}
