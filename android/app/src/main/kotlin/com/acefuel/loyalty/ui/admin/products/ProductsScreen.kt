package com.acefuel.loyalty.ui.admin.products

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Inventory2
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import com.acefuel.loyalty.core.di.LocalContainer
import com.acefuel.loyalty.ui.designsystem.ActiveChip
import com.acefuel.loyalty.ui.designsystem.ConfirmDialog
import com.acefuel.loyalty.ui.designsystem.EmptyState
import com.acefuel.loyalty.ui.designsystem.FormField
import com.acefuel.loyalty.ui.designsystem.InlineErrorCard
import com.acefuel.loyalty.ui.designsystem.NayaraCard
import com.acefuel.loyalty.ui.designsystem.NayaraPullToRefresh
import com.acefuel.loyalty.ui.designsystem.NayaraSnackbarHost
import com.acefuel.loyalty.ui.designsystem.NayaraTopBar
import com.acefuel.loyalty.ui.designsystem.SkeletonCard
import com.acefuel.loyalty.ui.designsystem.SkeletonList
import com.acefuel.loyalty.ui.designsystem.rememberHaptics
import com.acefuel.loyalty.ui.designsystem.showError
import com.acefuel.loyalty.ui.designsystem.showSuccess
import com.acefuel.loyalty.ui.theme.NayaraButton
import com.acefuel.loyalty.ui.theme.NayaraOutlinedButton
import com.acefuel.loyalty.ui.theme.NayaraSpacing
import com.acefuel.loyalty.ui.theme.nayara

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AdminProductsScreen(onBack: () -> Unit) {
    val container = LocalContainer.current
    val repo = remember { ProductsRepository(container.retrofit.create(ProductsApi::class.java), container.json) }
    val vm: ProductsViewModel = viewModel(factory = viewModelFactory { initializer { ProductsViewModel(repo) } })
    val state by vm.state.collectAsStateWithLifecycle()

    val snackbar = remember { SnackbarHostState() }
    val haptics = rememberHaptics()
    val listState = rememberLazyListState()
    var pendingDelete by remember { mutableStateOf<ProductDto?>(null) }

    LaunchedEffect(state.notice) {
        val msg = state.notice ?: return@LaunchedEffect
        haptics.confirm(); snackbar.showSuccess(msg); vm.dismissNotice()
    }
    LaunchedEffect(state.actionError) {
        val msg = state.actionError ?: return@LaunchedEffect
        haptics.reject(); snackbar.showError(msg); vm.dismissActionError()
    }
    LaunchedEffect(state.error) {
        val msg = state.error ?: return@LaunchedEffect
        if (state.products.isNotEmpty()) { haptics.reject(); snackbar.showError(msg); vm.consumeError() }
    }
    LaunchedEffect(state.form.editingId) {
        if (state.form.editingId != null) listState.animateScrollToItem(0)
    }

    Scaffold(
        topBar = { NayaraTopBar(title = "Products", onBack = onBack) },
        snackbarHost = { NayaraSnackbarHost(snackbar) },
    ) { innerPadding ->
        when {
            state.loading && state.products.isEmpty() && state.error == null ->
                Column(
                    modifier = Modifier.fillMaxSize().padding(innerPadding).padding(NayaraSpacing.ScreenMargin),
                    verticalArrangement = Arrangement.spacedBy(NayaraSpacing.Md),
                ) {
                    SkeletonCard(lines = 3)
                    SkeletonList(count = 5, showAvatar = false)
                }

            else -> NayaraPullToRefresh(
                isRefreshing = state.refreshing,
                onRefresh = vm::refresh,
                modifier = Modifier.fillMaxSize().padding(innerPadding),
            ) {
                LazyColumn(
                    state = listState,
                    modifier = Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(NayaraSpacing.ScreenMargin),
                    verticalArrangement = Arrangement.spacedBy(NayaraSpacing.Md),
                ) {
                    item(key = "form") { ProductForm(state.form, vm) }

                    if (state.error != null && state.products.isEmpty()) {
                        item(key = "load-error") { InlineErrorCard(state.error!!, onRetry = vm::load) }
                    }

                    item(key = "list-header") {
                        Text("Catalog", style = MaterialTheme.typography.titleSmall, color = MaterialTheme.nayara.textSecondary)
                    }

                    if (state.products.isEmpty()) {
                        item(key = "empty") {
                            EmptyState(title = "No products yet", message = "Add one with the form above.", icon = Icons.Filled.Inventory2)
                        }
                    } else {
                        items(state.products, key = { "p-${it.id}" }) { product ->
                            ProductCard(
                                product = product,
                                editing = state.form.editingId == product.id,
                                deleting = state.deletingId == product.id,
                                onEdit = { vm.startEdit(product) },
                                onDelete = { pendingDelete = product },
                                modifier = Modifier.animateItem(),
                            )
                        }
                    }
                }
            }
        }
    }

    pendingDelete?.let { product ->
        ConfirmDialog(
            title = "Remove ${product.displayName}?",
            text = "Products referenced by settlements or stock can't be removed.",
            confirmLabel = "Remove",
            destructive = true,
            onConfirm = { pendingDelete = null; vm.deleteProduct(product.id) },
            onDismiss = { pendingDelete = null },
        )
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun ProductForm(form: ProductFormState, vm: ProductsViewModel) {
    val haptics = rememberHaptics()
    val decimal = KeyboardOptions(keyboardType = KeyboardType.Decimal)

    NayaraCard(modifier = Modifier.fillMaxWidth(), shape = MaterialTheme.shapes.large) {
        Column(Modifier.padding(NayaraSpacing.Lg), verticalArrangement = Arrangement.spacedBy(NayaraSpacing.Md)) {
            Text(
                if (form.isEdit) "Edit Product" else "Add Product",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.SemiBold,
            )

            FormField(value = form.name, onValueChange = vm::onNameChange, label = "Product Name", errors = form.error?.let(::listOf))

            Text("Category", style = MaterialTheme.typography.labelMedium, color = MaterialTheme.nayara.textSecondary)
            FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                PRODUCT_CATEGORIES.forEach { category ->
                    FilterChip(
                        selected = form.category == category,
                        onClick = { haptics.tick(); vm.onCategoryChange(category) },
                        label = { Text(category.replaceFirstChar { it.uppercase() }) },
                    )
                }
            }

            if (form.isFuel) {
                FormField(
                    value = form.fuelTypeCode,
                    onValueChange = vm::onFuelTypeChange,
                    label = "Fuel Type Code",
                    helper = "e.g. petrol or diesel — its selling price prices matching nozzles.",
                )
            } else {
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    FormField(value = form.packSize, onValueChange = vm::onPackSizeChange, label = "Pack Size", keyboardOptions = decimal, modifier = Modifier.weight(1f))
                    FormField(value = form.packUnit, onValueChange = vm::onPackUnitChange, label = "Unit (ml / L)", modifier = Modifier.weight(1f))
                }
            }

            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                FormField(value = form.mrp, onValueChange = vm::onMrpChange, label = "MRP", prefix = { Text("Rs. ") }, keyboardOptions = decimal, modifier = Modifier.weight(1f))
                FormField(value = form.sellingPrice, onValueChange = vm::onSellingChange, label = "Selling", prefix = { Text("Rs. ") }, keyboardOptions = decimal, modifier = Modifier.weight(1f))
            }

            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                FormField(value = form.batch, onValueChange = vm::onBatchChange, label = "Batch", modifier = Modifier.weight(1f))
                FormField(value = form.slNum, onValueChange = vm::onSlNumChange, label = "Sl. No.", keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number), modifier = Modifier.weight(1f))
            }

            ToggleRow("Track stock", "Include in opening/closing stock reconciliation.", form.trackStock) { haptics.tick(); vm.onTrackStockChange(it) }
            ToggleRow("Show in app", "Available for new selections.", form.active) { haptics.tick(); vm.onActiveChange(it) }

            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                if (form.isEdit) {
                    NayaraOutlinedButton(onClick = { vm.cancelEdit() }, enabled = !form.saving, modifier = Modifier.weight(1f)) { Text("Cancel") }
                }
                NayaraButton(
                    onClick = { vm.submitForm() },
                    loading = form.saving,
                    enabled = !form.saving && form.name.isNotBlank(),
                    modifier = Modifier.weight(1f),
                ) { Text(if (form.isEdit) "Save Changes" else "Add Product") }
            }
        }
    }
}

@Composable
private fun ToggleRow(title: String, subtitle: String, checked: Boolean, onChange: (Boolean) -> Unit) {
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
        Column(Modifier.weight(1f)) {
            Text(title, style = MaterialTheme.typography.bodyLarge)
            Text(subtitle, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.nayara.textSecondary)
        }
        Switch(checked = checked, onCheckedChange = onChange)
    }
}

@Composable
private fun ProductCard(
    product: ProductDto,
    editing: Boolean,
    deleting: Boolean,
    onEdit: () -> Unit,
    onDelete: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val body: @Composable ColumnScope.() -> Unit = {
        Column(Modifier.padding(NayaraSpacing.Lg), verticalArrangement = Arrangement.spacedBy(NayaraSpacing.Sm)) {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                Text(product.displayName.ifBlank { product.name }, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold, modifier = Modifier.weight(1f))
                ActiveChip(active = product.active)
            }
            Text(
                buildString {
                    append(product.category.replaceFirstChar { it.uppercase() })
                    product.sellingPrice?.let { append(" · Selling Rs. $it") }
                    product.mrp?.let { append(" · MRP Rs. $it") }
                    product.batch?.takeIf { it.isNotBlank() }?.let { append(" · Batch $it") }
                },
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.nayara.textSecondary,
            )
            Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                TextButton(onClick = onEdit, enabled = !deleting) { Text("Edit") }
                TextButton(onClick = onDelete, enabled = !deleting) {
                    if (deleting) CircularProgressIndicator(Modifier.size(16.dp), strokeWidth = 2.dp)
                    else Text("Delete", color = MaterialTheme.nayara.statusError)
                }
            }
        }
    }
    if (editing) {
        Card(modifier = modifier.fillMaxWidth(), colors = CardDefaults.cardColors(containerColor = MaterialTheme.nayara.bgSurfaceSunken), content = body)
    } else {
        NayaraCard(modifier = modifier.fillMaxWidth(), shape = MaterialTheme.shapes.large, content = body)
    }
}
