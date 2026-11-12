package fr.pedalons.karoo.support

import fr.pedalons.karoo.api.TokenResponse
import fr.pedalons.karoo.auth.TokenStore
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow

/** An in-memory [TokenStore] with the save rule of the real one. */
class FakeTokenStore(
    var access: String? = "stored-access",
    var refresh: String? = "stored-refresh",
    /** The access token has 5 minutes or less left. */
    var expired: Boolean = false,
) : TokenStore {

    var saves = 0
        private set

    private val authenticated = MutableStateFlow(access != null && refresh != null)

    override val isAuthenticated: Flow<Boolean> = authenticated

    override suspend fun validAccessToken(): String? = if (expired) null else access

    override suspend fun needsRefresh(): Boolean = expired

    override suspend fun refreshToken(): String? = refresh

    override suspend fun save(t: TokenResponse) {
        saves++
        access = t.accessToken
        refresh = t.refreshToken ?: refresh
        expired = false
        authenticated.value = access != null && refresh != null
    }

    override suspend fun clear() {
        access = null
        refresh = null
        expired = true
        authenticated.value = false
    }
}
