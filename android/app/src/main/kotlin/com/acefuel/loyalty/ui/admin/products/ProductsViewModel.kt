package com.acefuel.loyalty.ui.admin.products

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.acefuel.loyalty.core.network.ApiResult
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

private const val NETWORK_MESSAGE = "Couldn't reach the server. Try again."

val PRODUCT_CATEGORIES = listOf("fuel", "lubricant", "oil", "additive")

/** Inline add/edit form. [editingId] == null means "create". */
data class ProductFormState(
    val editingId: Long? = null,
    val name: String = "",
    val category: String = "lubricant",
    val fuelTypeCode: String = "",
    val packSize: String = "",
    val packUnit: String = "",
    val batch: String = "",
    val mrp: String = "",
    val sellingPrice: String = "",
    val slNum: String = "",
    val trackStock: Boolean = true,
    val active: Boolean = true,
    val saving: Boolean = false,
    val error: String? = null,
) {
    val isEdit: Boolean get() = editingId != null
    val isFuel: Boolean get() = category == "fuel"
}

data class ProductsUiState(
    val loading: Boolean = true,
    val refreshing: Boolean = false,
    val error: String? = null,
    val products: List<ProductDto> = emptyList(),
    val form: ProductFormState = ProductFormState(),
    val deletingId: Long? = null,
    val notice: String? = null,
    val actionError: String? = null,
)

class ProductsViewModel(private val repository: ProductsRepository) : ViewModel() {

    private val _state = MutableStateFlow(ProductsUiState())
    val state: StateFlow<ProductsUiState> = _state.asStateFlow()

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
            when (val result = repository.loadProducts()) {
                is ApiResult.Success -> _state.update {
                    it.copy(loading = false, refreshing = false, error = null, products = result.data)
                }
                is ApiResult.Error -> _state.update { it.copy(loading = false, refreshing = false, error = result.message) }
                is ApiResult.NetworkError -> _state.update { it.copy(loading = false, refreshing = false, error = NETWORK_MESSAGE) }
            }
        }
    }

    fun dismissNotice() = _state.update { it.copy(notice = null) }
    fun dismissActionError() = _state.update { it.copy(actionError = null) }
    fun consumeError() = _state.update { it.copy(error = null) }

    // --- form ---
    fun onNameChange(v: String) = updateForm { it.copy(name = v, error = null) }
    fun onCategoryChange(v: String) = updateForm { it.copy(category = v, error = null) }
    fun onFuelTypeChange(v: String) = updateForm { it.copy(fuelTypeCode = v, error = null) }
    fun onPackSizeChange(v: String) = updateForm { it.copy(packSize = v.filter { c -> c.isDigit() || c == '.' }, error = null) }
    fun onPackUnitChange(v: String) = updateForm { it.copy(packUnit = v, error = null) }
    fun onBatchChange(v: String) = updateForm { it.copy(batch = v, error = null) }
    fun onMrpChange(v: String) = updateForm { it.copy(mrp = v.filter { c -> c.isDigit() || c == '.' }, error = null) }
    fun onSellingChange(v: String) = updateForm { it.copy(sellingPrice = v.filter { c -> c.isDigit() || c == '.' }, error = null) }
    fun onSlNumChange(v: String) = updateForm { it.copy(slNum = v.filter(Char::isDigit), error = null) }
    fun onTrackStockChange(v: Boolean) = updateForm { it.copy(trackStock = v) }
    fun onActiveChange(v: Boolean) = updateForm { it.copy(active = v) }

    fun startEdit(product: ProductDto) {
        _state.update {
            it.copy(
                notice = null,
                actionError = null,
                form = ProductFormState(
                    editingId = product.id,
                    name = product.name,
                    category = product.category,
                    fuelTypeCode = product.fuelTypeCode.orEmpty(),
                    packSize = product.packSize.orEmpty(),
                    packUnit = product.packUnit.orEmpty(),
                    batch = product.batch.orEmpty(),
                    mrp = product.mrp.orEmpty(),
                    sellingPrice = product.sellingPrice.orEmpty(),
                    slNum = product.slNum?.toString().orEmpty(),
                    trackStock = product.trackStock,
                    active = product.active,
                ),
            )
        }
    }

    fun cancelEdit() = _state.update { it.copy(form = ProductFormState()) }

    fun submitForm() {
        val form = _state.value.form
        if (form.saving) return
        val name = form.name.trim()
        if (name.isBlank()) {
            updateForm { it.copy(error = "Enter a product name.") }
            return
        }
        if (form.isFuel && form.fuelTypeCode.isBlank()) {
            updateForm { it.copy(error = "Enter the fuel type code for a fuel product.") }
            return
        }

        val request = ProductRequest(
            name = name,
            category = form.category,
            fuelTypeCode = form.fuelTypeCode.trim().ifBlank { null },
            packSize = form.packSize.trim().ifBlank { null },
            packUnit = form.packUnit.trim().ifBlank { null },
            batch = form.batch.trim().ifBlank { null },
            mrp = form.mrp.trim().ifBlank { null },
            sellingPrice = form.sellingPrice.trim().ifBlank { null },
            slNum = form.slNum.trim().ifBlank { null },
            trackStock = form.trackStock,
            active = form.active,
        )

        updateForm { it.copy(saving = true, error = null) }
        _state.update { it.copy(notice = null, actionError = null) }
        viewModelScope.launch {
            when (val result = repository.saveProduct(form.editingId, request)) {
                is ApiResult.Success -> {
                    _state.update {
                        it.copy(
                            form = ProductFormState(),
                            notice = if (form.isEdit) "Product updated successfully." else "Product added successfully.",
                        )
                    }
                    load()
                }
                is ApiResult.Error -> updateForm { it.copy(saving = false, error = result.message) }
                is ApiResult.NetworkError -> updateForm { it.copy(saving = false, error = NETWORK_MESSAGE) }
            }
        }
    }

    // --- delete ---
    fun deleteProduct(id: Long) {
        if (_state.value.deletingId != null) return
        _state.update { it.copy(deletingId = id, actionError = null, notice = null) }
        viewModelScope.launch {
            when (val result = repository.deleteProduct(id)) {
                is ApiResult.Success -> {
                    _state.update {
                        it.copy(
                            deletingId = null,
                            notice = result.data.message ?: "Product removed successfully.",
                            form = if (it.form.editingId == id) ProductFormState() else it.form,
                        )
                    }
                    load()
                }
                is ApiResult.Error -> _state.update { it.copy(deletingId = null, actionError = result.message) }
                is ApiResult.NetworkError -> _state.update { it.copy(deletingId = null, actionError = NETWORK_MESSAGE) }
            }
        }
    }

    private fun updateForm(transform: (ProductFormState) -> ProductFormState) {
        _state.update { it.copy(form = transform(it.form)) }
    }
}
