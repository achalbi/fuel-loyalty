package com.acefuel.loyalty.ui.login

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.tween
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.shrinkVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.LocalGasStation
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
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
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import com.acefuel.loyalty.core.di.LocalContainer
import com.acefuel.loyalty.ui.designsystem.FormField
import com.acefuel.loyalty.ui.designsystem.InlineErrorCard
import com.acefuel.loyalty.ui.designsystem.NayaraCard
import com.acefuel.loyalty.ui.designsystem.NayaraTopBar
import com.acefuel.loyalty.ui.designsystem.PasswordField
import com.acefuel.loyalty.ui.designsystem.rememberHaptics
import com.acefuel.loyalty.ui.theme.NayaraButton
import com.acefuel.loyalty.ui.theme.NayaraMotion
import com.acefuel.loyalty.ui.theme.NayaraPalette
import com.acefuel.loyalty.ui.theme.NayaraSpacing
import com.acefuel.loyalty.ui.theme.nayara

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun LoginScreen(onBack: () -> Unit) {
    val container = LocalContainer.current
    val viewModel: LoginViewModel = viewModel(
        factory = viewModelFactory { initializer { LoginViewModel(container.authRepository) } },
    )
    val state by viewModel.state.collectAsStateWithLifecycle()
    val haptics = rememberHaptics()

    var login by rememberSaveable { mutableStateOf("") }
    var password by remember { mutableStateOf("") }

    val loading = state is LoginUiState.Loading
    val error = (state as? LoginUiState.Error)?.message
    val canSubmit = login.isNotBlank() && password.isNotBlank()

    fun submit() {
        if (canSubmit && !loading) viewModel.submit(login, password)
    }

    LaunchedEffect(error) { if (error != null) haptics.reject() }

    Scaffold(
        topBar = { NayaraTopBar(title = "", onBack = onBack) },
    ) { innerPadding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = NayaraSpacing.Xl, vertical = NayaraSpacing.Lg),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Spacer(Modifier.height(NayaraSpacing.X3l))
            BrandMark()
            Spacer(Modifier.height(NayaraSpacing.X3l))

            NayaraCard(modifier = Modifier.fillMaxWidth()) {
                Column(Modifier.padding(NayaraSpacing.Xxl)) {
                    Text("Sign in", style = MaterialTheme.typography.titleLarge)
                    Spacer(Modifier.height(NayaraSpacing.Xs))
                    Text(
                        "Enter your staff credentials to continue.",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.nayara.textSecondary,
                    )
                    Spacer(Modifier.height(NayaraSpacing.Xl))

                    FormField(
                        value = login,
                        onValueChange = {
                            login = it
                            viewModel.clearError()
                        },
                        label = "Username",
                        enabled = !loading,
                        keyboardOptions = KeyboardOptions(imeAction = ImeAction.Next),
                    )
                    Spacer(Modifier.height(NayaraSpacing.Md))
                    PasswordField(
                        value = password,
                        onValueChange = {
                            password = it
                            viewModel.clearError()
                        },
                        label = "Password",
                        enabled = !loading,
                        imeAction = ImeAction.Done,
                        keyboardActions = KeyboardActions(onDone = { submit() }),
                    )

                    // Cache the last message so the card keeps its content while
                    // animating out (state is already Idle by then).
                    var lastError by remember { mutableStateOf("") }
                    if (error != null) lastError = error
                    AnimatedVisibility(
                        visible = error != null,
                        enter = fadeIn(tween(NayaraMotion.Base)) +
                            expandVertically(tween(NayaraMotion.Base, easing = NayaraMotion.Enter)),
                        exit = fadeOut(tween(NayaraMotion.Fast)) +
                            shrinkVertically(tween(NayaraMotion.Fast, easing = NayaraMotion.Exit)),
                    ) {
                        Column {
                            Spacer(Modifier.height(NayaraSpacing.Md))
                            InlineErrorCard(lastError)
                        }
                    }

                    Spacer(Modifier.height(NayaraSpacing.Xl))
                    NayaraButton(
                        onClick = { submit() },
                        enabled = canSubmit,
                        loading = loading,
                        modifier = Modifier.fillMaxWidth(),
                    ) {
                        Text("Sign In")
                    }
                }
            }
        }
    }
}

@Composable
private fun BrandMark() {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Box(
            modifier = Modifier
                .size(72.dp)
                .clip(MaterialTheme.shapes.large)
                .background(
                    Brush.linearGradient(
                        listOf(NayaraPalette.Navy950, NayaraPalette.Navy800, NayaraPalette.Cyan800),
                    ),
                ),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                Icons.Filled.LocalGasStation,
                contentDescription = null,
                tint = NayaraPalette.White,
                modifier = Modifier.size(36.dp),
            )
        }
        Spacer(Modifier.height(NayaraSpacing.Md))
        Text(
            "Ace Fuel Loyalty",
            style = MaterialTheme.typography.titleMedium,
            color = MaterialTheme.nayara.textPrimary,
            textAlign = TextAlign.Center,
        )
        Text(
            "Staff Portal",
            style = MaterialTheme.typography.labelMedium,
            color = MaterialTheme.nayara.textTertiary,
            textAlign = TextAlign.Center,
        )
    }
}
