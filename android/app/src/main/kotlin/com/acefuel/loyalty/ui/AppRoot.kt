package com.acefuel.loyalty.ui

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.rememberCoroutineScope
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import com.acefuel.loyalty.core.data.AuthState
import com.acefuel.loyalty.core.di.LocalContainer
import com.acefuel.loyalty.core.di.ServiceContainer
import androidx.navigation.NavType
import androidx.navigation.navArgument
import com.acefuel.loyalty.ui.adjust.AdjustPointsScreen
import com.acefuel.loyalty.ui.customers.CustomerProfileScreen
import com.acefuel.loyalty.ui.customers.CustomersScreen
import com.acefuel.loyalty.ui.home.HomeScreen
import com.acefuel.loyalty.ui.login.LoginScreen
import com.acefuel.loyalty.ui.loyalty.LoyaltyLookupScreen
import com.acefuel.loyalty.ui.redeem.RedeemScreen
import com.acefuel.loyalty.ui.transaction.TransactionScreen
import com.acefuel.loyalty.ui.scanner.PlateScannerScreen
import com.acefuel.loyalty.ui.theme.AceFuelLoyaltyTheme
import com.acefuel.loyalty.ui.admin.AdminMenuScreen
import com.acefuel.loyalty.ui.admin.attendance.AdminAttendanceScreen
import com.acefuel.loyalty.ui.admin.cycles.AdminCyclesScreen
import com.acefuel.loyalty.ui.admin.dashboard.AdminDashboardScreen
import com.acefuel.loyalty.ui.admin.fueltypes.AdminFuelTypesScreen
import com.acefuel.loyalty.ui.admin.pumps.AdminPumpsScreen
import com.acefuel.loyalty.ui.admin.rewardrates.AdminRewardRatesScreen
import com.acefuel.loyalty.ui.admin.schedules.AdminSchedulesScreen
import com.acefuel.loyalty.ui.admin.shifts.AdminShiftsScreen
import com.acefuel.loyalty.ui.admin.staff.AdminStaffScreen
import com.acefuel.loyalty.ui.admin.theme.AdminThemeScreen
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
    const val ADMIN_MENU = "admin_menu"
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

            // Register this device's FCM token once signed in (best-effort).
            LaunchedEffect(loggedIn) {
                if (loggedIn) {
                    runCatching {
                        com.google.firebase.messaging.FirebaseMessaging.getInstance().token
                            .addOnSuccessListener { token ->
                                scope.launch { runCatching { container.pushRepository.register(token) } }
                            }
                    }
                }
            }

            // Reactive navigation: leave login on success; leave home on logout.
            LaunchedEffect(authState, currentRoute) {
                if (loggedIn && currentRoute == Routes.LOGIN) {
                    navController.navigate(Routes.HOME) {
                        popUpTo(Routes.LOYALTY)
                    }
                } else if (!loggedIn && currentRoute == Routes.HOME) {
                    navController.navigate(Routes.LOYALTY) {
                        popUpTo(0)
                    }
                }
            }

            NavHost(navController = navController, startDestination = Routes.LOYALTY) {
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
                    if (user != null) {
                        HomeScreen(
                            user = user,
                            onNewTransaction = { navController.navigate(Routes.NEW_TRANSACTION) },
                            onCustomers = { navController.navigate(Routes.CUSTOMERS) },
                            onRedeem = { navController.navigate(Routes.REDEEM) },
                            onAdjustPoints = { navController.navigate(Routes.ADJUST) },
                            onAdmin = { navController.navigate(Routes.ADMIN_MENU) },
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
                        scannedPlate = scannedPlate,
                    )
                }
                composable("plate_scanner") {
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
                    RedeemScreen(onBack = { navController.popBackStack() })
                }
                composable(Routes.ADJUST) {
                    AdjustPointsScreen(onBack = { navController.popBackStack() })
                }
                composable(Routes.CUSTOMERS) {
                    CustomersScreen(
                        onBack = { navController.popBackStack() },
                        onOpenCustomer = { id -> navController.navigate("customer/$id") },
                    )
                }
                composable(
                    Routes.CUSTOMER_PROFILE,
                    arguments = listOf(navArgument("id") { type = NavType.LongType }),
                ) { entry ->
                    val id = entry.arguments?.getLong("id") ?: return@composable
                    CustomerProfileScreen(customerId = id, onBack = { navController.popBackStack() })
                }

                // ---- Admin ----
                val back: () -> Unit = { navController.popBackStack() }
                composable(Routes.ADMIN_MENU) {
                    AdminMenuScreen(onBack = back, onOpen = { route -> navController.navigate(route) })
                }
                composable("admin_dashboard") { AdminDashboardScreen(onBack = back) }
                composable("admin_transactions") { AdminTransactionsScreen(onBack = back) }
                composable("admin_users") { AdminUsersScreen(onBack = back) }
                composable("admin_fueltypes") { AdminFuelTypesScreen(onBack = back) }
                composable("admin_vehicletypes") { AdminVehicleTypesScreen(onBack = back) }
                composable("admin_pumps") { AdminPumpsScreen(onBack = back) }
                composable("admin_rewardrates") { AdminRewardRatesScreen(onBack = back) }
                composable("admin_theme") { AdminThemeScreen(onBack = back) }
                composable("admin_schedules") { AdminSchedulesScreen(onBack = back) }
                composable("admin_staff") { AdminStaffScreen(onBack = back) }
                composable("admin_shifts") { AdminShiftsScreen(onBack = back) }
                composable("admin_cycles") { AdminCyclesScreen(onBack = back) }
                composable("admin_attendance") { AdminAttendanceScreen(onBack = back) }
            }
        }
    }
}
