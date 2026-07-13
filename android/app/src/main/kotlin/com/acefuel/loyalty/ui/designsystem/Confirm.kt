package com.acefuel.loyalty.ui.designsystem

import androidx.compose.material3.AlertDialog
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.res.stringResource
import com.acefuel.loyalty.R
import com.acefuel.loyalty.ui.theme.nayara

// ============================================================================
// ConfirmDialog — the one confirmation dialog for the whole app, with a
// destructive variant that styles the confirm action in the error color
// (Google's convention: destructive confirm ≠ same visual weight as Cancel).
// Fires a reject/confirm haptic on the choice.
// ============================================================================

@Composable
fun ConfirmDialog(
    title: String,
    text: String,
    confirmLabel: String,
    onConfirm: () -> Unit,
    onDismiss: () -> Unit,
    destructive: Boolean = false,
    dismissLabel: String = stringResource(R.string.ds_cancel),
) {
    val haptics = rememberHaptics()
    AlertDialog(
        onDismissRequest = onDismiss,
        shape = MaterialTheme.shapes.large,
        title = { Text(title) },
        text = { Text(text) },
        confirmButton = {
            TextButton(
                onClick = {
                    if (destructive) haptics.reject() else haptics.confirm()
                    onConfirm()
                },
                colors = if (destructive) {
                    ButtonDefaults.textButtonColors(contentColor = MaterialTheme.nayara.statusError)
                } else {
                    ButtonDefaults.textButtonColors()
                },
            ) {
                Text(confirmLabel)
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text(dismissLabel) }
        },
    )
}
