package com.acefuel.loyalty.ui.admin.settings

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
import androidx.compose.material.icons.filled.DirectionsCar
import androidx.compose.material.icons.filled.EvStation
import androidx.compose.material.icons.filled.Inventory2
import androidx.compose.material.icons.filled.LocalGasStation
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material.icons.filled.Palette
import androidx.compose.material.icons.filled.People
import androidx.compose.material.icons.filled.Stars
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.acefuel.loyalty.core.network.dto.UserDto
import com.acefuel.loyalty.ui.designsystem.Avatar
import com.acefuel.loyalty.ui.designsystem.ChipTone
import com.acefuel.loyalty.ui.designsystem.ConfirmDialog
import com.acefuel.loyalty.ui.designsystem.NayaraListRow
import com.acefuel.loyalty.ui.designsystem.SectionHeader
import com.acefuel.loyalty.ui.designsystem.StatusChip
import com.acefuel.loyalty.ui.designsystem.rememberHaptics
import com.acefuel.loyalty.ui.theme.NayaraSpacing
import com.acefuel.loyalty.ui.theme.nayara

// ============================================================================
// Settings — admin tab 4 of 4. Everything configured once and touched twice a
// year, collected in one place.
//
// This is the single biggest IA fix in Option A. The web sidebar gives Reward
// Rates, Fuel Types, Vehicle Types, Pumps and Theme the same visual weight as
// Customers and Transactions — an inventory of the codebase, not a model of the
// job. Six of the old menu's thirteen rows were config. They live here now, and
// the three tabs in front of this one are free to be about the daily work.
//
// Grouping is by *what breaks if you get it wrong*: Loyalty (the earn/burn math),
// Station (physical hardware), Access (who can sign in), App (what customers see).
// ============================================================================

@Composable
fun AdminSettingsScreen(
    user: UserDto,
    onUsers: () -> Unit,
    onRewardRates: () -> Unit,
    onFuelTypes: () -> Unit,
    onVehicleTypes: () -> Unit,
    onProducts: () -> Unit,
    onPumps: () -> Unit,
    onNotifications: () -> Unit,
    onTheme: () -> Unit,
    onLogout: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val nayara = MaterialTheme.nayara
    val haptics = rememberHaptics()
    var showLogoutConfirm by rememberSaveable { mutableStateOf(false) }
    val name = user.displayName ?: user.name ?: user.username ?: "Admin"

    Column(
        modifier = modifier
            .fillMaxSize()
            .statusBarsPadding()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = NayaraSpacing.ScreenMargin),
    ) {
        Spacer(Modifier.height(NayaraSpacing.Xl))

        Row(verticalAlignment = Alignment.CenterVertically) {
            Avatar(name = name, size = 56.dp, keySalt = "admin-settings")
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
                    tone = ChipTone.Brand,
                    showDot = false,
                )
            }
        }

        SectionHeader("Loyalty")
        NayaraListRow(
            title = "Reward rates",
            subtitle = "Rupee unit, per-point cash value, per-type overrides",
            leadingIcon = Icons.Filled.Stars,
            leadingTint = nayara.rewardPointsText,
            onClick = { haptics.tick(); onRewardRates() },
        )
        NayaraListRow(
            title = "Fuel types",
            subtitle = "Codes are fixed once created",
            leadingIcon = Icons.Filled.LocalGasStation,
            leadingTint = nayara.fuelPetrol,
            onClick = { haptics.tick(); onFuelTypes() },
        )
        NayaraListRow(
            title = "Vehicle types",
            subtitle = "Icons, app labels, minimum redeemable points",
            leadingIcon = Icons.Filled.DirectionsCar,
            leadingTint = nayara.fuelDiesel,
            onClick = { haptics.tick(); onVehicleTypes() },
        )
        NayaraListRow(
            title = "Products",
            subtitle = "Priced catalog — fuels, lubricants, additives",
            leadingIcon = Icons.Filled.Inventory2,
            leadingTint = nayara.accentDefault,
            onClick = { haptics.tick(); onProducts() },
        )

        SectionHeader("Station")
        NayaraListRow(
            title = "Pumps & nozzles",
            subtitle = "Nozzle selection, per-nozzle fuel type",
            leadingIcon = Icons.Filled.EvStation,
            leadingTint = nayara.accentDefault,
            onClick = { haptics.tick(); onPumps() },
        )

        SectionHeader("Access")
        NayaraListRow(
            title = "Users",
            subtitle = "Admin and staff accounts",
            leadingIcon = Icons.Filled.People,
            leadingTint = nayara.actionPrimary,
            onClick = { haptics.tick(); onUsers() },
        )

        SectionHeader("App")
        NayaraListRow(
            title = "Notifications",
            subtitle = "Broadcasts and saved schedules",
            leadingIcon = Icons.Filled.Notifications,
            leadingTint = nayara.statusInfo,
            onClick = { haptics.tick(); onNotifications() },
        )
        NayaraListRow(
            title = "Theme",
            subtitle = "Primary colour, applied everywhere",
            leadingIcon = Icons.Filled.Palette,
            leadingTint = nayara.accentDefault,
            onClick = { haptics.tick(); onTheme() },
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
            text = "You'll need to sign in again to use admin features.",
            confirmLabel = "Log out",
            onConfirm = {
                showLogoutConfirm = false
                onLogout()
            },
            onDismiss = { showLogoutConfirm = false },
        )
    }
}
