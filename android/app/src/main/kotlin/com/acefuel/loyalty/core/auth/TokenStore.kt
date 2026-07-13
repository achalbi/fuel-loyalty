package com.acefuel.loyalty.core.auth

import android.content.Context
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking

private val Context.tokenDataStore by preferencesDataStore(name = "auth_tokens")

/**
 * Persists the access/refresh token pair in DataStore, with a volatile in-memory
 * mirror so the (synchronous) OkHttp interceptor/authenticator can read tokens
 * without blocking. Hydrated once at startup.
 */
class TokenStore(private val context: Context) {

    @Volatile
    var accessToken: String? = null
        private set

    @Volatile
    var refreshToken: String? = null
        private set

    /** Load persisted tokens into memory. Call once during app startup. */
    fun hydrateBlocking() = runBlocking {
        val prefs = context.tokenDataStore.data.first()
        accessToken = prefs[ACCESS_KEY]
        refreshToken = prefs[REFRESH_KEY]
    }

    suspend fun save(access: String, refresh: String) {
        accessToken = access
        refreshToken = refresh
        context.tokenDataStore.edit {
            it[ACCESS_KEY] = access
            it[REFRESH_KEY] = refresh
        }
    }

    /** Update only the access token (after a refresh) keeping the refresh token. */
    suspend fun updateAccess(access: String) {
        accessToken = access
        context.tokenDataStore.edit { it[ACCESS_KEY] = access }
    }

    suspend fun clear() {
        accessToken = null
        refreshToken = null
        context.tokenDataStore.edit { it.clear() }
    }

    val hasSession: Boolean get() = !accessToken.isNullOrBlank()

    private companion object {
        val ACCESS_KEY = stringPreferencesKey("access_token")
        val REFRESH_KEY = stringPreferencesKey("refresh_token")
    }
}
