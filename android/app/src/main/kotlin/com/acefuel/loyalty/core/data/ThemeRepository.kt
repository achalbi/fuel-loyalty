package com.acefuel.loyalty.core.data

import com.acefuel.loyalty.core.network.AceFuelApi
import com.acefuel.loyalty.core.network.ApiResult
import com.acefuel.loyalty.core.network.apiCall
import com.acefuel.loyalty.core.theme.BrandPalette
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.serialization.json.Json

class ThemeRepository(
    private val api: AceFuelApi,
    private val json: Json,
) {
    private val _primaryColorHex = MutableStateFlow(BrandPalette.DEFAULT_HEX)
    val primaryColorHex: StateFlow<String> = _primaryColorHex.asStateFlow()

    /** Fetch the admin-configured primary color; falls back to the brand default. */
    suspend fun refresh() {
        when (val result = apiCall(json) { api.theme() }) {
            is ApiResult.Success -> _primaryColorHex.value = result.data.primaryColor
            else -> Unit // keep last-known / default
        }
    }
}
