package com.acefuel.loyalty.ui.customers

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.AssistChip
import androidx.compose.material3.Card
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import com.acefuel.loyalty.core.di.LocalContainer
import com.acefuel.loyalty.core.network.dto.CustomerSummaryDto
import com.acefuel.loyalty.ui.theme.nayara

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CustomersScreen(onBack: () -> Unit, onOpenCustomer: (Long) -> Unit) {
    val container = LocalContainer.current
    val viewModel: CustomersViewModel = viewModel(
        factory = viewModelFactory { initializer { CustomersViewModel(container.staffRepository) } },
    )
    val state by viewModel.state.collectAsStateWithLifecycle()

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Customers") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                },
            )
        },
    ) { innerPadding ->
        Column(modifier = Modifier.fillMaxSize().padding(innerPadding).padding(horizontal = 16.dp)) {
            OutlinedTextField(
                value = state.query,
                onValueChange = viewModel::onQueryChange,
                label = { Text("Search by name or phone") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth().padding(vertical = 12.dp),
            )

            when {
                state.loading && state.customers.isEmpty() ->
                    Box(Modifier.fillMaxWidth().padding(32.dp), contentAlignment = Alignment.Center) {
                        CircularProgressIndicator()
                    }
                state.error != null ->
                    Text(state.error!!, color = MaterialTheme.colorScheme.error, modifier = Modifier.padding(8.dp))
                state.customers.isEmpty() ->
                    Text(
                        if (state.query.isBlank()) "No customers available yet." else "No customers matched that search.",
                        modifier = Modifier.padding(8.dp),
                        color = MaterialTheme.nayara.textSecondary,
                    )
                else -> LazyColumn(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    items(state.customers, key = { it.id }) { customer ->
                        CustomerRow(customer, onClick = { onOpenCustomer(customer.id) })
                    }
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun CustomerRow(customer: CustomerSummaryDto, onClick: () -> Unit) {
    Card(modifier = Modifier.fillMaxWidth(), onClick = onClick) {
        Column(modifier = Modifier.padding(16.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(customer.name ?: "Customer", style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.SemiBold)
                AssistChip(onClick = {}, enabled = false, label = { Text(if (customer.active) "Active" else "Inactive") })
            }
            customer.phoneNumber?.let { Text("+91 $it", style = MaterialTheme.typography.bodySmall) }
            val vehicles = if (customer.vehicleNumbers.isEmpty()) "No vehicles on file" else customer.vehicleNumbers.joinToString(", ")
            Text(vehicles, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.nayara.textSecondary)
            Spacer(Modifier.height(4.dp))
            Text("${customer.totalPoints} pts", style = MaterialTheme.typography.labelLarge, color = MaterialTheme.nayara.textBrand)
        }
    }
}
