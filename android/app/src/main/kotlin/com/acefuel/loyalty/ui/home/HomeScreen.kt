package com.acefuel.loyalty.ui.home

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.tween
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.shrinkVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowForward
import androidx.compose.material.icons.filled.AdminPanelSettings
import androidx.compose.material.icons.filled.People
import androidx.compose.material.icons.automirrored.filled.ReceiptLong
import androidx.compose.material.icons.filled.PointOfSale
import androidx.compose.material.icons.filled.Redeem
import androidx.compose.material.icons.filled.Tune
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.acefuel.loyalty.core.network.dto.UserDto
import com.acefuel.loyalty.ui.designsystem.Avatar
import com.acefuel.loyalty.ui.designsystem.StatusChip
import com.acefuel.loyalty.ui.designsystem.ChipTone
import com.acefuel.loyalty.ui.designsystem.rememberHaptics
import com.acefuel.loyalty.ui.loyalty.LoyaltyLookupCard
import com.acefuel.loyalty.ui.theme.NayaraHeroCard
import com.acefuel.loyalty.ui.theme.NayaraMotion
import com.acefuel.loyalty.ui.theme.NayaraPalette
import com.acefuel.loyalty.ui.theme.NayaraSpacing
import com.acefuel.loyalty.ui.theme.nayara
import java.time.LocalTime

private data class QuickAction(
    val icon: ImageVector,
    val label: String,
    val container: Color,
    val tint: Color,
    val onClick: () -> Unit,
)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HomeScreen(
    user: UserDto,
    onNewTransaction: () -> Unit,
    onCustomers: () -> Unit,
    onRedeem: () -> Unit,
    onAdjustPoints: () -> Unit,
    onDailySettlement: () -> Unit,
    onAdmin: () -> Unit,
) {
    val haptics = rememberHaptics()
    val nayara = MaterialTheme.nayara
    val isAdmin = user.role == "admin"

    val actions = buildList {
        // Item 2 — one capture: the entry screen records the sale and the visit
        // together, so there is no separate Capture Visit action.
        add(QuickAction(Icons.Filled.PointOfSale, "New Entry", nayara.actionPrimaryContainer, nayara.actionPrimary) { haptics.tick(); onNewTransaction() })
        // A settlement belongs to the FSM who worked the shift (Admin-12), so an
        // admin does not file one from here — the web console has the
        // enter-on-behalf-of flow for the case where an FSM cannot. Admins read
        // and reconcile settlements from Admin > Settlements instead.
        if (!isAdmin) {
            add(QuickAction(Icons.AutoMirrored.Filled.ReceiptLong, "Daily Settlement", nayara.statusInfoContainer, nayara.statusInfo) { haptics.tick(); onDailySettlement() })
        }
        add(QuickAction(Icons.Filled.People, "Customers", nayara.accentContainer, nayara.accentDefault) { haptics.tick(); onCustomers() })
        add(QuickAction(Icons.Filled.Redeem, "Redeem", nayara.rewardPointsContainer, nayara.rewardPointsText) { haptics.tick(); onRedeem() })
        if (isAdmin) {
            add(QuickAction(Icons.Filled.Tune, "Adjust Points", nayara.statusInfoContainer, nayara.statusInfo) { haptics.tick(); onAdjustPoints() })
        }
    }

    Scaffold { innerPadding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = NayaraSpacing.ScreenMargin, vertical = NayaraSpacing.Xl),
            verticalArrangement = Arrangement.spacedBy(NayaraSpacing.Xl),
        ) {
            GreetingHero(user)

            LoyaltyLookupCard()

            Text(
                "Quick actions",
                style = MaterialTheme.typography.titleSmall,
                color = nayara.textSecondary,
                modifier = Modifier.padding(start = NayaraSpacing.Xs),
            )

            // 2-column tile grid.
            Column(verticalArrangement = Arrangement.spacedBy(NayaraSpacing.Md)) {
                actions.chunked(2).forEach { rowActions ->
                    Row(horizontalArrangement = Arrangement.spacedBy(NayaraSpacing.Md)) {
                        rowActions.forEach { action ->
                            QuickActionTile(action, Modifier.weight(1f))
                        }
                        if (rowActions.size == 1) Spacer(Modifier.weight(1f))
                    }
                }
            }

            AnimatedVisibility(
                visible = isAdmin,
                enter = fadeIn(tween(NayaraMotion.Base)) +
                    expandVertically(tween(NayaraMotion.Base, easing = NayaraMotion.Enter)),
                exit = fadeOut(tween(NayaraMotion.Fast)) +
                    shrinkVertically(tween(NayaraMotion.Fast, easing = NayaraMotion.Exit)),
            ) {
                AdminRow(onClick = { haptics.tick(); onAdmin() })
            }

            // Log out moved to the Account tab — Home is for doing work, not
            // leaving. Bottom padding so the last tile clears the tab bar.
            Spacer(Modifier.height(NayaraSpacing.Sm))
        }
    }
}

@Composable
private fun GreetingHero(user: UserDto) {
    val name = user.displayName ?: user.username ?: "there"
    val greeting = remember {
        when (LocalTime.now().hour) {
            in 5..11 -> "Good morning"
            in 12..16 -> "Good afternoon"
            else -> "Good evening"
        }
    }
    NayaraHeroCard {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Avatar(name = name, size = 52.dp, keySalt = "hero")
            Spacer(Modifier.width(NayaraSpacing.Lg))
            Column(Modifier.weight(1f)) {
                Text(
                    greeting,
                    style = MaterialTheme.typography.bodyMedium,
                    color = NayaraPalette.Navy100,
                )
                Spacer(Modifier.height(2.dp))
                Text(
                    name,
                    style = MaterialTheme.typography.headlineSmall,
                    fontWeight = FontWeight.Bold,
                    color = NayaraPalette.White,
                )
                Spacer(Modifier.height(NayaraSpacing.Sm))
                StatusChip(
                    label = user.role.replaceFirstChar { it.uppercase() },
                    tone = ChipTone.Info,
                    showDot = false,
                )
            }
        }
    }
}

@Composable
private fun QuickActionTile(action: QuickAction, modifier: Modifier = Modifier) {
    Card(
        onClick = action.onClick,
        modifier = modifier.height(98.dp),
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp, pressedElevation = 6.dp),
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(NayaraSpacing.Lg),
            verticalArrangement = Arrangement.SpaceBetween,
        ) {
            Box(
                modifier = Modifier
                    .size(44.dp)
                    .clip(CircleShape)
                    .background(action.container),
                contentAlignment = Alignment.Center,
            ) {
                Icon(action.icon, contentDescription = null, tint = action.tint, modifier = Modifier.size(22.dp))
            }
            Text(
                action.label,
                style = MaterialTheme.typography.titleSmall,
                fontWeight = FontWeight.SemiBold,
            )
        }
    }
}

@Composable
private fun AdminRow(onClick: () -> Unit) {
    Card(
        onClick = onClick,
        modifier = Modifier.fillMaxWidth(),
        elevation = CardDefaults.cardElevation(defaultElevation = 2.dp, pressedElevation = 6.dp),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(NayaraSpacing.Lg),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Box(
                modifier = Modifier
                    .size(44.dp)
                    .clip(CircleShape)
                    .background(MaterialTheme.nayara.bgSurfaceSunken),
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    Icons.Filled.AdminPanelSettings,
                    contentDescription = null,
                    tint = MaterialTheme.nayara.textPrimary,
                    modifier = Modifier.size(22.dp),
                )
            }
            Spacer(Modifier.width(NayaraSpacing.Lg))
            Column(Modifier.weight(1f)) {
                Text("Admin console", style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.SemiBold)
                Text(
                    "Reports, staff, pumps & settings",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.nayara.textSecondary,
                )
            }
            Icon(
                Icons.AutoMirrored.Filled.ArrowForward,
                contentDescription = null,
                tint = MaterialTheme.nayara.textTertiary,
                modifier = Modifier.size(20.dp),
            )
        }
    }
}
