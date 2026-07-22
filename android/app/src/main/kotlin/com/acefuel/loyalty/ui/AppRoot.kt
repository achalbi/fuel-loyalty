package com.acefuel.loyalty.ui

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.consumeWindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AccountCircle
import androidx.compose.material.icons.filled.CameraAlt
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.People
import androidx.compose.material.icons.filled.Redeem
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Scaffold
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.core.content.ContextCompat
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.NavHostController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import com.acefuel.loyalty.core.data.AuthState
import com.acefuel.loyalty.core.di.LocalContainer
import com.acefuel.loyalty.core.di.ServiceContainer
import androidx.navigation.NavType
import androidx.navigation.navArgument
import com.acefuel.loyalty.ui.account.AccountScreen
import com.acefuel.loyalty.ui.designsystem.NayaraBottomBar
import com.acefuel.loyalty.ui.designsystem.NayaraNavItem
import com.acefuel.loyalty.ui.adjust.AdjustPointsScreen
import com.acefuel.loyalty.ui.customers.CustomerProfileScreen
import com.acefuel.loyalty.ui.customers.CustomersScreen
import com.acefuel.loyalty.ui.home.HomeScreen
import com.acefuel.loyalty.ui.login.LoginScreen
import com.acefuel.loyalty.ui.loyalty.LoyaltyLookupScreen
import com.acefuel.loyalty.ui.mypump.MyPumpScreen
import com.acefuel.loyalty.ui.redeem.RedeemScreen
import com.acefuel.loyalty.ui.transaction.TransactionScreen
import com.acefuel.loyalty.ui.scanner.PlateScannerScreen
import com.acefuel.loyalty.ui.visitentry.VisitEntryScreen
import com.acefuel.loyalty.ui.settlement.SettlementScreen
import com.acefuel.loyalty.ui.theme.AceFuelLoyaltyTheme
import com.acefuel.loyalty.ui.theme.NayaraMotion
import com.acefuel.loyalty.ui.admin.AdminRoutes
import com.acefuel.loyalty.ui.admin.AdminShell
import com.acefuel.loyalty.ui.admin.attendance.AdminAttendanceScreen
import com.acefuel.loyalty.ui.admin.cycles.AdminCyclesScreen
import com.acefuel.loyalty.ui.admin.fueltypes.AdminFuelTypesScreen
import com.acefuel.loyalty.ui.admin.products.AdminProductsScreen
import com.acefuel.loyalty.ui.admin.pumps.AdminPumpsScreen
import com.acefuel.loyalty.ui.admin.rewardrates.AdminRewardRatesScreen
import com.acefuel.loyalty.ui.admin.notifications.NotificationsHistoryScreen
import com.acefuel.loyalty.ui.admin.schedules.AdminSchedulesScreen
import com.acefuel.loyalty.ui.admin.shifts.AdminShiftsScreen
import com.acefuel.loyalty.ui.admin.staff.AdminStaffScreen
import com.acefuel.loyalty.ui.admin.theme.AdminThemeScreen
import com.acefuel.loyalty.ui.admin.campaigns.AdminCampaignsScreen
import com.acefuel.loyalty.ui.admin.crm.AdminReachOutScreen
import com.acefuel.loyalty.ui.admin.reports.AdminReportsScreen
import com.acefuel.loyalty.ui.admin.settlements.AdminSettlementsScreen
import com.acefuel.loyalty.ui.admin.transactions.AdminTransactionsScreen
import com.acefuel.loyalty.ui.admin.users.AdminUsersScreen
import com.acefuel.loyalty.ui.admin.vehicletypes.AdminVehicleTypesScreen
import kotlinx.coroutines.launch

private object Routes {
    const val LOYALTY = "loyalty"
    const val LOGIN = "login"
    const val HOME = "home"
    const val REDEEM = "redeem"
    const val ADJUST = "adjust"
    const val CUSTOMERS = "customers"
    const val CUSTOMER_PROFILE = "customer/{id}"
    const val NEW_TRANSACTION = "new_transaction"

    /**
     * The admin section's own 4-tab shell (Overview · Customers · Ops ·
     * Settings) — see ui/admin/AdminShell.kt. Replaces the old `admin_menu`
     * list-of-thirteen. The 13 verticals are still individual routes on this
     * NavHost; the shell pushes them.
     */
    const val ADMIN = AdminRoutes.SHELL
    const val ACCOUNT = "account"
    const val PLATE_SCANNER = "plate_scanner"
    const val MY_PUMP = "my_pump"
    const val CAPTURE_VISIT = "capture_visit"
    const val SETTLEMENT = "settlement"
}

/**
 * Bottom navigation — DESIGN_BRIEF §4a.
 *
 *   [ Home ]  [ Customers ]  ( SCAN )  [ Redeem ]  [ Account ]
 *
 * The brief specifies an **Activity** tab in the Redeem slot. It isn't here
 * because it can't be: there is no staff-scoped transactions endpoint. The API
 * exposes only `GET /api/v1/staff/customers/:id/ledger` (one customer at a
 * time) and `GET /api/v1/admin/transactions` (admin-only). A staff activity
 * feed needs a new server route before it can have a tab. Redeem takes the slot
 * meanwhile — it's the second-most-used action and it earns its place.
 */
private val BottomNavItems = listOf(
    NayaraNavItem(Routes.HOME, "Home", Icons.Filled.Home),
    NayaraNavItem(Routes.CUSTOMERS, "Customers", Icons.Filled.People),
    NayaraNavItem(Routes.REDEEM, "Redeem", Icons.Filled.Redeem),
    NayaraNavItem(Routes.ACCOUNT, "Account", Icons.Filled.AccountCircle),
)

/** Routes that show the bar. Everything else (scanner, forms, admin) is full-bleed. */
private val BottomBarRoutes = BottomNavItems.map { it.route }.toSet()

/**
 * Tab switching keeps the back stack shallow: pop back to Home, don't stack
 * siblings, and restore each tab's scroll position on return. Without
 * `launchSingleTop` a double-tap on a tab pushes a duplicate copy of it.
 */
private fun NavHostController.switchTab(route: String) {
    navigate(route) {
        popUpTo(Routes.HOME) { saveState = true }
        launchSingleTop = true
        restoreState = true
    }
}

@Composable
fun AppRoot(container: ServiceContainer) {
    CompositionLocalProvider(LocalContainer provides container) {
        val darkTheme = isSystemInDarkTheme()
        val primaryHex by container.themeRepository.primaryColorHex.collectAsStateWithLifecycle()

        AceFuelLoyaltyTheme(primaryHex = primaryHex, darkTheme = darkTheme) {
            val navController = rememberNavController()
            val authState by container.authRepository.state.collectAsStateWithLifecycle()
            val scope = rememberCoroutineScope()

            // Bootstrap theme + session once.
            LaunchedEffect(Unit) {
                launch { container.themeRepository.refresh() }
                launch { container.authRepository.loadSession() }
            }

            val currentRoute = navController.currentBackStackEntryAsState().value?.destination?.route
            val loggedIn = authState is AuthState.LoggedIn

            // Register this device's FCM token once signed in (best-effort),
            // and ask for POST_NOTIFICATIONS on Android 13+ — without the
            // runtime grant, pushes are silently dropped.
            val context = LocalContext.current
            val notifLauncher = rememberLauncherForActivityResult(
                ActivityResultContracts.RequestPermission(),
            ) { /* best-effort; push simply stays visible-off if denied */ }
            LaunchedEffect(loggedIn) {
                if (loggedIn) {
                    if (Build.VERSION.SDK_INT >= 33 &&
                        ContextCompat.checkSelfPermission(
                            context, Manifest.permission.POST_NOTIFICATIONS,
                        ) != PackageManager.PERMISSION_GRANTED
                    ) {
                        notifLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
                    }
                    runCatching {
                        com.google.firebase.messaging.FirebaseMessaging.getInstance().token
                            .addOnSuccessListener { token ->
                                scope.launch { runCatching { container.pushRepository.register(token) } }
                            }
                    }
                }
            }

            // Reactive navigation: send a fresh login and a restored session to
            // Home. On logout, return to the public landing from WHEREVER we are
            // (home, account, admin, a form…). Keying on LoggedOut (not just
            // !loggedIn) skips the Unknown session-restore transient at startup.
            // Without covering every authenticated route, logging out of
            // admin/account just leaves that screen showing its user==null
            // spinner until you press back.
            LaunchedEffect(authState, currentRoute) {
                if (loggedIn && currentRoute in setOf(Routes.LOGIN, Routes.LOYALTY)) {
                    navController.navigate(Routes.HOME) {
                        popUpTo(Routes.LOYALTY) { inclusive = true }
                        launchSingleTop = true
                    }
                } else if (authState is AuthState.LoggedOut &&
                    currentRoute != null &&
                    currentRoute != Routes.LOYALTY &&
                    currentRoute != Routes.LOGIN
                ) {
                    navController.navigate(Routes.LOYALTY) {
                        popUpTo(0)
                    }
                }
            }

            // The bar only exists for a signed-in staff member, and only on the
            // four tab destinations — never over the scanner, a form, or admin.
            val showBottomBar = loggedIn && currentRoute in BottomBarRoutes

            // SCAN is the app's highest-frequency action, so it gets the center
            // slot rather than living two taps deep on Home. Pushing the
            // transaction screen *then* the scanner means popping the scanner
            // lands on the transaction form with the plate already resolved —
            // the scanner writes to `previousBackStackEntry`, so it has to be
            // the transaction screen sitting underneath it, not Home.
            val onScan: () -> Unit = remember(navController) {
                {
                    navController.navigate(Routes.NEW_TRANSACTION)
                    navController.navigate(Routes.PLATE_SCANNER)
                }
            }

            Scaffold(
                // The shell owns only the bottom bar. Each screen's own Scaffold
                // + TopAppBar owns the status-bar (top) inset, so the shell must
                // NOT also apply it — otherwise the top inset is added twice and
                // every screen's app bar is pushed down by a doubled gap.
                contentWindowInsets = WindowInsets(0, 0, 0, 0),
                bottomBar = {
                    if (showBottomBar) {
                        NayaraBottomBar(
                            items = BottomNavItems,
                            currentRoute = currentRoute,
                            onSelect = { route ->
                                if (route != currentRoute) navController.switchTab(route)
                            },
                            onScan = onScan,
                            scanIcon = Icons.Filled.CameraAlt,
                        )
                    }
                },
            ) { innerPadding ->

            // Screen transitions per DESIGN_BRIEF §8: forward = gentle
            // slide-up + fade (Base/Emphasized); back = fast fade (Fast).
            NavHost(
                navController = navController,
                startDestination = Routes.LOYALTY,
                // Reserve space for the bottom bar and mark those insets consumed
                // so nested screen Scaffolds don't re-apply them.
                modifier = Modifier
                    .padding(innerPadding)
                    .consumeWindowInsets(innerPadding),
                enterTransition = {
                    fadeIn(tween(NayaraMotion.Base, easing = NayaraMotion.Enter)) +
                        slideInVertically(tween(NayaraMotion.Base, easing = NayaraMotion.Emphasized)) { it / 16 }
                },
                exitTransition = { fadeOut(tween(NayaraMotion.Fast, easing = NayaraMotion.Exit)) },
                popEnterTransition = { fadeIn(tween(NayaraMotion.Fast, easing = NayaraMotion.Enter)) },
                popExitTransition = {
                    fadeOut(tween(NayaraMotion.Fast, easing = NayaraMotion.Exit)) +
                        slideOutVertically(tween(NayaraMotion.Fast, easing = NayaraMotion.Exit)) { it / 16 }
                },
            ) {
                composable(Routes.LOYALTY) {
                    LoyaltyLookupScreen(
                        isLoggedIn = loggedIn,
                        onStaffAccess = {
                            navController.navigate(if (loggedIn) Routes.HOME else Routes.LOGIN)
                        },
                    )
                }
                composable(Routes.LOGIN) {
                    LoginScreen(onBack = { navController.popBackStack() })
                }
                composable(Routes.HOME) {
                    val user = (authState as? AuthState.LoggedIn)?.user
                    if (user == null) {
                        // Session still loading, or logout in flight before the
                        // reactive navigation kicks in — never show a blank screen.
                        Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                            CircularProgressIndicator()
                        }
                    } else {
                        HomeScreen(
                            user = user,
                            onNewTransaction = { navController.navigate(Routes.NEW_TRANSACTION) },
                            onCustomers = { navController.switchTab(Routes.CUSTOMERS) },
                            onRedeem = { navController.switchTab(Routes.REDEEM) },
                            onAdjustPoints = { navController.navigate(Routes.ADJUST) },
                            onCaptureVisit = { navController.navigate(Routes.CAPTURE_VISIT) },
                            onDailySettlement = { navController.navigate(Routes.SETTLEMENT) },
                            onAdmin = { navController.navigate(Routes.ADMIN) },
                        )
                    }
                }
                composable(Routes.ACCOUNT) {
                    val user = (authState as? AuthState.LoggedIn)?.user
                    if (user == null) {
                        Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                            CircularProgressIndicator()
                        }
                    } else {
                        AccountScreen(
                            user = user,
                            onAdmin = { navController.navigate(Routes.ADMIN) },
                            onMyPump = { navController.navigate(Routes.MY_PUMP) },
                            onLogout = { scope.launch { container.authRepository.logout() } },
                        )
                    }
                }
                composable(Routes.NEW_TRANSACTION) { entry ->
                    val scannedPlate by entry.savedStateHandle
                        .getStateFlow<String?>("scanned_plate", null)
                        .collectAsStateWithLifecycle()
                    TransactionScreen(
                        onBack = { navController.popBackStack() },
                        onViewCustomer = { id ->
                            navController.navigate("customer/$id") {
                                popUpTo(Routes.HOME)
                            }
                        },
                        onScanPlate = { navController.navigate("plate_scanner") },
                        onSetupPump = { navController.navigate(Routes.MY_PUMP) },
                        scannedPlate = scannedPlate,
                    )
                }
                composable(Routes.PLATE_SCANNER) {
                    PlateScannerScreen(
                        onBack = { navController.popBackStack() },
                        onResult = { plate ->
                            navController.previousBackStackEntry
                                ?.savedStateHandle?.set("scanned_plate", plate)
                            navController.popBackStack()
                        },
                    )
                }
                composable(Routes.REDEEM) {
                    // Reached only as a bottom-nav tab — no back arrow (system
                    // back still returns to Home via the tab back stack).
                    RedeemScreen(onBack = null)
                }
                composable(Routes.ADJUST) {
                    AdjustPointsScreen(onBack = { navController.popBackStack() })
                }
                composable(Routes.MY_PUMP) {
                    MyPumpScreen(onBack = { navController.popBackStack() })
                }
                composable(Routes.CAPTURE_VISIT) {
                    VisitEntryScreen(onBack = { navController.popBackStack() })
                }
                composable(Routes.SETTLEMENT) {
                    SettlementScreen(onBack = { navController.popBackStack() })
                }
                composable(Routes.CUSTOMERS) {
                    // Reached only as a bottom-nav tab — no back arrow (system
                    // back still returns to Home via the tab back stack).
                    CustomersScreen(
                        onBack = null,
                        onOpenCustomer = { id -> navController.navigate("customer/$id") },
                    )
                }
                composable(
                    Routes.CUSTOMER_PROFILE,
                    arguments = listOf(navArgument("id") { type = NavType.LongType }),
                ) { entry ->
                    val id = entry.arguments?.getLong("id") ?: return@composable
                    val profileUser = (authState as? AuthState.LoggedIn)?.user
                    CustomerProfileScreen(
                        customerId = id,
                        isAdmin = profileUser?.role == "admin",
                        onBack = { navController.popBackStack() },
                    )
                }

                // ---- Admin ----
                val back: () -> Unit = { navController.popBackStack() }

                // The shell (Overview · Customers · Ops · Settings). Its tabs are
                // internal state, not routes — only the leaves below are routes,
                // so the back stack stays exactly as shallow as it was before.
                composable(Routes.ADMIN) {
                    val user = (authState as? AuthState.LoggedIn)?.user
                    if (user == null) {
                        Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                            CircularProgressIndicator()
                        }
                    } else {
                        AdminShell(
                            user = user,
                            onExit = back,
                            onOpen = { route -> navController.navigate(route) },
                            onOpenCustomer = { id -> navController.navigate("customer/$id") },
                            onAdjustPoints = { navController.navigate(Routes.ADJUST) },
                            onRedeem = { navController.navigate(AdminRoutes.REDEEM) },
                            onLogout = { scope.launch { container.authRepository.logout() } },
                        )
                    }
                }

                // Redeem, reached from admin Ops. Distinct from the staff REDEEM
                // tab route: pushed, so it gets a back arrow (the tab version has
                // none) and does not raise the staff tab bar over the admin shell.
                composable(AdminRoutes.REDEEM) { RedeemScreen(onBack = back) }

                // E2: period-scoped customers list, pushed from the admin dashboard.
                composable(
                    AdminRoutes.CUSTOMERS_PERIOD,
                    arguments = listOf(
                        navArgument("start") { type = NavType.StringType; nullable = true; defaultValue = null },
                        navArgument("end") { type = NavType.StringType; nullable = true; defaultValue = null },
                    ),
                ) { entry ->
                    CustomersScreen(
                        onBack = { navController.popBackStack() },
                        onOpenCustomer = { id -> navController.navigate("customer/$id") },
                        startDate = entry.arguments?.getString("start")?.ifBlank { null },
                        endDate = entry.arguments?.getString("end")?.ifBlank { null },
                    )
                }

                composable(AdminRoutes.TRANSACTIONS) { AdminTransactionsScreen(onBack = back) }
                composable(AdminRoutes.REPORTS) { AdminReportsScreen(onBack = back) }
                composable(AdminRoutes.SETTLEMENTS) { AdminSettlementsScreen(onBack = back) }
                composable(AdminRoutes.CAMPAIGNS) { AdminCampaignsScreen(onBack = back) }
                composable(AdminRoutes.REACH_OUT) {
                    AdminReachOutScreen(
                        onBack = back,
                        onOpenCustomer = { id -> navController.navigate("customer/$id") },
                    )
                }
                composable(AdminRoutes.USERS) { AdminUsersScreen(onBack = back) }
                composable(AdminRoutes.FUEL_TYPES) { AdminFuelTypesScreen(onBack = back) }
                composable(AdminRoutes.VEHICLE_TYPES) { AdminVehicleTypesScreen(onBack = back) }
                composable(AdminRoutes.PRODUCTS) { AdminProductsScreen(onBack = back) }
                composable(AdminRoutes.PUMPS) { AdminPumpsScreen(onBack = back) }
                composable(AdminRoutes.REWARD_RATES) { AdminRewardRatesScreen(onBack = back) }
                composable(AdminRoutes.THEME) { AdminThemeScreen(onBack = back) }
                composable(AdminRoutes.SCHEDULES) {
                    AdminSchedulesScreen(
                        onBack = back,
                        onOpenHistory = { navController.navigate(AdminRoutes.NOTIFICATIONS_HISTORY) },
                    )
                }
                composable(AdminRoutes.NOTIFICATIONS_HISTORY) {
                    NotificationsHistoryScreen(onBack = back)
                }
                composable(AdminRoutes.STAFF) {
                    AdminStaffScreen(
                        onBack = back,
                        onAssignPump = { id -> navController.navigate(AdminRoutes.assignPump(id)) },
                    )
                }
                composable(
                    AdminRoutes.ASSIGN_PUMP,
                    arguments = listOf(navArgument("id") { type = NavType.LongType }),
                ) { entry ->
                    val id = entry.arguments?.getLong("id") ?: return@composable
                    MyPumpScreen(
                        onBack = back,
                        staffMemberId = id,
                        title = "Assign Pump",
                        intro = "Assign this operator's pump and its active nozzles. Every transaction they record will use this pump.",
                        saveLabel = "Save Pump Assignment",
                    )
                }
                composable(AdminRoutes.SHIFTS) { AdminShiftsScreen(onBack = back) }
                composable(AdminRoutes.CYCLES) { AdminCyclesScreen(onBack = back) }
                composable(AdminRoutes.ATTENDANCE) { AdminAttendanceScreen(onBack = back) }
            }
            } // Scaffold content
        }
    }
}
