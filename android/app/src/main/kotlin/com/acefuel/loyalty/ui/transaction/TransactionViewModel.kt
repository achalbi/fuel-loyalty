package com.acefuel.loyalty.ui.transaction

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.acefuel.loyalty.core.data.StaffRepository
import com.acefuel.loyalty.core.network.ApiResult
import com.acefuel.loyalty.core.network.dto.CatalogResponse
import com.acefuel.loyalty.core.network.dto.MyPumpDto
import com.acefuel.loyalty.core.network.dto.NozzleDto
import com.acefuel.loyalty.core.network.dto.RegisterCustomerRequest
import com.acefuel.loyalty.core.network.dto.StaffCustomerDto
import com.acefuel.loyalty.core.network.dto.StaffVehicleDto
import com.acefuel.loyalty.core.network.dto.TransactionCreateRequest
import com.acefuel.loyalty.core.network.dto.TransactionCreateResponse
import com.acefuel.loyalty.core.network.dto.VehicleMatchDto
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

const val MODE_VEHICLE = "vehicle"
const val MODE_PHONE = "phone"

/**
 * Mirror the server's fuel-type comparison. TransactionCreator matches a nozzle
 * to a vehicle by `parameterize(separator: "_")` of both fuel codes, so the
 * client must normalize the same way — some vehicles carry an un-normalized
 * code (e.g. "Petrol" vs the nozzle's "petrol") that the server accepts but a
 * raw `==` would reject, wrongly hiding a valid nozzle.
 */
internal fun normalizeFuelCode(value: String?): String =
    value.orEmpty().lowercase().replace(Regex("[^a-z0-9]+"), "_").trim('_')

/**
 * Inline "add customer" form, shown when a vehicle lookup matches nobody. Non-null
 * only while the registration sheet is open. Mirrors the web Staff registration
 * modal's fields.
 */
data class RegisterFormState(
    val name: String = "",
    val phoneNumber: String = "",
    val vehicleNumber: String = "",
    val fuelTypeCode: String? = null,
    val vehicleKindCode: String? = null,
    val companyName: String = "",
    val contactName: String = "",
    val contactPhone: String = "",
    val address: String = "",
    val notes: String = "",
    val submitting: Boolean = false,
    val error: String? = null,
)

data class TxnUiState(
    val lookupMode: String = MODE_VEHICLE,
    val vehicleNumber: String = "",
    val phoneNumber: String = "",
    val lookupLoading: Boolean = false,
    val lookupError: String? = null,
    // True once a lookup has returned, so "no matches" reads as a real empty
    // result rather than the initial blank state.
    val lookupCompleted: Boolean = false,
    val matches: List<VehicleMatchDto> = emptyList(),
    val phoneCustomer: StaffCustomerDto? = null,
    val selectedMatchIndex: Int? = null,
    val selectedVehicleId: Long? = null,
    val myPump: MyPumpDto? = null,
    val myPumpLoading: Boolean = true,
    val myPumpError: String? = null,
    val fuelAmount: String = "",
    val discountAmount: String = "",
    val paymentMode: String = "cash",
    val selectedNozzleId: Long? = null,
    val creating: Boolean = false,
    val createError: String? = null,
    val result: TransactionCreateResponse? = null,
    val showCeremony: Boolean = false,
    // Reference options for the registration form; fetched lazily on first use.
    val catalog: CatalogResponse? = null,
    // Non-null while the inline "add customer" sheet is open.
    val registerForm: RegisterFormState? = null,
) {
    /** True once a vehicle lookup has completed and matched no customer. */
    val vehicleUnmatched: Boolean
        get() = lookupMode == MODE_VEHICLE && lookupCompleted && matches.isEmpty() && lookupError == null

    /** Whether the currently chosen registration vehicle kind needs commercial fields. */
    val registrationIsCommercial: Boolean
        get() = catalog?.vehicleKinds?.firstOrNull { it.code == registerForm?.vehicleKindCode }?.commercial == true

    val selectedCustomer: StaffCustomerDto?
        get() = when (lookupMode) {
            MODE_VEHICLE -> selectedMatchIndex?.let { matches.getOrNull(it)?.customer }
            else -> phoneCustomer
        }

    /** (vehicleId, fuelTypeCode) for the resolved selection. */
    val selectedVehicle: Pair<Long, String?>?
        get() = when (lookupMode) {
            MODE_VEHICLE -> selectedMatchIndex?.let { matches.getOrNull(it) }?.let { it.vehicleId to it.fuelTypeCode }
            else -> phoneCustomer?.vehicles?.firstOrNull { it.id == selectedVehicleId }?.let { it.id to it.fuelTypeCode }
        }

    val selectedVehicleNumber: String?
        get() = when (lookupMode) {
            MODE_VEHICLE -> selectedMatchIndex?.let { matches.getOrNull(it)?.vehicleNumber }
            else -> phoneCustomer?.vehicles?.firstOrNull { it.id == selectedVehicleId }?.vehicleNumber
        }

    val selectedFuelTypeLabel: String?
        get() = when (lookupMode) {
            MODE_VEHICLE -> selectedMatchIndex?.let { matches.getOrNull(it)?.fuelType }
            else -> phoneCustomer?.vehicles?.firstOrNull { it.id == selectedVehicleId }?.fuelType
        }

    val phoneVehicles: List<StaffVehicleDto>
        get() = phoneCustomer?.vehicles ?: emptyList()

    /** Assigned+active nozzles filtered to the selected vehicle's fuel type. */
    fun nozzleOptions(): List<NozzleDto> {
        val fuel = normalizeFuelCode(selectedVehicle?.second)
        if (fuel.isEmpty()) return emptyList()
        return (myPump?.assignedNozzles() ?: emptyList())
            .filter { normalizeFuelCode(it.fuelTypeCode) == fuel }
    }

    val pumpReady: Boolean get() = myPump?.ready == true
    val customerActive: Boolean get() = selectedCustomer?.active == true

    val canSave: Boolean
        get() = selectedVehicle != null &&
            customerActive &&
            pumpReady &&
            selectedNozzleId != null &&
            (fuelAmount.toDoubleOrNull() ?: 0.0) > 0.0 &&
            discountValid &&
            !creating

    /**
     * A discount is optional; when given it comes off the fuel amount, so it can
     * be neither negative nor the whole sale. The server enforces the same rule.
     */
    val discountValid: Boolean
        get() {
            if (discountAmount.isBlank()) return true
            val discount = discountAmount.toDoubleOrNull() ?: return false
            val amount = fuelAmount.toDoubleOrNull() ?: return false
            return discount >= 0.0 && discount < amount
        }
}

class TransactionViewModel(private val repository: StaffRepository) : ViewModel() {

    private val _state = MutableStateFlow(TxnUiState())
    val state: StateFlow<TxnUiState> = _state.asStateFlow()

    init {
        loadMyPump()
    }

    fun loadMyPump() {
        _state.update { it.copy(myPumpLoading = true, myPumpError = null) }
        viewModelScope.launch {
            when (val r = repository.myPump()) {
                is ApiResult.Success -> _state.update { it.copy(myPumpLoading = false, myPump = r.data) }
                is ApiResult.Error -> _state.update { it.copy(myPumpLoading = false, myPumpError = r.message) }
                is ApiResult.NetworkError -> _state.update {
                    it.copy(myPumpLoading = false, myPumpError = "Couldn't load your pump. Check your connection.")
                }
            }
        }
    }

    /**
     * Re-fetch the pump on return from the My Pump setup screen, but only while
     * the nozzle section is actually blocked — either no pump is set up, or the
     * assigned nozzles don't cover the selected vehicle's fuel type. This picks
     * up a just-changed assignment without a needless skeleton flash on every
     * resume once nozzle options are already showing.
     */
    fun refreshPumpIfNeeded() {
        val s = _state.value
        if (s.myPumpLoading) return
        val blockedOnPump = !s.pumpReady
        val blockedOnFuelType = s.selectedVehicle != null && s.nozzleOptions().isEmpty()
        if (blockedOnPump || blockedOnFuelType) loadMyPump()
    }

    fun setMode(mode: String) {
        _state.update {
            it.copy(
                lookupMode = mode, matches = emptyList(), phoneCustomer = null,
                selectedMatchIndex = null, selectedVehicleId = null, lookupCompleted = false,
                selectedNozzleId = null, lookupError = null, result = null, createError = null,
                registerForm = null,
            )
        }
    }

    fun onVehicleNumberChange(value: String) =
        _state.update { it.copy(vehicleNumber = value.uppercase(), lookupCompleted = false) }

    fun onPhoneNumberChange(value: String) =
        _state.update { it.copy(phoneNumber = value.filter(Char::isDigit).take(10)) }

    fun onFuelAmountChange(value: String) = _state.update { current ->
        current.copy(fuelAmount = decimalInput(value))
    }

    fun onDiscountAmountChange(value: String) = _state.update { current ->
        current.copy(discountAmount = decimalInput(value))
    }

    /** Digits plus at most one decimal point. */
    private fun decimalInput(value: String): String {
        var seenDot = false
        return buildString {
            for (c in value) {
                when {
                    c.isDigit() -> append(c)
                    c == '.' && !seenDot -> { seenDot = true; append(c) }
                }
            }
        }
    }

    fun setPayment(mode: String) = _state.update { it.copy(paymentMode = mode) }

    fun lookup() {
        val s = _state.value
        if (s.lookupLoading) return // guard against a second IME/tap racing the first
        _state.update {
            it.copy(
                lookupLoading = true, lookupError = null, matches = emptyList(), phoneCustomer = null,
                selectedMatchIndex = null, selectedVehicleId = null, selectedNozzleId = null,
                lookupCompleted = false, result = null,
            )
        }
        viewModelScope.launch {
            if (s.lookupMode == MODE_VEHICLE) {
                when (val r = repository.vehicleLookup(s.vehicleNumber)) {
                    is ApiResult.Success -> _state.update {
                        it.copy(lookupLoading = false, matches = r.data, lookupCompleted = true,
                            selectedMatchIndex = if (r.data.size == 1) 0 else null)
                    }.also { if (r.data.size == 1) autoSelectNozzle() }
                    // A not-found plate is not a failure — it's the entry point to the
                    // "add customer" flow, so surface it as a completed-but-empty lookup
                    // (the invalid-format 422 still reads as a real error).
                    is ApiResult.Error ->
                        if (r.httpCode == 404 || r.code == "vehicle_not_found") {
                            _state.update {
                                it.copy(lookupLoading = false, matches = emptyList(),
                                    lookupCompleted = true, lookupError = null)
                            }
                        } else {
                            _state.update { it.copy(lookupLoading = false, lookupError = r.message) }
                        }
                    is ApiResult.NetworkError -> _state.update { it.copy(lookupLoading = false, lookupError = "Couldn't reach the server. Try again.") }
                }
            } else {
                when (val r = repository.lookupCustomer(s.phoneNumber)) {
                    is ApiResult.Success -> _state.update {
                        val autoVehicle = if (r.data.vehicles.size == 1) r.data.vehicles.first().id else null
                        it.copy(lookupLoading = false, phoneCustomer = r.data, selectedVehicleId = autoVehicle, lookupCompleted = true)
                    }.also { autoSelectNozzle() }
                    is ApiResult.Error -> _state.update { it.copy(lookupLoading = false, lookupError = r.message) }
                    is ApiResult.NetworkError -> _state.update { it.copy(lookupLoading = false, lookupError = "Couldn't reach the server. Try again.") }
                }
            }
        }
    }

    fun selectMatch(index: Int) {
        _state.update { it.copy(selectedMatchIndex = index, selectedNozzleId = null) }
        autoSelectNozzle()
    }

    fun selectVehicle(id: Long) {
        _state.update { it.copy(selectedVehicleId = id, selectedNozzleId = null) }
        autoSelectNozzle()
    }

    fun selectNozzle(id: Long) = _state.update { it.copy(selectedNozzleId = id) }

    private fun autoSelectNozzle() {
        _state.update { s ->
            val options = s.nozzleOptions()
            if (options.size == 1) s.copy(selectedNozzleId = options.first().id) else s
        }
    }

    fun create() {
        val s = _state.value
        if (s.creating) return // reentrancy guard: never post the same transaction twice
        val vehicle = s.selectedVehicle ?: return
        val amount = s.fuelAmount.toDoubleOrNull() ?: return
        _state.update { it.copy(creating = true, createError = null) }
        viewModelScope.launch {
            val request = TransactionCreateRequest(
                lookupMode = s.lookupMode,
                phoneNumber = if (s.lookupMode == MODE_PHONE) s.phoneNumber else null,
                vehicleNumber = if (s.lookupMode == MODE_VEHICLE) s.matches.getOrNull(s.selectedMatchIndex ?: -1)?.vehicleNumber else null,
                vehicleId = vehicle.first,
                fuelAmount = amount,
                discountAmount = s.discountAmount.toDoubleOrNull(),
                fuelPumpNozzleId = s.selectedNozzleId,
                paymentMode = s.paymentMode,
            )
            when (val r = repository.createTransaction(request)) {
                is ApiResult.Success -> _state.update { it.copy(creating = false, result = r.data, showCeremony = true) }
                is ApiResult.Error -> _state.update { it.copy(creating = false, createError = r.message) }
                is ApiResult.NetworkError -> _state.update { it.copy(creating = false, createError = "Couldn't reach the server. Try again.") }
            }
        }
    }

    /** Overlay auto-dismissed; the inline summary card stays behind it. */
    fun ceremonyFinished() = _state.update { it.copy(showCeremony = false) }

    /** One-shot: create failures are surfaced via snackbar, then cleared. */
    fun consumeCreateError() = _state.update { it.copy(createError = null) }

    fun startAnother() {
        _state.update {
            TxnUiState(
                myPump = it.myPump, myPumpLoading = it.myPumpLoading, myPumpError = it.myPumpError,
                catalog = it.catalog,
            )
        }
    }

    // --- Inline customer registration (unregistered plate) --------------------

    /** Lazily fetch the fuel-type / vehicle-kind options; failures leave it null. */
    fun loadCatalog() {
        if (_state.value.catalog != null) return
        viewModelScope.launch {
            when (val r = repository.catalog()) {
                is ApiResult.Success -> _state.update { it.copy(catalog = r.data) }
                is ApiResult.Error, is ApiResult.NetworkError -> Unit // pickers stay empty
            }
        }
    }

    /** Open the "add customer" sheet, prefilled with the looked-up plate. */
    fun startRegistration() {
        loadCatalog()
        _state.update { it.copy(registerForm = RegisterFormState(vehicleNumber = it.vehicleNumber)) }
    }

    fun cancelRegistration() = _state.update { it.copy(registerForm = null) }

    private fun patchRegister(transform: (RegisterFormState) -> RegisterFormState) =
        _state.update { s -> s.registerForm?.let { s.copy(registerForm = transform(it)) } ?: s }

    fun onRegisterName(value: String) = patchRegister { it.copy(name = value) }
    fun onRegisterPhone(value: String) = patchRegister { it.copy(phoneNumber = value.filter(Char::isDigit).take(10)) }
    fun onRegisterVehicleNumber(value: String) = patchRegister { it.copy(vehicleNumber = value.uppercase()) }
    fun onRegisterFuelType(code: String) = patchRegister { it.copy(fuelTypeCode = code) }
    fun onRegisterVehicleKind(code: String) = patchRegister { it.copy(vehicleKindCode = code) }
    fun onRegisterCompanyName(value: String) = patchRegister { it.copy(companyName = value) }
    fun onRegisterContactName(value: String) = patchRegister { it.copy(contactName = value) }
    fun onRegisterContactPhone(value: String) = patchRegister { it.copy(contactPhone = value.filter(Char::isDigit).take(10)) }
    fun onRegisterAddress(value: String) = patchRegister { it.copy(address = value) }
    fun onRegisterNotes(value: String) = patchRegister { it.copy(notes = value) }

    fun submitRegistration() {
        val s = _state.value
        val form = s.registerForm ?: return
        if (form.submitting) return

        val commercial = s.registrationIsCommercial
        registrationValidationError(form)?.let { message ->
            patchRegister { it.copy(error = message) }
            return
        }

        patchRegister { it.copy(submitting = true, error = null) }
        viewModelScope.launch {
            val request = RegisterCustomerRequest(
                name = form.name.trim(),
                phoneNumber = form.phoneNumber,
                vehicleNumber = form.vehicleNumber.trim(),
                fuelType = form.fuelTypeCode.orEmpty(),
                vehicleKind = form.vehicleKindCode.orEmpty(),
                commercialCompanyName = form.companyName.trim().ifBlank { null }.takeIf { commercial },
                commercialContactName = form.contactName.trim().ifBlank { null }.takeIf { commercial },
                commercialContactPhoneNumber = form.contactPhone.ifBlank { null }.takeIf { commercial },
                commercialAddress = form.address.trim().ifBlank { null }.takeIf { commercial },
                commercialNotes = form.notes.trim().ifBlank { null }.takeIf { commercial },
            )
            when (val r = repository.registerCustomer(request)) {
                is ApiResult.Success -> applyRegisteredCustomer(r.data.customer, request.vehicleNumber)
                is ApiResult.Error -> patchRegister { it.copy(submitting = false, error = r.message) }
                is ApiResult.NetworkError -> patchRegister { it.copy(submitting = false, error = "Couldn't reach the server. Try again.") }
            }
        }
    }

    /** Commercial details are all optional — staff often record the sale before they have them. */
    private fun registrationValidationError(form: RegisterFormState): String? = when {
        form.name.isBlank() -> "Enter the customer's name."
        form.phoneNumber.length != 10 -> "Enter a 10-digit phone number."
        form.vehicleNumber.isBlank() -> "Enter the vehicle number."
        form.fuelTypeCode.isNullOrBlank() -> "Select a fuel type."
        form.vehicleKindCode.isNullOrBlank() -> "Select a vehicle type."
        else -> null
    }

    /**
     * The just-registered customer becomes the sole vehicle match, so the existing
     * review → fuel → save path takes over exactly as if the plate had been found.
     */
    private fun applyRegisteredCustomer(customer: StaffCustomerDto, requestedVehicleNumber: String) {
        val wanted = requestedVehicleNumber.uppercase().filter(Char::isLetterOrDigit)
        val vehicle = customer.vehicles.firstOrNull {
            it.vehicleNumber.uppercase().filter(Char::isLetterOrDigit) == wanted
        } ?: customer.vehicles.lastOrNull()

        if (vehicle == null) {
            _state.update { it.copy(registerForm = null) }
            return
        }

        val match = VehicleMatchDto(
            vehicleId = vehicle.id,
            vehicleNumber = vehicle.vehicleNumber,
            fuelTypeCode = vehicle.fuelTypeCode,
            fuelType = vehicle.fuelType,
            vehicleKindCode = vehicle.vehicleKindCode,
            vehicleKind = vehicle.vehicleKind,
            customer = customer,
        )
        _state.update {
            it.copy(
                registerForm = null,
                vehicleNumber = vehicle.vehicleNumber,
                matches = listOf(match),
                selectedMatchIndex = 0,
                lookupCompleted = true,
                lookupError = null,
                selectedNozzleId = null,
            )
        }
        autoSelectNozzle()
    }
}
