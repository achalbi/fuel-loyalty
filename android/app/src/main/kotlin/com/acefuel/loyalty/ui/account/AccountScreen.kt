package com.acefuel.loyalty.ui.account

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Logout
import androidx.compose.material.icons.filled.AdminPanelSettings
import androidx.compose.material.icons.filled.DocumentScanner
import androidx.compose.material.icons.filled.LocalGasStation
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.acefuel.loyalty.core.di.LocalContainer
import com.acefuel.loyalty.core.network.dto.UserDto
import com.acefuel.loyalty.ui.designsystem.Avatar
import com.acefuel.loyalty.ui.designsystem.ChipTone
import com.acefuel.loyalty.ui.designsystem.ConfirmDialog
import com.acefuel.loyalty.ui.designsystem.NayaraListRow
import com.acefuel.loyalty.ui.designsystem.NayaraSwitchRow
import com.acefuel.loyalty.ui.designsystem.SectionHeader
import com.acefuel.loyalty.ui.designsystem.StatusChip
import com.acefuel.loyalty.ui.designsystem.rememberHaptics
import com.acefuel.loyalty.ui.theme.NayaraSpacing
import com.acefuel.loyalty.ui.theme.nayara
import kotlinx.coroutines.launch

// ============================================================================
// Account — the fourth bottom-nav destination (DESIGN_BRIEF §4a).
//
// Exists so the tab bar has a home for the things that were previously stranded
// at the bottom of HomeScreen: identity, admin entry, log out. The identity
// block comes from the already-loaded session (`GET /api/v1/auth/me`); "My
// Pump" opens its own screen (GET/PATCH /api/v1/my_pump) where staff assign the
// pump + nozzles that unblock recording transactions.
// ============================================================================

@Composable
fun AccountScreen(
    user: UserDto,
    onAdmin: () -> Unit,
    onMyPump: () -> Unit,
    onLogout: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val nayara = MaterialTheme.nayara
    val haptics = rememberHaptics()
    val scope = rememberCoroutineScope()
    val settingsStore = LocalContainer.current.settingsStore
    val onDeviceScanFirst by settingsStore.onDeviceScanFirst.collectAsStateWithLifecycle()
    var showLogoutConfirm by rememberSaveable { mutableStateOf(false) }
    val isAdmin = user.role == "admin"
    val name = user.displayName ?: user.name ?: user.username ?: "Staff"

    Column(
        modifier = modifier
            .fillMaxSize()
            // This screen has no TopAppBar, so it owns the status-bar inset
            // itself (the nav shell deliberately doesn't apply a top inset).
            .statusBarsPadding()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = NayaraSpacing.ScreenMargin),
    ) {
        Spacer(Modifier.height(NayaraSpacing.Xl))

        Row(verticalAlignment = Alignment.CenterVertically) {
            Avatar(name = name, size = 56.dp, keySalt = "account")
            Spacer(Modifier.width(NayaraSpacing.Lg))
            Column(Modifier.weight(1f)) {
                Text(
                    text = name,
                    style = MaterialTheme.typography.headlineSmall,
                    fontWeight = FontWeight.Bold,
                    color = nayara.textPrimary,
                )
                if (user.displayPhoneNumber != null) {
                    Spacer(Modifier.height(2.dp))
                    Text(
                        text = user.displayPhoneNumber,
                        style = MaterialTheme.typography.bodyMedium,
                        color = nayara.textSecondary,
                    )
                }
                Spacer(Modifier.height(NayaraSpacing.Sm))
                StatusChip(
                    label = user.role.replaceFirstChar { it.uppercase() },
                    tone = if (isAdmin) ChipTone.Brand else ChipTone.Info,
                    showDot = false,
                )
            }
        }

        if (!user.subtitle.isNullOrBlank() || !user.employeeCode.isNullOrBlank()) {
            SectionHeader("Details")
            Column(verticalArrangement = Arrangement.spacedBy(0.dp)) {
                if (!user.employeeCode.isNullOrBlank()) {
                    NayaraListRow(title = "Employee code", trailing = user.employeeCode)
                }
                if (!user.subtitle.isNullOrBlank()) {
                    NayaraListRow(title = "Assignment", trailing = user.subtitle)
                }
            }
        }

        SectionHeader("Pump")
        NayaraListRow(
            title = "My Pump",
            subtitle = "Choose your pump and its active nozzles",
            leadingIcon = Icons.Filled.LocalGasStation,
            leadingTint = nayara.actionPrimary,
            onClick = { haptics.tick(); onMyPump() },
        )

        if (isAdmin) {
            SectionHeader("Administration")
            NayaraListRow(
                title = "Admin tools",
                subtitle = "Dashboard, catalogs, shifts, notifications",
                leadingIcon = Icons.Filled.AdminPanelSettings,
                leadingTint = nayara.actionPrimary,
                onClick = { haptics.tick(); onAdmin() },
            )
        }

        SectionHeader("Scanner")
        NayaraSwitchRow(
            title = "On-device plate scanning",
            subtitle = "Faster and works offline. Falls back to the server when it can't read the number.",
            leadingIcon = Icons.Filled.DocumentScanner,
            leadingTint = nayara.actionPrimary,
            checked = onDeviceScanFirst,
            onCheckedChange = { checked ->
                haptics.tick()
                scope.launch { settingsStore.setOnDeviceScanFirst(checked) }
            },
        )

        SectionHeader("Session")
        NayaraListRow(
            title = "Log out",
            leadingIcon = Icons.AutoMirrored.Filled.Logout,
            leadingTint = nayara.statusError,
            onClick = { haptics.tick(); showLogoutConfirm = true },
        )

        Spacer(Modifier.height(NayaraSpacing.Xxl))
    }

    if (showLogoutConfirm) {
        ConfirmDialog(
            title = "Log out?",
            text = "You'll need to sign in again to use staff features.",
            confirmLabel = "Log out",
            onConfirm = {
                showLogoutConfirm = false
                onLogout()
            },
            onDismiss = { showLogoutConfirm = false },
        )
    }
}
