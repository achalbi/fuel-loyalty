package com.acefuel.loyalty.ui.mypump

import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.selection.toggleable
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.LocalGasStation
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Checkbox
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.RadioButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import com.acefuel.loyalty.core.di.LocalContainer
import com.acefuel.loyalty.core.network.dto.NozzleDto
import com.acefuel.loyalty.core.network.dto.PumpDto
import com.acefuel.loyalty.ui.designsystem.EmptyState
import com.acefuel.loyalty.ui.designsystem.InlineErrorCard
import com.acefuel.loyalty.ui.designsystem.NayaraCard
import com.acefuel.loyalty.ui.designsystem.NayaraSnackbarHost
import com.acefuel.loyalty.ui.designsystem.NayaraTopBar
import com.acefuel.loyalty.ui.designsystem.DateField
import com.acefuel.loyalty.ui.designsystem.SkeletonListItem
import com.acefuel.loyalty.ui.designsystem.rememberHaptics
import com.acefuel.loyalty.ui.designsystem.showError
import com.acefuel.loyalty.ui.theme.NayaraButton
import com.acefuel.loyalty.ui.theme.NayaraSpacing
import com.acefuel.loyalty.ui.theme.nayara
import kotlinx.coroutines.launch
import java.time.LocalDate

/**
 * My Pump — a staff member assigns the pump they work on and which of its
 * active nozzles are theirs. This is the setup the transaction screen requires
 * when nozzle mode is on; without it, staff are blocked from recording
 * transactions. Backend: GET/PATCH /api/v1/my_pump.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MyPumpScreen(
    onBack: () -> Unit,
    // When set, an admin is assigning this staff member's pump (A10) via the
    // admin endpoint instead of the self-service /my_pump endpoint (S-MYPUMP).
    staffMemberId: Long? = null,
    title: String = "My Pump",
    intro: String = "Choose the pump you work on and the nozzles available to you. New " +
        "transactions use this pump and show your nozzles as options.",
    saveLabel: String = "Save My Pump",
) {
    val container = LocalContainer.current
    val viewModel: MyPumpViewModel = viewModel(
        key = "pump-${staffMemberId ?: "self"}",
        factory = viewModelFactory { initializer { MyPumpViewModel(container.staffRepository, staffMemberId) } },
    )
    val state by viewModel.state.collectAsStateWithLifecycle()
    val haptics = rememberHaptics()
    val snackbar = remember { SnackbarHostState() }
    val scope = rememberCoroutineScope()

    // Save failures are transient: snackbar + reject haptic, selections kept.
    LaunchedEffect(state.saveError) {
        val message = state.saveError ?: return@LaunchedEffect
        haptics.reject()
        viewModel.consumeSaveError()
        scope.launch { snackbar.showError(message) }
    }

    Scaffold(
        topBar = { NayaraTopBar(title = title, onBack = onBack) },
        snackbarHost = { NayaraSnackbarHost(snackbar) },
    ) { innerPadding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = NayaraSpacing.ScreenMargin, vertical = NayaraSpacing.Lg),
        ) {
            Text(
                intro,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.nayara.textSecondary,
            )
            Spacer(Modifier.height(NayaraSpacing.Md))
            DateField(
                label = "Assignment date",
                value = state.assignmentDate,
                onChange = viewModel::setAssignmentDate,
                modifier = Modifier.fillMaxWidth(),
                placeholder = "Select date",
            )
            Spacer(Modifier.height(NayaraSpacing.Lg))

            when {
                state.loading -> {
                    repeat(3) {
                        SkeletonListItem(showAvatar = false)
                        Spacer(Modifier.height(NayaraSpacing.Md))
                    }
                }

                state.loadError != null -> InlineErrorCard(state.loadError!!, onRetry = viewModel::load)

                state.activePumps.isEmpty() -> EmptyState(
                    title = "No pumps available",
                    message = "No active pumps are set up yet. Ask an admin to add a pump with at least one active nozzle.",
                    icon = Icons.Filled.LocalGasStation,
                )

                else -> PumpForm(
                    state = state,
                    saveLabel = saveLabel,
                    onSelectPump = { haptics.tick(); viewModel.selectPump(it) },
                    onToggleNozzle = { haptics.tick(); viewModel.toggleNozzle(it) },
                    onSave = { haptics.tick(); viewModel.save() },
                )
            }
        }
    }
}

@Composable
private fun PumpForm(
    state: MyPumpUiState,
    saveLabel: String,
    onSelectPump: (Long) -> Unit,
    onToggleNozzle: (Long) -> Unit,
    onSave: () -> Unit,
) {
    if (state.saved) {
        SavedBanner(state.assignmentDate)
        Spacer(Modifier.height(NayaraSpacing.Lg))
    }

    SectionLabel("Pump")
    Spacer(Modifier.height(NayaraSpacing.Sm))
    Column(verticalArrangement = Arrangement.spacedBy(NayaraSpacing.Md)) {
        state.activePumps.forEach { pump ->
            PumpRow(
                pump = pump,
                selected = state.selectedPumpId == pump.id,
                onSelect = { onSelectPump(pump.id) },
            )
        }
    }

    Spacer(Modifier.height(NayaraSpacing.Xl))
    SectionLabel("Assigned nozzles")
    Spacer(Modifier.height(NayaraSpacing.Sm))
    when {
        state.selectedPumpId == null -> Hint("Select a pump to see its nozzles.")
        state.nozzlesForSelectedPump.isEmpty() ->
            Hint("This pump has no active nozzles. Ask an admin to activate one.")
        else -> Column(verticalArrangement = Arrangement.spacedBy(NayaraSpacing.Md)) {
            state.nozzlesForSelectedPump.forEach { nozzle ->
                NozzleRow(
                    nozzle = nozzle,
                    checked = nozzle.id in state.selectedNozzleIds,
                    onToggle = { onToggleNozzle(nozzle.id) },
                )
            }
        }
    }

    Spacer(Modifier.height(NayaraSpacing.Xl))
    NayaraButton(
        onClick = onSave,
        enabled = state.canSave,
        loading = state.saving,
        modifier = Modifier.fillMaxWidth(),
    ) {
        Text(saveLabel)
    }
    Spacer(Modifier.height(NayaraSpacing.Xxl))
}

@Composable
private fun PumpRow(pump: PumpDto, selected: Boolean, onSelect: () -> Unit) {
    val ring = if (selected) {
        Modifier.border(1.5.dp, MaterialTheme.nayara.actionPrimary, MaterialTheme.shapes.large)
    } else {
        Modifier
    }
    NayaraCard(
        modifier = Modifier
            .fillMaxWidth()
            .selectable(selected = selected, role = Role.RadioButton, onClick = onSelect)
            .then(ring),
    ) {
        Row(Modifier.padding(NayaraSpacing.Lg), verticalAlignment = Alignment.CenterVertically) {
            RadioButton(selected = selected, onClick = null)
            Spacer(Modifier.width(NayaraSpacing.Md))
            Text(pump.displayName, fontWeight = FontWeight.SemiBold)
        }
    }
}

@Composable
private fun NozzleRow(nozzle: NozzleDto, checked: Boolean, onToggle: () -> Unit) {
    val ring = if (checked) {
        Modifier.border(1.5.dp, MaterialTheme.nayara.actionPrimary, MaterialTheme.shapes.large)
    } else {
        Modifier
    }
    NayaraCard(
        modifier = Modifier
            .fillMaxWidth()
            .toggleable(value = checked, role = Role.Checkbox, onValueChange = { onToggle() })
            .then(ring),
    ) {
        Row(Modifier.padding(NayaraSpacing.Lg), verticalAlignment = Alignment.CenterVertically) {
            Checkbox(checked = checked, onCheckedChange = null)
            Spacer(Modifier.width(NayaraSpacing.Md))
            Column(verticalArrangement = Arrangement.spacedBy(NayaraSpacing.Xxs)) {
                Text(nozzle.displayName, fontWeight = FontWeight.SemiBold)
                Text(
                    nozzle.fuelType ?: nozzle.fuelTypeCode.orEmpty(),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.nayara.textSecondary,
                )
            }
        }
    }
}

@Composable
private fun SectionLabel(text: String) {
    Text(
        text,
        style = MaterialTheme.typography.titleSmall,
        fontWeight = FontWeight.SemiBold,
        color = MaterialTheme.nayara.textSecondary,
    )
}

@Composable
private fun Hint(message: String) {
    Card(
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.nayara.statusWarningContainer),
        modifier = Modifier.fillMaxWidth(),
    ) {
        Text(message, Modifier.padding(14.dp), color = MaterialTheme.nayara.statusOnWarningContainer)
    }
}

@Composable
private fun SavedBanner(date: LocalDate) {
    Card(
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.nayara.statusSuccessContainer),
        modifier = Modifier.fillMaxWidth(),
    ) {
        Text(
            "Pump assignment saved for ${date.dayOfMonth} ${date.month.name.lowercase().replaceFirstChar(Char::uppercase)} ${date.year}.",
            Modifier.padding(14.dp),
            color = MaterialTheme.nayara.statusOnSuccessContainer,
            fontWeight = FontWeight.SemiBold,
        )
    }
}
