@file:OptIn(ExperimentalMaterial3Api::class)

package com.acefuel.loyalty.ui.admin.users

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Add
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ExtendedFloatingActionButton
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import com.acefuel.loyalty.core.di.LocalContainer
import com.acefuel.loyalty.ui.theme.NayaraButton
import com.acefuel.loyalty.ui.theme.NayaraOutlinedButton
import com.acefuel.loyalty.ui.theme.nayara

@Composable
fun AdminUsersScreen(onBack: () -> Unit) {
    val container = LocalContainer.current
    val repo = remember {
        UsersRepository(container.retrofit.create(UsersApi::class.java), container.json)
    }
    val vm: UsersViewModel = viewModel(factory = viewModelFactory { initializer { UsersViewModel(repo) } })
    val state by vm.state.collectAsStateWithLifecycle()

    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Users") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                },
            )
        },
        floatingActionButton = {
            ExtendedFloatingActionButton(
                text = { Text("Add User") },
                icon = { Icon(Icons.Filled.Add, contentDescription = null) },
                onClick = { vm.openCreate() },
            )
        },
    ) { innerPadding ->
        when {
            state.loading && state.users.isEmpty() && state.error == null ->
                Box(Modifier.fillMaxSize().padding(innerPadding), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator()
                }

            else -> {
                val users = state.filteredUsers
                LazyColumn(
                    modifier = Modifier.fillMaxSize().padding(innerPadding),
                    contentPadding = PaddingValues(16.dp),
                    verticalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    item(key = "search") {
                        OutlinedTextField(
                            value = state.query,
                            onValueChange = vm::onQueryChange,
                            label = { Text("Search by name, username, phone or email") },
                            singleLine = true,
                            modifier = Modifier.fillMaxWidth(),
                        )
                    }

                    state.error?.let { message ->
                        item(key = "load-error") { ErrorCard(message) }
                    }

                    when {
                        users.isEmpty() && state.error == null ->
                            item(key = "empty") {
                                Text(
                                    if (state.query.isBlank()) {
                                        "No users available yet."
                                    } else {
                                        "No users matched that search."
                                    },
                                    style = MaterialTheme.typography.bodyMedium,
                                    color = MaterialTheme.nayara.textSecondary,
                                )
                            }

                        else -> items(users, key = { "u-${it.id}" }) { user ->
                            UserRow(user = user, onEdit = { vm.openEdit(user) })
                        }
                    }
                }
            }
        }
    }

    if (state.sheetOpen) {
        ModalBottomSheet(onDismissRequest = { vm.closeSheet() }, sheetState = sheetState) {
            UserFormSheet(state = state, vm = vm)
        }
    }
}

// ---------------------------------------------------------------------------
// List row
// ---------------------------------------------------------------------------

@Composable
private fun UserRow(user: AdminUserDto, onEdit: () -> Unit) {
    Card(modifier = Modifier.fillMaxWidth(), onClick = onEdit) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    user.name ?: user.username ?: "User",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold,
                    modifier = Modifier.weight(1f),
                )
                Row(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalAlignment = Alignment.CenterVertically) {
                    RoleBadge(user.role)
                    StatusPill(user.active)
                }
            }
            Text(
                user.phoneNumber?.takeIf { it.isNotBlank() }?.let { "+91 $it" } ?: "Mobile not set",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.nayara.textSecondary,
            )
            Text(
                user.email?.takeIf { it.isNotBlank() } ?: "Email not set",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.nayara.textTertiary,
            )
        }
    }
}

@Composable
private fun RoleBadge(role: String) {
    val isAdmin = role.equals("admin", ignoreCase = true)
    val container = if (isAdmin) MaterialTheme.nayara.statusInfoContainer else MaterialTheme.nayara.bgSurfaceSunken
    val content = if (isAdmin) MaterialTheme.nayara.statusOnInfoContainer else MaterialTheme.nayara.textSecondary
    Surface(color = container, shape = MaterialTheme.shapes.small) {
        Text(
            if (isAdmin) "Admin" else "Staff",
            modifier = Modifier.padding(horizontal = 10.dp, vertical = 4.dp),
            style = MaterialTheme.typography.labelMedium,
            color = content,
        )
    }
}

@Composable
private fun StatusPill(active: Boolean) {
    val container = if (active) MaterialTheme.nayara.statusSuccessContainer else MaterialTheme.nayara.bgSurfaceSunken
    val content = if (active) MaterialTheme.nayara.statusOnSuccessContainer else MaterialTheme.nayara.textSecondary
    Surface(color = container, shape = MaterialTheme.shapes.small) {
        Text(
            if (active) "Active" else "Inactive",
            modifier = Modifier.padding(horizontal = 10.dp, vertical = 4.dp),
            style = MaterialTheme.typography.labelMedium,
            color = content,
        )
    }
}

// ---------------------------------------------------------------------------
// Create / edit sheet
// ---------------------------------------------------------------------------

@Composable
private fun UserFormSheet(state: AdminUsersUiState, vm: UsersViewModel) {
    val scroll = rememberScrollState()
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .verticalScroll(scroll)
            .imePadding()
            .navigationBarsPadding()
            .padding(horizontal = 20.dp)
            .padding(bottom = 24.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Text(
            if (state.isEditing) "Edit User" else "Add User",
            style = MaterialTheme.typography.titleLarge,
            fontWeight = FontWeight.Bold,
        )

        if (state.formLoading) {
            Box(Modifier.fillMaxWidth().padding(32.dp), contentAlignment = Alignment.Center) {
                CircularProgressIndicator()
            }
            return@Column
        }

        val form = state.form
        val errors = state.fieldErrors

        state.formError?.let { ErrorCard(it) }

        FormField(
            value = form.name,
            onValueChange = vm::onName,
            label = "Name*",
            errors = errors["name"],
        )
        FormField(
            value = form.username,
            onValueChange = vm::onUsername,
            label = "Username (Login)*",
            errors = errors["username"],
            helper = "This is the login username shown on the sign-in page.",
        )
        FormField(
            value = form.phone,
            onValueChange = vm::onPhone,
            label = "Mobile Number*",
            errors = errors["phone_number"],
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Phone),
            prefix = { Text("+91 ") },
        )
        FormField(
            value = form.email,
            onValueChange = vm::onEmail,
            label = "Email (Optional)",
            errors = errors["email"],
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email),
        )

        // Role
        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Text("Role", style = MaterialTheme.typography.labelLarge)
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                FilterChip(
                    selected = form.role == "admin",
                    onClick = { vm.onRole("admin") },
                    label = { Text("Admin") },
                )
                FilterChip(
                    selected = form.role == "staff",
                    onClick = { vm.onRole("staff") },
                    label = { Text("Staff") },
                )
            }
            FieldError(errors["role"])
        }

        // Access status
        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Text("Access Status", style = MaterialTheme.typography.labelLarge)
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                FilterChip(
                    selected = form.active,
                    onClick = { vm.onActive(true) },
                    label = { Text("Active") },
                )
                FilterChip(
                    selected = !form.active,
                    onClick = { vm.onActive(false) },
                    label = { Text("Inactive") },
                )
            }
            Text(
                "Inactive users stay in history but cannot sign in until reactivated.",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.nayara.textSecondary,
            )
            FieldError(errors["active"])
        }

        FormField(
            value = form.password,
            onValueChange = vm::onPassword,
            label = "Password",
            errors = errors["password"],
            helper = if (state.isEditing) "Leave blank to keep the existing password." else null,
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password),
            visualTransformation = PasswordVisualTransformation(),
        )
        FormField(
            value = form.passwordConfirmation,
            onValueChange = vm::onPasswordConfirmation,
            label = "Password confirmation",
            errors = errors["password_confirmation"],
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password),
            visualTransformation = PasswordVisualTransformation(),
        )

        Spacer(Modifier.padding(top = 2.dp))
        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            NayaraOutlinedButton(
                onClick = { vm.closeSheet() },
                enabled = !state.saving,
                modifier = Modifier.weight(1f),
            ) { Text("Cancel") }
            NayaraButton(
                onClick = { vm.submit() },
                loading = state.saving,
                enabled = !state.saving,
                modifier = Modifier.weight(1f),
            ) { Text(if (state.isEditing) "Save Changes" else "Create User") }
        }
    }
}

@Composable
private fun FormField(
    value: String,
    onValueChange: (String) -> Unit,
    label: String,
    errors: List<String>?,
    helper: String? = null,
    keyboardOptions: KeyboardOptions = KeyboardOptions.Default,
    visualTransformation: VisualTransformation = VisualTransformation.None,
    prefix: (@Composable () -> Unit)? = null,
) {
    val supporting: (@Composable () -> Unit)? = if (!errors.isNullOrEmpty()) {
        { Text(errors.joinToString(" "), color = MaterialTheme.colorScheme.error) }
    } else if (helper != null) {
        { Text(helper) }
    } else {
        null
    }
    OutlinedTextField(
        value = value,
        onValueChange = onValueChange,
        label = { Text(label) },
        singleLine = true,
        isError = !errors.isNullOrEmpty(),
        keyboardOptions = keyboardOptions,
        visualTransformation = visualTransformation,
        prefix = prefix,
        supportingText = supporting,
        modifier = Modifier.fillMaxWidth(),
    )
}

@Composable
private fun FieldError(errors: List<String>?) {
    if (!errors.isNullOrEmpty()) {
        Text(
            errors.joinToString(" "),
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.error,
        )
    }
}

@Composable
private fun ErrorCard(message: String) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.errorContainer),
    ) {
        Text(
            message,
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onErrorContainer,
            modifier = Modifier.padding(14.dp),
        )
    }
}
