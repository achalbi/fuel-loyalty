package com.acefuel.loyalty.core.data

import com.acefuel.loyalty.core.auth.TokenStore
import com.acefuel.loyalty.core.network.AceFuelApi
import com.acefuel.loyalty.core.network.ApiResult
import com.acefuel.loyalty.core.network.apiCall
import com.acefuel.loyalty.core.network.dto.LoginRequest
import com.acefuel.loyalty.core.network.dto.UserDto
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.serialization.json.Json

sealed interface AuthState {
    /** Startup: a token exists but hasn't been validated yet. */
    data object Unknown : AuthState
    data object LoggedOut : AuthState
    data class LoggedIn(val user: UserDto) : AuthState
}

class AuthRepository(
    private val api: AceFuelApi,
    private val tokenStore: TokenStore,
    private val json: Json,
) {
    private val _state = MutableStateFlow<AuthState>(
        if (tokenStore.hasSession) AuthState.Unknown else AuthState.LoggedOut,
    )
    val state: StateFlow<AuthState> = _state.asStateFlow()

    suspend fun login(login: String, password: String): ApiResult<UserDto> {
        return when (val result = apiCall(json) { api.login(LoginRequest(login.trim(), password)) }) {
            is ApiResult.Success -> {
                tokenStore.save(result.data.accessToken, result.data.refreshToken)
                _state.value = AuthState.LoggedIn(result.data.user)
                ApiResult.Success(result.data.user)
            }
            is ApiResult.Error -> result
            is ApiResult.NetworkError -> result
        }
    }

    /** Validate the stored session on startup. */
    suspend fun loadSession() {
        if (!tokenStore.hasSession) {
            _state.value = AuthState.LoggedOut
            return
        }
        when (val result = apiCall(json) { api.me() }) {
            is ApiResult.Success -> _state.value = AuthState.LoggedIn(result.data.user)
            is ApiResult.Error -> {
                tokenStore.clear()
                _state.value = AuthState.LoggedOut
            }
            is ApiResult.NetworkError -> {
                // Keep the token; can't confirm offline. Stay Unknown so UI can retry.
            }
        }
    }

    suspend fun logout() {
        runCatching { api.logout() }
        tokenStore.clear()
        _state.value = AuthState.LoggedOut
    }
}
