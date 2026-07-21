package com.acefuel.loyalty.ui.admin

import androidx.activity.compose.BackHandler
import androidx.compose.animation.Crossfade
import androidx.compose.animation.core.tween
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.consumeWindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Dashboard
import androidx.compose.material.icons.filled.People
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.Tune
import androidx.compose.material3.Scaffold
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import com.acefuel.loyalty.core.network.dto.UserDto
import com.acefuel.loyalty.ui.admin.dashboard.AdminDashboardScreen
import com.acefuel.loyalty.ui.admin.ops.AdminOpsScreen
import com.acefuel.loyalty.ui.admin.settings.AdminSettingsScreen
import com.acefuel.loyalty.ui.customers.CustomersScreen
import com.acefuel.loyalty.ui.designsystem.NayaraNavItem
import com.acefuel.loyalty.ui.designsystem.NayaraTabBar
import com.acefuel.loyalty.ui.theme.NayaraMotion

// ============================================================================
// Admin shell — Option A ("Console") from ADMIN_NATIVE_DIRECTIONS.md.
//
// Replaces AdminMenuScreen: a flat list of 13 rows in 3 groups, where the
// dashboard — the thing an admin opens the app *for* — was one row among
// thirteen, and every daily task sat two taps deep behind a menu.
//
// The web console's sidebar has the same shape and the same problem. Option A
// keeps its vocabulary (an admin who knows the web app knows this) but reweights
// it around frequency rather than around the schema:
//
//   [ Overview ]  [ Customers ]  [ Ops ]  [ Settings ]
//     dashboard      4,182         the      the 6 things
//     lands first    members       daily    you set once
//                                  work
//
// Six of the old menu's thirteen rows were config that changes twice a year.
// They're all behind Settings now, and the three tabs in front of it are about
// the work.
//
// STATE, NOT A NESTED NAVHOST. The tabs are peers with no history between them
// (Compose's own guidance: don't nest NavHosts for a tab shell you can express
// as state). Deep screens — every one of the 13 verticals — still push onto the
// *outer* NavController, so they get the real back stack, the shared transitions,
// and the full-bleed treatment. The shell owns nothing but which tab is lit.
//
// Back from a non-Overview tab returns to Overview rather than exiting admin —
// the standard Android tab contract. Back from Overview exits to staff Home.
// ============================================================================

/** The four admin destinations. Route strings are shell-local — not NavHost routes. */
enum class AdminTab(val route: String, val label: String) {
    Overview("admin_tab_overview", "Overview"),
    Customers("admin_tab_customers", "Customers"),
    Ops("admin_tab_ops", "Ops"),
    Settings("admin_tab_settings", "Settings"),
}

private val AdminNavItems = listOf(
    NayaraNavItem(AdminTab.Overview.route, AdminTab.Overview.label, Icons.Filled.Dashboard),
    NayaraNavItem(AdminTab.Customers.route, AdminTab.Customers.label, Icons.Filled.People),
    NayaraNavItem(AdminTab.Ops.route, AdminTab.Ops.label, Icons.Filled.Tune),
    NayaraNavItem(AdminTab.Settings.route, AdminTab.Settings.label, Icons.Filled.Settings),
)

/**
 * @param onExit leave admin entirely (system back from the Overview tab).
 * @param onOpen push one of the 13 admin verticals onto the outer NavController.
 * @param onOpenCustomer push a customer profile (shared with the staff shell).
 */
@Composable
fun AdminShell(
    user: UserDto,
    onExit: () -> Unit,
    onOpen: (String) -> Unit,
    onOpenCustomer: (Long) -> Unit,
    onAdjustPoints: () -> Unit,
    onRedeem: () -> Unit,
    onLogout: () -> Unit,
    modifier: Modifier = Modifier,
) {
    var tab by rememberSaveable { mutableStateOf(AdminTab.Overview) }

    // Android tab contract: back from a secondary tab returns to the primary
    // one; only the primary tab's back exits the section. Enabled only when
    // off-Overview so Overview's back falls through to the NavHost and pops.
    BackHandler(enabled = tab != AdminTab.Overview) { tab = AdminTab.Overview }

    Scaffold(
        // The shell owns the bottom bar only. Every tab either has its own
        // TopAppBar (Overview, Customers) or applies statusBarsPadding itself
        // (Ops, Settings) — so the shell must not apply a top inset, or every
        // admin screen gets pushed down by a doubled gap.
        contentWindowInsets = WindowInsets(0, 0, 0, 0),
        bottomBar = {
            NayaraTabBar(
                items = AdminNavItems,
                currentRoute = tab.route,
                onSelect = { route ->
                    AdminTab.entries.firstOrNull { it.route == route }?.let { tab = it }
                },
            )
        },
        modifier = modifier,
    ) { innerPadding ->
        // Reserve the tab bar's space and mark those insets *consumed*. Overview
        // and Customers each nest their own Scaffold; without this they re-apply
        // the navigation-bar inset on top of the tab bar's, and every admin
        // screen ends up with a dead strip of padding at the bottom. Same trap
        // the staff shell documents in AppRoot.
        Box(
            Modifier
                .fillMaxSize()
                .padding(innerPadding)
                .consumeWindowInsets(innerPadding),
        ) {
            Crossfade(
                targetState = tab,
                animationSpec = tween(NayaraMotion.Base, easing = NayaraMotion.Standard),
                label = "admin-tab",
            ) { target ->
                when (target) {
                    // Dashboard-first: the whole point of Option A. Its back
                    // arrow is the visible way *out* of the console back to the
                    // staff app — the landing tab owns the section's exit
                    // (system back from here does the same).
                    AdminTab.Overview -> AdminDashboardScreen(
                        onBack = onExit,
                        onViewCustomers = { start, end -> onOpen(AdminRoutes.customersPeriod(start, end)) },
                    )

                    // The same customers screen staff use. An admin's customer
                    // list is not a different customer list, and shipping a second
                    // one would be two screens to keep in sync forever.
                    AdminTab.Customers -> CustomersScreen(
                        onBack = null,
                        onOpenCustomer = onOpenCustomer,
                    )

                    AdminTab.Ops -> AdminOpsScreen(
                        onAttendance = { onOpen(AdminRoutes.ATTENDANCE) },
                        onAdjustPoints = onAdjustPoints,
                        onRedeem = onRedeem,
                        onNotifications = { onOpen(AdminRoutes.SCHEDULES) },
                        onStaff = { onOpen(AdminRoutes.STAFF) },
                        onShifts = { onOpen(AdminRoutes.SHIFTS) },
                        onCycles = { onOpen(AdminRoutes.CYCLES) },
                        onTransactions = { onOpen(AdminRoutes.TRANSACTIONS) },
                    )

                    AdminTab.Settings -> AdminSettingsScreen(
                        user = user,
                        onUsers = { onOpen(AdminRoutes.USERS) },
                        onRewardRates = { onOpen(AdminRoutes.REWARD_RATES) },
                        onFuelTypes = { onOpen(AdminRoutes.FUEL_TYPES) },
                        onVehicleTypes = { onOpen(AdminRoutes.VEHICLE_TYPES) },
                        onProducts = { onOpen(AdminRoutes.PRODUCTS) },
                        onPumps = { onOpen(AdminRoutes.PUMPS) },
                        onNotifications = { onOpen(AdminRoutes.SCHEDULES) },
                        onTheme = { onOpen(AdminRoutes.THEME) },
                        onLogout = onLogout,
                    )
                }
            }
        }
    }

    // Overview's back exits admin. (BackHandler above intercepts the other tabs.)
    BackHandler(enabled = tab == AdminTab.Overview) { onExit() }
}

/**
 * Routes for the 13 admin verticals, registered on the outer NavHost in AppRoot.
 * Previously these were bare strings duplicated between AdminMenuScreen and
 * AppRoot; one typo in either and the row silently did nothing.
 */
object AdminRoutes {
    const val SHELL = "admin"
    const val TRANSACTIONS = "admin_transactions"
    const val USERS = "admin_users"
    const val FUEL_TYPES = "admin_fueltypes"
    const val VEHICLE_TYPES = "admin_vehicletypes"
    const val PRODUCTS = "admin_products"
    const val PUMPS = "admin_pumps"
    const val REWARD_RATES = "admin_rewardrates"
    const val THEME = "admin_theme"
    const val SCHEDULES = "admin_schedules"
    const val STAFF = "admin_staff"
    const val ASSIGN_PUMP = "admin_assign_pump/{id}"
    fun assignPump(id: Long) = "admin_assign_pump/$id"
    // E2 dashboard drill-through: a period-scoped customers list.
    const val CUSTOMERS_PERIOD = "admin_customers_period?start={start}&end={end}"
    fun customersPeriod(start: String?, end: String?) =
        "admin_customers_period?start=${start.orEmpty()}&end=${end.orEmpty()}"
    const val SHIFTS = "admin_shifts"
    const val CYCLES = "admin_cycles"
    const val ATTENDANCE = "admin_attendance"
    const val REDEEM = "admin_redeem"
}
