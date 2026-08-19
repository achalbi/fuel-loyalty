package com.acefuel.loyalty.ui.transaction

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.animateContentSize
import androidx.compose.animation.core.tween
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.shrinkVertically
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.selection.selectableGroup
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AccountBalanceWallet
import androidx.compose.material.icons.filled.CameraAlt
import androidx.compose.material.icons.filled.CreditCard
import androidx.compose.material.icons.filled.SearchOff
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.RadioButton
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.platform.LocalSoftwareKeyboardController
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.compose.LifecycleEventEffect
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import com.acefuel.loyalty.core.di.LocalContainer
import com.acefuel.loyalty.core.network.dto.CatalogResponse
import com.acefuel.loyalty.core.network.dto.NozzleDto
import com.acefuel.loyalty.ui.designsystem.ConfirmDialog
import com.acefuel.loyalty.ui.designsystem.EmptyState
import com.acefuel.loyalty.ui.designsystem.FormField
import com.acefuel.loyalty.ui.designsystem.InlineErrorCard
import com.acefuel.loyalty.ui.designsystem.NayaraBottomSheet
import com.acefuel.loyalty.ui.designsystem.NayaraCard
import com.acefuel.loyalty.ui.designsystem.NayaraSnackbarHost
import com.acefuel.loyalty.ui.designsystem.NayaraTopBar
import com.acefuel.loyalty.ui.designsystem.PointsPill
import com.acefuel.loyalty.ui.designsystem.SkeletonListItem
import com.acefuel.loyalty.ui.designsystem.SuccessOverlay
import com.acefuel.loyalty.ui.designsystem.rememberHaptics
import com.acefuel.loyalty.ui.designsystem.showError
import com.acefuel.loyalty.ui.theme.NayaraButton
import com.acefuel.loyalty.ui.theme.NayaraMotion
import com.acefuel.loyalty.ui.theme.NayaraOutlinedButton
import com.acefuel.loyalty.ui.theme.NayaraSpacing
import com.acefuel.loyalty.ui.theme.nayara
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TransactionScreen(
    onBack: () -> Unit,
    onViewCustomer: (Long) -> Unit,
    onScanPlate: () -> Unit = {},
    onSetupPump: () -> Unit = {},
    scannedPlate: String? = null,
) {
    val container = LocalContainer.current
    val viewModel: TransactionViewModel = viewModel(
        factory = viewModelFactory { initializer { TransactionViewModel(container.staffRepository) } },
    )
    val state by viewModel.state.collectAsStateWithLifecycle()
    val haptics = rememberHaptics()
    val snackbar = remember { SnackbarHostState() }
    val scope = rememberCoroutineScope()
    val keyboard = LocalSoftwareKeyboardController.current
    val focusManager = LocalFocusManager.current
    // Look Up / OK / Save all drop the cursor and close the keyboard so results
    // and the rest of the form aren't left hidden behind it. clearFocus() is what
    // removes the caret from the field; hide() closes the IME on its own too.
    val dismissKeyboard = {
        keyboard?.hide()
        focusManager.clearFocus()
    }
    // Plain remember (not saveable): the confirm summary reads ViewModel state,
    // which resets on process death — a restored dialog would show empty fields.
    var showConfirm by remember { mutableStateOf(false) }

    // Returning from the My Pump setup screen: re-check readiness so the nozzle
    // section unblocks without the user having to leave and re-open the form.
    LifecycleEventEffect(Lifecycle.Event.ON_RESUME) { viewModel.refreshPumpIfNeeded() }

    // A plate returned from the scanner flows in here: switch to vehicle mode,
    // fill the number, and run the lookup.
    LaunchedEffect(scannedPlate) {
        if (!scannedPlate.isNullOrBlank()) {
            viewModel.setMode(MODE_VEHICLE)
            viewModel.onVehicleNumberChange(scannedPlate)
            viewModel.lookup()
        }
    }

    // Create failures are transient: snackbar + reject haptic, form kept intact.
    // Consuming the error changes this effect's key and cancels it, so the
    // snackbar runs in the longer-lived composition scope.
    LaunchedEffect(state.createError) {
        val message = state.createError ?: return@LaunchedEffect
        haptics.reject()
        viewModel.consumeCreateError()
        scope.launch { snackbar.showError(message) }
    }

    Box(Modifier.fillMaxSize()) {
        Scaffold(
            topBar = { NayaraTopBar(title = "New Transaction", onBack = onBack) },
            snackbarHost = { NayaraSnackbarHost(snackbar) },
        ) { innerPadding ->
            val result = state.result
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(innerPadding)
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = NayaraSpacing.ScreenMargin, vertical = NayaraSpacing.Lg)
                    .animateContentSize(tween(NayaraMotion.Base, easing = NayaraMotion.Standard)),
            ) {
                if (result != null) {
                    SuccessCard(
                        message = result.message,
                        onViewCustomer = { onViewCustomer(result.customer.id) },
                        onAnother = { viewModel.startAnother() },
                    )
                    return@Column
                }

                // Step 1 — Find (mode tabs + lookup)
                StepHeader("1. Find customer")
                Spacer(Modifier.height(NayaraSpacing.Sm))
                SingleChoiceSegmentedButtonRow(modifier = Modifier.fillMaxWidth()) {
                    SegmentedButton(
                        selected = state.lookupMode == MODE_VEHICLE,
                        onClick = { haptics.tick(); viewModel.setMode(MODE_VEHICLE) },
                        shape = SegmentedButtonDefaults.itemShape(index = 0, count = 2),
                    ) {
                        Text("Vehicle Number")
                    }
                    SegmentedButton(
                        selected = state.lookupMode == MODE_PHONE,
                        onClick = { haptics.tick(); viewModel.setMode(MODE_PHONE) },
                        shape = SegmentedButtonDefaults.itemShape(index = 1, count = 2),
                    ) {
                        Text("Phone Number")
                    }
                }
                Spacer(Modifier.height(NayaraSpacing.Md))

                val canLookup = !state.lookupLoading && if (state.lookupMode == MODE_VEHICLE) {
                    state.vehicleNumber.length >= 6
                } else {
                    state.phoneNumber.length == 10
                }
                Row(verticalAlignment = Alignment.Bottom) {
                    if (state.lookupMode == MODE_VEHICLE) {
                        FormField(
                            value = state.vehicleNumber,
                            onValueChange = viewModel::onVehicleNumberChange,
                            label = "Vehicle number",
                            keyboardOptions = KeyboardOptions(imeAction = ImeAction.Search),
                            keyboardActions = KeyboardActions(onSearch = { if (canLookup) { dismissKeyboard(); viewModel.lookup() } }),
                            trailingIcon = {
                                IconButton(onClick = onScanPlate) {
                                    Icon(Icons.Filled.CameraAlt, contentDescription = "Scan plate")
                                }
                            },
                            modifier = Modifier.weight(1f),
                        )
                    } else {
                        FormField(
                            value = state.phoneNumber,
                            onValueChange = viewModel::onPhoneNumberChange,
                            label = "Phone number",
                            prefix = { Text("+91 ") },
                            keyboardOptions = KeyboardOptions(
                                keyboardType = KeyboardType.Phone,
                                imeAction = ImeAction.Search,
                            ),
                            keyboardActions = KeyboardActions(onSearch = { if (canLookup) { dismissKeyboard(); viewModel.lookup() } }),
                            modifier = Modifier.weight(1f),
                        )
                    }
                    Spacer(Modifier.width(NayaraSpacing.Md))
                    // OutlinedTextField reserves 8dp above its 56dp box for the floating
                    // label, so the row is 64dp: bottom-align and match the box height to
                    // line both edges up. Centering instead would sit the button 4dp high.
                    NayaraButton(
                        onClick = { dismissKeyboard(); viewModel.lookup() },
                        enabled = canLookup,
                        loading = state.lookupLoading,
                        modifier = Modifier.height(56.dp),
                    ) {
                        Text("Look Up")
                    }
                }

                // Cache the last message so the card keeps its text while animating out.
                var lastLookupError by remember { mutableStateOf("") }
                state.lookupError?.let { lastLookupError = it }
                AnimatedVisibility(
                    visible = state.lookupError != null,
                    enter = stepEnter(),
                    exit = stepExit(),
                ) {
                    Column {
                        Spacer(Modifier.height(NayaraSpacing.Md))
                        InlineErrorCard(lastLookupError, onRetry = { viewModel.lookup() })
                    }
                }

                // Lookup matched nobody: offer the new-customer path instead of dead-ending.
                AnimatedVisibility(
                    visible = state.vehicleUnmatched,
                    enter = stepEnter(),
                    exit = stepExit(),
                ) {
                    EmptyState(
                        title = "No customer found",
                        message = "No customer is registered for this vehicle number. " +
                            "Add the customer to record this sale.",
                        icon = Icons.Filled.SearchOff,
                        actionLabel = "Add Customer",
                        onAction = { viewModel.startRegistration() },
                    )
                }

                // Step 2 — Review / select
                AnimatedVisibility(
                    visible = state.lookupMode == MODE_VEHICLE && state.matches.isNotEmpty(),
                    enter = stepEnter(),
                    exit = stepExit(),
                ) {
                    Column {
                        Spacer(Modifier.height(NayaraSpacing.Xl))
                        StepHeader("2. Matching customer")
                        Spacer(Modifier.height(NayaraSpacing.Sm))
                        Column(verticalArrangement = Arrangement.spacedBy(NayaraSpacing.Md)) {
                            state.matches.forEachIndexed { index, match ->
                                SelectableRow(
                                    selected = state.selectedMatchIndex == index,
                                    onSelect = { haptics.tick(); viewModel.selectMatch(index) },
                                    title = match.customer.name ?: "Customer",
                                    subtitle = "+91 ${match.customer.phoneNumber} · ${match.customer.totalPoints} pts · ${match.fuelType}",
                                )
                            }
                        }
                    }
                }

                val phoneCustomer = state.phoneCustomer
                AnimatedVisibility(
                    visible = state.lookupMode == MODE_PHONE && phoneCustomer != null,
                    enter = stepEnter(),
                    exit = stepExit(),
                ) {
                    Column {
                        if (phoneCustomer != null) {
                            Spacer(Modifier.height(NayaraSpacing.Xl))
                            StepHeader("2. Select a vehicle")
                            Spacer(Modifier.height(NayaraSpacing.Sm))
                            NayaraCard(modifier = Modifier.fillMaxWidth()) {
                                Row(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .padding(NayaraSpacing.Lg),
                                    horizontalArrangement = Arrangement.SpaceBetween,
                                    verticalAlignment = Alignment.CenterVertically,
                                ) {
                                    Text(
                                        phoneCustomer.name ?: "Customer",
                                        style = MaterialTheme.typography.titleMedium,
                                        fontWeight = FontWeight.SemiBold,
                                    )
                                    PointsPill(points = phoneCustomer.totalPoints)
                                }
                            }
                            if (phoneCustomer.vehicles.isEmpty()) {
                                Spacer(Modifier.height(NayaraSpacing.Md))
                                Text("No vehicles on file for this customer.", color = MaterialTheme.colorScheme.error)
                            } else {
                                Spacer(Modifier.height(NayaraSpacing.Md))
                                Column(verticalArrangement = Arrangement.spacedBy(NayaraSpacing.Md)) {
                                    phoneCustomer.vehicles.forEach { v ->
                                        SelectableRow(
                                            selected = state.selectedVehicleId == v.id,
                                            onSelect = { haptics.tick(); viewModel.selectVehicle(v.id) },
                                            title = v.vehicleNumber,
                                            subtitle = "${v.fuelType} · ${v.vehicleKind}",
                                        )
                                    }
                                }
                            }
                        }
                    }
                }

                // Inactive-customer blocker
                if (state.selectedCustomer != null && !state.customerActive) {
                    Spacer(Modifier.height(NayaraSpacing.Md))
                    Blocker("This customer is inactive. Activate the customer before recording a transaction.")
                }

                // Step 3 — Fuel details
                AnimatedVisibility(
                    visible = state.selectedVehicle != null && state.customerActive,
                    enter = stepEnter(),
                    exit = stepExit(),
                ) {
                    Column {
                        Spacer(Modifier.height(NayaraSpacing.Xl))
                        StepHeader("3. Fuel details")
                        Spacer(Modifier.height(NayaraSpacing.Sm))
                        val amountInvalid = state.fuelAmount.isNotBlank() &&
                            (state.fuelAmount.toDoubleOrNull() ?: 0.0) <= 0.0
                        // Field + OK share a row like the lookup step. Top-aligned so the
                        // button sits against the input box while the helper/error line
                        // flows below it (that supporting text lives inside the field).
                        Row(verticalAlignment = Alignment.Top) {
                            FormField(
                                value = state.fuelAmount,
                                onValueChange = viewModel::onFuelAmountChange,
                                label = "Fuel amount",
                                prefix = { Text("₹ ") },
                                errors = if (amountInvalid) listOf("Enter a valid amount.") else null,
                                // Reward rates aren't exposed by the lookup APIs, so the
                                // earned points come from the server on save.
                                helper = "Points are calculated when the transaction is saved.",
                                keyboardOptions = KeyboardOptions(
                                    keyboardType = KeyboardType.Decimal,
                                    imeAction = ImeAction.Done,
                                ),
                                // OK/Done always closes the keyboard and drops the caret; if
                                // the rest of the form is already complete it opens the confirm.
                                keyboardActions = KeyboardActions(onDone = {
                                    dismissKeyboard()
                                    if (state.canSave) showConfirm = true
                                }),
                                modifier = Modifier.weight(1f),
                            )
                            Spacer(Modifier.width(NayaraSpacing.Md))
                            // Explicit dismiss affordance: the decimal keyboard covers the
                            // payment / nozzle / save controls below, so give the attendant a
                            // visible way to close it once the amount is typed.
                            // Top padding offsets the field's floating-label overhang so the
                            // button seats against the input box instead of riding above it.
                            NayaraButton(
                                onClick = { dismissKeyboard() },
                                enabled = state.fuelAmount.isNotBlank(),
                                modifier = Modifier.padding(top = NayaraSpacing.Sm),
                            ) {
                                Text("OK")
                            }
                        }
                        Spacer(Modifier.height(NayaraSpacing.Md))
                        // Optional: a counter discount comes off the fuel amount, so
                        // points are earned on what the customer actually paid.
                        FormField(
                            value = state.discountAmount,
                            onValueChange = viewModel::onDiscountAmountChange,
                            label = "Discount (optional)",
                            prefix = { Text("₹ ") },
                            errors = if (!state.discountValid) listOf("Discount must be less than the fuel amount.") else null,
                            keyboardOptions = KeyboardOptions(
                                keyboardType = KeyboardType.Decimal,
                                imeAction = ImeAction.Done,
                            ),
                            keyboardActions = KeyboardActions(onDone = {
                                dismissKeyboard()
                                if (state.canSave) showConfirm = true
                            }),
                        )
                        Spacer(Modifier.height(NayaraSpacing.Md))
                        Text("Payment", style = MaterialTheme.typography.labelLarge)
                        Spacer(Modifier.height(NayaraSpacing.Sm))
                        // Compact chip-sized buttons (same footprint as the old chips) but
                        // the selected mode fills with the brand color so the choice still
                        // reads at a glance. selectableGroup() ties them into one a11y radio group.
                        Row(
                            horizontalArrangement = Arrangement.spacedBy(NayaraSpacing.Sm),
                            modifier = Modifier.selectableGroup(),
                        ) {
                            PaymentOption(
                                selected = state.paymentMode == "cash",
                                onSelect = { haptics.tick(); viewModel.setPayment("cash") },
                                icon = Icons.Filled.AccountBalanceWallet,
                                label = "Cash",
                            )
                            PaymentOption(
                                selected = state.paymentMode == "credit",
                                onSelect = { haptics.tick(); viewModel.setPayment("credit") },
                                icon = Icons.Filled.CreditCard,
                                label = "Credit",
                            )
                        }

                        Spacer(Modifier.height(NayaraSpacing.Md))
                        NozzleSection(
                            state = state,
                            onRetryPump = viewModel::loadMyPump,
                            onSetupPump = onSetupPump,
                            onSelect = { haptics.tick(); viewModel.selectNozzle(it) },
                        )

                        Spacer(Modifier.height(NayaraSpacing.Lg))
                        NayaraButton(
                            onClick = { dismissKeyboard(); showConfirm = true },
                            enabled = state.canSave,
                            loading = state.creating,
                            modifier = Modifier.fillMaxWidth(),
                        ) {
                            Text("Save Transaction")
                        }
                    }
                }
            }
        }

        if (showConfirm) {
            ConfirmDialog(
                title = "Save transaction?",
                text = buildString {
                    append("Vehicle: ${state.selectedVehicleNumber ?: "—"}")
                    state.selectedFuelTypeLabel?.let { append("\nFuel: $it") }
                    append("\nAmount: ₹${state.fuelAmount}")
                    state.discountAmount.takeIf { it.isNotBlank() }?.let { append("\nDiscount: ₹$it") }
                    append("\nPayment: ${state.paymentMode.replaceFirstChar(Char::uppercase)}")
                },
                confirmLabel = "Save",
                onConfirm = {
                    showConfirm = false
                    viewModel.create()
                },
                onDismiss = { showConfirm = false },
            )
        }

        state.registerForm?.let { form ->
            RegisterCustomerSheet(
                form = form,
                catalog = state.catalog,
                isCommercial = state.registrationIsCommercial,
                onName = viewModel::onRegisterName,
                onPhone = viewModel::onRegisterPhone,
                onVehicleNumber = viewModel::onRegisterVehicleNumber,
                onFuelType = { haptics.tick(); viewModel.onRegisterFuelType(it) },
                onVehicleKind = { haptics.tick(); viewModel.onRegisterVehicleKind(it) },
                onCompanyName = viewModel::onRegisterCompanyName,
                onContactName = viewModel::onRegisterContactName,
                onContactPhone = viewModel::onRegisterContactPhone,
                onAddress = viewModel::onRegisterAddress,
                onNotes = viewModel::onRegisterNotes,
                onSubmit = { dismissKeyboard(); viewModel.submitRegistration() },
                onDismiss = viewModel::cancelRegistration,
            )
        }

        // The earn ceremony — overlays everything, then reveals the summary card.
        val ceremonyResult = state.result
        SuccessOverlay(
            visible = state.showCeremony,
            title = if (ceremonyResult?.rewardsPaused == true) "Transaction saved" else "Points awarded",
            subtitle = ceremonyResult?.let {
                if (it.rewardsPaused) it.message else "+${it.pointsEarned} pts · Balance ${it.newTotal}"
            },
            onFinished = viewModel::ceremonyFinished,
        )
    }
}

private fun stepEnter() = fadeIn(tween(NayaraMotion.Base)) +
    expandVertically(tween(NayaraMotion.Base, easing = NayaraMotion.Enter))

private fun stepExit() = fadeOut(tween(NayaraMotion.Fast)) +
    shrinkVertically(tween(NayaraMotion.Fast, easing = NayaraMotion.Exit))

@Composable
private fun NozzleSection(
    state: TxnUiState,
    onRetryPump: () -> Unit,
    onSetupPump: () -> Unit,
    onSelect: (Long) -> Unit,
) {
    Text("Nozzle", style = MaterialTheme.typography.labelLarge)
    Spacer(Modifier.height(NayaraSpacing.Sm))
    when {
        state.myPumpLoading -> SkeletonListItem(showAvatar = false)
        state.myPumpError != null -> InlineErrorCard(state.myPumpError, onRetry = onRetryPump)
        !state.pumpReady -> {
            Blocker("Set up My Pump with at least one active nozzle before recording transactions.")
            Spacer(Modifier.height(NayaraSpacing.Md))
            NayaraButton(onClick = onSetupPump, modifier = Modifier.fillMaxWidth()) {
                Text("Set up My Pump")
            }
        }
        else -> {
            val options = state.nozzleOptions()
            if (options.isEmpty()) {
                val fuel = state.selectedFuelTypeLabel
                Blocker(
                    if (fuel != null) {
                        "Your pump has no active $fuel nozzle assigned. Update My Pump to add one " +
                            "(or pick a pump that has a $fuel nozzle)."
                    } else {
                        "No nozzle is assigned to your pump for this vehicle's fuel type."
                    },
                )
                Spacer(Modifier.height(NayaraSpacing.Md))
                NayaraButton(onClick = onSetupPump, modifier = Modifier.fillMaxWidth()) {
                    Text("Change My Pump")
                }
            } else {
                Column(verticalArrangement = Arrangement.spacedBy(NayaraSpacing.Md)) {
                    options.forEach { nozzle: NozzleDto ->
                        SelectableRow(
                            selected = state.selectedNozzleId == nozzle.id,
                            onSelect = { onSelect(nozzle.id) },
                            title = nozzle.displayName,
                            subtitle = nozzle.fuelType ?: nozzle.fuelTypeCode.orEmpty(),
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun StepHeader(text: String) {
    // Quiet section-label look (DESIGN_BRIEF §5): the content cards carry emphasis.
    Text(
        text,
        style = MaterialTheme.typography.titleSmall,
        fontWeight = FontWeight.SemiBold,
        color = MaterialTheme.nayara.textSecondary,
    )
}

@Composable
private fun SelectableRow(selected: Boolean, onSelect: () -> Unit, title: String, subtitle: String) {
    // Soft-shadow card on the grey canvas; selection shows as a brand ring plus
    // the filled radio. The `.selectable` modifier keeps the exact RadioButton
    // semantics (single accessibility target) rather than a plain button.
    val selectionRing = if (selected) {
        Modifier.border(1.5.dp, MaterialTheme.nayara.actionPrimary, MaterialTheme.shapes.large)
    } else {
        Modifier
    }
    NayaraCard(
        modifier = Modifier
            .fillMaxWidth()
            .selectable(selected = selected, role = Role.RadioButton, onClick = onSelect)
            .then(selectionRing),
    ) {
        Row(Modifier.padding(NayaraSpacing.Lg), verticalAlignment = Alignment.CenterVertically) {
            // onClick = null: the row is the single accessibility target.
            RadioButton(selected = selected, onClick = null)
            Spacer(Modifier.width(NayaraSpacing.Md))
            Column(verticalArrangement = Arrangement.spacedBy(NayaraSpacing.Xxs)) {
                Text(title, fontWeight = FontWeight.SemiBold)
                Text(subtitle, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.nayara.textSecondary)
            }
        }
    }
}

@Composable
private fun PaymentOption(
    selected: Boolean,
    onSelect: () -> Unit,
    icon: ImageVector,
    label: String,
    modifier: Modifier = Modifier,
) {
    // Compact payment button, chip-sized. Selected = filled primary card with
    // white content; unselected = outlined white card (DESIGN_BRIEF §5.5: selector
    // state reads as filled vs outlined). Selected fill uses colorScheme.primary
    // — the same token the screen's NayaraButtons use — so it stays in step with
    // an admin brand override instead of a hardcoded navy. Card's contentColor
    // drives both the icon tint and the label, so they flip together. Same
    // RadioButton semantics as SelectableRow — the button is the a11y target.
    val nayara = MaterialTheme.nayara
    val scheme = MaterialTheme.colorScheme
    Card(
        shape = MaterialTheme.shapes.large,
        colors = CardDefaults.cardColors(
            containerColor = if (selected) scheme.primary else nayara.bgSurface,
            contentColor = if (selected) scheme.onPrimary else nayara.textPrimary,
        ),
        border = if (selected) null else BorderStroke(1.dp, nayara.borderDefault),
        // NayaraCard's 2dp resting lift in both states; the fill carries selection.
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp),
        modifier = modifier.selectable(selected = selected, role = Role.RadioButton, onClick = onSelect),
    ) {
        Row(
            modifier = Modifier.padding(horizontal = NayaraSpacing.Lg, vertical = NayaraSpacing.Sm),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(NayaraSpacing.Xs),
        ) {
            Icon(icon, contentDescription = null, modifier = Modifier.size(18.dp))
            Text(label, style = MaterialTheme.typography.labelLarge, fontWeight = FontWeight.SemiBold)
        }
    }
}

@Composable
private fun Blocker(message: String) {
    // Prerequisite not met — warning tokens, not error (DESIGN_BRIEF §5.5).
    Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.nayara.statusWarningContainer), modifier = Modifier.fillMaxWidth()) {
        Text(message, Modifier.padding(14.dp), color = MaterialTheme.nayara.statusOnWarningContainer)
    }
}

@Composable
private fun SuccessCard(message: String, onViewCustomer: () -> Unit, onAnother: () -> Unit) {
    // Earn moment — success/green tokens (DESIGN_BRIEF principle 4).
    Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.nayara.statusSuccessContainer), modifier = Modifier.fillMaxWidth()) {
        Column(Modifier.padding(20.dp)) {
            Text("Transaction saved", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold, color = MaterialTheme.nayara.statusOnSuccessContainer)
            Spacer(Modifier.height(8.dp))
            Text(message, color = MaterialTheme.nayara.statusOnSuccessContainer)
        }
    }
    Spacer(Modifier.height(16.dp))
    NayaraButton(onClick = onViewCustomer, modifier = Modifier.fillMaxWidth()) { Text("View Customer") }
    Spacer(Modifier.height(8.dp))
    NayaraOutlinedButton(onClick = onAnother, modifier = Modifier.fillMaxWidth()) { Text("New Transaction") }
}

/**
 * Inline "add customer" sheet for an unregistered plate. Collects the same fields
 * as the web registration modal — customer name/phone, the vehicle, its fuel type
 * and kind, plus commercial details when the kind needs them — then hands back to
 * the transaction flow via the ViewModel (the new customer becomes the match).
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun RegisterCustomerSheet(
    form: RegisterFormState,
    catalog: CatalogResponse?,
    isCommercial: Boolean,
    onName: (String) -> Unit,
    onPhone: (String) -> Unit,
    onVehicleNumber: (String) -> Unit,
    onFuelType: (String) -> Unit,
    onVehicleKind: (String) -> Unit,
    onCompanyName: (String) -> Unit,
    onContactName: (String) -> Unit,
    onContactPhone: (String) -> Unit,
    onAddress: (String) -> Unit,
    onNotes: (String) -> Unit,
    onSubmit: () -> Unit,
    onDismiss: () -> Unit,
) {
    NayaraBottomSheet(
        onDismissRequest = onDismiss,
        title = "Add customer",
        subtitle = "No customer is registered for this plate. Add them to record this sale.",
    ) {
        Column(
            modifier = Modifier.verticalScroll(rememberScrollState()),
            verticalArrangement = Arrangement.spacedBy(NayaraSpacing.Md),
        ) {
            FormField(
                value = form.name,
                onValueChange = onName,
                label = "Full name",
                keyboardOptions = KeyboardOptions(
                    capitalization = KeyboardCapitalization.Words,
                    imeAction = ImeAction.Next,
                ),
            )
            FormField(
                value = form.phoneNumber,
                onValueChange = onPhone,
                label = "Phone number",
                prefix = { Text("+91 ") },
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Phone, imeAction = ImeAction.Next),
            )
            FormField(
                value = form.vehicleNumber,
                onValueChange = onVehicleNumber,
                label = "Vehicle number",
                keyboardOptions = KeyboardOptions(
                    capitalization = KeyboardCapitalization.Characters,
                    imeAction = ImeAction.Next,
                ),
            )

            Text("Fuel type", style = MaterialTheme.typography.labelLarge)
            OptionChips(
                options = catalog?.fuelTypes?.map { it.code to it.label } ?: emptyList(),
                selected = form.fuelTypeCode,
                loading = catalog == null,
                onSelect = onFuelType,
            )

            Text("Vehicle type", style = MaterialTheme.typography.labelLarge)
            OptionChips(
                options = catalog?.vehicleKinds?.map { it.code to it.label } ?: emptyList(),
                selected = form.vehicleKindCode,
                loading = catalog == null,
                onSelect = onVehicleKind,
            )

            if (isCommercial) {
                FormField(
                    value = form.companyName,
                    onValueChange = onCompanyName,
                    label = "Company name (optional)",
                    keyboardOptions = KeyboardOptions(
                        capitalization = KeyboardCapitalization.Words,
                        imeAction = ImeAction.Next,
                    ),
                )
                FormField(
                    value = form.contactName,
                    onValueChange = onContactName,
                    label = "Owner / manager name (optional)",
                    keyboardOptions = KeyboardOptions(
                        capitalization = KeyboardCapitalization.Words,
                        imeAction = ImeAction.Next,
                    ),
                )
                FormField(
                    value = form.contactPhone,
                    onValueChange = onContactPhone,
                    label = "Owner / manager phone (optional)",
                    prefix = { Text("+91 ") },
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Phone, imeAction = ImeAction.Next),
                )
                FormField(
                    value = form.address,
                    onValueChange = onAddress,
                    label = "Address (optional)",
                    keyboardOptions = KeyboardOptions(
                        capitalization = KeyboardCapitalization.Sentences,
                        imeAction = ImeAction.Next,
                    ),
                )
                FormField(
                    value = form.notes,
                    onValueChange = onNotes,
                    label = "Notes (optional)",
                    keyboardOptions = KeyboardOptions(
                        capitalization = KeyboardCapitalization.Sentences,
                        imeAction = ImeAction.Done,
                    ),
                )
            }

            form.error?.let {
                Text(it, color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodySmall)
            }

            Spacer(Modifier.height(NayaraSpacing.Xs))
            NayaraButton(
                onClick = onSubmit,
                enabled = !form.submitting,
                loading = form.submitting,
                modifier = Modifier.fillMaxWidth(),
            ) {
                Text("Register & Continue")
            }
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun OptionChips(
    options: List<Pair<String, String>>,
    selected: String?,
    loading: Boolean,
    onSelect: (String) -> Unit,
) {
    if (options.isEmpty()) {
        Text(
            if (loading) "Loading options…" else "No options available.",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.nayara.textSecondary,
        )
        return
    }
    FlowRow(horizontalArrangement = Arrangement.spacedBy(NayaraSpacing.Sm)) {
        options.forEach { (code, label) ->
            FilterChip(
                selected = selected == code,
                onClick = { onSelect(code) },
                label = { Text(label) },
            )
        }
    }
}
