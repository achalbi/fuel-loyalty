package com.acefuel.loyalty.core.data

import android.content.Context
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking

private val Context.settingsDataStore by preferencesDataStore(name = "settings")

/**
 * Per-device app settings backed by DataStore. Hydrated once at startup (mirrors
 * [com.acefuel.loyalty.core.auth.TokenStore]) so the value is available synchronously
 * to the first Compose frame, then kept in a [StateFlow] for reactive reads.
 */
class SettingsStore(private val context: Context) {

    private val _onDeviceScanFirst = MutableStateFlow(DEFAULT_ON_DEVICE_SCAN_FIRST)

    /**
     * When true, the plate scanner recognizes on-device (ML Kit) first and only calls
     * the Plate Recognizer backend when the local read isn't a valid plate. When false,
     * the server is primary and the on-device read is the fallback.
     */
    val onDeviceScanFirst: StateFlow<Boolean> = _onDeviceScanFirst.asStateFlow()

    /** Load the persisted value into the flow. Call once during app startup. */
    fun hydrateBlocking() = runBlocking {
        val prefs = context.settingsDataStore.data.first()
        _onDeviceScanFirst.value = prefs[ON_DEVICE_SCAN_FIRST_KEY] ?: DEFAULT_ON_DEVICE_SCAN_FIRST
    }

    suspend fun setOnDeviceScanFirst(value: Boolean) {
        _onDeviceScanFirst.value = value
        context.settingsDataStore.edit { it[ON_DEVICE_SCAN_FIRST_KEY] = value }
    }

    private companion object {
        const val DEFAULT_ON_DEVICE_SCAN_FIRST = true
        val ON_DEVICE_SCAN_FIRST_KEY = booleanPreferencesKey("on_device_scan_first")
    }
}
