package com.acefuel.loyalty.core.data

import android.content.Context
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.longPreferencesKey
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import com.acefuel.loyalty.core.network.dto.LoyaltyResponse
import kotlinx.coroutines.flow.first
import kotlinx.serialization.json.Json

private val Context.loyaltyDataStore by preferencesDataStore(name = "loyalty_cache")

/** A cached loyalty result + when it was fetched (epoch millis). */
data class CachedLoyalty(val phone: String, val data: LoyaltyResponse, val fetchedAtMillis: Long)

/**
 * Caches the last successful loyalty lookup so the balance can be shown offline
 * with a "last updated" stamp (docs/native-handoff/10). Keyed by phone number.
 */
class LoyaltyCache(context: Context, private val json: Json) {
    private val ds = context.applicationContext.loyaltyDataStore

    suspend fun save(phone: String, data: LoyaltyResponse, nowMillis: Long) {
        ds.edit {
            it[PHONE] = phone
            it[PAYLOAD] = json.encodeToString(LoyaltyResponse.serializer(), data)
            it[FETCHED_AT] = nowMillis
        }
    }

    /** Returns the cached result for [phone] if present, else null. */
    suspend fun get(phone: String): CachedLoyalty? {
        val prefs = ds.data.first()
        val cachedPhone = prefs[PHONE] ?: return null
        if (cachedPhone != phone) return null
        val payload = prefs[PAYLOAD] ?: return null
        val data = runCatching { json.decodeFromString(LoyaltyResponse.serializer(), payload) }.getOrNull()
            ?: return null
        return CachedLoyalty(cachedPhone, data, prefs[FETCHED_AT] ?: 0L)
    }

    private companion object {
        val PHONE = stringPreferencesKey("phone")
        val PAYLOAD = stringPreferencesKey("payload")
        val FETCHED_AT = longPreferencesKey("fetched_at")
    }
}
