package com.acefuel.loyalty.ui.designsystem

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.SheetState
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.acefuel.loyalty.ui.theme.NayaraSpacing
import com.acefuel.loyalty.ui.theme.nayara

// ============================================================================
// Bottom sheet — DESIGN_BRIEF §7.
// Top radius xxl (28), 36×4 handle in border.strong, scrim overlay.scrim.
//
// Sheets are the primary "one screen, one job" surface in the staff app: the
// award keypad, the plate-confirm step, and the post-scan action picker are all
// sheets rather than screens, because none of them should cost a back-stack
// entry or lose the context behind them.
// ============================================================================

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun NayaraBottomSheet(
    onDismissRequest: () -> Unit,
    modifier: Modifier = Modifier,
    sheetState: SheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
    title: String? = null,
    subtitle: String? = null,
    content: @Composable ColumnScope.() -> Unit,
) {
    val nayara = MaterialTheme.nayara
    ModalBottomSheet(
        onDismissRequest = onDismissRequest,
        sheetState = sheetState,
        modifier = modifier,
        shape = SheetShape,
        containerColor = nayara.bgSurface,
        scrimColor = nayara.overlayScrim,
        dragHandle = { NayaraSheetHandle() },
    ) {
        Column(
            Modifier
                .fillMaxWidth()
                .navigationBarsPadding()
                .padding(horizontal = NayaraSpacing.Lg)
                .padding(bottom = NayaraSpacing.Xl),
        ) {
            if (title != null) {
                Text(
                    text = title,
                    style = MaterialTheme.typography.titleLarge.copy(fontWeight = FontWeight.ExtraBold),
                    color = nayara.textPrimary,
                )
            }
            if (subtitle != null) {
                Spacer(Modifier.height(NayaraSpacing.Xs))
                Text(
                    text = subtitle,
                    style = MaterialTheme.typography.bodyMedium,
                    color = nayara.textSecondary,
                )
            }
            if (title != null || subtitle != null) {
                Spacer(Modifier.height(NayaraSpacing.Lg))
            }
            content()
        }
    }
}

@Composable
private fun NayaraSheetHandle() {
    val nayara = MaterialTheme.nayara
    Box(
        Modifier
            .fillMaxWidth()
            .padding(vertical = NayaraSpacing.Md),
        contentAlignment = Alignment.Center,
    ) {
        Box(
            Modifier
                .size(width = 36.dp, height = 4.dp)
                .clip(CircleShape)
                .background(nayara.borderStrong),
        )
    }
}
