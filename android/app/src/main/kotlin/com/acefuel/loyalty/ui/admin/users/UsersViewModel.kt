package com.acefuel.loyalty.ui.admin.users

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.acefuel.loyalty.core.network.ApiResult
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

private const val NETWORK_MESSAGE = "Couldn't reach the server. Try again."

/** Editable state of the create/edit user form. */
data class UserForm(
    val name: String = "",
    val username: String = "",
    val phone: String = "", // 10-digit local part (the +91 prefix is fixed)
    val email: String = "",
    val role: String = "staff", // "admin" | "staff"
    val active: Boolean = true,
    val password: String = "",
    val passwordConfirmation: String = "",
)

data class AdminUsersUiState(
    val loading: Boolean = false,
    val users: List<AdminUserDto> = emptyList(),
    val query: String = "",
    val error: String? = null,
    // --- create/edit sheet ---
    val sheetOpen: Boolean = false,
    val editingId: Long? = null, // null while creating
    val formLoading: Boolean = false, // fetching GET :id for the edit prefill
    val form: UserForm = UserForm(),
    val saving: Boolean = false,
    val formError: String? = null, // top-level / base validation message
    val fieldErrors: Map<String, List<String>> = emptyMap(),
) {
    val isEditing: Boolean get() = editingId != null

    val filteredUsers: List<AdminUserDto>
        get() {
            val q = query.trim().lowercase()
            if (q.isEmpty()) return users
            return users.filter { u ->
                listOfNotNull(u.name, u.username, u.phoneNumber, u.email)
                    .any { it.lowercase().contains(q) }
            }
        }
}

class UsersViewModel(private val repository: UsersRepository) : ViewModel() {

    private val _state = MutableStateFlow(AdminUsersUiState())
    val state: StateFlow<AdminUsersUiState> = _state.asStateFlow()

    init {
        load()
    }

    fun load() {
        _state.update { it.copy(loading = true, error = null) }
        viewModelScope.launch {
            when (val result = repository.list()) {
                is ApiResult.Success -> _state.update { it.copy(loading = false, users = result.data) }
                is ApiResult.Error -> _state.update { it.copy(loading = false, error = result.message) }
                is ApiResult.NetworkError -> _state.update { it.copy(loading = false, error = NETWORK_MESSAGE) }
            }
        }
    }

    fun refresh() = load()

    fun onQueryChange(query: String) = _state.update { it.copy(query = query) }

    // --- Sheet lifecycle ----------------------------------------------------

    fun openCreate() {
        _state.update {
            it.copy(
                sheetOpen = true,
                editingId = null,
                formLoading = false,
                form = UserForm(),
                formError = null,
                fieldErrors = emptyMap(),
            )
        }
    }

    fun openEdit(user: AdminUserDto) {
        // Prefill instantly from the list row, then refresh from GET :id.
        _state.update {
            it.copy(
                sheetOpen = true,
                editingId = user.id,
                formLoading = true,
                form = user.toForm(),
                formError = null,
                fieldErrors = emptyMap(),
            )
        }
        viewModelScope.launch {
            when (val result = repository.show(user.id)) {
                is ApiResult.Success -> _state.update {
                    if (it.editingId == user.id && !it.saving) {
                        it.copy(formLoading = false, form = result.data.toForm())
                    } else {
                        it.copy(formLoading = false)
                    }
                }
                is ApiResult.Error -> _state.update {
                    if (it.editingId == user.id) it.copy(formLoading = false, formError = result.message) else it
                }
                is ApiResult.NetworkError -> _state.update {
                    if (it.editingId == user.id) it.copy(formLoading = false) else it
                }
            }
        }
    }

    fun closeSheet() {
        _state.update { it.copy(sheetOpen = false, saving = false, formLoading = false) }
    }

    // --- Field setters (each clears its own inline error) -------------------

    fun onName(value: String) = editField("name") { it.copy(name = value) }
    fun onUsername(value: String) = editField("username") { it.copy(username = value) }
    fun onPhone(value: String) = editField("phone_number") { it.copy(phone = value.filter(Char::isDigit).take(10)) }
    fun onEmail(value: String) = editField("email") { it.copy(email = value) }
    fun onRole(value: String) = editField("role") { it.copy(role = value) }
    fun onActive(value: Boolean) = editField("active") { it.copy(active = value) }
    fun onPassword(value: String) = editField("password") { it.copy(password = value) }
    fun onPasswordConfirmation(value: String) =
        editField("password_confirmation") { it.copy(passwordConfirmation = value) }

    private fun editField(key: String, transform: (UserForm) -> UserForm) {
        _state.update {
            it.copy(
                form = transform(it.form),
                formError = null,
                fieldErrors = if (it.fieldErrors.containsKey(key)) it.fieldErrors - key else it.fieldErrors,
            )
        }
    }

    // --- Submit -------------------------------------------------------------

    fun submit() {
        val current = _state.value
        if (current.saving || current.formLoading) return
        val form = current.form

        val clientErrors = buildMap<String, List<String>> {
            if (form.name.isBlank()) put("name", listOf("Name is required."))
            if (form.username.isBlank()) put("username", listOf("Username is required."))
            when {
                form.phone.isBlank() -> put("phone_number", listOf("Mobile number is required."))
                form.phone.length != 10 -> put("phone_number", listOf("must be a 10 digit mobile number"))
            }
            if (!current.isEditing && form.password.isBlank()) {
                put("password", listOf("Password is required."))
            }
            if (form.password.isNotBlank() && form.password != form.passwordConfirmation) {
                put("password_confirmation", listOf("doesn't match Password"))
            }
        }
        if (clientErrors.isNotEmpty()) {
            _state.update { it.copy(fieldErrors = clientErrors, formError = null) }
            return
        }

        val request = AdminUserRequest(
            name = form.name.trim(),
            username = form.username.trim(),
            phoneNumber = form.phone.trim(),
            email = form.email.trim(),
            role = form.role,
            active = form.active,
            password = form.password.ifBlank { null },
            passwordConfirmation = form.passwordConfirmation.ifBlank { null },
        )

        _state.update { it.copy(saving = true, formError = null, fieldErrors = emptyMap()) }
        viewModelScope.launch {
            val editingId = current.editingId
            val result = if (editingId != null) {
                repository.update(editingId, request)
            } else {
                repository.create(request)
            }
            when (result) {
                is ApiResult.Success -> {
                    _state.update { it.copy(saving = false, sheetOpen = false, editingId = null) }
                    load()
                }
                is ApiResult.Error -> {
                    val details = result.details ?: emptyMap()
                    val baseMessages = details["base"].orEmpty()
                    val topError = when {
                        baseMessages.isNotEmpty() -> baseMessages.joinToString(" ")
                        details.isEmpty() -> result.message
                        else -> null
                    }
                    _state.update {
                        it.copy(saving = false, formError = topError, fieldErrors = details - "base")
                    }
                }
                is ApiResult.NetworkError ->
                    _state.update { it.copy(saving = false, formError = NETWORK_MESSAGE) }
            }
        }
    }
}

private fun AdminUserDto.toForm() = UserForm(
    name = name.orEmpty(),
    username = username.orEmpty(),
    phone = phoneNumber.orEmpty(),
    email = email.orEmpty(),
    role = role,
    active = active,
    password = "",
    passwordConfirmation = "",
)
