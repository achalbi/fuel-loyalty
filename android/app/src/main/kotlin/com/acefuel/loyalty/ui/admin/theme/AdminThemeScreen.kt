package com.acefuel.loyalty.ui.admin.theme

import androidx.activity.compose.BackHandler
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
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
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import com.acefuel.loyalty.core.di.LocalContainer
import com.acefuel.loyalty.ui.designsystem.ConfirmDialog
import com.acefuel.loyalty.ui.designsystem.ErrorState
import com.acefuel.loyalty.ui.designsystem.FormField
import com.acefuel.loyalty.ui.designsystem.NayaraPullToRefresh
import com.acefuel.loyalty.ui.designsystem.NayaraSnackbarHost
import com.acefuel.loyalty.ui.designsystem.NayaraTopBar
import com.acefuel.loyalty.ui.designsystem.SkeletonCard
import com.acefuel.loyalty.ui.designsystem.rememberHaptics
import com.acefuel.loyalty.ui.designsystem.showError
import com.acefuel.loyalty.ui.designsystem.showSuccess
import com.acefuel.loyalty.ui.theme.NayaraButton
import com.acefuel.loyalty.ui.theme.NayaraMotion
import com.acefuel.loyalty.ui.theme.NayaraSpacing
import com.acefuel.loyalty.ui.theme.nayara

/** Tappable preset palette (any valid hex still works via the text field). */
private val PRESET_COLORS = listOf(
    "#1D63B0" to "Nayara navy (default)",
    "#052B54" to "Deep navy",
    "#0EA5E9" to "Sky",
    "#18945C" to "Green",
    "#0F766E" to "Teal",
    "#7C3AED" to "Violet",
    "#E11D48" to "Rose",
    "#F59E0B" to "Amber",
)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AdminThemeScreen(onBack: () -> Unit) {
    val container = LocalContainer.current
    val repo = remember {
        AdminThemeRepository(container.retrofit.create(AdminThemeApi::class.java), container.json)
    }
    val vm: AdminThemeViewModel = viewModel(
        factory = viewModelFactory { initializer { AdminThemeViewModel(repo) } },
    )
    val state by vm.state.collectAsStateWithLifecycle()

    val snackbar = remember { SnackbarHostState() }
    val haptics = rememberHaptics()

    var showDiscardConfirm by remember { mutableStateOf(false) }
    val requestBack: () -> Unit = {
        if (!state.loading && state.loadError == null && state.dirty) showDiscardConfirm = true else onBack()
    }
    BackHandler { requestBack() }

    // Show first, consume after: consuming inside the effect nulls the key it
    // is launched on, which would cancel the still-suspended showSnackbar.
    LaunchedEffect(state.successMessage) {
        val msg = state.successMessage ?: return@LaunchedEffect
        haptics.confirm()
        snackbar.showSuccess(msg)
        vm.consumeMessage()
    }
    LaunchedEffect(state.saveError) {
        val msg = state.saveError ?: return@LaunchedEffect
        haptics.reject()
        snackbar.showError(msg)
        vm.consumeSaveError()
    }

    Scaffold(
        topBar = { NayaraTopBar(title = "Theme", onBack = requestBack) },
        snackbarHost = { NayaraSnackbarHost(snackbar) },
    ) { innerPadding ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding),
        ) {
            when {
                state.loading -> Column(
                    modifier = Modifier.fillMaxSize().padding(NayaraSpacing.ScreenMargin),
                    verticalArrangement = Arrangement.spacedBy(NayaraSpacing.Lg),
                ) {
                    SkeletonCard(lines = 2)
                    SkeletonCard(lines = 4)
                }

                state.loadError != null -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    ErrorState(state.loadError!!, onRetry = vm::load)
                }

                else -> NayaraPullToRefresh(
                    isRefreshing = state.refreshing,
                    onRefresh = vm::refresh,
                    modifier = Modifier.fillMaxSize(),
                ) {
                    ThemeForm(state = state, vm = vm)
                }
            }
        }
    }

    if (showDiscardConfirm) {
        ConfirmDialog(
            title = "Discard changes?",
            text = "The theme color hasn't been saved yet. Discard it?",
            confirmLabel = "Discard",
            destructive = true,
            onConfirm = {
                showDiscardConfirm = false
                onBack()
            },
            onDismiss = { showDiscardConfirm = false },
        )
    }
}

@Composable
private fun ThemeForm(state: AdminThemeUiState, vm: AdminThemeViewModel) {
    val targetColor = remember(state.input, state.savedColor, state.inputValid) {
        if (state.inputValid) parseHexColorOrDefault(state.input)
        else parseHexColorOrDefault(hexDigitsOf(state.savedColor))
    }
    // Preview follows the selection with a smooth tint transition.
    val previewColor by animateColorAsState(
        targetValue = targetColor,
        animationSpec = tween(NayaraMotion.Base, easing = NayaraMotion.Standard),
        label = "theme-preview-color",
    )

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(NayaraSpacing.ScreenMargin),
        verticalArrangement = Arrangement.spacedBy(NayaraSpacing.Lg),
    ) {
        Column(verticalArrangement = Arrangement.spacedBy(NayaraSpacing.Xs)) {
            Text(
                "Primary color",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.SemiBold,
                color = MaterialTheme.nayara.textPrimary,
            )
            Text(
                "Sets the brand accent used across the customer app.",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.nayara.textSecondary,
            )
        }

        FormField(
            value = state.input,
            onValueChange = vm::onInputChange,
            label = "Hex color",
            prefix = { Text("#") },
            errors = state.fieldError?.let(::listOf),
            helper = "Six hex digits, e.g. 1D63B0",
            keyboardOptions = KeyboardOptions(
                capitalization = KeyboardCapitalization.Characters,
                keyboardType = KeyboardType.Ascii,
            ),
        )

        // Preset swatches ----------------------------------------------------
        Text(
            "Presets",
            style = MaterialTheme.typography.labelLarge,
            color = MaterialTheme.nayara.textSecondary,
        )
        PresetSwatches(
            selectedDigits = state.input,
            onSelect = vm::onPresetSelected,
        )

        // Live preview -------------------------------------------------------
        PreviewCard(previewColor = previewColor, savedColor = state.savedColor, updatedAt = state.updatedAt)

        // Save --------------------------------------------------------------
        NayaraButton(
            onClick = vm::save,
            enabled = state.canSave,
            loading = state.saving,
            modifier = Modifier.fillMaxWidth(),
        ) {
            Text("Save theme color")
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun PresetSwatches(selectedDigits: String, onSelect: (String) -> Unit) {
    val haptics = rememberHaptics()
    FlowRow(horizontalArrangement = Arrangement.spacedBy(12.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        PRESET_COLORS.forEach { (hex, name) ->
            ColorSwatch(
                hex = hex,
                name = name,
                selected = hexDigitsOf(hex) == selectedDigits,
                onClick = {
                    haptics.tick()
                    onSelect(hex)
                },
            )
        }
    }
}

@Composable
private fun ColorSwatch(hex: String, name: String, selected: Boolean, onClick: () -> Unit) {
    val color = parseHexColorOrDefault(hexDigitsOf(hex))
    val borderColor = if (selected) MaterialTheme.nayara.textPrimary else MaterialTheme.nayara.borderDefault
    Box(
        modifier = Modifier
            .size(44.dp)
            // clip before clickable so the ripple is bounded to the circle
            .clip(CircleShape)
            .background(color)
            .border(width = if (selected) 3.dp else 1.dp, color = borderColor, shape = CircleShape)
            .clickable(onClick = onClick)
            .semantics {
                contentDescription = "$name, ${hex.uppercase()}"
                this.selected = selected
            },
        contentAlignment = Alignment.Center,
    ) {
        if (selected) {
            Icon(
                Icons.Filled.Check,
                contentDescription = null,
                tint = contrastOn(color),
                modifier = Modifier.size(20.dp),
            )
        }
    }
}

@Composable
private fun PreviewCard(previewColor: Color, savedColor: String, updatedAt: String?) {
    val onColor = contrastOn(previewColor)
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.nayara.bgSurfaceRaised),
        border = BorderStroke(1.dp, MaterialTheme.nayara.borderDefault),
    ) {
        Column(
            modifier = Modifier.fillMaxWidth().padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Text(
                "Preview",
                style = MaterialTheme.typography.labelLarge,
                color = MaterialTheme.nayara.textSecondary,
            )

            // Accent badge / chip drawn with the chosen color.
            Box(
                modifier = Modifier
                    .background(previewColor, RoundedCornerShape(50))
                    .padding(horizontal = 14.dp, vertical = 6.dp),
            ) {
                Text("Accent", color = onColor, style = MaterialTheme.typography.labelMedium, fontWeight = FontWeight.SemiBold)
            }

            // Filled primary button drawn with the chosen color.
            Button(
                onClick = {},
                shape = MaterialTheme.shapes.medium,
                colors = ButtonDefaults.buttonColors(containerColor = previewColor, contentColor = onColor),
                modifier = Modifier.fillMaxWidth().heightIn(min = 52.dp),
            ) {
                Text("Primary button")
            }

            // Outline button tinted with the chosen color.
            OutlinedButton(
                onClick = {},
                shape = MaterialTheme.shapes.medium,
                border = BorderStroke(1.dp, previewColor),
                colors = ButtonDefaults.outlinedButtonColors(contentColor = previewColor),
                modifier = Modifier.fillMaxWidth().heightIn(min = 52.dp),
            ) {
                Text("Outline button")
            }

            Spacer(Modifier.height(0.dp))
            Text(
                "Current: ${savedColor.uppercase()}",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.nayara.textSecondary,
            )
            updatedAt?.let {
                Text(
                    "Last updated: $it",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.nayara.textTertiary,
                )
            }
        }
    }
}

// --- color helpers ----------------------------------------------------------

/** Parse six hex digits ("1D63B0") into an opaque Compose [Color]; falls back to navy. */
private fun parseHexColorOrDefault(hexDigits: String): Color = runCatching {
    Color(0xFF000000L or hexDigits.uppercase().toLong(16))
}.getOrDefault(Color(0xFF1D63B0))

/** Readable text/icon color for a filled swatch (mirrors the server brightness rule). */
private fun contrastOn(color: Color): Color {
    val brightness = (color.red * 299f + color.green * 587f + color.blue * 114f) / 1000f * 255f
    return if (brightness >= 150f) Color(0xFF052B54) else Color.White
}
