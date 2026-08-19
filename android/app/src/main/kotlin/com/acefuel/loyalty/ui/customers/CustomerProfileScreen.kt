package com.acefuel.loyalty.ui.customers

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.Agriculture
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.DirectionsBus
import androidx.compose.material.icons.filled.DirectionsCar
import androidx.compose.material.icons.filled.LocalShipping
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.filled.StarBorder
import androidx.compose.material.icons.filled.TwoWheeler
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import com.acefuel.loyalty.core.di.LocalContainer
import com.acefuel.loyalty.core.network.dto.CustomerContactDto
import com.acefuel.loyalty.core.network.dto.CustomerContactUpdateAttributes
import com.acefuel.loyalty.core.network.dto.CustomerProfileDto
import com.acefuel.loyalty.core.network.dto.CustomerUpdateRequest
import com.acefuel.loyalty.core.network.dto.CatalogResponse
import com.acefuel.loyalty.core.network.dto.FuelTypeOptionDto
import com.acefuel.loyalty.core.network.dto.LedgerEntryDto
import com.acefuel.loyalty.core.network.dto.StaffVehicleDto
import com.acefuel.loyalty.core.network.dto.TransactionSummaryDto
import com.acefuel.loyalty.core.network.dto.VehicleKindOptionDto
import com.acefuel.loyalty.core.network.dto.VehicleUpdateRequest
import com.acefuel.loyalty.ui.admin.crm.ContactLogDto
import com.acefuel.loyalty.ui.admin.crm.CrmApi
import com.acefuel.loyalty.ui.admin.crm.CrmRepository
import com.acefuel.loyalty.ui.admin.crm.CustomerCrmViewModel
import com.acefuel.loyalty.ui.admin.crm.FeedbackDto
import com.acefuel.loyalty.ui.admin.crm.InsightDto
import com.acefuel.loyalty.ui.admin.crm.RewardsSummaryDto
import com.acefuel.loyalty.ui.designsystem.AnimatedCounter
import com.acefuel.loyalty.ui.designsystem.Avatar
import com.acefuel.loyalty.ui.designsystem.ChipTone
import com.acefuel.loyalty.ui.designsystem.ConfirmDialog
import com.acefuel.loyalty.ui.designsystem.ErrorState
import com.acefuel.loyalty.ui.designsystem.FuelDot
import com.acefuel.loyalty.ui.designsystem.NayaraBottomSheet
import com.acefuel.loyalty.ui.designsystem.NayaraCard
import com.acefuel.loyalty.ui.designsystem.NayaraPullToRefresh
import com.acefuel.loyalty.ui.designsystem.NayaraSnackbarHost
import com.acefuel.loyalty.ui.designsystem.NayaraTopBar
import com.acefuel.loyalty.ui.designsystem.PickerField
import com.acefuel.loyalty.ui.designsystem.PlateChip
import com.acefuel.loyalty.ui.designsystem.SkeletonCard
import com.acefuel.loyalty.ui.designsystem.SkeletonList
import com.acefuel.loyalty.ui.designsystem.StatusChip
import com.acefuel.loyalty.ui.designsystem.rememberHaptics
import com.acefuel.loyalty.ui.designsystem.showError
import com.acefuel.loyalty.ui.designsystem.showSuccess
import com.acefuel.loyalty.ui.theme.NayaraButton
import com.acefuel.loyalty.ui.theme.NayaraHeroCard
import com.acefuel.loyalty.ui.theme.NayaraNumerals
import com.acefuel.loyalty.ui.theme.NayaraOutlinedButton
import com.acefuel.loyalty.ui.theme.NayaraPalette
import com.acefuel.loyalty.ui.theme.NayaraSpacing
import com.acefuel.loyalty.ui.theme.nayara
import java.time.format.DateTimeFormatter
import java.time.OffsetDateTime
import com.acefuel.loyalty.core.network.dto.CustomerNoteDto
import androidx.compose.material3.HorizontalDivider

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CustomerProfileScreen(customerId: Long, isAdmin: Boolean, onBack: () -> Unit) {
    val container = LocalContainer.current
    val viewModel: CustomerProfileViewModel = viewModel(
        key = "profile-$customerId",
        factory = viewModelFactory { initializer { CustomerProfileViewModel(container.staffRepository, customerId) } },
    )
    val state by viewModel.state.collectAsStateWithLifecycle()

    // Phase 4 — additive CRM state (feedback for all, insight + outreach for
    // admins). Kept in its own VM so the profile VM above stays untouched.
    val crmViewModel: CustomerCrmViewModel = viewModel(
        key = "crm-$customerId",
        factory = viewModelFactory {
            initializer {
                CustomerCrmViewModel(
                    CrmRepository(container.retrofit.create(CrmApi::class.java), container.json),
                    customerId,
                    isAdmin,
                )
            }
        },
    )
    val crmState by crmViewModel.state.collectAsStateWithLifecycle()

    val snackbar = remember { SnackbarHostState() }
    val haptics = rememberHaptics()
    var pendingConfirm by remember { mutableStateOf<ProfileAction?>(null) }
    var showFeedbackSheet by remember { mutableStateOf(false) }
    var showContactSheet by remember { mutableStateOf(false) }
    var showCustomerContactSheet by remember { mutableStateOf(false) }
    var contactBeingEdited by remember { mutableStateOf<CustomerContactDto?>(null) }
    var showCustomerEditSheet by remember { mutableStateOf(false) }
    var selectedVehicle by remember { mutableStateOf<StaffVehicleDto?>(null) }
    var editingVehicle by remember { mutableStateOf<StaffVehicleDto?>(null) }
    var addingVehicle by remember { mutableStateOf(false) }

    LaunchedEffect(state.actionMessage) {
        val message = state.actionMessage ?: return@LaunchedEffect
        haptics.confirm()
        snackbar.showSuccess(message)
        viewModel.consumeActionMessage()
    }
    LaunchedEffect(state.transientError) {
        val message = state.transientError ?: return@LaunchedEffect
        haptics.reject()
        snackbar.showError(message)
        viewModel.consumeTransientError()
    }
    // Same one-shot snackbar plumbing for the CRM actions.
    LaunchedEffect(crmState.actionMessage) {
        val message = crmState.actionMessage ?: return@LaunchedEffect
        haptics.confirm()
        snackbar.showSuccess(message)
        crmViewModel.consumeActionMessage()
    }
    LaunchedEffect(crmState.transientError) {
        val message = crmState.transientError ?: return@LaunchedEffect
        haptics.reject()
        snackbar.showError(message)
        crmViewModel.consumeTransientError()
    }

    Scaffold(
        topBar = { NayaraTopBar(title = state.profile?.name ?: "Customer", onBack = onBack) },
        snackbarHost = { NayaraSnackbarHost(snackbar) },
    ) { innerPadding ->
        val profile = state.profile
        when {
            state.loading && profile == null ->
                Column(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(innerPadding)
                        .padding(horizontal = NayaraSpacing.ScreenMargin, vertical = NayaraSpacing.Md),
                    verticalArrangement = Arrangement.spacedBy(NayaraSpacing.Md),
                ) {
                    SkeletonCard(lines = 3)
                    SkeletonList(count = 5, showAvatar = false)
                }
            profile == null ->
                ErrorState(
                    message = state.error ?: "Customer not found.",
                    modifier = Modifier.fillMaxSize().padding(innerPadding),
                    onRetry = viewModel::retry,
                )
            else -> {
                NayaraPullToRefresh(
                    isRefreshing = state.refreshing,
                    onRefresh = viewModel::refresh,
                    modifier = Modifier.fillMaxSize().padding(innerPadding),
                ) {
                    LazyColumn(
                        modifier = Modifier.fillMaxSize(),
                        verticalArrangement = Arrangement.spacedBy(NayaraSpacing.Md),
                        contentPadding = PaddingValues(
                            start = NayaraSpacing.ScreenMargin,
                            end = NayaraSpacing.ScreenMargin,
                            top = NayaraSpacing.Md,
                            bottom = NayaraSpacing.Xxl,
                        ),
                    ) {
                        item { HeroCard(profile) }
                        item {
                            ActionRow(
                                p = profile,
                                inFlight = state.actionInFlight,
                                canPauseRewards = isAdmin,
                                onTogglePaused = {
                                    // Pausing is disruptive -> confirm; resuming acts directly.
                                    if (profile.rewardsPaused) viewModel.togglePaused()
                                    else pendingConfirm = ProfileAction.Pause
                                },
                                onToggleActive = {
                                    if (profile.active) pendingConfirm = ProfileAction.Active
                                    else viewModel.toggleActive()
                                },
                            )
                        }

                        item { SectionHeader("Marketing opt-ins") }
                        item {
                            OptInToggles(
                                whatsapp = profile.whatsappOptIn,
                                sms = profile.smsOptIn,
                                enabled = state.actionInFlight == null,
                                onWhatsapp = { viewModel.setWhatsappOptIn(it) },
                                onSms = { viewModel.setSmsOptIn(it) },
                            )
                        }

                        item {
                            SectionHeaderWithAction("Notes", "Edit") { showCustomerEditSheet = true }
                        }
                        item { NotesCard(profile.notes) }

                        // Phase 4 CRM — insight + outreach are admin-only.
                        if (isAdmin) {
                            item { SectionHeader("CRM Insight") }
                            item { InsightCard(crmState.insight, crmState.insightLoading) }

                            // Item 5 — discount paid out, points redeemed and gifts
                            // handed over, for this customer.
                            item { SectionHeader("Rewards Given") }
                            item { RewardsCard(crmState.insight?.rewards, crmState.insightLoading) }

                            item {
                                SectionHeaderWithAction("Outreach", "Log contact") { showContactSheet = true }
                            }
                            if (crmState.contactLogs.isEmpty() && !crmState.insightLoading) {
                                item { EmptyNote("No outreach logged yet.") }
                            } else {
                                items(crmState.contactLogs, key = { "clog-${it.id}" }) {
                                    ContactLogCard(it, modifier = Modifier.animateItem())
                                }
                            }
                        }

                        // Feedback is visible to staff and admin alike.
                        item {
                            SectionHeaderWithAction("Feedback", "Add rating") { showFeedbackSheet = true }
                        }
                        item { FeedbackSummaryRow(crmState.avgRating, crmState.feedbackCount) }
                        if (crmState.feedbacks.isEmpty() && !crmState.feedbackLoading) {
                            item { EmptyNote("No feedback recorded yet.") }
                        } else {
                            items(crmState.feedbacks, key = { "fb-${it.id}" }) {
                                FeedbackCard(it, modifier = Modifier.animateItem())
                            }
                        }

                        item {
                            SectionHeaderWithAction("Vehicles (${profile.vehicles.size})", "Add vehicle") {
                                addingVehicle = true
                                viewModel.ensureCatalog()
                            }
                        }
                        if (profile.vehicles.isEmpty()) {
                            item { EmptyNote("No vehicles registered yet.") }
                        } else {
                            items(profile.vehicles, key = { "veh-${it.id}" }) {
                                VehicleCard(
                                    it,
                                    onClick = { selectedVehicle = it },
                                    modifier = Modifier.animateItem(),
                                )
                            }
                        }

                        item {
                            SectionHeaderWithAction("Contacts", "Add contact") {
                                contactBeingEdited = null
                                showCustomerContactSheet = true
                            }
                        }
                        if (profile.contacts.isEmpty()) {
                            item { EmptyNote("No contacts added yet.") }
                        } else {
                            items(profile.contacts, key = { "contact-${it.id}" }) {
                                ContactCard(
                                    it,
                                    onClick = {
                                        contactBeingEdited = it
                                        showCustomerContactSheet = true
                                    },
                                    modifier = Modifier.animateItem(),
                                )
                            }
                        }

                        item { SectionHeader("Recent Transactions") }
                        if (profile.recentTransactions.isEmpty()) {
                            item { EmptyNote("No transactions recorded yet.") }
                        } else {
                            items(profile.recentTransactions, key = { "txn-${it.id}" }) {
                                TransactionCard(it, modifier = Modifier.animateItem())
                            }
                        }

                        item { SectionHeader("Points Ledger") }
                        if (state.ledger.isEmpty() && !state.ledgerLoading) {
                            item { EmptyNote("No ledger entries yet.") }
                        } else {
                            items(state.ledger, key = { "ledger-${it.id}" }) {
                                LedgerRow(it, modifier = Modifier.animateItem())
                            }
                            item {
                                if (state.ledgerHasMore) {
                                    TextButton(onClick = { viewModel.loadMoreLedger() }, enabled = !state.ledgerLoading) {
                                        Text(if (state.ledgerLoading) "Loading…" else "Load more")
                                    }
                                }
                                Text(
                                    "Showing ${state.ledger.size} of ${state.ledgerTotal} entries",
                                    style = MaterialTheme.typography.labelSmall,
                                    color = MaterialTheme.nayara.textTertiary,
                                )
                            }
                        }
                    }
                }

                when (pendingConfirm) {
                    ProfileAction.Pause -> ConfirmDialog(
                        title = "Pause rewards?",
                        text = "${profile.name ?: "This customer"} will stop earning and redeeming points " +
                            "until rewards are resumed.",
                        confirmLabel = "Pause",
                        destructive = true,
                        onConfirm = {
                            pendingConfirm = null
                            viewModel.togglePaused()
                        },
                        onDismiss = { pendingConfirm = null },
                    )
                    ProfileAction.Active -> ConfirmDialog(
                        title = "Mark inactive?",
                        text = "${profile.name ?: "This customer"} will no longer appear as an active " +
                            "loyalty member. You can mark them active again later.",
                        confirmLabel = "Mark Inactive",
                        destructive = true,
                        onConfirm = {
                            pendingConfirm = null
                            viewModel.toggleActive()
                        },
                        onDismiss = { pendingConfirm = null },
                    )
                    ProfileAction.OptIn, null -> Unit // opt-in toggles act directly, no confirm
                }

                if (showFeedbackSheet) {
                    FeedbackSheet(
                        submitting = crmState.submittingFeedback,
                        onDismiss = { showFeedbackSheet = false },
                        onSubmit = { rating, comment ->
                            crmViewModel.addFeedback(rating, comment)
                            showFeedbackSheet = false
                        },
                    )
                }
                if (showContactSheet) {
                    LogContactSheet(
                        contacts = profile.contacts,
                        submitting = crmState.loggingContact,
                        onDismiss = { showContactSheet = false },
                        onSubmit = { channel, outcome, role, contactId, notes ->
                            crmViewModel.logContact(channel, outcome, role, contactId, notes)
                            showContactSheet = false
                        },
                    )
                }
                selectedVehicle?.let { vehicle ->
                    VehicleDetailsSheet(
                        vehicle = vehicle,
                        onEdit = {
                            selectedVehicle = null
                            editingVehicle = vehicle
                            viewModel.ensureCatalog()
                        },
                        onDismiss = { selectedVehicle = null },
                    )
                }
                editingVehicle?.let { vehicle ->
                    VehicleEditSheet(
                        vehicle = vehicle,
                        catalog = state.catalog,
                        catalogLoading = state.catalogLoading,
                        saving = state.vehicleSaving,
                        onDismiss = { editingVehicle = null },
                        onSave = { request ->
                            viewModel.updateVehicle(vehicle.id, request) {
                                editingVehicle = null
                            }
                        },
                    )
                }
                if (addingVehicle) {
                    VehicleEditSheet(
                        vehicle = null,
                        catalog = state.catalog,
                        catalogLoading = state.catalogLoading,
                        saving = state.vehicleSaving,
                        onDismiss = { addingVehicle = false },
                        onSave = { request ->
                            viewModel.createVehicle(request) {
                                addingVehicle = false
                            }
                        },
                    )
                }
                if (showCustomerEditSheet) {
                    CustomerEditSheet(
                        customer = profile,
                        saving = state.actionInFlight != null,
                        onDismiss = { showCustomerEditSheet = false },
                        onSave = { request ->
                            viewModel.updateCustomerDetails(request) {
                                showCustomerEditSheet = false
                            }
                        },
                    )
                }
                if (showCustomerContactSheet) {
                    CustomerContactSheet(
                        contact = contactBeingEdited,
                        saving = state.actionInFlight != null,
                        onDismiss = { showCustomerContactSheet = false },
                        onSave = { contactAttributes ->
                            viewModel.updateCustomerDetails(
                                CustomerUpdateRequest(customerContactsAttributes = listOf(contactAttributes)),
                            ) {
                                showCustomerContactSheet = false
                            }
                        },
                    )
                }
            }
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun HeroCard(p: CustomerProfileDto) {
    // Content on the brand gradient stays white by design (not theme tokens).
    NayaraHeroCard(modifier = Modifier.fillMaxWidth()) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Avatar(p.name, size = 44.dp)
            Spacer(Modifier.width(12.dp))
            Column {
                Text(
                    p.name ?: "Customer",
                    color = NayaraPalette.White,
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold,
                )
                p.phoneNumber?.let { Text("+91 $it", color = NayaraPalette.Navy100, style = MaterialTheme.typography.bodySmall) }
            }
        }
        Spacer(Modifier.height(16.dp))
        Text("Current Points", color = NayaraPalette.Navy200, style = MaterialTheme.typography.labelLarge)
        AnimatedCounter(
            value = p.totalPoints,
            style = NayaraNumerals.Hero,
            color = NayaraPalette.White,
        )
        Spacer(Modifier.height(12.dp))
        FlowRow(
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            InfoChip("${p.visitsCount} visits")
            InfoChip("${p.vehicles.size} vehicles")
            // B1/E4 — surface the account taxonomy (drive-in is the default, so
            // only the notable OTP/Fleet & Credit accounts get a chip).
            p.customerTypeLabel?.takeIf { p.customerType != null && p.customerType != "drive_in" }?.let { InfoChip(it) }
            p.transportName?.takeIf { it.isNotBlank() }?.let { InfoChip("Transport: $it") }
            InfoChip("Joined ${formatMonthYear(p.joinedAt)}")
            if (p.rewardsPaused) InfoChip("Rewards Paused")
            p.maxRedeemableCashReward?.let { InfoChip("Cash ₹%.2f".format(it)) }
        }
        // Extra room below the pills so they don't hug the card's bottom edge
        // (the hero card's own content padding alone reads as too tight here).
        Spacer(Modifier.height(8.dp))
    }
}

@Composable
private fun OptInToggles(
    whatsapp: Boolean,
    sms: Boolean,
    enabled: Boolean,
    onWhatsapp: (Boolean) -> Unit,
    onSms: (Boolean) -> Unit,
) {
    Column(verticalArrangement = Arrangement.spacedBy(NayaraSpacing.Xs)) {
        OptInRow("WhatsApp offers", whatsapp, enabled, onWhatsapp)
        OptInRow("SMS offers", sms, enabled, onSms)
        Text(
            "Set only with the customer's consent — offer campaigns reach these channels only when opted in.",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

@Composable
private fun OptInRow(label: String, checked: Boolean, enabled: Boolean, onChange: (Boolean) -> Unit) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(label, style = MaterialTheme.typography.bodyMedium)
        Switch(checked = checked, onCheckedChange = onChange, enabled = enabled)
    }
}

@Composable
private fun InfoChip(text: String) {
    Card(colors = CardDefaults.cardColors(containerColor = NayaraPalette.White.copy(alpha = 0.16f))) {
        Text(text, modifier = Modifier.padding(horizontal = 10.dp, vertical = 4.dp), style = MaterialTheme.typography.labelMedium, color = NayaraPalette.White)
    }
}

@Composable
private fun ActionRow(
    p: CustomerProfileDto,
    inFlight: ProfileAction?,
    canPauseRewards: Boolean,
    onTogglePaused: () -> Unit,
    onToggleActive: () -> Unit,
) {
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        // Pausing/resuming rewards is an admin-only capability (S-PAUSE); staff
        // never see this control.
        if (canPauseRewards) {
            NayaraOutlinedButton(onClick = onTogglePaused, enabled = inFlight == null, modifier = Modifier.weight(1f)) {
                ButtonLabel(
                    if (p.rewardsPaused) "Resume Rewards" else "Pause Rewards",
                    loading = inFlight == ProfileAction.Pause,
                )
            }
        }
        NayaraOutlinedButton(onClick = onToggleActive, enabled = inFlight == null, modifier = Modifier.weight(1f)) {
            ButtonLabel(
                if (p.active) "Mark Inactive" else "Mark Active",
                loading = inFlight == ProfileAction.Active,
            )
        }
    }
}

@Composable
private fun ButtonLabel(text: String, loading: Boolean) {
    if (loading) {
        CircularProgressIndicator(modifier = Modifier.size(18.dp), strokeWidth = 2.dp)
        Spacer(Modifier.width(8.dp))
    }
    Text(text)
}

@Composable
private fun SectionHeader(text: String) {
    Text(
        text,
        style = MaterialTheme.typography.titleSmall,
        color = MaterialTheme.nayara.textSecondary,
        modifier = Modifier.padding(top = NayaraSpacing.Sm),
    )
}

@Composable
private fun EmptyNote(text: String) {
    Text(text, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.nayara.textSecondary)
}

@Composable
private fun NotesCard(notes: List<CustomerNoteDto>) {
    NayaraCard(modifier = Modifier.fillMaxWidth()) {
        if (notes.isEmpty()) {
            Text(
                "No notes added yet.",
                modifier = Modifier.padding(NayaraSpacing.Lg),
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.nayara.textTertiary,
            )
            return@NayaraCard
        }

        Column(
            modifier = Modifier.padding(NayaraSpacing.Lg),
            verticalArrangement = Arrangement.spacedBy(NayaraSpacing.Md),
        ) {
            notes.forEachIndexed { index, note ->
                if (index > 0) HorizontalDivider()
                Column(verticalArrangement = Arrangement.spacedBy(NayaraSpacing.Xs)) {
                    Text(
                        listOfNotNull(formatNoteTimestamp(note.createdAt), note.author).joinToString(" · "),
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.nayara.textTertiary,
                    )
                    Text(note.body, style = MaterialTheme.typography.bodyMedium)
                }
            }
        }
    }
}

/** ISO-8601 from the API to something readable; falls back to the raw value. */
private fun formatNoteTimestamp(value: String): String =
    runCatching {
        OffsetDateTime.parse(value).format(DateTimeFormatter.ofPattern("d MMM yyyy, h:mm a"))
    }.getOrDefault(value)

@Composable
private fun VehicleCard(
    v: StaffVehicleDto,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    NayaraCard(onClick = onClick, modifier = modifier.fillMaxWidth()) {
        Row(
            modifier = Modifier.padding(NayaraSpacing.Lg),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            // Leading kind icon anchors the row so the plate + fuel line no longer
            // float alone in an empty full-width card.
            Box(
                modifier = Modifier
                    .size(44.dp)
                    .clip(CircleShape)
                    .background(MaterialTheme.nayara.bgSurfaceSunken),
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    vehicleKindIcon(v),
                    contentDescription = null,
                    tint = MaterialTheme.nayara.textSecondary,
                    modifier = Modifier.size(24.dp),
                )
            }
            Spacer(Modifier.width(NayaraSpacing.Md))
            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(NayaraSpacing.Xs),
            ) {
                PlateChip(v.vehicleNumber)
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(NayaraSpacing.Xs),
                ) {
                    FuelDot(v.fuelTypeCode ?: v.fuelType ?: "")
                    Text(
                        "${v.fuelType ?: "—"} · ${v.vehicleKind ?: "—"}",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.nayara.textSecondary,
                    )
                }
                if (v.commercial && !v.commercialContactName.isNullOrBlank()) {
                    Text("Contact: ${v.commercialContactName}", style = MaterialTheme.typography.bodySmall)
                }
            }
            Icon(
                Icons.AutoMirrored.Filled.KeyboardArrowRight,
                contentDescription = "View vehicle details",
                tint = MaterialTheme.nayara.textTertiary,
                modifier = Modifier.size(22.dp),
            )
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun VehicleDetailsSheet(
    vehicle: StaffVehicleDto,
    onEdit: () -> Unit,
    onDismiss: () -> Unit,
) {
    NayaraBottomSheet(
        onDismissRequest = onDismiss,
        title = "Vehicle details",
        subtitle = "Registered vehicle information",
    ) {
        Column(
            modifier = Modifier.fillMaxWidth(),
            verticalArrangement = Arrangement.spacedBy(NayaraSpacing.Xs),
        ) {
            Row(
                modifier = Modifier.fillMaxWidth().padding(bottom = NayaraSpacing.Sm),
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
                        vehicleKindIcon(vehicle),
                        contentDescription = null,
                        tint = MaterialTheme.nayara.textSecondary,
                        modifier = Modifier.size(24.dp),
                    )
                }
                Spacer(Modifier.width(NayaraSpacing.Md))
                PlateChip(vehicle.vehicleNumber)
            }

            VehicleDetailRow("Vehicle number", vehicle.vehicleNumber)
            VehicleDetailRow("Fuel type", vehicle.fuelType ?: vehicle.fuelTypeCode ?: "Not set")
            VehicleDetailRow("Vehicle type", vehicle.vehicleKind ?: vehicle.vehicleKindCode ?: "Not set")
            vehicle.displayName?.takeIf { it.isNotBlank() }?.let {
                VehicleDetailRow("Display name", it)
            }

            if (vehicle.commercial) {
                Text(
                    "Commercial registration",
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.SemiBold,
                    modifier = Modifier.padding(top = NayaraSpacing.Sm),
                )
                vehicle.commercialCompanyName?.takeIf { it.isNotBlank() }?.let {
                    VehicleDetailRow("Company", it)
                }
                vehicle.commercialContactName?.takeIf { it.isNotBlank() }?.let {
                    VehicleDetailRow("Contact", it)
                }
                vehicle.commercialContactPhoneNumber?.takeIf { it.isNotBlank() }?.let {
                    VehicleDetailRow("Contact phone", "+91 $it")
                }
                vehicle.commercialAddress?.takeIf { it.isNotBlank() }?.let {
                    VehicleDetailRow("Address", it)
                }
                vehicle.commercialNotes?.takeIf { it.isNotBlank() }?.let {
                    VehicleDetailRow("Notes", it)
                }
            }

            NayaraOutlinedButton(onClick = onEdit, modifier = Modifier.fillMaxWidth()) {
                Text("Edit vehicle")
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun VehicleEditSheet(
    vehicle: StaffVehicleDto?,
    catalog: CatalogResponse?,
    catalogLoading: Boolean,
    saving: Boolean,
    onDismiss: () -> Unit,
    onSave: (VehicleUpdateRequest) -> Unit,
) {
    var form by remember(vehicle?.id ?: 0L) { mutableStateOf(VehicleEditForm.from(vehicle)) }
    var validationError by remember(vehicle?.id ?: 0L) { mutableStateOf<String?>(null) }
    val selectedKind = catalog?.vehicleKinds?.firstOrNull { it.code == form.vehicleKind }
    val isCommercial = selectedKind?.commercial ?: (vehicle?.commercial == true)
    val fuelLabel = catalog?.fuelTypes?.firstOrNull { it.code == form.fuelType }?.label
        ?: vehicle?.fuelType
        ?: form.fuelType
    val kindLabel = selectedKind?.label ?: vehicle?.vehicleKind ?: form.vehicleKind

    NayaraBottomSheet(
        onDismissRequest = onDismiss,
        title = if (vehicle == null) "Add vehicle" else "Edit vehicle",
        subtitle = if (vehicle == null) "Add another vehicle for this customer." else "Update the registered vehicle details.",
    ) {
        Column(
            modifier = Modifier.verticalScroll(rememberScrollState()),
            verticalArrangement = Arrangement.spacedBy(NayaraSpacing.Md),
        ) {
            VehicleEditTextField(
                value = form.vehicleNumber,
                label = "Vehicle number",
                onValueChange = { form = form.copy(vehicleNumber = it) },
            )

            if (catalog != null) {
                CrmDropdownField(
                    label = "Fuel type",
                    selectedLabel = fuelLabel,
                    options = catalog.fuelTypes,
                    optionLabel = FuelTypeOptionDto::label,
                    onSelect = { form = form.copy(fuelType = it.code) },
                )
                CrmDropdownField(
                    label = "Vehicle type",
                    selectedLabel = kindLabel,
                    options = catalog.vehicleKinds,
                    optionLabel = VehicleKindOptionDto::label,
                    onSelect = { form = form.copy(vehicleKind = it.code) },
                )
            } else {
                Text(
                    if (catalogLoading) "Loading fuel and vehicle type options…"
                    else "Vehicle type options are unavailable. Try again.",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.nayara.textSecondary,
                )
            }

            if (isCommercial) {
                Text(
                    "Commercial registration",
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.SemiBold,
                )
                VehicleEditTextField(
                    value = form.companyName,
                    label = "Company name (optional)",
                    onValueChange = { form = form.copy(companyName = it) },
                )
                VehicleEditTextField(
                    value = form.contactName,
                    label = "Owner / manager name (optional)",
                    onValueChange = { form = form.copy(contactName = it) },
                )
                VehicleEditTextField(
                    value = form.contactPhone,
                    label = "Owner / manager phone (optional)",
                    onValueChange = { form = form.copy(contactPhone = it) },
                )
                VehicleEditTextField(
                    value = form.address,
                    label = "Address (optional)",
                    onValueChange = { form = form.copy(address = it) },
                )
                VehicleEditTextField(
                    value = form.notes,
                    label = "Notes (optional)",
                    onValueChange = { form = form.copy(notes = it) },
                )
            }

            validationError?.let {
                Text(it, color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodySmall)
            }

            Row(horizontalArrangement = Arrangement.spacedBy(NayaraSpacing.Md)) {
                NayaraOutlinedButton(
                    onClick = onDismiss,
                    enabled = !saving,
                    modifier = Modifier.weight(1f),
                ) {
                    Text("Cancel")
                }
                NayaraButton(
                    onClick = {
                        val error = when {
                            form.vehicleNumber.isBlank() -> "Vehicle number is required."
                            form.fuelType.isBlank() -> "Select a fuel type."
                            form.vehicleKind.isBlank() -> "Select a vehicle type."
                            else -> null
                        }
                        validationError = error
                        if (error == null) {
                            onSave(
                                VehicleUpdateRequest(
                                    vehicleNumber = form.vehicleNumber,
                                    fuelType = form.fuelType,
                                    vehicleKind = form.vehicleKind,
                                    commercialCompanyName = form.companyName.trim().ifBlank { null },
                                    commercialContactName = form.contactName.trim().ifBlank { null },
                                    commercialContactPhoneNumber = form.contactPhone.trim().ifBlank { null },
                                    commercialAddress = form.address.trim().ifBlank { null },
                                    commercialNotes = form.notes.trim().ifBlank { null },
                                ),
                            )
                        }
                    },
                    enabled = !saving && catalog != null,
                    loading = saving,
                    modifier = Modifier.weight(1f),
                ) {
                    Text("Save")
                }
            }
        }
    }
}

private data class VehicleEditForm(
    val vehicleNumber: String,
    val fuelType: String,
    val vehicleKind: String,
    val companyName: String,
    val contactName: String,
    val contactPhone: String,
    val address: String,
    val notes: String,
) {
    companion object {
        fun from(vehicle: StaffVehicleDto?) = VehicleEditForm(
            vehicleNumber = vehicle?.vehicleNumber.orEmpty(),
            fuelType = vehicle?.fuelTypeCode.orEmpty(),
            vehicleKind = vehicle?.vehicleKindCode.orEmpty(),
            companyName = vehicle?.commercialCompanyName.orEmpty(),
            contactName = vehicle?.commercialContactName.orEmpty(),
            contactPhone = vehicle?.commercialContactPhoneNumber.orEmpty(),
            address = vehicle?.commercialAddress.orEmpty(),
            notes = vehicle?.commercialNotes.orEmpty(),
        )
    }
}

@Composable
private fun VehicleEditTextField(
    value: String,
    label: String,
    onValueChange: (String) -> Unit,
) {
    OutlinedTextField(
        value = value,
        onValueChange = onValueChange,
        label = { Text(label) },
        singleLine = true,
        modifier = Modifier.fillMaxWidth(),
    )
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun CustomerEditSheet(
    customer: CustomerProfileDto,
    saving: Boolean,
    onDismiss: () -> Unit,
    onSave: (CustomerUpdateRequest) -> Unit,
) {
    var name by remember(customer.id) { mutableStateOf(customer.name.orEmpty()) }
    // Starts empty: saving appends a new dated entry rather than rewriting the
    // last one (staff feedback item 13).
    var notes by remember(customer.id) { mutableStateOf("") }

    NayaraBottomSheet(
        onDismissRequest = onDismiss,
        title = "Customer details",
        subtitle = "Keep outreach information current for the next conversation.",
    ) {
        Column(verticalArrangement = Arrangement.spacedBy(NayaraSpacing.Md)) {
            OutlinedTextField(
                value = name,
                onValueChange = { name = it },
                label = { Text("Name (optional)") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
            )
            OutlinedTextField(
                value = notes,
                onValueChange = { notes = it },
                label = { Text("Add a note") },
                placeholder = { Text("What was discussed or what to follow up on") },
                supportingText = { Text("Saved as a new dated entry — earlier notes are kept.") },
                minLines = 4,
                modifier = Modifier.fillMaxWidth(),
            )
            Row(horizontalArrangement = Arrangement.spacedBy(NayaraSpacing.Md)) {
                NayaraOutlinedButton(
                    onClick = onDismiss,
                    enabled = !saving,
                    modifier = Modifier.weight(1f),
                ) { Text("Cancel") }
                NayaraButton(
                    onClick = {
                        onSave(CustomerUpdateRequest(name = name.trim(), infoNote = notes.trim().ifBlank { null }))
                    },
                    enabled = !saving,
                    loading = saving,
                    modifier = Modifier.weight(1f),
                ) { Text("Save") }
            }
        }
    }
}

private val CUSTOMER_CONTACT_ROLES = listOf(
    "driver" to "Driver",
    "supervisor" to "Supervisor",
    "owner" to "Owner",
    "manager" to "Manager",
)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun CustomerContactSheet(
    contact: CustomerContactDto?,
    saving: Boolean,
    onDismiss: () -> Unit,
    onSave: (CustomerContactUpdateAttributes) -> Unit,
) {
    var role by remember(contact?.id ?: 0L) { mutableStateOf(contact?.role ?: "driver") }
    var name by remember(contact?.id ?: 0L) { mutableStateOf(contact?.name.orEmpty()) }
    var phone by remember(contact?.id ?: 0L) { mutableStateOf(contact?.phoneNumber.orEmpty()) }
    var notes by remember(contact?.id ?: 0L) { mutableStateOf(contact?.notes.orEmpty()) }
    var contacted by remember(contact?.id ?: 0L) { mutableStateOf(contact?.contacted == true) }
    var validationError by remember(contact?.id ?: 0L) { mutableStateOf<String?>(null) }

    NayaraBottomSheet(
        onDismissRequest = onDismiss,
        title = if (contact == null) "Add contact" else "Edit contact",
        subtitle = "Store the person to approach and notes from your conversations.",
    ) {
        Column(verticalArrangement = Arrangement.spacedBy(NayaraSpacing.Md)) {
            CrmDropdownField(
                label = "Role",
                selectedLabel = CUSTOMER_CONTACT_ROLES.firstOrNull { it.first == role }?.second ?: role,
                options = CUSTOMER_CONTACT_ROLES,
                optionLabel = { it.second },
                onSelect = { role = it.first },
            )
            OutlinedTextField(
                value = name,
                onValueChange = { name = it },
                label = { Text("Name (optional)") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
            )
            OutlinedTextField(
                value = phone,
                onValueChange = { phone = it.filter(Char::isDigit).take(10) },
                label = { Text("Phone (optional)") },
                prefix = { Text("+91 ") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
            )
            OutlinedTextField(
                value = notes,
                onValueChange = { notes = it },
                label = { Text("Notes") },
                placeholder = { Text("Conversation or follow-up notes") },
                minLines = 3,
                modifier = Modifier.fillMaxWidth(),
            )
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text("Contacted", style = MaterialTheme.typography.bodyMedium)
                Switch(checked = contacted, onCheckedChange = { contacted = it }, enabled = !saving)
            }
            validationError?.let {
                Text(it, color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodySmall)
            }
            Row(horizontalArrangement = Arrangement.spacedBy(NayaraSpacing.Md)) {
                NayaraOutlinedButton(
                    onClick = onDismiss,
                    enabled = !saving,
                    modifier = Modifier.weight(1f),
                ) { Text("Cancel") }
                NayaraButton(
                    onClick = {
                        val error = when {
                            name.isBlank() && phone.isBlank() -> "Enter a contact name or phone number."
                            phone.isNotBlank() && phone.length != 10 -> "Enter a 10-digit contact phone number."
                            else -> null
                        }
                        validationError = error
                        if (error == null) {
                            onSave(
                                CustomerContactUpdateAttributes(
                                    id = contact?.id,
                                    role = role,
                                    name = name.trim(),
                                    phoneNumber = phone.trim(),
                                    contacted = contacted,
                                    notes = notes.trim(),
                                ),
                            )
                        }
                    },
                    enabled = !saving,
                    loading = saving,
                    modifier = Modifier.weight(1f),
                ) { Text("Save") }
            }
        }
    }
}

@Composable
private fun VehicleDetailRow(label: String, value: String) {
    Row(
        modifier = Modifier.fillMaxWidth().padding(vertical = NayaraSpacing.Xxs),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.Top,
    ) {
        Text(
            label,
            style = MaterialTheme.typography.labelMedium,
            color = MaterialTheme.nayara.textTertiary,
            modifier = Modifier.padding(end = NayaraSpacing.Md),
        )
        Text(
            value,
            style = MaterialTheme.typography.bodyMedium,
            fontWeight = FontWeight.Medium,
            modifier = Modifier.weight(1f, fill = false),
        )
    }
}

@Composable
private fun ContactCard(
    c: CustomerContactDto,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    NayaraCard(onClick = onClick, modifier = modifier.fillMaxWidth()) {
        Row(
            modifier = Modifier.padding(NayaraSpacing.Lg),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(NayaraSpacing.Xxs),
            ) {
                Text(c.name?.ifBlank { null } ?: c.roleLabel, fontWeight = FontWeight.SemiBold)
                val meta = listOfNotNull(c.roleLabel, c.phoneNumber?.let { "+91 $it" }).joinToString(" · ")
                if (meta.isNotBlank()) {
                    Text(meta, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.nayara.textSecondary)
                }
                c.notes?.takeIf { it.isNotBlank() }?.let {
                    Text(it, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.nayara.textTertiary)
                }
            }
            if (c.contacted) {
                Icon(
                    Icons.Filled.CheckCircle,
                    contentDescription = "Contacted",
                    tint = MaterialTheme.nayara.statusSuccessText,
                    modifier = Modifier.size(20.dp),
                )
            }
        }
    }
}

/** Maps a vehicle's kind (code or label) to a representative glyph. */
private fun vehicleKindIcon(v: StaffVehicleDto): ImageVector {
    val key = (v.vehicleKindCode ?: v.vehicleKind ?: "").lowercase()
    return when {
        "two" in key || "2w" in key || "bike" in key || "motor" in key || "scooter" in key -> Icons.Filled.TwoWheeler
        "truck" in key || "lorry" in key || "hcv" in key || "hgv" in key || "lcv" in key -> Icons.Filled.LocalShipping
        "bus" in key -> Icons.Filled.DirectionsBus
        "tractor" in key || "agri" in key -> Icons.Filled.Agriculture
        else -> Icons.Filled.DirectionsCar
    }
}

@Composable
private fun TransactionCard(t: TransactionSummaryDto, modifier: Modifier = Modifier) {
    NayaraCard(modifier = modifier.fillMaxWidth()) {
        Column(
            modifier = Modifier.padding(NayaraSpacing.Lg),
            verticalArrangement = Arrangement.spacedBy(NayaraSpacing.Xxs),
        ) {
            Row(
                Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    t.vehicleNumber ?: "Vehicle not linked",
                    fontWeight = FontWeight.SemiBold,
                    modifier = Modifier.weight(1f, fill = false),
                )
                Text("₹%.2f".format(t.fuelAmount), style = NayaraNumerals.Default)
            }
            t.handledBy?.let { Text("Handled by $it", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.nayara.textSecondary) }
            val pumpNozzle = listOfNotNull(t.pump, t.nozzle).joinToString(" · ")
            if (pumpNozzle.isNotBlank()) Text(pumpNozzle, style = MaterialTheme.typography.bodySmall)
            t.pointsEarned?.let {
                Text(
                    "Reward Points: ${if (it >= 0) "+$it" else "$it"}",
                    style = MaterialTheme.typography.bodySmall,
                    color = if (it >= 0) MaterialTheme.nayara.statusSuccessText else MaterialTheme.nayara.textPrimary,
                )
            }
            // The ₹ value of the points this fuelling EARNED. Null (not 0) when no
            // cash-value-per-point is configured, so the line simply disappears
            // rather than claiming a ₹0.00 reward — same rule the web row applies.
            t.cashReward?.let {
                Text(
                    "Cash Reward: ₹%.2f".format(it),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.nayara.textSecondary,
                )
            }
            // Item 5 — the ₹ knocked off this fuelling. A ₹0 discount is the norm,
            // so only a real one earns a line (the web row's rule exactly:
            // `transaction.discount_amount.to_d.positive?`).
            if (t.discountAmount > 0) {
                Text(
                    "Discount: ₹%.2f".format(t.discountAmount),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.nayara.textSecondary,
                )
            }
            Text(formatDateTime(t.createdAt), style = MaterialTheme.typography.labelSmall, color = MaterialTheme.nayara.textTertiary)
        }
    }
}

@Composable
private fun LedgerRow(e: LedgerEntryDto, modifier: Modifier = Modifier) {
    NayaraCard(modifier = modifier.fillMaxWidth()) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = NayaraSpacing.Lg, vertical = NayaraSpacing.Md),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(Modifier.weight(1f)) {
                Text(e.label, style = MaterialTheme.typography.bodyMedium)
                Text(formatDateTime(e.createdAt), style = MaterialTheme.typography.labelSmall, color = MaterialTheme.nayara.textTertiary)
            }
            Spacer(Modifier.width(NayaraSpacing.Md))
            Text(
                if (e.points >= 0) "+${e.points}" else "${e.points}",
                style = NayaraNumerals.Default,
                color = if (e.points >= 0) MaterialTheme.nayara.statusSuccessText else MaterialTheme.nayara.textPrimary,
            )
        }
    }
}

private fun formatMonthYear(iso: String): String = runCatching {
    java.time.OffsetDateTime.parse(iso).format(java.time.format.DateTimeFormatter.ofPattern("MMM yyyy"))
}.getOrDefault(iso)

private fun formatDateTime(iso: String): String = runCatching {
    java.time.OffsetDateTime.parse(iso).format(java.time.format.DateTimeFormatter.ofPattern("dd MMM yyyy · hh:mm a"))
}.getOrDefault(iso)

// ============================================================================
// Phase 4 — CRM Insight, Outreach & Feedback sections + their bottom sheets.
// ============================================================================

private val CRM_CHANNELS = listOf(
    "call" to "Call",
    "whatsapp" to "WhatsApp",
    "sms" to "SMS",
    "in_person" to "In person",
)

private val CRM_OUTCOMES = listOf(
    "converted" to "Converted",
    "reached" to "Reached",
    "callback_requested" to "Callback requested",
    "no_answer" to "No answer",
    "declined" to "Declined",
)

/** Section header with a trailing text action (e.g. "Add rating" / "Log contact"). */
@Composable
private fun SectionHeaderWithAction(title: String, actionLabel: String, onAction: () -> Unit) {
    Row(
        modifier = Modifier.fillMaxWidth().padding(top = NayaraSpacing.Sm),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            title,
            style = MaterialTheme.typography.titleSmall,
            color = MaterialTheme.nayara.textSecondary,
        )
        TextButton(onClick = onAction) { Text(actionLabel) }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun InsightCard(insight: InsightDto?, loading: Boolean) {
    NayaraCard(modifier = Modifier.fillMaxWidth()) {
        Column(
            modifier = Modifier.padding(NayaraSpacing.Lg),
            verticalArrangement = Arrangement.spacedBy(NayaraSpacing.Sm),
        ) {
            when {
                insight == null && loading -> Row(verticalAlignment = Alignment.CenterVertically) {
                    CircularProgressIndicator(modifier = Modifier.size(18.dp), strokeWidth = 2.dp)
                    Spacer(Modifier.width(NayaraSpacing.Md))
                    Text(
                        "Loading insight…",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.nayara.textSecondary,
                    )
                }
                insight == null -> EmptyNote("Insight isn't available yet.")
                else -> {
                    FlowRow(
                        horizontalArrangement = Arrangement.spacedBy(NayaraSpacing.Sm),
                        verticalArrangement = Arrangement.spacedBy(NayaraSpacing.Xs),
                    ) {
                        StatusChip(insight.cadenceLabel, ChipTone.Info, showDot = false)
                        if (insight.isLost) StatusChip("Lost", ChipTone.Error, showDot = false)
                    }

                    val fraction = (insight.conversionProbability / 100f).coerceIn(0f, 1f)
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                    ) {
                        Text(
                            "Conversion probability",
                            style = MaterialTheme.typography.labelMedium,
                            color = MaterialTheme.nayara.textSecondary,
                        )
                        Text(
                            "${insight.conversionProbability}%",
                            style = MaterialTheme.typography.labelLarge,
                            fontWeight = FontWeight.SemiBold,
                        )
                    }
                    LinearProgressIndicator(
                        progress = { fraction },
                        modifier = Modifier.fillMaxWidth(),
                    )

                    val daysAgo = insight.daysSinceLastVisit?.let { " · $it days ago" }.orEmpty()
                    Text(
                        "Last visit: ${insight.lastVisitedOn ?: "—"}$daysAgo",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.nayara.textSecondary,
                    )
                    insight.expectedNextVisitOn?.let {
                        Text(
                            "Expected next: $it",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.nayara.textTertiary,
                        )
                    }
                    val gap = insight.medianGapDays?.let { " · typically every $it days" }.orEmpty()
                    Text(
                        "${insight.visitCount} visits$gap",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.nayara.textTertiary,
                    )
                }
            }
        }
    }
}

/**
 * Item 5 — the per-customer rewards rollup. Deliberately three separate figures:
 * discount is rupees off at the pump, redemptions are points cashed in, and a
 * campaign gift is a physical item with no rupee value at all.
 */
@Composable
private fun RewardsCard(rewards: RewardsSummaryDto?, loading: Boolean) {
    NayaraCard(modifier = Modifier.fillMaxWidth()) {
        Column(
            modifier = Modifier.padding(NayaraSpacing.Lg),
            verticalArrangement = Arrangement.spacedBy(NayaraSpacing.Sm),
        ) {
            when {
                rewards == null && loading -> Row(verticalAlignment = Alignment.CenterVertically) {
                    CircularProgressIndicator(modifier = Modifier.size(18.dp), strokeWidth = 2.dp)
                    Spacer(Modifier.width(NayaraSpacing.Md))
                    Text(
                        "Loading rewards…",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.nayara.textSecondary,
                    )
                }
                rewards == null -> EmptyNote("Rewards aren't available yet.")
                else -> {
                    RewardStatRow("Discount paid", "₹%.2f".format(rewards.discountTotal))
                    // With no cash-value-per-point set, every redemption stored a NULL
                    // amount — that 0 is structural, so show "—" and not "₹0.00".
                    RewardStatRow(
                        "Redemption value",
                        if (rewards.rewardValueConfigured || rewards.redemptionValue != 0.0) {
                            "₹%.2f".format(rewards.redemptionValue)
                        } else {
                            "—"
                        },
                    )
                    val plural = if (rewards.redemptionCount == 1) "" else "s"
                    RewardStatRow(
                        "Points redeemed",
                        "${rewards.redemptionPoints} (${rewards.redemptionCount} redemption$plural)",
                    )
                    RewardStatRow("Gifts given", rewards.giftCount.toString())
                    // The client asked WHAT was given, not just how many.
                    if (rewards.giftDescriptions.isNotEmpty()) {
                        Text(
                            "Gifts: ${rewards.giftDescriptions.joinToString(", ")}",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.nayara.textSecondary,
                        )
                    }
                    if (!rewards.rewardValueConfigured) {
                        Text(
                            "No cash value per point is configured, so redemption ₹ shows as \u201c—\u201d.",
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.nayara.textTertiary,
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun RewardStatRow(label: String, value: String) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            label,
            style = MaterialTheme.typography.labelMedium,
            color = MaterialTheme.nayara.textSecondary,
        )
        Text(value, style = MaterialTheme.typography.labelLarge, fontWeight = FontWeight.SemiBold)
    }
}

@Composable
private fun ContactLogCard(log: ContactLogDto, modifier: Modifier = Modifier) {
    NayaraCard(modifier = modifier.fillMaxWidth()) {
        Column(
            modifier = Modifier.padding(NayaraSpacing.Lg),
            verticalArrangement = Arrangement.spacedBy(NayaraSpacing.Xxs),
        ) {
            Text("${log.channelLabel} · ${log.outcomeLabel}", fontWeight = FontWeight.SemiBold)
            val who = listOfNotNull(log.loggedBy, log.contactedRole).joinToString(" · ")
            val meta = listOfNotNull(who.ifBlank { null }, formatDateTime(log.contactedAt)).joinToString(" · ")
            if (meta.isNotBlank()) {
                Text(meta, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.nayara.textSecondary)
            }
            log.notes?.takeIf { it.isNotBlank() }?.let {
                Text(it, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.nayara.textTertiary)
            }
        }
    }
}

@Composable
private fun FeedbackSummaryRow(avg: Double?, count: Int) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(NayaraSpacing.Md),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (count > 0 && avg != null) {
            StarRow(avg.toFloat())
            Text("%.1f".format(avg), fontWeight = FontWeight.SemiBold)
            Text(
                "$count rating${if (count == 1) "" else "s"}",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.nayara.textSecondary,
            )
        } else {
            Text(
                "No ratings yet",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.nayara.textSecondary,
            )
        }
    }
}

@Composable
private fun FeedbackCard(fb: FeedbackDto, modifier: Modifier = Modifier) {
    NayaraCard(modifier = modifier.fillMaxWidth()) {
        Column(
            modifier = Modifier.padding(NayaraSpacing.Lg),
            verticalArrangement = Arrangement.spacedBy(NayaraSpacing.Xxs),
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(NayaraSpacing.Sm),
            ) {
                StarRow(fb.rating.toFloat(), size = 16.dp)
                Text(fb.sourceLabel, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.nayara.textTertiary)
            }
            fb.comment?.takeIf { it.isNotBlank() }?.let {
                Text(it, style = MaterialTheme.typography.bodyMedium)
            }
            val meta = listOfNotNull(fb.recordedBy, formatDateTime(fb.createdAt)).joinToString(" · ")
            if (meta.isNotBlank()) {
                Text(meta, style = MaterialTheme.typography.labelSmall, color = MaterialTheme.nayara.textTertiary)
            }
        }
    }
}

/** Row of five stars filled to nearest whole from [rating] (0..5). */
@Composable
private fun StarRow(rating: Float, size: Dp = 18.dp) {
    Row {
        for (i in 1..5) {
            Icon(
                imageVector = if (rating >= i - 0.5f) Icons.Filled.Star else Icons.Filled.StarBorder,
                contentDescription = null,
                tint = if (rating >= i - 0.5f) MaterialTheme.nayara.rewardCoin else MaterialTheme.nayara.textTertiary,
                modifier = Modifier.size(size),
            )
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun FeedbackSheet(
    submitting: Boolean,
    onDismiss: () -> Unit,
    onSubmit: (rating: Int, comment: String) -> Unit,
) {
    var rating by remember { mutableStateOf(0) }
    var comment by remember { mutableStateOf("") }
    NayaraBottomSheet(
        onDismissRequest = onDismiss,
        title = "Add rating",
        subtitle = "Capture how the customer felt about this visit.",
    ) {
        Column(
            modifier = Modifier.fillMaxWidth().imePadding(),
            verticalArrangement = Arrangement.spacedBy(NayaraSpacing.Md),
        ) {
            Text("Rating", style = MaterialTheme.typography.labelMedium, color = MaterialTheme.nayara.textSecondary)
            StarSelector(rating = rating, onRating = { rating = it })
            OutlinedTextField(
                value = comment,
                onValueChange = { comment = it },
                label = { Text("Comment (optional)") },
                minLines = 2,
                modifier = Modifier.fillMaxWidth(),
            )
            Row(horizontalArrangement = Arrangement.spacedBy(NayaraSpacing.Md)) {
                NayaraOutlinedButton(onClick = onDismiss, enabled = !submitting, modifier = Modifier.weight(1f)) {
                    Text("Cancel")
                }
                NayaraButton(
                    onClick = { onSubmit(rating, comment) },
                    loading = submitting,
                    enabled = rating in 1..5,
                    modifier = Modifier.weight(1f),
                ) { Text("Save") }
            }
        }
    }
}

@Composable
private fun StarSelector(rating: Int, onRating: (Int) -> Unit) {
    Row {
        for (i in 1..5) {
            IconButton(onClick = { onRating(i) }) {
                Icon(
                    imageVector = if (i <= rating) Icons.Filled.Star else Icons.Filled.StarBorder,
                    contentDescription = "$i star${if (i == 1) "" else "s"}",
                    tint = if (i <= rating) MaterialTheme.nayara.rewardCoin else MaterialTheme.nayara.textTertiary,
                    modifier = Modifier.size(32.dp),
                )
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun LogContactSheet(
    contacts: List<CustomerContactDto>,
    submitting: Boolean,
    onDismiss: () -> Unit,
    onSubmit: (channel: String, outcome: String, role: String?, contactId: Long?, notes: String) -> Unit,
) {
    var channel by remember { mutableStateOf(CRM_CHANNELS.first().first) }
    var outcome by remember { mutableStateOf(CRM_OUTCOMES.first().first) }
    var contactId by remember { mutableStateOf<Long?>(null) }
    var notes by remember { mutableStateOf("") }

    NayaraBottomSheet(
        onDismissRequest = onDismiss,
        title = "Log contact",
        subtitle = "Record an outreach attempt and how it went.",
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .verticalScroll(rememberScrollState())
                .imePadding(),
            verticalArrangement = Arrangement.spacedBy(NayaraSpacing.Md),
        ) {
            CrmDropdownField(
                label = "Channel",
                selectedLabel = CRM_CHANNELS.first { it.first == channel }.second,
                options = CRM_CHANNELS,
                optionLabel = { it.second },
                onSelect = { channel = it.first },
            )
            CrmDropdownField(
                label = "Outcome",
                selectedLabel = CRM_OUTCOMES.first { it.first == outcome }.second,
                options = CRM_OUTCOMES,
                optionLabel = { it.second },
                onSelect = { outcome = it.first },
            )
            if (contacts.isNotEmpty()) {
                val options = listOf<CustomerContactDto?>(null) + contacts
                CrmDropdownField(
                    label = "Person (optional)",
                    selectedLabel = contactPersonLabel(contacts.firstOrNull { it.id == contactId }),
                    options = options,
                    optionLabel = { contactPersonLabel(it) },
                    onSelect = { contactId = it?.id },
                )
            }
            OutlinedTextField(
                value = notes,
                onValueChange = { notes = it },
                label = { Text("Notes (optional)") },
                minLines = 2,
                modifier = Modifier.fillMaxWidth(),
            )
            Row(horizontalArrangement = Arrangement.spacedBy(NayaraSpacing.Md)) {
                NayaraOutlinedButton(onClick = onDismiss, enabled = !submitting, modifier = Modifier.weight(1f)) {
                    Text("Cancel")
                }
                NayaraButton(
                    onClick = {
                        // A chosen person carries its own role through to the API.
                        val role = contacts.firstOrNull { it.id == contactId }?.role
                        onSubmit(channel, outcome, role, contactId, notes)
                    },
                    loading = submitting,
                    modifier = Modifier.weight(1f),
                ) { Text("Save") }
            }
        }
    }
}

/** "Not specified" for the null slot, else the contact's name (falling back to its role). */
private fun contactPersonLabel(contact: CustomerContactDto?): String =
    contact?.let { it.name?.ifBlank { null } ?: it.roleLabel } ?: "Not specified"

@Composable
private fun <T> CrmDropdownField(
    label: String,
    selectedLabel: String,
    options: List<T>,
    optionLabel: (T) -> String,
    onSelect: (T) -> Unit,
) {
    var expanded by remember { mutableStateOf(false) }
    var fieldWidthPx by remember { mutableStateOf(0) }
    val fieldWidth = with(LocalDensity.current) { fieldWidthPx.toDp() }
    Box(Modifier.fillMaxWidth().onGloballyPositioned { fieldWidthPx = it.size.width }) {
        PickerField(label = label, value = selectedLabel, onClick = { expanded = true })
        DropdownMenu(
            expanded = expanded,
            onDismissRequest = { expanded = false },
            modifier = Modifier.width(fieldWidth),
        ) {
            options.forEach { opt ->
                DropdownMenuItem(
                    text = { Text(optionLabel(opt)) },
                    onClick = {
                        onSelect(opt)
                        expanded = false
                    },
                )
            }
        }
    }
}
