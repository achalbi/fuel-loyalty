package com.acefuel.loyalty.ui.login

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.acefuel.loyalty.core.data.AuthRepository
import com.acefuel.loyalty.core.network.ApiResult
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

sealed interface LoginUiState {
    data object Idle : LoginUiState
    data object Loading : LoginUiState
    data class Error(val message: String) : LoginUiState
}

class LoginViewModel(private val authRepository: AuthRepository) : ViewModel() {

    private val _state = MutableStateFlow<LoginUiState>(LoginUiState.Idle)
    val state: StateFlow<LoginUiState> = _state.asStateFlow()

    fun submit(login: String, password: String) {
        if (login.isBlank() || password.isBlank()) {
            _state.value = LoginUiState.Error("Enter your username and password.")
            return
        }
        _state.value = LoginUiState.Loading
        viewModelScope.launch {
            // On success, AuthRepository flips its state to LoggedIn; the screen
            // observes that to navigate. Only surface failures here.
            when (val result = authRepository.login(login, password)) {
                is ApiResult.Success -> Unit
                is ApiResult.Error -> _state.value = LoginUiState.Error(result.message)
                is ApiResult.NetworkError -> _state.value = LoginUiState.Error(
                    "Couldn't reach the server. Check your connection and try again.",
                )
            }
        }
    }
}
