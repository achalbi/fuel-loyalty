package com.acefuel.loyalty.ui.adjust

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
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.SnackbarHostState
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
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import com.acefuel.loyalty.core.di.LocalContainer
import com.acefuel.loyalty.ui.designsystem.AnimatedCounter
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
fun AdjustPointsScreen(onBack: () -> Unit) {
    val container = LocalContainer.current
    val viewModel: AdjustPointsViewModel = viewModel(
        factory = viewModelFactory { initializer { AdjustPointsViewModel(container.staffRepository) } },
    )
    val state by viewModel.state.collectAsStateWithLifecycle()
    var phone by rememberSaveable { mutableStateOf("") }
    // Plain remember (not saveable): the confirm summary reads ViewModel state,
    // which resets on process death — a restored dialog could open uninvited.
    var showConfirm by remember { mutableStateOf(false) }
    val snackbar = remember { SnackbarHostState() }
    val haptics = rememberHaptics()

    LaunchedEffect(state.errorMessage) {
        val message = state.errorMessage ?: return@LaunchedEffect
        haptics.reject()
        snackbar.showError(message)
        viewModel.consumeError()
    }
    LaunchedEffect(state.lookupMessage) {
        if (state.lookupMessage != null) haptics.reject()
    }

    // Keep the last message so the overlay text survives its exit animation.
    var lastSuccessMessage by remember { mutableStateOf<String?>(null) }
    state.successMessage?.let { lastSuccessMessage = it }

    Box(Modifier.fillMaxSize()) {
        Scaffold(
            topBar = { NayaraTopBar(title = "Adjust Points", onBack = onBack) },
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
                    SkeletonCard(lines = 3)
                }

                val customer = state.customer
                AnimatedVisibility(
                    visible = customer != null,
                    enter = fadeIn(tween(NayaraMotion.Base)) +
                        expandVertically(tween(NayaraMotion.Base, easing = NayaraMotion.Enter)),
                ) {
                    val c = customer ?: return@AnimatedVisibility
                    Column {
                        NayaraCard(modifier = Modifier.fillMaxWidth()) {
                            Column(modifier = Modifier.padding(NayaraSpacing.CardPadding)) {
                                Text(
                                    c.name ?: "Customer",
                                    style = MaterialTheme.typography.titleMedium,
                                    fontWeight = FontWeight.SemiBold,
                                )
                                Text(
                                    "${c.statusLabel} · ${c.rewardsStatusLabel}",
                                    style = MaterialTheme.typography.labelMedium,
                                    color = MaterialTheme.nayara.textSecondary,
                                )
                                Spacer(Modifier.height(NayaraSpacing.Md))
                                AnimatedCounter(
                                    value = c.totalPoints,
                                    style = NayaraNumerals.Large,
                                )
                                Text(
                                    "Current points",
                                    style = MaterialTheme.typography.labelMedium,
                                    color = MaterialTheme.nayara.textSecondary,
                                )
                            }
                        }

                        Spacer(Modifier.height(NayaraSpacing.Lg))
                        SingleChoiceSegmentedButtonRow(modifier = Modifier.fillMaxWidth()) {
                            SegmentedButton(
                                selected = state.mode == AdjustMode.Add,
                                onClick = {
                                    haptics.tick()
                                    viewModel.setMode(AdjustMode.Add)
                                },
                                shape = SegmentedButtonDefaults.itemShape(index = 0, count = 2),
                            ) {
                                Text("Add")
                            }
                            SegmentedButton(
                                selected = state.mode == AdjustMode.Deduct,
                                onClick = {
                                    haptics.tick()
                                    viewModel.setMode(AdjustMode.Deduct)
                                },
                                shape = SegmentedButtonDefaults.itemShape(index = 1, count = 2),
                            ) {
                                Text("Deduct")
                            }
                        }

                        Spacer(Modifier.height(NayaraSpacing.Md))
                        FormField(
                            value = state.pointsInput,
                            onValueChange = viewModel::onPointsChange,
                            label = if (state.mode == AdjustMode.Deduct) "Points to deduct" else "Points to add",
                            errors = state.pointsError?.let { listOf(it) },
                            helper = if (state.mode == AdjustMode.Deduct) {
                                "Points will be deducted from the customer's balance."
                            } else {
                                "Points will be added to the customer's balance."
                            },
                            keyboardOptions = KeyboardOptions(
                                keyboardType = KeyboardType.Number,
                                imeAction = ImeAction.Done,
                            ),
                        )

                        Spacer(Modifier.height(NayaraSpacing.Lg))
                        NayaraButton(
                            onClick = { showConfirm = true },
                            enabled = state.canSubmit,
                            loading = state.submitting,
                            modifier = Modifier.fillMaxWidth(),
                        ) {
                            Text(if (state.mode == AdjustMode.Deduct) "Deduct Points" else "Add Points")
                        }
                    }
                }
            }
        }

        SuccessOverlay(
            visible = state.successMessage != null,
            title = "Points adjusted",
            subtitle = lastSuccessMessage,
            onFinished = viewModel::consumeSuccessMessage,
        )
    }

    val confirmCustomer = state.customer
    val confirmPoints = state.parsedPoints
    if (showConfirm && confirmCustomer != null && confirmPoints != null) {
        val deducting = state.mode == AdjustMode.Deduct
        val newBalance = if (deducting) confirmCustomer.totalPoints - confirmPoints else confirmCustomer.totalPoints + confirmPoints
        ConfirmDialog(
            title = if (deducting) "Deduct points?" else "Add points?",
            text = "${if (deducting) "Deduct" else "Add"} $confirmPoints pts " +
                "${if (deducting) "from" else "to"} ${confirmCustomer.name ?: "this customer"}. " +
                "New balance will be $newBalance pts.",
            confirmLabel = if (deducting) "Deduct" else "Add",
            destructive = deducting,
            onConfirm = {
                showConfirm = false
                viewModel.submit()
            },
            onDismiss = { showConfirm = false },
        )
    }
}
