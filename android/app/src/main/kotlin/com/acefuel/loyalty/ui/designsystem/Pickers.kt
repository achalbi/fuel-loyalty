package com.acefuel.loyalty.ui.designsystem

import androidx.compose.material3.AlertDialog
import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TimePicker
import androidx.compose.material3.rememberDatePickerState
import androidx.compose.material3.rememberTimePickerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import com.acefuel.loyalty.R
import java.time.LocalDate
import java.time.LocalTime
import java.time.format.DateTimeFormatter

// ============================================================================
// Date & time fields — Material 3 pickers behind a PickerField, replacing
// free-text "YYYY-MM-DD" / "HH:MM" inputs. DatePickerState works in UTC
// millis; we convert via epoch-day so the calendar date can never shift by
// timezone (a bug the old hand conversions had).
// ============================================================================

private val DateDisplay: DateTimeFormatter = DateTimeFormatter.ofPattern("dd MMM yyyy")

private const val MILLIS_PER_DAY = 86_400_000L

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DateField(
    label: String,
    value: LocalDate?,
    onChange: (LocalDate) -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    placeholder: String = "",
) {
    var open by rememberSaveable { mutableStateOf(false) }
    PickerField(
        label = label,
        value = value?.format(DateDisplay) ?: placeholder,
        onClick = { open = true },
        modifier = modifier,
        enabled = enabled,
    )
    if (open) {
        val state = rememberDatePickerState(
            initialSelectedDateMillis = value?.toEpochDay()?.times(MILLIS_PER_DAY),
        )
        DatePickerDialog(
            onDismissRequest = { open = false },
            confirmButton = {
                TextButton(
                    onClick = {
                        state.selectedDateMillis?.let { millis ->
                            onChange(LocalDate.ofEpochDay(Math.floorDiv(millis, MILLIS_PER_DAY)))
                        }
                        open = false
                    },
                ) { Text(stringResource(R.string.ds_confirm)) }
            },
            dismissButton = {
                TextButton(onClick = { open = false }) { Text(stringResource(R.string.ds_cancel)) }
            },
        ) {
            DatePicker(state = state)
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TimeField(
    label: String,
    value: LocalTime?,
    onChange: (LocalTime) -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
    placeholder: String = "",
) {
    var open by rememberSaveable { mutableStateOf(false) }
    PickerField(
        label = label,
        value = value?.format(DateTimeFormatter.ofPattern("HH:mm")) ?: placeholder,
        onClick = { open = true },
        modifier = modifier,
        enabled = enabled,
    )
    if (open) {
        val state = rememberTimePickerState(
            initialHour = value?.hour ?: 9,
            initialMinute = value?.minute ?: 0,
            is24Hour = true,
        )
        AlertDialog(
            onDismissRequest = { open = false },
            shape = MaterialTheme.shapes.large,
            title = { Text(label) },
            text = { TimePicker(state = state) },
            confirmButton = {
                TextButton(
                    onClick = {
                        onChange(LocalTime.of(state.hour, state.minute))
                        open = false
                    },
                ) { Text(stringResource(R.string.ds_confirm)) }
            },
            dismissButton = {
                TextButton(onClick = { open = false }) { Text(stringResource(R.string.ds_cancel)) }
            },
        )
    }
}
