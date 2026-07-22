package com.acefuel.loyalty.ui.admin.ops

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ReceiptLong
import androidx.compose.material.icons.filled.Badge
import androidx.compose.material.icons.filled.BarChart
import androidx.compose.material.icons.filled.Campaign
import androidx.compose.material.icons.filled.EventRepeat
import androidx.compose.material.icons.filled.FactCheck
import androidx.compose.material.icons.filled.Redeem
import androidx.compose.material.icons.filled.Schedule
import androidx.compose.material.icons.filled.Tune
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import com.acefuel.loyalty.ui.designsystem.QuickAction
import com.acefuel.loyalty.ui.designsystem.NayaraListRow
import com.acefuel.loyalty.ui.designsystem.SectionHeader
import com.acefuel.loyalty.ui.designsystem.rememberHaptics
import com.acefuel.loyalty.ui.theme.NayaraSpacing
import com.acefuel.loyalty.ui.theme.nayara

// ============================================================================
// Ops — admin tab 3 of 4. The "do something" half of admin.
//
// The web console scatters these across three sidebar groups and the old
// AdminMenuScreen buried each one behind a menu tap. The four things an admin
// actually *does* between shifts (record attendance, adjust a balance, redeem
// at the counter, broadcast a notice) are quick actions here — one tap from
// the tab, where they used to be three.
//
// Below the actions sit the ops surfaces themselves: attendance runs, the shift
// plumbing that feeds them, and the read-only transaction log.
//
// TODO (needs backend): the prototype's live widgets — "staff on shift, 0 of 5
// recorded", "Pump 3 · Nozzle 2 inactive" — are not here because nothing serves
// them. There is no roster-for-today endpoint; `GET /api/v1/admin/attendance_runs`
// lists saved runs, not open windows. Surfacing an unrecorded shift on this tab
// needs a small server addition (see ADMIN_NATIVE_DIRECTIONS.md §4). Until then
// this tab routes, it doesn't alert — which is precisely Option A's known limit.
// ============================================================================

@Composable
fun AdminOpsScreen(
    onAttendance: () -> Unit,
    onAdjustPoints: () -> Unit,
    onRedeem: () -> Unit,
    onNotifications: () -> Unit,
    onStaff: () -> Unit,
    onShifts: () -> Unit,
    onCycles: () -> Unit,
    onTransactions: () -> Unit,
    onReports: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val nayara = MaterialTheme.nayara
    val haptics = rememberHaptics()

    Column(
        modifier = modifier
            .fillMaxSize()
            // No TopAppBar on this screen, so it owns the status-bar inset
            // itself — the shell deliberately doesn't apply a top inset.
            .statusBarsPadding()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = NayaraSpacing.ScreenMargin),
    ) {
        Spacer(Modifier.height(NayaraSpacing.Xl))
        Text(
            text = "Operations",
            style = MaterialTheme.typography.headlineSmall,
            fontWeight = FontWeight.Bold,
            color = nayara.textPrimary,
        )
        Spacer(Modifier.height(NayaraSpacing.Xs))
        Text(
            text = "Attendance, shifts, and the day's activity.",
            style = MaterialTheme.typography.bodyMedium,
            color = nayara.textSecondary,
        )

        SectionHeader("Quick actions")
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(NayaraSpacing.Gutter),
        ) {
            QuickAction(
                label = "Attendance",
                icon = Icons.Filled.FactCheck,
                onClick = onAttendance,
                modifier = Modifier.weight(1f),
            )
            QuickAction(
                label = "Adjust",
                icon = Icons.Filled.Tune,
                onClick = onAdjustPoints,
                modifier = Modifier.weight(1f),
            )
            QuickAction(
                label = "Redeem",
                icon = Icons.Filled.Redeem,
                onClick = onRedeem,
                modifier = Modifier.weight(1f),
            )
            QuickAction(
                label = "Notify",
                icon = Icons.Filled.Campaign,
                onClick = onNotifications,
                modifier = Modifier.weight(1f),
            )
        }

        SectionHeader("Attendance")
        NayaraListRow(
            title = "Attendance runs",
            subtitle = "Record a shift, review or invalidate past runs",
            leadingIcon = Icons.Filled.FactCheck,
            leadingTint = nayara.actionPrimary,
            onClick = { haptics.tick(); onAttendance() },
        )
        NayaraListRow(
            title = "Staff",
            subtitle = "Profiles and shift assignment",
            leadingIcon = Icons.Filled.Badge,
            leadingTint = nayara.accentDefault,
            onClick = { haptics.tick(); onStaff() },
        )
        NayaraListRow(
            title = "Shifts",
            subtitle = "Start times and durations",
            leadingIcon = Icons.Filled.Schedule,
            leadingTint = nayara.accentDefault,
            onClick = { haptics.tick(); onShifts() },
        )
        NayaraListRow(
            title = "Cycles",
            subtitle = "Rotation sequences the roster loads from",
            leadingIcon = Icons.Filled.EventRepeat,
            leadingTint = nayara.accentDefault,
            onClick = { haptics.tick(); onCycles() },
        )

        SectionHeader("Activity")
        NayaraListRow(
            title = "Transactions",
            subtitle = "Read-only log · filter by date and amount",
            leadingIcon = Icons.AutoMirrored.Filled.ReceiptLong,
            leadingTint = nayara.actionPrimary,
            onClick = { haptics.tick(); onTransactions() },
        )
        NayaraListRow(
            title = "Reports",
            subtitle = "Litres, discount & gifts by vehicle / transporter / driver",
            leadingIcon = Icons.Filled.BarChart,
            leadingTint = nayara.accentDefault,
            onClick = { haptics.tick(); onReports() },
        )

        Spacer(Modifier.height(NayaraSpacing.Xxl))
    }
}
