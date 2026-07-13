@file:OptIn(ExperimentalMaterial3Api::class)

package com.acefuel.loyalty.ui.admin.users

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
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
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.PersonAdd
import androidx.compose.material.icons.filled.SearchOff
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ExtendedFloatingActionButton
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SheetValue
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import com.acefuel.loyalty.core.di.LocalContainer
import com.acefuel.loyalty.ui.designsystem.ActiveChip
import com.acefuel.loyalty.ui.designsystem.Avatar
import com.acefuel.loyalty.ui.designsystem.ChipTone
import com.acefuel.loyalty.ui.designsystem.ConfirmDialog
import com.acefuel.loyalty.ui.designsystem.EmptyState
import com.acefuel.loyalty.ui.designsystem.ErrorState
import com.acefuel.loyalty.ui.designsystem.FormField
import com.acefuel.loyalty.ui.designsystem.InlineErrorCard
import com.acefuel.loyalty.ui.designsystem.NayaraCard
import com.acefuel.loyalty.ui.designsystem.NayaraPullToRefresh
import com.acefuel.loyalty.ui.designsystem.NayaraSnackbarHost
import com.acefuel.loyalty.ui.designsystem.NayaraTopBar
import com.acefuel.loyalty.ui.designsystem.PasswordField
import com.acefuel.loyalty.ui.designsystem.SearchField
import com.acefuel.loyalty.ui.designsystem.SkeletonCard
import com.acefuel.loyalty.ui.designsystem.SkeletonList
import com.acefuel.loyalty.ui.designsystem.StatusChip
import com.acefuel.loyalty.ui.designsystem.rememberHaptics
import com.acefuel.loyalty.ui.designsystem.showError
import com.acefuel.loyalty.ui.designsystem.showSuccess
import com.acefuel.loyalty.ui.theme.NayaraButton
import com.acefuel.loyalty.ui.theme.NayaraOutlinedButton
import com.acefuel.loyalty.ui.theme.NayaraSpacing
import com.acefuel.loyalty.ui.theme.nayara

@Composable
fun AdminUsersScreen(onBack: () -> Unit) {
    val container = LocalContainer.current
    val repo = remember {
        UsersRepository(container.retrofit.create(UsersApi::class.java), container.json)
    }
    val vm: UsersViewModel = viewModel(factory = viewModelFactory { initializer { UsersViewModel(repo) } })
    val state by vm.state.collectAsStateWithLifecycle()

    val snackbar = remember { SnackbarHostState() }
    val haptics = rememberHaptics()

    LaunchedEffect(state.successMessage) {
        state.successMessage?.let {
            haptics.confirm()
            snackbar.showSuccess(it)
            vm.consumeSuccessMessage()
        }
    }
    LaunchedEffect(state.actionError) {
        state.actionError?.let {
            haptics.reject()
            snackbar.showError(it)
            vm.consumeActionError()
        }
    }

    Scaffold(
        topBar = { NayaraTopBar(title = "Users", onBack = onBack) },
        snackbarHost = { NayaraSnackbarHost(snackbar) },
        floatingActionButton = {
            ExtendedFloatingActionButton(
                text = { Text("Add User") },
                icon = { Icon(Icons.Filled.Add, contentDescription = null) },
                onClick = { vm.openCreate() },
            )
        },
    ) { innerPadding ->
        Column(Modifier.fillMaxSize().padding(innerPadding)) {
            // Pinned above the list so it stays reachable while scrolling.
            SearchField(
                value = state.query,
                onValueChange = vm::onQueryChange,
                placeholder = "Search by name, username, phone or email",
                modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp),
            )

            when {
                state.loading && state.users.isEmpty() && state.error == null ->
                    SkeletonList(Modifier.padding(horizontal = 16.dp), count = 8)

                state.error != null && state.users.isEmpty() ->
                    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        ErrorState(message = state.error!!, onRetry = vm::load)
                    }

                else -> {
                    val users = state.filteredUsers
                    NayaraPullToRefresh(
                        isRefreshing = state.refreshing,
                        onRefresh = vm::refresh,
                        modifier = Modifier.fillMaxSize(),
                    ) {
                        LazyColumn(
                            modifier = Modifier.fillMaxSize(),
                            contentPadding = PaddingValues(start = 16.dp, top = 8.dp, end = 16.dp, bottom = 112.dp),
                            verticalArrangement = Arrangement.spacedBy(12.dp),
                        ) {
                            when {
                                users.isEmpty() && state.query.isBlank() ->
                                    item(key = "empty") {
                                        EmptyState(
                                            title = "No users yet",
                                            message = "Users can sign in to the staff and admin apps.",
                                            icon = Icons.Filled.PersonAdd,
                                            actionLabel = "Add your first user",
                                            onAction = vm::openCreate,
                                        )
                                    }

                                users.isEmpty() ->
                                    item(key = "no-match") {
                                        EmptyState(
                                            title = "No matches",
                                            message = "No users matched that search.",
                                            icon = Icons.Filled.SearchOff,
                                        )
                                    }

                                else -> items(users, key = { "u-${it.id}" }) { user ->
                                    UserRow(
                                        user = user,
                                        onEdit = { vm.openEdit(user) },
                                        modifier = Modifier.animateItem(),
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    if (state.sheetOpen) {
        // Snapshot the prefill (re-captured when the GET :id refresh lands) to detect edits.
        val initialForm = remember(state.editingId, state.formLoading) { state.form }
        val dirty = !state.formLoading && state.form != initialForm
        GuardedSheet(dirty = dirty, onClose = vm::closeSheet) { requestClose ->
            UserFormSheet(state = state, vm = vm, onCancel = requestClose)
        }
    }
}

// ---------------------------------------------------------------------------
// Dismiss-guarded bottom sheet
// ---------------------------------------------------------------------------

/**
 * ModalBottomSheet that blocks swipe/scrim dismissal while [dirty] and asks
 * for confirmation instead, so half-filled forms aren't lost by accident.
 */
@Composable
private fun GuardedSheet(
    dirty: Boolean,
    onClose: () -> Unit,
    content: @Composable ColumnScope.(requestClose: () -> Unit) -> Unit,
) {
    val dirtyState = rememberUpdatedState(dirty)
    var confirmDiscard by remember { mutableStateOf(false) }
    val sheetState = rememberModalBottomSheetState(
        skipPartiallyExpanded = true,
        confirmValueChange = { value ->
            if (value == SheetValue.Hidden && dirtyState.value) {
                confirmDiscard = true
                false
            } else {
                true
            }
        },
    )
    // Route onDismissRequest through the dirty check too: the system back
    // gesture calls it directly, bypassing confirmValueChange.
    ModalBottomSheet(
        onDismissRequest = { if (dirtyState.value) confirmDiscard = true else onClose() },
        sheetState = sheetState,
    ) {
        content { if (dirtyState.value) confirmDiscard = true else onClose() }
    }
    if (confirmDiscard) {
        ConfirmDialog(
            title = "Discard changes?",
            text = "You have unsaved changes. Close without saving?",
            confirmLabel = "Discard",
            destructive = true,
            onConfirm = {
                confirmDiscard = false
                onClose()
            },
            onDismiss = { confirmDiscard = false },
        )
    }
}

// ---------------------------------------------------------------------------
// List row
// ---------------------------------------------------------------------------

@Composable
private fun UserRow(user: AdminUserDto, onEdit: () -> Unit, modifier: Modifier = Modifier) {
    NayaraCard(onClick = onEdit, modifier = modifier.fillMaxWidth()) {
        Row(
            modifier = Modifier.padding(NayaraSpacing.Lg),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(NayaraSpacing.Md),
        ) {
            Avatar(name = user.name ?: user.username)
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(
                    user.name ?: user.username ?: "User",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold,
                )
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
            Column(horizontalAlignment = Alignment.End, verticalArrangement = Arrangement.spacedBy(6.dp)) {
                RoleBadge(user.role)
                ActiveChip(user.active)
            }
            Icon(
                imageVector = Icons.AutoMirrored.Filled.KeyboardArrowRight,
                contentDescription = null,
                tint = MaterialTheme.nayara.textTertiary,
            )
        }
    }
}

@Composable
private fun RoleBadge(role: String) {
    val isAdmin = role.equals("admin", ignoreCase = true)
    StatusChip(
        label = if (isAdmin) "Admin" else "Staff",
        tone = if (isAdmin) ChipTone.Info else ChipTone.Neutral,
        showDot = false,
    )
}

// ---------------------------------------------------------------------------
// Create / edit sheet
// ---------------------------------------------------------------------------

@Composable
private fun UserFormSheet(state: AdminUsersUiState, vm: UsersViewModel, onCancel: () -> Unit) {
    val haptics = rememberHaptics()
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
            SkeletonCard(lines = 5)
            return@Column
        }

        val form = state.form
        val errors = state.fieldErrors

        state.formError?.let { InlineErrorCard(it) }

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
                    onClick = {
                        haptics.tick()
                        vm.onRole("admin")
                    },
                    label = { Text("Admin") },
                )
                FilterChip(
                    selected = form.role == "staff",
                    onClick = {
                        haptics.tick()
                        vm.onRole("staff")
                    },
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
                    onClick = {
                        haptics.tick()
                        vm.onActive(true)
                    },
                    label = { Text("Active") },
                )
                FilterChip(
                    selected = !form.active,
                    onClick = {
                        haptics.tick()
                        vm.onActive(false)
                    },
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

        PasswordField(
            value = form.password,
            onValueChange = vm::onPassword,
            label = "Password",
            errors = errors["password"],
            helper = if (state.isEditing) "Leave blank to keep the existing password." else null,
        )
        PasswordField(
            value = form.passwordConfirmation,
            onValueChange = vm::onPasswordConfirmation,
            label = "Password confirmation",
            errors = errors["password_confirmation"],
        )

        Spacer(Modifier.padding(top = 2.dp))
        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            NayaraOutlinedButton(
                onClick = onCancel,
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
private fun FieldError(errors: List<String>?) {
    if (!errors.isNullOrEmpty()) {
        Text(
            errors.joinToString(" "),
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.error,
        )
    }
}
