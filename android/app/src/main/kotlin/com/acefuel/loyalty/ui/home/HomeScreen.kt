package com.acefuel.loyalty.ui.home

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Card
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.acefuel.loyalty.core.network.dto.UserDto
import com.acefuel.loyalty.ui.theme.NayaraButton
import com.acefuel.loyalty.ui.theme.NayaraOutlinedButton
import com.acefuel.loyalty.ui.theme.NayaraTonalButton
import com.acefuel.loyalty.ui.theme.nayara

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HomeScreen(
    user: UserDto,
    onNewTransaction: () -> Unit,
    onCustomers: () -> Unit,
    onRedeem: () -> Unit,
    onAdjustPoints: () -> Unit,
    onAdmin: () -> Unit,
    onLogout: () -> Unit,
) {
    Scaffold(
        topBar = { TopAppBar(title = { Text("Staff Home") }) },
    ) { innerPadding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
                .padding(24.dp),
        ) {
            Card(modifier = Modifier.fillMaxWidth()) {
                Column(modifier = Modifier.padding(20.dp)) {
                    Text(
                        user.displayName ?: user.username ?: "User",
                        style = MaterialTheme.typography.titleLarge,
                        fontWeight = FontWeight.SemiBold,
                    )
                    Spacer(Modifier.height(4.dp))
                    Text(
                        text = user.role.replaceFirstChar { it.uppercase() },
                        style = MaterialTheme.typography.labelLarge,
                        color = MaterialTheme.colorScheme.primary,
                    )
                    user.displayPhoneNumber?.let {
                        Spacer(Modifier.height(8.dp))
                        Text(it, style = MaterialTheme.typography.bodyMedium)
                    }
                }
            }

            Spacer(Modifier.height(24.dp))
            NayaraButton(onClick = onNewTransaction, modifier = Modifier.fillMaxWidth()) {
                Text("New Transaction")
            }
            Spacer(Modifier.height(12.dp))
            NayaraTonalButton(onClick = onCustomers, modifier = Modifier.fillMaxWidth()) {
                Text("Customers")
            }
            Spacer(Modifier.height(12.dp))
            NayaraTonalButton(onClick = onRedeem, modifier = Modifier.fillMaxWidth()) {
                Text("Redeem Points")
            }
            if (user.role == "admin") {
                Spacer(Modifier.height(12.dp))
                NayaraTonalButton(onClick = onAdjustPoints, modifier = Modifier.fillMaxWidth()) {
                    Text("Adjust Points")
                }
                Spacer(Modifier.height(12.dp))
                NayaraButton(onClick = onAdmin, modifier = Modifier.fillMaxWidth()) {
                    Text("Admin")
                }
            }

            Spacer(Modifier.height(24.dp))
            NayaraOutlinedButton(onClick = onLogout, modifier = Modifier.fillMaxWidth()) {
                Text("Log out")
            }
        }
    }
}
