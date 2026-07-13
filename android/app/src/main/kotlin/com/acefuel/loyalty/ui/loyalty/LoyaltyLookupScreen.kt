package com.acefuel.loyalty.ui.loyalty

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.animateIntAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Login
import androidx.compose.material.icons.filled.Logout
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import com.acefuel.loyalty.R
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import com.acefuel.loyalty.core.di.LocalContainer
import com.acefuel.loyalty.core.network.dto.LoyaltyResponse
import com.acefuel.loyalty.ui.theme.NayaraButton
import com.acefuel.loyalty.ui.theme.NayaraHeroCard
import com.acefuel.loyalty.ui.theme.NayaraPalette
import com.acefuel.loyalty.ui.theme.nayara

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun LoyaltyLookupScreen(
    isLoggedIn: Boolean,
    onStaffAccess: () -> Unit,
) {
    val container = LocalContainer.current
    val viewModel: LoyaltyViewModel = viewModel(
        factory = viewModelFactory { initializer { LoyaltyViewModel(container.loyaltyRepository) } },
    )
    val state by viewModel.state.collectAsStateWithLifecycle()

    var phone by rememberSaveable { mutableStateOf("") }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Ace Fuel Loyalty") },
                actions = {
                    TextButton(onClick = onStaffAccess) {
                        Icon(
                            imageVector = if (isLoggedIn) Icons.Filled.Logout else Icons.Filled.Login,
                            contentDescription = null,
                        )
                        Spacer(Modifier.height(0.dp))
                        Text(" " + stringResource(if (isLoggedIn) R.string.staff_home else R.string.staff_login))
                    }
                },
            )
        },
    ) { innerPadding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 20.dp, vertical = 16.dp),
        ) {
            Text(
                text = stringResource(R.string.loyalty_title),
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.SemiBold,
            )
            Spacer(Modifier.height(4.dp))
            Text(
                text = stringResource(R.string.loyalty_subtitle),
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.nayara.textSecondary,
            )
            Spacer(Modifier.height(20.dp))

            OutlinedTextField(
                value = phone,
                onValueChange = { input -> phone = input.filter(Char::isDigit).take(10) },
                label = { Text(stringResource(R.string.loyalty_phone_label)) },
                prefix = { Text("+91 ") },
                singleLine = true,
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Phone),
                modifier = Modifier.fillMaxWidth(),
            )
            Spacer(Modifier.height(16.dp))

            NayaraButton(
                onClick = { viewModel.lookup(phone) },
                enabled = phone.length == 10,
                loading = state is LoyaltyUiState.Loading,
                modifier = Modifier.fillMaxWidth(),
            ) {
                Text(stringResource(R.string.loyalty_check_points))
            }

            Spacer(Modifier.height(20.dp))

            when (val s = state) {
                is LoyaltyUiState.Error -> ErrorCard(s.message)
                is LoyaltyUiState.Success -> {
                    if (s.offline) {
                        OfflineBanner(s.fetchedAtMillis)
                        Spacer(Modifier.height(12.dp))
                    }
                    LoyaltyResult(s.data)
                }
                else -> Unit
            }
        }
    }
}

@Composable
private fun ErrorCard(message: String) {
    Card(
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.errorContainer),
        modifier = Modifier.fillMaxWidth(),
    ) {
        Text(
            text = message,
            color = MaterialTheme.colorScheme.onErrorContainer,
            modifier = Modifier.padding(16.dp),
        )
    }
}

@Composable
private fun OfflineBanner(fetchedAtMillis: Long?) {
    val stamp = fetchedAtMillis?.takeIf { it > 0 }?.let {
        java.text.SimpleDateFormat("dd MMM yyyy · hh:mm a", java.util.Locale.getDefault())
            .format(java.util.Date(it))
    }
    val offlineText = stringResource(R.string.loyalty_offline)
    val lastUpdated = if (stamp != null) stringResource(R.string.loyalty_last_updated, stamp) else null
    Card(
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
        modifier = Modifier.fillMaxWidth(),
    ) {
        Text(
            text = offlineText + (lastUpdated?.let { "\n$it" } ?: ""),
            modifier = Modifier.padding(14.dp),
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.nayara.textSecondary,
        )
    }
}

@Composable
private fun LoyaltyResult(data: LoyaltyResponse) {
    Column(modifier = Modifier.fillMaxWidth()) {
        NayaraHeroCard(modifier = Modifier.fillMaxWidth()) {
            Column(
                modifier = Modifier.fillMaxWidth(),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Text(
                    text = stringResource(R.string.loyalty_total_points),
                    style = MaterialTheme.typography.labelLarge,
                    color = NayaraPalette.Navy200,
                )
                AnimatedPoints(target = data.totalPoints)
                Spacer(Modifier.height(8.dp))
                Text(
                    text = statusLine(data),
                    style = MaterialTheme.typography.bodyMedium,
                    color = NayaraPalette.Navy100,
                )
            }
        }

        Spacer(Modifier.height(16.dp))
        data.customer.name?.let {
            Text(it, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
        }
        data.customer.phoneNumber?.let {
            Text("Phone: $it", style = MaterialTheme.typography.bodySmall)
        }

        Spacer(Modifier.height(16.dp))
        Text(stringResource(if (data.fullHistory) R.string.loyalty_activities_all else R.string.loyalty_activities_recent),
            style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.SemiBold)
        Spacer(Modifier.height(8.dp))

        if (data.activities.isEmpty()) {
            Text(stringResource(R.string.loyalty_no_activity), style = MaterialTheme.typography.bodyMedium)
        } else {
            data.activities.forEach { activity ->
                ActivityRow(activity)
                Spacer(Modifier.height(8.dp))
            }
        }
    }
}

@Composable
private fun AnimatedPoints(target: Int) {
    var started by remember { mutableStateOf(false) }
    val value by animateIntAsState(
        targetValue = if (started) target else 0,
        animationSpec = tween(durationMillis = 1100),
        label = "points-count-up",
    )
    LaunchedEffect(target) { started = true }
    Text(
        text = value.toString(),
        style = MaterialTheme.typography.displayMedium,
        fontWeight = FontWeight.Bold,
        color = NayaraPalette.White,
    )
}

@Composable
private fun ActivityRow(activity: com.acefuel.loyalty.core.network.dto.LoyaltyActivityDto) {
    var expanded by remember { mutableStateOf(false) }
    Card(
        modifier = Modifier.fillMaxWidth(),
        onClick = { expanded = !expanded },
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
            ) {
                Text(formatDate(activity.createdAt), style = MaterialTheme.typography.bodyMedium)
                Text(
                    text = if (activity.points >= 0) "+${activity.points}" else "${activity.points}",
                    fontWeight = FontWeight.Bold,
                    color = if (activity.points >= 0) {
                        MaterialTheme.nayara.statusSuccessText
                    } else {
                        MaterialTheme.nayara.textPrimary
                    },
                )
            }
            AnimatedVisibility(visible = expanded) {
                Column {
                    Spacer(Modifier.height(8.dp))
                    activity.fuelType?.let { Text("Fuel: ${it.replaceFirstChar(Char::uppercase)}") }
                    Text("Vehicle: ${activity.vehicleNumber ?: "N/A"}")
                    Text("Fuel Amount: ${activity.fuelAmount?.let { "₹%.2f".format(it) } ?: "N/A"}")
                }
            }
        }
    }
}

@Composable
private fun statusLine(data: LoyaltyResponse): String = when {
    data.rewardsPaused -> stringResource(R.string.loyalty_status_paused)
    data.rewardsUnlocked ->
        stringResource(R.string.loyalty_status_unlocked, data.maxRedeemablePoints, data.minimumRedeemablePoints)
    else ->
        stringResource(R.string.loyalty_status_locked, data.pointsUntilRedeemable, data.minimumRedeemablePoints)
}

private fun formatDate(iso: String): String = runCatching {
    val dt = java.time.OffsetDateTime.parse(iso)
    dt.format(java.time.format.DateTimeFormatter.ofPattern("dd MMM yyyy"))
}.getOrDefault(iso)
