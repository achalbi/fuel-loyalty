package com.acefuel.loyalty.core.network

import com.acefuel.loyalty.core.auth.TokenStore
import okhttp3.Interceptor
import okhttp3.Response

/** Attaches the bearer access token to outgoing requests when a session exists. */
class AuthInterceptor(private val tokenStore: TokenStore) : Interceptor {
    override fun intercept(chain: Interceptor.Chain): Response {
        val request = chain.request()
        val token = tokenStore.accessToken
        if (token.isNullOrBlank() || request.header("Authorization") != null) {
            return chain.proceed(request)
        }
        return chain.proceed(
            request.newBuilder().header("Authorization", "Bearer $token").build(),
        )
    }
}
