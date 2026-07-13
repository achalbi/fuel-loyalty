package com.acefuel.loyalty.ui.admin

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material3.Card
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.acefuel.loyalty.ui.theme.nayara

/** An admin feature and the nav route that opens it. Routes are registered in AppRoot. */
data class AdminFeature(val label: String, val route: String, val group: String)

val ADMIN_FEATURES: List<AdminFeature> = listOf(
    AdminFeature("Dashboard", "admin_dashboard", "Admin"),
    AdminFeature("Transactions", "admin_transactions", "Admin"),
    AdminFeature("Users", "admin_users", "Admin"),
    AdminFeature("Fuel Types", "admin_fueltypes", "App Management"),
    AdminFeature("Pumps", "admin_pumps", "App Management"),
    AdminFeature("Vehicle Types", "admin_vehicletypes", "App Management"),
    AdminFeature("Reward Rates", "admin_rewardrates", "App Management"),
    AdminFeature("Theme", "admin_theme", "App Management"),
    AdminFeature("Notifications", "admin_schedules", "App Management"),
    AdminFeature("Staff", "admin_staff", "Attendance"),
    AdminFeature("Shifts", "admin_shifts", "Attendance"),
    AdminFeature("Cycles", "admin_cycles", "Attendance"),
    AdminFeature("Attendance", "admin_attendance", "Attendance"),
)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AdminMenuScreen(onBack: () -> Unit, onOpen: (String) -> Unit) {
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Admin") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                },
            )
        },
    ) { innerPadding ->
        LazyColumn(
            modifier = Modifier.fillMaxSize().padding(innerPadding).padding(horizontal = 16.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
            contentPadding = androidx.compose.foundation.layout.PaddingValues(vertical = 12.dp),
        ) {
            ADMIN_FEATURES.groupBy { it.group }.forEach { (group, features) ->
                item(key = "hdr-$group") {
                    Text(
                        group,
                        style = MaterialTheme.typography.labelMedium,
                        color = MaterialTheme.nayara.textSecondary,
                        modifier = Modifier.padding(top = 12.dp, bottom = 4.dp),
                    )
                }
                items(features.size, key = { "feat-${features[it].route}" }) { idx ->
                    val f = features[idx]
                    Card(modifier = Modifier.fillMaxWidth(), onClick = { onOpen(f.route) }) {
                        androidx.compose.foundation.layout.Row(
                            modifier = Modifier.fillMaxWidth().padding(18.dp),
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.SpaceBetween,
                        ) {
                            Text(f.label, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
                            Icon(
                                Icons.AutoMirrored.Filled.KeyboardArrowRight,
                                contentDescription = null,
                                tint = MaterialTheme.nayara.textTertiary,
                            )
                        }
                    }
                }
            }
            item { Spacer(Modifier.height(16.dp)) }
        }
    }
}
