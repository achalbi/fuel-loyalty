package com.acefuel.loyalty.ui.designsystem

import androidx.compose.foundation.layout.BoxScope
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.material3.pulltorefresh.PullToRefreshDefaults
import androidx.compose.material3.pulltorefresh.rememberPullToRefreshState
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier

// ============================================================================
// NayaraPullToRefresh — Material 3 pull-to-refresh with brand indicator
// colors. Every ViewModel in this app already exposes refresh(); this wires
// the standard gesture to it.
//
// Usage:
//   NayaraPullToRefresh(isRefreshing = state.refreshing, onRefresh = vm::refresh) {
//       LazyColumn { ... }   // content must be scrollable for the gesture
//   }
// ============================================================================

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun NayaraPullToRefresh(
    isRefreshing: Boolean,
    onRefresh: () -> Unit,
    modifier: Modifier = Modifier,
    content: @Composable BoxScope.() -> Unit,
) {
    val state = rememberPullToRefreshState()
    PullToRefreshBox(
        isRefreshing = isRefreshing,
        onRefresh = onRefresh,
        state = state,
        modifier = modifier,
        indicator = {
            PullToRefreshDefaults.Indicator(
                state = state,
                isRefreshing = isRefreshing,
                modifier = Modifier.align(Alignment.TopCenter),
                containerColor = MaterialTheme.colorScheme.surface,
                color = MaterialTheme.colorScheme.primary,
            )
        },
        content = content,
    )
}
