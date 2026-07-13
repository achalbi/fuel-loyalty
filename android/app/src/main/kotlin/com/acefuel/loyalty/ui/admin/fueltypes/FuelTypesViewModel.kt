package com.acefuel.loyalty.ui.admin.fueltypes

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.acefuel.loyalty.core.network.ApiResult
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

private const val NETWORK_MESSAGE = "Couldn't reach the server. Try again."

/**
 * The inline add/edit form. It is always present on the screen: [editingId] ==
 * null means "create", otherwise it edits the row whose id is [editingId] and
 * shows its fixed [editingCode] read-only.
 */
data class FuelTypeFormState(
    val editingId: Long? = null,
    val editingCode: String? = null,
    val name: String = "",
    val showInApp: Boolean = true,
    val saving: Boolean = false,
    val error: String? = null,
) {
    val isEdit: Boolean get() = editingId != null
}

data class FuelTypesUiState(
    val loading: Boolean = true,
    val error: String? = null,
    val fuelTypes: List<FuelTypeDto> = emptyList(),
    val form: FuelTypeFormState = FuelTypeFormState(),
    val deletingId: Long? = null,
    val notice: String? = null,
    val actionError: String? = null,
)

class FuelTypesViewModel(private val repository: FuelTypesRepository) : ViewModel() {

    private val _state = MutableStateFlow(FuelTypesUiState())
    val state: StateFlow<FuelTypesUiState> = _state.asStateFlow()

    init {
        load()
    }

    fun load() {
        _state.update { it.copy(loading = true, error = null) }
        viewModelScope.launch {
            when (val result = repository.loadFuelTypes()) {
                is ApiResult.Success -> _state.update {
                    it.copy(loading = false, error = null, fuelTypes = result.data)
                }
                is ApiResult.Error -> _state.update {
                    it.copy(loading = false, error = result.message)
                }
                is ApiResult.NetworkError -> _state.update {
                    it.copy(loading = false, error = NETWORK_MESSAGE)
                }
            }
        }
    }

    fun refresh() = load()

    fun dismissNotice() = _state.update { it.copy(notice = null) }

    fun dismissActionError() = _state.update { it.copy(actionError = null) }

    // --- form -------------------------------------------------------------

    fun onNameChange(value: String) = updateForm { it.copy(name = value, error = null) }

    fun onShowInAppChange(value: Boolean) = updateForm { it.copy(showInApp = value) }

    fun startEdit(fuelType: FuelTypeDto) {
        _state.update {
            it.copy(
                notice = null,
                actionError = null,
                form = FuelTypeFormState(
                    editingId = fuelType.id,
                    editingCode = fuelType.code,
                    name = fuelType.name,
                    showInApp = fuelType.active,
                ),
            )
        }
    }

    /** Reset the form back to a blank "create" state. */
    fun cancelEdit() = _state.update { it.copy(form = FuelTypeFormState()) }

    fun submitForm() {
        val form = _state.value.form
        if (form.saving) return
        val name = form.name.trim()
        if (name.isBlank()) {
            updateForm { it.copy(error = "Enter a fuel type name.") }
            return
        }

        updateForm { it.copy(saving = true, error = null) }
        _state.update { it.copy(notice = null, actionError = null) }
        viewModelScope.launch {
            val result = if (form.isEdit) {
                repository.updateFuelType(form.editingId!!, name, form.showInApp)
            } else {
                repository.createFuelType(name, form.showInApp)
            }
            when (result) {
                is ApiResult.Success -> {
                    _state.update {
                        it.copy(
                            form = FuelTypeFormState(),
                            notice = if (form.isEdit) {
                                "Fuel type updated successfully."
                            } else {
                                "Fuel type added successfully."
                            },
                        )
                    }
                    load()
                }
                is ApiResult.Error -> updateForm { it.copy(saving = false, error = result.message) }
                is ApiResult.NetworkError -> updateForm { it.copy(saving = false, error = NETWORK_MESSAGE) }
            }
        }
    }

    // --- delete -----------------------------------------------------------

    fun deleteFuelType(id: Long) {
        if (_state.value.deletingId != null) return
        _state.update { it.copy(deletingId = id, actionError = null, notice = null) }
        viewModelScope.launch {
            when (val result = repository.deleteFuelType(id)) {
                is ApiResult.Success -> {
                    _state.update {
                        it.copy(
                            deletingId = null,
                            notice = result.data.message ?: "Fuel type removed successfully.",
                            // If the row being edited was just deleted, reset the form.
                            form = if (it.form.editingId == id) FuelTypeFormState() else it.form,
                        )
                    }
                    load()
                }
                // 409 conflict (code = "delete_restricted") surfaces the backend message
                // explaining vehicles/nozzles still reference this fuel type.
                is ApiResult.Error -> _state.update { it.copy(deletingId = null, actionError = result.message) }
                is ApiResult.NetworkError -> _state.update {
                    it.copy(deletingId = null, actionError = NETWORK_MESSAGE)
                }
            }
        }
    }

    private fun updateForm(transform: (FuelTypeFormState) -> FuelTypeFormState) {
        _state.update { it.copy(form = transform(it.form)) }
    }
}
