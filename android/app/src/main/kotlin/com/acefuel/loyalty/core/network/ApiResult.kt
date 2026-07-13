package com.acefuel.loyalty.core.network

import com.acefuel.loyalty.core.network.dto.ErrorEnvelope
import kotlinx.serialization.json.Json
import retrofit2.HttpException
import java.io.IOException

/** Outcome of an API call: success, a structured server error, or a transport failure. */
sealed interface ApiResult<out T> {
    data class Success<T>(val data: T) : ApiResult<T>

    /** Server responded non-2xx; [message] is the API's human-facing string. */
    data class Error(
        val httpCode: Int,
        val code: String?,
        val message: String,
        val details: Map<String, List<String>>? = null,
    ) : ApiResult<Nothing>

    /** No response (offline, timeout, DNS, …). */
    data class NetworkError(val throwable: Throwable) : ApiResult<Nothing>
}

/**
 * Runs a Retrofit suspend call and maps failures into [ApiResult]. HttpException
 * bodies are parsed as the shared { "error": { code, message, details } } envelope.
 */
suspend fun <T> apiCall(json: Json, block: suspend () -> T): ApiResult<T> = try {
    ApiResult.Success(block())
} catch (e: HttpException) {
    val raw = runCatching { e.response()?.errorBody()?.string() }.getOrNull()
    val parsed = raw?.let { runCatching { json.decodeFromString<ErrorEnvelope>(it) }.getOrNull() }
    ApiResult.Error(
        httpCode = e.code(),
        code = parsed?.error?.code,
        message = parsed?.error?.message?.takeUnless { it.isBlank() } ?: "Something went wrong (${e.code()}).",
        details = parsed?.error?.details,
    )
} catch (e: IOException) {
    ApiResult.NetworkError(e)
}
