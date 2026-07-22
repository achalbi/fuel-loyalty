@file:OptIn(ExperimentalMaterial3Api::class)

package com.acefuel.loyalty.ui.admin.users

import android.Manifest
import android.content.Context
import android.content.Intent
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
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
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Badge
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.PersonAdd
import androidx.compose.material.icons.filled.PhotoCamera
import androidx.compose.material.icons.filled.PhotoLibrary
import androidx.compose.material.icons.filled.SearchOff
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
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
import androidx.compose.material3.TextButton
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
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import coil.compose.AsyncImage
import com.google.accompanist.permissions.ExperimentalPermissionsApi
import com.google.accompanist.permissions.isGranted
import com.google.accompanist.permissions.rememberPermissionState
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
    val contentResolver = LocalContext.current.contentResolver
    val repo = remember {
        UsersRepository(container.retrofit.create(UsersApi::class.java), container.json, contentResolver)
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

        KycSection(state = state, vm = vm)

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

// ---------------------------------------------------------------------------
// A7 — Operator KYC (address, Aadhaar, profile photo, ID-card photo)
// ---------------------------------------------------------------------------

private enum class KycTarget { Profile, IdCard }

@OptIn(ExperimentalPermissionsApi::class)
@Composable
private fun KycSection(state: AdminUsersUiState, vm: UsersViewModel) {
    val context = LocalContext.current
    val form = state.form
    val errors = state.fieldErrors

    // Which image the source chooser targets; the camera path also needs the
    // capture Uri + target held across the async result and the permission grant.
    var chooserFor by remember { mutableStateOf<KycTarget?>(null) }
    var pendingTarget by remember { mutableStateOf<KycTarget?>(null) }
    var captureUri by remember { mutableStateOf<Uri?>(null) }
    var cameraRequestTarget by remember { mutableStateOf<KycTarget?>(null) }

    fun deliver(target: KycTarget, image: PickedImage) = when (target) {
        KycTarget.Profile -> vm.onProfilePhotoPicked(image)
        KycTarget.IdCard -> vm.onIdCardPicked(image)
    }

    // Gallery: the system photo picker — no runtime permission, mirrors the web's
    // `accept="image/*"` file input.
    val imageRequest = remember { PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly) }
    val galleryPicker = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) { uri ->
        val target = pendingTarget
        pendingTarget = null
        if (uri != null && target != null) deliver(target, context.contentResolver.toPickedImage(uri))
    }
    val cameraPicker = rememberLauncherForActivityResult(ActivityResultContracts.TakePicture()) { success ->
        val target = pendingTarget
        val uri = captureUri
        pendingTarget = null
        captureUri = null
        if (success && target != null && uri != null) deliver(target, context.contentResolver.toPickedImage(uri))
    }

    fun launchGallery(target: KycTarget) {
        pendingTarget = target
        galleryPicker.launch(imageRequest)
    }
    fun launchCamera(target: KycTarget) {
        captureUri = context.newKycCaptureUri()
        pendingTarget = target
        cameraPicker.launch(captureUri!!)
    }

    // The manifest declares CAMERA (for the plate scanner), so the OS requires it
    // to be granted before ACTION_IMAGE_CAPTURE will open the camera app.
    val cameraPermission = rememberPermissionState(Manifest.permission.CAMERA) { granted ->
        val target = cameraRequestTarget
        cameraRequestTarget = null
        if (granted && target != null) launchCamera(target)
    }
    fun takePhoto(target: KycTarget) {
        if (cameraPermission.status.isGranted) {
            launchCamera(target)
        } else {
            cameraRequestTarget = target
            cameraPermission.launchPermissionRequest()
        }
    }

    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Text("Identity / KYC", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
        Text(
            "Optional. Aadhaar is encrypted at rest; revealing it is logged.",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.nayara.textSecondary,
        )

        FormField(
            value = form.address,
            onValueChange = vm::onAddress,
            label = "Address",
            errors = errors["address"],
            singleLine = false,
        )

        FormField(
            value = form.aadhaar,
            onValueChange = vm::onAadhaar,
            label = "Aadhaar Number",
            errors = errors["aadhaar_number"],
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
            helper = if (form.aadhaarPresent && state.revealedAadhaar == null) {
                "Current: ${form.aadhaarMasked ?: "on file"} — leave blank to keep"
            } else {
                null
            },
        )

        // Reveal the stored Aadhaar (audited). Only for an existing operator.
        if (state.isEditing && form.aadhaarPresent) {
            if (state.revealedAadhaar != null) {
                RevealedAadhaarCard(state.revealedAadhaar!!)
            } else {
                NayaraOutlinedButton(onClick = vm::revealKyc, enabled = !state.revealing) {
                    if (state.revealing) SmallSpinner() else Text("Reveal full Aadhaar (logged)")
                }
            }
            state.revealError?.let { FieldError(listOf(it)) }
        }

        // Profile photo
        Text("Profile Photo", style = MaterialTheme.typography.labelLarge)
        Row(
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            KycThumbnail(
                picked = form.pickedProfilePhoto?.uri,
                currentUrl = absoluteApiUrl(form.profilePhotoUrl),
            )
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                NayaraOutlinedButton(
                    onClick = { chooserFor = KycTarget.Profile },
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    Text(if (form.pickedProfilePhoto != null || form.profilePhotoUrl != null) "Change photo" else "Add photo")
                }
                if (form.pickedProfilePhoto != null) {
                    Text(
                        "New photo ready to upload.",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.nayara.textSecondary,
                    )
                }
            }
        }
        FieldError(errors["profile_photo"])

        // ID-card photo — sensitive, so it's never shown inline; viewing is gated
        // behind the audited reveal.
        Text("ID-card Photo", style = MaterialTheme.typography.labelLarge)
        Text(
            when {
                form.pickedIdCard != null -> "New ID card ready to upload."
                form.idCardPresent -> "ID card on file."
                else -> "No ID card captured."
            },
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.nayara.textSecondary,
        )
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            NayaraOutlinedButton(
                onClick = { chooserFor = KycTarget.IdCard },
                modifier = Modifier.weight(1f),
            ) {
                Text(if (form.pickedIdCard != null || form.idCardPresent) "Replace" else "Capture ID card")
            }
            if (form.idCardPresent) {
                if (state.revealedIdCardUrl != null) {
                    NayaraButton(
                        onClick = { openInBrowser(context, state.revealedIdCardUrl) },
                        modifier = Modifier.weight(1f),
                    ) { Text("Open ID card") }
                } else {
                    NayaraOutlinedButton(
                        onClick = vm::revealKyc,
                        enabled = !state.revealing,
                        modifier = Modifier.weight(1f),
                    ) {
                        if (state.revealing) SmallSpinner() else Text("View ID card")
                    }
                }
            }
        }
        FieldError(errors["id_card_photo"])

        // Purge — clears Aadhaar + ID card but keeps the account.
        if (state.isEditing && (form.aadhaarPresent || form.idCardPresent)) {
            var confirmPurge by remember { mutableStateOf(false) }
            NayaraOutlinedButton(onClick = { confirmPurge = true }, enabled = !state.purging) {
                Text("Purge KYC", color = MaterialTheme.colorScheme.error)
            }
            if (confirmPurge) {
                ConfirmDialog(
                    title = "Purge KYC?",
                    text = "This clears the Aadhaar and ID-card photo for this operator. The account stays.",
                    confirmLabel = "Purge",
                    destructive = true,
                    onConfirm = {
                        confirmPurge = false
                        vm.purgeKyc()
                    },
                    onDismiss = { confirmPurge = false },
                )
            }
        }
    }

    chooserFor?.let { target ->
        AlertDialog(
            onDismissRequest = { chooserFor = null },
            title = { Text("Add photo") },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    TextButton(
                        onClick = {
                            chooserFor = null
                            takePhoto(target)
                        },
                        modifier = Modifier.fillMaxWidth(),
                    ) {
                        Icon(Icons.Filled.PhotoCamera, contentDescription = null)
                        Spacer(Modifier.size(8.dp))
                        Text("Take photo", modifier = Modifier.weight(1f))
                    }
                    TextButton(
                        onClick = {
                            chooserFor = null
                            launchGallery(target)
                        },
                        modifier = Modifier.fillMaxWidth(),
                    ) {
                        Icon(Icons.Filled.PhotoLibrary, contentDescription = null)
                        Spacer(Modifier.size(8.dp))
                        Text("Choose from gallery", modifier = Modifier.weight(1f))
                    }
                }
            },
            confirmButton = {},
            dismissButton = { TextButton(onClick = { chooserFor = null }) { Text("Cancel") } },
        )
    }
}

@Composable
private fun KycThumbnail(picked: Uri?, currentUrl: String?) {
    val model: Any? = picked ?: currentUrl
    Box(
        modifier = Modifier
            .size(72.dp)
            .clip(RoundedCornerShape(12.dp))
            .background(MaterialTheme.colorScheme.surfaceVariant),
        contentAlignment = Alignment.Center,
    ) {
        if (model != null) {
            AsyncImage(
                model = model,
                contentDescription = "Profile photo",
                contentScale = ContentScale.Crop,
                modifier = Modifier.fillMaxSize(),
            )
        } else {
            Icon(
                Icons.Filled.Person,
                contentDescription = null,
                tint = MaterialTheme.nayara.textTertiary,
            )
        }
    }
}

@Composable
private fun RevealedAadhaarCard(value: String) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(MaterialTheme.colorScheme.surfaceVariant)
            .padding(12.dp),
        verticalArrangement = Arrangement.spacedBy(2.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Icon(Icons.Filled.Badge, contentDescription = null, tint = MaterialTheme.nayara.textSecondary)
            Text(
                value,
                style = MaterialTheme.typography.titleMedium,
                fontFamily = FontFamily.Monospace,
            )
        }
        Text(
            "Revealed — this access was logged.",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.nayara.textSecondary,
        )
    }
}

@Composable
private fun SmallSpinner() {
    CircularProgressIndicator(modifier = Modifier.size(18.dp), strokeWidth = 2.dp)
}

private fun openInBrowser(context: Context, relativeUrl: String?) {
    val absolute = absoluteApiUrl(relativeUrl) ?: return
    runCatching { context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(absolute))) }
}
