package com.acefuel.loyalty.ui.redeem

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.tween
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ExposedDropdownMenuBox
import androidx.compose.material3.ExposedDropdownMenuDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.MenuAnchorType
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.SnackbarResult
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import com.acefuel.loyalty.core.di.LocalContainer
import com.acefuel.loyalty.core.network.dto.StaffCustomerDto
import com.acefuel.loyalty.ui.designsystem.ConfirmDialog
import com.acefuel.loyalty.ui.designsystem.FormField
import com.acefuel.loyalty.ui.designsystem.InlineErrorCard
import com.acefuel.loyalty.ui.designsystem.NayaraCard
import com.acefuel.loyalty.ui.designsystem.NayaraSnackbarHost
import com.acefuel.loyalty.ui.designsystem.NayaraTopBar
import com.acefuel.loyalty.ui.designsystem.SkeletonCard
import com.acefuel.loyalty.ui.designsystem.SuccessOverlay
import com.acefuel.loyalty.ui.designsystem.rememberHaptics
import com.acefuel.loyalty.ui.designsystem.showError
import com.acefuel.loyalty.ui.theme.NayaraButton
import com.acefuel.loyalty.ui.theme.NayaraMotion
import com.acefuel.loyalty.ui.theme.NayaraNumerals
import com.acefuel.loyalty.ui.theme.NayaraSpacing
import com.acefuel.loyalty.ui.theme.nayara

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun RedeemScreen(onBack: (() -> Unit)? = null) {
    val container = LocalContainer.current
    val viewModel: RedeemViewModel = viewModel(
        factory = viewModelFactory { initializer { RedeemViewModel(container.staffRepository) } },
    )
    val state by viewModel.state.collectAsStateWithLifecycle()
    var phone by rememberSaveable { mutableStateOf("") }
    // Plain remember (not saveable): the confirm summary reads ViewModel state,
    // which resets on process death — a restored dialog could open uninvited.
    var showConfirm by remember { mutableStateOf(false) }
    val snackbar = remember { SnackbarHostState() }
    val haptics = rememberHaptics()

    // Redeem failures surface as a snackbar (form state is kept for retry).
    LaunchedEffect(state.redeemError) {
        val message = state.redeemError ?: return@LaunchedEffect
        haptics.reject()
        val result = snackbar.showError(message, actionLabel = if (state.redeemRetryable) "Retry" else null)
        viewModel.consumeRedeemError()
        if (result == SnackbarResult.ActionPerformed) viewModel.redeem()
    }
    LaunchedEffect(state.lookupMessage) {
        if (state.lookupMessage != null) haptics.reject()
    }

    // Keep the last message so the overlay text survives its exit animation.
    var lastSuccessMessage by remember { mutableStateOf<String?>(null) }
    state.successMessage?.let { lastSuccessMessage = it }

    Box(Modifier.fillMaxSize()) {
        Scaffold(
            topBar = { NayaraTopBar(title = "Redeem Points", onBack = onBack) },
            snackbarHost = { NayaraSnackbarHost(snackbar) },
        ) { innerPadding ->
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(innerPadding)
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = NayaraSpacing.ScreenMargin, vertical = NayaraSpacing.Lg),
                verticalArrangement = Arrangement.spacedBy(NayaraSpacing.Md),
            ) {
                Row(verticalAlignment = Alignment.Bottom) {
                    FormField(
                        value = phone,
                        onValueChange = { phone = it.filter(Char::isDigit).take(10) },
                        label = "Phone number",
                        prefix = { Text("+91 ") },
                        keyboardOptions = KeyboardOptions(
                            keyboardType = KeyboardType.Phone,
                            imeAction = ImeAction.Search,
                        ),
                        keyboardActions = KeyboardActions(onSearch = {
                            if (phone.length == 10) viewModel.lookup(phone)
                        }),
                        modifier = Modifier.weight(1f),
                    )
                    Spacer(Modifier.width(NayaraSpacing.Md))
                    NayaraButton(
                        onClick = { viewModel.lookup(phone) },
                        enabled = phone.length == 10,
                        loading = state.lookupLoading,
                    ) {
                        Text("Look Up")
                    }
                }

                state.lookupMessage?.let {
                    InlineErrorCard(
                        message = it,
                        onRetry = if (state.lookupRetryable && phone.length == 10) ({ viewModel.lookup(phone) }) else null,
                    )
                }

                if (state.lookupLoading) {
                    SkeletonCard(lines = 4)
                }

                val customer = state.customer
                AnimatedVisibility(
                    visible = customer != null,
                    enter = fadeIn(tween(NayaraMotion.Base)) +
                        expandVertically(tween(NayaraMotion.Base, easing = NayaraMotion.Enter)),
                ) {
                    val c = customer ?: return@AnimatedVisibility
                    Column {
                        CustomerCard(c)

                        Spacer(Modifier.height(NayaraSpacing.Lg))
                        when {
                            c.rewardsPaused -> BlockedNote(
                                "Rewards are paused for this customer. Resume rewards to redeem points.",
                            )
                            state.pointOptions.isEmpty() -> BlockedNote(
                                "This customer does not have enough redeemable points yet. " +
                                    "Minimum redemption for this customer is ${c.minimumRedeemablePoints} points.",
                            )
                            else -> RedeemForm(state, c, viewModel, onSubmit = { showConfirm = true })
                        }
                    }
                }
            }
        }

        SuccessOverlay(
            visible = state.successMessage != null,
            title = "Points redeemed",
            subtitle = lastSuccessMessage,
            onFinished = viewModel::consumeSuccessMessage,
        )
    }

    val confirmCustomer = state.customer
    val confirmPoints = state.selectedPoints
    if (showConfirm && confirmCustomer != null && confirmPoints != null) {
        val cash = confirmCustomer.cashValuePerPoint
        val valueText = if (cash != null && cash > 0) " (₹%.2f)".format(confirmPoints * cash) else ""
        ConfirmDialog(
            title = "Redeem points?",
            text = "Redeem $confirmPoints points$valueText for " +
                "${confirmCustomer.name ?: "this customer"}? This cannot be undone.",
            confirmLabel = "Redeem",
            onConfirm = {
                showConfirm = false
                viewModel.redeem()
            },
            onDismiss = { showConfirm = false },
        )
    }
}

@Composable
private fun CustomerCard(customer: StaffCustomerDto) {
    NayaraCard(modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(NayaraSpacing.CardPadding)) {
            Text(customer.name ?: "Customer", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
            Text(
                "${customer.statusLabel} · ${customer.rewardsStatusLabel}",
                style = MaterialTheme.typography.labelMedium,
                color = MaterialTheme.nayara.textSecondary,
            )
            customer.phoneNumber?.let {
                Text(
                    "+91 $it",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.nayara.textSecondary,
                )
            }
            Spacer(Modifier.height(NayaraSpacing.Md))
            Text(
                "${customer.totalPoints}",
                style = NayaraNumerals.Large,
                color = MaterialTheme.nayara.textPrimary,
            )
            Text(
                "Available points",
                style = MaterialTheme.typography.labelMedium,
                color = MaterialTheme.nayara.textSecondary,
            )
            Spacer(Modifier.height(NayaraSpacing.Md))
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                Stat("Minimum", "${customer.minimumRedeemablePoints}")
                Stat("Max redeemable", "${customer.maxRedeemablePoints}")
                Stat("Vehicles", "${customer.vehicles.size}")
            }
            customer.maxRedeemableCashReward?.let {
                Spacer(Modifier.height(NayaraSpacing.Sm))
                Text(
                    "Max cash reward: ₹%.2f".format(it),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.nayara.textSecondary,
                )
            }
        }
    }
}

@Composable
private fun Stat(label: String, value: String) {
    Column {
        Text(value, style = NayaraNumerals.Default, color = MaterialTheme.nayara.textPrimary)
        Text(label, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.nayara.textSecondary)
    }
}

@Composable
private fun BlockedNote(message: String) {
    // Not an error — the customer simply is not eligible yet (warning tokens).
    Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.nayara.statusWarningContainer)) {
        Text(message, modifier = Modifier.padding(16.dp), color = MaterialTheme.nayara.statusOnWarningContainer)
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun RedeemForm(
    state: RedeemUiState,
    customer: StaffCustomerDto,
    viewModel: RedeemViewModel,
    onSubmit: () -> Unit,
) {
    var expanded by remember { mutableStateOf(false) }
    val options = state.pointOptions
    val haptics = rememberHaptics()

    fun label(points: Int): String {
        val cash = customer.cashValuePerPoint
        return if (cash != null && cash > 0) "$points pts (₹%.2f)".format(points * cash) else "$points pts"
    }

    ExposedDropdownMenuBox(expanded = expanded, onExpandedChange = { expanded = it }) {
        OutlinedTextField(
            value = state.selectedPoints?.let { label(it) } ?: "",
            onValueChange = {},
            readOnly = true,
            label = { Text("Points to redeem") },
            trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = expanded) },
            modifier = Modifier
                .fillMaxWidth()
                .menuAnchor(MenuAnchorType.PrimaryNotEditable),
        )
        ExposedDropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
            options.forEach { points ->
                DropdownMenuItem(
                    text = { Text(label(points)) },
                    onClick = {
                        haptics.tick()
                        viewModel.selectPoints(points)
                        expanded = false
                    },
                )
            }
        }
    }
    Spacer(Modifier.height(NayaraSpacing.Xs))
    Text(
        "Points can only be redeemed in multiples of ${customer.redemptionIncrement}.",
        style = MaterialTheme.typography.bodySmall,
        color = MaterialTheme.nayara.textSecondary,
    )

    Spacer(Modifier.height(NayaraSpacing.Lg))
    NayaraButton(
        onClick = onSubmit,
        enabled = state.canRedeem,
        loading = state.redeeming,
        modifier = Modifier.fillMaxWidth(),
    ) {
        Text("Redeem Points")
    }
}
