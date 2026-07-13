package com.acefuel.loyalty.core.push

import com.acefuel.loyalty.core.network.ApiResult
import com.acefuel.loyalty.core.network.apiCall
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import retrofit2.Retrofit
import retrofit2.http.Body
import retrofit2.http.HTTP
import retrofit2.http.POST

// POST/DELETE /push/subscriptions (public; docs/native-handoff/08).

// No default on `platform`: kotlinx.serialization has encodeDefaults=false, so a
// property left at its default value is omitted from the JSON. The server treats a
// missing platform as "unknown", so the default would silently mislabel the sub.
// Keeping it required forces it into the payload (callers pass "android").
@Serializable
data class PushSubscriptionRequest(val token: String, val platform: String)

@Serializable
data class PushSubscriptionResponse(
    val id: Long? = null,
    val active: Boolean = true,
    val platform: String? = null,
)

interface PushApi {
    @POST("push/subscriptions")
    suspend fun register(@Body body: PushSubscriptionRequest): PushSubscriptionResponse

    @HTTP(method = "DELETE", path = "push/subscriptions", hasBody = true)
    suspend fun unregister(@Body body: PushSubscriptionRequest)
}

class PushRepository(private val api: PushApi, private val json: Json) {
    suspend fun register(token: String): ApiResult<PushSubscriptionResponse> =
        apiCall(json) { api.register(PushSubscriptionRequest(token, "android")) }

    suspend fun unregister(token: String): ApiResult<Unit> =
        apiCall(json) { api.unregister(PushSubscriptionRequest(token, "android")) }

    companion object {
        fun from(retrofit: Retrofit, json: Json) = PushRepository(retrofit.create(PushApi::class.java), json)
    }
}
