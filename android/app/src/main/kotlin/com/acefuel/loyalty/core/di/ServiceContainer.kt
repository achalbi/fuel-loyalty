package com.acefuel.loyalty.core.di

import android.content.Context
import androidx.compose.runtime.staticCompositionLocalOf
import com.acefuel.loyalty.BuildConfig
import com.acefuel.loyalty.core.auth.TokenStore
import com.acefuel.loyalty.core.data.AuthRepository
import com.acefuel.loyalty.core.data.LoyaltyRepository
import com.acefuel.loyalty.core.data.StaffRepository
import com.acefuel.loyalty.core.data.ThemeRepository
import com.acefuel.loyalty.core.network.AceFuelApi
import com.acefuel.loyalty.core.network.AuthInterceptor
import com.acefuel.loyalty.core.network.KotlinxJsonConverterFactory
import com.acefuel.loyalty.core.network.TokenAuthenticator
import kotlinx.serialization.json.Json
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.logging.HttpLoggingInterceptor
import retrofit2.Retrofit

/**
 * Lightweight manual DI. Built once in [com.acefuel.loyalty.AceFuelApp] and shared
 * with Compose via [LocalContainer]. (Hilt can replace this later once KSP is
 * validated on the AGP 9 toolchain.)
 */
class ServiceContainer(context: Context) {

    private val appContext = context.applicationContext

    val json = Json {
        ignoreUnknownKeys = true
        explicitNulls = false
    }

    val tokenStore = TokenStore(appContext).apply { hydrateBlocking() }

    private val baseUrl = BuildConfig.API_BASE_URL

    private val logging = HttpLoggingInterceptor().apply {
        level = if (BuildConfig.DEBUG) HttpLoggingInterceptor.Level.BODY
        else HttpLoggingInterceptor.Level.NONE
    }

    // No authenticator here — used only for the refresh call to avoid recursion.
    private val refreshClient = OkHttpClient.Builder()
        .addInterceptor(logging)
        .build()

    private val okHttpClient = OkHttpClient.Builder()
        .addInterceptor(AuthInterceptor(tokenStore))
        .addInterceptor(logging)
        .authenticator(TokenAuthenticator(tokenStore, baseUrl, json, refreshClient))
        .build()

    // Shared Retrofit; admin feature verticals create their own typed interfaces
    // from this via `retrofit.create(SomeAdminApi::class.java)`.
    val retrofit: Retrofit = Retrofit.Builder()
        .baseUrl(baseUrl)
        .client(okHttpClient)
        .addConverterFactory(KotlinxJsonConverterFactory(json, "application/json".toMediaType()))
        .build()

    // Plate recognition uploads an image and blocks on an external ALPR round-trip,
    // so it needs a longer budget than the 10s OkHttp default used for JSON calls.
    private val plateOkHttpClient = okHttpClient.newBuilder()
        .callTimeout(45, java.util.concurrent.TimeUnit.SECONDS)
        .writeTimeout(45, java.util.concurrent.TimeUnit.SECONDS)
        .readTimeout(45, java.util.concurrent.TimeUnit.SECONDS)
        .build()

    val plateRetrofit: Retrofit = retrofit.newBuilder().client(plateOkHttpClient).build()

    val api: AceFuelApi = retrofit.create(AceFuelApi::class.java)

    val authRepository = AuthRepository(api, tokenStore, json)
    val loyaltyRepository = LoyaltyRepository(api, json, com.acefuel.loyalty.core.data.LoyaltyCache(appContext, json))
    val themeRepository = ThemeRepository(api, json)
    val staffRepository = StaffRepository(api, json)
    val pushRepository = com.acefuel.loyalty.core.push.PushRepository.from(retrofit, json)
}

val LocalContainer = staticCompositionLocalOf<ServiceContainer> {
    error("ServiceContainer not provided")
}
