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
    // --- A7 operator KYC ---
    val address: String = "",
    // New Aadhaar being entered; blank keeps the stored value (like password).
    val aadhaar: String = "",
    val aadhaarMasked: String? = null, // current masked value, display only
    val aadhaarPresent: Boolean = false,
    val profilePhotoUrl: String? = null, // current server photo (relative path)
    val idCardPresent: Boolean = false,
    // Locally picked replacements, uploaded via multipart on submit.
    val pickedProfilePhoto: PickedImage? = null,
    val pickedIdCard: PickedImage? = null,
)

data class AdminUsersUiState(
    val loading: Boolean = false,
    val refreshing: Boolean = false,
    val users: List<AdminUserDto> = emptyList(),
    val query: String = "",
    val error: String? = null,
    // One-shot snackbar messages; the screen consumes them after showing.
    val successMessage: String? = null,
    val actionError: String? = null,
    // --- create/edit sheet ---
    val sheetOpen: Boolean = false,
    val editingId: Long? = null, // null while creating
    val formLoading: Boolean = false, // fetching GET :id for the edit prefill
    val form: UserForm = UserForm(),
    val saving: Boolean = false,
    val formError: String? = null, // top-level / base validation message
    val fieldErrors: Map<String, List<String>> = emptyMap(),
    // --- A7 KYC reveal / purge (transient — never persisted) ---
    val revealing: Boolean = false,
    val revealedAadhaar: String? = null,
    val revealedIdCardUrl: String? = null, // relative path from kyc_reveal
    val revealError: String? = null,
    val purging: Boolean = false,
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

    fun load() = fetch(asRefresh = false)

    fun refresh() = fetch(asRefresh = true)

    private fun fetch(asRefresh: Boolean) {
        _state.update {
            if (asRefresh) it.copy(refreshing = true) else it.copy(loading = true, error = null)
        }
        viewModelScope.launch {
            when (val result = repository.list()) {
                is ApiResult.Success ->
                    _state.update { it.copy(loading = false, refreshing = false, error = null, users = result.data) }
                is ApiResult.Error -> onFetchFailure(result.message)
                is ApiResult.NetworkError -> onFetchFailure(NETWORK_MESSAGE)
            }
        }
    }

    /** Empty screen keeps the full-area error; stale data stays visible with a snackbar. */
    private fun onFetchFailure(message: String) {
        _state.update {
            if (it.users.isEmpty()) {
                it.copy(loading = false, refreshing = false, error = message)
            } else {
                it.copy(loading = false, refreshing = false, actionError = message)
            }
        }
    }

    fun consumeSuccessMessage() = _state.update { it.copy(successMessage = null) }

    fun consumeActionError() = _state.update { it.copy(actionError = null) }

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
                revealing = false,
                revealedAadhaar = null,
                revealedIdCardUrl = null,
                revealError = null,
                purging = false,
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
                revealing = false,
                revealedAadhaar = null,
                revealedIdCardUrl = null,
                revealError = null,
                purging = false,
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
                // The row prefill is still usable — surface the failed refresh as a snackbar.
                is ApiResult.NetworkError -> _state.update {
                    if (it.editingId == user.id) {
                        it.copy(formLoading = false, actionError = "Couldn't refresh this user's details. Showing cached values.")
                    } else {
                        it
                    }
                }
            }
        }
    }

    fun closeSheet() {
        _state.update {
            it.copy(
                sheetOpen = false,
                saving = false,
                formLoading = false,
                // Revealed PII is transient — drop it the moment the sheet closes.
                revealing = false,
                revealedAadhaar = null,
                revealedIdCardUrl = null,
                revealError = null,
            )
        }
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

    // --- A7 KYC setters -----------------------------------------------------

    fun onAddress(value: String) = editField("address") { it.copy(address = value) }

    fun onAadhaar(value: String) =
        editField("aadhaar_number") { it.copy(aadhaar = value.filter(Char::isDigit).take(12)) }

    fun onProfilePhotoPicked(image: PickedImage) =
        editField("profile_photo") { it.copy(pickedProfilePhoto = image) }

    fun onIdCardPicked(image: PickedImage) =
        editField("id_card_photo") { it.copy(pickedIdCard = image) }

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
            // Aadhaar is optional; the Verhoeff checksum is enforced server-side.
            if (form.aadhaar.isNotBlank() && form.aadhaar.length != 12) {
                put("aadhaar_number", listOf("Aadhaar must be 12 digits."))
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
            address = form.address.trim(),
            // Blank keeps the stored Aadhaar (parallels the password field).
            aadhaarNumber = form.aadhaar.trim().ifBlank { null },
        )

        _state.update { it.copy(saving = true, formError = null, fieldErrors = emptyMap()) }
        viewModelScope.launch {
            val editingId = current.editingId
            // Only send multipart when an image was actually picked; a no-image
            // edit stays on the cheaper JSON path.
            val profile = form.pickedProfilePhoto
            val idCard = form.pickedIdCard
            val hasImages = profile != null || idCard != null
            val result = when {
                editingId != null && hasImages ->
                    repository.updateMultipart(editingId, request, profile, idCard)
                editingId != null -> repository.update(editingId, request)
                hasImages -> repository.createMultipart(request, profile, idCard)
                else -> repository.create(request)
            }
            when (result) {
                is ApiResult.Success -> {
                    _state.update {
                        it.copy(
                            saving = false,
                            sheetOpen = false,
                            editingId = null,
                            successMessage = if (editingId != null) "Changes saved." else "User created.",
                        )
                    }
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

    // --- A7 KYC reveal / purge ----------------------------------------------

    /**
     * Fetch the full Aadhaar + signed ID-card URL for the operator being edited.
     * The access is audited server-side; the result lives only in transient UI
     * state and is dropped when the sheet closes.
     */
    fun revealKyc() {
        val id = _state.value.editingId ?: return
        if (_state.value.revealing) return
        _state.update { it.copy(revealing = true, revealError = null) }
        viewModelScope.launch {
            when (val result = repository.kycReveal(id)) {
                is ApiResult.Success -> _state.update {
                    if (it.editingId != id) return@update it
                    it.copy(
                        revealing = false,
                        revealedAadhaar = result.data.aadhaarNumber,
                        revealedIdCardUrl = result.data.idCardPhotoUrl,
                    )
                }
                is ApiResult.Error -> _state.update {
                    if (it.editingId == id) it.copy(revealing = false, revealError = result.message) else it
                }
                is ApiResult.NetworkError -> _state.update {
                    if (it.editingId == id) it.copy(revealing = false, revealError = NETWORK_MESSAGE) else it
                }
            }
        }
    }

    /** Purge Aadhaar + ID-card for the operator being edited (keeps the account). */
    fun purgeKyc() {
        val id = _state.value.editingId ?: return
        if (_state.value.purging) return
        _state.update { it.copy(purging = true) }
        viewModelScope.launch {
            when (val result = repository.purgeKyc(id)) {
                is ApiResult.Success -> {
                    _state.update {
                        if (it.editingId != id) return@update it.copy(purging = false)
                        it.copy(
                            purging = false,
                            revealedAadhaar = null,
                            revealedIdCardUrl = null,
                            revealError = null,
                            successMessage = "KYC purged.",
                            form = it.form.copy(
                                aadhaar = "",
                                aadhaarMasked = result.data.aadhaarMasked,
                                aadhaarPresent = result.data.aadhaarPresent,
                                idCardPresent = result.data.idCardPresent,
                                pickedIdCard = null,
                            ),
                        )
                    }
                    load()
                }
                is ApiResult.Error -> _state.update { it.copy(purging = false, actionError = result.message) }
                is ApiResult.NetworkError -> _state.update { it.copy(purging = false, actionError = NETWORK_MESSAGE) }
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
    address = address.orEmpty(),
    aadhaar = "",
    aadhaarMasked = aadhaarMasked,
    aadhaarPresent = aadhaarPresent,
    profilePhotoUrl = profilePhotoUrl,
    idCardPresent = idCardPresent,
    pickedProfilePhoto = null,
    pickedIdCard = null,
)
