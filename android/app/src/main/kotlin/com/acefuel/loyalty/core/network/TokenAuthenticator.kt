package com.acefuel.loyalty.core.network

import com.acefuel.loyalty.core.auth.TokenStore
import com.acefuel.loyalty.core.network.dto.AuthResponse
import kotlinx.coroutines.runBlocking
import kotlinx.serialization.json.Json
import okhttp3.Authenticator
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import okhttp3.Response
import okhttp3.Route

/**
 * On a 401, exchanges the refresh token for a fresh access token and retries the
 * original request once. If refresh fails, the session is cleared. Runs on an
 * OkHttp background thread (blocking is fine here). Uses a dedicated client with
 * no authenticator to avoid recursion.
 */
class TokenAuthenticator(
    private val tokenStore: TokenStore,
    private val baseUrl: String,
    private val json: Json,
    private val refreshClient: OkHttpClient,
) : Authenticator {

    override fun authenticate(route: Route?, response: Response): Request? {
        val original = response.request
        val path = original.url.encodedPath
        // Never try to refresh the auth endpoints themselves.
        if (path.endsWith("/auth/refresh") || path.endsWith("/auth/login")) return null
        // Give up if we've already retried this request.
        if (responseCount(response) >= 2) return null

        val refresh = tokenStore.refreshToken
        if (refresh.isNullOrBlank()) return null

        val newAccess = synchronized(this) {
            // Another thread may have refreshed while we waited on the lock.
            val current = tokenStore.accessToken
            val stale = original.header("Authorization")?.removePrefix("Bearer ")
            if (current != null && current != stale) {
                current
            } else {
                refreshAccessToken(refresh)
            }
        } ?: return null

        return original.newBuilder()
            .header("Authorization", "Bearer $newAccess")
            .build()
    }

    private fun refreshAccessToken(refresh: String): String? {
        val body = """{"refresh_token":"$refresh"}"""
            .toRequestBody("application/json".toMediaType())
        val request = Request.Builder()
            .url(baseUrl.trimEnd('/') + "/api/v1/auth/refresh")
            .post(body)
            .build()

        return runCatching {
            refreshClient.newCall(request).execute().use { resp ->
                if (!resp.isSuccessful) {
                    runBlocking { tokenStore.clear() }
                    return null
                }
                val payload = resp.body?.string().orEmpty()
                val auth = json.decodeFromString<AuthResponse>(payload)
                runBlocking { tokenStore.save(auth.accessToken, auth.refreshToken) }
                auth.accessToken
            }
        }.getOrNull()
    }

    private fun responseCount(response: Response): Int {
        var count = 1
        var prior = response.priorResponse
        while (prior != null) {
            count++
            prior = prior.priorResponse
        }
        return count
    }
}
