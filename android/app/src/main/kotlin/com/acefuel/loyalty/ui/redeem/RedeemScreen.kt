package com.acefuel.loyalty.ui.redeem

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
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ExposedDropdownMenuBox
import androidx.compose.material3.ExposedDropdownMenuDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.MenuAnchorType
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import com.acefuel.loyalty.core.di.LocalContainer
import com.acefuel.loyalty.core.network.dto.StaffCustomerDto
import com.acefuel.loyalty.ui.theme.NayaraButton
import com.acefuel.loyalty.ui.theme.nayara

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun RedeemScreen(onBack: () -> Unit) {
    val container = LocalContainer.current
    val viewModel: RedeemViewModel = viewModel(
        factory = viewModelFactory { initializer { RedeemViewModel(container.staffRepository) } },
    )
    val state by viewModel.state.collectAsStateWithLifecycle()
    var phone by rememberSaveable { mutableStateOf("") }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Redeem Points") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
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
            Row(verticalAlignment = androidx.compose.ui.Alignment.Bottom) {
                OutlinedTextField(
                    value = phone,
                    onValueChange = { phone = it.filter(Char::isDigit).take(10) },
                    label = { Text("Phone number") },
                    prefix = { Text("+91 ") },
                    singleLine = true,
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Phone),
                    modifier = Modifier.weight(1f),
                )
                Spacer(Modifier.width(12.dp))
                NayaraButton(
                    onClick = { viewModel.lookup(phone) },
                    enabled = phone.length == 10,
                    loading = state.lookupLoading,
                ) {
                    Text("Look Up")
                }
            }

            state.lookupMessage?.let {
                Spacer(Modifier.height(12.dp))
                Text(it, color = MaterialTheme.colorScheme.error)
            }

            val customer = state.customer
            if (customer != null) {
                Spacer(Modifier.height(20.dp))
                CustomerCard(customer)

                Spacer(Modifier.height(16.dp))
                when {
                    customer.rewardsPaused -> BlockedNote(
                        "Rewards are paused for this customer. Resume rewards to redeem points.",
                    )
                    state.pointOptions.isEmpty() -> BlockedNote(
                        "This customer does not have enough redeemable points yet. " +
                            "Minimum redemption for this customer is ${customer.minimumRedeemablePoints} points.",
                    )
                    else -> RedeemForm(state, customer, viewModel)
                }
            }

            state.successMessage?.let {
                Spacer(Modifier.height(16.dp))
                Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.nayara.statusSuccessContainer)) {
                    Text(
                        it,
                        modifier = Modifier.padding(16.dp),
                        color = MaterialTheme.nayara.statusOnSuccessContainer,
                    )
                }
            }
        }
    }
}

@Composable
private fun CustomerCard(customer: StaffCustomerDto) {
    Card(modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(20.dp)) {
            Text(customer.name ?: "Customer", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
            Text(
                "${customer.statusLabel} · ${customer.rewardsStatusLabel}",
                style = MaterialTheme.typography.labelMedium,
                color = MaterialTheme.nayara.textSecondary,
            )
            customer.phoneNumber?.let { Text("+91 $it", style = MaterialTheme.typography.bodySmall) }
            Spacer(Modifier.height(12.dp))
            Text("${customer.totalPoints}", style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold)
            Text("Available points", style = MaterialTheme.typography.labelMedium)
            Spacer(Modifier.height(12.dp))
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                Stat("Minimum", "${customer.minimumRedeemablePoints}")
                Stat("Max redeemable", "${customer.maxRedeemablePoints}")
                Stat("Vehicles", "${customer.vehicles.size}")
            }
            customer.maxRedeemableCashReward?.let {
                Spacer(Modifier.height(8.dp))
                Text("Max cash reward: ₹%.2f".format(it), style = MaterialTheme.typography.bodySmall)
            }
        }
    }
}

@Composable
private fun Stat(label: String, value: String) {
    Column {
        Text(value, style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.SemiBold)
        Text(label, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.nayara.textSecondary)
    }
}

@Composable
private fun BlockedNote(message: String) {
    // Not an error — the customer simply is not eligible yet (warning tokens).
    Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.nayara.statusWarningContainer)) {
        Text(message, modifier = Modifier.padding(16.dp), color = MaterialTheme.nayara.statusOnWarningContainer)
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun RedeemForm(state: RedeemUiState, customer: StaffCustomerDto, viewModel: RedeemViewModel) {
    var expanded by remember { mutableStateOf(false) }
    val options = state.pointOptions

    fun label(points: Int): String {
        val cash = customer.cashValuePerPoint
        return if (cash != null && cash > 0) "$points pts (₹%.2f)".format(points * cash) else "$points pts"
    }

    ExposedDropdownMenuBox(expanded = expanded, onExpandedChange = { expanded = it }) {
        OutlinedTextField(
            value = state.selectedPoints?.let { label(it) } ?: "",
            onValueChange = {},
            readOnly = true,
            label = { Text("Points to redeem") },
            trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = expanded) },
            modifier = Modifier
                .fillMaxWidth()
                .menuAnchor(MenuAnchorType.PrimaryNotEditable),
        )
        ExposedDropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
            options.forEach { points ->
                DropdownMenuItem(
                    text = { Text(label(points)) },
                    onClick = {
                        viewModel.selectPoints(points)
                        expanded = false
                    },
                )
            }
        }
    }
    Spacer(Modifier.height(4.dp))
    Text(
        "Points can only be redeemed in multiples of ${customer.redemptionIncrement}.",
        style = MaterialTheme.typography.bodySmall,
        color = MaterialTheme.nayara.textSecondary,
    )

    state.redeemError?.let {
        Spacer(Modifier.height(12.dp))
        Text(it, color = MaterialTheme.colorScheme.error)
    }

    Spacer(Modifier.height(16.dp))
    NayaraButton(
        onClick = { viewModel.redeem() },
        enabled = state.canRedeem,
        loading = state.redeeming,
        modifier = Modifier.fillMaxWidth(),
    ) {
        Text("Redeem Points")
    }
}
