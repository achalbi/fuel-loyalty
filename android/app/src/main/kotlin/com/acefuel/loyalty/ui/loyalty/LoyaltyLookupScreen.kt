package com.acefuel.loyalty.ui.loyalty

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.togetherWith
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
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ExpandMore
import androidx.compose.material.icons.filled.Login
import androidx.compose.material.icons.filled.Logout
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.platform.LocalSoftwareKeyboardController
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.LifecycleResumeEffect
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import com.acefuel.loyalty.R
import com.acefuel.loyalty.core.di.LocalContainer
import com.acefuel.loyalty.core.network.dto.LoyaltyResponse
import com.acefuel.loyalty.ui.designsystem.AnimatedCounter
import com.acefuel.loyalty.ui.designsystem.FormField
import com.acefuel.loyalty.ui.designsystem.InlineErrorCard
import com.acefuel.loyalty.ui.designsystem.NayaraCard
import com.acefuel.loyalty.ui.designsystem.NayaraTopBar
import com.acefuel.loyalty.ui.designsystem.SkeletonCard
import com.acefuel.loyalty.ui.designsystem.SkeletonList
import com.acefuel.loyalty.ui.designsystem.rememberHaptics
import com.acefuel.loyalty.ui.theme.NayaraButton
import com.acefuel.loyalty.ui.theme.NayaraHeroCard
import com.acefuel.loyalty.ui.theme.NayaraMotion
import com.acefuel.loyalty.ui.theme.NayaraNumerals
import com.acefuel.loyalty.ui.theme.NayaraPalette
import com.acefuel.loyalty.ui.theme.NayaraSpacing
import com.acefuel.loyalty.ui.theme.nayara
import java.time.OffsetDateTime
import java.time.format.DateTimeFormatter

/**
 * Inline loyalty lookup for the authenticated Home screen. It uses the same
 * repository, validation, offline fallback, and result components as the
 * public lookup route, but keeps the operator in the Home workflow.
 */
@Composable
fun LoyaltyLookupCard(modifier: Modifier = Modifier) {
    val container = LocalContainer.current
    val viewModel: LoyaltyViewModel = viewModel(
        factory = viewModelFactory { initializer { LoyaltyViewModel(container.loyaltyRepository) } },
    )
    val state by viewModel.state.collectAsStateWithLifecycle()
    val haptics = rememberHaptics()
    val keyboardController = LocalSoftwareKeyboardController.current

    var phone by rememberSaveable { mutableStateOf("") }

    fun submitLookup() {
        if (phone.length == 10) {
            keyboardController?.hide()
            viewModel.lookup(phone)
        }
    }

    fun clearLookup() {
        keyboardController?.hide()
        phone = ""
        viewModel.reset()
    }

    // The counter is shared, so one customer's number must never greet the
    // next one: wipe the field and any result as soon as the screen stops
    // being the foreground destination.
    LifecycleResumeEffect(Unit) {
        onPauseOrDispose { clearLookup() }
    }

    val canClear = state is LoyaltyUiState.Success || state is LoyaltyUiState.Error

    LaunchedEffect(state) {
        when (state) {
            is LoyaltyUiState.Success -> haptics.confirm()
            is LoyaltyUiState.Error -> haptics.reject()
            else -> Unit
        }
    }

    NayaraCard(modifier = modifier.fillMaxWidth()) {
        Column(Modifier.padding(NayaraSpacing.CardPadding)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(
                    imageVector = Icons.Filled.Search,
                    contentDescription = null,
                    tint = MaterialTheme.nayara.actionPrimary,
                )
                Spacer(Modifier.width(NayaraSpacing.Md))
                Column {
                    Text(
                        stringResource(R.string.loyalty_title),
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.SemiBold,
                    )
                    Text(
                        stringResource(R.string.loyalty_subtitle),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.nayara.textSecondary,
                    )
                }
            }
            Spacer(Modifier.height(NayaraSpacing.Lg))

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(NayaraSpacing.Md),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                FormField(
                    value = phone,
                    onValueChange = { input ->
                        val filtered = input.filter(Char::isDigit).take(10)
                        if (filtered != phone) {
                            phone = filtered
                            if (state !is LoyaltyUiState.Idle) viewModel.reset()
                        }
                    },
                    label = stringResource(R.string.loyalty_phone_label),
                    prefix = { Text("+91 ") },
                    keyboardOptions = KeyboardOptions(
                        keyboardType = KeyboardType.Phone,
                        imeAction = ImeAction.Search,
                    ),
                    keyboardActions = KeyboardActions(
                        onSearch = { submitLookup() },
                    ),
                    modifier = Modifier.weight(1f),
                )

                if (canClear) {
                    NayaraButton(
                        onClick = { clearLookup() },
                        modifier = Modifier.width(92.dp),
                    ) {
                        Text(stringResource(R.string.ds_clear))
                    }
                } else {
                    NayaraButton(
                        onClick = { submitLookup() },
                        enabled = phone.length == 10,
                        loading = state is LoyaltyUiState.Loading,
                        modifier = Modifier.width(92.dp),
                    ) {
                        Text(stringResource(R.string.loyalty_check_points))
                    }
                }
            }

            Spacer(Modifier.height(NayaraSpacing.Lg))
            LookupResultContent(state = state, onRetry = { viewModel.lookup(phone) })
        }
    }
}

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
    val haptics = rememberHaptics()
    val keyboardController = LocalSoftwareKeyboardController.current

    var phone by rememberSaveable { mutableStateOf("") }

    fun submitLookup() {
        if (phone.length == 10) {
            keyboardController?.hide()
            viewModel.lookup(phone)
        }
    }

    fun clearLookup() {
        keyboardController?.hide()
        phone = ""
        viewModel.reset()
    }

    // The counter is shared, so one customer's number must never greet the
    // next one: wipe the field and any result as soon as the screen stops
    // being the foreground destination.
    LifecycleResumeEffect(Unit) {
        onPauseOrDispose { clearLookup() }
    }

    val canClear = state is LoyaltyUiState.Success || state is LoyaltyUiState.Error

    LaunchedEffect(state) {
        when (state) {
            is LoyaltyUiState.Success -> haptics.confirm()
            is LoyaltyUiState.Error -> haptics.reject()
            else -> Unit
        }
    }

    Scaffold(
        topBar = {
            NayaraTopBar(
                title = "Ace Fuel Loyalty",
                actions = {
                    TextButton(onClick = onStaffAccess) {
                        Icon(
                            imageVector = if (isLoggedIn) Icons.Filled.Logout else Icons.Filled.Login,
                            contentDescription = null,
                        )
                        Spacer(Modifier.width(6.dp))
                        Text(stringResource(if (isLoggedIn) R.string.staff_home else R.string.staff_login))
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
                .padding(horizontal = NayaraSpacing.ScreenMargin, vertical = NayaraSpacing.Lg),
        ) {
            Text(
                text = stringResource(R.string.loyalty_title),
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.SemiBold,
            )
            Spacer(Modifier.height(NayaraSpacing.Xs))
            Text(
                text = stringResource(R.string.loyalty_subtitle),
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.nayara.textSecondary,
            )
            Spacer(Modifier.height(NayaraSpacing.Xl))

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(NayaraSpacing.Md),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                FormField(
                    value = phone,
                    onValueChange = { input ->
                        val filtered = input.filter(Char::isDigit).take(10)
                        if (filtered != phone) {
                            phone = filtered
                            // Editing clears any non-idle state, including an
                            // in-flight lookup, so a stale response can't land under
                            // the new number.
                            if (state !is LoyaltyUiState.Idle) {
                                viewModel.reset()
                            }
                        }
                    },
                    label = stringResource(R.string.loyalty_phone_label),
                    prefix = { Text("+91 ") },
                    keyboardOptions = KeyboardOptions(
                        keyboardType = KeyboardType.Phone,
                        imeAction = ImeAction.Search,
                    ),
                    keyboardActions = KeyboardActions(
                        onSearch = { submitLookup() },
                    ),
                    modifier = Modifier.weight(1f),
                )

                if (canClear) {
                    NayaraButton(
                        onClick = { clearLookup() },
                        modifier = Modifier.width(92.dp),
                    ) {
                        Text(stringResource(R.string.ds_clear))
                    }
                } else {
                    NayaraButton(
                        onClick = { submitLookup() },
                        enabled = phone.length == 10,
                        loading = state is LoyaltyUiState.Loading,
                        modifier = Modifier.width(92.dp),
                    ) {
                        Text(stringResource(R.string.loyalty_check_points))
                    }
                }
            }

            Spacer(Modifier.height(NayaraSpacing.Xl))

            LookupResultContent(state = state, onRetry = { viewModel.lookup(phone) })
        }
    }
}

@Composable
private fun LookupResultContent(
    state: LoyaltyUiState,
    onRetry: () -> Unit,
) {
    AnimatedContent(
        targetState = state,
        transitionSpec = {
            (fadeIn(tween(NayaraMotion.Base, easing = NayaraMotion.Enter)) +
                slideInVertically(tween(NayaraMotion.Base, easing = NayaraMotion.Enter)) { it / 6 })
                .togetherWith(fadeOut(tween(NayaraMotion.Fast, easing = NayaraMotion.Exit)))
        },
        label = "loyalty-result",
    ) { s ->
        when (s) {
            is LoyaltyUiState.Loading -> Column(Modifier.fillMaxWidth()) {
                SkeletonCard(lines = 2)
                Spacer(Modifier.height(NayaraSpacing.Lg))
                SkeletonList(count = 3, showAvatar = false)
            }
            is LoyaltyUiState.Error -> InlineErrorCard(
                message = s.message,
                onRetry = onRetry,
            )
            is LoyaltyUiState.Success -> Column(Modifier.fillMaxWidth()) {
                if (s.offline) {
                    OfflineBanner(s.fetchedAtMillis)
                    Spacer(Modifier.height(NayaraSpacing.Md))
                }
                LoyaltyResult(s.data)
            }
            LoyaltyUiState.Idle -> Spacer(Modifier.height(0.dp))
        }
    }
}

@Composable
private fun OfflineBanner(fetchedAtMillis: Long?) {
    val formatter = remember {
        java.text.SimpleDateFormat("dd MMM yyyy · hh:mm a", java.util.Locale.getDefault())
    }
    val stamp = fetchedAtMillis?.takeIf { it > 0 }?.let { formatter.format(java.util.Date(it)) }
    val offlineText = stringResource(R.string.loyalty_offline)
    val lastUpdated = if (stamp != null) stringResource(R.string.loyalty_last_updated, stamp) else null
    NayaraCard(modifier = Modifier.fillMaxWidth()) {
        Text(
            text = offlineText + (lastUpdated?.let { "\n$it" } ?: ""),
            modifier = Modifier.padding(NayaraSpacing.Lg),
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
                Spacer(Modifier.height(4.dp))
                AnimatedCounter(
                    value = data.totalPoints,
                    style = NayaraNumerals.Hero,
                    color = NayaraPalette.White,
                )
                Spacer(Modifier.height(8.dp))
                Text(
                    text = statusLine(data),
                    style = MaterialTheme.typography.bodyMedium,
                    color = NayaraPalette.Navy100,
                )
            }
        }

        if (data.customer.name != null || data.customer.phoneNumber != null) {
            Spacer(Modifier.height(NayaraSpacing.Lg))
            NayaraCard(modifier = Modifier.fillMaxWidth()) {
                Column(
                    modifier = Modifier.padding(NayaraSpacing.CardPadding),
                    verticalArrangement = Arrangement.spacedBy(NayaraSpacing.Xs),
                ) {
                    data.customer.name?.let {
                        Text(it, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
                    }
                    data.customer.phoneNumber?.let {
                        Text(
                            "Phone: $it",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.nayara.textSecondary,
                        )
                    }
                }
            }
        }

        Spacer(Modifier.height(NayaraSpacing.Xl))
        Text(
            text = stringResource(if (data.fullHistory) R.string.loyalty_activities_all else R.string.loyalty_activities_recent),
            style = MaterialTheme.typography.titleSmall,
            fontWeight = FontWeight.SemiBold,
            color = MaterialTheme.nayara.textSecondary,
        )
        Spacer(Modifier.height(NayaraSpacing.Sm))

        if (data.activities.isEmpty()) {
            Text(
                stringResource(R.string.loyalty_no_activity),
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.nayara.textSecondary,
            )
        } else {
            Column(verticalArrangement = Arrangement.spacedBy(NayaraSpacing.Md)) {
                data.activities.forEach { activity ->
                    ActivityRow(activity)
                }
            }
        }
    }
}

@Composable
private fun ActivityRow(activity: com.acefuel.loyalty.core.network.dto.LoyaltyActivityDto) {
    val haptics = rememberHaptics()
    var expanded by remember { mutableStateOf(false) }
    val chevronRotation by animateFloatAsState(
        targetValue = if (expanded) 180f else 0f,
        animationSpec = tween(NayaraMotion.Base, easing = NayaraMotion.Standard),
        label = "activity-chevron",
    )
    NayaraCard(
        onClick = {
            haptics.tick()
            expanded = !expanded
        },
        modifier = Modifier.fillMaxWidth(),
    ) {
        Column(modifier = Modifier.padding(NayaraSpacing.Lg)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(formatDate(activity.createdAt), style = MaterialTheme.typography.bodyMedium)
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(
                        text = if (activity.points >= 0) "+${activity.points}" else "${activity.points}",
                        style = NayaraNumerals.Default,
                        color = if (activity.points >= 0) {
                            MaterialTheme.nayara.statusSuccessText
                        } else {
                            MaterialTheme.nayara.textPrimary
                        },
                    )
                    Spacer(Modifier.width(NayaraSpacing.Xs))
                    Icon(
                        Icons.Filled.ExpandMore,
                        contentDescription = null,
                        tint = MaterialTheme.nayara.textTertiary,
                        modifier = Modifier.rotate(chevronRotation),
                    )
                }
            }
            AnimatedVisibility(visible = expanded) {
                Column(verticalArrangement = Arrangement.spacedBy(NayaraSpacing.Xs)) {
                    Spacer(Modifier.height(NayaraSpacing.Xs))
                    activity.fuelType?.let {
                        Text(
                            "Fuel: ${it.replaceFirstChar(Char::uppercase)}",
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.nayara.textSecondary,
                        )
                    }
                    Text(
                        "Vehicle: ${activity.vehicleNumber ?: "N/A"}",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.nayara.textSecondary,
                    )
                    Text(
                        "Fuel Amount: ${activity.fuelAmount?.let { "₹%.2f".format(it) } ?: "N/A"}",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.nayara.textSecondary,
                    )
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

// Built once instead of per recomposition (formatter construction is not cheap).
private val activityDateFormatter: DateTimeFormatter = DateTimeFormatter.ofPattern("dd MMM yyyy")

private fun formatDate(iso: String): String = runCatching {
    OffsetDateTime.parse(iso).format(activityDateFormatter)
}.getOrDefault(iso)
