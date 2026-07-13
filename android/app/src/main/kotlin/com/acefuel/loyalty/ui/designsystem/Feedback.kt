package com.acefuel.loyalty.ui.designsystem

import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Error
import androidx.compose.material.icons.filled.Info
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Snackbar
import androidx.compose.material3.SnackbarDuration
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.SnackbarResult
import androidx.compose.material3.SnackbarVisuals
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.unit.dp
import com.acefuel.loyalty.ui.theme.NayaraSpacing
import com.acefuel.loyalty.ui.theme.nayara

// ============================================================================
// Typed snackbars — success / error / info with icon and semantic color,
// replacing android.widget.Toast (which floats outside the app's theming and
// can't offer actions like Undo/Retry). Standard pattern in Google's apps.
//
// Usage:
//   val snackbar = remember { SnackbarHostState() }
//   Scaffold(snackbarHost = { NayaraSnackbarHost(snackbar) }) { ... }
//   scope.launch { snackbar.showSuccess("Points redeemed") }
// ============================================================================

enum class SnackTone { Success, Error, Info }

class NayaraSnackbarVisuals(
    override val message: String,
    val tone: SnackTone,
    override val actionLabel: String? = null,
    override val withDismissAction: Boolean = false,
    override val duration: SnackbarDuration =
        if (actionLabel == null) SnackbarDuration.Short else SnackbarDuration.Long,
) : SnackbarVisuals

suspend fun SnackbarHostState.showSuccess(
    message: String,
    actionLabel: String? = null,
): SnackbarResult = showSnackbar(NayaraSnackbarVisuals(message, SnackTone.Success, actionLabel))

suspend fun SnackbarHostState.showError(
    message: String,
    actionLabel: String? = null,
): SnackbarResult = showSnackbar(NayaraSnackbarVisuals(message, SnackTone.Error, actionLabel))

suspend fun SnackbarHostState.showInfo(
    message: String,
    actionLabel: String? = null,
): SnackbarResult = showSnackbar(NayaraSnackbarVisuals(message, SnackTone.Info, actionLabel))

/** Snackbar host that renders [NayaraSnackbarVisuals] with tone colors + icon. */
@Composable
fun NayaraSnackbarHost(state: SnackbarHostState, modifier: Modifier = Modifier) {
    SnackbarHost(hostState = state, modifier = modifier) { data ->
        val tone = (data.visuals as? NayaraSnackbarVisuals)?.tone ?: SnackTone.Info
        val nayara = MaterialTheme.nayara
        val (container, content, iconTint, icon) = when (tone) {
            SnackTone.Success -> ToneStyle(
                nayara.statusSuccessContainer, nayara.statusOnSuccessContainer,
                nayara.statusSuccess, Icons.Filled.CheckCircle,
            )
            SnackTone.Error -> ToneStyle(
                nayara.statusErrorContainer, nayara.statusOnErrorContainer,
                nayara.statusError, Icons.Filled.Error,
            )
            SnackTone.Info -> ToneStyle(
                nayara.bgInverse, nayara.textInverse,
                nayara.textInverse, Icons.Filled.Info,
            )
        }
        Snackbar(
            modifier = Modifier.padding(NayaraSpacing.Md),
            shape = MaterialTheme.shapes.medium,
            containerColor = container,
            contentColor = content,
            action = data.visuals.actionLabel?.let { label ->
                {
                    TextButton(onClick = { data.performAction() }) {
                        Text(label, color = iconTint)
                    }
                }
            },
        ) {
            Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth()) {
                Icon(icon, contentDescription = null, tint = iconTint, modifier = Modifier.size(20.dp))
                Spacer(Modifier.width(NayaraSpacing.Md))
                Text(data.visuals.message, style = MaterialTheme.typography.bodyMedium)
            }
        }
    }
}

private data class ToneStyle(
    val container: Color,
    val content: Color,
    val iconTint: Color,
    val icon: ImageVector,
)
