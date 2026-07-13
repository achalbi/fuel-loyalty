package com.acefuel.loyalty.ui.designsystem

import androidx.compose.foundation.layout.RowScope
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarScrollBehavior
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import com.acefuel.loyalty.R

// ============================================================================
// NayaraTopBar — the app's one top bar: consistent back affordance and
// optional scroll behavior (pass TopAppBarDefaults.pinnedScrollBehavior() and
// hook Scaffold's nestedScroll to get the standard elevate-on-scroll).
// ============================================================================

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun NayaraTopBar(
    title: String,
    modifier: Modifier = Modifier,
    onBack: (() -> Unit)? = null,
    scrollBehavior: TopAppBarScrollBehavior? = null,
    actions: @Composable RowScope.() -> Unit = {},
) {
    TopAppBar(
        title = { Text(title) },
        modifier = modifier,
        navigationIcon = {
            if (onBack != null) {
                IconButton(onClick = onBack) {
                    Icon(
                        Icons.AutoMirrored.Filled.ArrowBack,
                        contentDescription = stringResource(R.string.ds_back),
                    )
                }
            }
        },
        scrollBehavior = scrollBehavior,
        actions = actions,
    )
}
